"""Print a mesh's BAKED COLLISION HULL - every `$physics_proxy` node as a world AABB.

`tools/measure_walls.py` measures what a mesh LOOKS like. This measures what it COLLIDES
like, which is a different mesh living in the same file, and it is the one you need before
building invisible-crate colliders for anything: trace the boxes onto the hull and
collision only ever sits where there is visible timber. Guessing instead is how you end up
with an invisible wall in mid-air, which plays worse than walking through.

The proxy nodes are in the `.cgf` (the scene graph), not the `.cgfm` (the vertex streams),
so this reads `IPL_Objects-part*.pak` only and unpacks nothing. Node chunk 0x100B is
{name[64], object_id at +64, 4x4 transform at +84}; its mesh chunk 0x1000 carries the
local bbox at +108. Nodes are named `$physics_proxy_<the artist's object name>`, which is
worth reading - `..._stairs_wooden_proxy003` is step 3 of a staircase.

This ANSWERS the question the `-- cv` annotations in `WallMxGroups` only guess at. The
heuristic there - a sibling `cv_*.cgf` means the mesh carries no hull of its own - is not a
dichotomy: `malesov_wall_tower.cgf` is marked `cv` and still has 40-odd inline proxies. Run
this instead of reading the annotation.

A mesh that does have `$physics_proxy` nodes collides when spawned `mercenaries_Prop` -
PROVIDED the spawn-time `properties` table carries `Physics`. Entity properties are read
when the entity physicalises, and the class default is not guaranteed to be in place by
then; see TowerSpawnPart and WallSpawnSegment. A mesh with none renders and you walk
through it, and needs colliders of its own.

Watch the pivot: a level-scale mesh puts its hull tens of metres from the origin
(malesov's starts at x 15.5), so those figures are not tower-local offsets you can paste.

Usage
    python tools/cgf_proxies.py objects/.../watchtower_a.cgf
    python tools/cgf_proxies.py --crate objects/.../watchtower_a.cgf

`--crate` also prints each box as a ready-to-paste collider row for the crate_low_a
collider mesh used by TowerColliders / the house walls, whose own proxy is
0.59 x 1.06 x 0.23 with its origin at the bottom and off centre in x:

    sx = (x1-x0)/0.59, x = x0 + 0.27*sx | sy = (y1-y0)/1.06, y = (y0+y1)/2
    sz = (z1-z0)/0.23, z = z0

See docs/archers.md for the watchtower worked example.
"""
import argparse
import glob
import struct
import sys
import zipfile

import numpy as np

PAKS = (r"C:/Program Files/Steam/steamapps/common/KingdomComeDeliverance2/Data/"
        r"IPL_Objects-part*.pak")
CHUNK_MESH, CHUNK_NODE = 0x1000, 0x100B
# crate_low_a.cgf's own $physics_proxy extents, the collider mesh the mod scales
CRATE_X0, CRATE_X1, CRATE_Y, CRATE_Z = -0.27, 0.32, 0.53, 0.23


def open_index(pattern):
    index = {}
    for path in sorted(glob.glob(pattern)):
        z = zipfile.ZipFile(path)
        for name in z.namelist():
            index[name.lower().replace(chr(92), "/")] = (z, name)
    return index


def proxies(data):
    """[(name, min, max)] for every node with geometry, in the mesh's own frame."""
    if len(data) < 16 or data[:4] != b"CrCh":
        return []
    _ver, count, table = struct.unpack_from("<III", data, 4)
    ch = {}
    for i in range(count):
        kind, _v, cid, size, off = struct.unpack_from("<HHIII", data, table + i * 16)
        ch[cid] = (kind, off, size)

    out = []
    for cid, (kind, off, _s) in sorted(ch.items()):
        if kind != CHUNK_NODE:
            continue
        name = data[off:off + 64].split(b"\0")[0].decode("latin1", "replace")
        oid = struct.unpack_from("<i", data, off + 64)[0]
        if oid not in ch or ch[oid][0] != CHUNK_MESH:
            continue
        tm = np.array(struct.unpack_from("<16f", data, off + 84), dtype=np.float64).reshape(4, 4)
        bb = struct.unpack_from("<6f", data, ch[oid][1] + 27 * 4)
        lo, hi = np.array(bb[0:3]), np.array(bb[3:6])
        if not np.all(np.isfinite(np.concatenate([lo, hi]))):
            continue
        corners = np.array([[x, y, z, 1.0] for x in (lo[0], hi[0])
                            for y in (lo[1], hi[1]) for z in (lo[2], hi[2])])
        w = (corners @ tm)[:, :3]
        out.append((name, w.min(axis=0), w.max(axis=0)))
    return out


def crate_row(name, lo, hi):
    sx, sy, sz = (hi[0] - lo[0]) / 0.59, (hi[1] - lo[1]) / 1.06, (hi[2] - lo[2]) / CRATE_Z
    return ('    { n = "%s", x = %.3f, y = %.3f, z = %.3f, sx = %.3f, sy = %.3f, sz = %.2f },'
            % (name[:18], lo[0] + 0.27 * sx, (lo[1] + hi[1]) / 2, lo[2], sx, sy, sz))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--crate", action="store_true", help="also emit collider table rows")
    args = ap.parse_args()

    index = open_index(PAKS)
    worst = 0
    for path in args.paths:
        entry = index.get(path.lower().replace(chr(92), "/"))
        if not entry:
            print("%s  NOT IN THE PAKS" % path)
            worst = 2
            continue
        z, name = entry
        found = proxies(z.read(name))
        hull = [p for p in found if p[0].startswith("$physics_proxy")]
        print("=== %s" % path.split("/")[-1])
        if not hull:
            print("    NO $physics_proxy NODES - check for a sibling cv_*.cgf; this mesh")
            print("    renders but you walk through it, and needs its own colliders.")
            worst = max(worst, 1)
        for n, lo, hi in hull:
            print("    %-42s %7.2f %7.2f %7.2f  ->%7.2f %7.2f %7.2f   %5.2f %5.2f %5.2f"
                  % (n[len("$physics_proxy_"):], lo[0], lo[1], lo[2],
                     hi[0], hi[1], hi[2], *(hi - lo)))
        if hull:
            L = np.min([p[1] for p in hull], axis=0)
            H = np.max([p[2] for p in hull], axis=0)
            print("    %-42s %7.2f %7.2f %7.2f  ->%7.2f %7.2f %7.2f"
                  % ("HULL TOTAL", *L, *H))
        if args.crate and hull:
            print("\n    -- crate_low_a collider rows")
            for n, lo, hi in hull:
                print(crate_row(n[len("$physics_proxy_"):], lo, hi))
        print("")
    return worst


if __name__ == "__main__":
    sys.exit(main())
