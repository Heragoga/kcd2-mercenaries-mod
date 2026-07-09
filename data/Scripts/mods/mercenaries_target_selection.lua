-- =======================================================================
-- HELPER: Shared logic to validate if an entity is a valid enemy target
-- =======================================================================
function mercenaries:IsValidEnemy(ent, distanceRefEnt, playerWuid)
    -- 1. Check if it's the player or the player's dog
    if ent.id == player.id then return false end
    if ent:GetName() == "companion_dog" then return false end
    
    -- 2. Validate using the shared helper (false = do NOT allow unconscious targets)
    if not self:IsAliveAndWell(ent, true) then return false end
    if ent.human and not ent.human:IsWeaponDrawn() then return false end
    -- 3. Distance Check (Relative to whichever entity is passed as distanceRefEnt)
    if distanceRefEnt then
        local tp = ent:GetPos()
        local refPos = distanceRefEnt:GetPos()
        if tp and refPos then
            local dx, dy, dz = tp.x - refPos.x, tp.y - refPos.y, tp.z - refPos.z
            if math.sqrt(dx*dx + dy*dy + dz*dz) > self.TargetDetectionRadius then return false end
        end
    end
    
    local eid = tostring(ent.soul:GetId())
    
    -- 4. Check if the candidate is a regular mercenary
    if self.Souls then
        for _, tierList in pairs(self.Souls) do
            for _, guid in ipairs(tierList) do
                if string.find(eid, guid) then
                    return false
                end
            end
        end
    end

    -- Check if the candidate is one of our archers
    if self.ArcherSouls then
        for _, tierList in pairs(self.ArcherSouls) do
            for _, guid in ipairs(tierList) do
                if string.find(eid, guid) then
                    return false
                end
            end
        end
    end
    
    -- Check if it's a custom hero companion
    if string.find(ent:GetName() or '', 'MercenaryCustomCompanion') then
        return false
    end


    
    -- 5. Failsafe: Ensure they aren't explicitly friendly to the player
    local rel_curr = ent.soul:GetRelationship(playerWuid, "Current")
    if rel_curr and rel_curr >= 1 then 
        return false 
    end
    --local isInArrangedFight = self.soul:HasScriptContext("combat_arrangedFight") and not self.soul:HasScriptContext("combat_suppressedDialogInArrangedFight")
    -- combat_flee
    -- combat_neverSurrenderOrFlee
    --combat_immortalityProtection
    --combat_fightInQuestSkirmish
    --crime_interruptFlee
    --combat_surrender
    -- avoid targeting fleeing or surrendering enemies, enemies that are in tournaments or scripted duels, enemies that are immortal
    if ent.soul:HasScriptContext("combat_flee")
    or ent.soul:HasScriptContext("combat_surrender")
    or ent.soul:HasScriptContext("crime_interruptFlee")
    or ent.soul:HasScriptContext("crime_fleeAfterSurrender")
--[[     or ent.soul:HasScriptContext("combat_arrangedFight") ]]
    
    or ent.soul:HasScriptContext("combat_immortalityProtection")then 
        return false
    end
    
    -- All checks passed!
    return true
end

-- =======================================================================
-- CORE: Called ONCE per second from MonitorLoop.
-- Does the sphere query and all soul API validation exactly once,
-- regardless of how many mercs are active. Result stored in
-- mercenaries.CachedEnemies for all mercs to read from.
-- =======================================================================
function mercenaries:UpdateEnemyCache()
    local ok, err = pcall(function()
        self.CachedEnemies = {}

        -- Anti-swarm load: rebuilt from MercTargetOf once per second.
        -- O(mercs), so every merc's per-tick swarm check is a plain lookup
        -- instead of an O(mercs) position scan.
        local load = {}
        for _, targetWuidStr in pairs(self.MercTargetOf) do
            load[targetWuidStr] = (load[targetWuidStr] or 0) + 1
        end
        self.TargetLoad = load

        if not player then return end
        local playerPos = player:GetPos()
        if not playerPos then return end

        local playerWuid = player.this and player.this.id or player.id

        -- NPC query runs every tick (once/sec)
        local ents = System.GetPhysicalEntitiesInBoxByClass(playerPos, 15.0, "NPC")
        if ents then
            for _, ent in pairs(ents) do
                if ent and type(ent) == "table" and ent.soul then
                    if self:IsValidEnemy(ent, player, playerWuid) then
                        local entWuid = ent.this and ent.this.id or ent.id
                        table.insert(self.CachedEnemies, { entity = ent, wuid = entWuid })
                    end
                end
            end
        end

        -- Animal queries run every 3 seconds — animals don't need per-second precision
        self._animalQueryTick = (self._animalQueryTick or 0) + 1
        if self._animalQueryTick >= 3 then
            self._animalQueryTick = 0

            -- Wolf/Dog enemy detection
            for _, className in ipairs({ "Wolf", "Dog" }) do
                local aEnts = System.GetPhysicalEntitiesInBoxByClass(playerPos, 15.0, className)
                if aEnts then
                    for _, ent in pairs(aEnts) do
                        if ent and type(ent) == "table" and ent.soul then
                            if self:IsValidEnemy(ent, player, playerWuid) then
                                local entWuid = ent.this and ent.this.id or ent.id
                                table.insert(self.CachedEnemies, { entity = ent, wuid = entWuid })
                            end
                        end
                    end
                end
            end

            -- Orphan horse cleanup
            -- Scans for Horse entities near the player following the MercenaryHorse_ convention.
            -- Despawns if: owning merc is dead/missing, or owning merc is not mounted.
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
                                -- Merc not in cache — dead or already cleaned up
                                shouldDespawn = true
                                reason = "merc not in ActiveMercs"
                            else
                                -- Check if merc is alive
                                if not self:IsAliveAndWell(mercEnt, true) then
                                    shouldDespawn = true
                                    reason = "merc dead or unconscious"
                                end
                            end

                            if shouldDespawn then
                                System.LogAlways('[MercHorse] Despawning orphan horse: ' .. horseName .. ' (' .. reason .. ')')
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

-- =======================================================================
-- CORE: Called per-merc from the behavior tree each second.
-- Reads from the pre-validated CachedEnemies list and re-sorts by
-- distance from THIS specific merc (cheap math only, no soul API calls).
-- =======================================================================
function mercenaries:ScanForEnemies(bt_data, myWuid)
    local ok, err = pcall(function()
        bt_data.enemiesArray = {}

        local me = XGenAIModule.GetEntityByWUID(myWuid)
        if not me then return end

        local myPos = me:GetPos()
        if not myPos then return end

        local potentialTargets = {}

        for _, entry in ipairs(self.CachedEnemies or {}) do
            local ent = entry.entity
            if ent then
                local ep = ent:GetPos()
                if ep then
                    local dx = ep.x - myPos.x
                    local dy = ep.y - myPos.y
                    local dz = ep.z - myPos.z
                    local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
                    table.insert(potentialTargets, { wuid = entry.wuid, distance = dist })
                end
            end
        end

        -- Sort by distance from this specific merc (closest first)
        table.sort(potentialTargets, function(a, b)
            return a.distance < b.distance
        end)

        -- Cap how many candidates get checked (each costs one engine
        -- GetTarget call in the behavior tree) — the nearest few are what
        -- matter, and this bounds the per-merc cost regardless of how many
        -- enemies are on the field.
        local maxCandidates = 8
        for i, v in ipairs(potentialTargets) do
            if i > maxCandidates then break end
            table.insert(bt_data.enemiesArray, v.wuid)
        end
    end)

    if not ok then
        System.LogAlways('[Mercenary Jeff] ScanForEnemies Error: ' .. tostring(err))
    end
end

-- =======================================================================
-- HELPER: True if the entity behind wuid is hurting badly enough that it
-- should look after itself instead of picking a fresh fight.
-- =======================================================================
function mercenaries:IsHealthCritical(wuid, threshold)
    local ok, result = pcall(function()
        local ent = wuid and XGenAIModule.GetEntityByWUID(wuid)
        if not ent or not ent.soul then return false end
        local hp = ent.soul:GetState('health')
        return hp ~= nil and hp <= (threshold or 25)
    end)
    return ok and result or false
end

-- =======================================================================
-- HELPER: Claims a target for a merc, respecting the anti-swarm cap.
-- Returns true if the claim succeeded (and records it in MercTargetOf so
-- next second's TargetLoad rebuild sees it).
-- =======================================================================
function mercenaries:TryClaimTarget(bt_data, myWuid, targetWuid)
    local targetWuidStr = tostring(targetWuid)
    if (self.TargetLoad[targetWuidStr] or 0) >= self.SwarmCap then return false end

    bt_data.playerTarget = targetWuid
    bt_data.isFriendly = false
    bt_data.foundTarget = true
    self.MercTargetOf[tostring(myWuid)] = targetWuidStr
    return true
end

-- =======================================================================
-- STANCE "everyone": grab the nearest valid hostile, no engine calls
-- needed beyond position reads already available on cached entities.
-- =======================================================================
function mercenaries:PickNearestValidTarget(bt_data, myWuid)
    local ok, err = pcall(function()
        if bt_data.foundTarget then return end
        if myWuid and self:IsHealthCritical(myWuid, 25) then return end

        local me = XGenAIModule.GetEntityByWUID(myWuid)
        local myPos = me and me:GetPos()
        if not myPos then return end

        local best, bestDist = nil, nil
        for _, entry in ipairs(self.CachedEnemies or {}) do
            local ep = entry.entity and entry.entity:GetPos()
            if ep and (self.TargetLoad[tostring(entry.wuid)] or 0) < self.SwarmCap then
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
        System.LogAlways('[Mercenary Jeff] PickNearestValidTarget Error: ' .. tostring(err))
    end
end

-- =======================================================================
-- STANCE "player_target": only join whatever the player is currently
-- fighting. bt_data.playerCombatTarget is filled by a single GetTarget
-- node on the player (once per merc, not once per candidate).
-- =======================================================================
function mercenaries:PickPlayersTarget(bt_data, myWuid)
    local ok, err = pcall(function()
        if bt_data.foundTarget then return end
        if myWuid and self:IsHealthCritical(myWuid, 25) then return end
        if not bt_data.playerCombatTarget then return end

        local targetWuidStr = tostring(bt_data.playerCombatTarget)
        if targetWuidStr == "" or targetWuidStr == tostring(bt_data.playerWUID) then return end

        local targetEnt = XGenAIModule.GetEntityByWUID(bt_data.playerCombatTarget)
        if not targetEnt or not targetEnt.soul then return end
        if not self:IsValidEnemy(targetEnt, player, bt_data.playerWUID) then return end

        self:TryClaimTarget(bt_data, myWuid, bt_data.playerCombatTarget)
    end)

    if not ok then
        System.LogAlways('[Mercenary Jeff] PickPlayersTarget Error: ' .. tostring(err))
    end
end

-- =======================================================================
-- STANCE "defend": only fight back if a candidate is personally targeting
-- ME. This is the only stance that needs to walk enemiesArray and ask the
-- engine who each candidate is targeting (capped to 8 nearest already).
-- =======================================================================
function mercenaries:EvaluateCombatTarget(bt_data, myWuid)
    local ok, err = pcall(function()
        if bt_data.foundTarget then return end
        if myWuid and self:IsHealthCritical(myWuid, 25) then return end
        if not bt_data.candidateTarget then return end
        if tostring(bt_data.candidateTarget) ~= tostring(myWuid) then return end

        self:TryClaimTarget(bt_data, myWuid, bt_data.candidate)
    end)

    if not ok then
        System.LogAlways('[Mercenary Jeff] EvaluateCombatTarget Error: ' .. tostring(err))
    end
end