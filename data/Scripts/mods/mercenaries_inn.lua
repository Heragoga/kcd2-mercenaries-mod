-- Makeshift inn upgrade (WIP): a camp tavern corner - long tables with log
-- benches, wine/beer barrels, jugs and tankards. Console-only for now: a prop
-- catalogue grid (merc_inn_props) plus the composition + live tuner below. Mirrors
-- the hunting station (mercenaries_hunting.lua); see it for the rig details.

-- Candidate models, grouped. `n` = short label logged on spawn; `m` = .cgf path.
mercenaries.InnProps = {
    -- Tables
    { n = "table_160",    m = "objects/manmade/common_furniture/tables/table_shabby_d_160_rough.cgf" },
    { n = "table_80",     m = "objects/manmade/common_furniture/tables/table_shabby_d_80_rough.cgf" },
    { n = "table_fancy",  m = "objects/manmade/common_furniture/tables/table_fancy_a.cgf" },

    -- Seating (log benches / stool)
    { n = "bench_log_a",  m = "objects/manmade/common_furniture/benches/low/bench_log_a.cgf" },
    { n = "bench_log_b",  m = "objects/manmade/common_furniture/benches/low/bench_log_b.cgf" },
    { n = "bench_rustic", m = "objects/manmade/common_furniture/benches/low/bench_rustic_210_a.cgf" },
    { n = "log_stool",    m = "objects/manmade/common_furniture/chairs/low/chair_trunk_c.cgf" },

    -- Barrels (storage + a spigot serving cask)
    { n = "barrel_a",     m = "objects/manmade/common_furniture/barrels/barrel_a.cgf" },
    { n = "barrel_b",     m = "objects/manmade/common_furniture/barrels/barrel_b.cgf" },
    { n = "barrel_beer",  m = "objects/manmade/common_furniture/barrels/barrel_beer.cgf" },
    { n = "barrel_spigot",m = "objects/manmade/common_furniture/barrels/barrel_small_spigot_plug.cgf" },

    -- Jugs / drinkware
    { n = "jug_mead",     m = "objects/manmade/task_specific_props/household/cooking_eating/jugs/jug_b_mead.cgf" },
    { n = "jug_metal",    m = "objects/manmade/task_specific_props/household/cooking_eating/jugs/jug_metal_a.cgf" },
    { n = "jug_f",        m = "objects/manmade/task_specific_props/household/cooking_eating/jugs/jug_f.cgf" },
    { n = "tin_jug",      m = "objects/manmade/task_specific_props/household/cooking_eating/jugs/tin_jug_01.cgf" },
    { n = "jug_pewter",   m = "objects/manmade/task_specific_props/household/cooking_eating/jugs/jug_pewter_small_copper.cgf" },
    { n = "tankard",      m = "objects/manmade/task_specific_props/household/cooking_eating/tankards/tankard_a.cgf" },
    { n = "cup",          m = "objects/manmade/task_specific_props/household/cooking_eating/cups/cup_a.cgf" },
    { n = "cup_tin",      m = "objects/manmade/task_specific_props/household/cooking_eating/cups/cup_tin_a.cgf" },

    -- Food on the table
    { n = "bowl_goulash", m = "objects/manmade/food/food/mushes/bowl_goulash.cgf" },
    { n = "bowl_kielbasa",m = "objects/manmade/food/food/bowl_kielbasas_raw_full.cgf" },
    { n = "bowl_g",       m = "objects/manmade/task_specific_props/household/cooking_eating/bowls/bowl_g.cgf" },

    -- Drinks
    { n = "wineskin_rustic", m = "objects/manmade/food/drinks/wineskin_rustic.cgf" },
    { n = "wineskin_fancy",  m = "objects/manmade/food/drinks/wineskin_fancy.cgf" },

    -- Table dressing (plates / food / light)
    { n = "plate_tin",    m = "objects/manmade/task_specific_props/household/cooking_eating/plates/plate_tin_a.cgf" },
    { n = "knife_eating", m = "objects/manmade/task_specific_props/household/cooking_eating/eating_tools/knife_eating.cgf" },
    { n = "bread",        m = "objects/manmade/food/food/bread.cgf" },
    { n = "cheese",       m = "objects/manmade/food/food/cheese_quarter.cgf" },
    { n = "lamp_table",   m = "objects/manmade/common_illumination/lamp_table_rustic_a.cgf" },
    { n = "candle",       m = "objects/manmade/common_illumination/candle_e.cgf" },
}
mercenaries.InnPropEnts = {}

-- Lay the whole catalogue out in a grid in front of the player, labelled in the
-- log ([InnProp] col C row R = name), so you can walk it and note the good ones.
function mercenaries:InnPropsSpawn()
    self:InnPropsClear()
    if not player then return end
    local o = player:GetWorldPos()
    local ang; pcall(function() ang = player:GetWorldAngles() end)
    local yaw = (ang and ang.z) or 0
    local fx, fy = math.cos(yaw), math.sin(yaw)
    local rx, ry = -fy, fx
    local perRow, gap = 6, 2.0
    for i, p in ipairs(self.InnProps) do
        local col = (i - 1) % perRow
        local row = math.floor((i - 1) / perRow)
        local fwd = 4.0 + row * gap
        local lat = (col - (perRow - 1) / 2) * gap
        local pos = { x = o.x + fx * fwd + rx * lat, y = o.y + fy * fwd + ry * lat, z = o.z }
        if self.CampSnapToGround then pos = self:CampSnapToGround(pos) end
        local e
        pcall(function()
            e = System.SpawnEntity({ class = "BasicEntity",
                name = "MercInnProp_" .. i .. "_" .. tostring(math.random(100000, 999999)),
                position = pos, orientation = { x = 0, y = 0, z = yaw + math.pi },
                properties = { object_Model = p.m, bMissionCritical = false, bSaved_by_game = false, bSerialize = false } })
        end)
        if e then table.insert(self.InnPropEnts, e.id) end
        System.LogAlways(string.format("[InnProp] col %d row %d = %-16s %s", col, row, p.n, e and "OK" or "FAILED"))
    end
    System.LogAlways("[InnProp] " .. #self.InnPropEnts .. "/" .. #self.InnProps .. " props spawned - merc_inn_props_clear to remove")
end

function mercenaries:InnPropsClear()
    for _, id in ipairs(self.InnPropEnts or {}) do pcall(function() System.RemoveEntity(id) end) end
    self.InnPropEnts = {}
end

mercenaries:DevCommand("merc_inn_props",       "mercenaries:InnPropsSpawn()", "Spawn all inn candidate props in a labelled grid to eye them")
mercenaries:DevCommand("merc_inn_props_clear", "mercenaries:InnPropsClear()", "Remove the inn prop grid")

-- Inn composition + live tuner. Same frame as the hunting station: fwd = toward
-- look dir, lat = +left, up = height; rotation is Euler degrees to SetAngles
-- {x=rx,y=ry,z=rz} but only yaw (rz) applies to these non-physicalized props (no
-- collision, by design). Tune live with merc_inn_* then merc_inn_dump.
-- Tavern seat: the plain trunk stool (same as the campfire logs), rotationally
-- symmetric so its own yaw never has to look right. The seated facing comes from
-- the SO's DIRECTIONAL Sit_1Place_Chair_High helper, not the mesh - Bench_Low is
-- omnidirectional and resolves to an arbitrary side.
mercenaries.InnStool = "objects/manmade/common_furniture/chairs/low/chair_trunk_c.cgf"
mercenaries.InnChairSO = {
    guidSmartObjectType = "57cbebae-c19a-443b-8945-999d8ee87955",
    soclass_SmartObjectHelpers = "Sit_1Place_Chair_High",
    sWH_AI_EntityCategory = "SeatChair",
    Script = { esBedTypes = "Chair" },
    Bed = { esReadingQuality = "bench_notable" },
}
mercenaries.InnStationDist = 5.0

mercenaries.InnStationLayout = {
    -- Two long tables, spaced so stools fit between them (table_2 center at fwd 2.6).
    { n = "table_main", m = "objects/manmade/common_furniture/tables/table_shabby_d_160_rough.cgf", fwd = 0.0, lat = 0.0, up = 0.0, rx = 0, ry = 0, rz = 90 },
    { n = "table_2",    m = "objects/manmade/common_furniture/tables/table_shabby_d_160_rough.cgf", fwd = 2.6, lat = 0.0, up = 0.0, rx = 0, ry = 0, rz = 90 },

    -- Trunk stools, both fwd sides of each table at +/-0.8 from its center.
    { n = "stool_1",    m = mercenaries.InnStool, fwd = -0.80, lat = -0.5, up = 0.0, rx = 0, ry = 0, rz = 0 },   -- table_main outer
    { n = "stool_2",    m = mercenaries.InnStool, fwd = -0.80, lat =  0.5, up = 0.0, rx = 0, ry = 0, rz = 0 },
    { n = "stool_3",    m = mercenaries.InnStool, fwd =  0.80, lat = -0.5, up = 0.0, rx = 0, ry = 0, rz = 0 },   -- table_main inner
    { n = "stool_4",    m = mercenaries.InnStool, fwd =  0.80, lat =  0.5, up = 0.0, rx = 0, ry = 0, rz = 0 },
    { n = "stool_5",    m = mercenaries.InnStool, fwd =  1.80, lat = -0.5, up = 0.0, rx = 0, ry = 0, rz = 0 },   -- table_2 inner
    { n = "stool_6",    m = mercenaries.InnStool, fwd =  1.80, lat =  0.5, up = 0.0, rx = 0, ry = 0, rz = 0 },
    { n = "stool_7",    m = mercenaries.InnStool, fwd =  3.40, lat = -0.5, up = 0.0, rx = 0, ry = 0, rz = 0 },   -- table_2 outer
    { n = "stool_8",    m = mercenaries.InnStool, fwd =  3.40, lat =  0.5, up = 0.0, rx = 0, ry = 0, rz = 0 },

    -- The "bar": a spigot serving cask + barrels at one end (regulars spread apart).
    { n = "barrel_spigot", m = "objects/manmade/common_furniture/barrels/barrel_small_spigot_plug.cgf", fwd = 0.8, lat = 2.5, up = 0.0, rx = 0, ry = 0, rz = 0 },
    { n = "barrel_beer",   m = "objects/manmade/common_furniture/barrels/barrel_beer.cgf",               fwd = 0.0, lat = 2.6, up = 0.0, rx = 0, ry = 0, rz = 0 },
    { n = "barrel_a",      m = "objects/manmade/common_furniture/barrels/barrel_a.cgf",                  fwd = 1.4, lat = 2.5, up = 0.0, rx = 0, ry = 0, rz = 0 },
    { n = "barrel_b",      m = "objects/manmade/common_furniture/barrels/barrel_b.cgf",                  fwd = 2.5, lat = 3.0, up = 0.0, rx = 0, ry = 0, rz = 0 },
    -- Jug sitting on top of barrel_a.
    { n = "barrel_jug",    m = "objects/manmade/task_specific_props/household/cooking_eating/jugs/tin_jug_01.cgf", fwd = 1.4, lat = 2.5, up = 0.96, rx = 0, ry = 0, rz = 0 },

    -- table_main dressing (offsets validated in play; up ~0.78).
    { n = "jug_mead",   m = "objects/manmade/task_specific_props/household/cooking_eating/jugs/jug_b_mead.cgf",   fwd = -0.01, lat =  0.25, up = 0.78, rx = 0, ry = 0, rz = 0 },
    { n = "tankard",    m = "objects/manmade/task_specific_props/household/cooking_eating/tankards/tankard_a.cgf",fwd =  0.10, lat = -0.30, up = 0.78, rx = 0, ry = 0, rz = 0 },
    { n = "bowl_food",  m = "objects/manmade/food/food/mushes/bowl_goulash.cgf",                                 fwd = -0.25, lat =  0.50, up = 0.78, rx = 0, ry = 0, rz = 0 },
    { n = "plate",      m = "objects/manmade/task_specific_props/household/cooking_eating/plates/plate_tin_a.cgf",fwd =  0.30, lat = -0.50, up = 0.78, rx = 0, ry = 0, rz = 0 },
    { n = "bread",      m = "objects/manmade/food/food/bread.cgf",                                               fwd =  0.30, lat =  0.50, up = 0.78, rx = 0, ry = 0, rz = 0 },
    { n = "cheese",     m = "objects/manmade/food/food/cheese_quarter.cgf",                                      fwd =  0.00, lat =  0.50, up = 0.78, rx = 0, ry = 0, rz = 0 },
    { n = "lamp",       m = "objects/manmade/common_illumination/lamp_table_rustic_a.cgf",                       fwd =  0.00, lat =  0.00, up = 0.78, rx = 0, ry = 0, rz = 0 },

    -- table_2 dressing: same offsets, shifted to table_2's center (fwd +2.6), models reused.
    { n = "jug_2",      m = "objects/manmade/task_specific_props/household/cooking_eating/jugs/jug_metal_a.cgf",  fwd =  2.59, lat =  0.25, up = 0.78, rx = 0, ry = 0, rz = 0 },
    { n = "wineskin",   m = "objects/manmade/food/drinks/wineskin_rustic.cgf",                                   fwd =  2.70, lat = -0.30, up = 0.78, rx = 0, ry = 0, rz = 0 },
    { n = "bowl_food_2",m = "objects/manmade/food/food/mushes/bowl_goulash.cgf",                                 fwd =  2.35, lat =  0.50, up = 0.78, rx = 0, ry = 0, rz = 0 },
    { n = "plate_2",    m = "objects/manmade/task_specific_props/household/cooking_eating/plates/plate_tin_a.cgf",fwd =  2.90, lat = -0.50, up = 0.78, rx = 0, ry = 0, rz = 0 },
    { n = "bread_2",    m = "objects/manmade/food/food/bread.cgf",                                               fwd =  2.90, lat =  0.50, up = 0.78, rx = 0, ry = 0, rz = 0 },
    { n = "cheese_2",   m = "objects/manmade/food/food/cheese_quarter.cgf",                                      fwd =  2.60, lat =  0.50, up = 0.78, rx = 0, ry = 0, rz = 0 },
    { n = "lamp_2",     m = "objects/manmade/common_illumination/lamp_table_rustic_a.cgf",                       fwd =  2.60, lat =  0.00, up = 0.78, rx = 0, ry = 0, rz = 0 },
}

mercenaries.InnStation = nil   -- { origin=, fwd=, left=, yaw=, ents={}, sel= } while up

local function innWorldPos(st, L)
    return {
        x = st.origin.x + st.fwd.x * L.fwd + st.left.x * L.lat,
        y = st.origin.y + st.fwd.y * L.fwd + st.left.y * L.lat,
        z = st.origin.z + (L.up or 0),
    }
end

-- Position + rotate layout entry i's (already-spawned) prop. Plain BasicEntity so
-- SetAngles applies YAW only; station facing folded into z. Live, no respawn.
function mercenaries:InnApply(i)
    local st = self.InnStation
    if not st then return end
    local L = self.InnStationLayout[i]
    local e = st.ents and st.ents[i]
    if not (L and e) then return end
    pcall(function() e:SetWorldPos(innWorldPos(st, L)) end)
    pcall(function() e:SetAngles({ x = math.rad(L.rx or 0), y = math.rad(L.ry or 0), z = st.yaw + math.rad(L.rz or 0) }) end)
end

function mercenaries:SpawnInnStation()
    self:InnStationClear()
    if not player then return end
    local o = player:GetWorldPos()
    local ang; pcall(function() ang = player:GetWorldAngles() end)
    local yaw = (ang and ang.z) or 0
    local fwd = { x = math.cos(yaw), y = math.sin(yaw) }
    local left = { x = -math.sin(yaw), y = math.cos(yaw) }
    local origin = { x = o.x + fwd.x * self.InnStationDist, y = o.y + fwd.y * self.InnStationDist, z = o.z }
    if self.CampSnapToGround then origin = self:CampSnapToGround(origin) end

    local st = { origin = origin, fwd = fwd, left = left, yaw = yaw, ents = {}, sel = 1 }
    self.InnStation = st
    for i, L in ipairs(self.InnStationLayout) do
        local e
        pcall(function()
            e = System.SpawnEntity({ class = "BasicEntity",
                name = "MercInnStation_" .. i .. "_" .. tostring(math.random(100000, 999999)),
                position = innWorldPos(st, L),
                properties = { object_Model = L.m, bMissionCritical = false, bSaved_by_game = false, bSerialize = false } })
        end)
        if e then st.ents[i] = e end
        self:InnApply(i)
    end
    System.LogAlways("[InnStation] spawned " .. #self.InnStationLayout .. " pieces. Tune: merc_inn_sel <i>, merc_inn_move <fwd> <lat> <up>, merc_inn_rot <x> <y> <z>, merc_inn_dump")
    self:InnList()
end

function mercenaries:InnStationClear()
    local st = self.InnStation
    if st then for _, e in pairs(st.ents or {}) do pcall(function() System.RemoveEntity(e.id) end) end end
    self.InnStation = nil
end

function mercenaries:InnList()
    for i, L in ipairs(self.InnStationLayout) do
        System.LogAlways(string.format("[InnStation] %2d %s%s", i, L.n, (self.InnStation and self.InnStation.sel == i) and "  <-- selected" or ""))
    end
end

function mercenaries:InnSel(i)
    i = tonumber(i)
    if not self.InnStation then System.LogAlways("[InnStation] not spawned"); return end
    if not (i and self.InnStationLayout[i]) then self:InnList(); return end
    self.InnStation.sel = i
    System.LogAlways("[InnStation] selected " .. i .. " = " .. self.InnStationLayout[i].n)
end

function mercenaries:InnMove(df, dl, du)
    local st = self.InnStation; if not st then return end
    local L = self.InnStationLayout[st.sel]; if not L then return end
    L.fwd = L.fwd + (tonumber(df) or 0)
    L.lat = L.lat + (tonumber(dl) or 0)
    L.up  = L.up  + (tonumber(du) or 0)
    self:InnApply(st.sel)
    System.LogAlways(string.format("[InnStation] %s pos: fwd=%.2f lat=%.2f up=%.2f", L.n, L.fwd, L.lat, L.up))
end

function mercenaries:InnRot(rx, ry, rz)
    local st = self.InnStation; if not st then return end
    local L = self.InnStationLayout[st.sel]; if not L then return end
    if rx and rx ~= "" then L.rx = tonumber(rx) or L.rx end
    if ry and ry ~= "" then L.ry = tonumber(ry) or L.ry end
    if rz and rz ~= "" then L.rz = tonumber(rz) or L.rz end
    self:InnApply(st.sel)
    System.LogAlways(string.format("[InnStation] %s rot: x=%s y=%s z=%s", L.n, tostring(L.rx), tostring(L.ry), tostring(L.rz)))
end

function mercenaries:InnDump()
    System.LogAlways("[InnStation] --- current layout ---")
    for i, L in ipairs(self.InnStationLayout) do
        System.LogAlways(string.format('    { n = "%s", m = "%s", fwd = %.2f, lat = %.2f, up = %.2f, rx = %s, ry = %s, rz = %s },',
            L.n, L.m, L.fwd, L.lat, L.up, tostring(L.rx), tostring(L.ry), tostring(L.rz)))
    end
end

mercenaries:DevCommand("merc_inn_spawn", "mercenaries:SpawnInnStation()",        "Spawn the inn composition in front of you")
mercenaries:DevCommand("merc_inn_clear", "mercenaries:InnStationClear()",        "Remove the inn station")
mercenaries:DevCommand("merc_inn_list",  "mercenaries:InnList()",                "List the inn pieces with their indices")
mercenaries:DevCommand("merc_inn_sel",   "mercenaries:InnSel(%1)",               "Select an inn piece to tune (index from merc_inn_list)")
mercenaries:DevCommand("merc_inn_move",  "mercenaries:InnMove(%1, %2, %3)",      "Nudge selected piece: merc_inn_move <dFwd> <dLat> <dUp>")
mercenaries:DevCommand("merc_inn_rot",   "mercenaries:InnRot('%1', '%2', '%3')", "Set selected piece rotation (deg): merc_inn_rot <x> <y> <z>  (z=yaw)")
mercenaries:DevCommand("merc_inn_dump",  "mercenaries:InnDump()",                "Print the tuned layout to the log for baking in")

-- ==== Camp inn / tavern station (the actual upgrade) ====
-- Built near camp when the inn upgrade is owned, on the flattest ring spot clear
-- of the other stations. The trunk stools are spawned as real sittable seats
-- (StanceSmartObject, added to CampSeats and flagged tavern) so mercs sit at the
-- tables; RotateCampRoles/ClaimSpot then prefer the tavern (see mercenaries_camp).
mercenaries.CampInn = nil

-- Seated facing, settled in play:
--  1. SpawnEntity's `orientation` is a forward DIRECTION VECTOR, not Euler angles
--     (SpawnCampFurnitureSO builds it from the yaw) - see the notes there.
--  2. The merc sits facing OPPOSITE that vector, so a seat is spawned pointing
--     180 from where its occupant should look. Hence 180 here = face the table.
--  3. The stool MESH's yaw has no effect on the sit, so it isn't tuned.
mercenaries.InnSeatYawFixDeg = 180

function mercenaries:SpawnCampInn(center)
    if self.CampInn then return true end
    center = center or self.CampCenter
    if not center then return false end

    -- The camp reserves a grid tile per upgrade (see CampStationTiles); only fall
    -- back to a flat-patch scan clear of the other stations if there wasn't one.
    local spot, ang = self:CampStationSpot("inn")
    if not spot then
        local avoid = {}
        if self.CampForge and self.CampForge.anvilPos then table.insert(avoid, self.CampForge.anvilPos) end
        if self.CampAlchemy and self.CampAlchemy.spot then table.insert(avoid, self.CampAlchemy.spot) end
        if self.CampHunt and self.CampHunt.origin then table.insert(avoid, self.CampHunt.origin) end
        if self.CampPracticeYard and self.CampPracticeYard.trainCenter then table.insert(avoid, self.CampPracticeYard.trainCenter) end
        if #avoid == 0 then avoid = nil end
        spot, ang = self:ForgeFindFlattest(center, avoid)
    end
    if not spot then
        ang = math.pi
        spot = self:CampSnapToGround({ x = center.x + math.cos(ang) * 10, y = center.y + math.sin(ang) * 10, z = center.z })
    end
    local F = { x = math.cos(ang), y = math.sin(ang) }
    local Lft = { x = -F.y, y = F.x }
    local function wp(L)
        return { x = spot.x + F.x * L.fwd + Lft.x * L.lat, y = spot.y + F.y * L.fwd + Lft.y * L.lat, z = spot.z + (L.up or 0) }
    end

    -- Table world centres, so each stool seat can face (and be turned toward) the
    -- nearer table.
    local tables = {}
    for _, L in ipairs(self.InnStationLayout) do
        if L.n == "table_main" or L.n == "table_2" then table.insert(tables, wp(L)) end
    end
    local function nearestTable(w)
        local best, bd
        for _, t in ipairs(tables) do
            local d = (t.x - w.x) ^ 2 + (t.y - w.y) ^ 2
            if not bd or d < bd then best, bd = t, d end
        end
        return best or spot
    end

    local st = { origin = spot, ang = ang, ids = {}, seatEntries = {}, seatWuidSet = {} }
    self.CampInn = st
    self.CampSeats = self.CampSeats or {}

    for _, L in ipairs(self.InnStationLayout) do
        local w = wp(L)
        if tostring(L.n):match("^stool") then
            -- Sittable seat: stool prop + Chair_High StanceSmartObject co-located.
            -- The SO's spawn direction vector is the ONLY thing that sets the
            -- seated facing (the stool mesh's own yaw has no effect - it is
            -- symmetric anyway).
            --
            -- Seats face SQUARELY across their table's long edge - NOT at the
            -- table's centre. The stools sit at lat +/-0.5 while the table centre
            -- is at lat 0, so aiming at the centre skewed every seat ~30 deg
            -- inward by a different amount: that was the "weird" facing. So every
            -- seat gets the same direction vector - the station's LEFT (forward +
            -- InnSeatYawFixDeg) - and only the seats whose table is BEHIND them
            -- are flipped 180.
            local tgt = nearestTable(w)
            local towardTable = (tgt.x - w.x) * F.x + (tgt.y - w.y) * F.y   -- >0 = table is ahead
            local soAng = ang + math.rad(self.InnSeatYawFixDeg or 0)
            if towardTable < 0 then soAng = soAng + math.pi end
            local wuid, soGroundPos = self:SpawnCampFurnitureSO(L.m, w, soAng, "MercInnStool", self.InnChairSO, nil, st.ids)
            if wuid then
                -- No firePos: that would make the BT Turn the merc before sitting,
                -- which fights the helper's own enter-align (reads as a weird spin).
                local entry = { wuid = wuid, pos = soGroundPos, occupant = nil, tavern = true }
                table.insert(self.CampSeats, entry)
                table.insert(st.seatEntries, entry)
                st.seatWuidSet[tostring(wuid)] = true
            end
        else
            local e
            pcall(function()
                e = System.SpawnEntity({ class = "BasicEntity",
                    name = "MercCampInn_" .. tostring(math.random(100000, 999999)),
                    position = w, properties = { object_Model = L.m, bMissionCritical = false, bSaved_by_game = false, bSerialize = false } })
            end)
            if e then
                pcall(function() e:SetAngles({ x = math.rad(L.rx or 0), y = math.rad(L.ry or 0), z = ang + math.rad(L.rz or 0) }) end)
                table.insert(st.ids, e.id)
            end
        end
    end
    System.LogAlways("[CampInn] tavern built (" .. #st.ids .. " props, " .. #st.seatEntries .. " seats)")
    return true
end

function mercenaries:DespawnCampInn()
    local st = self.CampInn
    if not st then return end
    for _, id in ipairs(st.ids or {}) do pcall(function() System.RemoveEntity(id) end) end
    -- Pull the tavern seats back out of the shared seat pool, and unseat any merc
    -- still assigned to one (their SO is gone; next role rotation reassigns them).
    if self.CampSeats then
        local keep = {}
        for _, sp in ipairs(self.CampSeats) do if not sp.tavern then table.insert(keep, sp) end end
        self.CampSeats = keep
    end
    local seats = st.seatWuidSet or {}
    for ws, f in pairs(self.CampFurniture or {}) do
        if f and f.wuid and seats[tostring(f.wuid)] then
            self.CampFurniture[ws] = nil
            if self.CampNextRotate then self.CampNextRotate[ws] = 0 end
        end
    end
    for ws, a in pairs(self.CampActivities or {}) do
        if a and a.locWuid and seats[tostring(a.locWuid)] then
            self.CampActivities[ws] = nil
            if self.CampNextRotate then self.CampNextRotate[ws] = 0 end
        end
    end
    self.CampInn = nil
    System.LogAlways("[CampInn] tavern torn down")
end

-- Rebuild the tavern in place (the sit helper caches its transform at spawn, so
-- any seat change needs a respawn). Seated mercs re-sit on the next role rotation.
function mercenaries:InnRebuild()
    if not self.CampInn then return end
    self:DespawnCampInn()
    self:SpawnCampInn(self.CampCenter)
end
mercenaries:DevCommand("merc_inn_rebuild", "mercenaries:InnRebuild()", "Rebuild the camp tavern in place")
