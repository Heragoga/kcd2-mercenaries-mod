--[[ Type: merc_save_string test_tag 12345

Type: merc_load_string test_tag ]]
-------------------------------------------------------------------------------
-- 1. SAVE METHOD: Despawns the old saver entity, spawns a new one with the data
-------------------------------------------------------------------------------
function mercenaries:SaveString(tag, dataString)
    if not tag or tag == "" then
        System.LogAlways("[Mercenaries] Error: Cannot save without a tag.")
        return
    end
    if not dataString or dataString == "" then 
        System.LogAlways("[Mercenaries] Error: Cannot save an empty string.")
        return 
    end

    -- Construct the unique prefix for this specific tag
    local searchPrefix = "mercenary_mod_state_data_" .. tostring(tag) .. "__"

    -- Step 1: Find and destroy the existing saver entity FOR THIS TAG
    local allTags = System.GetEntitiesByClass("BasicEntity")
    if allTags then
        for i, ent in ipairs(allTags) do
            local name = ent:GetName()
            if name and string.sub(name, 1, string.len(searchPrefix)) == searchPrefix then
                System.RemoveEntity(ent.id)
            end
        end
    end

    -- Step 2: Spawn a new entity with the updated data string attached to the prefix
    local newEntityName = searchPrefix .. tostring(dataString)
    
    System.LogAlways("[Mercenaries] Successfully saved state [" .. tostring(tag) .. "]: " .. tostring(dataString))

    System.SpawnEntity({
        class = "BasicEntity",
        name = newEntityName,
        position = {x = 0, y = 0, z = -100} 
    })
end

-------------------------------------------------------------------------------
-- 2. LOAD METHOD: Retrieves the string attached to the saver entity
-------------------------------------------------------------------------------
function mercenaries:LoadString(tag)
    if not tag or tag == "" then
        System.LogAlways("[Mercenaries] Error: Cannot load without a tag.")
        return nil
    end

    -- Construct the unique prefix we are looking for
    local searchPrefix = "mercenary_mod_state_data_" .. tostring(tag) .. "__"

    -- Step 1: Get all BasicEntity entities
    local allTags = System.GetEntitiesByClass("BasicEntity")
    
    if allTags then
        for i, ent in ipairs(allTags) do
            local name = ent:GetName()
            
            -- Step 2: If we find our prefix, slice off the prefix and return the data
            if name and string.sub(name, 1, string.len(searchPrefix)) == searchPrefix then
                -- Extract everything after the prefix length
                local extractedData = string.sub(name, string.len(searchPrefix) + 1)
                System.LogAlways("[Mercenaries] Loaded state [" .. tostring(tag) .. "]: " .. tostring(extractedData))
                return extractedData
            end
        end
    end
    
    -- Return nil if the entity doesn't exist (e.g., first time running the mod)
    System.LogAlways("[Mercenaries] No saved string found for tag: " .. tostring(tag))
    return nil 
end