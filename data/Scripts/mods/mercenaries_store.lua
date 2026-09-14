-- =============================================================================
-- Single-entity persistence - TEST BUILD
--
-- The candidate replacement for mercenaries_saving.lua's ~26 name-encoded
-- BasicEntity savers: ONE mercenaries_Store entity whose script table is
-- serialised into the save by the engine (OnSave/OnLoad -> "ScriptData").
-- See data/Scripts/Entities/mercenaries_Store.lua for the mechanism and
-- docs/save-footprint.md for why the entity-name hack is being replaced.
--
-- Nothing else in the mod reads this yet. It exists to answer, in game:
--   does the engine call OnSave/OnLoad for a mod-defined class, and does a
--   nested table survive the round trip?
--
--   merc_store_set <key> <value>   store an arbitrary string
--   merc_store_get <key>           read it back
--   merc_store_dump                every key currently held
--   merc_store_clear               empty the store (keeps the entity)
--   merc_store_probe               entity + last OnLoad report
--   merc_store_remove              delete the entity entirely
--
-- The round trip to prove: set a few keys, save, quit, relaunch, load, then
-- merc_store_probe + merc_store_dump.
-- =============================================================================

local STORE_CLASS = "mercenaries_Store"
local STORE_NAME  = "MercStore"   -- "^Merc%u" is the uninstall sweep's pattern

local function sLog(s) System.LogAlways("[MercStore] " .. tostring(s)) end

-- The entity is a singleton. Finding it is a class scan, which is cheap only
-- because this class has exactly one instance - unlike the old saver map, which
-- had to walk every BasicEntity in the level (~7ms a call, see docs/performance.md).
function mercenaries:StoreFind()
    local found = nil
    pcall(function()
        for _, e in pairs(System.GetEntitiesByClass(STORE_CLASS) or {}) do
            if e then
                -- Duplicates should be impossible, but an older save could carry
                -- one: keep the first and say so rather than silently picking.
                if found then
                    sLog("WARNING: more than one " .. STORE_CLASS .. " in the world - using the first")
                    break
                end
                found = e
            end
        end
    end)
    return found
end

-- Find or create. Position is irrelevant (nothing renders and nothing
-- physicalises), but it is kept off the play area like the old savers were.
function mercenaries:StoreEntity()
    local e = self:StoreFind()
    if e then return e end
    local ent = nil
    pcall(function()
        ent = System.SpawnEntity({
            class    = STORE_CLASS,
            name     = STORE_NAME,
            position = { x = 0, y = 0, z = -100 },
            properties = {
                bSaved_by_game = 1,
                bSerialize     = 1,
                Physics = { bPhysicalize = false, bRigidBody = false },
            },
        })
    end)
    if not ent then
        sLog("FAILED to spawn " .. STORE_CLASS .. " - is data/Entities/mercenaries_Store.ent in the pak?")
        return nil
    end
    if ent.MercStoreTable == nil then ent.MercStoreTable = {} end
    pcall(function() ent:DestroyPhysics() end)
    sLog("spawned " .. STORE_CLASS .. " id=" .. tostring(ent.id))
    return ent
end

-- ---- the API ---------------------------------------------------------------

function mercenaries:StoreSet(key, value)
    if type(key) ~= "string" or key == "" then
        sLog("set: need a key"); return false
    end
    value = tostring(value or "")
    -- The flat-string mirror in the entity script is tab/newline delimited, so a
    -- value carrying either would come back from the fallback path corrupted.
    -- Refuse rather than store something that only survives one of the two routes.
    if string.find(key, "[\t\n]") or string.find(value, "[\t\n]") then
        sLog("set: keys and values may not contain a tab or a newline"); return false
    end
    local e = self:StoreEntity()
    if not e then return false end
    if e.MercStoreTable == nil then e.MercStoreTable = {} end
    e.MercStoreTable[key] = value
    sLog(string.format("set [%s] = %s", key, value))
    return true
end

function mercenaries:StoreGet(key)
    local e = self:StoreFind()
    if not e or type(e.MercStoreTable) ~= "table" then return nil end
    return e.MercStoreTable[key]
end

function mercenaries:StoreAll()
    local e = self:StoreFind()
    if not e or type(e.MercStoreTable) ~= "table" then return {} end
    return e.MercStoreTable
end

function mercenaries:StoreClear()
    local e = self:StoreFind()
    if e then e.MercStoreTable = {} end
end

-- ---- console ---------------------------------------------------------------

-- `merc_store_set roster medium,100,SpawnedFriend_x` - the first word is the key,
-- everything after the first space is the value, spaces and all.
--
-- TRAP: the game's console cuts a command line at an `=` (it reads the rest as a
-- cvar assignment). `merc_lua local ok=false` arrived as `merc_lua local ok`.
-- So a VALUE containing `=` cannot be delivered from the console - it can from
-- Lua. Nothing to do about it here; just do not test with one.
function mercenaries:StoreSetCmd(line)
    local s = self:CmdClean(line)
    local key, value = string.match(s, "^(%S+)%s+(.*)$")
    if not key then
        sLog("usage: merc_store_set <key> <value>")
        return
    end
    self:StoreSet(key, value)
end

function mercenaries:StoreGetCmd(line)
    local key = self:CmdClean(line)
    if key == "" then sLog("usage: merc_store_get <key>"); return end
    local v = self:StoreGet(key)
    if v == nil then
        sLog(string.format("get [%s] = <not set>", key))
    else
        sLog(string.format("get [%s] = %s", key, v))
    end
end

function mercenaries:StoreDumpCmd()
    local e = self:StoreFind()
    if not e then sLog("dump: no store entity in the world"); return end
    local t, n = self:StoreAll(), 0
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k; n = n + 1 end
    table.sort(keys)
    sLog(string.format("dump: %d key(s) on entity id=%s", n, tostring(e.id)))
    for _, k in ipairs(keys) do sLog(string.format("   [%s] = %s", k, tostring(t[k]))) end
end

function mercenaries:StoreProbeCmd()
    local e = self:StoreFind()
    if not e then
        sLog("probe: NO store entity. Either nothing has been set this session, or")
        sLog("       the one in the save did not come back - which is the answer.")
        return
    end
    local n = 0
    for _ in pairs(self:StoreAll()) do n = n + 1 end
    sLog(string.format("probe: entity id=%s holds %d key(s)", tostring(e.id), n))
    if e.MercStoreReport then
        sLog("probe: " .. tostring(e.MercStoreReport))
    else
        sLog("probe: OnLoad has NOT run on this entity - it was spawned this session,")
        sLog("       not restored from a save. Save, relaunch, load, then probe again.")
    end
end

function mercenaries:StoreRemoveCmd()
    local e = self:StoreFind()
    if not e then sLog("remove: nothing to remove"); return end
    local id = e.id
    pcall(function() System.RemoveEntity(id) end)
    sLog("removed store entity id=" .. tostring(id))
end

-- Registered at PLAYER tier deliberately, unlike the rest of the diagnostics. The
-- dev tier exists to keep the auto-quitting bench/torture campaigns away from a
-- normal launch; these touch nothing but their own entity, and gating them behind
-- -devmode would only make the round trip - save, relaunch, load - harder to run.
-- They go away with this test build.
local function storeCmd(name, body, desc)
    pcall(function() System.AddCCommand(name, body, desc) end)
end

storeCmd("merc_store_set",    "mercenaries:StoreSetCmd('%line')",  "Persistence test: merc_store_set <key> <value>")
storeCmd("merc_store_get",    "mercenaries:StoreGetCmd('%line')",  "Persistence test: merc_store_get <key>")
storeCmd("merc_store_dump",   "mercenaries:StoreDumpCmd()",        "Persistence test: list every stored key")
storeCmd("merc_store_clear",  "mercenaries:StoreClear()",          "Persistence test: empty the store, keep the entity")
storeCmd("merc_store_probe",  "mercenaries:StoreProbeCmd()",       "Persistence test: did OnSave/OnLoad run, and what survived?")
storeCmd("merc_store_remove", "mercenaries:StoreRemoveCmd()",      "Persistence test: delete the store entity")
