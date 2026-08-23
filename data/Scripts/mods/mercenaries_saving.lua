-- Persistence trick: state is stored as the NAME of a hidden BasicEntity (saved
-- with the game), keyed "mercenary_mod_state_data_<tag>__<value>". Saving
-- replaces the tag's entity; loading reads the value back off the name.
--
-- A profiled session measured ~7ms PER CALL here, because each one walked every
-- BasicEntity in the level. LogiSave writes 18 tags in a row from a 5s tick, so one
-- pass could cost over 100ms in a single frame - a visible hitch at otherwise steady
-- fps. Two changes keep the semantics and remove the cost:
--   1. the tag -> entity id map below, so a rewrite removes the old entity directly
--      instead of scanning to find it;
--   2. SaveStrings(), which writes many tags behind at most ONE scan.
-- See docs/performance.md.

mercenaries.SaverPrefix = "mercenary_mod_state_data_"
mercenaries.SaverIds    = {}     -- [tag] = entity id of its saver entity
mercenaries.SaverValues = {}     -- [tag] = the value currently stored
mercenaries.SaverMapped = false  -- has the one-time full scan been done this session?
mercenaries.SaverLog    = false  -- per-write logging; off by default, it is file I/O

local function sLog(s) System.LogAlways("[Mercenaries] " .. s) end

local function tagPrefix(tag)
    return mercenaries.SaverPrefix .. tostring(tag) .. "__"
end

-- One scan, all tags. Every later read and write is a table lookup.
function mercenaries:SaverMap(force)
    if self.SaverMapped and not force then return end
    self.SaverIds    = {}
    self.SaverValues = {}
    local pfx, plen = self.SaverPrefix, string.len(self.SaverPrefix)
    local all = System.GetEntitiesByClass("BasicEntity")
    if all then
        for _, ent in ipairs(all) do
            local name = ent and ent:GetName()
            if name and string.sub(name, 1, plen) == pfx then
                local rest = string.sub(name, plen + 1)
                local tag, val = string.match(rest, "^(.-)__(.*)$")
                if tag then
                    -- Duplicates can exist from older builds that spawned without
                    -- removing. The last one wins, matching the old scan order.
                    self.SaverIds[tag]    = ent.id
                    self.SaverValues[tag] = val
                end
            end
        end
    end
    self.SaverMapped = true
end

function mercenaries:SaverForget()
    self.SaverIds, self.SaverValues, self.SaverMapped = {}, {}, false
end

-- Removes the entity currently holding `tag`, falling back to a scan only when the
-- map has never been built.
local function dropTag(self, tag)
    self:SaverMap()
    local id = self.SaverIds[tag]
    if id then
        pcall(function() System.RemoveEntity(id) end)
        self.SaverIds[tag] = nil
        return
    end
    -- Not in the map: nothing of this tag exists, so there is nothing to remove.
end

local function spawnTag(self, tag, dataString)
    local name = tagPrefix(tag) .. tostring(dataString)
    local ent = nil
    pcall(function()
        ent = System.SpawnEntity({
            class = "BasicEntity",
            name = name,
            position = { x = 0, y = 0, z = -100 },
        })
    end)
    if ent and ent.id then self.SaverIds[tag] = ent.id end
    self.SaverValues[tag] = tostring(dataString)
    if self.SaverLog then
        sLog("Successfully saved state [" .. tostring(tag) .. "]: " .. tostring(dataString))
    end
end

function mercenaries:SaveString(tag, dataString)
    if not tag or tag == "" then
        sLog("Error: Cannot save without a tag.")
        return
    end
    if not dataString or dataString == "" then
        sLog("Error: Cannot save an empty string.")
        return
    end
    tag = tostring(tag)
    self:SaverMap()
    -- Same value already stored: the entity would be identical, so skip the churn.
    if self.SaverValues[tag] == tostring(dataString) and self.SaverIds[tag] then return end
    dropTag(self, tag)
    spawnTag(self, tag, dataString)
end

-- Many tags, at most one scan. `pairs` of {tag = value}.
function mercenaries:SaveStrings(t)
    if type(t) ~= "table" then return end
    self:SaverMap()
    for tag, val in pairs(t) do
        if tag and tag ~= "" and val ~= nil and tostring(val) ~= "" then
            local tg, vs = tostring(tag), tostring(val)
            if not (self.SaverValues[tg] == vs and self.SaverIds[tg]) then
                dropTag(self, tg)
                spawnTag(self, tg, vs)
            end
        end
    end
end

-- Read back the value stored for a tag, or nil if never saved.
function mercenaries:LoadString(tag)
    if not tag or tag == "" then
        sLog("Error: Cannot load without a tag.")
        return nil
    end
    tag = tostring(tag)
    self:SaverMap()
    local v = self.SaverValues[tag]
    if v ~= nil then
        if self.SaverLog then sLog("Loaded state [" .. tag .. "]: " .. tostring(v)) end
        return v
    end
    if self.SaverLog then sLog("No saved string found for tag: " .. tag) end
    return nil
end

System.AddCCommand("merc_saver_remap", "mercenaries:SaverForget(); mercenaries:SaverMap(true)",
                   "Rebuild the tag -> saver-entity map from a full scan")
function mercenaries:SaverLogToggle()
    self.SaverLog = not self.SaverLog
    sLog("persistence logging " .. (self.SaverLog and "ON" or "OFF"))
end

System.AddCCommand("merc_saver_log", "mercenaries:SaverLogToggle()",
                   "Toggle per-write persistence logging (off by default: it is file I/O)")
