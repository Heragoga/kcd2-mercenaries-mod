"""Measure every wall mesh the castle table names, straight out of the paks.

The lengths in mercenaries.CastleWalls used to be guesses, and they were wrong by up to
2.9 m - `low_a` was declared 4.00 and measures 3.25, so every tile of it left a 0.75 m
hole. This prints what each mesh actually is, in the four figures the table needs:

    len    tile pitch, floored to a centimetre. For a piece BUILT to tile (a flat end
           face at each extreme) it is the commonest span across half-metre height
           bands - what the
           wall body spans, ignoring both the parapet overhang that laps the neighbour
           and any rubble. Anything else is measured 1st-to-99th percentile.
    yaw    -90 when the mesh runs along its own +Y, as the whole walltool kit does.
    ox     where the body sits ALONG the run relative to the origin. Pieces modelled
           from one end (seg220, whitewash) need this or the wall slides half a tile.
    lat    the same across the run: what WallLat has to be to put the wall BODY on the
           line. 5th-95th percentile within the body band, so neither a buttress spur nor
           the parapet overhang drags the wall sideways. Its sign flips with the run axis.
    tall   height ABOVE the origin. These meshes bury 1.5-4.3 m of foundation, so the
           bounding box is half again what you can stand behind.

Usage
    python tools/measure_walls.py                 # every mesh the castle table names
    python tools/measure_walls.py ruin fence      # substring filters on the entry name
    python tools/measure_walls.py --lua           # emit table rows ready to paste

See docs/castle.md.
"""
import argparse
import math
import re
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import cgf_mesh

PAKS = (r"C:/Program Files/Steam/steamapps/common/KingdomComeDeliverance2/Data/"
        r"*Objects-part*.pak")
CASTLE_LUA = ROOT / "data/Scripts/mods/mercenaries_castle.lua"


def prefixes(src):
    """Resolve `local RUI = DEF .. "walls/wall_ruined/"` chains to full paths."""
    out = {}
    for name, rhs in re.findall(r'^local (\w+)\s*=\s*(.+)$', src, re.M):
        lit = re.match(r'^"([^"]+)"', rhs)
        if lit:
            out[name] = lit.group(1)
            continue
        chain = re.match(r'^(\w+)\s*\.\.\s*"([^"]+)"', rhs)
        if chain and chain.group(1) in out:
            out[name] = out[chain.group(1)] + chain.group(2)
    return out


def entries():
    src = CASTLE_LUA.read_text(encoding="utf-8-sig", errors="replace")
    pre = prefixes(src)
    body = src.split("mercenaries.CastleWalls = {", 1)[1]
    for line in body.splitlines():
        if line.strip().startswith("}") and "=" not in line:
            return
        m = re.search(r'n\s*=\s*"([^"]+)".*?grp\s*=\s*"([^"]+)"', line)
        if not m:
            continue
        joined = re.search(r'm\s*=\s*(\w+)\s*\.\.\s*"([^"]+)"', line)
        if joined:
            path = pre.get(joined.group(1), joined.group(1)) + joined.group(2)
        else:
            bare = re.search(r'm\s*=\s*"([^"]+)"', line)
            path = bare.group(1) if bare else None
        stated = re.search(r'len\s*=\s*([0-9.]+)', line)
        yaw = re.search(r'yaw\s*=\s*(-?[0-9.]+)', line)
        yield (m.group(1), m.group(2), path,
               float(stated.group(1)) if stated else None,
               float(yaw.group(1)) if yaw else 0.0)


def measure(pak, path, yaw=0.0):
    """`yaw` is the table's own value: -90 means the mesh runs along its +Y, so the run
    axis and the across-run axis swap, and the across-run sign flips with them."""
    parts, _ = cgf_mesh.load(pak, path)
    if not parts:
        return None
    v = np.concatenate([p.verts for p in parts])
    x, y, z = v[:, 0], v[:, 1], v[:, 2]
    if round(yaw) == -90:
        # run along +Y. A body centred at local x sits that far to the RIGHT of the run,
        # so WallLat cancels it with the SAME sign, not the negated one.
        x, y = y, x
        flip = 1.0
    elif round(yaw) == 0:
        flip = -1.0
    else:
        raise SystemExit("measure_walls only knows yaw 0 and -90, got %s" % yaw)
    xlo, xhi = np.percentile(x, [1, 99])
    # The across-run stats come from the same band as the pitch: a parapet overhang is
    # wider than the wall under it, and letting it set `lat` shoves the body off the line
    # by up to 0.7 m on the thin wall.
    band = (z > -4.0) & (z < 7.0)
    if band.sum() < 50:
        band = np.ones(len(z), dtype=bool)
    ylo, yhi = np.percentile(y[band], [5, 95])

    # A piece BUILT to tile carries a flat end face at each extreme, and the pitch is the
    # distance between them - the full modelled length. Trimming that with percentiles
    # (right for a ruin, which throws rubble past its own end) shortens every tile and
    # drives the joints into each other: 18 cm of overlap on wall_kh_a, which is enough
    # for one tile's dressed stone to push through the next one's face.
    cross = max(y.max() - y.min(), 0.01)
    ends = []
    for edge in (x.min(), x.max()):
        near = np.abs(x - edge) < 0.02
        ends.append(near.sum() >= 20 and (y[near].max() - y[near].min()) > 0.5 * cross)
    tiling_faces = all(ends)

    # The pitch is what the wall BODY spans, and neither extreme measures it. The full
    # extent includes the parapet overhang, which juts 1.5 cm past the body at each end
    # precisely so it laps the neighbour - tile on that and every joint in the wall face
    # opens by 2 cm. The percentile trims the wrong end instead. Taking the span at each
    # 1 m height band and using the median reads the body itself: the overhang is two
    # bands out of fourteen, so it cannot carry the vote.
    bands = []
    for lo in np.arange(math.floor(z.min()), math.ceil(z.max()), 0.5):
        sl = (z >= lo) & (z < lo + 0.5)
        if sl.sum() >= 5:
            bands.append(float(x[sl].max() - x[sl].min()))
    # The MODE, not the median: bands cut by an arrow slit or a hoarding opening span
    # less than the body and would drag a median down, while the body's own span is the
    # one value that repeats up the whole height. The overhang appears in two bands out
    # of thirty and cannot outvote it.
    # A piece with tiling faces is aligned ACROSS the run by that face too, not by its
    # body: the arms of the walltool corners taper, so their middles do not match the
    # straight's middle even though their end faces match it exactly. Align the surfaces
    # that actually meet.
    if tiling_faces:
        face = np.abs(x - x.min()) < 0.02
        if face.sum() >= 20:
            ylo, yhi = float(y[face].min()), float(y[face].max())

    length = xhi - xlo
    if tiling_faces and bands:
        counts = {}
        for b in bands:
            key = math.floor(b * 100) / 100      # never round UP past the body
            counts[key] = counts.get(key, 0) + 1
        length = max(counts, key=lambda k: (counts[k], k))
    centre = ((x.max() + x.min()) / 2 if tiling_faces else (xlo + xhi) / 2)

    return {
        # floor, never round: a pitch longer than the stone opens a seam, a pitch
        # shorter just makes neighbours interpenetrate, which nobody can see
        "len": math.floor(length * 100) / 100,
        "faces": tiling_faces,
        # placed by its middle, so the offset has to be the middle of the same span the
        # pitch was taken from - mixing the two leaves every tile a centimetre out
        "ox": round(float(centre), 2),
        # the BODY centre, not the bounding box: a buttress, a drain or a stair
        # spur drags the box off the wall itself by up to 0.7 m
        "lat": round(flip * float((ylo + yhi) / 2), 2),
        "thick": round(float(yhi - ylo), 2),
        "tall": round(float(z.max()), 2),
        "buried": round(-float(z.min()), 2),
        "nodes": len(parts),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("filters", nargs="*", help="substring filters on the entry name")
    ap.add_argument("--lua", action="store_true", help="emit table rows ready to paste")
    args = ap.parse_args()

    pak = cgf_mesh.Pak(PAKS)
    if not args.lua:
        print("%-14s %-7s %7s %7s %6s %6s %6s %6s %5s  %s" %
              ("name", "grp", "stated", "len", "ox", "lat", "tall", "thick",
               "nodes", "note"))
        print("-" * 104)

    for name, grp, path, stated, yaw in entries():
        if args.filters and not any(f in name for f in args.filters):
            continue
        if not path or grp == "custom":
            continue
        if path.lower() not in pak:
            print("%-14s %-7s  NOT IN PAKS: %s" % (name, grp, path))
            continue
        g = measure(pak, path, yaw)
        if g is None:
            print("%-14s %-7s  NO GEOMETRY: %s" % (name, grp, path))
            continue
        if args.lua:
            print('    { n = "%s",%s grp = "%s", m = "%s", '
                  'len = %5.2f, tall = %5.2f, up = 0.00, lat = %5.2f, ox = %5.2f, '
                  'back = false, castle = true },'
                  % (name, " " * max(0, 13 - len(name)), grp, path,
                     g["len"], g["tall"], g["lat"], g["ox"]))
            continue
        note = []
        if stated and abs(stated - g["len"]) > 0.05:
            note.append("table says %.2f" % stated)
        if g["nodes"] > 6:
            note.append("COMPOSITE - a level slice, not a prop")
        if g["buried"] > 1.0:
            note.append("%.1fm buried" % g["buried"])
        note.append("tiling faces" if g["faces"] else "percentile")
        print("%-14s %-7s %7s %7.2f %6.2f %6.2f %6.2f %6.2f %5d  %s" %
              (name, grp, ("%.2f" % stated) if stated else "-", g["len"], g["ox"],
               g["lat"], g["tall"], g["thick"], g["nodes"], "; ".join(note)))


if __name__ == "__main__":
    main()
