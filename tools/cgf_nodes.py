"""Report whether a .cgf is ONE object or a whole baked level section.

A mesh path that reads like a single wall (`suchdol_fortress_walls.cgf`) can be the
entire fortress in one file - 32 nodes carrying the arcades, the bridge, the gate, the
palace and the towers. Spawn one of those as a wall segment and you tile whole castles
on top of each other. The CGF chunk table says which is which without opening anything:

    nodes == 1                  one object, safe to spawn as a prop
    nodes <= 6                  one object with its own parts (a gate and its leaves)
    nodes  > 6                  a level slice; every node comes with it
    a material named *whitebox  untextured blockout art, not shippable

Usage
    python tools/cgf_nodes.py wall fence            # substring filters over all meshes
    python tools/cgf_nodes.py --single wall         # only the single-node ones
    python tools/cgf_nodes.py --file path/to.cgf    # one exact mesh
    python tools/cgf_nodes.py --lua data/Scripts/mods/mercenaries_castle.lua
                                                    # audit every mesh a Lua file names

Reads the pak central directories, so it unpacks nothing (~4s for all 16.5k meshes).
See docs/castle.md.
"""
import argparse
import glob
import json
import os
import re
import struct
import sys
import zipfile

PAKS = r"C:/Program Files/Steam/steamapps/common/KingdomComeDeliverance2/Data/IPL_Objects-part*.pak"
CHUNK_NODE = 4120
CHUNK_MESH = 4096
SMALL = 6          # up to this many nodes is one object with its own parts, not a level slice
SKIP = re.compile(r"_lod[0-9]|/cv_|_occ[.]|_wb[.]|whitebox_", re.I)
BS = chr(92).encode()


def open_index(pattern):
    index = {}
    for path in sorted(glob.glob(pattern)):
        z = zipfile.ZipFile(path)
        for name in z.namelist():
            if name.lower().endswith(".cgf"):
                index[name.lower().replace(chr(92), "/")] = (z, name)
    return index


def probe(data):
    """(nodes, meshes, names) for one .cgf, or None if it is not a chunk file."""
    if len(data) < 20 or data[:5] != b"CrChF":
        return None
    _ver, count, offset = struct.unpack_from("<III", data, 4)
    if count > 6000 or offset + count * 16 > len(data):
        return None
    nodes = meshes = 0
    for i in range(count):
        kind = struct.unpack_from("<H", data, offset + i * 16)[0]
        if kind == CHUNK_NODE:
            nodes += 1
        elif kind == CHUNK_MESH:
            meshes += 1
    names = sorted(
        s.decode()
        for s in set(re.findall(rb"[ -~]{4,}", data))
        if not s.lower().endswith(b".mtl")
        and b"/" not in s
        and BS not in s
        and len(s) < 40
        and re.match(rb"^[A-Za-z][A-Za-z0-9_ ]+$", s)
    )
    return nodes, meshes, names


def report(index, paths, single_only=False, quiet_ok=False):
    worst = 0
    for path in paths:
        entry = index.get(path)
        if not entry:
            print("%-70s  NOT IN THE PAKS" % path[-70:])
            worst = max(worst, 2)
            continue
        z, name = entry
        got = probe(z.read(name) if z else open(name, "rb").read())
        if not got:
            print("%-70s  UNREADABLE" % path[-70:])
            continue
        nodes, meshes, names = got
        if single_only and nodes != 1:
            continue
        whitebox = any("whitebox" in n.lower() for n in names)
        note = ""
        if nodes > SMALL:
            note = "  <== COMPOSITE (%d nodes)" % nodes
            worst = max(worst, 1)
        elif nodes != 1:
            # a gate is legitimately a frame plus leaves plus decals; a wall is not
            note = "  -- multi-part (%d nodes)" % nodes
        if whitebox:
            note += "  <== WHITEBOX"
            worst = max(worst, 1)
        if quiet_ok and not note:
            continue
        useful = [n for n in names if not n.startswith(("CrChF", "GlobalRange", "WH_MergeNode"))]
        print("%-64s nodes %-4d meshes %-3d %s%s"
              % (path.split("/")[-1], nodes, meshes, ",".join(useful[:5])[:52], note))
    return worst


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("filters", nargs="*", help="substrings a mesh path must contain")
    ap.add_argument("--single", action="store_true", help="only single-node meshes")
    ap.add_argument("--problems", action="store_true", help="only composite or whitebox meshes")
    ap.add_argument("--file", action="append", default=[], help="one exact mesh path")
    ap.add_argument("--lua", help="audit every objects/*.cgf a Lua file names")
    ap.add_argument("--paks", default=PAKS)
    ap.add_argument("--data", action="append", default=["data"],
                    help="also index loose objects/*.cgf under this mod data folder")
    ap.add_argument("--json", help="write the full scan to this file")
    args = ap.parse_args()

    index = open_index(args.paks)
    for root in args.data:                       # our own compiled assets, not in a pak
        for path in glob.glob(os.path.join(root, "**", "*.cgf"), recursive=True):
            rel = os.path.relpath(path, root).replace(os.sep, "/").lower()
            index[rel] = (None, path)
    if not index:
        print("no meshes found - is --paks right?", file=sys.stderr)
        return 2

    paths = [p.lower() for p in args.file]
    if args.lua:
        text = open(args.lua, encoding="utf-8").read()
        consts = {}
        for _ in range(3):                       # locals defined from earlier locals
            for var, base, rest in re.findall(
                    r'local (\w+)\s*=\s*(?:(\w+)\s*\.\.\s*)?"([^"]*)"', text):
                if base and base in consts:
                    consts[var] = consts[base] + rest
                elif not base:
                    consts[var] = rest
        for var, rest in re.findall(r'\b(\w+)\s*\.\.\s*"([^"]+\.cgf)"', text):
            if var in consts:
                paths.append((consts[var] + rest).lower())
        paths += [m.lower() for m in re.findall(r'"(objects/[^"]+\.cgf)"', text)]
        paths = sorted(set(paths))
    if args.filters:
        paths += [k for k in sorted(index)
                  if not SKIP.search(k) and all(f.lower() in k for f in args.filters)]
    if not paths:
        paths = [k for k in sorted(index) if not SKIP.search(k)]

    if args.json:
        out = {}
        for k in paths:
            if k in index:
                z, n = index[k]
                got = probe(z.read(n) if z else open(n, "rb").read())
                if got:
                    out[k] = {"nodes": got[0], "meshes": got[1], "names": got[2][:16]}
        json.dump(out, open(args.json, "w"))
        print("wrote %s (%d meshes)" % (args.json, len(out)))

    print("%d mesh(es)" % len(paths))
    return report(index, paths, single_only=args.single, quiet_ok=args.problems)


if __name__ == "__main__":
    sys.exit(main())
