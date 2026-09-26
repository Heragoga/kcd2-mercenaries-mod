-- Prefabs: a knot of props arranged in Blender, spawned as one thing.
--
-- The layout is done in the Blender workspace (docs/blender-workspace.md): drag props
-- out of the KCD2 asset library, place them, and `prefab_export.py` writes the result to
-- data/Scripts/mods/prefabs/<name>.lua as a list of model + position + rotation. Nothing
-- in that folder is hand-written.
--
-- A prefab is stored in ITS OWN space - the export measures everything from an Empty
-- called `origin`, or from the world origin if there is none - so spawning it is a
-- rotate-and-add: the whole arrangement drops in at any point, facing any way.
--
-- Pieces are spawned as `mercenaries_Prop` (static, physicalised) through the house
-- spawner, so they clear the same way every other camp prop does and never serialise
-- into a save; a prefab is rebuilt, not loaded.

mercenaries.Prefabs = mercenaries.Prefabs or {}
mercenaries.PrefabEnts = mercenaries.PrefabEnts or {}

local function pLog(msg) System.LogAlways("[Prefab] " .. tostring(msg)) end

local function pArg(v)
    local t = tostring(v or ""):gsub("^%s*(.-)%s*$", "%1")
    return (t:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1"))
end

-- Generated prefabs are one file each, loaded the first time they are asked for, so
-- adding one to the mod is dropping a file in - there is no list to keep up to date.
function mercenaries:PrefabLoad(name)
    if self.Prefabs[name] then return true end
    pcall(function() Script.LoadScript("Scripts/mods/prefabs/" .. name .. ".lua") end)
    return self.Prefabs[name] ~= nil
end

function mercenaries:PrefabNames()
    local out = {}
    for k in pairs(self.Prefabs) do table.insert(out, k) end
    table.sort(out)
    return out
end

-- Place one prefab. `origin` is where its own origin lands, `yaw` which way it faces.
function mercenaries:SpawnPrefab(name, origin, yaw, prefix, trackList)
    if not self:PrefabLoad(name) then
        pLog("no prefab called '" .. tostring(name) .. "'")
        return 0
    end
    local parts = self.Prefabs[name]
    local list = trackList or self.PrefabEnts
    local c, s = math.cos(yaw or 0), math.sin(yaw or 0)
    local n = 0
    for _, p in ipairs(parts) do
        local pos = { x = origin.x + p.x * c - p.y * s,
                      y = origin.y + p.x * s + p.y * c,
                      z = origin.z + (p.z or 0) }
        if self.CampSnapToGround and p.snap then pos = self:CampSnapToGround(pos) end
        local scale = nil
        if p.sx then scale = { x = p.sx, y = p.sy or p.sx, z = p.sz or p.sx } end
        local ent = self:SpawnHousePart(p.m, pos, p.rx or 0, p.ry or 0,
                                        (p.rz or 0) + (yaw or 0), scale,
                                        prefix or "MercPrefab_", list)
        if ent then n = n + 1 end
    end
    pLog(string.format("%s: %d/%d piece(s) at %.1f %.1f", name, n, #parts,
                       origin.x, origin.y))
    return n
end

function mercenaries:PrefabClear()
    local n = 0
    for _, id in ipairs(self.PrefabEnts or {}) do
        if pcall(function() System.RemoveEntity(id) end) then n = n + 1 end
    end
    self.PrefabEnts = {}
    pLog("cleared " .. n .. " piece(s)")
end

-- ==== commands ====
function mercenaries:PrefabSpawnHere(line)
    local name = pArg(line)
    if name == "" then return self:PrefabList() end
    if not player then return end
    local o = player:GetWorldPos()
    local ang
    pcall(function() ang = player:GetWorldAngles() end)
    self:SpawnPrefab(name, o, (ang and ang.z) or 0)
end

function mercenaries:PrefabList()
    local names = self:PrefabNames()
    if #names == 0 then
        pLog("nothing loaded yet - merc_prefab_spawn <name> loads it by name")
        pLog("prefabs live in data/Scripts/mods/prefabs/, written by the Blender export")
        return
    end
    pLog("loaded prefabs:")
    for _, n in ipairs(names) do
        pLog(string.format("  %-24s %d piece(s)", n, #self.Prefabs[n]))
    end
end

mercenaries:DevCommand("merc_prefab_spawn", "mercenaries:PrefabSpawnHere('%line')",
    "Spawn a prefab where you stand, facing the way you face: merc_prefab_spawn <name>")
mercenaries:DevCommand("merc_prefab_list", "mercenaries:PrefabList()",
    "List the prefabs already loaded")
mercenaries:DevCommand("merc_prefab_clear", "mercenaries:PrefabClear()",
    "Remove every prefab piece spawned this session")
