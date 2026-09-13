-- Probing the engine's AI script interface.
--
-- CScriptBind_AI registers 261 functions into the Lua global `AI` (constructed by
-- CAISystem, and the base game's own scripts call it, so it is live in retail). This mod
-- has never used any of them. Two answer the two halves of the wall problem directly:
-- SetCollisionAvoidanceRadiusIncrement is the PER-AGENT version of ai_ExtraAvoidanceRadius,
-- and SetForcedNavigation posts an AI event carrying a direction, which is a movement-layer
-- override rather than another order for combat steering to outvote.
--
-- This file only measures. CanMoveStraightToPoint is the engine's own walkability test:
-- ask it whether an NPC can walk from where he stands to a point on the far side of our
-- palisade and the answer IS the bug, in one boolean, in the engine's own words.
--
-- merc_ai_probe runs the lot; it also runs once at load so a plain play session leaves the
-- answers in kcd.log.

local function aiLog(msg) System.LogAlways("[MercAI] " .. tostring(msg)) end

-- Everything worth knowing about, in the order it matters. `args` is what the binary's
-- argument check demands, so a call that throws is a signature error and not a dead bind.
mercenaries.AIProbeWanted = {
    { n = "CanMoveStraightToPoint",              args = 2 },
    { n = "SetCollisionAvoidanceRadiusIncrement",args = 2 },
    { n = "SetForcedNavigation",                 args = 2 },
    { n = "SetPFBlockerRadius",                  args = 3 },
    { n = "CreateTempGenericShapeBox",           args = 4 },
    { n = "IntersectsForbidden",                 args = 2 },
    { n = "IsPointInsideGenericShape",           args = 2 },
    { n = "GetEnclosingGenericShapeOfType",      args = 2 },
    { n = "SetPointListToFollow",                args = 2 },
    { n = "SetAdjustPath",                       args = 2 },
    { n = "GetNavigationType",                   args = 1 },
    { n = "GoTo",                                args = 2 },
    { n = "RequestToStopMovement",               args = 1 },
    { n = "SetPFProperties",                     args = 2 },
    { n = "ChangeMovementAbility",               args = 3 },
    { n = "SetSpeed",                            args = 2 },
}

-- Is the table there at all, and which of the ones we care about are real functions?
function mercenaries:AIProbeTable()
    if type(AI) ~= "table" then
        aiLog("the AI table is NOT present in this Lua state - everything below is moot")
        return false
    end
    local n = 0
    for _ in pairs(AI) do n = n + 1 end
    aiLog("AI table present with " .. n .. " entries")

    local missing = {}
    for _, w in ipairs(self.AIProbeWanted) do
        if type(AI[w.n]) ~= "function" then table.insert(missing, w.n) end
    end
    if #missing == 0 then
        aiLog("all " .. #self.AIProbeWanted .. " candidate binds are real functions")
    else
        aiLog("MISSING: " .. table.concat(missing, ", "))
    end
    return true
end

-- The nearest live NPC we may poke. Our own men first (they are ours to experiment on);
-- anything else within range otherwise.
function mercenaries:AIProbeSubject()
    local best, bestD
    local p
    pcall(function() p = player:GetWorldPos() end)
    if not p then return nil end
    for _, e in pairs(self.ActiveMercs or {}) do
        local q
        pcall(function() q = e:GetWorldPos() end)
        if q then
            local d = (q.x - p.x) ^ 2 + (q.y - p.y) ^ 2
            if not bestD or d < bestD then best, bestD = e, d end
        end
    end
    return best, bestD and math.sqrt(bestD) or nil
end

-- The whole question, asked of the engine. For each wall segment: stand off it on one
-- side, ask whether the NPC can walk straight to a point on the OTHER side. `true` means
-- the engine's own walkability test cannot see our wall, which is the bug stated by the
-- code that is supposed to know.
--
-- The control is the same query to a point two metres in front of him, which must come
-- back true, and to a point far underground, which must not. Without those a wall of
-- `false` answers would be indistinguishable from a bind that always says no.
function mercenaries:AIProbeWalk(maxSegs)
    if type(AI) ~= "table" or type(AI.CanMoveStraightToPoint) ~= "function" then
        aiLog("no CanMoveStraightToPoint - skipping the walkability probe")
        return
    end
    local ent, dist = self:AIProbeSubject()
    if not ent then aiLog("no merc to ask (need a hired man nearby)"); return end
    local id = ent.id
    local me
    pcall(function() me = ent:GetWorldPos() end)
    if not me then aiLog("subject has no position"); return end
    aiLog(string.format("subject %s at %.1f m from the player",
                        tostring(ent:GetName() or "?"), dist or -1))

    local function ask(what, pt)
        local ok, res = pcall(function() return AI.CanMoveStraightToPoint(id, pt) end)
        if not ok then
            aiLog("   " .. what .. ": CALL FAILED (" .. tostring(res) .. ")")
        else
            aiLog("   " .. what .. ": " .. tostring(res))
        end
        return ok, res
    end

    -- controls first, so the readings below mean something
    ask("control, 2 m in front of him", { x = me.x + 2, y = me.y, z = me.z })
    ask("control, 40 m underground", { x = me.x, y = me.y, z = me.z - 40 })

    local segs
    pcall(function() segs = self:NavWallSegments() end)
    if not segs or #segs == 0 then
        aiLog("no wall segments in this save - load a camp that has a palisade for the real reading")
        return
    end
    aiLog(#segs .. " wall segment(s); asking across the first " .. math.min(#segs, maxSegs or 4))

    for i = 1, math.min(#segs, maxSegs or 4) do
        local s = segs[i]
        local mx, my = (s.ax + s.bx) / 2, (s.ay + s.by) / 2
        local dx, dy = s.bx - s.ax, s.by - s.ay
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0.01 then
            -- unit normal to the segment: the way across it
            local nx, ny = -dy / len, dx / len
            local off = 3.0
            ask(string.format("segment %d, across the wall at (%.1f, %.1f)", i, mx, my),
                { x = mx + nx * off, y = my + ny * off, z = me.z })
            ask(string.format("segment %d, the other way across", i),
                { x = mx - nx * off, y = my - ny * off, z = me.z })
            if type(AI.IntersectsForbidden) == "function" then
                local ok, res = pcall(function()
                    return AI.IntersectsForbidden({ x = mx + nx * off, y = my + ny * off, z = me.z },
                                                  { x = mx - nx * off, y = my - ny * off, z = me.z })
                end)
                aiLog(string.format("   segment %d, IntersectsForbidden: %s", i,
                                    ok and tostring(res) or ("CALL FAILED " .. tostring(res))))
            end
        end
    end
end

-- Do the two per-agent levers accept a call at all? Nothing is left armed: the avoidance
-- increment goes back to 0 and the forced direction to the zero vector, which is how that
-- event is cleared.
function mercenaries:AIProbeLevers()
    if type(AI) ~= "table" then return end
    local ent = self:AIProbeSubject()
    if not ent then aiLog("no subject for the lever probe"); return end
    local id = ent.id

    local function try(name, fn)
        if type(AI[name]) ~= "function" then aiLog("   " .. name .. ": absent"); return end
        local ok, err = pcall(fn)
        aiLog("   " .. name .. ": " .. (ok and "accepted" or ("threw - " .. tostring(err))))
    end

    aiLog("per-agent levers:")
    try("SetCollisionAvoidanceRadiusIncrement",
        function() AI.SetCollisionAvoidanceRadiusIncrement(id, 1.5) end)
    try("SetForcedNavigation", function() AI.SetForcedNavigation(id, { x = 0, y = 0, z = 0 }) end)
    try("GetNavigationType", function() aiLog("      navtype = " .. tostring(AI.GetNavigationType(id))) end)
    -- put the avoidance increment back
    pcall(function() AI.SetCollisionAvoidanceRadiusIncrement(id, 0.0) end)
end

-- A runtime AI shape over the first wall segment. Whether the pathfinder honours one is
-- the open question; whether we can MAKE one is answered here.
function mercenaries:AIProbeShape()
    if type(AI) ~= "table" or type(AI.CreateTempGenericShapeBox) ~= "function" then
        aiLog("no CreateTempGenericShapeBox"); return
    end
    local segs
    pcall(function() segs = self:NavWallSegments() end)
    local c
    if segs and segs[1] then
        c = { x = (segs[1].ax + segs[1].bx) / 2, y = (segs[1].ay + segs[1].by) / 2, z = 0 }
        pcall(function() local p = player:GetWorldPos(); c.z = p.z end)
    else
        pcall(function() c = player:GetWorldPos() end)
    end
    if not c then return end
    -- (centre, half size, height, type) as the binary reads them; every type we can think
    -- of is worth one call, since the shape only matters if some type blocks navigation.
    for _, t in ipairs({ 0, 1, 2, 3 }) do
        local ok, res = pcall(function()
            return AI.CreateTempGenericShapeBox(c, 3.0, 4.0, t)
        end)
        aiLog(string.format("   CreateTempGenericShapeBox type %d: %s", t,
                            ok and tostring(res) or ("threw - " .. tostring(res))))
    end
end


-- The avoidance family, read live. Defaults decoded from the binary are worth checking
-- against the running game: the two cutoff ranges below switch avoidance OFF as an agent
-- closes on its target, which is the shape of "it barely works".
mercenaries.AIProbeCvars = {
    "ai_EnableORCA",
    "ai_CollisionAvoidanceRange",
    "ai_CollisionAvoidanceTargetCutoffRange",
    "ai_CollisionAvoidancePathEndCutoffRange",
    "ai_CollisionAvoidanceSmartObjectCutoffRange",
    "ai_CollisionAvoidanceAgentExtraFat",
    "ai_CollisionAvoidanceMinSpeed",
    "ai_CollisionAvoidanceAgentTimeHorizon",
    "ai_CollisionAvoidanceObstacleTimeHorizon",
    "ai_CollisionAvoidanceUpdateVelocities",
    "ai_CollisionAvoidanceEnableRadiusIncrement",
    "ai_CollisionAvoidanceClampVelocitiesWithNavigationMesh",
    "wh_ai_CollisionAvoidanceCandidatesMode",
    "wh_ai_CollisionAvoidanceCircularQueryRadius",
    "wh_ai_ObstaclesAddToCollisionAvoidance",
    "ai_ExtraAvoidanceRadius",
    "ai_ExtraActorAvoidanceRadius",
    "ai_MinActorDynamicObstacleAvoidanceRadius",
    "ai_AdjustPathsAroundDynamicObstacles",
    "ai_MovementSystemPathReplanningEnabled",
    "ai_ExtraForbiddenRadiusDuringBeautification",
    "ac_disableLivingVsRigidCollisions",
    -- the navmesh half: this one's help text is "Enables automatic rebuilding of nav mesh
    -- when a change in level is detected", and it is hardcoded OFF at registration
    "wh_ai_AutomaticMNMRebuild",
    "wh_ai_OverrideMNM",
    "wh_ai_CryNavigationSystemEnabled",
    "ai_MNMAllowDynamicRegenInEditor",
    "wh_ai_AdvancedNavMeshSpanMerge",
    "wh_ai_TileCacheAsBuildBuffer",
    "ai_NavGenThreadJobs",
    "ai_NavigationSystemMT",
    "wh_ai_NavMeshInUserData",
    "wh_ai_FindPathUseObstacles",
    "wh_ai_FindPathObstaclesMultiplier",
    -- Combat locomotion runs its OWN weighted steering solver and does not consume ORCA's
    -- output - but that solver has an obstacle term of its own. If these answer, they are the
    -- only lever that lives inside the combat pipeline.
    "WH_AI_CombatMove_ObstacleWeight",
    "WH_AI_CombatMove_M1ObstacleWeight",
    "WH_AI_CombatMove_M2MyWeight",
    "WH_AI_CombatMove_CheckRadius",
    "WH_AI_CombatMove_HistoryWeight",
    "WH_AI_CombatMove_ForeignTargetRepulsion",
    "WH_AI_CombatDirectionFactor",
    "WH_Move_OffMeshStuckDetectionMultiplier",
    "wh_ai_StuckDetectionAllowAnyMovement",
    "wh_ai_MovementTeleportWhenStuck",
    -- "Is ORCA disabled during battle game context" - if this ships on, avoidance is
    -- switched off in combat outright, which is a data-reachable half of the combat problem
    "wh_ai_DisableORCAInBattle",
    -- "Use non circle shapes in collision avoidance" - a long wall is not a circle
    "wh_ai_NonCircleCollisionAvoidance",
    "wh_ai_CollisionAvoidanceOutputHalfspace",
    "ai_ObstacleSizeThreshold",
    "ai_CollisionAvoidanceRadiusIncrementIncreaseRate",
    "ai_CollisionAvoidanceRadiusIncrementDecreaseRate",
    "ai_PathfinderGroupMatesAvoidanceRadius",
}

function mercenaries:AIProbeCvarDump()
    aiLog("live avoidance cvars:")
    for _, n in ipairs(self.AIProbeCvars) do
        local v = "<absent>"
        pcall(function() local g = System.GetCVar(n); if g ~= nil then v = tostring(g) end end)
        aiLog(string.format("   %-56s = %s", n, v))
    end
end


-- Does arming actually take, and does disarming put it back? The module writes global
-- cvars, so "it restored what it found" is worth proving rather than assuming.
function mercenaries:AIProbeArmCheck()
    if not self.NavObstWantsAll then aiLog("navobst not loaded"); return end
    local names = {}
    for k in pairs(self:NavObstWantsAll()) do table.insert(names, k) end
    table.sort(names)
    local function snap()
        local o = {}
        for _, n in ipairs(names) do
            pcall(function() o[n] = tostring(System.GetCVar(n)) end)
        end
        return o
    end
    local before = snap()
    pcall(function() self:NavObstArm(true, "probe") end)
    local armed = snap()
    pcall(function() self:NavObstArm(false, "probe") end)
    local after = snap()
    aiLog("arm check (shipped -> armed -> restored):")
    local bad = 0
    for _, n in ipairs(names) do
        local ok = (before[n] == after[n])
        if not ok then bad = bad + 1 end
        aiLog(string.format("   %-46s %s -> %s -> %s%s", n, tostring(before[n]),
                            tostring(armed[n]), tostring(after[n]), ok and "" or "   NOT RESTORED"))
    end
    aiLog(bad == 0 and "   all restored cleanly" or ("   " .. bad .. " cvar(s) NOT restored"))
end

function mercenaries:AIProbe()
    aiLog("==== AI script interface probe ====")
    pcall(function() self:AIProbeCvarDump() end)
    if not self:AIProbeTable() then return end
    pcall(function() self:AIProbeLevers() end)
    pcall(function() self:AIProbeWalk(4) end)
    pcall(function() self:AIProbeShape() end)
    if self.AIProbeMNMTest then pcall(function() self:AIProbeMNM() end) end
    pcall(function() self:AIProbeArmCheck() end)
    aiLog("==== probe done ====")
end

-- Once at load, so an ordinary play session leaves the answers in the log. Late enough
-- that the camp and the men are up.
function mercenaries.AIProbeOnLoadTimer()
    pcall(function() mercenaries:AIProbe() end)
end

-- OFF by default. The probe is forty lines of log, and its arm check writes global cvars and
-- puts them back - neither belongs in an ordinary play session. `merc_ai_probe` on demand.
mercenaries.AIProbeOnLoadRun = false


-- Off by default; the headless harness turns it on for a run. It was shipping TRUE, which
-- put a wall audit 25 s into every player's load - the comment was right and the value wrong.
mercenaries.AIProbeCrossOnLoad = false

-- The camp census is a diagnostic too: a 30 s chain doing a 60 m sphere query, and seven
-- multi-line dumps in an ordinary session. merc_camp_census runs it on demand instead.
mercenaries.AIProbeCensusOnLoad = false

function mercenaries.CampCensusStart()
    -- one slow chain, armed on load; the tick itself only does work near the camp
    pcall(function() mercenaries:ChainArm("CampCensusTick", 30000) end)
end

function mercenaries.AIProbeCrossOnLoadTimer()
    -- passive only: this runs in the user's own play session, so it must not spawn anything
    pcall(function() mercenaries:AIProbeWallAudit() end)
    -- TEMPORARY (my own secondary-monitor run only; disarm before the user plays)
    if mercenaries.AIProbeSpawnTest then
        pcall(function() mercenaries:AIProbeWallRigidCheck() end)
    end
end

function mercenaries.AIProbeCrossOnLoadTimerOld()
    -- The crossing test needs a mover, and AI.GoTo turned out to be inert for BT-driven NPCs
    -- (accepted by 9 men, moved 0 of them), so it measures nothing headlessly. What a headless
    -- run CAN answer is whether the blocker's physics is the right shape.
    pcall(function() mercenaries:AIProbeCvarDump() end)
    pcall(function() mercenaries:AIProbeExtentCheck() end)
end

function mercenaries:AIProbeOnLoad()
    if self.AIProbeCensusOnLoad then pcall(function() mercenaries.CampCensusStart() end) end
    if self.AIProbeCrossOnLoad then
        -- late enough that the company is spawned and following
        Script.SetTimerForFunction(25000, "mercenaries.AIProbeCrossOnLoadTimer")
    end
    if not self.AIProbeOnLoadRun then return end
    Script.SetTimerForFunction(12000, "mercenaries.AIProbeOnLoadTimer")
end


-- ==== the navmesh experiment ====
-- The Recast tile generator, its background thread and both Generate paths are all real
-- code in retail (only the two rebuild CONSOLE COMMANDS are no-op stubs). The switch that
-- is supposed to drive them from a world change is `wh_ai_AutomaticMNMRebuild`, and it
-- ships off. So: turn it on, put a wall in the world, and watch the engine's own log. It
-- prints "Building navigation:" from the tile generator and "NavMesh generation background
-- thread started" from the thread, so the answer arrives in its words, not ours.
mercenaries.AIProbeMNMTest = false     -- settled: no rebuild happens, see docs/walls-and-sieges.md
mercenaries.AIProbeMNMEnts = {}

function mercenaries:AIProbeMNMSpawnWall(n, dist)
    local p, ang
    pcall(function() p = player:GetWorldPos() end)
    pcall(function() ang = player:GetAngles() end)
    if not p then aiLog("no player position"); return 0 end
    local yaw = (ang and ang.z) or 0
    -- a straight run laid across the player's facing, a little way off
    local fx, fy = math.cos(yaw), math.sin(yaw)
    local rx, ry = -fy, fx
    local model = "objects/manmade/structures/defensive/walls/palisade/palisade_wall_a_v3.cgf"
    local made = 0
    for i = 1, (n or 8) do
        local t = (i - (n or 8) / 2 - 0.5) * 2.75
        local pos = { x = p.x + fx * (dist or 10) + rx * t,
                      y = p.y + fy * (dist or 10) + ry * t,
                      z = p.z - 3.0 }
        local e
        pcall(function()
            e = System.SpawnEntity({
                class = "mercenaries_Prop",
                name = "MercMNMTest_" .. i .. "_" .. tostring(math.random(100000, 999999)),
                position = pos,
                properties = { object_Model = model, bMissionCritical = false,
                               bSaved_by_game = false, bSerialize = false,
                               AI = { bUsedAsDynamicObstacle = 1 } },
            })
        end)
        if e then
            pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw + math.pi / 2 }) end)
            table.insert(self.AIProbeMNMEnts, e.id)
            made = made + 1
        end
    end
    aiLog(string.format("spawned %d test wall segment(s) %.0f m ahead", made, dist or 10))
    return made
end

function mercenaries:AIProbeMNMClear()
    local n = 0
    for _, id in ipairs(self.AIProbeMNMEnts or {}) do
        pcall(function() System.RemoveEntity(id); n = n + 1 end)
    end
    self.AIProbeMNMEnts = {}
    aiLog("removed " .. n .. " test wall segment(s)")
end

function mercenaries:AIProbeMNM()
    aiLog("---- navmesh rebuild experiment ----")
    local before = "?"
    pcall(function() before = tostring(System.GetCVar("wh_ai_AutomaticMNMRebuild")) end)
    aiLog("wh_ai_AutomaticMNMRebuild was " .. before .. "; setting it to 1")
    pcall(function() System.SetCVar("wh_ai_AutomaticMNMRebuild", 1) end)
    local after = "?"
    pcall(function() after = tostring(System.GetCVar("wh_ai_AutomaticMNMRebuild")) end)
    aiLog("wh_ai_AutomaticMNMRebuild now reads " .. after
          .. (after == before and "  (THE WRITE DID NOT TAKE)" or ""))
    -- The tile generator belongs to CryEngine's own NavigationSystem, and that ships with
    -- its update switched OFF (wh_ai_CryNavigationSystemEnabled = 0) because Warhorse's own
    -- Recast path takes over (wh_ai_OverrideMNM = 1). Turning the rebuild flag on while the
    -- system that would act on it is asleep explains a silent first attempt, so try both.
    local cn = "?"
    pcall(function() cn = tostring(System.GetCVar("wh_ai_CryNavigationSystemEnabled")) end)
    aiLog("wh_ai_CryNavigationSystemEnabled was " .. cn .. "; setting it to 1")
    pcall(function() System.SetCVar("wh_ai_CryNavigationSystemEnabled", 1) end)
    pcall(function() aiLog("   it now reads " .. tostring(System.GetCVar("wh_ai_CryNavigationSystemEnabled"))) end)
    self:AIProbeMNMSpawnWall(8, 10)
    aiLog("watch kcd.log for 'Building navigation' / 'NavMesh generation' over the next few seconds")
end

mercenaries:DevCommand("merc_mnm_test", "mercenaries:AIProbeMNM()",
                       "Enable wh_ai_AutomaticMNMRebuild, spawn a test wall, watch for a navmesh rebuild")
mercenaries:DevCommand("merc_mnm_clear", "mercenaries:AIProbeMNMClear()",
                       "Remove the test wall segments")


-- ==== the measurement that was missing ====
-- Every reading so far is mechanism: which cvar, which function, which flag. None of it says
-- what a man actually DOES when a wall stands between him and where he wants to be. This puts
-- a wall between the company and the player, moves the player to the far side, and samples
-- where everyone goes.
--
-- The verdict per man is one of four, and they are four different bugs:
--   THROUGH  crossed the line inside the wall's span - no collision, no avoidance
--   AROUND   crossed outside the span - he went round the end, which is the goal
--   PRESSED  never crossed, and got within a metre and a half - the reported symptom
--   IDLE     never crossed and never came near - he was not trying, so the run says nothing
mercenaries.AIProbeCrossEnts   = {}
mercenaries.AIProbeCrossLine   = nil
mercenaries.AIProbeCrossState  = nil
mercenaries.AIProbeCrossSink   = -3.0      -- what mercenaries_wall.lua actually uses
mercenaries.AIProbeCrossSegs   = 10
mercenaries.AIProbeCrossAhead  = 14.0
mercenaries.AIProbeCrossBeyond = 22.0
mercenaries.AIProbeCrossTicks  = 70        -- x 500 ms

function mercenaries:AIProbeCrossClear()
    for _, id in ipairs(self.AIProbeCrossEnts or {}) do
        pcall(function() System.RemoveEntity(id) end)
    end
    self.AIProbeCrossEnts = {}
end

-- Who to test on: everyone the collision layer already enumerates (every NPC within
-- SolidRegion of the player, by class), not just our own men - the complaint is about
-- raiders and passers-by too, and ActiveMercs can be empty.
function mercenaries:AIProbeCrossSubjects(nearSide, L, maxD)
    local out = {}
    local list = {}
    pcall(function() list = self:SolidCandidates() or {} end)
    for _, c in ipairs(list) do
        local q = c.pos
        if q then
            local dx, dy = q.x - L.cx, q.y - L.cy
            local fwd = dx * L.fx + dy * L.fy
            local lat = dx * L.rx + dy * L.ry
            -- on the near side of the wall, roughly in front of it, and not miles away
            if fwd < -1.0 and fwd > -(maxD or 45) and math.abs(lat) < L.half + 6 then
                table.insert(out, c)
            end
        end
    end
    return out
end

function mercenaries:AIProbeCrossStart(sink)
    self:AIProbeCrossClear()
    local p, ang
    pcall(function() p = player:GetWorldPos() end)
    pcall(function() ang = player:GetAngles() end)
    if not p then aiLog("cross test: no player position"); return end
    local yaw = (ang and ang.z) or 0
    local fx, fy = math.cos(yaw), math.sin(yaw)      -- forward
    local rx, ry = -fy, fx                           -- along the wall
    local segLen, n = 2.75, self.AIProbeCrossSegs
    local half = segLen * n / 2
    local cx = p.x + fx * self.AIProbeCrossAhead
    local cy = p.y + fy * self.AIProbeCrossAhead
    local dz = sink or self.AIProbeCrossSink
    local z = p.z + dz

    local model = "objects/manmade/structures/defensive/walls/palisade/palisade_wall_a_v3.cgf"
    local made = 0
    for i = 1, n do
        local t = (i - n / 2 - 0.5) * segLen
        local e
        pcall(function()
            e = System.SpawnEntity({
                class = "mercenaries_Prop",
                name = "MercCrossWall_" .. i .. "_" .. tostring(i * 7919),
                position = { x = cx + rx * t, y = cy + ry * t, z = z },
                properties = { object_Model = model, bMissionCritical = false,
                               bSaved_by_game = false, bSerialize = false,
                               AI = { bUsedAsDynamicObstacle = 1 } },
            })
        end)
        if e then
            pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw + math.pi / 2 }) end)
            table.insert(self.AIProbeCrossEnts, e.id)
            made = made + 1
        end
    end

    local L = { cx = cx, cy = cy, fx = fx, fy = fy, rx = rx, ry = ry, half = half }
    self.AIProbeCrossLine = L
    self.AIProbeCrossState = { tick = 0, men = {} }
    aiLog(string.format("cross test: %d segment(s), %.1f m wide, z offset %.1f m, %.0f m ahead",
                        made, segLen * n, dz, self.AIProbeCrossAhead))

    -- The destination: straight through the middle of the wall and out the far side. Anyone
    -- who reaches it without crossing the span went round an end, which is the whole question.
    local gx = cx + fx * 12.0
    local gy = cy + fy * 12.0
    local goal = { x = gx, y = gy, z = p.z }

    local subs = self:AIProbeCrossSubjects(true, L, 45)
    local sent, refused = 0, 0
    for _, c in ipairs(subs) do
        local k
        pcall(function() k = tostring(c.ent:GetName() or "?") end)
        if k and not self.AIProbeCrossState.men[k] then
            local ok = false
            if type(AI) == "table" and type(AI.GoTo) == "function" then
                ok = pcall(function() AI.GoTo(c.ent.id, goal) end)
            end
            if ok then sent = sent + 1 else refused = refused + 1 end
            self.AIProbeCrossState.men[k] = { minAbs = 9999, maxFwd = -9999, crossedIn = false,
                                              crossedOut = false, moved = 0,
                                              x0 = c.pos.x, y0 = c.pos.y, ent = c.ent, sent = ok }
        end
    end
    aiLog(string.format("cross test: %d subject(s) on the near side, AI.GoTo accepted by %d, threw for %d",
                        sent + refused, sent, refused))
    if (sent + refused) == 0 then
        aiLog("cross test: NOBODY TO WATCH - the run proves nothing")
        return
    end
    aiLog(string.format("cross test: goal is %.0f m beyond the wall, straight through it", 12.0))
    Script.SetTimerForFunction(500, "mercenaries.AIProbeCrossTick")
end

function mercenaries.AIProbeCrossTick()
    local m = mercenaries
    local st, L = m.AIProbeCrossState, m.AIProbeCrossLine
    if not (st and L) then return end
    st.tick = st.tick + 1
    for _, rec in pairs(st.men) do
        local q
        pcall(function() q = rec.ent:GetWorldPos() end)
        if q then
            local dx, dy = q.x - L.cx, q.y - L.cy
            local fwd = dx * L.fx + dy * L.fy      -- positive is past the wall
            local lat = dx * L.rx + dy * L.ry      -- along the wall
            local inSpan = math.abs(lat) <= L.half
            if inSpan and math.abs(fwd) < rec.minAbs then rec.minAbs = math.abs(fwd) end
            if fwd > rec.maxFwd then rec.maxFwd = fwd end
            if fwd > 1.0 then
                if inSpan then rec.crossedIn = true else rec.crossedOut = true end
            end
            local d = math.sqrt((q.x - rec.x0) ^ 2 + (q.y - rec.y0) ^ 2)
            if d > rec.moved then rec.moved = d end
        end
    end
    if st.tick < (m.AIProbeCrossTicks or 70) then
        Script.SetTimerForFunction(500, "mercenaries.AIProbeCrossTick")
    else
        m:AIProbeCrossReport()
    end
end

function mercenaries:AIProbeCrossReport()
    local st = self.AIProbeCrossState
    if not st then return end
    aiLog("==== cross test result ====")
    local tally = { THROUGH = 0, AROUND = 0, PRESSED = 0, IDLE = 0 }
    for k, r in pairs(st.men) do
        local verdict
        if r.crossedIn then verdict = "THROUGH"
        elseif r.crossedOut then verdict = "AROUND"
        elseif r.minAbs < 1.5 then verdict = "PRESSED"
        else verdict = "IDLE" end
        tally[verdict] = tally[verdict] + 1
        aiLog(string.format("   %-9s closest %.2f m, furthest %.1f m past, walked %.1f m  %s",
                            verdict, r.minAbs, r.maxFwd, r.moved, k))
    end
    aiLog(string.format("   THROUGH=%d  AROUND=%d  PRESSED=%d  IDLE=%d",
                        tally.THROUGH, tally.AROUND, tally.PRESSED, tally.IDLE))
    if (tally.THROUGH + tally.AROUND + tally.PRESSED) == 0 then
        aiLog("   nobody engaged the wall - this run measured nothing")
    end
    aiLog("==== cross test done ====")
    self.AIProbeCrossState = nil
end


-- ==== does a resting rigid blocker stay where it is put? ====
-- The obstacle candidate query asks the physics world for ent_rigid | ent_sleeping_rigid and
-- NOT ent_static, so the blocker has to be a rigid body to be seen at all. The risk that
-- buys is a wall-length box that can be nudged, sink, or topple. This spawns one exactly the
-- way mercenaries_navobst.lua does, then reads its pose back twice.
mercenaries.AIProbeBlockerEnt = nil
mercenaries.AIProbeBlockerWant = nil

function mercenaries:AIProbeBlockerCheck()
    aiLog("---- rigid blocker spawn check ----")
    local d
    pcall(function() d = self:NavObstBlockerMeasure() end)
    if not d then aiLog("could not measure the blocker mesh"); return end
    aiLog(string.format("mesh %.2f x %.2f x %.2f m, base at z%+.2f", d.x, d.y, d.z, d.minz or 0))

    local p, ang
    pcall(function() p = player:GetWorldPos() end)
    pcall(function() ang = player:GetAngles() end)
    if not p then return end
    local yaw = (ang and ang.z) or 0
    local fx, fy = math.cos(yaw), math.sin(yaw)
    local len = 8.0
    local zs = (tonumber(self.NavObstBlockerH) or 3.0) / d.z
    local pos = { x = p.x + fx * 10, y = p.y + fy * 10, z = p.z - (d.minz or 0) * zs }

    local e
    pcall(function()
        e = System.SpawnEntity({
            class = "mercenaries_Prop",
            name = "MercBlockerCheck_1",
            position = pos,
            orientation = { x = 0, y = 0, z = yaw + math.pi / 2 },
            scale = { x = len / d.x,
                      y = (tonumber(self.NavObstBlockerW) or 0.8) / d.y,
                      z = zs },
            properties = { object_Model = self.NavObstBlockerModel,
                           bMissionCritical = false, bSaved_by_game = false, bSerialize = false,
                           AI = { bUsedAsDynamicObstacle = 1 },
                           Physics = { bPhysicalize = true, bRigidBody = true,
                                       bResting = 1,
                                       Mass = self.NavObstBlockerMass or 25000,
                                       Density = -1, bPushableByPlayers = false } },
        })
    end)
    if not e then aiLog("SPAWN FAILED - the rigid blocker could not be created"); return end
    pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw + math.pi / 2 }) end)
    pcall(function() e:DrawSlot(0, 0) end)
    self.AIProbeBlockerEnt = e
    self.AIProbeBlockerWant = pos
    aiLog(string.format("spawned rigid blocker, scale %.1f x %.2f x %.1f at (%.1f, %.1f, %.1f)",
                        len / d.x, (tonumber(self.NavObstBlockerW) or 0.8) / d.y, zs,
                        pos.x, pos.y, pos.z))

    -- Did it actually physicalise RIGID? EntityCommon picks PE_STATIC unless
    -- Physics.bRigidBody is true, and a PE_STATIC reads mass 0. A control prop spawned the
    -- ordinary way gives the baseline to compare against, so the number means something.
    local ctrl
    pcall(function()
        ctrl = System.SpawnEntity({
            class = "mercenaries_Prop",
            name = "MercBlockerCheck_static",
            position = { x = pos.x, y = pos.y, z = pos.z - 60 },
            properties = { object_Model = self.NavObstBlockerModel, bMissionCritical = false,
                           bSaved_by_game = false, bSerialize = false },
        })
    end)
    local function mass(ent, what)
        if not ent then aiLog("   " .. what .. ": not spawned"); return end
        local m
        pcall(function() m = ent:GetMass() end)
        aiLog(string.format("   %-22s mass = %s", what, tostring(m)))
    end
    mass(e, "rigid blocker")
    mass(ctrl, "control (PE_STATIC)")
    aiLog("   a rigid body reads its Mass; a PE_STATIC reads 0 - if both read the same, the")
    aiLog("   Physics table did not take and the blocker is still invisible to the obstacle query")
    if ctrl then pcall(function() System.RemoveEntity(ctrl.id) end) end
    Script.SetTimerForFunction(6000, "mercenaries.AIProbeBlockerRead1")
end

local function blockerRead(label, nextFn, ms)
    local m = mercenaries
    local e, want = m.AIProbeBlockerEnt, m.AIProbeBlockerWant
    if not (e and want) then return end
    local q
    pcall(function() q = e:GetWorldPos() end)
    if not q then aiLog(label .. ": entity is gone"); return end
    local drift = math.sqrt((q.x - want.x) ^ 2 + (q.y - want.y) ^ 2 + (q.z - want.z) ^ 2)
    aiLog(string.format("%s: at (%.2f, %.2f, %.2f), drift %.3f m%s",
                        label, q.x, q.y, q.z, drift,
                        drift > 0.25 and "   MOVED" or "   holding"))
    if nextFn then Script.SetTimerForFunction(ms or 8000, nextFn) end
end

function mercenaries.AIProbeBlockerRead1()
    blockerRead("after 6 s", "mercenaries.AIProbeBlockerRead2", 12000)
end

function mercenaries.AIProbeBlockerRead2()
    blockerRead("after 18 s", nil)
    local m = mercenaries
    if m.AIProbeBlockerEnt then
        pcall(function() System.RemoveEntity(m.AIProbeBlockerEnt.id) end)
        m.AIProbeBlockerEnt = nil
    end
    aiLog("---- rigid blocker check done ----")
end


-- ==== is the stretched blocker really 8 m of physics, or a crate pretending? ====
mercenaries.AIProbeExtentEnts = {}

local function physAt(pos, r)
    -- returns the list of physical entities overlapping a small box, whichever argument
    -- form this build's bind accepts
    local out
    pcall(function()
        out = System.GetPhysicalEntitiesInBox({ x = pos.x - r, y = pos.y - r, z = pos.z - r },
                                              { x = pos.x + r, y = pos.y + r, z = pos.z + r })
    end)
    if out == nil then
        pcall(function() out = System.GetPhysicalEntitiesInBox(pos, r) end)
    end
    return out
end

local function contains(list, id)
    if type(list) ~= "table" then return nil end
    for _, e in pairs(list) do
        local eid
        pcall(function() eid = e.id end)
        if eid == id then return true end
        if e == id then return true end
    end
    return false
end

function mercenaries:AIProbeExtentClear()
    for _, id in ipairs(self.AIProbeExtentEnts or {}) do
        pcall(function() System.RemoveEntity(id) end)
    end
    self.AIProbeExtentEnts = {}
end

function mercenaries:AIProbeExtentCheck()
    aiLog("---- blocker physics extent check ----")
    self:AIProbeExtentClear()
    local d
    pcall(function() d = self:NavObstBlockerMeasure() end)
    if not d then aiLog("cannot measure the blocker mesh"); return end

    local p, ang
    pcall(function() p = player:GetWorldPos() end)
    pcall(function() ang = player:GetAngles() end)
    if not p then return end
    local yaw = (ang and ang.z) or 0
    local fx, fy = math.cos(yaw), math.sin(yaw)
    local LEN = 8.0
    local zs = (tonumber(self.NavObstBlockerH) or 3.0) / d.z
    local ys = (tonumber(self.NavObstBlockerW) or 0.8) / d.y
    local xs = LEN / d.x

    -- two blockers, 25 m apart so their probes cannot see each other:
    --   A: the shipped non-uniform stretch
    --   B: a UNIFORM scale of the same long-axis factor, as the control
    local PAL = "objects/manmade/structures/defensive/walls/palisade/palisade_wall_a_v3.cgf"
    local cases = {
        { tag = "crate non-uniform x13.6", scale = { x = xs, y = ys, z = zs },       off = 12 },
        { tag = "crate non-uniform x4",    scale = { x = 4, y = ys, z = zs },        off = 34 },
        { tag = "palisade scale 1",        scale = { x = 1, y = 1, z = 1 },  off = 56, model = PAL },
        { tag = "palisade x3 on length",   scale = { x = 3, y = 1, z = 1 },  off = 78, model = PAL },
    }

    for ci, c in ipairs(cases) do
        local pos = { x = p.x + fx * c.off, y = p.y + fy * c.off,
                      z = p.z - (d.minz or 0) * (c.scale.z or 1) }
        local e
        pcall(function()
            e = System.SpawnEntity({
                class = "mercenaries_Prop",
                name = "MercExtent_" .. ci,
                position = pos,
                orientation = { x = 0, y = 0, z = yaw + math.pi / 2 },
                scale = c.scale,
                properties = { object_Model = c.model or self.NavObstBlockerModel,
                               bMissionCritical = false, bSaved_by_game = false,
                               bSerialize = false,
                               AI = { bUsedAsDynamicObstacle = 1 },
                               Physics = { bPhysicalize = true, bRigidBody = true,
                                           bResting = 1,
                                           Mass = self.NavObstBlockerMass or 25000,
                                           Density = -1, bPushableByPlayers = false } },
            })
        end)
        if not e then
            aiLog("   " .. c.tag .. ": SPAWN FAILED")
        else
            pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw + math.pi / 2 }) end)
            pcall(function() e:DrawSlot(0, 0) end)
            table.insert(self.AIProbeExtentEnts, e.id)

            aiLog(string.format("   %s  scale %.1f/%.2f/%.1f", c.tag,
                                c.scale.x, c.scale.y, c.scale.z))
            local mn, mx
            pcall(function() mn, mx = e:GetWorldBBox() end)
            if mn and mx then
                aiLog(string.format("      world bbox %.2f x %.2f x %.2f m",
                                    mx.x - mn.x, mx.y - mn.y, mx.z - mn.z))
            else
                aiLog("      world bbox unavailable")
            end
            local m
            pcall(function() m = e:GetMass() end)
            aiLog("      mass = " .. tostring(m))

            -- the long axis runs across the player's facing, i.e. along (-fy, fx)
            local ux, uy = -fy, fx
            for _, t in ipairs({ 0.0, 1.5, -1.5, 3.3, -3.3, 5.0, -5.0, 7.5, -7.5 }) do
                local probe = { x = pos.x + ux * t, y = pos.y + uy * t, z = pos.z + 1.0 }
                local list = physAt(probe, 0.5)
                local hit = contains(list, e.id)
                local n = (type(list) == "table") and #list or -1
                local what = "nothing there"
                if hit == true then what = "BLOCKER PRESENT" elseif hit == false then what = "absent" end
                aiLog(string.format("      probe %+5.1f m along the wall: %s   (%d physical entity/ies there)",
                                    t, what, n))
            end
        end
    end
    aiLog("   If 'non-uniform' is absent at +/-3.3 m but present at 0, its physics is only a")
    aiLog("   crate at the centre and the shipped blocker is the wrong shape.")
    Script.SetTimerForFunction(8000, "mercenaries.AIProbeExtentDone")
end

function mercenaries.AIProbeExtentDone()
    pcall(function() mercenaries:AIProbeExtentClear() end)
    System.LogAlways("[MercAI] ---- extent check done ----")
end


-- ==== did the shipped wall change take? ====
-- Spawns through mercenaries:WallSpawnSegment - the real path, not a copy - and reads the mass
-- back. PE_STATIC reads 0; a rigid body reads its mass. Then re-reads position, because a
-- palisade that drifts or falls over is worse than one NPCs ignore.
mercenaries.AIProbeSpawnTest = false  -- off: never spawn anything in the user's own session
mercenaries.AIProbeWallEnts = {}

function mercenaries:AIProbeWallRigidCheck()
    aiLog("---- wall segment rigid check ----")
    aiLog("WallRigid = " .. tostring(self.WallRigid) ..
          ", mass setting = " .. tostring(self.WallRigidMass))
    local p, ang
    pcall(function() p = player:GetWorldPos() end)
    pcall(function() ang = player:GetAngles() end)
    if not p then aiLog("no player position"); return end
    local yaw = (ang and ang.z) or 0
    local fx, fy = math.cos(yaw), math.sin(yaw)
    local rx, ry = -fy, fx

    local before = #(self.WallSegEnts or {})
    for i = 1, 3 do
        local t = (i - 2) * 2.75
        local pos = { x = p.x + fx * 10 + rx * t, y = p.y + fy * 10 + ry * t, z = p.z }
        pcall(function() self:WallSpawnSegment(pos, yaw + math.pi / 2) end)
    end
    local made = #(self.WallSegEnts or {}) - before
    aiLog("spawned " .. made .. " wall segment(s) through WallSpawnSegment")
    if made <= 0 then aiLog("NOTHING SPAWNED - the check proves nothing"); return end

    local n = 0
    for i = before + 1, #self.WallSegEnts do
        local id = self.WallSegEnts[i]
        local e
        pcall(function() e = System.GetEntity(id) end)
        if e then
            local m, q
            pcall(function() m = e:GetMass() end)
            pcall(function() q = e:GetWorldPos() end)
            n = n + 1
            table.insert(self.AIProbeWallEnts, { id = id, m = m, x = q and q.x, y = q and q.y, z = q and q.z })
            aiLog(string.format("   segment %d: mass = %s%s", n, tostring(m),
                                (tonumber(m) or 0) > 0 and "   RIGID - visible to the obstacle query"
                                                      or "   ZERO - still static, the change did NOT take"))
        end
    end
    Script.SetTimerForFunction(10000, "mercenaries.AIProbeWallRigidRecheck")
end

function mercenaries.AIProbeWallRigidRecheck()
    local m = mercenaries
    local moved, n = 0, 0
    for _, rec in ipairs(m.AIProbeWallEnts or {}) do
        local e, q
        pcall(function() e = System.GetEntity(rec.id) end)
        if e then
            pcall(function() q = e:GetWorldPos() end)
            if q and rec.x then
                n = n + 1
                local d = math.sqrt((q.x - rec.x) ^ 2 + (q.y - rec.y) ^ 2 + (q.z - rec.z) ^ 2)
                if d > 0.25 then moved = moved + 1 end
                System.LogAlways(string.format("[MercAI]    segment drift after 10 s: %.3f m%s",
                                               d, d > 0.25 and "   MOVED" or "   holding"))
            end
        end
    end
    System.LogAlways(string.format("[MercAI] %d of %d segment(s) drifted", moved, n))
    for _, rec in ipairs(m.AIProbeWallEnts or {}) do
        pcall(function() System.RemoveEntity(rec.id) end)
    end
    m.AIProbeWallEnts = {}
    System.LogAlways("[MercAI] ---- wall rigid check done ----")
end


-- ==== passive audit: read-only, safe to leave on ====
-- The one question left that only a real save can answer: are the standing wall segments
-- actually rigid bodies now? A PE_STATIC segment reads mass 0 and is invisible to the engine's
-- obstacle query (mask ent_rigid|ent_sleeping_rigid); a rigid one reads its mass and is not.
-- Nothing here spawns, moves or writes anything.
function mercenaries:AIProbeWallAudit()
    aiLog("==== wall audit ====")
    local ids = self.WallSegEnts or {}
    if #ids == 0 then
        aiLog("no wall segments standing - build or load a camp with a palisade for this reading")
    else
        local rigid, static, gone, sample = 0, 0, 0, nil
        for _, id in ipairs(ids) do
            local e
            pcall(function() e = System.GetEntity(id) end)
            if not e then
                gone = gone + 1
            else
                local m
                pcall(function() m = e:GetMass() end)
                if (tonumber(m) or 0) > 0 then rigid = rigid + 1 else static = static + 1 end
                sample = sample or m
            end
        end
        aiLog(string.format("%d wall segment(s): %d RIGID (obstacle-visible), %d static (invisible), %d missing",
                            #ids, rigid, static, gone))
        aiLog("   sample mass = " .. tostring(sample))
        if static > 0 and rigid == 0 then
            aiLog("   -> these predate the fix; merc_wall_rebuild respawns them rigid")
        end
    end

    -- the handful of values worth seeing next to that
    for _, n in ipairs({ "ac_disableLivingVsRigidCollisions",
                         "ai_CollisionAvoidanceTargetCutoffRange",
                         "ai_ExtraAvoidanceRadius",
                         "ai_MovementSystemPathReplanningEnabled",
                         "wh_ai_ObstaclesAddToCollisionAvoidance" }) do
        local v = "<absent>"
        pcall(function() local g = System.GetCVar(n); if g ~= nil then v = tostring(g) end end)
        aiLog(string.format("   %-42s = %s", n, v))
    end
    aiLog("==== wall audit done ====")
end


-- ==== camp census: what is actually standing there, and how big are our tables ====
-- Read-only. "Lag near camp, worse the longer it has stood" is an accumulation signature, so
-- count the things that could accumulate rather than guess. A number that climbs is the bug.
mercenaries.CensusEvery   = 60.0
mercenaries.CensusLast    = nil
mercenaries.CensusRadius  = 60.0
mercenaries.CensusPrefixes = {
    "MercWallSeg_", "MercWallDecor_", "MercWallCap_", "MercWallMark_", "MercWallGhost_",
    "MercTowerPart_", "MercTowerLadder_", "MercTowerCol_", "MercTowerProp_",
    "MercGateProp_", "MercNavBlocker_", "MercCampHouse_", "MercCamp",
}

local function tcount(t)
    local n = 0
    if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
    return n
end

function mercenaries:CampCensus(quiet)
    local c = self.CampCenter
    if not c then
        if not quiet then aiLog("camp census: no camp") end
        return
    end

    -- Entities standing near the camp, by name prefix. GetEntitiesInSphere is what the mod
    -- already uses elsewhere, so this adds no new engine surface.
    local ents
    pcall(function() ents = System.GetEntitiesInSphere(c, self.CensusRadius or 60.0) end)
    local byPrefix, total, unnamed = {}, 0, 0
    for _, e in pairs(ents or {}) do
        total = total + 1
        local n = ""
        pcall(function() n = e:GetName() or "" end)
        if n == "" then
            unnamed = unnamed + 1
        else
            for _, p in ipairs(self.CensusPrefixes) do
                if string.sub(n, 1, string.len(p)) == p then
                    byPrefix[p] = (byPrefix[p] or 0) + 1
                    break
                end
            end
        end
    end

    aiLog(string.format("==== camp census (%.0f m) : %d entities in the sphere ====",
                        self.CensusRadius or 60.0, total))
    local names = {}
    for p in pairs(byPrefix) do names[#names + 1] = p end
    table.sort(names, function(a, b) return (byPrefix[a] or 0) > (byPrefix[b] or 0) end)
    for _, p in ipairs(names) do
        aiLog(string.format("   %-20s %d", p, byPrefix[p]))
    end

    -- The mod's own bookkeeping. A table that only grows is the other half of the suspect list.
    aiLog(string.format("   tables: WallSegEnts=%d TowerStations=%d CampEntities=%d ActiveMercs=%d",
                        tcount(self.WallSegEnts), tcount(self.TowerStations),
                        tcount(self.CampEntities), tcount(self.ActiveMercs)))
    aiLog(string.format("   tables: ForcedTargetOf=%d NavGoto=%d LivePatrols=%d NavObstBlockers=%d",
                        tcount(self.ForcedTargetOf), tcount(self.NavGoto),
                        tcount(self.LivePatrols), tcount(self.NavObstBlockerEnts)))
    aiLog(string.format("   tables: Gates=%d TowerParts=%d DevCommands=%d",
                        tcount(self.Gates), tcount(self.TowerParts), tcount(self.DevCommands)))
    aiLog("==== census done ====")
end

-- Driven by the mod's generation-named chain rather than a raw self-rearming timer: a second
-- load must not be able to leave a second chain running. This mod once shipped a save carrying
-- 5,899 pending timers, and a diagnostic has no business adding to that.
function mercenaries:CampCensusDrive()
    local t = 0
    pcall(function() t = System.GetCurrTime() or 0 end)
    local near = false
    pcall(function()
        local p, c = player:GetWorldPos(), self.CampCenter
        if p and c then
            local dx, dy = p.x - c.x, p.y - c.y
            near = (dx * dx + dy * dy) < (120 * 120)
        end
    end)
    if near and (not self.CensusLast or (t - self.CensusLast) >= (self.CensusEvery or 60.0)) then
        self.CensusLast = t
        pcall(function() self:CampCensus(true) end)
    end
    self:ChainArm("CampCensusTick", 20000)
end
mercenaries:ChainDef("CampCensusTick", "CampCensusDrive")

mercenaries:DevCommand("merc_camp_census", "mercenaries:CampCensus()",
                       "Count what is standing around the camp and how big the mod's tables are")

mercenaries:DevCommand("merc_wall_audit", "mercenaries:AIProbeWallAudit()",
                       "Report whether the standing wall segments are rigid (obstacle-visible) or static")

mercenaries:DevCommand("merc_wall_rigid_check", "mercenaries:AIProbeWallRigidCheck()",
                       "Spawn a few wall segments and report whether they physicalised rigid")

mercenaries:DevCommand("merc_extent_check", "mercenaries:AIProbeExtentCheck()",
                       "Ask the physics world whether a stretched blocker really is wall-length")

mercenaries:DevCommand("merc_blocker_check", "mercenaries:AIProbeBlockerCheck()",
                       "Spawn one resting rigid blocker and see whether it stays put")

mercenaries:DevCommand("merc_crosstest", "mercenaries:AIProbeCrossStart()",
                       "Put a wall between the company and the player, move the player across it, measure what they do")
mercenaries:DevCommand("merc_crosstest_flat", "mercenaries:AIProbeCrossStart(0)",
                       "Same, but with the wall sitting ON the ground instead of sunk 3 m")
mercenaries:DevCommand("merc_crosstest_clear", "mercenaries:AIProbeCrossClear()",
                       "Remove the cross-test wall")

mercenaries:DevCommand("merc_ai_probe", "mercenaries:AIProbe()",
                       "Probe the engine AI script interface and the wall walkability")
mercenaries:DevCommand("merc_ai_walk", "mercenaries:AIProbeWalk(8)",
                       "Ask the engine whether an NPC can walk straight through our walls")
