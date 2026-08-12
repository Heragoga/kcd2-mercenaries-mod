-- Hire regular mercs.
function mercenaries:Hire(cost, amount, tier)
    local p = player.inventory

    self:Recount()
    if not _G.MercCount then _G.MercCount = 0 end

    if _G.MercCount + amount > self.MaxCompanions then
        Game.SendInfoText('merc_info_too_many', false, 0, 3)
        return
    end

    if p:GetMoney() < cost then
        Game.SendInfoText('merc_info_not_enough_money', false, 0, 3)
        return
    end

    p:RemoveMoney(cost)

    -- Gate SaveString: only write when state actually changes.
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
        local currentWeaponPreset = _G.MercCurrentWeapon or 1

        for i=1, amount do
            local idx = self.SoulIndex[tier]
            local soulGuid = soulList[idx]
            
            self.SoulIndex[tier] = idx + 1
            if self.SoulIndex[tier] > #soulList then 
                self.SoulIndex[tier] = 1 
            end
            
            local offsetPos = self:FindValidGround({
                x = spawnPos.x + (math.random() - 0.5) * 1.5,
                y = spawnPos.y + (math.random() - 0.5) * 1.5,
                z = spawnPos.z
            }, spawnPos.z)

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
                mercenaries:EnsureMercIsAlwaysRendered(ent)

                self:EquipMercenary(ent, currentPreset)
                self:EquipMercenaryWeapon(ent, currentWeaponPreset, currentPreset)
                -- Register in cache immediately so MonitorLoop needn't world-scan.
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

    -- A hero can only be hired once - bail if this one is already alive.
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

    if _G.MercCount + amount > self.MaxCompanions then
        Game.SendInfoText('merc_info_too_many', false, 0, 3)
        return
    end

    if p:GetMoney() < cost then
        Game.SendInfoText('merc_info_not_enough_money', false, 0, 3)
        return
    end

    p:RemoveMoney(cost)

    -- Gate SaveString: only write when state actually changes.
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

        local offsetPos = self:FindValidGround({
            x = spawnPos.x + (math.random() - 0.5) * 1.5,
            y = spawnPos.y + (math.random() - 0.5) * 1.5,
            z = spawnPos.z
        }, spawnPos.z)

        local safeRot = {x = 0, y = 0, z = playerRot.z}
        local entityName = "MercenaryCustomCompanion_" .. soulGuid .. "_" .. tostring(math.random(10000, 99999))

        System.SpawnEntity({
            class = "NPC", 
            name = entityName, 
            position = offsetPos, 
            orientation = safeRot, 
            properties = {guidSharedSoulId = soulGuid}
        })

        local ent = System.GetEntityByName(entityName)
        if ent then
            mercenaries:EnsureMercIsAlwaysRendered(ent)
            self.ActiveMercs[entityName] = ent
            self:InjectInteraction(ent)
        end
    end)
    
    if not ok then System.LogAlways('[Mercenaries] Teleport Error: ' .. tostring(err)) end

    Game.SendInfoText('merc_info_hired_special', false, 0, 3)
end

-- Debug: spawn a line of mercs (player centred) facing a line of renegades for
-- combat testing. counts are { weak, medium, strong } per side (default 7/7/6);
-- outfit/weapon args default to the squad's current gear (enemy side to a
-- distinct set). Each side is laid out strongest-first so the front rows get
-- the better troops.
function mercenaries:SpawnTestBattle(mercCounts, mercOutfit, mercWeapon, enemyCounts, enemyOutfit, enemyWeapon)
    local pos = player:GetWorldPos()
    local dir = player:GetDirectionVector()
    if not pos or not dir or (dir.x == 0 and dir.y == 0) then return end

    local playerAngleZ = player:GetAngles().z

    -- Perpendicular to facing, to lay out a row across the player's front.
    local rightX, rightY = dir.y, -dir.x

    mercCounts = mercCounts or { weak = 7, medium = 7, strong = 6 }
    enemyCounts = enemyCounts or { weak = 7, medium = 7, strong = 6 }

    mercOutfit = mercOutfit or _G.MercCurrentOutfit or 1
    mercWeapon = mercWeapon or _G.MercCurrentWeapon or 1
    enemyOutfit = enemyOutfit or self:GetEnemyOutfitFor(mercOutfit)
    enemyWeapon = enemyWeapon or mercWeapon

    local colSpacing = 1.2
    local rowSpacing = 1.5
    local rowSize = 10
    local enemyDistance = 18.0

    -- Strongest first, so filling row-by-row puts better troops at the front.
    local function buildTierOrder(counts)
        local order = {}
        for _ = 1, (counts.strong or 0) do table.insert(order, "strong") end
        for _ = 1, (counts.medium or 0) do table.insert(order, "medium") end
        for _ = 1, (counts.weak or 0) do table.insert(order, "weak") end
        return order
    end

    local mercTierOrder = buildTierOrder(mercCounts)
    local enemyTierOrder = buildTierOrder(enemyCounts)

    local ok, err = pcall(function()
        for i, tier in ipairs(mercTierOrder) do
            local col = ((i - 1) % rowSize) + 1
            local row = math.floor((i - 1) / rowSize)
            local colOffset = (col - (rowSize + 1) / 2) * colSpacing
            local rowOffset = row * rowSpacing

            local mx = pos.x + rightX * colOffset - dir.x * rowOffset
            local my = pos.y + rightY * colOffset - dir.y * rowOffset

            local soulList = self.Souls[tier]
            local soulGuid = soulList[((i - 1) % #soulList) + 1]

            local entityName = "SpawnedFriend_" .. tier .. "_" .. tostring(math.random(10000, 99999)) .. "_" .. soulGuid

            System.SpawnEntity({
                class = "NPC",
                name = entityName,
                position = { x = mx, y = my, z = pos.z },
                orientation = { x = 0, y = 0, z = playerAngleZ },
                properties = { guidSharedSoulId = soulGuid }
            })

            local ent = System.GetEntityByName(entityName)
            if ent then
                mercenaries:EnsureMercIsAlwaysRendered(ent)
                self:EquipMercenary(ent, mercOutfit)
                self:EquipMercenaryWeapon(ent, mercWeapon, mercOutfit)
                self.ActiveMercs[entityName] = ent
                self:InjectInteraction(ent)
            end
        end

        if _G.MercenariesDismissed ~= false then
            _G.MercenariesDismissed = false
            self:SaveString("MercenariesDismissed", "0")
        end
        if _G.MercIdle ~= false then
            _G.MercIdle = false
            self:SaveString("MercIdlePersistent", "0")
        end
        self:Recount()

        local enemyRowX = pos.x + dir.x * enemyDistance
        local enemyRowY = pos.y + dir.y * enemyDistance
        local enemyFacingAngle = playerAngleZ + math.pi
        if enemyFacingAngle > math.pi then enemyFacingAngle = enemyFacingAngle - (2 * math.pi) end

        for i, tier in ipairs(enemyTierOrder) do
            local col = ((i - 1) % rowSize) + 1
            local row = math.floor((i - 1) / rowSize)
            local colOffset = (col - (rowSize + 1) / 2) * colSpacing
            local rowOffset = row * rowSpacing

            local ex = enemyRowX + rightX * colOffset + dir.x * rowOffset
            local ey = enemyRowY + rightY * colOffset + dir.y * rowOffset

            local soulGuid = self.RenegadeSouls[self.RenegadeSoulIndex]
            self.RenegadeSoulIndex = self.RenegadeSoulIndex + 1
            if self.RenegadeSoulIndex > #self.RenegadeSouls then
                self.RenegadeSoulIndex = 1
            end

            local entityName = "SpawnedRenegade_" .. tier .. "_" .. tostring(math.random(10000, 99999)) .. "_" .. soulGuid

            System.SpawnEntity({
                class = "NPC",
                name = entityName,
                position = { x = ex, y = ey, z = pos.z },
                orientation = { x = 0, y = 0, z = enemyFacingAngle },
                properties = { guidSharedSoulId = soulGuid }
            })

            local ent = System.GetEntityByName(entityName)
            if ent then
                self:EquipMercenary(ent, enemyOutfit)
                self:EquipMercenaryWeapon(ent, enemyWeapon, enemyOutfit)
                -- No manual DrawWeapon() - see SpawnRenegade / the target-selection doc.
            end
        end
    end)

    if not ok then System.LogAlways('[Mercenaries] SpawnTestBattle error: ' .. tostring(err)) end

    System.LogAlways('[Mercenary Jeff] Spawned test battle: ' .. #mercTierOrder .. ' mercs vs ' .. #enemyTierOrder .. ' renegades.')
end

-- Console-friendly wrapper around SpawnTestBattle (numeric args for AddCCommand),
-- splitting countPerSide evenly across tiers (remainder to strong).
-- Outfits: 1 Generic, 2 Bandits, 3 Cumans, 4 Leipa, 5 Kuttenberg, 6 Skalitz.
-- Weapons: 2 Sword+shield, 3 Axe+shield, 4 Longsword, 5 Mace+shield,
--          6 Shortsword, 7 Mace, 8 Axe, 9 Polearm.
function mercenaries:SpawnBattle(mercOutfit, mercWeapon, enemyOutfit, enemyWeapon, countPerSide)
    mercOutfit = tonumber(mercOutfit)
    mercWeapon = tonumber(mercWeapon)
    enemyOutfit = tonumber(enemyOutfit)
    enemyWeapon = tonumber(enemyWeapon)
    countPerSide = tonumber(countPerSide) or 20

    local third = math.floor(countPerSide / 3)
    local remainder = countPerSide - (third * 3)
    local counts = { weak = third, medium = third, strong = third + remainder }

    self:SpawnTestBattle(counts, mercOutfit, mercWeapon, counts, enemyOutfit, enemyWeapon)
end

-- ============================================================================
-- Enemy groups (replaces the old renegades). Six hostile groups that attack
-- ONLY the player and the mercenaries faction (hired mercs, archers and
-- companions). One shared faction (enemiesFaction). Melee use renegade_brain;
-- archers use enemy_archer_brain (missile). Souls/appearance/faction/skald are
-- in data/libs (*__enemies.xml); combat_level per soul mirrors the merc tiers.
-- Spawned as "SpawnedEnemy_<group>_<tier>_<rand>_<guid>". See docs/enemies.md.
-- ============================================================================
-- Pick an outfit index for SpawnTestBattle's enemy line that differs from the
-- mercs' current one, so the two battle lines read as distinct at a glance.
mercenaries.EnemyOutfitOverride = {
    [1] = 5, [2] = 5, [3] = 1, [4] = 2, [5] = 2, [6] = 2
}
function mercenaries:GetEnemyOutfitFor(mercOutfit)
    local override = self.EnemyOutfitOverride[mercOutfit]
    if override then return override end
    local outfitCount = 0
    for _ in pairs(self.Outfits) do outfitCount = outfitCount + 1 end
    if outfitCount < 2 then return mercOutfit end
    return ((mercOutfit % outfitCount) + 1)
end

mercenaries.EnemyGroups = {
    looter = {
        label = "Looters",
        clothing = {
            "20aba0c4-1cfb-42de-97dd-939530d6240d", "2285cbe9-3962-4093-94a9-86f556e5bf2f", "87d45cbe-f5af-418b-a238-9de0a541b28d",
            "8c3c5bb8-ffaa-4f30-b635-9af37750a4d0", "c8f922a2-f889-4d90-9d1d-3ffc26f90961", "e0eefec7-ac35-46eb-a07e-9cda47a926bb",
            "07a49bb9-1b92-43c2-848f-f4abf88a3b12", "c685a814-ace0-4c6b-b8bb-9a024d073d42", "394c8de2-7525-4f3a-8774-17876c95b6b6",
            "fdec006f-b7e2-491a-8a1d-f453501b7ffc", "0154a9ef-ad07-4c4a-bf5b-4bca21b65d7b", "d4468c20-47e3-49dd-995e-65063040696e",
        },
        melee = {
            { guid = "c5d5e34d-db66-59ab-b746-8b33acb1c6bc", tier = "weak" },
            { guid = "ee7360d6-aab7-541d-81ae-38181f4c1eed", tier = "weak" },
            { guid = "944cbf53-adbb-5371-8338-1f6c06ca6c0d", tier = "weak" },
            { guid = "63b84059-ad9f-53d7-bd3a-02cdb5cf0d31", tier = "weak" },
            { guid = "91e21fc3-e1d3-5fb2-8064-f0f24166dc67", tier = "weak" },
            { guid = "3a0e97de-66eb-548d-9f2e-e0263b0d9a32", tier = "weak" },
            { guid = "718f3c3a-8a1b-5c8e-82ec-8a48ef3ac884", tier = "weak" },
            { guid = "542c2d13-16d2-5389-81ae-ec6cbbbdf77e", tier = "weak" },
            { guid = "dcfe1fd1-ba0d-505c-a715-e848d224aa24", tier = "weak" },
            { guid = "b695f7ea-8d54-5218-864f-87b7df0afe2b", tier = "weak" },
        },
        archers = {
            "d95aee4b-bc8e-50fb-b9d9-bbca1cac62c9",
            "d99b867b-a4fd-559e-86b7-a2aa7be6ca8d",
        },
    },
    bandit = {
        label = "Bandits",
        clothing = {
            "07a49bb9-1b92-43c2-848f-f4abf88a3b12", "c685a814-ace0-4c6b-b8bb-9a024d073d42", "394c8de2-7525-4f3a-8774-17876c95b6b6",
            "fdec006f-b7e2-491a-8a1d-f453501b7ffc", "0154a9ef-ad07-4c4a-bf5b-4bca21b65d7b", "d4468c20-47e3-49dd-995e-65063040696e",
            "48f33d37-90ab-489a-9236-d56819d25ea2", "94d6d667-139b-4d79-a25b-f2b608b86c96", "ed029076-0371-4dd1-86dc-bdacc427f593",
            "0e75824c-19de-40d2-a6fa-14d6c9964c48",
        },
        melee = {
            { guid = "3740f7d5-082e-5b52-a295-e59d1fbfd5cf", tier = "medium" },
            { guid = "a5e89011-3694-5cf9-9549-5681e018f3f6", tier = "medium" },
            { guid = "f095dba0-7692-5a3b-85fd-3c66ced13c93", tier = "medium" },
            { guid = "024aed8f-ae8b-54a1-912f-ac50fb5d8286", tier = "medium" },
            { guid = "0a9d294b-c6a3-5103-9f13-697c07161797", tier = "medium" },
            { guid = "0cfb723d-4108-5742-a9e7-b901183694ba", tier = "strong" },
            { guid = "314c9fea-1365-5a7b-92b2-32bb604e5675", tier = "strong" },
            { guid = "d2043a49-34d1-5fbb-bc31-9ba26acfb7bc", tier = "strong" },
            { guid = "99808773-0bc9-5122-9664-5afbe5a2e9c5", tier = "strong" },
            { guid = "6082d7a9-aaac-56f9-968a-2ad8bc889d23", tier = "strong" },
        },
        archers = {
            "9e7771ac-433c-56d5-a8cb-1a0421f14480",
            "df24a6fd-b4e4-5fe7-8412-77e770378c73",
        },
    },
    sigi = {
        label = "Sigismund's soldiers",
        clothing = {
            "38a0421c-2f15-4f06-882e-08ec70b60964", "ea1790da-3e8c-42ab-91f9-c7a32aadba8c", "756deef5-2f65-43b8-80ce-c24f71c5fa8c",
            "867554aa-3869-4cd5-9a68-777758c6ac62", "a7ed4975-d7eb-453c-b105-1c00b3ef4004", "27819f74-9253-445f-9854-4947fd8d63c6",
            "47e600f9-211a-4bd9-81df-f8e2f72e0797", "2743aeed-5875-485d-9876-22a672e16847", "f726b377-64ad-4214-871c-4ac2cf64246f",
            "6fff0f15-312a-4197-8c0a-b4b5cf0f5543", "2c786925-afb6-4433-bde5-c00d5f1965fd", "fa9eb229-a17f-4603-a60d-0c7058f3b44b",
        },
        melee = {
            { guid = "b2cdf9d2-e2ac-5d65-ac26-14bbb604ea02", tier = "weak" },
            { guid = "dfeb0a05-e07d-55fe-a4f7-56dcfab824ac", tier = "weak" },
            { guid = "b18da434-a2b9-554e-bfd6-e4741d950272", tier = "weak" },
            { guid = "c5d77741-a0e3-56cf-ab92-e7253a59106f", tier = "weak" },
            { guid = "6f56cd06-fd11-5798-bcec-166a99bc0ba9", tier = "weak" },
            { guid = "5395e5ff-c70c-5abb-8137-ff4eea3fa515", tier = "medium" },
            { guid = "04106fb0-c42c-52e8-9101-2e219a2aeffd", tier = "medium" },
            { guid = "64ee05d8-5769-55ca-81da-48d2dd38e45e", tier = "medium" },
            { guid = "5f325223-8813-5a52-9dd1-71532bbe80e3", tier = "medium" },
            { guid = "f8a43a7f-7fcf-56eb-b198-d2aa6d191eee", tier = "medium" },
        },
        archers = {
            "aa0f78f0-963c-5508-bb29-784324d3daad",
            "1f780618-8147-50d8-963f-4e5b16212e7c",
        },
    },
    prague = {
        label = "Prague regiment",
        clothing = {
            "1d2added-3bb4-499e-a8d4-47c173645aaf", "4a9f5058-bfcf-4aaf-b3a6-61148255cfb1", "8613aa99-02bb-4aa5-988c-ce18ea85f848",
            "c0301b0e-684d-47c1-b3d3-349a97978413", "5932acad-aa4f-484c-9b48-397090f51d1c", "27a95a3c-3d88-4f42-beea-baea8ae7c486",
            "40b88acb-c938-4873-b925-9eca6d6d15ab", "90c339e3-5bba-4bde-a95a-65b15b17469a", "8244772d-c115-4db3-82fe-3d1b3ec48019",
            "91889017-8282-4638-980a-bfc258b68f02",
        },
        melee = {
            { guid = "b8fc46b7-74a1-5642-bd92-9da50b68a131", tier = "medium" },
            { guid = "8b166a9f-59a0-5d49-9317-09572f2af1ca", tier = "medium" },
            { guid = "96e1f4ef-0a7e-5b56-abb0-3884e4f46842", tier = "medium" },
            { guid = "a744baf6-6cee-5e3e-b02f-040c2fa3cfd0", tier = "medium" },
            { guid = "37da924f-0706-5feb-ac9f-255871d6c4d9", tier = "medium" },
            { guid = "98bff80d-be11-53f4-a668-0f0d249aa003", tier = "strong" },
            { guid = "54c00c33-073d-52bd-9198-c9b14b4d59de", tier = "strong" },
            { guid = "48361147-753e-5bc6-99fb-e34c5991edca", tier = "strong" },
            { guid = "148fd71b-6406-5476-bdb1-0f632e1c4be4", tier = "strong" },
            { guid = "6f77156e-f03f-5f4a-b5af-027e3e008d8d", tier = "strong" },
        },
        archers = {
            "2f814f9f-c653-5748-8d58-fe93aab42bf0",
            "0ac880dd-1a09-527b-91d4-f50d71f6a08f",
        },
    },
    cuman = {
        label = "Cumans",
        clothing = {
            "08d7d086-327a-4f95-92d3-6a6c60a494f0", "1291b696-d704-4fb0-90da-2bdf4c2eefef", "4163bbb6-a7bf-47a3-b5c7-bffdbe0c2062",
            "838f07ef-5875-4391-9fe2-5fd93ffa6501", "e1f7bfd8-f211-4693-9004-0fc36f166e1f", "fca2a301-45e5-4cd9-af18-09469bbd8102",
            "70618c60-9f1e-4949-a1d2-06b1a9709e82", "9b9f92a0-7040-4f3e-85ee-1f2651ee6672", "8d8951b3-af89-4c0a-a7d6-99c8f6f7fe86",
            "bd87c9e4-5481-4a98-8279-ec010e4c10ad", "978b6b0c-288b-4d0b-8cfa-f2fe1a801409", "efff8f2e-a199-4883-8bb8-3219c4103e22",
        },
        melee = {
            { guid = "91be4853-2c08-5897-9950-45bc0340e698", tier = "weak" },
            { guid = "d1eebb41-b561-5d43-ac96-57a132225d90", tier = "weak" },
            { guid = "8c50c097-4214-58c6-b3a5-a4aff8331eaf", tier = "weak" },
            { guid = "ca3c558d-8eee-5406-ae0f-65638445ce62", tier = "weak" },
            { guid = "3a4eaad1-2394-5ba6-aa20-5f1a959f32a3", tier = "medium" },
            { guid = "a2888224-b662-5f87-99b8-74bdcf2a8d47", tier = "medium" },
            { guid = "f1a77dbd-d784-5e1a-a6ab-85ce365d8d78", tier = "medium" },
            { guid = "b9d2aba9-0745-509d-a33d-52b933a68c62", tier = "strong" },
            { guid = "13350b8a-8b50-5961-9848-eeb7cdc676d4", tier = "strong" },
            { guid = "c6404cc4-96b5-592d-a267-3076852e9055", tier = "strong" },
        },
        archers = {
            "6fb9e36c-d1ba-5dfc-9169-4dcb57c60609",
            "f52aff9e-c17b-5c24-ae53-fc334b103343",
        },
    },
    knight = {
        label = "Sigismund's knights",
        -- Elites: combat_level is maxed (1.0) in the soul, so extra strength comes
        -- from a health boost applied on spawn (see EquipEnemy).
        healthMult = 1.6,
        -- Best in-game armour: every preset here has a steel cuirass (breastplate),
        -- tier 5-6 Sigismund / Kuttenberg plate. Mix of surcoated (waffenrock, first
        -- two rows) and plain plate (third row), so not every knight wears a tabard.
        clothing = {
            "b7d72548-8a0a-4631-b1c1-21c692ec99c4", "418ca358-97de-47c8-acd5-92bdcd11d157", "0f5e458e-1a8b-4477-8a02-8e11d96fe371",
            "768e217c-c1a8-46f4-af72-4924e9e6a552", "889f554c-d211-4147-8bd7-8432d2420ec0", "39681dff-fd4a-44ba-83b2-61c5611130ff",
            "8a6ea286-b8f7-458c-abdf-193f5b4a0542", "cbd0d40e-0b19-4e21-b896-7c11c2c64bdd", "fe31e28a-d4c9-4b8c-9e87-82dc40123042",
        },
        -- Knights prefer swords and maces (WeaponSets: 2 sword+shield, 4 longsword,
        -- 5 mace+shield, 7 mace) over axes/polearms. Tier is strong (best weapons).
        weapons = { 2, 4, 5, 7 },
        melee = {
            { guid = "25f42406-fa61-5842-bdaf-f879920cce87", tier = "strong" },
            { guid = "5b12e6cf-119d-55dc-a98a-ce5f169b09f1", tier = "strong" },
            { guid = "4685f05b-3703-5f87-8f83-20955818ebce", tier = "strong" },
            { guid = "4da9c018-bb9f-524d-aa53-ba7bc2d59984", tier = "strong" },
            { guid = "e1bc3abd-ed3c-5c0b-9e3a-5b11525d9a14", tier = "strong" },
        },
        archers = {
        },
    },

    -- Heinrich: a single, absurdly overpowered boss - essentially a late-game
    -- player. Henry's own look (henry head/hair/body), his final plate armour,
    -- St. George's sword, maxed combat_level (1.0) and 2x health. Spawn one.
    heinrich = {
        label = "Heinrich",
        healthMult = 2.0,
        weaponPreset = "94600b75-8cd2-42f5-8a85-9e5ad0db8318", -- sword_StGeorge (best sword)
        clothing = { "a6300700-1413-4314-bac5-fb7a6d132fe0" }, -- UC_HenryFinalArmor
        melee = {
            { guid = "1c9e791f-09ea-5171-96e7-102188affa24", tier = "strong" },
        },
        archers = {
        },
    },
}

-- Round-robin cursors so repeated spawns cycle faces instead of repeating one.
mercenaries.EnemySoulIndex = {}
mercenaries.EnemyArcherIndex = {}
for gk in pairs(mercenaries.EnemyGroups) do
    mercenaries.EnemySoulIndex[gk] = 1
    mercenaries.EnemyArcherIndex[gk] = 1
end

-- Anti-swarm bookkeeping for enemies, kept separate from the mercs' pool.
mercenaries.EnemySwarmCap = 2
mercenaries.EnemyTargetOf = {}   -- [enemyWuidStr] = targetWuidStr
mercenaries.EnemyTargetLoad = {} -- [targetWuidStr] = enemies currently on it

-- Dress a freshly spawned enemy: clothing from the group's pool, weapon via the
-- shared merc weapon path (which parses the tier out of the entity name, and
-- routes "_archer_" names to the bow set automatically).
function mercenaries:EquipEnemy(ent, groupKey, isArcher)
    if not ent or not ent.actor then return end
    local grp = self.EnemyGroups[groupKey]
    if not grp then return end
    local clothing = grp.clothing[math.random(1, #grp.clothing)]
    if clothing then pcall(function() ent.actor:EquipClothingPreset(clothing) end) end
    -- Weapon. A group can pin one exact preset (grp.weaponPreset, e.g. Heinrich's
    -- St. George's sword), or restrict to a preferred set of WeaponSets categories
    -- (grp.weapons, e.g. knights favour swords/maces); otherwise 1 = random melee
    -- category. Archers ignore all of this and get the bow (EquipMercenaryWeapon
    -- routes "_archer_" names to the bow set).
    if grp.weaponPreset and not isArcher then
        pcall(function() ent.actor:EquipWeaponPreset(grp.weaponPreset) end)
    else
        local weaponIndex = 1
        if grp.weapons and #grp.weapons > 0 and not isArcher then
            weaponIndex = grp.weapons[math.random(1, #grp.weapons)]
        end
        self:EquipMercenaryWeapon(ent, weaponIndex, nil)
    end

    -- combat_level tops out at 1.0, so groups that want to hit harder than that
    -- (the knights) get a health multiplier instead, making them tankier elites.
    if grp.healthMult and ent.actor then
        pcall(function()
            local maxHp = ent.actor:GetMaxHealth()
            if maxHp and maxHp > 0 then
                local boosted = maxHp * grp.healthMult
                ent.actor:SetMaxHealth(boosted)
                ent.actor:SetHealth(boosted)
            end
        end)
    end
end

-- Spawn ONE member of a group at an exact spot. The single spawn path for every
-- encounter (ambushes, patrols, bandit camps, the siege) - see docs/encounters.md.
-- Souls round-robin per group so repeats vary; the tier (or "archer") goes in the
-- name because the weapon/AI code parses it back out of there.
function mercenaries:SpawnEnemyAt(groupKey, isArcher, pos, yaw)
    local grp = self.EnemyGroups[groupKey]
    if not (grp and pos) then return nil end
    if isArcher and #grp.archers == 0 then isArcher = false end

    local ent
    local ok, err = pcall(function()
        local soulGuid, tierName
        if isArcher then
            soulGuid = grp.archers[self.EnemyArcherIndex[groupKey]]
            self.EnemyArcherIndex[groupKey] = (self.EnemyArcherIndex[groupKey] % #grp.archers) + 1
            tierName = "archer"
        else
            local m = grp.melee[self.EnemySoulIndex[groupKey]]
            self.EnemySoulIndex[groupKey] = (self.EnemySoulIndex[groupKey] % #grp.melee) + 1
            soulGuid, tierName = m.guid, m.tier
        end

        local entityName = "SpawnedEnemy_" .. groupKey .. "_" .. tierName .. "_" ..
                           tostring(math.random(10000, 99999)) .. "_" .. soulGuid

        System.SpawnEntity({
            class = "NPC",
            name = entityName,
            position = pos,
            orientation = { x = 0, y = 0, z = yaw or 0 },
            properties = { guidSharedSoulId = soulGuid }
        })

        ent = System.GetEntityByName(entityName)
        if ent then self:EquipEnemy(ent, groupKey, isArcher) end
    end)
    if not ok then System.LogAlways('[Enemies] SpawnEnemyAt error: ' .. tostring(err)) end
    return ent
end

-- Spawn `amount` members of an enemy group behind the player. Mostly melee, with
-- roughly every 4th unit an archer when the group has any (knights have none).
function mercenaries:SpawnEnemyGroup(groupKey, amount)
    amount = tonumber(amount) or 1
    local grp = self.EnemyGroups[groupKey]
    if not grp then
        System.LogAlways('[Enemies] Unknown group: ' .. tostring(groupKey))
        return
    end

    local ok, err = pcall(function()
        local spawnPos, playerRot = self:GetSafeSpawnPosition(player, 8)
        if not spawnPos then return end

        local playerPos = player:GetWorldPos()
        local awayX, awayY = 0, 1
        if playerPos then
            awayX, awayY = spawnPos.x - playerPos.x, spawnPos.y - playerPos.y
            local awayLen = math.sqrt(awayX * awayX + awayY * awayY)
            if awayLen > 0.01 then awayX, awayY = awayX / awayLen, awayY / awayLen
            else awayX, awayY = 0, 1 end
        end
        local rightX, rightY = awayY, -awayX
        -- Lay them out in a single row of 10 (wraps to a second rank beyond 10).
        local spacing, rowSize = 1.8, 10

        for i = 1, amount do
            local col = ((i - 1) % rowSize) + 1
            local row = math.floor((i - 1) / rowSize)
            local colOffset = (col - (rowSize + 1) / 2) * spacing
            local rowOffset = row * spacing
            local px = spawnPos.x + rightX * colOffset + awayX * rowOffset
            local py = spawnPos.y + rightY * colOffset + awayY * rowOffset
            local unitPos = self:FindValidGround({ x = px, y = py, z = spawnPos.z }, spawnPos.z)

            -- No manual DrawWeapon(): the attack tree's automation owns weapon draw.
            self:SpawnEnemyAt(groupKey, (i % 4 == 0), unitPos, playerRot.z)
        end
    end)

    if not ok then System.LogAlways('[Enemies] SpawnEnemyGroup error: ' .. tostring(err)) end
    System.LogAlways('[Enemies] Spawned ' .. amount .. ' x ' .. tostring(groupKey) .. '.')
end

-- ---------------------------------------------------------------------------
-- Backward-compat shims: the old renegade tokens / dialog menu / test battle
-- still call these. Map the three renegade tiers onto representative groups.
-- ---------------------------------------------------------------------------
mercenaries.RenegadeTierToGroup = { weak = "looter", medium = "bandit", strong = "knight" }

function mercenaries:SpawnRenegade(amount, _outfit, tier, _weapon)
    self:SpawnEnemyGroup(self.RenegadeTierToGroup[tier or "strong"] or "bandit", amount or 1)
end

-- Flat pool of enemy melee souls, used by SpawnTestBattle's enemy line.
mercenaries.RenegadeSouls = {}
for _, gk in ipairs({ "looter", "bandit", "sigi", "prague", "cuman", "knight" }) do
    for _, m in ipairs(mercenaries.EnemyGroups[gk].melee) do
        mercenaries.RenegadeSouls[#mercenaries.RenegadeSouls + 1] = m.guid
    end
end
mercenaries.RenegadeSoulIndex = 1

-- ---------------------------------------------------------------------------
-- Shared enemy target picker (called ~1s from enemy_melee_scheduler.xml and
-- enemy_archer_scheduler.xml). Unlike the old renegades (who fought everyone),
-- enemies ONLY target the player and the player's mercs/archers/companions -
-- never vanilla NPCs and never each other. Swarm-capped; sticks to a close,
-- live target. See docs/combat-target-selection.md.
-- ---------------------------------------------------------------------------
mercenaries.EnemyTargetStickRange = 5.0

function mercenaries:IsEnemySpawnName(name)
    if not name then return false end
    return string.find(name, 'SpawnedEnemy_', 1, true) ~= nil
        or string.find(name, 'SpawnedRenegade_', 1, true) ~= nil
end

-- Is this entity a valid enemy target: the player, or anything matching the
-- configurable prefix list (defaults to the player's mercs / archers /
-- companions). Encounter code can extend the list from outside.
mercenaries.EnemyTargetPrefixes = { "SpawnedFriend_", "MercenaryCustomCompanion" }

function mercenaries:IsEnemyTargetable(ent)
    if ent == player then return true end
    local n = ent:GetName() or ''
    for _, p in ipairs(self.EnemyTargetPrefixes) do
        if string.find(n, p, 1, true) then return true end
    end
    return false
end

function mercenaries:FindEnemyTarget(data, myWuid)
    local ok, err = pcall(function()
        local me = XGenAIModule.GetEntityByWUID(myWuid)
        if not me then return end
        local mp = me:GetPos()
        if not mp then return end

        -- Encounter override: a forced target (ForcedTargetOf, set from outside)
        -- wins over scanning for as long as it stays alive.
        local forced = self.ForcedTargetOf and self.ForcedTargetOf[tostring(myWuid)]
        if forced then
            local fe = XGenAIModule.GetEntityByWUID(forced)
            if fe and self:IsAliveAndWell(fe, true) then
                data.currentTarget = forced
                self.EnemyTargetOf[tostring(myWuid)] = tostring(forced)
                return
            end
            self.ForcedTargetOf[tostring(myWuid)] = nil
        end

        if data.currentTarget then
            local curEnt = XGenAIModule.GetEntityByWUID(data.currentTarget)
            if curEnt and self:IsAliveAndWell(curEnt, true) then
                local cp = curEnt:GetPos()
                if cp then
                    local dx, dy, dz = cp.x - mp.x, cp.y - mp.y, cp.z - mp.z
                    local walled = self.NavTargetBlocked and self:NavTargetBlocked(me, curEnt)
                    if not walled and (dx*dx + dy*dy + dz*dz) <= (self.EnemyTargetStickRange * self.EnemyTargetStickRange) then
                        return -- keep current close, live target
                    end
                    -- a wall went up between us (or he ran behind one): drop him
                    if walled then
                        data.currentTarget = nil
                        self.EnemyTargetOf[tostring(myWuid)] = nil
                    end
                end
            end
        end

        local myWuidStr = tostring(myWuid)
        local radius = 50.0
        local radiusSq = radius * radius

        self.EnemyTargetLoad = {}
        for _, tw in pairs(self.EnemyTargetOf) do
            self.EnemyTargetLoad[tw] = (self.EnemyTargetLoad[tw] or 0) + 1
        end

        local candidates = {}
        if player and self:IsAliveAndWell(player, true) then
            local pp = player:GetPos()
            if pp then
                local dx, dy, dz = pp.x - mp.x, pp.y - mp.y, pp.z - mp.z
                local d2 = dx*dx + dy*dy + dz*dz
                local walled = self.NavTargetBlocked and self:NavTargetBlocked(me, player)
                if d2 <= radiusSq and not walled then table.insert(candidates, { wuid = player.this.id, distSq = d2 }) end
            end
        end

        local ents = System.GetPhysicalEntitiesInBoxByClass(mp, radius, "NPC")
        if ents then
            for _, ent in pairs(ents) do
                if ent and type(ent) == "table" and ent.soul and ent.this and ent.this.id then
                    if tostring(ent.this.id) ~= myWuidStr and self:IsEnemyTargetable(ent) and self:IsAliveAndWell(ent, true)
                       and not (self.NavTargetBlocked and self:NavTargetBlocked(me, ent)) then
                        local ep = ent:GetPos()
                        if ep then
                            local dx, dy, dz = ep.x - mp.x, ep.y - mp.y, ep.z - mp.z
                            local d2 = dx*dx + dy*dy + dz*dz
                            if d2 <= radiusSq then table.insert(candidates, { wuid = ent.this.id, distSq = d2 }) end
                        end
                    end
                end
            end
        end

        if #candidates == 0 then
            data.currentTarget = nil
            self.EnemyTargetOf[myWuidStr] = nil
            return
        end

        table.sort(candidates, function(a, b) return a.distSq < b.distSq end)

        local chosen = nil
        for _, c in ipairs(candidates) do
            if (self.EnemyTargetLoad[tostring(c.wuid)] or 0) < self.EnemySwarmCap then
                chosen = c.wuid; break
            end
        end
        if not chosen then chosen = candidates[1].wuid end

        data.currentTarget = chosen
        self.EnemyTargetOf[myWuidStr] = tostring(chosen)
    end)

    if not ok then System.LogAlways('[Enemies] FindEnemyTarget error: ' .. tostring(err)) end
end

-- Legacy alias (no tree calls this anymore, kept for safety).
function mercenaries:FindRenegadeTarget(data, myWuid)
    return self:FindEnemyTarget(data, myWuid)
end

-- ============================================================
-- Control test: single fixed-soul merc.
--
-- The Malesov quest-override experiment needs the SAME soul GUID every time
-- so it can be pre-injected into specific SoulAssets - the normal Hire path
-- cycles SoulIndex through the whole tier list. This spawns exactly one merc
-- bound to mercenaries.TestSoulGuid: free, no cap check, no dismissal/idle
-- state changes. See docs/quest-override-test.md.
mercenaries.TestSoulGuid = "e1f2a3b4-1234-4efa-c890-123456789012"


function mercenaries:SpawnTestMerc()
    local soulGuid = self.TestSoulGuid

    local ok, err = pcall(function()
        local spawnPos, playerRot = self:GetSafeSpawnPosition(player, 3)
        if not spawnPos then
            System.LogAlways('[MercTest] no safe spawn position found')
            return
        end

        -- Name keeps the SpawnedFriend_ prefix so every existing system
        -- (cache, follow, targeting) treats it as a normal merc.
        local entityName = "SpawnedFriend_strong_" .. tostring(math.random(10000, 99999)) .. "_" .. soulGuid

        System.SpawnEntity({
            class = "NPC",
            name = entityName,
            position = self:FindValidGround(spawnPos, spawnPos.z),
            orientation = {x = 0, y = 0, z = playerRot.z},
            properties = {guidSharedSoulId = soulGuid}
        })

        local ent = System.GetEntityByName(entityName)
        if not ent then
            System.LogAlways('[MercTest] SpawnEntity produced no entity: ' .. entityName)
            return
        end

        self:EquipMercenary(ent, _G.MercCurrentOutfit or 1)
        self:EquipMercenaryWeapon(ent, _G.MercCurrentWeapon or 1, _G.MercCurrentOutfit or 1)
        self.ActiveMercs[entityName] = ent
        self:InjectInteraction(ent)

        -- Follow needs the squad to be un-dismissed and not idling.
        _G.MercenariesDismissed = false
        _G.MercIdle = false
        self:Recount()

        System.LogAlways('[MercTest] spawned ' .. entityName)
        System.LogAlways('[MercTest] soul guid: ' .. soulGuid)
    end)

    if not ok then
        System.LogAlways('[MercTest] spawn error: ' .. tostring(err))
    end
end

