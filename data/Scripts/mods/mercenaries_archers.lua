-- Ranged mercenaries (archers): a separate combat group with own souls, brain
-- (archer_scheduler.xml) and stances (skirmish/melee/hold). Named
-- "SpawnedFriend_archer_..." so they ride every squad system for free, with
-- '_archer_' branching the archer-specific bits. See docs/archers.md.

-- Tokens (skald dialog -> lua). Count on the hire token = how many to hire.
mercenaries.TokenIDArcher = "679a655e-189d-4519-b437-ccc4b92be60d"
mercenaries.TokenIDArcherStance = "679a655e-189d-4519-b437-ccc4b92be62d"      -- count = stance: 1 skirmish, 2 melee, 3 hold
mercenaries.TokenIDArcherWeaponType = "679a655e-189d-4519-b437-ccc4b92be63d" -- count = weapon: 1 bow, 2 crossbow, 3 handcannon

-- Archers are a single pool, no tiers. They still spawn under the melee mercs'
-- "medium" tier name so the tier-keyed squad systems (outfits, camp housing)
-- resolve them without an archer-specific branch. See docs/archers.md.
mercenaries.ArcherTier = "medium"
mercenaries.ArcherPrice = 150

mercenaries.ArcherStanceCode = { skirmish = 0, melee = 1, hold = 2 }
mercenaries.ArcherStanceByIndex = { [1] = "skirmish", [2] = "melee", [3] = "hold" }

mercenaries.ArcherWeaponTypeByIndex = { [1] = "bow", [2] = "crossbow", [3] = "handcannon" }

-- Archer souls (one pool of 10 faces), see soul__mercenaries.xml
mercenaries.ArcherSouls = {
    "187fbe3b-8dea-4f81-a933-6416a2bb8eab",
    "a1794fdd-66bb-4908-a834-6900a453007d",
    "6b7f50e2-4cee-4627-a417-2d57491bc8df",
    "ca41e429-90f5-4893-b1d8-ca6c1d480652",
    "7f0016fb-e8ee-48f2-aa81-c6fb8fd8cede",
    "1f7cbc4b-d665-4b2d-baf3-7cb129c2642e",
    "10870a67-df3f-4ce7-b34b-efe6470d892c",
    "3af05aa1-4613-4e48-85d6-7ad783c7938c",
    "b474ff9a-1e4a-4fcf-a2e9-d0df5cfbac53",
    "209eccf1-69e3-4f04-8384-b710dc6f2208"
}
mercenaries.ArcherSoulIndex = 1

-- Archer weapon sets, one table per ranged weapon type, each bundling the
-- ranged weapon + ammo (where applicable) + a shortsword sidearm - see
-- weapon_preset__mercenaries.xml (merc_weapon_archerset_*).
mercenaries.ArcherWeaponSets = {
    bow = {
        "d6d73839-0334-4e24-adfe-3fa4b6cbdd2c", "fe692cff-7236-4cfd-af19-bc44e3d20f19"
    },
    crossbow = {
        "3c4d5e6f-7a8b-4c9d-0e1f-2a3b4c5d6e7f", "4d5e6f7a-8b9c-4d0e-1f2a-3b4c5d6e7f8a"
    },
    handcannon = {
        "9c0d1e2f-3a4b-4c5d-6e7f-8a9b0c1d2e3f"
    }
}

-- Ammo the archers carry, by weapon type. Hand cannons have no tiered variant
-- in vanilla, so shot_ball is the only option.
mercenaries.ArcherAmmoClass = {
    bow = "710e3706-8974-404b-b23a-6f51670ef1ed",       -- arrow_hunting
    crossbow = "40337bef-e965-4a60-abee-695e9a784fa4",  -- bolt_hunting
    handcannon = "f10ded12-a41c-40bf-a8ae-883d4e845059" -- shot_ball
}

-- Every ammo class an archer might end up holding - used to detect "out of ammo"
-- in the combat trees, so it has to cover ammo looted or picked up mid-fight too.
mercenaries.ArcherArrowClasses = {
    "ad6f0f01-aec4-44d1-982c-1210eb01b74a", -- arrow_normal
    "710e3706-8974-404b-b23a-6f51670ef1ed", -- arrow_hunting
    "802507e9-d620-47b5-ae66-08fcc314e26a", -- arrow_enh_hunting
    "a5b31bbc-1e11-4831-835b-c06d5b13a7da", -- arrow_enh_piercing
    "13ba7468-11a2-483d-8cb9-25ce36a2d228", -- arrow_enh_cutting
    "7db6b854-e307-4a47-ba39-943190b2469e"  -- arrow_enh_precise
}
mercenaries.ArcherBoltClasses = {
    "8460003f-637f-4713-92c9-4954037c4b9c", -- bolt_normal
    "40337bef-e965-4a60-abee-695e9a784fa4", -- bolt_hunting
    "b738d184-4ae1-4d74-8fac-b8db1943b1d4", -- bolt_enh_hunting
    "c82f1a8d-3617-42b7-98a9-36e96ff71294", -- bolt_enh_piercing
    "e6652736-4cb4-42e9-b012-050064405f37", -- bolt_enh_cutting
    "081fc4a1-25e9-4492-8dc8-2d9d6668c07a"  -- bolt_enh_precise
}
mercenaries.ArcherShotClasses = {
    "f10ded12-a41c-40bf-a8ae-883d4e845059", -- shot_ball
    "fb30c64e-2360-4ed7-b805-531b3424fe4d"  -- battle_shot
}

function mercenaries:IsArcherName(name)
    return name ~= nil and string.find(name, '_archer_', 1, true) ~= nil
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

function mercenaries:HireArcher(cost, amount)
    local p = player.inventory

    self:Recount()
    if not _G.MercCount then _G.MercCount = 0 end

    if _G.MercCount + amount > self.MaxCompanions then
        System.LogAlways(string.format(
            '[Archer] HireArcher: rejected - too many (count=%d + %d > max=%d)',
            _G.MercCount, amount, self.MaxCompanions))
        Game.SendInfoText('merc_info_too_many', false, 0, 3)
        return
    end

    if p:GetMoney() < cost then
        System.LogAlways(string.format(
            '[Archer] HireArcher: rejected - not enough money (have %d, need %d)',
            p:GetMoney(), cost))
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

    -- Same indoor rule as Hire (mercenaries_spawning.lua): hired at an innkeeper's,
    -- the archers muster outside, and only the ones that actually appeared are paid for.
    local outside = nil
    local spawned = 0

    local ok, err = pcall(function()
        local a = self:HireSpawnAnchor()
        if not (a and a.pos and a.rot) then
            System.LogAlways('[Archer] HireArcher: no usable spawn position - nobody placed')
            return
        end
        local spawnPos, playerRot = a.pos, a.rot
        outside = a.outside

        local soulList = self.ArcherSouls
        local currentPreset = _G.MercCurrentOutfit or 1

        for i = 1, amount do
            local idx = self.ArcherSoulIndex
            local soulGuid = soulList[idx]

            self.ArcherSoulIndex = idx + 1
            if self.ArcherSoulIndex > #soulList then
                self.ArcherSoulIndex = 1
            end

            local raw = {
                x = spawnPos.x + (math.random() - 0.5) * 1.5,
                y = spawnPos.y + (math.random() - 0.5) * 1.5,
                z = spawnPos.z
            }
            local offsetPos = a.snap and self:FindValidGround(raw, spawnPos.z) or raw

            local safeRot = {x = 0, y = 0, z = playerRot.z}
            local entityName = "SpawnedFriend_archer_" .. self.ArcherTier .. "_" .. tostring(math.random(10000, 99999)) .. "_" .. soulGuid

            System.SpawnEntity({
                class = "NPC",
                name = entityName,
                position = offsetPos,
                orientation = safeRot,
                properties = {guidSharedSoulId = soulGuid}
            })

            local ent = System.GetEntityByName(entityName)

            if ent then
                -- Register before the equip calls, which throw on an empty preset table
                -- and would otherwise leave a live NPC nothing tracks. See Hire.
                self.ActiveMercs[entityName] = ent
                spawned = spawned + 1

                local dressed, derr = pcall(function()
                    mercenaries:EnsureMercIsAlwaysRendered(ent)
                    self:EquipMercenary(ent, currentPreset)
                    self:EquipArcherWeapon(ent)
                    self:InjectInteraction(ent)
                    self:CampOnMercJoined(ent)
                end)
                if not dressed then
                    System.LogAlways('[Archer] HireArcher: post-spawn setup failed for ' ..
                                     entityName .. ': ' .. tostring(derr))
                end
            else
                System.LogAlways('[Archer] HireArcher: SpawnEntity produced nothing for ' .. entityName)
            end
        end
    end)

    if not ok then System.LogAlways('[Archer] HireArcher error: ' .. tostring(err)) end

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
        Game.SendInfoText('merc_info_archer_hired_single', false, 0, 3)
    else
        Game.SendInfoText('merc_info_archer_hired_multiple', false, 0, 3)
    end

    if outside then Game.SendInfoText('merc_info_hired_outside', false, 0, 5) end

    -- A hire is one more moment where a batch of men must all pick up follow at once,
    -- and it rebuilds the formation (grow), which drops every follower's slot at the
    -- same time. Same bounded window the dismount, order-release, battle-over and
    -- loot-sweep cases use: anyone who demonstrably fails to start walking is re-fired.
    pcall(function() mercenaries:BeginFollowVerify("hire") end)
end

-- One archer, at an exact spot. The counterpart of SpawnMercAt (see it for why this
-- is not just HireArcher with a position argument).
function mercenaries:SpawnArcherAt(pos, yaw, outfit)
    if not pos then return nil end
    outfit = outfit or _G.MercCurrentOutfit or 1
    local ent
    local ok, err = pcall(function()
        local idx = self.ArcherSoulIndex
        local soulGuid = self.ArcherSouls[idx]
        self.ArcherSoulIndex = (idx % #self.ArcherSouls) + 1

        local name = "SpawnedFriend_archer_" .. self.ArcherTier .. "_" ..
                     tostring(math.random(10000, 99999)) .. "_" .. soulGuid
        System.SpawnEntity({
            class = "NPC", name = name, position = pos,
            orientation = { x = 0, y = 0, z = yaw or 0 },
            properties = { guidSharedSoulId = soulGuid },
        })
        ent = System.GetEntityByName(name)
        if not ent then return end
        self.ActiveMercs[name] = ent
        pcall(function()
            self:EnsureMercIsAlwaysRendered(ent)
            self:EquipMercenary(ent, outfit)
            self:EquipArcherWeapon(ent)
            self:InjectInteraction(ent)
            self:CampOnMercJoined(ent)
        end)
    end)
    if not ok then System.LogAlways('[Archer] SpawnArcherAt error: ' .. tostring(err)) end
    return ent
end

function mercenaries:EquipArcherWeapon(ent)
    if not ent or not ent.actor then return end

    local name = ent:GetName() or ''

    -- The custom uniform arms the archers too: it picks the missile set (its own, if
    -- the player handed one over) and hangs whatever else he named on top.
    if self:GearWantsCustom(ent, nil) then
        self:GearApplyWeapons(ent, true)
        return
    end

    local weaponType = self:GetArcherWeaponType()
    local sets = self.ArcherWeaponSets[weaponType] or self.ArcherWeaponSets["bow"]
    local presetId = sets[math.random(1, #sets)]

    if presetId and presetId ~= "" then
        System.LogAlways('[Archer] Equipping archer weapon preset: ' .. presetId .. ' on ' .. name)
        ent.actor:EquipWeaponPreset(presetId)
    end

    self:GiveArcherAmmo(ent, weaponType, 40)
end

-- Best-effort ammo top-up (arrows/bolts/shot by weapon type), covering re-equips
-- and long fights on top of the 40 rounds the storm preset ships.
function mercenaries:GiveArcherAmmo(ent, weaponType, amount)
    local ok, err = pcall(function()
        if not ent or not ent.inventory then return end

        local ammoClass = self.ArcherAmmoClass[weaponType] or self.ArcherAmmoClass["bow"]

        local have = 0
        pcall(function() have = ent.inventory:GetCountOfClass(ammoClass) or 0 end)
        local need = (amount or 40) - have
        if need <= 0 then return end

        -- Inventory:CreateItem(classId, health, amount) creates AND inserts in one
        -- call (Scripts/Utils/ItemUtils.lua, player.lua). The old two-step
        -- ItemManager.CreateItem(...) + inventory:AddItem(itemId) silently added
        -- nothing - a static archer ended up with only the single arrow his weapon
        -- preset shipped, fired it, and stood there "out of ammo" (see docs/archers.md).
        ent.inventory:CreateItem(ammoClass, 1.0, need)
        System.LogAlways('[Archer] Gave ' .. tostring(need) .. ' ammo to ' .. tostring(ent:GetName())
            .. ' (now ' .. tostring((ent.inventory:GetCountOfClass(ammoClass) or 0)) .. ')')
    end)
    if not ok then System.LogAlways('[Archer] GiveArcherAmmo error: ' .. tostring(err)) end
end

-- Refill quivers once combat is over (LowPriorityMonitorLoop, every 5s), so an
-- archer that ran dry doesn't stay a swordsman for the rest of the session.
function mercenaries:ResupplyArchersOutOfCombat()
    local ok, err = pcall(function()
        local weaponType = self:GetArcherWeaponType()

        for name, ent in pairs(self.ActiveMercs) do
            if self:IsArcherName(name) and ent and ent.inventory then
                local inCombat = false
                pcall(function() inCombat = ent.soul:HasScriptContext("crime_interruptAttack") end)

                if not inCombat then
                    local ammoClass = self.ArcherAmmoClass[weaponType] or self.ArcherAmmoClass["bow"]

                    local have = 0
                    pcall(function() have = ent.inventory:GetCountOfClass(ammoClass) or 0 end)
                    if have < 10 then
                        self:GiveArcherAmmo(ent, weaponType, 40)
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

-- Combat tick data for the archer attack trees: distances, isTargetAlive,
-- outOfAmmo, and stanceValid (goes false when the player switches archer stance,
-- so the running tree bails and the scheduler fires the new behaviour).
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
            if targetEnt and self:IsCombatViable(targetEnt) then
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

-- Token handling, called from MonitorInventory in mercenaries.lua.
function mercenaries:MonitorArcherTokens(p)
    local countArcher = p:GetCountOfClass(self.TokenIDArcher)
    local countArcherStance = p:GetCountOfClass(self.TokenIDArcherStance)
    local countArcherWeaponType = p:GetCountOfClass(self.TokenIDArcherWeaponType)

    if countArcher and countArcher > 0 then
        p:DeleteItemOfClass(self.TokenIDArcher, countArcher)
        self:HireArcher(self.ArcherPrice * countArcher, countArcher)
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
