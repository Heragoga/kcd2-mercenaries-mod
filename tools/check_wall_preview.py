"""The projection has to be the wall that gets built, not a stand-in for it.

Drives the real build-mode tick (WallBuildTick) against a stubbed aim point and checks
what it puts on screen against what WallRebuild lays for the same marks:

  * every tile previewed with the mesh the builder uses for it - the sloped piece where
    the run climbs, not the plain straight
  * the piece that will stand on the live corner previewed there too, so the turn being
    aimed is visible while it is being aimed
  * both open ends of the previewed run closed, because these walls are shells: the
    game's own pieces have no geometry across their end faces and a run being drawn has
    nothing standing against its ends, so you see through the stone into the grass
  * the pool respawns a slot whose mesh changed, and never leaves a hole in the array
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

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("mercenaries={DevCommand=function() end}; "
            "System={LogAlways=function() end, "
            "         SpawnEntity=function(p) SPAWNED[#SPAWNED+1]=p.properties.object_Model;"
            "                                 return {id=#SPAWNED, "
            "                                         SetPos=function() end,"
            "                                         SetAngles=function() end,"
            "                                         SetMaterial=function() end,"
            "                                         SetViewDistUnlimited=function() end,"
            "                                         SetViewDistRatio=function() end,"
            "                                         SetLodRatio=function() end} end,"
            "         RemoveEntity=function(id) KILLED[#KILLED+1]=id end,"
            "         GetEntity=function(id) return LIVE[id] end}; "
            "Script={LoadScript=function() end, SetTimerForFunction=function() end}; "
            "Game={SendInfoText=function() end}; SPAWNED={}; KILLED={}; LIVE={}")
lua.execute((ROOT / "data/Scripts/mods/mercenaries_wall.lua").read_text(encoding="utf-8-sig"))
lua.execute((ROOT / "data/Scripts/mods/mercenaries_castle.lua").read_text(encoding="utf-8-sig"))
lua.execute("""
-- entities the preview pool hands back out, recording where each one is put
LIVE = setmetatable({}, { __index = function(t, id)
    local e = { id = id,
                SetPos = function(_, p) PLACED[id] = { x = p.x, y = p.y, z = p.z } end,
                SetAngles = function(_, a) YAW[id] = a.z end,
                SetMaterial = function() end }
    rawset(t, id, e)
    return e
end })
PLACED, YAW = {}, {}

AIM = nil
mercenaries.TowerLookedAtPos = function() return AIM end
mercenaries.WallSpawnMarker = function() return nil end
mercenaries.WallSpawnStartMarker = function() return nil end
mercenaries.WallClearStartMarker = function() end
mercenaries.WallGateSnapAt = function() return nil end
mercenaries.WallClearSegments = function(s) s.WallSegEnts = {} end
mercenaries.WallBuildCornerPosts = function() return 0 end
mercenaries.WallSpawnSegment = function(s, pos, yaw, model)
    BUILT[#BUILT + 1] = { x = pos.x, y = pos.y, z = pos.z, yaw = yaw,
                          m = model or MODEL, kind = "wall" }
end
mercenaries.CastleSpawnVertex = function(s, pl, at, atZ)
    local z = atZ or s.WallLevelZ or at.z or 0
    BUILT[#BUILT + 1] = { x = at.x + (pl.dx or 0), y = at.y + (pl.dy or 0),
                          z = z + (pl.up or 0), yaw = pl.yaw, m = pl.m, kind = pl.kind }
    return true
end
BUILT = {}
""")

m = lua.globals().mercenaries
m.WallSnap = False
m.CastleCornersOn, m.CastleTowersOn = True, False
walls = {str(t.n): i + 1 for i, t in enumerate(m.CastleWalls.values())}

results, failures = [], []


def ground(fn):
    """Install a terrain, as the camp's own snap-to-ground would answer it."""
    if fn is None:
        m.CampSnapToGround = None
        return
    lua.globals()["GROUND"] = lua.eval(
        "function(s, p) return { x = p.x, y = p.y, z = HEIGHT(p.x, p.y) } end")
    lua.globals()["HEIGHT"] = fn
    m.CampSnapToGround = lua.globals()["GROUND"]


def draw(marks, aim):
    lua.execute("BUILT = {}; SPAWNED = {}; KILLED = {}; PLACED = {}; YAW = {}")
    m.WallMarks = lua.table_from(
        [lua.table_from({"x": p[0], "y": p[1], "z": p[2]}) for p in marks])
    m.WallRuns = lua.table_from([])
    m.WallClosed = False
    m.WallBaseYaw = None
    m.WallFlushEnd = None
    m.WallPreviewEnts = lua.table_from([])
    m.WallPreviewMdl = lua.table_from([])
    m.WallBuildActive = True
    lua.globals()["AIM"] = lua.table_from({"x": aim[0], "y": aim[1], "z": aim[2]})
    m.WallBuildTick()
    shown = []
    ents = list(m.WallPreviewEnts.values())
    placed, yaws = lua.globals().PLACED, lua.globals().YAW
    for i, eid in enumerate(ents):
        mdl = str(m.WallPreviewMdl[i + 1])
        p = placed[eid]
        shown.append({"m": mdl, "x": float(p.x), "y": float(p.y), "z": float(p.z),
                      "yaw": float(yaws[eid])})
    return shown


def mark_run(aims):
    """Lay the corners the way the player does, so the chain the preview is compared
    against is one the game could actually produce: the aim is snapped to the type's turn
    angles and the mark to the tile grid, and a chain that skipped either would have the
    preview and the builder pointing down two different edges."""
    lua.execute("BUILT = {}")
    m.WallMarks = lua.table_from([])
    m.WallRuns = lua.table_from([])
    m.WallClosed = False
    m.WallBaseYaw = None
    m.WallFlushEnd = None
    for a in aims:
        lua.globals()["AIM"] = lua.table_from({"x": a[0], "y": a[1], "z": a[2]})
        m.WallMark(m)
    lua.execute("BUILT = {}")
    return [(float(p.x), float(p.y), float(p.z)) for p in m.WallMarks.values()]


def built(marks, closed=False):
    lua.execute("BUILT = {}")
    pts = [lua.table_from({"x": p[0], "y": p[1], "z": p[2]}) for p in marks]
    m.WallMarks = lua.table_from([])
    m.WallRuns = lua.table_from([lua.table_from({"pts": lua.table_from(pts),
                                                 "closed": closed})])
    m.WallRebuild(m)
    return [{"m": str(b.m), "x": float(b.x), "y": float(b.y), "z": float(b.z),
             "yaw": float(b.yaw), "kind": str(b.kind)}
            for b in lua.globals().BUILT.values()]


for wall in ["kh_a", "kh_c"]:
    m.WallSetType(m, m.CastleWallBase + walls[wall])
    t = m.WallTypes[m.WallTypeIdx]
    caps = {str(t.cap.start), str(t.cap.finish)} if t.cap is not None else set()
    lua.globals()["MODEL"] = str(t.m)
    step = float(t.len)

    # ---- the fence: the line, and where it stops ------------------------------
    ground(None)
    chain = mark_run([(0.0, 0.0, 0.0), (24.78, 0.0, 0.0), (24.78 + 30.0, 30.0, 0.0)])
    marks, aim = chain[:-1], chain[-1]
    shown = draw(marks, aim)
    ref = built(chain)
    fence = str(t.ghost.m) if t.ghost is not None else None
    posts = [s for s in shown if s["m"] == fence]
    entry = {"wall": wall, "projection": "fence", "pieces": len(shown),
             "fence_pieces": len(posts)}
    if not fence:
        failures.append("%s: no fence declared for the projection" % wall)
    elif len(posts) != len(shown):
        failures.append("%s: %d of %d projected pieces are not the fence"
                        % (wall, len(shown) - len(posts), len(shown)))
    if posts:
        # the far end of the fence must land on the far end of the last wall piece
        run = math.atan2(aim[1] - marks[-1][1], aim[0] - marks[-1][0])
        ux, uy = math.cos(run), math.sin(run)
        wall_end = max((b["x"] - marks[-1][0]) * ux + (b["y"] - marks[-1][1]) * uy
                       for b in ref if b["kind"] == "wall") + step
        far = max((q["x"] - marks[-1][0]) * ux + (q["y"] - marks[-1][1]) * uy
                  for q in posts) + float(t.ghost.len) * 0.5
        entry["fence_end_error_m"] = round(abs(far - wall_end), 3)
        if abs(far - wall_end) > 1.0:
            failures.append("%s: the fence stops %.2f m from where the wall will"
                            % (wall, abs(far - wall_end)))
    results.append(entry)

    # ---- with the fence off, the projection is the wall itself ----------------
    t.ghost = None
    shown = draw(marks, aim)
    ref = built(chain)

    plain = [s for s in shown if s["m"] not in caps]
    lids = [s for s in shown if s["m"] in caps]
    corner = [s for s in plain if "bend" in s["m"] or "left_90" in s["m"]
              or "right_90" in s["m"]]
    entry = {"wall": wall, "terrain": "flat", "previewed": len(shown),
             "lids": len(lids), "corner_pieces": len(corner)}

    if not caps:
        failures.append("%s: no end caps declared" % wall)
    if len(lids) != 1:
        # the near end is closed by the corner piece, so exactly one lid is wanted
        failures.append("%s flat: %d end lid(s), expected 1 (the far end)"
                        % (wall, len(lids)))
    if len(corner) != 1:
        failures.append("%s flat: the corner being aimed is not in the preview (%d shown)"
                        % (wall, len(corner)))

    # every previewed tile must sit where the builder puts one, with the same mesh
    worst = 0.0
    for s in plain:
        near = [b for b in ref
                if math.hypot(b["x"] - s["x"], b["y"] - s["y"]) < 0.05]
        if not near:
            failures.append("%s flat: previewed %s at (%.2f,%.2f) - the builder puts "
                            "nothing there" % (wall, s["m"].split("/")[-1], s["x"], s["y"]))
            continue
        if not any(b["m"] == s["m"] for b in near):
            failures.append("%s flat: previewed %s at (%.2f,%.2f) but the builder lays %s"
                            % (wall, s["m"].split("/")[-1], s["x"], s["y"],
                               near[0]["m"].split("/")[-1]))
        worst = max(worst, min(abs(b["z"] - s["z"]) for b in near))
    entry["worst_height_difference_m"] = round(worst, 4)
    if worst > 0.02:
        failures.append("%s flat: the preview sits %.2f m off the built height"
                        % (wall, worst))
    results.append(entry)

    # ---- a slope, where the builder swaps in transition pieces ----------------
    ground(lua.eval("function(x, y) return 0.10 * x end"))
    chain = mark_run([(0.0, 0.0, 0.0), (80.0, 0.0, 8.0)])
    marks, aim = chain[:-1], chain[-1]
    shown = draw(marks, aim)
    ref = built(chain)
    plain = [s for s in shown if s["m"] not in caps]
    lids = [s for s in shown if s["m"] in caps]
    sloped = [s for s in plain if "slope" in s["m"]]
    ref_sloped = [b for b in ref if "slope" in b["m"]]
    results.append({"wall": wall, "terrain": "1 in 10 climb",
                    "previewed": len(shown), "lids": len(lids),
                    "sloped_previewed": len(sloped), "sloped_built": len(ref_sloped)})
    if ref_sloped and not sloped:
        failures.append("%s slope: the builder uses %d transition piece(s) and the "
                        "preview shows none" % (wall, len(ref_sloped)))
    if len(lids) != 2:
        failures.append("%s slope: %d end lid(s) on an open run, expected 2"
                        % (wall, len(lids)))
    for s in plain:
        near = [b for b in ref if math.hypot(b["x"] - s["x"], b["y"] - s["y"]) < 0.05]
        if near and not any(b["m"] == s["m"] for b in near):
            failures.append("%s slope: previewed %s where the builder lays %s"
                            % (wall, s["m"].split("/")[-1], near[0]["m"].split("/")[-1]))

    # ---- a corner aimed on a hillside ----------------------------------------
    # (still with the fence off: this is about the wall's own projection)
    # The run is laid at ONE height and buries its footing; a corner previewed on the
    # ground under its marker instead would float metres above its own curtain.
    ground(lua.eval("function(x, y) return 0.06 * x + 0.03 * y end"))
    chain = mark_run([(0.0, 0.0, 0.0), (30.0, 0.0, 0.0), (60.0, 30.0, 0.0)])
    marks, aim = chain[:-1], chain[-1]
    shown = draw(marks, aim)
    ref = built(chain)
    corner = [s for s in shown if "bend" in s["m"] or "_90" in s["m"]]
    ref_corner = [b for b in ref if b["kind"] == "corner"]
    step = 0.0
    if corner and ref_corner:
        step = min(abs(corner[0]["z"] - b["z"]) for b in ref_corner)
    results.append({"wall": wall, "terrain": "hillside corner",
                    "previewed_corner": len(corner), "built_corner": len(ref_corner),
                    "corner_height_difference_m": round(step, 4)})
    if ref_corner and not corner:
        failures.append("%s hillside: a corner is built but not previewed" % wall)
    if step > 0.02:
        failures.append("%s hillside: the previewed corner sits %.2f m off the built one"
                        % (wall, step))

    t.ghost = m.CastleGhostFence          # put it back for the next wall type

    # ---- the pool: a slot whose mesh changes must be respawned, densely -------
    ground(None)
    draw([(0.0, 0.0, 0.0)], (60.0, 0.0, 0.0))
    before = [str(x) for x in m.WallPreviewMdl.values()]
    draw([(0.0, 0.0, 0.0), (24.78, 0.0, 0.0)], (24.78 + 30.0, 30.0, 0.0))
    after = [str(x) for x in m.WallPreviewMdl.values()]
    ents = list(m.WallPreviewEnts.values())
    if len(ents) != len(after):
        failures.append("%s pool: %d entities for %d models - the array has a hole"
                        % (wall, len(ents), len(after)))
    if any(x in ("nil", "None", "") for x in after):
        failures.append("%s pool: a slot has no model recorded" % wall)
    results.append({"wall": wall, "check": "pool", "models_before": len(before),
                    "models_after": len(after), "entities": len(ents)})

# the lids have to be the shape of the hole they close
parts, _ = cgf_mesh.load(PAK, "objects/intermediates/walltool/wall_kh_a.cgf")
V = np.concatenate([p.verts for p in parts])
for tag, plane in (("start", V[:, 1].min()), ("finish", V[:, 1].max())):
    hole = V[np.abs(V[:, 1] - plane) < 0.30]
    lid, _ = cgf_mesh.load(PAK, "objects/mercenaries/walls/merc_kh_cap_%s.cgf" % tag)
    L = np.concatenate([p.verts for p in lid])
    dx = max(abs(L[:, 0].min() - hole[:, 0].min()), abs(L[:, 0].max() - hole[:, 0].max()))
    dz = abs(L[:, 2].min() - hole[:, 2].min())
    results.append({"cap": tag, "tris": int(sum(len(p.tris) for p in lid)),
                    "width_error_m": round(float(dx), 4),
                    "foot_error_m": round(float(dz), 4)})
    if dx > 0.05:
        failures.append("cap %s: %.3f m wider or narrower than the hole" % (tag, dx))
    if dz > 0.05:
        failures.append("cap %s: foot is %.3f m off the wall's" % (tag, dz))

print(json.dumps({"passed": not failures, "failures": failures, "results": results},
                 indent=2))
sys.exit(1 if failures else 0)
