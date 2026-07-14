-- Persistence trick: state is stored as the NAME of a hidden BasicEntity (saved
-- with the game), keyed "mercenary_mod_state_data_<tag>__<value>". Saving
-- replaces the tag's entity; loading reads the value back off the name.
function mercenaries:SaveString(tag, dataString)
    if not tag or tag == "" then
        System.LogAlways("[Mercenaries] Error: Cannot save without a tag.")
        return
    end
    if not dataString or dataString == "" then
        System.LogAlways("[Mercenaries] Error: Cannot save an empty string.")
        return
    end

    local searchPrefix = "mercenary_mod_state_data_" .. tostring(tag) .. "__"

    -- Destroy this tag's existing saver entity, then spawn a fresh one.
    local allTags = System.GetEntitiesByClass("BasicEntity")
    if allTags then
        for i, ent in ipairs(allTags) do
            local name = ent:GetName()
            if name and string.sub(name, 1, string.len(searchPrefix)) == searchPrefix then
                System.RemoveEntity(ent.id)
            end
        end
    end

    local newEntityName = searchPrefix .. tostring(dataString)

    System.LogAlways("[Mercenaries] Successfully saved state [" .. tostring(tag) .. "]: " .. tostring(dataString))

    System.SpawnEntity({
        class = "BasicEntity",
        name = newEntityName,
        position = {x = 0, y = 0, z = -100} 
    })
end

-- Read back the value stored for a tag, or nil if never saved.
function mercenaries:LoadString(tag)
    if not tag or tag == "" then
        System.LogAlways("[Mercenaries] Error: Cannot load without a tag.")
        return nil
    end

    local searchPrefix = "mercenary_mod_state_data_" .. tostring(tag) .. "__"
    local allTags = System.GetEntitiesByClass("BasicEntity")

    if allTags then
        for i, ent in ipairs(allTags) do
            local name = ent:GetName()
            if name and string.sub(name, 1, string.len(searchPrefix)) == searchPrefix then
                local extractedData = string.sub(name, string.len(searchPrefix) + 1)
                System.LogAlways("[Mercenaries] Loaded state [" .. tostring(tag) .. "]: " .. tostring(extractedData))
                return extractedData
            end
        end
    end

    System.LogAlways("[Mercenaries] No saved string found for tag: " .. tostring(tag))
    return nil
end