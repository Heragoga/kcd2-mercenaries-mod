-- =======================================================================
-- RANGED MERCENARIES (ARCHERS)
-- A separate combat group from the melee mercs: own souls (soul__archers.xml),
-- own brain (archer_brain -> data/AI/archer_scheduler.xml), own stance set.
--
-- Archers are spawned with entity names "SpawnedFriend_archer_<tier>_..."
-- ON PURPOSE: every existing squad system (ActiveMercs cache, pruning,
-- formation slots, distance teleport, healing, wait/follow/dismiss) matches
-- on 'SpawnedFriend', so archers ride along for free. Anything
-- archer-specific branches on the '_archer_' marker inside the name.
--
-- Archer stances (separate from the melee squad's stance):
--   skirmish - keep at shooting distance of the enemy and pelt them with
--              arrows; never enter melee unless an enemy is in their face
--              or the quiver runs dry (pure standFire, no repositioning).
--   guard    - stay glued to the player in combat and shoot from there.
--   melee    - close in and fight with the sidearm like a regular merc.
--   hold     - do not engage at all.
--
-- Who archers shoot at is governed by the SAME player-set stance
-- (_G.MercStance / GetStanceCode) that regular mercenaries use - see
-- archer_scheduler.xml, which calls PickNearestValidTarget/PickPlayersTarget/
-- EvaluateCombatTarget exactly like mercenary_scheduler.xml.
-- =======================================================================

-- Tokens (skald dialog -> lua). Count on the hire tokens = how many to hire.
mercenaries.TokenIDArcherWeak = "679a655e-189d-4519-b437-ccc4b92be59d"
mercenaries.TokenIDArcherMedium = "679a655e-189d-4519-b437-ccc4b92be60d"
mercenaries.TokenIDArcherStrong = "679a655e-189d-4519-b437-ccc4b92be61d"
-- Count = stance: 1 skirmish, 2 guard, 3 melee, 4 hold
mercenaries.TokenIDArcherStance = "679a655e-189d-4519-b437-ccc4b92be62d"
-- Count = ranged weapon type: 1 bow, 2 crossbow, 3 handcannon
mercenaries.TokenIDArcherWeaponType = "679a655e-189d-4519-b437-ccc4b92be63d"

mercenaries.ArcherStanceCode = { skirmish = 0, guard = 1, melee = 2, hold = 3 }
mercenaries.ArcherStanceByIndex = { [1] = "skirmish", [2] = "guard", [3] = "melee", [4] = "hold" }

mercenaries.ArcherWeaponTypeByIndex = { [1] = "bow", [2] = "crossbow", [3] = "handcannon" }

-- Archer souls, see data/libs/tables/rpg/soul__archers.xml
mercenaries.ArcherSouls = {
    weak = {
        "187fbe3b-8dea-4f81-a933-6416a2bb8eab",
        "a1794fdd-66bb-4908-a834-6900a453007d",
        "6b7f50e2-4cee-4627-a417-2d57491bc8df",
        "ca41e429-90f5-4893-b1d8-ca6c1d480652",
        "7f0016fb-e8ee-48f2-aa81-c6fb8fd8cede"
    },
    medium = {
        "1f7cbc4b-d665-4b2d-baf3-7cb129c2642e",
        "10870a67-df3f-4ce7-b34b-efe6470d892c",
        "3af05aa1-4613-4e48-85d6-7ad783c7938c",
        "b474ff9a-1e4a-4fcf-a2e9-d0df5cfbac53",
        "209eccf1-69e3-4f04-8384-b710dc6f2208"
    },
    strong = {
        "27b1b43c-8df5-4850-af56-8a3aada124ce",
        "81b39fbd-3c22-4d78-b16a-23539991309e",
        "3cdf2729-9a0a-4dd9-bbc7-5b2082159675",
        "2744267c-d252-4509-9288-a48d6e38bd40",
        "2813fb9d-a08b-494c-93ed-6b045d1e3024"
    }
}
mercenaries.ArcherSoulIndex = { weak = 1, medium = 1, strong = 1 }

-- Archer weapon sets, one table per ranged weapon type, each bundling the
-- ranged weapon + ammo (where applicable) + a shortsword sidearm - see
-- weapon_preset__mercenaries.xml (merc_weapon_archerset_*).
mercenaries.ArcherWeaponSets = {
    bow = {
        weak = {
            "fca40a2e-4d33-4675-8dc2-a918c0998198", "4838fefa-bd2f-433f-861a-6599e2182f5b"
        },
        medium = {
            "d6d73839-0334-4e24-adfe-3fa4b6cbdd2c", "fe692cff-7236-4cfd-af19-bc44e3d20f19"
        },
        strong = {
            "561167b1-0775-4066-8110-8c390e21ff95", "94c8ab63-cf02-471d-a6eb-7807623c8265"
        }
    },
    crossbow = {
        weak = {
            "1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d", "2b3c4d5e-6f7a-4b8c-9d0e-1f2a3b4c5d6e"
        },
        medium = {
            "3c4d5e6f-7a8b-4c9d-0e1f-2a3b4c5d6e7f", "4d5e6f7a-8b9c-4d0e-1f2a-3b4c5d6e7f8a"
        },
        strong = {
            "5e6f7a8b-9c0d-4e1f-2a3b-4c5d6e7f8a9b", "6f7a8b9c-0d1e-4f2a-3b4c-5d6e7f8a9b0c"
        }
    },
    handcannon = {
        weak = {
            "7a8b9c0d-1e2f-4a3b-4c5d-6e7f8a9b0c1d", "8b9c0d1e-2f3a-4b4c-5d6e-7f8a9b0c1d2e"
        },
        medium = {
            "9c0d1e2f-3a4b-4c5d-6e7f-8a9b0c1d2e3f"
        },
        strong = {
            "0d1e2f3a-4b5c-4d6e-7f8a-9b0c1d2e3f4a"
        }
    }
}

-- Vanilla ammo item classes (root item.xml), used to top ammo up on
-- spawn/re-equip and to detect "out of ammo" in the combat trees.
mercenaries.ArcherArrowClassByTier = {
    weak = "ad6f0f01-aec4-44d1-982c-1210eb01b74a",   -- arrow_normal
    medium = "710e3706-8974-404b-b23a-6f51670ef1ed", -- arrow_hunting
    strong = "802507e9-d620-47b5-ae66-08fcc314e26a"  -- arrow_enh_hunting
}
mercenaries.ArcherArrowClasses = {
    "ad6f0f01-aec4-44d1-982c-1210eb01b74a", -- arrow_normal
    "710e3706-8974-404b-b23a-6f51670ef1ed", -- arrow_hunting
    "802507e9-d620-47b5-ae66-08fcc314e26a", -- arrow_enh_hunting
    "a5b31bbc-1e11-4831-835b-c06d5b13a7da", -- arrow_enh_piercing
    "13ba7468-11a2-483d-8cb9-25ce36a2d228", -- arrow_enh_cutting
    "7db6b854-e307-4a47-ba39-943190b2469e"  -- arrow_enh_precise
}
mercenaries.ArcherBoltClassByTier = {
    weak = "8460003f-637f-4713-92c9-4954037c4b9c",   -- bolt_normal
    medium = "40337bef-e965-4a60-abee-695e9a784fa4", -- bolt_hunting
    strong = "b738d184-4ae1-4d74-8fac-b8db1943b1d4"  -- bolt_enh_hunting
}
mercenaries.ArcherBoltClasses = {
    "8460003f-637f-4713-92c9-4954037c4b9c", -- bolt_normal
    "40337bef-e965-4a60-abee-695e9a784fa4", -- bolt_hunting
    "b738d184-4ae1-4d74-8fac-b8db1943b1d4", -- bolt_enh_hunting
    "c82f1a8d-3617-42b7-98a9-36e96ff71294", -- bolt_enh_piercing
    "e6652736-4cb4-42e9-b012-050064405f37", -- bolt_enh_cutting
    "081fc4a1-25e9-4492-8dc8-2d9d6668c07a"  -- bolt_enh_precise
}
-- Hand cannons DO have a real vanilla ammo item (shot_ball) - there's no
-- tiered variant like arrows/bolts have, so every tier shares it.
mercenaries.ArcherShotClassByTier = {
    weak = "f10ded12-a41c-40bf-a8ae-883d4e845059",   -- shot_ball
    medium = "f10ded12-a41c-40bf-a8ae-883d4e845059", -- shot_ball
    strong = "f10ded12-a41c-40bf-a8ae-883d4e845059"  -- shot_ball
}
mercenaries.ArcherShotClasses = {
    "f10ded12-a41c-40bf-a8ae-883d4e845059", -- shot_ball
    "fb30c64e-2360-4ed7-b805-531b3424fe4d"  -- battle_shot
}

function mercenaries:IsArcherName(name)
    return name ~= nil and string.find(name, '_archer_', 1, true) ~= nil
end

function mercenaries:GetArcherTierFromName(name)
    name = name or ''
    if string.find(name, '_medium_') then return "medium" end
    if string.find(name, '_strong_') then return "strong" end
    return "weak"
end

function mercenaries:GetArcherStanceCode()
    return self.ArcherStanceCode[_G.ArcherStance or "skirmish"] or 0
end

function mercenaries:SetArcherStance(stance)
    if not self.ArcherStanceCode[stance] then stance = "skirmish" end
    _G.ArcherStance = stance
    self:SaveString("ArcherStancePersistent", stance)
    Game.SendInfoText('merc_info_archer_stance_' .. stance, false, 0, 3)
end

function mercenaries:GetArcherWeaponType()
    local wt = _G.ArcherWeaponType or "bow"
    if not self.ArcherWeaponSets[wt] then wt = "bow" end
    return wt
end

-- Called from OnGameplayStarted
function mercenaries:LoadArcherState()
    local savedStance = self:LoadString("ArcherStancePersistent")
    _G.ArcherStance = (savedStance and self.ArcherStanceCode[savedStance]) and savedStance or "skirmish"

    local savedWeaponType = self:LoadString("ArcherWeaponTypePersistent")
    _G.ArcherWeaponType = (savedWeaponType and self.ArcherWeaponSets[savedWeaponType]) and savedWeaponType or "bow"
end

-- =======================================================================
-- HIRE
-- =======================================================================
function mercenaries:HireArcher(cost, amount, tier)
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

        local soulList = self.ArcherSouls[tier] or self.ArcherSouls["weak"]
        local currentPreset = _G.MercCurrentOutfit or 1

        for i = 1, amount do
            local idx = self.ArcherSoulIndex[tier]
            local soulGuid = soulList[idx]

            self.ArcherSoulIndex[tier] = idx + 1
            if self.ArcherSoulIndex[tier] > #soulList then
                self.ArcherSoulIndex[tier] = 1
            end

            local offsetPos = {
                x = spawnPos.x + (math.random() - 0.5) * 1.5,
                y = spawnPos.y + (math.random() - 0.5) * 1.5,
                z = spawnPos.z
            }

            local safeRot = {x = 0, y = 0, z = playerRot.z}
            -- 'SpawnedFriend' keeps them inside every existing squad system,
            -- '_archer_' marks them for archer-specific handling.
            local entityName = "SpawnedFriend_archer_" .. tier .. "_" .. tostring(math.random(10000, 99999)) .. "_" .. soulGuid

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
                self:EquipArcherWeapon(ent)
                self.ActiveMercs[entityName] = ent
                self:InjectInteraction(ent)
            end
        end
    end)

    if not ok then System.LogAlways('[Archer] HireArcher error: ' .. tostring(err)) end

    if amount == 1 then
        Game.SendInfoText('merc_info_archer_hired_single', false, 0, 3)
    else
        Game.SendInfoText('merc_info_archer_hired_multiple', false, 0, 3)
    end
end

-- =======================================================================
-- EQUIPMENT
-- =======================================================================
function mercenaries:EquipArcherWeapon(ent)
    if not ent or not ent.actor then return end

    local name = ent:GetName() or ''
    local tier = self:GetArcherTierFromName(name)

    local weaponType = self:GetArcherWeaponType()
    local typeSets = self.ArcherWeaponSets[weaponType] or self.ArcherWeaponSets["bow"]
    local tierSets = typeSets[tier] or typeSets["weak"]
    local presetId = tierSets[math.random(1, #tierSets)]

    if presetId and presetId ~= "" then
        System.LogAlways('[Archer] Equipping archer weapon preset: ' .. presetId .. ' on ' .. name)
        ent.actor:EquipWeaponPreset(presetId)
    end

    self:GiveArcherAmmo(ent, tier, weaponType, 40)
end

-- Best-effort ammo top-up (arrows for bow, bolts for crossbow, shot_ball
-- for hand cannon). The storm inventory preset already ships 40 rounds;
-- this covers re-equips and long fights. Fails silently (logged) if the
-- item API is not available on this entity.
function mercenaries:GiveArcherAmmo(ent, tier, weaponType, amount)
    local ok, err = pcall(function()
        if not ent or not ent.inventory then return end

        local ammoClass
        if weaponType == "crossbow" then
            ammoClass = self.ArcherBoltClassByTier[tier] or self.ArcherBoltClassByTier["weak"]
        elseif weaponType == "handcannon" then
            ammoClass = self.ArcherShotClassByTier[tier] or self.ArcherShotClassByTier["weak"]
        else
            ammoClass = self.ArcherArrowClassByTier[tier] or self.ArcherArrowClassByTier["weak"]
        end

        local have = 0
        pcall(function() have = ent.inventory:GetCountOfClass(ammoClass) or 0 end)
        local need = (amount or 40) - have
        if need <= 0 then return end

        if ItemManager and ItemManager.CreateItem then
            local itemId = ItemManager.CreateItem(ammoClass, 1.0, need)
            if itemId then
                ent.inventory:AddItem(itemId)
                System.LogAlways('[Archer] Gave ' .. tostring(need) .. ' ammo to ' .. tostring(ent:GetName()))
            end
        end
    end)
    if not ok then System.LogAlways('[Archer] GiveArcherAmmo error: ' .. tostring(err)) end
end

-- QoL: called from LowPriorityMonitorLoop (every 5s). Archers that ran dry
-- during a fight refill their quiver once combat is over — same "top up to
-- 40" rule that hire/re-equip already applies, so an out-of-ammo archer
-- doesn't stay a swordsman for the rest of the session.
function mercenaries:ResupplyArchersOutOfCombat()
    local ok, err = pcall(function()
        local weaponType = self:GetArcherWeaponType()

        for name, ent in pairs(self.ActiveMercs) do
            if self:IsArcherName(name) and ent and ent.inventory then
                local inCombat = false
                pcall(function() inCombat = ent.soul:HasScriptContext("crime_interruptAttack") end)

                if not inCombat then
                    local tier = self:GetArcherTierFromName(name)
                    local classByTier = self.ArcherArrowClassByTier
                    if weaponType == "crossbow" then classByTier = self.ArcherBoltClassByTier
                    elseif weaponType == "handcannon" then classByTier = self.ArcherShotClassByTier end
                    local ammoClass = classByTier[tier]

                    local have = 0
                    pcall(function() have = ent.inventory:GetCountOfClass(ammoClass) or 0 end)
                    if have < 10 then
                        self:GiveArcherAmmo(ent, tier, weaponType, 40)
                    end
                end
            end
        end
    end)
    if not ok then System.LogAlways('[Archer] ResupplyArchersOutOfCombat error: ' .. tostring(err)) end
end

function mercenaries:SetArcherWeaponType(weaponType)
    if not self.ArcherWeaponSets[weaponType] then weaponType = "bow" end
    _G.ArcherWeaponType = weaponType
    self:SaveString("ArcherWeaponTypePersistent", weaponType)
    Game.SendInfoText('merc_info_archer_weapon_' .. weaponType, false, 0, 3)

    -- Re-equip every active archer with the newly selected weapon type.
    for name, ent in pairs(self.ActiveMercs) do
        if ent and ent.actor and self:IsArcherName(name) then
            self:EquipArcherWeapon(ent)
        end
    end
end

-- =======================================================================
-- COMBAT TICK DATA - called from the archer attack trees. Fills:
--   data.distanceToTarget / data.distanceToPlayer
--   data.isTargetAlive
--   data.outOfAmmo
--   data.stanceValid (false as soon as the player switches archer combat
--                     stance, which makes the running tree bail out so the
--                     scheduler can fire the newly selected behaviour)
-- =======================================================================
function mercenaries:UpdateArcherCombatData(data, myWuid, expectedStance)
    local ok, err = pcall(function()
        data.isTargetAlive = false
        data.stanceValid = true
        data.distanceToTarget = 9999.0

        local stance = _G.ArcherStance or "skirmish"
        if expectedStance and stance ~= expectedStance then
            data.stanceValid = false
        end

        local me = XGenAIModule.GetEntityByWUID(myWuid)
        local myPos = me and me:GetPos()

        if myPos and player then
            local pp = player:GetPos()
            if pp then
                local dx, dy, dz = pp.x - myPos.x, pp.y - myPos.y, pp.z - myPos.z
                data.distanceToPlayer = math.sqrt(dx*dx + dy*dy + dz*dz)
            end
        end

        if data.attackData and data.attackData.target then
            local targetEnt = XGenAIModule.GetEntityByWUID(data.attackData.target)
            if targetEnt and self:IsAliveAndWell(targetEnt, true) then
                data.isTargetAlive = true
                local tp = targetEnt:GetPos()
                if tp and myPos then
                    local dx, dy, dz = tp.x - myPos.x, tp.y - myPos.y, tp.z - myPos.z
                    data.distanceToTarget = math.sqrt(dx*dx + dy*dy + dz*dz)
                end
            end
        end

        data.outOfAmmo = false
        local weaponType = self:GetArcherWeaponType()
        if me and me.inventory and me.inventory.GetCountOfClass then
            local ammoClasses = self.ArcherArrowClasses
            if weaponType == "crossbow" then ammoClasses = self.ArcherBoltClasses
            elseif weaponType == "handcannon" then ammoClasses = self.ArcherShotClasses end
            local total = 0
            for _, ammoClass in ipairs(ammoClasses) do
                local ok2, c = pcall(function() return me.inventory:GetCountOfClass(ammoClass) end)
                if ok2 and c then total = total + c end
            end
            data.outOfAmmo = (total == 0)
        end
    end)

    if not ok then
        System.LogAlways('[Archer] UpdateArcherCombatData error: ' .. tostring(err))
    end
end

-- =======================================================================
-- TOKEN HANDLING - called from MonitorInventory in mercenaries.lua
-- =======================================================================
function mercenaries:MonitorArcherTokens(p)
    local countArcherWeak = p:GetCountOfClass(self.TokenIDArcherWeak)
    local countArcherMedium = p:GetCountOfClass(self.TokenIDArcherMedium)
    local countArcherStrong = p:GetCountOfClass(self.TokenIDArcherStrong)
    local countArcherStance = p:GetCountOfClass(self.TokenIDArcherStance)
    local countArcherWeaponType = p:GetCountOfClass(self.TokenIDArcherWeaponType)

    if countArcherWeak and countArcherWeak > 0 then
        p:DeleteItemOfClass(self.TokenIDArcherWeak, countArcherWeak)
        self:HireArcher(75 * countArcherWeak, countArcherWeak, "weak")
    end

    if countArcherMedium and countArcherMedium > 0 then
        p:DeleteItemOfClass(self.TokenIDArcherMedium, countArcherMedium)
        self:HireArcher(150 * countArcherMedium, countArcherMedium, "medium")
    end

    if countArcherStrong and countArcherStrong > 0 then
        p:DeleteItemOfClass(self.TokenIDArcherStrong, countArcherStrong)
        self:HireArcher(400 * countArcherStrong, countArcherStrong, "strong")
    end

    if countArcherStance and countArcherStance > 0 then
        p:DeleteItemOfClass(self.TokenIDArcherStance, countArcherStance)
        self:SetArcherStance(self.ArcherStanceByIndex[countArcherStance] or "skirmish")
    end

    if countArcherWeaponType and countArcherWeaponType > 0 then
        p:DeleteItemOfClass(self.TokenIDArcherWeaponType, countArcherWeaponType)
        self:SetArcherWeaponType(self.ArcherWeaponTypeByIndex[countArcherWeaponType] or "bow")
    end
end

-- Console commands for testing without dialog
System.AddCCommand("archer_hire_w1", "mercenaries:HireArcher(0, 1, 'weak')", "")
System.AddCCommand("archer_hire_w3", "mercenaries:HireArcher(0, 3, 'weak')", "")
System.AddCCommand("archer_hire_d1", "mercenaries:HireArcher(0, 1, 'medium')", "")
System.AddCCommand("archer_hire_d3", "mercenaries:HireArcher(0, 3, 'medium')", "")
System.AddCCommand("archer_hire_p1", "mercenaries:HireArcher(0, 1, 'strong')", "")
System.AddCCommand("archer_hire_p3", "mercenaries:HireArcher(0, 3, 'strong')", "")

System.AddCCommand("archer_stance_skirmish", "mercenaries:SetArcherStance('skirmish')", "")
System.AddCCommand("archer_stance_guard", "mercenaries:SetArcherStance('guard')", "")
System.AddCCommand("archer_stance_melee", "mercenaries:SetArcherStance('melee')", "")
System.AddCCommand("archer_stance_hold", "mercenaries:SetArcherStance('hold')", "")

System.AddCCommand("archer_weapon_bow", "mercenaries:SetArcherWeaponType('bow')", "")
System.AddCCommand("archer_weapon_crossbow", "mercenaries:SetArcherWeaponType('crossbow')", "")
System.AddCCommand("archer_weapon_handcannon", "mercenaries:SetArcherWeaponType('handcannon')", "")
