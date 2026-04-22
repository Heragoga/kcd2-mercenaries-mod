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

        if not player then return end
        local playerPos = player:GetPos()
        if not playerPos then return end

        local playerWuid = player.this and player.this.id or player.id
        local entsInArea = System.GetEntitiesInSphere(playerPos, 15.0)
        if not entsInArea then return end

        for _, ent in pairs(entsInArea) do
            if ent and type(ent) == "table" and ent.soul then
                if self:IsValidEnemy(ent, player, playerWuid) then
                    local entWuid = ent.this and ent.this.id or ent.id
                    table.insert(self.CachedEnemies, { entity = ent, wuid = entWuid })
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

        for _, v in ipairs(potentialTargets) do
            table.insert(bt_data.enemiesArray, v.wuid)
        end
    end)

    if not ok then
        System.LogAlways('[Mercenary Jeff] ScanForEnemies Error: ' .. tostring(err))
    end
end

-- =======================================================================
-- CORE: Evaluates a candidate in a loop to see if they are a valid target
-- =======================================================================
function mercenaries:EvaluateCombatTarget(bt_data)
    local ok, err = pcall(function()
        if bt_data.foundTarget then return end

        -- Candidates in enemiesArray already passed IsValidEnemy inside
        -- UpdateEnemyCache, so we only need the squad-targeting check here.
        local isTargetingSquad = false

        if bt_data.candidateTarget then
            local targetWuidStr = tostring(bt_data.candidateTarget)
            local playerWuidStr = tostring(bt_data.playerWUID)

            -- 1. Are they targeting the player directly?
            if targetWuidStr == playerWuidStr then
                isTargetingSquad = true
            else
                -- 2. Are they targeting the dog or another mercenary?
                local targetEnt = XGenAIModule.GetEntityByWUID(bt_data.candidateTarget)
                if targetEnt then
                    local tName = targetEnt:GetName() or ""
                    if tName == "companion_dog" or self:GetMercType(targetEnt) ~= nil then
                        isTargetingSquad = true
                    end
                end
            end
        end

        if isTargetingSquad then
            bt_data.playerTarget = bt_data.candidate
            bt_data.isFriendly = false
            bt_data.foundTarget = true
        end
    end)

    if not ok then
        System.LogAlways('[Mercenary Jeff] EvaluateCombatTarget Error: ' .. tostring(err))
    end
end