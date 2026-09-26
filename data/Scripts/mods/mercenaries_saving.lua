-- =============================================================================
-- Persistence.
--
-- State lives in ONE place: the script table of a single VANILLA BasicEntity
-- named MercStore, which the engine serialises into the save for us (OnSave/
-- OnLoad -> "ScriptData"; mercenaries_store.lua has the mechanism, the WHGame.dll
-- addresses, and why the class must not be one of ours). That entity is the
-- mod's entire save footprint.
--
-- It used to be one hidden BasicEntity PER TAG, carrying its value inside its
-- NAME ("mercenary_mod_state_data_<tag>__<value>"). That worked, but it left
-- ~26 vanilla-class entities baked into every save - which the game still
-- loads, and still simulates, with the mod uninstalled - and it could only
-- store a flat string per tag because a name is all there was to write into.
-- Old saves are migrated on first access and the legacy entities deleted, so a
-- player carries the debris for exactly one more save (see MigrateLegacy).
--
-- The public API is unchanged: SaveString / SaveStrings / LoadString, with
-- SaverValues as the read cache. SaverMap() refreshes that cache from the
-- entity; everything after it is a table lookup, so the ~7ms full-BasicEntity
-- scan that used to cost over 100ms in a single LogiSave frame is gone too.
-- See docs/save-footprint.md.
-- =============================================================================

-- Legacy only: the prefix the old per-tag entities used. Migration and the
-- uninstall sweep still need to recognise them; nothing writes one any more.
mercenaries.SaverPrefix = "mercenary_mod_state_data_"

mercenaries.SaverValues = {}     -- [tag] = value, the read cache
mercenaries.SaverIds    = {}     -- legacy; kept so older callers do not crash
mercenaries.SaverMapped = false  -- has the cache been filled this session?
mercenaries.SaverLog    = false  -- per-write logging; off by default, it is file I/O
mercenaries.SaverMigrated = false

local function sLog(s) System.LogAlways("[Mercenaries] " .. tostring(s)) end

-- The store's own table, or nil when there is no entity yet. Read-only callers
-- must not spawn one: a LoadString on a fresh game would otherwise create the
-- mod's save footprint before the player has done anything with the mod.
local function storeTable(self, create)
    local e = create and self:StoreEntity() or self:StoreFind()
    if not e then return nil end
    -- `health` is the slot vanilla BasicEntity:OnSave already round-trips; see the long
    -- note in mercenaries_store.lua for why the payload rides a vanilla field rather than
    -- an OnSave of our own.
    if type(e.health) ~= "table" then e.health = {} end
    return e.health
end

-- ---- legacy migration ------------------------------------------------------
-- Old saves hold one BasicEntity per tag. Lift them into the store and delete
-- them, so the first save made after this update is already clean. Runs once a
-- session, off the back of the first SaverMap.
function mercenaries:MigrateLegacy()
    if self.SaverMigrated then return 0 end
    self.SaverMigrated = true
    local found = {}
    local n = 0
    pcall(function()
        local pfx, plen = self.SaverPrefix, string.len(self.SaverPrefix)
        for _, ent in pairs(System.GetEntitiesByClass("BasicEntity") or {}) do
            local name = ent and ent:GetName()
            if name and string.sub(name, 1, plen) == pfx then
                local rest = string.sub(name, plen + 1)
                local tag, val = string.match(rest, "^(.-)__(.*)$")
                if tag and tag ~= "" then
                    -- Duplicates exist in saves from older builds, which spawned a
                    -- replacement without removing the old one. Last wins, matching
                    -- the scan order the old SaverMap used.
                    found[tag] = val
                    n = n + 1
                end
                pcall(function() System.RemoveEntity(ent.id) end)
            end
        end
    end)
    if n == 0 then return 0 end
    -- Do not resurrect state onto a save the player has scrubbed for uninstall.
    if self.UninstallScrubbed then
        sLog(string.format("migration: dropped %d legacy saver entit(ies) (persistence is off)", n))
        return 0
    end
    local t = storeTable(self, true)
    if not t then
        sLog("migration: FAILED to create the store - legacy state lost")
        return 0
    end
    local moved = 0
    for tag, val in pairs(found) do
        -- Anything already in the store is newer than the save's legacy copy.
        if t[tag] == nil then t[tag] = val; moved = moved + 1 end
    end
    sLog(string.format("migration: %d legacy saver entit(ies) removed, %d tag(s) moved into the store",
                       n, moved))
    return moved
end

-- Fill the cache from the store. Cheap: one class scan of a class with exactly
-- one instance, then a table copy.
function mercenaries:SaverMap(force)
    if self.SaverMapped and not force then return end
    self.SaverValues = {}
    -- A save from the build whose store used the mod's OWN entity class still holds that
    -- entity, and that single record is what fails a mod-less load outright. Lift it onto
    -- the vanilla-class store and delete it, before anything reads a tag.
    pcall(function() self:StoreMigrateLegacyClass() end)
    self:MigrateLegacy()
    local t = storeTable(self, false)
    local n = 0
    if t then
        for k, v in pairs(t) do self.SaverValues[k] = v; n = n + 1 end
    end
    self.SaverMapped = true
    -- One line per level load, so any session's log says whether the state came back
    -- without anyone having to run a command. n == 0 right after a load means the store
    -- did not persist; that is the whole question this file exists to answer.
    sLog(string.format("store: %d tag(s) restored from the save", n))
end

function mercenaries:SaverForget()
    self.SaverValues, self.SaverIds, self.SaverMapped = {}, {}, false
    -- Migration is per LEVEL, not per session: crossing to the other region loads a
    -- world with its own legacy entities still in it. Both latches, or the other
    -- region keeps its mercenaries_Store entity and still fails a mod-less load.
    self.SaverMigrated = false
    self.StoreLegacyDone = false
end

-- The scrub latch is a SILENT kill switch: merc_purge_savers and merc_uninstall set
-- UninstallScrubbed so nothing writes state back before the player saves, which is right,
-- but from that moment the mod persists NOTHING and used to say nothing about it. A
-- session that has quietly stopped saving looks exactly like a save/load bug - contracts
-- vanish, camps do not come back, progress resets - and the log gives you not one clue.
-- Rate-limited to one line every 10s so a busy tick cannot flood it.
function mercenaries:SaveRefused(tag)
    local now = 0
    pcall(function() now = System.GetCurrTime() or 0 end)
    if self._scrubWarnAt and (now - self._scrubWarnAt) < 10.0 then return end
    self._scrubWarnAt = now
    sLog("PERSISTENCE IS OFF for this session (merc_purge_savers / merc_uninstall was run):")
    sLog("  refused to save [" .. tostring(tag) .. "]. NOTHING is being written - contracts,")
    sLog("  camps and progress will not survive a reload. Restart the game to save again.")
end

-- One tag. The store is created on the first write and not before.
local function put(self, tag, value)
    local t = storeTable(self, true)
    if not t then
        sLog("save FAILED: could not create the store entity")
        return false
    end
    t[tag] = value
    self.SaverValues[tag] = value
    if self.SaverLog then sLog("saved [" .. tag .. "]: " .. value) end
    return true
end

function mercenaries:SaveString(tag, dataString)
    -- merc_uninstall has scrubbed this session: the store was emptied so the NEXT save is
    -- clean for an uninstalled game, and nothing - a logistics tick, a camp save, anything
    -- - may quietly write one back before the player saves.
    if self.UninstallScrubbed then self:SaveRefused(tag); return end
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
    local vs = tostring(dataString)
    if self.SaverValues[tag] == vs then return end   -- no churn for an unchanged value
    put(self, tag, vs)
end

-- Many tags at once. Kept as a separate entry point because the old backend had to
-- scan the level for each write; here it is only a loop, but ~40 call sites use it.
function mercenaries:SaveStrings(t)
    if self.UninstallScrubbed then self:SaveRefused("(batch)"); return end
    if type(t) ~= "table" then return end
    self:SaverMap()
    for tag, val in pairs(t) do
        if tag and tag ~= "" and val ~= nil and tostring(val) ~= "" then
            local tg, vs = tostring(tag), tostring(val)
            if self.SaverValues[tg] ~= vs then put(self, tg, vs) end
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

-- Drop every tag AND the store entity itself. This is what makes the mod's save
-- footprint nil: after this, a save contains nothing of ours at all.
function mercenaries:SaverWipe()
    local n = 0
    local t = storeTable(self, false)
    if t then for _ in pairs(t) do n = n + 1 end end
    pcall(function() self:StoreRemoveCmd() end)
    self.SaverValues, self.SaverIds, self.SaverMapped = {}, {}, false
    return n
end

mercenaries:DevCommand("merc_saver_remap", "mercenaries:SaverForget(); mercenaries:SaverMap(true)",
                   "Rebuild the tag cache from the store entity")
function mercenaries:SaverLogToggle()
    self.SaverLog = not self.SaverLog
    sLog("persistence logging " .. (self.SaverLog and "ON" or "OFF"))
end

mercenaries:DevCommand("merc_saver_log", "mercenaries:SaverLogToggle()",
                   "Toggle per-write persistence logging (off by default: it is file I/O)")
