"""merc_castle_square must lay a rectangle that closes exactly, with no seam.

Drawing one by hand cannot: the first edge is marked before a corner exists at its start
and the closing edge is never marked at all, so both get whatever the shape leaves them,
the tiling finds a remainder, and the flush fill covers it with a piece laid nearly on
top of its neighbour. The command builds from the grid instead, and this checks it.

  * all four sides the same length, and each exactly (corner allowance + n tiles)
  * exactly 4n straight pieces - if the flush fill ever fires, that count goes up
  * the placed meshes meet along every edge with no daylight
  * on SLOPING ground every corner sits on the curtain, not on the height the run was
    marked at - the climb is carried across the whole run, and a corner that ignores it
    ends up metres under its own wall
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
TOL = 0.02
_v = {}


def verts(model):
    if model not in _v:
        _v[model] = np.concatenate([p.verts for p in cgf_mesh.load(PAK, model)[0]])
    return _v[model]


lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("mercenaries={DevCommand=function() end}; System={LogAlways=function() end}; "
            "Script={LoadScript=function() end}")
lua.execute((ROOT / "data/Scripts/mods/mercenaries_wall.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "data/Scripts/mods/mercenaries_castle.lua").read_text(encoding="utf-8-sig"))
lua.execute("""
mercenaries.WallPreviewClear = function() end
mercenaries.WallClearSegments = function(s) s.WallSegEnts = {} end
mercenaries.WallSpawnSegment = function(s, pos, yaw, model)
    SEG[#SEG + 1] = { x = pos.x, y = pos.y, z = pos.z, yaw = yaw, model = model }
end
mercenaries.WallBuildCornerPosts = function() return 0 end
mercenaries.CastleBuildVertices_real = mercenaries.CastleBuildVertices
mercenaries.CastleBuildVertices = function() return 0 end
SEG = {}
player = { GetWorldPos = function() return {x=0, y=0, z=0} end,
           GetWorldAngles = function() return {x=0, y=0, z=0} end }
""")
count = lua.eval("function(t) return #t end")
m = lua.globals().mercenaries
m.CampSnapToGround = None
m.WallSnap = False
m.CastleCornersOn, m.CastleTowersOn = True, False
walls = {str(t.n): i + 1 for i, t in enumerate(m.CastleWalls.values())}

results, failures = [], []
for wall in ["kh_a", "kh_c", "kh_e_wet"]:
    m.WallSetType(m, m.CastleWallBase + walls[wall])
    t = m.WallTypes[m.WallTypeIdx]
    step, ox, lat = float(t.len), float(t.ox or 0), float(t.lat or 0)

    for n in [0, 2, 3, 4, 6]:
        lua.execute("SEG = {}")
        m.WallRuns = lua.table_from([])
        m.CastleSquare(m, str(n))
        r = m.WallRuns[1]
        rr = lua.table_from({"pts": r.pts, "closed": True})

        sides, tiles, worst = [], [], 0.0
        for i in range(1, 5):
            j = i % 4 + 1
            a, b = r.pts[i], r.pts[j]
            L = math.hypot(b.x - a.x, b.y - a.y)
            ca = float(m.WallVertexCut(m, rr, i, "out"))
            cb = float(m.WallVertexCut(m, rr, j, "in"))
            sides.append(round(L, 4))
            tiles.append((L - ca - cb) / step)

            # the placed stone along this edge, corner arms included
            ux, uy = (b.x - a.x) / L, (b.y - a.y) / L
            items = [(str(t.m), s.x, s.y, float(s.yaw))
                     for s in lua.globals().SEG.values()]
            for k in (i, j):
                pl = m.CastleVertexPlan(m, rr, k)
                if pl is not None:
                    v = rr.pts[k]
                    items.append((str(pl.m), v.x + (pl.dx or 0), v.y + (pl.dy or 0),
                                  float(pl.yaw)))
            spans = []
            for model, px, py, yaw in items:
                vv = verts(model)
                c, s = math.cos(yaw), math.sin(yaw)
                wx = px + vv[:, 0] * c - vv[:, 1] * s
                wy = py + vv[:, 0] * s + vv[:, 1] * c
                along = (wx - a.x) * ux + (wy - a.y) * uy
                across = -(wx - a.x) * uy + (wy - a.y) * ux
                keep = (np.abs(across - lat) < 2.0) & (along > -3.0) & (along < L + 3.0)
                if keep.sum() < 20:
                    continue
                spans.append((float(along[keep].min()), float(along[keep].max())))
            spans.sort()
            for p, q in zip(spans, spans[1:]):
                worst = max(worst, q[0] - p[1])

        pieces = int(count(lua.globals().SEG))
        if len(set(sides)) != 1:
            failures.append("%s / %d tiles: sides differ %s" % (wall, n, sides))
        if any(abs(x - round(x)) > 1e-6 for x in tiles):
            failures.append("%s / %d tiles: %s tiles per edge" % (wall, n, [round(x, 4) for x in tiles]))
        if pieces != 4 * n:
            failures.append("%s / %d tiles: %d pieces, expected %d - the flush fill fired"
                            % (wall, n, pieces, 4 * n))
        if worst > TOL:
            failures.append("%s / %d tiles: %.3f m gap" % (wall, n, worst))
        results.append({"wall": wall, "tiles_per_side": n, "side_m": sides[0],
                        "pieces": pieces, "worst_gap_m": round(worst, 4)})

# ---- corners on sloping ground must stand on the curtain, not on the marked height ----
lua.execute("""
GROUND = function(x, y) return 0 end
mercenaries.CampSnapToGround = function(s, p)
    return { x = p.x, y = p.y, z = GROUND(p.x, p.y) }
end
-- the corner case needs the real vertex builder back
mercenaries.CastleBuildVertices = mercenaries.CastleBuildVertices_real
mercenaries.WallBuildCornerPosts = function() return 0 end
VERT = {}
System.SpawnEntity = function(p)
    VERT[#VERT + 1] = { x = p.position.x, y = p.position.y, z = p.position.z,
                        model = p.properties.object_Model }
    return { id = #VERT, SetAngles=function() end, SetViewDistUnlimited=function() end,
             SetViewDistRatio=function() end, SetLodRatio=function() end,
             SetMaterial=function() end }
end
""")
m.WallSnap, m.WallLevel = True, True
corners = []
for label, fn in (("flat", "function(x,y) return 0 end"),
                  ("12% slope", "function(x,y) return x*0.12 end"),
                  ("cross slope", "function(x,y) return (x+y)*0.09 end"),
                  ("hill", "function(x,y) return 12-math.sqrt((x-30)^2+(y-30)^2)*0.15 end")):
    lua.execute("GROUND = " + fn)
    for wall in ("kh_a",):
        m.WallSetType(m, m.CastleWallBase + walls[wall])
        m.WallRuns = lua.table_from([])
        lua.execute("SEG = {}; VERT = {}")
        m.CastleSquare(m, "4")        # this rebuilds; calling it again doubles everything
        seg = list(lua.globals().SEG.values())
        vert = list(lua.globals().VERT.values())
        if not vert:
            failures.append("%s / %s: no corner pieces at all" % (wall, label))
            continue
        worst = 0.0
        for v in vert:
            near = min(seg, key=lambda s: math.hypot(float(s.x) - float(v.x),
                                                     float(s.y) - float(v.y)))
            worst = max(worst, abs(float(near.z) - float(v.z)))
        corners.append({"wall": wall, "terrain": label, "corners": len(vert),
                        "worst_corner_step_m": round(worst, 4)})
        if len(vert) != 4:
            failures.append("%s / %s: %d corners, expected 4" % (wall, label, len(vert)))
        if worst > TOL:
            failures.append("%s / %s: a corner sits %.2f m off its own wall"
                            % (wall, label, worst))

print(json.dumps({"passed": not failures, "cases": len(results),
                  "failures": failures, "detail": results,
                  "corners_on_slopes": corners}, indent=2))
raise SystemExit(1 if failures else 0)
