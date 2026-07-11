--Equips an individual merc with a certain style
function mercenaries:EquipMercenary(ent, currentPreset)
    if not ent or not ent.actor then return end
    
    local name = ent:GetName() or ''
    if string.find(name, 'MercenaryCustomCompanion') then
        return
    end    
    local tier = "weak"
    
    -- Parse tier directly from their entity name
    if string.find(name, '_medium_') then 
        tier = "medium" 
    elseif string.find(name, '_strong_') then 
        tier = "strong" 
    end
    
    local finalPresetId = ""
    
    -- 1 in 300 chance for CLOWN
    if math.random(1, 300) == 1 then
        finalPresetId = self.Clowns[math.random(1, #self.Clowns)]
        System.LogAlways('[Mercenary Jeff] HONK HONK. Clown mode activated for ' .. name)
    else
        -- Standard gear lookup based on Tier and Style
        local styleData = self.Outfits[currentPreset] or self.Outfits[1]
        local tierOutfits = styleData[tier] or styleData["weak"]
        finalPresetId = tierOutfits[math.random(1, #tierOutfits)]
    end

    if finalPresetId ~= "" then
        System.LogAlways('[Mercenary Jeff] Equipping clothing preset: ' .. finalPresetId .. ' on ' .. name)
        ent.actor:EquipClothingPreset(finalPresetId)
    end
end

-- Changes the outfit of every active merc.
function mercenaries:ChangeMercOutfit(presetNumber, skipSave)
    local currentPreset = presetNumber or 1
    
    -- Update the fast memory cache
    _G.MercCurrentOutfit = currentPreset
    
    System.LogAlways('[Mercenary Jeff] ChangeMercOutfit called with style: ' .. tostring(currentPreset))
    
    -- Gate SaveString: only write when this is a real user-initiated change
    if not skipSave then
        mercenaries:SaveString("MercOutfitPersistent", tostring(currentPreset))
    end

    -- PERFORMANCE: Iterate the cache instead of scanning all world NPCs.
    for name, ent in pairs(self.ActiveMercs) do
        if ent and ent.soul and ent.actor then
            -- Custom companions keep their own outfit, only re-equip regular mercs
            if string.find(name, 'SpawnedFriend') then
                self:EquipMercenary(ent, currentPreset)
            end
        end
    end
end


-- Helper to apply clothes to newly spawned mercs without triggering a save
function mercenaries.ReapplySavedOutfit()
    local savedOutfitString = mercenaries:LoadString("MercOutfitPersistent")

    local savedOutfit = 1

    if savedOutfitString and tonumber(savedOutfitString) then
        savedOutfit = tonumber(savedOutfitString)
    end

    -- Apply the outfit, passing true to skip re-saving it
    mercenaries:ChangeMercOutfit(savedOutfit, true)
end

-- =======================================================================
-- WEAPON LOADOUT — same structure as the clothing preset system above,
-- selected via dialogue instead of GetActions, EquipWeaponPreset instead
-- of EquipClothingPreset.
-- =======================================================================

-- The shield is bundled into the weapon preset alongside the weapon (the
-- engine equips a preset's items as a set - there's no separate shield
-- slot to fill), so to keep shields tied to the outfit we pick a preset
-- whose bundled shield matches the merc's clothing set. The shield-bearing
-- weapon types (2 sword+shield, 3 axe+shield, 5 mace+shield) each have their
-- variants split into a "generic" group and a "Skalitz" group (kite / Skalitz
-- wave shields); Skalitz-clad mercs draw from the Skalitz group, everyone
-- else from the generic group, so a non-Skalitz merc never rolls a Skalitz
-- shield and vice versa.
-- NOTE: only Skalitz has a dedicated shield in the current asset set, so the
-- generic group is shared by all non-Skalitz outfits (their shields still
-- vary by tier - pavese/heater/knight - just not by faction).
mercenaries.SkalitzOutfitIndex = 6
mercenaries.ShieldWeaponTypes = { [2] = true, [3] = true, [5] = true }
mercenaries.SkalitzShieldPresets = {
    -- Sword + shield (v3 kite / v4 Skalitz wave, all tiers)
    ["b6e1c2a4-3f8d-4c11-9a2e-7d5f8b3c1a90"] = true,
    ["a17f9d2b-6c4e-4a83-8b1f-3e9c7d2a5b64"] = true,
    ["c3d8a1f5-2b7e-4f96-8c3a-1d6e9b4f7c22"] = true,
    ["d4e9b2a6-3c8f-4a09-9d4b-2e7f0a5c8d33"] = true,
    ["e5fa3b7c-4d9a-4b12-8e5c-3f8a1b6d9e44"] = true,
    ["f60b4c8d-5eab-4c23-9f6d-4a9b2c7e0f55"] = true,
    -- Axe + shield (v3 kite / v4 Skalitz wave, all tiers)
    ["04cdf545-216f-40a9-8bbe-e3df62c6c9c4"] = true,
    ["8cadc064-2b10-4c83-b623-baa48ed00887"] = true,
    ["67b28c22-75ae-46c1-9fbb-74c4e5404bc8"] = true,
    ["d5320f5a-4b3f-4b24-a396-642e82ede04e"] = true,
    ["4da2558e-7c3b-4e71-9a0f-4e0fb96e31f7"] = true,
    ["a03246b9-5795-4b88-8a09-2558cd3f2b21"] = true,
    -- Mace + shield (v3 kite / v4 Skalitz wave; strong only has 3 variants,
    -- so v3 is the Skalitz-group one there)
    ["8cd52efe-5c75-4ca4-a73e-d742856de6ad"] = true,
    ["05de7ab9-82dd-44db-8dcf-c065a3f88f4f"] = true,
    ["e72434c6-0ce9-4a03-a9a1-a34586b5f141"] = true,
    ["b5a967b8-4ed8-4814-b233-a7b4125375d2"] = true,
    ["232574b9-4aef-42f2-8b78-8218d8702ddb"] = true
}

-- Equips an individual merc with a certain weapon loadout. outfitPreset lets
-- the caller pass the merc's clothing set so the shield can be matched to it;
-- it defaults to the squad's current outfit for the normal (non-battle) path.
function mercenaries:EquipMercenaryWeapon(ent, currentPreset, outfitPreset)
    if not ent or not ent.actor then return end

    local name = ent:GetName() or ''
    if string.find(name, 'MercenaryCustomCompanion') then
        return
    end
    -- Archers keep their bow set no matter what melee loadout the squad
    -- switches to - their combat trees depend on a missile weapon existing.
    if self:IsArcherName(name) then
        self:EquipArcherWeapon(ent)
        return
    end
    local tier = "weak"

    -- Parse tier directly from their entity name
    if string.find(name, '_medium_') then
        tier = "medium"
    elseif string.find(name, '_strong_') then
        tier = "strong"
    end

    local preset = currentPreset or 1
    if preset == 1 then
        -- "Random": pick a fresh category each time this merc is equipped,
        -- so the squad ends up with a varied mix of loadouts. Capped at 9
        -- (melee only) while ranged loadouts (10-12) are disabled.
        preset = math.random(2, 9)
    end

    local styleData = self.WeaponSets[preset] or self.WeaponSets[2]
    local tierWeapons = styleData[tier] or styleData["weak"]

    -- For shield weapon types, restrict the candidate presets to the shield
    -- group that matches the outfit (Skalitz vs generic) so the bundled shield
    -- stays thematically correct instead of being rolled at random.
    local candidates = tierWeapons
    if self.ShieldWeaponTypes[preset] then
        local outfit = outfitPreset or _G.MercCurrentOutfit or 1
        local wantSkalitz = (outfit == self.SkalitzOutfitIndex)
        local filtered = {}
        for _, id in ipairs(tierWeapons) do
            if (self.SkalitzShieldPresets[id] == true) == wantSkalitz then
                filtered[#filtered + 1] = id
            end
        end
        if #filtered > 0 then candidates = filtered end
    end

    local finalPresetId = candidates[math.random(1, #candidates)]

    if finalPresetId and finalPresetId ~= "" then
        System.LogAlways('[Mercenary Jeff] Equipping weapon preset: ' .. finalPresetId .. ' on ' .. name)
        ent.actor:EquipWeaponPreset(finalPresetId)
    end
end

-- Changes the weapon loadout of every active merc.
function mercenaries:ChangeMercWeapon(presetNumber, skipSave)
    local currentPreset = presetNumber or 1

    -- Update the fast memory cache
    _G.MercCurrentWeapon = currentPreset

    System.LogAlways('[Mercenary Jeff] ChangeMercWeapon called with loadout: ' .. tostring(currentPreset))

    -- Gate SaveString: only write when this is a real user-initiated change
    if not skipSave then
        mercenaries:SaveString("MercWeaponPersistent", tostring(currentPreset))
    end

    -- PERFORMANCE: Iterate the cache instead of scanning all world NPCs.
    for name, ent in pairs(self.ActiveMercs) do
        if ent and ent.soul and ent.actor then
            -- Custom companions keep their own weapon, only re-equip regular mercs
            if string.find(name, 'SpawnedFriend') then
                self:EquipMercenaryWeapon(ent, currentPreset)
            end
        end
    end
end

-- Helper to apply a weapon loadout to newly spawned mercs without triggering a save
function mercenaries.ReapplySavedWeapon()
    local savedWeaponString = mercenaries:LoadString("MercWeaponPersistent")

    local savedWeapon = 1

    if savedWeaponString and tonumber(savedWeaponString) then
        savedWeapon = tonumber(savedWeaponString)
    end

    -- Apply the loadout, passing true to skip re-saving it
    mercenaries:ChangeMercWeapon(savedWeapon, true)
end