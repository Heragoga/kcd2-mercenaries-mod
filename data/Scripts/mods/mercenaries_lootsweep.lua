-- Post-battle loot sweep.
--
-- When a fight near the player ends, idle mercs wander the bodies, kneel and
-- rummage. Nothing is transferred - it is pure theatre.
--
-- It rides the camp ACTIVITY pipeline rather than a behaviour module of its own:
-- this tick writes records into LootActivities, GetCampActivity hands them to
-- camp_actor.xml ahead of any real camp role, and mode 2 (walk, face, play an
-- unstance) does the work. A custom ContinuousSwitch case was tried for the camp
-- smith and never fired reliably - see docs/camp-forge.md.
--
-- Mercs finishing bodies off was attempted at length and is impossible: the mercy
-- kill is a player-only action, and no unstance reads as a killing blow. The
-- measurements are in docs/loot-sweep.md so nobody retries it.

local function nowT() local t = 0; pcall(function() t = System.GetCurrTime() or 0 end); return t end

mercenaries.LootSweepEnabled = true
mercenaries.LootPlayerRadius = 20.0    -- player must stay this close to the battle site
mercenaries.LootCorpseRadius = 30.0    -- bodies within this of the battle site are captured
-- ...but a body is only ever handed out if it is also this close to the PLAYER.
-- Everything bad about wandering mercs is a distance problem: the 20m melee
-- disengage in UpdateMeleeCombatData, the 35m follow self-heal that restarts the
-- behaviour mid-animation, the 50m straggler teleport, and AI LOD. Staying inside
-- the 18m enemy-scan radius also means a looter jumped by a straggler is actually
-- able to acquire it.
mercenaries.LootMercRange    = 18.0
mercenaries.LootWindow       = 150.0   -- seconds the sweep stays open once opened
mercenaries.LootSettleDelay  = 5.0     -- quiet seconds before it opens (weapons go away first)
mercenaries.LootMaxSweepers  = 8       -- most mercs out on the field at once
mercenaries.LootStandOff     = 1.1     -- metres short of the body the merc stops
mercenaries.LootArriveDist   = 2.5     -- counts as standing over the body
-- Seconds held on a body once he arrives. Sized to mode 2's hold (Wait 8s +- 3s,
-- so 5-11s) and deliberately NOT longer than it: at 15s the merc finished the
-- rummage and then stood over the body for the remainder, because re-entering an
-- unstance he is already in does not replay it. Cutting the tail of a long roll is
-- the better trade - the sweep is scenery, and standing still reads as broken.
mercenaries.LootDwell        = 9.0
-- Give up on a body he cannot reach. Short, because the failure mode looks exactly
-- like the bug it prevents: a merc pathing at something unreachable is a merc
-- standing about. Anything inside LootMercRange is ~18m, so 12s is generous.
mercenaries.LootWalkTimeout  = 12.0

-- Camp-activity records handed to camp_actor via GetCampActivity. Same shape as
-- CampActivities plus the sweep's own bookkeeping fields.
mercenaries.LootActivities = {}        -- [mercWuidStr] = { unstance, mode, pos, facePos, corpse, wuid, startedAt }
mercenaries.LootClaims  = {}           -- [corpseWuidStr] = mercWuidStr
mercenaries.LootVisited = {}           -- [corpseWuidStr] = true, so a body is worked once
mercenaries.LootBodies  = {}           -- captured once when the fight ends: { ent, wuid }
mercenaries.LootBattle  = nil          -- { x, y, z, opensAt, expiresAt }

mercenaries._lootAnchor   = nil        -- centroid of the live enemies, while they live
mercenaries._lootFighting = false

-- Whose bodies a merc will strip. IsModEnemyName alone missed the roaming patrols: they
-- are named SpawnedPatrolman_ ON PURPOSE, because IsModEnemyName also enrols an NPC in the
-- raid and wall-battle systems. Looting needs its own, wider test.
function mercenaries:IsLootableCorpseName(name)
    if not name or name == '' then return false end
    if self:IsModEnemyName(name) then return true end
    return string.find(name, 'SpawnedPatrolman_', 1, true) ~= nil
end

local function dist2(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return dx * dx + dy * dy + dz * dz
end

-- Positive death test. Deliberately NOT `not IsAliveAndWell(...)`: that also
-- returns true for a missing actor/soul or a failed GetState, which would put
-- half-loaded entities on the corpse list.
function mercenaries:IsCorpse(ent)
    if not ent or not ent.actor or not ent.soul then return false end
    local dead = false
    pcall(function()
        if ent.actor.IsDead and ent.actor:IsDead() then dead = true end
    end)
    if not dead then
        local ok, hp = pcall(function() return ent.soul:GetState('health') end)
        if ok and hp ~= nil and hp <= 0 then dead = true end
    end
    return dead
end

-- One full-class scan, once, at the moment the fight ends. GetEntitiesByClass is
-- the call confirmed to enumerate corpses (see docs/npc-lod.md's world census);
-- it is expensive, so the result is held for the whole sweep and never refreshed.
function mercenaries:LootCaptureBodies(anchor)
    local out = {}
    if not anchor then return out end
    local r2 = self.LootCorpseRadius * self.LootCorpseRadius
    pcall(function()
        local ents = System.GetEntitiesByClass('NPC')
        if not ents then return end
        for _, ent in pairs(ents) do
            if ent and self:IsLootableCorpseName(ent:GetName() or '') and self:IsCorpse(ent) then
                local ep = ent:GetPos()
                if ep and dist2(ep, anchor) <= r2 then
                    table.insert(out, { ent = ent, wuid = (ent.this and ent.this.id) or ent.id })
                end
            end
        end
    end)
    return out
end

-- Mercs eligible to wander off: alive, not fighting, not mounted. Camp actors are
-- included on purpose - a raid on the camp leaves bodies in it, and a loot record
-- outranks their camp role for as long as it exists.
--
-- Note a loot record makes IsCampActor true, which makes IsFormationEligible
-- false, so a looter drops out of the marching formation (and out of the running
-- for formation leader) exactly the way an in-camp merc does. That is the whole
-- reason this rides the camp pipeline instead of a module of its own.
function mercenaries:LootEligibleMercs()
    local out = {}
    for _, ent in pairs(self.ActiveMercs) do
        if ent and self:IsAliveAndWell(ent, false) then
            local skip = false
            -- Re-firing a follow-family behaviour on a mounted merc throws him off
            -- the horse; leave riders alone entirely.
            pcall(function()
                if ent.soul:HasScriptContext("crime_interruptAttack") then skip = true end
                if ent.human and ent.human:IsMounted() then skip = true end
            end)
            if not skip then
                table.insert(out, { ent = ent, wuid = (ent.this and ent.this.id) or ent.id })
            end
        end
    end
    return out
end

function mercenaries:LootSweepClear()
    self.LootActivities = {}
    self.LootClaims = {}
    self.LootVisited = {}
    self.LootBodies = {}
    self.LootBattle = nil
end

-- Drop one merc's task; the body is marked worked so nobody comes back to it.
function mercenaries:LootTaskDone(mercWuid)
    local k = tostring(mercWuid)
    local t = self.LootActivities[k]
    if t and t.corpse then
        local ck = tostring(t.corpse)
        self.LootVisited[ck] = true
        self.LootClaims[ck] = nil
    end
    self.LootActivities[k] = nil
end

function mercenaries.LootSweepLoop()
    pcall(function() mercenaries:LootSweepTick() end)
    Script.SetTimerForFunction(1000, "mercenaries.LootSweepLoop")
end

function mercenaries:LootSweepTick()
    local t = nowT()

    -- A staged wall battle owns the squad's movement (and gates every interrupt
    -- behind wbLocked); don't compete with it.
    local staged = (self.WBPhase or "idle") ~= "idle"
    if not self.LootSweepEnabled or _G.MercenariesDismissed or staged then
        if self.LootBattle or next(self.LootActivities) then self:LootSweepClear() end
        return
    end

    -- While anything hostile is cached we are still fighting: remember where, and
    -- keep the field clear of sweepers.
    local live = self.CachedEnemies or {}
    if #live > 0 then
        local cx, cy, cz, n = 0, 0, 0, 0
        for _, e in ipairs(live) do
            local p = e.entity and e.entity:GetPos()
            if p then cx, cy, cz, n = cx + p.x, cy + p.y, cz + p.z, n + 1 end
        end
        if n > 0 then self._lootAnchor = { x = cx / n, y = cy / n, z = cz / n } end
        self._lootFighting = true
        if self.LootBattle or next(self.LootActivities) then self:LootSweepClear() end
        return
    end

    -- The tick the last hostile left the cache: capture the bodies once and
    -- re-anchor on them, rather than on wherever the last man standing was.
    if self._lootFighting then
        self._lootFighting = false
        self:LootOpen(self._lootAnchor)
    end

    local b = self.LootBattle
    if not b then return end

    if t > b.expiresAt then
        System.LogAlways('[LootSweep] Window closed.')
        self:LootSweepClear()
        return
    end
    if t < b.opensAt then return end

    -- The player wandering off ends it: this is scenery for him, not a chore.
    -- Mounting counts as leaving - he is about to ride away, and a re-fired
    -- follow would dump any mounted merc off its horse.
    local pp = player and player:GetPos()
    if not pp or _G.PlayerMounted
       or dist2(pp, b) > (self.LootPlayerRadius * self.LootPlayerRadius) then
        if next(self.LootActivities) then
            System.LogAlways('[LootSweep] Player left the field; recalling.')
        end
        self:LootSweepClear()
        return
    end

    self:LootAdvance(t)
    self:LootAssign(t, pp)
end

-- Retire tasks that are finished: arrived and dwelt long enough, gave up walking,
-- or lost their merc.
function mercenaries:LootAdvance(t)
    for mk, task in pairs(self.LootActivities) do
        local me = task.wuid and XGenAIModule.GetEntityByWUID(task.wuid)
        if not me or not self:IsAliveAndWell(me, false) then
            self:LootTaskDone(mk)
        else
            local mp = me:GetPos()
            if mp and not task.arrivedAt then
                if dist2(mp, task.pos) <= (self.LootArriveDist * self.LootArriveDist) then
                    task.arrivedAt = t
                end
            end
            if task.arrivedAt then
                if (t - task.arrivedAt) > self.LootDwell then self:LootTaskDone(mk) end
            elseif (t - task.startedAt) > self.LootWalkTimeout then
                self:LootTaskDone(mk)
            end
        end
    end
end

-- Capture the battlefield and open the window. Split out so a console command can
-- force a sweep without waiting for a real fight.
function mercenaries:LootOpen(anchor)
    if not anchor then return false end
    local bodies = self:LootCaptureBodies(anchor)
    if #bodies == 0 then return false end

    local cx, cy, cz, n = 0, 0, 0, 0
    for _, c in ipairs(bodies) do
        local p = c.ent:GetPos()
        if p then cx, cy, cz, n = cx + p.x, cy + p.y, cz + p.z, n + 1 end
    end
    if n == 0 then return false end

    local t = nowT()
    self.LootBodies = bodies
    self.LootVisited = {}
    self.LootClaims = {}
    self.LootBattle = {
        x = cx / n, y = cy / n, z = cz / n,
        opensAt = t + self.LootSettleDelay,
        expiresAt = t + self.LootSettleDelay + self.LootWindow,
    }
    System.LogAlways('[LootSweep] Battle over, ' .. tostring(n) .. ' bodies; sweep opens shortly.')
    return true
end

-- Stand spot: LootStandOff short of the body on the side the merc approaches from.
--
-- Deliberately NOT ground-validated. A body is lying on walkable ground by
-- definition, so a metre to one side of it needs no proving, and Move pathfinds
-- the last stretch anyway. FindValidGround was called here at first and cost ~80
-- raycasts per assignment (nine probes per ring, spiralling out to 2 m), every
-- one of which logged a RayWorldIntersection parameter warning - it buried the
-- log during a sweep. See docs/loot-sweep.md.
local function standSpotFor(self, mercPos, corpsePos)
    local ax, ay = mercPos.x - corpsePos.x, mercPos.y - corpsePos.y
    local len = math.sqrt(ax * ax + ay * ay)
    if len < 0.1 then ax, ay, len = 1, 0, 1 end
    ax, ay = ax / len, ay / len
    return {
        x = corpsePos.x + ax * self.LootStandOff,
        y = corpsePos.y + ay * self.LootStandOff,
        z = corpsePos.z,
    }
end

-- Hand every free eligible merc the nearest unclaimed body within reach of the player.
function mercenaries:LootAssign(t, playerPos)
    local reach2 = self.LootMercRange * self.LootMercRange
    local free, anyLeft = {}, false
    for _, c in ipairs(self.LootBodies) do
        local ck = tostring(c.wuid)
        if not self.LootVisited[ck] and not self.LootClaims[ck] and self:IsCorpse(c.ent) then
            local p = c.ent:GetPos()
            if p then
                anyLeft = true
                if dist2(p, playerPos) <= reach2 then
                    table.insert(free, { wuid = c.wuid, pos = { x = p.x, y = p.y, z = p.z } })
                end
            end
        end
    end

    local busy = 0
    for _ in pairs(self.LootActivities) do busy = busy + 1 end

    -- Nothing left anywhere and nobody still working: the sweep is finished. Bodies
    -- merely out of the player's reach don't end it - he may walk over to them.
    if not anyLeft and busy == 0 then
        System.LogAlways('[LootSweep] Field picked over.')
        self:LootSweepClear()
        return
    end

    for _, m in ipairs(self:LootEligibleMercs()) do
        if busy >= self.LootMaxSweepers or #free == 0 then break end
        local mk = tostring(m.wuid)
        if not self.LootActivities[mk] then
            local mp = m.ent:GetPos()
            if mp then
                local bestI, bestD
                for i, c in ipairs(free) do
                    local d = dist2(mp, c.pos)
                    if not bestD or d < bestD then bestI, bestD = i, d end
                end
                if bestI then
                    local pick = table.remove(free, bestI)
                    self.LootClaims[tostring(pick.wuid)] = mk
                    self.LootActivities[mk] = {
                        -- camp-activity fields, read by camp_actor.xml
                        unstance = "Loot",
                        mode = 2,
                        pos = standSpotFor(self, mp, pick.pos),
                        facePos = pick.pos,
                        -- sweep bookkeeping
                        corpse = pick.wuid,
                        wuid = m.wuid,
                        startedAt = t,
                    }
                    busy = busy + 1
                end
            end
        end
    end
end

-- Debug: open a sweep on the bodies around the player right now, no fight needed.
function mercenaries:LootSweepForce()
    local pp = player and player:GetPos()
    if not pp then return end
    self:LootSweepClear()
    if self:LootOpen(pp) then
        self.LootBattle.opensAt = nowT()
        System.LogAlways('[LootSweep] Forced sweep open.')
    else
        System.LogAlways('[LootSweep] No mod-enemy bodies within ' .. tostring(self.LootCorpseRadius) .. 'm.')
    end
end

function mercenaries:LootSweepStop()
    self:LootSweepClear()
    System.LogAlways('[LootSweep] Cleared.')
end

function mercenaries:LootSweepStatus()
    local busy = 0
    for _ in pairs(self.LootActivities) do busy = busy + 1 end
    local b = self.LootBattle
    if not b then
        System.LogAlways('[LootSweep] idle (enabled=' .. tostring(self.LootSweepEnabled) .. ')')
        return
    end
    local t = nowT()
    System.LogAlways('[LootSweep] open: bodies=' .. tostring(#self.LootBodies)
        .. ' sweeping=' .. tostring(busy)
        .. ' opensIn=' .. string.format('%.1f', b.opensAt - t)
        .. ' expiresIn=' .. string.format('%.1f', b.expiresAt - t))
end
