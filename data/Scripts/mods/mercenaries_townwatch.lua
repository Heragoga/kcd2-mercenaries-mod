-- The town watch turns out.
--
-- Butcher enough people inside a village and the place fights back: a body of guards in
-- Kuttenberg livery musters out of sight and comes for the company. It is the enforcement
-- half of mercenaries_crimewatch.lua, which does all the watching - this file only decides
-- when to answer and what to send.
--
-- Everything about the muster is deliberately OURS, not the game's. Vanilla town guards
-- would fight the player and ignore the mercs entirely - no vanilla faction declares any
-- relation to mercenariesFaction, so the fight would be one-sided and the squad would stop
-- rendering (see docs/npc-lod.md). These men are enemiesFaction, like every other force
-- the mod fields, so both sides can see each other. See docs/town-watch.md.
--
-- Three waves, escalating, and the town only gives up after the third. See TWWaves.
--
-- A town is the worst terrain the mod places NPCs in - walls, interiors, the roof trap in
-- reference_indoor_spawn_roof_trap - and NOTHING here can promise a spot is escapable
-- before the fact. So placement is defended at four depths: anchor on a living townsman
-- (proven ground) who is himself outdoors, validate every man's own slot, check where the
-- engine actually put him, and finally TownWatchInertCheck - which measures the outcome
-- and picks the wave up again if it never set off.

local function twLog(s) System.LogAlways("[TownWatch] " .. tostring(s)) end

local function nowT()
    local t = 0
    pcall(function() t = System.GetCurrTime() or 0 end)
    return t
end

local function dist2(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return dx * dx + dy * dy
end

-- ==== config ====

-- OFF by default, with mercenaries_crimewatch.lua's own flag. The feature is unfinished
-- and ships dormant; see TownWatchFeatureEnable at the bottom of this file.
mercenaries.TWEnabled = false

-- The company has to be a company. Fewer than this and the town has no reason to muster
-- rather than simply arrest him - and a four-man squad jumped by a dozen guards is not a
-- fight, it is an execution.
mercenaries.TWMinMercs = 3          -- strictly MORE than this many living mercs

-- What counts as having gone too far. Either threshold alone is enough.
mercenaries.TWCivilianKills = 3
mercenaries.TWGuardKills    = 1

mercenaries.TWSpawnPoints   = 5     -- candidate muster points around the player
mercenaries.TWSpawnRadius   = 32.0  -- ...on a ring this far out: out of sight, short march
mercenaries.TWSpawnJitter   = 6.0   -- +/- on the radius so the ring is not a perfect circle
mercenaries.TWSpawnSpread   = 1.8   -- spacing between men at one point
mercenaries.TWPointTries    = 6     -- bearings tried per point before it is given up on

-- Muster points taken from the crowd. A living townsman's feet are a proven spawn - see
-- TownWatchCivilianPoints.
mercenaries.TWCivMinDist    = 16.0  -- no closer to the player than this
mercenaries.TWCivMaxDist    = 70.0
mercenaries.TWCivOffset     = 1.6   -- spawn beside him, not inside him
-- How far the engine may move a man off his muster point before we give up on him. It
-- snaps a spawn to navmesh, and a long snap means the point was inside geometry.
mercenaries.TWSpawnSlipMax  = 12.0

-- Ceiling on any one wave BEFORE difficulty. Raised with TWHardCap, because it - not the
-- hard cap - is what actually binds on the default tier: DifficultyCeil returns this
-- value unchanged at Medium and below, so leaving it at 24 would have meant a 40-man
-- company still only ever drew 24 guards however high the absolute cap went.
mercenaries.TWMaxCount      = 48
-- ...and an ABSOLUTE one, after it, since DifficultyCeil multiplies the line above by the
-- tier. High on purpose: a large company should be able to bring a city down on itself.
-- What makes that affordable is not the count but the SPREAD below - see TWMenPerPoint.
mercenaries.TWHardCap       = 70

-- SPREAD, and it is a performance measure before it is a design one. A big wave landing on
-- one spot is a single mass brawl in the player's face, which is the most expensive thing
-- this mod can produce; the same men split across the village fight in pockets, most of
-- them far enough away to cost a fraction of that, and drift in as they win or lose.
--
-- So a wave's `points` is a MINIMUM, not a count: no muster point holds more than
-- TWMenPerPoint men, and the wave takes as many points as that needs.
mercenaries.TWMenPerPoint   = 8
mercenaries.TWMaxPoints     = 10

-- Big waves also muster FURTHER OUT. Same reasoning: distance is cheap, and a company
-- that has drawn seventy men should see them coming up the street rather than appear
-- around it. Metres added to the ideal ring radius per man in the wave, clamped inside
-- the anchor scan.
mercenaries.TWSpreadPerMan  = 0.9

-- THREE WAVES, and the town only gives up after the third.
--
-- The shape is an escalation the player is meant to feel: the first patrol to reach the
-- street is beaten by any real company, and each answer after it is bigger than the last.
-- `share` is guards per living merc, `floor` the least it may ever be, and `over` a hard
-- minimum stated relative to the company - which is what actually delivers "outnumbers".
--
-- `points` is the MINIMUM number of places the wave arrives from, not the number. The
-- first is a scramble: whoever was nearby, from every direction. The two after it want to
-- read as a formed body coming from one place - but only while they are small enough for
-- that to mean anything. TWMenPerPoint overrides this upward, so a muster of forty arrives
-- as five columns from five streets rather than one heap in one street.
--
-- `delay` is measured from the event named in `after`.
mercenaries.TWWaves = {
    {
        label  = "the watch",
        share  = 0.65, floor = 3, over = -1,   -- fewer men than the company has
        points = 5,
        after  = "trigger", delay = 0,
    },
    {
        label  = "the muster",
        share  = 1.25, floor = 5, over = 1,    -- slightly more than the company
        points = 1,
        after  = "previous wave destroyed", delay = 120.0,
    },
    {
        label  = "the town in arms",
        share  = 2.0,  floor = 8, over = 4,    -- significantly more
        points = 1,
        after  = "wave two arriving", delay = 300.0,
    },
}

-- The watch defends its own village and nothing else. Walk this far from where they
-- mustered and they stand down; the fight is over and they were never a pursuit force.
mercenaries.TWLeaveRange    = 140.0
mercenaries.TWLeaveGrace    = 12.0  -- seconds outside that range before they go

mercenaries.TWRegenDays     = 3.0   -- a town that lost ALL THREE waves is spent this long
mercenaries.TWTickSecs      = 2.0
mercenaries.TWRetrySecs     = 15.0  -- a wave that found nowhere to muster tries again

-- One line per wave. Wave one keeps the original key so no save or localisation that
-- already knows it breaks.
mercenaries.TWWaveInfoText = {
    'merc_info_townwatch_out',
    'merc_info_townwatch_wave2',
    'merc_info_townwatch_wave3',
}

-- ==== state ====

mercenaries.TWActive   = false
mercenaries.TWPlace    = nil        -- settlement key the watch belongs to
mercenaries.TWForce    = {}         -- spawned entities
mercenaries.TWAnchor   = nil        -- where they mustered; the leash centre
mercenaries.TWLeftAt   = nil        -- when the player first went out of range
mercenaries.TWKills    = {}         -- [placeKey] = { civilian = n, guard = n }
mercenaries.TWWiped    = {}         -- [placeKey] = upkeep-day the LAST wave was destroyed
mercenaries._twAt      = 0

-- Where in the escalation we are. TWWave is the last wave that ARRIVED (0 while the town
-- is quiet); TWNextAt is when the next one is due, nil when none is pending.
mercenaries.TWWave     = 0
mercenaries.TWNextAt   = nil

-- ==== the trigger ====

-- Crimewatch hands every attributed kill here. `stealth` is its own judgement: an NPC
-- that was never seen aware (never in combat danger, never with a weapon out) died
-- without knowing anyone was there, and a knife in the dark does not raise a town.
function mercenaries:TownWatchNoteKill(kind, placeKey, stealth)
    if not self.TWEnabled then return end
    if stealth then return end
    if not placeKey then return end
    if kind ~= "civilian" and kind ~= "guard" then return end

    local k = self.TWKills[placeKey] or { civilian = 0, guard = 0 }
    k[kind] = (k[kind] or 0) + 1
    self.TWKills[placeKey] = k
    self.TWLastKillAt = nowT()
    twLog(string.format("%s: %d civilian(s), %d guard(s) on the company's account",
                        placeKey, k.civilian, k.guard))
end

-- Is there a fight on? A muster with none would drop a dozen guards into a quiet street.
--
-- This used to be IsInCombatDanger plus the BT attacker register, and it read FALSE
-- through an eight-merc massacre in Kutna Hora - which is why nothing ever triggered
-- naturally. Neither source fires when WE are the aggressors and the victims are unarmed
-- townsfolk: nothing locks on to us, and butchering a fleeing baker is not "danger".
-- CrimeFightOn covers that (a merc holding a combat target is the reading that fires), and
-- a fresh kill is added on top - the massacre IS the combat.
mercenaries.TWKillIsCombatSecs = 20.0

function mercenaries:TownWatchInCombat()
    local on = false
    pcall(function() on = self:CrimeFightOn() end)
    if on then return true end
    if (nowT() - (self.TWLastKillAt or -1e9)) <= self.TWKillIsCombatSecs then return true end
    return false
end

-- Has this village used up its watch recently? A town whose guards were all killed three
-- days ago has nobody left to send.
function mercenaries:TownWatchOnCooldown(placeKey)
    local wiped = self.TWWiped[placeKey]
    if not wiped then return false, 0 end
    local day = 0
    pcall(function() day = self:LogiUpkeepDay() end)
    local left = (wiped + self.TWRegenDays) - day
    if left <= 0 then
        self.TWWiped[placeKey] = nil
        self:TownWatchSave()
        return false, 0
    end
    return true, left
end

-- Every condition, in cheapest-first order. Returns the settlement key to answer for.
function mercenaries:TownWatchShouldRespond()
    if not (self.TWEnabled and player) then return nil end
    if self.TWActive then return nil end

    local alive = 0
    pcall(function() alive = self:LogiAliveCount() end)
    if alive <= self.TWMinMercs then return nil end

    local inTown, _, _ = self:CrimeInSettlement()
    if not inTown then return nil end
    local placeKey = (self.CWHeat or {}).placeKey
    if not placeKey then return nil end

    local k = self.TWKills[placeKey]
    if not k then return nil end
    if (k.guard or 0) < self.TWGuardKills and (k.civilian or 0) < self.TWCivilianKills then
        return nil
    end

    local cooling, left = self:TownWatchOnCooldown(placeKey)
    if cooling then
        -- Said once per village, not once per tick.
        if not self._twCoolSaid or self._twCoolSaid ~= placeKey then
            self._twCoolSaid = placeKey
            twLog(string.format("%s has no watch left to send (%.1f day(s) to go)",
                                placeKey, left))
        end
        return nil
    end

    if not self:TownWatchInCombat() then return nil end
    return placeKey
end

-- ==== the muster ====

-- How many men wave `idx` brings. Sized off the living company, then scaled and capped by
-- the quartermaster's difficulty tier.
--
-- NOTE the `base` argument passed to DifficultyCount is the wave's OWN intended size, not
-- the merc count. DifficultyCount caps `want` at `base * countMult`, so passing the merc
-- count would clamp wave three (2x the company) back to 1.2x on Medium and flatten the
-- whole escalation. Passing `want` as its own base makes the call do what is wanted here -
-- scale the wave by the tier - while leaving every other caller's meaning intact.
--
-- `over` is applied AFTER difficulty, because it is the promise the design makes: wave two
-- outnumbers the company and wave three badly outnumbers it, on Easy as well as on Horde.
function mercenaries:TownWatchForceSize(idx)
    local w = self.TWWaves[idx or 1]
    if not w then return 0 end

    local n = 0
    pcall(function() n = self:LogiAliveCount() end)

    local want = math.floor(n * w.share + 0.5)
    if want < w.floor then want = w.floor end
    pcall(function() want = self:DifficultyCount(want, want, w.floor) end)

    -- Relative to the company, whatever the tier said.
    if w.over and w.over > 0 then
        if want < n + w.over then want = n + w.over end
    elseif w.over and w.over < 0 then
        -- The first wave must stay UNDER the company: it is meant to be beaten.
        local cap = n + w.over
        if cap < w.floor then cap = w.floor end
        if want > cap then want = cap end
    end

    local ceil_ = self.TWMaxCount
    pcall(function() ceil_ = self:DifficultyCeil(self.TWMaxCount) end)
    if want > ceil_ then want = ceil_ end
    if want > self.TWHardCap then want = self.TWHardCap end
    if want < 1 then want = 1 end
    return want
end

-- One muster point: walk out along a bearing until a spot validates. Returns nil when the
-- whole bearing is unusable, which is expected in a town and is exactly why there are five
-- of these.
function mercenaries:TownWatchFindPoint(from, bearing)
    for i = 0, self.TWPointTries - 1 do
        -- Fan either side of the bearing as we go, so a blocked spoke is not retried
        -- straight down its own length.
        local a = bearing + ((i % 2 == 0) and 1 or -1) * (math.floor(i / 2) * 0.35)
        local r = self.TWSpawnRadius + (math.random() * 2 - 1) * self.TWSpawnJitter
        local cx = from.x + math.cos(a) * r
        local cy = from.y + math.sin(a) * r

        local pos
        pcall(function() pos = self:CampSnapToGround({ x = cx, y = cy, z = from.z }) end)
        if pos then
            -- Under a roof is a spawn on somebody's rooftop waiting to happen: the
            -- ground probes work from above. See reference_indoor_spawn_roof_trap.
            local roofed = false
            pcall(function() roofed = self:CampDetectRoof(pos) and true or false end)
            if not roofed then
                local ok = false
                pcall(function()
                    ok = self:CampValidateSpot(pos, pos.z, self.CampMercFootprint) and true or false
                end)
                if ok then return pos end
            end
        end
    end
    return nil
end

-- PREFERRED SOURCE: stand where the locals are standing.
--
-- Raycasting a town is guesswork - the first pass validated all five geometric points and
-- still put three of seven men somewhere the player never saw them. A living townsman is
-- not guesswork: the engine is already holding him upright, outdoors, on navmesh, inside
-- the village, at a height that is genuinely the ground. His feet are a proven spawn.
--
-- So the muster ring is built from the crowd. One sphere scan, keep the living vanilla
-- locals in the distance band, bucket them by bearing so the watch still comes from all
-- round the player rather than out of one doorway, and take the best of each bucket.
-- `arcs` is how many bearings the crowd is divided into, and `idealR` the ring radius the
-- best anchor in each arc is chosen against. Both scale with the size of the wave.
function mercenaries:TownWatchCivilianPoints(from, arcs, idealR)
    arcs   = arcs or self.TWSpawnPoints
    idealR = idealR or self.TWSpawnRadius

    local ents
    pcall(function()
        ents = System.GetEntitiesInSphereByClass(from, self.TWCivMaxDist, 'NPC')
    end)
    if not ents then return {} end

    local buckets = {}
    for _, ent in pairs(ents) do
        local name
        pcall(function() name = ent.GetName and ent:GetName() end)
        local faction = self.CrimeFactionOf and self:CrimeFactionOf(ent) or nil
        if name and self:CrimeIsVanillaNpc(ent, name, faction)
           and self:IsAliveAndWell(ent, false) then
            local p
            pcall(function() p = ent:GetWorldPos() end)
            -- A townsman standing INDOORS is a terrible anchor. His own feet are fine,
            -- but a wave forms a block around him, and a block around a man in a kitchen
            -- is a wave inside somebody's house - alive, with a target, and no way out.
            -- That is exactly how wave two came to spawn and then stand there.
            local roofed = false
            if p then pcall(function() roofed = self:CampDetectRoof(p) and true or false end) end
            if p and not roofed then
                local dx, dy = p.x - from.x, p.y - from.y
                local d = math.sqrt(dx * dx + dy * dy)
                if d >= self.TWCivMinDist and d <= self.TWCivMaxDist then
                    local b = math.atan2(dy, dx)
                    local idx = math.floor(((b + math.pi) / (2 * math.pi)) * arcs) % arcs
                    -- Best in a bucket is whoever stands nearest the ideal ring radius:
                    -- far enough to be out of the fight, near enough to arrive.
                    local score = math.abs(d - idealR)
                    local cur = buckets[idx]
                    if not cur or score < cur.score then
                        buckets[idx] = { pos = p, score = score, who = name, dist = d }
                    end
                end
            end
        end
    end

    local pts = {}
    for _, b in pairs(buckets) do
        -- Beside him, not inside him. The offset is small and his own z is kept: that
        -- height is a floor somebody is demonstrably standing on.
        local a = math.random() * math.pi * 2
        table.insert(pts, {
            pos  = { x = b.pos.x + math.cos(a) * self.TWCivOffset,
                     y = b.pos.y + math.sin(a) * self.TWCivOffset,
                     z = b.pos.z },
            from = string.format("beside %s at %.0fm", b.who, b.dist),
        })
    end
    return pts
end

-- Civilians first, raycast ring to make up the numbers.
--
-- `wanted` is how many points this wave arrives from. One means a formed body marching in
-- from a single place, which is what waves two and three are - but a single point that
-- happens to be unusable would cost the whole wave, so a failed single-point muster falls
-- back to the full ring rather than to nothing.
-- `minPoints` is the wave's own shape (1 for a formed body, 5 for a scramble); `count` is
-- how many men have to fit. The wave takes whichever is larger, so a formed body of
-- seventy still arrives as several columns rather than one heap.
function mercenaries:TownWatchPoints(from, minPoints, count)
    minPoints = minPoints or self.TWSpawnPoints
    count     = count or 0

    local byCount = math.ceil(count / math.max(1, self.TWMenPerPoint))
    local wanted  = math.max(minPoints, byCount, 1)
    if wanted > self.TWMaxPoints then wanted = self.TWMaxPoints end

    -- Further out the bigger it is, but never past the crowd scan.
    local idealR = self.TWSpawnRadius + count * self.TWSpreadPerMan
    local maxR   = self.TWCivMaxDist - 4.0
    if idealR > maxR then idealR = maxR end

    -- Ask the crowd for as many bearings as we intend to use, so the anchors come from
    -- all round the player rather than several out of one arc.
    local all = self:TownWatchCivilianPoints(from, wanted, idealR)
    local civ = #all

    if #all < wanted then
        local base = math.random() * math.pi * 2
        for i = 0, wanted - 1 do
            if #all >= wanted then break end
            local bearing = base + (i / wanted) * math.pi * 2
            local p = self:TownWatchFindPoint(from, bearing)
            if p then table.insert(all, { pos = p, from = "raycast ring" }) end
        end
    end

    local pts = all
    if wanted < #all then
        pts = {}
        for i = 1, wanted do table.insert(pts, all[i]) end
    end

    twLog(string.format(
        "muster points: %d wanted for %d men (min %d), %d found (%d crowd, %d ring), ideal ring %.0fm",
        wanted, count, minPoints, #all, civ, #all - civ, idealR))
    return pts, all
end

-- Hand the whole force the player as a forced target, and pin their view distance the way
-- every other spread-out force in the mod does. Written under BOTH wuid keys:
-- enemy_melee_scheduler.xml calls FindEnemyTarget with entity.this.id, while the camp
-- tables use GetMyWUID. They coincide for these NPCs today and writing both costs nothing.
function mercenaries:TownWatchAimAt(force)
    local tgt
    pcall(function() tgt = player and player.this and player.this.id end)
    if not tgt then return end
    self.ForcedTargetOf = self.ForcedTargetOf or {}

    local n = 0
    for _, e in ipairs(force or {}) do
        if e and self:IsAliveAndWell(e, true) then
            pcall(function()
                if e.this and e.this.id then self.ForcedTargetOf[tostring(e.this.id)] = tgt end
                local w = XGenAIModule.GetMyWUID(e)
                if w then self.ForcedTargetOf[tostring(w)] = tgt end
                if self.LodPinEntity then self:LodPinEntity(e) end
            end)
            n = n + 1
        end
    end
    if n > 0 then twLog(string.format("  %d guard(s) sent at the player", n)) end
end

-- ...and take it back when they go, so a dead man's entry cannot outlive him in a table
-- every enemy in the mod reads.
function mercenaries:TownWatchDropAim(force)
    if not self.ForcedTargetOf then return end
    for _, e in ipairs(force or {}) do
        if e then
            pcall(function()
                if e.this and e.this.id then self.ForcedTargetOf[tostring(e.this.id)] = nil end
                local w = XGenAIModule.GetMyWUID(e)
                if w then self.ForcedTargetOf[tostring(w)] = nil end
            end)
        end
    end
end

function mercenaries:TownWatchMuster(placeKey, waveIdx)
    waveIdx = waveIdx or 1
    local wave = self.TWWaves[waveIdx]
    if not wave then return false end

    local pp
    pcall(function() pp = player:GetWorldPos() end)
    if not pp then return false end

    -- Survivors of the previous wave are FOLDED INTO this one, not added on top of it.
    -- Wave three is timed off wave two arriving, so wave two may well still be standing;
    -- spawning a full third wave beside it would put both on the field at once. What the
    -- design promises is how many men the player faces, not how many were created this
    -- minute - so the wave tops up to its size and the holdovers count towards it.
    local holdover = {}
    for _, e in ipairs(self.TWForce or {}) do
        if e and self:IsAliveAndWell(e, true) then table.insert(holdover, e) end
    end

    local target = self:TownWatchForceSize(waveIdx)
    local want   = target - #holdover
    if #holdover > 0 then
        twLog(string.format("  %d man/men of wave %d still standing - topping up to %d",
                            #holdover, self.TWWave or 0, target))
    end

    -- Points are chosen AFTER the count, because the count is what decides how many
    -- there need to be and how far out they sit.
    local pts, all = self:TownWatchPoints(pp, wave.points, want)
    if #pts == 0 then
        twLog("no muster point validated anywhere around the player - not responding")
        return false
    end

    local spawned = {}
    local lost, refused = 0, 0
    local i = 0
    local widened = false
    while #spawned < want do
        local p = pts[(i % #pts) + 1]
        -- Men are dealt round-robin across the points; `slot` is which man this is AT
        -- HIS OWN point. Four abreast, then a new row - and the rows alternate in FRONT
        -- of and BEHIND the anchor rather than all marching off in +y, so a 24-man wave
        -- at one point occupies a patch around him instead of an 8m tail that runs into
        -- whatever happens to be north of him.
        local slot  = math.floor(i / #pts)
        local file_ = slot % 4
        local band  = math.floor(slot / 4)
        local row   = ((band % 2 == 0) and 1 or -1) * math.ceil(band / 2)
        local at = { x = p.pos.x + (file_ - 1.5) * self.TWSpawnSpread,
                     y = p.pos.y + row * self.TWSpawnSpread,
                     z = p.pos.z }

        -- EVERY man's own spot is validated, not just the anchor. One bad man used to be
        -- one bad man; at 24 to a single point it is the whole wave, and a spot inside a
        -- wall spawns someone who is alive, has a target and cannot move. A refused slot
        -- costs one loop iteration, which the `want * 4` budget below already allows for.
        local placeable = true
        pcall(function()
            if self:CampDetectRoof(at) then placeable = false return end
            placeable = self:CampValidateSpot(at, p.pos.z, self.CampMercFootprint) and true or false
        end)
        if placeable then
            local yaw = math.atan2(pp.y - at.y, pp.x - at.x)
            local ent
            pcall(function() ent = self:SpawnEnemyAt("townguard", false, at, yaw) end)

            -- Where he ACTUALLY is, not where we asked for. The engine snaps a spawn to
            -- navmesh and can move him a long way, or drop him through the world; an
            -- earlier run put three of seven men somewhere the player never saw them and
            -- reported success for all seven. A man who landed far from his muster point
            -- is deleted rather than left wherever he went.
            if ent then
                local real
                pcall(function() real = ent:GetWorldPos() end)
                local slip = real and math.sqrt(dist2(real, at)) or nil
                if slip and slip > self.TWSpawnSlipMax then
                    twLog(string.format("  discarded a guard: asked for %s, engine put him %.0fm away",
                                        p.from, slip))
                    pcall(function() System.RemoveEntity(ent.id) end)
                    lost = lost + 1
                else
                    table.insert(spawned, ent)
                end
            else
                lost = lost + 1
            end
        else
            refused = refused + 1
        end

        i = i + 1

        -- A single-point wave whose one point turns out to be unusable would otherwise be
        -- lost entirely. Widen to every point we found and carry on, once.
        if not widened and #spawned == 0 and i >= 3 and #all > #pts then
            widened, pts, i = true, all, 0
            twLog("  the single muster point is refusing - widening to the whole ring")
        end

        if i > want * 4 then break end   -- every point refusing: stop rather than spin
    end

    if #spawned == 0 and #holdover == 0 then
        twLog("muster points validated but nobody spawned")
        return false
    end
    if lost > 0 or refused > 0 then
        twLog(string.format("  %d spawn(s) discarded, %d slot(s) refused as unplaceable",
                            lost, refused))
    end

    -- The wave is the holdovers plus the new men.
    local fresh = #spawned
    for _, e in ipairs(spawned) do table.insert(holdover, e) end
    spawned = holdover

    -- EVERY man is handed the player as his target, and this is not optional once the
    -- wave is spread out. FindEnemyTarget scans 50m CENTRED ON THE MAN; guards mustered
    -- across the far side of a village see nobody at all and simply carry on standing -
    -- which is precisely the "only half of them engaged" that ForcedTargetOf was added to
    -- Raborsch to fix (mercenaries_raborsch.lua). One shared target for the whole force,
    -- as PatrolAlert does: round-robin across marks makes everyone path at a different
    -- moving man and nobody converges. They re-target normally once they are in among the
    -- squad.
    self:TownWatchAimAt(spawned)

    self.TWActive  = true
    self.TWPlace   = placeKey
    self.TWWave    = waveIdx
    self.TWNextAt  = nil
    self.TWLeftAt  = nil
    -- For the inert watchdog: where the wave started and when. Retries are per WAVE -
    -- a bad muster for wave two must not spend wave three's allowance.
    self.TWMusterAt = nowT()
    self.TWMusterCentre = self:TownWatchCentroid(spawned)
    self.TWInertUsed = 0
    -- Every wave replaces the record. The dead of the previous one are left on the
    -- ground (see TownWatchClear) and are nobody's responsibility any more.
    self.TWForce   = spawned
    self.TWAnchor  = pp
    self.TWKills[placeKey] = nil      -- the account is settled; they answered it

    twLog(string.format(
        "%s - WAVE %d (%s): %d guard(s) on the field (%d new of %d asked) from %d muster point(s)",
        placeKey, waveIdx, wave.label, #spawned, fresh, math.max(want, 0), #pts))
    for _, p in ipairs(pts) do twLog("    point: " .. tostring(p.from)) end

    -- Wave three is scheduled the moment wave two ARRIVES, not when it dies: the town does
    -- not wait to see how the muster gets on before calling everyone else out.
    local nxt = self.TWWaves[waveIdx + 1]
    if nxt and nxt.after == "wave two arriving" then
        self.TWNextAt = nowT() + nxt.delay
        twLog(string.format("    wave %d due in %.0fs", waveIdx + 1, nxt.delay))
    end

    pcall(function()
        Game.SendInfoText(self.TWWaveInfoText[waveIdx] or self.TWWaveInfoText[1], false, 0, 6)
    end)
    return true
end

-- ==== standing down ====

function mercenaries:TownWatchCentroid(list)
    local n, sx, sy, sz = 0, 0, 0, 0
    for _, e in ipairs(list or {}) do
        if e and self:IsAliveAndWell(e, true) then
            local p
            pcall(function() p = e:GetWorldPos() end)
            if p then n, sx, sy, sz = n + 1, sx + p.x, sy + p.y, sz + p.z end
        end
    end
    if n == 0 then return nil end
    return { x = sx / n, y = sy / n, z = sz / n }
end

-- THE SAFETY NET. A wave that spawned somewhere it cannot leave is alive, has a target and
-- never arrives - which is what "wave two spawned but just stood there" looks like from the
-- street. Nothing upstream can promise a town spot is escapable, so instead of trying
-- harder to predict it, this measures the outcome: if the wave's centre has not moved after
-- TWInertSecs, the muster was bad and the men are picked up and put down somewhere else.
--
-- Re-placing rather than despawning, because the wave is owed to the player either way.
-- Bounded by TWInertRetries so a village that simply has nowhere good cannot loop.
mercenaries.TWInertSecs    = 25.0
mercenaries.TWInertDist    = 4.0    -- centroid moved less than this = it never set off
mercenaries.TWInertRetries = 2

function mercenaries:TownWatchInertCheck()
    if not (self.TWMusterAt and self.TWMusterCentre) then return end
    if (nowT() - self.TWMusterAt) < self.TWInertSecs then return end
    -- Checked once per window: re-stamp the clock whatever the verdict.
    self.TWMusterAt = nowT()

    local now = self:TownWatchCentroid(self.TWForce)
    if not now then return end
    if math.sqrt(dist2(now, self.TWMusterCentre)) > self.TWInertDist then
        -- They are moving. Re-baseline and leave them alone.
        self.TWMusterCentre = now
        return
    end

    self.TWInertUsed = (self.TWInertUsed or 0) + 1
    if self.TWInertUsed > self.TWInertRetries then
        twLog("the wave is still inert and out of retries - leaving it be")
        self.TWMusterAt = nil
        return
    end

    local pp
    pcall(function() pp = player and player:GetWorldPos() end)
    if not pp then return end

    local alive = self:TownWatchLiving()
    local pts = self:TownWatchPoints(pp, self.TWSpawnPoints, alive)
    if #pts == 0 then twLog("the wave is inert and there is nowhere better") return end

    twLog(string.format("the wave has not moved in %.0fs - re-placing it (attempt %d)",
                        self.TWInertSecs, self.TWInertUsed))

    local moved, k = 0, 0
    for _, e in ipairs(self.TWForce or {}) do
        if e and self:IsAliveAndWell(e, true) then
            local p = pts[(k % #pts) + 1]
            local slot = math.floor(k / #pts)
            local at = { x = p.pos.x + ((slot % 4) - 1.5) * self.TWSpawnSpread,
                         y = p.pos.y + math.floor(slot / 4) * self.TWSpawnSpread,
                         z = p.pos.z }
            pcall(function() e:SetWorldPos(at) end)
            moved, k = moved + 1, k + 1
        end
    end

    self.TWMusterCentre = self:TownWatchCentroid(self.TWForce)
    -- Re-aimed: whatever left them inert may equally have cost them their target.
    self:TownWatchAimAt(self.TWForce)
    twLog(string.format("  moved %d guard(s) to %d fresh point(s)", moved, #pts))
end

function mercenaries:TownWatchLiving()
    local n = 0
    for _, e in ipairs(self.TWForce or {}) do
        if e and self:IsAliveAndWell(e, true) then n = n + 1 end
    end
    return n
end

function mercenaries:TownWatchClear(reason, wiped)
    if not self.TWActive then return end
    local place = self.TWPlace
    self:TownWatchDropAim(self.TWForce)

    for _, e in ipairs(self.TWForce or {}) do
        if e then
            -- The dead stay: bodies the player earned are his to loot, and the loot
            -- sweep is already watching for them. Only the living are withdrawn.
            if self:IsAliveAndWell(e, true) then
                pcall(function() System.RemoveEntity(e.id) end)
            end
        end
    end

    if wiped and place then
        local day = 0
        pcall(function() day = self:LogiUpkeepDay() end)
        self.TWWiped[place] = day
        self:TownWatchSave()
        twLog(string.format("%s lost its whole watch - %g days before it has another",
                            place, self.TWRegenDays))
    end

    self.TWActive, self.TWPlace, self.TWForce = false, nil, {}
    self.TWAnchor, self.TWLeftAt = nil, nil
    self.TWWave, self.TWNextAt = 0, nil
    self.TWMusterAt, self.TWMusterCentre, self.TWInertUsed = nil, nil, 0
    twLog("stood down: " .. tostring(reason))
end

-- The escalation, one tick at a time. The town is "active" from the first wave arriving
-- until either it runs out of waves or the player leaves - INCLUDING the quiet gaps
-- between waves, when nothing of theirs is standing. Those gaps are the point: the street
-- goes silent, and then it does not stay silent.
function mercenaries:TownWatchServiceActive()
    local pp
    pcall(function() pp = player and player:GetWorldPos() end)

    -- Leaving ends the whole sequence, gap or no gap, and costs the town nothing: they
    -- never got to finish, so they are not spent.
    if pp and self.TWAnchor
       and dist2(pp, self.TWAnchor) > (self.TWLeaveRange * self.TWLeaveRange) then
        self.TWLeftAt = self.TWLeftAt or nowT()
        if (nowT() - self.TWLeftAt) >= self.TWLeaveGrace then
            self:TownWatchClear("the player has left the village", false)
        end
        return
    end
    self.TWLeftAt = nil

    local living = self:TownWatchLiving()
    local wave   = self.TWWave or 0
    local nextW  = self.TWWaves[wave + 1]

    if living > 0 then self:TownWatchInertCheck() end

    if living == 0 then
        if not nextW then
            -- The last wave is down. NOW the town is spent - it has nothing else to send,
            -- and will not for three days.
            self:TownWatchClear("the town has run out of men", true)
            return
        end
        -- A wave dying starts the clock on the next one, unless that one was already
        -- scheduled off its own event (wave three is timed from wave two arriving).
        if not self.TWNextAt and nextW.after == "previous wave destroyed" then
            self.TWNextAt = nowT() + nextW.delay
            twLog(string.format("wave %d destroyed - wave %d (%s) in %.0fs",
                                wave, wave + 1, nextW.label, nextW.delay))
        end
    end

    -- Due, and the player is still here to meet it.
    if nextW and self.TWNextAt and nowT() >= self.TWNextAt then
        self.TWNextAt = nil
        if not self:TownWatchMuster(self.TWPlace, wave + 1) then
            -- Nowhere to put them. Try again shortly rather than dropping the wave.
            self.TWNextAt = nowT() + self.TWRetrySecs
            twLog(string.format("wave %d could not muster - retrying in %.0fs",
                                wave + 1, self.TWRetrySecs))
        end
    end
end

-- ==== tick ====

function mercenaries:TownWatchTick()
    if not self.TWEnabled then return end
    local t = nowT()
    if (t - (self._twAt or 0)) < self.TWTickSecs then return end
    self._twAt = t

    if self.TWActive then
        self:TownWatchServiceActive()
        return
    end

    local place = self:TownWatchShouldRespond()
    if place then self:TownWatchMuster(place, 1) end
end

-- ==== persistence ====
-- Only the cooldowns are worth saving. A muster is a fight in progress, and a fight does
-- not survive a level change with anything useful left of it - but "this village has no
-- guards left" has to outlive both the save and the road to the next town.

function mercenaries:TownWatchSave()
    local out = {}
    for place, day in pairs(self.TWWiped or {}) do
        table.insert(out, place .. ":" .. tostring(day))
    end
    pcall(function() self:SaveString("TWWiped", table.concat(out, ",")) end)
end

function mercenaries:TownWatchLoad()
    self.TWWiped = {}
    local s
    pcall(function() s = self:LoadString("TWWiped") end)
    if not s or s == "" then return end
    for pair in string.gmatch(s, "[^,]+") do
        local place, day = string.match(pair, "^([^:]+):(.+)$")
        if place and tonumber(day) then self.TWWiped[place] = tonumber(day) end
    end
end

function mercenaries:TownWatchOnLoad()
    -- The entities died with the level; the record of them must not outlive them or the
    -- next tick services a force of nils and never stands down.
    self.TWActive, self.TWPlace, self.TWForce = false, nil, {}
    self.TWAnchor, self.TWLeftAt, self._twAt = nil, nil, 0
    self.TWKills, self._twCoolSaid, self.TWLastKillAt = {}, nil, nil
    -- A part-finished escalation does not survive a level change either. The town gets
    -- the benefit of the doubt: it keeps its remaining waves rather than being marked
    -- spent for a sequence that never finished.
    self.TWWave, self.TWNextAt = 0, nil
    self.TWMusterAt, self.TWMusterCentre, self.TWInertUsed = nil, nil, 0
    self:TownWatchLoad()
end

-- ==== commands ====

function mercenaries:TownWatchStatus()
    if not self.TWEnabled then
        twLog("the town-response feature is OFF - merc_townwatch_enable turns it on")
    end
    twLog(string.format("enabled=%s active=%s place=%s wave=%d/%d living=%d/%d",
          tostring(self.TWEnabled), tostring(self.TWActive), tostring(self.TWPlace),
          self.TWWave or 0, #self.TWWaves,
          self:TownWatchLiving(), #(self.TWForce or {})))
    if self.TWNextAt then
        twLog(string.format("  wave %d due in %.0fs",
              (self.TWWave or 0) + 1, self.TWNextAt - nowT()))
    end

    local alive = 0
    pcall(function() alive = self:LogiAliveCount() end)
    local inTown, place = self:CrimeInSettlement()
    local fightOn, why = false, nil
    pcall(function() fightOn, why = self:CrimeFightOn() end)
    local sinceKill = nowT() - (self.TWLastKillAt or -1e9)
    twLog(string.format("gates: mercs=%d (need >%d)  inTown=%s (%s)  fighting=%s",
          alive, self.TWMinMercs, tostring(inTown), tostring(place),
          tostring(self:TownWatchInCombat())))
    twLog(string.format("  fight evidence: %s%s",
          fightOn and tostring(why) or "none",
          sinceKill <= self.TWKillIsCombatSecs
            and string.format("; a kill %.0fs ago", sinceKill) or ""))
    twLog(string.format("at difficulty '%s', against %d merc(s), the three waves would be:",
          tostring(self.Difficulty), alive))
    for i, w in ipairs(self.TWWaves) do
        twLog(string.format("  wave %d %-18s %2d guard(s) from %d point(s), %s%s",
              i, w.label, self:TownWatchForceSize(i), w.points,
              w.delay > 0 and string.format("%.0fs after ", w.delay) or "on ", w.after))
    end

    local any = false
    for p, k in pairs(self.TWKills or {}) do
        any = true
        twLog(string.format("  account %-14s %d civilian(s) / %d guard(s)  (need %d or %d)",
              p, k.civilian or 0, k.guard or 0, self.TWCivilianKills, self.TWGuardKills))
    end
    if not any then twLog("  no village has anything on the company's account") end

    local day = 0
    pcall(function() day = self:LogiUpkeepDay() end)
    for p, wiped in pairs(self.TWWiped or {}) do
        twLog(string.format("  spent   %-14s %.1f day(s) until it can answer again",
              p, (wiped + self.TWRegenDays) - day))
    end
end

-- `merc_watch_force` with no argument starts the sequence at wave one; with a number it
-- jumps straight to that wave, which is the only sane way to test waves two and three
-- without killing the ones before them.
function mercenaries:TownWatchForce(line)
    local idx = tonumber(line and string.match(tostring(line), "%d+")) or 1
    if not self.TWWaves[idx] then twLog("no such wave: " .. tostring(idx)) return end
    -- With the feature off the scheduler slot does not run, so a wave forced into the
    -- world would never be serviced: it would never escalate, never leash and never stand
    -- down. Refuse rather than strand one.
    if not self.TWEnabled then
        twLog("the town-response feature is off - merc_townwatch_enable first")
        return
    end

    local place = (self.CWHeat or {}).placeKey
    if not place then twLog("not in a village - nothing to muster") return end
    if self.TWActive and self:TownWatchLiving() > 0 then
        twLog("a wave is already out - merc_watch_stand_down first")
        return
    end
    self:TownWatchMuster(place, idx)
end

-- The waves alone. merc_townwatch_enable is the switch that owns the whole feature; this
-- is the finer control for testing one half of it.
function mercenaries:TownWatchToggle(on)
    self.TWEnabled = on and true or false
    if not self.TWEnabled then self:TownWatchClear("disabled", false) end
    twLog("town watch " .. (self.TWEnabled and "on" or "off"))
    if self.TWEnabled and not self.CrimeWatchEnabled then
        twLog("  ...but the crime watchdog is off, so nothing will ever trigger one." ..
              " merc_townwatch_enable turns on both.")
    end
end

function mercenaries:TownWatchResetCooldowns()
    self.TWWiped = {}
    self:TownWatchSave()
    twLog("every village has its watch back")
end

-- ==== the feature switch ====
--
-- The whole town-response feature - the crime watchdog AND the waves it turns out - is
-- shipped OFF and lives behind this one command. It is unfinished: the muster still has to
-- guess at town terrain, and seventy guards in a street has never been measured on a real
-- machine. Nothing about it should be able to surprise somebody who just wants the mod.
--
-- One switch for both halves on purpose. The watchdog exists only to feed the waves, and a
-- half-enabled feature (tallying kills nothing ever answers) is a worse state than either
-- end of the switch.
--
-- Session-scoped, deliberately NOT saved. "Temporarily disabled" has to mean the next
-- launch is quiet again, whatever was switched on in this one; the flags are plain Lua and
-- so survive a level change within a session, which is all the persistence testing needs.
function mercenaries:TownWatchFeatureEnable(on)
    on = on and true or false
    if not on then
        self:TownWatchClear("the feature was switched off", false)
        self.TWKills = {}
    end
    self.TWEnabled = on
    self.CrimeWatchEnabled = on
    if self.CrimeWatchOnLoad then pcall(function() self:CrimeWatchOnLoad() end) end

    twLog("town response " .. (on and
        "ENABLED for this session (merc_watch_status to see the gates)" or
        "disabled - no scanning, no waves"))
end

function mercenaries:TownWatchFeatureState()
    twLog(string.format("town response: %s (watchdog=%s, waves=%s)",
          (self.TWEnabled and self.CrimeWatchEnabled) and "ON" or "OFF",
          tostring(self.CrimeWatchEnabled), tostring(self.TWEnabled)))
end

mercenaries:DevCommand("merc_townwatch_enable", "mercenaries:TownWatchFeatureEnable(true)",
                       "Turn ON the town-response feature for this session (off by default)")
mercenaries:DevCommand("merc_townwatch_disable", "mercenaries:TownWatchFeatureEnable(false)",
                       "Turn the town-response feature back off")
mercenaries:DevCommand("merc_townwatch", "mercenaries:TownWatchFeatureState()",
                       "Is the town-response feature on?")

mercenaries:DevCommand("merc_watch_status", "mercenaries:TownWatchStatus()",
                       "Town-watch gates, the company's account per village, and cooldowns")
-- '%line', not '%1': the engine only ever substitutes the whole argument line
-- (reference_ccommand_arg_substitution).
mercenaries:DevCommand("merc_watch_force", "mercenaries:TownWatchForce('%line')",
                       "Turn out a wave here and now, ignoring every gate (merc_watch_force 2)")
mercenaries:DevCommand("merc_watch_stand_down", "mercenaries:TownWatchClear('by hand', false)",
                       "Send the current watch away")
mercenaries:DevCommand("merc_watch_on",  "mercenaries:TownWatchToggle(true)",  "Enable the town watch")
mercenaries:DevCommand("merc_watch_off", "mercenaries:TownWatchToggle(false)", "Disable the town watch")
mercenaries:DevCommand("merc_watch_reset", "mercenaries:TownWatchResetCooldowns()",
                       "Clear every village's 3-day regeneration timer")
