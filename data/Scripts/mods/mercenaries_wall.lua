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
mercenaries.WallTypes = {
    { n = "taras_a",       m = "objects/manmade/task_specific_props/combat/tarases/taras_a.cgf",                       len = 2.00, up =  0.00, lat =  0.00 },
    { n = "taras_c",       m = "objects/manmade/task_specific_props/combat/tarases/taras_c.cgf",                       len = 2.00, up =  0.00, lat =  0.00 },
    { n = "palisade_high", m = "objects/manmade/structures/defensive/walls/palisade/palisade_wall_a_v3.cgf",           len = 2.75, up = -3.00, lat =  0.00 },
    { n = "pavise_a",      m = "objects/manmade/task_specific_props/combat/pavises/pavise_a.cgf",                      len = 1.00, up =  0.00, lat =  0.00 },
    { n = "pavise_b",      m = "objects/manmade/task_specific_props/combat/pavises/pavise_b.cgf",                      len = 1.00, up =  0.00, lat =  0.00 },
    { n = "stakes",        m = "objects/manmade/structures/defensive/walls/palisade/palisade_wall_single_sharp.cgf",   len = 0.40, up =  0.00, lat =  0.00 },
}
mercenaries.WallTypeIdx = 3      -- the high palisade: the one that worked

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
mercenaries.WallSnap    = true   -- snap each segment to the ground it stands on (follows slopes)

mercenaries.WallMarks = {}       -- { {x,y,z, ent=} } in mark order
mercenaries.WallSegEnts = {}     -- spawned wall segment ids (rebuilt wholesale)
mercenaries.WallClosed = false
mercenaries.WallGateMin = 5.0    -- a corner may come no closer than this to the first one

local function wallType(self)
    return self.WallTypes[self.WallTypeIdx] or self.WallTypes[1]
end

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
function mercenaries:WallSpawnSegment(pos, yaw)
    local params = {
        class = "mercenaries_Prop",
        name = "MercWallSeg_" .. tostring(math.random(100000, 999999)),
        position = pos,
        orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
        properties = { object_Model = wallType(self).m, bMissionCritical = false,
                       bSaved_by_game = false, bSerialize = false },
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
        pcall(function() ent:SetViewDistRatio(255) end)
        pcall(function() ent:SetLodRatio(255) end)
        pcall(function() ent:RenderShadow(true) end)
        table.insert(self.WallSegEnts, ent.id)
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
function mercenaries:WallEdgeSegments(a, b)
    local out = {}
    local dx, dy = b.x - a.x, b.y - a.y
    local L = math.sqrt(dx * dx + dy * dy)
    local step = segLen(self)
    local n = segCount(L, step)
    if n < 1 then return out end
    local ux, uy = dx / L, dy / L
    local yaw = math.atan2(uy, ux) + math.rad(self.WallYawFix or 0)
    -- lateral offset is to the LEFT of a->b
    local lx, ly = -uy * (self.WallLat or 0), ux * (self.WallLat or 0)

    for i = 0, n - 1 do
        local d = step * (i + 0.5)
        local p = { x = a.x + ux * d + lx, y = a.y + uy * d + ly,
                    z = a.z + (b.z - a.z) * (d / L) }
        if self.WallSnap and self.CampSnapToGround then p = self:CampSnapToGround(p) end
        p.z = p.z + (self.WallUp or 0)
        table.insert(out, { pos = p, yaw = yaw })
    end
    return out
end

-- Where the run from a toward b actually stops: a whole number of segments along the
-- line. nil when not even one fits. This is what a corner marker snaps to, so walls
-- always touch the anchors without the spacing ever being stretched.
function mercenaries:WallEdgeEnd(a, b)
    local dx, dy = b.x - a.x, b.y - a.y
    local L = math.sqrt(dx * dx + dy * dy)
    local step = segLen(self)
    if L < step then return nil end
    local n = segCount(L, step)
    local d = n * step
    local p = { x = a.x + (dx / L) * d, y = a.y + (dy / L) * d, z = a.z + (b.z - a.z) * (d / L) }
    if self.CampSnapToGround then p = self:CampSnapToGround(p) end
    return p
end

function mercenaries:WallBuildEdge(a, b)
    local segs = self:WallEdgeSegments(a, b)
    for _, s in ipairs(segs) do self:WallSpawnSegment(s.pos, s.yaw) end
    return #segs
end

function mercenaries:WallClearSegments()
    for _, id in ipairs(self.WallSegEnts or {}) do pcall(function() System.RemoveEntity(id) end) end
    self.WallSegEnts = {}
end

-- Pull every corner back onto a whole multiple of the CURRENT segment length. Corners
-- are snapped when they are marked, but changing the length (or the wall type) after
-- the fact leaves them off-multiple, so the last piece of each edge stops short and
-- the joint at that corner opens up. Walking the chain and re-fitting each corner to
-- its predecessor closes them again. Idempotent: once every edge is an exact multiple
-- a second pass moves nothing. A corner that ends up closer than one segment is
-- dropped, since no wall could reach it.
function mercenaries:WallRefitCorners()
    local m = self.WallMarks
    if #m < 2 then return 0 end
    local out, moved, dropped = { m[1] }, 0, 0
    for i = 2, #m do
        local prev = out[#out]
        local fitted = self:WallEdgeEnd(prev, m[i])
        if fitted then
            local dx, dy = fitted.x - m[i].x, fitted.y - m[i].y
            if (dx * dx + dy * dy) > 1e-6 then moved = moved + 1 end
            fitted.ent = m[i].ent
            if fitted.ent then pcall(function() fitted.ent:SetPos({ x = fitted.x, y = fitted.y, z = fitted.z }) end) end
            table.insert(out, fitted)
        else
            if m[i].ent then pcall(function() System.RemoveEntity(m[i].ent.id) end) end
            dropped = dropped + 1
        end
    end
    self.WallMarks = out
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
    local m = self.WallMarks
    if #m < 3 then return 0 end
    local n, count = #m, 0
    local first, last = 2, n - 1
    if self.WallClosed then first, last = 1, n end
    for i = first, last do
        local prev = m[(i - 2) % n + 1]
        local nxt  = m[i % n + 1]
        local yaw = cornerYaw(prev, m[i], nxt)
        if yaw then
            self:WallSpawnCornerPost(m[i], yaw + math.rad(self.WallYawFix or 0))
            count = count + 1
        end
    end
    return count
end

-- Re-render every edge from the marker list with the current parameters.
function mercenaries:WallRebuild()
    pcall(function() if self.WallTouched then self:WallTouched() end end)
    self:WallClearSegments()
    self:WallRefitCorners()
    local m = self.WallMarks
    if #m < 2 then System.LogAlways("[Wall] mark at least two corners (merc_wall_mark)"); return end
    local total = 0
    for i = 1, #m - 1 do total = total + self:WallBuildEdge(m[i], m[i + 1]) end
    if self.WallClosed and #m > 2 then total = total + self:WallBuildEdge(m[#m], m[1]) end
    total = total + self:WallBuildCornerPosts()
    System.LogAlways(string.format("[Wall] %s: %d corners%s, %d segments (len %.2f, yaw+%d, up %.2f, lat %.2f)",
        wallType(self).n, #m, self.WallClosed and " closed" or "", total,
        segLen(self), self.WallYawFix or 0, self.WallUp or 0, self.WallLat or 0))
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

-- Mark a corner where you are looking; the edge from the previous corner fills in.
-- The corner SNAPS to the end of the last whole segment rather than sitting at the
-- raw cursor, so the wall touches it and the next edge carries on from there with the
-- spacing unchanged. Anything the cursor was reaching past that is cut off.
function mercenaries:WallMark()
    local pos = self:TowerLookedAtPos()
    if not pos then Game.SendInfoText('merc_info_tower_aim', false, 0, 3); return end
    if self.CampSnapToGround then pos = self:CampSnapToGround(pos) end

    local prev = self.WallMarks[#self.WallMarks]
    if prev then
        local fitted = self:WallEdgeEnd(prev, pos)
        if not fitted then
            System.LogAlways("[Wall] too close to the last corner for a segment")
            return
        end
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

    local mk = { x = pos.x, y = pos.y, z = pos.z }
    mk.ent = self:WallSpawnMarker(mk)
    table.insert(self.WallMarks, mk)
    -- The first corner has no wall attached to it yet, so without this there is nothing
    -- on screen to show where the run began (or where to close the ring back to). The
    -- marker stands until the wall is finished or cleared.
    if not prev then self:WallSpawnStartMarker(mk) end
    pcall(function() if self.WallTouched then self:WallTouched() end end)
    if prev then self:WallBuildEdge(prev, mk) end
    -- the corner just became interior (it now has a wall either side), so post it
    local m = self.WallMarks
    if self.WallPosts and #m >= 3 then
        local yaw = cornerYaw(m[#m - 2], m[#m - 1], m[#m])
        if yaw then self:WallSpawnCornerPost(m[#m - 1], yaw + math.rad(self.WallYawFix or 0)) end
    end
    System.LogAlways("[Wall] corner " .. #self.WallMarks .. " marked")
end

function mercenaries:WallCloseRing()
    if #self.WallMarks < 3 then System.LogAlways("[Wall] need three corners to close"); return end
    self.WallClosed = true
    self:WallRebuild()
end

function mercenaries:WallUndo()
    pcall(function() if self.WallTouched then self:WallTouched() end end)
    local m = self.WallMarks
    if #m == 0 then return end
    if #m == 1 then self:WallClearStartMarker() end
    local last = table.remove(m)
    if last.ent then pcall(function() System.RemoveEntity(last.ent.id) end) end
    self.WallClosed = false
    self:WallRebuild()
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

function mercenaries:WallPreviewClear()
    for _, id in ipairs(self.WallPreviewEnts or {}) do pcall(function() System.RemoveEntity(id) end) end
    self.WallPreviewEnts = {}
end

-- Keep exactly `n` white preview pieces alive (pool, so no per-tick respawn flicker).
function mercenaries:WallPreviewResize(n)
    local ents = self.WallPreviewEnts
    while #ents > n do
        local id = table.remove(ents)
        pcall(function() System.RemoveEntity(id) end)
    end
    while #ents < n do
        local e
        pcall(function()
            e = System.SpawnEntity({
                class = "BasicEntity",
                name = "MercWallGhost_" .. tostring(math.random(100000, 999999)),
                position = { x = 0, y = 0, z = -1000 },
                properties = { object_Model = wallType(self).m, bMissionCritical = false,
                               bSaved_by_game = false, bSerialize = false },
            })
        end)
        if not e then break end
        -- NO material override: the palisade mesh is multi-submaterial, and a single
        -- white .mtl only maps onto slot 0 - which is why the preview showed just the
        -- stake tops, and why distant pieces (whose LOD meshes map materials
        -- differently) dropped out entirely. Keeping the mesh's own materials renders
        -- all of it at every distance. See the ghost/submaterial note in
        -- mercenaries_tower.lua.
        pcall(function() e:SetViewDistUnlimited() end)
        pcall(function() e:SetViewDistRatio(255) end)
        pcall(function() e:SetLodRatio(255) end)
        table.insert(ents, e.id)
    end
end

function mercenaries.WallBuildTick()
    local self = mercenaries
    if not self.WallBuildActive then return end
    pcall(function()
        local segs = {}
        local pos = self:TowerLookedAtPos()
        if pos and #self.WallMarks > 0 then
            if self.CampSnapToGround then pos = self:CampSnapToGround(pos) end
            segs = self:WallEdgeSegments(self.WallMarks[#self.WallMarks], pos)
        end
        self:WallPreviewResize(#segs)
        for i, s in ipairs(segs) do
            local id = self.WallPreviewEnts[i]
            local e = id and System.GetEntity(id)
            if e then
                pcall(function() e:SetPos(s.pos) end)
                pcall(function() e:SetAngles({ x = 0, y = 0, z = s.yaw }) end)
            end
        end
    end)
    Script.SetTimerForFunction(100, "mercenaries.WallBuildTick")
end

function mercenaries:StartWallBuild()
    if self.WallBuildActive then System.LogAlways("[Wall] already building"); return end
    -- Starting a new wall replaces the old one. Marking onto an existing run would
    -- join the two into one impossible polygon, and the player has paid for a wall,
    -- not for a second lap of the one he has.
    if self.WallMarks and #self.WallMarks > 0 then
        self:WallClearAll()
        Game.SendInfoText('merc_info_wall_replaced', false, 0, 4)
        System.LogAlways("[Wall] previous wall taken down")
    end
    self.WallBuildActive = true
    Game.SendInfoText('merc_info_wall_building', false, 0, 5)
    Script.SetTimerForFunction(100, "mercenaries.WallBuildTick")
end

-- Leaves build mode. Walls and corner markers stay (merc_wall_close still works;
-- merc_wall_done takes the barrels away, merc_wall_clear removes everything).
function mercenaries:EndWallBuild()
    if not self.WallBuildActive then return end
    self.WallBuildActive = false
    self:WallPreviewClear()
    -- a wall now exists: re-cut the guards' route along it and arm the backstop
    pcall(function() if self.NavRefreshPatrolRings then self:NavRefreshPatrolRings() end end)
    pcall(function() if self.WBStart then self:WBStart() end end)
    self:WallClearStartMarker()
    pcall(function() if self.DefSave then self:DefSave() end end)
    Game.SendInfoText('merc_info_wall_done', false, 0, 3)
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
    self:WallPreviewClear()          -- pool holds the old mesh; let it respawn
    self:WallRebuild()
end

function mercenaries:WallSetLen(v)   self.WallSegLen = tonumber(v); self:WallRebuild() end
function mercenaries:WallSetYaw(v)   self.WallYawFix = tonumber(v) or 0; self:WallRebuild() end
function mercenaries:WallSetUp(v)    self.WallUp     = tonumber(v) or 0; self:WallRebuild() end
function mercenaries:WallSetLat(v)   self.WallLat    = tonumber(v) or 0; self:WallRebuild() end
function mercenaries:WallSetSnap(v)  self.WallSnap   = (tonumber(v) ~= 0); self:WallRebuild() end
function mercenaries:WallSetPosts(v) self.WallPosts  = (tonumber(v) ~= 0); self:WallRebuild() end

function mercenaries:WallHelp()
    local lines = {
        "===== Wall builder =====",
        "merc_wall_mark      drop a corner where you look (edge to the previous corner fills in)",
        "merc_wall_close     join the last corner back to the first (needs 3+)",
        "merc_wall_undo      remove the last corner",
        "merc_wall_markers <01>  show the corner barrels while tuning (off by default)",
        "merc_wall_clear     remove walls and markers",
        "merc_wall_type <n>  wall mesh (no arg lists them; 3 = high palisade)",
        "merc_wall_len <m>   segment spacing - slightly under the mesh length to overlap",
        "merc_wall_yaw <deg> segment yaw fix (try 90 if pieces run across the edge)",
        "merc_wall_up <m>    height offset (negative sinks them)",
        "merc_wall_lat <m>   sideways offset from the edge line",
        "merc_wall_snap <01> follow the ground under each segment (default 1)",
        "merc_wall_rebuild   re-render with the current settings",
    }
    for _, l in ipairs(lines) do System.LogAlways(l) end
end

-- %line, not %1: AddCCommand does not substitute %1 into the body, it passes the
-- literal "%1" (see the CCommand arg-substitution note).
System.AddCCommand("merc_wall_help",    "mercenaries:WallHelp()",          "List the wall-builder commands")
System.AddCCommand("merc_wall_build",   "mercenaries:StartWallBuild()",    "Start building: left-click marks a corner, right-click finishes")
System.AddCCommand("merc_wall_stop",    "mercenaries:EndWallBuild()",      "Leave wall build mode (normally right-click)")
System.AddCCommand("merc_wall_mark",    "mercenaries:WallMark()",          "Mark a wall corner where you look (normally left-click)")
System.AddCCommand("merc_wall_close",   "mercenaries:WallCloseRing()",     "Close the polygon (last corner back to the first)")
System.AddCCommand("merc_wall_undo",    "mercenaries:WallUndo()",          "Remove the last corner")
System.AddCCommand("merc_wall_done",    "mercenaries:WallHideMarkers()",   "Remove the marker barrels, keep the walls")
System.AddCCommand("merc_wall_clear",   "mercenaries:WallClearAll()",      "Remove all walls and markers")
System.AddCCommand("merc_wall_rebuild", "mercenaries:WallRebuild()",       "Re-render the walls with the current settings")
System.AddCCommand("merc_wall_type",    "mercenaries:WallSetType(%line)",  "Wall mesh: merc_wall_type <n> (no arg lists them)")
System.AddCCommand("merc_wall_len",     "mercenaries:WallSetLen(%line)",   "Segment spacing in metres")
System.AddCCommand("merc_wall_yaw",     "mercenaries:WallSetYaw(%line)",   "Segment yaw fix in degrees (try 90)")
System.AddCCommand("merc_wall_up",      "mercenaries:WallSetUp(%line)",    "Height offset in metres (negative sinks)")
System.AddCCommand("merc_wall_lat",     "mercenaries:WallSetLat(%line)",   "Sideways offset from the edge line")
System.AddCCommand("merc_wall_snap",    "mercenaries:WallSetSnap(%line)",  "Follow ground under each segment: 0 or 1")
System.AddCCommand("merc_wall_markers", "mercenaries:WallSetMarkers(%line)","Show the corner barrels while tuning: 0 or 1")
System.AddCCommand("merc_wall_posts",   "mercenaries:WallSetPosts(%line)", "Corner posts bridging the joint: 0 or 1")
