-- Patrol tester.
--
-- A sandbox for working out how bandit and soldier patrols should move: drop waypoints,
-- spawn a leader with a body of men formed up around him, and send them walking the
-- route. Nothing here is player-facing yet.
--
-- The TESTER must not fight the player. It shares patrol_scheduler.xml with the roaming
-- gangs, which do fight, so the tree's combat arms are gated on $patrolFights - set by
-- PatrolRole, true only for a man belonging to a live roaming record.
--
-- An earlier flag-gate attempt is on record as having failed (docs/patrols.md), but that
-- one gated Lua while the tester souls still sat on renegade_brain, whose own scheduler
-- arms were never gated. patrol_brain now maps only to patrol_scheduler.xml, so these two
-- arms are the only reachable combat path.
--
-- Belt and braces on top: the souls stay on testFaction (friendly to the player and the
-- mercs), the names are SpawnedPatrol_ rather than SpawnedEnemy_ so IsModEnemyName does
-- not match, and weapons are sheathed on spawn. The bandit/soldier LOOK comes from
-- EquipEnemy, which is clothing and weapons only and has nothing to do with faction.
--
-- Movement is testnpc_walk.xml's mechanism for the leader, and a CrimeFollower chain for
-- the rest (patrol_follow.xml); see docs/patrols.md.

local function pLog(s) System.LogAlways("[Patrol] " .. s) end
local function pKey(ent) return ent and tostring((ent.this and ent.this.id) or ent.id) or nil end

mercenaries.PatrolPoints  = {}      -- { {x,y,z, ent=} } in the order they were dropped
mercenaries.PatrolLeader  = nil
mercenaries.PatrolMembers = {}      -- followers only, leader excluded
mercenaries.PatrolIndex   = 1
mercenaries.PatrolActive  = false

mercenaries.PatrolLineSpacing = 1.8    -- shoulder to shoulder within a rank
mercenaries.PatrolRankBack    = 2.5    -- first rank this far behind the leader
mercenaries.PatrolRankGap     = 2.2    -- and the second rank this far behind the first
mercenaries.PatrolSwitchR     = 7.0    -- take the next waypoint this far out, so the Move never ends
mercenaries.PatrolEpoch       = 0      -- bumped on respawn so followers re-join
mercenaries.PatrolWidth       = 2          -- files 2 = double column
mercenaries.PatrolLoop        = true       -- run the route round and round
mercenaries.PatrolStuckSecs   = 6.0        -- no progress for this long: give up on the waypoint
mercenaries.PatrolStuckGain   = 0.75       -- ...where "progress" means closing by this much

-- Souls on testFaction carrying patrol_brain. Cycled so a patrol is not copies of one man;
-- see libs/tables/rpg/soul__mercenaries.xml.
mercenaries.PatrolSouls = {
    "f1e2d3c4-0010-4a00-8b00-000000000011",
    "f1e2d3c4-0010-4a00-8b00-000000000012",
    "f1e2d3c4-0010-4a00-8b00-000000000013",
    "f1e2d3c4-0010-4a00-8b00-000000000014",
}
mercenaries.PatrolSoulIdx = 0
mercenaries.PatrolBest    = {}   -- [patrolKey] = stuck-detector state
mercenaries.PatrolChainOf = {}   -- [followerKey] = "targetKey@epoch", the order he is under

-- ==== waypoints ====
function mercenaries:PatrolAddWaypoint()
    local pos = self:TowerLookedAtPos()
    if not pos then pLog("look at solid ground first"); return end
    if self.CampSnapToGround then pos = self:CampSnapToGround(pos) end
    -- Nudge onto ground an NPC can stand on. A point more than ~2m off the navmesh makes
    -- every path request fail, and the leader then spams the log without moving.
    if self.FindValidGround then pos = self:FindValidGround(pos, pos.z) end

    local wp = { x = pos.x, y = pos.y, z = pos.z }
    pcall(function()
        local e = System.SpawnEntity({
            class = "BasicEntity",
            name = "MercPatrolWP_" .. tostring(math.random(100000, 999999)),
            position = wp,
            properties = { object_Model = "objects/manmade/common_furniture/barrels/barrel_a.cgf",
                           bMissionCritical = false, bSaved_by_game = false, bSerialize = false },
        })
        wp.ent = e
    end)
    table.insert(self.PatrolPoints, wp)
    pLog("waypoint " .. #self.PatrolPoints .. " placed")
end

-- Who each man walks behind. The follow CHAIN the mod used before (AssignNpcFormation):
-- the first PatrolWidth men follow the leader, and everyone after follows the man
-- PatrolWidth places ahead - so man 3 walks behind man 1 and man 4 behind man 2, which is
-- a double column. Returns the entity to follow and which file he is in.
-- Who this man walks behind, within his own patrol. The first PatrolWidth men follow the
-- leader; everyone after follows the man PatrolWidth places ahead, giving two files.
-- leader/members are optional: pass them when the caller already has a PatrolCtx result
-- (see PatrolFollowRole/PatrolChainPoll) to avoid asking PatrolCtx again.
function mercenaries:PatrolChain(ent, leader, members)
    if leader == nil then leader, members = self:PatrolCtx(ent) end
    if not leader then return nil, 0 end
    local idx
    for i, e in ipairs(members or {}) do
        if pKey(e) == pKey(ent) then idx = i break end
    end
    if not idx then return nil, 0 end

    local w = math.max(1, self.PatrolWidth or 2)
    local slot = idx - 1
    local file = slot % w
    if slot < w then return leader, file end
    return (members[slot - w + 1] or leader), file
end

function mercenaries:PatrolClearWaypoints()
    for _, wp in ipairs(self.PatrolPoints) do
        if wp.ent then pcall(function() System.RemoveEntity(wp.ent.id) end) end
    end
    self.PatrolPoints = {}
    self.PatrolIndex = 1
    pLog("waypoints cleared")
end

-- ==== the men ====
-- Where the i-th of n stands at spawn. Two FILES going back, not two ranks abreast, so
-- the block starts in the same double column the chain will march in - man 1 and 2 behind
-- the leader, 3 and 4 behind them, and so on.
function mercenaries:PatrolSlot(i, n)
    local w    = math.max(1, self.PatrolWidth or 2)
    local file = (i - 1) % w
    local row  = math.floor((i - 1) / w)
    local lat  = (file - (w - 1) / 2) * self.PatrolLineSpacing
    local back = self.PatrolRankBack + row * self.PatrolRankGap
    return back, lat
end

function mercenaries:PatrolSpawn(line)
    local a = {}
    for w in tostring(line or ""):gmatch("%S+") do a[#a + 1] = w end
    local count = tonumber(a[1]) or 6
    local group = (a[2] ~= nil and a[2] ~= "") and a[2] or "bandit"

    if not player then return end
    if not self.EnemyGroups[group] then
        local names = {}
        for k in pairs(self.EnemyGroups) do table.insert(names, k) end
        table.sort(names)
        pLog("unknown group '" .. tostring(group) .. "' - try: " .. table.concat(names, ", "))
        return
    end

    self:PatrolClearMen()

    local o = player:GetWorldPos()
    local ang; pcall(function() ang = player:GetWorldAngles() end)
    local yaw = (ang and ang.z) or 0
    local fx, fy = math.cos(yaw), math.sin(yaw)
    local rx, ry = -fy, fx

    -- the leader stands 10m ahead of the player, his men formed up behind him
    local lead = { x = o.x + fx * 10, y = o.y + fy * 10, z = o.z }
    if self.FindValidGround then lead = self:FindValidGround(lead, o.z) end

    local function spawnOne(pos)
        local soul = self.PatrolSouls[(self.PatrolSoulIdx % #self.PatrolSouls) + 1]
        self.PatrolSoulIdx = self.PatrolSoulIdx + 1
        local name = "SpawnedPatrol_" .. tostring(math.random(10000, 99999)) .. "_" .. soul
        local e
        local ok, err = pcall(function()
            System.SpawnEntity({
                class = "NPC",
                name = name,
                position = pos,
                orientation = { x = 0, y = 0, z = yaw },
                properties = { guidSharedSoulId = soul },
            })
            e = System.GetEntityByName(name)
            -- dress him as the requested group; appearance is independent of faction
            if e and self.EquipEnemy then self:EquipEnemy(e, group, false) end
            -- nothing in patrol_scheduler.xml ever draws a weapon, so put it away: a
            -- patrol walking about with steel out reads as hostile even when it is not
            if e and e.actor then pcall(function() e.actor:DrawWeapon(false) end) end
        end)
        if not ok then pLog("spawn error: " .. tostring(err)) end
        return e
    end

    self.PatrolLeader = spawnOne(lead)
    if not self.PatrolLeader then pLog("leader failed to spawn"); return end

    self.PatrolMembers = {}
    for i = 1, count do
        local back, lat = self:PatrolSlot(i, count)
        local p = { x = lead.x - fx * back + rx * lat, y = lead.y - fy * back + ry * lat, z = lead.z }
        if self.FindValidGround then p = self:FindValidGround(p, lead.z) end
        local e = spawnOne(p)
        if e then table.insert(self.PatrolMembers, e) end
    end

    self.PatrolIndex = 1
    self.PatrolActive = false
    self.PatrolEpoch = (self.PatrolEpoch or 0) + 1   -- new body of men: re-issue the follow orders
    self:PatrolStart()
    pLog(string.format("leader + %d %s formed up (merc_patrol_go to walk the route)",
        #self.PatrolMembers, group))
end

function mercenaries:PatrolClearMen()
    local n = 0
    if self.PatrolLeader then
        pcall(function() System.RemoveEntity(self.PatrolLeader.id) end); n = n + 1
    end
    for _, e in ipairs(self.PatrolMembers or {}) do
        pcall(function() System.RemoveEntity(e.id) end); n = n + 1
    end
    self.PatrolLeader, self.PatrolMembers = nil, {}
    self.PatrolChainOf = {}
    self.PatrolActive = false
    if n > 0 then pLog("removed " .. n .. " patrol NPC(s)") end
end

function mercenaries:PatrolClearAll()
    self:PatrolClearMen()
    self:PatrolClearWaypoints()
end

-- ==== marching ====
function mercenaries:PatrolIsMember(ent)
    return self:PatrolCtx(ent) ~= nil
end

function mercenaries:PatrolGo()
    if not self.PatrolLeader then pLog("nobody to send - merc_patrol_spawn first"); return end
    if #self.PatrolPoints == 0 then pLog("no waypoints - merc_patrol_wp first"); return end
    self.PatrolIndex = 1
    self.PatrolActive = true
    self._patrolBestD = nil
    pLog("marching, " .. #self.PatrolPoints .. " waypoint(s)" .. (self.PatrolLoop and ", looping" or ""))
end

function mercenaries:PatrolStop()
    self.PatrolActive = false
    pLog("halted")
end

-- BT hook: who this man is, and whether the patrol is marching.
-- BT hook: who this man is, and whether his patrol is marching.
function mercenaries:PatrolRole(data, ent)
    data.isPatrol       = false
    data.isPatrolLeader = false
    data.patrolWalking  = false
    data.patrolFights   = false      -- set before the early return below, not after

    local leader, _, pts, _, rec = self:PatrolCtx(ent)
    if not leader then return end

    data.isPatrol       = true
    data.isPatrolLeader = (pKey(ent) == pKey(leader))

    if data.followEpoch ~= (self.PatrolEpoch or 0) then
        data.followFired = false
        data.followEpoch = self.PatrolEpoch or 0
    end

    -- either behaviour ended for any reason: issue it again
    local k = pKey(ent)
    if k and self.PatrolRefire and self.PatrolRefire[k] then
        self.PatrolRefire[k] = nil
        data.followFired = false
    end
    if k and self.PatrolRefireWalk and self.PatrolRefireWalk[k] then
        self.PatrolRefireWalk[k] = nil
        data.walkFired = false
    end

    -- a roaming patrol always marches; the tester waits for merc_patrol_go
    if rec then
        data.patrolWalking = (pts ~= nil and #pts > 0)
        data.patrolFights  = true    -- roaming gangs fight; the tester never does
    else
        data.patrolWalking = (self.PatrolActive == true)
    end
end

-- Does this man hold a live combat claim? patrol_scheduler.xml acquires through
-- FindEnemyTarget, so the claim lives in EnemyTargetOf.
function mercenaries:PatrolHasTarget(ent)
    local k = pKey(ent)
    return (k ~= nil) and (self.EnemyTargetOf ~= nil) and (self.EnemyTargetOf[k] ~= nil)
end

-- Holding a claim is what stands a patrolman down off his route, so a claim that never turns
-- into an actual fight stops him for good - he neither walks nor swings. That is the "the
-- patrol always stops when it gets near me" case: something claimed the player, the route
-- yielded, and combat never started.
--
-- So a claim has a grace period. Hold one for longer than PatrolEngageGrace without being in
-- a combat context and it is written off: the claim is dropped, the route resumes, and
-- FindEnemyTarget is free to pick again on the next pass.
mercenaries.PatrolEngageGrace = 5.0

function mercenaries:PatrolClaimStalled(ent)
    local k = pKey(ent)
    if not k or not self:PatrolHasTarget(ent) then
        if k then self.PatrolClaimAt = self.PatrolClaimAt or {}; self.PatrolClaimAt[k] = nil end
        return false
    end

    local inCombat = false
    pcall(function() inCombat = ent.soul:HasScriptContext("crime_interruptAttack") end)

    self.PatrolClaimAt = self.PatrolClaimAt or {}
    local now = 0; pcall(function() now = System.GetCurrTime() or 0 end)

    if inCombat then self.PatrolClaimAt[k] = nil; return false end
    if not self.PatrolClaimAt[k] then self.PatrolClaimAt[k] = now; return false end
    if (now - self.PatrolClaimAt[k]) < self.PatrolEngageGrace then return false end

    -- Written off. Drop the claim so he is not pinned, and take the gang alert's forced
    -- target with it or FindEnemyTarget would simply hand the same one straight back.
    self.PatrolClaimAt[k] = nil
    if self.EnemyTargetOf then self.EnemyTargetOf[k] = nil end
    if self.EnemyClaimWuid then self.EnemyClaimWuid[k] = nil end
    if self.ForcedTargetOf then self.ForcedTargetOf[k] = nil end
    pLog("a man could not engage his target - dropping it and walking on")
    return true
end

-- The route yields only to a claim that is actually turning into a fight.
function mercenaries:PatrolYieldToCombat(ent)
    if not self:PatrolHasTarget(ent) then return false end
    if self:PatrolClaimStalled(ent) then return false end
    return true
end

-- BT hook: start of a walk. Seeds the destination so the Move has somewhere to go on its
-- very first evaluation.
-- BT hook for patrol_follow.xml: refresh who this man walks behind, and end the
-- behaviour when he is no longer a follower at all.
-- BT hook for patrol_follow.xml: refresh who this man walks behind.
function mercenaries:PatrolFollowRole(data, ent)
    data.stillFollowing = false
    -- Same rule as the leader's walk: hand the interrupt slot to combat.
    if self:PatrolYieldToCombat(ent) then return end
    local leader, members = self:PatrolCtx(ent)
    if not leader then return end
    if pKey(ent) == pKey(leader) then return end

    local tgt, file = self:PatrolChain(ent, leader, members)
    if not tgt then return end

    data.followTarget   = (tgt.this and tgt.this.id) or tgt.id
    data.crimeRole      = file            -- 0 = Main, 1 = Assist: the two chain files
    data.stillFollowing = true

    -- baseline for PatrolChainPoll, so the watcher does not fire on the order it was
    -- just given and restart the node it is meant to leave alone
    self.PatrolChainOf = self.PatrolChainOf or {}
    self.PatrolChainOf[pKey(ent)] = pKey(tgt) .. "@" .. tostring(self.PatrolEpoch or 0)
end

-- BT hook: has anything about this man's orders actually changed since the CrimeFollower
-- node started? Only a real change ends the node - restarting it makes him dash to
-- re-acquire his station, so restarting on a timer produced a catch-up sprint on every
-- tick of that timer.
-- BT hook: has this man's order actually changed since the CrimeFollower node started?
-- Only a real change ends the node - restarting it makes him dash to re-acquire his
-- station, so ending it on a timer produced a catch-up sprint on every tick of that timer.
function mercenaries:PatrolChainPoll(data, ent)
    data.chainChanged = false
    if self:PatrolYieldToCombat(ent) then data.stillFollowing = false; return end
    local leader, members = self:PatrolCtx(ent)
    if not leader then data.stillFollowing = false; return end
    if pKey(ent) == pKey(leader) then data.stillFollowing = false; return end

    local tgt = self:PatrolChain(ent, leader, members)
    if not tgt then data.stillFollowing = false; return end

    local k = pKey(ent)
    self.PatrolChainOf = self.PatrolChainOf or {}
    local want = pKey(tgt) .. "@" .. tostring(self.PatrolEpoch or 0)
    if self.PatrolChainOf[k] ~= want then
        self.PatrolChainOf[k] = want
        data.chainChanged = true
    end
end

mercenaries.PatrolRefire     = {}   -- [manKey] = true: his follow behaviour ended, re-issue it
mercenaries.PatrolRefireWalk = {}   -- [manKey] = true: his walk behaviour ended, re-issue it

function mercenaries:PatrolFollowEnd(ent)
    -- The scheduler latches followFired so it does not re-fire every second, and that latch
    -- is never cleared on its own. Anything that ends this behaviour - combat replacing it,
    -- a failed move, the leader dying - would therefore leave the man standing for good.
    -- Flag him so PatrolRole re-arms the fire.
    local k = pKey(ent)
    if k then
        self.PatrolRefire = self.PatrolRefire or {}
        self.PatrolRefire[k] = true
    end
end

-- Same re-arm as the followers': the scheduler latches walkFired, and combat replacing
-- this behaviour would otherwise leave the leader standing for good once the fight ended.
function mercenaries:PatrolWalkEnd(ent)
    local k = pKey(ent)
    if k then
        self.PatrolRefireWalk = self.PatrolRefireWalk or {}
        self.PatrolRefireWalk[k] = true
    end
end

function mercenaries:PatrolWalkStart(data, ent)
    data.routeDone = false
    self:PatrolWalkTick(data, ent)
end

-- BT hook, every 150ms: advance the route and rewrite the destination IN PLACE.
--
-- The waypoint is taken at PatrolSwitchR, comfortably before he reaches it, so the Move
-- node never arrives and never ends - the loop around it would otherwise restart it from
-- a standstill, which is the stop every few metres. Same mechanism as testnpc_walk.xml.
-- BT hook, every 150ms: advance along the route and rewrite the destination IN PLACE.
--
-- The next point is taken at PatrolSwitchR, comfortably before he reaches it, so the Move
-- never arrives and never ends - the loop around it would otherwise restart it from a
-- standstill, which is the stop every few metres. Same mechanism as testnpc_walk.xml.
function mercenaries:PatrolWalkTick(data, ent)
    -- The route YIELDS to a fight, and does so from the inside. patrol_walk is the
    -- incumbent interrupt at a HIGHER priority than combat_melee, so whether the
    -- combat fire can evict it is uncertain (see docs/patrols.md); ending the walk
    -- ourselves the moment a target is claimed frees the slot either way, and is
    -- what stops the leader marching straight through a fight. The scheduler
    -- re-fires the walk once FindEnemyTarget drops the target again.
    if self:PatrolYieldToCombat(ent) then data.routeDone = true; return end

    local leader, _, pts, idx, rec = self:PatrolCtx(ent)
    if not (leader and pts and #pts > 0) then data.routeDone = true; return end
    if (not rec) and (not self.PatrolActive) then data.routeDone = true; return end

    local wp = pts[idx]
    if not wp then data.routeDone = true; return end

    local p; pcall(function() p = ent:GetWorldPos() end)
    if p then
        local dx, dy = wp.x - p.x, wp.y - p.y
        local d = math.sqrt(dx * dx + dy * dy)

        -- Unreachable point (off the navmesh, across water, inside geometry): the Move
        -- fails every tick and he stands there. Watch for no progress and move on.
        local now = 0; pcall(function() now = System.GetCurrTime() or 0 end)
        local key = tostring(rec and rec.key or "tester")
        self.PatrolBest = self.PatrolBest or {}
        local b = self.PatrolBest[key]
        if (not b) or b.idx ~= idx or d < (b.d - self.PatrolStuckGain) then
            self.PatrolBest[key] = { d = d, idx = idx, at = now }
        elseif (now - b.at) > self.PatrolStuckSecs then
            pLog("point " .. idx .. " unreachable (" .. string.format("%.0f", d) .. "m) - skipping")
            self.PatrolBest[key] = nil
            idx = self:PatrolStepIndex(rec, #pts, idx)
            if not rec then self.PatrolIndex = idx end
            wp = pts[idx] or wp
            data.wpPos.x, data.wpPos.y, data.wpPos.z = wp.x, wp.y, wp.z
            return
        end

        -- Keep stepping until the published point is beyond the switch radius, rather
        -- than stepping once. One step is enough only while nothing else touches the
        -- index; PatrolSyncIndex does, and a single step then republishes a point the
        -- leader has already walked past - which brakes and turns him. Capped at the
        -- route length so a short or degenerate route cannot spin here.
        local steps = 0
        while steps < #pts do
            local wx, wy = wp.x - p.x, wp.y - p.y
            if (wx * wx + wy * wy) > (self.PatrolSwitchR * self.PatrolSwitchR) then break end

            local nxt = self:PatrolStepIndex(rec, #pts, idx)
            if nxt == idx then
                if (not rec) and (not self.PatrolLoop) then
                    data.routeDone = true
                    self.PatrolActive = false
                    pLog("route finished")
                    return
                end
                break
            end

            idx = nxt
            if not rec then self.PatrolIndex = nxt end
            wp    = pts[nxt] or wp
            steps = steps + 1
        end
    end

    data.wpPos.x, data.wpPos.y, data.wpPos.z = wp.x, wp.y, wp.z
end

function mercenaries:PatrolStatus()
    pLog("waypoints: " .. #self.PatrolPoints .. ", heading for " .. self.PatrolIndex ..
         ", marching: " .. tostring(self.PatrolActive))
    pLog("leader: " .. (self.PatrolLeader and "yes" or "none") ..
         ", followers: " .. #(self.PatrolMembers or {}) ..
         ", files: " .. tostring(self.PatrolWidth))
end

mercenaries:DevCommand("merc_patrol_wp",     "mercenaries:PatrolAddWaypoint()",  "Drop a patrol waypoint where you are looking")
mercenaries:DevCommand("merc_patrol_wpclear","mercenaries:PatrolClearWaypoints()","Remove the patrol waypoints")
mercenaries:DevCommand("merc_patrol_go",     "mercenaries:PatrolGo()",           "Send the patrol walking the waypoints")
mercenaries:DevCommand("merc_patrol_stop",   "mercenaries:PatrolStop()",         "Halt the patrol where it stands")
mercenaries:DevCommand("merc_patrol_status", "mercenaries:PatrolStatus()",       "Where the patrol is and what it is doing")
