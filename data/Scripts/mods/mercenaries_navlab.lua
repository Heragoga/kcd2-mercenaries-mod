-- Wall-blocking lab: does ANY engine setting make an NPC respect a spawned wall?
--
-- One command runs a matrix. Each case builds a wall across the player's facing, drops a
-- test NPC behind it, orders him to a point on the far side, samples where he goes, and
-- says whether he went THROUGH the wall, AROUND its end, or never got past it.
--
-- The order is deliberately given through `testnpc_walk` (one long engine Move to a fixed
-- point). Nothing in mercenaries_navmesh.lua touches that path, so a pass is the ENGINE
-- avoiding the wall and not our own steering flattering the result.
--
-- Nothing here is shipped behaviour. It arms global AI cvars, and it puts every one of
-- them back when the run ends or is stopped. See docs/walls-and-sieges.md.

local function labSay(s) System.LogAlways("[NavLab] " .. s) end

-- Geometry, all measured along the player's facing at the moment the run starts.
mercenaries.LabWallAt   = 15.0    -- wall this far in front of the start
mercenaries.LabWallHalf = 8.0     -- half its width, so going round is a real detour
mercenaries.LabGoalAt   = 45.0    -- the point he is ordered to, well past the wall
mercenaries.LabSettle   = 2.5     -- seconds for the wall to physicalise before he is sent
mercenaries.LabWalk     = 40.0    -- seconds he is given; a BLOCKED case runs it out, and a kicked one needs the slack
mercenaries.LabGap      = 1.5     -- seconds between cases
mercenaries.LabTickMs   = 250
mercenaries.LabRepeats  = 3       -- trials per case; one is not a measurement
mercenaries.LabMovedMin = 2.0     -- less ground than this covered = the walker never started
-- The walk is handed over by a BT interrupt (testnpc_scheduler.xml), and the hand-off
-- does not always take: `Function_crime_getMrkev` is wrapped in SuppressFailure, so a
-- failed one leaves AddInterrupt with an empty host, the log line still prints, and the
-- man stands on his spawn point. Whole runs have been voided by it. So a walker who has
-- not moved is re-ordered rather than written off.
mercenaries.LabKickAfter  = 4.0   -- seconds of standing still before re-issuing the order
mercenaries.LabKickMax    = 4     -- give-ups after this many

-- Every case is: a wall build, some cvars, and optionally an AI bind called on each
-- segment once it stands. `all` is the union of the cvar cases, so a pass there with
-- failures above it means the effect needs more than one of them.
local ALL = {
    wh_ai_ObstaclesAddToCollisionAvoidance = 1,
    wh_ai_FindPathUseObstacles             = 1,
    wh_ai_AutomaticMNMRebuild              = 1,
    ai_AdjustPathsAroundDynamicObstacles   = 1,
    ai_MovementSystemPathReplanningEnabled = 1,
}

-- THE BROAD SWEEP, kept because its result is the reason for the focused set below.
-- Every case walked straight through except three, and the three that did not are all
-- collision AVOIDANCE, not pathfinding - which fits what the navmesh actually is (baked
-- offline into recast.pak, so a runtime spawn can never appear in it).
mercenaries.LabCasesBroad = {
    { n = "baseline",      build = "prop"  },
    { n = "crate",         build = "crate" },
    { n = "obstacles_ca1", build = "prop",  cvars = { wh_ai_ObstaclesAddToCollisionAvoidance = 1 } },
    { n = "obstacles_ca2", build = "prop",  cvars = { wh_ai_ObstaclesAddToCollisionAvoidance = 2 } },
    { n = "findpath_obst", build = "prop",  cvars = { wh_ai_FindPathUseObstacles = 1,
                                                      wh_ai_FindPathObstaclesMultiplier = 50 } },
    { n = "mnm_rebuild",   build = "prop",  cvars = { wh_ai_AutomaticMNMRebuild = 1 } },
    { n = "dyn_obstacles", build = "prop",  cvars = { ai_AdjustPathsAroundDynamicObstacles = 1 } },
    { n = "replanning",    build = "prop",  cvars = { ai_MovementSystemPathReplanningEnabled = 1 } },
    { n = "all_cvars",     build = "prop",  cvars = ALL },
    { n = "crate_all",     build = "crate", cvars = ALL },
    { n = "pf_blocker",    build = "prop",  blocker = 1.5 },
    { n = "shape_box",     build = "prop",  shape = true },
    { n = "all_blocker",   build = "prop",  cvars = ALL, blocker = 1.5, shape = true },
}

-- THE FOCUSED SET. Collision avoidance is a STEERING system - it never consults the
-- navmesh - which is why it is the one thing that moved him when nothing else did. These
-- cases turn it on and then try to make it push harder and see further.
local CA1 = { wh_ai_ObstaclesAddToCollisionAvoidance = 1 }

mercenaries.LabCases = {
    { n = "control",       build = "prop" },
    { n = "ca1",           build = "prop",  cvars = CA1 },
    { n = "ca2",           build = "prop",  cvars = { wh_ai_ObstaclesAddToCollisionAvoidance = 2 } },
    { n = "ca1_fat",       build = "prop",  cvars = {
        wh_ai_ObstaclesAddToCollisionAvoidance = 1,
        ai_ExtraAvoidanceRadius = 2.0,
        ai_ExtraActorAvoidanceRadius = 2.0,
        ai_MinActorDynamicObstacleAvoidanceRadius = 2.0 } },
    { n = "ca1_far",       build = "prop",  cvars = {
        wh_ai_ObstaclesAddToCollisionAvoidance = 1,
        ai_CollisionAvoidanceRange = 30.0,
        wh_ai_CollisionAvoidanceCircularQueryRadius = 30.0,
        ai_CollisionAvoidanceObstacleTimeHorizon = 10.0 } },
    { n = "ca1_everything", build = "prop", cvars = {
        wh_ai_ObstaclesAddToCollisionAvoidance = 1,
        ai_ExtraAvoidanceRadius = 2.0,
        ai_ExtraActorAvoidanceRadius = 2.0,
        ai_MinActorDynamicObstacleAvoidanceRadius = 2.0,
        ai_CollisionAvoidanceRange = 30.0,
        wh_ai_CollisionAvoidanceCircularQueryRadius = 30.0,
        ai_CollisionAvoidanceObstacleTimeHorizon = 10.0,
        ai_CollisionAvoidanceUpdateVelocities = 1,
        ai_ObstacleSizeThreshold = 0.1 } },
    { n = "crate_only",    build = "crate" },
    { n = "crate_ca1",     build = "crate", cvars = CA1 },
}

mercenaries.LabRun = nil          -- nil when idle; the whole run state when going

-- ==== cvars ====
function mercenaries:LabCvarNames()
    local seen, out = {}, {}
    for _, set in ipairs({ self.LabCases, self.LabCasesBroad, self.LabCasesPhys,
                           self.LabCasesBinds, self.LabCasesSee, self.LabCasesDanger,
                           self.LabCasesSolid, self.LabCasesSolid2 }) do
        for _, c in ipairs(set or {}) do
            for k in pairs(c.cvars or {}) do
                if not seen[k] then seen[k] = true; table.insert(out, k) end
            end
        end
    end
    table.sort(out)
    return out
end

function mercenaries:LabSnapshot()
    local snap = {}
    for _, name in ipairs(self:LabCvarNames()) do
        local v
        pcall(function() v = System.GetCVar(name) end)
        snap[name] = v
    end
    return snap
end

-- Back to the snapshot first, THEN the case's own values, so one case can never leak
-- into the next.
function mercenaries:LabApplyCvars(case)
    local run = self.LabRun; if not run then return end
    for name, v in pairs(run.snap) do
        if v ~= nil then pcall(function() System.SetCVar(name, v) end) end
    end
    for name, v in pairs((case and case.cvars) or {}) do
        pcall(function() System.SetCVar(name, v) end)
    end
end

-- ==== the wall ====
mercenaries.LabWallEnts = {}

-- `spec` (optional): { class =, physics =, aiObstacle = } - what the case wants this
-- piece spawned AS. bUsedAsDynamicObstacle is the property RigidBodyEx carries with the
-- shipping comment "This value is currently used for the MNM Navigation System", so it
-- has to go in at SPAWN: entity properties are read when the entity physicalises.
local function labSpawn(model, pos, yaw, scale, invisible, list, spec)
    spec = spec or {}
    local ent
    local params = {
        class = spec.class or "mercenaries_Prop",
        name = "MercNavLab_" .. tostring(math.random(100000, 999999)),
        position = pos,
        orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
        properties = { object_Model = model, bMissionCritical = false,
                       bSaved_by_game = false, bSerialize = false },
    }
    if scale then params.scale = scale end
    if spec.aiObstacle then params.properties.AI = { bUsedAsDynamicObstacle = 1 } end
    if spec.physics then params.properties.Physics = spec.physics end
    pcall(function() ent = System.SpawnEntity(params) end)
    if not ent then
        params.class = "BasicEntity"
        params.properties.Physics = { bPhysicalize = true, bRigidBody = false,
                                      Mass = 0, Density = 0, bPushableByPlayers = false }
        pcall(function() ent = System.SpawnEntity(params) end)
    end
    if ent and spec.aiObstacle then
        -- and again after the fact, in case the class read its properties before ours
        pcall(function() ent.Properties.AI = ent.Properties.AI or {} end)
        pcall(function() ent.Properties.AI.bUsedAsDynamicObstacle = 1 end)
        pcall(function() ent:SetFromProperties() end)
    end
    if ent then
        pcall(function() ent:SetAngles({ x = 0, y = 0, z = yaw }) end)
        if scale then pcall(function() ent:SetScale(scale) end) end
        if invisible then pcall(function() ent:DrawSlot(0, 0) end) end
        table.insert(list, ent.id)
    end
    return ent
end

function mercenaries:LabClearWall()
    self:LabDangerClear()
    for _, id in ipairs(self.LabWallEnts or {}) do
        pcall(function() System.RemoveEntity(id) end)
    end
    self.LabWallEnts = {}
end

-- A straight run across the facing, centred on the axis. `prop` is the shipping palisade
-- as the mod spawns it today; `crate` is the invisible thick collider the player house
-- uses for walls it cannot get collision out of the mesh for.
function mercenaries:LabBuildWall(case)
    self:LabClearWall()
    local run = self.LabRun; if not run then return 0 end
    local mid = {
        x = run.o.x + run.f.x * self.LabWallAt,
        y = run.o.y + run.f.y * self.LabWallAt,
        z = run.o.z,
    }
    local half = self.LabWallHalf
    local a = { x = mid.x - run.r.x * half, y = mid.y - run.r.y * half, z = mid.z }
    local b = { x = mid.x + run.r.x * half, y = mid.y + run.r.y * half, z = mid.z }
    if self.CampSnapToGround then
        a = self:CampSnapToGround(a)
        b = self:CampSnapToGround(b)
    end
    run.wa, run.wb = a, b

    if case.build == "none" then
        return 0
    elseif case.spec then
        -- Any build the shipping wall functions can lay out, spawned as the case asks.
        local t = self.WallTypes[self.WallTypeIdx] or self.WallTypes[1]
        for _, seg in ipairs(self:WallEdgeSegments(a, b, true) or {}) do
            labSpawn(t.m, seg.pos, seg.yaw, nil, false, self.LabWallEnts, case.spec)
        end
    elseif case.build == "crate" then
        -- Square and scaled the same both ways, so its facing does not matter; it only
        -- has to be thick and continuous.
        local yaw = math.atan2(b.y - a.y, b.x - a.x)
        local step = 0.8
        local n = math.ceil((half * 2) / step)
        for i = 0, n - 1 do
            local d = -half + (i + 0.5) * step
            local p = { x = mid.x + run.r.x * d, y = mid.y + run.r.y * d, z = mid.z }
            if self.CampSnapToGround then p = self:CampSnapToGround(p) end
            for _, dz in ipairs({ 0.4, 1.2, 2.0 }) do
                labSpawn("objects/manmade/common_furniture/crates/crate_low_a.cgf",
                         { x = p.x, y = p.y, z = p.z + dz }, yaw,
                         { x = 1.5, y = 1.5, z = 1.0 }, true, self.LabWallEnts, case.spec)
            end
        end
    else
        -- THE BUILDER, not a copy of it. WallEdgeSegments owns the spacing, the yaw
        -- (atan2 along the run plus WallYawFix - no quarter turn, which is what a
        -- hand-rolled version got wrong twice), the lateral offset, the ground snap and
        -- the -3m sink; WallSpawnSegment owns the entity class and the mesh. A lab wall
        -- is then a mod wall by construction, and the baseline measures what ships.
        -- `flush` makes the run reach b instead of stopping at the last whole piece, so
        -- it covers the full span the verdict calls THROUGH.
        local saved = self.WallSegEnts
        self.WallSegEnts = {}
        pcall(function()
            for _, seg in ipairs(self:WallEdgeSegments(a, b, true) or {}) do
                self:WallSpawnSegment(seg.pos, seg.yaw)
            end
        end)
        self.LabWallEnts = self.WallSegEnts
        self.WallSegEnts = saved
    end

    if case.cclass then self:LabApplyClass(case.cclass) end
    if case.danger then self:LabDangerRegions(case.danger) end
    if case.wallCollider then self:LabWallColliderMode(case.wallCollider) end

    if case.blocker and AI and AI.SetPFBlockerRadius then
        local ok = 0
        for _, id in ipairs(self.LabWallEnts) do
            if pcall(function() AI.SetPFBlockerRadius(id, 0, case.blocker) end) then ok = ok + 1 end
        end
        labSay(string.format("   SetPFBlockerRadius accepted %d/%d", ok, #self.LabWallEnts))
    end
    if case.shape and AI and AI.CreateTempGenericShapeBox then
        local name
        pcall(function()
            name = AI.CreateTempGenericShapeBox(mid, half, 4.0, "AIAnchor")
        end)
        labSay("   CreateTempGenericShapeBox -> " .. tostring(name))
    end
    return #self.LabWallEnts
end

-- ==== one case ====
function mercenaries:LabStartCase(i, rep)
    local run = self.LabRun; if not run then return end
    local case = run.set[i]
    run.idx = i
    run.rep = rep or 1
    run.case = case
    run.phase = "settle"
    run.t = 0
    run.samples = {}
    run.startAlong = 2.0              -- LabSpawnNpc puts him here, on the axis
    run.maxAlong = -999
    run.maxLat = 0
    run.minWall = nil
    run.crossLat = nil
    run.verdict = nil
    run.kicks = 0
    run.lastKick = 0

    self:LabApplyCvars(case)
    local built = self:LabBuildWall(case)
    self:ClearTestNpcs()
    local sp = self:CampSnapToGround({ x = run.o.x + run.f.x * 2.0, y = run.o.y + run.f.y * 2.0, z = run.o.z })
    local ent = self:LabSpawnNpc(sp, math.atan2(run.f.y, run.f.x))
    run.npc = ent
    labSay(string.format("case %d/%d '%s' try %d/%d: %s wall, %d piece(s), npc=%s",
        i, #run.set, case.n, run.rep, self.LabRepeats, case.build, built,
        ent and "yes" or "FAILED"))
    if ent and case.walkerCollider then
        local ok = pcall(function() ent:SetColliderMode(case.walkerCollider) end)
        labSay(string.format("   walker SetColliderMode(%d) %s",
            case.walkerCollider, ok and "accepted" or "REFUSED"))
    end
    -- Disarm AFTER he is built. If he is still stopped by the wall, the character kept
    -- what it was physicalised with and the cvar never has to stay on.
    if case.restoreAfterSpawn then
        for k, v in pairs(case.restoreAfterSpawn) do
            pcall(function() System.SetCVar(k, v) end)
            labSay(string.format("   %s put back to %s after the spawn", k, tostring(v)))
        end
    end
end

function mercenaries:LabSample()
    local run = self.LabRun; if not (run and run.npc) then return end
    local p
    pcall(function() p = run.npc:GetWorldPos() end)
    if not p then return end
    local dx, dy = p.x - run.o.x, p.y - run.o.y
    local along = dx * run.f.x + dy * run.f.y
    local lat   = dx * run.r.x + dy * run.r.y
    local prev = run.samples[#run.samples]
    table.insert(run.samples, { a = along, l = lat })
    if along > run.maxAlong then run.maxAlong = along end
    if math.abs(lat) > (run.maxLat or 0) then run.maxLat = math.abs(lat) end

    -- Distance to the wall as a SEGMENT, not to its infinite plane: how close he
    -- actually came to the timber, which is the number that says whether anything is
    -- pushing him at all.
    if run.wa and run.wb then
        local dx, dy = run.wb.x - run.wa.x, run.wb.y - run.wa.y
        local L2 = dx * dx + dy * dy
        local t = 0
        if L2 > 1e-6 then
            t = ((p.x - run.wa.x) * dx + (p.y - run.wa.y) * dy) / L2
            if t < 0 then t = 0 elseif t > 1 then t = 1 end
        end
        local cx, cy = run.wa.x + dx * t, run.wa.y + dy * t
        local d = math.sqrt((p.x - cx) ^ 2 + (p.y - cy) ^ 2)
        if (not run.minWall) or d < run.minWall then run.minWall = d end
    end

    -- The moment he passes the wall plane decides the case: inside its span is THROUGH,
    -- outside is AROUND. Interpolated, because a 250ms sample can straddle the plane.
    if (not run.crossLat) and prev and prev.a < self.LabWallAt and along >= self.LabWallAt then
        local span = along - prev.a
        local f = (span > 1e-6) and ((self.LabWallAt - prev.a) / span) or 0
        run.crossLat = prev.l + (lat - prev.l) * f
        run.verdict = (math.abs(run.crossLat) <= self.LabWallHalf) and "THROUGH" or "AROUND"
        labSay(string.format("   crossed at lateral %.2fm (max %.2fm, came within %.2fm of the timber) -> %s",
            run.crossLat, run.maxLat or 0, run.minWall or -1, run.verdict))
    end
end

-- A walker who has not left his spawn point has not been measured. Re-raise the request
-- so the scheduler fires the interrupt again, and say so, because a kicked trial is a
-- weaker measurement than a clean one and the reader should know it happened.
--
-- The kick is deliberately NOT per tick: re-firing an interrupt that DID take restarts
-- the tree and the Move never lands, which is the trap the retreat experiment hit.
-- LabKickAfter is measured from the last kick, so each one gets its own chance to work.
function mercenaries:LabKickIfStalled(run)
    if not (run and run.npc) then return end
    if run.verdict then return end
    local moved = (run.maxAlong or -999) - (run.startAlong or 0)
    if moved >= 0.5 then return end
    local since = run.t - (run.lastKick or 0)
    if since < (self.LabKickAfter or 4.0) then return end
    run.kicks = (run.kicks or 0) + 1
    run.lastKick = run.t
    if run.kicks > (self.LabKickMax or 4) then return end
    local spd, st
    pcall(function() spd = run.npc:GetSpeed() end)
    pcall(function() st = run.npc.actor:GetCurrentAnimationState() end)
    labSay(string.format("   still on his spawn after %.0fs (speed=%s anim=%s) - re-ordering (kick %d)",
        run.t, tostring(spd), tostring(st), run.kicks))
    self.NavWalkRequested = true
end

function mercenaries:LabFinishCase()
    local run = self.LabRun; if not run then return end
    if not run.verdict then
        local moved = (run.maxAlong or -999) - (run.startAlong or 0)
        if moved < (self.LabMovedMin or 2.0) then
            run.verdict = "NOMOVE"
            labSay(string.format("   WALKER NEVER MOVED (%.1fm from his spawn, %d re-order(s)) - trial void, not a result",
                math.max(moved, 0), run.kicks or 0))
        else
            run.verdict = "BLOCKED"
            labSay(string.format("   never passed the wall plane (walked %.1fm, wall at %.1fm)",
                moved, self.LabWallAt - (run.startAlong or 0)))
        end
    end
    table.insert(run.results, {
        n = run.case.n, build = run.case.build, verdict = run.verdict,
        lat = run.crossLat, maxAlong = run.maxAlong, samples = #run.samples,
        maxLat = run.maxLat or 0, minWall = run.minWall,
    })
    self:LabClearWall()
    self:ClearTestNpcs()
    self.NavWalkRequested = false
end

-- ==== the chain ====
function mercenaries:LabTickDrive()
    local run = self.LabRun
    if not run then return end
    local dt = (self.LabTickMs or 250) / 1000
    run.t = run.t + dt

    if run.phase == "settle" then
        if run.t >= self.LabSettle then
            local goal = self.LabGoalAtRun or self.LabGoalAt
            self.NavWaypoints = { { x = run.o.x + run.f.x * goal,
                                    y = run.o.y + run.f.y * goal,
                                    z = run.o.z } }
            self.NavWalkRequested = true
            run.phase = "walk"
            run.t = 0
            labSay("   walking")
            if run.case and run.case.probe then pcall(function() self:LabProbeBinds(run) end) end
            if run.case and run.case.canmove then pcall(function() self:LabProbeCanMove(run) end) end
            if run.case and run.case.forbidden then pcall(function() self:LabProbeForbidden(run) end) end
            if run.case and run.case.solid then pcall(function() self:LabProbeSolid(run) end) end
            -- The shipping question: an NPC who already exists, armed on the spot. The
            -- cvar alone does nothing to a character that is already physicalised - the
            -- help text says "or update collider mode otherwise", and a real mode change
            -- is what re-applies it.
            if run.case and run.case.lateRigid and run.npc then
                pcall(function() System.SetCVar("ac_disableLivingVsRigidCollisions", 0) end)
                local ok = pcall(function() run.npc:SetColliderMode(3) end)
                labSay("   late arm: cvar set mid-walk, collider pulsed to 3 -> " ..
                    (ok and "accepted" or "REFUSED"))
            end
        end
    elseif run.phase == "walk" then
        if run.case and run.case.forceNav then pcall(function() self:LabForceNav(run) end) end
        if run.case and run.case.forceAxis then pcall(function() self:LabForceNavAxis(run) end) end
        -- The animated character re-requests its own mode constantly, so an override set
        -- once at spawn does not survive; push it every tick or the case measures nothing.
        if run.case and run.case.walkerCollider and run.npc then
            pcall(function() run.npc:SetColliderMode(run.case.walkerCollider) end)
        end
        self:LabSample()
        self:LabKickIfStalled(run)
        if run.verdict or run.t >= self.LabWalk then
            self:LabFinishCase()
            run.phase = "gap"
            run.t = 0
        end
    elseif run.phase == "gap" then
        if run.t >= self.LabGap then
            if run.rep < self.LabRepeats then
                self:LabStartCase(run.idx, run.rep + 1)
            else
                local nxt = run.idx + 1
                if run.only or nxt > #run.set then
                    self:LabStop("finished")
                    return
                end
                self:LabStartCase(nxt, 1)
            end
        end
    end

    self:ChainArm("LabTick", self.LabTickMs or 250)
end
mercenaries:ChainDef("LabTick", "LabTickDrive")

function mercenaries:LabStart(line, setName)
    if self.LabRun then labSay("already running (merc_wall_lab_stop)"); return end
    if not player then labSay("no player"); return end
    if not self.SpawnTestNpc then labSay("test NPC module missing"); return end

    local set = self.LabCases
    if setName == "broad" or setName == true then set = self.LabCasesBroad end
    if setName == "phys" then set = self.LabCasesPhys end
    if setName == "binds" then set = self.LabCasesBinds end
    if setName == "see" then set = self.LabCasesSee end
    if setName == "danger" then set = self.LabCasesDanger end
    if setName == "solid" then set = self.LabCasesSolid end
    if setName == "solid2" then set = self.LabCasesSolid2 end
    self:LabSweepLeftovers()
    local only
    local arg = tostring(line or ""):match("%S+")
    if arg then
        only = tonumber(arg)
        if not only then
            for i, c in ipairs(set) do if c.n == arg then only = i end end
        end
        if not only or not set[only] then labSay("no such case: " .. arg); return end
    end

    local o = player:GetWorldPos()
    local ang; pcall(function() ang = player:GetWorldAngles() end)
    local yaw = (ang and ang.z) or 0
    local laneYaw, laneLen = self:LabFindLane(o, yaw)
    local need = self.LabWallAt + self.LabLaneBeyond
    if laneLen < need then
        labSay(string.format("no lane here: best bearing has %.0fm of the %.0fm needed - move to open ground",
            laneLen, need))
        if self.LabAutoQuit and not self.LabLocate then
            self.LabAutoQuit = false
            labSay("auto-quit")
            pcall(function() System.ExecuteCommand("quit") end)
        end
        return
    end
    if math.abs(laneYaw - yaw) > 1e-3 then
        labSay(string.format("lane: turned %.0f degrees off your facing for %.0fm of clear ground",
            math.deg(laneYaw - yaw), laneLen))
    end
    yaw = laneYaw
    -- Fit the walk to the lane: the goal sits as far out as the ground allows, capped at
    -- the default. A 38m lane still gives a 15m wall and a 36m goal.
    self.LabGoalAtRun = math.max(self.LabWallAt + 6, math.min(self.LabGoalAt, laneLen - 2))
    self.LabRun = {
        o = { x = o.x, y = o.y, z = o.z },
        f = { x = math.cos(yaw), y = math.sin(yaw) },
        r = { x = -math.sin(yaw), y = math.cos(yaw) },
        snap = self:LabSnapshot(),
        savedWps = self.NavWaypoints,
        results = {},
        set = set,
        only = (only ~= nil),
    }
    do
        local missing, present = {}, {}
        for _, name in ipairs(self:LabCvarNames()) do
            local v
            pcall(function() v = System.GetCVar(name) end)
            table.insert(v == nil and missing or present, name)
        end
        labSay(string.format("cvars: %d registered, %d MISSING", #present, #missing))
        for _, n in ipairs(missing) do labSay("   MISSING  " .. n) end
        -- The SHIPPING values, printed before anything is armed. Which way round a
        -- "disable" flag ships decides whether a result means anything at all.
        for _, n in ipairs(present) do
            if n:find("^ac_") then
                labSay(string.format("   ships as  %s = %s", n, tostring(self.LabRun.snap[n])))
            end
        end
    end
    labSay(string.format("run starting: %s x%d, wall %.0fm out and %.0fm wide, goal %.0fm (lane %.0fm)",
        only and ("case " .. only) or (#set .. " cases"), self.LabRepeats,
        self.LabWallAt, self.LabWallHalf * 2, self.LabGoalAtRun or self.LabGoalAt, laneLen))
    labSay("STAND STILL and keep the area clear until it reports")
    self:LabStartCase(only or 1, 1)
    self:ChainArm("LabTick", self.LabTickMs or 250)
end

function mercenaries:LabStop(why)
    local run = self.LabRun
    self:LabClearWall()
    pcall(function() self:ClearTestNpcs() end)
    self.NavWalkRequested = false
    if run then
        for name, v in pairs(run.snap) do
            if v ~= nil then pcall(function() System.SetCVar(name, v) end) end
        end
        self.NavWaypoints = run.savedWps or {}
        self.LabResults = run.results
        self.LabRun = nil
        labSay("stopped (" .. tostring(why or "by hand") .. "); cvars restored")
        self:LabReport()
    else
        labSay("not running")
    end
    if self.LabAutoQuit then
        self.LabAutoQuit = false
        labSay("auto-quit")
        pcall(function() System.ExecuteCommand("quit") end)
    end
end

function mercenaries:LabReport()
    local res = self.LabResults or {}
    if #res == 0 then labSay("no results yet"); return end

    -- Group by case, in the order they were run.
    local order, byName = {}, {}
    for _, r in ipairs(res) do
        if not byName[r.n] then
            byName[r.n] = { n = r.n, build = r.build, tries = 0, around = 0, blocked = 0,
                            sumLat = 0, bestLat = 0, sumWall = 0, wallN = 0 }
            table.insert(order, r.n)
        end
        local g = byName[r.n]
        g.tries = g.tries + 1
        if r.verdict == "AROUND" then g.around = g.around + 1 end
        if r.verdict == "BLOCKED" then g.blocked = g.blocked + 1 end
        if r.verdict == "NOMOVE" then g.nomove = (g.nomove or 0) + 1 end
        g.sumLat = g.sumLat + (r.maxLat or 0)
        if (r.maxLat or 0) > g.bestLat then g.bestLat = r.maxLat or 0 end
        if r.minWall then g.sumWall = g.sumWall + r.minWall; g.wallN = g.wallN + 1 end
    end

    labSay("--- results ---")
    labSay(string.format("%-15s %-6s %7s %7s %8s %8s", "case", "build",
        "around", "blocked", "meanLat", "maxLat"))
    local void = 0
    for _, name in ipairs(order) do
        local g = byName[name]
        void = void + (g.nomove or 0)
        labSay(string.format("%-15s %-6s %3d/%-3d %3d/%-3d %7.2fm %7.2fm%s",
            g.n, g.build, g.around, g.tries, g.blocked, g.tries,
            g.sumLat / math.max(g.tries, 1), g.bestLat,
            (g.nomove or 0) > 0 and ("  " .. g.nomove .. " VOID") or ""))
    end
    if void > 0 then
        labSay(string.format("!! %d trial(s) VOID: the walker never left his spawn. Nothing in this", void))
        labSay("   table means anything until that is fixed - a man who cannot walk cannot")
        labSay("   be stopped by a wall.")
    end
    labSay("meanLat is the headline: how far sideways the wall pushed him, averaged over")
    labSay("the tries. The control says what a straight line looks like; anything well")
    labSay("above that is the engine steering round the wall, whatever the verdict says.")
    labSay(string.format("(the wall is %.0fm wide, so a lateral near %.0fm is its end)",
        self.LabWallHalf * 2, self.LabWallHalf))
end

function mercenaries:LabShow(line)
    if self.LabRun then labSay("a run is going; merc_wall_lab_stop first"); return end
    if not player then labSay("no player"); return end
    local case = self.LabCases[1]
    local arg = tostring(line or ""):match("%S+")
    if arg then
        local i = tonumber(arg)
        local found
        for _, set in ipairs({ self.LabCasesPhys, self.LabCases, self.LabCasesBroad }) do
            if i and set[i] then found = found or set[i] end
            for _, c in ipairs(set) do if c.n == arg then found = c end end
        end
        if not found then labSay("no such case: " .. arg); return end
        case = found
    end

    local o = player:GetWorldPos()
    local ang; pcall(function() ang = player:GetWorldAngles() end)
    local yaw = (ang and ang.z) or 0
    self.LabRun = {
        o = { x = o.x, y = o.y, z = o.z },
        f = { x = math.cos(yaw), y = math.sin(yaw) },
        r = { x = -math.sin(yaw), y = math.cos(yaw) },
    }
    local n = self:LabBuildWall(case)
    self.LabRun = nil
    labSay(string.format("'%s' wall standing: %d piece(s), %.0fm out, %.0fm wide - walk it, then merc_wall_lab_clear",
        case.n, n, self.LabWallAt, self.LabWallHalf * 2))
end

function mercenaries:LabSetRepeats(v)
    local n = tonumber(tostring(v or ""):match("%d+"))
    if n and n >= 1 then self.LabRepeats = n end
    labSay("trials per case: " .. self.LabRepeats)
end

function mercenaries:LabList()
    labSay("--- focused set (merc_wall_lab) ---")
    for i, c in ipairs(self.LabCases) do
        local bits = {}
        for k, v in pairs(c.cvars or {}) do table.insert(bits, k .. "=" .. tostring(v)) end
        if c.blocker then table.insert(bits, "SetPFBlockerRadius") end
        if c.shape then table.insert(bits, "TempGenericShapeBox") end
        table.sort(bits)
        labSay(string.format("%2d %-16s %-6s %s", i, c.n, c.build,
            (#bits > 0) and table.concat(bits, ", ") or "(nothing changed)"))
    end
    labSay("--- broad sweep (merc_wall_lab_broad) ---")
    for i, c in ipairs(self.LabCasesBroad) do
        labSay(string.format("%2d %-16s %-6s", i, c.n, c.build))
    end
    labSay("--- physics set (merc_wall_lab_phys / F11) ---")
    for i, c in ipairs(self.LabCasesPhys) do
        labSay(string.format("%2d %-16s %-6s %s", i, c.n, c.build, c.cclass or ""))
    end
end


-- ==== the physics set ====
-- Every pathfinding lever is dead (the navmesh is baked into recast.pak, see the docs)
-- and the one cvar that seemed to steer him turned out to be the player standing off
-- the axis. What is left is the NPC's BODY: does it collide with the wall at all, and
-- does that depend on the wall's collision class? These spawn the same wall under every
-- NPC-facing class the engine has, plus a heavy rigid body, which NPCs are known to
-- shove. Set from EntityCommon.ApplyCollisionFiltering: SetPhysicParams with
-- PHYSICPARAM_COLLISION_CLASS and the gcc_* globals the game defines.
local CA1 = { wh_ai_ObstaclesAddToCollisionAvoidance = 1 }

-- Resting so it does not topple or roll: what is wanted is a wall that registers with the
-- navigation system, not a physics prop that falls over the moment an NPC leans on it.
local RESTING = { bRigidBodyActive = false, bResting = 1, bPhysicalize = true,
                  Mass = 10000, Density = -1, bPushableByPlayers = false }

-- The pathfinder's own danger-cost system, which needs no navmesh change.
local DANGER_CV = {
    ai_PathfinderDangerCostForExplosives        = 100.0,
    ai_PathfinderExplosiveDangerRadius          = 12.0,
    ai_PathfinderExplosiveDangerMaxThreatDistance = 120.0,
    ai_PathfinderDangerCostForAttentionTarget   = 100.0,
}

mercenaries.LabCasesDanger = {
    { n = "control",    build = "prop", forbidden = true },
    { n = "danger_r4",  build = "prop", danger = 4.0 },
    { n = "danger_r8",  build = "prop", danger = 8.0 },
    { n = "danger_cv",  build = "prop", danger = 4.0, cvars = DANGER_CV },
    { n = "danger_all", build = "prop", danger = 8.0, cvars = {
        ai_PathfinderDangerCostForExplosives        = 100.0,
        ai_PathfinderExplosiveDangerRadius          = 12.0,
        ai_PathfinderExplosiveDangerMaxThreatDistance = 120.0,
        ai_PathfinderDangerCostForAttentionTarget   = 100.0,
        ai_AdjustPathsAroundDynamicObstacles        = 1,
        ai_MovementSystemPathReplanningEnabled      = 1 } },
}

-- Does the engine's own walkability query see a spawned wall? Distance-controlled.
mercenaries.LabCasesSee = {
    { n = "see_wall",    build = "prop", canmove = true },
    { n = "see_nowall",  build = "none", canmove = true },
    { n = "fnav_axis",   build = "none", forceAxis = true },
    { n = "fnav_wall",   build = "prop", forceAxis = true },
}

-- Binds rather than geometry: what does the ENGINE say and accept?
mercenaries.LabCasesBinds = {
    { n = "probe_control", build = "prop", probe = true },
    { n = "probe_obst",    build = "spec", probe = true,
                           spec = { class = "RigidBodyEx", physics = { bRigidBodyActive = false,
                                    bResting = 1, bPhysicalize = true, Mass = 10000,
                                    Density = -1, bPushableByPlayers = false }, aiObstacle = true },
                           cvars = { ai_AdjustPathsAroundDynamicObstacles = 1 } },
    { n = "forced_nav",    build = "prop", forceNav = true },
    { n = "pointlist",     build = "prop", probe = true },
}

-- ==== THE COLLIDER-MODE SET ====
-- Every set above asked the NAVIGATION to route round the wall, and every one failed
-- because the navmesh is baked. This one asks a different question: the wall carries a
-- real `$physics_proxy` and the player is stopped by it, so why is the NPC's own body
-- not? The engine keeps a separate collider mode for AI and for the player
-- (`ac_ColliderModeAI` / `ac_ColliderModePlayer`), and `entity:SetColliderMode(n)` is
-- live per entity - the shipping door smart object (AI/world/so_door.xml) puts both the
-- NPC and the door into mode 7 while he walks through, then back to 0.
--
--   0 Undefined  1 Disabled  2 GroundedOnly  3 Pushable
--   4 NonPushable  5 PushesPlayersOnly  6 Spectator  7 Interactive
--
-- A mode that only resolves against the ground is exactly the symptom: solid to the
-- player, transparent to an NPC, and no amount of navmesh work would ever have shown it.
local COLLIDER_MODE_NAMES = { [0] = "Undefined", "Disabled", "GroundedOnly", "Pushable",
                              "NonPushable", "PushesPlayersOnly", "Spectator", "Interactive" }

mercenaries.LabCasesSolid = {
    { n = "control",       build = "prop", solid = true },
    { n = "cm_ai_ground",  build = "prop", solid = true, cvars = { ac_ColliderModeAI = 2 } },
    { n = "cm_ai_push",    build = "prop", solid = true, cvars = { ac_ColliderModeAI = 3 } },
    { n = "cm_ai_nonpush", build = "prop", solid = true, cvars = { ac_ColliderModeAI = 4 } },
    { n = "walker_cm3",    build = "prop", solid = true, walkerCollider = 3 },
    { n = "walker_cm4",    build = "prop", solid = true, walkerCollider = 4 },
    { n = "wall_cm4",      build = "prop", solid = true, wallCollider = 4 },
    { n = "mcm_entity",    build = "prop", solid = true, cvars = { ac_movementControlMethodHor = 1 } },
    { n = "mcm_ent_cm4",   build = "prop", solid = true,
                           cvars = { ac_movementControlMethodHor = 1, ac_ColliderModeAI = 4 } },
    { n = "extra_solid",   build = "prop", solid = true, cvars = { ac_enableExtraSolidCollider = 1 } },
    { n = "living_coll",   build = "prop", solid = true,
                           cvars = { ac_disableLivingVsRigidCollisions = 0,
                                     ac_disableLivingVsLivingCollisions = 0 } },
    -- The other-way control: with the override on and NOTHING built, he must still walk.
    -- Without this a mode that simply freezes every NPC reads as a wall that works.
    { n = "nowall_cm4",    build = "none", solid = true, cvars = { ac_ColliderModeAI = 4 } },
}

-- ==== THE ISOLATION SET ====
-- `living_coll` in the set above is the first case in this whole investigation that ever
-- BLOCKED a walker - both trials, 12.7m walked against a wall at 13.0m. It set two cvars
-- at once, and the engine's own help text says which one matters:
--
--   ac_disableLivingVsRigidCollisions
--     "Disable collisions between living and rigid entities.
--      Must reload level (or update collider mode otherwise) to work."
--
-- So KCD2 ships with living-vs-rigid collision OFF, and that - not the navmesh - is why
-- an NPC walks through a wall the player cannot. This set answers the three questions
-- that decide whether it can ship: which cvar, does it latch per character at collider
-- update (so it can be SCOPED rather than armed globally), and can an NPC who already
-- exists be converted without a level reload.
mercenaries.LabCasesSolid2 = {
    { n = "control",      build = "prop",  solid = true },
    { n = "rigid_off",    build = "prop",  solid = true, cvars = { ac_disableLivingVsRigidCollisions = 0 } },
    { n = "living_off",   build = "prop",  solid = true, cvars = { ac_disableLivingVsLivingCollisions = 0 } },
    { n = "rigid_crate",  build = "crate", solid = true, cvars = { ac_disableLivingVsRigidCollisions = 0 } },
    -- Armed for the spawn, disarmed immediately after. Still BLOCKED means the character
    -- keeps what it was built with and the mod never has to leave the cvar on.
    { n = "rigid_scoped", build = "prop",  solid = true, cvars = { ac_disableLivingVsRigidCollisions = 0 },
                          restoreAfterSpawn = { ac_disableLivingVsRigidCollisions = 1 } },
    -- The one that decides whether NPCs already in the world can be converted: spawned
    -- with the cvar at its shipping value, then armed and given a collider-mode pulse.
    { n = "rigid_late",   build = "prop",  solid = true, lateRigid = true },
    -- He must still cross open ground with the cvar on, or "blocked" means "broken".
    { n = "rigid_nowall", build = "none",  solid = true, cvars = { ac_disableLivingVsRigidCollisions = 0 } },
}

-- Rays across the wall line at ankle, hip and chest height. Every result before this one
-- assumed the wall was physically there and none of them checked, so a wall that failed
-- to physicalise would have read as an NPC ignoring it.
function mercenaries:LabProbeSolid(run)
    if not (run and run.wa and run.wb) then labSay("   solid probe: no wall line"); return end
    local mask = ent_terrain + ent_static
    if ent_rigid then mask = mask + ent_rigid end
    if ent_sleeping_rigid then mask = mask + ent_sleeping_rigid end
    local mid = { x = (run.wa.x + run.wb.x) * 0.5,
                  y = (run.wa.y + run.wb.y) * 0.5,
                  z = (run.wa.z + run.wb.z) * 0.5 }
    local out = {}
    for _, dz in ipairs({ 0.25, 0.90, 1.60 }) do
        local from = { x = mid.x - run.f.x * 4.0, y = mid.y - run.f.y * 4.0, z = mid.z + dz }
        local dir  = { x = run.f.x * 8.0, y = run.f.y * 8.0, z = 0 }
        local tbl, hits = {}, 0
        pcall(function() hits = Physics.RayWorldIntersection(from, dir, 4, mask, nil, nil, tbl) end)
        local what = "NOTHING"
        if hits > 0 and tbl[1] and tbl[1].pos then
            local nm
            pcall(function() nm = tbl[1].entity and tbl[1].entity:GetName() end)
            local d = math.sqrt((tbl[1].pos.x - from.x) ^ 2 + (tbl[1].pos.y - from.y) ^ 2)
            what = string.format("%s @%.2fm", nm or "unnamed", d)
        end
        table.insert(out, string.format("%.2f=%s", dz, what))
    end
    labSay("   solid probe across the wall: " .. table.concat(out, "  "))
end

-- Put every standing piece into one collider mode. A prop is not an animated character,
-- so this may simply be refused - which is itself the answer for that case.
function mercenaries:LabWallColliderMode(mode)
    local ok = 0
    for _, id in ipairs(self.LabWallEnts or {}) do
        local e
        pcall(function() e = System.GetEntity(id) end)
        if e and pcall(function() e:SetColliderMode(mode) end) then ok = ok + 1 end
    end
    labSay(string.format("   wall SetColliderMode(%d %s) took on %d/%d piece(s)",
        mode, COLLIDER_MODE_NAMES[mode] or "?", ok, #(self.LabWallEnts or {})))
    return ok
end

mercenaries.LabCasesPhys = {
    { n = "control",       build = "prop" },
    { n = "obst_prop",     build = "spec", spec = { class = "mercenaries_Prop", aiObstacle = true } },
    { n = "obst_prop_cv",  build = "spec", spec = { class = "mercenaries_Prop", aiObstacle = true },
                           cvars = { ai_AdjustPathsAroundDynamicObstacles = 1 } },
    { n = "rigidex",       build = "spec", spec = { class = "RigidBodyEx", physics = RESTING } },
    { n = "rigidex_obst",  build = "spec", spec = { class = "RigidBodyEx", physics = RESTING, aiObstacle = true } },
    { n = "rigidex_cv",    build = "spec", spec = { class = "RigidBodyEx", physics = RESTING, aiObstacle = true },
                           cvars = { ai_AdjustPathsAroundDynamicObstacles = 1 } },
    { n = "rigidex_all",   build = "spec", spec = { class = "RigidBodyEx", physics = RESTING, aiObstacle = true },
                           cvars = { ai_AdjustPathsAroundDynamicObstacles = 1,
                                     wh_ai_ObstaclesAddToCollisionAvoidance = 1,
                                     wh_ai_FindPathUseObstacles = 1,
                                     ai_MinActorDynamicObstacleAvoidanceRadius = 2.0,
                                     ai_ObstacleSizeThreshold = 0.1 } },
    { n = "debris",        build = "spec", spec = { class = "Debris", physics = RESTING, aiObstacle = true },
                           cvars = { ai_AdjustPathsAroundDynamicObstacles = 1 } },
    { n = "crate_obst",    build = "crate", spec = { class = "mercenaries_Prop", aiObstacle = true },
                           cvars = { ai_AdjustPathsAroundDynamicObstacles = 1 } },
    { n = "rigidex_alive", build = "spec", spec = { class = "RigidBodyEx", aiObstacle = true,
                             physics = { bRigidBodyActive = true, bResting = 1, bPhysicalize = true,
                                         Mass = 10000, Density = -1, bPushableByPlayers = false } },
                           cvars = { ai_AdjustPathsAroundDynamicObstacles = 1 } },
}

local function labClassFlag(name)
    local v = _G[name]
    if v == nil and g_PhysicsCollisionClass then v = g_PhysicsCollisionClass[name] end
    return v
end

-- Put every piece of the standing wall in one collision class. Returns how many took it.
function mercenaries:LabApplyClass(name)
    local flag = labClassFlag(name)
    if not flag then labSay("   collision class " .. tostring(name) .. " is not defined"); return 0 end
    if not PHYSICPARAM_COLLISION_CLASS then labSay("   PHYSICPARAM_COLLISION_CLASS missing"); return 0 end
    local ok = 0
    for _, id in ipairs(self.LabWallEnts or {}) do
        local e
        pcall(function() e = System.GetEntity(id) end)
        if e and pcall(function()
            e:SetPhysicParams(PHYSICPARAM_COLLISION_CLASS, { collisionClass = flag, collisionClassIgnore = 0 })
        end) then ok = ok + 1 end
    end
    labSay(string.format("   collision class %s (0x%x) on %d/%d piece(s)", name, flag, ok, #self.LabWallEnts))
    return ok
end

-- ==== spawn him ON the axis ====
-- SpawnTestNpc puts the man wherever the PLAYER is standing. Every lateral in two runs
-- was really the player's own offset from the axis - including a 9.45m "AROUND" that
-- was the player walking to the end of the crate wall to look at it. The run's origin
-- is the only thing he may start from.
function mercenaries:LabSpawnNpc(pos, yaw)
    local name = "SpawnedTestNpc_" .. tostring(math.random(10000, 99999)) .. "_" .. self.TestNpcSoul
    local ent
    local ok, err = pcall(function()
        System.SpawnEntity({
            class = "NPC",
            name = name,
            position = pos,
            orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
            properties = { guidSharedSoulId = self.TestNpcSoul },
        })
        ent = System.GetEntityByName(name)
        if ent and self.EquipEnemy then self:EquipEnemy(ent, "looter", false) end
    end)
    if not ok then labSay("   npc spawn error: " .. tostring(err)) end
    if ent then table.insert(self.TestNpcs, ent) end
    return ent
end

-- Anything a crashed or aborted run left in the world. Not MercWallSeg_: that is the
-- camp wall's own prefix and a real camp may be standing.
function mercenaries:LabSweepLeftovers()
    local n = 0
    for _, cls in ipairs({ "NPC", "mercenaries_Prop", "BasicEntity" }) do
        local ents
        pcall(function() ents = System.GetEntitiesByClass(cls) end)
        for _, e in pairs(ents or {}) do
            local nm = ""
            pcall(function() nm = e:GetName() or "" end)
            if nm:find("^SpawnedTestNpc_") or nm:find("^MercNavLab_") then
                pcall(function() System.RemoveEntity(e.id) end)
                n = n + 1
            end
        end
    end
    if n > 0 then labSay("swept " .. n .. " leftover lab entit(ies)") end
    return n
end

-- ==== find a lane ====
-- The run needs LabLaneLen metres of open ground. Rather than trust wherever the save
-- left the player facing, sweep bearings and take the clearest one - the player's own
-- facing wins a tie. A bearing is clear as far as the ground can be found under it with
-- no step bigger than LabLaneMaxRise between samples: that rejects walls, buildings,
-- roofs and drops, and passes a tree canopy the way the camp scan does.
mercenaries.LabLaneLen     = 50.0    -- how far a bearing is scanned; longer lanes win
mercenaries.LabLaneStep    = 2.0
mercenaries.LabLaneMaxRise = 1.3     -- 0.8 rejected every road ditch and clearing edge on the map
mercenaries.LabLaneBeyond  = 8.0     -- ground needed PAST the wall: the verdict fires at the
                                     -- wall plane, the goal only has to be reachable beyond it

function mercenaries:LabLaneClear(o, yaw, len, lateral)
    local fx, fy = math.cos(yaw), math.sin(yaw)
    local rx, ry = -fy, fx
    local lastZ = o.z
    local clear = 0
    for d = self.LabLaneStep, len, self.LabLaneStep do
        local p = { x = o.x + fx * d + rx * lateral, y = o.y + fy * d + ry * lateral, z = lastZ }
        local g = self:CampSnapToGround(p)
        if (not g) or g == p then break end
        if math.abs(g.z - lastZ) > self.LabLaneMaxRise then break end
        lastZ = g.z
        clear = d
    end
    return clear
end

function mercenaries:LabWallLineClear(o, yaw)
    local fx, fy = math.cos(yaw), math.sin(yaw)
    local rx, ry = -fy, fx
    local cx, cy = o.x + fx * self.LabWallAt, o.y + fy * self.LabWallAt
    local centre = self:CampSnapToGround({ x = cx, y = cy, z = o.z })
    if (not centre) or centre.z == o.z then return false end
    for lat = -self.LabWallHalf, self.LabWallHalf, 2.0 do
        local p = { x = cx + rx * lat, y = cy + ry * lat, z = centre.z }
        local g = self:CampSnapToGround(p)
        if (not g) or g == p then return false end
        if math.abs(g.z - centre.z) > self.LabLaneMaxRise then return false end
    end
    return true
end

function mercenaries:LabFindLane(o, prefYaw)
    local n = 24
    local best, bestLen = prefYaw, -1
    for i = 0, n - 1 do
        local yaw = prefYaw + (i / n) * 2 * math.pi
        local c = self:LabLaneClear(o, yaw, self.LabLaneLen, 0)
        -- the wall is 16m wide: the ground along its own line must be there and level
        -- with the centre, or it stands in a hedge or hangs over a ditch
        if c >= self.LabWallAt + self.LabLaneBeyond and not self:LabWallLineClear(o, yaw) then
            c = self.LabWallAt - 1
        end
        if c > bestLen then best, bestLen = yaw, c end
        if c >= self.LabLaneLen then break end
    end
    return best, bestLen
end


-- ==== the bind probe ====
-- Three AI binds documented in the scriptbind reference and never exercised. Two of them
-- would matter to the mod even if no wall ever blocks anyone:
--
--   CanMoveStraightToPoint  a QUESTION. If the engine answers "no" with a spawned wall in
--                           the way, then navigation DOES see it and only the mover
--                           ignores it - which would be a completely different problem
--                           from the one measured so far.
--   SetPointListToFollow    hands the engine an explicit polyline. If it takes, a merc on
--                           the engine's own follow chain could be routed round a wall
--                           without evicting his behaviour at all.
--   SetForcedNavigation     forces a movement direction over pathfinding. The one lever
--                           that could beat combat steering, which is why battles are
--                           staged instead.
function mercenaries:LabProbeBinds(run)
    local npc = run.npc; if not npc then return end
    local id = npc.id
    local far = { x = run.o.x + run.f.x * (self.LabGoalAtRun or self.LabGoalAt),
                  y = run.o.y + run.f.y * (self.LabGoalAtRun or self.LabGoalAt),
                  z = run.o.z }
    local near = { x = run.o.x + run.f.x * 5.0, y = run.o.y + run.f.y * 5.0, z = run.o.z }

    local function say(name, ok, val)
        labSay(string.format("   %-24s %s%s", name,
            ok and "call OK" or "THREW",
            (val ~= nil) and ("  -> " .. tostring(val)) or ""))
    end

    if AI and AI.CanMoveStraightToPoint then
        local v1, v2
        local a = pcall(function() v1 = AI.CanMoveStraightToPoint(id, far) end)
        local b = pcall(function() v2 = AI.CanMoveStraightToPoint(id, near) end)
        say("CanMove->far(wall)", a, v1)
        say("CanMove->near(clear)", b, v2)
        if a and b and v1 ~= v2 then
            labSay("   !! the engine answers DIFFERENTLY across the wall - it sees it")
        end
    else
        labSay("   CanMoveStraightToPoint missing")
    end

    if AI and AI.GetNavigationType then
        local v
        local ok = pcall(function() v = AI.GetNavigationType(id) end)
        say("GetNavigationType", ok, v)
    end

    if AI and AI.SetPointListToFollow then
        -- round the wall's left end and back to the axis
        local pts = {
            { x = run.o.x + run.f.x * 8 + run.r.x * 11, y = run.o.y + run.f.y * 8 + run.r.y * 11, z = run.o.z },
            { x = run.o.x + run.f.x * 20 + run.r.x * 11, y = run.o.y + run.f.y * 20 + run.r.y * 11, z = run.o.z },
            { x = far.x, y = far.y, z = far.z },
        }
        local ok = pcall(function() AI.SetPointListToFollow(id, pts, #pts, false) end)
        say("SetPointListToFollow", ok)
    end
end

-- Pushed every tick of the walk: a direction, not a destination.
function mercenaries:LabForceNav(run)
    local npc = run.npc; if not (npc and AI and AI.SetForcedNavigation) then return end
    local d = { x = run.r.x, y = run.r.y, z = 0 }
    local ok = pcall(function() AI.SetForcedNavigation(npc.id, d) end)
    if not run._forcedSaid then
        run._forcedSaid = true
        labSay("   SetForcedNavigation " .. (ok and "call OK (pushing sideways every tick)" or "THREW"))
    end
end


-- ==== is CanMoveStraightToPoint actually seeing the WALL? ====
-- The first probe asked about a point 45m away through the wall and a point 5m away in
-- the clear, and got false/true. That is not evidence: the far one is nine times further,
-- and any distance limit would answer the same way. This asks the same distances ALONG
-- the axis (through the wall) and ACROSS it (open ground), and the `nowall` case runs the
-- identical sweep with nothing built. Three readings settle it:
--
--   axis blocked, cross clear, nowall-axis clear  -> the engine sees the wall
--   axis and cross both blocked past the same range -> it is a distance limit
--   nowall-axis blocked too                        -> the terrain, not us
mercenaries.LabCanMoveDists = { 8, 12, 18, 25, 35, 45 }

function mercenaries:LabProbeCanMove(run)
    local npc = run.npc; if not npc then return end
    if not (AI and AI.CanMoveStraightToPoint) then labSay("   CanMoveStraightToPoint missing"); return end
    local id = npc.id

    local function ask(d, lat)
        local p = { x = run.o.x + run.f.x * d + run.r.x * lat,
                    y = run.o.y + run.f.y * d + run.r.y * lat, z = run.o.z }
        p = self:CampSnapToGround(p)
        local v
        local ok = pcall(function() v = AI.CanMoveStraightToPoint(id, p) end)
        if not ok then return "THREW" end
        return tostring(v)
    end

    local axis, cross = {}, {}
    for _, d in ipairs(self.LabCanMoveDists) do
        table.insert(axis, string.format("%dm=%s", d, ask(d, 0)))
        -- same distance, 90 degrees off: open ground, no wall on that bearing
        table.insert(cross, string.format("%dm=%s", d, ask(0, d)))
    end
    labSay("   ALONG the axis (wall at " .. self.LabWallAt .. "m): " .. table.concat(axis, "  "))
    labSay("   ACROSS it (open ground):        " .. table.concat(cross, "  "))
end

-- Does SetForcedNavigation MOVE him? The first probe pushed sideways while the Move node
-- pulled forward and he went nowhere, which says the bind bites but not which way. This
-- pushes him straight down the axis and reports the ground he actually covered.
function mercenaries:LabForceNavAxis(run)
    local npc = run.npc; if not (npc and AI and AI.SetForcedNavigation) then return end
    local d = { x = run.f.x, y = run.f.y, z = 0 }
    pcall(function() AI.SetForcedNavigation(npc.id, d) end)
    if not run._forcedSaid then
        run._forcedSaid = true
        labSay("   SetForcedNavigation: pushing FORWARD every tick")
    end
end


-- ==== danger regions ====
-- AI.RegisterDamageRegion(entityId, radius): "Register a spherical region that causes
-- damage (so should be avoided in PATHFINDING). Owner entity position is used as region
-- center." That is the one primitive found so far that asks the pathfinder to route
-- around something without the navmesh changing at all - the ground either side of the
-- wall is already walkable mesh, it just needs a reason not to cross. The pathfinder has
-- the matching cost knobs (ai_PathfinderDangerCost*, ai_PathfinderExplosiveDanger*), and
-- MNM::DangerArea is a real class in the binary.
function mercenaries:LabDangerRegions(radius)
    if not (AI and AI.RegisterDamageRegion) then labSay("   RegisterDamageRegion missing"); return 0 end
    local ok = 0
    for _, id in ipairs(self.LabWallEnts or {}) do
        if pcall(function() AI.RegisterDamageRegion(id, radius) end) then ok = ok + 1 end
    end
    labSay(string.format("   RegisterDamageRegion(r=%.1f) accepted on %d/%d piece(s)",
        radius, ok, #self.LabWallEnts))
    return ok
end

-- Disabled by a radius <= 0, per the bind's own documentation. Left behind, a region
-- would sit in the AI system for the rest of the session and poison every later case.
function mercenaries:LabDangerClear()
    if not (AI and AI.RegisterDamageRegion) then return end
    for _, id in ipairs(self.LabWallEnts or {}) do
        pcall(function() AI.RegisterDamageRegion(id, 0) end)
    end
end

-- Does the engine report a forbidden region across the wall? One line, and it says
-- whether that whole subsystem is live in this build.
function mercenaries:LabProbeForbidden(run)
    if not (AI and AI.IntersectsForbidden) then labSay("   IntersectsForbidden missing"); return end
    local a = { x = run.o.x, y = run.o.y, z = run.o.z }
    local b = { x = run.o.x + run.f.x * 30, y = run.o.y + run.f.y * 30, z = run.o.z }
    local v
    local ok = pcall(function() v = AI.IntersectsForbidden(a, b) end)
    if not ok then labSay("   IntersectsForbidden THREW"); return end
    if type(v) == "table" and v.x then
        local d = math.sqrt((v.x - a.x) ^ 2 + (v.y - a.y) ^ 2)
        labSay(string.format("   IntersectsForbidden -> hit at %.1fm (30m = no forbidden region)", d))
    else
        labSay("   IntersectsForbidden -> " .. tostring(v))
    end
end

-- ==== find somewhere to run ====
-- A save can put the player anywhere - both closed-loop runs so far landed with 15-38m
-- of ground. So the auto run does not trust its start: it probes where the player is,
-- and if that has no lane it walks a list of spots the mod already knows are open (the
-- bandit-camp clearings, then points along every patrol road on both levels), teleports
-- to each, waits for the world to stream in, and probes again. A spot on the other
-- level simply has no ground under it after the wait, and is skipped.
mercenaries.LabLocateSettle = 5.0     -- seconds after a teleport before the ground is trusted
mercenaries.LabLocateReady  = 1.5     -- seconds standing on it before the lane is measured
mercenaries.LabLocateStride = 25      -- every Nth road point is a candidate
mercenaries.LabLocateMax    = 40      -- spots tried before giving up
mercenaries.LabLocate = nil

function mercenaries:LabCandidates()
    local out = {}
    for _, s in ipairs(self.BanditCampSites or {}) do
        if s.x and s.y and s.z then
            table.insert(out, { x = s.x, y = s.y, z = s.z, tag = tostring(s.name or "site") })
        end
    end
    -- Interleave the two levels so a Trosecko save is not made to sit through every
    -- Kuttenberg road first.
    local lists = {}
    for _, tbl in ipairs({ self.PatrolRoutesKuttenberg, self.PatrolRoutesTrosky }) do
        local l = {}
        for _, r in ipairs(tbl or {}) do
            local pts = r.pts or {}
            for i = 12, #pts - 12, self.LabLocateStride do
                local p = pts[i]
                table.insert(l, { x = p.x, y = p.y, z = p.z, tag = tostring(r.name) .. "#" .. i })
            end
        end
        table.insert(lists, l)
    end
    local i = 1
    while #out < self.LabLocateMax and (lists[1][i] or lists[2][i]) do
        if lists[1][i] then table.insert(out, lists[1][i]) end
        if lists[2][i] then table.insert(out, lists[2][i]) end
        i = i + 1
    end
    return out
end

local function labPlayerYaw()
    local ang
    pcall(function() ang = player:GetWorldAngles() end)
    return (ang and ang.z) or 0
end

function mercenaries:LabLocateNext()
    local L = self.LabLocate; if not L then return end
    L.idx = L.idx + 1
    local c = L.list[L.idx]
    if not c then
        labSay("no clear lane at any known spot (" .. #L.list .. " tried)")
        self.LabLocate = nil
        if self.LabAutoQuit then
            self.LabAutoQuit = false
            labSay("auto-quit")
            pcall(function() System.ExecuteCommand("quit") end)
        end
        return false
    end
    L.here = c.tag
    L.phase = "settle"
    L.t = 0
    pcall(function() player:SetWorldPos({ x = c.x, y = c.y, z = c.z + 2.0 }) end)
    labSay(string.format("trying %s (%.0f, %.0f)", c.tag, c.x, c.y))
    return true
end

function mercenaries:LabLocateTick()
    local L = self.LabLocate
    if not L then return end
    local dt = (self.LabTickMs or 250) / 1000
    L.t = L.t + dt

    if L.phase == "settle" then
        -- Held at the spot while the world streams in; a wrong-level spot has no ground
        -- and he would otherwise fall through the map.
        local c = L.list[L.idx]
        if L.t < self.LabLocateSettle then
            pcall(function() player:SetWorldPos({ x = c.x, y = c.y, z = c.z + 2.0 }) end)
        else
            local g = self:CampSnapToGround({ x = c.x, y = c.y, z = c.z + 2.0 })
            if (not g) or g.z == c.z + 2.0 then
                labSay("   no ground here - not this level")
                if not self:LabLocateNext() then return end
            else
                pcall(function() player:SetWorldPos({ x = g.x, y = g.y, z = g.z + 0.3 }) end)
                L.phase = "ready"
                L.t = 0
            end
        end
    elseif L.phase == "ready" then
        if L.t >= self.LabLocateReady then L.phase = "probe" end
    elseif L.phase == "probe" then
        local o
        pcall(function() o = player:GetWorldPos() end)
        local need = self.LabWallAt + self.LabLaneBeyond
        local _, len = 0, -1
        if o then _, len = self:LabFindLane(o, labPlayerYaw()) end
        if len >= need then
            labSay(string.format("lane found at %s: %.0fm", tostring(L.here), len))
            self.LabLocate = nil
            self:LabStart("", self.LabAutoSet or "solid")
            return
        end
        labSay(string.format("   no lane at %s (best %.0fm of %.0fm)", tostring(L.here), len, need))
        if not self:LabLocateNext() then return end
    end

    self:ChainArm("LabLocator", self.LabTickMs or 250)
end
mercenaries:ChainDef("LabLocator", "LabLocateTick")

-- ==== one key, one run, then quit ====
-- Registered outright (not as a dev command, which only exist after merc_dev) so a
-- harness can bind a key to it at load. Finds a lane, runs the physics set, quits.
mercenaries.LabAutoQuit = false
mercenaries.LabAutoSet  = "solid2"    -- which set F11 / the harness runs

function mercenaries:LabAuto()
    if self.LabRun or self.LabLocate then labSay("already going"); return end
    if not player then labSay("no player"); return end
    self.LabAutoQuit = true
    self.LabRepeats = 2
    self.LabLocate = { list = self:LabCandidates(), idx = 0, phase = "probe", t = 0, here = "the save's own spot" }
    labSay("locating: probing where the player stands, then " .. #self.LabLocate.list .. " known spot(s)")
    self:ChainArm("LabLocator", self.LabTickMs or 250)
end

System.AddCCommand("merc_wall_lab_auto", "mercenaries:LabAuto()",
    "Harness entry: find a lane, run the physics wall lab, quit the game when it reports (also F11)")

-- Zero-argument entry points: nothing to quote, nothing to substitute. These are what
-- to reach for from merc_lua.
function mercenaries:LabBinds() self:LabStart("", "binds") end
function mercenaries:LabSee()   self:LabStart("", "see")   end
function mercenaries:LabDanger() self:LabStart("", "danger") end
function mercenaries:LabPhys()  self:LabStart("", "phys")  end
function mercenaries:LabSolid() self:LabStart("", "solid") end
function mercenaries:LabBroad() self:LabStart("", "broad") end

function mercenaries:LabStartSet(setName, line)
    self:LabStart(line, setName)
end

mercenaries:DevCommand("merc_wall_lab",        "mercenaries:LabStart('%line')",
    "Run the focused avoidance matrix: merc_wall_lab [caseNumberOrName]. Stand still, face open ground")
mercenaries:DevCommand("merc_wall_lab_broad",  "mercenaries:LabStartSet('broad', '%line')",
    "Run the original broad sweep instead")
mercenaries:DevCommand("merc_wall_lab_phys",   "mercenaries:LabStartSet('phys', '%line')",
    "Run the physics/collision-class set (what F11 runs)")
mercenaries:DevCommand("merc_wall_lab_binds",  "mercenaries:LabStartSet('binds', '%line')",
    "Run the AI-bind probe set: what the engine answers and accepts")
mercenaries:DevCommand("merc_wall_lab_see",    "mercenaries:LabStartSet('see', '%line')",
    "Does the engine's walkability query see a spawned wall? (distance-controlled)")
mercenaries:DevCommand("merc_wall_lab_danger", "mercenaries:LabStartSet('danger', '%line')",
    "AI.RegisterDamageRegion: ask the PATHFINDER to route around the wall")
mercenaries:DevCommand("merc_wall_lab_solid",  "mercenaries:LabStartSet('solid', '%line')",
    "Collider modes: is the wall solid, and why does the NPC's own body not resolve against it?")
mercenaries:DevCommand("merc_wall_lab_solid2", "mercenaries:LabStartSet('solid2', '%line')",
    "Isolate ac_disableLivingVsRigidCollisions: which cvar, can it be scoped, can it be armed late")
mercenaries:DevCommand("merc_wall_lab_tries",  "mercenaries:LabSetRepeats(%line)",
    "Trials per case (default 3): merc_wall_lab_tries <n>")
mercenaries:DevCommand("merc_wall_lab_stop",   "mercenaries:LabStop()",
    "Abort the run and put every cvar back")
mercenaries:DevCommand("merc_wall_lab_report", "mercenaries:LabReport()",
    "Print the results of the last run")
mercenaries:DevCommand("merc_wall_lab_cases",  "mercenaries:LabList()",
    "List the cases the matrix will try")
mercenaries:DevCommand("merc_wall_lab_show",   "mercenaries:LabShow(%line)",
    "Build one case's wall and leave it standing so you can look at it: merc_wall_lab_show [caseNumberOrName]")
mercenaries:DevCommand("merc_wall_lab_clear",  "mercenaries:LabClearWall()",
    "Remove a wall left standing by merc_wall_lab_show")

-- The harness keys exist only under -devmode: a shipped mod must not take F11 and
-- numpad-9 off every player for a test rig.
do
    local devmode = false
    pcall(function() devmode = System.IsDevModeEnable() end)
    if devmode then
        pcall(function() System.ExecuteCommand("bind f11 merc_wall_lab_auto") end)
        pcall(function() System.ExecuteCommand("bind np_9 merc_wall_lab_auto") end)
    end
end
