-- =============================================================================
-- mercenaries_Store - TEST BUILD
--
-- One entity that carries the whole mod state through a save, instead of the
-- ~26 name-encoded BasicEntity corpses in mercenaries_saving.lua.
--
-- The mechanism is CryEngine's own: CScriptProxy (WHGame.dll release_1_5,
-- RVA 0x3815254) looks for OnSave on an entity's script table, calls it with a
-- fresh table, and serialises that table into the entity's save record under the
-- key "ScriptData". On load it reads ScriptData back and hands it to OnLoad.
-- Vanilla uses it - see references/Scripts/Entities/Others/Ladder.lua.
--
-- This is the TEST version. It answers two questions and logs the answers:
--   1. does the engine call OnSave/OnLoad at all for a MOD-DEFINED class?
--   2. does it serialise a nested table, or only flat scalars?
-- so both are written every save: `store` (nested) and `packed` (one string).
-- Whichever comes back decides what the shipping version may rely on.
-- Drive it with merc_store_* (mercenaries_store.lua).
-- =============================================================================

mercenaries_Store = {
    Properties = {
        soclasses_SmartObjectClass = "",
        sWH_AI_EntityCategory = "",
        bMissionCritical = false,
        bCanTriggerAreas = false,
        object_Model = "",
        -- The whole point: unlike mercenaries_Prop (which sets both to 0 so camp
        -- pieces stay out of saves), this one MUST be written to the save.
        bSaved_by_game = 1,
        bSerialize = 1,
        -- Never physicalise. The old saver entities defaulted to rigid bodies and
        -- ~58 of them ended up stacked on one point, interpenetrating, never
        -- allowed to sleep - see the note in mercenaries_saving.lua.
        Physics = {
            bPhysicalize = false,
            bRigidBody = false,
            bPushableByPlayers = false,
        },
        MultiplayerOptions = {
            bNetworked = false,
        },
    },
    Client = {},
    Server = {},
    Editor = {
        Icon = "physicsobject.bmp",
        IconOnTop = 1,
    },
}

EntityCommon.Derive(mercenaries_Store, BasicEntity)

local SEP_PAIR = "\n"
local SEP_KV   = "\t"

local function sLog(s) System.LogAlways("[MercStore] " .. tostring(s)) end

-- ---- packing, for the flat-string mirror ----------------------------------
-- Only used to find out whether the engine keeps nested tables. Keys and values
-- that contain a tab or a newline are rejected by StoreSet, so this stays lossless.
local function pack(t)
    local out = {}
    for k, v in pairs(t or {}) do
        out[#out + 1] = tostring(k) .. SEP_KV .. tostring(v)
    end
    return table.concat(out, SEP_PAIR)
end

local function unpack_(s)
    local t = {}
    if type(s) ~= "string" or s == "" then return t end
    for line in string.gmatch(s .. SEP_PAIR, "(.-)" .. SEP_PAIR) do
        if line ~= "" then
            local k, v = string.match(line, "^(.-)" .. SEP_KV .. "(.*)$")
            if k then t[k] = v end
        end
    end
    return t
end

function mercenaries_Store:OnSpawn()
    BasicEntity.OnSpawn(self)
    if self.MercStoreTable == nil then self.MercStoreTable = {} end
end

-- OnReset runs on a fresh spawn but ALSO when the editor/engine resets an entity;
-- it must not wipe a table that OnLoad has just restored.
function mercenaries_Store:OnReset()
    if self.MercStoreTable == nil then self.MercStoreTable = {} end
end

function mercenaries_Store:OnSave(tbl)
    local data = self.MercStoreTable or {}
    local n = 0
    for _ in pairs(data) do n = n + 1 end
    -- Candidate A: hand the engine the nested table directly.
    tbl.store = data
    -- Candidate B: the same content as ONE string, so a serialiser that drops
    -- sub-tables still gets the data through.
    tbl.packed = pack(data)
    tbl.count  = n
    tbl.probe  = "merc_store_ok"
    sLog(string.format("OnSave fired: %d key(s), packed %d byte(s)", n, string.len(tbl.packed)))
end

function mercenaries_Store:OnLoad(tbl)
    tbl = tbl or {}
    local nested, packed = tbl.store, tbl.packed
    local nestedOk = (type(nested) == "table")
    local packedOk = (type(packed) == "string" and packed ~= "")

    -- Nested wins when it survived; the packed mirror is the fallback AND the
    -- evidence for whether the shipping version is allowed to use sub-tables.
    if nestedOk then
        self.MercStoreTable = nested
    elseif packedOk then
        self.MercStoreTable = unpack_(packed)
    else
        self.MercStoreTable = {}
    end

    local n = 0
    for _ in pairs(self.MercStoreTable) do n = n + 1 end
    self.MercStoreReport = string.format(
        "OnLoad fired: probe=%s count=%s nested_table=%s packed_string=%s -> %d key(s) restored",
        tostring(tbl.probe), tostring(tbl.count),
        nestedOk and "SURVIVED" or "LOST",
        packedOk and "SURVIVED" or "LOST", n)
    sLog(self.MercStoreReport)
end
