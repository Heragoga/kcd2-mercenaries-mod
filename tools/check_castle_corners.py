"""Drive the REAL castle builder round a corner and check the stone meets.

merc_castle_rects is a lineup; this is the path merc_castle_build actually takes -
CastleVertexPlan picks the piece, WallEdgeSegments tiles the edges up to the cut it
asks for, and the two have to agree to the centimetre. Checks both hands, because the
walltool kit is the only family with a right-hand corner mesh and a right turn used to
fall back to a tower.
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

class Both(object):
    """Our own pieces live in data/Objects; the kit's live in the paks."""

    def __init__(self):
        self.pak = cgf_mesh.Pak(r"C:/Program Files/Steam/steamapps/common/"
                                r"KingdomComeDeliverance2/Data/*Objects-part*.pak")

    def read(self, path):
        local = ROOT / "data" / path
        return local.read_bytes() if local.is_file() else self.pak.read(path)


PAK = Both()
TOL = 0.02
_v = {}


def body(model):
    if model not in _v:
        parts, _ = cgf_mesh.load(PAK, model)
        v = np.concatenate([p.verts for p in parts])
        # below the parapet overhang: the band the pitch and cuts are measured in
        _v[model] = v[(v[:, 2] > -4.0) & (v[:, 2] < 7.0)]
    return _v[model]


# this check works off raw vertices, so it already sees the real end faces


def arm(model, x, y, yaw, direction, band):
    """Reach of a placed piece along `direction`, counting only the arm on that line."""
    v = body(model)
    c, s = math.cos(yaw), math.sin(yaw)
    wx, wy = x + v[:, 0] * c - v[:, 1] * s, y + v[:, 0] * s + v[:, 1] * c
    ux, uy = math.cos(direction), math.sin(direction)
    keep = np.abs(-wx * uy + wy * ux - band) < 2.0
    if keep.sum() < 20:
        return None
    a = wx * ux + wy * uy
    return float(a[keep].min()), float(a[keep].max())


lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("mercenaries={DevCommand=function() end}; System={LogAlways=function() end}; "
            "Script={LoadScript=function() end, SetTimerForFunction=function() end}; "
            "Game={SendInfoText=function() end}")
lua.execute((ROOT / "data/Scripts/mods/mercenaries_wall.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "data/Scripts/mods/mercenaries_castle.lua").read_text(encoding="utf-8-sig"))
m = lua.globals().mercenaries
m.CampSnapToGround = None
m.WallSnap = False
m.CastleCornersOn = True
m.CastleTowersOn = False           # corners only: this is what is under test

walls = {str(t.n): (i + 1, t) for i, t in enumerate(m.CastleWalls.values())}


def select(name):
    idx, t = walls[name]
    m.WallTypeIdx = m.CastleWallBase + idx
    m.WallSegLen, m.WallUp = None, t.up or 0
    m.WallLat, m.WallOx = t.lat or 0, t.ox or 0
    m.WallYawFix = t.yaw or 0
    return t


def pt(x, y):
    return lua.table_from({"x": x, "y": y, "z": 0})


def run(points, closed):
    return lua.table_from({"pts": lua.table_from([pt(*p) for p in points]),
                           "closed": closed})


def check(name, points, closed, label):
    t = select(name)
    r = run(points, closed)
    n = len(points)
    out = {"layout": label, "wall": name, "pieces": 0, "corners": 0, "issues": []}

    placed = []          # (model, x, y, yaw)
    plans = {}
    for i in range(1, n + 1):
        pl = m.CastleVertexPlan(m, r, i)
        if pl is None:
            continue
        plans[i] = pl
        v = r.pts[i]
        placed.append((str(pl.m), v.x + (pl.dx or 0), v.y + (pl.dy or 0), float(pl.yaw)))
        out["corners"] += 1
        if str(pl.kind) != "corner":
            out["issues"].append("vertex %d got a %s, not a corner" % (i, pl.kind))

    edges = range(1, n + (1 if closed else 0))
    for i in edges:
        j = i % n + 1
        a, b = r.pts[i], r.pts[j]
        cut_a = m.WallVertexCut(m, r, i, "out")
        cut_b = m.WallVertexCut(m, r, j, "in")
        # exactly what mercenaries_wall.lua's own edge() does: once a corner eats into
        # the run the tiling is flushed, so the remainder is filled by one overlapping
        # piece rather than left as daylight
        segs = m.WallEdgeSegments(m, a, b, (cut_a + cut_b) > 0, cut_a, cut_b)
        for s in segs.values():
            placed.append((str(t.m), s.pos.x, s.pos.y, float(s.yaw)))
            out["pieces"] += 1

        # every piece on this edge must meet the next with no daylight
        direction = math.atan2(b.y - a.y, b.x - a.x)
        ux, uy = math.cos(direction), math.sin(direction)
        band = -a.x * uy + a.y * ux + float(t.lat or 0)
        spans = []
        for model, x, y, yaw in placed:
            sp = arm(model, x, y, yaw, direction, band)
            if sp is not None:
                spans.append(sp)
        spans.sort()
        worst = 0.0
        for p, q in zip(spans, spans[1:]):
            worst = max(worst, q[0] - p[1])
        out.setdefault("edge_gaps", []).append(round(worst, 4))
        if worst > TOL:
            out["issues"].append("edge %d: %.3f m gap" % (i, worst))
    return out


def faces_meet(wall):
    """Do the corner's arm face and the straight's end face land on the same plane?

    This is the flushness test that matters and the only one that is unambiguous: the two
    meshes carry an identical end face (x -1.6016..1.2959 on the walltool kit), so if the
    placement is right those faces coincide in world space. Comparing the pieces' middles
    instead measures the taper, not the joint.
    """
    t = select(wall)
    step = float(t.len)
    side = 5.09 + 3.89 + 4 * step
    r = run([(0, 0), (side, 0), (side, side), (0, side)], True)
    a, b = r.pts[1], r.pts[2]
    ca = m.WallVertexCut(m, r, 1, "out")
    cb = m.WallVertexCut(m, r, 2, "in")
    seg = list(m.WallEdgeSegments(m, a, b, (ca + cb) > 0, ca, cb).values())[0]

    def world(model, x, y, yaw, pick):
        v = np.concatenate([p.verts for p in cgf_mesh.load(PAK, model)[0]])
        f = v[np.abs(pick(v) - pick(v).min()) < 0.02]
        c, s = math.cos(yaw), math.sin(yaw)
        return (x + f[:, 0] * c - f[:, 1] * s, y + f[:, 0] * s + f[:, 1] * c)

    tx, ty = world(str(t.m), seg.pos.x, seg.pos.y, float(seg.yaw), lambda v: v[:, 1])
    pl = m.CastleVertexPlan(m, r, 1)
    cv = r.pts[1]
    cx, cy = world(str(pl.m), cv.x + (pl.dx or 0), cv.y + (pl.dy or 0), float(pl.yaw),
                   lambda v: v[:, 0])
    return abs(float(cx.mean() - tx.mean())), abs(float(cy.min() - ty.min()))


SQ = [(0, 0), (60, 0), (60, 60), (0, 60)]                 # anticlockwise: left turns
CW = [(0, 0), (0, 60), (60, 60), (60, 0)]                 # clockwise: right turns
ROT = [(x * math.cos(0.6) - y * math.sin(0.6), x * math.sin(0.6) + y * math.cos(0.6))
       for x, y in SQ]

results = []
for wall in ["kh_a", "kh_b", "kh02_a"]:
    results.append(check(wall, SQ, True, "square, left turns"))
    results.append(check(wall, CW, True, "square, right turns"))
    results.append(check(wall, ROT, True, "square rotated 34 deg"))

# which mesh answered each hand
select("kh_a")
left = m.CastleVertexPlan(m, run(SQ, True), 2)
right = m.CastleVertexPlan(m, run(CW, True), 2)
hands = {"left turn": str(left.m).split("/")[-1], "right turn": str(right.m).split("/")[-1]}
if "left_90" not in hands["left turn"] or "right_90" not in hands["right turn"]:
    results.append({"layout": "handedness", "issues": ["wrong mesh for a hand: %s" % hands]})

# The generated bends are the straight piece curved, so their start face is the straight's
# own face - the joint should be flush to the millimetre, not merely close.
def bend_joint(wall, turn):
    t = select(wall)
    a = math.radians(turn)
    r = run([(0, 0), (60, 0),
             (60 + 60 * math.cos(a), 60 * math.sin(a))], False)
    pl = m.CastleVertexPlan(m, r, 2)
    if pl is None:
        return None
    ca = m.WallVertexCut(m, r, 1, "out")
    cb = m.WallVertexCut(m, r, 2, "in")
    segs = list(m.WallEdgeSegments(m, r.pts[1], r.pts[2], True, ca, cb).values())
    last = segs[-1]

    def placed(model, which, x, y, yaw):
        v = np.concatenate([p.verts for p in cgf_mesh.load(PAK, model)[0]])
        yy = v[:, 1]
        f = v[np.abs(yy - (yy.min() if which == "start" else yy.max())) < 0.02]
        c, s = math.cos(yaw), math.sin(yaw)
        return x + f[:, 0] * c - f[:, 1] * s, y + f[:, 0] * s + f[:, 1] * c

    wx, wy = placed(str(t.m), "end", last.pos.x, last.pos.y, float(last.yaw))
    v = r.pts[2]
    gx, gy = placed(str(pl.m), "start", v.x + (pl.dx or 0), v.y + (pl.dy or 0),
                    float(pl.yaw))
    return (round(float(gx.mean() - wx.mean()), 4),
            round(float(gy.min() - wy.min()), 4), str(pl.m).split("/")[-1])


bends = {}
for turn in (15, 30, 45, 60, 75, -15, -30, -45, -60, -75):
    got = bend_joint("kh_a", turn)
    if got is None:
        results.append({"layout": "bend %d" % turn, "wall": "kh_a",
                        "issues": ["no piece for a %d degree turn" % turn]})
        continue
    along, across, mesh = got
    bends["%+d" % turn] = {"mesh": mesh, "along_m": along, "across_m": across}
    # along may overlap (negative); a gap or any lateral step is a fault
    if along > TOL or abs(across) > TOL:
        results.append({"layout": "bend %d" % turn, "wall": "kh_a",
                        "issues": ["joint off by %.3f along, %.3f across"
                                   % (along, across)]})

flush = {}
for wall in ["kh_a", "kh_b", "kh_c"]:
    along, across = faces_meet(wall)
    flush[wall] = {"along_m": round(along, 4), "across_m": round(across, 4)}
    if max(along, across) > TOL:
        results.append({"layout": "flush joint", "wall": wall,
                        "issues": ["faces miss by %.3f m along, %.3f m across"
                                   % (along, across)]})

# ==== the turn a corner MAKES has to be the turn its mesh is cut for ====
# A run is drawn on the type's turn grid, but the refit then slides its marks onto the
# tile grid, and that used to change the bearing of every edge after the one it moved.
# A 40-degree turn wearing a 45-degree bend is a 5-degree wedge of daylight on the
# outgoing joint, so the refit has to slide a mark along its own bearing and nowhere
# else. Drawn here the way the player draws it - aim, snap, mark, rebuild.
lua.execute("""
AIM = nil
mercenaries.TowerLookedAtPos = function() return AIM end
mercenaries.WallSpawnMarker = function() return nil end
mercenaries.WallSpawnStartMarker = function() return nil end
mercenaries.WallClearStartMarker = function() end
mercenaries.WallGateSnapAt = function() return nil end
mercenaries.WallPreviewClear = function() end
mercenaries.WallClearSegments = function(s) s.WallSegEnts = {} end
mercenaries.WallBuildCornerPosts = function() return 0 end
mercenaries.WallSpawnSegment = function() end
mercenaries.CastleSpawnVertex = function() return true end
""")
m.WallSetType(m, m.CastleWallBase + walls["kh_a"][0])
m.WallCloseSnap = 0          # these are OPEN runs; closing is check_wall_close's job
snap = float(m.WallSnapAngle or 0)
grid = {"snap_angle_deg": snap, "runs": []}
worst_turn = 0.0
for shape in ([45], [30, 30], [75, 75], [60, 90, 60], [15, -45, 90], [90, 90, 45],
              [-75, -90, -75], [45, -45, 45]):
    m.WallMarks = lua.table_from([])
    m.WallRuns = lua.table_from([])
    m.WallClosed = False
    m.WallBaseYaw = None
    m.WallFlushEnd = None
    lua.globals()["AIM"] = pt(0.0, 0.0)
    m.WallMark(m)
    ang = 0.0
    # the first edge sets the orientation and makes no turn, so the shape's angles are
    # applied from the SECOND mark on and `turns` below reads back exactly `shape`
    lua.globals()["AIM"] = pt(45.0, 0.0)
    m.WallMark(m)
    for turn in list(shape) + [0.0]:
        mk = m.WallMarks[len(list(m.WallMarks.values()))]
        ang += math.radians(turn)
        lua.globals()["AIM"] = pt(mk.x + math.cos(ang) * 45.0, mk.y + math.sin(ang) * 45.0)
        m.WallMark(m)
    m.WallCommitRun(m)
    m.WallRebuild(m)
    r = m.WallRuns[1]
    pts = list(r.pts.values())
    bad, turns = [], []
    for i in range(2, len(pts)):
        a, b, c = r.pts[i - 1], r.pts[i], r.pts[i + 1]
        ain = math.atan2(b.y - a.y, b.x - a.x)
        aout = math.atan2(c.y - b.y, c.x - b.x)
        turn = math.degrees(aout - ain)
        while turn <= -180:
            turn += 360
        while turn > 180:
            turn -= 360
        turns.append(round(turn, 3))
        if abs(turn) < 8:
            continue                       # straight on; no piece stands here
        pl = m.CastleVertexPlan(m, r, i)
        if pl is None or str(pl.kind) != "corner":
            continue
        cut = m.CastleCornerFor(m, turn, m.WallTypes[m.WallTypeIdx])
        if cut is None:
            bad.append("turn %.2f at vertex %d has no piece" % (turn, i))
            continue
        off = abs(turn - float(cut.turn))
        worst_turn = max(worst_turn, off)
        if off > 0.05:
            bad.append("vertex %d turns %.2f but wears the %d-degree bend (%.2f out)"
                       % (i, turn, int(cut.turn), off))
    grid["runs"].append({"drawn": shape, "turns": turns, "issues": bad})
    if bad:
        results.append({"layout": "drawn %s" % shape, "wall": "kh_a", "issues": bad})
grid["worst_turn_error_deg"] = round(worst_turn, 4)

issues = [i for r in results for i in r["issues"]]
print(json.dumps({"passed": not issues, "hands": hands, "flush_joint": flush, "bends": bends,
                  "turn_grid": grid, "layouts": len(results), "failures": issues,
                  "detail": results}, indent=2))
raise SystemExit(1 if issues else 0)
