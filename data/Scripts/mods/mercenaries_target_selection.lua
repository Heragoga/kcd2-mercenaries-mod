-- Validate whether an entity is a valid enemy target. skipRelationshipCheck
-- bypasses only the relationship gate, for whoever the player is already
-- fighting. See docs/combat-target-selection.md for the full ruleset.
function mercenaries:IsValidEnemy(ent, distanceRefEnt, playerWuid, skipRelationshipCheck)
    if ent.id == player.id then return false end
    if ent:GetName() == "companion_dog" then return false end

    if not self:IsAliveAndWell(ent, true) then return false end
    if ent.human and not ent.human:IsWeaponDrawn() then return false end
    if distanceRefEnt then
        local tp = ent:GetPos()
        local refPos = distanceRefEnt:GetPos()
        if tp and refPos then
            local dx, dy, dz = tp.x - refPos.x, tp.y - refPos.y, tp.z - refPos.z
            if math.sqrt(dx*dx + dy*dy + dz*dz) > self.TargetDetectionRadius then return false end
        end
    end
    
    local eid = tostring(ent.soul:GetId())

    -- Skip our own: regular mercs, archers, and the custom hero companion.
    if self.Souls then
        for _, tierList in pairs(self.Souls) do
            for _, guid in ipairs(tierList) do
                if string.find(eid, guid) then
                    return false
                end
            end
        end
    end

    if self.ArcherSouls then
        for _, guid in ipairs(self.ArcherSouls) do
            if string.find(eid, guid) then
                return false
            end
        end
    end
    if self.StaticArcherSouls then
        for _, guid in ipairs(self.StaticArcherSouls) do
            if string.find(eid, guid) then
                return false
            end
        end
    end
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
    if ent.soul:HasScriptContext("combat_flee")
    or ent.soul:HasScriptContext("combat_surrender")
    or ent.soul:HasScriptContext("crime_interruptFlee")
    or ent.soul:HasScriptContext("crime_fleeAfterSurrender")
    or ent.soul:HasScriptContext("combat_immortalityProtection")then
        return false
    end

    return true
end

-- Called once/sec from MonitorLoop: one sphere query + all soul-API validation
-- for the whole squad, cached in mercenaries.CachedEnemies. See the doc.
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

        -- Animals and horse cleanup run every 3rd tick (no per-second precision needed).
        self._animalQueryTick = (self._animalQueryTick or 0) + 1
        if self._animalQueryTick >= 3 then
            self._animalQueryTick = 0

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

-- Per-merc, each second from the BT: re-sort the pre-validated CachedEnemies by
-- distance from this merc (cheap math, no soul API) and keep the 8 nearest.
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

        table.sort(potentialTargets, function(a, b)
            return a.distance < b.distance
        end)

        -- Cap candidates: each one the BT checks costs an engine GetTarget call.
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

-- True if the entity is hurt badly enough to look after itself, not fight.
function mercenaries:IsHealthCritical(wuid, threshold)
    local ok, result = pcall(function()
        local ent = wuid and XGenAIModule.GetEntityByWUID(wuid)
        if not ent or not ent.soul then return false end
        local hp = ent.soul:GetState('health')
        return hp ~= nil and hp <= (threshold or 25)
    end)
    return ok and result or false
end

-- Claim a target for a merc if it's below SwarmCap; records it in MercTargetOf.
function mercenaries:TryClaimTarget(bt_data, myWuid, targetWuid)
    local targetWuidStr = tostring(targetWuid)
    if (self.TargetLoad[targetWuidStr] or 0) >= self.SwarmCap then return false end

    bt_data.playerTarget = targetWuid
    bt_data.isFriendly = false
    bt_data.foundTarget = true
    self.MercTargetOf[tostring(myWuid)] = targetWuidStr
    return true
end

-- Stance "everyone": the player's combat target first (claimed regardless of
-- relationship), else the nearest strictly-hostile cached enemy.
function mercenaries:PickNearestValidTarget(bt_data, myWuid)
    local ok, err = pcall(function()
        if bt_data.foundTarget then return end
        if myWuid and self:IsHealthCritical(myWuid, 25) then return end

        if bt_data.playerCombatTarget then
            local targetWuidStr = tostring(bt_data.playerCombatTarget)
            if targetWuidStr ~= "" and targetWuidStr ~= tostring(bt_data.playerWUID) then
                local targetEnt = XGenAIModule.GetEntityByWUID(bt_data.playerCombatTarget)
                if targetEnt and targetEnt.soul and self:IsValidEnemy(targetEnt, player, bt_data.playerWUID, true) then
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

-- Stance "player_target": only join whatever the player is currently fighting.
function mercenaries:PickPlayersTarget(bt_data, myWuid)
    local ok, err = pcall(function()
        if bt_data.foundTarget then return end
        if myWuid and self:IsHealthCritical(myWuid, 25) then return end
        if not bt_data.playerCombatTarget then return end

        local targetWuidStr = tostring(bt_data.playerCombatTarget)
        if targetWuidStr == "" or targetWuidStr == tostring(bt_data.playerWUID) then return end

        local targetEnt = XGenAIModule.GetEntityByWUID(bt_data.playerCombatTarget)
        if not targetEnt or not targetEnt.soul then return end
        if not self:IsValidEnemy(targetEnt, player, bt_data.playerWUID, true) then return end

        self:TryClaimTarget(bt_data, myWuid, bt_data.playerCombatTarget)
    end)

    if not ok then
        System.LogAlways('[Mercenary Jeff] PickPlayersTarget Error: ' .. tostring(err))
    end
end

-- Stance "defend": only fight back at a candidate personally targeting this merc.
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