-- Siege BUILDER - the in-game placement editor for the siege of Raborsch.
--
-- A sibling of the bandit-camp builder (mercenaries_banditcamp.lua), same feel and same
-- underlying placement engine, but a catalogue built for a siege rather than a camp: men on
-- both sides, field defences to put them behind, and stations you can place more than one of.
--
--   F5  defenders (friendly)      F9   props and furniture
--   F6  attackers (hostile)       F10  stations (carts, taverns, towers)
--   F7  barricades                F11  dump layout
--   F8  tents and the camp circle
--
-- Press a category key to select it; press it again to CYCLE variants. The ghost follows your
-- aim, LEFT CLICK places, RIGHT CLICK takes back the last piece. Both clicks reach us through
-- Player.OnAction, which only fires WITH A WEAPON DRAWN - draw one before building, or use
-- merc_siege_place / merc_siege_undo from the console.
--
-- merc_siege_binds takes the F-keys (they are shared with the camp builder and the route
-- recorder); merc_bcamp_binds and merc_binds_routes take them back.
--
-- See docs/siege-builder.md.

local function sLog(s) System.LogAlways("[Siege] " .. s) end

mercenaries.SiegePieces = {}   -- undo stack: { kind=, label=, ents={id,...}, mark=, pos=, yaw= }
mercenaries.SiegeCat    = 0
mercenaries.SiegeSel    = { 1, 1, 1, 1, 1, 1 }

mercenaries.SiegeTentYaw     = -math.pi / 2
-- Wall pieces are modelled along their length, so unturned they lie across the direction you
-- are facing instead of standing in front of you. One constant: flip the sign if a mesh
-- disagrees.
mercenaries.SiegeBarricadeYaw = math.pi / 2
mercenaries.SiegeUpgradeGhost = "objects/manmade/common_furniture/barrels/barrel_a.cgf"
-- A man is previewed by something man-sized rather than a barrel on the floor, so a line of
-- them reads as a line of men while you are laying it out.
mercenaries.SiegeManGhost    = "objects/manmade/task_specific_props/combat/pavises/pavise_a.cgf"

-- Which enemy group the attacker tools spawn. Cycled by merc_siege_group so the whole
-- besieging force can be one faction without re-picking it per man.
mercenaries.SiegeEnemyGroup  = "sigi"
mercenaries.SiegeEnemyGroups = { "sigi", "bandit", "looter", "knight", "cuman", "prague" }

-- Field defences. Every one of these is vetted (see the barricade notes): purpose-built
-- combat props out of task_specific_props/combat rather than repurposed fencing. A taras is
-- the Hussite war-wagon shield-wall; a pavise is the big standing shield a crossbowman
-- sheltered behind, which is exactly what a placed archer wants in front of him.
local CB = "objects/manmade/task_specific_props/combat/"
local PAL = "objects/manmade/structures/defensive/walls/palisade/"
mercenaries.SiegeBarricades = {
    { label = "taras (wagon wall) a", model = CB .. "tarases/taras_a.cgf" },
    { label = "taras (wagon wall) c", model = CB .. "tarases/taras_c.cgf" },
    { label = "pavise a",             model = CB .. "pavises/pavise_a.cgf" },
    { label = "pavise b",             model = CB .. "pavises/pavise_b.cgf" },
    { label = "palisade wall",        model = PAL .. "palisade_wall_a_v3.cgf" },
    { label = "sharpened stakes",     model = PAL .. "palisade_wall_single_sharp.cgf" },
    -- Closed gates. Both were walked in the barricade gallery, so both are known to exist.
    { label = "closed gate (road barrier)",
      model = "objects/manmade/structures/logistical/barriers/barrier_road_natural_closed.cgf" },
    { label = "closed gate (stick fence)",
      model = "objects/manmade/structures/logistical/fences/fence_sticks_c_gate.cgf" },
    -- Kept last and clearly labelled: it looks superb and belongs to no siege of this size.
    { label = "cannon (unrealistic)", model = CB .. "cannon.cgf" },
}

-- Patrol waypoints. Placed markers, not spawned men: each one appends to the route being
-- built, and the route is dumped for the siege to walk its attacker patrols along. The marker
-- is a stake so the line is readable while you lay it out; it is NOT part of the layout.
mercenaries.SiegeWaypointModel = "objects/manmade/structures/defensive/walls/palisade/palisade_wall_single_sharp.cgf"
mercenaries.SiegeRoutes  = {}   -- { { {x,y,z}, ... }, ... }
mercenaries.SiegeRouteAt = 0    -- which route new waypoints join (0 = none started)

-- The one-click camp circle.
mercenaries.SiegeCircleSeats = 6
mercenaries.SiegeCircleSeatR = 2.4
-- Six of the camp's seven ring slots, so one is always left open as a way in - the merc camp
-- does the same. The RADIUS is the camp's own (CampTentRingRadius), not a number of ours.
mercenaries.SiegeCircleTents = 6

-- ==== catalogue ====
function mercenaries:SiegeCatalogue()
    if self._siegeCat then return self._siegeCat end

    -- Defenders hold ground for the player. The archer is an ordinary static archer with no
    -- tower under him - SpawnStaticArcher places and pins him wherever he is put, so a wall
    -- top or a barricade line works as well as a platform.
    -- Towers and nothing else. Ground archers and footmen were here and are gone: the
    -- defence of Raborsch is fought off the walls, and a defender standing in the open was
    -- only ever going to walk off and get himself killed.
    local defenders = {
        { label = "defender archer tower", station = "tower" },
        { label = "defender archer cart",  station = "cart" },
    }

    -- Static archers, and waypoints for the patrols that walk between them. No sentries and
    -- no captain: the men who move are patrol men, defined by a route rather than placed one
    -- at a time.
    local attackers = {
        { label = "attacker static archer", man = "enemy_archer" },
        { label = "patrol waypoint",        waypoint = true,
          ghost = mercenaries.SiegeWaypointModel },
    }

    local barricades = {}
    for _, b in ipairs(self.SiegeBarricades) do
        barricades[#barricades + 1] = { label = b.label, model = b.model,
                                        yaw = b.yaw or self.SiegeBarricadeYaw }
    end

    -- Tents, and the camp circle: fire plus a ring of seats, the same arrangement the merc
    -- camp lays down, placed as ONE piece so a besieging camp can be dropped in whole.
    local tents = {}
    for i, m in ipairs(self.CampTentVariants or {}) do
        tents[#tents + 1] = { label = "tent " .. i, model = m, yaw = self.SiegeTentYaw }
    end
    if self.CampPlayerTentModel then
        tents[#tents + 1] = { label = "big round tent (player tent)", model = self.CampPlayerTentModel,
                              yaw = self.SiegeTentYaw }
    end
    -- Proven real by walking merc_siege_tents_gallery. Of eighteen candidates only these
    -- rendered - there are NO cuman tents, no yurt, no pavilion and no military tent in the
    -- game data, however plausible the paths look.
    tents[#tents + 1] = { label = "big round tent b", yaw = self.SiegeTentYaw,
                          model = "objects/manmade/structures/living/tents/tent_big_round_b.cgf" }
    tents[#tents + 1] = { label = "big square tent", yaw = self.SiegeTentYaw,
                          model = "objects/manmade/structures/living/tents/tent_big_square_a.cgf" }
    tents[#tents + 1] = { label = "small forest tent c", yaw = self.SiegeTentYaw,
                          model = "objects/manmade/structures/living/tents/tent_small_forest_c.cgf" }
    -- Anything else found with merc_siege_try goes here.
    for _, m in ipairs(self.SiegeExtraTents or {}) do
        tents[#tents + 1] = { label = m:match("([^/]+)%.cgf$") or "tent", model = m,
                              yaw = self.SiegeTentYaw }
    end
    tents[#tents + 1] = { label = "camp circle (fire + seats)", circle = true,
                          ghost = "objects/manmade/task_specific_props/food_processing/cooking/camp_cooking_c_old.cgf" }
    tents[#tents + 1] = { label = "campfire only", fire = true,
                          ghost = "objects/manmade/task_specific_props/food_processing/cooking/camp_cooking_c_old.cgf" }

    -- Props and furniture are the camp builder's, verbatim: the same catalogue, so anything
    -- that can dress a camp can dress a siege line. Duplicating the list would only let the
    -- two drift apart.
    local props = {}
    for _, c in ipairs(self:BCampCatalogue() or {}) do
        if c.name == "furniture" or c.name == "props" then
            for _, it in ipairs(c.items) do props[#props + 1] = it end
        end
    end

    -- Stations. Unlike the camp, these may be placed MORE THAN ONCE - see SiegeBuildStation
    -- for how the singleton guard is stepped around.
    local stations = {
        { label = "supply cart",   multi = "CampFoodCart", build = function(s, p) return s:SpawnCampFoodCart(p) end,  tile = "cart" },
        { label = "tavern / inn",  multi = "CampInn",      build = function(s, p) return s:SpawnCampInn(p) end,       tile = "inn" },
        { label = "hunter's spot", multi = "CampHunt",     build = function(s, p) return s:SpawnCampHunt(p) end,      tile = "hunt" },
    }
    for _, u in ipairs(stations) do u.ghost = u.ghost or self.SiegeUpgradeGhost end

    self._siegeCat = {
        { name = "defenders",  items = defenders },
        { name = "attackers",  items = attackers },
        { name = "barricades", items = barricades },
        { name = "tents",      items = tents },
        { name = "props",      items = props },
        { name = "stations",   items = stations },
    }
    return self._siegeCat
end

local function current(self)
    local cats = self:SiegeCatalogue()
    local c = cats[self.SiegeCat]
    if not c then return nil, nil end
    local i = ((self.SiegeSel[self.SiegeCat] - 1) % #c.items) + 1
    return c, c.items[i]
end

-- ==== the spec ====
function mercenaries:SiegeSpec()
    local cat, item = current(self)
    if not item then return nil end
    local ghostModel = item.ghost or item.model
        or (item.man and self.SiegeManGhost) or self.SiegeUpgradeGhost
    return {
        parts = { { model = ghostModel, x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = item.yaw or 0 } },
        validMaterial = nil,
        sink = 0,
        isValid = function() return true end,
        atMax   = function() return false end,
        confirm = function(s, pos, angle) s:SiegePlace(pos, angle) end,
        onCancel = function(s) s:SiegeUndo() end,
        keepOnCancel = true,
        info = { placing = 'merc_info_tower_placing', already = 'merc_info_tower_already',
                 aim = 'merc_info_tower_aim', blocked = 'merc_info_tower_blocked',
                 limit = 'merc_info_tower_limit', raised = 'merc_info_tower_raised',
                 cancelled = 'merc_info_tower_cancelled' },
    }
end

function mercenaries:SiegeRefresh(quiet)
    local spec = self:SiegeSpec()
    if not spec then return end
    if self.ActivePlacement then self:EndPlacement() end
    self:StartPlacement(spec)
    if not quiet then
        local cat, item = current(self)
        local n = #cat.items
        local i = ((self.SiegeSel[self.SiegeCat] - 1) % n) + 1
        local extra = ""
        if cat.name == "attackers" then extra = "   [" .. tostring(self.SiegeEnemyGroup) .. "]" end
        sLog(string.format("%s  %d/%d  %s%s", cat.name, i, n, item.label, extra))
    end
end

function mercenaries:SiegePick(catIdx)
    if self.SiegeCat == catIdx then
        self.SiegeSel[catIdx] = self.SiegeSel[catIdx] + 1
    else
        self.SiegeCat = catIdx
    end
    self:SiegeRefresh()
end

-- ==== men ====
-- One placed man, either side. Defenders are the player's static archers / mercs; attackers
-- come out of the enemy-group system so they carry the right souls, gear and hostility.
-- One placed attacker archer. Comes out of the enemy-group system so he carries the right
-- soul, gear and hostility. No `elevated`: he is on whatever the player stood him on, and
-- melee should engage him normally.
function mercenaries:SiegeSpawnMan(item, pos, yaw)
    local ents = {}
    local e = self:SpawnStaticArcher(pos, "hostile", yaw, self.SiegeEnemyGroup)
    if e then table.insert(ents, e.id) end
    return ents
end

-- ==== patrol waypoints ====
-- A waypoint joins the route currently being built, starting one if there is none. The marker
-- is a visible stake so the line reads while you lay it out - it is NOT part of the layout and
-- SiegeDump prints the coordinates separately.
function mercenaries:SiegeWaypoint(pos)
    if self.SiegeRouteAt == 0 then self:SiegePatrolNew(true) end
    local r = self.SiegeRoutes[self.SiegeRouteAt]
    local g = self:CampSnapToGround(pos)
    table.insert(r, { x = g.x, y = g.y, z = g.z })
    sLog(string.format("route %d: waypoint %d", self.SiegeRouteAt, #r))
    return r
end

function mercenaries:SiegePatrolNew(quiet)
    table.insert(self.SiegeRoutes, {})
    self.SiegeRouteAt = #self.SiegeRoutes
    if not quiet then sLog("started patrol route " .. self.SiegeRouteAt) end
end

-- ==== stations ====
-- The camp's upgrades are SINGLETONS: each one begins `if self.CampFoodCart then return true
-- end`, so a second call quietly does nothing. A siege wants a row of supply carts and more
-- than one tavern, so the field is cleared before each build and again afterwards. Undo does
-- not use the upgrade's own teardown for these (it would only know about the newest one) -
-- it uses the CampEntities watermark, which is exact.
function mercenaries:SiegeBuildStation(item, pos, yaw)
    local restore, had
    if item.tile then
        self.CampStationTiles = self.CampStationTiles or {}
        had, restore = true, self.CampStationTiles[item.tile]
        self.CampStationTiles[item.tile] = { x = pos.x, y = pos.y, z = pos.z, ang = yaw }
    end

    local prev
    if item.multi then prev = self[item.multi]; self[item.multi] = nil end

    local mark = #(self.CampEntities or {})
    local ok, res = pcall(function() return item.build(self, pos, yaw) end)

    if item.multi then self[item.multi] = nil end   -- free the slot for the next one
    if had then self.CampStationTiles[item.tile] = restore end

    if not ok or res == false then
        if item.multi then self[item.multi] = prev end
        sLog(item.label .. " could not be built here")
        return nil
    end
    return mark
end

-- ==== placing ====
function mercenaries:SiegePlace(pos, yaw)
    local cat, item = current(self)
    if not item then return end
    pos = pos or self.PlacePos
    yaw = (yaw or self.PlaceAngle or 0) + (item.yaw or 0)
    if not pos then sLog("look at solid ground first"); return end

    local ents = {}

    if item.waypoint then
        local r = self:SiegeWaypoint(pos)
        self:SpawnCampPropModel(self.SiegeWaypointModel, self:CampSnapToGround(pos), 0, "SiegeWp", ents)
        table.insert(self.SiegePieces, { kind = "waypoint", label = item.label, ents = ents,
                                         pos = pos, yaw = 0, route = self.SiegeRouteAt, at = #r })
        return

    elseif item.man then
        local made = self:SiegeSpawnMan(item, pos, yaw)
        if not made then return end
        ents = made
        table.insert(self.SiegePieces, { kind = "attacker", label = item.label, ents = ents,
                                         pos = pos, yaw = yaw, group = self.SiegeEnemyGroup })
        sLog("placed " .. item.label); return

    elseif item.station then
        -- Defender stations: the player's own, so no group is passed and their archers are
        -- friendly exactly as a camp tower's are.
        if item.station == "tower" then
            local before = #(self.TowerStations or {})
            self:SpawnTowerStation(pos, yaw)
            if #(self.TowerStations or {}) <= before then sLog("tower refused here"); return end
            table.insert(self.SiegePieces, { kind = "tower", label = item.label, station = "tower",
                                             pos = pos, yaw = yaw })
        else
            local before = #(self.ArcherCarts or {})
            self:SpawnArcherCart(pos, yaw)
            if #(self.ArcherCarts or {}) <= before then sLog("cart refused here"); return end
            table.insert(self.SiegePieces, { kind = "cart", label = item.label, station = "cart",
                                             pos = pos, yaw = yaw })
        end
        sLog("placed " .. item.label); return

    elseif item.build then
        local mark = self:SiegeBuildStation(item, pos, yaw)
        if not mark then return end
        table.insert(self.SiegePieces, { kind = "station", label = item.label, pos = pos, yaw = yaw,
                                         mark = mark })
        sLog("placed " .. item.label); return

    elseif item.circle then
        -- A whole camp in one click: fire in the middle, a ring of log seats around it, then
        -- tents further out with a bed inside each. It used to be only the fire and the logs,
        -- which is a fire pit rather than a camp.
        pcall(function() self:SpawnCampFirePrefab(pos, 0, nil, "SiegeProp_", ents) end)

        local seat = self.CampModels and self.CampModels.Log
        if seat then
            for k = 1, self.SiegeCircleSeats do
                local a = (k / self.SiegeCircleSeats) * math.pi * 2
                local sp = { x = pos.x + math.cos(a) * self.SiegeCircleSeatR,
                             y = pos.y + math.sin(a) * self.SiegeCircleSeatR, z = pos.z }

                self:SpawnCampFurnitureSO(seat, self:CampSnapToGround(sp), a + math.pi,
                                          "SiegeSeat", self.CampChairSO, nil, ents)
            end
        end

        -- Tents and beds EXACTLY as SpawnMercCamp lays them: CampRingPos for the slot, then
        -- `ringAngle + pi + CampTentFacingFix` for the facing, and the bed placed off the
        -- tent through CampRelativeOffset(CampBedOffset). Rolling this by hand is what had
        -- them facing outward - the mesh's own convention is in CampTentFacingFix, and it is
        -- not the same quarter turn the loose-tent catalogue uses.
        -- The ring is sized for CampClusterTentRingSlots (7) but only SiegeCircleTents are
        -- placed, so a slot is always left open as a way in - the camp does the same.
        local tents = self.CampTentVariants or {}
        local bed   = self.CampModels and self.CampModels.Bed
        for k = 1, self.SiegeCircleTents do
            local tp, ringAngle = self:CampRingPos(pos, self.CampTentRingRadius, k,
                                                   self.CampClusterTentRingSlots, yaw)
            tp = self:CampSnapToGround(tp)
            local tAngle = ringAngle + math.pi + self.CampTentFacingFix
            if #tents > 0 then
                self:SpawnCampPropModel(tents[math.random(#tents)], tp, tAngle, "SiegeProp", ents)
            end
            if bed then
                local bp, bAngle = self:CampRelativeOffset(tp, tAngle, self.CampBedOffset)
                bp = self:CampSnapToGround(bp)
                self:SpawnCampFurnitureSO(bed, bp, bAngle, "SiegeBed", self.CampBedSO, nil, ents)
            end
        end

    elseif item.fire then
        pcall(function() self:SpawnCampFirePrefab(pos, 0, nil, "SiegeProp_", ents) end)

    elseif item.stash then
        pcall(function()
            local e = System.SpawnEntity({
                class = "Stash",
                name = "SiegeChest_" .. tostring(math.random(100000, 999999)),
                position = self:CampSnapToGround(pos),
                orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
                properties = { object_Model = item.stash, bSaved_by_game = false },
            })
            if e then
                pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw }) end)
                table.insert(ents, e.id)
            end
        end)

    elseif item.so then
        self:SpawnCampFurnitureSO(item.model, pos, yaw, "SiegeFurn", item.so, nil, ents)

    elseif item.model then
        self:SpawnCampPropModel(item.model, pos, yaw, "SiegeProp", ents)
        if item.light then
            pcall(function()
                local e = System.SpawnEntity({
                    class = "Light",
                    name = "SiegeLight_" .. tostring(math.random(100000, 999999)),
                    position = { x = pos.x, y = pos.y, z = pos.z + (item.lightZ or 1.0) },
                    properties = item.light,
                })
                if e then table.insert(ents, e.id) end
            end)
        end
    else
        sLog("nothing to place for " .. tostring(item.label)); return
    end

    local kind = (cat.name == "barricades") and "barricade"
              or (cat.name == "tents") and "tent" or "prop"
    table.insert(self.SiegePieces, { kind = kind, label = item.label, ents = ents, pos = pos, yaw = yaw })
    sLog("placed " .. item.label)
end

function mercenaries:SiegeUndo()
    local last = table.remove(self.SiegePieces)
    if not last then sLog("nothing to undo"); return end

    if last.kind == "waypoint" then
        local r = self.SiegeRoutes[last.route]
        if r then table.remove(r) end
        for _, id in ipairs(last.ents or {}) do pcall(function() System.RemoveEntity(id) end) end
        sLog("undid waypoint " .. tostring(last.at) .. " of route " .. tostring(last.route))
        return
    end

    if last.station == "tower" then
        local st = table.remove(self.TowerStations or {})
        if st then pcall(function() self:TowerStationClearOne(st) end) end
    elseif last.station == "cart" then
        local st = table.remove(self.ArcherCarts or {})
        if st then pcall(function() self:ArcherCartClearOne(st) end) end
    elseif last.kind == "station" then
        -- Watermark only. These are placed many times over, so the upgrade's own teardown
        -- would remove whichever one it happens to be holding rather than the last placed.
        local ents = self.CampEntities or {}
        for i = #ents, (last.mark or #ents) + 1, -1 do
            pcall(function() System.RemoveEntity(ents[i]) end)
            table.remove(ents, i)
        end
    else
        for _, id in ipairs(last.ents or {}) do
            -- A placed man may be a static archer, which has bookkeeping of its own.
            pcall(function()
                local e = System.GetEntity(id)
                if e and self.RemoveStaticArcher then self:RemoveStaticArcher(e) end
            end)
            pcall(function() System.RemoveEntity(id) end)
        end
    end
    sLog("undid " .. tostring(last.label))
end

-- ==== site commands ====
function mercenaries:SiegeNew()
    for _, p in ipairs(self.SiegePieces) do
        for _, id in ipairs(p.ents or {}) do pcall(function() System.RemoveEntity(id) end) end
    end
    self.SiegePieces = {}
    self.SiegeRoutes, self.SiegeRouteAt = {}, 0
    pcall(function() if self.TowerStationClearAll then self:TowerStationClearAll() end end)
    pcall(function() if self.ClearArcherCarts then self:ClearArcherCarts() end end)
    if self.SiegeCat == 0 then self.SiegeCat = 1 end
    self:SiegeRefresh()
    sLog("new siege - cleared, builder on")
end

function mercenaries:SiegeGroup(name)
    name = (name or ""):gsub("%s+", "")
    if name == "" then
        -- No argument: step to the next one.
        local list, at = self.SiegeEnemyGroups, 1
        for i, g in ipairs(list) do if g == self.SiegeEnemyGroup then at = i break end end
        name = list[(at % #list) + 1]
    end
    if not self.EnemyGroups[name] then
        sLog("no such group: " .. name .. " (" .. table.concat(self.SiegeEnemyGroups, ", ") .. ")")
        return
    end
    self.SiegeEnemyGroup = name
    sLog("attackers are now: " .. name)
end

-- Asset probe. The mod only knows the meshes it already uses, so this drops ANY .cgf at your
-- aim point to find out whether it exists: it renders, it is real; it comes up pink or
-- invisible, it is not. Anything worth keeping goes in SiegeExtraTents (or straight into a
-- catalogue). This is how the barricade list was picked, and it beats guessing paths.
--   merc_siege_try objects/manmade/structures/living/tents/tent_big_round_b.cgf
mercenaries.SiegeExtraTents = {}

function mercenaries:SiegeTry(path)
    path = (path or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if path == "" then
        sLog("merc_siege_try <model path>  e.g. objects/manmade/structures/living/tents/tent_big_a.cgf")
        return
    end
    local pos = self.PlacePos
    if not pos then
        pcall(function()
            local p = player:GetWorldPos()
            local a = player:GetWorldAngles()
            pos = { x = p.x + math.cos(a.z) * 4, y = p.y + math.sin(a.z) * 4, z = p.z }
        end)
    end
    if not pos then sLog("no position - look at some ground"); return end
    local ents = {}
    self:SpawnCampPropModel(path, self:CampSnapToGround(pos), self.PlaceAngle or 0, "SiegeTry", ents)
    if #ents == 0 then sLog("nothing spawned - the path is wrong"); return end
    table.insert(self.SiegePieces, { kind = "prop", label = path, ents = ents, pos = pos, yaw = 0 })
    sLog("tried " .. path .. " - if it rendered it is real; right-click undoes it")
end

-- Tent GALLERY. There are no cuman (or any other big) tents referenced anywhere in the mod,
-- and guessing a path silently places nothing, so these are laid out in a row to be walked
-- past: whatever renders exists. Exactly how the barricade list was vetted.
-- The list is candidates, NOT verified assets - gaps in the row are meshes that do not exist.
local TT = "objects/manmade/structures/living/tents/"
mercenaries.SiegeTentCandidates = {
    -- ROUND 3: every one of these was grepped out of the reference data, not invented.
    -- CAUTION: that data is a SUBSET of the game, not the whole of it - tent_small_forest_c
    -- renders in game and appears nowhere in it. So absence from a grep is NOT proof a mesh
    -- is missing, and the gallery stays the only real arbiter.
    TT .. "tent_big_square_b_hungarien_green.cgf",   -- Hungarian green - the closest thing to a cuman tent, and apt
    TT .. "tent_big_fancy_a.cgf",   -- the pavilion
    TT .. "fancytentgypsy.cgf",
    TT .. "gypsycamp_tent_b.cgf",
    TT .. "tent_big_square_a_rope_a.cgf",
    TT .. "tent_big_square_b_hanger_b.cgf",
    TT .. "tent_big_square_b_rope_a.cgf",
    TT .. "tent_big_rectangle_a_nocloth.cgf",
    TT .. "tent_big_round_a_curtain_a.cgf",
    TT .. "tent_big_round_a_curtain_b.cgf",
    TT .. "tent_big_round_b_rope_a.cgf",
    TT .. "tent_center_column_a.cgf",
    TT .. "tent_burned_a.cgf",   -- burned out - siege damage
    TT .. "tent_burned_b.cgf",
    TT .. "tent_burned_d.cgf",
    TT .. "tent_small_b_damaged.cgf",
    TT .. "tent_big_round_a_construction_a.cgf",   -- half-struck
    TT .. "canopy_tent_big_a.cgf",
    TT .. "canopy_small_rustic_a.cgf",
    TT .. "canopy_tent_cover_a.cgf",
    TT .. "canopy_tent_cover_a_merlon.cgf",
    TT .. "canopy_tent_cover_a_nosticks.cgf",
    TT .. "tent_big_a.cgf",   -- seen in one sweep only
}
mercenaries.SiegeTentGalleryEnts = {}

function mercenaries:SiegeTentGallery(spacing)
    self:SiegeTentGalleryClear()
    if not player then return end
    local o, ang
    pcall(function() o = player:GetWorldPos(); ang = player:GetWorldAngles() end)
    if not o then sLog("no player position"); return end
    local yaw = (ang and ang.z) or 0
    local step = tonumber(spacing) or 6.0
    -- Laid out to the player's LEFT, walking away, so the row is in front of you.
    local rx, ry = -math.sin(yaw), math.cos(yaw)
    for i, m in ipairs(self.SiegeTentCandidates) do
        local p = self:CampSnapToGround({ x = o.x + math.cos(yaw) * 6 + rx * (i - 1) * step,
                                          y = o.y + math.sin(yaw) * 6 + ry * (i - 1) * step,
                                          z = o.z })
        self:SpawnCampPropModel(m, p, yaw + self.SiegeTentYaw, "SiegeGallery",
                                self.SiegeTentGalleryEnts)
        sLog(string.format("  %2d  %s", i, m:match("([^/]+)%.cgf$") or m))
    end
    sLog("walk the row - whatever RENDERED exists. Tell me the numbers and I will add them.")
    sLog("merc_siege_tents_clear removes the row")
end

function mercenaries:SiegeTentGalleryClear()
    for _, id in ipairs(self.SiegeTentGalleryEnts or {}) do
        pcall(function() System.RemoveEntity(id) end)
    end
    self.SiegeTentGalleryEnts = {}
end

-- Let the placed men fight. Until this is run they all hold fire, which is what makes the
-- siege possible to lay out at all.
function mercenaries:SiegeGo()
    self.SiegePeace = false
    sLog("peace off - everyone placed is live")
end

function mercenaries:SiegeHold()
    self.SiegePeace = true
    sLog("peace on - every static archer holds fire")
end

function mercenaries:SiegeDump()
    if #self.SiegePieces == 0 then sLog("nothing placed yet"); return end
    local o = self.SiegePieces[1].pos
    sLog("---- " .. #self.SiegePieces .. " piece(s) ----")
    sLog("-- paste into mercenaries_raborsch.lua under RaborschLayouts")
    sLog("mercenaries.RaborschLayouts.RENAME_ME = {")
    for _, p in ipairs(self.SiegePieces) do
        if p.pos and p.kind ~= "waypoint" then
            local g = p.group and string.format(', group = "%s"', p.group) or ""
            sLog(string.format('    { kind = "%s", what = "%s", x = %.2f, y = %.2f, z = %.2f, yaw = %.4f%s },',
                 p.kind, p.label, p.pos.x - o.x, p.pos.y - o.y, p.pos.z - o.z, p.yaw or 0, g))
        end
    end
    sLog("}")

    -- Patrol routes. Absolute, not relative: a patrol walks real ground and the whole point of
    -- placing the waypoints by hand is that they sit where the ground allows.
    local nRoutes = 0
    for _, r in ipairs(self.SiegeRoutes or {}) do if #r > 1 then nRoutes = nRoutes + 1 end end
    if nRoutes > 0 then
        sLog("-- patrol routes (absolute, paste under RaborschPatrols):")
        sLog("mercenaries.RaborschPatrols.RENAME_ME = {")
        for ri, r in ipairs(self.SiegeRoutes or {}) do
            if #r > 1 then
                sLog(string.format('    { name = "patrol%d", pts = {', ri))
                for _, w in ipairs(r) do
                    sLog(string.format('        { x = %.2f, y = %.2f, z = %.2f },', w.x, w.y, w.z))
                end
                sLog("    }},")
            end
        end
        sLog("}")
    end
    local lvl = "unknown"
    for _, get in ipairs({ function() return System.GetCurrLevelName() end,
                           function() return Game.GetLevelName() end,
                           function() return System.GetCurrAsyncLevelName() end }) do
        local ok, v = pcall(get)
        if ok and v and v ~= "" then lvl = tostring(v); break end
    end
    sLog("-- and its site row:")
    sLog(string.format('    { name = "raborsch", level = "%s", x = %.2f, y = %.2f, z = %.2f, yaw = 0, layout = "RENAME_ME" },',
         lvl, o.x, o.y, o.z))
end

function mercenaries:SiegeStop()
    if self.ActivePlacement then self:EndPlacement() end
    self.SiegeCat = 0
    sLog("builder off")
end

function mercenaries:SiegeList()
    local cats = self:SiegeCatalogue()
    local c = cats[self.SiegeCat]
    if not c then sLog("no category selected - press F5-F10"); return end
    local sel = ((self.SiegeSel[self.SiegeCat] - 1) % #c.items) + 1
    sLog(c.name .. ":")
    for i, it in ipairs(c.items) do
        sLog(string.format("  %s%d  %s", (i == sel) and "> " or "  ", i, it.label))
    end
end

function mercenaries:SiegeHelp()
    sLog("F5 defender towers/carts   F6 attacker archers + patrol waypoints")
    sLog("F7 barricades & gates   F8 tents/camp circle")
    sLog("F9 props & furniture   F10 stations (carts, taverns, towers)   F11 dump")
    sLog("  press the same key again to cycle variants; the ghost follows your aim")
    sLog("LEFT CLICK places, RIGHT CLICK undoes - both need a weapon drawn (engine input map)")
    sLog("merc_siege_group [name] picks who the attackers are (" .. table.concat(mercenaries.SiegeEnemyGroups, ", ") .. ")")
    sLog("merc_siege_patrol starts a new patrol route - waypoints on F6 join the current one")
    sLog("merc_siege_try <path> drops any .cgf to see whether it exists")
    sLog("merc_siege_tents_gallery lays out every candidate big tent in a row")
    sLog("PEACE is ON while building - merc_siege_go lets them fight, merc_siege_hold stops them")
    sLog("merc_siege_new clears   merc_siege_list shows the category   merc_siege_off leaves")
    sLog("merc_bcamp_binds gives the F-keys back to the camp builder")
end

-- DISABLED. F5-F11 belong to the Aleksej lodging editor (mercenaries_aleksej.lua) while that
-- room is being authored. Every merc_siege_* command still works from the console - only the
-- key grab is off.
--
-- TO RESTORE: uncomment the block below, and point the load hook in mercenaries.lua back at
-- SiegeBinds instead of AlxBinds.
function mercenaries:SiegeBinds(quiet)
    self.SiegePeace = true
    aLogSiegeBindsOff()
    -- self:EditorOwner("siege")
    -- self:EditorsStopExcept("siege")
    -- pcall(function()
    --     System.ExecuteCommand("bind f5 merc_siege_defenders")
    --     System.ExecuteCommand("bind f6 merc_siege_attackers")
    --     System.ExecuteCommand("bind f7 merc_siege_barricades")
    --     System.ExecuteCommand("bind f8 merc_siege_tents")
    --     System.ExecuteCommand("bind f9 merc_siege_props")
    --     System.ExecuteCommand("bind f10 merc_siege_stations")
    --     System.ExecuteCommand("bind f11 merc_siege_dump")
    -- end)
    -- if not quiet then self:SiegeHelp() end
end

function aLogSiegeBindsOff()
    sLog("key binding is OFF for the siege builder - F5-F11 belong to the lodging editor.")
    sLog("  every merc_siege_* command still works from the console")
end

mercenaries:DevCommand("merc_siege_defenders",  "mercenaries:SiegePick(1)", "F5 - defenders")
mercenaries:DevCommand("merc_siege_attackers",  "mercenaries:SiegePick(2)", "F6 - attackers")
mercenaries:DevCommand("merc_siege_barricades", "mercenaries:SiegePick(3)", "F7 - barricades")
mercenaries:DevCommand("merc_siege_tents",      "mercenaries:SiegePick(4)", "F8 - tents and the camp circle")
mercenaries:DevCommand("merc_siege_props",      "mercenaries:SiegePick(5)", "F9 - props and furniture")
mercenaries:DevCommand("merc_siege_stations",   "mercenaries:SiegePick(6)", "F10 - carts, taverns, towers")
mercenaries:DevCommand("merc_siege_dump",       "mercenaries:SiegeDump()",  "F11 - print the layout")
mercenaries:DevCommand("merc_siege_tents_gallery", "mercenaries:SiegeTentGallery(%line)", "Lay out every candidate tent mesh in a row: whatever renders exists")
mercenaries:DevCommand("merc_siege_tents_clear",   "mercenaries:SiegeTentGalleryClear()", "Remove the tent gallery")
mercenaries:DevCommand("merc_siege_go",        "mercenaries:SiegeGo()",   "Let the placed men fight (peace off)")
mercenaries:DevCommand("merc_siege_hold",      "mercenaries:SiegeHold()", "Make everyone hold fire again (peace on)")
mercenaries:DevCommand("merc_siege_patrol",     "mercenaries:SiegePatrolNew()", "Start a NEW patrol route; waypoints placed after this join it")
mercenaries:DevCommand("merc_siege_new",        "mercenaries:SiegeNew()",   "Clear the site and start over")
mercenaries:DevCommand("merc_siege_place",      "mercenaries:SiegePlace()", "Place at your aim point (console alternative to left-click)")
mercenaries:DevCommand("merc_siege_undo",       "mercenaries:SiegeUndo()",  "Take back the last piece")
mercenaries:DevCommand("merc_siege_group",      "mercenaries:SiegeGroup(%line)", "Who the attackers are: merc_siege_group sigi|bandit|looter|knight|cuman|prague")
mercenaries:DevCommand("merc_siege_try",        "mercenaries:SiegeTry(%line)", "Drop any .cgf at your aim point to see if it exists: merc_siege_try <path>")
mercenaries:DevCommand("merc_siege_list",       "mercenaries:SiegeList()",  "List the current category")
mercenaries:DevCommand("merc_siege_help",       "mercenaries:SiegeHelp()",  "Key map and commands")
mercenaries:DevCommand("merc_siege_off",        "mercenaries:SiegeStop()",  "Leave the editor")
mercenaries:DevCommand("merc_siege_binds",      "mercenaries:SiegeBinds()", "Give F5-F11 to the siege builder")
