-- Player house upgrade: with it bought, the player's round tent is replaced by a
-- real hut with a sleepable bed. Everything here is a straight port of the
-- spawn-house mod (references/spawn house, villagebuilding_building.lua) - same
-- models, same local offsets, same collider walls, same bed - so it behaves
-- exactly as it does there. Gated on LogiState().hasHouse; see SpawnPlayerCampTent.
--
-- How a house is put together (all of this is load-bearing):
--  * The hut's render mesh has NO player collision, so the visible shell is
--    spawned for looks and the walls are a ring of INVISIBLE crate colliders
--    (CampHouseWalls) tiled along hand-mapped segments, with a gap for the door.
--  * Colliders only work spawned as PE_STATIC, which a plain BasicEntity can't
--    do - hence the mercenaries_Prop entity class (BasicEntity + bRigidBody =
--    false). Falls back to a physicalised BasicEntity if that class is missing.
--  * The hut sits on a bridge-deck foundation (its own collision = a walkable
--    floor) raised by CampHouseZ.

local HOUSE_SHELL  = "objects/manmade/structures/living/houses/wooden/small_roof_to_ground_house_a.cgf"
local HOUSE_WINDOW = "objects/intermediates/elements/window_timber_f_small.cgf"

-- Visual parts, local to the house origin. Quaternions are the prefab's
-- Rotate="a,b,c,d" read as (w,x,y,z), from small_roof_to_ground_house_a.xml.
mercenaries.CampHouseParts = {
    { model = HOUSE_SHELL,  x = 0,        y = 0,        z = 0,        qw = 1,         qx = 0,         qy = 0,         qz = 0 },
    { model = HOUSE_WINDOW, x = 4.570302, y = 1.120802, z = 2.101488, qw = 0.4999726, qx = 0.5000274, qy = 0.4999726, qz = 0.5000274 },
    { model = HOUSE_WINDOW, x = 4.570302, y = 0.114213, z = 2.101488, qw = 0.4999726, qx = 0.5000274, qy = 0.4999726, qz = 0.5000274 },
}

-- Foundation the hut sits on: a solid bridge-deck (walkable floor).
mercenaries.CampHouseFoundationModel  = "objects/manmade/structures/logistical/bridges/common_bridge_deck_half.cgf"
mercenaries.CampHouseFoundationZ      = 0.40
mercenaries.CampHouseZ                = 0.10
mercenaries.CampHouseFoundationScale  = { x = 1.15, y = 1.0, z = 1.0 }
mercenaries.CampHouseFoundationOffset = { x = 0.1, y = -2.5, yaw = 0.0 }
mercenaries.CampHouseHeightScale      = 1.0

-- Sleepable bed inside the hut (local offset; yaw in radians).
mercenaries.CampHouseBedModel  = "objects/manmade/common_furniture/beds/low/bed_shabby_a.cgf"
mercenaries.CampHouseBedOffset = { x = 3.0, y = 1.6, z = 0.3, yaw = 1.5708 }

-- Invisible collision walls: hand-mapped segments (two local endpoints + per-axis
-- crate scale), tiled with crates at each layer height so the player can't walk
-- through or vault over. The gap between segments is the doorway.
mercenaries.CampHouseWallCollider = "objects/manmade/common_furniture/crates/crate_low_a.cgf"
mercenaries.CampHouseWallStep     = 0.4
mercenaries.CampHouseWallLayerZ   = { 0.5, 1.5, 2.5 }
mercenaries.CampHouseWalls = {
    { ax = -0.060, ay =  3.093, bx =  4.611, by =  3.071, sx = 1.000, sy = 2.000, sz = 1.000 },
    { ax =  4.425, ay =  1.651, bx =  4.397, by = -0.903, sx = 1.000, sy = 0.750, sz = 1.000 },
    { ax =  4.708, ay = -1.718, bx = -0.054, by = -1.708, sx = 1.000, sy = 1.600, sz = 1.000 },
    { ax =  0.186, ay = -0.177, bx =  0.159, by = -1.028, sx = 1.000, sy = 0.750, sz = 1.000 },
    { ax =  0.213, ay =  1.362, bx =  0.204, by =  2.151, sx = 1.000, sy = 0.750, sz = 1.000 },
}

-- The hut's door is its local -X gable, so a half-turn points it at the player.
mercenaries.CampHouseFacingFix = math.pi

mercenaries.CampHouseCenter = nil   -- {x,y} while a house stands

-- Quaternion (x,y,z,w) -> Euler radians in the Z*Y*X order SetAngles uses.
function mercenaries:HouseQuatToEuler(qx, qy, qz, qw)
    local sinr = 2 * (qw * qx + qy * qz)
    local cosr = 1 - 2 * (qx * qx + qy * qy)
    local roll = math.atan2(sinr, cosr)
    local sinp = 2 * (qw * qy - qz * qx)
    if sinp > 1 then sinp = 1 elseif sinp < -1 then sinp = -1 end
    local pitch = math.asin(sinp)
    local siny = 2 * (qw * qz + qx * qy)
    local cosy = 1 - 2 * (qy * qy + qz * qz)
    local yaw = math.atan2(siny, cosy)
    return roll, pitch, yaw
end

-- House-local (lx,ly,lz) -> world at (origin, angle).
function mercenaries:HouseLocalToWorld(origin, angle, lx, ly, lz)
    local c, s = math.cos(angle), math.sin(angle)
    return {
        x = origin.x + lx * c - ly * s,
        y = origin.y + lx * s + ly * c,
        z = origin.z + (lz or 0),
    }
end

-- One STATIC house part. mercenaries_Prop physicalises PE_STATIC; a plain
-- BasicEntity would be a pushable rigid body, so it's only the fallback.
function mercenaries:SpawnHousePart(model, pos, rx, ry, rz, scale)
    local params = {
        name = "MercCampHouse_" .. tostring(math.random(100000, 999999)),
        position = pos,
        orientation = { x = rx, y = ry, z = rz },
        -- Never serialised: the camp is rebuilt from scratch on load, and saved
        -- house parts came back as broken white placeholders (see docs/camp.md).
        properties = { object_Model = model, bMissionCritical = false,
                       bSaved_by_game = false, bSerialize = false },
    }
    if scale then params.scale = scale end
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
        table.insert(self.CampEntities, ent.id)
    end
    return ent
end

-- One wall crate; invisible unless `visible` (DrawSlot 0,0 keeps physics).
function mercenaries:SpawnHouseWallCrate(wp, yaw, sx, sy, sz, visible)
    local ent = self:SpawnHousePart(self.CampHouseWallCollider, wp, 0, 0, yaw, { x = sx, y = sy, z = sz })
    if ent and not visible then pcall(function() ent:DrawSlot(0, 0) end) end
    return ent
end

-- Tile crates along one wall segment.
function mercenaries:TileHouseWall(origin, angle, w, visible)
    local ex, ey = w.bx - w.ax, w.by - w.ay
    local len = math.sqrt(ex * ex + ey * ey)
    local sx, sy, sz = w.sx or 1, w.sy or 1, w.sz or 1
    local segYaw = (len > 0.001) and math.atan2(ey, ex) or 0
    local step = math.max(0.3, self.CampHouseWallStep * sx)
    local n = math.max(1, math.floor(len / step + 0.5))
    for i = 0, n do
        local t = (n > 0) and (i / n) or 0
        for _, lz in ipairs(self.CampHouseWallLayerZ) do
            local wp = self:HouseLocalToWorld(origin, angle, w.ax + ex * t, w.ay + ey * t, lz)
            self:SpawnHouseWallCrate(wp, angle + segYaw, sx, sy, sz, visible)
        end
    end
end

-- The player's bed inside the hut. Spawns the vanilla "Bed" entity class - only
-- that class carries the sleep interaction (its GetActions / OnUsed); a
-- BasicEntity is the fallback.
function mercenaries:SpawnCampHouseBed(origin, angle)
    if not self.CampHouseBedModel or self.CampHouseBedModel == "" then return end
    local ok, err = pcall(function()
        local b = self.CampHouseBedOffset
        local wp = self:HouseLocalToWorld(origin, angle, b.x, b.y, (b.z or 0) + self.CampHouseZ)
        local bedAngle = angle + (b.yaw or 0)

        -- Exactly the player TENT's bed recipe (SpawnPlayerCampTent): a plain
        -- BasicEntity carrying the vanilla bed smart-object properties, plus a
        -- linked BedTrigger. The trigger is what drives the "E - Sleep" prompt and
        -- the lying stance - the spawn-house mod's `Bed`-class bed has no trigger,
        -- so it looked right but couldn't be slept in.
        local bedEnt = System.SpawnEntity({
            class = "BasicEntity",
            name = "MercCampHouseBed_" .. tostring(math.random(100000, 999999)),
            position = wp,
            properties = {
                object_Model = self.CampHouseBedModel,
                bMissionCritical = false,
                bSaved_by_game = false,
                bSerialize = false,
                guidSmartObjectType = "425d4fdf-8dcd-4a2b-fdc5-cbb1b5d25b89",
                soclass_SmartObjectHelpers = "Bed_1Place_Low",
                sWH_AI_EntityCategory = "Bed",
                sSittingTagGlobal = "sittingNoTable",
                fUsabilityDistance = 1.25,
                bInteractiveCollisionClass = true,
                Script = { esBedTypes = "GroundBed" },
                Bed = { esSleepQuality = "low", esReadingQuality = "bed_ground" },
            }
        })

        if bedEnt then
            pcall(function() bedEnt:SetAngles({ x = 0, y = 0, z = bedAngle }) end)
            pcall(function() bedEnt:SetViewDistUnlimited() end)
            pcall(function() bedEnt:RenderShadow(true) end)
            table.insert(self.CampEntities, bedEnt.id)
            -- No ground-snap: the bed sits on the hut's raised deck, not the terrain.
            self:SpawnCampBedTrigger(bedEnt, wp, bedAngle)
        end
    end)
    if not ok then System.LogAlways("[CampHouse] SpawnCampHouseBed error: " .. tostring(err)) end
end

-- Build the hut at (origin, angle): foundation, bed, shell + windows, colliders.
-- Every piece tracks in CampEntities, so break-camp tears it down with the rest.
function mercenaries:SpawnCampHouse(centerPos, facingAngle)
    local ok, err = pcall(function()
        local origin = self:CampSnapToGround(centerPos)
        local angle = (facingAngle or 0) + self.CampHouseFacingFix

        -- Centroid of the wall endpoints - centres the foundation under the hut.
        local cx, cy, cn = 0, 0, 0
        for _, w in ipairs(self.CampHouseWalls) do
            cx = cx + w.ax + w.bx; cy = cy + w.ay + w.by; cn = cn + 2
        end
        local insLx, insLy = 0, 0
        if cn > 0 then insLx, insLy = cx / cn, cy / cn end

        if self.CampHouseFoundationModel and self.CampHouseFoundationModel ~= "" then
            local fo = self.CampHouseFoundationOffset
            local fp = self:HouseLocalToWorld(origin, angle, insLx + fo.x, insLy + fo.y, self.CampHouseFoundationZ)
            local fs = self.CampHouseFoundationScale
            local scale = (fs and (fs.x ~= 1 or fs.y ~= 1 or fs.z ~= 1)) and { x = fs.x, y = fs.y, z = fs.z } or nil
            self:SpawnHousePart(self.CampHouseFoundationModel, fp, 0, 0, angle + (fo.yaw or 0), scale)
        end

        self:SpawnCampHouseBed(origin, angle)

        local h = self.CampHouseHeightScale or 1.0
        for _, part in ipairs(self.CampHouseParts) do
            local wp = self:HouseLocalToWorld(origin, angle, part.x, part.y, (part.z or 0) * h + self.CampHouseZ)
            local rx, ry, rz = self:HouseQuatToEuler(part.qx or 0, part.qy or 0, part.qz or 0, part.qw or 1)
            local scale = (h ~= 1.0) and { x = 1, y = 1, z = h } or nil
            self:SpawnHousePart(part.model, wp, rx, ry, rz + angle, scale)
        end

        for _, w in ipairs(self.CampHouseWalls) do
            self:TileHouseWall(origin, angle, w, false)
        end

        local inside = self:HouseLocalToWorld(origin, angle, insLx, insLy, 0)
        self.CampHouseCenter = { x = inside.x, y = inside.y }
        System.LogAlways("[CampHouse] player house raised")
    end)
    if not ok then System.LogAlways("[CampHouse] SpawnCampHouse error: " .. tostring(err)) end
end

-- On break-camp: the props go with CampEntities; the centre is ours to reset.
function mercenaries:ClearCampHouse()
    self.CampHouseCenter = nil
end
