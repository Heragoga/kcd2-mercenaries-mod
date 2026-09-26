-- =============================================================================
-- Walls NPCs steer around: the engine's own dynamic-obstacle channel.
--
-- The navmesh ships baked (Levels/<level>/recast.pak, Detour tiles), so a palisade the
-- player builds is never in it and the long-range pathfinder aims straight through. The
-- engine's answer for things that appear after the bake is not the navmesh at all - it is
-- the collision-avoidance obstacle set, the local steering layer that makes an NPC veer
-- round a barrel. That layer IS fed from data, by one property:
--
--     Properties.AI.bUsedAsDynamicObstacle = 1
--
-- `RigidBodyEx` ships it with Warhorse's comment "This value is currently used for the MNM
-- Navigation System", and it is the only navigation-related property in the whole script
-- pak. Read in WHGame.dll (release_1_5_1308617_856) by sub_30141B0 (Properties -> AI ->
-- the flag); sub_300CB98 turns the entity's bounding box into an obstacle cylinder and
-- sub_2FF685C adds it to the avoidance set of every agent nearby.
--
-- The mod used to spawn wall segments as `mercenaries_Prop`, which had no `AI` sub-table
-- at all - so every wall was invisible to that system. The property now lives on the class
-- and in the spawn parameters (mercenaries_Prop.lua, WallSpawnSegment). This file arms the
-- cvar that makes the engine consume it, and only while the player is near a wall of ours.
--
-- Two honest limits:
--   * this is LOCAL steering, not planning. An NPC veers when the obstacle is inside his
--     avoidance horizon; he does not plan a route to a gate 40 m away. The mod's own A*
--     (mercenaries_navmesh.lua) is what does the planning for mod NPCs, and
--     mercenaries_solid.lua is the backstop that stops anyone who still arrives.
--   * a wall is a long thin thing made of many cylinders, which is not what an avoidance
--     solver is best at. Expect "veers along it" rather than "turns and walks to the gate".
--
-- No native code, no ASI loader: this ships in the pak like everything else.
-- =============================================================================

local function obstSay(s) System.LogAlways("[MercNavObst] " .. s) end

-- 0 = never touch the cvars, 1 = arm while near a wall of ours (default), 2 = always armed
mercenaries.NavObstMode   = 1
mercenaries.NavObstGate   = 140.0    -- player further than this from every wall: disarm
mercenaries.NavObstTickMs = 2000

-- `wh_ai_ObstaclesAddToCollisionAvoidance` is deliberately NOT written: it already ships
-- enabled, and writing our own value only risks lowering it.
--
-- What was actually wrong once the walls were registered as obstacles: the solver stops
-- avoiding as an agent closes in. `ai_CollisionAvoidanceTargetCutoffRange` ships at 3.0 m
-- and its help text is "Distance from its current target for an agent to stop avoiding
-- obstacles" - so a man walking at something within 3 m of a wall gives up avoiding exactly
-- where the wall is. The path-end cutoff (1.3 m) does the same for his destination. Those
-- two are the "it barely works".
mercenaries.NavObstTargetCut  = 0.5     -- ships 3.0
mercenaries.NavObstPathEndCut = 0.5     -- ships 1.3
-- A palisade is long. Seen 5 m out with a 1.5 s horizon there is no room to go round it,
-- only to clip it, so both are widened.
mercenaries.NavObstRange      = 12.0    -- ships 5.0
mercenaries.NavObstHorizon    = 3.0     -- ships 1.5
-- Metres added to every dynamic obstacle's own size, and the floor for an actor's. A wall
-- segment is about 2.75 m long and thin, so a margin is what turns "clips the corner" into
-- "goes round it".
mercenaries.NavObstExtra  = 0.6
mercenaries.NavObstMinAct = 1.0
-- Per-agent, through AI.SetCollisionAvoidanceRadiusIncrement. The engine ramps towards it
-- (ai_CollisionAvoidanceRadiusIncrement{Increase,Decrease}Rate) rather than applying it
-- instantly, and honours it only while ai_CollisionAvoidanceEnableRadiusIncrement is on.
mercenaries.NavObstAgentInc = 0.8
mercenaries.NavObstAgents   = true      -- do the per-agent pass at all
-- `wh_ai_DisableORCAInBattle` ships at 1: "Is ORCA disabled during battle game context".
-- Collision avoidance is switched off outright once a fight starts, which is the whole of
-- "in combat it does nothing". Turning it back on is one cvar - but it is off by default
-- for a reason (men who avoid each other are men who will not close to swing), so it is its
-- own switch, armed only inside the camp region like everything else here.
mercenaries.NavObstOrcaInBattle = true
mercenaries.NavObstTouched  = {}        -- [key] = true, so an increment can be taken back

mercenaries.NavObstArmed  = false
mercenaries.NavObstSaved  = nil      -- the cvars as they shipped, restored on disarm

-- Every cvar this module writes, with the value it writes.
function mercenaries:NavObstWants()
    return {
        ai_CollisionAvoidanceTargetCutoffRange     = self.NavObstTargetCut,
        ai_CollisionAvoidancePathEndCutoffRange    = self.NavObstPathEndCut,
        ai_CollisionAvoidanceRange                 = self.NavObstRange,
        ai_CollisionAvoidanceObstacleTimeHorizon   = self.NavObstHorizon,
        ai_CollisionAvoidanceEnableRadiusIncrement = 1,
        ai_ExtraAvoidanceRadius                    = self.NavObstExtra,
        ai_MinActorDynamicObstacleAvoidanceRadius  = self.NavObstMinAct,
        -- the path, not just the steering: bend the route round dynamic obstacles and let a
        -- blocked one be replanned
        ai_AdjustPathsAroundDynamicObstacles       = 1,
        ai_MovementSystemPathReplanningEnabled     = 1,
    }
end

-- Split out because it is the one write here that changes how a FIGHT behaves, not just
-- how someone walks; NavObstWants stays the set that is always safe to arm.
function mercenaries:NavObstWantsAll()
    local w = self:NavObstWants()
    if self.NavObstOrcaInBattle then w.wh_ai_DisableORCAInBattle = 0 end
    return w
end

-- The per-agent half, through the engine's own AI script interface (the Lua global `AI`,
-- 265 live functions - see docs/walls-and-sieges.md). Two calls per man:
--   SetAdjustPath                     - let HIS path bend round dynamic obstacles
--   SetCollisionAvoidanceRadiusIncrement - give HIM a margin the global cvar cannot
-- Everyone the collision layer already enumerates, which is every NPC within SolidRegion
-- of the player plus the whole company - so enemies and raiders get it too, not just ours.
function mercenaries:NavObstAgentPass(on)
    if not (self.NavObstAgents and type(AI) == "table") then return 0 end
    local inc = on and (tonumber(self.NavObstAgentInc) or 0) or 0
    local n = 0
    local list = {}
    pcall(function() list = self:SolidCandidates() or {} end)
    for _, c in ipairs(list) do
        local id = c.ent and c.ent.id
        if id then
            if type(AI.SetAdjustPath) == "function" then
                pcall(function() AI.SetAdjustPath(id, on and 1 or 0) end)
            end
            if type(AI.SetCollisionAvoidanceRadiusIncrement) == "function" then
                pcall(function() AI.SetCollisionAvoidanceRadiusIncrement(id, inc) end)
            end
            self.NavObstTouched[c.key] = on or nil
            n = n + 1
        end
    end
    return n
end

function mercenaries:NavObstArm(on, why)
    if on == self.NavObstArmed then return end
    local wants = self:NavObstWantsAll()
    if on then
        local saved = {}
        for name in pairs(wants) do
            local v
            pcall(function() v = System.GetCVar(name) end)
            saved[name] = v
        end
        self.NavObstSaved = saved
        for name, v in pairs(wants) do pcall(function() System.SetCVar(name, v) end) end
        obstSay(string.format("armed (%s): walls are collision-avoidance obstacles", tostring(why)))
    else
        for name, v in pairs(self.NavObstSaved or {}) do
            if v ~= nil then pcall(function() System.SetCVar(name, v) end) end
        end
        self.NavObstSaved = nil
        obstSay(string.format("disarmed (%s)", tostring(why)))
    end
    self.NavObstArmed = on
end

-- Near a wall of ours? Reuses the wall segment list the mod's own A* cuts against.
function mercenaries:NavObstNearWall()
    if not self.NavWallSegments then return false end
    local segs, box
    pcall(function() segs, box = self:NavWallSegments() end)
    if not segs or #segs == 0 then return false end
    local p
    pcall(function() p = player and player:GetWorldPos() end)
    if not p then return false end
    local pad = self.NavObstGate or 140.0
    if box then
        if p.x < box.minx - pad or p.x > box.maxx + pad
        or p.y < box.miny - pad or p.y > box.maxy + pad then return false end
    end
    return true
end


-- ==== one obstacle per stretch of wall, not one per plank ====
-- Obstacle registration is PER ENTITY: `sub_2FF685C` walks all the physics parts of one
-- entity and merges them into a single footprint, then registers that. So a palisade built
-- as forty 2.75 m props is forty independent obstacles for the solver to weigh against each
-- other, with a numeric gap between each pair that a velocity can be threaded through - and
-- the shape it registers is the entity's physics OBB flattened to floor height, so short
-- boxes in a row do not join up into a wall.
--
-- One invisible collider spanning each STRAIGHT STRETCH of the run fixes both: a single
-- continuous footprint, and far fewer candidates. The visible palisade props are untouched;
-- this only adds the thing the solver actually reasons about. Same recipe the camp house
-- uses for its walls - mercenaries_Prop + a crate mesh + DrawSlot(0,0), which keeps the
-- physics and drops the render.
-- Superseded: the wall SEGMENTS are rigid now, so they register their own true
-- geometry and a stretched stand-in is both unnecessary and less accurate (a crate
-- scaled 13.6x measured ~6.5 m of physics for an intended 8 m). Kept for walls made
-- of meshes that cannot be physicalised rigid; merc_navobst_blockers 1 re-enables.
-- OFF. These invisible resting-rigid blockers never demonstrably improved NPC navigation, and
-- they cost three real bugs: they were left standing after a camp was torn down (nothing called
-- NavObstBlockerClear outside a rebuild), and their footprint is both short and OFFSET - measured
-- in game at ~6.5 m of physics for an intended 8 m, displaced ~0.9 m, because the crate mesh's
-- pivot is not its centre. NPCs ignore rigid bodies (ac_disableLivingVsRigidCollisions = 1) but
-- the PLAYER does not, so all they reliably did was put invisible collision a metre off the wall.
-- merc_navobst_blockers 1 re-enables them; they need a correctly-centred collider first.
mercenaries.NavObstBlockerOn    = false
mercenaries.NavObstBlockerModel = "objects/manmade/common_furniture/crates/crate_low_a.cgf"
mercenaries.NavObstBlockerH     = 3.0    -- how tall it stands, metres
mercenaries.NavObstBlockerW     = 0.8    -- how thick across the wall line, metres
mercenaries.NavObstBlockerTurn  = 8      -- degrees; a bend sharper than this ends a stretch
-- Shortest chunk we would LIKE, metres. The crate measures about 0.59 m along its length, so
-- a whole 30 m stretch in one piece means a 50x non-uniform scale, and the camp house tiles
-- its crates rather than stretching one - which reads as its author having found the limit.
-- Keep the scaling modest: a crate stretched 13.6x measured only ~6.5 m of physics for an
-- intended 8 m, so a shorter blocker is a more honest one.
mercenaries.NavObstBlockerMax   = 4.0
-- ...but the engine's obstacle registry is ONE GLOBAL POOL OF 32 SLOTS (sub_2FF6618 pushes
-- into a hard-capped ring), shared with every other obstacle in the world. Spending a dozen
-- of them on one palisade would evict other things and risk our own being evicted. So the
-- chunk length is chosen from this budget instead: long walls get longer chunks rather than
-- more of them.
mercenaries.NavObstBlockerBudget = 8
-- THE reason any of this works at all. The obstacle candidate gather asks the physics world
-- for ent_rigid | ent_sleeping_rigid (query flags 0x50006 in sub_2F52A5C); ent_static is NOT
-- in the mask. A PE_STATIC wall is therefore never a candidate, and the engine never even
-- reads bUsedAsDynamicObstacle on it - which is why tuning avoidance changed nothing. So the
-- blocker is physicalised RIGID and put to rest: a sleeping rigid body IS in the mask.
-- The visible palisade stays static; a forty-piece rigid palisade would be shovable.
mercenaries.NavObstBlockerRigid = true
mercenaries.NavObstBlockerMass  = 25000      -- heavy enough that nothing shifts it
mercenaries.NavObstBlockerEnts  = {}
mercenaries.NavObstBlockerPoses = {}         -- id -> intended {x,y,z,yaw}, to catch drift
mercenaries.NavObstBlockerDims  = nil    -- the crate's own size at scale 1, measured once

-- Measure the blocker mesh once by spawning one and asking it. Guessing a mesh's size is
-- how you get a collider that is either a stub or a hundred metres long.
function mercenaries:NavObstBlockerMeasure()
    if self.NavObstBlockerDims then return self.NavObstBlockerDims end
    local p
    pcall(function() p = player and player:GetWorldPos() end)
    if not p then return nil end
    local e
    pcall(function()
        e = System.SpawnEntity({
            class = "mercenaries_Prop",
            name = "MercNavObstMeasure_" .. tostring(math.random(100000, 999999)),
            position = { x = p.x, y = p.y, z = p.z - 500 },
            properties = { object_Model = self.NavObstBlockerModel, bMissionCritical = false,
                           bSaved_by_game = false, bSerialize = false },
        })
    end)
    if not e then return nil end
    local mn, mx
    pcall(function() mn, mx = e:GetLocalBBox() end)
    pcall(function() System.RemoveEntity(e.id) end)
    if not (mn and mx) then return nil end
    local d = { x = math.max(0.01, mx.x - mn.x),
                y = math.max(0.01, mx.y - mn.y),
                z = math.max(0.01, mx.z - mn.z),
                -- where the mesh's bottom sits relative to its own origin, so the blocker
                -- can be stood ON the ground: sub_300CB98 rejects an obstacle that does not
                -- stick up far enough above the floor, or that floats above it
                minz = mn.z }
    self.NavObstBlockerDims = d
    obstSay(string.format("blocker mesh measures %.2f x %.2f x %.2f m at scale 1", d.x, d.y, d.z))
    return d
end

function mercenaries:NavObstBlockerClear()
    local n = 0
    for _, id in ipairs(self.NavObstBlockerEnts or {}) do
        pcall(function() System.RemoveEntity(id); n = n + 1 end)
    end
    self.NavObstBlockerEnts = {}
    self.NavObstBlockerPoses = {}
    self._navObstCentreSaid = nil
    return n
end

-- A rigid body can be nudged, and an invisible one drifting out of the wall line would be a
-- silent bug. Put any that moved back where it belongs.
function mercenaries:NavObstBlockerHold()
    local moved = 0
    for _, id in ipairs(self.NavObstBlockerEnts or {}) do
        local want = self.NavObstBlockerPoses and self.NavObstBlockerPoses[id]
        if want then
            local e
            pcall(function() e = System.GetEntity(id) end)
            if e then
                local q
                pcall(function() q = e:GetWorldPos() end)
                if q and ((q.x - want.x) ^ 2 + (q.y - want.y) ^ 2 + (q.z - want.z) ^ 2) > 0.0625 then
                    pcall(function() e:SetWorldPos({ x = want.x, y = want.y, z = want.z }) end)
                    pcall(function() e:SetAngles({ x = 0, y = 0, z = want.yaw }) end)
                    moved = moved + 1
                end
            end
        end
    end
    return moved
end

-- Consecutive points of a run that carry on in roughly the same direction, returned as
-- {ax, ay, bx, by} stretches.
function mercenaries:NavObstStretches()
    local out = {}
    local lim = math.cos(math.rad(tonumber(self.NavObstBlockerTurn) or 8))
    for _, r in ipairs(self:WallAllRuns() or {}) do
        local m = r.pts or {}
        local n = #m
        if n >= 2 then
            local last = n
            if r.closed then last = n + 1 end
            local sx, sy = m[1].x, m[1].y
            local px, py = m[1].x, m[1].y
            local dx, dy
            for i = 2, last do
                local q = m[(i - 1) % n + 1]
                local ex, ey = q.x - px, q.y - py
                local el = math.sqrt(ex * ex + ey * ey)
                if el > 0.01 then
                    local ux, uy = ex / el, ey / el
                    if dx and (dx * ux + dy * uy) < lim then
                        table.insert(out, { ax = sx, ay = sy, bx = px, by = py })
                        sx, sy = px, py
                    end
                    dx, dy = ux, uy
                    px, py = q.x, q.y
                end
            end
            if (px - sx) ^ 2 + (py - sy) ^ 2 > 0.04 then
                table.insert(out, { ax = sx, ay = sy, bx = px, by = py })
            end
        end
    end
    return out
end

function mercenaries:NavObstBlockersBuild()
    self:NavObstBlockerClear()
    if not self.NavObstBlockerOn then obstSay("blockers are off"); return 0 end
    local d = self:NavObstBlockerMeasure()
    if not d then obstSay("could not measure the blocker mesh - no blockers built"); return 0 end
    local stretches = self:NavObstStretches()
    if #stretches == 0 then return 0 end

    -- One chunk length for the whole camp, sized so the total never exceeds the budget.
    local total = 0
    for _, st in ipairs(stretches) do
        total = total + math.sqrt((st.bx - st.ax) ^ 2 + (st.by - st.ay) ^ 2)
    end
    local budget = math.max(1, math.floor(tonumber(self.NavObstBlockerBudget) or 8))
    -- every stretch costs at least one blocker, so the budget left for LENGTH is what
    -- remains after each stretch has taken its one
    local chunkLen = math.max(tonumber(self.NavObstBlockerMax) or 8.0, total / budget)
    self._navObstChunkLen = chunkLen

    local pz
    pcall(function() pz = player and player:GetWorldPos().z end)
    local made = 0
    for _, st in ipairs(stretches) do
        local ex, ey = st.bx - st.ax, st.by - st.ay
        local slen = math.sqrt(ex * ex + ey * ey)
        local chunks = math.max(1, math.ceil(total / math.max(1.0, self._navObstChunkLen or 8.0)))
        local ux, uy = (slen > 0.001) and ex / slen or 1, (slen > 0.001) and ey / slen or 0
        local len = slen / chunks
        for ci = 0, chunks - 1 do
          if slen > 0.5 then
            local c0 = (ci + 0.5) * len
            local mx, my = st.ax + ux * c0, st.ay + uy * c0
            local yaw = math.atan2(ey, ex)
            local z = pz or 0
            -- the ground under the middle of the stretch, not the player's feet
            pcall(function()
                local hit = self.CampSnapToGround and self:CampSnapToGround({ x = mx, y = my, z = (pz or 0) + 40 })
                if hit and hit.z then z = hit.z end
            end)
            local zs = (tonumber(self.NavObstBlockerH) or 3.0) / d.z
            z = z - (d.minz or 0) * zs           -- stand it on the ground, not through it
            local e
            pcall(function()
                e = System.SpawnEntity({
                    class = "mercenaries_Prop",
                    name = "MercNavBlocker_" .. tostring(math.random(100000, 999999)),
                    position = { x = mx, y = my, z = z },
                    orientation = { x = 0, y = 0, z = yaw },
                    scale = { x = len / d.x,
                              y = (tonumber(self.NavObstBlockerW) or 0.8) / d.y,
                              z = zs },
                    properties = { object_Model = self.NavObstBlockerModel,
                                   bMissionCritical = false, bSaved_by_game = false,
                                   bSerialize = false,
                                   AI = { bUsedAsDynamicObstacle = 1 },
                                   -- bRigidBody is the only switch that matters here:
                                   -- EntityCommon.PhysicalizeRigid picks PE_RIGID on it and
                                   -- PE_STATIC otherwise, and only a rigid body is in the
                                   -- obstacle query's mask. bResting anything but 0 leaves it
                                   -- asleep, which is ent_sleeping_rigid - also in the mask.
                                   -- (bRigidBodyActive is an entity field, not a property:
                                   -- putting it here does nothing.)
                                   Physics = self.NavObstBlockerRigid and {
                                       bPhysicalize = true,
                                       bRigidBody = true,
                                       bResting = 1,
                                       Mass = self.NavObstBlockerMass or 25000,
                                       Density = -1,
                                       bPushableByPlayers = false,
                                   } or nil },
                })
            end)
            if e then
                pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw }) end)
                -- Centre it on the wall line. The crate's pivot is not its middle, so a
                -- blocker spawned "at" the midpoint straddles it unevenly - the physics probe
                -- found geometry 3.3 m one way and none the other. Read where the box
                -- actually landed and shift it. Must precede DrawSlot, which zeroes the bbox.
                local bmn, bmx
                pcall(function() bmn, bmx = e:GetWorldBBox() end)
                local fx, fy, fz = mx, my, z
                if bmn and bmx and (bmx.x - bmn.x) > 0.01 then
                    local ccx = (bmn.x + bmx.x) / 2
                    local ccy = (bmn.y + bmx.y) / 2
                    fx = mx + (mx - ccx)
                    fy = my + (my - ccy)
                    -- and stand its true bottom on the ground rather than trusting the pivot
                    fz = z + (z - bmn.z)
                    pcall(function() e:SetWorldPos({ x = fx, y = fy, z = fz }) end)
                    if not self._navObstCentreSaid then
                        self._navObstCentreSaid = true
                        obstSay(string.format("blocker pivot offset corrected by (%.2f, %.2f, %.2f) m",
                                              fx - mx, fy - my, fz - z))
                    end
                end
                pcall(function() e:DrawSlot(0, 0) end)     -- invisible, still physical
                table.insert(self.NavObstBlockerEnts, e.id)
                self.NavObstBlockerPoses[e.id] = { x = fx, y = fy, z = fz, yaw = yaw }
                made = made + 1
            end
          end
        end
    end
    obstSay(string.format("%d blocker(s) over %d stretch(es), %.0f m of wall, %.1f m each (budget %d of the engine's 32 obstacle slots)",
                          made, #stretches, total, chunkLen, budget))
    if made > budget then
        obstSay(string.format("NOTE: %d blockers exceeds the %d budget - long or many-cornered walls cost one slot per corner",
                              made, budget))
    end
    return made
end

function mercenaries:NavObstBlockersSet(line)
    local n = tonumber(tostring(line or ""):match("%-?%d+") or "")
    self.NavObstBlockerOn = (n ~= 0)
    obstSay("blockers " .. (self.NavObstBlockerOn and "on" or "off"))
    self:NavObstBlockersBuild()
end

function mercenaries:NavObstTickDrive()
    local mode = self.NavObstMode or 0
    local want = false
    if mode == 2 then
        want = true
    elseif mode == 1 then
        pcall(function() want = self:NavObstNearWall() end)
    end
    pcall(function() self:NavObstArm(want, want and "at the walls" or "away from the walls") end)
    -- Agents come and go inside an armed region, so the pass repeats rather than running
    -- once on arming; a man spawned between ticks would otherwise never get his margin.
    if want then
        pcall(function() self:NavObstAgentPass(true) end)
        pcall(function() self:NavObstBlockerHold() end)
    elseif next(self.NavObstTouched or {}) then
        pcall(function() self:NavObstAgentPass(false) end)
        self.NavObstTouched = {}
    end
    self:ChainArm("NavObstTick", self.NavObstTickMs or 2000)
end
mercenaries:ChainDef("NavObstTick", "NavObstTickDrive")

-- Cvars are global and a level load re-applies the level's own cvar context over them; the
-- chain died with the level too.
function mercenaries:NavObstOnLoad()
    self.NavObstArmed = false
    self.NavObstSaved = nil
    local saved
    pcall(function() saved = self:LoadString("MercNavObst") end)
    if saved == "0" then self.NavObstMode = 0 elseif saved == "1" then self.NavObstMode = 1
    elseif saved == "2" then self.NavObstMode = 2 end
    local prof
    pcall(function() prof = self:LoadString("MercNavObstProfile") end)
    if prof and self.NavObstProfiles[prof] then self:NavObstApplyProfile(prof) end
    obstSay(string.format("mode %d; walls carry the obstacle property from spawn", self.NavObstMode or 0))
    self:ChainArm("NavObstTick", 3000)
    -- A wall built before this fix has no property and never will until it is re-spawned.
    -- Say so once, on the load, rather than leaving it to be discovered.
    Script.SetTimerForFunction(9000, "mercenaries.NavObstReportTimer")
end

-- A camp saved before this change has wall segments with no obstacle property, and the
-- property is only read when an entity physicalises - so they can never acquire it while
-- they stand. Re-spawn them once, here, rather than leaving a player to find out from a
-- doc that they must type a dev command. WallRebuild is what the camp does for itself
-- whenever an upgrade is bought, so this is a path the walls already take.
function mercenaries.NavObstReportTimer()
    local m = mercenaries
    pcall(function() m:NavObstStatus() end)
    local flagged, n = 0, 0
    pcall(function() flagged, n = m:NavObstCheckWalls() end)
    pcall(function() m:NavObstBlockersBuild() end)
    if n > 0 and flagged < n and m.WallRebuild and not m._navObstHealed then
        m._navObstHealed = true
        obstSay("re-spawning the walls once so they carry the obstacle property")
        pcall(function() m:WallRebuild() end)
    end
end

-- ==== HOW HARD TO PUSH IT ====
--
-- Every cvar in NavObstWants is GLOBAL: armed, they change collision avoidance for every
-- agent in the level, not only near our walls. That is a fixed cost that appears the moment
-- ONE wall stands and does not grow with the wall's length - which is the shape of the lag
-- reported at the palisade.
--
-- The numbers that matter, and what the game ships:
--   ai_CollisionAvoidanceRange              5.0 -> 12.0   ~5.8x the area each agent scans
--   ai_CollisionAvoidanceTargetCutoffRange  3.0 -> 0.5    agents keep avoiding right up to
--   ai_CollisionAvoidancePathEndCutoffRange 1.3 -> 0.5      their destination instead of
--                                                           dropping out of it
--   ai_CollisionAvoidanceObstacleTimeHorizon 1.5 -> 3.0   twice the lookahead
--   wh_ai_DisableORCAInBattle                 1 -> 0      ORCA back on in fights, which the
--                                                           game disables for performance
--
-- ORCA is superlinear in the number of neighbours in range, so the first of those is the
-- expensive one. "tame" keeps the behaviour - walls are still obstacles agents steer round -
-- at values near the shipped ones.
mercenaries.NavObstProfiles = {
    wide = { cut = 0.5, endcut = 0.5, range = 12.0, horizon = 3.0,
             extra = 0.6, minact = 1.0, inc = 0.8, orca = true },
    tame = { cut = 2.0, endcut = 1.0, range = 6.5,  horizon = 2.0,
             extra = 0.3, minact = 0.6, inc = 0.4, orca = false },
}

function mercenaries:NavObstApplyProfile(name)
    local pr = self.NavObstProfiles[name]
    if not pr then return false end
    self.NavObstProfile    = name
    self.NavObstTargetCut  = pr.cut
    self.NavObstPathEndCut = pr.endcut
    self.NavObstRange      = pr.range
    self.NavObstHorizon    = pr.horizon
    self.NavObstExtra      = pr.extra
    self.NavObstMinAct     = pr.minact
    self.NavObstAgentInc   = pr.inc
    self.NavObstOrcaInBattle = pr.orca
    -- re-arm so the new values are actually written, if it is armed right now
    if self.NavObstArmed then
        self:NavObstArm(false, "profile change")
        self:NavObstArm(true, "profile " .. name)
    end
    return true
end

function mercenaries:NavObstProfileSet(line)
    local v = tostring(line or ""):gsub("[\"']", ""):gsub("%s", "")
    if not self.NavObstProfiles[v] then
        obstSay("merc_navobst_profile <wide|tame> - currently "
                .. tostring(self.NavObstProfile or "wide"))
        obstSay("   wide = as before; tame = the same behaviour at near-shipping cost")
        return
    end
    self:NavObstApplyProfile(v)
    pcall(function() self:SaveString("MercNavObstProfile", v) end)
    obstSay("profile " .. v .. " (remembered)")
end

System.AddCCommand("merc_navobst_profile", "mercenaries:NavObstProfileSet('%line')",
                   "How hard the wall obstacle system pushes the AI: wide | tame")

function mercenaries:NavObstSet(line)
    local v = tonumber(tostring(line or ""):match("%-?%d+"))
    if v == nil or v < 0 or v > 2 then
        obstSay("merc_navobst <0|1|2>   0 = off, 1 = near our walls (default), 2 = always")
        return self:NavObstStatus()
    end
    self.NavObstMode = v
    pcall(function() self:SaveString("MercNavObst", tostring(v)) end)
    obstSay("mode " .. v .. " (remembered)")
    self:NavObstTickDrive()
end

-- Does a standing wall segment actually carry the property? Reads it back off a live
-- entity, so "the walls in this save predate the fix" is answerable rather than guessed.
function mercenaries:NavObstCheckWalls()
    local ids = self.WallSegEnts or {}
    local n, flagged = 0, 0
    for _, id in ipairs(ids) do
        local e
        pcall(function() e = System.GetEntity(id) end)
        if e then
            n = n + 1
            local v
            pcall(function() v = e.Properties and e.Properties.AI and e.Properties.AI.bUsedAsDynamicObstacle end)
            if v == 1 or v == true then flagged = flagged + 1 end
        end
    end
    obstSay(string.format("%d of %d standing wall segment(s) carry bUsedAsDynamicObstacle", flagged, n))
    if n > 0 and flagged < n then
        obstSay("segments built before this fix: merc_wall_rebuild (or rebuild the camp) to re-spawn them")
    end
    return flagged, n
end

function mercenaries:NavObstStatus()
    local live = {}
    for name in pairs(self:NavObstWantsAll()) do
        local v
        pcall(function() v = System.GetCVar(name) end)
        live[#live + 1] = string.format("%s=%s", name:gsub("^wh_ai_", ""):gsub("^ai_", ""), tostring(v))
    end
    obstSay(string.format("mode %d, armed=%s, near a wall=%s",
        self.NavObstMode or 0, tostring(self.NavObstArmed), tostring(self:NavObstNearWall())))
    obstSay("   " .. table.concat(live, "  "))
    self:NavObstCheckWalls()
end

-- Draw what the engine thinks the obstacles are, for one agent by name. This is the engine's
-- own debug view, so it answers "is my wall in the set at all" directly.
function mercenaries:NavObstDebugDraw(line)
    local name = tostring(line or ""):match("%S+")
    if not name then
        pcall(function() System.SetCVar("ai_DebugDrawCollisionAvoidanceObstaclesForAgent", 0) end)
        obstSay("obstacle debug draw off")
        return
    end
    pcall(function() System.SetCVar("ai_DebugDrawCollisionAvoidanceAgentName", name) end)
    pcall(function() System.SetCVar("ai_DebugDrawCollisionAvoidanceObstaclesForAgent", 1) end)
    obstSay("drawing collision-avoidance obstacles for '" .. name .. "'")
end

-- ==== does it change anything? ====
-- The wall lab's test NPC is unusable (its walk order silently fails to take - see
-- docs/walls-and-sieges.md), so measure on the company, who follow the player with no
-- behaviour-tree interrupt in the way. Walk ALONG a wall of yours for two 15 s stretches:
-- the first with the obstacles off, the second with them on. What is reported is how close
-- the men let themselves get to the timber. If the avoidance layer is doing anything, the
-- clearance goes up.
mercenaries.NavObstTestSecs   = 15
mercenaries.NavObstTestTickMs = 500

local function pointSegDist2(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local L2 = dx * dx + dy * dy
    local t = 0
    if L2 > 1e-6 then
        t = ((px - ax) * dx + (py - ay) * dy) / L2
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
    end
    local cx, cy = ax + dx * t, ay + dy * t
    return (px - cx) ^ 2 + (py - cy) ^ 2
end

-- Closest any man came to the wall line this tick, and how many were near enough to count.
function mercenaries:NavObstSampleClearance(T)
    local segs
    pcall(function() segs = self:NavWallSegments() end)
    if not segs or #segs == 0 then return end
    for _, ent in pairs(self.ActiveMercs or {}) do
        local p
        pcall(function() p = ent:GetWorldPos() end)
        if p then
            local best
            for i = 1, #segs do
                local s = segs[i]
                local d2 = pointSegDist2(p.x, p.y, s.ax, s.ay, s.bx, s.by)
                if (not best) or d2 < best then best = d2 end
            end
            -- Only men actually working near the wall are evidence; a man 30 m away is not.
            if best and best < 400 then
                local d = math.sqrt(best)
                T.sum = T.sum + d
                T.n = T.n + 1
                if (not T.min) or d < T.min then T.min = d end
            end
        end
    end
end

function mercenaries:NavObstTestStart()
    if self.NavObstTest then obstSay("self test already running"); return end
    local segs
    pcall(function() segs = self:NavWallSegments() end)
    if not segs or #segs == 0 then obstSay("no wall of ours here - build one first"); return end
    local men = 0
    for _ in pairs(self.ActiveMercs or {}) do men = men + 1 end
    if men == 0 then obstSay("no company to measure - hire some men first"); return end

    self.NavObstTest = { phase = "off", t = 0, sum = 0, n = 0, min = nil, result = {}, wasMode = self.NavObstMode }
    self.NavObstMode = 0
    self:NavObstArm(false, "self test control")
    obstSay(string.format("self test: %d man/men. WALK ALONG THE WALL for %d seconds - control, obstacles OFF",
        men, self.NavObstTestSecs))
    self:ChainArm("NavObstTest", self.NavObstTestTickMs or 500)
end

function mercenaries:NavObstTestDrive()
    local T = self.NavObstTest
    if not T then return end
    T.t = T.t + (self.NavObstTestTickMs or 500) / 1000
    pcall(function() self:NavObstSampleClearance(T) end)
    if T.t >= (self.NavObstTestSecs or 15) then
        local mean = (T.n > 0) and (T.sum / T.n) or 0
        T.result[T.phase] = { mean = mean, min = T.min or 0, n = T.n }
        obstSay(string.format("   %-3s  %d sample(s), mean clearance %.2fm, closest %.2fm",
            T.phase, T.n, mean, T.min or 0))
        if T.phase == "off" then
            T.phase, T.t, T.sum, T.n, T.min = "on", 0, 0, 0, nil
            self.NavObstMode = 2
            self:NavObstArm(true, "self test armed")
            obstSay("self test: obstacles ON - walk the same stretch again for " ..
                tostring(self.NavObstTestSecs) .. " seconds")
        else
            local a, b = T.result.off, T.result.on
            obstSay("--- self test ---")
            obstSay(string.format("   off  mean %.2fm closest %.2fm   |   on  mean %.2fm closest %.2fm",
                a.mean, a.min, b.mean, b.min))
            if a.n < 8 or b.n < 8 then
                obstSay("   INCONCLUSIVE: too few samples near the wall - walk closer to it next time")
            elseif b.mean > a.mean + 0.25 or b.min > a.min + 0.25 then
                obstSay("   they keep further off the timber with obstacles on: the layer is doing something")
            else
                obstSay("   no difference - the walls are not reaching the avoidance set; merc_navobst_draw <npc>")
            end
            self.NavObstMode = T.wasMode
            self.NavObstTest = nil
            self:NavObstTickDrive()
            return
        end
    end
    self:ChainArm("NavObstTest", self.NavObstTestTickMs or 500)
end
mercenaries:ChainDef("NavObstTest", "NavObstTestDrive")

System.AddCCommand("merc_navobst_selftest", "mercenaries:NavObstTestStart()",
    "Walk along a wall for 30s: measures how close the company lets itself get, obstacles off then on")
System.AddCCommand("merc_navobst", "mercenaries:NavObstSet('%line')",
    "NPCs steer around our walls (collision-avoidance obstacles): 0 off, 1 near our walls (default), 2 always")
System.AddCCommand("merc_navobst_blockers", "mercenaries:NavObstBlockersSet('%line')",
                   "One merged invisible obstacle per straight stretch of wall: 0 off, 1 on")
System.AddCCommand("merc_navobst_status", "mercenaries:NavObstStatus()",
    "Obstacle state, the cvars, and whether the standing walls carry the property")
System.AddCCommand("merc_navobst_draw", "mercenaries:NavObstDebugDraw('%line')",
    "Draw the engine's collision-avoidance obstacles for one agent: merc_navobst_draw <npcName> (no arg = off)")
