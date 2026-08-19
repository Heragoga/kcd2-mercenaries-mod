-- TEMPORARY test NPC. One soul on its own minimal brain (testnpc_brain ->
-- testnpc_scheduler.xml): it targets the player and attacks, and does nothing else.
-- It is the subject for working out whether an NPC's movement can be steered while it
-- is in combat, which is the prerequisite for a superimposed navmesh of our own.
-- Delete this file, its brain rows and data/AI/testnpc_scheduler.xml when done.

mercenaries.TestNpcSoul = "f1e2d3c4-0003-4a00-8b00-000000000003"
mercenaries.TestNpcs = {}

-- Retreat rule, read by testnpc_combat.xml: once the player is inside CloseRange the
-- combat branch is failed out, a spot up to RetreatRange away is picked, and he runs
-- there before re-engaging. MinRange keeps the spot far enough to be an obvious run
-- rather than a shuffle.
mercenaries.TestNpcCloseRange   = 3.0
mercenaries.TestNpcRetreatRange = 10.0
mercenaries.TestNpcRetreatMin   = 4.0

-- Who is mid-retreat, keyed by entity id. While a NPC is in here the scheduler must
-- not re-fire anything: every AddInterrupt carries IgnorePriorityOnPreviousInterrupt,
-- so a second fire RESTARTS the retreat tree and its Move never finishes - which is
-- why he only twitched while "retreat interrupt fired" repeated in the log. Combat
-- re-aggro is suppressed the same way, so nothing competes for movement until the run
-- is over.
mercenaries.TestNpcRetreating = {}

local function retreatKey(ent)
    return ent and tostring((ent.this and ent.this.id) or ent.id) or nil
end

function mercenaries:TestNpcSetRetreating(ent, on)
    local k = retreatKey(ent)
    if not k then return end
    self.TestNpcRetreating[k] = on and true or nil
    System.LogAlways("[TestNpc] retreating = " .. tostring(on and true or false))
end

function mercenaries:IsTestNpcRetreating(ent)
    local k = retreatKey(ent)
    return (k ~= nil) and (self.TestNpcRetreating[k] == true)
end

-- Sets data.tooClose and data.retreating for the scheduler loops (2D distance - a
-- height difference should not count as "he reached me").
function mercenaries:TestNpcCheckClose(data, ent)
    data.tooClose = false
    data.retreating = self:IsTestNpcRetreating(ent)
    if data.retreating then return end        -- no new decisions while running away
    if not (ent and player) then return end
    local p, q
    pcall(function() p = ent:GetWorldPos(); q = player:GetWorldPos() end)
    if not (p and q) then return end
    local dx, dy = q.x - p.x, q.y - p.y
    if (dx * dx + dy * dy) < (self.TestNpcCloseRange * self.TestNpcCloseRange) then
        data.tooClose = true
    end
end

-- Picks the run-away spot and hands it to the Move node through data.retreatPos.
--
-- The vec3 must be filled COMPONENT-WISE. `data.retreatPos = {x=..,y=..,z=..}`
-- replaces the engine's vec3 with a plain Lua table, the Move node then reads no
-- destination and fails on the spot - which is why the NPC only paused for the
-- retreat tree's one-second wait and went straight back to fighting. camp_actor.xml
-- (the mod's own working movement) assigns .x/.y/.z one at a time; same here.
function mercenaries:TestNpcPickRetreat(data, ent)
    if not ent then return end
    local p
    pcall(function() p = ent:GetWorldPos() end)
    if not p then return end
    local a = math.random() * math.pi * 2
    local r = self.TestNpcRetreatMin + math.random() * (self.TestNpcRetreatRange - self.TestNpcRetreatMin)
    local dest = { x = p.x + math.cos(a) * r, y = p.y + math.sin(a) * r, z = p.z }
    if self.CampSnapToGround then dest = self:CampSnapToGround(dest) end

    data.retreatPos.x = dest.x
    data.retreatPos.y = dest.y
    data.retreatPos.z = dest.z
    data.tooClose = false
    System.LogAlways(string.format("[TestNpc] player within %.1fm -> running %.1fm to (%.1f, %.1f, %.1f)",
        self.TestNpcCloseRange, r, dest.x, dest.y, dest.z))
end

function mercenaries:SetTestNpcRanges(close, far)
    if close and close ~= "" and tonumber(close) then self.TestNpcCloseRange = tonumber(close) end
    if far and far ~= "" and tonumber(far) then self.TestNpcRetreatRange = tonumber(far) end
    System.LogAlways(string.format("[TestNpc] close %.1fm, retreat up to %.1fm",
        self.TestNpcCloseRange, self.TestNpcRetreatRange))
end

function mercenaries:SpawnTestNpc(dist)
    if not player then return end
    dist = tonumber(dist) or 8.0
    local o = player:GetWorldPos()
    local ang; pcall(function() ang = player:GetWorldAngles() end)
    local yaw = (ang and ang.z) or 0
    local pos = { x = o.x + math.cos(yaw) * dist, y = o.y + math.sin(yaw) * dist, z = o.z }
    if self.CampSnapToGround then pos = self:CampSnapToGround(pos) end

    local name = "SpawnedTestNpc_" .. tostring(math.random(10000, 99999)) .. "_" .. self.TestNpcSoul
    local ent
    local ok, err = pcall(function()
        System.SpawnEntity({
            class = "NPC",
            name = name,
            position = pos,
            orientation = { x = 0, y = 0, z = yaw + math.pi },
            properties = { guidSharedSoulId = self.TestNpcSoul },
        })
        ent = System.GetEntityByName(name)
        -- a weapon, or he closes in and has nothing to swing
        if ent and self.EquipEnemy then self:EquipEnemy(ent, "looter", false) end
    end)
    if not ok then System.LogAlways("[TestNpc] spawn error: " .. tostring(err)) end
    if ent then
        table.insert(self.TestNpcs, ent)
        System.LogAlways("[TestNpc] spawned '" .. name .. "' " .. dist .. "m ahead - he should come at you")
    else
        System.LogAlways("[TestNpc] spawn FAILED")
    end
    return ent
end

function mercenaries:ClearTestNpcs()
    local n = 0
    for _, e in ipairs(self.TestNpcs or {}) do
        pcall(function() System.RemoveEntity(e.id) end)
        n = n + 1
    end
    self.TestNpcs = {}
    System.LogAlways("[TestNpc] removed " .. n)
end

-- Where is he and what is he doing? For watching movement while combat runs.
function mercenaries:TestNpcState()
    for i, e in ipairs(self.TestNpcs or {}) do
        pcall(function()
            local p = e:GetWorldPos()
            local spd; pcall(function() spd = e:GetSpeed() end)
            local st;  pcall(function() st = e.actor:GetCurrentAnimationState() end)
            System.LogAlways(string.format("[TestNpc] %d pos=(%.2f, %.2f, %.2f) speed=%s anim=%s",
                i, p.x, p.y, p.z, tostring(spd), tostring(st)))
        end)
    end
end

-- ==== WAYPOINTS ====
-- A hand-placed route for the test NPC: the first half of the custom-navmesh idea,
-- where Lua owns the path and the BT only executes legs. Waypoints are plain
-- coordinates (no entities needed - Move takes a vec3); the barrels are just so the
-- route is visible while testing.
mercenaries.NavWaypoints = {}
mercenaries.NavWpMarkerModel = "objects/manmade/common_furniture/barrels/barrel_a.cgf"
mercenaries.NavWpMarkers = {}
mercenaries.NavWalkRequested = false      -- raised by merc_wp_go, consumed by the scheduler
mercenaries.NavWalking = {}               -- [entKey] = current waypoint index while walking

function mercenaries:NavWpAdd()
    local pos = self:TowerLookedAtPos()
    if not pos then System.LogAlways("[Nav] look at solid ground first"); return end
    if self.CampSnapToGround then pos = self:CampSnapToGround(pos) end
    table.insert(self.NavWaypoints, { x = pos.x, y = pos.y, z = pos.z })
    local e
    pcall(function()
        e = System.SpawnEntity({
            class = "BasicEntity",
            name = "MercNavWp_" .. tostring(math.random(100000, 999999)),
            position = pos,
            properties = { object_Model = self.NavWpMarkerModel, bMissionCritical = false,
                           bSaved_by_game = false, bSerialize = false },
        })
    end)
    if e then table.insert(self.NavWpMarkers, e.id) end
    System.LogAlways(string.format("[Nav] waypoint %d at (%.1f, %.1f, %.1f)",
        #self.NavWaypoints, pos.x, pos.y, pos.z))
end

function mercenaries:NavWpClear()
    for _, id in ipairs(self.NavWpMarkers or {}) do pcall(function() System.RemoveEntity(id) end) end
    self.NavWpMarkers = {}
    self.NavWaypoints = {}
    self.NavWalkRequested = false
    self.NavWalking = {}
    System.LogAlways("[Nav] waypoints cleared")
end

function mercenaries:NavWpList()
    System.LogAlways("[Nav] " .. #self.NavWaypoints .. " waypoint(s):")
    for i, w in ipairs(self.NavWaypoints) do
        System.LogAlways(string.format("[Nav]   %d (%.1f, %.1f, %.1f)", i, w.x, w.y, w.z))
    end
end

function mercenaries:NavWpGo()
    if #self.NavWaypoints == 0 then System.LogAlways("[Nav] no waypoints (merc_wp_add)"); return end
    if #(self.TestNpcs or {}) == 0 then System.LogAlways("[Nav] no test NPC (merc_testnpc)"); return end
    self.NavWalkRequested = true
    System.LogAlways("[Nav] walk requested over " .. #self.NavWaypoints .. " waypoint(s)")
end

function mercenaries:NavWpStop()
    self.NavWalkRequested = false
    self.NavWalking = {}
    System.LogAlways("[Nav] walk cancelled (he finishes the leg he is on)")
end

-- Scheduler poll: raise data.walkWanted once, then drop the request so the interrupt
-- is not re-fired every tick (re-firing restarts the tree and the Move never lands -
-- the same trap the retreat experiment hit).
function mercenaries:TestNpcWalkPoll(data, ent)
    data.walkWanted = false
    if not self.NavWalkRequested then return end
    if self:IsTestNpcWalking(ent) then return end
    data.walkWanted = true
    self.NavWalkRequested = false
end

local function walkKey(ent)
    return ent and tostring((ent.this and ent.this.id) or ent.id) or nil
end

function mercenaries:IsTestNpcWalking(ent)
    local k = walkKey(ent)
    return (k ~= nil) and (self.NavWalking[k] ~= nil)
end

-- How near a corner he must be before the destination is switched to the next one.
-- Bigger = the corner is cut earlier and more smoothly; too big and he visibly skips
-- corners. The LAST waypoint uses the tighter arrive radius, since there is nothing
-- to cut to and he should actually get there.
mercenaries.NavSwitchRadius = 2.5
mercenaries.NavArriveRadius = 1.0

local function setWp(data, w)
    data.wpPos.x = w.x
    data.wpPos.y = w.y
    data.wpPos.z = w.z
end

function mercenaries:TestNpcWalkStart(data, ent)
    local k = walkKey(ent); if not k then return end
    self.NavWalking[k] = 1
    data.routeDone = false
    local w = self.NavWaypoints[1]
    if w then setWp(data, w) else data.routeDone = true end
    System.LogAlways("[Nav] walk started (" .. #self.NavWaypoints .. " waypoints)")
end

function mercenaries:TestNpcWalkEnd(ent, why)
    local k = walkKey(ent); if not k then return end
    self.NavWalking[k] = nil
    System.LogAlways("[Nav] walk ended: " .. tostring(why))
end

-- Switch the destination to the next corner BEFORE he reaches this one, so the single
-- long-running Move just retargets (destChangedThreshold) instead of completing - that
-- is what removes the stop at each waypoint.
function mercenaries:TestNpcAdvanceWaypoint(data, ent)
    local k = walkKey(ent); if not k then return end
    local i = self.NavWalking[k]
    local w = i and self.NavWaypoints[i]
    if not w then data.routeDone = true; return end

    local p
    pcall(function() p = ent:GetWorldPos() end)
    if not p then return end
    local dx, dy = w.x - p.x, w.y - p.y
    local d2 = dx * dx + dy * dy

    local isLast = (i >= #self.NavWaypoints)
    local r = isLast and self.NavArriveRadius or self.NavSwitchRadius
    if d2 > (r * r) then return end          -- not there yet, keep running

    if isLast then
        data.routeDone = true
        System.LogAlways("[Nav] final waypoint reached")
        return
    end

    i = i + 1
    self.NavWalking[k] = i
    setWp(data, self.NavWaypoints[i])
    System.LogAlways(string.format("[Nav] cornering -> waypoint %d/%d", i, #self.NavWaypoints))
end


-- Wall-aware chase: he heads for the player, going around camp walls when one is in
-- the way and straight at him when it is not. The live-target case that matters.
mercenaries.NavChaseRequested = false

function mercenaries:NavChase()
    if #(self.TestNpcs or {}) == 0 then System.LogAlways("[Nav] no test NPC (merc_testnpc)"); return end
    self.NavChaseRequested = true
    System.LogAlways("[Nav] chase requested - walk behind a wall and watch him come round")
end

function mercenaries:NavChaseStop()
    self.NavChaseRequested = false
    for _, e in ipairs(self.TestNpcs or {}) do pcall(function() self:NavGotoEnd(e, "cancelled") end) end
    System.LogAlways("[Nav] chase cancelled")
end

-- Scheduler poll; same one-shot handshake as the walk, so the interrupt is never
-- re-fired underneath a running goto.
function mercenaries:TestNpcGotoPoll(data, ent)
    data.gotoWanted = false
    if not self.NavChaseRequested then return end
    if self:IsNavGotoActive(ent) then return end
    if not player then return end
    if self:NavGotoRequest(ent, player) then data.gotoWanted = true end
end

System.AddCCommand("merc_nav_chase",      "mercenaries:NavChase()",     "Test NPC walks to you, around walls when needed")
System.AddCCommand("merc_nav_chase_stop", "mercenaries:NavChaseStop()", "Stop the chase")

System.AddCCommand("merc_wp_add",   "mercenaries:NavWpAdd()",   "Drop a waypoint where you are looking")
System.AddCCommand("merc_wp_clear", "mercenaries:NavWpClear()", "Remove all waypoints")
System.AddCCommand("merc_wp_list",  "mercenaries:NavWpList()",  "List the waypoints")
System.AddCCommand("merc_wp_go",    "mercenaries:NavWpGo()",    "Send the test NPC along the waypoints")
System.AddCCommand("merc_wp_stop",  "mercenaries:NavWpStop()",  "Cancel the walk")
System.AddCCommand("merc_wp_radius","mercenaries:SetNavRadii(%line)", "Corner smoothing: merc_wp_radius <switchM> <arriveM>")

System.AddCCommand("merc_testnpc",       "mercenaries:SpawnTestNpc(%line)", "Spawn the test NPC (no combat; walks waypoints): merc_testnpc [distance]")
System.AddCCommand("merc_testnpc_clear", "mercenaries:ClearTestNpcs()",     "Remove all test NPCs")
System.AddCCommand("merc_testnpc_state", "mercenaries:TestNpcState()",      "Log each test NPC's position, speed and animation state")
System.AddCCommand("merc_testnpc_range", "mercenaries:SetTestNpcRanges(%line)", "Retreat trigger + distance: merc_testnpc_range <closeM> <retreatM>")
