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

-- Equips an individual merc with a certain weapon loadout
function mercenaries:EquipMercenaryWeapon(ent, currentPreset)
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
    local finalPresetId = tierWeapons[math.random(1, #tierWeapons)]

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