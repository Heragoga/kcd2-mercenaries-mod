-- ---------------------------------------------------------------------------
-- OUTLAW, TOWNSMAN, OR NEITHER - the gate that sits above every other rule here.
--
-- The relationship floor (-1 to the player) was doing two jobs it cannot tell apart.
-- A bandit sits at -1 because he is a robber. THE TOWN WATCH SITS AT -1 BECAUSE THE
-- PLAYER IS WANTED - and so does every townsman in a settlement that has turned on him.
-- To IsValidEnemy those two were the same number, the weapon gate is waived on that
-- path, so the squad opened on the watch with nobody having thrown a punch. That is the
-- "mercs attack guards or random NPCs even though the player is not fighting them and
-- they are not attacking" report, and it needs no stance and no order to happen.
--
-- So hostility is no longer a single number. A man is:
--   * "hostile"   - an outlaw. Fair game on every path, including the aggressive stance.
--   * "protected" - the watch, or the people they protect. The squad never STARTS
--                   anything with him, whatever the faction table, the stance or the
--                   fight around him says. He becomes a target the moment he takes the
--                   player or a merc as his own - see AggressorConfirmed.
--   * "neutral"   - neither. Taken only on the ordinary hostile paths (relationship -1,
--                   or confirmed fighting us); never picked up by the aggressive stance.
--
-- RPG.IsPublicEnemy is the primary test and it is vanilla's own: AnimStash.lua calls it
-- to decide whether a body is looted or robbed, and it reads Labels="publicEnemy" off
-- the faction and nothing else (docs/public-enemy.md). Every bandit, Cuman and raider
-- subtree carries the label; no guard or townsman faction does; and all three of the
-- mod's own hostile factions were given it. One engine call, and it is the single most
-- reliable "is this a bandit" answer the game has.
--
-- Cached by WUID: a man's faction and crime role do not change, and this is asked per
-- candidate per cache pass.
-- ---------------------------------------------------------------------------
mercenaries.HostileKindCache    = {}
mercenaries.HostileKindCacheN   = 0
mercenaries.HostileKindCacheMax = 1024

function mercenaries:HostileKindClear()
    self.HostileKindCache, self.HostileKindCacheN = {}, 0
end

function mercenaries:ClassifyHostility(ent)
    local name = ""
    pcall(function() name = ent:GetName() or "" end)

    -- Anything this mod spawned as a hostile is one, whatever the world thinks of him.
    if (self.IsModEnemyName and self:IsModEnemyName(name))
    or string.find(name, "SpawnedFoe_", 1, true)
    or string.find(name, "SpawnedPatrol", 1, true) then
        return "hostile"
    end

    local wuidStr = nil
    pcall(function() wuidStr = tostring(ent.this and ent.this.id or ent.id) end)
    if wuidStr and self.BanditCampActors and self.BanditCampActors[wuidStr] then
        return "hostile"
    end

    local pe = false
    pcall(function()
        local w = ent.this and ent.this.id or ent.id
        pe = (RPG and RPG.IsPublicEnemy and RPG.IsPublicEnemy(w)) and true or false
    end)
    if not pe then pcall(function() pe = ent.soul:IsPublicEnemy() and true or false end) end
    if pe then return "hostile" end

    local faction = self.CrimeFactionOf and self:CrimeFactionOf(ent) or nil
    if faction == "enemiesFaction" or faction == "foeFaction" or faction == "patrolFaction" then
        return "hostile"
    end
    -- Our own spawns that reach here (quartermaster, test NPCs) are refused outright
    -- rather than left to the name checks further up IsValidEnemy.
    if faction and self.CrimeOwnFactions and self.CrimeOwnFactions[faction] then
        return "protected"
    end

    -- Same classifier the crime watchdog uses, and it is the measured one: hostile
    -- faction words first, then the crime_isAuthority/isSecurity contexts, then the
    -- faction path, then the name (docs/crime-watch.md).
    if self.CrimeClassify then
        local kind = self:CrimeClassify(ent, name, faction)
        if kind == "hostile" then return "hostile" end
        if kind == "guard" or kind == "civilian" then return "protected" end
    end

    return "neutral"
end

function mercenaries:HostileKind(ent)
    if not (ent and ent.soul) then return "neutral" end
    local key
    pcall(function() key = tostring(ent.this and ent.this.id or ent.id) end)
    if key then
        local hit = self.HostileKindCache[key]
        if hit then return hit end
    end
    local kind = "neutral"
    local ok, res = pcall(self.ClassifyHostility, self, ent)
    if ok and res then kind = res end
    if key then
        if self.HostileKindCacheN >= self.HostileKindCacheMax then self:HostileKindClear() end
        self.HostileKindCache[key] = kind
        self.HostileKindCacheN = self.HostileKindCacheN + 1
    end
    return kind
end

-- The town watch and the people they protect. See ClassifyHostility.
function mercenaries:IsProtectedNpc(ent)
    return self:HostileKind(ent) == "protected"
end

-- ---------------------------------------------------------------------------
-- IS HE ACTUALLY ATTACKING US, OR DID SOMEBODY JUST WALK INTO SOMEBODY?
--
-- The company defends the player and each other: ANYONE who has taken the player or a
-- merc as his target is a legitimate target, guard or not. The `protected` verdict never
-- blocks that - it only blocks the squad PICKING a fight with a man who is not in one.
--
-- Which makes the quality of "he has taken one of ours as his target" the whole thing,
-- and the raw signal is not good enough on its own. THE ENGINE REGISTERS COLLISIONS AS
-- HITS, constantly - a villager walks into a merc, a horse clips somebody, the column
-- shoulders through a market - and each one can flicker an attacker relationship into
-- existence for a moment. Acting on that instantly is how a bump becomes a dead townsman.
--
-- So a non-outlaw has to clear three bars before the squad will touch him:
--
--   1. WEAPON DRAWN. The single strongest collision filter there is: nobody unsheathes
--      to bump into you. (A guard's halberd is always in his hands, which is why this
--      cannot be the only test - see 2 and 3.)
--   2. A REAL COMBAT STATE - crime_interruptAttack, the same context every scheduler
--      here reads for $inCombat, or IsInCombatDanger. A collision does not open one.
--   3. IT HAS TO LAST, AND ON THE SAME MAN. A bump is a moment and its attention
--      wanders; a fight is continuous and it has one victim. The record is keyed
--      candidate>victim, so a man who shoulders his way down a column - flickering
--      from merc to merc - never accumulates, and only somebody who has held the SAME
--      one of ours for AggressorConfirmSecs clears it.
--
-- An OUTLAW skips all three: he is fair game the instant he is seen, which is what keeps
-- the reaction against bandits as sharp as it was. The delay is only ever paid on
-- somebody the squad would otherwise have had no business touching.
--
-- REAL seconds (os.clock), not System.GetCurrTime: the engine clock runs ~29x fast
-- through a sleep or a wait, which would collapse the window to nothing.
--
-- The window is the one real trade-off here - too short and a bump-and-grumble from a
-- halberdier (whose weapon is ALWAYS in his hands, so bar 1 is free for him) reads as an
-- assault; too long and a merc takes a few extra blows before his mates come. Tunable
-- live with merc_aggro_confirm <seconds> so it can be dialled from inside a session
-- rather than guessed at here.
-- ---------------------------------------------------------------------------
-- How many people the viking stance will hold in the cache at once. See `consider`.
mercenaries.VikingCacheMax = 40

mercenaries.AggressorConfirmSecs = 2.0
mercenaries.AggressorSeen        = {}
mercenaries.AggressorSeenN       = 0
mercenaries.AggressorSeenMax     = 512

local realClock = (os and os.clock) or function() return 0 end

function mercenaries:AggressorClear()
    self.AggressorSeen, self.AggressorSeenN = {}, 0
end

function mercenaries:AggressorForget(key)
    if self.AggressorSeen[key] ~= nil then
        self.AggressorSeen[key] = nil
        self.AggressorSeenN = math.max(0, self.AggressorSeenN - 1)
    end
end

function mercenaries:AggressorConfirmSet(secs)
    self.AggressorConfirmSecs = math.max(0, tonumber(secs) or 2.0)
    self:AggressorClear()
    System.LogAlways("[MercTarget] a non-outlaw must hold one of ours as his target for "
        .. tostring(self.AggressorConfirmSecs) .. "s before the squad will fight him")
end

function mercenaries:AggressorConfirmed(ent, wuid, victimWuidStr)
    if not ent then return false end
    if self:HostileKind(ent) == "hostile" then return true end

    local key = tostring(wuid) .. ">" .. tostring(victimWuidStr)

    local armed = false
    pcall(function() armed = ent.human and ent.human:IsWeaponDrawn() or false end)
    if not armed then self:AggressorForget(key) return false end

    local fighting = false
    pcall(function()
        fighting = ent.soul:HasScriptContext("crime_interruptAttack")
                or ent.soul:IsInCombatDanger() or false
    end)
    if not fighting then self:AggressorForget(key) return false end

    local t = realClock()
    local first = self.AggressorSeen[key]
    if not first then
        if self.AggressorSeenN >= self.AggressorSeenMax then self:AggressorClear() end
        self.AggressorSeen[key] = t
        self.AggressorSeenN = self.AggressorSeenN + 1
        return false
    end
    return (t - first) >= self.AggressorConfirmSecs
end

-- Whether the squad keeps fighting an enemy who has broken and run. Off puts routed
-- enemies back out of reach of every merc. docs/enemy-morale.md.
mercenaries.ChaseFleeingEnemies = true

-- Validate whether an entity is a valid enemy target. skipRelationshipCheck
-- bypasses only the relationship gate, for whoever the player is already
-- fighting; skipWeaponCheck bypasses only the weapon-drawn gate, for candidates
-- that are about to be judged on who they are targeting instead; allowProtected
-- bypasses the townsman/watch gate, for somebody confirmed to be fighting us or
-- called by the player.
-- See docs/combat-target-selection.md for the full ruleset.
function mercenaries:IsValidEnemy(ent, distanceRefEnt, playerWuid, skipRelationshipCheck, skipWeaponCheck, allowProtected)
    if ent.id == player.id then return false end
    if ent:GetName() == "companion_dog" then return false end

    if not self:IsCombatViable(ent) then return false end

    -- A camp that has not alerted yet keeps its people out of the fight entirely, and
    -- that gate was assumed to be enforced by the weapon-drawn check just below - see
    -- the comment on BanditCampSuppressed in mercenaries_banditcamp_quest.lua. It is
    -- not: UpdateEnemyCache calls this with skipWeaponCheck=true on purpose (so a
    -- drawn-but-not-yet-swinging enemy is still cached), which let a merc claim a
    -- still-sheathed, still-docile camp member as a target from as far as
    -- EnemyScanRadius (18m) - well outside BanditCampAlertRange (10m), the range at
    -- which the camp itself would notice and actually fight back. The merc then
    -- chased a target that could neither be beaten into alerting nor killed, and the
    -- distance leash flapped him between draw and sheathe indefinitely. Checked
    -- unconditionally (not just when skipWeaponCheck) so no caller can reintroduce it.
    -- Holding fire while a siege is being built (merc_siege_go releases them).
    if self.SiegePeace then
        local w = ent.this and ent.this.id or ent.id
        -- pcall(f, self, arg), not pcall(function() ... end): the closure form allocates a
        -- fresh closure on every candidate, and this runs per nearby NPC per 300ms tick.
        local ok, sup = pcall(self.SiegeSuppressed, self, tostring(w))
        if ok and sup then return false end
    end

    -- Was `if self.BanditCampSuppressed then` - a METHOD REFERENCE, so always truthy, so
    -- this block ran for every candidate in every session whether or not a bandit camp had
    -- ever existed. Each pass cost a string, a closure and a fresh table (BanditCampSlots).
    -- In open country that is nothing; in Kuttenberg it is dozens of NPCs x ~3 allocations,
    -- three times a second, feeding a collector that pauses the main thread.
    if self.BanditCampAnyUnalerted and self:BanditCampAnyUnalerted() then
        -- entity.this.id, not XGenAIModule.GetMyWUID(ent): FindEnemyTarget (the
        -- proven-working caller of BanditCampSuppressed) keys off entity.this.id, and
        -- BanditCampActors/CachedEnemies elsewhere in this file follow the same rule.
        local candWuid = ent.this and ent.this.id or ent.id
        local ok, suppressed = pcall(self.BanditCampSuppressed, self, tostring(candWuid))
        if ok and suppressed then return false end
    end

    if not skipWeaponCheck and ent.human and not ent.human:IsWeaponDrawn() then return false end
    if distanceRefEnt then
        local tp = ent:GetPos()
        local refPos = distanceRefEnt:GetPos()
        if tp and refPos then
            local dx, dy, dz = tp.x - refPos.x, tp.y - refPos.y, tp.z - refPos.z
            if math.sqrt(dx*dx + dy*dy + dz*dz) > self.TargetDetectionRadius then return false end
        end
        -- A camp wall between us is not a fight: don't lock on to someone who cannot
        -- be reached. Elevated shooters (tower, cart) are exempt inside the check.
        if self.NavTargetBlocked and self:NavTargetBlocked(distanceRefEnt, ent) then return false end
    end
    
    local eid = tostring(ent.soul:GetId())

    -- Skip our own: regular mercs, archers, and the custom hero companion.
    -- See mercenaries_perf.lua:IsOwnSoulId - O(1) hash lookup, same containment
    -- semantics as the old Souls/ArcherSouls/StaticArcherSouls triple scan.
    if self:IsOwnSoulId(eid) then return false end
    -- Companions are not in the Souls tables IsOwnSoulId is built from - each one has
    -- its own soul - so they are recognised by name instead. IsHeroName, not the old
    -- prefix: they are spawned as SpawnedFriend_hero_ now, and a miss here means the
    -- squad treats its own named companions as targets.
    if self:IsHeroName(ent:GetName() or '') then
        return false
    end

    -- THE SQUAD NEVER STARTS ANYTHING WITH THE WATCH, OR WITH THE PEOPLE IT PROTECTS.
    -- Checked above the relationship gate rather than inside it, because the relationship
    -- gate is what gets it wrong: a wanted player drives every guard in the settlement to
    -- exactly the same -1 floor a bandit sits at, and the drawn-weapon proof is waived on
    -- that path, so the squad opened on the watch with nobody having thrown a punch. It
    -- sits above the aggression ladder too - every rung of it is about outlaws.
    --
    -- It is NOT a rule about who may be fought. allowProtected is how the three things
    -- that outrank it get through, and the first of them is the important one:
    --   * he is actively fighting the player or a merc (AggressorConfirmed - and that is
    --     where the collision filter lives, because a bump is not an assault);
    --   * he has already been confirmed as an attacker this fight (IsRecentAttacker),
    --     which is how the whole squad joins in rather than one man;
    --   * the player called him by name.
    if not allowProtected and self:IsProtectedNpc(ent) then return false end

    -- Must be genuinely hostile: relationship to the player pinned at exactly -1
    -- (the faction-hostile floor). Neutral/unresolved (0, 0.5, nil) is not fair
    -- game. skipRelationshipCheck bypasses only this gate. See the doc.
    if not skipRelationshipCheck then
        local rel_curr = ent.soul:GetRelationship(playerWuid, "Current")
        if rel_curr == nil or rel_curr > -1.0 then
            return false
        end
    end
    -- Never a target: a man who has surrendered, a frightened civilian
    -- (crime_indifferentFlee), or anyone a quest is protecting.
    -- "crime_fleeAfterSurrender" used to be queried here and does not exist in
    -- ScriptContext.xml, so every candidate check logged
    -- "[Error] Script context does not exist" - hundreds of lines a fight. Only
    -- visible on the dev build. crime_indifferentFlee is the real neighbouring one.
    if ent.soul:HasScriptContext("combat_surrender")
    or ent.soul:HasScriptContext("crime_indifferentFlee")
    or ent.soul:HasScriptContext("combat_immortalityProtection") then
        return false
    end
    -- A routed enemy is still an enemy - see docs/enemy-morale.md for why they rout at
    -- all. Pursuit is bounded by the melee module's own leashes, so this cannot walk the
    -- company off the map.
    if not self.ChaseFleeingEnemies
    and (ent.soul:HasScriptContext("combat_flee")
      or ent.soul:HasScriptContext("crime_interruptFlee")) then
        return false
    end

    return true
end

-- ---------------------------------------------------------------------------
-- WHO IS FIGHTING US - recorded by the BEHAVIOUR TREE, not by Lua.
--
-- `soul:GetTarget()` is NOT a Lua scriptbind in this engine. It appears nowhere in
-- vanilla's own scripts (where soul:IsInCombatDanger and soul:HasScriptContext are used
-- dozens of times) and every call the mod makes to it sits inside a pcall, so it fails
-- silently and reads as "nobody is targeting anyone". Anything built on it is dead code
-- that looks alive - which is exactly what happened: the whole lock-on detection was
-- inert, so against enemies the relationship floor refuses (base-game and DLC camps, who
-- are not pinned at -1) the squad had no targets at all and stood and watched.
--
-- The engine's GetTarget BEHAVIOUR-TREE node does work, and always has - it is what
-- feeds $candidateTarget for the acquisition pass. So the authoritative answer comes
-- from there: EvaluateCombatTarget records every candidate it confirms is locked onto
-- the player or onto a merc, and this register is what the cache reads back.
--
-- Entries expire: a man who broke off, died or streamed out must stop seeding the fight.
-- ---------------------------------------------------------------------------
mercenaries.AttackerSeen = {}          -- [wuidStr] = time last confirmed fighting us
mercenaries.AttackerMemorySecs = 6.0

function mercenaries:NoteAttacker(wuid)
    if not wuid then return end
    local t = 0
    pcall(function() t = System.GetCurrTime() or 0 end)
    self.AttackerSeen[tostring(wuid)] = t
end

function mercenaries:IsRecentAttacker(wuid)
    if not wuid then return false end
    local at = self.AttackerSeen[tostring(wuid)]
    if not at then return false end
    local t = 0
    pcall(function() t = System.GetCurrTime() or 0 end)
    if (t - at) > self.AttackerMemorySecs then
        self.AttackerSeen[tostring(wuid)] = nil
        return false
    end
    return true
end

-- Is this man on the SAME SIDE as the one confirmed to be fighting us? Hostile to him
-- means he is fighting our enemy too and is never a target; allied means he is in the
-- band; neither answer available falls back to a shared soul, which is what a base-game
-- camp is. See docs/combat-target-selection.md, "The fight group".
--
-- ALLIED MEANS 1, NOT "ANYTHING ABOVE ZERO". The old threshold was `rel > 0`, and this
-- mod's own relationship gate documents 0.5 as a NEUTRAL reading - it is an authored
-- value in the vanilla faction tree. So every armed neutral near a brawl read as "in the
-- band" and was swept in with the relationship floor waived, which is the same caravan-
-- guard bug this function was written to fix, reintroduced one threshold lower.
function mercenaries:StandsWith(ent, a)
    if not (a and ent and ent.soul) then return false end
    -- Never, whatever the numbers say: a bandit fighting the watch does not make the
    -- watch our enemy. Cheaper than the relationship call, so it goes first.
    if self:IsProtectedNpc(ent) then return false end
    local rel
    pcall(function() rel = ent.soul:GetRelationship(a.wuid, "Current") end)
    if rel ~= nil then
        if rel <= -1.0 then return false end
        if rel >= 1.0 then return true end
    end
    local id
    pcall(function() id = tostring(ent.soul:GetId()) end)
    return (id ~= nil) and (a.soul ~= nil) and (id == a.soul)
end

-- Is this WUID the player or one of the squad? OurWuids is rebuilt once per enemy-cache
-- pass; anything asking earlier than that reads an empty set and simply says no.
function mercenaries:IsOneOfOurs(wuid)
    if not wuid then return false end
    return (self.OurWuids or {})[tostring(wuid)] == true
end

-- Called every 300ms from CombatScanLoop: one sphere query + all soul-API
-- validation for the whole squad, cached in mercenaries.CachedEnemies.
-- Candidates that have not drawn a weapon yet are cached too and are fair game
-- for targeting; the armed flag only tells the logistics tick whether a fight is
-- actually under way. See the doc.
function mercenaries:UpdateEnemyCache()
    local ok, err = pcall(function()
        self.CachedEnemies = {}

        -- Who counts as "one of ours" for LockedOntoUs. Built here rather than per
        -- candidate: this pass already walks the roster once for the load map below.
        local ours = {}
        local load = {}
        for _, targetWuidStr in pairs(self.MercTargetOf) do
            load[targetWuidStr] = (load[targetWuidStr] or 0) + 1
        end
        self.TargetLoad = load

        if not player then return end
        local playerPos = player:GetPos()
        if not playerPos then return end

        local playerWuid = player.this and player.this.id or player.id
        ours[tostring(playerWuid)] = true
        for _, ent in pairs(self.ActiveMercs or {}) do
            local w = ent and (ent.this and ent.this.id or ent.id)
            if w then ours[tostring(w)] = true end
        end
        self.OurWuids = ours

        -- Alerted: look as far as EnemyAlertRadius. The alert is raised below the moment an
        -- ARMED hostile is in the cache (a fight, not a passer-by) and held for a few seconds
        -- after the last one, so a squad standing in a market is not sweeping 60m of NPCs.
        local radius = self.EnemyAlerted and self.EnemyAlertRadius or self.EnemyScanRadius

        -- Read once per pass, not per candidate: `consider` below branches on it twice.
        local vikingOn = (self:EngageCode() == 1)

        -- Where the men confirmed to be FIGHTING us are standing, and the armed
        -- candidates the normal gates turned away. Both feed the second pass below, and
        -- `maybe` is also published for ScanForEnemies to hand to the behaviour tree -
        -- the BT's GetTarget node is the only thing that can tell us they are fighting.
        local attackers, maybe = {}, {}

        local function consider(ent, entWuid, pos)
            if not (ent and type(ent) == "table" and ent.soul) then return end
            -- Read once and handed down: EngageCacheAccepts needs it for the lock-on
            -- gate and the cache entry needs it for the alert, and it is an engine call.
            local armed = (ent.human == nil) or ent.human:IsWeaponDrawn()
            -- UNARMED and not a confirmed attacker: nothing downstream can accept him, so
            -- stop after the one call above instead of paying the full acceptance chain.
            --   * LockedOntoUs returns false outright for armed == false;
            --   * the aggressive stance's own IsValidEnemy call keeps its weapon gate, so
            --     it rejects him anyway - just ~6 engine calls later;
            --   * `maybe` (the fight-group second pass) only ever takes ARMED candidates;
            --   * the alert only ever rises from ARMED cache entries.
            -- The one path this closes is an unarmed NPC sitting at the -1 relationship
            -- floor entering the cache as a non-threat - and he enters on the very next
            -- 300ms pass the moment he draws, or immediately via `confirmed` if he lands
            -- a blow. In a town this is the whole cost: ~10 engine calls per bystander
            -- per pass became 1. See docs/performance.md.
            -- ...unless the men have been told to kill everyone, in which case an unarmed
            -- bystander is precisely who they are looking for. The early-out is the whole
            -- reason a town is cheap, so viking is also the one stance that costs what a
            -- town used to cost - which is what VikingCacheMax below is for.
            if not armed and not vikingOn and not self:IsRecentAttacker(entWuid) then return end
            -- The engagement stance can widen this: see EngageCacheAccepts.
            local accept, viaLockOn =
                self:EngageCacheAccepts(ent, playerWuid, armed, self:IsRecentAttacker(entWuid))
            if accept then
                -- A CEILING ON THE MASSACRE, and it is a performance guard rather than a
                -- mercy: viking admits every living soul in the alert radius, which in
                -- Kuttenberg is hundreds, and PickCombatTarget sweeps the whole cache per
                -- merc per tick. Fifty men have no use for more than this many targets at
                -- once, and as each one dies the next pass admits another - so nothing is
                -- spared, it just arrives in waves. Only viking is ever capped.
                if vikingOn and #self.CachedEnemies >= (self.VikingCacheMax or 40) then return end
                table.insert(self.CachedEnemies, { entity = ent, wuid = entWuid, armed = armed, pos = pos })
                -- Identity, not just a position: StandsWith has to ask a candidate what
                -- he thinks of THIS man.
                if viaLockOn and pos then
                    local sid
                    pcall(function() sid = tostring(ent.soul:GetId()) end)
                    table.insert(attackers, { x = pos.x, y = pos.y, z = pos.z,
                                              wuid = entWuid, soul = sid })
                end
            elseif armed and pos then
                table.insert(maybe, { entity = ent, wuid = entWuid, pos = pos })
            end
        end

        -- Shared player-centered scan covers this exact (pos, radius) - see
        -- mercenaries_perf.lua and docs/performance.md #4. A nil return means
        -- not covered/stale, never "nobody there", so the fallback is the
        -- original box query, unchanged.
        local shared = self:PerfNpcsNear(playerPos, radius, 400)
        if shared then
            for _, e in ipairs(shared) do
                local p = e.pos
                consider(e.entity, e.wuid, p and { x = p.x, y = p.y, z = p.z } or nil)
            end
        else
            local ents = System.GetPhysicalEntitiesInBoxByClass(playerPos, radius, "NPC")
            if ents then
                for _, ent in pairs(ents) do
                    if ent and type(ent) == "table" then
                        local p0 = ent:GetPos()
                        consider(ent, ent.this and ent.this.id or ent.id,
                                 p0 and { x = p0.x, y = p0.y, z = p0.z } or nil)
                    end
                end
            end
        end

        -- ---------------------------------------------------------------------------
        -- SECOND PASS: the men standing WITH whoever is fighting us.
        --
        -- The lock-on gate above only admits the individuals who have actually taken one
        -- of ours as a target - in a camp of ten that is the two or three who reacted
        -- first. The rest are still behind the relationship floor, so the squad has two
        -- or three claimable enemies for twenty men, and seventeen of them stand there
        -- with nothing to go at. That is the "only three of twenty ever engaged" report,
        -- and it is not the swarm cap: there was nothing to be capped.
        --
        -- A fight is a fight between GROUPS. Once someone is confirmed to be fighting us,
        -- every ARMED man standing with him is in it, and the squad should commit to all
        -- of them - which is what "the alert engages everyone" has always meant.
        --
        -- Deliberately narrow, on four counts at once:
        --   * it does nothing at all unless somebody is already fighting us, so peace is
        --     untouched and so is the cost - `maybe` is only walked when `attackers` is
        --     non-empty, which is almost never;
        --   * ARMED only, which is the same drawn-weapon proof the aggressive stance
        --     leans on - a bystander in a market is not swept up by a brawl beside him;
        --   * and ON THAT MAN'S SIDE, or the pass claims the people our enemy is himself
        --     fighting - a caravan's guards, a random encounter's travellers (StandsWith);
        --   * within FightGroupRange of a confirmed attacker, not of the player, so it
        --     grows from the fight rather than from wherever the player happens to be;
        --   * IsOwnSide plus the whole of IsValidEnemy still apply, so it can never turn
        --     the squad on itself, on a hero, or on a man who is fleeing or protected.
        -- ---------------------------------------------------------------------------
        if #attackers > 0 and #maybe > 0 then
            local r2 = (self.FightGroupRange or 20.0) ^ 2
            for _, m in ipairs(maybe) do
                -- WHO he is near, not merely that he is near someone.
                local with = nil
                for _, a in ipairs(attackers) do
                    local dx, dy, dz = m.pos.x - a.x, m.pos.y - a.y, m.pos.z - a.z
                    if (dx * dx + dy * dy + dz * dz) <= r2 then with = a break end
                end
                if with and not self:IsOwnSide(m.entity)
                   and self:StandsWith(m.entity, with)
                   and self:IsValidEnemy(m.entity, player, playerWuid, true, false) then
                    table.insert(self.CachedEnemies,
                                 { entity = m.entity, wuid = m.wuid, armed = true, pos = m.pos })
                    m.taken = true
                end
            end
        end

        -- Whatever is left is what ScanForEnemies offers the behaviour tree as extra
        -- candidates, so its GetTarget node can find the men who ARE fighting us among
        -- them. That is the bootstrap: one confirmed attacker seeds NoteAttacker, and the
        -- next pass through here admits him and everyone standing with him.
        local rest = {}
        for _, m in ipairs(maybe) do
            if not m.taken then table.insert(rest, m) end
        end
        self.MaybeEnemies = rest

        -- Raise / hold / drop the alert from what this pass just found. Armed only: an
        -- unarmed hostile is an aggro source, not a fight, and widening the sweep for one
        -- would keep the squad permanently alert in any town with a grumpy NPC in it.
        local armedNear = false
        for _, e in ipairs(self.CachedEnemies) do
            if e.armed then armedNear = true break end
        end

        -- The PLAYER's own combat state is the other trigger, and it is the important one:
        -- the cache above only reaches EnemyScanRadius while unalerted, so an alert raised
        -- purely from its contents can never fire for something far away - the very case this
        -- exists for. Whether the player is fighting is knowable at any distance.
        -- ...and it fires on the player DRAWING AND LOCKING ON, not only on him being
        -- swung at. The unalerted cache reaches EnemyScanRadius (18m) from the player, so
        -- against base-game enemies - who are not in it until they commit - the squad
        -- could not react until the fight was already on top of him. Both halves of this
        -- are knowable at any distance, and raising the alert widens the sweep to
        -- EnemyAlertRadius so the whole engagement becomes visible at once.
        --
        -- IsInCombatDanger, not GetTarget. `soul:GetTarget()` is not a Lua scriptbind
        -- (see NoteAttacker) so the version of this that asked it never fired at all;
        -- IsInCombatDanger is used on player.soul throughout vanilla's own scripts and
        -- means exactly what is wanted here - the player is in a fight, whether or not a
        -- blow has landed on HIM yet, which the crime context below only catches after.
        if not armedNear then
            pcall(function()
                if not (player and player.soul) then return end
                if player.soul:HasScriptContext("crime_interruptAttack") then armedNear = true return end
                if player.soul:IsInCombatDanger() then armedNear = true end
            end)
        end
        -- ...and so is "one of ours is already committed to someone".
        if not armedNear and next(self.MercTargetOf or {}) ~= nil then armedNear = true end
        local now = 0
        pcall(function() now = System.GetCurrTime() or 0 end)
        if armedNear then
            self._alertAt = now
            if not self.EnemyAlerted then
                self.EnemyAlerted = true
                System.LogAlways('[Mercenary Jeff] squad alert: scanning to ' ..
                                 tostring(self.EnemyAlertRadius) .. 'm')
            end
        elseif self.EnemyAlerted then
            if not self._alertAt or (now - self._alertAt) >= self.EnemyAlertHoldSecs then
                self.EnemyAlerted = false
                System.LogAlways('[Mercenary Jeff] squad alert over')
                -- The end of a fight is the other moment a merc reliably ends up with a
                -- behaviour that has stopped producing movement - combat replaced follow,
                -- and whatever ran next did not always give it back. Same bounded window
                -- the dismount and order-release cases use.
                pcall(function() self:BeginFollowVerify("battle over") end)
            end
        end

        -- Open the anti-swarm cap up when the squad outnumbers the enemy. A hard cap
        -- of 2 with no at-cap fallback in PickCombatTarget meant surplus mercs found
        -- every candidate full and never engaged at all.
        --
        -- The CEILING has to scale too. At a fixed SwarmCapMax of 4, a 50-man squad against
        -- a handful of bandits could only ever commit 4 men per enemy - everyone past that
        -- found every candidate full, kept no target, and held formation. That is the
        -- "half of them engage, half straggle at the back" report: they were not stuck,
        -- they had simply been refused a target. The ceiling now rises with how badly the
        -- enemy is outnumbered, so a big squad commits properly, and it is still a ceiling
        -- so a lone bandit does not get all fifty at once.
        local n    = #self.CachedEnemies
        local mercs = _G.MercCount or 0
        local want  = (n > 0) and math.ceil(mercs / n) or self.SwarmCap
        local ceil_ = (n > 0)
            and math.max(self.SwarmCapMax or 4, math.ceil(mercs / (n * 2)))
            or  (self.SwarmCapMax or 4)
        if ceil_ > (self.SwarmCapHard or 10) then ceil_ = (self.SwarmCapHard or 10) end
        self.EffectiveSwarmCap = math.max(self.SwarmCap, math.min(ceil_, want))

        -- Animals run every 3rd tick (~0.9s), horse cleanup every 9th (~2.7s) -
        -- neither needs the combat cadence, and the horse sweep is a 100m query.
        self._animalQueryTick = (self._animalQueryTick or 0) + 1
        if self._animalQueryTick >= 3 then
            self._animalQueryTick = 0
            self._horseQueryTick = (self._horseQueryTick or 0) + 1

            for _, className in ipairs({ "Wolf", "Dog" }) do
                local aEnts = System.GetPhysicalEntitiesInBoxByClass(playerPos, radius, className)
                if aEnts then
                    for _, ent in pairs(aEnts) do
                        if ent and type(ent) == "table" and ent.soul then
                            if self:IsValidEnemy(ent, player, playerWuid) then
                                local entWuid = ent.this and ent.this.id or ent.id
                                local p0 = ent:GetPos()
                                local pos = p0 and { x = p0.x, y = p0.y, z = p0.z } or nil
                                table.insert(self.CachedEnemies, { entity = ent, wuid = entWuid, armed = true, pos = pos })
                            end
                        end
                    end
                end
            end
        end

        if (self._horseQueryTick or 0) >= 3 then
            self._horseQueryTick = 0

            -- Orphan horse cleanup: despawn MercenaryHorse_* whose owner is dead/missing.
            local horses = System.GetPhysicalEntitiesInBoxByClass(playerPos, 100.0, "Horse")
            if horses then
                for _, horseEnt in pairs(horses) do
                    if horseEnt and horseEnt:GetName() then
                        local horseName = horseEnt:GetName()
                        if string.find(horseName, 'MercenaryHorse_', 1, true) then
                            -- Re-applied here rather than only at mount: a horse that has been
                            -- re-physicalised loses it. docs/collision-ghosting.md.
                            if self:GhostCollisionOn() then
                                self:ApplyCollisionGhost(horseEnt, self.GhostHorseMask)
                            end

                            local mercName = string.sub(horseName, string.len('MercenaryHorse_') + 1)
                            local shouldDespawn = false
                            local reason = ""

                            local mercEnt = self.ActiveMercs[mercName]

                            if not mercEnt then
                                shouldDespawn = true
                                reason = "merc not in ActiveMercs"
                            elseif not self:IsAliveAndWell(mercEnt, true) then
                                shouldDespawn = true
                                reason = "merc dead or unconscious"
                            -- The horse lifecycle that normally does this lives in
                            -- follow.xml, and follow is REPLACED by combat_melee the
                            -- moment a fight starts - so the one case it can never
                            -- clean up is the one dismount-to-fight creates. Both
                            -- globals are already debounced (1.2s on the mount poll,
                            -- 2s/10s on the threat latch), so neither flickers.
                            elseif not _G.PlayerMounted then
                                shouldDespawn = true
                                reason = "player is on foot"
                            elseif _G.MercDismountThreat then
                                shouldDespawn = true
                                reason = "dismounted to fight"
                            end

                            if shouldDespawn then
                                System.LogAlways('[MercHorse] Despawning orphan horse: ' .. horseName .. ' (' .. reason .. ')')
                                if self.PerfUnregister then self:PerfUnregister(horseName) end
                                pcall(function() System.RemoveEntity(horseEnt.id) end)
                            end
                        end
                    end
                end
            end

        end
    end)

    if not ok then
        System.LogAlways('[Mercenary Jeff] UpdateEnemyCache Error: ' .. tostring(err))
    end
end

-- Per-merc, each BT tick: rank the pre-validated CachedEnemies by distance from
-- this merc (cheap math, no soul API) and keep the 8 nearest, nearest-first.
-- Bounded insertion instead of a full sort - each candidate is only ever
-- compared against the current top 8, never against the whole list.
-- How many nearest cached enemies the BT runs its GetTarget node over, per merc, per poll.
-- 8 was the shipped value; 4 halves the densest engine-call site in the mod during a fight.
mercenaries.ScanMaxCandidates = 4

function mercenaries:ScanCandidatesSet(n)
    self.ScanMaxCandidates = tonumber(n) or 4
    System.LogAlways("[Mercenary Jeff] target-scan candidates per merc per poll = " ..
        tostring(self.ScanMaxCandidates) ..
        " (each one is an engine GetTarget; combat only, invisible in a peaceful bench)")
end

function mercenaries:ScanForEnemies(bt_data, myWuid)
    local ok, err = pcall(function()
        bt_data.enemiesArray = {}

        local me = XGenAIModule.GetEntityByWUID(myWuid)
        if not me then return end

        local myPos = me:GetPos()
        if not myPos then return end

        -- Cap candidates: each one the BT checks costs an engine GetTarget call, per merc,
        -- per poll. At 50 mercs against a crowd that is the single densest engine-call site
        -- in the mod - and it is COMBAT-ONLY, so it never shows up in a peaceful bench.
        --
        -- 4, not 8. The list is sorted NEAREST FIRST, and this feeds two things: the lock-on
        -- detection (EvaluateCombatTarget -> NoteAttacker, which learns who is fighting us)
        -- and nothing else - PickCombatTarget re-reads the full cache itself and is not
        -- capped by this. So the only thing a lower cap can cost is noticing an attacker who
        -- is 5th-nearest or further, and he is picked up on the next poll as the melee moves.
        -- A tunable field rather than a local so it can be A/B'd live: merc_scan_lean/full.
        local maxCandidates = self.ScanMaxCandidates or 4
        local nearWuid, nearDist, count = {}, {}, 0

        -- Cached enemies first, then the armed candidates the cache refused. The BT runs
        -- its GetTarget node over every one of these, and that node is the only working
        -- way to learn who is fighting us - see NoteAttacker. `rest` is empty except in a
        -- real fight, so in a town this adds nothing.
        local pools = { self.CachedEnemies or {}, self.MaybeEnemies or {} }
        for _, pool in ipairs(pools) do
        for _, entry in ipairs(pool) do
            local ent = entry.entity
            if ent then
                local ep = entry.pos or ent:GetPos()
                if ep then
                    local dx = ep.x - myPos.x
                    local dy = ep.y - myPos.y
                    local dz = ep.z - myPos.z
                    -- Squared distance: same ordering as sqrt, no sqrt call needed.
                    local dist = dx*dx + dy*dy + dz*dz

                    if count < maxCandidates or dist < nearDist[count] then
                        local i = (count < maxCandidates) and (count + 1) or maxCandidates
                        while i > 1 and nearDist[i - 1] > dist do
                            nearDist[i] = nearDist[i - 1]
                            nearWuid[i] = nearWuid[i - 1]
                            i = i - 1
                        end
                        nearDist[i] = dist
                        nearWuid[i] = entry.wuid
                        if count < maxCandidates then count = count + 1 end
                    end
                end
            end
        end
        end

        for i = 1, count do
            table.insert(bt_data.enemiesArray, nearWuid[i])
        end
    end)

    if not ok then
        System.LogAlways('[Mercenary Jeff] ScanForEnemies Error: ' .. tostring(err))
    end
end

-- Within EnemyScanRadius of the player, i.e. the same reach the enemy cache uses.
-- The player's own lock-on reaches much further; a merc sent after something that
-- far off just trips the 20m follow leash, gets pulled back, re-acquires, and
-- sits in the engine's "running to battle" state forever without ever arriving.
function mercenaries:IsWithinAggroRange(ent)
    local ok, result = pcall(function()
        local ep, pp = ent:GetPos(), player and player:GetPos()
        if not ep or not pp then return false end
        -- Same reach the cache is currently using, or the player's own target would be
        -- refused at exactly the distances the alert exists to cover.
        local r = self.EnemyAlerted and self.EnemyAlertRadius or self.EnemyScanRadius
        local dx, dy, dz = ep.x - pp.x, ep.y - pp.y, ep.z - pp.z
        return (dx*dx + dy*dy + dz*dz) <= (r * r)
    end)
    return ok and result or false
end

-- Did the engine EVER answer "what is the player fighting"?
--
-- Three behaviour trees ask, with <GetTarget ReferenceNPC="$playerWUID">, and every poll of
-- every merc answers "[GetTarget]:Cannot find host NPC" - the node resolves an NPC by WUID
-- and the player is not one. So bt_data.playerCombatTarget is expected to be nil for ever,
-- and the branch in PickCombatTarget that reads it is expected to be unreachable.
--
-- Expected, not proven, which is why the node was gated rather than deleted. This fires once
-- per session the first time the value is ever non-nil. If the line never appears, the branch
-- is dead and both it and the node can go; if it does, the node works under some condition
-- worth finding and the gate is the right shape after all.
mercenaries._pctProbed = false

function mercenaries:PlayerCombatTargetProbe()
    if self._pctProbed then return end
    self._pctProbed = true
    System.LogAlways("[Mercenary Jeff] GetTarget on the PLAYER answered for the first time - " ..
                     "the player-target branch is reachable after all (see PlayerCombatTargetProbe)")
end

-- THE one place MercTargetOf is written, so TargetLoad is always maintained with it.
--
-- TargetLoad used to be rebuilt only once per UpdateEnemyCache pass (300ms) and
-- TryClaimTarget never touched it, so every merc evaluating inside that window judged
-- the cap against the same stale snapshot. With a lot of enemies about that breaks
-- twice over: they all pile onto the same nearest man because he still reads as empty,
-- and the NEXT snapshot then shows every candidate far OVER cap - so the men who did
-- not get a fight are refused every target there is and simply stand through the
-- battle. It also flaps: a merc whose target dies is refused a new one, sheathes, and
-- is handed one again a tick later. Counting the claim as it is made fixes both.
-- UpdateEnemyCache still recounts from scratch each pass, which corrects any drift.
-- [myWuidStr] = when the claim was made. A claim is normally released by combat_melee's
-- OnFail; PruneCombatClaims uses this to evict the ones where that never ran.
mercenaries.MercClaimAt = {}
-- How long a claim may stand without its holder ever being in combat danger. Longer than any
-- legitimate approach across open ground, short enough that an orphan cannot outlive a fight.
mercenaries.MercClaimGraceSecs = 45.0

function mercenaries:MercSetClaim(myWuidStr, targetWuidStr)
    local prev = self.MercTargetOf[myWuidStr]
    if prev == targetWuidStr then return end
    if prev then
        local n = (self.TargetLoad[prev] or 1) - 1
        self.TargetLoad[prev] = (n > 0) and n or nil
    end
    self.MercTargetOf[myWuidStr] = targetWuidStr
    if targetWuidStr then
        self.TargetLoad[targetWuidStr] = (self.TargetLoad[targetWuidStr] or 0) + 1
        local now = 0
        pcall(function() now = System.GetCurrTime() or 0 end)
        self.MercClaimAt[myWuidStr] = now
    else
        self.MercClaimAt[myWuidStr] = nil
    end
end

function mercenaries:MercDropClaim(myWuid)
    if not myWuid then return end
    self:MercSetClaim(tostring(myWuid), nil)
end

-- How far a fight spreads from whoever is confirmed to be fighting us: every armed man
-- inside this of an attacker counts as being in the same battle. See the second pass in
-- UpdateEnemyCache.
mercenaries.FightGroupRange = 20.0

-- How close a merc must already be to the fight before he is allowed past the
-- anti-swarm cap. See the fallback at the end of PickCombatTarget.
mercenaries.SwarmOverflowRange = 18.0

-- Is this WUID an archer merc? One entity lookup, so callers that ask per candidate
-- resolve it once and test StaticArcherPerched (an O(1) table read) per target instead.
-- Only ever a merc asks (static archers pick their own targets in their own scheduler),
-- so '_archer_' in the name means an archer MERC and not an enemy bowman.
function mercenaries:MercIsArcherWuid(myWuid)
    local myName
    pcall(function()
        local me = XGenAIModule.GetEntityByWUID(myWuid)
        myName = me and me:GetName()
    end)
    return (myName and self:IsArcherName(myName)) or false
end

mercenaries.ArcherHoldFire   = true   -- merc_archer_holdfire 0/1
mercenaries.ArcherMeleeClear = 2.2    -- a friend closer than this to the target = no shot

-- Is one of ours - a merc or the player - within `r` of `pos`? `skip` is the asking man's
-- own ENTITY id (ActiveMercs holds entities, not wuids), so he does not count himself.
-- Fifty distance checks at most, and only when an archer picks a target.
function mercenaries:FriendlyWithin(pos, r, skip)
    local r2 = r * r
    local pp
    pcall(function() pp = player and player:GetWorldPos() end)
    if pp then
        local dx, dy = pp.x - pos.x, pp.y - pos.y
        if dx * dx + dy * dy <= r2 then return true end
    end
    for _, ent in pairs(self.ActiveMercs or {}) do
        if ent and ent.id ~= skip then
            local p
            pcall(function() p = ent:GetWorldPos() end)
            if p then
                local dx, dy = p.x - pos.x, p.y - pos.y
                if dx * dx + dy * dy <= r2 then return true end
            end
        end
    end
    return false
end

function mercenaries:ArcherHoldFireSet(on)
    self.ArcherHoldFire = on and true or false
    pcall(function() self:SaveString("MercArcherHoldFire", self.ArcherHoldFire and "1" or "0") end)
    System.LogAlways("[Mercenaries] archers " .. (self.ArcherHoldFire and "hold fire into a melee" or "shoot into a melee"))
end

-- May this merc go for this target? The one rule here is the PERCHED archer: a man on a
-- watchtower deck or a cart bed is archer-merc business only, because a footman walks to
-- the foot of the thing and stands there while the distance leash flaps him between drawn
-- and sheathed.
--
-- It used to refuse EVERY entity in StaticArchers, which is where the besiegers at
-- Raborsch went wrong: they are static archers standing on open ground, so the whole
-- company refused to touch them and the siege was fought against the foot alone. Perch,
-- not registry membership, is what actually puts a target out of reach.
--
-- Keyed by entity.this.id, which is what CachedEnemies stores and what SpawnStaticArcher
-- records under - the two keyspaces have to agree or this silently never matches.
function mercenaries:MercMayClaim(myWuid, targetWuidStr, iAmArcher)
    if not (self.StaticArcherPerched and self:StaticArcherPerched(targetWuidStr)) then return true end
    if iAmArcher ~= nil then return iAmArcher end
    return self:MercIsArcherWuid(myWuid)
end

-- Claim a target for a merc if it's below the cap; records it in MercTargetOf.
-- force bypasses the cap - used only for genuine self-defence, where refusing the
-- claim would leave a merc standing still while someone swings at him.
function mercenaries:TryClaimTarget(bt_data, myWuid, targetWuid, force)
    -- Beat 9's body double is the player's kill and nobody else's. A merc finishing him from
    -- behind ends the quest in a way that reads as a bug however correct the code is.
    if self.AlxDoubleName then
        local te
        pcall(function() te = XGenAIModule.GetEntityByWUID(targetWuid) end)
        if te and self:AlxDoubleName(te:GetName()) then return false end
    end
    -- The wall lab's walker is a measurement, not a foe: with the company standing next to
    -- the player he was killed on his spawn point twenty trials running and every one read
    -- as "never moved". Only while a lab is running, so play is never touched.
    if self.LabRun then
        local te
        pcall(function() te = XGenAIModule.GetEntityByWUID(targetWuid) end)
        local nm = ""
        if te then pcall(function() nm = te:GetName() or "" end) end
        if nm:find("^SpawnedTestNpc_") then return false end
    end
    local targetWuidStr = tostring(targetWuid)

    if not self:MercMayClaim(myWuid, targetWuidStr) then return false end

    -- An archer does not loose into a melee. A man locked with one of ours takes the arrow
    -- as often as the enemy does ("archers do a lot of teamkill when shooting at enemies
    -- engaged with friendly troops, including the player"), so a bowman refuses any target
    -- with a friend within arm's reach of it and waits for a clean one. Not in the melee
    -- stance, where he is a footman with a bow on his back; and never for self-defence.
    if self.ArcherHoldFire ~= false and not force and _G.ArcherStance ~= "melee"
       and self:MercIsArcherWuid(myWuid) then
        local tpos, meId
        pcall(function()
            local te = XGenAIModule.GetEntityByWUID(targetWuid)
            tpos = te and te:GetWorldPos()
            local me = XGenAIModule.GetEntityByWUID(myWuid)
            meId = me and me.id
        end)
        if tpos and self:FriendlyWithin(tpos, self.ArcherMeleeClear or 2.2, meId) then
            return false
        end
    end

    -- Holding ground means holding it. Checked here rather than in the acquisition
    -- passes because this is the single choke point every claim goes through, so no
    -- path can smuggle a man off his station - not even a force-claim.
    if self.HoldActive and self.HoldOutOfLeash and self:HoldOutOfLeash(myWuid, targetWuid) then
        return false
    end
    -- Marching under a forced ground order: he is not fighting anything until he is standing
    -- on his mark. Without this he re-acquires on the way and the order stalls a metre later.
    if self.MarchForce and self.MarchForce[tostring(myWuid)] then return false end

    local cap = self.EffectiveSwarmCap or self.SwarmCap
    if not force and (self.TargetLoad[targetWuidStr] or 0) >= cap then return false end

    bt_data.playerTarget = targetWuid
    bt_data.isFriendly = false
    bt_data.foundTarget = true
    self:MercSetClaim(tostring(myWuid), targetWuidStr)
    -- Every claim on somebody who is not a recognised outlaw, named in the log. The
    -- gates above should make this rare - a man genuinely swinging at a merc, or a
    -- target the player called himself - so a burst of these lines IS the bug report
    -- for "they attacked the watch again", with the name of who they went for.
    -- Once per merc per target, or a whole fight writes a line every poll.
    self.ClaimTraceSeen = self.ClaimTraceSeen or {}
    self.ClaimTraceN    = self.ClaimTraceN or 0
    -- Bounded: a long siege is thousands of distinct pairings, and an unbounded table
    -- here would ride into the save like the timer flood did.
    if self.ClaimTraceN >= 2048 then self.ClaimTraceSeen, self.ClaimTraceN = {}, 0 end
    local traceKey = tostring(myWuid) .. ">" .. targetWuidStr
    if not self.ClaimTraceSeen[traceKey] then
        self.ClaimTraceSeen[traceKey] = true
        self.ClaimTraceN = self.ClaimTraceN + 1
        pcall(function()
            local te = XGenAIModule.GetEntityByWUID(targetWuid)
            if not te then return end
            local kind = self:HostileKind(te)
            if kind ~= "hostile" then
                System.LogAlways("[MercTarget] claim on a non-outlaw: " ..
                    tostring(te:GetName()) .. " (" .. kind .. ")")
            end
        end)
    end
    return true
end

-- First pass, run per candidate from the BT (which supplies candidateTarget via
-- the engine's GetTarget node): claim anyone locked onto the player or onto this
-- merc. This is the lock-on trigger - it fires the moment an enemy picks its
-- victim, without waiting for a blow to land, and it does not care whether that
-- enemy has drawn a weapon yet.
function mercenaries:EvaluateCombatTarget(bt_data, myWuid)
    local ok, err = pcall(function()
        if bt_data.foundTarget then return end
        if not bt_data.candidateTarget then return end

        local aggroOn = tostring(bt_data.candidateTarget)
        if aggroOn ~= tostring(myWuid) and aggroOn ~= tostring(bt_data.playerWUID) then return end

        -- Hold fire means hold fire, even when it is us being swung at. Every other
        -- stance still lets a man defend himself. Say so occasionally, or a squad
        -- standing still while it is cut down just reads as broken.
        if not self:EngageAllowsRetaliation() then
            self:HoldFireWarn()
            return
        end

        -- The candidate list now includes men the CACHE refused (see ScanForEnemies), so
        -- this is the point that has to re-validate rather than assume. Both hostility
        -- gates are waived, because "he has taken one of ours as his target" is a
        -- stronger proof than either of them - the same reasoning as EngageCacheAccepts.
        local cand
        pcall(function() cand = XGenAIModule.GetEntityByWUID(bt_data.candidate) end)
        if not cand then return end
        if self:IsOwnSide(cand) then return end

        -- THE COMPANY DEFENDS THE PLAYER AND EACH OTHER. Whoever this man is - guard,
        -- villager, anyone - having taken the player or a merc as his target makes him a
        -- legitimate target, and the `protected` verdict does not stand in the way of
        -- that. It stands in the way of the squad STARTING something, which is a
        -- different question answered further down in PickCombatTarget.
        --
        -- What it is not is a licence to act on the raw signal: an outlaw is taken on
        -- sight, everyone else has to clear the collision filter first (weapon out, a
        -- real combat state, and still on the same man a couple of seconds later). See
        -- AggressorConfirmed -
        -- the engine registers collisions as hits all day long, and a bump must not
        -- read as an assault.
        if not self:AggressorConfirmed(cand, bt_data.candidate, aggroOn) then return end
        if not self:IsValidEnemy(cand, player, bt_data.playerWUID, true, true, true) then return end

        local selfDefence = (aggroOn == tostring(myWuid))

        -- THE authoritative record of who is fighting us, and the only one that works:
        -- this is the engine's own GetTarget node's answer, not a Lua guess. The enemy
        -- cache reads it back next pass to admit him and everyone standing with him.
        self:NoteAttacker(bt_data.candidate)
        if self.BanditCampAlertFor then
            self:BanditCampAlertFor(tostring(bt_data.candidate), "a bandit is fighting us")
        end

        -- Someone swinging at ME overrides the swarm cap: refusing that claim leaves
        -- a merc standing still while he is being hit. Defending the PLAYER keeps the
        -- cap - spreading out still makes sense there.
        self:TryClaimTarget(bt_data, myWuid, bt_data.candidate, selfDefence)
    end)

    if not ok then
        System.LogAlways('[Mercenary Jeff] EvaluateCombatTarget Error: ' .. tostring(err))
    end
end

-- Second pass: nobody is locked onto us yet. Take whoever the player is fighting,
-- else the nearest hostile.
--
-- Exactly ONE of the two hostility gates may be waived per path, never both:
--   * the player's target waives the relationship check (the player can pick a
--     fight with anyone), so it still demands a drawn weapon as proof this is a
--     real combatant. GetTarget on the player will hand back whoever he happens
--     to be looking at, so without that proof the squad charges villagers and
--     sits in a permanent combat state.
--   * the nearest-hostile sweep waives the drawn-weapon check, because the -1
--     relationship floor is already proof of hostility, and waiting for the
--     unsheathe animation meant the squad never moved until someone was hit.
function mercenaries:PickCombatTarget(bt_data, myWuid)
    local ok, err = pcall(function()
        if bt_data.foundTarget then return end

        -- A target the player has actually called outranks everything else, and is
        -- force-claimed: the whole point of the order is that they all go for that
        -- one man, so the anti-swarm cap must not quietly refuse half the squad.
        local focus = self.OrderFocusLive and self:OrderFocusLive()
        if focus then
            local fe
            pcall(function() fe = XGenAIModule.GetEntityByWUID(focus) end)
            -- allowProtected: the player pointed at this man and said "him". The
            -- townsman gate exists to stop the squad PICKING a fight nobody asked for,
            -- and an explicit called target is the one thing that is not that. It is
            -- still logged by TryClaimTarget's trace.
            if fe and fe.soul and self:IsValidEnemy(fe, player, bt_data.playerWUID, true, false, true) then
                if self:TryClaimTarget(bt_data, myWuid, focus, true) then return end
            end
        end

        -- Everything below this line is the squad picking its OWN fight, which is
        -- exactly what the defend and hold stances forbid.
        if not self:EngageAllowsInitiative() then return end

        if bt_data.playerCombatTarget then
            self:PlayerCombatTargetProbe()
            local targetWuidStr = tostring(bt_data.playerCombatTarget)
            if targetWuidStr ~= "" and targetWuidStr ~= tostring(bt_data.playerWUID) then
                local targetEnt = XGenAIModule.GetEntityByWUID(bt_data.playerCombatTarget)
                if targetEnt and targetEnt.soul
                   and self:IsWithinAggroRange(targetEnt)
                   and self:IsValidEnemy(targetEnt, player, bt_data.playerWUID, true, false) then
                    if self:TryClaimTarget(bt_data, myWuid, bt_data.playerCombatTarget) then
                        return
                    end
                end
            end
        end

        local me = XGenAIModule.GetEntityByWUID(myWuid)
        local myPos = me and me:GetPos()
        if not myPos then return end

        local cap  = self.EffectiveSwarmCap or self.SwarmCap
        local hard = self.SwarmCapHard or 10
        if hard < cap then hard = cap end
        local best, bestDist = nil, nil
        -- ...and the nearest one that is merely under the HARD stop, for the fallback below.
        local any, anyDist = nil, nil
        -- Candidates this man is not allowed to claim are skipped HERE rather than being
        -- picked and then refused by TryClaimTarget: `best` is the single nearest enemy, so
        -- one perched archer standing closer than the foot around him used to blank the whole
        -- pass and leave a melee merc with no target at all.
        local iAmArcher = self:MercIsArcherWuid(myWuid)
        for _, entry in ipairs(self.CachedEnemies or {}) do
            local ep = entry.pos or (entry.entity and entry.entity:GetPos())
            local ws = tostring(entry.wuid)
            if ep and self:MercMayClaim(myWuid, ws, iAmArcher) then
                local dx, dy, dz = ep.x - myPos.x, ep.y - myPos.y, ep.z - myPos.z
                local d = dx*dx + dy*dy + dz*dz
                local load = self.TargetLoad[ws] or 0
                if load < hard and (not anyDist or d < anyDist) then any, anyDist = entry.wuid, d end
                if load < cap  and (not bestDist or d < bestDist) then best, bestDist = entry.wuid, d end
            end
        end

        if best and self:TryClaimTarget(bt_data, myWuid, best) then return end

        -- AT-CAP FALLBACK. Every candidate is full, so the anti-swarm rule has nothing
        -- left to offer this man, and the cap is a preference rather than a law. Without
        -- this he keeps no target at all and stands through the whole battle with his
        -- weapon away, a few metres from a fight - which is far worse than one more man
        -- on an already-busy enemy.
        --
        -- BOUNDED TWO WAYS, and both bounds are the design rather than caution.
        --
        --   * SwarmCapHard still stands. It is the "fifty men must not all mob three
        --     bandits" stop, and against a handful of enemies EffectiveSwarmCap has
        --     already risen to meet it - so there is no headroom, nothing spills over,
        --     and the surplus keeps formation exactly as before. In a real battle the
        --     cap is down at two to four while the hard stop is ten, and that gap is
        --     precisely the relief this needs.
        --   * SwarmOverflowRange. A benched merc standing inside the melee doing nothing
        --     is the bug; a man forty metres back in the column is the design. Distance
        --     tells the two apart on its own.
        --
        -- Force bypasses the soft cap only: the hold leash and the perched-archer rule
        -- inside TryClaimTarget still apply, so this cannot pull a man off his station.
        if any and anyDist <= (self.SwarmOverflowRange * self.SwarmOverflowRange) then
            self:TryClaimTarget(bt_data, myWuid, any, true)
        end
    end)

    if not ok then
        System.LogAlways('[Mercenary Jeff] PickCombatTarget Error: ' .. tostring(err))
    end
end

-- ==== squad threat ====
-- True while a live hostile is close enough to the player to be worth dismounting for.
-- Set once per CombatScanLoop pass from the cache it just refreshed, and read by the
-- mounted arm of follow.xml, which otherwise sits in a 10s StanceElement block and only
-- notices the fight when that block expires - the "mounted mercs take ages to engage" lag.
mercenaries.SquadThreatRange = 35.0

function mercenaries:UpdateSquadThreat()
    local near = false
    pcall(function()
        if not player then return end
        local pp = player:GetWorldPos()
        if not pp then return end
        local r2 = self.SquadThreatRange * self.SquadThreatRange
        -- CachedEnemies holds { entity=, wuid=, armed= } wrappers, not entities.
        for _, e in pairs(self.CachedEnemies or {}) do
            local ent = e and e.entity
            if ent and self:IsCombatViable(ent) then
                local q = ent:GetWorldPos()
                if q then
                    local dx, dy = q.x - pp.x, q.y - pp.y
                    if (dx * dx + dy * dy) <= r2 then near = true; break end
                end
            end
        end
    end)
    _G.MercSquadThreat = near
end

-- BT hook for the mounted arm: should this rider break off and get down?
function mercenaries:MercShouldDismount(bt_data)
    bt_data.squadThreat = (_G.MercSquadThreat == true)
end

-- ==== dismounting for a fight ====
-- Deliberately NOT MercSquadThreat. That flag is true whenever anything hostile is
-- within 35m, which on an open road with roaming patrols about is most of the time,
-- and hanging the horse lifecycle off it directly would churn mounts continuously.
-- An earlier attempt to fail the mounted branch on it broke mounted following
-- outright, because that Parallel is failureMode="Any" and the arm fired almost
-- constantly (docs/formations.md).
--
-- So this one is armed enemies only, closer in, and latched on BOTH edges: it has to
-- hold for a couple of seconds before they get down, and stay clear for a good while
-- before they get back up. The horse itself is then removed by the existing lifecycle
-- countdown, which is the same path a real player dismount already takes - no new
-- branch, no new failure mode.
mercenaries.AutoDismount          = true
mercenaries.AutoDismountRange     = 22.0
mercenaries.AutoDismountHoldSecs  = 2.0
mercenaries.AutoDismountClearSecs = 10.0

function mercenaries:UpdateDismountThreat()
    if not self.AutoDismount then
        _G.MercDismountThreat = false
        self._dtNearSince, self._dtClearSince = nil, nil
        return
    end

    local near = false
    pcall(function()
        if not player then return end
        local pp = player:GetWorldPos()
        if not pp then return end
        local r2 = self.AutoDismountRange * self.AutoDismountRange
        for _, e in pairs(self.CachedEnemies or {}) do
            local ent = e and e.entity
            -- Armed only: a sheathed hostile is not a reason to put fifty men on foot.
            if ent and e.armed and self:IsCombatViable(ent) then
                local q = ent:GetWorldPos()
                if q then
                    local dx, dy = q.x - pp.x, q.y - pp.y
                    if (dx * dx + dy * dy) <= r2 then near = true; break end
                end
            end
        end
    end)

    local now = 0
    pcall(function() now = System.GetCurrTime() or 0 end)

    if near then
        self._dtNearSince  = self._dtNearSince or now
        self._dtClearSince = nil
    else
        self._dtClearSince = self._dtClearSince or now
        self._dtNearSince  = nil
    end

    if _G.MercDismountThreat then
        if self._dtClearSince and (now - self._dtClearSince) >= self.AutoDismountClearSecs then
            _G.MercDismountThreat = false
        end
    elseif self._dtNearSince and (now - self._dtNearSince) >= self.AutoDismountHoldSecs then
        _G.MercDismountThreat = true
    end
end

-- ==== is the SQUAD operating mounted ====
-- The two halves of follow.xml's mount poll. In Lua rather than inline in the XML
-- `code` attributes because the answer now has a policy in it (HorsesAllowed) and a
-- Lua comment inside an XML attribute silently truncates the rest of the script.
--
-- Mounting is instant, dismounting is debounced: a single missed StanceCheck would
-- otherwise flip this global false for the WHOLE squad, dismounting everyone and starting
-- every horse's despawn countdown. Poll and debounce are a pair - see docs/formations.md.
mercenaries.MountDebounceSecs = 1.2

function mercenaries:MercPlayerMountSeen()
    pcall(function() _G.PlayerMountedSeenAt = System.GetCurrTime() end)
    -- Horses off: the player may ride, the company never does. Held false HERE so every
    -- reader of the global agrees - the formation picks a foot preset and the fall-behind
    -- teleport stays armed, which is what lets men on foot keep up with a rider at all.
    if not self:HorsesAllowed() then
        if _G.PlayerMounted then _G.PlayerMounted = false end
        return
    end
    -- Past HorsesMaxCompany men OUT with the player, the company marches on foot whatever
    -- he rides: fifty riders is a hundred AI entities, and the engine's answer is riders
    -- dropping out of the Detail budget - horses standing riderless past a certain
    -- distance, men popping in and out (2026-09-03, 50 men). The fall-behind teleport keeps
    -- men on foot with a rider, exactly as with merc_horses 0.
    local cap = self.HorsesMaxCompany or 0
    if cap > 0 and self:MercsOutCount() > cap then
        if not self._horsesCapNoted then
            self._horsesCapNoted = true
            System.LogAlways(string.format("[Mercenaries] %d men out is past the %d-rider limit (merc_horses_max) - the company stays on foot",
                                           self:MercsOutCount(), cap))
        end
        if _G.PlayerMounted then _G.PlayerMounted = false end
        return
    end
    self._horsesCapNoted = false
    if not _G.PlayerMounted then _G.PlayerMounted = true end
end

-- How many of the company are out with the player (all of them without a camp; the sortie
-- with one). Polled per merc from the follow tree, so the answer is cached for a second.
function mercenaries:MercsOutCount()
    local now = 0
    pcall(function() now = System.GetCurrTime() or 0 end)
    if self._outCountAt and (now - self._outCountAt) < 1.0 and self._outCount then return self._outCount end
    local n = 0
    pcall(function()
        for _, ent in pairs(self.ActiveMercs or {}) do
            local w = ent and (ent.this and ent.this.id or ent.id)
            if w and (not self.CampActive or self:IsMercInSortie(w)) then n = n + 1 end
        end
    end)
    self._outCount, self._outCountAt = n, now
    return n
end

function mercenaries:MercPlayerMountLost()
    if not _G.PlayerMounted then return end
    local t = _G.PlayerMountedSeenAt
    local now
    pcall(function() now = System.GetCurrTime() end)
    if not (t and now) or (now - t) > self.MountDebounceSecs then _G.PlayerMounted = false end
end

-- Called from follow.xml's horse-lifecycle poll in place of the old inline
-- expression, so the "get down and fight" rule sits with the rest of the combat
-- state instead of being buried in an XML attribute.
function mercenaries:MercMountState(bt_data, myWuid)
    local want = false
    pcall(function() want = (_G.PlayerMounted and self:IsMercInSortie(myWuid)) or false end)
    if want and _G.MercDismountThreat then want = false end
    bt_data.playerIsMounted = want
end

-- INSTANT MOUNT. Called from follow.xml's horse lifecycle the tick the horse exists. The
-- tree's own path - StanceElement walks the man to a horse spawned a few metres off and
-- plays the mount transition - is what took a fifty-man company ten to twenty seconds to
-- get into the saddle (2026-09-03), each man queueing his own walk and animation. The Human
-- bind has `ForceMount(EntityId horseId)` ("Mounts selected horse", C_ScriptBindHuman), so he
-- is put on it here and the tree's StanceCheck finds him already riding and goes straight to
-- the ride loop. If neither bind takes, nothing is lost: the walk-to-mount path still runs.
-- Which bind answered is logged once.
function mercenaries:MercInstantMount(ent, horseEnt)
    if not (ent and horseEnt and horseEnt.id) then return false end
    -- The mount is the body that would ride the player down, and this is the first tick it
    -- exists - the 3-tick horse sweep is the backstop. docs/collision-ghosting.md.
    if self:GhostCollisionOn() then self:ApplyCollisionGhost(horseEnt, self.GhostHorseMask) end
    local already = false
    pcall(function() already = ent.human and ent.human.IsMounted and ent.human:IsMounted() or false end)
    if already then return true end
    local how = nil
    if ent.human then
        if ent.human.ForceMount then
            local ok = pcall(function() ent.human:ForceMount(horseEnt.id) end)
            if ok then how = "ForceMount" end
        end
        if not how and ent.human.Mount then
            local ok = pcall(function() ent.human:Mount(horseEnt.id) end)
            if ok then how = "Mount" end
        end
    end
    if how and not self._instantMountNoted then
        self._instantMountNoted = true
        System.LogAlways("[MercHorse] instant mount through human:" .. how .. " - the walk-to-mount path is the fallback only")
    elseif not how and not self._instantMountFailNoted then
        self._instantMountFailNoted = true
        System.LogAlways("[MercHorse] no instant-mount bind answered on this build - men walk to their horses as before")
    end
    return how ~= nil
end

function mercenaries:AutoDismountSet(v)
    self.AutoDismount = (tostring(v or ''):match('1') ~= nil)
    System.LogAlways('[Mercenary Jeff] dismount-to-fight ' .. (self.AutoDismount and 'ON' or 'OFF'))
end

function mercenaries:ChaseFleeingSet(v)
    self.ChaseFleeingEnemies = v and true or false
    System.LogAlways('[Mercenary Jeff] chase routed enemies ' .. (self.ChaseFleeingEnemies and 'ON' or 'OFF'))
end

-- ---------------------------------------------------------------------------
-- LOAD RESET.
--
-- Everything below is plain Lua and therefore OUTLIVES the level it belongs to, while the
-- behaviour trees that maintain it do not. That asymmetry is how a session acquires a
-- permanently widened enemy sweep:
--
--   * a merc holding a combat claim at the moment the game is saved keeps his MercTargetOf
--     entry across the load, but the combat_melee tree whose OnFail would release it is
--     gone. UpdateEnemyCache reads `next(MercTargetOf) ~= nil` as "somebody is fighting us"
--     and refreshes _alertAt on every pass, so EnemyAlerted never times out;
--   * EnemyAlerted then holds the shared scan at EnemyAlertRadius (60m, or the siege's
--     160m) instead of EnemyScanRadius (18m) for the rest of the session, everywhere,
--     including a city with several hundred NPCs inside that circle. Three sweeps a second,
--     each candidate through IsWeaponDrawn and IsValidEnemy.
--
-- Nothing is lost by clearing it: every table here is rebuilt from the world within one
-- CombatScan pass, and a fight that is genuinely still on re-raises the alert immediately.
-- See docs/performance.md.
function mercenaries:TargetingOnLoad()
    self.CachedEnemies  = {}
    self.MaybeEnemies   = {}
    self.MercTargetOf   = {}
    self.TargetLoad     = {}
    self.MercClaimAt    = {}
    self.EnemyTargetOf  = {}
    self.EnemyClaimWuid = {}
    -- ForcedTargetOf is deliberately NOT cleared. It is not bookkeeping - it is a siege or
    -- an encounter saying who a specific man is to fight, it plays no part in the alert
    -- latch, and PruneCombatClaims already drops the entries whose enemy is gone. Wiping it
    -- would leave the besiegers of a siege reloaded mid-battle standing with no orders.
    self.EnemyAlerted   = false
    self._alertAt       = nil
    self.EnemyAlertRadius = self.EnemyAlertRadiusDefault or 60
    -- Keyed by WUID, and a load is the one moment WUIDs can be handed to different men.
    self:HostileKindClear()
    self:AggressorClear()
    self.ClaimTraceSeen, self.ClaimTraceN = {}, 0
    _G.MercSquadThreat    = false
    _G.MercDismountThreat = false
end

-- ==== who may be fought, and why ====
--
-- Read-only. Every NPC within the current scan radius with the three answers that decide
-- whether the company may raise a hand to him: the outlaw/townsman verdict, his
-- relationship to the player, and whether he is in the cache right now. Run it standing
-- where the men went for somebody they should not have.
function mercenaries:TargetDumpNearby(radius)
    local r = tonumber(radius) or (self.EnemyAlerted and self.EnemyAlertRadius or self.EnemyScanRadius) or 18
    local pp = player and player:GetPos()
    if not pp then return end

    local cached = {}
    for _, e in ipairs(self.CachedEnemies or {}) do cached[tostring(e.wuid)] = true end
    local maybe = {}
    for _, e in ipairs(self.MaybeEnemies or {}) do maybe[tostring(e.wuid)] = true end

    local playerWuid = player.this and player.this.id or player.id
    System.LogAlways(string.format(
        "[MercTarget] within %.0fm - stance %s, alert %s", r,
        tostring(_G.MercEngage or "default"), tostring(self.EnemyAlerted)))

    local n = 0
    for _, cls in ipairs({ "NPC", "NPC_Female", "NPC_NAI" }) do
        local ents
        pcall(function() ents = System.GetEntitiesInSphereByClass(pp, r, cls) end)
        for _, ent in pairs(ents or {}) do
            if ent and type(ent) == "table" and ent.soul then
                local w = tostring(ent.this and ent.this.id or ent.id)
                local rel, armed, name
                pcall(function() rel = ent.soul:GetRelationship(playerWuid, "Current") end)
                pcall(function() armed = ent.human and ent.human:IsWeaponDrawn() or false end)
                pcall(function() name = ent:GetName() end)
                n = n + 1
                System.LogAlways(string.format(
                    "  %-36s %-9s rel=%-6s %s%s%s%s",
                    tostring(name), self:HostileKind(ent),
                    rel and string.format("%.2f", rel) or "?",
                    armed and "armed " or "",
                    cached[w] and "CACHED " or "",
                    maybe[w] and "maybe " or "",
                    self.MercTargetOf and (function()
                        for _, tw in pairs(self.MercTargetOf) do
                            if tw == w then return "CLAIMED" end
                        end
                        return ""
                    end)() or ""))
            end
        end
    end
    System.LogAlways("[MercTarget] " .. tostring(n) .. " NPC(s)")
end
