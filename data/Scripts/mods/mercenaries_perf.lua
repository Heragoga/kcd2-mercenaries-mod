-- Shared caches every hot path reads from instead of re-deriving its own copy.
-- Loaded first in the chain: nothing here calls into another mod module at load time.
-- See docs/performance.md.

mercenaries.PerfPos           = {}    -- [wuidStr] = {x,y,z}; .player = player pos
mercenaries.PerfNpcScan       = nil   -- {at, cx, cy, cz, r, list={{entity,wuid,pos},...}}
mercenaries.PerfWidestRadius  = 0     -- widest radius any consumer has asked for
mercenaries.EntityByWuid      = {}    -- [key] = wuid, for lookups that used GetEntityByName
mercenaries.CampActorCache    = {}    -- [wuidStr] = bool
mercenaries.PatrolMemberIndex = {}    -- [wuidStr] = LivePatrols record

local function pfLog(s) System.LogAlways("[MercPerf] " .. tostring(s)) end

local function nowSecs()
    local t = 0
    pcall(function() t = System.GetCurrTime() or 0 end)
    return t
end

-- ---------------------------------------------------------------------------
-- Own-soul identity. Replaces a 65-entry string.find scan run per candidate.
-- ---------------------------------------------------------------------------

local GUID_PAT = "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x"

-- Souls / ArcherSouls / StaticArcherSouls are assigned once at load and never mutated,
-- so this is built once.
function mercenaries:OwnedSoulSet()
    if self._ownedSoulSet then return self._ownedSoulSet end
    local set, n = {}, 0
    local function add(g)
        if type(g) == "string" and g ~= "" then
            local k = string.lower(g)
            if not set[k] then set[k] = true; n = n + 1 end
        end
    end
    for _, tierList in pairs(self.Souls or {}) do
        if type(tierList) == "table" then for _, g in ipairs(tierList) do add(g) end end
    end
    for _, g in ipairs(self.ArcherSouls or {}) do add(g) end
    for _, g in ipairs(self.StaticArcherSouls or {}) do add(g) end
    self._ownedSoulSet, self._ownedSoulCount = set, n
    return set
end

-- Exactly the containment test the old triple loop did: the id may arrive wrapped,
-- so an exact hit is tried first and the embedded GUID second.
function mercenaries:IsOwnSoulId(eid)
    if not eid or eid == "" then return false end
    local set = self:OwnedSoulSet()
    local low = string.lower(eid)
    if set[low] then return true end
    local g = string.match(low, GUID_PAT)
    if g and set[g] then return true end
    return false
end

-- The old scan, kept only so merc_perf_verify can compare the two answers.
function mercenaries:IsOwnSoulIdLegacy(eid)
    if not eid then return false end
    if self.Souls then
        for _, tierList in pairs(self.Souls) do
            for _, guid in ipairs(tierList) do
                if string.find(eid, guid) then return true end
            end
        end
    end
    if self.ArcherSouls then
        for _, guid in ipairs(self.ArcherSouls) do
            if string.find(eid, guid) then return true end
        end
    end
    if self.StaticArcherSouls then
        for _, guid in ipairs(self.StaticArcherSouls) do
            if string.find(eid, guid) then return true end
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Entity handles by key. Replaces System.GetEntityByName in tick paths.
-- ---------------------------------------------------------------------------

function mercenaries:PerfRegister(key, ent)
    if not key or not ent then return end
    local w = ent.this and ent.this.id or ent.id
    if w then self.EntityByWuid[tostring(key)] = w end
end

function mercenaries:PerfUnregister(key)
    if key then self.EntityByWuid[tostring(key)] = nil end
end

-- nil when the key is unknown or the entity is gone, so callers can fall back
-- to their own lookup rather than treating a miss as "does not exist".
function mercenaries:PerfEntity(key)
    if not key then return nil end
    local w = self.EntityByWuid[tostring(key)]
    if not w then return nil end
    local e = nil
    pcall(function() e = XGenAIModule.GetEntityByWUID(w) end)
    if not e then self.EntityByWuid[tostring(key)] = nil end
    return e
end

-- Resolve by name once, then keep the handle. Safe drop-in for a polled
-- System.GetEntityByName: same answer, linear scan only on the first miss.
function mercenaries:PerfEntityByName(name)
    if not name or name == "" then return nil end
    local e = self:PerfEntity(name)
    if e then return e end
    pcall(function() e = System.GetEntityByName(name) end)
    if e then self:PerfRegister(name, e) end
    return e
end

function mercenaries:PerfReset()
    self._retreatCache     = {}
    self.PerfPos           = {}
    self.PerfNpcScan       = nil
    self.EntityByWuid      = {}
    self.CampActorCache    = {}
    self.PatrolMemberIndex = {}
end

-- ---------------------------------------------------------------------------
-- Positions, refreshed once per master tick.
-- ---------------------------------------------------------------------------

-- Position tables are REUSED rather than rebuilt. This runs every master tick for every
-- merc, so allocating a fresh {x,y,z} each time was a steady garbage stream feeding the
-- Lua collector - which runs on the main thread and pauses it. See docs/performance.md.
function mercenaries:PerfScanMercs()
    local pos  = self.PerfPos
    local seen = self._perfPosSeen
    if not seen then seen = {}; self._perfPosSeen = seen end
    for k in pairs(seen) do seen[k] = nil end

    if player then
        local p = nil
        pcall(function() p = player:GetWorldPos() end)
        if p then
            local t = pos.player
            if t then t.x, t.y, t.z = p.x, p.y, p.z
            else pos.player = { x = p.x, y = p.y, z = p.z } end
            seen.player = true
        end
    end
    for _, ent in pairs(self.ActiveMercs or {}) do
        local w = ent and (ent.this and ent.this.id or ent.id)
        if w then
            local p = nil
            pcall(function() p = ent:GetWorldPos() end)
            if p then
                local k = tostring(w)
                local t = pos[k]
                if t then t.x, t.y, t.z = p.x, p.y, p.z
                else pos[k] = { x = p.x, y = p.y, z = p.z } end
                seen[k] = true
            end
        end
    end
    -- Drop only what is genuinely gone, so the surviving tables stay live.
    for k in pairs(pos) do
        if not seen[k] then pos[k] = nil end
    end
end

function mercenaries:PerfMercPos(wuid)
    if not wuid then return nil end
    return self.PerfPos[tostring(wuid)]
end

-- ---------------------------------------------------------------------------
-- One NPC box query per window, sliced by radius for narrower consumers.
-- ---------------------------------------------------------------------------

-- Announced at spawn by anything that needs to see further than the squad does
-- (static archers reach StaticArcherRange around themselves, not the player).
function mercenaries:PerfWantRadius(r)
    r = tonumber(r)
    if r and r > (self.PerfWidestRadius or 0) then self.PerfWidestRadius = r end
end

function mercenaries:PerfScanNpcs()
    if not player then self.PerfNpcScan = nil; return end
    local pp = nil
    pcall(function() pp = player:GetPos() end)
    if not pp then self.PerfNpcScan = nil; return end

    -- Radius RECOMPUTED from live state, not latched. PerfWantRadius only ever raises
    -- PerfWidestRadius and nothing lowers it except PerfReset (once, on load), so placing a
    -- single tower archer widened this shared scan from 18m to StaticArcherRange (90m) for
    -- the rest of the session - even after that archer was gone, and even with the player
    -- nowhere near it. A 90m circle covers ~25x the area of an 18m one, so in a crowded
    -- city that is the difference between a handful of NPCs per pass and hundreds, each one
    -- then run through IsValidEnemy. The wide radius is honoured only while static archers
    -- actually exist. See docs/performance.md "Costs that scale with NPC density".
    local r = self.EnemyAlerted and (self.EnemyAlertRadius or 0) or (self.EnemyScanRadius or 18)
    if next(self.StaticArchers or {}) ~= nil then
        r = math.max(r, self.StaticArcherRange or 0)
    end
    -- The entry tables and the list are reused between passes for the same reason as
    -- PerfScanMercs: this rebuilt one table per nearby NPC every 300ms.
    local scan = self.PerfNpcScan
    if not scan then scan = { list = {} }; self.PerfNpcScan = scan end
    local list = scan.list
    local n = 0

    local ents = nil
    pcall(function() ents = System.GetPhysicalEntitiesInBoxByClass(pp, r, "NPC") end)
    if ents then
        for _, ent in pairs(ents) do
            if ent and type(ent) == "table" and ent.soul then
                -- Same wuid derivation the consumers use. Requiring ent.this here would
                -- make the shared list a STRICT SUBSET of what a consumer's own query
                -- returns, and those candidates would silently stop being seen.
                local w = ent.this and ent.this.id or ent.id
                local p = nil
                pcall(function() p = ent:GetPos() end)
                if w and p then
                    n = n + 1
                    local e = list[n]
                    if e then
                        e.entity, e.wuid = ent, w
                        e.pos.x, e.pos.y, e.pos.z = p.x, p.y, p.z
                    else
                        list[n] = { entity = ent, wuid = w,
                                    pos = { x = p.x, y = p.y, z = p.z } }
                    end
                end
            end
        end
    end
    -- Truncate rather than rebuild; consumers use ipairs so a shorter list is enough,
    -- and clearing the tail releases the entity references.
    for i = #list, n + 1, -1 do
        local e = list[i]
        if e then e.entity = nil end
        list[i] = nil
    end
    scan.at, scan.cx, scan.cy, scan.cz, scan.r = nowSecs(), pp.x, pp.y, pp.z, r
end

-- nil means "not covered, run your own query" - never "nobody is there".
function mercenaries:PerfNpcsNear(pos, radius, maxAgeMs)
    local scan = self.PerfNpcScan
    if not (scan and pos and radius) then return nil end
    if maxAgeMs then
        if (nowSecs() - (scan.at or 0)) * 1000 > maxAgeMs then return nil end
    end
    local dx, dy = pos.x - scan.cx, pos.y - scan.cy
    if math.sqrt(dx * dx + dy * dy) + radius > (scan.r or 0) then return nil end
    local r2, out = radius * radius, {}
    for _, e in ipairs(scan.list) do
        local ex, ey, ez = e.pos.x - pos.x, e.pos.y - pos.y, e.pos.z - pos.z
        if (ex * ex + ey * ey + ez * ez) <= r2 then out[#out + 1] = e end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Camp-actor answer, refreshed round-robin by the scheduler.
-- ---------------------------------------------------------------------------

-- Computes on a miss rather than answering false, so a merc hired between
-- sweeps is never briefly mistaken for a non-camp-actor.
function mercenaries:CampActorGet(wuid)
    if not wuid then return false end
    local k = tostring(wuid)
    local v = self.CampActorCache[k]
    if v ~= nil then return v end
    return self:CampActorRefresh(wuid)
end

function mercenaries:CampActorRefresh(wuid)
    if not wuid then return false end
    local k, v = tostring(wuid), false
    pcall(function() v = self:IsCampActor(wuid) and true or false end)
    self.CampActorCache[k] = v
    return v
end

function mercenaries:CampActorInvalidate(wuid)
    if wuid then self.CampActorCache[tostring(wuid)] = nil end
end

function mercenaries:CampActorInvalidateAll()
    self.CampActorCache = {}
end

-- ---------------------------------------------------------------------------
-- Patrol gang membership, indexed instead of rescanned.
-- ---------------------------------------------------------------------------

function mercenaries:PatrolIndexGang(rec)
    if not rec then return end
    for _, e in ipairs(rec.men or {}) do
        local w = e and (e.this and e.this.id or e.id)
        if w then self.PatrolMemberIndex[tostring(w)] = rec end
    end
end

function mercenaries:PatrolIndexClear(rec)
    if not rec then return end
    for k, v in pairs(self.PatrolMemberIndex) do
        if v == rec then self.PatrolMemberIndex[k] = nil end
    end
end

function mercenaries:PatrolIndexRebuild()
    self.PatrolMemberIndex = {}
    for _, rec in pairs(self.LivePatrols or {}) do self:PatrolIndexGang(rec) end
end

-- ---------------------------------------------------------------------------
-- Diagnostics
-- ---------------------------------------------------------------------------

-- Proves the hash set answers exactly what the old 65-entry scan answered, against
-- whatever NPCs are actually around. Run it in a town with the squad out.
function mercenaries:PerfVerify()
    self:OwnedSoulSet()
    pfLog("owned soul ids: " .. tostring(self._ownedSoulCount or 0))

    local pp = nil
    if player then pcall(function() pp = player:GetPos() end) end
    if not pp then pfLog("no player position - cannot sample NPCs"); return end

    local ents = nil
    pcall(function() ents = System.GetPhysicalEntitiesInBoxByClass(pp, 100.0, "NPC") end)
    ents = ents or {}

    local checked, mismatch = 0, 0
    for _, ent in pairs(ents) do
        if ent and type(ent) == "table" and ent.soul then
            local eid = nil
            pcall(function() eid = tostring(ent.soul:GetId()) end)
            if eid then
                checked = checked + 1
                local new, old = self:IsOwnSoulId(eid), self:IsOwnSoulIdLegacy(eid)
                if new ~= old then
                    mismatch = mismatch + 1
                    local nm = "?"
                    pcall(function() nm = ent:GetName() or "?" end)
                    pfLog(string.format("  MISMATCH new=%s old=%s id=%s %s",
                                        tostring(new), tostring(old), eid, nm))
                end
            end
        end
    end
    pfLog(string.format("checked %d NPC(s), %d mismatch(es)%s", checked, mismatch,
                        mismatch == 0 and " - hash set is equivalent" or " - DO NOT SHIP"))
end

function mercenaries:PerfStatus()
    local scan = self.PerfNpcScan
    pfLog(string.format("widestRadius=%.0f npcScan=%s posCached=%d entKeys=%d campActor=%d patrolIdx=%d",
        self.PerfWidestRadius or 0,
        scan and string.format("%d npc(s) r=%.0f age=%.1fs", #scan.list, scan.r or 0, nowSecs() - (scan.at or 0))
             or "none",
        self:_TableCount(self.PerfPos),
        self:_TableCount(self.EntityByWuid),
        self:_TableCount(self.CampActorCache),
        self:_TableCount(self.PatrolMemberIndex)))
end

mercenaries:DevCommand("merc_perf_verify", "mercenaries:PerfVerify()",
                   "Check the own-soul hash set answers the same as the old scan for every NPC nearby")
mercenaries:DevCommand("merc_perf_status", "mercenaries:PerfStatus()",
                   "Report shared cache sizes and NPC scan age")
