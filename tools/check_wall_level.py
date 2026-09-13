"""Run WallRunLevel against made-up terrain and check what it decides.

The engine's ground query is the one thing that cannot be stubbed honestly, so it is
replaced with a height field and everything else - the real WallRunLevel, the real
WallEdgeSegments, the real cuts - runs unchanged on top of it.

What must hold, for every slope and every wall type:
  * no piece ever floats: its mesh bottom (level - deep) is at or below its own ground
  * a piece is buried more than a third of its visible height only when staying put was
    already impossible
  * a flat run is left exactly where the player drew it
"""
import json
import math
import sys
from pathlib import Path

from lupa.luajit21 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("mercenaries={DevCommand=function() end}; System={LogAlways=function() end}; "
            "Script={LoadScript=function() end}")
lua.execute((ROOT / "data/Scripts/mods/mercenaries_wall.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "data/Scripts/mods/mercenaries_castle.lua").read_text(encoding="utf-8-sig"))
m = lua.globals().mercenaries

# A height field standing in for the terrain. GROUND is swapped per scenario.
lua.execute("""
GROUND = function(x, y) return 0 end
mercenaries.CampSnapToGround = function(self, p)
    return { x = p.x, y = p.y, z = GROUND(p.x, p.y) }
end
""")
m.WallSnap = True
m.WallLevel = True
m.CastleCornersOn = True
m.CastleTowersOn = False

walls = {str(t.n): (i + 1, t) for i, t in enumerate(m.CastleWalls.values())}


def select(name):
    idx, t = walls[name]
    m.WallTypeIdx = m.CastleWallBase + idx
    m.WallSegLen, m.WallUp = None, t.up or 0
    m.WallLat, m.WallOx, m.WallYawFix = t.lat or 0, t.ox or 0, t.yaw or 0
    return t


def run(points, closed=False):
    return lua.table_from({
        "pts": lua.table_from([lua.table_from({"x": x, "y": y, "z": 0})
                               for x, y in points]),
        "closed": closed})


SCENARIOS = [
    ("flat",            "function(x,y) return 0 end",                 0.0),
    ("gentle 1.5m rise", "function(x,y) return x*0.025 end",          1.5),
    ("3m rise",         "function(x,y) return x*0.05 end",            3.0),
    ("8m rise",         "function(x,y) return x*0.133 end",           8.0),
    ("20m rise",        "function(x,y) return x*0.333 end",          20.0),
    ("first mark on a peak",
     "function(x,y) if x < 6 then return 6 else return 0 end end",    6.0),
    ("valley",          "function(x,y) return math.abs(x-30)*0.2 end", 6.0),
    ("ridge",           "function(x,y) return 6-math.abs(x-30)*0.2 end", 6.0),
]

results, failures = [], []
for wall in ["kh_a", "kh02_a", "ruin_k", "fence5"]:
    t = select(wall)
    # a type sunk on purpose puts its origin `up` below the level, so the mesh bottom is
    # at level + up - deep and the wall showing above ground is tall + up
    tall, deep, up = float(t.tall), float(t.deep or 0), float(t.up or 0)
    visible = max(0.5, tall + up)
    for label, fn, _span in SCENARIOS:
        lua.execute("GROUND = " + fn)
        r = run([(0, 0), (60, 0)])
        z, how, slack = m.WallRunLevel(m, r)
        if z is None:
            failures.append("%s / %s: no level returned" % (wall, label))
            continue

        # sample the ground the same way the builder does and audit every piece
        m.WallLevelZ = None
        segs = []
        for s in m.WallEdgeSegments(m, r.pts[1], r.pts[2], False, 0, 0).values():
            segs.append(float(s.pos.ground))
        worst_float = max((z + up - deep) - g for g in segs)
        worst_bury = max(g - z for g in segs)

        if worst_float > 1e-6:
            failures.append("%s / %s: a piece floats %.2f m" % (wall, label, worst_float))
        if label == "flat" and abs(z) > 1e-6:
            failures.append("%s / %s: flat run moved to %.2f" % (wall, label, z))
        if str(how) == "first" and worst_bury > visible / 3 + 1e-6:
            failures.append("%s / %s: stayed put but buried %.2f m of %.2f showing"
                            % (wall, label, worst_bury, visible))
        results.append({"wall": wall, "terrain": label, "level_m": round(float(z), 2),
                        "rule": str(how), "worst_buried_m": round(worst_bury, 2),
                        "worst_float_m": round(max(0.0, worst_float), 3),
                        "showing_m": round(visible, 2), "third_m": round(visible / 3, 2)})

print(json.dumps({"passed": not failures, "cases": len(results),
                  "failures": failures, "detail": results}, indent=2))
raise SystemExit(1 if failures else 0)
