-- Food cart upgrade dressing: a supply wagon loaded with sacks, standing in camp
-- while the Food Cart upgrade has days left (LogiState().foodCartDays > 0).
-- Placed like the other stations - flattest ring spot near camp, clear of them.
--
-- Models follow the vanilla wagon_with_flour prefab (references/Prefabs/
-- exteriorDecoration): wagon_b.cgf is the WHOLE wagon in one mesh (the
-- wagon_b_body/_wheel_/_axel pieces are for assembling it by hand), and its bed
-- sits at z ~0.95, which is where that prefab stacks its flour sacks.

mercenaries.CampFoodCart = nil
mercenaries.CampCartModel = "objects/manmade/vehicles/wagons/wagon_b.cgf"

-- Station frame: fwd = outward from camp (so -fwd is the side you approach from),
-- lat = +left, up = height, rz = yaw in degrees. Sacks are the same ones the camp
-- and hunting station already use.
mercenaries.CampFoodCartLayout = {
    { n = "cart",      m = mercenaries.CampCartModel,                                 fwd =  0.0, lat =  0.0, up = 0.00, rz = 0 },

    -- Load on the wagon bed.
    { n = "bed_sack_a",m = "objects/manmade/common_furniture/sacks/sack_a.cgf",       fwd =  0.30, lat =  0.20, up = 0.95, rz =  20 },
    { n = "bed_sack_b",m = "objects/manmade/common_furniture/sacks/sack_b.cgf",       fwd = -0.25, lat = -0.25, up = 0.95, rz = -35 },
    { n = "bed_sack_c",m = "objects/manmade/common_furniture/sacks/sack_items/sack_items.cgf", fwd = 0.65, lat = -0.15, up = 0.95, rz = 60 },

    -- Unloaded sacks on the ground, on the camp side (what you see walking up).
    { n = "gnd_sack_a",m = "objects/manmade/common_furniture/sacks/sack_a.cgf",       fwd = -1.75, lat =  0.45, up = 0.00, rz =  15 },
    { n = "gnd_sack_b",m = "objects/manmade/common_furniture/sacks/sack_b.cgf",       fwd = -2.00, lat = -0.30, up = 0.00, rz = -50 },
    { n = "gnd_sack_c",m = "objects/manmade/common_furniture/sacks/sack_items/sack_items.cgf", fwd = -2.15, lat = 0.20, up = 0.00, rz = 100 },
}

function mercenaries:SpawnCampFoodCart(center)
    if self.CampFoodCart then return true end
    center = center or self.CampCenter
    if not center then return false end

    -- The camp reserves a grid tile per upgrade (see CampStationTiles); only fall
    -- back to a flat-patch scan clear of the other stations if there wasn't one.
    local spot, ang = self:CampStationSpot("cart")
    if not spot then
        local avoid = {}
        if self.CampForge and self.CampForge.anvilPos then table.insert(avoid, self.CampForge.anvilPos) end
        if self.CampAlchemy and self.CampAlchemy.spot then table.insert(avoid, self.CampAlchemy.spot) end
        if self.CampHunt and self.CampHunt.origin then table.insert(avoid, self.CampHunt.origin) end
        if self.CampInn and self.CampInn.origin then table.insert(avoid, self.CampInn.origin) end
        if self.CampPracticeYard and self.CampPracticeYard.trainCenter then table.insert(avoid, self.CampPracticeYard.trainCenter) end
        if #avoid == 0 then avoid = nil end
        spot, ang = self:ForgeFindFlattest(center, avoid)
    end
    if not spot then
        ang = math.pi / 2
        spot = self:CampSnapToGround({ x = center.x + math.cos(ang) * 8, y = center.y + math.sin(ang) * 8, z = center.z })
    end
    local F = { x = math.cos(ang), y = math.sin(ang) }
    local Lft = { x = -F.y, y = F.x }

    local st = { origin = spot, ang = ang, ids = {} }
    self.CampFoodCart = st
    for _, L in ipairs(self.CampFoodCartLayout) do
        local w = { x = spot.x + F.x * L.fwd + Lft.x * L.lat,
                    y = spot.y + F.y * L.fwd + Lft.y * L.lat,
                    z = spot.z + (L.up or 0) }
        -- Spawned directly rather than via SpawnCampPropModel: that snaps to the
        -- ground, which would drop the bed sacks off the wagon. `spot` is already
        -- ground-snapped, so `up` is a height above it (as in the other stations).
        local yaw = ang + math.rad(L.rz or 0)
        local e
        pcall(function()
            e = System.SpawnEntity({ class = "BasicEntity",
                name = "MercCampCart_" .. tostring(math.random(100000, 999999)),
                position = w, orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
                properties = { object_Model = L.m, bMissionCritical = false, bSaved_by_game = false, bSerialize = false } })
        end)
        if e then
            pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw }) end)
            table.insert(st.ids, e.id)
        end
    end
    System.LogAlways("[CampCart] food cart parked (" .. #st.ids .. " props)")
    return true
end

function mercenaries:DespawnCampFoodCart()
    local st = self.CampFoodCart
    if not st then return end
    for _, id in ipairs(st.ids or {}) do pcall(function() System.RemoveEntity(id) end) end
    self.CampFoodCart = nil
    System.LogAlways("[CampCart] food cart removed")
end
