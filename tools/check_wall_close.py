"""Bringing a run back to where it started has to close it, cleanly.

Drives the real build path - aim, mark, aim near the first corner, click - and checks:

  * the click CLOSES instead of marking another corner
  * the ring has no ends: every vertex carries a corner piece or a tower
  * the join is not a hole and not a wall laid on top of a wall. The tile grid cannot
    generally be made to land exactly on the corner a run started from, so the leftover
    is shared across the join's joints; what matters is that the worst single joint stays
    small and no two pieces end up on the same ground.
  * an OPEN run has both its ends lidded, because these walls are shells with no geometry
    across their end faces - that is the see-through edge

Run lengths and shapes are the ones a player actually draws, snapped through WallSnapAim.
"""
import itertools
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
CELL = 0.5
_v = {}


def body(model):
    if model not in _v:
        parts, _ = cgf_mesh.load(PAK, model)
        v = np.concatenate([p.verts for p in parts])
        _v[model] = v[(v[:, 2] > -3.0) & (v[:, 2] < 8.0)][:, :2]
    return _v[model]


def cells(model, x, y, yaw):
    v = body(model)
    c, s = math.cos(yaw), math.sin(yaw)
    wx = x + v[:, 0] * c - v[:, 1] * s
    wy = y + v[:, 0] * s + v[:, 1] * c
    q = np.stack([np.floor(wx / CELL), np.floor(wy / CELL)], 1).astype(np.int64)
    return set(map(tuple, np.unique(q, axis=0)))


lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("mercenaries={DevCommand=function() end}; "
            "System={LogAlways=function(s) LOG[#LOG+1]=s end, "
            "         SpawnEntity=function() return nil end, RemoveEntity=function() end}; "
            "Script={LoadScript=function() end, SetTimerForFunction=function() end}; "
            "Game={SendInfoText=function() end}; LOG={}")
lua.execute((ROOT / "data/Scripts/mods/mercenaries_wall.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "data/Scripts/mods/mercenaries_castle.lua").read_text(encoding="utf-8-sig"))
# closing a ring finishes the wall, and a finished stone wall cuts itself a gatehouse -
# which needs the gate module present
lua.execute((ROOT / "data/Scripts/mods/mercenaries_gate.lua").read_text(encoding="utf-8-sig"))
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
mercenaries.WallSpawnSegment = function(s, pos, yaw, model)
    SEG[#SEG + 1] = { x = pos.x, y = pos.y, z = pos.z, yaw = yaw,
                      m = model or MODEL, kind = "wall" }
end
mercenaries.GateBuildColliders = function() end
mercenaries.GateClearColliders = function() end
mercenaries.GateTouched = function() end
mercenaries.WallSpawnCap = function(s, model, seg)
    SEG[#SEG + 1] = { x = seg.pos.x, y = seg.pos.y, z = seg.pos.z, yaw = seg.yaw,
                      m = model, kind = "cap" }
    return true
end
mercenaries.CastleSpawnVertex = function(s, pl, at, atZ)
    SEG[#SEG + 1] = { x = at.x + (pl.dx or 0), y = at.y + (pl.dy or 0),
                      z = atZ or 0, yaw = pl.yaw, m = pl.m, kind = pl.kind }
    return true
end
SEG = {}
""")

m = lua.globals().mercenaries
m.CampSnapToGround = None
m.WallSnap = False
m.CastleCornersOn, m.CastleTowersOn = True, False
walls = {str(t.n): i + 1 for i, t in enumerate(m.CastleWalls.values())}

results, failures = [], []


def draw(shape, leg, close_at_end):
    """Mark the shape, then aim back at the first corner and click."""
    lua.execute("SEG = {}; LOG = {}")
    m.WallMarks = lua.table_from([])
    m.WallRuns = lua.table_from([])
    m.WallClosed = False
    m.WallBaseYaw = None
    m.WallFlushEnd = None
    m.WallBuildActive = True
    lua.globals()["AIM"] = lua.table_from({"x": 0.0, "y": 0.0, "z": 0.0})
    m.WallMark(m)
    ang = 0.0
    lua.globals()["AIM"] = lua.table_from({"x": leg, "y": 0.0, "z": 0.0})
    m.WallMark(m)
    first = (0.0, 0.0)
    for turn in shape:
        n = len(list(m.WallMarks.values()))
        if n == 0:
            break                       # the run closed itself and build mode ended
        mk = m.WallMarks[n]
        ang += math.radians(turn)
        lua.globals()["AIM"] = lua.table_from(
            {"x": mk.x + math.cos(ang) * leg, "y": mk.y + math.sin(ang) * leg, "z": 0.0})
        m.WallMark(m)
    if close_at_end:
        # The shape may already have brought the run home - walking a square round is
        # exactly that - in which case the snap has closed it and there is nothing left to
        # click. Otherwise aim back at the first corner, a little off it, as a player would.
        if len(list(m.WallMarks.values())) > 0:
            lua.globals()["AIM"] = lua.table_from({"x": first[0] + 2.0, "y": first[1] - 1.5,
                                                   "z": 0.0})
            m.WallMark(m)
    else:
        m.WallCommitRun(m)
    # Every mark rebuilds, so only the LAST render counts - draw it again from the
    # committed run with the list cleared.
    lua.execute("SEG = {}")
    m.WallRebuild(m)
    return [{"m": str(s.m), "x": float(s.x), "y": float(s.y), "yaw": float(s.yaw),
             "kind": str(s.kind)} for s in lua.globals().SEG.values()]


for wall in ["kh_a", "kh_c"]:
    m.WallSetType(m, m.CastleWallBase + walls[wall])
    t = m.WallTypes[m.WallTypeIdx]
    step = float(t.len)
    lua.globals()["MODEL"] = str(t.m)

    # ---- closing a ring -------------------------------------------------------
    for shape, leg, label in (([90, 90, 90], 50.0, "square"),
                              ([90, 90, 90], 38.0, "small square"),
                              ([60, 60, 60, 60, 60], 34.0, "hexagon"),
                              ([45, 90, 45, 90], 40.0, "chamfered")):
        pieces = draw(shape, leg, True)
        closed = bool(m.WallRuns[1].closed) if len(list(m.WallRuns.values())) else False
        r = m.WallRuns[1]
        pts = list(r.pts.values())
        rr = lua.table_from({"pts": r.pts, "closed": True})

        # No vertex the wall BENDS at may be bare. One it runs straight through is not a
        # corner at all and correctly has nothing standing on it.
        def turn_at(i):
            a, b, c = pts[(i - 2) % len(pts)], pts[i - 1], pts[i % len(pts)]
            t = math.degrees(math.atan2(c.y - b.y, c.x - b.x)
                             - math.atan2(b.y - a.y, b.x - a.x))
            return (t + 180) % 360 - 180

        bare = [i for i in range(1, len(pts) + 1)
                if abs(turn_at(i)) >= 8 and m.CastleVertexPlan(m, rr, i) is None]
        # the join: worst gap or overlap between consecutive pieces along that edge
        a, b = r.pts[len(pts)], r.pts[1]
        L = math.hypot(b.x - a.x, b.y - a.y)
        ux, uy = (b.x - a.x) / L, (b.y - a.y) / L
        spans = []
        for p in pieces:
            vv = body(p["m"])
            c, s = math.cos(p["yaw"]), math.sin(p["yaw"])
            wx = p["x"] + vv[:, 0] * c - vv[:, 1] * s
            wy = p["y"] + vv[:, 0] * s + vv[:, 1] * c
            along = (wx - a.x) * ux + (wy - a.y) * uy
            across = -(wx - a.x) * uy + (wy - a.y) * ux
            keep = (np.abs(across - float(t.lat or 0)) < 2.0) & (along > -2.0) & (along < L + 2.0)
            if keep.sum() >= 20:
                spans.append((float(along[keep].min()), float(along[keep].max())))
        spans.sort()
        # A HOLE and a LAP are not the same defect and must not share a number. Fixed-length
        # tiles cannot cover an arbitrary span exactly, so one of the two is unavoidable at
        # the join; the builder is required to choose the lap. Daylight in a curtain wall is
        # a way through it.
        worst_gap, worst_lap = 0.0, 0.0
        for p, q in zip(spans, spans[1:]):
            d = q[0] - p[1]
            if d > 0:
                worst_gap = max(worst_gap, d)
            else:
                worst_lap = max(worst_lap, -d)
        worst = worst_gap

        # nothing laid on top of anything else, anywhere on the ring
        foot = [cells(p["m"], p["x"], p["y"], p["yaw"]) for p in pieces]
        stacked = 0
        for i, j in itertools.combinations(range(len(pieces)), 2):
            inter = len(foot[i] & foot[j])
            if inter and inter / min(len(foot[i]), len(foot[j])) > 0.35:
                stacked += 1

        seam = None
        for line in list(lua.globals().LOG.values()):
            if "ring closed" in str(line):
                seam = str(line)
        entry = {"wall": wall, "ring": label, "closed": closed, "corners": len(pts),
                 "fit": seam,
                 "pieces": len(pieces), "bare_vertices": bare,
                 "worst_gap_m": round(worst_gap, 3),
                 "worst_lap_m": round(worst_lap, 3), "stacked_pairs": stacked}
        results.append(entry)
        if not closed:
            failures.append("%s %s: aiming back at the first corner did not close the ring"
                            % (wall, label))
        if bare:
            failures.append("%s %s: vertices %s have nothing standing on them"
                            % (wall, label, bare))
        if worst_gap > 0.15:
            failures.append("%s %s: %.2f m of DAYLIGHT at the join - that is a way through "
                            "the wall" % (wall, label, worst_gap))
        # a lap is the accepted compromise, but a lap of a whole tile means a piece was
        # laid on top of its neighbour for nothing
        if worst_lap > step * 0.95:
            failures.append("%s %s: the join laps %.2f m, all but a whole piece laid on "
                            "top of its neighbour" % (wall, label, worst_lap))
        if stacked:
            failures.append("%s %s: %d piece(s) laid on top of another"
                            % (wall, label, stacked))

    # ---- an open run has both ends lidded -------------------------------------
    pieces = draw([45], 45.0, False)
    lids = [p for p in pieces if p["kind"] == "cap"]
    results.append({"wall": wall, "open run": "one turn", "pieces": len(pieces),
                    "lids": len(lids)})
    if len(lids) != 2:
        failures.append("%s open run: %d lid(s) on the ends, expected 2" % (wall, len(lids)))

print(json.dumps({"passed": not failures, "failures": failures, "results": results},
                 indent=2))
sys.exit(1 if failures else 0)
