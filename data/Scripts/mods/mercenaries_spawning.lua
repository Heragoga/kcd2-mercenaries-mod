-- Hire regular mercs.
function mercenaries:Hire(cost, amount, tier)
    local p = player.inventory

    self:Recount()
    if not _G.MercCount then _G.MercCount = 0 end

    -- Both rejections below were completely silent in the log - a small on-screen toast
    -- was the only trace, easy to miss over everything else the game puts on screen, and
    -- a hire that never happened for this reason looked identical in the log to one that
    -- happened and simply produced no NPC. Logged so "troops don't spawn" is diagnosable
    -- from kcd.log alone rather than guessed at.
    if _G.MercCount + amount > self.MaxCompanions then
        System.LogAlways(string.format('[Mercenaries] Hire: rejected - too many (count=%d + %d > max=%d)',
            _G.MercCount, amount, self.MaxCompanions))
        Game.SendInfoText('merc_info_too_many', false, 0, 3)
        return
    end

    if p:GetMoney() < cost then
        System.LogAlways(string.format('[Mercenaries] Hire: rejected - not enough money (have %d, need %d)',
            p:GetMoney(), cost))
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

    -- Hired at an innkeeper's, the men muster outside rather than in his taproom -
    -- HireSpawnAnchor decides that, and hiring in the open is untouched. `spawned`
    -- is counted for real: every earlier version paid the fee, sent the "hired"
    -- text and bumped the count whether or not a single NPC actually appeared.
    local outside = nil
    local spawned = 0

    local ok, err = pcall(function()
        local a = self:HireSpawnAnchor()
        if not (a and a.pos and a.rot) then
            System.LogAlways('[Mercenaries] Hire: no usable spawn position - nobody placed')
            return
        end
        local spawnPos, playerRot = a.pos, a.rot
        outside = a.outside

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
            
            local raw = {
                x = spawnPos.x + (math.random() - 0.5) * 1.5,
                y = spawnPos.y + (math.random() - 0.5) * 1.5,
                z = spawnPos.z
            }
            -- a.snap = false means an enclosed interior: every ground probe here
            -- fires from above and would find the roof, so the anchor's own height
            -- is used verbatim. See HireSpawnAnchor.
            local offsetPos = a.snap and self:FindValidGround(raw, spawnPos.z) or raw

            local safeRot = {x = 0, y = 0, z = playerRot.z}
            local entityName = "SpawnedFriend_" .. tier .. "_" .. tostring(math.random(10000, 99999)) .. "_" .. soulGuid

            -- Spawn the entity
            System.SpawnEntity({
                class = "NPC", 
                name = entityName, 
                position = offsetPos, 
                orientation = safeRot, 
                properties = mercenaries:RosterSpawnProps(soulGuid)
            })
            
            local ent = System.GetEntityByName(entityName)

            if ent then
                -- REGISTER FIRST, then dress him. The equip calls pick randomly out of
                -- preset tables and throw on an empty one; with registration after them
                -- a throw left a live NPC standing in the world that nothing tracked -
                -- not in ActiveMercs, so invisible to Recount, dismiss and every squad
                -- command - while still being counted as hired and therefore not
                -- refunded. Registration is also what MonitorLoop uses instead of a
                -- world scan, so it wants to happen as early as possible either way.
                self.ActiveMercs[entityName] = ent
                spawned = spawned + 1

                -- Its own pcall: one man's bad gear must not abort the rest of the batch.
                local dressed, derr = pcall(function()
                    mercenaries:EnsureMercIsAlwaysRendered(ent)
                    self:EquipMercenary(ent, currentPreset)
                    self:EquipMercenaryWeapon(ent, currentWeaponPreset, currentPreset)
                    self:InjectInteraction(ent)
                    -- Hired while the company is waiting out a main-quest battle: he joins
                    -- them rather than standing in the battle (mercenaries_mainquest_watchdog.lua).
                    if self.MQWOnHire then self:MQWOnHire(ent) end
                    -- With a camp up, say which half of the squad he joined - nothing else
                    -- does, and the default left him neither camping nor following.
                    self:CampOnMercJoined(ent)
                end)
                if not dressed then
                    System.LogAlways('[Mercenaries] Hire: post-spawn setup failed for ' ..
                                     entityName .. ': ' .. tostring(derr))
                end

            else
                System.LogAlways('[Mercenaries] Hire: SpawnEntity produced nothing for ' .. entityName)
            end

        end

    end)

    if not ok then System.LogAlways('[Mercenaries] Teleport Error: ' .. tostring(err)) end

    -- Nobody pays for a man who never arrived, and the count goes back to what is
    -- actually standing there rather than what was asked for.
    if spawned < amount then
        self:Recount()
        local refund = math.floor((cost or 0) * (amount - spawned) / math.max(amount, 1))
        if refund > 0 then self:GiveMoney(refund) end
    end

    if spawned <= 0 then
        Game.SendInfoText('merc_info_hire_failed', false, 0, 4)
        return
    end

    if spawned == 1 then
        Game.SendInfoText('merc_info_hired_single', false, 0, 3)
    else
        Game.SendInfoText('merc_info_hired_multiple', false, 0, 3)
    end

    -- They are out of sight, so say so - otherwise a hire indoors reads as nothing
    -- having happened at all.
    if outside then Game.SendInfoText('merc_info_hired_outside', false, 0, 5) end

    -- A hire is one more moment where a batch of men must all pick up follow at once,
    -- and it rebuilds the formation (grow), which drops every follower's slot at the
    -- same time. Same bounded window the dismount, order-release, battle-over and
    -- loot-sweep cases use: anyone who demonstrably fails to start walking is re-fired.
    pcall(function() mercenaries:BeginFollowVerify("hire") end)
end


-- One merc, at an exact spot, free and off the books except for ActiveMercs. Hire owns
-- the money, the cap and the muster point; this is for callers that already decided
-- where a man stands - the battle stager in mercenaries_commands.lua.
function mercenaries:SpawnMercAt(tier, pos, yaw, outfit, weapon)
    if not pos then return nil end
    local soulList = self.Souls[tier] or self.Souls["weak"]
    if not soulList then return nil end
    outfit = outfit or _G.MercCurrentOutfit or 1
    weapon = weapon or _G.MercCurrentWeapon or 1

    local ent
    local ok, err = pcall(function()
        local idx = self.SoulIndex[tier] or 1
        local soulGuid = soulList[idx]
        self.SoulIndex[tier] = (idx % #soulList) + 1

        local name = "SpawnedFriend_" .. tier .. "_" .. tostring(math.random(10000, 99999)) .. "_" .. soulGuid
        System.SpawnEntity({
            class = "NPC", name = name, position = pos,
            orientation = { x = 0, y = 0, z = yaw or 0 },
            properties = mercenaries:RosterSpawnProps(soulGuid),
        })
        ent = System.GetEntityByName(name)
        if not ent then return end
        -- Registered before dressing, for the reason given in Hire.
        self.ActiveMercs[name] = ent
        pcall(function()
            self:EnsureMercIsAlwaysRendered(ent)
            self:EquipMercenary(ent, outfit)
            self:EquipMercenaryWeapon(ent, weapon, outfit)
            self:InjectInteraction(ent)
            self:CampOnMercJoined(ent)
        end)
    end)
    if not ok then System.LogAlways('[Mercenaries] SpawnMercAt error: ' .. tostring(err)) end
    return ent
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
        System.LogAlways(string.format(
            '[Mercenaries] HireCustomCompanion: rejected - too many (count=%d + %d > max=%d)',
            _G.MercCount, amount, self.MaxCompanions))
        Game.SendInfoText('merc_info_too_many', false, 0, 3)
        return
    end

    if p:GetMoney() < cost then
        System.LogAlways(string.format(
            '[Mercenaries] HireCustomCompanion: rejected - not enough money (have %d, need %d)',
            p:GetMoney(), cost))
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

    -- Same indoor rule as Hire above: hired in a tavern, he waits outside it.
    local outside = nil
    local spawned = 0

    local ok, err = pcall(function()
        local a = self:HireSpawnAnchor()
        if not (a and a.pos and a.rot) then
            System.LogAlways('[Mercenaries] HireCustomCompanion: no usable spawn position')
            return
        end
        local spawnPos, playerRot = a.pos, a.rot
        outside = a.outside

        local raw = {
            x = spawnPos.x + (math.random() - 0.5) * 1.5,
            y = spawnPos.y + (math.random() - 0.5) * 1.5,
            z = spawnPos.z
        }
        local offsetPos = a.snap and self:FindValidGround(raw, spawnPos.z) or raw

        local safeRot = {x = 0, y = 0, z = playerRot.z}
        -- SpawnedFriend_, like the archers: the prefix is what every squad system keys
        -- on, so a companion gets the camp, the look-at prompts, formations, orders and
        -- the LOD boost for free instead of each of those needing its own special case.
        -- `_hero_` marks the exceptions - own gear, no talking. See IsHeroName.
        local entityName = "SpawnedFriend_hero_" .. soulGuid .. "_" .. tostring(math.random(10000, 99999))

        System.SpawnEntity({
            class = "NPC", 
            name = entityName, 
            position = offsetPos, 
            orientation = safeRot, 
            properties = {guidSharedSoulId = soulGuid}
        })

        local ent = System.GetEntityByName(entityName)
        if ent then
            -- Register before anything can throw - see the note in Hire above.
            self.ActiveMercs[entityName] = ent
            spawned = 1
            local dressed, derr = pcall(function()
                mercenaries:EnsureMercIsAlwaysRendered(ent)
                self:InjectInteraction(ent)
                self:CampOnMercJoined(ent)
            end)
            -- And again a moment later. A regular hire runs two equip calls between
            -- SpawnEntity and InjectInteraction, which touch ent.actor and
            -- ent.inventory and so force the script table live before GetActions is
            -- assigned to it; a companion is equipped by his soul and gets nothing in
            -- between, so the override can land on a table the engine has not finished
            -- with. Re-injecting is idempotent - it reassigns the same closures - so
            -- this costs a timer and settles the race either way.
            Script.SetTimerForFunction(1000, "mercenaries.CCReinject", ent.id)
            if not dressed then
                System.LogAlways('[Mercenaries] HireCustomCompanion: post-spawn setup failed for ' ..
                                 entityName .. ': ' .. tostring(derr))
            end
        else
            System.LogAlways('[Mercenaries] HireCustomCompanion: SpawnEntity produced nothing for ' .. entityName)
        end
    end)

    if not ok then System.LogAlways('[Mercenaries] Teleport Error: ' .. tostring(err)) end

    if spawned <= 0 then
        self:Recount()
        if (cost or 0) > 0 then self:GiveMoney(cost) end
        Game.SendInfoText('merc_info_hire_failed', false, 0, 4)
        return
    end

    Game.SendInfoText('merc_info_hired_special', false, 0, 3)
    if outside then Game.SendInfoText('merc_info_hired_outside', false, 0, 5) end

    -- A hire is one more moment where a batch of men must all pick up follow at once,
    -- and it rebuilds the formation (grow), which drops every follower's slot at the
    -- same time. Same bounded window the dismount, order-release, battle-over and
    -- loot-sweep cases use: anyone who demonstrably fails to start walking is re-fired.
    pcall(function() mercenaries:BeginFollowVerify("hire") end)
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
-- 7 is the custom uniform and has no preset pool of its own; EquipMercenary
-- falls back to style 1 for it, so it is mapped like style 1 here.
mercenaries.EnemyOutfitOverride = {
    [1] = 5, [2] = 5, [3] = 1, [4] = 2, [5] = 2, [6] = 2,
    [7] = 5, [8] = 2, [9] = 4,
    -- The house liveries all field against a plainly different-looking line.
    [10] = 2, [11] = 3, [12] = 2, [13] = 3, [14] = 2, [15] = 3, [16] = 2, [17] = 3
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
        -- WeaponSets categories this group may draw. 2/3/5 bundle a shield;
        -- a list without them can never produce one.
        weapons = { 6, 7, 8 },
        -- Empty on purpose: looters carry no shield. Their weapons list holds no
        -- shield-bearing category either, so this is belt and braces.
        shields = {},
        -- Nothing but the clothes they were caught in: tunic, hose, shoes, maybe a
        -- cap or a hood. No helmet, no mail, no padding, no shield (see weapons).
        clothing = {
            "6d657263-e001-4c00-9000-000000000001", "6d657263-e001-4c00-9000-000000000002", "6d657263-e001-4c00-9000-000000000003",
            "6d657263-e001-4c00-9000-000000000004", "6d657263-e001-4c00-9000-000000000005", "6d657263-e001-4c00-9000-000000000006",
            "6d657263-e001-4c00-9000-000000000007", "6d657263-e001-4c00-9000-000000000008", "6d657263-e001-4c00-9000-000000000009",
            "6d657263-e001-4c00-9000-00000000000a", "6d657263-e001-4c00-9000-00000000000b", "6d657263-e001-4c00-9000-00000000000c",
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
    -- The levy. Bodies, not soldiers: villagers handed a weapon and pointed at a wall, in the
    -- clothes they were standing in. They exist so a siege still feels like a siege when the
    -- player turns up with four men - see RaborschRecruitCount, which fields most of them for a
    -- thin company and none at all for a full one.
    --
    -- Souls are the LOOTER group's weakest, reused as they are: they are already on
    -- enemiesFaction, already have appearance rules, already have their faction relations. Only
    -- the wardrobe changes, from bandit leathers to plain village wear.
    recruit = {
        label = "Recruits",
        -- Plain village shields (Pisek), no heraldry - fits the plain village wear.
        shields = {
            "10f9a49f-07d0-4873-88d0-54d2cd5567f1", "3d4d4f2f-b6bd-4018-b0cf-1b3b1a4a4f93", "cb7cbe56-00e7-4f92-b19f-4479849fca71",
        },
        clothing = {
            "ecf4eea7-ffe5-4a98-a351-8947eeabe5bd", "24e4aa5b-cd2c-4dba-9426-b63e674b7037", "c522ba8f-18ff-4274-8acb-d7d0f50d0365",
            "cbc20d2b-3fff-4147-a650-92a8dcaf9875", "fd456ed6-f39e-4dad-8c53-e818c9789562", "b8c4e76c-1282-4103-a0dd-aa04dc2486b8",
            "70b2e01e-016c-4939-b557-6e3a07ba6e99", "579e95df-0471-4b6a-8ab8-be355fe619f6", "eed86bb2-3a7b-463a-becc-1f0496fef0d8",
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
        archers = {},
    },
    bandit = {
        label = "Bandits",
        -- WeaponSets categories this group may draw. 2/3/5 bundle a shield;
        -- a list without them can never produce one.
        weapons = { 3, 6, 7, 8, 7, 8 },
        -- The vanilla Trosecko bandit-camp shield, plus a couple of scavenged
        -- painted patterns for variety.
        shields = {
            "707470d0-9ce2-41ff-9836-1911f8420448", "2a668746-916a-41db-b079-29c7aa4a9845", "fd0449fd-931f-4ede-a752-f419617297af",
        },
        -- Looted mail over a gambeson with scrap plate on the limbs and an open
        -- helmet - never a cuirass or a brigandine, which a bandit has no way to
        -- come by. Quality 1 and a low Condition on every preset is what makes
        -- the kit read as rusty and pitted.
        clothing = {
            "6d657263-e002-4c00-9000-000000000001", "6d657263-e002-4c00-9000-000000000002", "6d657263-e002-4c00-9000-000000000003",
            "6d657263-e002-4c00-9000-000000000004", "6d657263-e002-4c00-9000-000000000005", "6d657263-e002-4c00-9000-000000000006",
            "6d657263-e002-4c00-9000-000000000007", "6d657263-e002-4c00-9000-000000000008", "6d657263-e002-4c00-9000-000000000009",
            "6d657263-e002-4c00-9000-00000000000a", "6d657263-e002-4c00-9000-00000000000b", "6d657263-e002-4c00-9000-00000000000c",
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
        -- WeaponSets categories this group may draw. 2/3/5 bundle a shield;
        -- a list without them can never produce one.
        weapons = { 2, 3, 4, 5, 7, 8 },
        -- Sigismund's own livery (Shield_Kite_Sigismund_* / Shield_Heater_Sigismund_*).
        shields = {
            "50341116-226b-410f-abcb-4f2a52b0efe9", "94b119d6-2e57-4d63-ad93-56e669ea0294",
            "4a13b6f7-1b8d-4b60-ab66-cacbed951120", "c0b01938-8a36-4418-9a59-97073adf3dc3",
        },
        -- Sigismund was King of Hungary, so his men fly the Magyar/Uher heraldry -
        -- the only Sigismund-army livery the game ships. Good kit, but open
        -- helmets throughout: kettle hats, skull caps and open bascinets.
        clothing = {
            "6d657263-e003-4c00-9000-000000000001", "6d657263-e003-4c00-9000-000000000002", "6d657263-e003-4c00-9000-000000000003",
            "6d657263-e003-4c00-9000-000000000004", "6d657263-e003-4c00-9000-000000000005", "6d657263-e003-4c00-9000-000000000006",
            "6d657263-e003-4c00-9000-000000000007", "6d657263-e003-4c00-9000-000000000008", "6d657263-e003-4c00-9000-000000000009",
            "6d657263-e003-4c00-9000-00000000000a", "6d657263-e003-4c00-9000-00000000000b", "6d657263-e003-4c00-9000-00000000000c",
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
        -- WeaponSets categories this group may draw. 2/3/5 bundle a shield;
        -- a list without them can never produce one.
        weapons = { 2, 3, 4, 5, 7, 8 },
        -- Prague's own livery (Shield_Kite_Prague_* / Shield_Heater_Prague_*).
        shields = {
            "e784827b-ea4a-43d3-afa4-91c1bb6b40df", "fd65fbb0-115b-4b63-a410-c235a69860a1",
            "3f8a55d6-5b3a-4b58-b88b-007560f6dc02", "1ef6f97a-4fed-4d18-883f-fabe1aa58a8b",
        },
        -- Prague livery on every man (4 surcoats, a coat, 2 hoods, 2 coifs), same
        -- standard of kit as the Hungarians and the same open helmets.
        clothing = {
            "6d657263-e004-4c00-9000-000000000001", "6d657263-e004-4c00-9000-000000000002", "6d657263-e004-4c00-9000-000000000003",
            "6d657263-e004-4c00-9000-000000000004", "6d657263-e004-4c00-9000-000000000005", "6d657263-e004-4c00-9000-000000000006",
            "6d657263-e004-4c00-9000-000000000007", "6d657263-e004-4c00-9000-000000000008", "6d657263-e004-4c00-9000-000000000009",
            "6d657263-e004-4c00-9000-00000000000a", "6d657263-e004-4c00-9000-00000000000b", "6d657263-e004-4c00-9000-00000000000c",
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
    -- Aleksej's own Ruthenians, the last fight of the arc. Nine years in Bohemia and paid out of
    -- a Hungarian archbishop's silver, so they are neither one thing nor the other: the cuman
    -- wardrobe mixed man to man with plate.
    --
    -- NO WAFFENROCKS. The obvious plate pool - EnemyGroups.knight - is Sigismund's livery and
    -- every one of its presets carries a Waffenrock item, which is precisely what these men must
    -- not be wearing. These six are armoured, male and heraldry-free (checked item by item
    -- against clothing_preset.xml).
    --
    -- Axes and shields, always: weapons is the WeaponSets index list and 3 is axe+shield
    -- (mercenaries_equipment.lua, ShieldWeaponTypes).
    --
    -- Their own souls, purely so they are called Ruthenians rather than Cumans -
    -- char_enemy_cuman_* is shared with a Kleinkrieg contract and renaming it would rename them.
    ruthenian = {
        label = "Ruthenians",
        weapons = { 3 },
        -- The dedicated Cuman shield family, not a Sigismund/Prague livery one - the
        -- comment above says these six are heraldry-free, checked item by item, and
        -- a faction-liveried kite shield would undo exactly that.
        shields = {
            "00f104b3-e95c-41ee-95a9-35d0331ac295", "10badb5a-8249-4649-9c3e-374b5f8224ff",
            "2cb53d10-c5da-47ef-8789-8e1ae34dac6c", "94111648-b45b-4a1c-b189-8dd628deaa56",
        },
        clothing = {
            "08d7d086-327a-4f95-92d3-6a6c60a494f0", "1291b696-d704-4fb0-90da-2bdf4c2eefef", "4163bbb6-a7bf-47a3-b5c7-bffdbe0c2062",
            "838f07ef-5875-4391-9fe2-5fd93ffa6501", "e1f7bfd8-f211-4693-9004-0fc36f166e1f", "fca2a301-45e5-4cd9-af18-09469bbd8102",
            "70618c60-9f1e-4949-a1d2-06b1a9709e82", "9b9f92a0-7040-4f3e-85ee-1f2651ee6672", "8d8951b3-af89-4c0a-a7d6-99c8f6f7fe86",
            "bd87c9e4-5481-4a98-8279-ec010e4c10ad", "978b6b0c-288b-4d0b-8cfa-f2fe1a801409", "efff8f2e-a199-4883-8bb8-3219c4103e22",
            "fdb7279e-f270-4983-a056-d202e5ebf210", "fb01d6a3-b3c2-4e38-9b56-3b08fb51856a", "f71d7aa7-fb43-4def-a837-7841fc5bb6cf",
            "f0039e7c-1e96-45f7-8cc7-619332a8a782", "ef83067c-303f-4fc1-800a-d8e1fa524c7a", "fa74a7d7-a4ed-4fc0-be05-6f7c84d6c6c8",
        },
        melee = {
            { guid = "a1e50100-1c4b-4e6a-9f01-3b8c5d2e7f01", tier = "weak" },
            { guid = "a1e50100-1c4b-4e6a-9f01-3b8c5d2e7f02", tier = "medium" },
            { guid = "a1e50100-1c4b-4e6a-9f01-3b8c5d2e7f03", tier = "strong" },
        },
        archers = {
            { guid = "a1e50100-1c4b-4e6a-9f01-3b8c5d2e7f04", tier = "medium" },
        },
    },
    cuman = {
        label = "Cumans",
        -- WeaponSets categories this group may draw. 2/3/5 bundle a shield;
        -- a list without them can never produce one.
        weapons = { 3, 6, 7, 8, 2, 8 },
        -- Vanilla ships a dedicated Cuman shield family (Shield_Cuman_*, item.xml
        -- Class=8 SubClass=9) - use it rather than any of the kite/pavise/heater
        -- ones the other factions draw from.
        shields = {
            "000a72ec-f904-4e06-8c57-2eac8ab6ec73", "1c22229e-9703-4e23-a552-9d13f74ada02",
            "30b6df49-7789-4c22-b645-e5e087df8ffd", "f13c6be9-09ab-492d-82f5-628170cc1dc2",
        },
        -- Cuman kit throughout - caftan instead of a gambeson, loose hose, knee
        -- boots, open bascinets, no heraldry. Budget sits between the bandits and
        -- the regular soldiers, and the ramp is deliberately wide so a line of
        -- them is a mix rather than a uniform.
        clothing = {
            "6d657263-e005-4c00-9000-000000000001", "6d657263-e005-4c00-9000-000000000002", "6d657263-e005-4c00-9000-000000000003",
            "6d657263-e005-4c00-9000-000000000004", "6d657263-e005-4c00-9000-000000000005", "6d657263-e005-4c00-9000-000000000006",
            "6d657263-e005-4c00-9000-000000000007", "6d657263-e005-4c00-9000-000000000008", "6d657263-e005-4c00-9000-000000000009",
            "6d657263-e005-4c00-9000-00000000000a", "6d657263-e005-4c00-9000-00000000000b", "6d657263-e005-4c00-9000-00000000000c",
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
        -- Kuttenberg (their surcoat, per the clothing comment below) and Bergov
        -- (a noble seat) - a heraldic step up from the rank-and-file Sigismund
        -- livery on the plain "sigi" soldiers. Only applies when the weapons roll
        -- below actually lands on a shield type (2 sword+shield / 5 mace+shield) -
        -- weapons {4, 7} are longsword/bare mace and stay unshielded.
        shields = {
            "23d3d037-6eb4-46dd-b294-10b0951b85f8", "a18df8ed-8a4a-47fa-a9fc-bbf8a7f72d68",
            "1da8f314-6441-4afc-9a4a-f516067e9613", "c37d067f-7342-4952-a8ce-2e2d78832d7f",
        },
        -- Best armour in the mod: closed-visor bascinets, steel cuirass or heavy
        -- brigandine over mail, full limb harness. Twelve different noble houses,
        -- one per preset, so a line of them reads as a coalition not a regiment.
        clothing = {
            "6d657263-e006-4c00-9000-000000000001", "6d657263-e006-4c00-9000-000000000002", "6d657263-e006-4c00-9000-000000000003",
            "6d657263-e006-4c00-9000-000000000004", "6d657263-e006-4c00-9000-000000000005", "6d657263-e006-4c00-9000-000000000006",
            "6d657263-e006-4c00-9000-000000000007", "6d657263-e006-4c00-9000-000000000008", "6d657263-e006-4c00-9000-000000000009",
            "6d657263-e006-4c00-9000-00000000000a", "6d657263-e006-4c00-9000-00000000000b", "6d657263-e006-4c00-9000-00000000000c",
        },
        -- WeaponSets categories this group may draw. 2/3/5 bundle a shield;
        -- a list without them can never produce one.
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

    -- The town watch. Turned out by mercenaries_townwatch.lua when the company starts
    -- murdering people in a settlement - never spawned by an encounter or a raid.
    --
    -- Kuttenberg livery on every man (Waffenrock02/09_mKuttenberg, one Coat04), kettle
    -- hats throughout - the town-watch helm - over a mail coif, short mail and a
    -- gambeson. The senior half add brigandine arms. Budget ~1050-1250, deliberately
    -- between the bandits and Sigismund's soldiers: a municipal watch, not an army.
    --
    -- No archers. A town watch that opens fire into a crowded street is neither what
    -- they did nor something the spawn points could place safely.
    townguard = {
        label = "Town watch",
        -- Sword, axe and mace, all with shields (2/3/5) plus bare mace and axe. Kite
        -- shields in Kuttenberg's own livery.
        weapons = { 2, 2, 3, 5, 7, 8 },
        shields = {
            "a18df8ed-8a4a-47fa-a9fc-bbf8a7f72d68",  -- shieldKite_kuttenberg_A
            "23d3d037-6eb4-46dd-b294-10b0951b85f8",  -- shieldKite_kuttenberg_B
        },
        clothing = {
            "6d657263-e00a-4c00-9000-000000000001", "6d657263-e00a-4c00-9000-000000000002",
            "6d657263-e00a-4c00-9000-000000000003", "6d657263-e00a-4c00-9000-000000000004",
            "6d657263-e00a-4c00-9000-000000000005", "6d657263-e00a-4c00-9000-000000000006",
            "6d657263-e00a-4c00-9000-000000000007", "6d657263-e00a-4c00-9000-000000000008",
            "6d657263-e00a-4c00-9000-000000000009", "6d657263-e00a-4c00-9000-00000000000a",
        },
        melee = {
            { guid = "7c9a1e50-0b21-5a01-9e10-4d1f0a7b0001", tier = "medium" },
            { guid = "7c9a1e50-0b21-5a01-9e10-4d1f0a7b0002", tier = "medium" },
            { guid = "7c9a1e50-0b21-5a01-9e10-4d1f0a7b0003", tier = "medium" },
            { guid = "7c9a1e50-0b21-5a01-9e10-4d1f0a7b0004", tier = "medium" },
            { guid = "7c9a1e50-0b21-5a01-9e10-4d1f0a7b0005", tier = "medium" },
            { guid = "7c9a1e50-0b21-5a01-9e10-4d1f0a7b0006", tier = "strong" },
            { guid = "7c9a1e50-0b21-5a01-9e10-4d1f0a7b0007", tier = "strong" },
            { guid = "7c9a1e50-0b21-5a01-9e10-4d1f0a7b0008", tier = "strong" },
            { guid = "7c9a1e50-0b21-5a01-9e10-4d1f0a7b0009", tier = "strong" },
            { guid = "7c9a1e50-0b21-5a01-9e10-4d1f0a7b000a", tier = "strong" },
        },
        archers = {},
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

-- The RAW wuid behind each EnemyTargetOf key. The key is a string and cannot be
-- handed back to GetEntityByWUID, so without this there is no way to ask "is the
-- claimer still alive" - and a dead claimer's entry inflated EnemyTargetLoad
-- forever, until EnemySwarmCap silently stopped binding. See PruneCombatClaims.
mercenaries.EnemyClaimWuid = {}  -- [enemyWuidStr] = raw wuid of the claimer

-- Dress a freshly spawned enemy: clothing from the group's pool, weapon via the
-- shared merc weapon path (which parses the tier out of the entity name, and
-- routes "_archer_" names to the bow set automatically).
-- Weapon categories to draw from when a group names none of its own. Explicit
-- categories only - 1 ("random") is what produced the empty weapon sets in the
-- first place, so it is never used here.
mercenaries.EnemyWeaponFallbacks = { 2, 4, 7, 8 }

-- Do not add a "skip the clothing" option here. A runtime-spawned NPC that has never had a
-- clothing preset applied accepts inventory:CreateItem and then quietly refuses
-- actor:EquipInventoryItem, so a leader who is hand-dressed afterwards has to come through this
-- preset first or he ends up carrying his harness instead of wearing it. See AlxSpawnLeaderNPC.
function mercenaries:EquipEnemy(ent, groupKey, isArcher)
    if not ent or not ent.actor then return end
    local grp = self.EnemyGroups[groupKey]
    if not grp then return end
    -- The difficulty tier gets first refusal on the wardrobe; it returns nil on
    -- the mixed tiers, which leaves the original uniform draw untouched.
    local clothing = self:DiffPickClothing(groupKey)
                     or grp.clothing[math.random(1, #grp.clothing)]
    if clothing then pcall(function() ent.actor:EquipClothingPreset(clothing) end) end
    -- Weapon. A group can pin one exact preset (grp.weaponPreset, e.g. Heinrich's
    -- St. George's sword), or restrict to a preferred set of WeaponSets categories
    -- (grp.weapons, e.g. knights favour swords/maces); otherwise 1 = random melee
    -- category. Archers ignore all of this and get the bow (EquipMercenaryWeapon
    -- routes "_archer_" names to the bow set).
    if grp.weaponPreset and not isArcher then
        pcall(function() ent.actor:EquipWeaponPreset(grp.weaponPreset) end)
    else
        -- Every draw comes from the group's OWN allowed categories. That is what
        -- keeps a shield off a group that must not have one: 2/3/5 bundle a
        -- shield, so a list without them cannot produce one however it rolls.
        local allowed = self.EnemyWeaponFallbacks
        if grp.weapons and #grp.weapons > 0 and not isArcher then
            allowed = grp.weapons
        end
        local resolvedType = self:EquipMercenaryWeapon(
            ent, allowed[math.random(1, #allowed)], nil)

        -- BACKSTOP for the empty weapon set the log reports:
        --   [DrawAction]: Can't execute explicit DrawAction for selected weapon set which
        --   contains no weapons!
        -- EquipMercenaryWeapon picks a weapon CATEGORY and lets the engine fill it; when the
        -- category yields nothing for this character the set comes out empty, combat_melee
        -- dies at the draw, and he stands in the open being hit. That was ~23 of 75 besiegers.
        --
        -- A SECOND draw from the same allowed list, not a hardcoded category. The
        -- old code re-equipped everyone with category 2 (sword+shield) here, and
        -- since the last call wins that silently overrode grp.weapons for every
        -- group - knights included - and handed a shield to anyone who spawned.
        -- grp.melee is NOT usable here: despite the name it holds character SOUL
        -- guids (see the spawn below), and feeding one to EquipWeaponPreset leaves
        -- the man with nothing at all.
        if not isArcher then
            local backstop = allowed[math.random(1, #allowed)]
            local ok, again = pcall(function()
                return self:EquipMercenaryWeapon(ent, backstop, nil)
            end)
            if ok and again then resolvedType = again end

            -- Shield to match the FACTION, not the player's own squad. Without this,
            -- the shield preset above (merc gear, shared with the player's mercs)
            -- reads outfitPreset=nil and falls back to _G.MercCurrentOutfit - the
            -- squad's own current outfit choice, which has nothing to do with this
            -- enemy at all. That is the literal cause of "enemy shields... are the
            -- same as the mercs". Only fires when the draw that actually stuck
            -- produced a shield-bearing category, so a longsword- or bare-mace-armed
            -- man is left alone.
            if self.ShieldWeaponTypes[resolvedType] and #(grp.shields or {}) > 0 then
                pcall(function() self:EquipEnemyShield(ent, grp) end)
            end
        end
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

-- Put the group's own shield on an already-armed enemy, replacing whatever his
-- weapon preset bundled by default. `grp.shields` is a pool of vanilla shield
-- item_class_ids (data/libs/tables/item/item.xml, Class=8) picked to read as that
-- faction: Shield_Kite_Prague_* for the Prague regiment, Shield_Kite_Sigismund_* /
-- Shield_Heater_Sigismund_* for Sigismund's soldiers and knights, the dedicated
-- Shield_Cuman_* family for Cumans (and reused for the ruthenian group, which is
-- explicitly written elsewhere in this file to be heraldry-free - a faction-liveried
-- Sigismund/Prague shield would contradict that), Shield_Pavise_Tlama for bandits
-- (the vanilla Trosecko bandit-camp shield), and unbranded painted/heraldic
-- patterns for looters and recruits, who belong to no organised force.
--
-- Reuses AlxWear (mercenaries_aleksej.lua): CreateItem into the inventory, find
-- the instance id, EquipInventoryItem on that - the pattern proven to work on a
-- runtime-spawned NPC. Safe to call unconditionally; a group with no `shields`
-- pool (heinrich) just no-ops.
function mercenaries:EquipEnemyShield(ent, grp)
    if not (ent and grp and grp.shields and #grp.shields > 0) then return end
    local shieldClass = grp.shields[math.random(1, #grp.shields)]
    self:AlxWear(ent, shieldClass, "enemy shield (" .. tostring(grp.label) .. ")")
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

    -- A burst this size is about to blow the stock AI-LOD budgets; arm the boost BEFORE the
    -- men exist rather than after CachedEnemies notices them. The bench measured the gap:
    -- 64 hidden-flips during a battle, clustered at its start. See LodBoostPrime.
    if self.LodBoostPrime then pcall(function() self:LodBoostPrime(amount + (_G.MercCount or 0)) end) end

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

-- (LodBoostPrime is called from SpawnEnemyGroup below - see mercenaries_lodboost.lua.)

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
-- Kept for compatibility; no longer gates target holding (see FindEnemyTarget).
mercenaries.EnemyTargetStickRange = 5.0

-- How far an enemy will follow the target he has already committed to before giving
-- up on him and re-acquiring. Deliberately as large as the acquisition radius: a
-- fighter that re-picks mid-approach makes his scheduler re-fire, and a re-fire
-- restarts the approach. See the comment in FindEnemyTarget and docs/foe-ai.md.
mercenaries.EnemyTargetHoldRange = 60.0

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
    -- Never a static archer. He is up a tower or on a wagon bed, so a footman walks to the
    -- foot of it and stands there for the rest of the battle. This mirrors the rule already
    -- applied to the mercs' own targeting (TryClaimTarget) - the same problem, both ways round.
    if self:IsStaticArcherName(n) then return false end
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

        -- A bandit camp that has not noticed anything yet takes no targets at all, which is
        -- what lets the player scout or sneak past it. Cleared the moment the camp is
        -- alerted (see BanditCampAlertTick in mercenaries_banditcamp_quest.lua).
        if self.SiegePeace and self:SiegeSuppressed(tostring(myWuid)) then return nil end
        if self.BanditCampSuppressed and self:BanditCampSuppressed(tostring(myWuid)) then
            data.currentTarget = nil
            self.EnemyTargetOf[tostring(myWuid)] = nil
            self.EnemyClaimWuid[tostring(myWuid)] = nil
            return
        end

        -- Encounter override: a forced target (ForcedTargetOf, set from outside)
        -- wins over scanning for as long as it stays alive.
        local forced = self.ForcedTargetOf and self.ForcedTargetOf[tostring(myWuid)]
        if forced then
            local fe = XGenAIModule.GetEntityByWUID(forced)
            if fe and self:IsAliveAndWell(fe, true) then
                data.currentTarget = forced
                self.EnemyTargetOf[tostring(myWuid)] = tostring(forced)
                self.EnemyClaimWuid[tostring(myWuid)] = myWuid
                return
            end
            self.ForcedTargetOf[tostring(myWuid)] = nil
        end

        if data.currentTarget then
            local curEnt = XGenAIModule.GetEntityByWUID(data.currentTarget)
            if curEnt and self:IsCombatViable(curEnt) then
                local cp = curEnt:GetPos()
                if cp then
                    local dx, dy, dz = cp.x - mp.x, cp.y - mp.y, cp.z - mp.z
                    local walled = self.NavTargetBlocked and self:NavTargetBlocked(me, curEnt)
                    -- Hold him for the whole approach, not just once he is close.
                    --
                    -- This used to keep the current target only inside EnemyTargetStickRange
                    -- (5m), so for every second of every approach it fell through and
                    -- re-picked the nearest man instead. In a crowded fight - the Kleinkrieg
                    -- convoy - the nearest man keeps changing, which changes currentTarget,
                    -- which trips the scheduler's `$currentTarget ~= $firedTarget` re-fire.
                    -- A re-fire REPLACES the running combat and runs its OnFail, so the
                    -- fighter restarts his approach roughly once a second: that is the
                    -- step-pause-step. Enemies now behave like foes (docs/foe-ai.md) - the
                    -- target is dropped only when he is dead, unreachable or walled off, and
                    -- the swarm cap applies at acquisition rather than shuffling anyone off
                    -- a man he is already fighting.
                    local holdSq = (self.EnemyTargetHoldRange or 60.0) ^ 2
                    if not walled and (dx*dx + dy*dy + dz*dz) <= holdSq then
                        return -- keep the live target we are already committed to
                    end
                    -- a wall went up between us (or he ran behind one): drop him
                    if walled then
                        data.currentTarget = nil
                        self.EnemyTargetOf[tostring(myWuid)] = nil
                        self.EnemyClaimWuid[tostring(myWuid)] = nil
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
                    if tostring(ent.this.id) ~= myWuidStr and self:IsEnemyTargetable(ent) and self:IsCombatViable(ent)
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
            self.EnemyClaimWuid[myWuidStr] = nil
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
        self.EnemyClaimWuid[myWuidStr] = myWuid
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
        pcall(function() self:CampOnMercJoined(ent) end)

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


-- Second pass over a freshly hired companion, a second after the hire. Re-registers
-- him (the name is the ActiveMercs key and it does not change) and re-injects the
-- look-at prompts. See the note at the timer that arms this.
function mercenaries.CCReinject(entId)
    local self = mercenaries
    local ent
    pcall(function() ent = System.GetEntity(entId) end)
    if not ent then return end
    local name = ent.GetName and ent:GetName() or nil
    if not name or not self:IsHeroName(name) then return end
    if not self:IsAliveAndWell(ent, true) then return end
    self.ActiveMercs[name] = ent
    pcall(function() self:EnsureMercIsAlwaysRendered(ent) end)
    pcall(function() self:InjectInteraction(ent) end)
    System.LogAlways("[Mercenaries] companion re-injected: " .. name)
end
