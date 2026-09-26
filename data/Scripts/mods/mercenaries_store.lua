-- =============================================================================
-- Single-entity persistence.
--
-- ONE entity carries the whole mod state through a save. It is the backend
-- mercenaries_saving.lua's SaveString/LoadString sit on, and it replaced one hidden
-- BasicEntity PER TAG whose value was carried inside its NAME.
--
-- A nested table DOES survive the engine's ScriptData serialisation - measured on
-- playline3/exit.whs, 2026-09-14: 61 tags in one sub-table, restored intact. What that
-- save also proved, the hard way, is that the carrier must be a VANILLA class (below).
-- The commands re-check both:
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

-- =============================================================================
-- WHY THIS IS A VANILLA CLASS (2026-09-14, and it is the whole bug)
--
-- The store was mercenaries_Store, a class this mod defines. Remove the mod and the
-- engine cannot build it, so the entity restore logs
--     [Error][LoadGame] Class:'mercenaries_Store' not found ... = 'MercStore'
-- and - this is the part that matters - sub_370EC7C sets the load-context failure flag
-- at [ctx+0x30]. The caller turns that flag into a HARD FAILURE:
--     [Warning] Validator: Errors during Game Loading
--     [CryAction] LoadGame: 'exit.whs' failed. Ending GameContext
--     [Error] Load of game has failed (CryEngine data)
--     Exiting to main menu because save game loading failed.
-- That was the ONLY [Error][LoadGame] in a 6.5MB modding-tools log. ONE entity of a
-- missing class aborts the entire load. The same line, for mercenaries_Prop
-- ('merc_bl_flag_3'), is in the very first "load failed" save of this investigation.
--
-- So the one object the mod MUST leave in every save cannot be a class the mod owns.
-- BasicEntity is vanilla: without the mod the engine builds it, ignores the payload,
-- and the load succeeds. Everything else the mod spawns keeps its own classes and is
-- flagged out of the save entirely (NoSaveSweep), which is the other half of the rule:
--
--   in the save: exactly one vanilla entity. Of our own classes: nothing, ever.
-- =============================================================================

local STORE_CLASS = "BasicEntity"     -- MUST stay a vanilla class. See above.
local STORE_NAME  = "MercStore"       -- "^Merc%u" is the uninstall sweep's pattern
-- Published so NoSaveSweep / SaveFootprintAudit can exclude the store BY NAME. They used
-- to exclude it by class, and when the store became a vanilla BasicEntity the sweep began
-- stamping ENTITY_FLAG_NO_SAVE on it every 60s - the mod's own save carrier - so nothing
-- persisted at all.
mercenaries.StoreEntityName = STORE_NAME
local LEGACY_CLASS = "mercenaries_Store"

local function sLog(s) System.LogAlways("[MercStore] " .. tostring(s)) end

-- HOW THE PAYLOAD RIDES (2026-09-14, second attempt)
--
-- First try was an INSTANCE-level OnSave override on the entity's script table. It never
-- fired once: CryEngine caches OnSave/OnLoad on the CLASS when the entity script is
-- parsed, so assigning ent.OnSave afterwards is invisible to it. The store spawned, the
-- log showed no "OnSave fired", and nothing persisted.
--
-- So no override at all: the payload goes in a field vanilla BasicEntity ALREADY
-- round-trips. Its OnSave is literally
--     table.health = self.health ;  table.dead = self.dead
-- and `health` appears on exactly two lines of the whole class - those two. Nothing
-- reads it, nothing resets it: BasicEntity has no Health properties, so EntityCommon's
-- damage path (which does use self.health) is never set up for it. Putting our table
-- there means the engine's own, already-cached OnSave carries it, and OnLoad hands it
-- back. Without the mod it is a vanilla entity with an odd value in a field nobody looks
-- at, and the load succeeds.
local function storeTableOf(ent)
    if not ent then return nil end
    if type(ent.health) ~= "table" then ent.health = {} end
    return ent.health
end

-- BasicEntity is a busy class - the level is full of them - so the store is found by
-- NAME, not by being the only instance of its class the way mercenaries_Store was.
function mercenaries:StoreFind()
    local found = nil
    pcall(function()
        for _, e in pairs(System.GetEntitiesByClass(STORE_CLASS) or {}) do
            if e and e.GetName and e:GetName() == STORE_NAME then
                -- Duplicates should be impossible, but an older save could carry
                -- one: keep the first and say so rather than silently picking.
                if found then
                    sLog("WARNING: more than one " .. STORE_NAME .. " in the world - using the first")
                    break
                end
                found = e
            end
        end
    end)
    return found
end

-- A save written by the build that used the mod's OWN class still has that entity, and
-- it is exactly the thing that kills a mod-less load. Lift its tags across and delete it.
function mercenaries:StoreMigrateLegacyClass()
    if self.StoreLegacyDone then return 0 end
    self.StoreLegacyDone = true
    local moved, killed = 0, 0
    pcall(function()
        for _, e in pairs(System.GetEntitiesByClass(LEGACY_CLASS) or {}) do
            if e then
                local t = (type(e.MercStoreTable) == "table") and e.MercStoreTable or {}
                local dst = self:StoreEntity()
                local dt = storeTableOf(dst)
                if dt then
                    for k, v in pairs(t) do
                        if dt[k] == nil then dt[k] = v; moved = moved + 1 end
                    end
                end
                pcall(function() System.RemoveEntity(e.id) end)
                killed = killed + 1
            end
        end
    end)
    if killed > 0 then
        sLog(string.format("migrated %d tag(s) off %d legacy %s entit(ies) - those were what broke a mod-less load",
                           moved, killed, LEGACY_CLASS))
    end
    return moved
end

-- Find or create. Position is irrelevant (nothing renders and nothing
-- physicalises), but it is kept off the play area like the old savers were.
function mercenaries:StoreEntity()
    local e = self:StoreFind()
    if e then return e end
    local ent = nil
    -- NOT SpawnTransient: this is the one entity that must reach the save.
    pcall(function()
        ent = System.SpawnEntity({
            class    = STORE_CLASS,
            name     = STORE_NAME,
            position = { x = 0, y = 0, z = -100 },
            properties = {
                bSaved_by_game = 1,
                bSerialize     = 1,
                -- The old per-tag savers defaulted to rigid bodies and ~58 of them ended
                -- up stacked on one point, never allowed to sleep. Never physicalise.
                Physics = { bPhysicalize = false, bRigidBody = false },
            },
        })
    end)
    if not ent then
        sLog("FAILED to spawn the store (" .. STORE_CLASS .. ")")
        return nil
    end
    storeTableOf(ent)
    pcall(function() ent:DestroyPhysics() end)
    sLog("spawned store id=" .. tostring(ent.id) .. " class=" .. STORE_CLASS)
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
    local t = storeTableOf(self:StoreEntity())
    if not t then return false end
    t[key] = value
    sLog(string.format("set [%s] = %s", key, value))
    return true
end

function mercenaries:StoreGet(key)
    local e = self:StoreFind()
    if not e or type(e.health) ~= "table" then return nil end
    return e.health[key]
end

function mercenaries:StoreAll()
    local e = self:StoreFind()
    if not e or type(e.health) ~= "table" then return {} end
    return e.health
end

function mercenaries:StoreClear()
    local e = self:StoreFind()
    if e then e.health = {} end
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
    sLog("probe: class=" .. tostring(e.class or "?") ..
         " payload rides vanilla BasicEntity.health, so there is no mod OnSave to report.")
    sLog("probe: n>0 after a relaunch+load is the proof; n==0 there means it did not persist.")
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

-- The no-save sweep lives in mercenaries_roster.lua (it reuses the uninstall sweep's
-- classification); it is exposed here because it is the other half of "the store is the
-- only thing in the save", and it is what you run to check that claim by hand.
storeCmd("merc_nosave_sweep", "mercenaries:NoSaveSweep()",
         "Flag every entity this mod owns out of the next save (runs on load too)")
storeCmd("merc_save_footprint", "mercenaries:SaveFootprintAudit()",
         "What this save would carry: mod entities flagged out vs still written")
