-- Archer tower upgrade (WIP): console-only for now - two prop galleries to eye
-- candidates, plus the tower composition + live tuner below.
--
-- Sourced from the game's own data (see references/). The tower is built from the
-- scafolding/ kit, which is what the game's own scaffolding-tower prefabs
-- (references/Prefabs/manmade/scaffolding/) are assembled from.
--
-- COLLISION WARNING (from the spawn-house postmortem): big structures keep their
-- collision in a separate cv_*.cgf rather than the render mesh, so a deck may well
-- be walk-through and need the invisible-crate-collider treatment (see
-- mercenaries_house.lua). The small scaffolding parts are the better bet for
-- carrying their own physics proxy - worth checking early, since a tower you
-- can't stand on is no tower.

-- Generic gallery: lay `list` out in a row to the player's right, `up` metres off
-- the ground, labelled in the log so the good ones can be noted by index.
function mercenaries:TowerGallery(list, tag, spacing, up, track)
    if not player then return end
    spacing = tonumber(spacing) or 8.0
    up = up or 1.0
    local o = player:GetWorldPos()
    local ang; pcall(function() ang = player:GetWorldAngles() end)
    local yaw = (ang and ang.z) or 0
    local fx, fy = math.cos(yaw), math.sin(yaw)
    local rx, ry = -fy, fx
    for i, p in ipairs(list) do
        local lat = (i - 1) * spacing
        local pos = { x = o.x + fx * 10.0 + rx * lat, y = o.y + fy * 10.0 + ry * lat, z = o.z }
        if self.CampSnapToGround then pos = self:CampSnapToGround(pos) end
        pos.z = pos.z + up
        local e
        pcall(function()
            e = System.SpawnEntity({ class = "BasicEntity",
                name = "MercTowerProp_" .. i .. "_" .. tostring(math.random(100000, 999999)),
                position = pos,
                orientation = { x = math.cos(yaw + math.pi), y = math.sin(yaw + math.pi), z = 0 },
                properties = { object_Model = p.m, bMissionCritical = false,
                               bSaved_by_game = false, bSerialize = false } })
        end)
        if e then
            pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw + math.pi }) end)
            pcall(function() e:SetViewDistUnlimited() end)
            table.insert(track, e.id)
        end
        System.LogAlways(string.format("[%s] #%-2d = %-22s %s", tag, i, p.n, e and "OK" or "FAILED"))
    end
    System.LogAlways("[" .. tag .. "] " .. #track .. "/" .. #list .. " props in a row to your right, " .. up .. "m up")
end

-- ==== Gallery 1: structure (towers / decks / legs / platforms) ====
-- #2 (scaf_floor_a) and #10 (scaf_main_beam_c) are the picked ones - they're the
-- tower composition below.
mercenaries.TowerProps = {
    { n = "watchtower",        m = "objects/manmade/structures/defensive/watchtowers/unique/nebakov/watchtower.cgf" },
    { n = "scaf_floor_a",      m = "objects/manmade/structures/scafolding/scaffolding_floor_only_a.cgf" },
    { n = "scaf_floor_b",      m = "objects/manmade/structures/scafolding/scaffolding_floor_only_b.cgf" },
    { n = "scaf_floor_c",      m = "objects/manmade/structures/scafolding/scaffolding_floor_only_c.cgf" },
    { n = "scaf_floor_d",      m = "objects/manmade/structures/scafolding/scaffolding_floor_only_d.cgf" },
    { n = "scaf_floor_e",      m = "objects/manmade/structures/scafolding/scaffolding_floor_only_e.cgf" },
    { n = "scaf_floor_f",      m = "objects/manmade/structures/scafolding/scaffolding_floor_only_f.cgf" },
    { n = "scaf_floor_ladder", m = "objects/manmade/structures/scafolding/scaffolding_floor_only_ladder_a.cgf" },
    { n = "scaf_main_beam_a",  m = "objects/manmade/structures/scafolding/scaffolding_main_beam_a.cgf" },
    { n = "scaf_main_beam_c",  m = "objects/manmade/structures/scafolding/scaffolding_main_beam_c.cgf" },
    { n = "scaf_beam_a",       m = "objects/manmade/structures/scafolding/scaffolding_beam_only_a.cgf" },
    { n = "scaf_beam_b",       m = "objects/manmade/structures/scafolding/scaffolding_beam_only_b.cgf" },
    { n = "scaf_beam_end",     m = "objects/manmade/structures/scafolding/scaffolding_beam_only_end.cgf" },
    { n = "scaf_support_a",    m = "objects/manmade/structures/scafolding/scaffolding_beam_support_a.cgf" },
    { n = "scaf_support_b",    m = "objects/manmade/structures/scafolding/scaffolding_beam_support_b.cgf" },
    { n = "scaf_handrail_a",   m = "objects/manmade/structures/scafolding/scaffolding_handrail_a.cgf" },
    { n = "scaf_handrail_b",   m = "objects/manmade/structures/scafolding/scaffolding_handrail_b.cgf" },
    { n = "scaf_handrail_c",   m = "objects/manmade/structures/scafolding/scaffolding_handrail_c.cgf" },
    { n = "scaf_handrail_d",   m = "objects/manmade/structures/scafolding/scaffolding_handrail_d.cgf" },
    { n = "scaf_ramp_d",       m = "objects/manmade/structures/scafolding/scaffolding_ramp_d.cgf" },
    { n = "platform_a",        m = "objects/manmade/common_furniture/platforms/platform_a.cgf" },
    { n = "platform_b",        m = "objects/manmade/common_furniture/platforms/platform_b.cgf" },
    { n = "ore_platform",      m = "objects/manmade/task_specific_props/metal_industry/silver/silver_ore_platform.cgf" },
    { n = "bridge_deck_half",  m = "objects/manmade/structures/logistical/bridges/common_bridge_deck_half.cgf" },
    { n = "palisade_post",     m = "objects/manmade/structures/defensive/walls/palisade/palisade_wall_single_sharp.cgf" },
    { n = "pillory_log",       m = "objects/manmade/structures/municipal/law_and_order/pillory_log.cgf" },
    { n = "tree_log_b",        m = "objects/natural/vegetation/trees/fallen_trees/tree_log_b.cgf" },
}
mercenaries.TowerPropEnts = {}

function mercenaries:TowerPropsSpawn(spacing)
    self:TowerPropsClear()
    self:TowerGallery(self.TowerProps, "TowerProp", spacing or 8.0, 1.0, self.TowerPropEnts)
    System.LogAlways("[TowerProp] merc_tower_props_clear to remove")
end
function mercenaries:TowerPropsClear()
    for _, id in ipairs(self.TowerPropEnts or {}) do pcall(function() System.RemoveEntity(id) end) end
    self.TowerPropEnts = {}
end

-- ==== Gallery 2: railings / fences / ladders ====
-- The scaffolding handrails are purpose-built for these decks and are the natural
-- first choice; the fences are the alternatives if they read too "construction
-- site". Ladders are named by their height in cm (225 = 2.25m), so once the deck
-- height is settled the right one can just be read off the name.
mercenaries.TowerRails = {
    -- Purpose-built scaffolding handrails
    { n = "scaf_handrail_a",   m = "objects/manmade/structures/scafolding/scaffolding_handrail_a.cgf" },
    { n = "scaf_handrail_b",   m = "objects/manmade/structures/scafolding/scaffolding_handrail_b.cgf" },
    { n = "scaf_handrail_c",   m = "objects/manmade/structures/scafolding/scaffolding_handrail_c.cgf" },
    { n = "scaf_handrail_d",   m = "objects/manmade/structures/scafolding/scaffolding_handrail_d.cgf" },

    -- Rod / plank fences (tidier, more "built")
    { n = "fence_4rod_01",     m = "objects/manmade/structures/logistical/fences/fence_4rod_01.cgf" },
    { n = "fence_4rod_02",     m = "objects/manmade/structures/logistical/fences/fence_4rod_02.cgf" },
    { n = "fence_4rod_03",     m = "objects/manmade/structures/logistical/fences/fence_4rod_03.cgf" },
    { n = "fence_4rod_end",    m = "objects/manmade/structures/logistical/fences/fence_4rod_end.cgf" },
    { n = "fence_planks_03",   m = "objects/manmade/structures/logistical/fences/fence_planks_a_03.cgf" },
    { n = "fence_planks_05",   m = "objects/manmade/structures/logistical/fences/fence_planks_a_05.cgf" },
    { n = "fence_planks_end",  m = "objects/manmade/structures/logistical/fences/fence_planks_a_end.cgf" },

    -- Rustic / stick fences (rougher, camp-like)
    { n = "fence_rural_a",     m = "objects/manmade/structures/logistical/fences/fence_rural_a.cgf" },
    { n = "fence_rural_b",     m = "objects/manmade/structures/logistical/fences/fence_rural_b.cgf" },
    { n = "fence_rural_c",     m = "objects/manmade/structures/logistical/fences/fence_rural_c.cgf" },
    { n = "fence_crisscross",  m = "objects/manmade/structures/logistical/fences/fence_crisscross_end.cgf" },
    { n = "fence_sticks_a_01", m = "objects/manmade/structures/logistical/fences/fence_sticks_a_01.cgf" },
    { n = "fence_sticks_a_03", m = "objects/manmade/structures/logistical/fences/fence_sticks_a_03.cgf" },
    { n = "fence_sticks_c_02", m = "objects/manmade/structures/logistical/fences/fence_sticks_c_02.cgf" },
    { n = "fence_sticks_c_04", m = "objects/manmade/structures/logistical/fences/fence_sticks_c_04.cgf" },
    { n = "fence_sticks_d_01", m = "objects/manmade/structures/logistical/fences/fence_sticks_d_01.cgf" },
    { n = "fence_polish_01",   m = "objects/manmade/structures/logistical/fences/fence_polish_a_01.cgf" },
    { n = "fence_polish_nostx",m = "objects/manmade/structures/logistical/fences/fence_polish_a_nosticks.cgf" },
    { n = "fence_polish_tall1",m = "objects/manmade/structures/logistical/fences/fence_polish_tall_1.cgf" },

    -- Ladders (number = height in cm)
    { n = "ladder",            m = "objects/manmade/common_fixtures/ladders/ladder.cgf" },
    { n = "ladder_rustic_225", m = "objects/manmade/common_fixtures/ladders/ladder_rustic_225.cgf" },
    { n = "ladder_rustic_250", m = "objects/manmade/common_fixtures/ladders/ladder_rustic_250.cgf" },
    { n = "ladder_rustic_300", m = "objects/manmade/common_fixtures/ladders/ladder_rustic_300.cgf" },
    { n = "ladder_rustic_350", m = "objects/manmade/common_fixtures/ladders/ladder_rustic_350.cgf" },
    { n = "ladder_rustic_400", m = "objects/manmade/common_fixtures/ladders/ladder_rustic_400.cgf" },
    { n = "ladder_siege_10m",  m = "objects/manmade/common_fixtures/ladders/ladder_siege_10m.cgf" },
    { n = "ladder_broken_300", m = "objects/manmade/common_fixtures/ladders/ladder_broken_300.cgf" },
}
mercenaries.TowerRailEnts = {}

function mercenaries:TowerRailsSpawn(spacing)
    self:TowerRailsClear()
    self:TowerGallery(self.TowerRails, "TowerRail", spacing or 3.5, 1.0, self.TowerRailEnts)
    System.LogAlways("[TowerRail] merc_tower_rails_clear to remove")
end
function mercenaries:TowerRailsClear()
    for _, id in ipairs(self.TowerRailEnts or {}) do pcall(function() System.RemoveEntity(id) end) end
    self.TowerRailEnts = {}
end

System.AddCCommand("merc_tower_props",       "mercenaries:TowerPropsSpawn(%1)", "Row of archer-tower structure props, 1m up: merc_tower_props [spacing]")
System.AddCCommand("merc_tower_props_clear", "mercenaries:TowerPropsClear()",   "Remove the structure prop row")
System.AddCCommand("merc_tower_rails",       "mercenaries:TowerRailsSpawn(%1)", "Row of railing/fence/ladder candidates, 1m up: merc_tower_rails [spacing]")
System.AddCCommand("merc_tower_rails_clear", "mercenaries:TowerRailsClear()",   "Remove the railing/ladder row")


-- ==== The tower: an exact replica of the game's own scaffolding tower ====
-- Rebuilt part-for-part from references/Prefabs/manmade/scaffolding/
-- scaffolding_tower_1wide_2high_ladder_uneven.xml (the compact 1-wide/2-high one;
-- the 3-wide and 4x6 variants were tried in play and dropped). The prefab can't
-- just be Game.SpawnPrefab'd - that needs a real prefab-host entity class, see the
-- spawn-house postmortem - so it is reassembled the same way the player house is.
--
-- Positions/quaternions are that file's values verbatim (its Rotate="a,b,c,d" read
-- as (w,x,y,z), converted with HouseQuatToEuler). The ladder is a real climbable
-- Ladder ENTITY - that class loads the mesh, physicalises it PE_STATIC and adds
-- the "@use_ladder" -> GrabOnLadder action - carrying the properties of the
-- Ladder/ladder_400 template the prefab instances, with its internal offset folded
-- in. Confirmed climbable in play.
--
-- This is the *uneven* prefab: its two pole-pairs deliberately sit at slightly
-- different heights (z 0.72 vs 0.50) to take up sloping ground.
local SCAF = "objects/manmade/structures/scafolding/"

mercenaries.TowerParts = {
    { model = SCAF .. "scaffolding_handrail_c.cgf",          x = -1.134644, y = -0.725514, z = 0.741791, qw = 1, qx = 0, qy = 0, qz = 0 },
    { model = SCAF .. "scaffolding_handrail_c.cgf",          x =  1.178375, y = -0.769817, z = 2.866657, qw = 4.371139e-08, qx = 0, qy = 0, qz = 1 },
    { model = SCAF .. "scaffolding_beam_support_a.cgf",      x =  0.521000, y =  0.091393, z = 0.504337, qw = 0.7071068, qx = 0, qy = 0, qz = 0.7071068 },
    { model = SCAF .. "scaffolding_beam_support_b.cgf",      x = -0.540184, y = -0.098377, z = 0.504337, qw = 0.7071067, qx = 0, qy = 0, qz = -0.7071068 },
    { model = SCAF .. "scaffolding_main_beam_c.cgf",         x = -1.139229, y = -0.725514, z = 0.722488, qw = 1, qx = 0, qy = 0, qz = 0 },
    { model = SCAF .. "scaffolding_main_beam_c.cgf",         x =  1.360771, y = -0.725514, z = 0.504337, qw = 1, qx = 0, qy = 0, qz = 0 },
    { model = SCAF .. "scaffolding_floor_only_ladder_a.cgf", x = -1.139229, y = -0.725514, z = 2.113335, qw = 1, qx = 0, qy = 0, qz = 0 },
    { model = SCAF .. "scaffolding_floor_only_ladder_a.cgf", x = -1.139229, y = -0.725514, z = 4.515823, qw = 1, qx = 0, qy = 0, qz = 0 },
}

mercenaries.TowerLadders = {
    { model = "objects/manmade/common_fixtures/ladders/ladder_rustic_400.cgf", height = 4,
      so = "Ladder_400", guid = "450aabee-95e7-4ff6-eca8-3d783b1664ae",
      x = 0.223284, y = -0.789013, z = 0.522682,
      qw = 0.7064338, qx = 0.03084356, qy = -0.03084356, qz = -0.7064338 },
}

-- How deep the whole tower sits in the ground (negative = sunk). This is the lever
-- for the archer's height: he stands on the TOP deck, so sinking the tower is what
-- brings his vantage down low enough to depress his aim onto nearby targets while
-- still overlooking the camp. Tune live with merc_tower_sink.
mercenaries.TowerSink = -2.1

-- COLLIDERS: the deck meshes carry no player collision of their own (big
-- structures keep theirs in a separate cv_*.cgf - the spawn-house finding), so
-- each walkable deck gets an invisible scaled crate, exactly like the player
-- house's walls. Positions are tower-local (the same frame as TowerParts); scale
-- multiplies the crate mesh. Values below were tuned in play (merc_tower_col_*);
-- re-tune any time and merc_tower_col_dump to get a fresh block to paste here.
mercenaries.TowerColliderModel = "objects/manmade/common_furniture/crates/crate_low_a.cgf"
mercenaries.TowerCollidersVisible = false   -- merc_tower_col_show 1 to see them while tuning
-- Collider on the TOP deck (z 4.52) - the archer stands up top. His height is
-- brought down not by moving him to the mid deck but by sinking the whole tower
-- into the ground (TowerSink / merc_tower_sink), so he keeps the top-deck vantage
-- at a workable absolute height.
mercenaries.TowerColliders = {
    { n = "deck", x = -0.99, y = -0.73, z = 4.52, sx = 2.50, sy = 2.50, sz = 0.30 },
}

-- Where the tower's archer ends up, in the same tower-local frame: standing on
-- the TOP deck's collider slab (see above). He is not placed AT this point - he
-- is dropped onto it from StaticArcherDropHeight above (a NPC put exactly on a
-- footing gets shoved out of it or tunnels through), and he is never
-- navmesh-grounded up there, so the collider is all that holds him. See
-- mercenaries_static_archer.lua. Tune with merc_tower_archer_z.
-- x is the outward/facing axis (local +x = st.yaw); more positive backs him off the
-- front ledge he shoots over; z is his standing height on the deck.
mercenaries.TowerArcherLocal = { x = -0.79, y = -0.73, z = 4.65 }
mercenaries.TowerArcherMode = "defend"
-- The archer is spawned this long AFTER the tower, not with it: a collider
-- spawned in the same frame is not physicalised/registered yet, so an archer
-- placed immediately drops straight through the deck. Waiting for the structure
-- to exist first is what makes the placement reliable rather than a coin-flip.
mercenaries.TowerArcherDelay = 2000

mercenaries.TowerStationDist = 10.0
mercenaries.TowerStation = nil   -- { ids =, cols =, origin =, yaw = } while up

-- One tower part, spawned STATIC (mercenaries_Prop) so anything whose mesh does
-- carry a physics proxy collides.
function mercenaries:TowerSpawnPart(p, origin, yaw, track)
    local wp = self:HouseLocalToWorld(origin, yaw, p.x, p.y, p.z)
    local rx, ry, rz = self:HouseQuatToEuler(p.qx or 0, p.qy or 0, p.qz or 0, p.qw or 1)
    rz = rz + yaw
    local params = {
        name = "MercTowerPart_" .. tostring(math.random(100000, 999999)),
        position = wp,
        orientation = { x = rx, y = ry, z = rz },
        properties = { object_Model = p.model, bMissionCritical = false,
                       bSaved_by_game = false, bSerialize = false },
    }
    params.class = "mercenaries_Prop"
    local ent = System.SpawnEntity(params)
    if not ent then
        params.class = "BasicEntity"
        params.properties.Physics = { bPhysicalize = true, bRigidBody = false, Mass = 0, Density = 0, bPushableByPlayers = false }
        ent = System.SpawnEntity(params)
    end
    if ent then
        pcall(function() ent:SetAngles({ x = rx, y = ry, z = rz }) end)
        pcall(function() ent:SetViewDistUnlimited() end)
        pcall(function() ent:RenderShadow(true) end)
        table.insert(track, ent.id)
    end
    return ent
end

function mercenaries:TowerSpawnLadder(L, origin, yaw, track)
    local wp = self:HouseLocalToWorld(origin, yaw, L.x, L.y, L.z)
    local rx, ry, rz = self:HouseQuatToEuler(L.qx, L.qy, L.qz, L.qw)
    rz = rz + yaw
    local lad
    pcall(function()
        lad = System.SpawnEntity({
            class = "Ladder",
            name = "MercTowerLadder_" .. tostring(math.random(100000, 999999)),
            position = wp,
            orientation = { x = rx, y = ry, z = rz },
            properties = {
                fileModel = L.model, height = L.height,
                guidSmartObjectType = L.guid, soclass_SmartObjectHelpers = L.so,
                bUsable = true, bSaved_by_game = false,
            },
        })
    end)
    if lad then
        pcall(function() lad:SetAngles({ x = rx, y = ry, z = rz }) end)
        table.insert(track, lad.id)
    end
    return lad
end

-- (Re)spawn collider `i` live, so a tuner nudge shows up immediately.
function mercenaries:TowerColApply(i)
    local st = self.TowerStation
    if not st then return end
    local c = self.TowerColliders[i]
    if not c then return end
    if st.cols[i] then pcall(function() System.RemoveEntity(st.cols[i]) end); st.cols[i] = nil end
    local wp = self:HouseLocalToWorld(st.origin, st.yaw, c.x, c.y, c.z)
    local params = {
        class = "mercenaries_Prop",
        name = "MercTowerCol_" .. i .. "_" .. tostring(math.random(100000, 999999)),
        position = wp,
        orientation = { x = math.cos(st.yaw), y = math.sin(st.yaw), z = 0 },
        scale = { x = c.sx, y = c.sy, z = c.sz },
        properties = { object_Model = self.TowerColliderModel, bMissionCritical = false,
                       bSaved_by_game = false, bSerialize = false },
    }
    local ent = System.SpawnEntity(params)
    if not ent then
        params.class = "BasicEntity"
        params.properties.Physics = { bPhysicalize = true, bRigidBody = false, Mass = 0, Density = 0, bPushableByPlayers = false }
        ent = System.SpawnEntity(params)
    end
    if ent then
        pcall(function() ent:SetAngles({ x = 0, y = 0, z = st.yaw }) end)
        if not self.TowerCollidersVisible then pcall(function() ent:DrawSlot(0, 0) end) end
        st.cols[i] = ent.id
    end
end

-- Build the tower. With no args it uses the last placed spot if there is one (so
-- merc_tower_sink and other re-tunes rebuild in place), else a fixed offset ahead
-- of the player. `atPos`/`atYaw` (from aim-placement) set and remember a new spot.
function mercenaries:SpawnTowerStation(atPos, atYaw)
    self:TowerStationClear()
    if not player then return end
    if atPos then
        self.TowerPlacedPos = { x = atPos.x, y = atPos.y, z = atPos.z }
        self.TowerPlacedYaw = atYaw
    end
    local yaw, origin
    if self.TowerPlacedPos then
        origin = { x = self.TowerPlacedPos.x, y = self.TowerPlacedPos.y, z = self.TowerPlacedPos.z }
        if self.TowerPlacedYaw ~= nil then
            yaw = self.TowerPlacedYaw
        else
            local pang; pcall(function() pang = player:GetWorldAngles() end)
            yaw = (pang and pang.z) or 0
        end
    else
        local o = player:GetWorldPos()
        local pang; pcall(function() pang = player:GetWorldAngles() end)
        yaw = (pang and pang.z) or 0
        origin = { x = o.x + math.cos(yaw) * self.TowerStationDist,
                   y = o.y + math.sin(yaw) * self.TowerStationDist, z = o.z }
        -- remember it so sink/tuning re-tunes rebuild here, not wherever I've walked to
        self.TowerPlacedPos = { x = origin.x, y = origin.y, z = origin.z }
        self.TowerPlacedYaw = yaw
    end
    if self.CampSnapToGround then origin = self:CampSnapToGround(origin) end
    origin.z = origin.z + self.TowerSink

    local st = { origin = origin, yaw = yaw, ids = {}, cols = {} }
    self.TowerStation = st

    for _, p in ipairs(self.TowerParts) do self:TowerSpawnPart(p, origin, yaw, st.ids) end
    local nl = 0
    for _, L in ipairs(self.TowerLadders) do
        if self:TowerSpawnLadder(L, origin, yaw, st.ids) then nl = nl + 1 end
    end
    for i = 1, #self.TowerColliders do self:TowerColApply(i) end

    -- The archer who mans it follows in a moment, once the deck collider above is
    -- actually physicalised - see TowerArcherDelay.
    Script.SetTimerForFunction(self.TowerArcherDelay, "mercenaries.TowerSpawnArcherDelayed")

    System.LogAlways(string.format("[Tower] built: %d parts, %d/%d ladders, %d colliders, sunk %.2fm - archer in %dms",
        #self.TowerParts, nl, #self.TowerLadders, #self.TowerColliders, self.TowerSink, self.TowerArcherDelay))
    System.LogAlways("[Tower] tune: merc_tower_col_show 1 | merc_tower_col_sel <i> | merc_tower_col_move <dx> <dy> <dz> | merc_tower_col_scale <sx> <sy> <sz> | merc_tower_col_dump")
    self:TowerColList()
end

-- Deferred archer spawn (see TowerArcherDelay). No-ops if the tower came down in
-- the meantime, or already has its archer.
function mercenaries.TowerSpawnArcherDelayed()
    local self = mercenaries
    local st = self.TowerStation
    if not st or st.archer then return end
    local a = self.TowerArcherLocal
    local ap = self:HouseLocalToWorld(st.origin, st.yaw, a.x, a.y, a.z)
    st.archerPos = ap
    st.archer = self:SpawnStaticArcher(ap, self.TowerArcherMode, st.yaw)
    System.LogAlways("[Tower] archer " .. (st.archer and ("manned the deck (" .. self.TowerArcherMode .. ")") or "FAILED"))
    -- Once he has settled onto the deck, pin him for good by attaching him to a
    -- static unscaled anchor (the winning merc_tower_hold #6 method) - that holds an
    -- NPC off the ground where nothing else did, and unlike the slab it does not
    -- squash him. Deferred so he is standing before the attach snaps his transform.
    if st.archer then Script.SetTimerForFunction(2500, "mercenaries.TowerAttachArcherDelayed") end
end

function mercenaries.TowerAttachArcherDelayed()
    local self = mercenaries
    local st = self.TowerStation
    if not (st and st.archer and st.archerPos) then return end
    self:AttachStaticArcher(st.archer, st.archerPos, st.yaw)
end

function mercenaries:TowerStationClear()
    local st = self.TowerStation
    if not st then return end
    for _, id in ipairs(st.ids or {}) do pcall(function() System.RemoveEntity(id) end) end
    for _, id in pairs(st.cols or {}) do pcall(function() System.RemoveEntity(id) end) end
    if st.archer then pcall(function() self:RemoveStaticArcher(st.archer) end) end
    self.TowerStation = nil
end

-- Debug: spawn fresh ahead of the player (forgets any placed spot).
function mercenaries:SpawnTowerAhead()
    self.TowerPlacedPos = nil
    self.TowerPlacedYaw = nil
    self:SpawnTowerStation()
end

-- ==== PLACEMENT: aim + F2 ====
-- Ported from references/spawn house (villagebuilding's building mode): each tick,
-- raycast from the camera, show a ghost model at the crosshair; F2 raises the real
-- tower there, F3 cancels. The upgrade purchase (LogiBuyTower) just calls
-- StartTowerPlacement - buying it enables placing, nothing more (no persistence yet).
mercenaries.TowerBuildActive = false
mercenaries.TowerPreviewId = nil
mercenaries.TowerBuildPos = nil
mercenaries.TowerBuildAngle = 0.0
-- A single representative ghost (one main beam) - the whole composite is too heavy
-- to respawn every tick; this just marks the spot/footing.
mercenaries.TowerPreviewModel = "objects/manmade/structures/scafolding/scaffolding_main_beam_c.cgf"

-- Raycast from the camera; world position under the crosshair (terrain + static only).
function mercenaries:TowerLookedAtPos()
    local result = nil
    pcall(function()
        local camPos, camDir
        pcall(function() camPos = System.GetViewCameraPos() end)
        pcall(function() camDir = System.GetViewCameraDir() end)
        if not (camPos and camDir) then
            local pp = player:GetWorldPos()
            local d = player:GetDirectionVector()
            if pp and d then camPos = { x = pp.x, y = pp.y, z = pp.z + 1.7 }; camDir = d end
        end
        if not (camPos and camDir) then return end
        local range = 100
        local hits = {}
        local n = Physics.RayWorldIntersection(camPos,
            { x = camDir.x * range, y = camDir.y * range, z = camDir.z * range },
            2, ent_terrain + ent_static, player.id, nil, hits)
        if n and n > 0 and hits[1] and hits[1].pos then
            result = { x = hits[1].pos.x, y = hits[1].pos.y, z = hits[1].pos.z }
        end
    end)
    return result
end

function mercenaries:TowerDespawnPreview()
    if self.TowerPreviewId then
        pcall(function() System.RemoveEntity(self.TowerPreviewId) end)
        self.TowerPreviewId = nil
    end
end

function mercenaries.TowerBuildTick()
    local self = mercenaries
    if not self.TowerBuildActive then return end
    pcall(function()
        self:TowerDespawnPreview()
        local pos = self:TowerLookedAtPos()
        if pos then
            self.TowerBuildPos = pos
            if player then
                local pp = player:GetWorldPos()
                -- face the tower (and its archer) outward, away from where you stand
                self.TowerBuildAngle = math.atan2(pos.y - pp.y, pos.x - pp.x)
            end
            local ent = System.SpawnEntity({
                class = "BasicEntity",
                name = "MercTowerPreview_" .. tostring(math.random(100000, 999999)),
                position = pos,
                properties = { object_Model = self.TowerPreviewModel, bMissionCritical = false,
                               bSaved_by_game = false, bSerialize = false },
            })
            if ent then pcall(function() ent:SetViewDistUnlimited() end); self.TowerPreviewId = ent.id end
        end
    end)
    Script.SetTimerForFunction(250, "mercenaries.TowerBuildTick")
end

function mercenaries:StartTowerPlacement()
    if self.TowerBuildActive then
        Game.SendInfoText("Already placing the tower - aim and press F2.", false, 0, 3)
        return
    end
    self.TowerBuildActive = true
    self.TowerBuildPos = nil
    pcall(function() System.ExecuteCommand("bind f2 merc_tower_place") end)
    pcall(function() System.ExecuteCommand("bind f3 merc_tower_place_cancel") end)
    Game.SendInfoText("Aim at a spot, F2 to raise the tower (F3 to cancel).", false, 0, 5)
    Script.SetTimerForFunction(100, "mercenaries.TowerBuildTick")
end

function mercenaries:EndTowerPlacement()
    self.TowerBuildActive = false
    self:TowerDespawnPreview()
end

function mercenaries:ConfirmTowerPlacement()
    if not self.TowerBuildActive then Game.SendInfoText("You're not placing a tower right now.", false, 0, 3); return end
    if not self.TowerBuildPos then Game.SendInfoText("Aim at solid ground first.", false, 0, 3); return end
    local pos, angle = self.TowerBuildPos, self.TowerBuildAngle
    self:EndTowerPlacement()
    self:SpawnTowerStation(pos, angle)
    Game.SendInfoText("Tower raised.", false, 0, 3)
end

function mercenaries:CancelTowerPlacement()
    if not self.TowerBuildActive then return end
    self:EndTowerPlacement()
    Game.SendInfoText("Tower placement cancelled.", false, 0, 3)
end

-- ==== Collider tuner ====
mercenaries.TowerColSel = 1

function mercenaries:TowerColList()
    for i, c in ipairs(self.TowerColliders) do
        System.LogAlways(string.format("[TowerCol] %d %-9s pos=(%.2f, %.2f, %.2f) scale=(%.2f, %.2f, %.2f)%s",
            i, c.n, c.x, c.y, c.z, c.sx, c.sy, c.sz, (self.TowerColSel == i) and "  <-- selected" or ""))
    end
end

function mercenaries:TowerColSelect(i)
    i = tonumber(i)
    if not (i and self.TowerColliders[i]) then self:TowerColList(); return end
    self.TowerColSel = i
    System.LogAlways("[TowerCol] selected " .. i .. " = " .. self.TowerColliders[i].n)
end

-- Nudge the selected collider, in tower-local metres: dx = across the pole-pairs,
-- dy = the other horizontal, dz = height.
function mercenaries:TowerColMove(dx, dy, dz)
    local c = self.TowerColliders[self.TowerColSel]; if not c then return end
    c.x = c.x + (tonumber(dx) or 0)
    c.y = c.y + (tonumber(dy) or 0)
    c.z = c.z + (tonumber(dz) or 0)
    self:TowerColApply(self.TowerColSel)
    System.LogAlways(string.format("[TowerCol] %s pos = (%.2f, %.2f, %.2f)", c.n, c.x, c.y, c.z))
end

-- Set the selected collider's scale (multiplier on the crate mesh). Pass all
-- three, or leave one blank to keep it.
function mercenaries:TowerColScale(sx, sy, sz)
    local c = self.TowerColliders[self.TowerColSel]; if not c then return end
    if sx and sx ~= "" and tonumber(sx) then c.sx = tonumber(sx) end
    if sy and sy ~= "" and tonumber(sy) then c.sy = tonumber(sy) end
    if sz and sz ~= "" and tonumber(sz) then c.sz = tonumber(sz) end
    self:TowerColApply(self.TowerColSel)
    System.LogAlways(string.format("[TowerCol] %s scale = (%.2f, %.2f, %.2f)", c.n, c.sx, c.sy, c.sz))
end

-- Colliders are invisible in play; show them to tune.
function mercenaries:TowerColShow(v)
    self.TowerCollidersVisible = (tonumber(v) == 1)
    for i = 1, #self.TowerColliders do self:TowerColApply(i) end
    System.LogAlways("[TowerCol] colliders " .. (self.TowerCollidersVisible and "VISIBLE" or "hidden"))
end

-- Add another collider (e.g. for the lower deck), copied from the selected one.
function mercenaries:TowerColAdd(name)
    local c = self.TowerColliders[self.TowerColSel] or { x = 0, y = 0, z = 1, sx = 1, sy = 1, sz = 1 }
    table.insert(self.TowerColliders, {
        n = (name and name ~= "" and name) or ("col_" .. (#self.TowerColliders + 1)),
        x = c.x, y = c.y, z = c.z, sx = c.sx, sy = c.sy, sz = c.sz })
    self.TowerColSel = #self.TowerColliders
    self:TowerColApply(self.TowerColSel)
    self:TowerColList()
end

function mercenaries:TowerColDump()
    System.LogAlways("[TowerCol] --- current colliders ---")
    for _, c in ipairs(self.TowerColliders) do
        System.LogAlways(string.format('    { n = "%s", x = %.2f, y = %.2f, z = %.2f, sx = %.2f, sy = %.2f, sz = %.2f },',
            c.n, c.x, c.y, c.z, c.sx, c.sy, c.sz))
    end
    System.LogAlways(string.format("    -- TowerSink = %.2f", self.TowerSink))
end

-- How deep the whole tower sits in the ground (negative = sunk). Respawns it.
function mercenaries:TowerSetSink(v)
    self.TowerSink = tonumber(v) or self.TowerSink
    System.LogAlways("[Tower] sink = " .. tostring(self.TowerSink))
    self:SpawnTowerStation()
end

-- Re-drop the tower's archer at a different deck height, without rebuilding the
-- whole tower. One arg = the tower-local z he should end up standing at; a second
-- optional arg sets how far above that he is dropped from.
function mercenaries:TowerArcherZ(z, drop)
    local st = self.TowerStation
    if not st then System.LogAlways("[Tower] not spawned"); return end
    if z and z ~= "" and tonumber(z) then self.TowerArcherLocal.z = tonumber(z) end
    if drop and drop ~= "" and tonumber(drop) then self.StaticArcherDropHeight = tonumber(drop) end
    if st.archer then pcall(function() self:RemoveStaticArcher(st.archer) end); st.archer = nil end
    local a = self.TowerArcherLocal
    local ap = self:HouseLocalToWorld(st.origin, st.yaw, a.x, a.y, a.z)
    st.archerPos = ap
    st.archer = self:SpawnStaticArcher(ap, self.TowerArcherMode, st.yaw)
    if st.archer then Script.SetTimerForFunction(2500, "mercenaries.TowerAttachArcherDelayed") end
    System.LogAlways(string.format("[Tower] archer z = %.2f, dropped from %.2f above", a.z, self.StaticArcherDropHeight))
end

System.AddCCommand("merc_tower_spawn",     "mercenaries:SpawnTowerAhead()",               "Spawn the scaffolding tower fresh ahead of you (parts, climbable ladder, deck collider)")
System.AddCCommand("merc_tower_clear",     "mercenaries:TowerStationClear()",             "Remove the tower")
System.AddCCommand("merc_tower_build",        "mercenaries:StartTowerPlacement()",   "Enter tower placement mode: aim at a spot, F2 to place, F3 to cancel")
System.AddCCommand("merc_tower_place",        "mercenaries:ConfirmTowerPlacement()", "Place the tower at the ghost marker (bound to F2 in placement mode)")
System.AddCCommand("merc_tower_place_cancel", "mercenaries:CancelTowerPlacement()",  "Cancel tower placement (bound to F3 in placement mode)")
System.AddCCommand("merc_tower_sink",      "mercenaries:TowerSetSink(%1)",                "Move the tower into the ground (negative = deeper), e.g. -2.0 - lowers the on-top archer's height. Respawns it.")
System.AddCCommand("merc_tower_archer_z",  "mercenaries:TowerArcherZ('%1', '%2')",        "Re-drop the tower archer: merc_tower_archer_z <deck z> [drop height]")
System.AddCCommand("merc_tower_col_show",  "mercenaries:TowerColShow(%1)",                "Show/hide the deck colliders while tuning: merc_tower_col_show <0|1>")
System.AddCCommand("merc_tower_col_list",  "mercenaries:TowerColList()",                  "List the deck colliders")
System.AddCCommand("merc_tower_col_sel",   "mercenaries:TowerColSelect(%1)",              "Select a collider to tune")
System.AddCCommand("merc_tower_col_move",  "mercenaries:TowerColMove(%1, %2, %3)",        "Nudge selected collider: merc_tower_col_move <dx> <dy> <dz>")
System.AddCCommand("merc_tower_col_scale", "mercenaries:TowerColScale('%1', '%2', '%3')", "Set selected collider scale: merc_tower_col_scale <sx> <sy> <sz>")
System.AddCCommand("merc_tower_col_add",   "mercenaries:TowerColAdd('%1')",               "Add another collider (copy of selected): merc_tower_col_add [name]")
System.AddCCommand("merc_tower_col_dump",  "mercenaries:TowerColDump()",                  "Print the tuned colliders + sink for baking in")

-- ==== FOOTING TEST (merc_tower_foot) ====
-- The deck collider blocks the PLAYER but not an NPC - the archer drops straight
-- through it to the ground. Runtime navmesh is not an option (NavigationSeedPoint
-- is a bake-time seed), so an NPC up a tower has to be held by a real physics
-- surface. This spawns a row of candidate footings FLOATING at `height`, each
-- with a static archer placed on top: walk the row and note which archers are
-- still standing. Whichever footing holds one is the tower's deck collider.
--
-- The variants deliberately separate the three suspects:
--   * gcc_interactive - mercenaries_Prop sets bInteractiveCollisionClass, and
--     that class may well be player-interaction only (the Ladder entity toggles
--     exactly this flag). "interactive=false" clears it.
--   * scaled proxies - SetScale may not scale the collision proxy, only the mesh
--     (the spawn-house mod flagged this as unknown). The "unscaled" rows test it.
--   * the mesh itself - some meshes carry a baked physics proxy, some keep it in
--     a separate cv_*.cgf and are pass-through. primitive_box and the bridge deck
--     are the best bets (the spawn-house mod uses that deck AS a walkable floor).
local CRATE = "objects/manmade/common_furniture/crates/crate_low_a.cgf"
mercenaries.FootTests = {
    { n = "crate_interactive_OFF", m = CRATE, sc = { 2.5, 2.5, 0.3 }, inter = false },
    { n = "crate_interactive_ON",  m = CRATE, sc = { 2.5, 2.5, 0.3 }, inter = true  },
    { n = "crate_unscaled",        m = CRATE, sc = nil,               inter = false },
    { n = "primitive_box",         m = "objects/default/primitive_box.cgf", sc = { 2.5, 2.5, 0.3 }, inter = false },
    { n = "primitive_box_unscaled",m = "objects/default/primitive_box.cgf", sc = nil,               inter = false },
    { n = "bridge_deck_half",      m = "objects/manmade/structures/logistical/bridges/common_bridge_deck_half.cgf", sc = nil, inter = false },
    { n = "scaffold_deck_a",       m = "objects/manmade/structures/scafolding/scaffolding_floor_only_a.cgf",        sc = nil, inter = false },
    { n = "stone_fence_5m",        m = "objects/manmade/structures/logistical/fences/stone_fence_5m.cgf",           sc = nil, inter = false },
}
mercenaries.FootTestEnts = {}
mercenaries.FootTestArchers = {}
mercenaries.FootTestSpots = {}

function mercenaries.FootTestArchersDelayed()
    local self = mercenaries
    for _, s in ipairs(self.FootTestSpots or {}) do
        local a = self:SpawnStaticArcher({ x = s.x, y = s.y, z = s.z }, "defend", s.yaw)
        if a then table.insert(self.FootTestArchers, a) end
    end
    self.FootTestSpots = {}
end

function mercenaries:FootTestSpawn(height, spacing)
    self:FootTestClear()
    if not player then return end
    height = tonumber(height) or 3.0
    spacing = tonumber(spacing) or 6.0
    local o = player:GetWorldPos()
    local ang; pcall(function() ang = player:GetWorldAngles() end)
    local yaw = (ang and ang.z) or 0
    local fx, fy = math.cos(yaw), math.sin(yaw)
    local rx, ry = -fy, fx

    System.LogAlways("[FootTest] === which footing holds an NPC? (archers still standing = it works) ===")
    for i, t in ipairs(self.FootTests) do
        local lat = (i - 1) * spacing
        local base = { x = o.x + fx * 8.0 + rx * lat, y = o.y + fy * 8.0 + ry * lat, z = o.z }
        if self.CampSnapToGround then base = self:CampSnapToGround(base) end
        local fp = { x = base.x, y = base.y, z = base.z + height }

        local params = {
            class = "mercenaries_Prop",
            name = "MercTowerFoot_" .. i .. "_" .. tostring(math.random(100000, 999999)),
            position = fp,
            orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
            properties = { object_Model = t.m, bMissionCritical = false,
                           bSaved_by_game = false, bSerialize = false,
                           bInteractiveCollisionClass = t.inter },
        }
        if t.sc then params.scale = { x = t.sc[1], y = t.sc[2], z = t.sc[3] } end
        local e
        pcall(function() e = System.SpawnEntity(params) end)
        if e then
            pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw }) end)
            pcall(function() e:SetViewDistUnlimited() end)
            table.insert(self.FootTestEnts, e.id)
        end

        -- Where his archer goes; the archers themselves follow once the footings
        -- are physicalised (same reason as the tower - see TowerArcherDelay).
        table.insert(self.FootTestSpots, { x = fp.x, y = fp.y, z = fp.z + 0.15, yaw = yaw + math.pi })
        System.LogAlways(string.format("[FootTest] #%-2d %-24s %s", i, t.n, e and "spawned" or "FAILED"))
    end
    Script.SetTimerForFunction(self.TowerArcherDelay, "mercenaries.FootTestArchersDelayed")
    System.LogAlways("[FootTest] footings are " .. height .. "m up, " .. spacing ..
        "m apart to your right; archers land in " .. self.TowerArcherDelay ..
        "ms. Note which numbers still have an archer on top; merc_tower_foot_clear to remove")
end

function mercenaries:FootTestClear()
    for _, id in ipairs(self.FootTestEnts or {}) do pcall(function() System.RemoveEntity(id) end) end
    self.FootTestEnts = {}
    for _, a in ipairs(self.FootTestArchers or {}) do pcall(function() self:RemoveStaticArcher(a) end) end
    self.FootTestArchers = {}
end

System.AddCCommand("merc_tower_foot",       "mercenaries:FootTestSpawn(%1, %2)", "Row of candidate NPC footings, each with an archer on top: merc_tower_foot [height] [spacing]")
System.AddCCommand("merc_tower_foot_clear", "mercenaries:FootTestClear()",       "Remove the footing test")


-- ==== HOLD TEST (merc_tower_hold) ====
-- The footing was never the problem: a static slab stops rigid bodies, but an NPC
-- is ground-snapped to the NAVMESH by its movement controller, and there is no
-- navmesh up on a deck - so the slab holds him for a frame and the AI snap pulls
-- him down after. The 1s global keeper only notices a second later; that lag IS
-- the "falls through, then teleports back up" the player sees.
--
-- So the fix has to stop him FALLING, not catch him afterwards. Every cell here
-- gets the SAME visible slab at `height`; only the hold STRATEGY differs. The
-- global keeper is switched off for these archers (rec.holdTest), so each strategy
-- is judged raw. Walk the row and note which archer (1) stays up on its own and
-- (2) still looses arrows at a nearby enemy - a hold that freezes his shooting is
-- no good. Tell me the winning number and it becomes how the tower archer is held.
local HOLD_SLAB = "objects/manmade/common_furniture/crates/crate_low_a.cgf"
mercenaries.HoldTests = {
    { n = "1_control",     note = "no hold (keeper off) - the bug, for reference" },
    { n = "2_fast_keeper", note = "re-pin every 50ms if he slips >0.1m", fast = true },
    { n = "3_physics_off", note = "EnablePhysics(0) after landing",
      apply = function(self, ent) ent:EnablePhysics(0) end },
    { n = "4_awake_off",   note = "AwakePhysics(0) after landing",
      apply = function(self, ent) ent:AwakePhysics(0) end },
    { n = "5_no_gravity",  note = "physics sim gravity set to 0",
      apply = function(self, ent) ent:SetPhysicParams(PHYSICPARAM_SIMULATION, { gravity = { x = 0, y = 0, z = 0 } }) end },
    { n = "6_attach_slab", note = "AttachChild archer to the static slab",
      apply = function(self, ent, slab) if slab then slab:AttachChild(ent.id, 0) end end },
}
mercenaries.HoldTestSpots = {}
mercenaries.HoldTestArchers = {}
mercenaries.HoldTestActive = false

-- Fast keeper for the "2_fast_keeper" cells only: re-pin to the anchor the instant
-- he slips more than 0.1m, at 50ms - fast/tight enough that the drop is invisible,
-- unlike the 1s/1.8m global keeper. Re-arms itself while the test is up.
function mercenaries.HoldTestFastKeep()
    local self = mercenaries
    if not self.HoldTestActive then return end
    for ws, rec in pairs(self.StaticArchers) do
        if rec.fastKeep and rec.anchor and rec.ent and not self.StaticArcherPending[ws] then
            pcall(function()
                local cur = rec.ent:GetWorldPos()
                if cur and cur.z < (rec.anchor.z - 0.1) then
                    rec.ent:SetPos({ x = rec.anchor.x, y = rec.anchor.y, z = rec.anchor.z })
                end
            end)
        end
    end
    Script.SetTimerForFunction(50, "mercenaries.HoldTestFastKeep")
end

-- Archers land ~2.5s after this fires (they are dropped, see StaticArcherPlaceTick);
-- only then is it safe to apply a strategy that assumes he is already standing.
function mercenaries.TowerHoldApplyDelayed()
    local self = mercenaries
    for _, s in ipairs(self.HoldTestSpots) do
        if s.archer and s.t.apply then
            local ok = pcall(function() s.t.apply(self, s.archer, s.slab) end)
            System.LogAlways("[TowerHold] " .. s.t.n .. " strategy " .. (ok and "applied" or "FAILED (api missing)"))
        end
    end
    System.LogAlways("[TowerHold] spawn an enemy near the row and watch which archer stays up AND shoots")
end

function mercenaries.TowerHoldArchersDelayed()
    local self = mercenaries
    for _, s in ipairs(self.HoldTestSpots) do
        local a = self:SpawnStaticArcher({ x = s.x, y = s.y, z = s.z }, "defend", s.yaw)
        if a then
            local ws = tostring(a.this and a.this.id or a.id)
            local rec = self.StaticArchers[ws]
            if rec then rec.holdTest = true; rec.holdStrategy = s.t.n; if s.t.fast then rec.fastKeep = true end end
            s.archer = a
            table.insert(self.HoldTestArchers, a)
        end
    end
    self.HoldTestActive = true
    Script.SetTimerForFunction(50, "mercenaries.HoldTestFastKeep")
    Script.SetTimerForFunction(2500, "mercenaries.TowerHoldApplyDelayed")
end

function mercenaries:TowerHoldSpawn(height, spacing)
    self:TowerHoldClear()
    if not player then return end
    height = tonumber(height) or 3.0
    spacing = tonumber(spacing) or 4.0
    local o = player:GetWorldPos()
    local ang; pcall(function() ang = player:GetWorldAngles() end)
    local yaw = (ang and ang.z) or 0
    local fx, fy = math.cos(yaw), math.sin(yaw)
    local rx, ry = -fy, fx

    System.LogAlways("[TowerHold] === which hold keeps an NPC up on a deck? ===")
    for i, t in ipairs(self.HoldTests) do
        local lat = (i - 1) * spacing
        local base = { x = o.x + fx * 8.0 + rx * lat, y = o.y + fy * 8.0 + ry * lat, z = o.z }
        if self.CampSnapToGround then base = self:CampSnapToGround(base) end
        local sp = { x = base.x, y = base.y, z = base.z + height }

        local slab
        pcall(function()
            slab = System.SpawnEntity({
                class = "mercenaries_Prop",
                name = "MercHoldSlab_" .. i .. "_" .. tostring(math.random(100000, 999999)),
                position = sp,
                orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
                scale = { x = 2.5, y = 2.5, z = 0.3 },
                properties = { object_Model = HOLD_SLAB, bMissionCritical = false,
                               bSaved_by_game = false, bSerialize = false },
            })
        end)
        if slab then pcall(function() slab:SetAngles({ x = 0, y = 0, z = yaw }) end) end

        table.insert(self.HoldTestSpots, { x = sp.x, y = sp.y, z = sp.z + 0.15, yaw = yaw + math.pi, slab = slab, t = t })
        System.LogAlways(string.format("[TowerHold] #%d %-13s %s", i, t.n, t.note))
    end
    -- Slab first, archers once it is physicalised (same reason as TowerArcherDelay).
    Script.SetTimerForFunction(self.TowerArcherDelay, "mercenaries.TowerHoldArchersDelayed")
    System.LogAlways("[TowerHold] " .. #self.HoldTests .. " slabs " .. height .. "m up, " .. spacing ..
        "m apart to your right; archers land shortly. merc_tower_hold_clear to remove")
end

function mercenaries:TowerHoldClear()
    self.HoldTestActive = false
    for _, a in ipairs(self.HoldTestArchers or {}) do pcall(function() self:RemoveStaticArcher(a) end) end
    self.HoldTestArchers = {}
    for _, s in ipairs(self.HoldTestSpots or {}) do
        if s.slab then pcall(function() System.RemoveEntity(s.slab.id) end) end
    end
    self.HoldTestSpots = {}
end

System.AddCCommand("merc_tower_hold",       "mercenaries:TowerHoldSpawn(%1, %2)", "Row of NPC-hold strategies, each with an archer on a deck slab: merc_tower_hold [height] [spacing]")
System.AddCCommand("merc_tower_hold_clear", "mercenaries:TowerHoldClear()",       "Remove the hold test")
