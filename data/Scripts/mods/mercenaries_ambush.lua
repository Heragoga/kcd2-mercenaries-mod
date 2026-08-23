-- Ambush authoring toolkit: mark archer spots, melee spots and trigger areas in
-- the world with barrels, then dump them as pasteable Lua. Authoring only - the
-- runtime that fires an ambush comes later and reads AmbushScenes.
-- Workflow and the encounter roadmap: docs/encounters.md.

-- All barrels: they stand upright and read at a distance. The flag marker used
-- before lies flat on the ground and is easy to walk past.
mercenaries.AmbushMarkerModels = {
    archer  = "objects/manmade/weapons/arrows/barrel_arrow_full_closed.cgf",  -- barrel of arrows
    melee   = "objects/manmade/common_furniture/barrels/barrel_a.cgf",
    trigger = "objects/manmade/common_furniture/barrels/barrel_c.cgf",
}

-- Finished scenes, keyed by name. Filled by the dumped tables.
mercenaries.AmbushScenes = mercenaries.AmbushScenes or {}

-- The scene being authored: { name, level, archers = {}, melee = {}, triggers = {} }
mercenaries.AmbushScene = nil
-- Placements not yet saved: { kind, spots = {}, markers = {} }
mercenaries.AmbushPending = nil
-- Markers of everything already saved into the scene, so clear can remove them.
mercenaries.AmbushMarkers = {}
mercenaries.AmbushTestEnemies = {}

mercenaries.AmbushKinds = { archer = true, melee = true, trigger = true }

-- %line hands over the raw rest of the line: stray whitespace, and the console
-- wraps it in quotes, which then survive into the scene name ([""forest_bend""]).
local function trimArg(v)
    if v == nil then return "" end
    local s = tostring(v):gsub("^%s*(.-)%s*$", "%1")
    s = s:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- No level API is exposed to Lua (nothing in the script bindings, nothing in the
-- vanilla scripts), so this stays best-effort. "unknown" is treated as
-- "matches any level" at runtime - a trigger box from the other map simply never
-- contains the player.
local function levelName()
    local n
    for _, get in ipairs({
        function() return System.GetCurrLevelName() end,
        function() return Game.GetLevelName() end,
        function() return System.GetCurrAsyncLevelName() end,
    }) do
        local ok, v = pcall(get)
        if ok and v and v ~= "" then return tostring(v) end
    end
    return "unknown"
end

-- No Physics property at all: that is exactly how the placement ghost gets a
-- visible, walk-through prop (see GhostBuild). Passing an explicit
-- Physics={bPhysicalize=false} table instead is not a recipe the mod uses
-- anywhere, and markers spawned that way came out as the wrong mesh.
function mercenaries:AmbushMarkerSpawn(pos, kind)
    local model = self.AmbushMarkerModels[kind] or self.AmbushMarkerModels.melee
    local ent
    pcall(function()
        ent = System.SpawnEntity({
            class = "BasicEntity",
            name = "MercAmbushMark_" .. tostring(math.random(100000, 999999)),
            position = pos,
            properties = { object_Model = model, bMissionCritical = false,
                           bSaved_by_game = false, bSerialize = false },
        })
    end)
    if not ent then System.LogAlways("[Ambush] marker spawn FAILED for " .. tostring(model)) end
    return ent
end

local function removeMarkers(list)
    for _, id in ipairs(list or {}) do
        pcall(function() System.RemoveEntity(id) end)
    end
end

function mercenaries:AmbushNewScene(name)
    name = trimArg(name)
    if name == "" then name = "ambush_" .. tostring(math.random(100, 999)) end
    self:AmbushClear()
    self.AmbushDisarmed[tostring(name)] = nil   -- a re-authored scene starts armed
    self.AmbushScene = {
        name = tostring(name), level = levelName(),
        archers = {}, melee = {}, triggers = {},
    }
    System.LogAlways("[Ambush] new scene '" .. self.AmbushScene.name .. "' on level " .. self.AmbushScene.level)
    System.LogAlways("[Ambush] merc_ambush_archer / _melee / _trigger to place, merc_ambush_save after each, merc_ambush_dump when done")
end

-- One spec for all three marker kinds: left-click drops a barrel and records the
-- spot, right-click throws away everything placed since the mode started.
function mercenaries:AmbushPlaceSpec(kind)
    return {
        parts = { { model = self.AmbushMarkerModels[kind], x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0 } },
        sink = 0,
        isValid = function() return true end,
        atMax   = function() return false end,
        confirm = function(s, pos)
            local p = { x = pos.x, y = pos.y, z = pos.z }
            local ent = s:AmbushMarkerSpawn(p, kind)
            table.insert(s.AmbushPending.spots, p)
            if ent then table.insert(s.AmbushPending.markers, ent.id) end
            System.LogAlways(string.format("[Ambush] %s spot %d at %.2f %.2f %.2f",
                kind, #s.AmbushPending.spots, p.x, p.y, p.z))
        end,
        onCancel = function(s)
            local n = #(s.AmbushPending and s.AmbushPending.spots or {})
            if s.AmbushPending then
                removeMarkers(s.AmbushPending.markers)
                s.AmbushPending = nil
            end
            System.LogAlways("[Ambush] discarded " .. n .. " unsaved " .. kind .. " spot(s)")
        end,
        info = { placing = 'merc_info_ambush_placing', already = 'merc_info_ambush_already',
                 aim = 'merc_info_ambush_aim', blocked = 'merc_info_ambush_aim',
                 limit = 'merc_info_ambush_aim', raised = 'merc_info_ambush_marked',
                 cancelled = 'merc_info_ambush_cancelled' },
    }
end

function mercenaries:AmbushPlace(kind)
    if not self.AmbushKinds[kind] then return end
    if not self.AmbushScene then
        System.LogAlways("[Ambush] no scene - run merc_ambush_new first")
        return
    end
    self.AmbushPending = { kind = kind, spots = {}, markers = {} }
    if kind == "trigger" then
        System.LogAlways("[Ambush] trigger mode: place FOUR corners per area; place 8 for two areas, and so on")
    end
    self:StartPlacement(self:AmbushPlaceSpec(kind))
end

-- Commit whatever is pending into the scene. Trigger corners are grouped in
-- fours and stored as the box that contains them.
function mercenaries:AmbushSave()
    local pend = self.AmbushPending
    if not (self.AmbushScene and pend and #pend.spots > 0) then
        System.LogAlways("[Ambush] nothing to save")
        return
    end
    self:EndPlacement()

    if pend.kind == "trigger" then
        local n = #pend.spots
        local areas = math.floor(n / 4)
        if areas == 0 then
            System.LogAlways("[Ambush] need 4 corners per area, only " .. n .. " placed - nothing saved")
            return
        end
        for a = 1, areas do
            local minx, miny, maxx, maxy
            for i = (a - 1) * 4 + 1, a * 4 do
                local p = pend.spots[i]
                minx = (minx and math.min(minx, p.x)) or p.x
                maxx = (maxx and math.max(maxx, p.x)) or p.x
                miny = (miny and math.min(miny, p.y)) or p.y
                maxy = (maxy and math.max(maxy, p.y)) or p.y
            end
            table.insert(self.AmbushScene.triggers,
                { minx = minx, miny = miny, maxx = maxx, maxy = maxy })
        end
        if n % 4 ~= 0 then
            System.LogAlways("[Ambush] WARNING: " .. (n % 4) .. " leftover corner(s) ignored")
        end
        System.LogAlways("[Ambush] saved " .. areas .. " trigger area(s), " ..
            #self.AmbushScene.triggers .. " total")
    else
        local dest = self.AmbushScene[pend.kind == "archer" and "archers" or "melee"]
        for _, p in ipairs(pend.spots) do table.insert(dest, p) end
        System.LogAlways("[Ambush] saved " .. #pend.spots .. " " .. pend.kind ..
            " spot(s), " .. #dest .. " total")
    end

    for _, id in ipairs(pend.markers) do table.insert(self.AmbushMarkers, id) end
    self.AmbushPending = nil
end

function mercenaries:AmbushDump()
    local sc = self.AmbushScene
    if not sc then System.LogAlways("[Ambush] no scene"); return end

    local function dumpSpots(label, list)
        System.LogAlways("    " .. label .. " = {")
        for _, p in ipairs(list) do
            System.LogAlways(string.format("        { x = %.2f, y = %.2f, z = %.2f },", p.x, p.y, p.z))
        end
        System.LogAlways("    },")
    end

    System.LogAlways("[Ambush] ---- copy from here into mercenaries_ambush_scenes.lua ----")
    System.LogAlways('mercenaries.AmbushScenes["' .. sc.name .. '"] = {')
    System.LogAlways('    level = "' .. sc.level .. '",')
    dumpSpots("archers", sc.archers)
    dumpSpots("melee", sc.melee)
    System.LogAlways("    triggers = {")
    for _, t in ipairs(sc.triggers) do
        System.LogAlways(string.format("        { minx = %.2f, miny = %.2f, maxx = %.2f, maxy = %.2f },",
            t.minx, t.miny, t.maxx, t.maxy))
    end
    System.LogAlways("    },")
    System.LogAlways("}")
    System.LogAlways("[Ambush] ---- end (" .. #sc.archers .. " archers, " .. #sc.melee ..
        " melee, " .. #sc.triggers .. " triggers) ----")
end

-- Populate the saved spots for real, so the layout can be judged in-game.
function mercenaries:AmbushTest(groupKey)
    local sc = self.AmbushScene
    if not sc then System.LogAlways("[Ambush] no scene"); return end
    groupKey = trimArg(groupKey)
    if groupKey == "" then groupKey = "looter" end
    if not self.EnemyGroups[groupKey] then
        System.LogAlways("[Ambush] unknown group " .. tostring(groupKey)); return
    end

    self:AmbushClearTest()
    local pp = player and player:GetWorldPos()

    local function spawnAt(p, isArcher)
        -- 16 tries: a scene places a dozen units in one frame, and forest ground is
        -- exactly the case that exhausts the spiral.
        local pos = self:FindValidGround({ x = p.x, y = p.y, z = p.z }, p.z, 3.0, 0.5, 16) or p
        local yaw = 0
        if pp then yaw = math.atan2(pp.y - pos.y, pp.x - pos.x) end
        local ent = self:SpawnEnemyAt(groupKey, isArcher, pos, yaw)
        if ent then table.insert(self.AmbushTestEnemies, ent.id) end
    end

    for _, p in ipairs(sc.archers) do spawnAt(p, true) end
    for _, p in ipairs(sc.melee)   do spawnAt(p, false) end
    System.LogAlways(string.format("[Ambush] test: %d %s archer(s) + %d melee spawned",
        #sc.archers, groupKey, #sc.melee))
end

function mercenaries:AmbushClearTest()
    for _, id in ipairs(self.AmbushTestEnemies) do
        pcall(function() System.RemoveEntity(id) end)
    end
    self.AmbushTestEnemies = {}
end

function mercenaries:AmbushClear()
    if self.ActivePlacement then self:EndPlacement() end
    if self.AmbushPending then removeMarkers(self.AmbushPending.markers) end
    removeMarkers(self.AmbushMarkers)
    self.AmbushPending = nil
    self.AmbushMarkers = {}
    self:AmbushClearTest()
    System.LogAlways("[Ambush] markers and test enemies cleared")
end

-- ---------------------------------------------------------------------------
-- Runtime: walking into a trigger box springs that scene.
-- ---------------------------------------------------------------------------
mercenaries.AmbushEnabled = true
mercenaries.AmbushDefaultGroup = "looter"
-- The ambush currently on the ground: { scene =, ents = {}, origin = }
mercenaries.AmbushActive = nil
-- Scenes that have fired and may not fire again until the player walks out.
mercenaries.AmbushDisarmed = {}
-- Leave a live ambush this far behind and it is cleaned up, so one the player
-- ran away from cannot block every future ambush.
mercenaries.AmbushForgetRange = 250.0

local function inBox(t, p)
    return p.x >= t.minx and p.x <= t.maxx and p.y >= t.miny and p.y <= t.maxy
end

-- Everything that can fire right now: the saved scenes PLUS the scene being
-- authored. Without the draft, marking a scene and walking into it does nothing
-- until it has been dumped and pasted into mercenaries_ambush_scenes.lua - which
-- is not what "I placed the barrels and walked in" expects.
function mercenaries:AmbushEligibleScenes()
    local d = self.AmbushScene
    if d and #(d.triggers or {}) > 0 and (#(d.archers or {}) + #(d.melee or {})) > 0 then
        local out = {}
        for name, sc in pairs(self.AmbushScenes) do out[name] = sc end
        out[d.name] = d
        return out
    end
    return self.AmbushScenes
end

function mercenaries:AmbushSceneHasPlayer(sc, pp)
    for _, t in ipairs(sc.triggers or {}) do
        if inBox(t, pp) then return true end
    end
    return false
end

function mercenaries:AmbushAliveCount()
    local n = 0
    for _, e in ipairs((self.AmbushActive and self.AmbushActive.ents) or {}) do
        local alive = false
        pcall(function() alive = (e ~= nil) and self:IsAliveAndWell(e, true) end)
        if alive then n = n + 1 end
    end
    return n
end

function mercenaries:AmbushSpawnScene(name, sc)
    local group = sc.group or self.AmbushDefaultGroup
    if not self.EnemyGroups[group] then group = self.AmbushDefaultGroup end
    local pp = player and player:GetWorldPos()
    local ents, origin = {}, nil

    local function spawnAt(p, isArcher)
        local pos = self:FindValidGround({ x = p.x, y = p.y, z = p.z }, p.z, 3.0, 0.5, 16) or p
        origin = origin or pos
        local yaw = 0
        if pp then yaw = math.atan2(pp.y - pos.y, pp.x - pos.x) end
        local e = self:SpawnEnemyAt(group, isArcher, pos, yaw)
        if e then table.insert(ents, e) end
    end

    for _, p in ipairs(sc.archers or {}) do spawnAt(p, true) end
    for _, p in ipairs(sc.melee or {})   do spawnAt(p, false) end

    self.AmbushActive = { scene = name, ents = ents, origin = origin }
    System.LogAlways(string.format("[Ambush] '%s' sprung: %d %s", name, #ents, group))
end

function mercenaries:AmbushDespawnActive()
    for _, e in ipairs((self.AmbushActive and self.AmbushActive.ents) or {}) do
        pcall(function() System.RemoveEntity(e.id) end)
    end
    self.AmbushActive = nil
end

-- Every second from MonitorLoop. Never fires while markers are being placed.
function mercenaries:AmbushMonitor()
    if not self.AmbushEnabled or self.ActivePlacement then return end
    -- The quartermaster's master switch for uninvited trouble.
    if self.EncountersOn and not self:EncountersOn() then return end
    local pp = player and player:GetWorldPos()
    if not pp then return end

    local scenes = self:AmbushEligibleScenes()

    for name, sc in pairs(scenes) do
        if self.AmbushDisarmed[name] and not self:AmbushSceneHasPlayer(sc, pp) then
            self.AmbushDisarmed[name] = nil
        end
    end

    -- One ambush at a time: it clears when everyone is down, or is cleaned up
    -- once the player has left it far behind.
    if self.AmbushActive then
        if self:AmbushAliveCount() == 0 then
            self.AmbushActive = nil
        else
            local o = self.AmbushActive.origin
            if o then
                local dx, dy = o.x - pp.x, o.y - pp.y
                if (dx * dx + dy * dy) > (self.AmbushForgetRange * self.AmbushForgetRange) then
                    System.LogAlways("[Ambush] '" .. tostring(self.AmbushActive.scene) .. "' left behind - cleaned up")
                    self:AmbushDespawnActive()
                end
            end
            return
        end
    end

    for name, sc in pairs(scenes) do
        if not self.AmbushDisarmed[name] and self:AmbushSceneHasPlayer(sc, pp) then
            self.AmbushDisarmed[name] = true
            self:AmbushSpawnScene(name, sc)
            return
        end
    end
end

-- Why did/didn't it fire? Prints the player position against every trigger box.
function mercenaries:AmbushWhere()
    local pp = player and player:GetWorldPos()
    if not pp then System.LogAlways("[Ambush] no player position"); return end
    System.LogAlways(string.format("[Ambush] player at %.2f %.2f %.2f | triggers %s | placing %s",
        pp.x, pp.y, pp.z, self.AmbushEnabled and "armed" or "OFF",
        self.ActivePlacement and "YES (blocks firing)" or "no"))
    local any = false
    for name, sc in pairs(self:AmbushEligibleScenes()) do
        any = true
        for i, t in ipairs(sc.triggers or {}) do
            System.LogAlways(string.format("[Ambush]   %s box %d x[%.1f..%.1f] y[%.1f..%.1f] -> %s%s",
                name, i, t.minx, t.maxx, t.miny, t.maxy,
                inBox(t, pp) and "INSIDE" or "outside",
                self.AmbushDisarmed[name] and " [disarmed]" or ""))
        end
    end
    if not any then System.LogAlways("[Ambush] no eligible scenes (draft needs saved triggers AND spots)") end
end

function mercenaries:AmbushSetEnabled(v)
    self.AmbushEnabled = (tonumber(trimArg(v)) ~= 0)
    System.LogAlways("[Ambush] triggers " .. (self.AmbushEnabled and "ARMED" or "off"))
end

function mercenaries:AmbushStatus()
    local scenes = self:AmbushEligibleScenes()
    local n = 0
    for _ in pairs(scenes) do n = n + 1 end
    System.LogAlways("[Ambush] " .. n .. " live scene(s), triggers " ..
        (self.AmbushEnabled and "armed" or "off"))
    local draft = self.AmbushScene
    for name, sc in pairs(scenes) do
        System.LogAlways(string.format("[Ambush]   %s: %d archers, %d melee, %d trigger(s), level %s%s%s",
            name, #(sc.archers or {}), #(sc.melee or {}), #(sc.triggers or {}),
            tostring(sc.level or "unknown"),
            (draft and sc == draft) and " [being authored]" or "",
            self.AmbushDisarmed[name] and " [disarmed]" or ""))
    end
    if draft and not scenes[draft.name] then
        System.LogAlways(string.format("[Ambush]   %s: draft NOT live yet - %d archers, %d melee, %d trigger(s); needs at least one trigger and one spot, each merc_ambush_save'd",
            draft.name, #draft.archers, #draft.melee, #draft.triggers))
    end
    if self.AmbushActive then
        System.LogAlways("[Ambush] active: '" .. tostring(self.AmbushActive.scene) ..
            "', " .. self:AmbushAliveCount() .. " still up")
    end
end

-- %line (not %1) - AddCCommand only ever substitutes the whole rest of the line;
-- a %1 body arrives as the literal string "%1". See reference_ccommand_arg_substitution.
System.AddCCommand("merc_ambush_new",     "mercenaries:AmbushNewScene('%line')", "Start a new ambush scene: merc_ambush_new [name]")
System.AddCCommand("merc_ambush_archer",  "mercenaries:AmbushPlace('archer')", "Mark archer spots: left-click places a barrel, right-click discards them all, merc_ambush_save keeps them")
System.AddCCommand("merc_ambush_melee",   "mercenaries:AmbushPlace('melee')",  "Mark melee spots: left-click places a barrel, right-click discards them all, merc_ambush_save keeps them")
System.AddCCommand("merc_ambush_trigger", "mercenaries:AmbushPlace('trigger')","Mark trigger areas: four barrels per area (place 8 for two areas), then merc_ambush_save")
System.AddCCommand("merc_ambush_save",    "mercenaries:AmbushSave()",          "Save the spots placed since the last placement command into the scene")
System.AddCCommand("merc_ambush_dump",    "mercenaries:AmbushDump()",          "Print the scene as pasteable Lua")
System.AddCCommand("merc_ambush_test",    "mercenaries:AmbushTest('%line')",   "Spawn the scene for real: merc_ambush_test [group] (default looter) - archers on archer spots, melee on melee spots")
System.AddCCommand("merc_ambush_test_clear", "mercenaries:AmbushClearTest()",  "Remove the enemies spawned by merc_ambush_test")
System.AddCCommand("merc_ambush_clear",   "mercenaries:AmbushClear()",         "Remove all ambush markers and test enemies")
System.AddCCommand("merc_ambush_status",  "mercenaries:AmbushStatus()",        "List the live ambush scenes and whether triggers are armed")
System.AddCCommand("merc_ambush_where",   "mercenaries:AmbushWhere()",         "Why isn't it firing? Prints your position against every trigger box")
System.AddCCommand("merc_ambush_arm",     "mercenaries:AmbushSetEnabled('%line')", "Arm or disarm live ambush triggers: merc_ambush_arm 0 | 1")
System.AddCCommand("merc_ambush_despawn", "mercenaries:AmbushDespawnActive()", "Remove the ambush currently on the ground")
