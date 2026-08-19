-- Camp defences (wall, archer towers, archer carts): what the player has BUILT at a
-- particular camp, as opposed to the upgrades that travel with the company.
--
-- They belong to one pitch, not to the squad. Everything is stored against the camp
-- anchor it was built at, restored when that same camp goes back up (after a save
-- load or an upgrade rebuild), and thrown away the moment a camp is pitched somewhere
-- else - move on and the walls stay behind. Corner/position lists are saved as flat
-- strings through the mod's existing SaveString slots, so nothing here relies on
-- entity serialization (spawned props are deliberately non-persistent - see the camp
-- notes on white pyramids).

mercenaries.DefAnchorEps = 2.0     -- same pitch if within this of the saved anchor

local function fmt(n) return string.format("%.2f", n or 0) end

-- ==== serialisation ====
local function packPoints(list)
    local out = {}
    for _, p in ipairs(list or {}) do
        table.insert(out, fmt(p.x) .. "," .. fmt(p.y) .. "," .. fmt(p.z))
    end
    return table.concat(out, ";")
end

local function unpackPoints(s)
    local out = {}
    if not s or s == "" then return out end
    for chunk in string.gmatch(s, "[^;]+") do
        local x, y, z = string.match(chunk, "([^,]+),([^,]+),([^,]+)")
        if x then table.insert(out, { x = tonumber(x), y = tonumber(y), z = tonumber(z) }) end
    end
    return out
end

-- x,y,z,yaw and an optional fifth number (gates use it for the open flag). Towers and
-- carts write four fields and read back with `open` nil, so the format is unchanged
-- for them and old saves still load.
local function packPoses(list)
    local out = {}
    for _, p in ipairs(list or {}) do
        local s = fmt(p.x) .. "," .. fmt(p.y) .. "," .. fmt(p.z) .. "," .. fmt(p.yaw)
        if p.open ~= nil then s = s .. "," .. fmt(p.open) end
        table.insert(out, s)
    end
    return table.concat(out, ";")
end

local function unpackPoses(s)
    local out = {}
    if not s or s == "" then return out end
    for chunk in string.gmatch(s, "[^;]+") do
        local x, y, z, a = string.match(chunk, "([^,]+),([^,]+),([^,]+),([^,]+)")
        if x then
            local extra = string.match(chunk, "[^,]+,[^,]+,[^,]+,[^,]+,([^,]+)")
            table.insert(out, { x = tonumber(x), y = tonumber(y), z = tonumber(z),
                                yaw = tonumber(a), open = tonumber(extra) })
        end
    end
    return out
end

-- ==== save ====
function mercenaries:DefSave()
    local o = self.CampBuildOrigin
    if not o then return end

    self:SaveString("QMDefX", tostring(o.x))
    self:SaveString("QMDefY", tostring(o.y))

    -- Runs are packed one per "|" field, each still a ";"-separated point list, so a
    -- single-run string written by an older save still unpacks as run one. The closed
    -- flags ride alongside as a matching list.
    local runs, closed = {}, {}
    for _, r in ipairs(self:WallAllRuns()) do
        table.insert(runs, packPoints(r.pts))
        table.insert(closed, r.closed and "1" or "0")
    end
    self:SaveString("QMWallPts",    table.concat(runs, "|"))
    self:SaveString("QMWallClosed", table.concat(closed, "|"))
    self:SaveString("QMWallType",   tostring(self.WallTypeIdx or 3))
    -- guarded like the rest of this file: a DefSave must never be the thing that breaks
    -- because an optional module did not load
    local gates = {}
    pcall(function() gates = self:GateSaveList() or {} end)
    self:SaveString("QMGates", packPoses(gates))

    -- Only the PLAYER's towers. A tower carrying `group` belongs to somebody else's camp (the
    -- bandit-camp contract builds its watchtowers through the same TowerStations list), and
    -- saving it here means the defence restore rebuilds it on load as one of ours - which put
    -- a FRIENDLY archer on a bandit watchtower alongside the enemy one the camp spawned.
    -- That camp persists through its own contract state and rebuilds its own towers.
    local towers = {}
    for _, st in ipairs(self.TowerStations or {}) do
        if st.placedGround and not st.group then
            table.insert(towers, { x = st.placedGround.x, y = st.placedGround.y,
                                   z = st.placedGround.z, yaw = st.yaw or 0 })
        end
    end
    self:SaveString("QMTowers", packPoses(towers))

    -- Player carts only, for the same reason as the towers above: a cart carrying `group`
    -- belongs to a bandit camp, and persisting it here would have the defence restore rebuild
    -- it as ours, putting friendly archers on a bandit wagon.
    local carts = {}
    for _, st in ipairs(self.ArcherCarts or {}) do
        if st.origin and not st.group then
            table.insert(carts, { x = st.origin.x, y = st.origin.y, z = st.origin.z, yaw = st.yaw or 0 })
        end
    end
    self:SaveString("QMCarts", packPoses(carts))
end

-- Are the stored defences the ones for the camp standing now?
function mercenaries:DefBelongToCurrentCamp()
    local o = self.CampBuildOrigin
    if not o then return false end
    local sx = tonumber(self:LoadString("QMDefX") or "")
    local sy = tonumber(self:LoadString("QMDefY") or "")
    if not (sx and sy) then return false end
    local dx, dy = o.x - sx, o.y - sy
    return (dx * dx + dy * dy) <= (self.DefAnchorEps * self.DefAnchorEps)
end

-- ==== restore ====
-- Called after the camp itself is back up. Rebuilds only when the anchor matches, so
-- a camp pitched somewhere new starts bare.
function mercenaries:DefRestore()
    if not self.CampBuildOrigin then return end
    if not self:DefBelongToCurrentCamp() then
        self:DefForget()
        System.LogAlways("[Defences] new pitch - previous camp's defences left behind")
        return
    end

    local runsRaw, closedRaw = {}, {}
    for chunk in string.gmatch((self:LoadString("QMWallPts") or "") .. "|", "([^|]*)|") do
        table.insert(runsRaw, chunk)
    end
    for chunk in string.gmatch((self:LoadString("QMWallClosed") or "") .. "|", "([^|]*)|") do
        table.insert(closedRaw, chunk)
    end

    self.WallRuns  = {}
    self.WallMarks = {}
    self.WallClosed = false
    local nCorners = 0
    for i, raw in ipairs(runsRaw) do
        local pts = unpackPoints(raw)
        if #pts >= 2 then
            table.insert(self.WallRuns, { pts = pts, closed = (closedRaw[i] == "1") })
            nCorners = nCorners + #pts
        end
    end

    if #self.WallRuns > 0 then
        local ty = tonumber(self:LoadString("QMWallType") or "")
        if ty and self.WallTypes[ty] then
            self.WallTypeIdx = ty
            self.WallSegLen = nil
            self.WallUp  = self.WallTypes[ty].up  or 0
            self.WallLat = self.WallTypes[ty].lat or 0
        end
        pcall(function() self:WallRebuild() end)
    end

    for _, g in ipairs(unpackPoses(self:LoadString("QMGates"))) do
        pcall(function() self:GateBuild({ x = g.x, y = g.y, z = g.z }, g.yaw, g.open == 1) end)
    end

    for _, t in ipairs(unpackPoses(self:LoadString("QMTowers"))) do
        pcall(function() self:TowerBuildStation({ x = t.x, y = t.y, z = t.z }, t.yaw) end)
    end
    for _, c in ipairs(unpackPoses(self:LoadString("QMCarts"))) do
        pcall(function() self:SpawnArcherCart({ x = c.x, y = c.y, z = c.z }, c.yaw) end)
    end

    if self.NavBuild then pcall(function() self:NavBuild() end) end
    pcall(function() if self.NavRefreshPatrolRings then self:NavRefreshPatrolRings() end end)
    pcall(function() if self.WBStart then self:WBStart() end end)
    System.LogAlways(string.format("[Defences] restored: %d wall run(s)/%d corner(s), %d gate(s), %d tower(s), %d cart(s)",
        #self.WallRuns, nCorners, #unpackPoses(self:LoadString("QMGates")),
        #unpackPoses(self:LoadString("QMTowers")), #unpackPoses(self:LoadString("QMCarts"))))
end

function mercenaries.DefRestoreDelayed()
    pcall(function() mercenaries:DefRestore() end)
end

-- ==== teardown ====
-- Remove what is standing (used when a camp is broken or re-pitched elsewhere).
function mercenaries:DefClearWorld()
    pcall(function() self:WallClearAll() end)
    pcall(function() self:GateClearAll() end)
    pcall(function() self:TowerStationClearAll() end)
    pcall(function() self:ClearArcherCarts() end)
end

function mercenaries:DefForget()
    self:SaveString("QMGates", "")
    self:SaveString("QMWallPts", "")
    self:SaveString("QMWallClosed", "0")
    self:SaveString("QMTowers", "")
    self:SaveString("QMCarts", "")
    self:SaveString("QMDefX", "")
    self:SaveString("QMDefY", "")
end

-- A camp was pitched somewhere new: the old defences are gone for good.
function mercenaries:DefOnNewCamp()
    self:DefClearWorld()
    self:DefForget()
    System.LogAlways("[Defences] camp moved - walls, towers and carts left behind")
end

System.AddCCommand("merc_def_save",    "mercenaries:DefSave()",       "Save the current camp's defences")
System.AddCCommand("merc_def_restore", "mercenaries:DefRestore()",    "Rebuild the saved defences")
System.AddCCommand("merc_def_forget",  "mercenaries:DefForget()",     "Forget the saved defences")
System.AddCCommand("merc_def_clear",   "mercenaries:DefClearWorld()", "Remove standing walls, towers and carts")
