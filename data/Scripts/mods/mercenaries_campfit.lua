-- Making a camp prop LIE ON its ground instead of hovering level above it.
--
-- Two faults, one cause. Every camp prop was spawned with yaw only -
-- `SetAngles({ x = 0, y = 0, z = angleZ })` - and given a single height from one downward
-- ray at its origin. A prop is not a point: `tent_small_rustic_a` measures 3.06 x 4.66 m.
-- One height and no tilt is correct only on a billiard table; on anything else the uphill
-- half of the mesh goes into the hill and the downhill half hangs in the air. Measured on
-- gently rolling ground (0.9 m of variation across the whole camp), 27 of 66 props were
-- buried more than 5 cm, 11 floated more than 10 cm, and 19 stood more than 5 degrees off
-- their own ground. The camp's validator accepts slopes up to 28 degrees, so the worst
-- LEGAL site is far worse than that.
--
-- The fix is to stop treating the prop as a point: fit a plane to the terrain under its
-- measured footprint, put the prop's origin on that plane, and rotate it to match.
--
-- WHAT THIS DELIBERATELY DOES NOT TOUCH. Only `SpawnCampPropModel` - the decoration path -
-- calls this. Beds, seats and activity anchors come through `SpawnCampFurnitureSO`, which
-- is a different function, and they are left flat and untilted on purpose: an NPC's
-- sit/sleep animation is authored against a level surface, and this codebase has already
-- had mercs sitting a metre above a seat once (see CampPropsStatic in mercenaries_camp.lua)
-- from a change that looked equally harmless. Height correction is safe for those and tilt
-- is not, so they get neither until somebody can watch a merc lie down on a slope.
--
-- See docs/camp-inspection.md.

mercenaries.CampAlignToGround = true    -- master switch; merc_camp_align 0/1
mercenaries.CampAlignMaxDeg   = 18      -- clamp. A tent at 25 degrees reads as broken even
                                        -- when it is perfectly on its ground, and the mesh's
                                        -- own eaves start intersecting the slope.
mercenaries.CampAlignMap      = 1       -- which Euler convention SetAngles wants: 1..4.
                                        -- Calibrated from the residual the geo pass reports,
                                        -- not guessed - see merc_camp_alignmap.
mercenaries.CampFitStats      = { fitted = 0, tiltSum = 0, tiltMax = 0, moveSum = 0, moveMax = 0 }
                                        -- last build's totals, for merc_camp_align_report;
                                        -- reset with the camp on both teardown paths

-- Least-squares plane through the terrain under one footprint, expressed in the prop's own
-- frame: z(u, v) = a + b*u + c*v, where u runs along the prop's RIGHT and v along its
-- FORWARD, both measured from the footprint's centre.
--
-- The nine sample points are symmetric about that centre, which makes the normal equations
-- decouple - no matrix, no solver, three sums. That matters because this runs a couple of
-- hundred times while a camp is going up, on a machine that is already the slow one.
--
-- Returns a, b, c, n (samples used) - or nil when the column has no terrain at all
-- (a bridge, an interior with the heightmap cut away), in which case the caller must fall
-- back on the old single-ray height rather than inventing a plane.
function mercenaries:CampFitGroundPlane(centre, angle, halfW, halfH, fromZ)
    local fx, fy = math.cos(angle), math.sin(angle)
    local rx, ry = -fy, fx

    local su, sv, sz, suu, svv, n = 0, 0, 0, 0, 0, 0
    local lo, hi
    for _, s in ipairs({ {0,0}, {-1,-1}, {1,-1}, {1,1}, {-1,1}, {0,-1}, {0,1}, {-1,0}, {1,0} }) do
        local u, v = halfW * s[1], halfH * s[2]
        local px = centre.x + rx * u + fx * v
        local py = centre.y + ry * u + fy * v
        local z = self:CampFitTerrainZ(px, py, fromZ)
        if z then
            if not lo or z < lo then lo = z end
            if not hi or z > hi then hi = z end
            n = n + 1
            sz = sz + z
            su = su + u * z
            sv = sv + v * z
            suu = suu + u * u
            svv = svv + v * v
        end
    end
    if n < 4 then return nil end

    local a = sz / n
    local b = (suu > 1e-4) and (su / suu) or 0
    local c = (svv > 1e-4) and (sv / svv) or 0
    return a, b, c, n, lo, hi
end

-- Terrain height with a reach that suits a prop rather than a player. GroundTerrainAt looks
-- a fixed distance below the height it is handed; a footprint corner hanging over a bank can
-- be further down than that, and a nil there would silently drop a sample and flatten the fit.
function mercenaries:CampFitTerrainZ(x, y, fromZ)
    local hits = self:GroundRawHits(x, y, fromZ, 120, 1, ent_terrain)
    local h = hits[1]
    if h and h.pos then return h.pos.z end
    return nil
end

-- The two Euler components that lay a prop on a plane of gradient (b, c).
--
-- Which of SetAngles' x and y is pitch, which is roll, and which way each is signed, is a
-- property of this engine's Euler order that no amount of reading settles - so it is a
-- SETTING, not a guess. All four candidates are the same two angles with the axes swapped
-- and the signs flipped; merc_camp_alignmap picks one, and the geo pass's `mismatch` column
-- says immediately which is right: the correct map drives it to nearly zero, a wrong one
-- leaves it at or above the ground's own slope.
function mercenaries:CampFitAngles(p, q)
    -- atan of the gradient is the tilt about the axis ACROSS that gradient. p and q are
    -- WORLD gradients (along world X and Y) - see the note in CampFitProp.
    local tu = math.atan(p)      -- tilt implied by the slope along world X
    local tv = math.atan(q)      -- ...and along world Y
    local m = self.CampAlignMap or 1
    if     m == 1 then return -tv,  tu
    elseif m == 2 then return  tv, -tu
    elseif m == 3 then return  tu,  tv
    else                return -tu, -tv end
end

-- ================================================ keeping clear of buildings

-- The flatness gate reads the TERRAIN HEIGHTMAP, and a barn's dirt apron is perfectly flat
-- heightmap. So a spot with a building standing on it passes every test the placer has: the
-- ground is level, the material is soil, nothing of ours is nearby. The fifth judged survey
-- found the whole remaining geometry problem in that one blind spot - a smokehouse with
-- "roughly 0.5 to 1.0 m of the prop inside the roof", a void under its downhill footing, and
-- a drying rack with two posts over the apron lip:
--
--   "the 0.55 m step test is sampling the terrain heightmap and does not see building
--    collision, so a spot occupied by a barn reads flat"
--
-- The test for a building is the difference between the two surfaces. A collision ray sees
-- the barn; a terrain-only ray sees the ground under it. Where they disagree by more than a
-- kerb's worth, something is standing there.
mercenaries.CampStructureTol   = 0.45   -- collision this far above terrain = a structure
mercenaries.CampStructureRings = 8      -- samples around the footprint
-- How far a station may end up from the camp centre, however good the ground is out
-- there. Beyond this it stops being part of the camp.
-- Pulled in from 14 m after a judged survey called the camp "three or four disconnected
-- islands" with 20-30 m of dead ground between them. A station further out than this is
-- not part of the camp however good its footing.
mercenaries.CampStationLeash   = 11.0

-- Is the ground at (x, y) free of anything built? Returns true when clear.
function mercenaries:CampSpotStructureFree(x, y, fromZ, radius)
    radius = radius or 2.0
    local tol = self.CampStructureTol or 0.45

    local function solidZ(px, py)
        local hits = self:GroundRawHits(px, py, fromZ, 120, 1, self:GroundMask())
        local h = hits[1]
        if h and h.pos then return h.pos.z end
        return nil
    end

    -- Centre first: the cheapest rejection, and the most common one.
    local n = self.CampStructureRings
    for k = 0, n do
        local px, py = x, y
        if k > 0 then
            local a = (k - 1) / n * 2 * math.pi
            px = x + math.cos(a) * radius
            py = y + math.sin(a) * radius
        end
        local tz = self:CampFitTerrainZ(px, py, fromZ)
        local sz = solidZ(px, py)
        if tz and sz and (sz - tz) > tol then return false, sz - tz end
    end
    return true, 0
end

-- Nudge a blindly-offset position onto ground that is clear of buildings. The camp's food
-- stations and the player's chest are placed at a fixed bearing and radius from the camp
-- origin with no validation whatsoever, which is how a smokehouse ends up inside a barn.
-- This spirals outward from the wanted spot and takes the first clear one, so the station
-- still lands roughly where the layout intended.
-- `model` and `angle`, when given, also test the prop's MEASURED footprint against what the
-- camp has already claimed. The claim system (CampClaimFoot / CampFootClaimed) was fully
-- built and CampFootClaimed had no callers at all - props announced the space they took and
-- nothing ever asked. That is why a tent awning and a smokehouse were spawned in the same
-- place and interpenetrated in ten frames of one survey.
function mercenaries:CampNudgeClearOfStructures(pos, radius, maxOut, model, angle)
    if not pos or not self.CampSpotStructureFree then return pos end
    maxOut = maxOut or 9.0
    local fromZ = pos.z + 8
    local half = model and self.CampPropFootHalf and self:CampPropFootHalf(model, 0.35) or nil
    -- A caller with no model (a whole station) still has to keep off what the camp has put
    -- down: without this the stations tested buildings, plants and the ground and never the
    -- claims, and a weapon stack was found standing through the hunting station's rack.
    if not half and radius then half = { w = radius, h = radius } end
    -- Bad ground counts as "not clear" too. A station that falls back to a blind offset can
    -- land in a stream just as easily as inside a barn, and the fifth survey found the whole
    -- tavern in a streambed with an ale barrel floating clear of the water - "the single
    -- worst thing in the set". One helper, both faults.
    local function good(px, py)
        if not self:CampSpotStructureFree(px, py, fromZ, radius or 2.0) then return false end
        -- Vanilla entities, by volume. Cheap, and it catches what a downward ray walks past.
        if self.CampSpotEntityFree then
            local free = self:CampSpotEntityFree(px, py, pos.z, math.max(radius or 2.0, 1.5))
            if not free then return false end
        end
        if self.CampSurfaceOK and not self:CampSurfaceOK(px, py, fromZ) then return false end
        -- ...and nothing growing there. The bake is the only witness to a bush; every ray
        -- above walks straight through one.
        if self.VegFootprintHit then
            local plant = self:VegFootprintHit({ x = px, y = py }, angle or 0,
                half or { w = radius or 1.0, h = radius or 1.0 })
            if plant then return false end
        end
        -- ...and not on top of something the camp has already put down. A slack of 0.35 m is
        -- baked into `half` above: a bare box test lets a canvas skirt brush a plank wall,
        -- and touching reads as intersecting from any distance.
        if half and self.CampFootClaimed then
            local occupied = self:CampFootClaimed({ x = px, y = py, z = pos.z }, angle or 0, half)
            if occupied then return false end
        end
        -- ...and the ground it is moving TO has to be as flat as the ground it is leaving.
        -- Without this the spiral cheerfully relocates a station out of a barn and onto a
        -- bank: measured 2026-09-20, two stations moved 2.5 m "onto clear ground" and the
        -- camp's floating count went from 1 prop to 8. Clear is not the same as level.
        if self.CampMaxSpread and self.CampFitGroundPlane then
            local w = (half and half.w) or 1.0
            local h = (half and half.h) or 1.0
            local _, _, _, n, lo, hi = self:CampFitGroundPlane(
                { x = px, y = py }, angle or 0, math.max(w, 0.6), math.max(h, 0.6), fromZ)
            if n and lo and hi and (hi - lo) > self.CampMaxSpread then return false end
        end
        return true
    end

    if good(pos.x, pos.y) then return pos end

    -- LEASHED, and it takes the nearest good spot rather than the first one it trips over.
    --
    -- Unleashed, "find clear, level, unclaimed ground" degenerates into "walk to the empty
    -- ploughed field", because on a real site that is the only place satisfying all three at
    -- once. A judged survey watched it do exactly that: the tavern ended up alone in a field
    -- with no other camp prop in shot, and the forge strung across ten metres of furrows.
    -- A camp is a place, not a scatter, so distance from the camp is a cost, not free.
    local c = self.CampCenter or self.CampBuildOrigin
    local cap = self.CampStationLeash or 14.0

    for _, R in ipairs({ 2.5, 4.0, 5.5, 7.0, maxOut }) do
        local bestX, bestY, bestD
        for a = 0, 11 do
            local ang = a * (math.pi / 6)
            local px = pos.x + math.cos(ang) * R
            local py = pos.y + math.sin(ang) * R
            -- Never past the leash, measured from the camp itself.
            local okDist = true
            if c then
                local dx, dy = px - c.x, py - c.y
                okDist = (dx * dx + dy * dy) <= (cap * cap)
            end
            if okDist and good(px, py) then
                -- Nearest the camp centre wins, so a ring is searched for the BEST spot on
                -- it rather than abandoned at the first acceptable one.
                local d = 0
                if c then d = (px - c.x) ^ 2 + (py - c.y) ^ 2 end
                if not bestD or d < bestD then bestX, bestY, bestD = px, py, d end
            end
        end
        if bestX then
            local gz = self:CampFitTerrainZ(bestX, bestY, fromZ) or pos.z
            self:GroundNote(string.format(
                'moved a station %.1f m onto clear ground, to (%.1f, %.1f)', R, bestX, bestY))
            return { x = bestX, y = bestY, z = gz }
        end
    end
    -- Nowhere clear within reach: leave it where the layout wanted rather than flinging it
    -- across the map. A prop against a wall beats a prop in the next field.
    return pos
end

-- ==================================================== ground worth standing on

-- After two rounds the judge's verdict was that seating is solved and SITING is not: props
-- landing "in metre-high grass, brambles and streambed gravel instead of on the mown ground
-- twenty metres away". CampValidateSpot scored slope and obstacles and had no opinion at all
-- about what the ground was MADE of.
--
-- It does now, and the rule is measured rather than guessed. `merc_camp_surfscan` on a real
-- camp reported what every prop was standing on against what was available around it:
--
--     under 123 props          available in 60 m (512 cells)
--     mat_soil     75 (61%)    mat_soil     41.4%
--     mat_grass    35 (28%)    mat_grass    51.8%
--     mat_forest    7          mat_forest    3.3%
--     mat_bushes    6          mat_bushes    2.7%
--                              mat_mudwater  0.4%   <- the streambed
--
-- So 13 props sat on scrub and undergrowth that makes up 6% of the ground, while 93% of what
-- was within reach was clean soil or grass. That is the defect, in numbers: not a shortage
-- of good ground, just no preference for it.
--
-- Bad ground is a DENY-LIST here, unlike the tilt rule, because the failure modes are known
-- by name and an unfamiliar surface is far more likely to be ordinary footing than a bramble
-- thicket. An unknown material should not stop a camp being pitched at all.
mercenaries.CampBadSurfaces = {
    ["mat_bushes"]   = true,   -- brambles and scrub: props vanish into them
    ["mat_forest"]   = true,   -- leaf litter under canopy, always with trunks nearby
    ["mat_mudwater"] = true,   -- the streambed. "drying rack in the creek"
    ["mat_water"]    = true,
    ["mat_mud"]      = true,   -- a bog. The first camp of the day was pitched in one
}

mercenaries.CampSurfaceRule = true      -- merc_camp_surfrule 0/1

-- Names are resolved once and remembered: GetSurfaceTypeNameById is a bind call and this is
-- asked several hundred times while a camp goes up.
mercenaries.CampSurfNameCache = {}

function mercenaries:CampSurfaceName(id)
    if id == nil then return nil end
    local c = self.CampSurfNameCache[id]
    if c ~= nil then return c end
    local n
    pcall(function() n = System.GetSurfaceTypeNameById(id) end)
    n = n or ("id" .. tostring(id))
    self.CampSurfNameCache[id] = n
    return n
end

-- Is the ground at this column worth standing on? Returns ok, name.
function mercenaries:CampSurfaceOK(x, y, fromZ)
    if not self.CampSurfaceRule then return true, nil end
    local _, surf = self:GroundTerrainAt(x, y, fromZ)
    if surf == nil then return true, nil end          -- no reading is not a reason to refuse
    local name = self:CampSurfaceName(surf)
    if self.CampBadSurfaces[name] then return false, name end
    return true, name
end

function mercenaries:CampSurfRuleSet(line)
    self.CampSurfaceRule = self:CmdBool(line)
    System.LogAlways("[CampFit] surface rule is now "
        .. (self.CampSurfaceRule and "ON" or "OFF")
        .. " - rebuild the camp to see it")
end

mercenaries:DevCommand("merc_camp_surfrule", "mercenaries:CampSurfRuleSet(%line)",
    "Refuse to place camp props on scrub, forest floor, mud and water: 0/1")

function mercenaries:CampSpreadSet(line)
    local v = tonumber(self:CmdClean(line))
    if not v then
        System.LogAlways("[CampFit] merc_camp_spread <metres> - current "
            .. tostring(self.CampMaxSpread) .. "; 0 disables the flatness gate")
        return
    end
    self.CampMaxSpread = (v > 0) and v or nil
    System.LogAlways("[CampFit] footprint flatness gate is now " .. tostring(self.CampMaxSpread)
        .. " - rebuild the camp to apply")
end

mercenaries:DevCommand("merc_camp_spread", "mercenaries:CampSpreadSet(%line)",
    "How much the ground may step across an anchor's footprint before it is refused, in metres")

-- ====================================================== what may lean, and what may not

-- Laying EVERYTHING on the ground normal was too blunt, and the first judged survey said so
-- precisely: the tents came out right - "the hem traces the ground contour on all four
-- sides" - while the smokehouse and the drying rack leaned 10-12 degrees downhill like they
-- were toppling. A canvas skirt follows the ground because canvas is limp. A plank-built
-- shed does not: a carpenter stands it plumb and packs under the low side, and a leaning one
-- reads as broken however faithfully it matches the terrain.
--
-- So tilt is an ALLOW-LIST, not a deny-list. Anything not named here stays plumb, which
-- means a model added later is treated as rigid until somebody decides otherwise - the safe
-- default, because a wrongly-plumb prop looks ordinary and a wrongly-leaning one looks like
-- a bug.
mercenaries.CampFitTiltPatterns = {
    "tent", "sack", "pile", "cloth", "canvas", "tarp", "straw", "mat_", "hide", "blanket",
}

-- Plumb props are seated on the LOWEST ground under their footprint, not on the plane
-- through its middle. Pivoting a rigid box about its centre is what lifted the downhill base
-- corner clear of the slope - "roughly 15-20 cm of clear air under the near-left corner,
-- with the ground visible through it". Sitting it on the low corner instead trades that gap
-- for burying the uphill side, and burying is the right trade: a shed dug into a bank looks
-- like a shed dug into a bank, a floating one looks like a bug.
mercenaries.CampFitSink = 0.03      -- and a little further, so the seam is never visible

function mercenaries:CampFitTiltable(model)
    local m = string.lower(tostring(model or ""))
    for _, pat in ipairs(self.CampFitTiltPatterns) do
        if string.find(m, pat, 1, true) then return true end
    end
    return false
end

-- ======================================================= self-calibration

-- Enumerating sign conventions was the wrong method and it cost two full sweeps. Four
-- candidates were tried against local gradients and four against world gradients, and every
-- one of the eight made the mismatch WORSE - which is the signature of a model that is wrong
-- rather than a sign that is backwards.
--
-- So stop guessing and MEASURE. SetAngles' effect on a prop's up axis is a linear map for
-- small angles, and a linear map in two unknowns is determined by two probes:
--
--     up(ax, ay) ~= up(0, 0) + ax * dA + ay * dB
--
-- Spawn one throwaway entity, set (t, 0) and read its up axis, set (0, t) and read it again,
-- and dA and dB fall out. Inverting that 2x2 gives the (ax, ay) that puts the up axis on any
-- normal we like - no convention to pick, and it is correct by construction on whatever
-- Euler order this build actually uses.
--
-- The one thing two probes at a single yaw cannot tell us is whether ax and ay act in the
-- WORLD frame or in the prop's own, so the probe is repeated at yaw 90 degrees. If the
-- response is unchanged, the axes are world-fixed and world gradients feed the solve; if it
-- rotates with the prop, they are local and local gradients do.
mercenaries.CampAlignBasis = nil     -- { ax = {x,y}, ay = {x,y} } response, at yaw 0
mercenaries.CampAlignLocal = nil     -- true = ax/ay act in the prop's frame, false = world
mercenaries.CampAlignProbeModel = "objects/manmade/common_furniture/crates/crate_box_c.cgf"

local function upOf(ent)
    local u
    pcall(function()
        local v = ent:GetDirectionVector(2)
        if v then u = { x = v.x, y = v.y, z = v.z } end
    end)
    return u
end

-- One probe: set these angles on `ent`, read back where its up axis went.
local function probeUp(ent, ax, ay, yaw)
    pcall(function() ent:SetAngles({ x = ax, y = ay, z = yaw }) end)
    return upOf(ent)
end

function mercenaries:CampAlignCalibrate()
    if not player then return false end
    local t = 0.20                       -- ~11.5 deg: big enough to measure, small enough to stay linear
    local p = player:GetWorldPos()
    local ent
    pcall(function()
        ent = System.SpawnEntity({
            class = "BasicEntity",
            name = "MercAlignProbe_" .. tostring(math.random(100000, 999999)),
            -- Well below the terrain: it exists for a few milliseconds and nobody should
            -- ever see it. Physics off so it cannot push anything while it is there.
            position = { x = p.x, y = p.y, z = p.z - 400 },
            properties = {
                object_Model = self.CampAlignProbeModel,
                bSaved_by_game = false, bSerialize = false,
                Physics = { bPhysicalize = false, bRigidBody = false },
            },
        })
    end)
    if not ent then
        System.LogAlways("[CampFit] calibration FAILED: could not spawn a probe entity")
        return false
    end

    local function basisAt(yaw)
        local u0 = probeUp(ent, 0, 0, yaw)
        local ux = probeUp(ent, t, 0, yaw)
        local uy = probeUp(ent, 0, t, yaw)
        if not (u0 and ux and uy) then return nil end
        return {
            ax = { x = (ux.x - u0.x) / t, y = (ux.y - u0.y) / t },
            ay = { x = (uy.x - u0.x) / t, y = (uy.y - u0.y) / t },
        }
    end

    local b0 = basisAt(0)
    local b90 = basisAt(math.rad(90))
    pcall(function() System.RemoveEntity(ent.id) end)

    if not b0 or not b90 then
        System.LogAlways("[CampFit] calibration FAILED: the probe reported no up axis")
        return false
    end

    -- World-fixed if turning the prop 90 degrees did not change how ax/ay move its up axis.
    local d = math.abs(b90.ax.x - b0.ax.x) + math.abs(b90.ax.y - b0.ax.y)
            + math.abs(b90.ay.x - b0.ay.x) + math.abs(b90.ay.y - b0.ay.y)
    self.CampAlignLocal = (d > 0.35)
    self.CampAlignBasis = b0

    System.LogAlways(string.format(
        "[CampFit] calibration: d(up)/d(ax) = (%+.3f, %+.3f)  d(up)/d(ay) = (%+.3f, %+.3f)",
        b0.ax.x, b0.ax.y, b0.ay.x, b0.ay.y))
    System.LogAlways(string.format(
        "[CampFit] yaw-90 difference %.3f -> ax/ay act in the %s frame",
        d, self.CampAlignLocal and "PROP'S OWN" or "WORLD"))
    return true
end

-- Solve the 2x2 for the angles that put the up axis on a plane of gradient (gx, gy).
-- A plane z = a + gx*x + gy*y has unit normal proportional to (-gx, -gy, 1), so the up axis
-- has to move by (-gx, -gy) in the horizontal plane.
function mercenaries:CampAlignSolve(gx, gy)
    local B = self.CampAlignBasis
    if not B then return nil end
    local det = B.ax.x * B.ay.y - B.ax.y * B.ay.x
    if math.abs(det) < 1e-6 then return nil end
    local tx, ty = -gx, -gy
    local ax = ( tx * B.ay.y - ty * B.ay.x) / det
    local ay = ( ty * B.ax.x - tx * B.ax.y) / det
    return ax, ay
end

-- The whole correction for one prop, called from SpawnCampPropModel.
--
-- `pos` is what the ground snap already decided, and is used as the search height rather
-- than trusted as the answer. Returns newZ, angX, angY, plus a small diagnostic table; or
-- nil when it cannot improve on what it was given, which the caller treats as "leave it
-- exactly as it was".
function mercenaries:CampFitProp(model, pos, angle, ghost)
    if not self.CampAlignToGround then return nil end
    if not (pos and self.CampPropFootHalf) then return nil end
    angle = angle or 0

    -- Once per session, before the first prop that needs it.
    if self.CampAlignBasis == nil and self.CampAlignCalTried ~= true then
        self.CampAlignCalTried = true
        pcall(function() self:CampAlignCalibrate() end)
    end

    local half = self:CampPropFootHalf(model, 0)
    local w, h = half.w or 0, half.h or 0
    -- A SMALL PROP STILL NEEDS A HEIGHT, it just does not need a tilt. Returning nil here sent
    -- every barrel, bucket, jug and trestle foot down the caller's fallback, which is a single
    -- ray at the prop's origin - so on a 6 degree slope they contacted at the uphill corner and
    -- hung at the downhill one. That is five of the floaters in one judged survey:
    --
    --   "a level, rigid prop on a ~6-degree slope, contacting at its uphill corner and hanging
    --    at its downhill one, which is exactly what a single centre-point ray produces"
    --
    -- Below about a third of a metre the plane's GRADIENT is measuring heightmap noise rather
    -- than the slope the prop sits on, and a sack does not read as tilted anyway - so small
    -- props take the plumb path below, seated on their lowest corner like any other rigid prop.
    local small = (w < 0.30 or h < 0.30)
    -- Sample over at least a small span even for a tiny prop, or the "corners" collapse onto
    -- the centre and the minimum is the centre ray all over again.
    local sw, sh = math.max(w, 0.22), math.max(h, 0.22)

    local centre = self:CampFootCentre(pos, angle, half)
    local a, b, c, n, lo, hi = self:CampFitGroundPlane(centre, angle, sw, sh, pos.z + 8)
    if not a then return nil end

    -- A rigid prop stays plumb and sits on the lowest ground under its own footprint.
    if small or not self:CampFitTiltable(model) then
        local st = self.CampFitStats
        if st then
            st.fitted = st.fitted + 1
            st.plumb = (st.plumb or 0) + 1
            local moved = math.abs((lo or pos.z) - pos.z)
            st.moveSum = st.moveSum + moved
            if moved > st.moveMax then st.moveMax = moved end
        end
        -- FOOTPRINT-AWARE SEATING. Sitting on the strict minimum buries the uphill corner by
        -- roughly footprintWidth * tan(slope): about 4 cm for a 0.35 m stool, which nobody can
        -- see, and about 18 cm for the smokehouse's 1.5 m footprint, which reads as half its
        -- plinth eaten. A judged survey confirmed exactly that split - every small prop flush,
        -- the one wide prop sunk - and that the global sink constant was NOT the problem.
        --
        -- So lift wide props part-way back up the spread. k ramps in from 0 at 0.8 m diagonal
        -- to 0.35 at 2.0 m, which keeps the downhill corner within a centimetre or two of the
        -- ground while roughly halving the uphill burial. Small props are untouched, because
        -- for them hi-lo is already near zero and k never leaves 0.
        local seat = lo or pos.z
        if lo and hi then
            local diag = math.sqrt((2 * w) ^ 2 + (2 * h) ^ 2)
            local t = (diag - 0.8) / 1.2
            if t < 0 then t = 0 elseif t > 1 then t = 1 end
            seat = lo + (hi - lo) * (0.35 * t)
        end
        return seat - (self.CampFitSink or 0), 0, 0,
               { a = a, b = b, c = c, n = n, tilt = 0, plumb = true }
    end

    local fx, fy = math.cos(angle), math.sin(angle)
    local rx, ry = -fy, fx

    -- The plane's height at the prop's ORIGIN, which is not its footprint centre: three of
    -- the five tent meshes are not centred on their own origin, one of them by 0.69 m.
    local originZ = a - b * (half.right or 0) - c * (half.forward or 0)

    -- INTO WORLD AXES BEFORE THE EULER. The gradients above are in the prop's own frame
    -- (u along its right, v along its forward), but SetAngles' x and y turn out to be
    -- rotations about the WORLD axes, composed with the yaw rather than inside it. Feeding
    -- local gradients straight in tilts the prop in the wrong plane, which is why all four
    -- sign conventions made the mismatch WORSE instead of one of them fixing it - measured
    -- 2026-09-19, mean mismatch rose above the ground's own slope for every map, and a tent
    -- on a 30.1 deg slope came out at 49.1 deg, its slope plus the clamp.
    --
    -- A point at local (u, v) sits at world (u*r + v*f) for orthonormal r, f, so the same
    -- plane in world axes has gradients p, q below.
    local p = b * rx + c * fx
    local q = b * ry + c * fy

    local angX, angY = 0, 0
    local tilt = math.deg(math.atan(math.sqrt(p * p + q * q)))
    if tilt > 0.5 then
        local maxT = math.rad(self.CampAlignMaxDeg or 18)
        local scale = 1.0
        local tr = math.atan(math.sqrt(p * p + q * q))
        if tr > maxT then scale = maxT / tr end     -- clamp, keeping the tilt DIRECTION
        -- Measured basis first. Whether the gradient handed to the solve is the world one or
        -- the prop's own is itself a measurement (see CampAlignCalibrate), not a choice.
        if self.CampAlignBasis then
            local gx, gy
            if self.CampAlignLocal then
                -- SWAPPED, and not by accident. The basis was measured with
                -- GetDirectionVector, which reports in WORLD axes, at yaw 0 - where the
                -- prop's right (u, carrying b) lies along world +Y and its forward (v,
                -- carrying c) lies along world +X. Feeding (b, c) in as if they were (x, y)
                -- tilts the prop by exactly the right amount about the wrong axis, which is
                -- what the first run after the physics fix showed: want and got matched to a
                -- tenth of a degree on every prop while the mismatch still rose.
                gx, gy = c * scale, b * scale
            else
                gx, gy = p * scale, q * scale
            end
            angX, angY = self:CampAlignSolve(gx, gy)
        end
        if not angX then angX, angY = self:CampFitAngles(p * scale, q * scale) end
        -- A near-degenerate fit can hand back a wild angle (one prop came out asking for
        -- 278.9 degrees). Nothing in a camp should ever lean past the clamp, so refuse it
        -- rather than spawn a prop standing on its head.
        local lim = math.rad(self.CampAlignMaxDeg or 18) * 1.5
        if math.abs(angX) > lim or math.abs(angY) > lim then angX, angY = 0, 0 end
    end

    local st = self.CampFitStats
    if st then
        st.fitted = st.fitted + 1
        st.tiltSum = st.tiltSum + tilt
        if tilt > st.tiltMax then st.tiltMax = tilt end
        local moved = math.abs(originZ - pos.z)
        st.moveSum = st.moveSum + moved
        if moved > st.moveMax then st.moveMax = moved end
    end

    return originZ, angX, angY, { a = a, b = b, c = c, n = n, tilt = tilt }
end

-- Re-apply the fitted orientation to every prop that was given one, after the fact.
--
-- This exists to answer a question the last three sweeps could not: the tilt is computed
-- correctly (the calibration probe proves SetAngles moves a prop's up axis exactly as the
-- solve expects), yet camp props come out level. Either the angles never reach the entity,
-- or something resets them between our SetAngles and the next frame - a deferred
-- physicalization, or BasicEntity re-reading the `orientation` it was spawned with.
--
-- If running this AFTER the camp is standing drives the geo pass's delta negative, it is the
-- second case, and a re-apply on a short timer is also the fix. If it changes nothing, the
-- angles are not reaching the entity at all and the spawn path is where to look.
function mercenaries:CampRetilt()
    local wanted, applied, moved = 0, 0, 0
    for _, r in ipairs(self.CampPropLog or {}) do
        local ax, ay = r.angX or 0, r.angY or 0
        if ax ~= 0 or ay ~= 0 then
            wanted = wanted + 1
            pcall(function()
                local e = System.GetEntity(r.id)
                if not e then return end
                local before
                if e.GetDirectionVector then
                    local v = e:GetDirectionVector(2)
                    if v then before = v.z end
                end
                e:SetAngles({ x = ax, y = ay, z = r.angle or 0 })
                applied = applied + 1
                if e.GetDirectionVector then
                    local v = e:GetDirectionVector(2)
                    -- z of the up axis drops below 1 exactly when the prop is off level, so
                    -- this counts how many actually MOVED rather than how many were asked to.
                    if v and before and math.abs(v.z - before) > 0.001 then moved = moved + 1 end
                end
            end)
        end
    end
    System.LogAlways(string.format(
        "[CampFit] retilt: %d prop(s) wanted a tilt, %d reached, %d changed their up axis",
        wanted, applied, moved))
end

-- Facts about individual props, changing nothing. What the fit ASKED for against what the
-- entity actually IS. An aggregate over a camp cannot answer this: every rebuild lands on
-- different ground, so a mean that moved might only mean the hill moved.
--
--   want   the tilt the fit computed, in degrees
--   upz    z of the prop's up axis. 1.000 is dead level; a prop tilted by t reads cos(t).
--   got    the tilt that implies, in degrees
--
-- want high and got 0.0 means the orientation never reached the entity.
function mercenaries:CampTiltReport(line)
    local n = tonumber(self:CmdClean(line)) or 12
    local shown, level = 0, 0
    for _, r in ipairs(self.CampPropLog or {}) do
        local ax, ay = r.angX or 0, r.angY or 0
        if ax ~= 0 or ay ~= 0 then
            local upz
            pcall(function()
                local e = System.GetEntity(r.id)
                if e and e.GetDirectionVector then
                    local v = e:GetDirectionVector(2)
                    if v then upz = v.z end
                end
            end)
            local want = math.deg(math.sqrt(ax * ax + ay * ay))
            local got = upz and math.deg(math.acos(math.max(-1, math.min(1, upz)))) or -1
            if upz and upz > 0.9999 then level = level + 1 end
            if shown < n then
                shown = shown + 1
                System.LogAlways(string.format(
                    "[CampTilt] %-26s want=%5.1f deg  upz=%s  got=%5.1f deg",
                    tostring(r.prefix), want,
                    upz and string.format("%.4f", upz) or " nil  ", got))
            end
        end
    end
    System.LogAlways(string.format(
        "[CampTilt] %d of the tilted props are still dead level", level))
end

mercenaries:DevCommand("merc_camp_tiltreport", "mercenaries:CampTiltReport(%line)",
    "Per prop: the tilt the fit asked for against the orientation the entity actually has")

mercenaries:DevCommand("merc_camp_retilt", "mercenaries:CampRetilt()",
    "Re-apply the fitted tilt to every camp prop that was given one, after the build")

-- ======================================== vanilla props, by volume not by ray

-- `System.GetPhysicalEntitiesInBox` is a real volume query and it was sitting unused. A ray
-- down the middle of a cart misses both wheels; a box around the footprint cannot. It also
-- answers the question the camp could previously only ask about its OWN props - the claim map
-- knows where our tents are and knows nothing about the level's carts, crates and stashes.
--
-- It does NOT see the level's static brushes (the barn is not an entity) - that is what the
-- collision-vs-terrain ray test is for - and it does not see vegetation, which has no physics
-- proxy at all and cannot be detected by anything (see docs/camp-inspection.md).
--
-- Classes that are solid and placed by the level. NPCs, the player, triggers and loose
-- pickables are all excluded: they move, or you can walk through them, and rejecting ground
-- because a merc happens to be standing on it would reject most of the camp.
mercenaries.CampSolidClasses = {
    BasicEntity = true, AnimObject = true, Stash = true, Door = true,
    DestroyableObject = true, BreakableObject = true, RigidBodyEx = true,
    Ladder = true, Cart = true, TrainingDummy = true,
}

function mercenaries:CampSpotEntityFree(x, y, z, radius)
    local ents
    pcall(function()
        ents = System.GetPhysicalEntitiesInBox({ x = x, y = y, z = z }, radius or 1.5)
    end)
    if not ents then return true, nil end          -- query unavailable: do not invent a refusal
    for _, e in ipairs(ents) do
        local nm, cls
        pcall(function() nm = e:GetName() end)
        pcall(function() cls = e.class end)
        nm = tostring(nm or "")
        -- Ours, by prefix. Everything this mod spawns is Merc*, and the claim map already
        -- governs those - rejecting on them here would refuse the camp its own ground.
        if not (string.find(nm, "Merc", 1, true) == 1
                or string.find(nm, "Spawned", 1, true) == 1
                or string.find(nm, "Alx", 1, true) == 1) then
            if cls and self.CampSolidClasses[cls] then
                return false, nm .. "[" .. tostring(cls) .. "]"
            end
        end
    end
    return true, nil
end

-- ==================================================== staying on the same ground

-- Being within the leash is not the same as being part of the camp. A judged survey found the
-- mess tables 20-25 m away ACROSS A STREAM and the food dryer BEHIND the vanilla barn - both
-- on perfectly good ground, both unreachable-looking, because distance alone says nothing
-- about what lies between.
--
-- Contiguity: walk the straight line from the camp to the candidate and compare the terrain
-- under it against the straight line joining the two endpoints. A stream bed or a ditch dips
-- well below that line; a barn's ridge rises well above it. Either means the candidate is
-- somewhere else, whatever the map distance says.
mercenaries.CampContigDip  = 1.6   -- m below the line before it counts as a gully
mercenaries.CampContigRise = 2.2   -- m above it before it counts as something in the way

function mercenaries:CampSpotContiguous(from, to)
    if not (from and to) then return true end
    local dx, dy = to.x - from.x, to.y - from.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 3.0 then return true end
    local steps = math.min(24, math.max(6, math.floor(dist / 1.5)))
    local z0 = self:CampFitTerrainZ(from.x, from.y, from.z + 8) or from.z
    local z1 = self:CampFitTerrainZ(to.x, to.y, to.z + 8) or to.z
    for i = 1, steps - 1 do
        local t = i / steps
        local px, py = from.x + dx * t, from.y + dy * t
        local straight = z0 + (z1 - z0) * t
        local gz = self:CampFitTerrainZ(px, py, math.max(z0, z1) + 12)
        if gz then
            if (straight - gz) > self.CampContigDip then return false, "gully" end
            if (gz - straight) > self.CampContigRise then return false, "ridge" end
        end
    end
    return true
end

-- Pull a station back to the camp if it has wandered, and refuse ground that is not
-- contiguous with it. Returns the spot to use.
function mercenaries:CampLeashToCamp(pos, cap)
    if not pos then return pos end
    local c = self.CampCenter or self.CampBuildOrigin
    if not c then return pos end
    cap = cap or self.CampStationLeash or 11.0

    local dx, dy = pos.x - c.x, pos.y - c.y
    local d = math.sqrt(dx * dx + dy * dy)
    local ok = self:CampSpotContiguous(c, pos)
    if d <= cap and ok then return pos end
    self:GroundNote(string.format('a station at %.1f m (cap %.1f, %s) is being pulled in',
        d, cap, ok and 'joined' or 'cut off by the ground'))

    -- Walk back along the line toward the camp until it is both inside the cap and on
    -- ground that joins up with it.
    for _, f in ipairs({ 0.85, 0.7, 0.55, 0.4, 0.28 }) do
        local r = math.min(cap, d * f)
        if d > 0.01 then
            local px = c.x + dx / d * r
            local py = c.y + dy / d * r
            local gz = self:CampFitTerrainZ(px, py, (c.z or pos.z) + 40) or pos.z
            local cand = { x = px, y = py, z = gz }
            if self:CampSpotContiguous(c, cand)
               and (not self.CampSpotStructureFree or self:CampSpotStructureFree(px, py, gz + 8, 2.0))
               and (not self.CampSurfaceOK or self:CampSurfaceOK(px, py, gz + 8))
               and (not self.VegSpotBlocked or not self:VegSpotBlocked(px, py, 2.0)) then
                self:GroundNote(string.format('pulled a station in from %.1f m to %.1f m', d, r))
                return cand
            end
        end
    end

    -- The line back to the camp crosses the stream, and every point on it fails the same way.
    -- Walking it shorter cannot help; the station has to come in on a DIFFERENT bearing. A
    -- judged survey found the mess tables 25-30 m out across a brook and bushes - the line
    -- walk above had refused all five of its candidates and kept the far spot. Rings inside
    -- the leash, nearest bearing first, the same tests: the first spot that is clear, level
    -- enough and joined to the camp by ground a man can walk wins.
    local want = math.atan2(dy, dx)
    for _, R in ipairs({ 7.0, 8.5, 10.0, math.min(cap, 11.0) }) do
        local best, bestTurn
        for k = 0, 11 do
            local ang = want + k * (math.pi / 6)
            local px = c.x + math.cos(ang) * R
            local py = c.y + math.sin(ang) * R
            local gz = self:CampFitTerrainZ(px, py, (c.z or pos.z) + 40) or pos.z
            local cand = { x = px, y = py, z = gz }
            local turn = math.abs(math.atan2(math.sin(ang - want), math.cos(ang - want)))
            if (not bestTurn or turn < bestTurn)
               and self:CampSpotContiguous(c, cand)
               and (not self.CampSpotStructureFree or self:CampSpotStructureFree(px, py, gz + 8, 2.5))
               and (not self.CampSurfaceOK or self:CampSurfaceOK(px, py, gz + 8))
               and (not self.VegSpotBlocked or not self:VegSpotBlocked(px, py, 2.5))
               and (not self.CampSpotClearOfProps or self:CampSpotClearOfProps(cand, 3.0)) then
                best, bestTurn = cand, turn
            end
        end
        if best then
            self:GroundNote(string.format('brought a station in from %.1f m to a %.1f m ring, %.0f deg round',
                d, R, math.deg(bestTurn or 0)))
            return best
        end
    end
    return pos
end

-- ====================================================== finding the site

-- "Make camp here" can be said in a beech wood on a hillside, and then there is no camp
-- to be had within two metres of the man it was said to. The steepest-ground test did
-- exactly that: the map came back with not one buildable cell (3321 void, 4600 under
-- plants), the shortfall fallback took two cells that were "100 % bad", and a tent ring
-- was built in the trees on the cliff. Here the ground is asked about FIRST, cheaply, over
-- a wide circle: is there a patch a one-ring camp fits on, and where is the nearest? A
-- camp that walks thirty metres to a clearing is what the player meant; a camp in the
-- trees is not, and neither is no camp at all when open ground is in sight.
mercenaries.CampSiteRadius   = 36.0   -- how far the camp may walk from where it was asked for
mercenaries.CampSiteRing     = 6.0    -- spacing between the rings of candidates
mercenaries.CampSiteHalf     = 8.0    -- half-width of the ground a one-ring camp needs
mercenaries.CampSiteMaxVeg   = 0.35   -- more of the square than this under plants: not a site
mercenaries.CampSiteMaxRough = 0.30   -- mean rise per metre over the square (0.30 = 17 deg)
mercenaries.CampSiteMaxStep  = 3.0    -- height range across the square

-- Score one candidate centre. Returns score (lower is better), ok, and the parts.
function mercenaries:CampSiteScore(cx, cy, refZ)
    local half, step = self.CampSiteHalf, 4.0
    local grid, n, lo, hi = {}, 0, nil, nil
    for i = -2, 2 do
        grid[i] = {}
        for j = -2, 2 do
            local z = self:CampFitTerrainZ(cx + i * step, cy + j * step, refZ + 40)
            grid[i][j] = z
            if z then
                n = n + 1
                if not lo or z < lo then lo = z end
                if not hi or z > hi then hi = z end
            end
        end
    end
    if n < 20 then return nil, false end          -- a void, a roof, the edge of the world
    local rough, nr = 0, 0
    for i = -2, 2 do
        for j = -2, 2 do
            local z = grid[i][j]
            if z then
                local zx = grid[i + 1] and grid[i + 1][j]
                local zy = grid[i][j + 1]
                if zx then rough = rough + math.abs(zx - z) / step; nr = nr + 1 end
                if zy then rough = rough + math.abs(zy - z) / step; nr = nr + 1 end
            end
        end
    end
    rough = (nr > 0) and (rough / nr) or 0
    -- Plants: the area of their boxes inside the square (a trunk counts with its clearance).
    -- A UNION over 1 m cells, not a sum of box areas: the bushes of a thicket overlap, and
    -- summing their boxes read the it16 bench spot as 70% under plants where 35% of the
    -- ground actually was (measured offline from the tiles, 2026-09-22) - so the camp fled
    -- a meadow it had stood on for a week and pitched on the 7-degree slope next to it.
    local veg = 0
    if self.VegNear then
        local ox, oy, w = cx - half, cy - half, 2 * half
        local mark, covered = {}, 0
        for _, e in ipairs(self:VegNear(cx, cy, half + 1)) do
            local x0, y0, x1, y1
            if e[1] == 1 then
                local r = (e[9] or 0.3) + (self.VegTrunkClear or 0.5)
                x0, y0, x1, y1 = e[2] - r, e[3] - r, e[2] + r, e[3] + r
            else
                x0, y0, x1, y1 = e[4], e[5], e[6], e[7]
            end
            local ix0, iy0 = math.max(x0, ox), math.max(y0, oy)
            local ix1, iy1 = math.min(x1, ox + w), math.min(y1, oy + w)
            if ix1 > ix0 and iy1 > iy0 then
                for i = math.floor(ix0 - ox), math.ceil(ix1 - ox) - 1 do
                    for j = math.floor(iy0 - oy), math.ceil(iy1 - oy) - 1 do
                        local k = i * 64 + j
                        if not mark[k] then mark[k] = true; covered = covered + 1 end
                    end
                end
            end
        end
        veg = math.min(1, covered / (w * w))
    end
    -- Water and bog, at the centre and the four quarter points.
    local wet = 0
    if self.CampSurfaceOK then
        for _, o in ipairs({ { 0, 0 }, { -4, -4 }, { 4, -4 }, { -4, 4 }, { 4, 4 } }) do
            if not self:CampSurfaceOK(cx + o[1], cy + o[2], refZ + 40) then wet = wet + 1 end
        end
    end
    -- Something built on it.
    local built = 0
    if self.CampSpotStructureFree and not self:CampSpotStructureFree(cx, cy, refZ + 8, 4.0) then
        built = 1
    end
    -- Ploughed field under the square, as a share of its samples: a preference for the
    -- meadow next to it, never a refusal.
    local fieldN = 0
    if self.VegFieldAt then
        for i = -2, 2 do
            for j = -2, 2 do
                if self:VegFieldAt(cx + i * step, cy + j * step) then fieldN = fieldN + 1 end
            end
        end
    end
    local field = fieldN / 25
    local range = hi - lo
    local ok = veg <= self.CampSiteMaxVeg and rough <= self.CampSiteMaxRough
               and range <= self.CampSiteMaxStep and wet == 0 and built == 0
    local score = veg * 3 + rough * 4 + range * 0.3 + wet + built * 2 + field * 1.5
    return score, ok, veg, rough, range, wet, field
end

-- The centre to build at: the asked spot if a camp fits there, else the best spot on the
-- nearest ring that has one, else nil - and nil means "no camp here", said out loud.
function mercenaries:CampFindSite(center)
    if not (center and self.CampFitTerrainZ) then return center, 0 end
    local refZ = center.z
    local s0, ok0, veg0, rough0, range0, wet0, field0 = self:CampSiteScore(center.x, center.y, refZ)
    -- A spot that takes a camp is kept - unless it is a farmer's field and there is meadow
    -- within a ring or two: then the nearest ring with a spot that is both fit and mostly
    -- off the furrows wins, and the asked spot stays the fallback.
    if s0 and ok0 and (field0 or 0) < 0.5 then return center, 0 end
    if s0 and ok0 then
        for R = self.CampSiteRing, 2 * self.CampSiteRing, self.CampSiteRing do
            local nb = math.max(8, math.floor(2 * math.pi * R / 5))
            local best, bestScore
            for k = 0, nb - 1 do
                local a = k * 2 * math.pi / nb
                local cx, cy = center.x + math.cos(a) * R, center.y + math.sin(a) * R
                local s, ok, _, _, _, _, fld = self:CampSiteScore(cx, cy, refZ)
                if s and ok and (fld or 0) < 0.3 and (not bestScore or s < bestScore) then
                    bestScore, best = s, { x = cx, y = cy }
                end
            end
            if best then
                local gz = self:CampFitTerrainZ(best.x, best.y, refZ + 40) or refZ
                System.LogAlways(string.format(
                    '[Mercenaries] camp site: the asked spot is a ploughed field (%.0f%%); moved %.0f m onto the meadow at (%.1f, %.1f)',
                    field0 * 100, R, best.x, best.y))
                return { x = best.x, y = best.y, z = gz }, R
            end
        end
        return center, 0
    end
    System.LogAlways(string.format(
        '[Mercenaries] camp site: the asked spot will not take a camp (%.0f%% under plants, rise %.2f/m, %.1f m of relief, %d wet) - looking round',
        (veg0 or 1) * 100, rough0 or 0, range0 or 0, wet0 or 0))
    for R = self.CampSiteRing, self.CampSiteRadius, self.CampSiteRing do
        local nb = math.max(8, math.floor(2 * math.pi * R / 5))
        local best, bestScore
        for k = 0, nb - 1 do
            local a = k * 2 * math.pi / nb
            local cx, cy = center.x + math.cos(a) * R, center.y + math.sin(a) * R
            local s, ok = self:CampSiteScore(cx, cy, refZ)
            if s and ok and (not bestScore or s < bestScore) then
                bestScore, best = s, { x = cx, y = cy }
            end
        end
        if best then
            local gz = self:CampFitTerrainZ(best.x, best.y, refZ + 40) or refZ
            System.LogAlways(string.format(
                '[Mercenaries] camp site: moved %.0f m to open ground at (%.1f, %.1f)', R, best.x, best.y))
            return { x = best.x, y = best.y, z = gz }, R
        end
    end
    System.LogAlways(string.format('[Mercenaries] camp site: no ground for a camp within %.0f m', self.CampSiteRadius))
    return nil
end

-- ================================================ a station's whole footprint

-- Claim the ground a station's LAYOUT covers - the box round every piece's offset, at the
-- station's yaw, plus a margin - rather than a box guessed round its origin. A food cart's
-- wheels and shafts sat outside the guessed box, and a shelter was built through them.
function mercenaries:CampLayoutClaim(spot, ang, layout, margin, what)
    if not (spot and layout and self.CampClaimFoot) then return end
    local f0, f1, l0, l1 = math.huge, -math.huge, math.huge, -math.huge
    for _, L in ipairs(layout) do
        local f, l = tonumber(L.fwd) or 0, tonumber(L.lat) or 0
        if f < f0 then f0 = f end
        if f > f1 then f1 = f end
        if l < l0 then l0 = l end
        if l > l1 then l1 = l end
    end
    if f0 > f1 then return end
    margin = margin or 0.8
    local F = { x = math.cos(ang), y = math.sin(ang) }
    local Lft = { x = -F.y, y = F.x }
    local cf, cl = (f0 + f1) / 2, (l0 + l1) / 2
    local c = { x = spot.x + F.x * cf + Lft.x * cl, y = spot.y + F.y * cf + Lft.y * cl, z = spot.z }
    -- The claim's frame: forward carries the depth (fwd), right carries the width. `lat`
    -- is +left, which is the negative of the claim's right - the box is symmetric, so only
    -- the centre had to be placed with the sign right.
    self:CampClaimFoot(c, ang, { w = (l1 - l0) / 2 + margin, h = (f1 - f0) / 2 + margin }, what)
end

-- ================================================ a station's own furniture

-- Where one of a station's satellite props may stand. The tavern's barrels and the forge's
-- grindstone were blind offsets from the station centre: the centre was checked against
-- everything and its furniture against nothing, and a judged survey found an ale barrel
-- standing on a merc's bed and the grindstone under a bush. Each prop's own footprint is
-- tested against the bake, against what the camp had put down before the station (`upto`,
-- so a stool beside its own table is not refused for touching it) and against the ground's
-- material; a prop that fails slides toward the station centre until it is clear, and one
-- that never clears is not built. Returns the spot to use, or nil to leave the prop out.
function mercenaries:CampSatelliteSpot(pos, yaw, model, centre, what, upto, halfOverride)
    if not (pos and (model or halfOverride) and self.CampPropFootHalf) then return pos end
    local half = halfOverride or self:CampPropFootHalf(model, 0.15)
    local function clear(px, py)
        local p = { x = px, y = py, z = pos.z }
        if self.VegFootprintHit and self:VegFootprintHit(p, yaw or 0, half) then return false end
        if self.CampFootClaimed and self:CampFootClaimed(p, yaw or 0, half, upto) then return false end
        if self.CampSurfaceOK and not self:CampSurfaceOK(px, py, pos.z + 6) then return false end
        -- ...and the settled camp map at its corners: the map knows the stream's bank and
        -- the bushes' boxes, and a barrel with one foot on the bank is a barrel in the water.
        local map = self.CampLastMap
        if map and self.CampMapClassAt then
            local fx, fy = math.cos(yaw or 0), math.sin(yaw or 0)
            local rx, ry = -fy, fx
            for _, c in ipairs({ { 0, 0 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
                local cx = px + rx * c[1] * half.w + fx * c[2] * half.h
                local cy = py + ry * c[1] * half.w + fy * c[2] * half.h
                if self:CampMapClassAt(map, cx, cy) == "veg" then return false end
            end
        end
        return true
    end
    if clear(pos.x, pos.y) then return pos end
    local dx, dy = (centre and centre.x or pos.x) - pos.x, (centre and centre.y or pos.y) - pos.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d > 0.05 then
        dx, dy = dx / d, dy / d
        for _, s in ipairs({ 0.5, 1.0, 1.5, 2.0 }) do
            if s < d - 0.3 and clear(pos.x + dx * s, pos.y + dy * s) then
                self:GroundNote(string.format('%s slid %.1f m in toward its station, clear of what stood there',
                    tostring(what), s))
                return { x = pos.x + dx * s, y = pos.y + dy * s, z = pos.z }
            end
        end
    end
    self:GroundNote(string.format('%s left out: nothing clear near (%.1f, %.1f)', tostring(what), pos.x, pos.y))
    return nil
end

-- ================================================= seating loose clutter

-- The one place a prop can still end up in the air. `CampSnapToGround` takes the FIRST
-- surface a downward ray meets - so a barrel beside a trestle table snaps onto the TABLE, a
-- chest beside a bed awning snaps onto the CANVAS, and both hang there. It is the same trap
-- that put a log stool on top of the cooking tripod, one layer further out, and after the
-- seats were fixed these two were the only visible floaters left in 42 frames.
--
-- Terrain-only, like the seat fix: this cannot see props at all, so there is nothing for it
-- to land on by mistake. Height only - loose clutter keeps whatever orientation it was given.
function mercenaries:CampSeatOnTerrain(pos, model, angle)
    if not pos then return pos end
    local z
    if self.CampFitProp then
        z = self:CampFitProp(model, pos, angle or 0, false)
    end
    if not z and self.CampFitTerrainZ then
        z = self:CampFitTerrainZ(pos.x, pos.y, pos.z + 8)
    end
    if not z then return pos end
    return { x = pos.x, y = pos.y, z = z }
end

-- ===================================================================== commands

function mercenaries:CampAlignSet(line)
    self.CampAlignToGround = self:CmdBool(line)
    System.LogAlways("[CampFit] ground alignment is now "
        .. (self.CampAlignToGround and "ON" or "OFF")
        .. " - rebuild the camp (merc_camp_break, merc_camp_make) to see it")
end

function mercenaries:CampAlignMapSet(line)
    local n = tonumber(self:CmdClean(line))
    if not n or n < 1 or n > 4 then
        System.LogAlways("[CampFit] merc_camp_alignmap <1-4> - current " .. tostring(self.CampAlignMap))
        System.LogAlways("[CampFit] rebuild, then merc_camp_geo: the map whose mismatch is")
        System.LogAlways("[CampFit] nearest zero is the right one for this engine's Euler order")
        return
    end
    self.CampAlignMap = math.floor(n)
    System.LogAlways("[CampFit] align map " .. self.CampAlignMap .. " - rebuild the camp to apply")
end

function mercenaries:CampAlignMaxSet(line)
    local n = tonumber(self:CmdClean(line))
    if not n then
        System.LogAlways("[CampFit] merc_camp_alignmax <degrees> - current " .. tostring(self.CampAlignMaxDeg))
        return
    end
    self.CampAlignMaxDeg = n
    System.LogAlways("[CampFit] tilt clamped at " .. n .. " deg - rebuild the camp to apply")
end

function mercenaries:CampAlignReport()
    local st = self.CampFitStats
    if not st or st.fitted == 0 then
        System.LogAlways("[CampFit] nothing fitted yet - pitch a camp with alignment on")
        return
    end
    System.LogAlways(string.format(
        "[CampFit] fitted=%d (%d left plumb)  mean tilt=%.1f deg  max=%.1f deg  mean height move=%.3f m  max=%.3f m",
        st.fitted, st.plumb or 0, st.tiltSum / st.fitted, st.tiltMax,
        st.moveSum / st.fitted, st.moveMax))
end

mercenaries:DevCommand("merc_camp_align",     "mercenaries:CampAlignSet(%line)",
    "Lay camp props on the ground plane under them instead of spawning them level: 0/1")
mercenaries:DevCommand("merc_camp_alignmap",  "mercenaries:CampAlignMapSet(%line)",
    "Which Euler convention the tilt uses, 1-4; pick the one whose geo mismatch is nearest zero")
mercenaries:DevCommand("merc_camp_alignmax",  "mercenaries:CampAlignMaxSet(%line)",
    "Clamp the tilt a prop may take, in degrees")
mercenaries:DevCommand("merc_camp_aligncal", "mercenaries:CampAlignCalibrate()",
    "Measure how SetAngles moves a prop's up axis, and in which frame - settles the tilt mapping")
mercenaries:DevCommand("merc_camp_align_report", "mercenaries:CampAlignReport()",
    "What the last camp build's ground fit actually did")
