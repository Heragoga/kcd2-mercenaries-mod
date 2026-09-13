"""Walk a sloping wall up and down made-up terrain and check what it spends.

A type with transition pieces is not levelled: it walks. Two shapes of walk exist.

  * The city wall ENTERS a lean, HOLDS it while the ground keeps pulling away, and
    LEAVES it back to level. Its three pieces chain because their end faces agree on
    the angle, so a long climb is one continuous incline.
  * The yard wall owns only a level-to-level STEP, so it spends one whenever the ground
    has pulled far enough away - a staircase, which is all its pieces can do.

What must hold, whichever shape:
  * flat ground spends nothing and moves nothing
  * every lean that is entered is left again before the edge ends - finishing on a
    tilted face would butt a level corner
  * a hold is only spent when a whole tile of lean is warranted, so the wall does not
    climb past the ground and then have to come back down
  * ground at the lean's own gradient is walked in ONE lean, not a series of them
"""
import json
from pathlib import Path

from lupa.luajit21 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("mercenaries={DevCommand=function() end}; System={LogAlways=function() end}; "
            "Script={LoadScript=function() end}")
lua.execute((ROOT / "data/Scripts/mods/mercenaries_wall.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "data/Scripts/mods/mercenaries_castle.lua").read_text(encoding="utf-8-sig"))
lua.execute("""
mercenaries.WallPreviewClear = function() end
mercenaries.WallRebuild = function() end
GROUND = function(x, y) return 0 end
mercenaries.CampSnapToGround = function(s, p)
    return { x = p.x, y = p.y, z = GROUND(p.x, p.y) }
end
""")
m = lua.globals().mercenaries
m.WallSnap, m.WallLevel = True, True
m.CastleCornersOn, m.CastleTowersOn = True, False
walls = {str(t.n): i + 1 for i, t in enumerate(m.CastleWalls.values())}

TERRAIN = [
    ("flat",      "function(x,y) return 0 end"),
    ("5% climb",  "function(x,y) return x*0.05 end"),
    ("8% climb",  "function(x,y) return x*0.08 end"),
    ("15% climb", "function(x,y) return x*0.15 end"),
    ("21% climb", "function(x,y) return x*0.21 end"),
    ("8% fall",   "function(x,y) return -x*0.08 end"),
    ("15% fall",  "function(x,y) return -x*0.15 end"),
    ("hill",      "function(x,y) return 9-math.abs(x-75)*0.12 end"),
    ("valley",    "function(x,y) return math.abs(x-75)*0.12 end"),
]


def symbol(model):
    s = str(model)
    return ("." if not model else
            "I" if "_in_" in s else "H" if "_ramp_" in s else
            "O" if "_out_" in s else "S")


results, failures = [], []
for wall in ["kh_a", "kh_e_wet", "khstone_a", "khplaster_b"]:
    m.WallSetType(m, m.CastleWallBase + walls[wall])
    t = m.WallTypes[m.WallTypeIdx]
    if t.slope is None:
        failures.append("%s: declares no slope pieces" % wall)
        continue
    sink = float(t.up or 0)
    leaning = t.slope.up.hold is not None
    grade = abs(float(t.slope.up.hold.rise) / float(t.len)) if leaning else         abs(float(t.slope.up.step.rise) / float(t.len))

    for label, fn in TERRAIN:
        lua.execute("GROUND = " + fn)
        r = lua.table_from({"pts": lua.table_from(
            [lua.table_from({"x": 0, "y": 0, "z": 0}),
             lua.table_from({"x": 150, "y": 0, "z": 0})]), "closed": False})
        # the climb belongs to one run; a test that reuses the runtime must clear it
        m.WallClimbReset(m)
        out = m.WallRunLevel(m, r)
        z, how = (float(out[0]), str(out[1])) if isinstance(out, tuple) else (float(out), "?")
        m.WallLevelZ = z
        m.WallClimbReset(m)
        segs = m.WallEdgeSegments(m, r.pts[1], r.pts[2], False, 0, 0)
        pieces = "".join(symbol(s.model) for s in segs.values())
        worst = max(abs(float(s.pos.ground) + sink - float(s.pos.z)) for s in segs.values())
        m.WallLevelZ = None

        if how != "stepped":
            failures.append("%s / %s: levelled instead of walked" % (wall, label))
        if label == "flat" and (pieces.strip(".") or abs(z) > 1e-6):
            failures.append("%s / flat: spent a piece on level ground" % wall)
        if pieces.count("I") != pieces.count("O"):
            failures.append("%s / %s: %d leans entered, %d left - one is still open"
                            % (wall, label, pieces.count("I"), pieces.count("O")))
        # ground at the lean's own gradient should be one lean, not several
        if leaning and label == "21% climb" and pieces.count("I") != 1:
            failures.append("%s / %s: broke a matching slope into %d leans"
                            % (wall, label, pieces.count("I")))
        results.append({"wall": wall, "terrain": label, "pieces": pieces,
                        "worst_off_ground_m": round(worst, 2),
                        "lean_gradient": round(grade, 3),
                        "shape": "lean" if leaning else "step"})

print(json.dumps({"passed": not failures, "cases": len(results),
                  "failures": failures, "detail": results}, indent=2))
raise SystemExit(1 if failures else 0)
