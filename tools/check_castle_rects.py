"""Run merc_castle_rects in LuaJIT and check every rectangle it lays out.

Stubs only the engine calls, so everything measured here comes out of the real
mercenaries:CastleRects. Three checks, in rising order of how much they catch:

 1. piece count and tile centres - the arithmetic
 2. seams: each piece's REAL span pulled back out of the pak, put where the builder put
    the entity, must meet its neighbour. This is what catches a wrong `ox`, which leaves
    the tile centres perfect while the stone sits half a tile down the run.
 3. straddle: the same span across the run must sit on the rectangle's edge line. This
    is what catches a wrong `lat` SIGN, which puts a 2.5 m thick wall entirely on one
    side of where it belongs - invisible to every other check here.
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
_span = {}
_verts = {}


def verts(model):
    if model not in _verts:
        parts, _ = cgf_mesh.load(PAK, model)
        v = np.concatenate([p.verts for p in parts])
        _verts[model] = v[(v[:, 2] > 0.5) & (v[:, 2] < 7.5)]     # the wall body
    return _verts[model]


def arm_span(model, ent, edge_dir, band):
    """How far a placed piece reaches along `edge_dir`, counting only the arm that lies
    in this edge's own lateral band. Isolates one arm of an L-shaped corner mesh."""
    v = verts(model)
    c, sn = math.cos(ent["yaw"]), math.sin(ent["yaw"])
    wx = ent["x"] + v[:, 0] * c - v[:, 1] * sn
    wy = ent["y"] + v[:, 0] * sn + v[:, 1] * c
    ux, uy = math.cos(edge_dir), math.sin(edge_dir)
    along = wx * ux + wy * uy
    across = -wx * uy + wy * ux
    keep = np.abs(across - band) < 2.0            # within a wall thickness of the line
    if keep.sum() < 20:
        return None
    return float(along[keep].min()), float(along[keep].max())


def spans(model, yaw):
    """((along lo, along hi), (across lo, across hi)) of the mesh body, rubble trimmed.

    `yaw` is the wall type's own: -90 means the mesh runs along its +Y, so the two axes
    swap and the across-run one points the other way.
    """
    key = (model, yaw)
    if key not in _span:
        parts, _ = cgf_mesh.load(PAK, model)
        v = np.concatenate([p.verts for p in parts])
        v = v[(v[:, 2] > -4.0) & (v[:, 2] < 7.0)]     # the wall body, not its overhang
        if round(yaw) == -90:
            along, across = v[:, 1], -v[:, 0]
        else:
            along, across = v[:, 0], v[:, 1]
        # same test measure_walls.py uses: a piece with a flat end face at each extreme
        # tiles on its full length, so its span must be measured that way too
        cross = max(across.max() - across.min(), 0.01)
        faces = all((np.abs(along - e) < 0.02).sum() >= 20
                    and (across[np.abs(along - e) < 0.02].max()
                         - across[np.abs(along - e) < 0.02].min()) > 0.5 * cross
                    for e in (along.min(), along.max()))
        lo, hi = ((along.min(), along.max()) if faces
                  else tuple(np.percentile(along, [1, 99])))
        # the across span from the END FACE when there is one - the same basis `lat` is
        # measured on, because the wall batters and its body centre is not its face centre
        edge = np.abs(along - along.min()) < 0.02
        if faces and edge.sum() >= 20:
            acr = (float(across[edge].min()), float(across[edge].max()))
        else:
            acr = tuple(np.percentile(across, [5, 95]))
        _span[key] = ((lo, hi), acr)
    return _span[key]


lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("mercenaries={DevCommand=function() end}; "
            "System={LogAlways=function(s) table.insert(LOG, s) end}; "
            "Script={LoadScript=function() end}; LOG={}")
lua.execute((ROOT / "data/Scripts/mods/mercenaries_wall.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "data/Scripts/mods/mercenaries_castle.lua").read_text(encoding="utf-8-sig"))
lua.execute("""
SPAWNED = {}
System.SpawnEntity = function(p)
    table.insert(SPAWNED, { model = p.properties.object_Model,
                            x = p.position.x, y = p.position.y, z = p.position.z,
                            ox = p.orientation.x, oy = p.orientation.y })
    return { id = #SPAWNED, SetAngles=function() end, SetViewDistUnlimited=function() end,
             SetViewDistRatio=function() end, SetLodRatio=function() end,
             SetMaterial=function() end }
end
System.RemoveEntity = function() end
player = { GetWorldPos = function() return {x=0, y=0, z=0} end,
           GetWorldAngles = function() return {x=0, y=0, z=0} end }
""")

m = lua.globals().mercenaries
m.CampSnapToGround = None          # flat ground: the layout must be exact

SIDE, GAP = 24.0, 12.0
# The player faces +X and the rectangle is wound anticlockwise from the near-right, so
# the first edge - the one carrying the doorway - runs along +X, quarter-turn index 0.
DOOR_EDGE = 0
TOL = 0.02                         # 2 cm: below what anyone can see, above float noise

group = sys.argv[1] if len(sys.argv) > 1 else "picks"
m.CastleRects(m, "%s %g %g" % (group, SIDE, GAP))

spawned = list(lua.globals().SPAWNED.values())
walls = {str(t.n): t for t in m.CastleWalls.values()}
if group == "picks":
    names = [str(v) for v in m.CastleRectPicks.values()]
else:
    names = [n for n, t in walls.items() if group == "all" or str(t.grp) == group]

by_model = {}
for s in spawned:
    by_model.setdefault(str(s.model), []).append(s)

report, failures = [], []
for name in names:
    t = walls[name]
    length, ox, lat = float(t.len), float(t.ox or 0), float(t.lat or 0)
    yawfix = float(t.yaw or 0)
    corner = m.CastleCornerList(m, t)
    piece = None
    for c in (corner.values() if corner is not None else []):
        if abs(90 - float(c.turn or 0)) < 8:
            piece = c
    cut_in = float(piece.cutIn or piece.cut or 2.0) if piece is not None else 0.0
    cut_out = float(piece.cutOut or piece.cut or 2.0) if piece is not None else 0.0
    n = max(2, math.floor((SIDE - cut_in - cut_out) / length + 0.5))
    side = n * length + cut_in + cut_out
    want = 4 * n - 1                   # one tile is left out as a doorway

    got = by_model.get(str(t.m), [])
    if len(got) != want:
        failures.append("%s: %d pieces, expected %d" % (name, len(got), want))
        continue

    (alo, ahi), (clo, chi) = spans(str(t.m), yawfix)
    # The rectangle's centre cannot come from the entity positions: a piece modelled from
    # one end carries a large `ox`, which shifts every entity backwards along its OWN
    # edge, and those four directions do not cancel. Undo it first.
    tiles = []
    for s in got:
        a = math.atan2(s.oy, s.ox) - math.radians(yawfix)
        ux, uy = math.cos(a), math.sin(a)
        # back to the tile centre, then back to the corner this edge started from
        tiles.append((s.x + ux * ox + uy * lat, s.y + uy * ox - ux * lat, a))
    # Opposite edges are `side` apart whatever the corner allowance, so the midpoint of
    # the extremes in each axis is the rectangle's centre.
    cx = (min(p[0] for p in tiles) + max(p[0] for p in tiles)) / 2
    cy = (min(p[1] for p in tiles) + max(p[1] for p in tiles)) / 2

    seam = straddle = pitch_err = 0.0
    for e in range(4):
        edge = e * math.pi / 2                      # this edge's own direction
        ux, uy = math.cos(edge), math.sin(edge)
        nx, ny = -uy, ux                            # left normal, same as the builder's
        here = [s for s in got
                if abs(math.cos(math.atan2(s.oy, s.ox)
                                - (edge + math.radians(yawfix))) - 1) < 1e-6]
        expect = n - 1 if e == DOOR_EDGE else n
        if len(here) != expect:
            failures.append("%s: edge %d has %d pieces, expected %d"
                            % (name, e, len(here), expect))
            continue

        # ACROSS the run: the stone's own body must be centred on the rectangle's edge,
        # which sits side/2 from its middle. Fails loudly if `lat` has the wrong sign.
        for s in here:
            body = (s.x - cx) * nx + (s.y - cy) * ny + (clo + chi) / 2
            straddle = max(straddle, abs(abs(body) - side / 2))

        # ALONG the run: neighbouring stones must meet, and the spacing must be `len`.
        centres = sorted(s.x * ux + s.y * uy for s in here)
        for p, q in zip(centres, centres[1:]):
            step = q - p
            if abs(step - length) > abs(step - 2 * length):
                step -= length                      # the doorway leaves a double gap
            pitch_err = max(pitch_err, abs(step - length))
        if e != DOOR_EDGE:
            for p, q in zip(centres, centres[1:]):
                seam = max(seam, (q + alo) - (p + ahi))     # gaps only; overlap is fine

    if seam > TOL:
        failures.append("%s: %.3f m gap between neighbouring stones" % (name, seam))
    # This catches a `lat` with the WRONG SIGN, which throws the wall a wall's thickness
    # off its line. It is not a flushness test: the wall batters, so how far its across
    # centre sits from the line depends on which slice of it you measure. Whether the
    # corner and the straight actually meet flush is decided face to face, in
    # check_castle_corners.
    if straddle > 0.10:
        failures.append("%s: stone sits %.3f m off its edge line (lat sign?)"
                        % (name, straddle))
    if pitch_err > TOL:
        failures.append("%s: tile spacing off by %.3f m" % (name, pitch_err))

    report.append({"name": name, "tile": round(length, 2), "tiles_per_side": n,
                   "side_m": round(side, 2), "tall_m": float(t.tall or 0),
                   "walk_m": float(t.walk or 0), "pieces": len(got),
                   "worst_seam_m": round(seam, 4), "worst_straddle_m": round(straddle, 4),
                   "worst_pitch_m": round(pitch_err, 4)})

# ---- corner pieces: does the L actually meet the straight wall on both arms? ----
# Several wall types share one corner mesh, so by_model lumps their corners together.
# Give each corner to whichever rectangle's straights it is nearest.
hubs = {}
for nm in names:
    st = by_model.get(str(walls[nm].m), [])
    if st:
        hubs[nm] = (sum(q.x for q in st) / len(st), sum(q.y for q in st) / len(st))
owner = {}
for nm in names:
    pc = walls[nm].corners
    if pc is None:
        continue
    for c in by_model.get(str(list(pc.values())[0].m), []):
        owner[id(c)] = min(hubs, key=lambda k: math.hypot(c.x - hubs[k][0], c.y - hubs[k][1]))

corner_report = []
for name in names:
    t = walls[name]
    lst = m.CastleCornerList(m, t)
    piece = None
    for c in (lst.values() if lst is not None else []):
        if abs(90 - float(c.turn or 0)) < 8:
            piece = c
    if piece is None:
        continue
    yawfix = float(t.yaw or 0)
    straights = [{"x": s.x, "y": s.y, "yaw": math.atan2(s.oy, s.ox)}
                 for s in by_model.get(str(t.m), [])]
    if not straights:
        continue
    corners = [{"x": s.x, "y": s.y, "yaw": math.atan2(s.oy, s.ox)}
               for s in by_model.get(str(piece.m), []) if owner.get(id(s)) == name]
    if len(corners) != 4:
        failures.append("%s: %d corner pieces, expected 4" % (name, len(corners)))
        continue

    worst, doorways, length = 0.0, 0, float(t.len)
    for co in corners:
        # the corner mesh's incoming arm runs along its own +Y, so its world direction is
        # the entity yaw plus the 90 the kit is modelled with
        incoming = co["yaw"] - math.radians(float(piece.yaw or 0))
        outgoing = incoming + math.pi / 2                     # a left turn
        for direction in (incoming, outgoing):
            ux, uy = math.cos(direction), math.sin(direction)
            band = -co["x"] * uy + co["y"] * ux
            mine = arm_span(str(piece.m), co, direction, band)
            if mine is None:
                failures.append("%s: corner arm not found along %.0f deg"
                                % (name, math.degrees(direction)))
                continue
            # the nearest straight lying on the same line, on either side
            best = None
            for st in straights:
                if abs(math.cos(st["yaw"] - (direction + math.radians(yawfix))) - 1) > 1e-6:
                    continue
                sp = arm_span(str(t.m), st, direction, band)
                if sp is None:
                    continue
                gap = max(mine[0] - sp[1], sp[0] - mine[1])   # negative = overlapping
                if best is None or gap < best:
                    best = gap
            if best is None:
                continue
            # The doorway removes a tile, so the corner beside it has no neighbour and
            # the nearest wall is most of a tile away. A misfitted corner is out by
            # centimetres, never by half a tile, so the two cannot be confused. Exactly
            # one arm per rectangle may look like this; a second would be a real hole.
            if best > length / 2:
                doorways += 1
            else:
                worst = max(worst, best)
    if doorways > 1:
        failures.append("%s: %d corner arms have no wall beside them, expected 1"
                        % (name, doorways))
    corner_report.append({"name": name, "corners": len(corners), "doorways": doorways,
                          "worst_corner_gap_m": round(worst, 4)})
    if worst > TOL:
        failures.append("%s: %.3f m gap where a corner meets its wall" % (name, worst))

# The rectangles must not overlap each other.
boxes = [(nm, min(s.x for s in by_model[str(walls[nm].m)]),
          max(s.x for s in by_model[str(walls[nm].m)]),
          min(s.y for s in by_model[str(walls[nm].m)]),
          max(s.y for s in by_model[str(walls[nm].m)]))
         for nm in names if by_model.get(str(walls[nm].m))]
for i in range(len(boxes)):
    for j in range(i + 1, len(boxes)):
        a, b = boxes[i], boxes[j]
        if a[1] < b[2] and b[1] < a[2] and a[3] < b[4] and b[3] < a[4]:
            failures.append("%s overlaps %s" % (a[0], b[0]))

result = {"passed": not failures, "group": group, "rectangles": len(report),
          "pieces_total": len(spawned), "failures": failures, "detail": report,
          "corners": corner_report}
print(json.dumps(result, indent=2))
raise SystemExit(1 if failures else 0)
