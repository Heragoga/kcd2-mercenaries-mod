--Equips an individual merc with a certain style
function mercenaries:EquipMercenary(ent, currentPreset)
    if not ent or not ent.actor then return end
    
    local name = ent:GetName() or ''
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