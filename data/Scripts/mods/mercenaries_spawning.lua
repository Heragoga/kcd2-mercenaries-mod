--Hire regular mercs
function mercenaries:Hire(cost, amount, tier)
    local p = player.inventory

    self:Recount()
    if not _G.MercCount then _G.MercCount = 0 end

    -- Check limits and cost first (Early Exit)
    if _G.MercCount + amount > self.MaxCompanions then
        Game.SendInfoText('merc_info_too_many', false, 0, 3)
        return
    end

    if p:GetMoney() < cost then
        Game.SendInfoText('merc_info_not_enough_money', false, 0, 3)
        return
    end

    -- Apply costs and update variables
    p:RemoveMoney(cost)

    -- Gate SaveString: only write if state actually needs to change
    if _G.MercenariesDismissed ~= false then
        _G.MercenariesDismissed = false
        self:SaveString("MercenariesDismissed", "0")
    end
    if _G.MercIdle ~= false then
        _G.MercIdle = false
        _G.MercPersistentIdleFlag = false
        self:SaveString("MercIdlePersistent", "0")
    end

    _G.MercCount = _G.MercCount + amount

    local ok, err = pcall(function()
        local spawnPos, playerRot = self:GetSafeSpawnPosition(player, 3)
        if not spawnPos then return end

        local soulList = self.Souls[tier] or self.Souls["weak"]
        
        local currentPreset = _G.MercCurrentOutfit or 1

        for i=1, amount do
            local idx = self.SoulIndex[tier]
            local soulGuid = soulList[idx]
            
            self.SoulIndex[tier] = idx + 1
            if self.SoulIndex[tier] > #soulList then 
                self.SoulIndex[tier] = 1 
            end
            
            local offsetPos = {
                x = spawnPos.x + (math.random() - 0.5) * 1.5,
                y = spawnPos.y + (math.random() - 0.5) * 1.5,
                z = spawnPos.z
            }

            local safeRot = {x = 0, y = 0, z = playerRot.z}
            local entityName = "SpawnedFriend_" .. tier .. "_" .. tostring(math.random(10000, 99999)) .. "_" .. soulGuid

            -- Spawn the entity
            System.SpawnEntity({
                class = "NPC", 
                name = entityName, 
                position = offsetPos, 
                orientation = safeRot, 
                properties = {guidSharedSoulId = soulGuid}
            })
            
            local ent = System.GetEntityByName(entityName)

            if ent then
                self:EquipMercenary(ent, currentPreset)
                -- PERFORMANCE: Register in cache immediately so the next
                -- MonitorLoop tick doesn't need a full world scan to find them.
                self.ActiveMercs[entityName] = ent
                self:InjectInteraction(ent)

            end

        end

    end)
    
    if not ok then System.LogAlways('[Mercenaries] Teleport Error: ' .. tostring(err)) end

    if amount == 1 then
        Game.SendInfoText('merc_info_hired_single', false, 0, 3)
    else
        Game.SendInfoText('merc_info_hired_multiple', false, 0, 3)
    end
end


function mercenaries:HireCustomCompanion(ccID)
    local p = player.inventory
    local amount = 1
    
    local heroData = self.CustomCompanionsData[ccID]
    if not heroData then 
        System.LogAlways('[Mercenaries] Error: Invalid custom companion ID passed: ' .. tostring(ccID))
        return 
    end

    local cost = heroData.cost
    local soulGuid = heroData.guid

    -- Check if this hero is already alive in the world using the cache first
    for name, ent in pairs(self.ActiveMercs) do
        if string.find(name, soulGuid, 1, true) then
            local ok, hp = pcall(function() return ent.soul:GetState('health') end)
            if (ok and hp and hp > 0) or not ok then
                Game.SendInfoText('merc_info_already_hired', false, 0, 3)
                return
            end
        end
    end

    self:Recount()
    if not _G.MercCount then _G.MercCount = 0 end

    -- Check limits and cost first (Early Exit)
    if _G.MercCount + amount > self.MaxCompanions then
        Game.SendInfoText('merc_info_too_many', false, 0, 3)
        return
    end

    if p:GetMoney() < cost then
        Game.SendInfoText('merc_info_not_enough_money', false, 0, 3)
        return
    end

    -- Apply costs and update variables
    p:RemoveMoney(cost)

    -- Gate SaveString: only write if state actually needs to change
    if _G.MercenariesDismissed ~= false then
        _G.MercenariesDismissed = false
        self:SaveString("MercenariesDismissed", "0")
    end
    if _G.MercIdle ~= false then
        _G.MercIdle = false
        self:SaveString("MercIdlePersistent", "0")
    end

    _G.MercCount = _G.MercCount + amount

    local ok, err = pcall(function()
        local spawnPos, playerRot = self:GetSafeSpawnPosition(player, 3)
        if not spawnPos then return end
        
        local offsetPos = {
            x = spawnPos.x + (math.random() - 0.5) * 1.5,
            y = spawnPos.y + (math.random() - 0.5) * 1.5,
            z = spawnPos.z
        }

        local safeRot = {x = 0, y = 0, z = playerRot.z}
        local entityName = "MercenaryCustomCompanion_" .. soulGuid .. "_" .. tostring(math.random(10000, 99999))

        System.SpawnEntity({
            class = "NPC", 
            name = entityName, 
            position = offsetPos, 
            orientation = safeRot, 
            properties = {guidSharedSoulId = soulGuid}
        })

        -- PERFORMANCE: Register in cache immediately
        local ent = System.GetEntityByName(entityName)
        if ent then
            self.ActiveMercs[entityName] = ent
            self:InjectInteraction(ent)

        end
    end)
    
    if not ok then System.LogAlways('[Mercenaries] Teleport Error: ' .. tostring(err)) end

    Game.SendInfoText('merc_info_hired_special', false, 0, 3)
end