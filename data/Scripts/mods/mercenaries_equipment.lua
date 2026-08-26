-- Equips an individual merc with a clothing preset for their tier and style.
function mercenaries:EquipMercenary(ent, currentPreset)
    if not ent or not ent.actor then return end
    
    local name = ent:GetName() or ''
    -- A named companion wears the gear his own character wears and nothing else - every
    -- style, the custom uniform included. He carries the SpawnedFriend_ prefix like
    -- everyone else, so this has to be an explicit check, and it has to come first.
    --
    -- GearHeroRestore is only ever work once: it puts his own look back if an earlier
    -- build had already dressed him in the pattern, and after that finds nothing.
    if self:IsHeroName(name) then
        self:GearHeroRestore(ent)
        return
    end
    -- Style 7 is not a preset pool at all: it is the set of items the player handed
    -- over, worn piece by piece. See mercenaries_custom_gear.lua.
    if currentPreset == self.CustomOutfitIndex then
        self:GearApplyArmour(ent)
        return
    end
    -- Any other style: the custom pieces must not be on him. Applying a preset over
    -- them does NOT take them off - that is what the mash-up of livery and harness
    -- was - so they are deleted. Done here rather than only when leaving style 7, so
    -- it holds however this was reached, reload included. Squad only: enemies come
    -- through this function too and have nothing to do with the player's uniform.
    local mine = string.find(name, 'SpawnedFriend') ~= nil
                 or string.find(name, self.StaticArcherNamePrefix or 'SpawnedTower_archer_', 1, true) == 1
    if mine then self:GearRemoveCustom(ent) end
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

    for name, ent in pairs(self.ActiveMercs) do
        if ent and ent.soul and ent.actor then
            -- Custom companions keep their own outfit, only re-equip regular mercs
            if string.find(name, 'SpawnedFriend') then
                self:EquipMercenary(ent, currentPreset)
            end
        end
    end

    -- The custom uniform carries the weapon as well, so switching into or out of it
    -- has to re-arm the company - the weapon loadout on its own never changed.
    if currentPreset == self.CustomOutfitIndex or self.MercPrevOutfit == self.CustomOutfitIndex then
        self:ChangeMercWeapon(_G.MercCurrentWeapon or 1, true)
    end
    self.MercPrevOutfit = currentPreset
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

-- Weapon loadouts: same preset structure as clothing, but the shield is bundled
-- into the weapon preset (no separate shield slot). Shield-bearing types (2/3/5)
-- split into a "generic" and a "Skalitz" group; Skalitz-clad mercs roll from the
-- Skalitz group and everyone else from generic, so shields match the outfit.
mercenaries.SkalitzOutfitIndex = 6
mercenaries.ShieldWeaponTypes = { [2] = true, [3] = true, [5] = true }

-- The band the "random" loadout (index 1) rolls in. Polearms (9) are excluded:
-- the weapon reaches the hand fine - merc_wpn_audit reports 121/121 armed with no
-- empty hands - but nothing renders while a polearm is sheathed, so a polearm NPC
-- reads as unarmed until he draws. That is what the missing-weapon reports were
-- about. Ranged (10-12) stay out as before. merc_weapon_polearm still hands them
-- out on purpose; raise the max to 9 to put them back in the roll.
mercenaries.RandomMeleeSetMin = 2
mercenaries.RandomMeleeSetMax = 8
-- The v3 ("kite") slot in each shield type used to hold a plain kite shield and
-- v4 ("Skalitz wave") a Skalitz-decorated one, both items from the third-party
-- "House of Kobyla Arms, Armour and Regalia" mod - a hidden dependency nobody
-- shipping this mod noticed: hire a merc into one of those presets without that
-- mod installed and he gets no shield at all, or a broken one. Both are now
-- vanilla: v3 -> Shield_Kite_Cross_RW (plain, so it moved to the generic pool
-- below and dropped out of this table), v4 -> the genuine vanilla
-- Shield_Kite_Skalitz (still Skalitz-only, just no longer borrowed). See
-- weapon_preset__mercenaries.xml for the item swap itself.
mercenaries.SkalitzShieldPresets = {
    -- Sword + shield, v4 (all tiers)
    ["a17f9d2b-6c4e-4a83-8b1f-3e9c7d2a5b64"] = true,
    ["d4e9b2a6-3c8f-4a09-9d4b-2e7f0a5c8d33"] = true,
    ["f60b4c8d-5eab-4c23-9f6d-4a9b2c7e0f55"] = true,
    -- Axe + shield, v4 (all tiers)
    ["8cadc064-2b10-4c83-b623-baa48ed00887"] = true,
    ["d5320f5a-4b3f-4b24-a396-642e82ede04e"] = true,
    ["a03246b9-5795-4b88-8a09-2558cd3f2b21"] = true,
    -- Mace + shield, v4 (weak/medium); strong only has 3 variants and its v3 slot
    -- is the Skalitz one there (no v4 exists for strong mace).
    ["05de7ab9-82dd-44db-8dcf-c065a3f88f4f"] = true,
    ["b5a967b8-4ed8-4814-b233-a7b4125375d2"] = true,
    ["232574b9-4aef-42f2-8b78-8218d8702ddb"] = true
}

-- Equips an individual merc with a certain weapon loadout. outfitPreset lets
-- the caller pass the merc's clothing set so the shield can be matched to it;
-- it defaults to the squad's current outfit for the normal (non-battle) path.
function mercenaries:EquipMercenaryWeapon(ent, currentPreset, outfitPreset)
    if not ent or not ent.actor then return end

    local name = ent:GetName() or ''
    -- Same as EquipMercenary: a named companion keeps his own weapon, whatever the
    -- squad is carrying, the custom uniform included.
    if self:IsHeroName(name) then
        return
    end
    -- The custom uniform owns the weapon too, for every tier and for the archers.
    -- Enemies come through here with outfitPreset nil and would otherwise inherit
    -- the squad's, so GearWantsCustom checks who this actually is.
    if self:GearWantsCustom(ent, outfitPreset) then
        self:GearApplyWeapons(ent, self:IsArcherName(name))
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
        -- so the squad ends up with a varied mix of loadouts.
        preset = math.random(self.RandomMeleeSetMin, self.RandomMeleeSetMax)
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

    -- Which category actually got equipped - "random" only resolves it here, so a
    -- caller upstream (EquipEnemy, matching the shield to the enemy's own faction
    -- instead of the merc squad's) has no other way to find out. Every earlier
    -- return in this function is a case the caller cannot act on anyway (archer,
    -- custom companion, bad entity), so returning nil there is correct too.
    return preset
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