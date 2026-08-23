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

-- ==== Gallery 3: barricades / obstacles ====
-- Candidates for a defensive barricade upgrade. The pick of the crop is
-- objects/manmade/task_specific_props/combat/: TARASES are the Hussite war-wagon
-- barricade (plank shield-walls used to close the gaps of a wagon fort) and PAVISES
-- are the big standing shields crossbowmen sheltered behind - both are purpose-built
-- field obstacles rather than repurposed fencing. The palisade pieces (especially
-- the single_sharp stakes) are the closest thing to a spiked barricade; the fences
-- are the rougher, camp-made alternatives.
mercenaries.BarricadeProps = {
    -- purpose-built field defences
    { n = "taras_a",           m = "objects/manmade/task_specific_props/combat/tarases/taras_a.cgf" },
    { n = "taras_c",           m = "objects/manmade/task_specific_props/combat/tarases/taras_c.cgf" },
    { n = "taras_d_part",      m = "objects/manmade/task_specific_props/combat/tarases/taras_d_part.cgf" },
    { n = "pavise_a",          m = "objects/manmade/task_specific_props/combat/pavises/pavise_a.cgf" },
    { n = "pavise_b",          m = "objects/manmade/task_specific_props/combat/pavises/pavise_b.cgf" },

    -- sharpened stakes / palisade
    { n = "palisade_sharp",    m = "objects/manmade/structures/defensive/walls/palisade/palisade_wall_single_sharp.cgf" },
    { n = "palisade_a_v3",     m = "objects/manmade/structures/defensive/walls/palisade/palisade_wall_a_v3.cgf" },
    { n = "palisade_b_beam",   m = "objects/manmade/structures/defensive/walls/palisade/palisade_wall_b_beam.cgf" },
    { n = "palisade_b_v4",     m = "objects/manmade/structures/defensive/walls/palisade/palisade_wall_b_v4_trosky.cgf" },

    -- road barrier / gates
    { n = "barrier_road",      m = "objects/manmade/structures/logistical/barriers/barrier_road_natural_closed.cgf" },
    { n = "fence_sticks_gate", m = "objects/manmade/structures/logistical/fences/fence_sticks_c_gate.cgf" },
    { n = "fence_crisscross",  m = "objects/manmade/structures/logistical/fences/fence_crisscross_end.cgf" },

    -- heavier / emplacement
    { n = "cannon",            m = "objects/manmade/task_specific_props/combat/cannon.cgf" },
    { n = "cannon_ammo",       m = "objects/manmade/task_specific_props/combat/cannon_ammo.cgf" },
    { n = "wall_ruined_a",     m = "objects/manmade/structures/defensive/walls/wall_ruined/wall_ruined_piece_a.cgf" },
    { n = "stone_fence_5m",    m = "objects/manmade/structures/logistical/fences/stone_fence_5m_noterrain.cgf" },
}
mercenaries.BarricadePropEnts = {}

function mercenaries:BarricadePropsSpawn(spacing)
    self:BarricadePropsClear()
    self:TowerGallery(self.BarricadeProps, "Barricade", spacing or 4.0, 0.0, self.BarricadePropEnts)
    System.LogAlways("[Barricade] merc_barricade_clear to remove")
end
function mercenaries:BarricadePropsClear()
    for _, id in ipairs(self.BarricadePropEnts or {}) do pcall(function() System.RemoveEntity(id) end) end
    self.BarricadePropEnts = {}
end

System.AddCCommand("merc_barricade",       "mercenaries:BarricadePropsSpawn(%line)", "Row of barricade/obstacle candidates: merc_barricade [spacing]")
System.AddCCommand("merc_barricade_clear", "mercenaries:BarricadePropsClear()",      "Remove the barricade row")

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
-- Any number of towers can be up at once (place as many as you like). Each station
-- is { ids =, cols =, origin =, yaw =, placedGround =, archer =, archerPos =, dead = }.
-- Effectively no limit. A siege wants a wall's worth of them and the old cap of 5 was a
-- camp-sized budget; the number is kept rather than deleted because two code paths still read
-- it (the cap check and the placement engine's atMax).
mercenaries.TowerMaxCount = 999  -- how many archer towers may stand at once
mercenaries.TowerStations = {}   -- every live tower
mercenaries.TowerStation = nil   -- the latest one - the subject of the tuning commands
-- Deferred archer spawn/attach run off FIFO queues, not self.TowerStation: placing a
-- second tower before the first's timer fires would otherwise move the target out
-- from under it. Each build pushes its station; each timer pops the front.
mercenaries.TowerArcherSpawnQueue = {}
mercenaries.TowerArcherAttachQueue = {}

-- One tower part, spawned STATIC (mercenaries_Prop) so anything whose mesh does
-- carry a physics proxy collides.
-- `namePrefix` keeps somebody else's tower out of the player camp's global name sweep:
-- "MercTower*" is swept by ClearAnyLeftoverCamp and by the upgrade rebuild, anywhere on the
-- map, so a bandit camp's watchtower named that way vanishes when the player rebuilds theirs.
function mercenaries:TowerSpawnPart(p, origin, yaw, track, namePrefix)
    local wp = self:HouseLocalToWorld(origin, yaw, p.x, p.y, p.z)
    local rx, ry, rz = self:HouseQuatToEuler(p.qx or 0, p.qy or 0, p.qz or 0, p.qw or 1)
    rz = rz + yaw
    local params = {
        name = (namePrefix or "MercTowerPart_") .. tostring(math.random(100000, 999999)),
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

function mercenaries:TowerSpawnLadder(L, origin, yaw, track, namePrefix)
    local wp = self:HouseLocalToWorld(origin, yaw, L.x, L.y, L.z)
    local rx, ry, rz = self:HouseQuatToEuler(L.qx, L.qy, L.qz, L.qw)
    rz = rz + yaw
    local lad
    pcall(function()
        lad = System.SpawnEntity({
            class = "Ladder",
            name = (namePrefix or "MercTowerLadder_") .. tostring(math.random(100000, 999999)),
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
        name = (st.group and "BCampQTowerCol_" or "MercTowerCol_") .. i .. "_" .. tostring(math.random(100000, 999999)),
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

-- Build ONE tower at an already-decided ground spot (pre-sink) + yaw, and add it to
-- the live list. Never clears anything - placing another just calls this again.
-- `opts` (optional) makes this tower somebody else's: { mode = "hostile", group = "bandit" }
-- gives a bandit-camp watchtower whose archer shoots the player and the mercs. Omitted, it
-- is the player's own tower exactly as before.
function mercenaries:TowerBuildStation(ground, yaw, opts)
    if not player then return nil end
    local origin = { x = ground.x, y = ground.y, z = ground.z }
    if self.CampSnapToGround then origin = self:CampSnapToGround(origin) end
    origin.z = origin.z + self.TowerSink

    local st = { origin = origin, yaw = yaw, ids = {}, cols = {},
                 mode = opts and opts.mode, group = opts and opts.group,
                 placedGround = { x = ground.x, y = ground.y, z = ground.z } }
    table.insert(self.TowerStations, st)
    self.TowerStation = st   -- newest becomes the tuning subject

    -- A foreign tower (bandit camp) names its parts differently so the player camp's global
    -- "MercTower*" sweep cannot take it down. See TowerSpawnPart.
    local partPrefix = st.group and "BCampQTowerPart_" or nil
    for _, p in ipairs(self.TowerParts) do self:TowerSpawnPart(p, origin, yaw, st.ids, partPrefix) end
    local nl = 0
    for _, L in ipairs(self.TowerLadders) do
        if self:TowerSpawnLadder(L, origin, yaw, st.ids, partPrefix) then nl = nl + 1 end
    end
    for i = 1, #self.TowerColliders do self:TowerColApply(i) end   -- acts on self.TowerStation = st

    -- Archer via the FIFO queue (see the queue note above): remember his world spot
    -- now, spawn him once the deck collider is physicalised.
    st.archerPos = self:HouseLocalToWorld(origin, yaw, self.TowerArcherLocal.x, self.TowerArcherLocal.y, self.TowerArcherLocal.z)
    table.insert(self.TowerArcherSpawnQueue, st)
    Script.SetTimerForFunction(self.TowerArcherDelay, "mercenaries.TowerSpawnArcherDelayed")

    System.LogAlways(string.format("[Tower] built #%d: %d parts, %d/%d ladders, %d colliders, sunk %.2fm - archer in %dms",
        #self.TowerStations, #self.TowerParts, nl, #self.TowerLadders, #self.TowerColliders, self.TowerSink, self.TowerArcherDelay))
    -- Somebody else's tower is not one of the player's defences and must not touch their
    -- saved set. DefSave filters on st.group as well; this just avoids the pointless rewrite.
    if not st.group then
        pcall(function() if self.DefSave then self:DefSave() end end)
    end
    return st
end

-- Place a NEW tower: from an aim spot (atPos/atYaw) or, with no args, a fixed offset
-- ahead of the player. Additive - existing towers stay up.
function mercenaries:SpawnTowerStation(atPos, atYaw, opts)
    if not player then return end
    -- The cap is the PLAYER's defence budget. A foreign (bandit-camp) tower is authored in
    -- a layout and trusted: it must neither be refused by the cap nor eat into it - the
    -- roman fort's four towers could not build next to a single player tower otherwise.
    if not (opts and opts.group) then
        local own = 0
        for _, st in ipairs(self.TowerStations) do
            if not st.group then own = own + 1 end
        end
        if own >= self.TowerMaxCount then
            System.LogAlways("[Tower] limit reached (" .. self.TowerMaxCount .. ") - merc_tower_clear first")
            Game.SendInfoText('merc_info_tower_limit', false, 0, 4)
            return
        end
    end
    local yaw, ground
    if atPos then
        ground = { x = atPos.x, y = atPos.y, z = atPos.z }
        if atYaw ~= nil then
            yaw = atYaw
        else
            local pang; pcall(function() pang = player:GetWorldAngles() end)
            yaw = (pang and pang.z) or 0
        end
    else
        local o = player:GetWorldPos()
        local pang; pcall(function() pang = player:GetWorldAngles() end)
        yaw = (pang and pang.z) or 0
        ground = { x = o.x + math.cos(yaw) * self.TowerStationDist,
                   y = o.y + math.sin(yaw) * self.TowerStationDist, z = o.z }
    end
    return self:TowerBuildStation(ground, yaw, opts)
end

-- Tear down the current tower and rebuild it in place (for the sink/archer tuners).
function mercenaries:RebuildCurrentTower()
    local st = self.TowerStation
    if not st then self:SpawnTowerStation(); return end
    local ground, yaw = st.placedGround, st.yaw
    self:TowerStationClearOne(st)
    self:TowerBuildStation(ground, yaw)
end

-- Deferred archer spawn (see TowerArcherDelay), FIFO - one pop per build.
function mercenaries.TowerSpawnArcherDelayed()
    local self = mercenaries
    local st = table.remove(self.TowerArcherSpawnQueue, 1)
    if not st or st.dead or st.archer then return end
    st.archer = self:SpawnStaticArcher(st.archerPos, st.mode or self.TowerArcherMode, st.yaw, st.group, true)
    System.LogAlways("[Tower] archer " .. (st.archer and ("manned the deck (" .. self.TowerArcherMode .. ")") or "FAILED"))
    -- Once he has settled onto the deck, pin him for good by attaching him to a
    -- static unscaled anchor (the winning merc_tower_hold #6 method) - that holds an
    -- NPC off the ground where nothing else did, and unlike the slab it does not
    -- squash him. Deferred so he is standing before the attach snaps his transform.
    if st.archer then
        table.insert(self.TowerArcherAttachQueue, st)
        Script.SetTimerForFunction(2500, "mercenaries.TowerAttachArcherDelayed")
    end
end

function mercenaries.TowerAttachArcherDelayed()
    local self = mercenaries
    local st = table.remove(self.TowerArcherAttachQueue, 1)
    if not (st and not st.dead and st.archer and st.archerPos) then return end
    self:AttachStaticArcher(st.archer, st.archerPos, st.yaw)
end

-- Remove one tower (its parts, colliders, archer) and drop it from the live list.
function mercenaries:TowerStationClearOne(st)
    if not st then return end
    st.dead = true   -- stop any queued archer spawn/attach from touching it
    for _, id in ipairs(st.ids or {}) do pcall(function() System.RemoveEntity(id) end) end
    for _, id in pairs(st.cols or {}) do pcall(function() System.RemoveEntity(id) end) end
    if st.archer then pcall(function() self:RemoveStaticArcher(st.archer) end); st.archer = nil end
    for i = #self.TowerStations, 1, -1 do
        if self.TowerStations[i] == st then table.remove(self.TowerStations, i) end
    end
    if self.TowerStation == st then self.TowerStation = self.TowerStations[#self.TowerStations] end
end

-- Remove every tower THE PLAYER OWNS. TowerStations is one shared list, so this used to take the
-- bandit camps' watchtowers with it: breaking camp - which fast travel does on its own - stripped
-- an Aleksej or Kleinkrieg camp of its towers mid-contract, archers and all, while the player was
-- somewhere else entirely. A station raised in "hostile" mode belongs to an encounter, and that
-- encounter's own teardown is the only thing allowed to remove it.
function mercenaries:TowerStationClearAll()
    local kept = {}
    for i = #self.TowerStations, 1, -1 do
        local st = self.TowerStations[i]
        -- st.group is set only by an encounter (SpawnTowerStation's opts) - the player's own
        -- towers carry none, which is the same test SpawnArcherCart already budgets on.
        if st and st.group then
            table.insert(kept, 1, st)
        else
            self:TowerStationClearOne(st)
        end
    end
    self.TowerStations = kept
    self.TowerStation = kept[#kept]
    System.LogAlways("[Tower] player towers removed (" .. #kept .. " encounter tower(s) left standing)")
end

-- Debug: add one more tower ahead of the player.
function mercenaries:SpawnTowerAhead()
    self:SpawnTowerStation()
end

-- ==== PLACEMENT: aim + click ====
-- Ported from references/spawn house (villagebuilding's building mode): each tick,
-- raycast from the camera and slide a white ghost to the crosshair; LMB places, RMB
-- cancels (through the Player.OnAction hook below). The engine is generic (see the
-- GENERIC PLACEMENT ENGINE section); the tower and the archer cart just hand it a
-- spec. The upgrade purchase (LogiBuyTower / LogiBuyArcherCart) starts placement.

-- GHOST: the real tower (every part + the ladder mesh, no archer) in a flat white
-- material, so what you aim is what you get. It is spawned ONCE when placement
-- starts and MOVED each tick - respawning a nine-part composite four times a second
-- would flicker badly. Ghost parts are plain BasicEntities: no mercenaries_Prop, so
-- no physics and nothing to collide with while it slides around under the crosshair.
-- MATERIAL: poses_nomultimaterial (what the vanilla trigger scripts use) renders
-- PINK - that is CryEngine's missing-material placeholder, i.e. the path does not
-- resolve at runtime. The candidates below are all materials the game's own prefab
-- data actually references, so they exist. Cycle them with merc_tower_ghost_mtl <n>.
-- (Pink is worth keeping in mind as the "invalid placement" colour later.)
mercenaries.TowerGhostMaterials = {
    "objects/manmade/task_specific_props/clothing_industry/tailoring/cloth_folded_b_linen_white",
    "objects/intermediates/elements/textures/timbered_wall_a_elements_white_bright",
    "objects/intermediates/elements/textures/timbered_wall_a_elements_plastered_beige_white",
    "objects/intermediates/elements/textures/window_halftimber_halfwhite",
    "objects/manmade/structures/defensive/fortress/suchdol/suchdol_fortress_white_decal",
}
mercenaries.TowerGhostMaterial = mercenaries.TowerGhostMaterials[1]   -- #2 in the old list, the linen white
-- The missing-material placeholder renders bright pink, which is exactly the "you
-- can't build here" signal we want - so the broken path earns its keep after all.
mercenaries.TowerGhostBadMaterial = "objects/intermediates/poses/poses_nomultimaterial"

-- VALIDITY. A tower may not land on what the camp has already built (a tower on top
-- of a tent), nor on another tower. Slight clipping is fine, so these are generous
-- rather than exact footprints; tune with merc_tower_clearance.
mercenaries.TowerCampClearRadius = 3.5   -- keep this far from any spawned camp prop
mercenaries.TowerClearRadius     = 6.0   -- and this far from another tower
mercenaries.TowerCampBlockers = {}
mercenaries.TowerBlockerScanRadius = 60.0   -- how far around camp to gather props
mercenaries._ghostValid = nil

-- Does `name` belong to a mod-spawned camp prop? Same prefixes the camp teardown
-- uses (CampPropPrefixes). Tower/ghost/anchor pieces are deliberately NOT counted
-- here - towers get their own IsSpotNearTower check, and the ghost must not block
-- itself.
function mercenaries:IsTowerBlockerName(name)
    if not name then return false end
    if string.sub(name, 1, 9)  == "MercTower" then return false end   -- towers, ghost, testers
    if string.sub(name, 1, 16) == "MercArcherAnchor" then return false end
    for _, p in ipairs(self.CampPropPrefixes or {}) do
        if string.sub(name, 1, #p) == p then return true end
    end
    return false
end

-- Snapshot every mod prop near camp when placement starts. Done by SPATIAL QUERY +
-- name, not by walking one id list: each upgrade tracks its props in its own list
-- (the food cart in its st.ids, the house in CampEntities, ...), so no single list
-- is complete - the earlier CampEntities-only version missed the cart and the rest.
-- Props don't move, so one snapshot per placement session is enough.
function mercenaries:TowerCacheCampBlockers()
    self.TowerCampBlockers = {}
    local center = self.CampCenter
    if not center and player then center = player:GetWorldPos() end
    if not center then return end
    local ents
    pcall(function() ents = System.GetEntitiesInSphere(center, self.TowerBlockerScanRadius) end)
    if not ents then return end
    for _, e in pairs(ents) do
        pcall(function()
            if e and self:IsTowerBlockerName(e:GetName() or "") then
                local p = e:GetWorldPos() or e:GetPos()
                if p then table.insert(self.TowerCampBlockers, { x = p.x, y = p.y }) end
            end
        end)
    end
    System.LogAlways("[Tower] " .. #self.TowerCampBlockers .. " camp props to build around")
end

-- Public: is `pos` inside an existing tower's footprint? Used by the camp too, so a
-- newly built tent/upgrade doesn't land on a tower (mercenaries_camp.lua).
function mercenaries:IsSpotNearTower(pos, radius)
    if not pos then return false end
    radius = radius or self.TowerClearRadius
    for _, st in ipairs(self.TowerStations or {}) do
        if st.origin then
            local dx, dy = pos.x - st.origin.x, pos.y - st.origin.y
            if (dx * dx + dy * dy) < (radius * radius) then return true end
        end
    end
    return false
end

function mercenaries:TowerSpotIsValid(pos)
    if not pos then return false end
    if self:IsSpotNearTower(pos) then return false end
    local r2 = self.TowerCampClearRadius * self.TowerCampClearRadius
    for _, b in ipairs(self.TowerCampBlockers) do
        local dx, dy = pos.x - b.x, pos.y - b.y
        if (dx * dx + dy * dy) < r2 then return false end
    end
    return true
end

-- Recolour the ghost only when validity actually flips, not every tick.
--
-- SUBMATERIAL GOTCHA: a real .mtl with a single submaterial only maps onto slot 0,
-- so on a mesh with several submaterial slots (wagon_b.cgf) every submesh bound to
-- another slot simply stops drawing - that is why the white wagon showed only wheels
-- and axle. The PINK placeholder does not have this problem: the engine substitutes
-- it for every slot, so invalid always renders the complete mesh. A spec whose mesh
-- is multi-submaterial therefore sets validMaterial = nil and keeps its own
-- materials while valid (ResetMaterial), taking pink only when blocked.
function mercenaries:GhostSetValid(valid)
    if valid == self._ghostValid then return end
    local prev = self._ghostValid
    self._ghostValid = valid
    local spec = self.ActivePlacement
    local m = spec and spec.validMaterial
    for _, g in ipairs(self.GhostParts) do
        if g.ent then
            pcall(function()
                if not valid then
                    g.ent:SetMaterial(self.TowerGhostBadMaterial)   -- pink: draws every slot
                elseif m then
                    g.ent:SetMaterial(m)                            -- white (single-material meshes only)
                elseif prev == false then
                    g.ent:ResetMaterial(0)                          -- coming back from pink: restore own materials
                end
                -- valid + own-materials + not returning from pink: leave the mesh exactly
                -- as spawned (its own materials, full mesh) - never force white on it
            end)
        end
    end
end

function mercenaries:SetTowerClearance(campR, towerR)
    if campR and campR ~= "" and tonumber(campR) then self.TowerCampClearRadius = tonumber(campR) end
    if towerR and towerR ~= "" and tonumber(towerR) then self.TowerClearRadius = tonumber(towerR) end
    System.LogAlways(string.format("[Tower] clearance: camp %.1fm, tower %.1fm",
        self.TowerCampClearRadius, self.TowerClearRadius))
end
-- ==== GENERIC GHOST (shared by every placeable: tower, archer cart, ...) ====
-- `parts` is a flat list of { model, x, y, z, rx, ry, rz } in the thing's local
-- frame. Spawned once as white BasicEntities, then slid to the aim point each tick.
mercenaries.GhostParts = {}   -- { { ent =, x,y,z, rx,ry,rz } }

-- `material` nil = leave each mesh its own materials (see the submaterial note on
-- GhostSetValid); otherwise every ghost part is forced to it.
function mercenaries:GhostBuild(parts, material)
    self:GhostClear()
    if not player then return end
    local o = player:GetWorldPos()
    for i, src in ipairs(parts) do
        local g = { model = src.model, x = src.x, y = src.y, z = src.z,
                    rx = src.rx or 0, ry = src.ry or 0, rz = src.rz or 0 }
        local e
        pcall(function()
            e = System.SpawnEntity({
                class = "BasicEntity",
                name = "MercPlaceGhost_" .. i .. "_" .. tostring(math.random(100000, 999999)),
                position = { x = o.x, y = o.y, z = o.z - 50 },   -- parked below until the first move
                properties = { object_Model = g.model, bMissionCritical = false,
                               bSaved_by_game = false, bSerialize = false },
            })
        end)
        if e then
            if material then pcall(function() e:SetMaterial(material) end) end
            pcall(function() e:SetViewDistUnlimited() end)
            g.ent = e
            table.insert(self.GhostParts, g)
        end
    end
    System.LogAlways("[Place] ghost: " .. #self.GhostParts .. "/" .. #parts .. " parts")
end

-- Slide the whole ghost to the aim point. `sink` matches the real build's z offset
-- (the tower's TowerSink, 0 for a cart) so the preview sits where it will land.
function mercenaries:GhostMove(pos, yaw, sink)
    local base = { x = pos.x, y = pos.y, z = pos.z + (sink or 0) }
    for _, g in ipairs(self.GhostParts) do
        if g.ent then
            pcall(function()
                g.ent:SetPos(self:HouseLocalToWorld(base, yaw, g.x, g.y, g.z))
                g.ent:SetAngles({ x = g.rx, y = g.ry, z = g.rz + yaw })
            end)
        end
    end
end

function mercenaries:GhostClear()
    for _, g in ipairs(self.GhostParts or {}) do
        if g.ent then pcall(function() System.RemoveEntity(g.ent.id) end) end
    end
    self.GhostParts = {}
end

-- Accepts an index into TowerGhostMaterials, or a full material path. No arg lists
-- the candidates. Applies live, so it can be judged without leaving placement mode.
function mercenaries:SetTowerGhostMaterial(m)
    if not m or m == "" then
        System.LogAlways("[Tower] ghost material = " .. self.TowerGhostMaterial)
        for i, p in ipairs(self.TowerGhostMaterials) do
            System.LogAlways(string.format("[Tower]   %d = %s", i, p))
        end
        return
    end
    local idx = tonumber(m)
    self.TowerGhostMaterial = (idx and self.TowerGhostMaterials[idx]) or tostring(m)
    for _, g in ipairs(self.GhostParts or {}) do
        if g.ent then pcall(function() g.ent:SetMaterial(self.TowerGhostMaterial) end) end
    end
    System.LogAlways("[Tower] ghost material = " .. self.TowerGhostMaterial)
end

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
            2, ent_terrain + ent_static, (player and player.id) or nil, nil, hits)
        if n and n > 0 and hits[1] and hits[1].pos then
            result = { x = hits[1].pos.x, y = hits[1].pos.y, z = hits[1].pos.z }
        end
    end)
    return result
end

-- ==== GENERIC PLACEMENT ENGINE ====
-- Driven by a `spec` (built per placeable - see TowerPlaceSpec, and CartPlaceSpec in
-- mercenaries_archer_cart.lua). Fields:
--   parts   : ghost geometry (list passed to GhostBuild)
--   sink    : z offset applied to ghost and to the real build
--   isValid : function(self, pos) -> bool  (drives the pink invalid recolour)
--   atMax   : function(self) -> bool
--   confirm : function(self, pos, angle)   (spawn the real thing; stays in mode)
--   info    : { placing, already, aim, blocked, limit, raised, cancelled } string keys
-- The mouse (LMB place / RMB cancel) reaches this through HandlePlacementAction.
mercenaries.ActivePlacement = nil
mercenaries.PlacePos = nil
mercenaries.PlaceAngle = 0.0
mercenaries.PlaceValid = true

function mercenaries.PlaceTick()
    local self = mercenaries
    local spec = self.ActivePlacement
    if not spec then return end
    pcall(function()
        local pos = self:TowerLookedAtPos()
        if pos then
            self.PlacePos = pos
            if player then
                local pp = player:GetWorldPos()
                -- face outward, away from where you stand
                self.PlaceAngle = math.atan2(pos.y - pp.y, pos.x - pp.x)
            end
            self:GhostMove(pos, self.PlaceAngle, spec.sink)
            self.PlaceValid = spec.isValid(self, pos)
            self:GhostSetValid(self.PlaceValid)
        end
    end)
    -- 100ms: the ghost is only moved, not respawned, so it tracks the crosshair smoothly.
    Script.SetTimerForFunction(100, "mercenaries.PlaceTick")
end

function mercenaries:StartPlacement(spec)
    if self.ActivePlacement then Game.SendInfoText(self.ActivePlacement.info.already, false, 0, 3); return end
    self.ActivePlacement = spec
    self.PlacePos = nil
    -- Mouse-driven (LMB place / RMB cancel) via the Player.OnAction hook - no key binds.
    self:TowerCacheCampBlockers()
    self._ghostValid = nil          -- force the first recolour
    self:GhostBuild(spec.parts, spec.validMaterial)
    Game.SendInfoText(spec.info.placing, false, 0, 5)
    Script.SetTimerForFunction(100, "mercenaries.PlaceTick")
end

function mercenaries:EndPlacement()
    self.ActivePlacement = nil
    self:GhostClear()
end

function mercenaries:ConfirmPlacement()
    local spec = self.ActivePlacement
    if not spec then return end
    if not self.PlacePos then Game.SendInfoText(spec.info.aim, false, 0, 3); return end
    if not self.PlaceValid then Game.SendInfoText(spec.info.blocked, false, 0, 3); return end
    if spec.atMax(self) then Game.SendInfoText(spec.info.limit, false, 0, 4); self:EndPlacement(); return end
    -- Stays in placement mode so more can be placed in one go; RMB ends it.
    spec.confirm(self, self.PlacePos, self.PlaceAngle)
    Game.SendInfoText(spec.info.raised, false, 0, 3)
end

-- onCancel (optional) lets a spec undo what it placed this session - the ambush
-- marker tools use it so right-click discards every marker. Specs without it
-- (tower, cart) just leave placement mode and keep what they built.
function mercenaries:CancelPlacement()
    local spec = self.ActivePlacement
    if not spec then return end
    if spec.onCancel then pcall(function() spec.onCancel(self) end) end
    -- keepOnCancel: right-click is an UNDO, not an exit. The bandit camp builder is a
    -- persistent editor - you place, take one back, place again - so leaving the mode on
    -- every right-click would make it unusable. Specs without the flag (tower, cart, ambush
    -- markers) behave exactly as before.
    if spec.keepOnCancel then return end
    self:EndPlacement()
    Game.SendInfoText(spec.info.cancelled, false, 0, 3)
end

-- ---- Tower placeable ----
function mercenaries:TowerPlaceSpec()
    local parts = {}
    for _, p in ipairs(self.TowerParts) do
        local rx, ry, rz = self:HouseQuatToEuler(p.qx or 0, p.qy or 0, p.qz or 0, p.qw or 1)
        table.insert(parts, { model = p.model, x = p.x, y = p.y, z = p.z, rx = rx, ry = ry, rz = rz })
    end
    for _, L in ipairs(self.TowerLadders) do
        local rx, ry, rz = self:HouseQuatToEuler(L.qx, L.qy, L.qz, L.qw)
        table.insert(parts, { model = L.model, x = L.x, y = L.y, z = L.z, rx = rx, ry = ry, rz = rz })
    end
    return {
        parts = parts,
        -- scaffolding pieces are single-material, so the white takes cleanly here
        validMaterial = self.TowerGhostMaterial,
        sink = self.TowerSink,
        isValid = function(s, pos) return s:TowerSpotIsValid(pos) end,
        atMax   = function(s) return #s.TowerStations >= s.TowerMaxCount end,
        confirm = function(s, pos, angle) s:SpawnTowerStation(pos, angle) end,
        info = { placing = 'merc_info_tower_placing', already = 'merc_info_tower_already',
                 aim = 'merc_info_tower_aim', blocked = 'merc_info_tower_blocked',
                 limit = 'merc_info_tower_limit', raised = 'merc_info_tower_raised',
                 cancelled = 'merc_info_tower_cancelled' },
    }
end

function mercenaries:StartTowerPlacement() self:StartPlacement(self:TowerPlaceSpec()) end

-- ==== MOUSE INPUT: Player.OnAction hook ====
-- Animation polling was a dead end - Actor.GetCurrentAnimationState() only ever
-- reports locomotion (MotionIdle/Movement/Jump/Land), never an attack or block, and
-- Entity.GetCurAnimation() is always nil. The real input path is the player's
-- OnAction callback, which receives the ACTION NAME directly (the pattern is lifted
-- from references/CompanionMerchant, which hooks it the same way).
--
-- Action names come from references/Libs/Config/keybindSuperactions.xml:
--   mouse1 -> superaction "attack_primary" -> action "attack_primary_mouse" (combat_base)
--   mouse2 -> superaction "block"          -> action "block"                (combat_base)
-- Both live in the combat_base map, so they may only fire with a weapon drawn -
-- merc_action_log 1 shows exactly what arrives, whatever the state.
mercenaries.ActionLog = false   -- merc_action_log 1 to watch input names again
mercenaries._onActionHooked = false

-- Confirmed live: LMB = attack_primary_mouse press/release. RMB = attack_abort AND
-- block together (attack_abort arrives FIRST), then block hold... then both release.
mercenaries.TowerPlaceActions  = { attack_primary_mouse = true }
mercenaries.TowerCancelActions = { block = true }
-- Everything a mouse button emits while placing, acted on or not. All of it is
-- swallowed so Henry never swings or raises his guard while choosing a spot - and
-- because attack_abort precedes block on RMB, it must be eaten too or the cancel
-- would fire on block while attack_abort had already leaked through to the game.
mercenaries.TowerSwallowActions = { attack_primary_mouse = true, block = true, attack_abort = true }

-- After a cancel, placement is already off but the trailing block/hold, block/release
-- and attack_abort/release are still coming; this brief window keeps eating them.
mercenaries._swallowInput = false
function mercenaries.TowerClearInputSwallow() mercenaries._swallowInput = false end

-- Returns true if the action was consumed by a placement or wall-build mode.
function mercenaries:HandlePlacementAction(action, activation)
    if not self.TowerSwallowActions[action] then return false end
    local wall = self.WallBuildActive
    if not (self.ActivePlacement or wall or self._swallowInput) then return false end

    if activation == "press" then
        if self.ActivePlacement then
            if self.TowerPlaceActions[action] then
                self:ConfirmPlacement()           -- stays in placement mode for the next one
            elseif self.TowerCancelActions[action] then
                self:CancelPlacement()
                self._swallowInput = true
                Script.SetTimerForFunction(400, "mercenaries.TowerClearInputSwallow")
            end
        elseif wall then
            if self.TowerPlaceActions[action] then
                self:WallMark()                   -- drop a corner, keep building
            elseif self.TowerCancelActions[action] then
                self:EndWallBuild()
                self._swallowInput = true
                Script.SetTimerForFunction(400, "mercenaries.TowerClearInputSwallow")
            end
        end
    end
    return true
end

-- Chain onto Player.OnAction. Registered once, re-applied a moment after gameplay
-- start so a mod that overwrote the callback without chaining cannot lock us out.
function mercenaries.UpdateOnAction()
    local self = mercenaries
    if not Player then return end
    if not self._onActionHooked then
        self._originalOnAction = Player.OnAction
        self._onActionHooked = true
    end
    Player.OnAction = function(p, action, activation, value)
        local consumed = false
        pcall(function() consumed = self:HandlePlacementAction(action, activation) end)
        if self.ActionLog then
            System.LogAlways(string.format("[Action] %s / %s / %s%s",
                tostring(action), tostring(activation), tostring(value), consumed and "  <- CONSUMED" or ""))
        end
        -- Pass through to whatever was there before, unless placement took it.
        if not consumed and self._originalOnAction then
            self._originalOnAction(p, action, activation, value)
        end
    end
end

-- Only "0" turns it off; a bare `merc_action_log` (empty arg) turns it ON, which is
-- what the old tostring(v)=="1" test got wrong.
function mercenaries:SetActionLog(v)
    self.ActionLog = (tonumber(v) ~= 0)
    self:UpdateOnAction()   -- make sure the hook is live even if called early
    System.LogAlways("[Action] logging " .. (self.ActionLog and "ON - press LMB/RMB and read the names" or "off"))
end

System.AddCCommand("merc_action_log", "mercenaries:SetActionLog('%1')", "Log every player input action: merc_action_log 1 (0 to stop)")

-- ==== INPUT PROBE (legacy): what is the player playing when he clicks? ====
-- There is no mouse-button hook in KCD's Lua, so left/right click have to be
-- inferred from what Henry is DOING - a swing for LMB, a block/guard for RMB. This
-- logs his current animation so those two can be identified by name and then matched
-- in the placement handler. Which getter actually exists in this build is unknown,
-- so every one we know of is tried and whichever return something are reported.
--   merc_anim_poll 1          start (500ms, as asked)
--   merc_anim_poll 1 100      start with a tighter interval - a swing is quick and
--                             500ms will very likely step straight over it
--   merc_anim_poll 0          stop
mercenaries.AnimPollActive = false
mercenaries.AnimPollInterval = 500
mercenaries.AnimPollLast = ""

-- All verified against references/script_bind_2025_01_14 (the Warhorse scriptbind
-- docs) rather than guessed:
--   Entity.GetCurAnimation()                    - no args
--   Entity.IsAnimationRunning(charSlot, layer)  - two ints
--   Entity.GetAnimationTime(charSlot, layer)    - two ints
--   Actor.GetCurrentAnimationState()            - "state for the current animation"
--   Human.IsWeaponDrawn()                       - any weapon active
mercenaries.AnimProbes = {
    { n = "GetCurAnimation()",        f = function(p) return p:GetCurAnimation() end },
    { n = "actor:GetCurAnimState()",  f = function(p) return p.actor:GetCurrentAnimationState() end },
    { n = "human:IsWeaponDrawn()",    f = function(p) return p.human:IsWeaponDrawn() end },
    { n = "IsAnimRunning(0,0)",       f = function(p) return p:IsAnimationRunning(0, 0) end },
    { n = "IsAnimRunning(0,1)",       f = function(p) return p:IsAnimationRunning(0, 1) end },
    { n = "IsAnimRunning(0,2)",       f = function(p) return p:IsAnimationRunning(0, 2) end },
    { n = "IsAnimRunning(0,3)",       f = function(p) return p:IsAnimationRunning(0, 3) end },
    { n = "GetAnimationTime(0,0)",    f = function(p) return p:GetAnimationTime(0, 0) end },
}

-- Add a probe at runtime once merc_player_dump has shown a promising method:
--   merc_anim_add human GetCombatState      -> calls player.human:GetCombatState()
--   merc_anim_add . GetCurAnimation 0       -> calls player:GetCurAnimation(0)
function mercenaries:AnimProbeAdd(sub, method, arg)
    if not method or method == "" then System.LogAlways("[AnimPoll] usage: merc_anim_add <sub|.> <method> [arg]"); return end
    local a = (arg ~= nil and arg ~= "") and (tonumber(arg) or tostring(arg)) or nil
    local label = ((sub and sub ~= "" and sub ~= ".") and (sub .. ":") or "") .. method .. "(" .. tostring(a or "") .. ")"
    table.insert(self.AnimProbes, { n = label, f = function(p)
        local obj = (sub and sub ~= "" and sub ~= ".") and p[sub] or p
        if a ~= nil then return obj[method](obj, a) end
        return obj[method](obj)
    end })
    System.LogAlways("[AnimPoll] added probe " .. label)
end

-- A returned nil and a missing method are NOT the same thing - conflating them is
-- what made every probe read "<unavailable>" last time. Errors report <err>, a live
-- call that simply has nothing to say reports nil.
local function animProbeValue(pr)
    local v
    local ok = pcall(function() v = pr.f(player) end)
    if not ok then return "<err>" end
    if v == nil then return "nil" end
    return tostring(v)
end

-- One-shot: which of the getters exist at all.
function mercenaries:AnimProbeOnce()
    if not player then System.LogAlways("[AnimPoll] no player"); return end
    System.LogAlways("[AnimPoll] --- probing every known animation getter ---")
    for _, pr in ipairs(self.AnimProbes) do
        local v = animProbeValue(pr)
        System.LogAlways(string.format("[AnimPoll] %-26s = %s", pr.n, v or "<unavailable>"))
    end
end

function mercenaries.AnimPollTick()
    local self = mercenaries
    if not self.AnimPollActive then return end
    if player then
        local parts = {}
        for _, pr in ipairs(self.AnimProbes) do
            local v = animProbeValue(pr)
            -- dead probes are constant, so keep them out of the running log
            if v ~= "<err>" then table.insert(parts, pr.n .. "=" .. v) end
        end
        local line = table.concat(parts, "  |  ")
        -- only on change, so the swing/block stand out instead of drowning in idle
        if line ~= "" and line ~= self.AnimPollLast then
            self.AnimPollLast = line
            System.LogAlways("[AnimPoll] " .. line)
        end
    end
    Script.SetTimerForFunction(self.AnimPollInterval, "mercenaries.AnimPollTick")
end

function mercenaries:AnimPoll(on, ms)
    local want = (tonumber(on) ~= 0)
    if ms and ms ~= "" and tonumber(ms) then self.AnimPollInterval = tonumber(ms) end
    if want and not self.AnimPollActive then
        self.AnimPollActive = true
        self.AnimPollLast = ""
        self:AnimProbeOnce()
        System.LogAlways("[AnimPoll] polling every " .. self.AnimPollInterval ..
            "ms - draw a weapon, swing (LMB) and block (RMB), and watch which names appear. merc_anim_poll 0 to stop")
        Script.SetTimerForFunction(self.AnimPollInterval, "mercenaries.AnimPollTick")
    elseif not want then
        self.AnimPollActive = false
        System.LogAlways("[AnimPoll] stopped")
    end
end

-- ==== REFLECTION: what does `player` actually expose? ====
-- Enumerates the player entity and its sub-objects (and what sits behind their
-- metatable __index, which is where C++-bound methods live) so the real animation /
-- combat getters can be read off instead of guessed at.
--   merc_player_dump            player + every known sub-object
--   merc_player_dump human      just player.human
function mercenaries:PlayerApiDump(which)
    if not player then System.LogAlways("[PlayerAPI] no player"); return end

    local seen = {}
    local function dump(name, tbl, depth)
        if tbl == nil then System.LogAlways("[PlayerAPI] " .. name .. " = nil"); return end
        local t = type(tbl)
        if t ~= "table" and t ~= "userdata" then
            System.LogAlways(string.format("[PlayerAPI] %s = %s (%s)", name, tostring(tbl), t))
            return
        end
        if seen[tbl] or depth > 2 then return end
        seen[tbl] = true

        local keys = {}
        local ok = pcall(function()
            for k, v in pairs(tbl) do table.insert(keys, tostring(k) .. ":" .. type(v)) end
        end)
        if not ok or #keys == 0 then
            System.LogAlways(string.format("[PlayerAPI] ===== %s (%s) - not enumerable directly =====", name, t))
        else
            table.sort(keys)
            System.LogAlways(string.format("[PlayerAPI] ===== %s (%s, %d keys) =====", name, t, #keys))
            local line = ""
            for _, k in ipairs(keys) do
                if #line + #k + 2 > 170 then System.LogAlways("[PlayerAPI]   " .. line); line = "" end
                line = (line == "") and k or (line .. ", " .. k)
            end
            if line ~= "" then System.LogAlways("[PlayerAPI]   " .. line) end
        end

        -- C++ bindings usually hide behind the metatable rather than being direct keys
        local mt = nil
        pcall(function() mt = getmetatable(tbl) end)
        if mt and type(mt) == "table" and type(mt.__index) == "table" then
            dump(name .. ".__index", mt.__index, depth + 1)
        end
    end

    which = (which and which ~= "" and which ~= "%1") and tostring(which) or nil
    if which then
        dump("player." .. which, player[which], 0)
    else
        dump("player", player, 0)
        for _, sub in ipairs({ "actor", "human", "soul", "player", "inventory", "Properties" }) do
            local v = nil
            pcall(function() v = player[sub] end)
            if v ~= nil then dump("player." .. sub, v, 0) end
        end
    end
    System.LogAlways("[PlayerAPI] done - look for anything animation/combat/attack/stance related")
end

-- Quoted args so a missing one is an empty string rather than "Not enough arguments".
System.AddCCommand("merc_anim_poll",   "mercenaries:AnimPoll('%1', '%2')",              "Log the player's probed state on change: merc_anim_poll 1 [intervalMs] (0 to stop)")
System.AddCCommand("merc_anim_add",    "mercenaries:AnimProbeAdd('%1', '%2', '%3')",    "Add a probe: merc_anim_add <sub|.> <method> [arg]")
System.AddCCommand("merc_player_dump", "mercenaries:PlayerApiDump('%1')",               "List what the player entity actually exposes: merc_player_dump [sub]")

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

-- How deep the whole tower sits in the ground (negative = sunk). Rebuilds the
-- current tower in place to preview it.
function mercenaries:TowerSetSink(v)
    self.TowerSink = tonumber(v) or self.TowerSink
    System.LogAlways("[Tower] sink = " .. tostring(self.TowerSink))
    self:RebuildCurrentTower()
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
    st.archer = self:SpawnStaticArcher(ap, self.TowerArcherMode, st.yaw, nil, true)
    if st.archer then
        table.insert(self.TowerArcherAttachQueue, st)
        Script.SetTimerForFunction(2500, "mercenaries.TowerAttachArcherDelayed")
    end
    System.LogAlways(string.format("[Tower] archer z = %.2f, dropped from %.2f above", a.z, self.StaticArcherDropHeight))
end

System.AddCCommand("merc_tower_spawn",     "mercenaries:SpawnTowerAhead()",               "Spawn the scaffolding tower fresh ahead of you (parts, climbable ladder, deck collider)")
System.AddCCommand("merc_tower_clear",     "mercenaries:TowerStationClearAll()",          "Remove all towers")
System.AddCCommand("merc_tower_build",        "mercenaries:StartTowerPlacement()",   "Enter tower placement mode: look at a spot, left-click to place, right-click to finish")
System.AddCCommand("merc_tower_place",        "mercenaries:ConfirmPlacement()",      "Place at the ghost marker (normally left-click)")
System.AddCCommand("merc_tower_place_cancel", "mercenaries:CancelPlacement()",       "Leave placement mode (normally right-click)")
System.AddCCommand("merc_tower_ghost_mtl",    "mercenaries:SetTowerGhostMaterial('%1')", "Set the placement ghost's material (blank = show current)")
System.AddCCommand("merc_tower_clearance",    "mercenaries:SetTowerClearance('%1', '%2')", "How much room a tower needs: merc_tower_clearance <fromCampProps> <fromTowers>")
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
