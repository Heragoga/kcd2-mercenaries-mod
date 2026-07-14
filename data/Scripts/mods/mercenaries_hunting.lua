-- Hunting upgrade (WIP): a camp hunting/butchering/tanning station like the forge.
-- Console-only for now: a prop catalogue laid out in a labelled grid (merc_hunt_props)
-- for eyeing candidate models, plus the station composition + live tuner below.

-- Candidate models, grouped. `n` = short label logged on spawn; `m` = .cgf path.
mercenaries.HuntProps = {
    -- Archery (bows / quivers / arrows)
    { n = "bow_a",            m = "objects/manmade/weapons/bows/bow_a.cgf" },
    { n = "bow_b",            m = "objects/manmade/weapons/bows/bow_b.cgf" },
    { n = "bow_e",            m = "objects/manmade/weapons/bows/bow_e.cgf" },
    { n = "quiver",           m = "objects/manmade/task_specific_props/combat/archery/quiver_with_arrows.cgf" },
    { n = "arrows_bundle",    m = "objects/manmade/weapons/arrows/arrows_bundle_beige.cgf" },
    { n = "arrows_pack",      m = "objects/manmade/weapons/arrows/arrows_pack.cgf" },
    { n = "arrow_barrel",     m = "objects/manmade/weapons/arrows/barrel_arrow_full_closed.cgf" },
    { n = "arrow_basket",     m = "objects/manmade/weapons/arrows/basket_arrow_half.cgf" },

    -- Butchering (table + tools + cut meat)
    { n = "butcher_table",    m = "objects/manmade/common_furniture/tables/table_shabby_d_160_rough.cgf" },
    { n = "butcher_hook",     m = "objects/manmade/task_specific_props/food_processing/butchering/butcher_hook.cgf" },
    { n = "butcher_knife",    m = "objects/manmade/task_specific_props/food_processing/butchering/butcher_knife_big.cgf" },
    { n = "cleaver",          m = "objects/manmade/task_specific_props/food_processing/butchering/cleaver_b.cgf" },
    { n = "meat_piece_a",     m = "objects/manmade/task_specific_props/food_processing/butchering/skinned_deer_piece_a.cgf" },
    { n = "meat_piece_c",     m = "objects/manmade/task_specific_props/food_processing/butchering/skinned_deer_piece_c.cgf" },

    -- Carcasses (whole, hanging, small, guts)
    { n = "deer_corpse",      m = "objects/manmade/task_specific_props/foraging/hunting/deer_corpse.cgf" },
    { n = "deer_hanging",     m = "objects/manmade/task_specific_props/foraging/hunting/deer_hanging.cgf" },
    { n = "deer_hang_shabby", m = "objects/manmade/task_specific_props/foraging/hunting/deer_hanging_shabby_v2.cgf" },
    { n = "hare_dead",        m = "objects/characters/assets/hare_dead/hare_dead.cgf" },
    { n = "viscera",          m = "objects/manmade/task_specific_props/foraging/hunting/viscera.cgf" },

    -- Tanning (frame/rack, drying furs, rolled pelts, tools)
    { n = "tanning_frame",    m = "objects/manmade/task_specific_props/clothing_industry/tanning/tanning_frame_hare_c.cgf" },
    { n = "drying_fur_e",     m = "objects/manmade/task_specific_props/clothing_industry/tanning/drying_fur_e.cgf" },
    { n = "drying_fur_f",     m = "objects/manmade/task_specific_props/clothing_industry/tanning/drying_fur_f.cgf" },
    { n = "skin_boar_roll",   m = "objects/manmade/task_specific_props/clothing_industry/tanning/skin_boar_rolled.cgf" },
    { n = "skin_deer_roll",   m = "objects/manmade/task_specific_props/clothing_industry/tanning/skin_deer_rolled.cgf" },
    { n = "skin_hare_roll",   m = "objects/manmade/task_specific_props/clothing_industry/tanning/skin_hare_rolled.cgf" },
    { n = "skin_group",       m = "objects/manmade/task_specific_props/clothing_industry/tanning/skin_rolled_group_a.cgf" },
    { n = "skin_hare_fin",    m = "objects/manmade/task_specific_props/clothing_industry/tanning/skin_hare_finished_both.cgf" },
    { n = "scraper",          m = "objects/manmade/task_specific_props/clothing_industry/tanning/scraper.cgf" },

    -- Furs / pelts (laid out)
    { n = "fur_deer",         m = "objects/manmade/common_furniture/furs/fur_deer.cgf" },
    { n = "fur_hare",         m = "objects/manmade/common_furniture/furs/fur_hare.cgf" },

    -- Drying / smoking (rack, house, hanging meat)
    { n = "drying_rack",      m = "objects/manmade/structures/industrial/drying_house/drying_rack_a.cgf" },
    { n = "drying_house",     m = "objects/manmade/structures/industrial/drying_house/drying_house_a.cgf" },
    { n = "kielbasa_smoked",  m = "objects/manmade/food/food/kielbasas_smoked_single.cgf" },
    { n = "meat_bacon",       m = "objects/manmade/food/food/meat_bacon.cgf" },

    -- Sacks / storage
    { n = "sack_a",           m = "objects/manmade/common_furniture/sacks/sack_a.cgf" },
    { n = "sack_b",           m = "objects/manmade/common_furniture/sacks/sack_b.cgf" },
    { n = "sack_items",       m = "objects/manmade/common_furniture/sacks/sack_items/sack_items.cgf" },

    -- Hanging dressing + trophies
    { n = "onion_hanging",    m = "objects/manmade/food/food/vegetable/onion_hanging_a.cgf" },
    { n = "herbs_hanging",    m = "objects/manmade/task_specific_props/alchemy/herbs/herbs_hanging_a.cgf" },
    { n = "antlers",          m = "objects/manmade/task_specific_props/foraging/hunting/antlers_deer_c.cgf" },
    { n = "antlers_mounted",  m = "objects/manmade/task_specific_props/foraging/hunting/antlers_mounted_c.cgf" },
    { n = "snare",            m = "objects/manmade/task_specific_props/foraging/hunting/snare.cgf" },
}
mercenaries.HuntPropEnts = {}

-- Lay the whole catalogue out in a grid in front of the player, each prop faced
-- toward the player and labelled in the log ([HuntProp] col C row R = name), so
-- you can walk the grid and note the good ones by position.
function mercenaries:HuntPropsSpawn()
    self:HuntPropsClear()
    if not player then return end
    local o = player:GetWorldPos()
    local ang; pcall(function() ang = player:GetWorldAngles() end)
    local yaw = (ang and ang.z) or 0
    local fx, fy = math.cos(yaw), math.sin(yaw)   -- forward (player look dir)
    local rx, ry = -fy, fx                          -- player's left->right axis
    local perRow, gap = 6, 2.5
    for i, p in ipairs(self.HuntProps) do
        local col = (i - 1) % perRow
        local row = math.floor((i - 1) / perRow)
        local fwd = 4.0 + row * gap
        local lat = (col - (perRow - 1) / 2) * gap
        local pos = { x = o.x + fx * fwd + rx * lat, y = o.y + fy * fwd + ry * lat, z = o.z }
        if self.CampSnapToGround then pos = self:CampSnapToGround(pos) end
        local e
        pcall(function()
            e = System.SpawnEntity({ class = "BasicEntity",
                name = "MercHuntProp_" .. i .. "_" .. tostring(math.random(100000, 999999)),
                position = pos, orientation = { x = 0, y = 0, z = yaw + math.pi },
                properties = { object_Model = p.m, bMissionCritical = false } })
        end)
        if e then table.insert(self.HuntPropEnts, e.id) end
        System.LogAlways(string.format("[HuntProp] col %d row %d = %-16s %s", col, row, p.n, e and "OK" or "FAILED"))
    end
    System.LogAlways("[HuntProp] " .. #self.HuntPropEnts .. "/" .. #self.HuntProps .. " props spawned - walk the grid; merc_hunt_props_clear to remove")
end

function mercenaries:HuntPropsClear()
    for _, id in ipairs(self.HuntPropEnts or {}) do pcall(function() System.RemoveEntity(id) end) end
    self.HuntPropEnts = {}
end

System.AddCCommand("merc_hunt_props",       "mercenaries:HuntPropsSpawn()", "Spawn all hunting-upgrade candidate props in a labelled grid to eye them")
System.AddCCommand("merc_hunt_props_clear", "mercenaries:HuntPropsClear()", "Remove the hunting prop grid")


-- Hunting station composition + live tuner. Each entry is placed relative to a
-- station origin in the player's frame: fwd = toward look dir, lat = +left, up =
-- height. Rotation is raw Euler degrees passed to SetAngles as {x=rx, y=ry, z=rz}
-- (KCD2 convention: x=roll, y=pitch, z=yaw). The station's facing (player yaw) is
-- added to rz automatically. Props that spawn "on their side" need rx or ry ~90 to
-- stand. First-pass numbers - tune live with merc_hunt_* then merc_hunt_dump.
mercenaries.HuntLog = "objects/manmade/common_furniture/chairs/low/chair_trunk_c.cgf"
mercenaries.HuntStationDist = 5.0

mercenaries.HuntStationLayout = {
    -- Main table: bow / arrows / pelt on top, log chairs around it.
    { n = "main_table", m = "objects/manmade/common_furniture/tables/table_shabby_d_160_rough.cgf", fwd = 0.0, lat = -2.0, up = 0.0, rx = 0, ry = 0, rz = 90 },
    { n = "chair_a",    m = mercenaries.HuntLog,  fwd =  0.9, lat =  0.0, up = 0.0, rx = 0, ry = 0, rz = 0 },
    { n = "chair_b",    m = mercenaries.HuntLog,  fwd = -0.6, lat =  0.0, up = 0.0, rx = 0, ry = 0, rz = 0 },
    { n = "chair_c",    m = mercenaries.HuntLog,  fwd =  0.2, lat =  0.8, up = 0.0, rx = 0, ry = 0, rz = 0 },
    { n = "bow",        m = "objects/manmade/weapons/bows/bow_a.cgf",                                  fwd =  0.2, lat =  0.0, up = 0.82, rx = 90, ry = 90, rz = 90 },
    { n = "arrows",     m = "objects/manmade/weapons/arrows/arrows_bundle_beige.cgf",                  fwd =  0.49, lat = 0.07, up = 0.73, rx = 90, ry = 0, rz = 0 },
    { n = "pelt_a",     m = "objects/manmade/common_furniture/furs/fur_hare.cgf",                      fwd = -0.0, lat =  0.3, up = 0.75, rx = 0,  ry = 0, rz = 0 },

    -- Second table pulled up next to the main one (right side): deer carcass on it.
    { n = "table_2",    m = "objects/manmade/common_furniture/tables/table_shabby_d_80_rough.cgf",     fwd = 0.2, lat = 0.1, up = 0.0, rx = 0, ry = 0, rz = 90 },
    { n = "carcass",    m = "objects/manmade/task_specific_props/foraging/hunting/deer_corpse.cgf",    fwd = -0.1, lat = -1.9, up = 0.78, rx = 0, ry = 0, rz = 90 },

    -- Drying rack + storage cluster to the other side, tightened in.
    { n = "drying_rack",m = "objects/manmade/structures/industrial/drying_house/drying_rack_a.cgf",    fwd = -0.2, lat =  1.9, up = 0.0, rx = 0, ry = 0, rz = 0 },
    { n = "arrow_barrel",m= "objects/manmade/weapons/arrows/barrel_arrow_full_closed.cgf",             fwd = 0.6, lat =  2.1, up = 0.0, rx = 0, ry = 0, rz = 90 },
    { n = "sack_a",     m = "objects/manmade/common_furniture/sacks/sack_a.cgf",                       fwd = -1.1, lat = 2.1, up = 0.0, rx = 0, ry = 0, rz = 90 },
    { n = "sack_b",     m = "objects/manmade/common_furniture/sacks/sack_b.cgf",                       fwd = -1.4, lat = 1.7, up = 0.0, rx = 0, ry = 0, rz = 90 },
    { n = "quiver",     m = "objects/manmade/task_specific_props/combat/archery/quiver_with_arrows.cgf",fwd = 0.1, lat = 2.1, up = 0.24, rx = 0, ry = 0, rz = 90 },
}

mercenaries.HuntStation = nil   -- { origin=, fwd=, right=, yaw=, ents={}, sel= } while up

-- World position of layout entry L, from the stored station frame.
local function huntWorldPos(st, L)
    return {
        x = st.origin.x + st.fwd.x * L.fwd + st.left.x * L.lat,
        y = st.origin.y + st.fwd.y * L.fwd + st.left.y * L.lat,
        z = st.origin.z + (L.up or 0),
    }
end

-- Position + rotate layout entry i's (already-spawned) prop. Plain BasicEntity has
-- no physics proxy, so SetAngles only applies YAW (z) - pitch/roll (rx/ry) are
-- ignored here (a static-physics proxy would honor them but adds collision, which
-- we don't want on camp props). Station facing folded into z. Live, no respawn.
function mercenaries:HuntApply(i)
    local st = self.HuntStation
    if not st then return end
    local L = self.HuntStationLayout[i]
    local e = st.ents and st.ents[i]
    if not (L and e) then return end
    pcall(function() e:SetWorldPos(huntWorldPos(st, L)) end)
    pcall(function() e:SetAngles({ x = math.rad(L.rx or 0), y = math.rad(L.ry or 0), z = st.yaw + math.rad(L.rz or 0) }) end)
end

function mercenaries:SpawnHuntStation()
    self:HuntStationClear()
    if not player then return end
    local o = player:GetWorldPos()
    local ang; pcall(function() ang = player:GetWorldAngles() end)
    local yaw = (ang and ang.z) or 0
    local fwd = { x = math.cos(yaw), y = math.sin(yaw) }
    local left = { x = -math.sin(yaw), y = math.cos(yaw) }   -- +lat = player's left
    local origin = { x = o.x + fwd.x * self.HuntStationDist, y = o.y + fwd.y * self.HuntStationDist, z = o.z }
    if self.CampSnapToGround then origin = self:CampSnapToGround(origin) end

    local st = { origin = origin, fwd = fwd, left = left, yaw = yaw, ents = {}, sel = 1 }
    self.HuntStation = st
    for i, L in ipairs(self.HuntStationLayout) do
        local e
        pcall(function()
            e = System.SpawnEntity({ class = "BasicEntity",
                name = "MercHuntStation_" .. i .. "_" .. tostring(math.random(100000, 999999)),
                position = huntWorldPos(st, L),
                properties = { object_Model = L.m, bMissionCritical = false } })
        end)
        if e then st.ents[i] = e end   -- store the entity ref (not the id)
        self:HuntApply(i)
    end
    System.LogAlways("[HuntStation] spawned " .. #self.HuntStationLayout .. " pieces. Tune: merc_hunt_sel <i>, merc_hunt_move <fwd> <lat> <up>, merc_hunt_rot <x> <y> <z>, merc_hunt_dump")
    self:HuntList()
end

function mercenaries:HuntStationClear()
    local st = self.HuntStation
    if st then for _, e in pairs(st.ents or {}) do pcall(function() System.RemoveEntity(e.id) end) end end
    self.HuntStation = nil
end

-- List the pieces with their index (for merc_hunt_sel).
function mercenaries:HuntList()
    for i, L in ipairs(self.HuntStationLayout) do
        System.LogAlways(string.format("[HuntStation] %2d %s%s", i, L.n, (self.HuntStation and self.HuntStation.sel == i) and "  <-- selected" or ""))
    end
end

function mercenaries:HuntSel(i)
    i = tonumber(i)
    if not self.HuntStation then System.LogAlways("[HuntStation] not spawned"); return end
    if not (i and self.HuntStationLayout[i]) then self:HuntList(); return end
    self.HuntStation.sel = i
    System.LogAlways("[HuntStation] selected " .. i .. " = " .. self.HuntStationLayout[i].n)
end

function mercenaries:HuntMove(df, dl, du)
    local st = self.HuntStation; if not st then return end
    local L = self.HuntStationLayout[st.sel]; if not L then return end
    L.fwd = L.fwd + (tonumber(df) or 0)
    L.lat = L.lat + (tonumber(dl) or 0)
    L.up  = L.up  + (tonumber(du) or 0)
    self:HuntApply(st.sel)
    System.LogAlways(string.format("[HuntStation] %s pos: fwd=%.2f lat=%.2f up=%.2f", L.n, L.fwd, L.lat, L.up))
end

function mercenaries:HuntRot(rx, ry, rz)
    local st = self.HuntStation; if not st then return end
    local L = self.HuntStationLayout[st.sel]; if not L then return end
    if rx and rx ~= "" then L.rx = tonumber(rx) or L.rx end
    if ry and ry ~= "" then L.ry = tonumber(ry) or L.ry end
    if rz and rz ~= "" then L.rz = tonumber(rz) or L.rz end
    self:HuntApply(st.sel)
    System.LogAlways(string.format("[HuntStation] %s rot: x=%s y=%s z=%s", L.n, tostring(L.rx), tostring(L.ry), tostring(L.rz)))
end

-- Print the whole tuned layout in a form easy to paste back so I can bake it in.
function mercenaries:HuntDump()
    System.LogAlways("[HuntStation] --- current layout ---")
    for i, L in ipairs(self.HuntStationLayout) do
        System.LogAlways(string.format('    { n = "%s", m = "%s", fwd = %.2f, lat = %.2f, up = %.2f, rx = %s, ry = %s, rz = %s },',
            L.n, L.m, L.fwd, L.lat, L.up, tostring(L.rx), tostring(L.ry), tostring(L.rz)))
    end
end

System.AddCCommand("merc_hunt_spawn", "mercenaries:SpawnHuntStation()",        "Spawn the hunting-station composition in front of you")
System.AddCCommand("merc_hunt_clear", "mercenaries:HuntStationClear()",        "Remove the hunting station")
System.AddCCommand("merc_hunt_list",  "mercenaries:HuntList()",                "List the station pieces with their indices")
System.AddCCommand("merc_hunt_sel",   "mercenaries:HuntSel(%1)",               "Select a station piece to tune (index from merc_hunt_list)")
System.AddCCommand("merc_hunt_move",  "mercenaries:HuntMove(%1, %2, %3)",      "Nudge selected piece: merc_hunt_move <dFwd> <dLat> <dUp>")
System.AddCCommand("merc_hunt_rot",   "mercenaries:HuntRot('%1', '%2', '%3')", "Set selected piece rotation (deg): merc_hunt_rot <x> <y> <z>  (x=roll, y=pitch, z=yaw)")
System.AddCCommand("merc_hunt_dump",  "mercenaries:HuntDump()",                "Print the tuned layout to the log for baking in")


-- ==== Camp hunting station (the actual upgrade) ====
-- Built near camp when the Hunter upgrade is owned, on the flattest ring spot that
-- clears the other camp stations. Faces outward from camp; same tuned layout as the
-- console tester above, just anchored to a camp spot instead of the player.
mercenaries.CampHunt = nil

function mercenaries:SpawnCampHunt(center)
    if self.CampHunt then return true end
    center = center or self.CampCenter
    if not center then return false end

    -- Keep clear of the forge / alchemy / practice-yard patches already placed.
    local avoid = {}
    if self.CampForge and self.CampForge.anvilPos then table.insert(avoid, self.CampForge.anvilPos) end
    if self.CampAlchemy and self.CampAlchemy.spot then table.insert(avoid, self.CampAlchemy.spot) end
    if self.CampPracticeYard and self.CampPracticeYard.trainCenter then table.insert(avoid, self.CampPracticeYard.trainCenter) end
    if #avoid == 0 then avoid = nil end   -- empty list would normalize to a bad {{}} avoid

    local spot, ang = self:ForgeFindFlattest(center, avoid)
    if not spot then
        ang = math.pi
        spot = self:CampSnapToGround({ x = center.x + math.cos(ang) * 10, y = center.y + math.sin(ang) * 10, z = center.z })
    end
    local F = { x = math.cos(ang), y = math.sin(ang) }   -- forward = outward from camp
    local Lft = { x = -F.y, y = F.x }
    local st = { origin = spot, ang = ang, ents = {} }
    self.CampHunt = st

    for i, L in ipairs(self.HuntStationLayout) do
        local w = { x = spot.x + F.x * L.fwd + Lft.x * L.lat,
                    y = spot.y + F.y * L.fwd + Lft.y * L.lat,
                    z = spot.z + (L.up or 0) }
        local e
        pcall(function()
            e = System.SpawnEntity({ class = "BasicEntity",
                name = "MercCampHunt_" .. i .. "_" .. tostring(math.random(100000, 999999)),
                position = w, properties = { object_Model = L.m, bMissionCritical = false } })
        end)
        if e then
            pcall(function() e:SetAngles({ x = math.rad(L.rx or 0), y = math.rad(L.ry or 0), z = ang + math.rad(L.rz or 0) }) end)
            table.insert(st.ents, e.id)
        end
    end
    System.LogAlways("[CampHunt] hunting station built (" .. #st.ents .. " props)")
    return true
end

function mercenaries:DespawnCampHunt()
    local st = self.CampHunt
    if not st then return end
    for _, id in ipairs(st.ents or {}) do pcall(function() System.RemoveEntity(id) end) end
    self.CampHunt = nil
    System.LogAlways("[CampHunt] hunting station torn down")
end
