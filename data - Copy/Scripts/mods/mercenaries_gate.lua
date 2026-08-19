-- Camp gates: the thing that closes the openings the wall builder leaves.
--
-- A gate is placed on its own (merc_gate_build / the quartermaster), independently of
-- any wall, and can be opened or closed. A CLOSED gate is a piece of wall as far as
-- pathing is concerned - it contributes a blocking segment - and a camp whose gates
-- are all shut is not raided. See docs/gates.md.
--
-- The candidate grid at the bottom is the authoring tool the meshes were chosen with.
--
-- Every mesh below was read out of the game's own Objects paks, so they all exist.
-- The camp wall is palisade_wall_a_v3 (mercenaries_wall.lua, type 3, up -3.00), so
-- each cell also spawns a piece of that wall either side of the candidate: a gate is
-- only judgeable against the wall it has to join.

local PAL  = "objects/manmade/structures/defensive/walls/palisade/"
local GATE = "objects/manmade/structures/logistical/gate/"
local FEN  = "objects/manmade/structures/logistical/fences/"
local BAR  = "objects/manmade/structures/logistical/barriers/"
local DOOR = "objects/manmade/common_fixtures/doors/"

-- Ordered best-guess first. The palisade-folder gate is the only gate the game ships
-- in the same kit as our wall; the gate/ folder pieces are free-standing timber gates
-- that would suit a camp; fences and barriers are the small, cheap fallbacks.
mercenaries.GateMxCandidates = {
    { n = "palisade_gate_nebakov", m = PAL  .. "palisade_halved_lower_gate_nebakov.cgf" },
    { n = "gate_beams_a",          m = GATE .. "gate_beams_a.cgf" },
    { n = "gate_beams_a_left",     m = GATE .. "gate_beams_a_door_left.cgf" },
    { n = "gate_beams_a_right",    m = GATE .. "gate_beams_a_door_right.cgf" },
    { n = "gate_wooden_a",         m = GATE .. "gate_wooden_a.cgf" },
    { n = "gate_wooden_a_burned",  m = GATE .. "gate_wooden_a_burned.cgf" },
    { n = "gate_wooden_b",         m = GATE .. "gate_wooden_b.cgf" },
    { n = "gate_wooden_c",         m = GATE .. "gate_wooden_c.cgf" },
    { n = "gate_wooden_d",         m = GATE .. "gate_wooden_d.cgf" },
    { n = "gate_wooden_d_closed",  m = GATE .. "gate_wooden_d_closed.cgf" },
    { n = "gate_wooden_d_portal",  m = GATE .. "gate_wooden_d_portal.cgf" },
    { n = "gate_wooden_d_wing_l",  m = GATE .. "gate_wooden_d_wing_left.cgf" },
    { n = "gate_wooden_d_wing_r",  m = GATE .. "gate_wooden_d_wing_right.cgf" },
    { n = "gate_wooden_e",         m = GATE .. "gate_wooden_e.cgf" },

    -- Fence gates: small, but the stick and plank ones share the camp's rough timber look.
    { n = "fence_sticks_c_gate",   m = FEN  .. "fence_sticks_c_gate.cgf" },
    { n = "fence_sticks_c_post",   m = FEN  .. "fence_sticks_c_gatepost.cgf" },
    { n = "fence_sticks_d_gate_1", m = FEN  .. "fence_sticks_d_gate_01.cgf" },
    { n = "fence_sticks_d_gate_2", m = FEN  .. "fence_sticks_d_gate_02.cgf" },
    { n = "fence_planks_a_gate",   m = FEN  .. "fence_planks_a_gate.cgf" },
    { n = "fence_4rod_gate_01",    m = FEN  .. "fence_4rod_gate_01.cgf" },
    { n = "fence_crisscross_gate", m = FEN  .. "fence_crisscross_gate.cgf" },

    -- Barriers: a checkpoint bar rather than a gate, but they read as "closed road".
    { n = "barrier_road_a",        m = BAR  .. "barrier_road_a.cgf" },
    { n = "barrier_road_closed",   m = BAR  .. "barrier_road_a_closed.cgf" },
    { n = "barrier_road_opened",   m = BAR  .. "barrier_road_a_opened.cgf" },
    { n = "barrier_natural_close", m = BAR  .. "barrier_road_natural_closed.cgf" },
    { n = "barrier_spikes",        m = BAR  .. "barrier_spikes.cgf" },

    -- Bare door leaves, for hanging in a frame built from wall pieces.
    { n = "gate_a_doors",          m = DOOR .. "gate_a_doors.cgf" },
    { n = "gate_b_doors",          m = DOOR .. "gate_b_doors.cgf" },
    { n = "gate_grille_static",    m = DOOR .. "gate_grille_static.cgf" },

    -- Trosky's palisade gate section. Big and level-specific; kept last.
    { n = "trosky_gate_palisade",  m = "objects/manmade/structures/defensive/gatehouses/unique/trosky/gate_e_palisade_part.cgf" },
}

mercenaries.GateMxFlankModel = PAL .. "palisade_wall_a_v3.cgf"
mercenaries.GateMxFlankUp    = -3.00   -- the camp wall's own sink (mercenaries_wall.lua)
mercenaries.GateMxFlankLen   = 2.75
mercenaries.GateMxYaw     = 0       -- degrees added to every gallery candidate
mercenaries.GateMxUp         = 0       -- height offset applied to every gallery candidate
mercenaries.GateMxEnts       = {}
mercenaries.GateMxLastArgs   = {}

local function gateArg(v)
    local t = tostring(v or ""):gsub("^%s*(.-)%s*$", "%1")
    t = t:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
    return (t:gsub("^%s*(.-)%s*$", "%1"))
end

local function gateMxSpawn(self, model, pos, yaw)
    local params = {
        class = "mercenaries_Prop",
        name = "MercGate_" .. tostring(math.random(100000, 999999)),
        position = pos,
        orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
        properties = { object_Model = model, bMissionCritical = false,
                       bSaved_by_game = false, bSerialize = false },
    }
    local ent = System.SpawnEntity(params)
    if not ent then
        params.class = "BasicEntity"
        params.properties.Physics = { bPhysicalize = true, bRigidBody = false,
                                      Mass = 0, Density = 0, bPushableByPlayers = false }
        ent = System.SpawnEntity(params)
    end
    if ent then
        pcall(function() ent:SetAngles({ x = 0, y = 0, z = yaw }) end)
        pcall(function() ent:SetViewDistUnlimited() end)
        pcall(function() ent:SetViewDistRatio(255) end)
        pcall(function() ent:SetLodRatio(255) end)
        table.insert(self.GateMxEnts, ent.id)
    end
    return ent
end

-- ==== the gate itself ====
-- Two meshes per style: the game has no animated field gate, so opening and closing is
-- a mesh swap. gate_wooden_d and gate_wooden_d_closed are the same gate carved open and
-- shut, which is why that pair is the default.
mercenaries.GateStyles = {
    { n = "wooden_d",  open = GATE .. "gate_wooden_d.cgf",
                       closed = GATE .. "gate_wooden_d_closed.cgf",       width = 4.0 },
    { n = "road_bar",  open = BAR .. "barrier_road_a_opened.cgf",
                       closed = BAR .. "barrier_road_natural_closed.cgf", width = 4.0 },
}
mercenaries.GateStyleIdx = 1
mercenaries.GateMax      = 4      -- a camp with a gate on every side is enough
-- COSMETIC ONLY: which way the mesh's own front axis points. It is deliberately NOT
-- applied to GateBlockSegments - the blocking span is derived from the gate's logical
-- yaw, and turning the mesh must never swing the seal off the opening.
mercenaries.GateYawFix   = 90     -- degrees added to a placed gate's MESH
mercenaries.GateSink     = 0      -- height offset for a placed gate
-- Clearance between a snapped gate's end and the palisade it butts onto. 0 is
-- geometrically flush; -0.6 is the value that actually reads right in play, tucking the
-- gate slightly into the wall so the two meshes overlap instead of meeting on a seam.
mercenaries.GateWallDist = -0.6
-- Invisible crate colliders, exactly the trick the player house uses: a spawned mesh's
-- own physics proxy is not enough to stop the player walking through, so a line of
-- PE_STATIC crates is tiled across the opening and then hidden with DrawSlot(0, 0),
-- which drops the render slot and keeps the physics. They exist only while the gate is
-- SHUT - an open gate has to be walkable.
mercenaries.GateColliderModel = "objects/manmade/common_furniture/crates/crate_low_a.cgf"
mercenaries.GateColliderStep  = 0.4          -- spacing along the gate, in metres
mercenaries.GateColliderLayerZ = { 0.5, 1.5, 2.5 }   -- stacked so it cannot be vaulted
mercenaries.GateColliderScale = { x = 1.0, y = 1.0, z = 1.0 }
mercenaries.GateColliderShow  = false        -- merc_gate_colliders_show 1 to see them
-- TEMPORARILY OFF while the E prompt is diagnosed: the crates sit right on the gate
-- line in three layers, so they are the obvious suspect for swallowing the interaction
-- ray before it reaches the gate. merc_gate_colliders 1 puts them back.
mercenaries.GateCollidersEnabled = false

mercenaries.Gates        = {}     -- { { x, y, z, yaw, open, ent, colliders } }

local function gateStyle(self)
    return self.GateStyles[self.GateStyleIdx] or self.GateStyles[1]
end

function mercenaries:GateWidth()
    return gateStyle(self).width or 4.0
end

function mercenaries:GateModel(open)
    local st = gateStyle(self)
    if open then return st.open end
    return st.closed
end

-- Remove a gate's prop, keeping the record. Used on every state change: with no
-- animation there is nothing to do but swap the mesh.
local function gateDespawnEnt(g)
    if g.ent then pcall(function() System.RemoveEntity(g.ent) end); g.ent = nil end
    for _, id in ipairs(g.colliders or {}) do
        pcall(function() System.RemoveEntity(id) end)
    end
    g.colliders = {}
end

-- Tile the invisible colliders across a SHUT gate. Laid along the gate's own panel -
-- the same line GateBlockSegments blocks for pathing - so what stops an NPC and what
-- stops the player are the same span.
function mercenaries:GateBuildColliders(g)
    self:GateClearColliders(g)
    if g.open or not self.GateCollidersEnabled then return 0 end
    g.colliders = {}

    local yaw = g.yaw or 0
    local px, py = -math.sin(yaw), math.cos(yaw)      -- along the panel
    local half = self:GateWidth() * 0.5
    local sc = self.GateColliderScale or { x = 1, y = 1, z = 1 }
    local step = math.max(0.3, (self.GateColliderStep or 0.4) * (sc.x or 1))
    local n = math.max(1, math.floor((self:GateWidth()) / step + 0.5))

    for i = 0, n do
        local t = (i / n) * 2 - 1                     -- -1 .. +1 across the gate
        local bx, by = g.x + px * half * t, g.y + py * half * t
        for _, lz in ipairs(self.GateColliderLayerZ or { 1.0 }) do
            local ent
            pcall(function()
                ent = System.SpawnEntity({
                    class = "mercenaries_Prop",
                    name = "MercGateCol_" .. tostring(math.random(100000, 999999)),
                    position = { x = bx, y = by, z = g.z + lz },
                    orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
                    scale = sc,
                    properties = { object_Model = self.GateColliderModel,
                                   bMissionCritical = false,
                                   -- not an interaction target: a crate that answers the
                                   -- interactor would steal the gate's own E prompt
                                   bInteractiveCollisionClass = false,
                                   bSaved_by_game = false, bSerialize = false },
                })
            end)
            if ent then
                pcall(function() ent:SetAngles({ x = 0, y = 0, z = yaw }) end)
                -- DrawSlot(0, 0) removes the render slot and leaves the physics behind
                if not self.GateColliderShow then pcall(function() ent:DrawSlot(0, 0) end) end
                table.insert(g.colliders, ent.id)
            end
        end
    end
    return #g.colliders
end

function mercenaries:GateClearColliders(g)
    for _, id in ipairs(g.colliders or {}) do
        pcall(function() System.RemoveEntity(id) end)
    end
    g.colliders = {}
end

local function gateSpawnEnt(self, g)
    gateDespawnEnt(g)
    local yaw = (g.yaw or 0) + math.rad(self.GateYawFix or 0)
    local pos = { x = g.x, y = g.y, z = g.z + (self.GateSink or 0) }
    local params = {
        -- mercenaries_Gate carries the E prompt (see Scripts/Entities/mercenaries_Gate.lua)
        class = "mercenaries_Gate",
        name = "MercGateProp_" .. tostring(math.random(100000, 999999)),
        position = pos,
        orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
        properties = { object_Model = self:GateModel(g.open), bMissionCritical = false,
                       bSaved_by_game = false, bSerialize = false },
    }
    -- Falls back through mercenaries_Prop before BasicEntity: if the gate class did not
    -- register, the gate should still be a solid static prop (just without the prompt)
    -- rather than a rigid body that can be shoved about.
    local ent = System.SpawnEntity(params)
    if not ent then
        params.class = "mercenaries_Prop"
        ent = System.SpawnEntity(params)
    end
    if not ent then
        params.class = "BasicEntity"
        params.properties.Physics = { bPhysicalize = true, bRigidBody = false,
                                      Mass = 0, Density = 0, bPushableByPlayers = false }
        ent = System.SpawnEntity(params)
    end
    if ent then
        pcall(function() ent:SetAngles({ x = 0, y = 0, z = yaw }) end)
        pcall(function() ent:SetViewDistUnlimited() end)
        pcall(function() ent:SetViewDistRatio(255) end)
        pcall(function() ent:SetLodRatio(255) end)
        pcall(function() ent:RenderShadow(true) end)
        -- GetActions runs on the entity and cannot see the gate record, so the state
        -- rides along on the entity itself
        ent.mercGateOpen = g.open
        g.ent = ent.id
    end
    self:GateBuildColliders(g)
    return ent
end

-- Place a gate. `open` defaults to closed, which is the state a player who has just
-- paid for a gate expects to see.
function mercenaries:GateBuild(pos, yaw, open)
    if not pos then return nil end
    local p = pos
    if self.CampSnapToGround then p = self:CampSnapToGround({ x = pos.x, y = pos.y, z = pos.z }) end
    local g = { x = p.x, y = p.y, z = p.z, yaw = yaw or 0, open = (open == true) }
    table.insert(self.Gates, g)
    gateSpawnEnt(self, g)
    self:GateTouched()
    return g
end

-- Gates change what the navmesh may cross, so the wall cache has to be dropped and the
-- guards re-posted whenever one is built, removed or swung.
function mercenaries:GateTouched()
    pcall(function() if self.WallTouched then self:WallTouched() end end)
    pcall(function() if self.NavRefreshPatrolRings then self:NavRefreshPatrolRings() end end)
end

function mercenaries:GateSetOpen(g, open)
    open = (open == true)
    if g.open == open then return false end
    g.open = open
    gateSpawnEnt(self, g)
    return true
end

-- The central order: swing every gate the camp has. This is what the quartermaster
-- command and merc_gate_open/merc_gate_close both run through.
function mercenaries:GateSetAllOpen(open)
    if #(self.Gates or {}) == 0 then
        Game.SendInfoText('merc_info_gate_none', false, 0, 3)
        System.LogAlways("[Gate] the camp has no gates")
        return 0
    end
    local n = 0
    for _, g in ipairs(self.Gates) do
        if self:GateSetOpen(g, open) then n = n + 1 end
    end
    self:GateTouched()
    pcall(function() if self.DefSave then self:DefSave() end end)
    if open then
        Game.SendInfoText('merc_info_gate_opened', false, 0, 4)
    else
        Game.SendInfoText('merc_info_gate_closed', false, 0, 4)
    end
    System.LogAlways(string.format("[Gate] %d gate(s) now %s (%d changed)",
        #self.Gates, open and "open" or "shut", n))
    return n
end

-- Called from mercenaries_Gate:OnUsed. The swing destroys the entity the callback is
-- running on, so the actual work waits a tick.
function mercenaries:GateToggleByEntity(entId)
    for _, g in ipairs(self.Gates or {}) do
        if g.ent == entId then
            self._gatePending = g
            Script.SetTimerForFunction(1, "mercenaries.GateToggleDeferred")
            return true
        end
    end
    return false
end

function mercenaries.GateToggleDeferred()
    local self = mercenaries
    local g = self._gatePending
    self._gatePending = nil
    if not g then return end
    pcall(function()
        self:GateSetOpen(g, not g.open)
        self:GateTouched()
        if self.DefSave then self:DefSave() end
    end)
end

function mercenaries:GateCount() return #(self.Gates or {}) end

-- True only when there IS something to shut and all of it is shut. An unwalled camp
-- with no gates must never read as sealed.
function mercenaries:GateAllClosed()
    local gs = self.Gates or {}
    if #gs == 0 then return false end
    for _, g in ipairs(gs) do
        if g.open then return false end
    end
    return true
end

-- Where the sentries stand (NavGatePosts) - the gates themselves, once any exist.
function mercenaries:GatePositions()
    local out = {}
    for _, g in ipairs(self.Gates or {}) do
        table.insert(out, { x = g.x, y = g.y, z = g.z })
    end
    return out
end

-- A shut gate is a piece of wall: one blocking segment across the opening, laid
-- perpendicular to the way the gate faces. Open gates contribute nothing, so the gap
-- reopens and a raid marches through it.
function mercenaries:GateBlockSegments()
    local out = {}
    local half = self:GateWidth() * 0.5
    for _, g in ipairs(self.Gates or {}) do
        if not g.open then
            -- g.yaw, NOT g.yaw + GateYawFix: see the note on GateYawFix
            local yaw = g.yaw or 0
            local px, py = -math.sin(yaw), math.cos(yaw)
            table.insert(out, { ax = g.x - px * half, ay = g.y - py * half,
                                bx = g.x + px * half, by = g.y + py * half })
        end
    end
    return out
end

function mercenaries:GateSaveList()
    local out = {}
    for _, g in ipairs(self.Gates or {}) do
        table.insert(out, { x = g.x, y = g.y, z = g.z, yaw = g.yaw or 0,
                            open = g.open and 1 or 0 })
    end
    return out
end

function mercenaries:GateClearAll()
    for _, g in ipairs(self.Gates or {}) do gateDespawnEnt(g) end   -- colliders included
    self.Gates = {}
    self:GateTouched()
end

function mercenaries:GateRemoveNearest()
    if not player then return end
    local pp; pcall(function() pp = player:GetWorldPos() end)
    if not pp then return end
    local best, bi, bd
    for i, g in ipairs(self.Gates or {}) do
        local dx, dy = g.x - pp.x, g.y - pp.y
        local d = dx * dx + dy * dy
        if not bd or d < bd then best, bi, bd = g, i, d end
    end
    if not best then System.LogAlways("[Gate] no gates to remove"); return end
    gateDespawnEnt(best)
    table.remove(self.Gates, bi)
    self:GateTouched()
    pcall(function() if self.DefSave then self:DefSave() end end)
    System.LogAlways("[Gate] removed (" .. #self.Gates .. " left)")
end

-- Rebuild every gate's prop: used after a style, yaw or sink change.
function mercenaries:GateRefresh()
    for _, g in ipairs(self.Gates or {}) do gateSpawnEnt(self, g) end
    self:GateTouched()
end

function mercenaries:GateSetStyle(v)
    local i = tonumber(gateArg(v))
    if not (i and self.GateStyles[i]) then
        System.LogAlways("[Gate] styles:")
        for k, st in ipairs(self.GateStyles) do
            local mark = ""
            if k == self.GateStyleIdx then mark = "  <- current" end
            System.LogAlways(string.format("[Gate]   %d = %-10s%s", k, st.n, mark))
        end
        return
    end
    self.GateStyleIdx = i
    self:GateRefresh()
    System.LogAlways("[Gate] style " .. gateStyle(self).n)
end

function mercenaries:GateSetYawFix(v)
    self.GateYawFix = tonumber(gateArg(v)) or 0
    self:GateRefresh()
end

function mercenaries:GateSetSink(v)
    self.GateSink = tonumber(gateArg(v)) or 0
    self:GateRefresh()
end

-- Build the collider crates at all. Off while the E prompt is being diagnosed.
function mercenaries:GateSetColliders(v)
    self.GateCollidersEnabled = (tonumber(gateArg(v)) == 1)
    self:GateRefresh()
    System.LogAlways("[Gate] colliders " .. (self.GateCollidersEnabled and "ON" or "OFF"))
end

-- Show them, to check the span actually covers the opening.
function mercenaries:GateSetCollidersShow(v)
    self.GateColliderShow = (tonumber(gateArg(v)) == 1)
    self:GateRefresh()
    System.LogAlways("[Gate] colliders " .. (self.GateColliderShow and "VISIBLE" or "hidden"))
end

function mercenaries:GateSetWallDist(v)
    self.GateWallDist = tonumber(gateArg(v)) or 0
    System.LogAlways(string.format("[Gate] wall clearance %.2fm (affects the NEXT snapped gate)",
        self.GateWallDist))
end

-- The gate's length along its own panel: both the blocking span and the slot the wall
-- builder leaves for it, so the two can never disagree.
function mercenaries:GateSetWidth(v)
    local w = tonumber(gateArg(v))
    if not w or w <= 0 then
        System.LogAlways(string.format("[Gate] width %.2fm", self:GateWidth())); return
    end
    gateStyle(self).width = w
    self:GateTouched()
    System.LogAlways(string.format("[Gate] width %.2fm", w))
end

-- ==== placement ====
-- Deliberately NOT subject to the camp-clearance test the tower and cart use: a gate
-- belongs in the gap in a wall, which is exactly where those refuse to sit. The only
-- rule is that two gates may not share a spot.
mercenaries.GateSpotMin = 3.0

function mercenaries:GateSpotIsValid(pos)
    if not pos then return false end
    for _, g in ipairs(self.Gates or {}) do
        local dx, dy = pos.x - g.x, pos.y - g.y
        if (dx * dx + dy * dy) < (self.GateSpotMin * self.GateSpotMin) then return false end
    end
    return true
end

function mercenaries:GatePlaceSpec()
    return {
        parts = { { model = self:GateModel(false), x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0 } },
        validMaterial = nil,
        sink = self.GateSink or 0,
        isValid = function(s, pos) return s:GateSpotIsValid(pos) end,
        atMax   = function(s) return #s.Gates >= s.GateMax end,
        confirm = function(s, pos, angle)
            s:GateBuild(pos, angle, false)
            pcall(function() if s.DefSave then s:DefSave() end end)
        end,
        info = { placing = 'merc_info_gate_placing', already = 'merc_info_gate_already',
                 aim = 'merc_info_gate_aim', blocked = 'merc_info_gate_blocked',
                 limit = 'merc_info_gate_limit', raised = 'merc_info_gate_raised',
                 cancelled = 'merc_info_gate_cancelled' },
    }
end

function mercenaries:StartGatePlacement() self:StartPlacement(self:GatePlaceSpec()) end

function mercenaries:GateStatus()
    local state = "at least one open"
    if self:GateAllClosed() then state = "ALL SHUT (raids suppressed)" end
    if not self.GateCollidersEnabled then
        System.LogAlways("[Gate] collider crates are OFF (merc_gate_colliders 1 to build them)")
    end
    System.LogAlways(string.format("[Gate] %d gate(s), style %s, %s",
        #(self.Gates or {}), gateStyle(self).n, state))
    for i, g in ipairs(self.Gates or {}) do
        System.LogAlways(string.format("[Gate]   #%d %-6s at %.1f,%.1f yaw %.0f, %d collider(s)",
            i, g.open and "open" or "closed", g.x, g.y, math.deg(g.yaw or 0),
            #(g.colliders or {})))
    end
end

System.AddCCommand("merc_gate_build",  "mercenaries:StartGatePlacement()",
    "Place a gate: aim, left-click to place, right-click to finish")
System.AddCCommand("merc_gate_open",   "mercenaries:GateSetAllOpen(true)",  "Open every camp gate")
System.AddCCommand("merc_gate_close",  "mercenaries:GateSetAllOpen(false)", "Shut every camp gate (stops raids)")
System.AddCCommand("merc_gate_remove", "mercenaries:GateRemoveNearest()",   "Remove the gate nearest you")
System.AddCCommand("merc_gate_clear",  "mercenaries:GateClearAll()",        "Remove every gate")
System.AddCCommand("merc_gate_status", "mercenaries:GateStatus()",          "List the camp gates and their state")
System.AddCCommand("merc_gate_style",  "mercenaries:GateSetStyle('%line')", "Gate mesh pair: merc_gate_style <n> (no arg lists them)")
System.AddCCommand("merc_gate_yawfix", "mercenaries:GateSetYawFix('%line')","Rotate every gate by N degrees (mesh front axis fix)")
System.AddCCommand("merc_gate_sink",   "mercenaries:GateSetSink('%line')",  "Raise or sink every gate by N metres")
System.AddCCommand("merc_gate_walldist","mercenaries:GateSetWallDist('%line')", "Clearance between a snapped gate and the wall it joins (0 = flush, negative overlaps)")
System.AddCCommand("merc_gate_width",  "mercenaries:GateSetWidth('%line')", "Length of the gate in metres (default 4)")
System.AddCCommand("merc_gate_colliders","mercenaries:GateSetColliders('%line')", "Build the shut gate's collider crates at all: 0 or 1 (currently OFF)")
System.AddCCommand("merc_gate_colliders_show","mercenaries:GateSetCollidersShow('%line')", "Make those collider crates visible: 0 or 1")

-- ==== candidate gallery (authoring) ====
-- cellsize = cell width in metres, percol = candidates per row, flank = 0/1.
function mercenaries:GateMatrixSpawn(line)
    local a = {}
    for w in gateArg(line):gmatch("%S+") do a[#a + 1] = w end
    local spacing = tonumber(a[1]) or 12.0
    local cols    = tonumber(a[2]) or 5
    local flank   = (a[3] == nil or tonumber(a[3]) ~= 0)
    self.GateMxLastArgs = { spacing, cols, flank and 1 or 0 }

    self:GateMatrixClear()
    if not player then return end
    if cols < 1 then cols = 1 end

    local o = player:GetWorldPos()
    local ang; pcall(function() ang = player:GetWorldAngles() end)
    local yaw = (ang and ang.z) or 0
    local fx, fy = math.cos(yaw), math.sin(yaw)
    local rx, ry = -fy, fx
    local gateYaw  = yaw + math.pi + math.rad(self.GateMxYaw or 0)
    local flankYaw = math.atan2(ry, rx) + math.rad(self.WallYawFix or 0)

    local rowPitch = spacing + 2.0
    local half = (cols - 1) * spacing * 0.5

    for i, p in ipairs(self.GateMxCandidates) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local fwd = 14.0 + row * rowPitch
        local lat = col * spacing - half
        local cx  = o.x + fx * fwd + rx * lat
        local cy  = o.y + fy * fwd + ry * lat

        local pos = { x = cx, y = cy, z = o.z }
        if self.CampSnapToGround then pos = self:CampSnapToGround(pos) end
        local ground = pos.z
        pos.z = ground + (self.GateMxUp or 0)

        local e = gateMxSpawn(self, p.m, pos, gateYaw)

        if flank then
            for _, s in ipairs({ -1, 1 }) do
                local d = s * (spacing * 0.5 - self.GateMxFlankLen * 0.5)
                local fp = { x = cx + rx * d, y = cy + ry * d, z = ground }
                if self.CampSnapToGround then fp = self:CampSnapToGround(fp) end
                fp.z = fp.z + (self.GateMxFlankUp or 0)
                gateMxSpawn(self, self.GateMxFlankModel, fp, flankYaw)
            end
        end

        System.LogAlways(string.format("[Gate] #%-2d r%d c%d  %-22s %s",
            i, row + 1, col + 1, p.n, e and "OK" or "FAILED"))
    end

    System.LogAlways(string.format(
        "[Gate] %d candidates, %d per row, %.1fm cells%s. merc_gate_matrix_clear to remove.",
        #self.GateMxCandidates, cols, spacing,
        flank and ", flanked by the camp palisade" or ""))
end

function mercenaries:GateMatrixClear()
    for _, id in ipairs(self.GateMxEnts or {}) do
        pcall(function() System.RemoveEntity(id) end)
    end
    self.GateMxEnts = {}
end

local function gateMxRespawn(self)
    local a = self.GateMxLastArgs or {}
    self:GateMatrixSpawn(table.concat({ a[1] or 12, a[2] or 5, a[3] or 1 }, " "))
end

function mercenaries:GateMxSetYaw(v)
    self.GateMxYaw = tonumber(gateArg(v)) or 0
    gateMxRespawn(self)
end

function mercenaries:GateMxSetUp(v)
    self.GateMxUp = tonumber(gateArg(v)) or 0
    gateMxRespawn(self)
end

function mercenaries:GateMxList()
    for i, p in ipairs(self.GateMxCandidates) do
        System.LogAlways(string.format("[Gate] #%-2d %-22s %s", i, p.n, p.m))
    end
end

-- %line, not %1: AddCCommand only substitutes the whole rest of the line.
System.AddCCommand("merc_gate_matrix",       "mercenaries:GateMatrixSpawn('%line')",
    "Grid of palisade-gate candidates: merc_gate_matrix [cellsize] [percol] [flank 0|1]")
System.AddCCommand("merc_gate_matrix_clear", "mercenaries:GateMatrixClear()",
    "Remove the gate matrix")
System.AddCCommand("merc_gate_mx_yaw",          "mercenaries:GateMxSetYaw('%line')",
    "Spin every candidate by N degrees and respawn (try 90)")
System.AddCCommand("merc_gate_mx_up",           "mercenaries:GateMxSetUp('%line')",
    "Raise or sink every candidate by N metres and respawn")
System.AddCCommand("merc_gate_mx_list",         "mercenaries:GateMxList()",
    "Print the candidate list with mesh paths")
