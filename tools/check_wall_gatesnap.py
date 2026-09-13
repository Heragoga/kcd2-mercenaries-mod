"""Hanging a gate on a palisade you have reached.

A gate is hung by carrying the wall's own line onward: it starts at the wall's END and
grows outward from it, collinear, so wall - gate - wall touches all the way across. That
only works at a FREE END of a run.

Offering an interior corner was the bug behind "the gate snaps one anchor point along".
The old test took the nearest SEGMENT and grew the gate out of whichever end of it was
nearer the aim, so aiming at a corner in the middle of a run pushed the gate past that
corner and onto the next stretch of wall. A 45-degree turn hid it - the two lines diverge
fast - but a freehand palisade bends gently, and there the gate lands almost exactly one
corner along, sitting on the wall that follows.

What has to be true:

  * aiming at a free end snaps, and the gate lies along that wall's own direction
  * the gate sits BEYOND the end - it never overlaps a panel that is already standing
  * aiming at an interior corner does not snap at all; that click marks a corner instead
  * a closed ring offers nothing to snap to
"""
import json
import math
import sys
from pathlib import Path

from lupa.luajit21 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("mercenaries={DevCommand=function() end}; "
            "System={LogAlways=function(s) LOG[#LOG+1]=s end, "
            "        SpawnEntity=function() return nil end, RemoveEntity=function() end}; "
            "Script={LoadScript=function() end, SetTimerForFunction=function() end}; "
            "Game={SendInfoText=function() end}; LOG={}")
for f in ("mercenaries_wall", "mercenaries_castle", "mercenaries_gate"):
    lua.execute((ROOT / ("data/Scripts/mods/%s.lua" % f)).read_text(encoding="utf-8-sig"))
lua.execute("""
mercenaries.WallPreviewClear = function() end
mercenaries.WallClearSegments = function(s) s.WallSegEnts = {} end
mercenaries.WallBuildCornerPosts = function() return 0 end
mercenaries.WallSpawnCap = function() return true end
mercenaries.CastleSpawnVertex = function() return true end
mercenaries.GateBuildColliders = function() end
mercenaries.GateClearColliders = function() end
mercenaries.GateTouched = function() end
mercenaries.DefSave = function() end
mercenaries.WallSpawnSegment = function(s, pos, yaw, model)
    SEG[#SEG + 1] = { x = pos.x, y = pos.y, z = pos.z, yaw = yaw }
end
SEG = {}
""")

m = lua.globals().mercenaries
m.CampSnapToGround = None
m.WallSnap = False
types = {str(t.n): i + 1 for i, t in enumerate(m.WallTypes.values())}
m.WallSetType(m, types["palisade_high"])
step = float(m.WallTypes[m.WallTypeIdx].len)
WIDE = float(m.GateWidth(m))
GAP = float(m.GateWallDist or 0)

results, failures = [], []


def lay(pts, closed=False):
    """Commit a run; return the panels it puts up AND the corners it actually kept.

    A run is refitted when it is built - marks slide along their own bearings onto whole
    tile counts - so the corners that end up standing are not the ones fed in. The gate
    snaps to the wall that exists, so that is what the angles have to be measured against.
    """
    lua.execute("SEG = {}")
    m.WallMarks = lua.table_from([])
    m.WallRuns = lua.table_from([lua.table_from({
        "pts": lua.table_from([lua.table_from({"x": p[0], "y": p[1], "z": 0.0})
                               for p in pts]),
        "closed": closed})])
    m.WallRebuild(m)
    kept = [(float(q.x), float(q.y)) for q in m.WallRuns[1].pts.values()]
    return [(float(s.x), float(s.y)) for s in lua.globals().SEG.values()], kept


def aim(x, y):
    return m.WallGateSnapAt(m, lua.table_from({"x": x, "y": y, "z": 0.0}))


# A gently bending palisade - the shape that made this visible. Sharp turns hide it.
PTS = [(0.0, 0.0), (24.0, 0.0), (48.0, 4.0), (72.0, 10.0)]
panels, kept = lay(PTS)

# ==== the free end snaps, and the gate lands past it ====
for label, end, inner in (("far end", kept[-1], kept[-2]), ("start", kept[0], kept[1])):
    ux, uy = end[0] - inner[0], end[1] - inner[1]
    L = math.hypot(ux, uy)
    ux, uy = ux / L, uy / L
    got = aim(end[0] + ux * 1.5, end[1] + uy * 1.5)
    row = {"aimed at": label, "snapped": got is not None}
    if got is None:
        failures.append("%s: aiming just past the wall's own end did not snap a gate"
                        % label)
        results.append(row)
        continue

    # collinear with the wall it is meeting
    facing = float(got.yaw) - math.pi / 2
    off = math.degrees(abs(math.atan2(math.sin(facing - math.atan2(uy, ux)),
                                      math.cos(facing - math.atan2(uy, ux)))))
    row["off_the_wall_line_deg"] = round(off, 3)
    if off > 0.01:
        failures.append("%s: the gate lies %.1f degrees off the wall it is meeting; an "
                        "angled join never closes" % (label, off))

    # It grows OUTWARD from the end. The near edge deliberately tucks back into the wall
    # by GateWallDist (-0.60 m) so the joint has no daylight in it - that overlap is the
    # design, and what must not happen is the gate marching off down the standing wall.
    along = (float(got.x) - end[0]) * ux + (float(got.y) - end[1]) * uy
    edge = along - WIDE / 2
    row["centre_past_the_end_m"] = round(along, 2)
    row["near_edge_vs_end_m"] = round(edge, 2)
    if along <= 0:
        failures.append("%s: the gate's centre is %.2f m - it grew back INTO the wall "
                        "instead of onward from its end" % (label, along))
    if abs(edge - GAP) > 0.01:
        failures.append("%s: the gate's near edge is %.2f m from the wall's end; the "
                        "clearance is set to %.2f" % (label, edge, GAP))

    # and it must not have been hung a whole panel or more down the standing wall
    near = min(math.hypot(float(got.x) - p[0], float(got.y) - p[1]) for p in panels)
    row["nearest_standing_panel_m"] = round(near, 2)
    if near < step * 0.9:
        failures.append("%s: the gate's centre is %.2f m from a panel already standing, "
                        "inside the %.2f m pitch - it is sitting on the wall"
                        % (label, near, step))
    results.append(row)

# ==== an interior corner offers nothing ====
for i in (1, 2):
    c = kept[i]
    hits = [d for d in (0.0, 1.0, 2.0) if aim(c[0] + d, c[1]) is not None]
    results.append({"aimed at": "interior corner %d" % i, "snapped_at_offsets": hits})
    if hits:
        failures.append("interior corner %d snapped a gate; a gate grown from there lands "
                        "on the next stretch of wall - this is the 'one anchor point "
                        "along' bug" % i)

# ==== a closed ring has no free end ====
_, ring = lay([(0.0, 0.0), (30.0, 0.0), (30.0, 30.0), (0.0, 30.0)], closed=True)
hits = [p for p in (ring[0], ring[1], (15.0, 0.0)) if aim(p[0], p[1]) is not None]
results.append({"closed ring": "snap points offered", "hits": len(hits)})
if hits:
    failures.append("a closed ring offered %d gate snap(s); it has no free end" % len(hits))

# ==== and the stone wall is unaffected: it never snapped gates at all ====
castle = {str(t.n): i + 1 for i, t in enumerate(m.CastleWalls.values())}
m.WallSetType(m, m.CastleWallBase + castle["kh_a"])
results.append({"kh_a": "gate snap radius", "m": float(m.WallGateSnap or 0)})
if float(m.WallGateSnap or 0) != 0:
    failures.append("the stone wall has gate snapping on; it is drawn corner to corner")
m.WallSetType(m, types["palisade_high"])

print(json.dumps({"passed": not failures, "failures": failures, "results": results},
                 indent=2))
sys.exit(1 if failures else 0)
