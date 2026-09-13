"""A way through the stone wall: the archway tile, and the leaves hung in it.

A gate for a stone curtain is not a gate stood in a gap, the way a palisade's is - the
wall has to open. The kit ships a TILE with an arch cut through it on the same pitch as
the plain one, so it drops into the run and the merlon grid carries over the top. What
has to be true:

  * exactly one tile of the run becomes the archway, and the rest are unchanged
  * that tile is RAISED by the curtain's own sink, or the opening is underground: the
    arch is cut at the mesh's ground and the curtain is buried three metres
  * the leaves are hung inside the opening, not somewhere along the tile
  * rebuilding does not hang a second set, and clearing puts plain curtain back
  * the leaves the gateway carries are its own, not whatever gate style the camp is on
  * a finished stone wall cuts its OWN way through, on a straight stretch with a whole
    tile of wall either side - nobody buys a gatehouse separately, and a wall with no way
    in is a camp nobody can enter
"""
import json
import math
import sys
from pathlib import Path

import numpy as np
from lupa.luajit21 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import cgf_mesh

PAK = cgf_mesh.Pak(r"C:/Program Files/Steam/steamapps/common/"
                   r"KingdomComeDeliverance2/Data/*Objects-part*.pak")

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("mercenaries={DevCommand=function() end}; "
            "System={LogAlways=function(s) LOG[#LOG+1]=s end, "
            "         SpawnEntity=function() return nil end, RemoveEntity=function() end}; "
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
mercenaries.WallSpawnSegment = function(s, pos, yaw, model)
    SEG[#SEG + 1] = { x = pos.x, y = pos.y, z = pos.z, yaw = yaw, m = model or MODEL }
end
mercenaries.GateTouched = function() end
mercenaries.DefSave = function() end
SEG = {}
""")
# the gate module spawns props; there is no world here, so let the record stand alone
lua.execute("mercenaries.GateBuildColliders = function() end\n"
            "mercenaries.GateClearColliders = function() end")

m = lua.globals().mercenaries
m.CampSnapToGround = None
m.WallSnap = False
m.CastleCornersOn, m.CastleTowersOn = True, False
m.Gates = lua.table_from([])
walls = {str(t.n): i + 1 for i, t in enumerate(m.CastleWalls.values())}

results, failures = [], []


def rebuild(pts, closed=False):
    lua.execute("SEG = {}")
    m.WallMarks = lua.table_from([])
    m.WallRuns = lua.table_from([lua.table_from({
        "pts": lua.table_from([lua.table_from({"x": p[0], "y": p[1], "z": p[2]})
                               for p in pts]),
        "closed": closed})])
    m.WallRebuild(m)
    return [{"m": str(s.m), "x": float(s.x), "y": float(s.y), "z": float(s.z),
             "yaw": float(s.yaw)} for s in lua.globals().SEG.values()]


for wall in ["kh_a", "kh_c"]:
    m.WallSetType(m, m.CastleWallBase + walls[wall])
    t = m.WallTypes[m.WallTypeIdx]
    lua.globals()["MODEL"] = str(t.m)
    spec = t.gateway
    if spec is None:
        failures.append("%s: no gateway piece declared" % wall)
        continue
    arch = str(spec.m)
    rise = float(spec.rise)
    along = float(spec.along)

    # a straight run, then a gateway asked for a third of the way along it
    pts = [(0.0, 0.0, 0.0), (12.39 * 5, 0.0, 0.0)]
    m.CastleGateways = lua.table_from([])
    plain = rebuild(pts)
    at = plain[2]
    m.CastleGateways = lua.table_from(
        [lua.table_from({"x": at["x"] + 6.0, "y": at["y"], "z": 0.0})])
    m.Gates = lua.table_from([])
    laid = rebuild(pts)

    arches = [s for s in laid if s["m"] == arch]
    others = [s for s in laid if s["m"] != arch]
    gates = [g for g in m.Gates.values()]
    entry = {"wall": wall, "pieces": len(laid), "archways": len(arches),
             "gates_hung": len(gates)}

    if len(arches) != 1:
        failures.append("%s: %d archway tiles, expected exactly 1" % (wall, len(arches)))
    if len(laid) != len(plain):
        failures.append("%s: the run has %d pieces with a gateway and %d without - the "
                        "archway tile is not the same pitch" % (wall, len(laid), len(plain)))
    if len(gates) != 1:
        failures.append("%s: %d gate(s) hung, expected 1" % (wall, len(gates)))

    if arches and others:
        lift = arches[0]["z"] - others[0]["z"]
        entry["raised_m"] = round(lift, 3)
        if abs(lift - rise) > 0.01:
            failures.append("%s: the archway tile is raised %.2f m, expected %.2f - its "
                            "opening would be underground" % (wall, lift, rise))

    # the leaves have to be INSIDE the opening, which is where the mesh has no stone
    if arches and gates:
        g = gates[0]
        a = arches[0]
        run = a["yaw"] - math.radians(float(t.yaw or 0))
        d = ((g.x - a["x"]) * math.cos(run) + (g.y - a["y"]) * math.sin(run))
        entry["leaves_at_m"] = round(d, 2)
        parts, _ = cgf_mesh.load(PAK, arch)
        v = parts[0].verts
        low = v[(v[:, 2] > 0.3) & (v[:, 2] < 2.0)]
        # the clear span: the widest stretch of the tile with no stone in the walking band
        ys = np.sort(low[:, 1])
        gaps = np.diff(ys)
        i = int(np.argmax(gaps))
        lo, hi = float(ys[i]), float(ys[i + 1])
        entry["opening_m"] = [round(lo, 2), round(hi, 2)]
        # the gate sits `rise` above the tile origin, so compare in the tile's own frame
        if not (lo < d - (rise - rise) < hi):
            failures.append("%s: the leaves sit %.2f m along the tile, outside the "
                            "opening at %.2f..%.2f" % (wall, d, lo, hi))
        if abs(d - along) > 0.01:
            failures.append("%s: the leaves are at %.2f m, the spec says %.2f"
                            % (wall, d, along))
        # The leaves are 2.35 m wide along their own X and the entity yaw adds GateYawFix,
        # so that width has to come out ALONG the run. Across it, the door vanishes inside
        # three and a half metres of wall and the gate is invisible.
        mesh = float(g.yaw) + math.radians(float(m.GateYawFix or 0))
        entry["leaf_width_along_run"] = round(abs(math.cos(mesh - run)), 4)
        if abs(math.cos(mesh - run)) < 0.99:
            failures.append("%s: the leaves lie %.0f degrees off the run, so they are "
                            "buried in the wall" % (wall, math.degrees(abs(mesh - run))))
        # and the seal has to cross the opening, not the stone
        seal = [b for b in m.GateBlockSegments(m).values()]
        if seal:
            b = seal[0]
            sx, sy = b.bx - b.ax, b.by - b.ay
            L = math.hypot(sx, sy)
            entry["seal_along_run"] = round(abs((sx / L) * math.cos(run)
                                                + (sy / L) * math.sin(run)), 4)
            if abs((sx / L) * math.cos(run) + (sy / L) * math.sin(run)) < 0.99:
                failures.append("%s: the gate's seal lies across the wall, not across the "
                                "opening" % wall)
        if str(g.style.n) != "kh_arch":
            failures.append("%s: the gateway is wearing the camp's gate style, not its own"
                            % wall)
        if str(g.tag) != "gateway":
            failures.append("%s: the gateway's leaves are not tagged, so a rebuild will "
                            "leave a second set behind" % wall)

    # rebuilding must not stack a second set of leaves
    rebuild(pts)
    again = len([g for g in m.Gates.values()])
    entry["gates_after_rebuild"] = again
    if again != 1:
        failures.append("%s: %d gate(s) after a second rebuild - the leaves are being "
                        "hung again without the old ones coming down" % (wall, again))

    # and clearing puts plain curtain back
    m.CastleGateways = lua.table_from([])
    back = rebuild(pts)
    entry["archways_after_clear"] = len([s for s in back if s["m"] == arch])
    if any(s["m"] == arch for s in back):
        failures.append("%s: an archway tile is still standing after the gateways were "
                        "cleared" % wall)
    results.append(entry)

# ==== the automatic gatehouse ====
# Finishing a stone wall has to cut one without being asked, and it has to land on a
# straight stretch rather than jammed against a corner.
m.WallSetType(m, m.CastleWallBase + walls["kh_a"])
t = m.WallTypes[m.WallTypeIdx]
lua.globals()["MODEL"] = str(t.m)
arch = str(t.gateway.m)
step = float(t.len)

for label, pts, closed in (
        ("straight run", [(0.0, 0.0, 0.0), (step * 5, 0.0, 0.0)], False),
        ("square", [(0.0, 0.0, 0.0), (49.56, 0.0, 0.0), (49.56, 49.56, 0.0),
                    (0.0, 49.56, 0.0)], True)):
    m.CastleGateways = lua.table_from([])
    m.Gates = lua.table_from([])
    lua.execute("SEG = {}")
    m.WallMarks = lua.table_from([])
    m.WallRuns = lua.table_from([lua.table_from({
        "pts": lua.table_from([lua.table_from({"x": p[0], "y": p[1], "z": p[2]})
                               for p in pts]),
        "closed": closed})])
    m.WallRebuild(m)
    made = bool(m.CastleGatewayAuto(m))
    laid = [{"m": str(x.m), "x": float(x.x), "y": float(x.y)}
            for x in lua.globals().SEG.values()]
    arches = [x for x in laid if x["m"] == arch]
    entry = {"auto": label, "cut": made, "gateways": len(list(m.CastleGateways.values())),
             "archways": len(arches)}

    # it must not sit on the first or last tile of its edge: those are the corner's
    plain = [x for x in laid if x["m"] != arch]
    if arches:
        a = arches[0]
        near = min(math.hypot(a["x"] - q["x"], a["y"] - q["y"]) for q in plain)
        far = [q for q in plain
               if abs(math.hypot(a["x"] - q["x"], a["y"] - q["y"]) - step) < step * 0.35]
        entry["neighbours_a_tile_away"] = len(far)
        entry["nearest_other_piece_m"] = round(near, 2)
        if len(far) < 2:
            failures.append("auto %s: the gatehouse has %d neighbouring tile(s), so it is "
                            "against a corner" % (label, len(far)))
    if not made:
        failures.append("auto %s: no gatehouse was cut" % label)
    if len(arches) != 1:
        failures.append("auto %s: %d archway tiles, expected 1" % (label, len(arches)))

    # asking again must not cut a second one
    again = bool(m.CastleGatewayAuto(m))
    entry["cut_again"] = again
    if again:
        failures.append("auto %s: a second gatehouse was cut into a wall that had one"
                        % label)
    results.append(entry)

# ==== a run's ENDS ====
# The wall finishes its own ends with its lid. Standing the mod's own tower there puts a
# different wall's block on the Kuttenberg curtain - wrong height, wrong stone - and it
# reads as a corner that failed to appear rather than as a finish.
m.CastleTowersOn = True
m.CastleTowerEnds = True
m.CastleGateways = lua.table_from([])
pts = [(0.0, 0.0, 0.0), (step * 3, 0.0, 0.0), (step * 3, step * 3, 0.0)]
m.WallMarks = lua.table_from([])
m.WallRuns = lua.table_from([lua.table_from({
    "pts": lua.table_from([lua.table_from({"x": p[0], "y": p[1], "z": p[2]}) for p in pts]),
    "closed": False})])
r = m.WallRuns[1]
ends = []
for i in (1, 3):
    pl = m.CastleVertexPlan(m, r, i)
    ends.append(None if pl is None else str(pl.kind))
results.append({"open run": "ends", "towers_on": True, "end_pieces": ends})
if any(e == "tower" for e in ends):
    failures.append("a run end took a tower the wall does not own; it should take its lid")

print(json.dumps({"passed": not failures, "failures": failures, "results": results},
                 indent=2))
sys.exit(1 if failures else 0)
