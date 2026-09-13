"""A palisade is drawn freehand; a castle is not.

Stone turns only where the kit owns a corner piece, so a castle run is pulled onto a grid
of allowed bearings. Stakes have no such problem - a 2.75 m panel meets its neighbour at
any angle, with a corner post over the joint - and a snap there only stops the player
drawing the line they want.

What has to be true:

  * a palisade keeps the EXACT angle aimed at: WallSnapAim hands the position back
    untouched, at seven degrees or seventy-three
  * the run still tiles: panels evenly spaced along each edge, no two stacked on
    the same spot, no daylight between neighbours
  * a castle type still snaps, and to the turns its own kit has (15 degrees for the
    Kuttenberg walls, whose corner set is 15/30/45/60/75/90)
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
castle = {str(t.n): i + 1 for i, t in enumerate(m.CastleWalls.values())}

results, failures = [], []


def build(pts):
    lua.execute("SEG = {}")
    m.WallMarks = lua.table_from([])
    m.WallRuns = lua.table_from([lua.table_from({
        "pts": lua.table_from([lua.table_from({"x": p[0], "y": p[1], "z": 0.0})
                               for p in pts]),
        "closed": False})])
    m.WallRebuild(m)
    return [{"x": float(s.x), "y": float(s.y), "yaw": float(s.yaw)}
            for s in lua.globals().SEG.values()]


# ==== the palisade keeps the angle it was aimed at ====
m.WallSetType(m, types["palisade_high"])
step = float(m.WallTypes[m.WallTypeIdx].len)
entry = {"type": "palisade_high", "snap_deg": float(m.WallSnapAngle), "angles": []}
if float(m.WallSnapAngle) != 0:
    failures.append("the palisade snaps to %g degrees; it is meant to be freehand"
                    % float(m.WallSnapAngle))

# WallSnapAim is what a mark passes through. With a base direction already set by the
# first edge, an odd angle has to come back unchanged.
m.WallMarks = lua.table_from([lua.table_from({"x": 0.0, "y": 0.0, "z": 0.0}),
                              lua.table_from({"x": 30.0, "y": 0.0, "z": 0.0})])
m.WallBaseYaw = None
frm = lua.table_from({"x": 30.0, "y": 0.0, "z": 0.0})
for deg in (7.0, 23.0, 38.5, 61.0, 73.3, 112.0, 174.0):
    want = math.radians(deg)
    aim = lua.table_from({"x": 30.0 + math.cos(want) * 25.0,
                          "y": math.sin(want) * 25.0, "z": 0.0})
    got = m.WallSnapAim(m, frm, aim)
    ang = math.degrees(math.atan2(float(got.y) - 0.0, float(got.x) - 30.0))
    entry["angles"].append({"aimed": deg, "got": round(ang, 3)})
    if abs(ang - deg) > 0.01:
        failures.append("palisade: aimed at %.1f degrees, the builder moved it to %.1f"
                        % (deg, ang))
results.append(entry)

# ==== and a freehand run still tiles ====
for name, turns in (("gentle", [7.0, -13.0, 21.0]),
                    ("sharp", [67.0, -48.0, 113.0]),
                    ("wandering", [23.5, 41.2, -17.8, 88.3])):
    pts, ang, at = [(0.0, 0.0)], 0.0, (0.0, 0.0)
    for tn in turns:
        ang += math.radians(tn)
        at = (at[0] + math.cos(ang) * 22.0, at[1] + math.sin(ang) * 22.0)
        pts.append(at)
    laid = build([(p[0], p[1], 0.0) for p in pts])
    row = {"run": name, "turns": turns, "pieces": len(laid)}

    # nothing stacked on the same spot
    worst_pair = None
    for i in range(len(laid)):
        for j in range(i + 1, len(laid)):
            d = math.hypot(laid[i]["x"] - laid[j]["x"], laid[i]["y"] - laid[j]["y"])
            if worst_pair is None or d < worst_pair:
                worst_pair = d
    row["closest_two_pieces_m"] = round(worst_pair, 3) if worst_pair else None
    if worst_pair is not None and worst_pair < step * 0.5:
        failures.append("%s: two panels %.2f m apart, closer than half the %.2f m pitch - "
                        "they are stacked" % (name, worst_pair, step))

    # Even spacing along each edge. A panel belongs to the edge it FACES: at a sharp turn
    # the next edge's panels pass within metres of this one's line, and counting those as
    # this edge's makes an honest run look mis-tiled.
    yawfix = math.radians(float(m.WallTypes[m.WallTypeIdx].yaw or 0))
    worst_gap = 0.0
    for a, b in zip(pts, pts[1:]):
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        ux, uy = (b[0] - a[0]) / L, (b[1] - a[1]) / L
        want = math.atan2(uy, ux)
        on = []
        for q in laid:
            facing = q["yaw"] - yawfix
            if abs(math.atan2(math.sin(facing - want), math.cos(facing - want))) > 0.02:
                continue
            along = (q["x"] - a[0]) * ux + (q["y"] - a[1]) * uy
            across = -(q["x"] - a[0]) * uy + (q["y"] - a[1]) * ux
            if abs(across) < 1.5 and -1.0 < along < L + 1.0:
                on.append(along)
        on.sort()
        for p, q in zip(on, on[1:]):
            worst_gap = max(worst_gap, abs((q - p) - step))
    row["worst_spacing_error_m"] = round(worst_gap, 3)
    if worst_gap > 0.05:
        failures.append("%s: panels are out by %.2f m from the %.2f m pitch"
                        % (name, worst_gap, step))
    results.append(row)

# ==== the castle still snaps, to its own kit's turns ====
for wall in ("kh_a", "kh_c"):
    m.WallSetType(m, m.CastleWallBase + castle[wall])
    snap = float(m.WallSnapAngle)
    turns = sorted({abs(int(c.turn)) for c
                    in (m.CastleCornerList(m, m.WallTypes[m.WallTypeIdx]) or {}).values()})
    results.append({"type": wall, "snap_deg": snap, "kit_turns": turns})
    if snap <= 0:
        failures.append("%s: the stone wall is freehand; it can only turn where its kit "
                        "has a corner" % wall)
    if any(t % int(snap) for t in turns if t):
        failures.append("%s: the snap of %g degrees does not divide every turn the kit "
                        "owns (%s)" % (wall, snap, turns))

    m.WallMarks = lua.table_from([lua.table_from({"x": 0.0, "y": 0.0, "z": 0.0}),
                                  lua.table_from({"x": 40.0, "y": 0.0, "z": 0.0})])
    m.WallBaseYaw = None
    frm = lua.table_from({"x": 40.0, "y": 0.0, "z": 0.0})
    aim = lua.table_from({"x": 40.0 + math.cos(math.radians(23.0)) * 30.0,
                          "y": math.sin(math.radians(23.0)) * 30.0, "z": 0.0})
    got = m.WallSnapAim(m, frm, aim)
    ang = math.degrees(math.atan2(float(got.y), float(got.x) - 40.0))
    results[-1]["aimed_23_landed_on"] = round(ang, 2)
    if abs(ang - round(ang / snap) * snap) > 0.01:
        failures.append("%s: 23 degrees landed on %.2f, which is not a multiple of %g"
                        % (wall, ang, snap))

print(json.dumps({"passed": not failures, "failures": failures, "results": results},
                 indent=2))
sys.exit(1 if failures else 0)
