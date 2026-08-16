-- Archer cart: a supply wagon manned by three static archers standing on the bed.
-- It reuses every proven piece rather than inventing anything:
--   * the wagon mesh + a bed collider are spawned STATIC (mercenaries_Prop), the
--     same way the tower's parts are;
--   * the three archers are ordinary static archers (mercenaries_static_archer.lua)
--     - out of the squad, own targeting modes, marksman buff - held on the bed by
--     the attach-to-unscaled-anchor method (the winning merc_tower_hold #6);
--   * spawn is two-stage and FIFO-queued exactly like the tower: collider first,
--     archers once it is physicalised, attach once they have settled. Placing a
--     second cart before the first's timers fire cannot cross the wires.
-- See [[reference_elevated_npc_attach_hold]] and mercenaries_tower.lua.

mercenaries.ArcherCarts = {}          -- list of live carts { ids =, archers =, origin =, yaw =, dead = }
mercenaries.ArcherCartModel = "objects/manmade/vehicles/wagons/wagon_b.cgf"
mercenaries.ArcherCartColliderModel = "objects/manmade/common_furniture/crates/crate_low_a.cgf"
mercenaries.ArcherCartMode = "defend"
mercenaries.ArcherCartDelay = 2000    -- wagon/collider -> archers (let the collider physicalise)
mercenaries.ArcherCartAttachDelay = 2500  -- archers -> attach (let them settle onto the bed)
mercenaries.ArcherCartMax = 5

-- Invisible collider covering the wagon bed, so the dropped archers land instead of
-- tunnelling through the render-only wagon mesh. Local to the cart (fwd = along the
-- wagon outward, lat = +left, up = height above ground). wagon_b's bed sits ~0.95.
mercenaries.ArcherCartBedCollider = { up = 0.90, sx = 1.30, sy = 3.00, sz = 0.20 }

-- The three archers on the bed: fwd spaces them along its length, they stand at
-- `up`, and face `face` degrees off the cart's yaw (0 = outward, away from where it
-- was placed). Spread so they cover front, a flank and the rear.
mercenaries.ArcherCartArcherLayout = {
    { fwd = 0.0, lat =  0.60, up = 1.00, face =   0 },
    { fwd = 0.0, lat = -0.15, up = 1.00, face =  90 },
    { fwd = 0.0, lat = -0.90, up = 1.00, face = 180 },
}

mercenaries.ArcherCartSpawnQueue = {}
mercenaries.ArcherCartAttachQueue = {}

-- One static part (wagon or collider), spawned STATIC so it collides.
function mercenaries:ArcherCartSpawnPart(model, wp, yaw, scale, invisible, track)
    local params = {
        class = "mercenaries_Prop",
        name = "MercArcherCart_" .. tostring(math.random(100000, 999999)),
        position = wp,
        orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
        properties = { object_Model = model, bMissionCritical = false,
                       bSaved_by_game = false, bSerialize = false },
    }
    if scale then params.scale = scale end
    local ent = System.SpawnEntity(params)
    if not ent then
        params.class = "BasicEntity"
        params.properties.Physics = { bPhysicalize = true, bRigidBody = false, Mass = 0, Density = 0, bPushableByPlayers = false }
        ent = System.SpawnEntity(params)
    end
    if ent then
        pcall(function() ent:SetAngles({ x = 0, y = 0, z = yaw }) end)
        pcall(function() ent:SetViewDistUnlimited() end)
        if invisible then pcall(function() ent:DrawSlot(0, 0) end) end
        table.insert(track, ent.id)
    end
    return ent
end

-- Build one cart. `atPos`/`atYaw` place it; with no args it goes ahead of the player.
-- `opts` = { mode =, group = } makes it somebody else's - a bandit camp's cart, whose archers
-- run in "hostile" mode on enemy souls. Omitted, it is the player's own exactly as before.
function mercenaries:SpawnArcherCart(atPos, atYaw, opts)
    if not player then return end
    -- Player budget only; foreign carts are layout-authored (see the tower cap note).
    if not (opts and opts.group) then
        local own = 0
        for _, st in ipairs(self.ArcherCarts) do
            if not st.group then own = own + 1 end
        end
        if own >= self.ArcherCartMax then
            System.LogAlways("[ArcherCart] limit reached (" .. self.ArcherCartMax .. ") - merc_archer_cart_clear first")
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
        ground = { x = o.x + math.cos(yaw) * (self.TowerStationDist or 10.0),
                   y = o.y + math.sin(yaw) * (self.TowerStationDist or 10.0), z = o.z }
    end
    if self.CampSnapToGround then ground = self:CampSnapToGround(ground) end

    local st = { origin = ground, yaw = yaw, ids = {}, archers = {},
                 mode = opts and opts.mode, group = opts and opts.group }
    table.insert(self.ArcherCarts, st)

    -- wagon (visible) + bed collider (invisible)
    self:ArcherCartSpawnPart(self.ArcherCartModel, ground, yaw, nil, false, st.ids)
    local bc = self.ArcherCartBedCollider
    local bedWp = self:HouseLocalToWorld(ground, yaw, 0, 0, bc.up)
    self:ArcherCartSpawnPart(self.ArcherCartColliderModel, bedWp, yaw,
        { x = bc.sx, y = bc.sy, z = bc.sz }, true, st.ids)

    -- remember where each archer belongs; they follow once the collider exists
    st.archerSpecs = {}
    for _, a in ipairs(self.ArcherCartArcherLayout) do
        table.insert(st.archerSpecs, {
            pos  = self:HouseLocalToWorld(ground, yaw, a.fwd, a.lat, a.up),
            face = yaw + math.rad(a.face or 0),
        })
    end
    table.insert(self.ArcherCartSpawnQueue, st)
    Script.SetTimerForFunction(self.ArcherCartDelay, "mercenaries.ArcherCartSpawnArchersDelayed")

    System.LogAlways("[ArcherCart] cart #" .. #self.ArcherCarts .. " parked - archers in " .. self.ArcherCartDelay .. "ms")
    -- Somebody else's cart is not one of the player's defences: saving it would have the
    -- defence restore rebuild it on load as OURS, with friendly archers on it. Same trap the
    -- watchtowers hit. DefSave filters on st.group too.
    if not st.group then
        pcall(function() if self.DefSave then self:DefSave() end end)
    end
    return st
end

-- Deferred archer spawn (FIFO, one pop per cart).
function mercenaries.ArcherCartSpawnArchersDelayed()
    local self = mercenaries
    local st = table.remove(self.ArcherCartSpawnQueue, 1)
    if not st or st.dead then return end
    for _, spec in ipairs(st.archerSpecs or {}) do
        local ent = self:SpawnStaticArcher(spec.pos, st.mode or self.ArcherCartMode, spec.face, st.group)
        if ent then table.insert(st.archers, { ent = ent, pos = spec.pos, face = spec.face }) end
    end
    System.LogAlways("[ArcherCart] " .. #st.archers .. "/" .. #(st.archerSpecs or {}) .. " archers aboard")
    table.insert(self.ArcherCartAttachQueue, st)
    Script.SetTimerForFunction(self.ArcherCartAttachDelay, "mercenaries.ArcherCartAttachDelayed")
end

-- Deferred attach - pins each archer to the bed for good (FIFO, one pop per cart).
function mercenaries.ArcherCartAttachDelayed()
    local self = mercenaries
    local st = table.remove(self.ArcherCartAttachQueue, 1)
    if not st or st.dead then return end
    for _, a in ipairs(st.archers) do
        if a.ent then self:AttachStaticArcher(a.ent, a.pos, a.face) end
    end
end

function mercenaries:ArcherCartClearOne(st)
    if not st then return end
    st.dead = true
    for _, id in ipairs(st.ids or {}) do pcall(function() System.RemoveEntity(id) end) end
    for _, a in ipairs(st.archers or {}) do
        if a.ent then pcall(function() self:RemoveStaticArcher(a.ent) end) end
    end
    for i = #self.ArcherCarts, 1, -1 do
        if self.ArcherCarts[i] == st then table.remove(self.ArcherCarts, i) end
    end
end

function mercenaries:ClearArcherCarts()
    for i = #self.ArcherCarts, 1, -1 do self:ArcherCartClearOne(self.ArcherCarts[i]) end
    self.ArcherCarts = {}
    System.LogAlways("[ArcherCart] all carts removed")
end

-- Nudge the archers' standing height on the bed, then respawn every cart in place.
function mercenaries:SetArcherCartHeight(up)
    up = tonumber(up); if not up then return end
    for _, a in ipairs(self.ArcherCartArcherLayout) do a.up = up end
    local placed = {}
    for _, st in ipairs(self.ArcherCarts) do table.insert(placed, { pos = st.origin, yaw = st.yaw }) end
    self:ClearArcherCarts()
    for _, p in ipairs(placed) do self:SpawnArcherCart(p.pos, p.yaw) end
    System.LogAlways("[ArcherCart] archer height = " .. up)
end

-- %line, not %1: AddCCommand does not substitute %1 into the body (see
-- [[reference_ccommand_arg_substitution]]), it passes the literal "%1"; %line is the
-- whole typed remainder, which for a single numeric arg is exactly what we want.
-- ==== PLACEMENT (aim + click, via the generic engine in mercenaries_tower.lua) ====
mercenaries.ArcherCartClearRadius = 5.0   -- keep this far from another cart

function mercenaries:IsSpotNearCart(pos, radius)
    if not pos then return false end
    radius = radius or self.ArcherCartClearRadius
    for _, st in ipairs(self.ArcherCarts or {}) do
        if st.origin then
            local dx, dy = pos.x - st.origin.x, pos.y - st.origin.y
            if (dx * dx + dy * dy) < (radius * radius) then return true end
        end
    end
    return false
end

-- Same rules as a tower: clear of camp props (the shared TowerCampBlockers snapshot),
-- clear of towers, and clear of other carts.
function mercenaries:CartSpotIsValid(pos)
    if not pos then return false end
    if self:IsSpotNearTower(pos) then return false end
    if self:IsSpotNearCart(pos) then return false end
    local r2 = self.TowerCampClearRadius * self.TowerCampClearRadius
    for _, b in ipairs(self.TowerCampBlockers or {}) do
        local dx, dy = pos.x - b.x, pos.y - b.y
        if (dx * dx + dy * dy) < r2 then return false end
    end
    return true
end

-- GHOST. The whole wagon mesh, keeping its OWN materials while the spot is valid
-- (validMaterial = nil): wagon_b.cgf is multi-submaterial, and forcing a single white
-- material onto it drops every submesh bound to another slot - only wheels and axle
-- survived. Pink still works when blocked, because the engine substitutes the
-- placeholder for every slot. See the note on GhostSetValid in mercenaries_tower.lua.
function mercenaries:CartPlaceSpec()
    return {
        parts = { { model = self.ArcherCartModel, x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0 } },
        validMaterial = nil,
        sink = 0,
        isValid = function(s, pos) return s:CartSpotIsValid(pos) end,
        atMax   = function(s) return #s.ArcherCarts >= s.ArcherCartMax end,
        confirm = function(s, pos, angle) s:SpawnArcherCart(pos, angle) end,
        info = { placing = 'merc_info_cart_placing', already = 'merc_info_cart_already',
                 aim = 'merc_info_cart_aim', blocked = 'merc_info_cart_blocked',
                 limit = 'merc_info_cart_limit', raised = 'merc_info_cart_raised',
                 cancelled = 'merc_info_cart_cancelled' },
    }
end

function mercenaries:StartArcherCartPlacement() self:StartPlacement(self:CartPlaceSpec()) end

System.AddCCommand("merc_archer_cart",        "mercenaries:SpawnArcherCart()",       "Spawn an archer cart (wagon + 3 static archers) ahead of you")
System.AddCCommand("merc_archer_cart_build",  "mercenaries:StartArcherCartPlacement()","Enter archer-cart placement: aim, left-click to place, right-click to finish")
System.AddCCommand("merc_archer_cart_clear",  "mercenaries:ClearArcherCarts()",      "Remove all archer carts")
System.AddCCommand("merc_archer_cart_z",      "mercenaries:SetArcherCartHeight(%line)","Set the archers' standing height on the bed (respawns carts)")
