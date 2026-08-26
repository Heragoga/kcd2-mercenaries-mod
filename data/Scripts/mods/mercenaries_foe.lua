-- Foe AI: a self-contained hostile NPC, decoupled from the enemy/renegade systems.
--
-- Two states and nothing else:
--   idle    - not alerted. Stands around (foe_idle.xml). This is where camp life or
--             a march goes later; for the test it is a stand-and-emote loop.
--   combat  - alerted and holding a target. Runs foe_combat.xml.
--
-- Alerting is the point of the system. A foe notices a target only inside its own
-- FoeDetectRange, but the moment one does it SHOUTS, and every foe within
-- FoeAlertRange of the shouter is alerted too - so a single scout pulls a whole
-- band in at once instead of each man waking up when the fight reaches him.
--
-- Engagement latency is owned by Lua, not by the tree. FoeTick decides who should be
-- fighting; the tree reports back a heartbeat while its behaviour is actually
-- running. Anything that should be fighting and is not gets re-fired ~1s later,
-- forever. That is the structural fix for the old system's "some of them never
-- engage": there, a failed AddInterrupt was invisible and nothing retried it.
--
-- See docs/foe-ai.md.

-- ---------------------------------------------------------------------------
-- Tuning
-- ---------------------------------------------------------------------------
mercenaries.FoeTickMs      = 250     -- master tick; also the detection resolution
mercenaries.FoeDetectRange = 20.0    -- how far a foe notices a target on its own
mercenaries.FoeAlertRange  = 70.0    -- how far the shout carries to other foes
mercenaries.FoeEngageRange = 120.0   -- an alerted foe takes targets out to here, and holds him to here
mercenaries.FoeSwarmCap    = 4       -- foes allowed on one target AT ACQUISITION before spilling over
mercenaries.FoeRequireLos  = true    -- detection needs line of sight (the shout does not)
mercenaries.FoeAlertChains = false   -- true: a foe alerted BY a shout shouts on too

-- Fire/heartbeat contract with the trees.
mercenaries.FoeBeatTimeout = 2.5     -- no heartbeat for this long = the behaviour is not running
mercenaries.FoeRefireDelay = 1.0     -- minimum gap between two fire attempts on one foe

-- Who a foe may fight. Same shape as the old EnemyTargetPrefixes so encounter code
-- can extend it, but its own list: this system shares no state with that one.
mercenaries.FoeTargetPrefixes = { "SpawnedFriend_", "MercenaryCustomCompanion" }

-- Which combat automation decorators foe_combat switches on, read on every combat
-- entry. All true is vanilla's melee stack (references/AI/crime/friendlyFight.xml);
-- the point of having them here is `foe_auto <name> 0/1`, which lets a movement
-- problem be bisected in-game instead of one guess per rebuild.
mercenaries.FoeAutomation = {
    offense  = true,
    defense  = true,
    guard    = true,
    weapon   = true,   -- WeaponAutomationDecorator: only ever active on an ARMED foe
    movement = true,   -- CombatFollowerDecorator: the approach itself
}

-- Standing emotes for the idle state (all verified working in camp_actor).
mercenaries.FoeIdleEmotes = {
    "waiting_armsCrossed",
    "waiting_nervous_lookingAround_noObject",
    "Stretching",
}

-- ---------------------------------------------------------------------------
-- Roster
-- ---------------------------------------------------------------------------
-- [idStr] = {
--   ent, wuid, name, pos,
--   alerted, alertedAt, alertedBy,   -- 'self' | 'shout' | 'console'
--   shout,                           -- shout queued, consumed by foe_combat
--   target, firedTarget, firedAt, firedKind,
--   beat, beatKind,                  -- last heartbeat time + which behaviour sent it
--   engagedAt,                       -- first combat heartbeat (engagement telemetry)
--   spawnedAt,
-- }
mercenaries.Foes = {}
mercenaries.FoeLoopArmed = false

local function idOf(ent)
    if not ent then return nil end
    local id = (ent.this and ent.this.id) or ent.id
    return id and tostring(id) or nil
end

function mercenaries:FoeRecord(id, create)
    if not id then return nil end
    local k = tostring(id)
    local r = self.Foes[k]
    if r or not create then return r end
    -- Self-heal: a foe whose scheduler polls before (or without) a Lua registration
    -- still gets a record, so nothing can fall out of the system silently.
    local ent = XGenAIModule.GetEntityByWUID(id)
    if not ent then return nil end
    return self:FoeRegister(ent)
end

function mercenaries:FoeRegister(ent)
    local k = idOf(ent)
    if not k then return nil end
    if self.Foes[k] then return self.Foes[k] end
    self.Foes[k] = {
        ent = ent, wuid = (ent.this and ent.this.id) or ent.id,
        name = ent:GetName() or '',
        alerted = false, shout = false,
        beat = 0, firedAt = 0, spawnedAt = System.GetCurrTime(),
    }
    self:FoeArm()
    return self.Foes[k]
end

function mercenaries:FoeForget(id)
    if id then self.Foes[tostring(id)] = nil end
end

-- ---------------------------------------------------------------------------
-- Master tick
-- ---------------------------------------------------------------------------
function mercenaries:FoeArm()
    if self.FoeLoopArmed then return end
    self.FoeLoopArmed = true
    Script.SetTimerForFunction(self.FoeTickMs, "mercenaries.FoeLoop")
end

function mercenaries.FoeLoop()
    mercenaries.FoeLoopArmed = false
    pcall(function() mercenaries:FoeTick() end)
    if next(mercenaries.Foes) then mercenaries:FoeArm() end
end

-- Every candidate a foe may fight, gathered once per tick rather than once per foe.
-- They are all near the player by definition, so one sphere query covers the lot.
function mercenaries:FoeCandidates()
    local out = {}
    if not player then return out end
    local pp = player:GetPos()
    if not pp then return out end

    if self:IsCombatViable(player) then
        out[#out + 1] = { ent = player, wuid = player.this.id, key = 'player', pos = pp }
    end

    local ents = System.GetPhysicalEntitiesInBoxByClass(pp, 90.0, "NPC")
    if not ents then return out end
    for _, ent in pairs(ents) do
        if ent and type(ent) == "table" and ent.soul and ent.this and ent.this.id
           and not self.Foes[tostring(ent.this.id)] then
            local n = ent:GetName() or ''
            local match = false
            for _, p in ipairs(self.FoeTargetPrefixes) do
                if string.find(n, p, 1, true) then match = true; break end
            end
            if match and self:IsCombatViable(ent) then
                local ep = ent:GetPos()
                -- The identity key is the entity NAME. Neither `tostring(ent.id)` nor
                -- `tostring(ent.this.id)` is safe here: those are handles, and a handle
                -- read fresh each tick does not necessarily stringify to the same text
                -- twice. Comparing two of them is what made "is this still the same
                -- man?" answer no on every single tick - which re-fired the combat, and
                -- a re-fire restarts the behaviour. Names are plain strings and unique
                -- per entity (System.GetEntityByName depends on it).
                if ep then out[#out + 1] = { ent = ent, wuid = ent.this.id, key = n, pos = ep } end
            end
        end
    end
    return out
end

-- Eye-height line of sight. Only ever asked about a candidate already inside
-- FoeDetectRange, so this is a handful of rays a tick at most.
function mercenaries:FoeHasLos(fromPos, toPos)
    if not self.FoeRequireLos then return true end
    local clear = true
    local ok = pcall(function()
        local hitTable = {}
        local a = { x = fromPos.x, y = fromPos.y, z = fromPos.z + 1.6 }
        local dir = { x = toPos.x - a.x, y = toPos.y - a.y, z = toPos.z + 1.6 - a.z }
        -- ent_terrain + ent_static only: an NPC standing between the two is not cover.
        local hits = Physics.RayWorldIntersection(a, dir, 2, ent_terrain + ent_static, nil, nil, hitTable)
        clear = ((hits or 0) == 0)
    end)
    if not ok then return true end   -- never let a ray failure blind the whole band
    return clear
end

function mercenaries:FoeTick()
    if not player then return end
    local now = System.GetCurrTime()

    -- Every position an alarm goes out from this tick: a foe who spotted something, a
    -- foe who was hit, or a foe who just died. All three wake the men around them.
    local alarms = {}

    -- 1. Prune the dead and the despawned. A foe going down is itself an alarm - if he
    --    is dropped at range by an archer nobody would otherwise ever notice.
    for k, r in pairs(self.Foes) do
        local alive = false
        pcall(function()
            local e = XGenAIModule.GetEntityByWUID(r.wuid)
            if e then r.ent = e; alive = self:IsAliveAndWell(e, true) end
        end)
        if not alive then
            if r.pos then alarms[#alarms + 1] = { pos = r.pos, why = 'a foe went down', bark = false } end
            self.Foes[k] = nil
        end
    end
    if not next(self.Foes) then return end

    -- 2. Being hit alerts a foe outright: detection range is about noticing someone,
    --    and an arrow out of the trees has already answered that question.
    for _, r in pairs(self.Foes) do
        local hp
        pcall(function() hp = r.ent.soul:GetState('health') end)
        if hp then
            if r.hp and hp < r.hp and not r.alerted then
                r.alerted, r.alertedAt, r.alertedBy = true, now, 'hurt'
                r.shout = true
                local p
                pcall(function() p = r.ent:GetPos() end)
                if p then alarms[#alarms + 1] = { pos = p, why = 'a foe was hit', bark = true } end
            end
            r.hp = hp
        end
    end

    local cands = self:FoeCandidates()

    -- Anti-swarm load, rebuilt from last tick's assignments.
    local load = {}
    for _, r in pairs(self.Foes) do
        if r.target then
            local tk = tostring(r.target)
            load[tk] = (load[tk] or 0) + 1
        end
    end

    -- 3. Detection and targeting, one pass over the roster.
    for _, r in pairs(self.Foes) do
        local mp
        pcall(function() mp = r.ent:GetPos() end)
        r.pos = mp
        if mp then
            local near, nearD2, pick, pickD2
            for _, c in ipairs(cands) do
                local dx, dy, dz = c.pos.x - mp.x, c.pos.y - mp.y, c.pos.z - mp.z
                local d2 = dx * dx + dy * dy + dz * dz
                if not nearD2 or d2 < nearD2 then near, nearD2 = c, d2 end
                if (load[tostring(c.wuid)] or 0) < self.FoeSwarmCap then
                    if not pickD2 or d2 < pickD2 then pick, pickD2 = c, d2 end
                end
            end

            -- Detection: only while still unalerted, and only on his own eyes.
            if not r.alerted and near and nearD2 <= (self.FoeDetectRange * self.FoeDetectRange)
               and self:FoeHasLos(mp, near.pos) then
                r.alerted, r.alertedAt, r.alertedBy = true, now, 'self'
                r.shout = true
                alarms[#alarms + 1] = { pos = mp, why = "'" .. r.name .. "' spotted a target",
                                        bark = true }
            end

            if r.alerted then
                -- Hold the current target for the whole approach. He is only dropped
                -- when he is gone (dead, despawned, out of engage range) - NOT because
                -- someone else drifted nearer.
                --
                -- The first version re-picked every tick unless the target was within
                -- 6m, which is to say every tick of a 40m charge. Every re-pick that
                -- landed on a different object re-fired the combat behaviour, and a
                -- re-fire evicts the running one and restarts it: that is the step,
                -- wait, step, wait. A charging man does not shop for a better target.
                local keep = false
                if r.targetKey then
                    for _, c in ipairs(cands) do
                        if c.key == r.targetKey then
                            local dx, dy, dz = c.pos.x - mp.x, c.pos.y - mp.y, c.pos.z - mp.z
                            if (dx * dx + dy * dy + dz * dz) <= (self.FoeEngageRange * self.FoeEngageRange) then
                                keep = true
                                r.target = c.wuid       -- refresh the handle, same man
                            end
                            break
                        end
                    end
                end
                if not keep then
                    -- Acquisition. The swarm cap applies HERE and only here, so it
                    -- spreads a band out over the squad as they pick targets rather
                    -- than shuffling anyone off a man he is already fighting.
                    local chosen, chosenD2 = pick, pickD2
                    if not chosen then chosen, chosenD2 = near, nearD2 end
                    if chosen and chosenD2 <= (self.FoeEngageRange * self.FoeEngageRange) then
                        r.target, r.targetKey = chosen.wuid, chosen.key
                    else
                        r.target, r.targetKey = nil, nil
                    end
                end
            end
        end
    end

    -- 4. The alarm: everyone inside FoeAlertRange of it joins in, whether or not they
    --    can see anything themselves. Single hop unless FoeAlertChains - a foe woken by
    --    a shout does not shout again, or one alarm would ripple across the map.
    for _, a in ipairs(alarms) do
        local n = 0
        for _, r in pairs(self.Foes) do
            if not r.alerted and r.pos then
                local dx, dy, dz = r.pos.x - a.pos.x, r.pos.y - a.pos.y, r.pos.z - a.pos.z
                if (dx * dx + dy * dy + dz * dz) <= (self.FoeAlertRange * self.FoeAlertRange) then
                    r.alerted, r.alertedAt, r.alertedBy = true, now, 'shout'
                    r.shout = (self.FoeAlertChains and a.bark) and true or false
                    n = n + 1
                end
            end
        end
        System.LogAlways(string.format("[Foe] %s - %d more foe(s) inside %.0fm engage",
            a.why, n, self.FoeAlertRange))
    end

    -- 5. Targets for the men woken in step 4. Without this they would be alerted with
    --    nothing to attack until the next tick, and would fire the idle behaviour once
    --    on the way - a visible stutter at the exact moment the band is meant to charge.
    --    Nearest man, swarm cap ignored: step 3 re-balances them next tick, and the cap
    --    only matters once they are actually on top of someone.
    for _, r in pairs(self.Foes) do
        if r.alerted and not r.target and r.pos then
            local best, bestD2
            for _, c in ipairs(cands) do
                local dx, dy, dz = c.pos.x - r.pos.x, c.pos.y - r.pos.y, c.pos.z - r.pos.z
                local d2 = dx * dx + dy * dy + dz * dz
                if not bestD2 or d2 < bestD2 then best, bestD2 = c, d2 end
            end
            if best and bestD2 <= (self.FoeEngageRange * self.FoeEngageRange) then
                r.target, r.targetKey = best.wuid, best.key
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Tree contract
-- ---------------------------------------------------------------------------
-- Called by foe_scheduler.xml every FoeTickMs. Publishes the target and decides
-- whether a behaviour must be (re-)fired. This is the ONLY place that decision is
-- made - the tree never second-guesses it, so there is no race between a fire loop
-- and an "am I in combat" tracker.
function mercenaries:FoePoll(data, id)
    data.foeFire      = false
    data.foeFireIdle  = false
    data.foeHasTarget = false

    local ok, err = pcall(function()
        local r = self:FoeRecord(id, true)
        if not r then return end
        local now = System.GetCurrTime()

        -- An alerted foe with nothing in range holds whatever he is doing. He must NOT
        -- be sent back to idle: that tree sheathes his weapon, and one bad tick in the
        -- middle of a charge would have him put his sword away and draw it again.
        local want
        if r.alerted then
            want = r.target and 'combat' or nil
        else
            want = 'idle'
        end
        if not want then return end

        if want == 'combat' then
            data.foeTarget = r.target
            data.foeHasTarget = true
        end

        -- A running fight is NEVER interrupted just because Lua now fancies a different
        -- target. There is no need: when the man he is actually fighting goes down, the
        -- combat tree's watchdog ends the behaviour, the heartbeat stops, and the next
        -- poll re-fires him at whoever the record holds by then. Re-pointing a live
        -- fight only ever restarted it - and a restart replays the whole entry,
        -- including the weapon draw, which is the stutter.
        --
        -- r.repoint is the deliberate override for an encounter that really must move
        -- someone mid-fight. Nothing sets it today.
        local why
        if (now - (r.beat or 0)) >= self.FoeBeatTimeout then
            why = 'no heartbeat'
        elseif r.beatKind ~= want then
            why = 'running ' .. tostring(r.beatKind) .. ', wants ' .. want
        elseif want == 'combat' and r.repoint then
            why = 'forced re-point'
            r.repoint = nil
        end
        if not why then return end
        if (now - (r.firedAt or 0)) < self.FoeRefireDelay then return end

        r.refireWhy = why
        if want == 'combat' then data.foeFire = true else data.foeFireIdle = true end
    end)
    if not ok then System.LogAlways('[Foe] FoePoll error: ' .. tostring(err)) end
end

-- The scheduler reports the outcome of every fire attempt. ok=false means the
-- interrupt could not even be issued (no interrupt host) - logged, because that
-- failure was completely silent in the old system.
function mercenaries:FoeOnFired(id, kind, ok)
    local r = self:FoeRecord(id, false)
    if not r then return end
    local now = System.GetCurrTime()

    -- Retries that never produce a heartbeat mean the behaviour is being refused
    -- (priority, a competing interrupt, a missing SmartBehaviorTemplate row). The
    -- retry keeps him from being stranded, but say so once instead of looping in
    -- silence, which is exactly how the old system hid the same problem.
    if r.firedKind == kind and (r.beat or 0) <= (r.firedAt or 0) then
        r.stuck = (r.stuck or 0) + 1
        if r.stuck == 5 then
            System.LogAlways(string.format(
                "[Foe] '%s' has been told to %s 5 times with no heartbeat back - the behaviour is not starting",
                r.name, tostring(kind)))
        end
    else
        r.stuck = 0
    end

    -- Every RE-fire (not the first) restarts the behaviour, and a restarted charge is
    -- a visible stop. If this line shows up repeatedly on one foe, that is the bug -
    -- the reason says which of the three conditions in FoePoll asked for it.
    if r.firedKind == kind and r.refireWhy then
        System.LogAlways(string.format("[Foe] '%s' re-fired %s (%s)",
            r.name, tostring(kind), tostring(r.refireWhy)))
    end
    r.refireWhy = nil

    r.firedAt = now
    r.firedKind = kind
    if kind == 'combat' then r.firedTarget, r.firedKey = r.target, r.targetKey end
    if not ok then
        System.LogAlways(string.format("[Foe] '%s' could not fire %s (no interrupt host) - retrying",
            r.name, tostring(kind)))
    end
end

-- Heartbeat from a running behaviour. Its absence is what triggers a re-fire.
function mercenaries:FoeBeat(id, kind)
    local r = self:FoeRecord(id, false)
    if not r then return end
    local now = System.GetCurrTime()
    r.beat, r.beatKind = now, kind
    if kind == 'combat' and not r.engagedAt then
        r.engagedAt = now
        if r.alertedAt then
            System.LogAlways(string.format("[Foe] '%s' engaged %.2fs after being alerted (%s)",
                r.name, now - r.alertedAt, tostring(r.alertedBy)))
        end
    end
end

-- Entry point of foe_combat: heartbeat, target liveness, and the one-shot shout.
function mercenaries:FoeCombatEnter(data, id)
    data.foeShout = false
    data.isTargetAlive = true

    -- Only draw if he is not already holding his weapon. The explicit DrawAction is a
    -- full animation that stops him where he stands, and every re-fire of this
    -- behaviour replays it - which is what turned re-fire churn into a visible
    -- step-pause-step approach for ARMED foes only (an empty weapon set makes the
    -- DrawAction fail instantly, so those ran in straight - that was the tell).
    -- Resolved from the id, not from the BT's `entity` global: this is an ordinary Lua
    -- function, and that global is not reliably in scope inside one.
    data.needsDraw = true
    pcall(function()
        local me = XGenAIModule.GetEntityByWUID(id)
        if me and me.human and me.human:IsWeaponDrawn() then data.needsDraw = false end
    end)

    -- Read before the combat Parallel is built, so the decorators pick these up.
    local a = self.FoeAutomation
    data.automation_offense  = a.offense
    data.automation_defense  = a.defense
    data.automation_guard    = a.guard
    data.automation_weapon   = a.weapon
    data.automation_movement = a.movement

    local r = self:FoeRecord(id, false)
    if not r then return end
    self:FoeBeat(id, 'combat')
    if r.shout then
        r.shout = false
        data.foeShout = true
    end
end

-- Combat watchdog. Foes have no leash: they were alerted, so they finish the fight.
-- The only exit is the target going down, which frees them for the next one.
--
-- Judged on attackData.target - the man this tree was actually fired at - not on the
-- record's current target. The two differ for the tick between Lua re-pointing him
-- and the scheduler re-firing, and it is the man he is swinging at whose death should
-- end this run of the behaviour.
function mercenaries:FoeCombatTick(data, id)
    data.isTargetAlive = false
    local ok = pcall(function()
        local r = self:FoeRecord(id, false)
        if not r then return end
        self:FoeBeat(id, 'combat')
        local tw = (data.attackData and data.attackData.target) or r.target
        if not tw then return end
        local t = XGenAIModule.GetEntityByWUID(tw)
        if t and self:IsCombatViable(t) then data.isTargetAlive = true end
    end)
    if not ok then data.isTargetAlive = true end   -- a lookup hiccup is not a death
end

function mercenaries:FoeIdleTick(data, id)
    self:FoeBeat(id, 'idle')
    data.foeEmote = self.FoeIdleEmotes[math.random(#self.FoeIdleEmotes)]
end

function mercenaries:FoeCombatEnded(id)
    local r = self:FoeRecord(id, false)
    if not r then return end
    r.beat, r.beatKind = 0, nil       -- next poll re-decides immediately
    r.firedTarget, r.firedKey = nil, nil
end

-- ---------------------------------------------------------------------------
-- Spawning
-- ---------------------------------------------------------------------------
mercenaries.FoeSouls = {
    "f0e15001-1a2b-4c3d-8e4f-000000000001",
    "f0e15001-1a2b-4c3d-8e4f-000000000002",
    "f0e15001-1a2b-4c3d-8e4f-000000000003",
    "f0e15001-1a2b-4c3d-8e4f-000000000004",
    "f0e15001-1a2b-4c3d-8e4f-000000000005",
    "f0e15001-1a2b-4c3d-8e4f-000000000006",
}
mercenaries.FoeSoulIndex = 1

-- Bandit clothing presets. Gear only - no AI is shared with the enemy groups.
mercenaries.FoeClothing = {
    "07a49bb9-1b92-43c2-848f-f4abf88a3b12", "c685a814-ace0-4c6b-b8bb-9a024d073d42",
    "394c8de2-7525-4f3a-8774-17876c95b6b6", "fdec006f-b7e2-491a-8a1d-f453501b7ffc",
    "0154a9ef-ad07-4c4a-bf5b-4bca21b65d7b", "d4468c20-47e3-49dd-995e-65063040696e",
    "48f33d37-90ab-489a-9236-d56819d25ea2", "94d6d667-139b-4d79-a25b-f2b608b86c96",
}

-- A foe with an empty weapon set stands in the open being hit: the draw fails and
-- the combat tree dies at its first node. EquipMercenaryWeapon picks a random
-- category that can come out empty, so category 2 is applied after it as a backstop
-- (the same fix EquipEnemy carries).
function mercenaries:FoeEquip(ent)
    if not (ent and ent.actor) then return end
    pcall(function() ent.actor:EquipClothingPreset(self.FoeClothing[math.random(#self.FoeClothing)]) end)
    pcall(function() self:EquipMercenaryWeapon(ent, math.random(self.RandomMeleeSetMin, self.RandomMeleeSetMax), nil) end)
    pcall(function() self:EquipMercenaryWeapon(ent, 2, nil) end)
end

function mercenaries:FoeSpawnAt(pos, yaw, tier)
    if not pos then return nil end
    tier = tier or "medium"
    local ent
    local ok, err = pcall(function()
        local soul = self.FoeSouls[self.FoeSoulIndex]
        self.FoeSoulIndex = (self.FoeSoulIndex % #self.FoeSouls) + 1
        -- The tier token is parsed back out of the name by EquipMercenaryWeapon.
        local name = "SpawnedFoe_" .. tier .. "_" ..
                     tostring(math.random(10000, 99999)) .. "_" .. soul
        System.SpawnEntity({
            class = "NPC", name = name, position = pos,
            orientation = { x = 0, y = 0, z = yaw or 0 },
            properties = { guidSharedSoulId = soul },
        })
        ent = System.GetEntityByName(name)
        if ent then
            self:FoeEquip(ent)
            self:FoeRegister(ent)
        end
    end)
    if not ok then System.LogAlways('[Foe] spawn error: ' .. tostring(err)) end
    return ent
end

-- Spawn count foes dist metres ahead of the player, scattered over spread metres,
-- all facing him and all UNALERTED - walk at them and watch the alert run.
function mercenaries:FoeSpawn(count, dist, spread)
    if not player then return end
    count  = math.max(1, tonumber(count) or 8)
    dist   = tonumber(dist)   or 45.0
    spread = tonumber(spread) or 20.0

    local ok, err = pcall(function()
        local o = player:GetWorldPos()
        local ang
        pcall(function() ang = player:GetWorldAngles() end)
        local yaw = (ang and ang.z) or 0
        local fx, fy = math.cos(yaw), math.sin(yaw)
        local rx, ry = fy, -fx
        local centre = { x = o.x + fx * dist, y = o.y + fy * dist, z = o.z }

        for i = 1, count do
            local across = (count > 1) and (((i - 1) / (count - 1) - 0.5) * spread) or 0
            local along  = (math.random() - 0.5) * spread * 0.4
            local p = { x = centre.x + rx * across + fx * along,
                        y = centre.y + ry * across + fy * along,
                        z = centre.z }
            if self.CampSnapToGround then p = self:CampSnapToGround(p) end
            self:FoeSpawnAt(p, yaw + math.pi, (i % 3 == 0) and "strong" or "medium")
        end
    end)
    if not ok then System.LogAlways('[Foe] FoeSpawn error: ' .. tostring(err)) end
    System.LogAlways(string.format(
        "[Foe] spawned %d at %.0fm, spread %.0fm. Detection %.0fm, shout carries %.0fm.",
        count, dist, spread, self.FoeDetectRange, self.FoeAlertRange))
end

-- The alert demo: one scout well forward of a band that is far too far back to see
-- anything. Walk up to the scout and the whole band should come at once.
function mercenaries:FoeSpawnScouted()
    if not player then return end
    local ok = pcall(function()
        local o = player:GetWorldPos()
        local ang
        pcall(function() ang = player:GetWorldAngles() end)
        local yaw = (ang and ang.z) or 0
        local fx, fy = math.cos(yaw), math.sin(yaw)
        local rx, ry = fy, -fx

        local scout = { x = o.x + fx * 30, y = o.y + fy * 30, z = o.z }
        if self.CampSnapToGround then scout = self:CampSnapToGround(scout) end
        self:FoeSpawnAt(scout, yaw + math.pi, "strong")

        for i = 1, 8 do
            local across = ((i - 1) / 7 - 0.5) * 24
            local p = { x = o.x + fx * 75 + rx * across, y = o.y + fy * 75 + ry * across, z = o.z }
            if self.CampSnapToGround then p = self:CampSnapToGround(p) end
            self:FoeSpawnAt(p, yaw + math.pi, "medium")
        end
    end)
    if not ok then System.LogAlways('[Foe] FoeSpawnScouted failed') end
    System.LogAlways("[Foe] scout at 30m, band of 8 at 75m. Walk to the scout: he shouts, they all come.")
end

function mercenaries:FoeClear()
    local n = 0
    for k, r in pairs(self.Foes) do
        pcall(function() System.RemoveEntity(r.ent.id) end)
        self.Foes[k] = nil
        n = n + 1
    end
    System.LogAlways("[Foe] removed " .. n .. " foe(s)")
end

-- ---------------------------------------------------------------------------
-- Debug
-- ---------------------------------------------------------------------------
function mercenaries:FoeAlertAll()
    local now = System.GetCurrTime()
    local n = 0
    for _, r in pairs(self.Foes) do
        if not r.alerted then
            r.alerted, r.alertedAt, r.alertedBy, r.shout = true, now, 'console', true
            n = n + 1
        end
    end
    System.LogAlways("[Foe] alerted " .. n .. " foe(s)")
end

function mercenaries:FoeCalm()
    for _, r in pairs(self.Foes) do
        r.alerted, r.shout, r.target, r.targetKey = false, false, nil, nil
        r.alertedAt, r.alertedBy, r.engagedAt = nil, nil, nil
        r.beat, r.beatKind, r.firedTarget, r.firedKey = 0, nil, nil, nil
    end
    System.LogAlways("[Foe] all foes calmed")
end

function mercenaries:FoeStatus()
    local now = System.GetCurrTime()
    local n = 0
    System.LogAlways(string.format(
        "[Foe] detect %.0fm / shout %.0fm / engage %.0fm / swarm cap %d / LOS %s",
        self.FoeDetectRange, self.FoeAlertRange, self.FoeEngageRange,
        self.FoeSwarmCap, tostring(self.FoeRequireLos)))
    for _, r in pairs(self.Foes) do
        n = n + 1
        local state = r.alerted and (r.target and "COMBAT" or "alerted, no target") or "idle"
        local delay = (r.alertedAt and r.engagedAt)
            and string.format("%.2fs", r.engagedAt - r.alertedAt) or "-"
        -- wants vs fighting: if those two differ for long it is normal (a live fight is
        -- never interrupted to re-point); if they differ AND he is not fighting at all,
        -- something is wrong.
        System.LogAlways(string.format(
            "[Foe]   %-44s %-18s by=%-7s engage=%-7s beat=%s (%.1fs ago) wants=%s fighting=%s",
            r.name, state, tostring(r.alertedBy or '-'), delay,
            tostring(r.beatKind or 'none'), now - (r.beat or now),
            tostring(r.targetKey or '-'), tostring(r.firedKey or '-')))
    end
    if n == 0 then System.LogAlways("[Foe]   (no foes)") end
end

-- foe_auto <offense|defense|guard|weapon|movement> <0|1>. Takes effect on the next
-- combat entry, so follow it with foe_calm then foe_alert to re-fire everyone.
function mercenaries:FoeSetAutomation(line)
    local name, val = string.match(tostring(line or ''), "^%s*(%a+)%s+(%d)")
    if not (name and val and self.FoeAutomation[name] ~= nil) then
        local parts = {}
        for k, v in pairs(self.FoeAutomation) do
            parts[#parts + 1] = k .. "=" .. tostring(v)
        end
        table.sort(parts)
        System.LogAlways("[Foe] automation: " .. table.concat(parts, "  "))
        System.LogAlways("[Foe] foe_auto <offense|defense|guard|weapon|movement> <0|1>, then foe_calm + foe_alert")
        return
    end
    self.FoeAutomation[name] = (val == "1")
    System.LogAlways(string.format("[Foe] automation %s = %s (foe_calm then foe_alert to apply)",
        name, tostring(self.FoeAutomation[name])))
end

function mercenaries:FoeSetRanges(line)
    local detect, alert = string.match(tostring(line or ''), "^%s*([%d%.]+)%s+([%d%.]+)")
    if tonumber(detect) then self.FoeDetectRange = tonumber(detect) end
    if tonumber(alert)  then self.FoeAlertRange  = tonumber(alert)  end
    System.LogAlways(string.format("[Foe] detect %.0fm, shout carries %.0fm",
        self.FoeDetectRange, self.FoeAlertRange))
end

mercenaries:DevCommand("foe_spawn",       "mercenaries:FoeSpawn(8, 45, 20)",   "Spawn 8 unalerted foes 45m ahead")
mercenaries:DevCommand("foe_spawn_1",     "mercenaries:FoeSpawn(1, 25, 0)",    "Spawn one unalerted foe 25m ahead")
mercenaries:DevCommand("foe_spawn_20",    "mercenaries:FoeSpawn(20, 55, 40)",  "Spawn 20 unalerted foes 55m ahead")
mercenaries:DevCommand("foe_spawn_scout", "mercenaries:FoeSpawnScouted()",     "Alert demo: a scout at 30m and a band at 75m")
mercenaries:DevCommand("foe_clear",       "mercenaries:FoeClear()",            "Remove every foe")
mercenaries:DevCommand("foe_status",      "mercenaries:FoeStatus()",           "Per-foe state, alert source and engage delay")
mercenaries:DevCommand("foe_alert",       "mercenaries:FoeAlertAll()",         "Alert every foe now (debug)")
mercenaries:DevCommand("foe_calm",        "mercenaries:FoeCalm()",             "Send every foe back to idle (debug)")
mercenaries:DevCommand("foe_ranges",      "mercenaries:FoeSetRanges('%line')", "foe_ranges <detectM> <shoutM>")
mercenaries:DevCommand("foe_auto",        "mercenaries:FoeSetAutomation('%line')", "foe_auto <offense|defense|guard|weapon|movement> <0|1>; no args lists them")
