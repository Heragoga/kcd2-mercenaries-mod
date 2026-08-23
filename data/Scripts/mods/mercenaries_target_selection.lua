-- Validate whether an entity is a valid enemy target. skipRelationshipCheck
-- bypasses only the relationship gate, for whoever the player is already
-- fighting; skipWeaponCheck bypasses only the weapon-drawn gate, for candidates
-- that are about to be judged on who they are targeting instead.
-- See docs/combat-target-selection.md for the full ruleset.
function mercenaries:IsValidEnemy(ent, distanceRefEnt, playerWuid, skipRelationshipCheck, skipWeaponCheck)
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
    if string.find(ent:GetName() or '', 'MercenaryCustomCompanion') then
        return false
    end

    -- Must be genuinely hostile: relationship to the player pinned at exactly -1
    -- (the faction-hostile floor). Neutral/unresolved (0, 0.5, nil) is not fair
    -- game. skipRelationshipCheck bypasses only this gate. See the doc.
    if not skipRelationshipCheck then
        local rel_curr = ent.soul:GetRelationship(playerWuid, "Current")
        if rel_curr == nil or rel_curr > -1.0 then
            return false
        end
    end
    -- Skip fleeing/surrendering/immortal candidates.
    -- "crime_fleeAfterSurrender" used to be queried here and does not exist in
    -- ScriptContext.xml, so every candidate check logged
    -- "[Error] Script context does not exist" - hundreds of lines a fight. Only
    -- visible on the dev build. crime_indifferentFlee is the real neighbouring one.
    if ent.soul:HasScriptContext("combat_flee")
    or ent.soul:HasScriptContext("combat_surrender")
    or ent.soul:HasScriptContext("crime_interruptFlee")
    or ent.soul:HasScriptContext("crime_indifferentFlee")
    or ent.soul:HasScriptContext("combat_immortalityProtection")then
        return false
    end

    return true
end

-- Called every 300ms from CombatScanLoop: one sphere query + all soul-API
-- validation for the whole squad, cached in mercenaries.CachedEnemies.
-- Candidates that have not drawn a weapon yet are cached too and are fair game
-- for targeting; the armed flag only tells the logistics tick whether a fight is
-- actually under way. See the doc.
function mercenaries:UpdateEnemyCache()
    local ok, err = pcall(function()
        self.CachedEnemies = {}

        -- Anti-swarm load, rebuilt from MercTargetOf so each merc's swarm check
        -- is an O(1) lookup instead of a position scan.
        local load = {}
        for _, targetWuidStr in pairs(self.MercTargetOf) do
            load[targetWuidStr] = (load[targetWuidStr] or 0) + 1
        end
        self.TargetLoad = load

        if not player then return end
        local playerPos = player:GetPos()
        if not playerPos then return end

        local playerWuid = player.this and player.this.id or player.id

        -- Alerted: look as far as EnemyAlertRadius. The alert is raised below the moment an
        -- ARMED hostile is in the cache (a fight, not a passer-by) and held for a few seconds
        -- after the last one, so a squad standing in a market is not sweeping 60m of NPCs.
        local radius = self.EnemyAlerted and self.EnemyAlertRadius or self.EnemyScanRadius

        -- Shared player-centered scan covers this exact (pos, radius) - see
        -- mercenaries_perf.lua and docs/performance.md #4. A nil return means
        -- not covered/stale, never "nobody there", so the fallback is the
        -- original box query, unchanged.
        local shared = self:PerfNpcsNear(playerPos, radius, 400)
        if shared then
            for _, e in ipairs(shared) do
                local ent = e.entity
                if ent and type(ent) == "table" and ent.soul then
                    -- The engagement stance can widen this: see EngageCacheAccepts.
                    if self:EngageCacheAccepts(ent, playerWuid) then
                        local armed = (ent.human == nil) or ent.human:IsWeaponDrawn()
                        local p = e.pos
                        local pos = p and { x = p.x, y = p.y, z = p.z } or nil
                        table.insert(self.CachedEnemies, { entity = ent, wuid = e.wuid, armed = armed, pos = pos })
                    end
                end
            end
        else
            local ents = System.GetPhysicalEntitiesInBoxByClass(playerPos, radius, "NPC")
            if ents then
                for _, ent in pairs(ents) do
                    if ent and type(ent) == "table" and ent.soul then
                        if self:EngageCacheAccepts(ent, playerWuid) then
                            local entWuid = ent.this and ent.this.id or ent.id
                            local armed = (ent.human == nil) or ent.human:IsWeaponDrawn()
                            local p0 = ent:GetPos()
                            local pos = p0 and { x = p0.x, y = p0.y, z = p0.z } or nil
                            table.insert(self.CachedEnemies, { entity = ent, wuid = entWuid, armed = armed, pos = pos })
                        end
                    end
                end
            end
        end

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
        if not armedNear then
            pcall(function()
                if player and player.soul and player.soul:HasScriptContext("crime_interruptAttack") then
                    armedNear = true
                end
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
function mercenaries:ScanForEnemies(bt_data, myWuid)
    local ok, err = pcall(function()
        bt_data.enemiesArray = {}

        local me = XGenAIModule.GetEntityByWUID(myWuid)
        if not me then return end

        local myPos = me:GetPos()
        if not myPos then return end

        -- Cap candidates: each one the BT checks costs an engine GetTarget call.
        local maxCandidates = 8
        local nearWuid, nearDist, count = {}, {}, 0

        for _, entry in ipairs(self.CachedEnemies or {}) do
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
    local targetWuidStr = tostring(targetWuid)

    -- A static archer - on a watchtower OR on an archer cart - is not a melee merc's business.
    -- He walks to the foot of the thing and stands there while the distance leash flaps him
    -- between drawn and sheathed. Only an archer merc may claim him. This covers BOTH now:
    -- gating on `elevated` alone still left melee mercs piling onto cart archers.
    -- Nothing needs undoing when a tower archer comes down - BanditCampBringArchersDown calls
    -- RemoveStaticArcher and replaces him with a new ground entity that was never in the table.
    --
    -- Keyed by entity.this.id, which is what CachedEnemies stores and what SpawnStaticArcher
    -- records under - the two keyspaces have to agree or this silently never matches.
    local rec = self.StaticArchers and self.StaticArchers[targetWuidStr]
    if rec then
        local myName
        pcall(function()
            local me = XGenAIModule.GetEntityByWUID(myWuid)
            myName = me and me:GetName()
        end)
        -- Only ever a merc asks here (static archers pick targets in their own scheduler), so
        -- '_archer_' in the name means an archer MERC and not the enemy on the platform.
        if not (myName and self:IsArcherName(myName)) then return false end
    end

    -- Holding ground means holding it. Checked here rather than in the acquisition
    -- passes because this is the single choke point every claim goes through, so no
    -- path can smuggle a man off his station - not even a force-claim.
    if self.HoldActive and self.HoldOutOfLeash and self:HoldOutOfLeash(myWuid, targetWuid) then
        return false
    end

    local cap = self.EffectiveSwarmCap or self.SwarmCap
    if not force and (self.TargetLoad[targetWuidStr] or 0) >= cap then return false end

    bt_data.playerTarget = targetWuid
    bt_data.isFriendly = false
    bt_data.foundTarget = true
    self.MercTargetOf[tostring(myWuid)] = targetWuidStr
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

        -- Someone swinging at ME overrides the swarm cap: refusing that claim leaves
        -- a merc standing still while he is being hit. Defending the PLAYER keeps the
        -- cap - spreading out still makes sense there.
        local selfDefence = (aggroOn == tostring(myWuid))
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
            if fe and fe.soul and self:IsValidEnemy(fe, player, bt_data.playerWUID, true, false) then
                if self:TryClaimTarget(bt_data, myWuid, focus, true) then return end
            end
        end

        -- Everything below this line is the squad picking its OWN fight, which is
        -- exactly what the defend and hold stances forbid.
        if not self:EngageAllowsInitiative() then return end

        if bt_data.playerCombatTarget then
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

        local best, bestDist = nil, nil
        for _, entry in ipairs(self.CachedEnemies or {}) do
            local ep = entry.pos or (entry.entity and entry.entity:GetPos())
            if ep and (self.TargetLoad[tostring(entry.wuid)] or 0) < (self.EffectiveSwarmCap or self.SwarmCap) then
                local dx, dy, dz = ep.x - myPos.x, ep.y - myPos.y, ep.z - myPos.z
                local d = dx*dx + dy*dy + dz*dz
                if not bestDist or d < bestDist then
                    best, bestDist = entry.wuid, d
                end
            end
        end

        if best then self:TryClaimTarget(bt_data, myWuid, best) end
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

-- Called from follow.xml's horse-lifecycle poll in place of the old inline
-- expression, so the "get down and fight" rule sits with the rest of the combat
-- state instead of being buried in an XML attribute.
function mercenaries:MercMountState(bt_data, myWuid)
    local want = false
    pcall(function() want = (_G.PlayerMounted and self:IsMercInSortie(myWuid)) or false end)
    if want and _G.MercDismountThreat then want = false end
    bt_data.playerIsMounted = want
end

function mercenaries:AutoDismountSet(v)
    self.AutoDismount = (tostring(v or ''):match('1') ~= nil)
    System.LogAlways('[Mercenary Jeff] dismount-to-fight ' .. (self.AutoDismount and 'ON' or 'OFF'))
end

System.AddCCommand("merc_autodismount", "mercenaries:AutoDismountSet('%line')",
    "Mercs get off their horses to fight: merc_autodismount 0 | 1")
