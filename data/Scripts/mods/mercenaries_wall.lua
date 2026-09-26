-- Wall builder: drop barrel markers where you look, and each edge between
-- consecutive markers is filled with a tiled run of wall segments. Mark three or
-- more and merc_wall_close joins the last back to the first, so the markers are the
-- corners of a polygon whose edges become walls.
--
-- Everything is rebuilt from the marker list (merc_wall_rebuild), so any parameter
-- can be re-tuned after the fact and the whole ring re-renders with it. Wall pieces
-- are STATIC (mercenaries_Prop) so they collide; markers are plain props.
-- Mesh picks come from the merc_barricade gallery - see docs and the barricade notes.

-- len/up/lat are per type because they depend on the mesh's own size and pivot: the
-- high palisade values below are the ones tuned in play. Switching type loads that
-- type's numbers; the merc_wall_len/up/lat commands still override them.
--
-- `ox` is NOT tuned - it is read off the mesh by tools/measure_gate.py. It is where the
-- body sits along the run relative to the mesh's own origin, and a piece is placed by
-- subtracting it, so the body lands where it was asked for. palisade_wall_a_v3 is
-- modelled 0.18 m off its own centre; with ox = 0 every piece of the camp wall was laid
-- that far down the run, so a run's two ends missed their own corner marks by 0.18 m in
-- opposite directions. That is the gap at the gate and the daylight at every corner.
mercenaries.WallTypes = {
    { n = "taras_a",       m = "objects/manmade/task_specific_props/combat/tarases/taras_a.cgf",                       len = 2.00, up =  0.00, lat =  0.00, ox = 0.06 },
    { n = "taras_c",       m = "objects/manmade/task_specific_props/combat/tarases/taras_c.cgf",                       len = 2.00, up =  0.00, lat =  0.00, ox = 0.05 },
    { n = "palisade_high", m = "objects/manmade/structures/defensive/walls/palisade/palisade_wall_a_v3.cgf",           len = 2.75, up = -3.00, lat =  0.00, ox = 0.18 },
    { n = "pavise_a",      m = "objects/manmade/task_specific_props/combat/pavises/pavise_a.cgf",                      len = 1.00, up =  0.00, lat =  0.00 },
    { n = "pavise_b",      m = "objects/manmade/task_specific_props/combat/pavises/pavise_b.cgf",                      len = 1.00, up =  0.00, lat =  0.00 },
    { n = "stakes",        m = "objects/manmade/structures/defensive/walls/palisade/palisade_wall_single_sharp.cgf",   len = 0.40, up =  0.00, lat =  0.00 },
}
mercenaries.WallTypeIdx = 3      -- the high palisade: the one that worked
mercenaries.WallTypePalisade = 3 -- and what LogiBuyWall must always go back to

-- Wall segments physicalise RIGID (resting) rather than static, which is the only way the
-- engine's obstacle system can see them at all - see docs/walls-and-sieges.md. Heavy and
-- asleep so they behave like the static ones did; merc_wall_rigid 0 puts them back.
-- OFF. Rigid + sunk 3 m into the ground = physics ejects the segment out of the terrain
-- and the tall thin ones topple. Confirmed in play. The obstacle visibility comes from
-- the invisible on-ground blockers instead, which are never buried and so never ejected.
mercenaries.WallRigid     = false
mercenaries.WallRigidMass = 25000

-- Corners are tracked as plain positions; nothing is spawned to show them (the wall
-- itself marks where they are). merc_wall_markers 1 puts the barrels back while
-- tuning, since a corner with no wall yet is otherwise invisible.
mercenaries.WallMarkerModel = "objects/manmade/common_furniture/barrels/barrel_a.cgf"
mercenaries.WallMarkersVisible = false

-- Tunables, initialised from the default type above.
mercenaries.WallSegLen  = nil    -- nil = use the type's own len
mercenaries.WallYawFix  = 0      -- degrees added to every segment's yaw (90 if the mesh runs across the edge)
mercenaries.WallUp      = -3.00  -- height offset (negative sinks the wall into the ground)
-- Lateral offset from the edge line (+ = left of A->B). Keep it at 0: it is applied
-- perpendicular to EACH edge, so at a corner one edge ends at B+lat*n1 while the next
-- starts at B+lat*n2, opening a gap of |lat|*|n1-n2| (~1.4*lat on a right angle).
-- Along a straight run it shifts every segment equally, so it changes nothing visible
-- now that the corner markers are hidden - it only ever aligned the wall to those.
mercenaries.WallLat     = 0.00
-- Where a mesh's own body sits ALONG the run relative to its origin. Every piece is
-- placed by its centre, so a mesh modelled from its left-hand end outward (seg220,
-- whitewash: origin at x=0, body running out to +5.06) lands half a tile down the run
-- and the whole wall slides off its markers. Measured off the mesh, subtracted here.
-- WallSetType loads the selected type's own value over this; see WallTypes above.
mercenaries.WallOx      = 0.18
mercenaries.WallSnap    = true   -- snap each segment to the ground it stands on (follows slopes)
-- Stone runs are laid at ONE height instead - see WallRunLevel. Castle wall types only;
-- a palisade has no joints to tear and keeps following the ground.
mercenaries.WallLevel   = true

-- A camp may have any number of separate wall stretches. WallRuns holds the finished
-- ones; WallMarks is the run currently being drawn, so everything in build mode still
-- works on a single corner list. EndWallBuild commits WallMarks into WallRuns.
-- Wall segments used to force SetViewDistRatio(255) + SetLodRatio(255) on top of
-- SetViewDistUnlimited, so every piece drew at maximum detail at any range for ever. Off by
-- default now; merc_camp_perf 0 turns it back on (needs merc_wall_rebuild to take effect).
mercenaries.WallForceMaxLod = false

mercenaries.WallRuns  = {}       -- { { pts = { {x,y,z}, ... }, closed = bool }, ... }
mercenaries.WallMarks = {}       -- { {x,y,z, ent=} } in mark order - the run being built
mercenaries.WallSegEnts = {}     -- spawned wall segment ids (rebuilt wholesale)
mercenaries.WallClosed = false
-- Coming within this of ANY existing palisade turns the build preview into a gate, so a
-- run that reaches back to another stretch (or to its own start) closes with a gate
-- rather than with more wall. It is the width of a palisade piece: get a wall's width
-- from a wall and you are at the opening, not still building along it.
mercenaries.WallGateSnap = 3.5
-- How much of the run being drawn is ignored by that test, in corners back from the
-- live end. Without it the corner just dropped is itself "a nearby palisade" and every
-- preview would snap to a gate the moment building started.
mercenaries.WallGateSnapSkip = 2
-- Superseded by the snap above: anything close enough to the start to seal the ring is
-- now gate territory, so there is no need to refuse the corner. Raise it to bring the
-- old "leave a gateway" refusal back.
mercenaries.WallGateMin = 0.0

local function wallType(self)
    return self.WallTypes[self.WallTypeIdx] or self.WallTypes[1]
end

-- Every run that has enough corners to be a wall, finished ones first and the
-- in-progress one last. This is what the navmesh, the staged battle and the raid
-- checks read - none of them care which run a piece of wall belongs to.
function mercenaries:WallAllRuns()
    local out = {}
    for _, r in ipairs(self.WallRuns or {}) do
        if r.pts and #r.pts >= 2 then table.insert(out, r) end
    end
    if self.WallMarks and #self.WallMarks >= 2 then
        -- carrying the same two per-run fields a committed run gets, so the stretch being
        -- drawn tiles, refits and saves exactly as it will once it is committed
        table.insert(out, { pts = self.WallMarks, closed = self.WallClosed,
                            flushEnd = self.WallFlushEnd, wtype = self.WallTypeIdx })
    end
    return out
end

function mercenaries:WallHasAny()
    if self.WallMarks and #self.WallMarks >= 2 then return true end
    for _, r in ipairs(self.WallRuns or {}) do
        if r.pts and #r.pts >= 2 then return true end
    end
    return false
end

function mercenaries:WallAllPoints()
    local out = {}
    for _, r in ipairs(self:WallAllRuns()) do
        for _, p in ipairs(r.pts) do table.insert(out, p) end
    end
    return out
end

-- The run with the most corners: used where a single perimeter is wanted (the guards'
-- wall-hugging patrol), which only makes sense against one stretch.
function mercenaries:WallLongestRun()
    local best
    for _, r in ipairs(self:WallAllRuns()) do
        if not best or #r.pts > #best.pts then best = r end
    end
    return best
end

-- Distance from p to segment ab, in 2D.
local function ptSegDist2D(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local L2 = dx * dx + dy * dy
    if L2 < 1e-6 then
        local ex, ey = px - ax, py - ay
        return math.sqrt(ex * ex + ey * ey)
    end
    local t = ((px - ax) * dx + (py - ay) * dy) / L2
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    local cx, cy = ax + dx * t, ay + dy * t
    local ex, ey = px - cx, py - cy
    return math.sqrt(ex * ex + ey * ey)
end

-- Every FREE END of an existing palisade. These are the only places a gate can be hung,
-- because a gate is hung by carrying the wall's own line onward: it starts at the end and
-- grows outward from it.
--
-- An interior corner is not a free end, and offering one was the bug behind "the gate
-- snaps one anchor point along". The old test took the nearest SEGMENT and grew the gate
-- out of whichever end of it was closer to the aim - so aiming at a corner in the middle
-- of a run pushed the gate past that corner and straight on top of the next stretch of
-- wall. A 45-degree turn hid it (the two lines diverge fast); freehand palisades bend
-- gently, so the gate lands almost exactly one corner along, over the wall that follows.
--
-- A closed ring has no free end and offers nothing. The run being drawn offers only its
-- START - its other end is the cursor.
function mercenaries:WallSnapEnds()
    local out = {}
    local function add(m, i, from)
        local a, b = m[i], m[from]
        if not (a and b) then return end
        local ux, uy = a.x - b.x, a.y - b.y          -- outward, away from the wall
        local L = math.sqrt(ux * ux + uy * uy)
        if L < 1e-4 then return end
        table.insert(out, { x = a.x, y = a.y, z = a.z, ux = ux / L, uy = uy / L })
    end
    for _, r in ipairs(self.WallRuns or {}) do
        if not r.closed and #r.pts >= 2 then
            add(r.pts, 1, 2)
            add(r.pts, #r.pts, #r.pts - 1)
        end
    end
    local m = self.WallMarks or {}
    if #m >= 2 + (self.WallGateSnapSkip or 2) then add(m, 1, 2) end
    return out
end

-- Shortest 2D distance from `pos` to any edge of a list of { pts, closed } runs.
local function runsNearestDist(pos, runs)
    local best = nil
    for _, r in ipairs(runs or {}) do
        local m = r.pts or {}
        for i = 1, #m - 1 do
            local d = ptSegDist2D(pos.x, pos.y, m[i].x, m[i].y, m[i + 1].x, m[i + 1].y)
            if not best or d < best then best = d end
        end
        if r.closed and #m > 2 then
            local d = ptSegDist2D(pos.x, pos.y, m[#m].x, m[#m].y, m[1].x, m[1].y)
            if not best or d < best then best = d end
        end
    end
    return best
end

-- How far `pos` is from the nearest bit of wall, or nil if there is none. Used to keep a
-- gateway on the curtain rather than out in the field beside it.
function mercenaries:WallNearestDist(pos)
    if not pos then return nil end
    return runsNearestDist(pos, self:WallAllRuns())
end

-- How much room a camp structure needs beside a palisade. A station's props reach about
-- 3.4m out from its tile centre (the tavern's tables are the widest - see the station
-- layouts), so five metres off the wall line keeps the whole assembly clear of it.
mercenaries.WallClearRadius = 5.0

-- Is `pos` close enough to a palisade for something built there to clip it? The camp asks
-- this before handing an upgrade a grid tile, the same way IsSpotNearTower keeps one off a
-- watchtower.
--
-- The SAVED runs stand in when nothing is live, for the same reason DefSavedTowerSpots
-- exists: buying an upgrade rebuilds the camp, and BreakMercCamp -> DefClearWorld empties
-- WallRuns a moment before the new layout is chosen, so at the instant a tile is claimed
-- the palisade the player can still see is invisible to a live check.
function mercenaries:IsSpotNearWall(pos, radius)
    if not pos then return false end
    radius = radius or self.WallClearRadius
    if radius <= 0 then return false end
    local best = self:WallNearestDist(pos)
    if not best and self.DefSavedWallRuns then
        local saved
        pcall(function() saved = self:DefSavedWallRuns() end)
        best = runsNearestDist(pos, saved)
    end
    return best ~= nil and best < radius
end

-- Is `pos` close enough to an existing palisade to become a gate? Returns the pose to
-- build it at, or nil.
--
-- The gate CONTINUES the line being built: its panel lies along the direction of
-- travel, so it reads as the last piece of the wall rather than a prop dropped beside
-- it. GateBlockSegments lays a gate's blocking span perpendicular to its facing, hence
-- the quarter turn between the two.
function mercenaries:WallGateSnapAt(pos)
    if not pos then return nil end
    -- No gate module, no snapping: the builder falls back to plain wall rather than
    -- erroring on the first click near a palisade.
    if not (self.GateBuild and self.GateModel) then return nil end
    if (self.WallGateSnap or 0) <= 0 then return nil end
    local ends = self:WallSnapEnds()
    if #ends == 0 then return nil end

    local best, bd
    for _, e in ipairs(ends) do
        local d = math.sqrt((pos.x - e.x) ^ 2 + (pos.y - e.y) ^ 2)
        if not bd or d < bd then best, bd = e, d end
    end
    if not best or bd > (self.WallGateSnap or 3.5) then return nil end

    -- SNAP to the wall rather than to the aim. The gate takes the END of the palisade it
    -- has reached and that palisade's OWN direction, so it is collinear with it and its
    -- edge sits on the wall's last corner. Orienting it along the direction of travel
    -- instead - which is what this did - left it at an angle to the wall it was meeting,
    -- and an angled join can never close: the two never touch on both sides at once.
    local ex, ey = best.x, best.y
    local ux, uy = best.ux, best.uy            -- along the wall, pointing away from it

    local gap  = self.GateWallDist or 0
    local wide = self:GateWidth()
    -- near edge sits on the wall's end (plus the clearance), so the gate grows outward
    local nx, ny = ex + ux * gap, ey + uy * gap
    local cx, cy = nx + ux * wide * 0.5, ny + uy * wide * 0.5
    local far = { x = nx + ux * wide, y = ny + uy * wide, z = pos.z }

    local c = { x = cx, y = cy, z = pos.z }
    if self.CampSnapToGround then
        c = self:CampSnapToGround(c)
        far = self:CampSnapToGround(far)
    end
    -- blocking span runs along the wall, so the facing is a quarter turn off it
    return { x = c.x, y = c.y, z = c.z, yaw = math.atan2(uy, ux) + math.pi / 2,
             dist = bd, far = far, snapped = true }
end

-- How far a joint may be stretched before it stops being a joint and starts being a
-- gap: the walltool's pieces are modelled about 4 cm longer than the pitch they are
-- laid at, so that is all the room a spread has.
local WallJointSlack = 0.03

local function segLen(self)
    local L = tonumber(self.WallSegLen) or wallType(self).len or 2.0
    if L < 0.1 then L = 0.1 end
    return L
end

-- Slack for the floor() below. A corner is snapped to exactly n*step from the last
-- one, but re-measuring that with sqrt() returns a hair under n*step, so a bare
-- floor() gives n-1 and quietly drops the final segment - the further out the corner,
-- the bigger the absolute error and the more often it happened.
local SEG_EPS = 1e-3

local function segCount(L, step)
    return math.floor(L / step + SEG_EPS)
end

-- One static wall piece.
--
-- A type carrying `vary` is a set of interchangeable meshes rather than one: the pieces
-- are cycled along the run so a long wall does not read as the same 4m repeated. The
-- counter is per rebuild, so the same wall comes back the same way every time.
mercenaries.WallVaryIdx = 0

function mercenaries:WallSpawnSegment(pos, yaw, override)
    local wt = wallType(self)
    local model = override or wt.m
    if not override and wt.vary and #wt.vary > 0 then
        model = wt.vary[(self.WallVaryIdx % #wt.vary) + 1]
        self.WallVaryIdx = self.WallVaryIdx + 1
    end
    local params = {
        class = "mercenaries_Prop",
        name = "MercWallSeg_" .. tostring(math.random(100000, 999999)),
        position = pos,
        orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
        -- AI.bUsedAsDynamicObstacle is on the class too; passed again here because entity
        -- properties are read when the entity physicalises, and the spawn-time table is the
        -- only one guaranteed to be in place by then. It is what makes NPCs steer round the
        -- piece instead of into it - see mercenaries_Prop.lua and mercenaries_navobst.lua.
        properties = { object_Model = model, bMissionCritical = false,
                       bSaved_by_game = false, bSerialize = false,
                       AI = { bUsedAsDynamicObstacle = 1 },
                       -- THE point of this whole exercise. The engine gathers obstacle
                       -- candidates with a physics query whose mask is
                       -- ent_rigid | ent_sleeping_rigid (0x50006 in sub_2F52A5C); ent_static
                       -- is not in it. A PE_STATIC segment is therefore never offered to the
                       -- obstacle builder and bUsedAsDynamicObstacle on it does nothing at
                       -- all. Physicalised RIGID and left resting, the segment IS in the mask
                       -- (ent_sleeping_rigid) and registers its own true geometry - no
                       -- stretched stand-in, no pivot guesswork.
                       Physics = mercenaries.WallRigid and {
                           bPhysicalize = true,
                           bRigidBody = true,
                           bResting = 1,
                           Mass = mercenaries.WallRigidMass or 25000,
                           Density = -1,
                           bPushableByPlayers = false,
                       } or nil },
    }
    local ent = System.SpawnEntity(params)
    if not ent then
        params.class = "BasicEntity"
        params.properties.Physics = { bPhysicalize = true, bRigidBody = false, Mass = 0, Density = 0, bPushableByPlayers = false }
        ent = System.SpawnEntity(params)
    end
    if ent then
        pcall(function() ent:SetAngles({ x = 0, y = 0, z = yaw }) end)
        pcall(function() ent:SetViewDistUnlimited() end)
        -- Forcing ratio AND LOD to 255 means every segment draws at maximum detail at any
        -- distance for ever - and wall is the one thing in the camp with no cap on how much of
        -- it a player can buy. Towers and house parts never force these and look fine, so this
        -- was the outlier rather than a requirement. merc_camp_perf 0 restores it.
        if self.WallForceMaxLod then
            pcall(function() ent:SetViewDistRatio(255) end)
            pcall(function() ent:SetLodRatio(255) end)
        end
        pcall(function() ent:RenderShadow(true) end)
        table.insert(self.WallSegEnts, ent.id)
        -- Our own meshes carry no material of their own: rc.exe writes "default" as the
        -- library name whenever it compiles from FBX, so the type names the .mtl and it
        -- is applied here. Base-game meshes leave `mtl` nil and keep their own.
        local wt = wallType(self)
        if wt.mtl then pcall(function() ent:SetMaterial(wt.mtl) end) end
        -- stone walls are one-sided level facades: a turned-about copy closes the
        -- see-through face and gives the wall its thickness (mercenaries_castle.lua)
        if self.CastleSpawnBack then self:CastleSpawnBack(pos, yaw) end
        -- and the clutter that was modelled onto this type, a few pieces of it
        if wt.decor and not self._castleBacking then self:WallSpawnDecor(wt, pos, yaw) end
    end
    return ent
end

-- Where the segments along a->b go: { {pos =, yaw =} }.
--
-- Spacing is ALWAYS the segment length - it is never stretched to reach the cursor,
-- so the distance between pieces (and from the starting anchor) never changes. The
-- count is rounded down and anything left over is simply cut off, so pushing the
-- cursor out pops the next whole segment in when it fits.
--
-- The wall still meets its corners because WallMark snaps the anchor to where the run
-- actually ENDED (see WallEdgeEnd) rather than to the raw cursor position, so the next
-- edge starts exactly where the last piece finished.
-- Preview and the real build both use this, so the ghost never lies.
-- `flush`: the run must REACH b, not stop at the last whole piece. Tiling is by whole
-- segments and the remainder is normally cut off, which is exactly the gap that showed
-- up between the wall and a gate. One extra piece, laid so its far edge lands on b,
-- closes it - it overlaps its neighbour by whatever the remainder was, and an overlap
-- in a line of stakes is invisible where a gap is not.
-- `cutA` / `cutB`: metres at each end that something else is already standing in. A
-- castle corner piece or a corner tower IS that much of the wall (mercenaries_castle.lua
-- hands out the figures), so the tiling starts that far in rather than running into it.
-- Both are half a segment, so what is left is still a whole number of pieces and the
-- merlon grid carries through the turn.
function mercenaries:WallEdgeSegments(a, b, flush, cutA, cutB)
    local out = {}
    local dx, dy = b.x - a.x, b.y - a.y
    local L = math.sqrt(dx * dx + dy * dy)
    local c0 = math.max(0, tonumber(cutA) or 0)
    local c1 = math.max(0, tonumber(cutB) or 0)
    local span = L - c0 - c1
    local step = segLen(self)
    local n = segCount(span, step)
    -- The fill lays ONE more piece, placed so its far edge lands on b, and pays for it
    -- with an overlap of (step - remainder) onto whatever is already standing behind it.
    -- That is a fair trade while something IS standing behind it. When the remainder is
    -- a few centimetres the piece reaches a whole tile back - through the corner mesh at
    -- this end and out into the edge before it - which is the wall-on-top-of-a-wall a
    -- multi-turn run used to grow. So "cover" allows it only while the piece's near end
    -- stops at or beyond the corner's own turning point; plain `true` is the gate, where
    -- the run MUST touch b whatever it costs.
    local rest = span - n * step
    local fill = false
    -- A ring's JOIN has to land on b exactly. This used to share the leftover out across
    -- the edge's own joints - spreading the pieces rather than laying them a tile apart -
    -- on the reasoning that a few centimetres at each of four joints is invisible while
    -- one 20 cm slot is not.
    --
    -- The spread can only ever make the pitch LONGER than a tile. `n` is the floor of
    -- span/step, so span/n is always at least step, and a pitch longer than the piece is
    -- daylight at every single joint. On a 50 m side it came to 1.14 m of clear air three
    -- times over: not a few centimetres, a stone wall you can walk through. Choosing the
    -- other way (n+1 pieces, pitch shorter than a tile) is no better - it laps 2.25 m of
    -- stone at every joint and throws the merlon spacing out with it.
    --
    -- So the leftover goes where it goes on every other edge: exact pitch, and ONE extra
    -- piece slid flush to the end to lap the one before it. The overlap is confined to a
    -- single joint instead of being smeared across all of them, and the closing edge now
    -- reads exactly like the other three.
    local pitch = step
    if flush == "close" and span > 0.15 then
        -- The leftover is worth a piece of its own only if a piece would actually show.
        -- Below that it is left to the corner, whose arm covers a few centimetres without
        -- anyone seeing; above it, one piece slid flush to the end laps the one before it,
        -- which is what every other edge does.
        --
        -- What must NOT happen is either extreme. Spreading the pieces wider than a tile
        -- opens daylight at every joint - `n` is the floor of span/step, so span/n is
        -- always at least step - and on a 50 m side that was 1.14 m of clear air three
        -- times over. Lapping a piece over a tiny remainder is the opposite failure: the
        -- filler lands all but on top of its neighbour and the two z-fight.
        --
        -- A tile is modelled a few centimetres LONGER than the pitch it is laid at, and
        -- that over-length is the only slack a spread has to hide in: stretch a joint by
        -- more than that and it is a hole. So the leftover is shared out only while every
        -- joint stays inside it, and anything bigger buys its own piece.
        local lo = math.max(1, n)
        -- What is left over decides this, not how many pieces are already down. A
        -- remainder small enough to tuck against a corner arm is left there; anything
        -- bigger takes another piece, even on an edge currently holding only one - a
        -- chamfered ring's join is a single tile with eleven metres still to cover.
        local joints = lo - 1
        if rest > 0.25 and rest > WallJointSlack * math.max(1, joints) then
            -- Too much to hide in the joints. Take one MORE piece and close the pitch up
            -- instead: the pieces then lap rather than part. With fixed-length tiles an
            -- arbitrary span has to give somewhere, and stone lapping stone is a seam
            -- while stone parting from stone is a hole in the curtain.
            n, pitch = lo + 1, span / (lo + 1)
            rest = 0
        elseif joints >= 1 and rest > 0.005 then
            pitch, rest = span / lo, 0
        end
    elseif rest > 0.15 then
        if flush == "cover" then
            fill = (c0 + c1) > 0 and (c0 + span) >= step - 0.05
        elseif flush then
            fill = true
        end
    end
    if n < 1 then
        if not fill or span < 0.15 then return out end
        n = 0                                   -- too short for a whole piece: fill it anyway
    end
    local ux, uy = dx / L, dy / L
    local yaw = math.atan2(uy, ux) + math.rad(self.WallYawFix or 0)
    -- lateral offset is to the LEFT of a->b
    local lx, ly = -uy * (self.WallLat or 0), ux * (self.WallLat or 0)

    local ox = tonumber(self.WallOx) or 0

    -- ==== walking a slope ====
    -- A type with transition pieces climbs instead of levelling, and it climbs the way a
    -- wall does: it ENTERS a lean, HOLDS it for as long as the ground keeps pulling away,
    -- and LEAVES it back to level. That is one continuous incline, not a staircase - the
    -- pieces chain because their end faces agree on the angle.
    --
    -- A type that only owns a level-to-level step (the yard wall, whose pieces the game
    -- ships) has no lean to hold, so it just spends one step whenever the ground has
    -- pulled far enough away.
    local wt = wallType(self)
    local slope = wt.slope
    -- Carried across the whole run, not reset per edge: an edge that started again from
    -- zero would drop the wall back to the marked height at every corner, which is what
    -- put a corner piece three metres under its own curtain.
    local climb = tonumber(self.WallClimb) or 0.0
    local lean = tonumber(self.WallLean) or 0   -- 0 level, 1 leaning up, -1 leaning down

    -- Which piece this tile spends, given how far the ground has pulled away. `last` is
    -- true on the final tile of the edge: a lean MUST be left before the edge ends, or
    -- the run finishes on a tilted face with a level corner to meet.
    local function pick(want, last, room)
        if not slope then return nil end
        local set = (lean > 0) and slope.up or (lean < 0) and slope.down or nil
        if set then
            -- Hold the lean only while there is enough ground left to justify a whole
            -- tile of it. A 12-degree lean climbs 2.6 m a tile against ground that
            -- typically rises one, so testing merely "is the ground still above us"
            -- spends holds that overshoot and then have to be levelled off again.
            local going = (want / set.hold.rise) > 0.5
            local piece = (going and not last) and set.hold or set.leave
            if piece == set.leave then lean = 0 end
            return piece
        end
        local start = tonumber(slope.start) or 1.0
        set = (want > start) and slope.up or (want < -start) and slope.down or nil
        if not set then return nil end
        if set.step then return set.step end     -- level to level in one tile, no lean
        -- entering costs a tile now and another to leave, so only if there is room
        if room < 2 then return nil end
        lean = (want > 0) and 1 or -1
        return set.enter
    end

    local function place(d, last, room)         -- d measured from a, along a->b
        local e = d - ox                        -- the piece's origin, not its centre
        local p = { x = a.x + ux * e + lx, y = a.y + uy * e + ly,
                    z = a.z + (b.z - a.z) * (d / L) }
        if self.CampSnapToGround then p = self:CampSnapToGround(p) end
        -- Sample the terrain under the MIDDLE of the piece, not under its origin: this
        -- kit is modelled from one end, so the two are half a tile apart and levelling
        -- off the origin biases the whole run down the slope by six metres.
        p.ground = p.z
        if ox ~= 0 and self.CampSnapToGround then
            local mid = self:CampSnapToGround({ x = a.x + ux * d + lx,
                                                y = a.y + uy * d + ly, z = p.z })
            p.ground = mid.z
        end
        local model = nil
        if self.WallLevelZ then
            -- the piece starts where the run currently stands and hands on its own rise
            p.z = self.WallLevelZ + climb
            local piece = pick(p.ground - p.z, last, room)
            if piece then
                model = piece.m
                climb = climb + (tonumber(piece.rise) or 0)
            end
        elseif not self.WallSnap then
            p.z = a.z + (b.z - a.z) * (d / L)
        end
        p.z = p.z + (self.WallUp or 0)
        table.insert(out, { pos = p, yaw = yaw, model = model })
    end

    for i = 0, n - 1 do place(c0 + pitch * (i + 0.5), i == n - 1, n - i) end

    if fill then
        place(L - c1 - step * 0.5, true, 1)     -- last piece ends exactly where b's does
    end
    self.WallClimb, self.WallLean = climb, lean
    return out
end

-- Where the run from a toward b actually stops: a whole number of segments along the
-- line. nil when not even one fits. This is what a corner marker snaps to, so walls
-- always touch the anchors without the spacing ever being stretched.
-- `allow` is what the pieces standing on this edge's two ends take out of it. A corner
-- mesh is not a whole number of tiles wide, so an edge snapped to n*step leaves the
-- tiling a remainder it cannot use, and the flush fill closes that with one more piece
-- laid nearly on top of its neighbour - a 9 m overlap on the walltool kit, which is the
-- whole tile. Snapping to allow + n*step instead makes the span an exact number of tiles,
-- the flush fill never fires, and a square drawn on this grid closes on itself.
-- `back` gives up that many whole tiles, for a caller trying several lengths of the same
-- edge. The refit needs it: the mark that makes an edge come out whole is not always the
-- furthest one out, because how far the walls step back for a mark depends on the turn
-- it makes and moving it can take the turn away altogether.
function mercenaries:WallEdgeEnd(a, b, allow, back)
    local dx, dy = b.x - a.x, b.y - a.y
    local L = math.sqrt(dx * dx + dy * dy)
    local step = segLen(self)
    allow = math.max(0, tonumber(allow) or 0)
    if L < allow then return nil end
    -- n = 0 is legal once there is an allowance: two corner pieces meeting with no
    -- straight between them is the shortest edge this kit can make, and refusing it
    -- would put the smallest square it can draw at 21 m a side instead of 9.
    local n = (L - allow < step) and 0 or segCount(L - allow, step)
    n = math.max(0, n - math.max(0, math.floor(tonumber(back) or 0)))
    if n == 0 and allow <= 0 then return nil end
    local d = n * step + allow
    local p = { x = a.x + (dx / L) * d, y = a.y + (dy / L) * d, z = a.z + (b.z - a.z) * (d / L) }
    if self.CampSnapToGround then p = self:CampSnapToGround(p) end
    return p
end

-- ==== decor ====
-- A wall type can carry a list of clutter - barrels, quivers, a scatter of stones -
-- modelled onto it in Blender and lifted off by assets/blender/export_wall.py. Baking it
-- into the mesh would put the same barrel in the same place every four metres, so the
-- pieces are spawned separately and only a FEW of them per segment.
--
-- Which few is decided by hashing the segment's own position, not by math.random: the
-- run has to come back identical after a rebuild or a save, and seeding the global RNG
-- to get that would reach into everything else that rolls a number.
mercenaries.WallDecor = mercenaries.WallDecor or {}

local function decorHash(x, y, i)
    local n = math.floor(x * 7919.0 + y * 104729.0 + i * 1299721.0)
    n = (n * 1103515245 + 12345) % 2147483648
    if n < 0 then n = -n end
    return n / 2147483648
end

function mercenaries:WallDecorList(name)
    if not name then return nil end
    if self.WallDecor[name] == nil then
        -- loaded by name the first time it is asked for, so adding a wall's clutter is
        -- dropping a generated file in beside the others
        pcall(function()
            Script.LoadScript("Scripts/mods/prefabs/wall_" .. name .. "_decor.lua")
        end)
        if self.WallDecor[name] == nil then self.WallDecor[name] = false end
    end
    return self.WallDecor[name] or nil
end

function mercenaries:WallSpawnDecor(wt, pos, yaw)
    local list = self:WallDecorList(wt and wt.decor)
    if not list or #list == 0 then return 0 end
    local want = math.min(tonumber(wt.decorCount) or 3, #list)

    -- rank every piece by its hash for this spot and take the best `want`: a stable
    -- subset with no RNG state and no repeats
    local order = {}
    for i = 1, #list do
        order[i] = { i = i, h = decorHash(pos.x, pos.y, i) }
    end
    table.sort(order, function(a, b) return a.h < b.h end)

    local c, s = math.cos(yaw), math.sin(yaw)
    local n = 0
    for k = 1, want do
        local p = list[order[k].i]
        local at = { x = pos.x + p.x * c - p.y * s,
                     y = pos.y + p.x * s + p.y * c,
                     z = pos.z + (p.z or 0) }
        local scale = p.s and { x = p.s, y = p.s, z = p.s } or nil
        local ok = pcall(function()
            self:SpawnHousePart(p.m, at, p.rx or 0, p.ry or 0, (p.rz or 0) + yaw,
                                scale, "MercWallDecor_", self.WallSegEnts)
        end)
        if ok then n = n + 1 end
    end
    return n
end


function mercenaries:WallBuildEdge(a, b, flush, cutA, cutB)
    local segs = self:WallEdgeSegments(a, b, flush, cutA, cutB)
    for _, s in ipairs(segs) do
        -- A tile the player has asked a way through is laid as the kit's ARCHWAY tile
        -- instead - same pitch, so the run does not change - and the leaves are hung in
        -- the opening. Everything else about the run carries on as if it were a plain
        -- piece, which is the point of using a tile for it.
        local gw = self.CastleGatewayFor and self:CastleGatewayFor(s.pos) or nil
        if gw then
            local rise = tonumber(gw.rise) or 0
            self:WallSpawnSegment({ x = s.pos.x, y = s.pos.y, z = s.pos.z + rise },
                                  s.yaw, gw.m)
            self:CastleGatewayHang(gw, s.pos, s.yaw)
        else
            self:WallSpawnSegment(s.pos, s.yaw, s.model)
        end
    end
    return #segs, segs
end

-- ==== the open ends ====
-- These walls are SHELLS: the kit's pieces have no geometry across their two end faces,
-- because in the levels they were cut for there is always another piece against them.
-- Where a run simply stops you therefore look straight through the stone into the grass
-- behind it. A lid closes each end that nothing else is standing against - a tower on the
-- end, or a ring that has no ends at all.
function mercenaries:WallSpawnCap(model, seg)
    if not (model and seg) then return nil end
    local ent
    pcall(function()
        ent = System.SpawnEntity({
            class = "BasicEntity",
            name = "MercWallCap_" .. tostring(math.random(100000, 999999)),
            position = seg.pos,
            properties = { object_Model = model, bMissionCritical = false,
                           bSaved_by_game = false, bSerialize = false },
        })
    end)
    if not ent then return nil end
    pcall(function() ent:SetAngles({ x = 0, y = 0, z = seg.yaw }) end)
    pcall(function() ent:SetViewDistUnlimited() end)
    pcall(function() ent:SetViewDistRatio(255) end)
    pcall(function() ent:SetLodRatio(255) end)
    pcall(function() ent:RenderShadow(true) end)
    table.insert(self.WallSegEnts, ent.id)
    return ent
end

-- Whether a corner piece or a tower already stands on vertex i, in which case the end
-- there is covered and needs no lid. Guarded: the castle module is optional.
function mercenaries:WallVertexHas(r, i)
    if not self.CastleVertexPlan then return false end
    local pl
    pcall(function() pl = self:CastleVertexPlan(r, i) end)
    return (pl and pl.m) and true or false
end

-- How much of the run the piece standing on vertex i of r takes up, 0 when nothing does.
-- `side` is "in" for the edge ARRIVING at the vertex and "out" for the one leaving it.
-- They differ: a corner mesh is not symmetric about its own turn, and the walltool's
-- 90-degree pieces eat 5.1 m of the edge they receive and only 3.9 m of the one they
-- hand on. Asking for one figure and using it both ways leaves a metre of daylight.
-- Guarded: the castle module is optional and a wall must still build without it.
function mercenaries:WallVertexCut(r, i, side)
    if not self.CastleVertexCut then return 0 end
    local cut = 0
    pcall(function() cut = tonumber(self:CastleVertexCut(r, i, side)) or 0 end)
    return cut
end

function mercenaries:WallClearSegments()
    for _, id in ipairs(self.WallSegEnts or {}) do pcall(function() System.RemoveEntity(id) end) end
    self.WallSegEnts = {}
    -- the blockers belong to the wall; they must not outlive it
    pcall(function() if self.NavObstBlockerClear then self:NavObstBlockerClear() end end)
    self.WallVaryIdx = 0
end

-- Pull every corner back onto a whole multiple of the CURRENT segment length. Corners
-- are snapped when they are marked, but changing the length (or the wall type) after
-- the fact leaves them off-multiple, so the last piece of each edge stops short and
-- the joint at that corner opens up. Walking the chain and re-fitting each corner to
-- its predecessor closes them again. Idempotent: once every edge is an exact multiple
-- a second pass moves nothing. A corner that ends up closer than one segment is
-- dropped, since no wall could reach it.
-- Refit every stretch, not just the one being drawn: changing the segment length or
-- the wall type after several are up would otherwise leave the finished ones
-- off-multiple, with their last piece short and their joints open.
function mercenaries:WallRefitCorners()
    -- The run being drawn, UNLESS it has been closed into a ring. A ring is fitted as a
    -- ring (WallFitClose) and refitting it as an open chain afterwards slides the very
    -- marks that were placed to bring the join home, which reopens it and can swing the
    -- last corner onto an angle nothing is cut for.
    local moved = self.WallClosed and 0
                  or self:WallRefitRun(self.WallMarks, self.WallFlushEnd)
    for _, r in ipairs(self.WallRuns or {}) do
        -- A CLOSED ring is left alone. Refitting walks the corners in order, and each
        -- correction moves the one after it, so a ring comes out of the pass a different
        -- shape than it went in - and its closing edge is never fitted at all, because
        -- there is no corner after the last one to fit it against. A ring that was laid
        -- exactly (merc_castle_square) would be pulled off the grid by the very pass
        -- meant to put it on the grid.
        if not r.closed then
            moved = moved + self:WallRefitRun(r.pts, r.flushEnd)
        end
    end
    return moved
end

-- `keepLast`: leave the final corner exactly where it is. A run closed by a gate ends on
-- the gate's edge, which is deliberately NOT a whole number of segments from the corner
-- before it - refitting it would pull it back to the last whole multiple (undoing the
-- flush fill and reopening the gap at the gate), or drop it outright when the gate sits
-- less than one segment away.
-- The allowance at a mark is CIRCULAR: how far the walls step back for it depends on
-- which bend piece its turn asks for, and the turn depends on where the mark ends up.
-- Fitting it with the allowance read off the run as it stood BEFORE anything moved is
-- what left edges off the grid - sliding a mark back swings the edge leaving it, which
-- can land the next turn on a different piece with a different arm. The tiler then found
-- a remainder and the fill covered it with a piece laid nearly on top of the corner:
-- the duplicate wall that grew on the far side of a multi-turn run.
--
-- Chasing that circle round - place, re-read the turn, place again - does not close it:
-- the two answers can simply swap for ever, and every attempt measured from the LAST one
-- rather than from the mark as it came in walks the run down to nothing in a few
-- rebuilds. So the arms are ENUMERATED instead. The type owns a handful of them; each is
-- tried, and one is only accepted if the mark it produces really does make the turn that
-- arm belongs to. That is an exact test, and the widest arm that passes it is the one
-- kept, since that is the mark nearest where the player aimed.
--
-- Every distance a mark might step back for, plus nothing at all.
function mercenaries:WallVertexCutChoices()
    local seen, out = { [0] = true }, { 0 }
    pcall(function()
        local wt = self.WallTypes[self.WallTypeIdx] or {}
        for _, c in ipairs(self:CastleCornerList(wt) or {}) do
            local v = tonumber(c.cutIn) or tonumber(c.cut) or 0
            if not seen[v] then seen[v] = true; out[#out + 1] = v end
        end
    end)
    return out
end

-- One walk of the chain. `orig` is the marks as they came in - every attempt measures to
-- those, never to the last attempt, or each try would shorten the edge again and a few
-- rebuilds would walk the run down to nothing. Returns the fitted list, how many marks
-- moved, and which of `orig` survived.
function mercenaries:WallRefitChain(orig, keepLast, was, closed)
    local m = orig
    local last = keepLast and m[#m] or nil
    local upto = last and (#m - 1) or #m
    local out, moved, dropped, keep = { m[1] }, 0, 0, { 1 }
    for i = 2, upto do
        -- The chain the cuts are read off: the marks already settled, then the ones
        -- still to come as they came in. Rebuilt here rather than patched, so a mark
        -- dropped for being too close cannot leave the indices one out for the rest of
        -- the run - which would read every remaining allowance off the wrong corner.
        local w, at = { pts = {}, closed = closed or false }, #out + 1
        for k = 1, #out do w.pts[k] = out[k] end
        for k = i, #m do w.pts[#w.pts + 1] = orig[k] end
        local prev = out[#out]
        -- Where this mark was reaching for, measured out along the bearing it was drawn
        -- on. The bearing is fixed; only how far down it the mark sits is up for refit.
        local want = orig[i]
        if want.bear and want.reach then
            want = { x = prev.x + math.cos(want.bear) * want.reach,
                     y = prev.y + math.sin(want.bear) * want.reach, z = want.z }
            w.pts[at] = want
        end
        -- What the mark BEFORE this one takes out of the edge is fixed: sliding this one
        -- along the ray it already lies on cannot change the turn behind it.
        local base = self:WallVertexCut(w, at - 1, "out")
        local step = segLen(self)
        local fitted, fitD, best, bestRest, bestD = nil, -1, nil, math.huge, -1
        local nxt = orig[i + 1]
        local function put(p)
            w.pts[at] = { x = p.x, y = p.y, z = p.z }
            -- The mark AFTER this one lies along its OWN bearing from wherever this one
            -- ends up, so the turn made here is the difference of two bearings and
            -- nothing else. Leaving it where it came in measures the turn along a line to
            -- a point that is about to move, and reads the wrong arm off it - which fits
            -- the edge to a 45-degree corner it then builds a 30-degree one on, and the
            -- tiler covers the leftover with a piece laid on top of its neighbour.
            if nxt and nxt.bear and nxt.reach and w.pts[at + 1] then
                w.pts[at + 1] = { x = p.x + math.cos(nxt.bear) * nxt.reach,
                                  y = p.y + math.sin(nxt.bear) * nxt.reach, z = nxt.z }
            end
        end
        for _, cin in ipairs(self:WallVertexCutChoices()) do
            -- Not just the furthest mark each arm allows: giving up a tile can be what
            -- takes the turn back below the angle a corner exists for, and that changes
            -- the arm again. The shorter fits are candidates in their own right.
            for back = 0, 2 do
                local cand = self:WallEdgeEnd(prev, want, base + cin, back)
                if cand then
                    put(cand)
                    local d = math.sqrt((cand.x - prev.x) ^ 2 + (cand.y - prev.y) ^ 2)
                    -- Scored on the cut the run will REALLY read here, never on the one
                    -- the candidate was built from: what has to come out whole is the
                    -- edge the tiler is about to lay. Whether the two agree is beside the
                    -- point - some turns have no arm that agrees with itself at all.
                    local span = d - base - self:WallVertexCut(w, at, "in")
                    local rest = (span < -0.02) and math.huge
                                 or (span - segCount(span, step) * step)
                    if rest < 0.02 then
                        if d > fitD then fitted, fitD = cand, d end
                    elseif rest < bestRest - 1e-6
                           or (rest < bestRest + 1e-6 and d > bestD) then
                        best, bestRest, bestD = cand, rest, d
                    end
                end
            end
        end
        fitted = fitted or best
        if fitted then
            put(fitted)
            local from = (was and was[i]) or m[i]
            local dx, dy = fitted.x - from.x, fitted.y - from.y
            if (dx * dx + dy * dy) > 1e-6 then moved = moved + 1 end
            fitted.ent, fitted.aim = m[i].ent, m[i].aim
            fitted.bear, fitted.reach = m[i].bear, m[i].reach
            fitted.spread = m[i].spread
            if fitted.ent then pcall(function() fitted.ent:SetPos({ x = fitted.x, y = fitted.y, z = fitted.z }) end) end
            table.insert(out, fitted)
            table.insert(keep, i)
        else
            if m[i].ent then pcall(function() System.RemoveEntity(m[i].ent.id) end) end
            dropped = dropped + 1
        end
    end
    if last then table.insert(out, last); table.insert(keep, #m) end
    return out, moved, dropped, keep
end

function mercenaries:WallRefitRun(marks, keepLast, closed)
    local m = marks
    if not m or #m < 2 then return 0 end
    -- Fit to where the player AIMED, not to where the mark currently sits. The fit can
    -- only ever shorten an edge, and how far it shortens depends on the arm the mark's
    -- turn asks for - which changes as the run grows past it. Measuring to the mark
    -- itself therefore ratchets: a corner pulled in while it was still the end of the run
    -- is pulled in again from there once a turn appears on it, and again on the next
    -- rebuild. A wall drawn 25 m long came out 6 m long that way. The aim never moves, so
    -- fitting to it lets a mark come back out again when its arm shrinks.
    local orig, was = {}, {}
    for i = 1, #m do
        local a = m[i].aim or m[i]
        orig[i] = { x = a.x, y = a.y, z = a.z, ent = m[i].ent, aim = m[i].aim,
                    bear = m[i].bear, reach = m[i].reach, spread = m[i].spread }
        was[i] = { x = m[i].x, y = m[i].y }
    end

    local out, moved, dropped = nil, 0, 0
    for _ = 1, 8 do
        local res, mv, dr, keep = self:WallRefitChain(orig, keepLast, was, closed)
        out, moved = res, mv
        if dr == 0 then break end
        dropped = dropped + dr
        -- A mark was dropped for being too close. The marks BEFORE the hole were fitted
        -- to a turn that is no longer there - the corner they stepped back for has gone
        -- and their edges are off the grid again - so the walk starts over on the
        -- shortened list. From the positions that CAME IN, not the ones just fitted, so
        -- restarting cannot shorten the run a second time.
        local left, kept = {}, {}
        for _, k in ipairs(keep) do
            left[#left + 1] = orig[k]
            kept[#kept + 1] = was[k]
        end
        orig, was = left, kept
        if #orig < 2 then break end
    end
    out = out or orig

    -- written back IN PLACE: the caller may be holding either WallMarks or a run's own
    -- point list, and reassigning a local would silently drop the refit for the latter
    for i = #m, 1, -1 do m[i] = nil end
    for i = 1, #out do m[i] = out[i] end
    if moved > 0 or dropped > 0 then
        System.LogAlways(string.format("[Wall] refit %d corner(s)%s", moved,
            (dropped > 0) and (", dropped " .. dropped .. " too close") or ""))
    end
    return moved
end

-- CORNER POSTS. Two straight segments meeting at a turn of theta leave a wedge on the
-- OUTER face roughly width*tan(theta/2) wide - so the sharper the corner the bigger
-- the gap, and no amount of tiling closes it. One extra piece dropped on the corner
-- and turned to the angle bisector bridges both faces. Off for a wall type with no
-- post mesh set (postModel nil = reuse the wall mesh itself).
mercenaries.WallPosts = false   -- reads better without them; merc_wall_posts 1 to try

function mercenaries:WallSpawnCornerPost(c, yaw)
    local t = wallType(self)
    local model = t.postModel or t.m
    local p = { x = c.x, y = c.y, z = c.z }
    if self.WallSnap and self.CampSnapToGround then p = self:CampSnapToGround(p) end
    p.z = p.z + (t.postUp or self.WallUp or 0)
    local saveM = t.m
    t.m = model                              -- WallSpawnSegment reads the type's mesh
    self:WallSpawnSegment(p, yaw)
    t.m = saveM
end

-- Bisector yaw at corner b between a->b and b->c.
local function cornerYaw(a, b, c)
    local d1x, d1y = b.x - a.x, b.y - a.y
    local d2x, d2y = c.x - b.x, c.y - b.y
    local l1 = math.sqrt(d1x * d1x + d1y * d1y)
    local l2 = math.sqrt(d2x * d2x + d2y * d2y)
    if l1 < 1e-6 or l2 < 1e-6 then return nil end
    local bx, by = d1x / l1 + d2x / l2, d1y / l1 + d2y / l2
    if (bx * bx + by * by) < 1e-9 then return math.atan2(d1y, d1x) end
    return math.atan2(by, bx)
end

function mercenaries:WallBuildCornerPosts()
    if not self.WallPosts then return 0 end
    local count = 0
    for _, r in ipairs(self:WallAllRuns()) do
        local m = r.pts
        if #m >= 3 then
            local n = #m
            local first, last = 2, n - 1
            if r.closed then first, last = 1, n end
            for i = first, last do
                local prev = m[(i - 2) % n + 1]
                local nxt  = m[i % n + 1]
                local yaw = cornerYaw(prev, m[i], nxt)
                if yaw then
                    self:WallSpawnCornerPost(m[i], yaw + math.rad(self.WallYawFix or 0))
                    count = count + 1
                end
            end
        end
    end
    return count
end

-- The climb and the lean belong to ONE run and must be cleared before another starts.
-- They live on `self` because WallEdgeSegments has to carry them from edge to edge, and
-- anything that calls the tiler outside a rebuild - the build-mode ghost, the nav lab -
-- would otherwise inherit whatever the last run left behind and start a wall part-way up
-- a slope it never climbed.
function mercenaries:WallClimbReset()
    self.WallClimb, self.WallLean = 0.0, 0
end

-- ==== one height for a whole run ====
--
-- A stone wall cannot bend. Snapping each 12 m piece to the ground under its own middle
-- stair-steps the run and tears the joints open, so a stone run is laid at ONE height and
-- the terrain is allowed to swallow the difference. Which height is the whole question:
--
--   * Start from the first piece's own ground, which is where the player began drawing.
--   * Keep it while that costs nothing much: no piece buried more than a third of its
--     visible height, and no piece left hanging in the air.
--   * Otherwise drop to the highest level at which nothing floats, which is the lowest
--     ground on the run plus the foundation the mesh carries below its origin. These
--     walls bury 2.5-4.9 m of footing, so that is a lot of slope absorbed before any
--     daylight shows underneath.
--
-- Returns nil for a wall that should keep following the ground - a palisade of separate
-- stakes has no joints to tear.
function mercenaries:WallRunLevel(r)
    local t = wallType(self)
    if not (self.WallLevel and t.castle and self.CampSnapToGround) then return nil end

    local saved, savedClimb, savedLean = self.WallLevelZ, self.WallClimb, self.WallLean
    self.WallLevelZ = nil
    self:WallClimbReset()
    local grounds = {}
    local m = r.pts
    local edges = {}
    for i = 1, #m - 1 do edges[#edges + 1] = { m[i], m[i + 1], i, i + 1 } end
    if r.closed and #m > 2 then edges[#edges + 1] = { m[#m], m[1], #m, 1 } end
    for _, e in ipairs(edges) do
        local cutA = self:WallVertexCut(r, e[3], "out")
        local cutB = self:WallVertexCut(r, e[4], "in")
        local gate = r.flushEnd and (e[4] == #m) or nil
        for _, s in ipairs(self:WallEdgeSegments(e[1], e[2], gate or "cover", cutA, cutB)) do
            grounds[#grounds + 1] = s.pos.ground or s.pos.z
        end
    end
    self.WallLevelZ, self.WallClimb, self.WallLean = saved, savedClimb, savedLean
    if #grounds == 0 then return nil end

    local lowest, highest = grounds[1], grounds[1]
    for _, g in ipairs(grounds) do
        if g < lowest  then lowest  = g end
        if g > highest then highest = g end
    end
    local first = grounds[1]
    -- A type with transition pieces WALKS the ground; levelling it would set the run
    -- off at a height the steps then spend themselves climbing back from. It starts
    -- where the first piece stands and steps from there.
    if t.slope then return first, "stepped", 0 end
    local up    = tonumber(self.WallUp) or 0
    local deep  = tonumber(t.deep) or 0.0
    -- A type sunk on purpose (the city walls drop 3 m) has that much less wall showing
    -- and that much more footing below ground, and both belong in the sums.
    local visible = math.max(0.5, (tonumber(t.tall) or 4.0) + up)

    local buried   = highest - first                  -- burial on TOP of the intended sink
    local floating = (first + up - deep) - lowest     -- worst daylight under a piece
    if buried <= visible / 3 and floating <= 0 then return first, "first", buried end
    -- the highest level at which the lowest piece's footing still just reaches its ground
    local raised = lowest + deep - up
    return raised, "raised", highest - raised
end

-- Re-render every edge from the marker list with the current parameters.
function mercenaries:WallRebuild()
    pcall(function() if self.WallTouched then self:WallTouched() end end)
    self:WallClearSegments()
    -- The gateway leaves hang in a tile of the wall, so they come down and go back up
    -- with it. Anything else in the gate list - a palisade gate the player hung - is
    -- theirs and stays where it is.
    pcall(function()
        for i = #(self.Gates or {}), 1, -1 do
            if self.Gates[i].tag == "gateway" then self:GateRemoveAt(i) end
        end
        if self.CastleGatewayReset then self:CastleGatewayReset() end
    end)
    self:WallRefitCorners()
    -- before anything is measured: a stone ring walked the wrong way round faces its
    -- battlements at its own courtyard and turns the way no corner piece is cut for
    pcall(function() if self.CastleFixWinding then self:CastleFixWinding() end end)
    local runs = self:WallAllRuns()
    if #runs == 0 then System.LogAlways("[Wall] mark at least two corners (merc_wall_mark)"); return end
    local total, corners = 0, 0
    local levelled = nil
    for _, r in ipairs(runs) do
        local m = r.pts
        corners = corners + #m
        local z, how, slack = self:WallRunLevel(r)
        self.WallLevelZ = z
        self:WallClimbReset()
        -- what the corner pieces stand on: the height the run has climbed to by the
        -- time it reaches each marker
        r.vertexZ = z and {} or nil
        if z then levelled = string.format("%s %.2fm, %.2fm buried at the worst piece",
                                           how, z, math.max(0, slack or 0)) end
        -- A corner is a whole number of segments from the last one, and a piece standing
        -- on either end of an edge takes exactly half a segment out of it - so an edge
        -- with a piece at BOTH ends still tiles exactly, and one with a piece at only
        -- one end is left half a segment short. That half is filled the way the run into
        -- a gate is: one more piece, laid to finish where the edge does. It overlaps its
        -- neighbour by a whole number of metres, so the merlons stay on their grid, and
        -- a hole in a stone wall is worth more than an overlap inside it.
        -- the first and last tiles the run lays, so its two open ends can be lidded
        local firstSeg, lastSeg = nil, nil
        local function edge(a, b, gate, cutA, cutB, isFirst, isLast)
            local n, segs = self:WallBuildEdge(a, b, gate or "cover", cutA, cutB)
            if segs and #segs > 0 then
                if isFirst and not firstSeg then firstSeg = segs[1] end
                if isLast then lastSeg = segs[#segs] end
            end
            return n
        end
        local function mark(i)
            if r.vertexZ then r.vertexZ[i] = (self.WallLevelZ or 0) + (self.WallClimb or 0) end
        end
        for i = 1, #m - 1 do
            mark(i)
            total = total + edge(m[i], m[i + 1],
                                 (m[i + 1].spread and "close")
                                 or (r.flushEnd and (i == #m - 1)),
                                 self:WallVertexCut(r, i, "out"),
                                 self:WallVertexCut(r, i + 1, "in"),
                                 i == 1, i == #m - 1)
        end
        mark(#m)
        if r.closed and #m > 2 then
            total = total + edge(m[#m], m[1], "close",
                                 self:WallVertexCut(r, #m, "out"),
                                 self:WallVertexCut(r, 1, "in"))
        end

        -- A ring has no ends; an open run has two, and each is a hole unless a tower is
        -- standing on it.
        local wt = wallType(self)
        if wt.cap and not r.closed then
            if firstSeg and not self:WallVertexHas(r, 1) then
                total = total + (self:WallSpawnCap(wt.cap.start, firstSeg) and 1 or 0)
            end
            if lastSeg and not self:WallVertexHas(r, #m) then
                total = total + (self:WallSpawnCap(wt.cap.finish, lastSeg) and 1 or 0)
            end
        end
    end
    total = total + self:WallBuildCornerPosts()
    pcall(function()
        if self.CastleBuildVertices then total = total + (self:CastleBuildVertices() or 0) end
    end)
    self.WallLevelZ = nil
    System.LogAlways(string.format("[Wall] %s: %d run(s), %d corners, %d segments (len %.2f, yaw+%d, up %.2f, lat %.2f)",
        wallType(self).n, #runs, corners, total,
        segLen(self), self.WallYawFix or 0, self.WallUp or 0, self.WallLat or 0))
    if levelled then System.LogAlways("[Wall] levelled: " .. levelled) end
    -- The segments carry AI.bUsedAsDynamicObstacle, but on their own that does NOTHING: the
    -- engine gathers obstacle candidates with a physics query whose mask is
    -- ent_rigid | ent_sleeping_rigid, and these pieces are PE_STATIC, so they are never even
    -- offered to it. What the engine can see is the invisible per-stretch RIGID blocker that
    -- NavObstBlockersBuild puts along the run - so it has to be rebuilt with the wall, or a
    -- freshly built palisade has no obstacle behind it until the next load.
    if self.NavObstCheckWalls then pcall(function() self:NavObstCheckWalls() end) end
    if self.NavObstBlockersBuild then pcall(function() self:NavObstBlockersBuild() end) end
end

function mercenaries:WallSpawnMarker(pos)
    if not self.WallMarkersVisible then return nil end
    local e
    pcall(function()
        e = System.SpawnEntity({
            class = "BasicEntity",
            name = "MercWallMark_" .. tostring(math.random(100000, 999999)),
            position = pos,
            properties = { object_Model = self.WallMarkerModel, bMissionCritical = false,
                           bSaved_by_game = false, bSerialize = false },
        })
    end)
    if e then pcall(function() e:SetViewDistUnlimited() end) end
    return e
end

-- Marks where the run started: a stake at the first corner, tall enough to spot from
-- across the camp. Cleared when the wall is finished (EndWallBuild) or wiped.
mercenaries.WallStartMarkerModel = "objects/manmade/structures/defensive/walls/palisade/palisade_wall_single_sharp.cgf"
mercenaries.WallStartMarkerEnt = nil

function mercenaries:WallSpawnStartMarker(pos)
    self:WallClearStartMarker()
    local e
    pcall(function()
        e = System.SpawnEntity({
            class = "BasicEntity",
            name = "MercWallStart_" .. tostring(math.random(100000, 999999)),
            position = pos,
            properties = { object_Model = self.WallStartMarkerModel, bMissionCritical = false,
                           bSaved_by_game = false, bSerialize = false },
        })
    end)
    if e then
        pcall(function() e:SetViewDistUnlimited() end)
        pcall(function() e:SetViewDistRatio(255) end)
        self.WallStartMarkerEnt = e.id
    end
    Game.SendInfoText('merc_info_wall_start', false, 0, 3)
end

function mercenaries:WallClearStartMarker()
    if self.WallStartMarkerEnt then
        pcall(function() System.RemoveEntity(self.WallStartMarkerEnt) end)
        self.WallStartMarkerEnt = nil
    end
end

-- Show/hide the corner barrels (off by default).
function mercenaries:WallSetMarkers(v)
    self.WallMarkersVisible = (tonumber(v) == 1)
    for _, mk in ipairs(self.WallMarks or {}) do
        if mk.ent then pcall(function() System.RemoveEntity(mk.ent.id) end); mk.ent = nil end
        if self.WallMarkersVisible then mk.ent = self:WallSpawnMarker(mk) end
    end
    System.LogAlways("[Wall] corner markers " .. (self.WallMarkersVisible and "shown" or "hidden"))
end

-- ==== ANGLE SNAP ====
-- A CASTLE is not drawn freehand, and a PALISADE is nothing but. The difference is the
-- kit: stone turns only where a corner piece exists for the turn, so every edge after the
-- first is pulled onto a multiple of WallSnapAngle from the direction the FIRST edge was
-- drawn in. The run keeps one orientation the player chose, every corner is a turn the
-- kit owns, and a square corner tower sits flush because at a right angle both walls meet
-- a FACE of it rather than one of its corners. The base direction is the first edge's, so
-- a castle can still be laid out at any angle to the world - it just has to stay
-- consistent with itself after that.
--
-- Stakes have none of those problems. A palisade panel is 2.75 m and meets its neighbour
-- at whatever angle you like, with a corner post to hide the joint, so there is nothing
-- for a snap to protect and it only gets in the way of drawing the line you want. The
-- default is therefore FREEHAND, and a type earns its snapping by owning corner pieces
-- (CastleSnapAngleFor reads the turns its kit actually has).
mercenaries.WallSnapAngle = 0       -- degrees; 0 is freehand
mercenaries.WallSnapAngleDefault = 0    -- what a type with no corners of its own gets
mercenaries.WallBaseYaw   = nil     -- set by the first edge of the run being drawn

function mercenaries:WallRunBaseYaw()
    if self.WallBaseYaw then return self.WallBaseYaw end
    local m = self.WallMarks or {}
    if #m >= 2 then
        return math.atan2(m[2].y - m[1].y, m[2].x - m[1].x)
    end
    return nil
end

-- Pull `pos` onto the nearest allowed ray out of `from`. Keeps the distance the player
-- aimed at, so only the direction is corrected.
function mercenaries:WallSnapAim(from, pos)
    local step = math.rad(tonumber(self.WallSnapAngle) or 0)
    if step <= 0 or not from or not pos then return pos end
    local base = self:WallRunBaseYaw()
    if not base then return pos end          -- the first edge sets the orientation
    local dx, dy = pos.x - from.x, pos.y - from.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 1e-3 then return pos end
    local ang = math.atan2(dy, dx)
    local k = math.floor((ang - base) / step + 0.5)
    local snapped = base + k * step
    local out = { x = from.x + math.cos(snapped) * d,
                  y = from.y + math.sin(snapped) * d, z = pos.z }
    if self.CampSnapToGround then out = self:CampSnapToGround(out) end
    return out
end

function mercenaries:WallSetSnapAngle(v)
    self.WallSnapAngle = tonumber(v) or 0
    System.LogAlways(string.format("[Wall] corner angles snap to %d degrees%s",
        self.WallSnapAngle, (self.WallSnapAngle <= 0) and " (off - freehand)" or ""))
end

-- Mark a corner where you are looking; the edge from the previous corner fills in.
-- The corner SNAPS to the end of the last whole segment rather than sitting at the
-- raw cursor, so the wall touches it and the next edge carries on from there with the
-- spacing unchanged. Anything the cursor was reaching past that is cut off.
function mercenaries:WallMark()
    local pos = self:TowerLookedAtPos()
    if not pos then Game.SendInfoText('merc_info_tower_aim', false, 0, 3); return end
    if self.CampSnapToGround then pos = self:CampSnapToGround(pos) end
    pos = self:WallSnapAim(self.WallMarks[#self.WallMarks], pos)

    -- Standing at another palisade: this click hangs a GATE and leaves the run alone.
    -- No charge - the stretch was paid for, and the gate is how it is finished. The
    -- quartermaster's gate purchase is for adding one to a camp that is already built.
    -- ...but only when a run is actually being DRAWN. Reported 2.3: buying a second stretch
    -- and clicking the first corner while stood at the existing palisade hung a gate and
    -- ended the build on that very click ("gate hung, palisade finished"), because the snap
    -- was tested before there was anything to finish. The first corner of a new run is
    -- always just a corner.
    local snap = (#self.WallMarks > 0) and self:WallGateSnapAt(pos) or nil
    if snap then
        if (self:GateCount() or 0) >= self.GateMax then
            Game.SendInfoText('merc_info_gate_limit', false, 0, 4)
            System.LogAlways("[Wall] gate limit reached - not hanging another")
            return
        end

        -- Matches the preview exactly: the run is carried to the gate's outer edge and
        -- that last edge is filled flush, so wall - gate - wall touches all the way.
        local prev = self.WallMarks[#self.WallMarks]
        if prev then
            local corner = { x = snap.far.x, y = snap.far.y, z = snap.far.z }
            corner.ent = self:WallSpawnMarker(corner)
            table.insert(self.WallMarks, corner)
            self.WallFlushEnd = true
        end

        self:WallGateGhostOff()
        self:GateBuild({ x = snap.x, y = snap.y, z = snap.z }, snap.yaw, false)
        -- Hanging the gate COMPLETES the wall: the gate is the way through, so there is
        -- nothing left to draw and build mode ends here. Right-clicking before reaching a
        -- palisade is the other way to finish, and leaves the stretch open with no gate.
        self:EndWallBuild(true)
        Game.SendInfoText('merc_info_wall_gate_done', false, 0, 4)
        System.LogAlways(string.format(
            "[Wall] gate snapped to the palisade (%.1fm away, %.2fm clearance, %.1fm long)",
            snap.dist or 0, self.GateWallDist or 0, self:GateWidth()))
        return
    end

    -- Back at the corner the run started from: this click CLOSES the ring rather than
    -- marking another corner. A camp wants a wall the whole way round, and bringing the
    -- run home is how you ask for one.
    if self:WallCloseSnapAt(pos) then
        self:WallCloseRing()
        self:EndWallBuild(true)
        Game.SendInfoText('merc_info_wall_done', false, 0, 3)
        return
    end

    local prev = self.WallMarks[#self.WallMarks]
    if prev then
        -- The cut this edge LEAVES is known - it depends on marks already down. The one
        -- it arrives at is not, because the piece standing there depends on a mark the
        -- player has not placed yet, so assume the corner they are most likely drawing:
        -- with 90-degree snapping, a 90-degree corner.
        local allow = 0
        pcall(function()
            local mk, n = self.WallMarks, #self.WallMarks
            local r = (n >= 2) and { pts = { mk[n - 1], prev, pos } } or { pts = { prev, pos } }
            allow = (tonumber(self:CastleVertexCut(r, (n >= 2) and 2 or 1, "out")) or 0)
            local c = self:CastleCornerFor(90, wallType(self))
            if c then allow = allow + (tonumber(c.cutIn) or tonumber(c.cut) or 0) end
        end)
        local fitted = self:WallEdgeEnd(prev, pos, allow)
        if not fitted then
            System.LogAlways("[Wall] too close to the last corner for a segment")
            return
        end
        -- Kept for the refit: the BEARING this edge was drawn on and how far along it the
        -- player reached. The corner lands on the tile grid, short of where it was aimed,
        -- and how short depends on the arm its turn will ask for - a turn that does not
        -- exist yet, because the mark after it has not been placed. The refit therefore
        -- has to move it again later, and it must slide it along this same bearing: the
        -- bearing is what WallSnapAim put on the type's turn grid, and a mark refitted
        -- towards a fixed world point instead drifts off that grid as its predecessor
        -- moves, leaving a turn of 40 degrees wearing a 45-degree bend and a wedge of
        -- daylight where the two should meet.
        fitted.bear = math.atan2(pos.y - prev.y, pos.x - prev.x)
        fitted.reach = math.sqrt((pos.x - prev.x) ^ 2 + (pos.y - prev.y) ^ 2)
        fitted.aim = { x = pos.x, y = pos.y, z = pos.z }
        pos = fitted
    end

    -- Always leave a gateway. A ring closed right up has no way in, and the staged
    -- battle then has no gap to muster at, so a corner may not come within
    -- WallGateMin of where the run began.
    local first = self.WallMarks[1]
    if first then
        local dx, dy = pos.x - first.x, pos.y - first.y
        if (dx * dx + dy * dy) < (self.WallGateMin * self.WallGateMin) then
            Game.SendInfoText('merc_info_wall_gate', false, 0, 4)
            System.LogAlways(string.format("[Wall] too close to the start - leave a %.0fm gate", self.WallGateMin))
            return
        end
    end

    local mk = { x = pos.x, y = pos.y, z = pos.z, aim = pos.aim,
                 bear = pos.bear, reach = pos.reach }
    mk.ent = self:WallSpawnMarker(mk)
    table.insert(self.WallMarks, mk)
    -- The first corner has no wall attached to it yet, so without this there is nothing
    -- on screen to show where the run began (or where to close the ring back to). The
    -- marker stands until the wall is finished or cleared.
    if not prev then self:WallSpawnStartMarker(mk) end
    pcall(function() if self.WallTouched then self:WallTouched() end end)
    -- Marking this corner turns the one before it from the end of the run into a TURN,
    -- which changes what stands on it and how far the walls either side step back for
    -- it. Once anything does, the run is rebuilt rather than just extended.
    local active = false
    pcall(function() active = (self.CastleVertexActive and self:CastleVertexActive()) or false end)
    if active then
        self:WallRebuild()
    elseif prev then
        self:WallBuildEdge(prev, mk)
    end
    -- the corner just became interior (it now has a wall either side), so post it
    local m = self.WallMarks
    if not active and self.WallPosts and #m >= 3 then
        local yaw = cornerYaw(m[#m - 2], m[#m - 1], m[#m])
        if yaw then self:WallSpawnCornerPost(m[#m - 1], yaw + math.rad(self.WallYawFix or 0)) end
    end
    System.LogAlways("[Wall] corner " .. #self.WallMarks .. " marked")
end

-- ==== closing the ring ====
-- A camp wants a wall all the way round, and the way to ask for that is to bring the run
-- back to where it started. Within this of the first corner the aim snaps onto it and the
-- next click CLOSES rather than marking - scaled off the tile, so it is about a piece and
-- a half whatever the wall type.
mercenaries.WallCloseSnap = nil          -- nil = 1.5 tiles; merc_wall_close_snap to override

function mercenaries:WallCloseDist()
    return tonumber(self.WallCloseSnap) or (segLen(self) * 1.5)
end

-- The first corner, when the aim is close enough to it to be asking for a ring.
function mercenaries:WallCloseSnapAt(pos)
    local m = self.WallMarks or {}
    if not pos or #m < 3 then return nil end
    local d = self:WallCloseDist()
    local dx, dy = pos.x - m[1].x, pos.y - m[1].y
    if (dx * dx + dy * dy) > d * d then return nil end
    return m[1]
end

-- Closing is OVER-CONSTRAINED. Every edge has to be a whole number of tiles plus the arms
-- standing on its two ends, and the join also has to land exactly on the corner the run
-- started from; nothing satisfies both in general. So the two marks before the join are
-- searched over the lengths their own bearings allow - the shape the player drew is kept,
-- only how far each of those two edges runs is chosen - and the pair leaving the join
-- nearest a whole number of tiles wins. Whatever is left is shared out across the join's
-- joints by WallEdgeSegments.
-- How many of the marks before the join the search may slide, and how far the last one's
-- bearing may swing. Three lengths and a few bearings is what it takes to bring a
-- freehand hexagon home; two lengths alone left metres of it over.
local CLOSE_MARKS = 3
local CLOSE_BEAR = 1
local CLOSE_TOL = 0.05

-- What a joint on this edge will actually open by once WallEdgeSegments shares the
-- leftover out along it: the pieces go down at span/k instead of a tile apart, so every
-- joint is off by that much. Counting the raw remainder instead flatters a short edge -
-- one that fits no whole tile at all has no joints to share anything between, and a
-- remainder of 6 m there reads as 6 m of daylight, not as a rounding error.
local function joinErr(span, step)
    if span < 0.15 then return 0.0 end
    local t = segCount(span, step)
    return math.min(math.abs(span / math.max(1, t) - step),
                    math.abs(span / (t + 1) - step))
end

function mercenaries:WallFitClose(m)
    local seam, square = self:WallFitCloseOnce(m)
    if seam and square and seam <= CLOSE_TOL then return seam end

    -- Still not home. One edge cannot be made to land on a corner it does not point at,
    -- however its length is chosen - so give the join TWO edges by dropping an EXTRA
    -- CORNER into it. That is a second bearing to play with, which is the freedom the join
    -- was missing, and it reads as part of the wall because it is one. The whole ring is
    -- then fitted again around the new shape, which is what puts the edges either side of
    -- it back on the grid.
    local saved = {}
    for i = 1, #m do
        saved[i] = { x = m[i].x, y = m[i].y, z = m[i].z, bear = m[i].bear,
                     reach = m[i].reach, ent = m[i].ent }
    end
    local added = self:WallFitCloseCorner(m)
    if added and (not seam or added < seam - 0.005)
       and self:WallRingFaults(m) == 0 then return added end
    -- the extra corner did not earn its place: put the shape back as it was
    for i = #m, 1, -1 do m[i] = nil end
    for i = 1, #saved do
        m[i] = saved[i]
        if m[i].ent then
            local q = m[i]
            pcall(function() q.ent:SetPos({ x = q.x, y = q.y, z = q.z }) end)
        end
    end
    return seam
end

function mercenaries:WallFitCloseOnce(m)
    if #m < 3 then return nil end
    -- Closing turns the run's START into a turn: the corner it began at now has arms, and
    -- the two edges either side of it were fitted back when it had none. So the whole
    -- chain is refitted as a RING first - every edge back onto the grid with the closed
    -- allowances - and only then is the join searched for.
    -- Three times, not once: on a ring the arms at the START depend on the turn it makes,
    -- which depends on where the LAST mark ends up - a circle that runs the whole way
    -- round, so one forward walk fits the first edge against a last mark it has not placed
    -- yet. Each pass measures from the bearings the player drew, never from the pass
    -- before, so this settles rather than creeping.
    for _ = 1, 3 do self:WallRefitRun(m, nil, true) end
    local n = #m
    if n < 3 then return nil end

    local step = segLen(self)
    local choices = self:WallVertexCutChoices()
    local snap = math.rad(tonumber(self.WallSnapAngle) or 0)
    local first = math.max(2, n - CLOSE_MARKS + 1)
    local base = {}
    for k = 1, n do base[k] = m[k] end

    local function dist(a, b)
        return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
    end

    -- How far the run bends at a vertex, in degrees; the same sum CastleVertexPlan makes.
    local function turnAt(i)
        local a, b, c = base[(i - 2) % n + 1], base[i], base[i % n + 1]
        local t = math.deg(math.atan2(c.y - b.y, c.x - b.x)
                           - math.atan2(b.y - a.y, b.x - a.x))
        while t <= -180 do t = t + 360 end
        while t > 180 do t = t - 360 end
        return t
    end

    -- Every place mark i can sit: along its own bearing (or one a step or two off it), at
    -- the lengths the tile grid leaves once both ends of its edge have taken their arms.
    local function spots(i, swing)
        local prev, mk = base[i - 1], m[i]
        if not (mk.bear and mk.reach) then return { mk } end
        local ring = { pts = base, closed = true }
        local out, seen = {}, {}
        for k = -swing, swing do
            local bear = mk.bear + k * snap
            local want = { x = prev.x + math.cos(bear) * mk.reach,
                           y = prev.y + math.sin(bear) * mk.reach, z = mk.z }
            -- the arm behind this mark, read with the edge pointing where it now points
            base[i] = want
            local outCut = self:WallVertexCut(ring, i - 1, "out")
            for _, cin in ipairs(choices) do
                for back = 0, 3 do
                    local c = self:WallEdgeEnd(prev, want, outCut + cin, back)
                    if c then
                        local key = string.format("%.2f:%.2f", c.x, c.y)
                        if not seen[key] then
                            seen[key] = true
                            c.bear, c.reach = bear, mk.reach
                            out[#out + 1] = c
                        end
                    end
                end
            end
        end
        base[i] = mk
        return out
    end

    local best, bestRest, bestPull, bestOk = nil, math.huge, math.huge, false

    local function score()
        local ring = { pts = base, closed = true }
        -- Every turn the search moved has to be one the kit is cut for. Swinging a
        -- bearing to bring the join home is free only while it does not leave a corner
        -- the wall bends through with nothing standing on it - a wedge of daylight is
        -- worse than a seam.
        for k = first - 2, n + 1 do
            local i = (k - 1) % n + 1
            if math.abs(turnAt(i)) >= 8 and not self:WallVertexHas(ring, i) then return end
        end
        -- Every edge whose allowance the search can move still has to tile: the ones it
        -- moved, and the FIRST one - closing gives the mark the run started from arms it
        -- never had while the run was open, and the edge leaving it has to step back for
        -- them like any other.
        local function tiles(k)
            local span = dist(base[k - 1], base[k])
                       - self:WallVertexCut(ring, k - 1, "out")
                       - self:WallVertexCut(ring, k, "in")
            if span < -0.02 then return false end
            local r = span - segCount(span, step) * step
            return not (r > 0.05 and r < step - 0.05)
        end
        if not tiles(2) then return end
        for k = first, n do
            if not tiles(k) then return end
        end
        local allow = self:WallVertexCut(ring, n, "out") + self:WallVertexCut(ring, 1, "in")
        local span = dist(base[n], base[1]) - allow
        if span < -0.02 then return end
        local rest = joinErr(span, step)
        local pull = 0
        for k = first, n do pull = pull + dist(base[k], m[k]) end
        -- Closing perfectly is not worth any price. Once the join is within a few
        -- centimetres it is as closed as the spread can make it, so among those the one
        -- that drags the run least off what was drawn wins - otherwise the search happily
        -- shortens a 40 m side to 12 m for the sake of another centimetre.
        local square = self:WallTurnError(base, n) < 1.5
                      and self:WallTurnError(base, 1) < 1.5
        local good, wasGood = (rest < CLOSE_TOL and square), bestRest < CLOSE_TOL and bestOk
        local better
        if good and wasGood then better = pull < bestPull - 0.01
        elseif good ~= wasGood then better = good
        else better = (rest < bestRest - 0.01)
                      or (rest < bestRest + 0.01 and pull < bestPull) end
        if better then
            best = {}
            for k = first, n do
                best[k] = { x = base[k].x, y = base[k].y, z = base[k].z,
                            bear = base[k].bear, reach = base[k].reach }
            end
            bestRest, bestPull, bestOk = rest, pull, square
        end
    end

    -- NOT pruned as we walk. Rejecting a mark the moment its own edge fails to tile is
    -- five times quicker, and it was tried: it also throws away branches that come good
    -- once the marks after them move, and the join it settles for is a third worse. A
    -- close is one deliberate click per wall, so the quarter-second is the cheaper of the
    -- two.
    local function walk(i)
        if i > n then return score() end
        for _, c in ipairs(spots(i, (i == n) and CLOSE_BEAR or 0)) do
            base[i] = c
            walk(i + 1)
        end
        base[i] = m[i]
    end
    walk(first)

    local function apply(chosen)
        for k = first, n do
            local mk, c = m[k], chosen[k]
            mk.x, mk.y, mk.z = c.x, c.y, c.z
            mk.bear, mk.reach = c.bear, c.reach
            if mk.ent then pcall(function() mk.ent:SetPos({ x = mk.x, y = mk.y, z = mk.z }) end) end
        end
    end

    -- Not home. One edge cannot be made to land on a corner it does not point at, however
    -- its length is chosen - so give the join TWO edges by dropping an EXTRA CORNER into
    -- it. That is a second bearing to play with, which is the degree of freedom the join
    -- was missing, and the corner reads as part of the wall because it is one.
    if not best then return nil end
    apply(best)
    return bestRest, bestOk
end

-- Every place mark i can sit: along its own bearing, at the lengths the tile grid leaves
-- once both ends of its edge have taken their arms. `prev` stands in for the mark before
-- it, which the caller may already have moved.
function mercenaries:WallFitCloseSpots(m, i, prev, swing)
    prev = prev or m[i - 1]
    local mk = m[i]
    if not (mk.bear and mk.reach) then return { mk } end
    local snap = math.rad(tonumber(self.WallSnapAngle) or 0)
    local ring = { pts = {}, closed = true }
    for k = 1, #m do ring.pts[k] = m[k] end
    ring.pts[i - 1] = prev
    local out, seen = {}, {}
    for k = -(swing or 0), (swing or 0) do
        local bear = mk.bear + k * snap
        local want = { x = prev.x + math.cos(bear) * mk.reach,
                       y = prev.y + math.sin(bear) * mk.reach, z = mk.z }
        ring.pts[i] = want
        -- sliding a mark along its own bearing cannot change the turn behind it, so the
        -- arm there is read once and serves every length
        local outCut = self:WallVertexCut(ring, i - 1, "out")
        for _, cin in ipairs(self:WallVertexCutChoices()) do
            for back = 0, 3 do
                local c = self:WallEdgeEnd(prev, want, outCut + cin, back)
                if c then
                    local key = string.format("%.2f:%.2f", c.x, c.y)
                    if not seen[key] then
                        seen[key] = true
                        c.bear, c.reach = bear, mk.reach
                        out[#out + 1] = c
                    end
                end
            end
        end
    end
    ring.pts[i] = mk
    return out
end

-- Close the join with an extra corner in it. The last two marks still slide along their
-- own bearings; on top of that the two halves of the join each take a bearing off the
-- turn grid, and where they cross is where the new corner goes. Both halves then have to
-- tile, and every turn the shape now makes has to be one the kit is cut for.
function mercenaries:WallFitCloseCorner(m)
    local n = #m
    if n < 3 then return nil end
    local step = segLen(self)
    local snap = math.rad(tonumber(self.WallSnapAngle) or 15)
    if snap <= 0 then return nil end
    -- only as far round as the kit actually has a piece: past its sharpest corner every
    -- bearing is rejected anyway, and searching to 180 degrees either way was four times
    -- the work for nothing
    local sharp = 0
    pcall(function()
        for _, c in ipairs(self:CastleCornerList(self.WallTypes[self.WallTypeIdx]) or {}) do
            sharp = math.max(sharp, math.abs(tonumber(c.turn) or 0))
        end
    end)
    if sharp <= 0 then return nil end
    local span = math.floor(math.rad(sharp) / snap + 1e-6)
    local firstBear = math.atan2(m[2].y - m[1].y, m[2].x - m[1].x)

    -- Whether an edge comes out a whole number of tiles, which every edge but the join's
    -- own two halves has to.
    local function onGrid(sp)
        if sp < -0.02 then return false end
        local r = sp - segCount(sp, step) * step
        return not (r > 0.05 and r < step - 0.05)
    end

    local ring = { pts = {}, closed = true }
    for k = 1, n do ring.pts[k] = m[k] end
    local in2 = self:WallVertexCut(ring, 2, "in")    -- the turn at mark 2 never moves
    local L12 = math.sqrt((m[2].x - m[1].x) ^ 2 + (m[2].y - m[1].y) ^ 2)

    local best, bestScore, bestPull = nil, math.huge, math.huge
    -- both marks before the join may also swing a step, which is what gets an odd
    -- hexagon home when three lengths alone cannot
    local A = self:WallFitCloseSpots(m, n - 1, nil, 1)
    local B = nil
    for _, a in ipairs(A) do
        B = self:WallFitCloseSpots(m, n, a, 1)
        ring.pts[n - 1] = a
        for _, b in ipairs(B) do
            ring.pts[n] = b
            -- what the mark before the join takes out of the edge running into it; the
            -- bearings either side of it are fixed, so this holds for every th1 below
            local outN1 = self:WallVertexCut(ring, n - 1, "out")
            local dAB = math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
            local dx, dy = m[1].x - b.x, m[1].y - b.y
            -- Sliding the mark before the join also decides what the edge ARRIVING there
            -- steps back for, and that edge is already built. Candidates are offered for
            -- every arm the type owns, so most of them do not actually fit it.
            local prev2 = m[n - 2] or m[1]
            local fits = onGrid(math.sqrt((a.x - prev2.x) ^ 2 + (a.y - prev2.y) ^ 2)
                                - self:WallVertexCut(ring, (n - 3) % n + 1, "out")
                                - self:WallVertexCut(ring, n - 1, "in"))
            if fits then
            for k1 = -span, span do
                local th1 = (b.bear or 0) + k1 * snap
                local outN = self:WallCutForTurn(math.deg(k1 * snap), "out")
                local inN = self:WallCutForTurn(math.deg(k1 * snap), "in")
                -- Turning the join out of this mark changes what the edge ARRIVING at it
                -- has to step back for, and that edge is already built. If it no longer
                -- tiles, this bearing is not available however well the join would land.
                if outN and inN and onGrid(dAB - outN1 - inN) then
                    local u1x, u1y = math.cos(th1), math.sin(th1)
                    for k2 = -span, span do
                        local th2 = th1 + k2 * snap
                        local inX = self:WallCutForTurn(math.deg(k2 * snap), "in")
                        local outX = self:WallCutForTurn(math.deg(k2 * snap), "out")
                        local turn1 = math.deg(firstBear - th2)
                        while turn1 <= -180 do turn1 = turn1 + 360 end
                        while turn1 > 180 do turn1 = turn1 - 360 end
                        local in1 = self:WallCutForTurn(turn1, "in")
                        local out1 = self:WallCutForTurn(turn1, "out")
                        -- and the same at the other end: the run's FIRST edge has to step
                        -- back for the corner the join now makes there
                        if inX and outX and in1 and out1
                           and onGrid(L12 - out1 - in2) then
                            local u2x, u2y = math.cos(th2), math.sin(th2)
                            local det = u1x * u2y - u1y * u2x
                            if math.abs(det) > 1e-4 then
                                local L1 = (dx * u2y - dy * u2x) / det
                                local L2 = (u1x * dy - u1y * dx) / det
                                local s1, s2 = L1 - outN - inX, L2 - outX - in1
                                if L1 > 0.1 and L2 > 0.1 and s1 > -0.02 and s2 > -0.02 then
                                    local sc = math.max(joinErr(s1, step),
                                                        joinErr(s2, step))
                                    local pull = math.abs(a.x - m[n - 1].x)
                                               + math.abs(a.y - m[n - 1].y)
                                               + math.abs(b.x - m[n].x)
                                               + math.abs(b.y - m[n].y)
                                    if sc < bestScore - 0.005
                                       or (sc < bestScore + 0.005 and pull < bestPull) then
                                        local X = { x = b.x + u1x * L1, y = b.y + u1y * L1,
                                                    z = b.z, bear = th1, reach = L1 }
                                        best = { a = a, b = b, score = sc, x = X.x,
                                                 y = X.y, z = X.z, bear = th1, reach = L1 }
                                        bestScore, bestPull = sc, pull
                                    end
                                end
                            end
                        end
                    end
                end
            end
            end
        end
    end
    if not best then return nil end

    local function put(mk, c)
        mk.x, mk.y, mk.z = c.x, c.y, c.z
        mk.bear, mk.reach = c.bear, c.reach
        if mk.ent then pcall(function() mk.ent:SetPos({ x = mk.x, y = mk.y, z = mk.z }) end) end
    end
    put(m[n - 1], best.a)
    put(m[n], best.b)
    table.insert(m, { x = best.x, y = best.y, z = best.z, bear = best.bear,
                      reach = best.reach, spread = true })
    System.LogAlways(string.format("[Wall] a corner was added to close the ring (%.0f deg)",
                                   math.deg(best.bear - (best.b.bear or 0))))
    return bestScore
end

-- Is the ring this candidate makes actually buildable? Every turn has to be one the kit
-- is cut for, no two arms may reach through each other, and every edge has to tile - bar
-- the join's own two halves, which are allowed a remainder because it gets shared out
-- along them.
function mercenaries:WallRingOK(m, a, b, X, n)
    local step = segLen(self)
    local pts = {}
    for k = 1, n do pts[k] = m[k] end
    pts[n - 1], pts[n], pts[n + 1] = a, b, X
    local N = n + 1
    local ring = { pts = pts, closed = true }
    for i = 1, N do
        local p, q = pts[(i - 2) % N + 1], pts[i % N + 1]
        local t = math.deg(math.atan2(q.y - pts[i].y, q.x - pts[i].x)
                           - math.atan2(pts[i].y - p.y, pts[i].x - p.x))
        while t <= -180 do t = t + 360 end
        while t > 180 do t = t - 360 end
        if math.abs(t) >= 8 and not self:WallVertexHas(ring, i) then return false end
        local span = math.sqrt((pts[i].x - p.x) ^ 2 + (pts[i].y - p.y) ^ 2)
                   - self:WallVertexCut(ring, (i - 2) % N + 1, "out")
                   - self:WallVertexCut(ring, i, "in")
        if span < -0.02 then return false end
        if i ~= N and i ~= 1 then                 -- not one of the join's two halves
            local r = span - segCount(span, step) * step
            if r > 0.05 and r < step - 0.05 then return false end
        end
    end
    return true
end

-- How many edges of the ring do not tile, how many turns have nothing cut for them, and
-- how many corner arms reach through each other. `halves` says how many edges at the end
-- of the list are the join's own, which are allowed a remainder because the spread shares
-- it out along them.
function mercenaries:WallRingFaults(m)
    -- an added corner makes the join two edges, and both of them spread
    local halves = (m[#m] and m[#m].spread) and 2 or 1
    local step = segLen(self)
    local N = #m
    if N < 3 then return 99 end
    local ring = { pts = m, closed = true }
    local bad = 0
    for i = 1, N do
        local pi = (i - 2) % N + 1
        local p, q = m[pi], m[i % N + 1]
        local t = math.deg(math.atan2(q.y - m[i].y, q.x - m[i].x)
                           - math.atan2(m[i].y - p.y, m[i].x - p.x))
        while t <= -180 do t = t + 360 end
        while t > 180 do t = t - 360 end
        if math.abs(t) >= 8 and not self:WallVertexHas(ring, i) then bad = bad + 1 end
        if self:WallTurnError(m, i) > 1.5 then bad = bad + 1 end
        local span = math.sqrt((m[i].x - p.x) ^ 2 + (m[i].y - p.y) ^ 2)
                   - self:WallVertexCut(ring, pi, "out") - self:WallVertexCut(ring, i, "in")
        if span < -0.02 then
            bad = bad + 1
        elseif not (i == 1 or halves > 1 and i == N) then
            local r = span - segCount(span, step) * step
            if r > 0.05 and r < step - 0.05 then bad = bad + 1 end
        end
    end
    return bad
end

-- How far the turn at vertex i is from the angle the piece standing on it is cut for.
-- The join's bearing is decided by geometry rather than drawn on the turn grid, so its two
-- turns land wherever they land - and a 50-degree turn wearing a 45-degree bend leaves
-- five degrees of daylight on the outgoing joint, which is the wedge a freehand ring kept
-- showing even when its tiling came out exact.
function mercenaries:WallTurnError(pts, i)
    local n = #pts
    if n < 3 then return 0.0 end
    local p, q = pts[(i - 2) % n + 1], pts[i % n + 1]
    local t = math.deg(math.atan2(q.y - pts[i].y, q.x - pts[i].x)
                       - math.atan2(pts[i].y - p.y, pts[i].x - p.x))
    while t <= -180 do t = t + 360 end
    while t > 180 do t = t - 360 end
    if math.abs(t) < 8 then return 0.0 end
    local c
    pcall(function() c = self:CastleCornerFor(t, self.WallTypes[self.WallTypeIdx]) end)
    if not c then return 999.0 end
    return math.abs(t - (tonumber(c.turn) or 0))
end

-- What a turn of `turn` degrees takes out of the edge on `side`, or nil when the wall type
-- has no piece cut for that turn at all - in which case the shape simply cannot be built.
function mercenaries:WallCutForTurn(turn, side)
    if math.abs(turn) < 8 then return 0 end
    local c
    pcall(function() c = self:CastleCornerFor(turn, self.WallTypes[self.WallTypeIdx]) end)
    if not c then return nil end
    if side == "in" then return tonumber(c.cutIn) or tonumber(c.cut) or 0 end
    return tonumber(c.cutOut) or tonumber(c.cut) or 0
end

local function copyMarks(m)
    local c = {}
    for i = 1, #m do
        local p = m[i]
        c[i] = { x = p.x, y = p.y, z = p.z, aim = p.aim, bear = p.bear,
                 reach = p.reach, spread = p.spread, ent = p.ent }
    end
    return c
end

local function setMarks(m, c)
    for i = #m, 1, -1 do m[i] = nil end
    for i = 1, #c do m[i] = c[i] end
end

-- The mark the player stopped on is not always one a ring can be closed from. Coming home
-- nearly parallel to the first edge asks for a hairpin at both ends of the join - 130 and
-- 175 degrees, angles no piece in the kit is cut for - and the wall is then built with two
-- corners simply missing. Giving that last corner up and closing from the one before costs
-- a corner nobody asked for and buys a ring that can actually be built, so it is tried:
-- closing from the last mark, then from the one before it, then the one before that, and
-- the first shape that comes out buildable wins.
function mercenaries:WallCloseRing()
    local m = self.WallMarks
    if #m < 3 then System.LogAlways("[Wall] need three corners to close"); return end
    local start = copyMarks(m)
    local best, bestFaults, bestSeam, bestDrop = nil, math.huge, math.huge, 0
    for drop = 0, 2 do
        if #start - drop < 3 then break end
        local try = copyMarks(start)
        for i = #try, #try - drop + 1, -1 do try[i] = nil end
        setMarks(m, try)
        local seam = self:WallFitClose(m) or math.huge
        local faults = self:WallRingFaults(m)
        if faults < bestFaults or (faults == bestFaults and seam < bestSeam) then
            best, bestFaults, bestSeam, bestDrop = copyMarks(m), faults, seam, drop
        end
        if faults == 0 and seam <= CLOSE_TOL then break end
    end
    setMarks(m, best)
    for i = 1, #start do
        local keep = false
        for j = 1, #m do if m[j].ent == start[i].ent then keep = true break end end
        if not keep and start[i].ent then
            local e = start[i].ent
            pcall(function() System.RemoveEntity(e.id) end)
        end
    end
    self.WallClosed = true
    self:WallRebuild()
    System.LogAlways(string.format("[Wall] ring closed (%d corners, join within %.2f m%s%s)",
        #m, (bestSeam < math.huge) and bestSeam or 0,
        (bestDrop > 0) and string.format(", %d corner(s) given up", bestDrop) or "",
        (bestFaults > 0) and string.format(", %d joint(s) the kit cannot make", bestFaults) or ""))
end

-- Undo works backwards through the run being drawn, then pops the last FINISHED run
-- back onto the drawing board so its corners can be undone in turn. Without that, a
-- stretch committed by leaving build mode could never be taken back one corner at a time.
function mercenaries:WallUndo()
    pcall(function() if self.WallTouched then self:WallTouched() end end)
    local m = self.WallMarks
    if #m == 0 then
        local r = table.remove(self.WallRuns)
        if not r then return end
        self.WallMarks  = r.pts
        self.WallClosed = r.closed
        System.LogAlways("[Wall] reopened the previous run (" .. #r.pts .. " corners)")
        self:WallRebuild()
        return
    end
    if #m == 1 then self:WallClearStartMarker() end
    local last = table.remove(m)
    if last.ent then pcall(function() System.RemoveEntity(last.ent.id) end) end
    self.WallClosed = false
    self:WallRebuild()
end

-- Remove the whole of the last stretch built, without touching the ones before it.
function mercenaries:WallUndoRun()
    pcall(function() if self.WallTouched then self:WallTouched() end end)
    if self.WallMarks and #self.WallMarks > 0 then
        for _, mk in ipairs(self.WallMarks) do
            if mk.ent then pcall(function() System.RemoveEntity(mk.ent.id) end) end
        end
        self.WallMarks = {}
        self.WallClosed = false
        self:WallClearStartMarker()
    elseif not table.remove(self.WallRuns) then
        System.LogAlways("[Wall] nothing to remove")
        return
    end
    self:WallRebuild()
    pcall(function() if self.DefSave then self:DefSave() end end)
    System.LogAlways("[Wall] last stretch removed (" .. #self.WallRuns .. " left)")
end

function mercenaries:WallClearAll()
    pcall(function() if self.WallTouched then self:WallTouched() end end)
    self:WallClearSegments()
    self:WallPreviewClear()
    self:WallClearStartMarker()
    for _, mk in ipairs(self.WallMarks or {}) do
        if mk.ent then pcall(function() System.RemoveEntity(mk.ent.id) end) end
    end
    self.WallMarks = {}
    self.WallRuns = {}
    self.WallClosed = false
    System.LogAlways("[Wall] cleared")
end

-- Take the marker barrels away, keeping the walls (the "done building" step).
function mercenaries:WallHideMarkers()
    for _, mk in ipairs(self.WallMarks or {}) do
        if mk.ent then pcall(function() System.RemoveEntity(mk.ent.id) end); mk.ent = nil end
    end
    System.LogAlways("[Wall] markers removed (walls kept; merc_wall_clear removes everything)")
end

-- ==== BUILD MODE: left-click marks a corner, right-click finishes ====
-- While active, the run from the last corner to the crosshair is previewed as WHITE
-- segments. The preview pool grows/shrinks as the count changes (whole segments only),
-- so extending the run makes another piece pop in exactly where it will be built.
-- Mouse comes through the same Player.OnAction hook the tower/cart placement uses.
mercenaries.WallBuildActive = false
mercenaries.WallPreviewEnts = {}

mercenaries.WallPreviewMdl = {}

function mercenaries:WallPreviewClear()
    for _, id in ipairs(self.WallPreviewEnts or {}) do pcall(function() System.RemoveEntity(id) end) end
    self.WallPreviewEnts = {}
    self.WallPreviewMdl = {}
end

-- Show exactly the pieces the run would be built from - the sloped tile where it climbs,
-- the bend that closes the turn being aimed - rather than the plain straight everywhere.
-- A preview that shows one mesh while the builder lays another is a preview of a
-- different wall, and the joint you line up is not the joint you get.
--
-- Pooled by SLOT, so walking the cursor out pops the next piece in without the whole run
-- flickering; a slot whose mesh changed is the only one respawned, because a spawned
-- entity's model cannot be swapped afterwards.
function mercenaries:WallPreviewApply(items)
    local ents, mdl = self.WallPreviewEnts, self.WallPreviewMdl
    while #ents > #items do
        local id = table.remove(ents)
        table.remove(mdl)
        pcall(function() System.RemoveEntity(id) end)
    end
    for i, it in ipairs(items) do
        if mdl[i] ~= it.model then
            if ents[i] then pcall(function() System.RemoveEntity(ents[i]) end) end
            local e
            pcall(function()
                e = System.SpawnEntity({
                    class = "BasicEntity",
                    name = "MercWallGhost_" .. tostring(math.random(100000, 999999)),
                    position = { x = 0, y = 0, z = -1000 },
                    properties = { object_Model = it.model, bMissionCritical = false,
                                   bSaved_by_game = false, bSerialize = false },
                })
            end)
            if not e then
                -- keep the pool dense: a hole in the array would make #ents lie
                for k = #ents, i, -1 do
                    local id = table.remove(ents); table.remove(mdl)
                    if id then pcall(function() System.RemoveEntity(id) end) end
                end
                return
            end
            -- NO material override: the palisade mesh is multi-submaterial, and a single
            -- white .mtl only maps onto slot 0 - which is why the preview showed just the
            -- stake tops, and why distant pieces (whose LOD meshes map materials
            -- differently) dropped out entirely. Keeping the mesh's own materials renders
            -- all of it at every distance. See the ghost/submaterial note in
            -- mercenaries_tower.lua.
            pcall(function() e:SetViewDistUnlimited() end)
            pcall(function() e:SetViewDistRatio(255) end)
            pcall(function() e:SetLodRatio(255) end)
            if it.mtl then pcall(function() e:SetMaterial(it.mtl) end) end
            ents[i], mdl[i] = e.id, it.model
        end
        local e = ents[i] and System.GetEntity(ents[i])
        if e then
            pcall(function() e:SetPos(it.pos) end)
            pcall(function() e:SetAngles({ x = 0, y = 0, z = it.yaw }) end)
        end
    end
end

-- Ghost of the gate the current aim would build. Uses the shared placement ghost, which
-- is independent of ActivePlacement, so it can run inside wall build mode.
function mercenaries:WallGateGhostOn(snap)
    if not self._wallGateGhost then
        self:GhostClear()
        self:GhostBuild({ { model = self:GateModel(false), x = 0, y = 0, z = 0,
                            rx = 0, ry = 0, rz = 0 } }, nil)
        self._wallGateGhost = true
    end
    -- through GateMeshPos, exactly as the real build is: a ghost placed on the opening's
    -- centre while the gate is placed on its mesh offset is a preview that lies by
    -- however far the mesh is off its own middle
    local yaw = snap.yaw + math.rad(self.GateYawFix or 0)
    self:GhostMove(self:GateMeshPos({ x = snap.x, y = snap.y, z = snap.z }, yaw, false),
                   yaw, self.GateSink or 0)
end

function mercenaries:WallGateGhostOff()
    if not self._wallGateGhost then return end
    self:GhostClear()
    self._wallGateGhost = nil
end

function mercenaries.WallBuildTick()
    local self = mercenaries
    if not self.WallBuildActive then return end
    pcall(function()
        local segs = {}
        local prev = self.WallMarks[#self.WallMarks]
        local pos = self:TowerLookedAtPos()
        if pos and self.CampSnapToGround then pos = self:CampSnapToGround(pos) end
        pos = self:WallSnapAim(prev, pos)

        -- Nothing marked yet: there is no edge to draw, so preview the STAKE the first
        -- corner plants. Without it the opening click is aimed blind - the builder shows
        -- nothing at all until a corner is already down and can only be undone.
        -- No gate snap here either, for the same reason WallMark refuses one: the first
        -- corner of a run is always just a corner, so a gate ghost would be a lie.
        if not prev then
            self.WallGateSnapPose = nil
            self:WallGateGhostOff()
            self:WallPreviewApply(pos and
                { { pos = pos, yaw = 0, model = self.WallStartMarkerModel } } or {})
            return
        end

        -- Near an existing palisade the run ends in a gate. The gate snaps onto the wall
        -- it has reached, and the preview then walls the whole way from the live corner
        -- up to the gate's outer edge - flush, so the last piece meets it exactly.
        -- Everything behind that stays ordinary palisade.
        --
        -- GATE FIRST, then the ring close - the order WallMark uses. The close snap
        -- reaches a tile and a half (4.1 m on the palisade) and the gate snap 3.5 m, so
        -- the close radius CONTAINS the gate one: testing it first meant the run's own
        -- start could never raise a gate ghost, while the click on that same spot hung
        -- one anyway. That is the reported "the gate is not projected, it only appears
        -- after confirmation" - the preview was showing a plain ring close and the click
        -- was building a gate. A ring brought home through its own gateway is the right
        -- answer; the preview just has to say so.
        local snap = pos and self:WallGateSnapAt(pos) or nil
        -- At the gate limit WallMark refuses the click outright, so the preview must not
        -- offer the ring close it is not going to get either.
        local blocked = snap and (self:GateCount() or 0) >= self.GateMax
        if blocked then snap = nil end
        local shut = (not (snap or blocked)) and pos and self:WallCloseSnapAt(pos) or nil
        if shut then pos = { x = shut.x, y = shut.y, z = shut.z } end
        self.WallGateSnapPose = snap
        -- The run this edge is ABOUT to become: every mark already down, plus the one
        -- being aimed standing in for the next. Which piece lands on the live corner
        -- depends on where this edge is heading, so the cut the walls step back for and
        -- the mesh that fills it can only be asked for against the whole chain.
        local function ghostRun(target)
            if not (prev and target) then return nil, 0 end
            local pts = {}
            for _, q in ipairs(self.WallMarks or {}) do pts[#pts + 1] = q end
            pts[#pts + 1] = target
            if #pts < 2 then return nil, 0 end
            if shut then
                pts[#pts] = nil                -- the ring closes onto its own first corner
                return { pts = pts, closed = true }, #pts
            end
            return { pts = pts, closed = false }, #pts - 1      -- index of the live corner
        end
        local function ghostCut(target, side, at2)
            local r, at = ghostRun(target)
            if not (r and self.CastleVertexCut) then return 0 end
            local cut = 0
            pcall(function()
                cut = tonumber(self:CastleVertexCut(r, at2 or at, side or "out")) or 0
            end)
            return cut
        end
        -- A stone run is laid at one height, so the ghost has to be too, or the piece
        -- you are aiming sits at a height the built wall will not use and the joint you
        -- are lining up is not the joint you get. The level is worked out over the marks
        -- ALREADY down plus the one being aimed, which is the run this edge is about to
        -- become.
        local function ghostLevel(target)
            local r = ghostRun(target)
            if not r then return nil end
            local z
            pcall(function() z = self:WallRunLevel(r) end)
            return z
        end
        local far, levelZ = nil, nil          -- where this edge ends, gate or cursor
        if snap then
            self:WallGateGhostOn(snap)
            if prev then
                far = snap.far
                self:WallClimbReset()
                levelZ = ghostLevel(far)
                self.WallLevelZ = levelZ
                segs = self:WallEdgeSegments(prev, far, true, ghostCut(far))
                self.WallLevelZ = nil
            end
        else
            self:WallGateGhostOff()
            if pos and prev then
                far = pos
                self:WallClimbReset()
                levelZ = ghostLevel(far)
                self.WallLevelZ = levelZ
                segs = self:WallEdgeSegments(prev, far, shut and "close" or false,
                                             ghostCut(far),
                                             shut and ghostCut(far, "in", 1) or 0)
                self.WallLevelZ = nil
            end
        end

        local wt = wallType(self)
        local items = {}
        local fence = wt.ghost
        if fence and #segs > 0 then
            -- A low stone fence along the line, from the corner being drawn from to where
            -- the last piece of wall will end. Tiled at its own pitch, spread so it lands
            -- exactly on that end rather than overshooting it, and snapped to the ground so
            -- it reads as a line on the terrain.
            local run = (segs[1].yaw or 0) - math.rad(self.WallYawFix or 0)
            local ux, uy = math.cos(run), math.sin(run)
            local last = segs[#segs].pos
            local tail = (last.x - prev.x) * ux + (last.y - prev.y) * uy + segLen(self)
            local flen = tonumber(fence.len) or 5.0
            local k = math.max(1, math.floor(tail / flen + 0.5))
            local pitch = tail / k
            local lat = tonumber(fence.lat) or 0
            local lx, ly = -uy * lat, ux * lat
            local fy = run + math.rad(tonumber(fence.yaw) or 0)
            for i = 0, k - 1 do
                local d = pitch * (i + 0.5) - (tonumber(fence.ox) or 0)
                local p = { x = prev.x + ux * d + lx, y = prev.y + uy * d + ly, z = prev.z }
                if self.CampSnapToGround then p = self:CampSnapToGround(p) end
                p.z = p.z + (tonumber(fence.up) or 0)
                items[#items + 1] = { pos = p, yaw = fy, model = fence.m, mtl = fence.mtl }
            end
        else
            for _, s in ipairs(segs) do
                items[#items + 1] = { pos = s.pos, yaw = s.yaw,
                                      model = s.model or wt.m,
                                      mtl = (not s.model) and wt.mtl or nil }
            end
        end

        -- The piece that will stand on the corner this edge leaves. Without it the ghost
        -- starts a corner's arm short of the mark with nothing filling the gap, which
        -- reads as the wall missing its turn - and the turn is the thing being aimed.
        local plan = nil
        if far and self.CastleVertexPlan then
            local r, at = ghostRun(far)
            if r then pcall(function() plan = self:CastleVertexPlan(r, at) end) end
        end
        if plan and plan.m and prev and not fence then
            local p = { x = prev.x + (plan.dx or 0), y = prev.y + (plan.dy or 0),
                        z = prev.z }
            if self.WallSnap and self.CampSnapToGround then p = self:CampSnapToGround(p) end
            -- the height the RUN stands at, not the ground under the marker: a levelled
            -- run buries metres of its own footing, and a corner left on the ground would
            -- sit that far above its own curtain
            if levelZ then p.z = levelZ end
            p.z = p.z + (plan.up or 0)
            items[#items + 1] = { pos = p, yaw = plan.yaw or 0, model = plan.m,
                                  mtl = plan.mtl }
        end

        -- ==== the open ends ====
        -- These walls are SHELLS: the game's own pieces have no geometry closing their
        -- two end faces, because in the levels they were cut for there is always another
        -- piece against them. A run being drawn has nothing against its ends, so you look
        -- straight through the stone into the grass behind. A cap closes each one that
        -- nothing else is standing against.
        -- Each lid was cut from the wall at the end it closes and carries that end's own
        -- offset, so it goes on a tile's own origin and yaw and lands exactly on its
        -- face. The near one is only wanted when nothing is standing against it: once a
        -- corner piece is previewed on the live mark, that is what closes the run there.
        if wt.cap and #segs > 0 and not fence then
            if not (plan and plan.m) then
                items[#items + 1] = { pos = segs[1].pos, yaw = segs[1].yaw,
                                      model = wt.cap.start, mtl = wt.cap.mtl }
            end
            items[#items + 1] = { pos = segs[#segs].pos, yaw = segs[#segs].yaw,
                                  model = wt.cap.finish, mtl = wt.cap.mtl }
        end

        self:WallPreviewApply(items)
    end)
    Script.SetTimerForFunction(100, "mercenaries.WallBuildTick")
end

-- Each build session draws ONE new stretch and leaves every earlier one standing, so a
-- camp can be walled a side at a time. Anything left half-drawn from a previous session
-- is committed first rather than being extended - marking onto it would join two
-- separate stretches into one impossible polygon.
function mercenaries:StartWallBuild()
    if self.WallBuildActive then System.LogAlways("[Wall] already building"); return end
    self:WallCommitRun()
    self.WallBuildActive = true
    Game.SendInfoText('merc_info_wall_building', false, 0, 5)
    Script.SetTimerForFunction(100, "mercenaries.WallBuildTick")
end

-- Move the run being drawn into the finished list. The corner markers go with it: they
-- belong to the build session, not to the wall.
function mercenaries:WallCommitRun()
    self.WallBaseYaw = nil          -- the next run chooses its own orientation
    local m = self.WallMarks or {}
    if #m >= 2 then
        local pts = {}
        for _, p in ipairs(m) do
            -- the aim travels with the mark: the refit still runs on a finished
            -- stretch whenever the segment length or the wall type changes
            table.insert(pts, { x = p.x, y = p.y, z = p.z, aim = p.aim,
                                bear = p.bear, reach = p.reach, spread = p.spread })
        end
        -- Which wall this run is made of. Without it a stone curtain and a palisade are the
        -- same entry and nothing downstream can count them apart. It rides along in the
        -- save too (QMWallOpts), so a restored stone run is not read back as timber.
        table.insert(self.WallRuns, { pts = pts, closed = self.WallClosed,
                                      flushEnd = self.WallFlushEnd,
                                      wtype = self.WallTypeIdx })
    end
    for _, mk in ipairs(m) do
        if mk.ent then pcall(function() System.RemoveEntity(mk.ent.id) end) end
    end
    self.WallMarks = {}
    self.WallClosed = false
    self.WallFlushEnd = nil
end

-- Leaves build mode. Walls and corner markers stay (merc_wall_close still works;
-- merc_wall_done takes the barrels away, merc_wall_clear removes everything).
-- `quiet` suppresses the finished-building notice, for the caller that has a better one
-- of its own to send (hanging a gate).
function mercenaries:EndWallBuild(quiet)
    if not self.WallBuildActive then return end
    self.WallBuildActive = false
    self:WallPreviewClear()
    self:WallGateGhostOff()
    self.WallGateSnapPose = nil
    self:WallCommitRun()
    self:WallRebuild()
    -- A stone wall cuts itself a way through. It is not sold separately and it is not the
    -- player's job to remember: a curtain with no gate is a camp nobody can get into.
    pcall(function() if self.CastleGatewayAuto then self:CastleGatewayAuto() end end)
    -- a wall now exists: re-cut the guards' route along it and arm the backstop
    pcall(function() if self.NavRefreshPatrolRings then self:NavRefreshPatrolRings() end end)
    pcall(function() if self.WBStart then self:WBStart() end end)
    self:WallClearStartMarker()
    pcall(function() if self.DefSave then self:DefSave() end end)
    if not quiet then Game.SendInfoText('merc_info_wall_done', false, 0, 3) end
end

function mercenaries:WallSetType(v)
    local i = tonumber(v)
    if not (i and self.WallTypes[i]) then
        System.LogAlways("[Wall] wall types:")
        for k, t in ipairs(self.WallTypes) do
            System.LogAlways(string.format("[Wall]   %d = %-13s (len %.2f)%s", k, t.n, t.len,
                (k == self.WallTypeIdx) and "  <- current" or ""))
        end
        return
    end
    self.WallTypeIdx = i
    local t = self.WallTypes[i]
    self.WallSegLen = nil            -- back to the new type's own length
    self.WallUp  = t.up  or 0        -- and its own tuned offsets
    self.WallLat = t.lat or 0
    self.WallOx  = t.ox  or 0
    -- The walltool kit models its walls running along the mesh's own +Y, not +X, so a
    -- whole family needs -90 here or every piece stands across its run.
    self.WallYawFix = t.yaw or 0
    -- and only let the player draw turns this type actually has a corner for
    -- `or the default`, never `or whatever is there`: these are per-type settings, and
    -- leaving the last type's behind is how a 90-degree kit hands its snapping to the
    -- next wall selected and quietly stops that one turning where it used to.
    self.WallSnapAngle = self.WallSnapAngleDefault or 0
    pcall(function()
        if self.CastleSnapAngleFor then
            self.WallSnapAngle = self:CastleSnapAngleFor(t) or self.WallSnapAngle
        end
    end)
    -- A type that owns a corner for BOTH hands can close every turn itself, so it starts
    -- with towers off the turns entirely. Leaving the default of one every other corner
    -- drops a tower - and until now, a tower from a different kit at a different height -
    -- onto half of them, which reads as the corner piece simply failing to appear.
    -- merc_castle_tower_every 2 puts them back once a matching tower is chosen.
    self.CastleTowerEvery = (t.towerEvery ~= nil) and t.towerEvery
                            or self.CastleTowerEveryDefault or 2
    -- Stone is drawn corner to corner; a click that lands near an existing wall should
    -- mark a corner, not silently turn into a gate. Gate snapping is a palisade feature.
    self.WallGateSnap = t.gatesnap or ((t.castle and 0) or 3.5)
    self:WallPreviewClear()          -- pool holds the old mesh; let it respawn
    self:WallRebuild()
end

function mercenaries:WallSetCloseSnap(v)
    local n = tonumber(v)
    self.WallCloseSnap = n
    System.LogAlways(string.format("[Wall] ring closes within %.1f m of the first corner%s",
        self:WallCloseDist(), (self:WallCloseDist() <= 0) and " (off)" or ""))
end

function mercenaries:WallSetGateSnap(v) self.WallGateSnap = tonumber(v) or 3.5
    System.LogAlways(string.format("[Wall] gate snap %.2fm", self.WallGateSnap)) end
function mercenaries:WallSetClearRadius(v) self.WallClearRadius = tonumber(v) or 5.0
    System.LogAlways(string.format("[Wall] camp structures keep %.2fm off the wall", self.WallClearRadius)) end
function mercenaries:WallSetLen(v)   self.WallSegLen = tonumber(v); self:WallRebuild() end
function mercenaries:WallSetYaw(v)   self.WallYawFix = tonumber(v) or 0; self:WallRebuild() end
function mercenaries:WallSetUp(v)    self.WallUp     = tonumber(v) or 0; self:WallRebuild() end
function mercenaries:WallSetLat(v)   self.WallLat    = tonumber(v) or 0; self:WallRebuild() end
function mercenaries:WallSetSnap(v)  self.WallSnap   = (tonumber(v) ~= 0); self:WallRebuild() end
function mercenaries:WallSetLevel(v) self.WallLevel  = (tonumber(v) ~= 0); self:WallRebuild()
    System.LogAlways("[Wall] stone runs " .. (self.WallLevel and "laid at one height"
        or "following the ground piece by piece")) end
function mercenaries:WallSetPosts(v) self.WallPosts  = (tonumber(v) ~= 0); self:WallRebuild() end

function mercenaries:WallHelp()
    local lines = {
        "===== Wall builder =====",
        "Each merc_wall_build draws a NEW stretch; earlier ones stay up.",
        "Aim within merc_wall_gatesnap metres of any palisade and the preview becomes a GATE.",
        "Hanging that gate FINISHES the stretch; right-click finishes it early with no gate.",
        "merc_wall_mark      drop a corner where you look (edge to the previous corner fills in)",
        "merc_wall_close     join the last corner back to the first (needs 3+)",
        "merc_wall_undo      remove the last corner (steps back into the previous stretch)",
        "merc_wall_undo_run  remove the whole of the last stretch",
        "merc_wall_markers <01>  show the corner barrels while tuning (off by default)",
        "merc_wall_clear     remove EVERY stretch and its markers",
        "merc_wall_type <n>  wall mesh (no arg lists them; 3 = high palisade)",
        "merc_wall_len <m>   segment spacing - slightly under the mesh length to overlap",
        "merc_wall_yaw <deg> segment yaw fix (try 90 if pieces run across the edge)",
        "merc_wall_up <m>    height offset (negative sinks them)",
        "merc_wall_lat <m>   sideways offset from the edge line",
        "merc_wall_snap <01> follow the ground under each segment (default 1)",
        "merc_wall_clearance <m>  how far a camp upgrade is kept off the wall (0 = off)",
        "merc_wall_rebuild   re-render with the current settings",
        "merc_wall_matrix <group>  gallery of every base-game stone wall (no arg lists the groups)",
        "merc_wall_mx_where  name the gallery piece you are standing at",
        "merc_wall_mx_use    build with the gallery piece you are standing at",
    }
    for _, l in ipairs(lines) do System.LogAlways(l) end
end

-- %line, not %1: AddCCommand does not substitute %1 into the body, it passes the
-- literal "%1" (see the CCommand arg-substitution note).
mercenaries:DevCommand("merc_wall_help",    "mercenaries:WallHelp()",          "List the wall-builder commands")
mercenaries:DevCommand("merc_wall_build",   "mercenaries:StartWallBuild()",    "Start building: left-click marks a corner, right-click finishes")
mercenaries:DevCommand("merc_wall_stop",    "mercenaries:EndWallBuild()",      "Leave wall build mode (normally right-click)")
mercenaries:DevCommand("merc_wall_mark",    "mercenaries:WallMark()",          "Mark a wall corner where you look (normally left-click)")
mercenaries:DevCommand("merc_wall_close",   "mercenaries:WallCloseRing()",     "Close the polygon (last corner back to the first)")
mercenaries:DevCommand("merc_wall_close_snap", "mercenaries:WallSetCloseSnap('%1')", "How near the first corner the aim closes the ring (0 = off, blank = 1.5 tiles)")
mercenaries:DevCommand("merc_wall_undo",    "mercenaries:WallUndo()",          "Remove the last corner")
mercenaries:DevCommand("merc_wall_undo_run", "mercenaries:WallUndoRun()",     "Remove the whole of the last wall stretch")
mercenaries:DevCommand("merc_wall_gatesnap", "mercenaries:WallSetGateSnap(%line)", "How near a palisade turns the preview into a gate (metres, 0 = never)")
mercenaries:DevCommand("merc_wall_clearance", "mercenaries:WallSetClearRadius(%line)", "How far a camp upgrade is kept off the wall (metres, 0 = off)")
mercenaries:DevCommand("merc_wall_done",    "mercenaries:WallHideMarkers()",   "Remove the marker barrels, keep the walls")
mercenaries:DevCommand("merc_wall_clear",   "mercenaries:WallClearAll()",      "Remove all walls and markers")
mercenaries:DevCommand("merc_wall_rebuild", "mercenaries:WallRebuild()",       "Re-render the walls with the current settings")
mercenaries:DevCommand("merc_wall_type",    "mercenaries:WallSetType(%line)",  "Wall mesh: merc_wall_type <n> (no arg lists them)")
mercenaries:DevCommand("merc_wall_len",     "mercenaries:WallSetLen(%line)",   "Segment spacing in metres")
mercenaries:DevCommand("merc_wall_yaw",     "mercenaries:WallSetYaw(%line)",   "Segment yaw fix in degrees (try 90)")
mercenaries:DevCommand("merc_wall_up",      "mercenaries:WallSetUp(%line)",    "Height offset in metres (negative sinks)")
mercenaries:DevCommand("merc_wall_lat",     "mercenaries:WallSetLat(%line)",   "Sideways offset from the edge line")
mercenaries:DevCommand("merc_wall_snap",    "mercenaries:WallSetSnap(%line)",  "Follow ground under each segment: 0 or 1")
mercenaries:DevCommand("merc_wall_level",   "mercenaries:WallSetLevel(%line)", "Lay a STONE run at one height instead of stepping it down the slope: 0 or 1")
mercenaries:DevCommand("merc_wall_markers", "mercenaries:WallSetMarkers(%line)","Show the corner barrels while tuning: 0 or 1")
mercenaries:DevCommand("merc_wall_posts",   "mercenaries:WallSetPosts(%line)", "Corner posts bridging the joint: 0 or 1")
mercenaries:DevCommand("merc_wall_angle",   "mercenaries:WallSetSnapAngle(%line)", "Snap corners to N degrees off the run's first edge (0 = freehand, the palisade default; stone sets its own from its corner kit)")

-- ==== stone gallery (authoring) ====
-- Every base-game stone wall, tower and gate worth trying as a castle wall, laid out
-- in a grid to be walked. Grouped by scale: the castle-scale pieces are whole level
-- walls and need a 45m cell where the modular kit wants 9m, so one grid for all of
-- them would either overlap or sprawl past the streaming range.
-- Paths come from the IPL_Objects pak index, so a mesh that fails to spawn is one the
-- spawner refused, not a typo. `-- cv` marks one whose collision lives in a sibling
-- cv_* proxy: it renders but does not block, and needs the invisible-crate treatment
-- before it can be a wall.
mercenaries.WallMxGroups = {
    { key = "kit", cell = 9, cols = 6, desc = "Kutna Hora city-wall kit: tall, tileable, straight/corner/end/gate", meshes = {
        "objects/intermediates/walltool/wall_kh_02_a.cgf",
        "objects/intermediates/walltool/wall_kh_02_b.cgf",
        "objects/intermediates/walltool/wall_kh_02_drain.cgf",
        "objects/intermediates/walltool/wall_kh_02_end.cgf",
        "objects/intermediates/walltool/wall_kh_02_start.cgf",
        "objects/intermediates/walltool/wall_kh_a.cgf",
        "objects/intermediates/walltool/wall_kh_a_railing.cgf",
        "objects/intermediates/walltool/wall_kh_b.cgf",
        "objects/intermediates/walltool/wall_kh_b_railing.cgf",
        "objects/intermediates/walltool/wall_kh_c.cgf",
        "objects/intermediates/walltool/wall_kh_c_railing.cgf",
        "objects/intermediates/walltool/wall_kh_column.cgf",
        "objects/intermediates/walltool/wall_kh_column_b.cgf",
        "objects/intermediates/walltool/wall_kh_column_c.cgf",
        "objects/intermediates/walltool/wall_kh_d.cgf",
        "objects/intermediates/walltool/wall_kh_e.cgf",
        "objects/intermediates/walltool/wall_kh_end_a.cgf",
        "objects/intermediates/walltool/wall_kh_end_a_railing.cgf",
        "objects/intermediates/walltool/wall_kh_end_b.cgf",
        "objects/intermediates/walltool/wall_kh_gate_a.cgf",
        "objects/intermediates/walltool/wall_kh_gate_a_railing.cgf",
        "objects/intermediates/walltool/wall_kh_gate_b.cgf",
        "objects/intermediates/walltool/wall_kh_gate_b_railing.cgf",
        "objects/intermediates/walltool/wall_kh_gate_c.cgf",
        "objects/intermediates/walltool/wall_kh_gate_c_railing.cgf",
        "objects/intermediates/walltool/wall_kh_left_90.cgf",
        "objects/intermediates/walltool/wall_kh_left_90_railing.cgf",
        "objects/intermediates/walltool/wall_kh_right_90.cgf",
        "objects/intermediates/walltool/wall_kh_right_90_railing.cgf",
    } },
    { key = "low", cell = 7, cols = 7, desc = "walltool low stone walls: property/garden height, capped", meshes = {
        "objects/intermediates/walltool/stone_wall_big_a.cgf",
        "objects/intermediates/walltool/stone_wall_big_b.cgf",
        "objects/intermediates/walltool/stone_wall_big_c.cgf",
        "objects/intermediates/walltool/stone_wall_big_column.cgf",
        "objects/intermediates/walltool/stone_wall_big_column_b.cgf",
        "objects/intermediates/walltool/stone_wall_big_column_c.cgf",
        "objects/intermediates/walltool/stone_wall_big_end_a.cgf",
        "objects/intermediates/walltool/stone_wall_big_gate_a.cgf",
        "objects/intermediates/walltool/stone_wall_kh_column_a.cgf",
        "objects/intermediates/walltool/stone_wall_kh_column_b.cgf",
        "objects/intermediates/walltool/stone_wall_kh_doorway.cgf",
        "objects/intermediates/walltool/stone_wall_kh_down.cgf",
        "objects/intermediates/walltool/stone_wall_kh_end.cgf",
        "objects/intermediates/walltool/stone_wall_kh_gate.cgf",
        "objects/intermediates/walltool/stone_wall_kh_left_90.cgf",
        "objects/intermediates/walltool/stone_wall_kh_normal.cgf",
        "objects/intermediates/walltool/stone_wall_kh_normal_b.cgf",
        "objects/intermediates/walltool/stone_wall_kh_pillar.cgf",
        "objects/intermediates/walltool/stone_wall_kh_plaster_bulge_a.cgf",
        "objects/intermediates/walltool/stone_wall_kh_plaster_bulge_b.cgf",
        "objects/intermediates/walltool/stone_wall_kh_plaster_doorway.cgf",
        "objects/intermediates/walltool/stone_wall_kh_plaster_down.cgf",
        "objects/intermediates/walltool/stone_wall_kh_plaster_end.cgf",
        "objects/intermediates/walltool/stone_wall_kh_plaster_gate.cgf",
        "objects/intermediates/walltool/stone_wall_kh_plaster_gate_end_a.cgf",
        "objects/intermediates/walltool/stone_wall_kh_plaster_gate_end_b.cgf",
        "objects/intermediates/walltool/stone_wall_kh_plaster_left_90.cgf",
        "objects/intermediates/walltool/stone_wall_kh_plaster_normal.cgf",
        "objects/intermediates/walltool/stone_wall_kh_plaster_normal_b.cgf",
        "objects/intermediates/walltool/stone_wall_kh_plaster_pillar.cgf",
        "objects/intermediates/walltool/stone_wall_kh_plaster_right_90.cgf",
        "objects/intermediates/walltool/stone_wall_kh_plaster_start.cgf",
        "objects/intermediates/walltool/stone_wall_kh_plaster_up.cgf",
        "objects/intermediates/walltool/stone_wall_kh_right_90.cgf",
        "objects/intermediates/walltool/stone_wall_kh_shingles_a.cgf",
        "objects/intermediates/walltool/stone_wall_kh_shingles_b.cgf",
        "objects/intermediates/walltool/stone_wall_kh_shingles_c.cgf",
        "objects/intermediates/walltool/stone_wall_kh_shingles_d.cgf",
        "objects/intermediates/walltool/stone_wall_kh_shingles_e.cgf",
        "objects/intermediates/walltool/stone_wall_kh_shingles_f.cgf",
        "objects/intermediates/walltool/stone_wall_kh_shingles_g.cgf",
        "objects/intermediates/walltool/stone_wall_kh_start.cgf",
        "objects/intermediates/walltool/stone_wall_kh_up.cgf",
        "objects/intermediates/walltool/stone_wall_sedlec_plaster_schingles_a.cgf",
        "objects/intermediates/walltool/stone_wall_sedlec_plaster_schingles_b.cgf",
        "objects/intermediates/walltool/stone_wall_sedlec_plaster_schingles_c.cgf",
        "objects/intermediates/walltool/stone_wall_sedlec_plaster_schingles_end.cgf",
        "objects/intermediates/walltool/stone_wall_sedlec_plaster_schingles_gate.cgf",
    } },
    { key = "seg", cell = 7, cols = 5, desc = "Loose stone segments and low ruined pieces", meshes = {
        "objects/manmade/common_decorations/streets_deco/guard_stone_wall_a.cgf",
        "objects/manmade/common_decorations/streets_deco/guard_stone_wall_b.cgf",
        "objects/manmade/common_decorations/streets_deco/guard_stone_wall_c.cgf",
        "objects/manmade/common_decorations/streets_deco/guard_stone_wall_d.cgf",
        "objects/manmade/structures/defensive/walls/wall_rough_whitewashed/wall_rough_whitewashed_piece_a.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/wall_low_ruined_kh_a.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/wall_low_ruined_kh_b.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/wall_low_ruined_kh_c.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/wall_low_ruined_kh_d.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/wall_low_ruined_kh_e.cgf",
        "objects/manmade/structures/defensive/walls/wall_segments/wall_segment_220_60_a_a.cgf",
        "objects/manmade/structures/defensive/walls/wall_segments/wall_segment_220_60_a_b.cgf",
        "objects/manmade/structures/defensive/walls/wall_segments/wall_segment_220_60_a_c.cgf",
    } },
    { key = "ruin", cell = 12, cols = 6, desc = "Ruined fortress wall pieces (Cimburk / generic)", meshes = {
        "objects/manmade/structures/defensive/fortress/cimburk/ruined_wall_a.cgf",
        "objects/manmade/structures/defensive/fortress/cimburk/ruined_wall_b.cgf",
        "objects/manmade/structures/defensive/fortress/cimburk/ruined_wall_c.cgf",
        "objects/manmade/structures/defensive/fortress/cimburk/ruined_wall_piece_a.cgf",
        "objects/manmade/structures/defensive/fortress/cimburk/ruined_wall_piece_b.cgf",
        "objects/manmade/structures/defensive/fortress/cimburk/ruined_wall_piece_c.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/ruined_fortress_wall_brokenbeam_a.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/ruined_fortress_wall_brokenbeam_b.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/ruined_fortress_wall_piece_a.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/ruined_fortress_wall_piece_b.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/ruined_fortress_wall_piece_c.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/ruined_fortress_wall_piece_d.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/ruined_fortress_wall_piece_d_half_a.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/ruined_fortress_wall_piece_d_half_b.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/ruined_fortress_wall_piece_d_quater.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/ruined_fortress_wall_piece_e.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/ruined_fortress_wall_piece_f.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/ruined_fortress_wall_piece_g.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/ruined_fortress_wall_piece_h.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/ruined_fortress_wall_piece_h_flipped.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/ruined_fortress_wall_piece_i.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/ruined_fortress_wall_piece_j.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/ruined_fortress_wall_piece_k.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/ruined_fortress_wall_piece_l.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/ruined_fortress_wall_piece_m.cgf",             -- cv
        "objects/manmade/structures/defensive/walls/wall_ruined/ruined_fortress_wall_piece_m_roof.cgf",
        "objects/manmade/structures/defensive/walls/wall_ruined/wall_ruined_piece_a.cgf",
        "objects/manmade/structures/logistical/fences/wall_ruined_piece_a.cgf",
    } },
    { key = "castle", cell = 45, cols = 5, desc = "Castle-scale wall runs - whole level pieces, huge", meshes = {
        "objects/manmade/structures/defensive/castles/unique/nebakov/allure_nebakov_01.cgf",
        "objects/manmade/structures/defensive/fortress/malesov/malesov_allure.cgf",
        "objects/manmade/structures/defensive/fortress/malesov/malesov_wall_01.cgf",
        "objects/manmade/structures/defensive/fortress/malesov/malesov_wall_02.cgf",                           -- cv
        "objects/manmade/structures/defensive/fortress/malesov/malesov_wall_03.cgf",
        "objects/manmade/structures/defensive/fortress/malesov/malesov_wall_gate_part.cgf",
        "objects/manmade/structures/defensive/fortress/malesov/malesov_wall_stone_01.cgf",
        "objects/manmade/structures/defensive/fortress/malesov/malesov_wall_stone_02.cgf",
        "objects/manmade/structures/defensive/fortress/malesov/malesov_wall_tower.cgf",                        -- cv
        "objects/manmade/structures/defensive/fortress/malesov/stones_malesov_wall_defaul_tall.cgf",
        "objects/manmade/structures/defensive/fortress/malesov/stones_malesov_wall_default.cgf",
        "objects/manmade/structures/defensive/fortress/malesov/stones_malesov_wall_state_1.cgf",
        "objects/manmade/structures/defensive/fortress/malesov/stones_malesov_wall_state_1_b.cgf",
        "objects/manmade/structures/defensive/fortress/malesov/stones_malesov_wall_state_1_tall.cgf",
        "objects/manmade/structures/defensive/fortress/malesov/stones_malesov_wall_state_default.cgf",
        "objects/manmade/structures/defensive/fortress/pritoky/pritoky_fortress_wall.cgf",
        "objects/manmade/structures/defensive/fortress/ratibor/ratibor_fortress_walls.cgf",
        "objects/manmade/structures/defensive/fortress/suchdol/suchdol_broken_wall_cover.cgf",
        "objects/manmade/structures/defensive/fortress/suchdol/suchdol_fortress_walls.cgf",
        "objects/manmade/structures/defensive/fortress/suchdol/suchdol_fortress_walls_b.cgf",
        "objects/manmade/structures/defensive/fortress/suchdol/suchdol_fortress_walls_c.cgf",
        "objects/manmade/structures/defensive/fortress/suchdol/suchdol_palace_wall_part_damaged.cgf",
        "objects/manmade/structures/defensive/fortress/suchdol/suchdol_palace_wall_part_undamaged.cgf",
        "objects/manmade/structures/defensive/walls/unique/dobesovicko/dobesovicko_wall.cgf",
        "objects/manmade/structures/defensive/walls/unique/kutna_hora/barborsky_wall.cgf",
        "objects/manmade/structures/defensive/walls/unique/kutna_hora/barborsky_wall_b.cgf",
        "objects/manmade/structures/defensive/walls/unique/kutna_hora/barborsky_wall_c.cgf",
        "objects/manmade/structures/defensive/walls/unique/kutna_hora/wall_corridor_kh_kourimska.cgf",
        "objects/manmade/structures/defensive/walls/unique/opatovice/parcel_01_wall.cgf",
        "objects/manmade/structures/defensive/walls/unique/opatovice/parcel_02_wall.cgf",
        "objects/manmade/structures/defensive/walls/unique/opatovice/parcel_04_wall.cgf",
        "objects/manmade/structures/defensive/walls/unique/semin/walls_semin.cgf",
        "objects/manmade/structures/defensive/walls/unique/semin/walls_semin_burned.cgf",
        "objects/manmade/structures/defensive/walls/unique/suchdol/church_suchdol_wall.cgf",
        "objects/manmade/structures/defensive/walls/unique/trosky/lowercastle_walls.cgf",
        "objects/manmade/structures/defensive/walls/unique/trosky/lowercastle_walls_railing.cgf",
        "objects/manmade/structures/defensive/walls/unique/vysoka/church_vysoka_wall.cgf",
        "objects/manmade/task_specific_props/combat/castle_siege/castle_wall_test/castle_wall_test.cgf",
    } },
    { key = "tower", cell = 35, cols = 5, desc = "Towers and bastions to anchor the corners", meshes = {
        "objects/intermediates/elements/doorway_bastion_kh_a_100.cgf",
        "objects/intermediates/elements/doorway_bastion_kh_a_60.cgf",
        "objects/manmade/structures/defensive/castles/unique/trosky/trosky_5_guardtower.cgf",                  -- cv
        "objects/manmade/structures/defensive/fortress/cimburk/ruined_tower_a.cgf",
        "objects/manmade/structures/defensive/fortress/malesov/malesov_machicolation_tower.cgf",
        "objects/manmade/structures/defensive/fortress/malesov/malesov_round_tower.cgf",                       -- cv
        "objects/manmade/structures/defensive/fortress/malesov/malesov_wall_tower.cgf",                        -- cv
        "objects/manmade/structures/defensive/fortress/ratibor/ratibor_tower.cgf",                             -- cv
        "objects/manmade/structures/defensive/fortress/suchdol/suchdol_fortress_tower.cgf",
        "objects/manmade/structures/defensive/gatehouses/unique/nebakov/outer_gate_tower.cgf",
        "objects/manmade/structures/defensive/gatehouses/unique/nebakov/outer_gate_tower_b.cgf",
        "objects/manmade/structures/defensive/gatehouses/unique/nebakov/small_inner_gate_tower.cgf",           -- cv
        "objects/manmade/structures/defensive/walls/unique/kutna_hora/bastion_kh_01.cgf",
        "objects/manmade/structures/defensive/walls/unique/kutna_hora/bastion_kh_01_kourimska.cgf",
        "objects/manmade/structures/defensive/walls/unique/kutna_hora/bastion_kh_01_white.cgf",
        "objects/manmade/structures/defensive/walls/unique/kutna_hora/bastion_kh_03.cgf",
        "objects/manmade/structures/defensive/watchtowers/unique/nebakov/watchtower.cgf",                      -- cv
        "objects/manmade/structures/defensive/watchtowers/watchtower_a.cgf",
    } },
    { key = "gate", cell = 30, cols = 5, desc = "Stone gates and gatehouses", meshes = {
        "objects/intermediates/walltool/stone_wall_big_gate_a.cgf",
        "objects/intermediates/walltool/stone_wall_kh_gate.cgf",
        "objects/intermediates/walltool/stone_wall_kh_plaster_gate.cgf",
        "objects/intermediates/walltool/stone_wall_kh_plaster_gate_end_a.cgf",
        "objects/intermediates/walltool/stone_wall_kh_plaster_gate_end_b.cgf",
        "objects/intermediates/walltool/stone_wall_sedlec_plaster_schingles_gate.cgf",
        "objects/intermediates/walltool/wall_kh_decal_empty_gate_b.cgf",
        "objects/intermediates/walltool/wall_kh_decal_empty_gate_c.cgf",
        "objects/intermediates/walltool/wall_kh_gate_a.cgf",
        "objects/intermediates/walltool/wall_kh_gate_a_railing.cgf",
        "objects/intermediates/walltool/wall_kh_gate_b.cgf",
        "objects/intermediates/walltool/wall_kh_gate_b_railing.cgf",
        "objects/intermediates/walltool/wall_kh_gate_c.cgf",
        "objects/intermediates/walltool/wall_kh_gate_c_railing.cgf",
        "objects/manmade/structures/defensive/fortress/malesov/malesov_wall_gate_part.cgf",
        "objects/manmade/structures/defensive/fortress/ratibor/ratibor_gate.cgf",
        "objects/manmade/structures/defensive/fortress/suchdol/suchdol_fortress_gate.cgf",                     -- cv
        "objects/manmade/structures/defensive/gatehouses/unique/malesov/gate_malesov.cgf",
        "objects/manmade/structures/defensive/gatehouses/unique/malesov/gate_malesov_railing.cgf",
        "objects/manmade/structures/defensive/gatehouses/unique/trosky/trosky_1_gatehouse.cgf",
        "objects/manmade/structures/defensive/walls/unique/kutna_hora/gate_kh_01.cgf",                         -- cv
        "objects/manmade/structures/defensive/walls/unique/kutna_hora/gate_kh_01_b.cgf",                       -- cv
        "objects/manmade/structures/defensive/walls/unique/kutna_hora/gate_kh_01_b1_zwinger.cgf",
        "objects/manmade/structures/defensive/walls/unique/kutna_hora/gate_kh_01_c.cgf",                       -- cv
        "objects/manmade/structures/defensive/walls/unique/kutna_hora/gate_kh_01_d.cgf",
        "objects/manmade/structures/defensive/walls/unique/kutna_hora/gate_kh_01_door_cover.cgf",
        "objects/manmade/structures/defensive/walls/unique/kutna_hora/gate_kh_02.cgf",
        "objects/manmade/structures/defensive/walls/unique/kutna_hora/gate_kh_03.cgf",                         -- cv
        "objects/manmade/structures/defensive/walls/unique/kutna_hora/gate_kh_kourimska_zwinger.cgf",
        "objects/manmade/structures/defensive/walls/unique/kutna_hora/gate_zwinger.cgf",
    } },}

mercenaries.WallMxEnts     = {}    -- { { id =, n =, m =, x =, y = } } in gallery order
mercenaries.WallMxYaw      = 90    -- degrees added to every candidate (90 = broadside to you)
mercenaries.WallMxUp       = 0     -- height offset applied to every candidate
mercenaries.WallMxLastArgs = ""

local function wallMxArg(v)
    local t = tostring(v or ""):gsub("^%s*(.-)%s*$", "%1")
    t = t:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
    return (t:gsub("^%s*(.-)%s*$", "%1"))
end

local function wallMxName(path)
    return (tostring(path):match("([^/]+)%.cgf$") or tostring(path))
end

local function wallMxTotal()
    local n = 0
    for _, g in ipairs(mercenaries.WallMxGroups) do n = n + #g.meshes end
    return n
end

-- Same static prop the builder itself spawns, so what you see here is what a finished
-- wall would look like: mercenaries_Prop collides, BasicEntity is the fallback.
local function wallMxSpawn(self, model, pos, yaw)
    local params = {
        class = "mercenaries_Prop",
        name = "MercWallMx_" .. tostring(math.random(100000, 999999)),
        position = pos,
        orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
        -- AI.bUsedAsDynamicObstacle is on the class too; passed again here because entity
        -- properties are read when the entity physicalises, and the spawn-time table is the
        -- only one guaranteed to be in place by then. It is what makes NPCs steer round the
        -- piece instead of into it - see mercenaries_Prop.lua and mercenaries_navobst.lua.
        properties = { object_Model = model, bMissionCritical = false,
                       bSaved_by_game = false, bSerialize = false,
                       AI = { bUsedAsDynamicObstacle = 1 },
                       -- THE point of this whole exercise. The engine gathers obstacle
                       -- candidates with a physics query whose mask is
                       -- ent_rigid | ent_sleeping_rigid (0x50006 in sub_2F52A5C); ent_static
                       -- is not in it. A PE_STATIC segment is therefore never offered to the
                       -- obstacle builder and bUsedAsDynamicObstacle on it does nothing at
                       -- all. Physicalised RIGID and left resting, the segment IS in the mask
                       -- (ent_sleeping_rigid) and registers its own true geometry - no
                       -- stretched stand-in, no pivot guesswork.
                       Physics = mercenaries.WallRigid and {
                           bPhysicalize = true,
                           bRigidBody = true,
                           bResting = 1,
                           Mass = mercenaries.WallRigidMass or 25000,
                           Density = -1,
                           bPushableByPlayers = false,
                       } or nil },
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
        table.insert(self.WallMxEnts,
            { id = ent.id, n = wallMxName(model), m = model, x = pos.x, y = pos.y })
    end
    return ent
end

function mercenaries:WallMatrixClear()
    for _, e in ipairs(self.WallMxEnts or {}) do
        pcall(function() System.RemoveEntity(e.id) end)
    end
    self.WallMxEnts = {}
end

function mercenaries:WallMxMenu()
    System.LogAlways("[WallMx] merc_wall_matrix <group> [cellsize] [percol]")
    for _, g in ipairs(self.WallMxGroups) do
        System.LogAlways(string.format("[WallMx]   %-7s %3d  %s", g.key, #g.meshes, g.desc))
    end
    System.LogAlways(string.format(
        "[WallMx]   all     %3d  every group, each band with its own cell size (~1km deep)",
        wallMxTotal()))
    System.LogAlways("[WallMx] merc_wall_mx_where names the piece you are standing at")
end

-- Groups are laid out as bands running away from you, each with its own cell size, so
-- `all` does not have to pick one spacing for both a 2m kit piece and a 60m fortress
-- wall. Columns run left to right across your facing.
function mercenaries:WallMatrix(line)
    local a = {}
    for w in wallMxArg(line):gmatch("%S+") do a[#a + 1] = w end
    local key = string.lower(a[1] or "")
    if key == "" then return self:WallMxMenu() end

    local want = {}
    for _, g in ipairs(self.WallMxGroups) do
        if key == "all" or g.key == key then table.insert(want, g) end
    end
    if #want == 0 then
        System.LogAlways("[WallMx] no group called '" .. key .. "'")
        return self:WallMxMenu()
    end
    self.WallMxLastArgs = wallMxArg(line)

    self:WallMatrixClear()
    if not player then return end

    local o = player:GetWorldPos()
    local ang; pcall(function() ang = player:GetWorldAngles() end)
    local pyaw = (ang and ang.z) or 0
    local fx, fy = math.cos(pyaw), math.sin(pyaw)
    local rx, ry = -fy, fx
    local yaw = pyaw + math.rad(self.WallMxYaw or 0)

    local n, failed, band = 0, 0, 14.0
    for _, g in ipairs(want) do
        local cell = tonumber(a[2]) or g.cell
        local cols = math.max(1, math.floor(tonumber(a[3]) or g.cols))
        local rowPitch = cell + 2.0
        local half = (cols - 1) * cell * 0.5
        System.LogAlways(string.format("[WallMx] -- %s (%d pieces, %.0fm cells) at %.0fm --",
            g.key, #g.meshes, cell, band))

        for i, path in ipairs(g.meshes) do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local fwd = band + row * rowPitch
            local lat = col * cell - half
            local pos = { x = o.x + fx * fwd + rx * lat,
                          y = o.y + fy * fwd + ry * lat, z = o.z }
            if self.CampSnapToGround then pos = self:CampSnapToGround(pos) end
            pos.z = pos.z + (self.WallMxUp or 0)

            n = n + 1
            if wallMxSpawn(self, path, pos, yaw) then
                System.LogAlways(string.format("[WallMx] #%-3d %-7s r%d c%d  %s",
                    n, g.key, row + 1, col + 1, wallMxName(path)))
            else
                failed = failed + 1
                System.LogAlways(string.format("[WallMx] #%-3d %-7s FAILED  %s", n, g.key, path))
            end
        end
        band = band + (math.floor((#g.meshes - 1) / cols) + 1) * rowPitch + cell
    end

    System.LogAlways(string.format(
        "[WallMx] %d piece(s)%s, %.0fm deep. merc_wall_mx_where identifies one, merc_wall_matrix_clear removes them.",
        n, (failed > 0) and (" (" .. failed .. " failed)") or "", band))
end

-- Which one am I looking at? The grid is too big to count rows in, and a piece's log
-- line is hundreds of lines back by the time you have walked out to it.
function mercenaries:WallMxNearest()
    if not player or #(self.WallMxEnts or {}) == 0 then return nil end
    local p = player:GetWorldPos()
    local best, bd
    for i, e in ipairs(self.WallMxEnts) do
        local d = (e.x - p.x) ^ 2 + (e.y - p.y) ^ 2
        if not bd or d < bd then best, bd = i, d end
    end
    return best, math.sqrt(bd or 0)
end

function mercenaries:WallMxWhere()
    local i, d = self:WallMxNearest()
    if not i then
        System.LogAlways("[WallMx] nothing spawned - merc_wall_matrix <group> first")
        return
    end
    local e = self.WallMxEnts[i]
    System.LogAlways(string.format("[WallMx] #%d %s (%.1fm away)", i, e.n, d))
    System.LogAlways("[WallMx] " .. e.m)
    System.LogAlways(string.format(
        "[WallMx] WallTypes row:  { n = \"%s\", m = \"%s\", len = 2.00, up = 0.00, lat = 0.00 },",
        e.n, e.m))
end

-- Draw with the piece you are standing at, without editing WallTypes first. One
-- scratch slot, reused, so trying twenty candidates does not leave twenty types.
function mercenaries:WallMxUse()
    local i = self:WallMxNearest()
    if not i then
        System.LogAlways("[WallMx] nothing spawned - merc_wall_matrix <group> first")
        return
    end
    local e = self.WallMxEnts[i]
    local idx
    for k, t in ipairs(self.WallTypes) do if t.n == "gallery" then idx = k end end
    if idx then
        self.WallTypes[idx].m = e.m
    else
        table.insert(self.WallTypes, { n = "gallery", m = e.m, len = 2.00, up = 0.00, lat = 0.00 })
        idx = #self.WallTypes
    end
    System.LogAlways("[WallMx] wall type " .. idx .. " (gallery) is now " .. e.n)
    System.LogAlways("[WallMx] merc_wall_len / merc_wall_up / merc_wall_yaw to fit it, then merc_wall_build")
    self:WallSetType(idx)
end

function mercenaries:WallMxList(line)
    local key = string.lower(wallMxArg(line))
    if key == "" then return self:WallMxMenu() end
    for _, g in ipairs(self.WallMxGroups) do
        if key == "all" or g.key == key then
            System.LogAlways("[WallMx] -- " .. g.key .. " --")
            for i, path in ipairs(g.meshes) do
                System.LogAlways(string.format("[WallMx]   %-3d %-42s %s", i, wallMxName(path), path))
            end
        end
    end
end

local function wallMxRespawn(self)
    if self.WallMxLastArgs ~= "" then self:WallMatrix(self.WallMxLastArgs) end
end

function mercenaries:WallMxSetYaw(v) self.WallMxYaw = tonumber(wallMxArg(v)) or 0; wallMxRespawn(self) end
function mercenaries:WallMxSetUp(v)  self.WallMxUp  = tonumber(wallMxArg(v)) or 0; wallMxRespawn(self) end

mercenaries:DevCommand("merc_wall_matrix",       "mercenaries:WallMatrix('%line')",
    "Grid of every base-game stone wall: merc_wall_matrix <group|all> [cellsize] [percol] (no arg lists the groups)")
mercenaries:DevCommand("merc_wall_matrix_clear", "mercenaries:WallMatrixClear()",
    "Remove the stone gallery")
mercenaries:DevCommand("merc_wall_mx_where",     "mercenaries:WallMxWhere()",
    "Name the gallery piece you are standing at, with a WallTypes row to paste")
mercenaries:DevCommand("merc_wall_mx_use",       "mercenaries:WallMxUse()",
    "Build with the gallery piece you are standing at (scratch wall type)")
mercenaries:DevCommand("merc_wall_mx_list",      "mercenaries:WallMxList('%line')",
    "Print a group's mesh paths: merc_wall_mx_list <group|all>")
mercenaries:DevCommand("merc_wall_mx_yaw",       "mercenaries:WallMxSetYaw('%line')",
    "Spin every gallery piece by N degrees and respawn (default 90)")
mercenaries:DevCommand("merc_wall_mx_up",        "mercenaries:WallMxSetUp('%line')",
    "Raise or sink every gallery piece by N metres and respawn")

-- Walls have no per-entity liveness check, the way gates got one in GateWatchdog: an engine
-- sweep, a save load or a level change can take the segments out from under WallSegEnts and
-- nothing notices. Repeated fast travel means many such events, which is why "a lot" is the
-- trigger. Walls are rebuilt wholesale, so noticing is the whole job.
mercenaries.WallWatchdogEvery = 30.0     -- seconds between repairs, so a real failure cannot thrash
mercenaries.WallWatchdogLast  = nil

function mercenaries:WallWatchdog()
    if not (self.CampActive and self:WallHasAny()) then return end
    local ids = self.WallSegEnts or {}
    if #ids == 0 then return end

    local live = 0
    for _, id in ipairs(ids) do
        local e
        pcall(function() e = System.GetEntity(id) end)
        if e then
            -- by NAME as well as by id: ids are recycled, and a live id that now belongs to
            -- something else would read as "the wall is fine" for ever
            local n = ""
            pcall(function() n = e:GetName() or "" end)
            if string.sub(n, 1, 8) == "MercWall" then live = live + 1 end
        end
    end
    if live >= math.floor(#ids * 0.5) then return end

    local t = 0
    pcall(function() t = System.GetCurrTime() or 0 end)
    if self.WallWatchdogLast and (t - self.WallWatchdogLast) < (self.WallWatchdogEvery or 30.0) then
        return
    end
    self.WallWatchdogLast = t
    System.LogAlways(string.format(
        "[Wall] only %d of %d segment(s) still standing - rebuilding the run", live, #ids))
    pcall(function() self:WallRebuild() end)
end
