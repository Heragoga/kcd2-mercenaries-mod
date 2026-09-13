-- Camp navmesh: a small node graph laid over the camp so mod NPCs can walk AROUND
-- camp walls, which the engine's own baked navmesh knows nothing about.
--
-- Deliberately narrow. It is only consulted when a straight line from an NPC to its
-- target crosses one of our wall lines, and only near camp; everywhere else the
-- engine paths as it always has. That keeps the interrupt churn (and the risk of
-- behaviour-tree restart thrash) to the one situation this exists for.
--
-- Wall geometry comes from the wall builder's CORNERS (WallAllRuns), not
-- from the individual segment props: the corners are the authoritative line, so
-- blocking is exact 2D segment intersection - no raycasts, no navmesh introspection.
-- See docs/walls-and-sieges.md.

mercenaries.NavSpacing      = 2.5     -- node grid step
mercenaries.NavRadius       = 35.0    -- graph covers this far around the camp centre
mercenaries.NavActiveRadius = 60.0    -- outside this of camp, the system stays out of the way
mercenaries.NavGraph        = nil     -- { nodes = {{x,y,z}}, adj = { [i] = {j,...} }, center =, spacing = }
mercenaries.NavDebugEnts    = {}

-- Logging on the hot path is a synchronous write; with 30 NPCs steering every tick it
-- alone can cost more than the pathfinding. merc_nav_debug 1 turns it back on.
mercenaries.NavDebug = false
local function navLog(s) if mercenaries.NavDebug then System.LogAlways("[Nav] " .. s) end end
local function navSay(s) System.LogAlways("[Nav] " .. s) end   -- always, for explicit commands

-- ==== wall geometry ====
-- Rebuilt only when the wall actually changes (WallTouched bumps the version), and
-- carries a bounding box so NavIsBlocked can reject far-away segments with six float
-- compares instead of a full intersection scan.
mercenaries.WallVersion = 0
mercenaries.NavWallCache = nil

function mercenaries:WallTouched()
    self.WallVersion = (self.WallVersion or 0) + 1
    self.NavWallCache = nil
    self.NavGraphWallVersion = nil     -- graph edges were cut against the old wall
end

function mercenaries:NavWallSegments()
    local c = self.NavWallCache
    if c and c.version == self.WallVersion then return c.segs, c.box end

    local segs = {}
    local minx, miny, maxx, maxy
    local function acc(x, y)
        if not minx or x < minx then minx = x end
        if not maxx or x > maxx then maxx = x end
        if not miny or y < miny then miny = y end
        if not maxy or y > maxy then maxy = y end
    end
    -- Every stretch the camp has, flattened: a blocking segment is a blocking segment
    -- whichever run it came from, and the gap sweep works off these rather than off any
    -- one corner list.
    for _, r in ipairs(self:WallAllRuns()) do
        local m = r.pts
        for i = 1, #m - 1 do
            table.insert(segs, { ax = m[i].x, ay = m[i].y, bx = m[i + 1].x, by = m[i + 1].y })
            acc(m[i].x, m[i].y); acc(m[i + 1].x, m[i + 1].y)
        end
        if r.closed and #m > 2 then
            table.insert(segs, { ax = m[#m].x, ay = m[#m].y, bx = m[1].x, by = m[1].y })
        end
    end
    -- A shut gate blocks like wall; an open one contributes nothing and the gap sweep
    -- finds its opening again. This is what makes shutting the gates actually seal the
    -- camp rather than just change a mesh.
    for _, g in ipairs((self.GateBlockSegments and self:GateBlockSegments()) or {}) do
        table.insert(segs, g)
        acc(g.ax, g.ay); acc(g.bx, g.by)
    end
    local box = minx and { minx = minx, miny = miny, maxx = maxx, maxy = maxy } or nil
    self.NavWallCache = { version = self.WallVersion, segs = segs, box = box }
    return segs, box
end

local function ccw(ax, ay, bx, by, cx, cy)
    return (cy - ay) * (bx - ax) > (by - ay) * (cx - ax)
end

-- Do segments p1p2 and p3p4 cross? Standard orientation test; touching endpoints are
-- not treated specially, which is fine here because nodes never sit exactly on a wall.
local function segsCross(x1, y1, x2, y2, x3, y3, x4, y4)
    return ccw(x1, y1, x3, y3, x4, y4) ~= ccw(x2, y2, x3, y3, x4, y4)
       and ccw(x1, y1, x2, y2, x3, y3) ~= ccw(x1, y1, x2, y2, x4, y4)
end

-- How close a route may come to a wall. Without this, paths scrape along the palisade
-- and the slightest steering error puts someone inside it. Gap detection deliberately
-- passes 0 so a narrow gateway is not sealed shut by the margin.
mercenaries.NavBlockMargin = 1.8

local function pointSegDist(px, py, ax, ay, bx, by)
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

-- Is the straight line a->b interrupted by a wall? This is the whole gate: false and
-- nothing in this file is used. `marginOverride` of 0 gives the exact geometric test.
function mercenaries:NavIsBlocked(a, b, marginOverride)
    if not (a and b) then return false end
    local segs, box = self:NavWallSegments()
    if #segs == 0 then return false end
    local margin = marginOverride or self.NavBlockMargin or 0
    -- cheap reject: the leg's bounding box misses the wall's entirely
    if box then
        local lx1, lx2 = a.x, b.x; if lx1 > lx2 then lx1, lx2 = lx2, lx1 end
        local ly1, ly2 = a.y, b.y; if ly1 > ly2 then ly1, ly2 = ly2, ly1 end
        if lx2 < box.minx or lx1 > box.maxx or ly2 < box.miny or ly1 > box.maxy then return false end
    end
    for i = 1, #segs do
        local w = segs[i]
        if segsCross(a.x, a.y, b.x, b.y, w.ax, w.ay, w.bx, w.by) then return true end
        if margin > 0 then
            -- endpoint clearance: cheap stand-in for full segment-to-segment distance,
            -- and enough to stop routes hugging the wall
            if pointSegDist(a.x, a.y, w.ax, w.ay, w.bx, w.by) < margin then return true end
            if pointSegDist(b.x, b.y, w.ax, w.ay, w.bx, w.by) < margin then return true end
        end
    end
    return false
end

-- ==== camp obstacles ====
-- Tents, the player's hut and the fire: solid to look at, walk-through to the engine,
-- and deliberately NOT part of the A* graph. A camp packs its tents onto a 3.9m ring
-- (CampTentRingRadius), so cutting graph edges against them seals the fire circle off
-- and every route inside camp comes back NO ROUTE - which beelines, i.e. exactly the
-- clipping this exists to stop. An obstacle is therefore a purely LOCAL correction to
-- the point an NPC is already steering at, applied in NavSteerPoint. It never enters
-- NavIsBlocked, the graph, the gap sweep or the targeting test: the wall keeps those.
--
-- Footprints use the camp builder's own frame (see CampFootprintStats): `half.w` is the
-- half-extent ACROSS the facing, `half.h` the half-extent ALONG it.
mercenaries.NavObstacles     = {}
mercenaries.NavObsClearance  = 0.45   -- how far outside a footprint a route is aimed
mercenaries.NavObsRange      = 16.0   -- obstacles further than this from the walker are ignored
mercenaries.NavObsMaxHops    = 3      -- corners rounded per steering tick before giving up
mercenaries.NavObsCornerMin  = 0.60   -- a corner nearer than this is one he is already on
mercenaries.NavObsGiveUpSecs = 9.0    -- rounding this long with no progress means no way round
mercenaries.NavObsMuteSecs   = 6.0    -- then walk straight for this long
mercenaries.NavObsProgress   = 0.5    -- metres nearer the target that count as progress

function mercenaries:NavAddObstacle(pos, angle, half, tag)
    if not (pos and half) then return nil end
    local w = math.max(tonumber(half.w) or 0, 0.1)
    local h = math.max(tonumber(half.h) or 0, 0.1)
    local o = { x = pos.x, y = pos.y, z = pos.z or 0, a = tonumber(angle) or 0,
                w = w, h = h, tag = tag or "camp" }
    table.insert(self.NavObstacles, o)
    return o
end

-- No tag clears the lot. Obstacles are rebuilt with the camp, never saved.
function mercenaries:NavClearObstacles(tag)
    if not tag then self.NavObstacles = {}; return end
    local keep = {}
    for _, o in ipairs(self.NavObstacles or {}) do
        if o.tag ~= tag then table.insert(keep, o) end
    end
    self.NavObstacles = keep
end

function mercenaries:NavHasObstacles()
    return #(self.NavObstacles or {}) > 0
end

-- A world point in the obstacle's own frame: `across` along its right, `along` its facing.
local function obsLocal(o, px, py)
    local c, s = math.cos(o.a), math.sin(o.a)
    local dx, dy = px - o.x, py - o.y
    return (-s * dx + c * dy), (c * dx + s * dy)
end

-- Liang-Barsky: does the local-frame segment touch the box of half-extents hw x hh?
local function segHitsBox(u1, v1, u2, v2, hw, hh)
    if (math.abs(u1) <= hw and math.abs(v1) <= hh)
    or (math.abs(u2) <= hw and math.abs(v2) <= hh) then return true end
    local du, dv = u2 - u1, v2 - v1
    local t0, t1 = 0.0, 1.0
    local function clip(p, q)
        if math.abs(p) < 1e-9 then return q >= 0 end
        local r = q / p
        if p < 0 then
            if r > t1 then return false end
            if r > t0 then t0 = r end
        else
            if r < t0 then return false end
            if r < t1 then t1 = r end
        end
        return true
    end
    if not clip(-du, u1 + hw) then return false end
    if not clip( du, hw - u1) then return false end
    if not clip(-dv, v1 + hh) then return false end
    if not clip( dv, hh - v1) then return false end
    return t0 <= t1
end

-- The padded footprint's four corners, world space.
local function obsCorners(o, pad)
    local c, s = math.cos(o.a), math.sin(o.a)
    local w, h = o.w + pad, o.h + pad
    local out = {}
    for _, q in ipairs({ { w, h }, { -w, h }, { -w, -h }, { w, -h } }) do
        out[#out + 1] = { x = o.x + (-s) * q[1] + c * q[2],
                          y = o.y + ( c) * q[1] + s * q[2],
                          z = o.z }
    end
    return out
end

-- The nearest obstacle standing between a and b, or nil. One distance compare per
-- obstacle rejects the whole camp when the walker is elsewhere, which is the usual case.
function mercenaries:NavObstacleHit(a, b, pad)
    local obs = self.NavObstacles
    if not (a and b and obs and #obs > 0) then return nil end
    pad = pad or self.NavObsClearance
    local range2 = (self.NavObsRange or 16.0) ^ 2
    local best, bestD2
    for i = 1, #obs do
        local o = obs[i]
        local dx, dy = o.x - a.x, o.y - a.y
        local d2 = dx * dx + dy * dy
        if d2 <= range2 and (not bestD2 or d2 < bestD2) then
            local au, av = obsLocal(o, a.x, a.y)
            -- Already standing IN it (spawned inside his own tent, sitting at the fire):
            -- deflecting a man who is inside only pushes him deeper, so he is let walk
            -- straight out. The test is the RAW footprint, not the padded one - a man
            -- merely inside the clearance margin must still be steered, or brushing a
            -- corner switches avoidance off exactly where it is needed.
            if math.abs(au) > o.w or math.abs(av) > o.h then
                local bu, bv = obsLocal(o, b.x, b.y)
                if segHitsBox(au, av, bu, bv, o.w + pad, o.h + pad) then
                    best, bestD2 = o, d2
                end
            end
        end
    end
    return best
end

function mercenaries:NavObstacleBlocks(a, b)
    return self:NavObstacleHit(a, b) ~= nil
end

-- Wall OR camp obstacle. Kept apart from NavIsBlocked on purpose: "is a wall in the
-- way" drives the graph, the gap sweep and targeting, and none of those want tents.
function mercenaries:NavPathBlocked(a, b, marginOverride)
    if self:NavIsBlocked(a, b, marginOverride) then return true end
    return self:NavObstacleBlocks(a, b)
end

-- Round whatever stands between `me` and `p`: hop to a corner of the box in the way,
-- re-test, up to NavObsMaxHops times. Corners sit a fifth further out than the test box,
-- so the one just chosen is strictly outside it and the next hop cannot pick it again.
-- Returns `p` itself when nothing is in the way, which is the common case.
--
-- THE SIDE IS LATCHED (rec.obsSide, keyed by obstacle) until that obstacle stops
-- blocking. Choosing afresh every tick makes him alternate between the two near corners
-- and walk on the spot, because the cheapest corner is always the one he just left.
--
-- Corners are tried FAR first: aiming at the far one skims the side of the tent and
-- comes out past it, and the near one is the fallback that gets him clear of the box's
-- slab so the far one becomes reachable on the next tick.
function mercenaries:NavAvoidPoint(rec, me, p)
    if not (me and p) or #(self.NavObstacles or {}) == 0 then return p end
    local pad  = self.NavObsClearance or 0.45
    local cmin = self.NavObsCornerMin or 0.60
    local sides
    if rec then rec.obsSide = rec.obsSide or {}; sides = rec.obsSide end
    local seen = {}
    local aim = p

    for _ = 1, (self.NavObsMaxHops or 3) do
        local o = self:NavObstacleHit(me, aim, pad)
        if not o then break end
        seen[o] = true

        local dx, dy = aim.x - me.x, aim.y - me.y
        local L = math.sqrt(dx * dx + dy * dy)
        if L < 1e-6 then break end
        local dirx, diry = dx / L, dy / L
        local perpx, perpy = -diry, dirx

        local cand = {}
        for _, c in ipairs(obsCorners(o, pad * 1.2)) do
            local ex, ey = c.x - me.x, c.y - me.y
            table.insert(cand, { lat = ex * perpx + ey * perpy,
                                 along = ex * dirx + ey * diry, p = c })
        end

        local side = sides and sides[o]
        if not side then
            local latMax, latMin = cand[1].lat, cand[1].lat
            for _, e in ipairs(cand) do
                if e.lat > latMax then latMax = e.lat end
                if e.lat < latMin then latMin = e.lat end
            end
            side = (math.abs(latMax) <= math.abs(latMin)) and 1 or -1
            if sides then sides[o] = side end
        end

        local onSide = {}
        for _, e in ipairs(cand) do
            if (side > 0 and e.lat >= 0) or (side < 0 and e.lat <= 0) then
                table.insert(onSide, e)
            end
        end
        if #onSide == 0 then onSide = cand end
        table.sort(onSide, function(x, y) return x.along > y.along end)

        local mu, mv = obsLocal(o, me.x, me.y)
        local pick
        for _, e in ipairs(onSide) do
            local cu, cv = obsLocal(o, e.p.x, e.p.y)
            if not segHitsBox(mu, mv, cu, cv, o.w + pad, o.h + pad) then pick = e.p; break end
        end
        if not pick then break end

        -- Standing on the corner he just rounded, aiming at it is a zero-length step and
        -- he stops there. Keep the direction - it points out of the box's slab - and push
        -- the aim out to cmin, so the far corner comes into view on the next tick.
        local pdx, pdy = pick.x - me.x, pick.y - me.y
        local pd = math.sqrt(pdx * pdx + pdy * pdy)
        if pd < cmin then
            if pd < 1e-6 then break end
            pick = { x = me.x + pdx / pd * cmin, y = me.y + pdy / pd * cmin, z = pick.z }
        end
        aim = pick
    end

    if sides then
        for o in pairs(sides) do if not seen[o] then sides[o] = nil end end
    end
    -- A tent is never a reason to cross a WALL. The wall is the graph's business and a
    -- deflection that put him on the far side of one would undo it.
    if aim ~= p and self:NavIsBlocked(me, aim) then return p end
    return aim
end

-- Avoidance plus the give-up that keeps it honest. Local rounding cannot find a gap on
-- the far side of a ring of tents, and a man who circles one for ever looks worse than a
-- man who clips it - so deflection that gains no ground stands the layer down for a few
-- seconds and lets him walk.
function mercenaries:NavAvoidSteer(rec, me, tp)
    if not rec then return self:NavAvoidPoint(nil, me, tp) end
    local now = 0
    pcall(function() now = System.GetCurrTime() or 0 end)
    if rec.obsMuteUntil and now < rec.obsMuteUntil then return tp end

    local aim = self:NavAvoidPoint(rec, me, tp)
    if aim == tp then
        rec.obsBest, rec.obsSince = nil, nil
        return tp
    end

    local d = math.sqrt((tp.x - me.x) ^ 2 + (tp.y - me.y) ^ 2)
    if (not rec.obsBest) or d < (rec.obsBest - (self.NavObsProgress or 0.5)) then
        rec.obsBest, rec.obsSince = d, now
    elseif rec.obsSince and (now - rec.obsSince) > (self.NavObsGiveUpSecs or 9.0) then
        rec.obsMuteUntil = now + (self.NavObsMuteSecs or 6.0)
        rec.obsBest, rec.obsSince = nil, nil
        navLog("obstacle detour got nowhere; walking straight for a bit")
        return tp
    end
    return aim
end

-- ==== graph ====
function mercenaries:NavBuild(radius, spacing)
    local center = self.CampCenter
    if not center then navLog("no camp - nothing to build around"); return false end
    radius  = tonumber(radius)  or self.NavRadius
    spacing = tonumber(spacing) or self.NavSpacing
    -- grow to clear the wall, plus room to walk around the outside of it
    local need = self:NavWallExtent() + 3 * spacing + 6.0
    if need > radius then
        radius = need
        navLog(string.format("graph grown to %.0fm to clear the wall", radius))
    end

    -- Every node below pays a CampSnapToGround raycast, and the radius grows with the wall,
    -- so this is quadratic in camp size. It is rebuilt whenever WallTouched() fires - which
    -- includes any gate change, and GateWatchdog re-hangs gates on a 5 s tick. Count it, so a
    -- rebuild storm shows up in the log instead of being inferred.
    local t0 = 0
    pcall(function() t0 = System.GetCurrTime() or 0 end)
    self.NavBuildCount = (self.NavBuildCount or 0) + 1

    local nodes, index = {}, {}
    local steps = math.floor(radius / spacing)
    for gx = -steps, steps do
        for gy = -steps, steps do
            local x, y = center.x + gx * spacing, center.y + gy * spacing
            local dx, dy = x - center.x, y - center.y
            if (dx * dx + dy * dy) <= (radius * radius) then
                local p = { x = x, y = y, z = center.z }
                if self.CampSnapToGround then p = self:CampSnapToGround(p) end
                table.insert(nodes, p)
                index[gx .. "," .. gy] = #nodes
            end
        end
    end

    -- 8-way neighbours, minus any edge that crosses a wall
    local adj, edges, blocked = {}, 0, 0
    for gx = -steps, steps do
        for gy = -steps, steps do
            local i = index[gx .. "," .. gy]
            if i then
                adj[i] = adj[i] or {}
                for _, d in ipairs({ {1,0}, {0,1}, {1,1}, {1,-1} }) do
                    local j = index[(gx + d[1]) .. "," .. (gy + d[2])]
                    if j then
                        if self:NavIsBlocked(nodes[i], nodes[j]) then
                            blocked = blocked + 1
                        else
                            adj[i] = adj[i] or {}; adj[j] = adj[j] or {}
                            table.insert(adj[i], j)
                            table.insert(adj[j], i)
                            edges = edges + 1
                        end
                    end
                end
            end
        end
    end

    self.NavGraph = { nodes = nodes, adj = adj, center = center, spacing = spacing, radius = radius }
    self.NavGraphWallVersion = self.WallVersion
    local t1 = 0
    pcall(function() t1 = System.GetCurrTime() or 0 end)
    System.LogAlways(string.format(
        "[Nav] graph build #%d: %d node(s) (one ground raycast each), radius %.0fm, %.0fms",
        self.NavBuildCount or 0, #nodes, radius, (t1 - t0) * 1000))
    navLog(string.format("graph built: %d nodes, %d edges, %d edges cut by walls (%.0fm radius, %.1fm spacing)",
        #nodes, edges, blocked, radius, spacing))
    return true
end

-- Rebuild after the wall changes; cheap enough to just redo the whole thing.
function mercenaries:NavRebuildIfNeeded()
    if self.CampActive and self.CampCenter then self:NavBuild() end
end

function mercenaries:NavNearestNode(p)
    local g = self.NavGraph
    if not (g and p) then return nil end
    local best, bestD2
    for i, n in ipairs(g.nodes) do
        local dx, dy = n.x - p.x, n.y - p.y
        local d2 = dx * dx + dy * dy
        if not bestD2 or d2 < bestD2 then best, bestD2 = i, d2 end
    end
    return best
end

-- The nearest node that can actually be walked to in a straight line. Plain "nearest"
-- is wrong as soon as the wall is not a simple ring: standing just outside a corner,
-- the closest grid node is often on the FAR side of the wall, so the route began by
-- stepping straight through it. Falls back to the nearest node when nothing is
-- visible (better a rough route than none).
-- Single pass, no allocation: track the nearest node overall and the nearest VISIBLE
-- one, only paying for a visibility test when a node is closer than the best visible
-- so far. The earlier version built and sorted a table of every node on each call,
-- which is fine for a debug command and far too costly once dozens of NPCs steer with it.
function mercenaries:NavNearestVisibleNode(p)
    local g = self.NavGraph
    if not (g and p) then return nil end
    local nodes = g.nodes
    local bestAny, bestAnyD2, bestVis, bestVisD2
    for i = 1, #nodes do
        local n = nodes[i]
        local dx, dy = n.x - p.x, n.y - p.y
        local d2 = dx * dx + dy * dy
        if not bestAnyD2 or d2 < bestAnyD2 then bestAny, bestAnyD2 = i, d2 end
        if (not bestVisD2 or d2 < bestVisD2) and not self:NavIsBlocked(p, n) then
            bestVis, bestVisD2 = i, d2
        end
    end
    if bestVis then return bestVis, true end
    return bestAny, false
end

-- How far the wall reaches from the camp centre; the graph must cover it or a route
-- around a large enclosure has nowhere to go.
function mercenaries:NavWallExtent()
    local c = self.CampCenter
    if not c then return 0 end
    local far = 0
    for _, m in ipairs(self:WallAllPoints()) do
        local dx, dy = m.x - c.x, m.y - c.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d > far then far = d end
    end
    return far
end

-- ==== A* ====
local function dist(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

function mercenaries:NavAStar(startIdx, goalIdx)
    local g = self.NavGraph
    if not (g and startIdx and goalIdx) then return nil end
    if startIdx == goalIdx then return { startIdx } end
    local nodes, adj = g.nodes, g.adj
    local goal = nodes[goalIdx]

    local open      = { [startIdx] = true }
    local cameFrom  = {}
    local gScore    = { [startIdx] = 0 }
    local fScore    = { [startIdx] = dist(nodes[startIdx], goal) }

    -- linear open-set scan: the graph is small (~800 nodes) and this runs on demand,
    -- not per tick, so a heap is not worth the complexity here
    while true do
        local cur, curF
        for i in pairs(open) do
            local f = fScore[i] or math.huge
            if not curF or f < curF then cur, curF = i, f end
        end
        if not cur then return nil end                     -- exhausted: no route
        if cur == goalIdx then
            local path = { cur }
            while cameFrom[cur] do cur = cameFrom[cur]; table.insert(path, 1, cur) end
            return path
        end
        open[cur] = nil
        for _, nb in ipairs(adj[cur] or {}) do
            local tentative = (gScore[cur] or math.huge) + dist(nodes[cur], nodes[nb])
            if tentative < (gScore[nb] or math.huge) then
                cameFrom[nb] = cur
                gScore[nb]   = tentative
                fScore[nb]   = tentative + dist(nodes[nb], goal)
                open[nb]     = true
            end
        end
    end
end

-- Drop every node that can be skipped without crossing a wall, so he runs a few long
-- legs instead of many short ones - fewer corners, far less stop-go.
--
-- Two bugs here broke every non-circular wall. The scan used to fall through to pts[i]
-- even when that leg was itself blocked, inserting a leg straight through the wall; it
-- now keeps the last node it can actually see and lets the next pass continue from
-- there. It also used to delete the final node whenever the target was visible from it,
-- which silently handed the approach to the node BEFORE it - and that one often cannot
-- see the target at all.
function mercenaries:NavStringPull(from, pts)
    local out = {}
    local anchor = from
    local i = 1
    while i <= #pts do
        local pick = nil
        for j = #pts, i, -1 do
            if not self:NavPathBlocked(anchor, pts[j]) then pick = j; break end
        end
        if not pick then
            -- nothing from here is directly visible; step one node along the A* path,
            -- which is reachable by construction, and re-anchor there
            pick = i
        end
        table.insert(out, pts[pick])
        anchor = pts[pick]
        i = pick + 1
    end
    return out
end

-- Sanity check: no leg of the finished route may cross a wall or a camp footprint.
function mercenaries:NavValidatePath(from, path)
    local prev, bad = from, 0
    for _, p in ipairs(path or {}) do
        if self:NavPathBlocked(prev, p) then bad = bad + 1 end
        prev = p
    end
    return bad
end

-- THE ENTRY POINT. Returns a list of waypoints from `fromPos` to `toPos` that avoids
-- the walls, or nil when the direct line is already clear / the system does not apply.
function mercenaries:NavPathAround(fromPos, toPos)
    if not (fromPos and toPos) then return nil end
    if not self:NavIsBlocked(fromPos, toPos) then return nil end     -- no wall in the way
    local c = self.CampCenter
    if not c then return nil end
    -- Near camp by EITHER end: a man 70m out walking to a muster point 20m from the
    -- centre still has to route round the wall, and testing only where he stands now
    -- left him beelining at it until he happened to cross the radius.
    local d1 = (fromPos.x - c.x) ^ 2 + (fromPos.y - c.y) ^ 2
    local d2 = (toPos.x - c.x) ^ 2 + (toPos.y - c.y) ^ 2
    if math.min(d1, d2) > (self.NavActiveRadius * self.NavActiveRadius) then return nil end

    -- Rebuild when there is no graph, or the wall changed since it was cut.
    if (not self.NavGraph) or (self.NavGraphWallVersion ~= self.WallVersion) then self:NavBuild() end
    local g = self.NavGraph
    if not g then return nil end

    -- Both ends must be entered from a node on the RIGHT side of the wall, or the route
    -- starts or finishes by walking through it.
    local s, sVis = self:NavNearestVisibleNode(fromPos)
    local e, eVis = self:NavNearestVisibleNode(toPos)
    if not (s and e) then navLog("no usable start/goal node"); return nil end
    if not sVis then navLog("warning: no node visible from the start") end
    if not eVis then navLog("warning: no node visible from the target") end

    local idxPath = self:NavAStar(s, e)
    if not idxPath then
        navLog("A* found no route - the wall may fully enclose one side (no gate?)")
        return nil
    end

    local pts = {}
    for _, i in ipairs(idxPath) do table.insert(pts, g.nodes[i]) end
    pts = self:NavStringPull(fromPos, pts)
    table.insert(pts, { x = toPos.x, y = toPos.y, z = toPos.z })

    local bad = self:NavValidatePath(fromPos, pts)
    if bad > 0 then navLog("warning: " .. bad .. " leg(s) still cross a wall") end
    return pts
end

-- ==== runtime: wall-aware approach (nav_goto.xml) ====
-- Corner smoothing values are the ones tuned in play with merc_wp_radius.
mercenaries.NavSwitchR   = 7.0    -- swap to the next leg this far out (wide = smooth corners)
mercenaries.NavArriveR   = 2.0    -- close enough to the final target
mercenaries.NavRecalcMove = 3.0   -- target must move this far before the route is redone
mercenaries.NavGoto = {}          -- [entKey] = { target =, targetPos =, path =, idx =, lastTargetPos = }

local function navKey(ent)
    return ent and tostring((ent.this and ent.this.id) or ent.id) or nil
end

-- `target` is an entity (tracked live) or a fixed {x,y,z}.
-- opts.endWhenClear: finish as soon as the straight line opens up, instead of walking
-- all the way in. That is what a fighter wants - once the wall is no longer between
-- him and his target, combat should take back over.
-- opts.trailEnt/trailBack/trailAim/trailDir: march in column behind that entity instead
-- of walking to a fixed point (see targetPosOf).
function mercenaries:NavGotoRequest(ent, target, opts)
    local k = navKey(ent); if not k then return false end
    local rec = { idx = 1 }
    if target and target.GetWorldPos then rec.target = target else rec.targetPos = target end
    if opts then
        if opts.endWhenClear then rec.endWhenClear = true end
        rec.walk      = opts.walk
        rec.trailEnt  = opts.trailEnt
        rec.trailBack = opts.trailBack
        rec.trailLat  = opts.trailLat
        rec.trailAim  = opts.trailAim
        rec.trailDir  = opts.trailDir
        rec.mode      = opts.mode
        -- obsAware: keep the detour alive while a TENT is in the way, not only a wall.
        -- Only the follow detour wants this - staging and hold orders walk to a fixed
        -- mark and must arrive there even if a tent stands off to one side of it.
        if opts.obsAware then rec.obsAware = true end
    end
    self.NavGoto[k] = rec
    return true
end

-- What kind of order is he currently under? Lets a caller notice the order should change
-- without tearing down a walk that is already correct.
function mercenaries:NavGotoMode(ent)
    local k = navKey(ent); if not k then return nil end
    local rec = self.NavGoto[k]
    return rec and rec.mode or nil
end

-- One-line answer to "is this man actually pathfinding, or walking at the wall?"
function mercenaries:NavGotoState(ent)
    local k = navKey(ent); if not k then return "-" end
    local rec = self.NavGoto[k]
    if not rec then return "no order" end
    local how = rec.trailEnt and "column " or ""
    if not rec.running then return how .. "queued" end
    if rec.path then return string.format("%sleg %d/%d", how, rec.idx or 1, #rec.path) end
    if rec.failAt then return how .. "NO ROUTE" end
    return how .. "straight"
end

function mercenaries:IsNavGotoActive(ent)
    local k = navKey(ent)
    return (k ~= nil) and (self.NavGoto[k] ~= nil) and (self.NavGoto[k].running == true)
end

function mercenaries:NavGotoStart(data, ent)
    local k = navKey(ent); if not k then return end
    local rec = self.NavGoto[k]; if not rec then data.gotoDone = true; return end
    rec.running = true
    data.gotoDone = false
    data.navWalk = (rec.walk == true)
    self:NavGotoTick(data, ent)
end

function mercenaries:NavGotoEnd(ent, why)
    local k = navKey(ent); if not k then return end
    local rec = self.NavGoto[k]
    self.NavGoto[k] = nil
    -- A follow detour REPLACED the follow behaviour, so ending it leaves the man with
    -- nothing running and a latch that still says he is following - the standing-still
    -- bug. FollowStalled is the existing signal that evicts and re-arms him properly
    -- (hold does the same on release). The timestamp is the cooldown NavFollowPoll
    -- reads, so the two are not traded back and forth at the edge of a tent.
    if rec and rec.mode == "followdetour" then
        self.NavFollowLast = self.NavFollowLast or {}
        local t = 0; pcall(function() t = System.GetCurrTime() or 0 end)
        self.NavFollowLast[k] = t
        if self.FollowStalled then pcall(function() self:FollowStalled(ent) end) end
    end
    navLog("goto ended: " .. tostring(why))
end

-- A trailing NPC's destination is a point a fixed distance behind the man he follows,
-- measured back along that man's own line of march. N independent movers aimed at nearby
-- points shove each other sideways, which is what pushed them into the wall; a column
-- keeps one route and one set of legs for the whole file.
local function targetPosOf(rec)
    if rec.trailEnt then
        local p
        pcall(function() p = rec.trailEnt:GetWorldPos() end)
        if not p then return nil end                    -- leader gone: caller re-elects
        local ax, ay = 0, 0
        if rec.trailAim then ax, ay = rec.trailAim.x - p.x, rec.trailAim.y - p.y end
        local L = math.sqrt(ax * ax + ay * ay)
        if L < 1.0 and rec.trailDir then                -- leader is on his mark; hold the line
            ax, ay, L = rec.trailDir.x, rec.trailDir.y, 1.0
        end
        if L <= 1e-3 then return p end
        local hx, hy = ax / L, ay / L                   -- his heading
        local back, lat = rec.trailBack or 0, rec.trailLat or 0
        return { x = p.x - hx * back - hy * lat,
                 y = p.y - hy * back + hx * lat, z = p.z }
    end
    if rec.target then
        local p
        pcall(function() p = rec.target:GetWorldPos() end)
        return p
    end
    return rec.targetPos
end

mercenaries.NavFailBackoff = 1.5     -- seconds before retrying a route that could not be found
mercenaries.NavClearTicksToEnd = 4   -- consecutive clear ticks before a combat detour hands back
mercenaries.NavDetourMaxSeconds = 30 -- give up on a route that never opens (walled in, no gate)

mercenaries.NavLaneWidth = 1.6      -- how far off the shared line a man may walk
mercenaries.NavLaneMin   = 1.2      -- lanes are dropped this close to the waypoint

-- Everyone routing round the same wall gets the same waypoints out of A*, so they walk
-- single file into each other. Each NPC keeps a fixed lane - a sideways offset from the
-- leg he is on - so the group spreads into a band instead of a queue.
--
-- The offset is verified against the wall every tick and dropped the moment it would put
-- him inside one: near a gateway the lane collapses to zero and they file through.
function mercenaries:NavLaneOffset(rec, me, wp)
    if rec.lane == nil then
        rec.lane = (math.random() * 2 - 1) * (self.NavLaneWidth or 0)
    end
    if rec.lane == 0 then return wp end

    local dx, dy = wp.x - me.x, wp.y - me.y
    local L = math.sqrt(dx * dx + dy * dy)
    if L < (self.NavLaneMin or 1.2) then return wp end     -- on top of it: no room to fan out

    local ox, oy = -dy / L * rec.lane, dx / L * rec.lane
    local p = { x = wp.x + ox, y = wp.y + oy, z = wp.z }
    if self:NavPathBlocked(me, p) then return wp end       -- lane runs into a wall or a tent
    return p
end

-- THE SHARED STEERING CORE. Given a caller-owned record, where am I heading right now?
-- Returns the point to steer at, plus true when the target itself is reachable in a
-- straight line. Everything that wants wall-aware movement (nav_goto and camp patrol)
-- calls this rather than duplicating the logic. Every point it hands back has been put
-- through NavAvoidSteer, so tents are rounded whether or not a wall was involved.
--
-- `rec` is any table the caller keeps per NPC; this owns the fields path/idx/
-- lastTargetPos/failAt inside it.
function mercenaries:NavSteerPoint(rec, me, tp)
    if not (rec and me and tp) then return tp, true end

    -- Wall in the way? Only a wall puts him on the graph; a tent is rounded locally by
    -- NavAvoidSteer on the way out, which is why that is applied to every point below.
    if not self:NavIsBlocked(me, tp) then
        rec.path, rec.failAt = nil, nil
        return self:NavAvoidSteer(rec, me, tp), true
    end

    local now = 0
    pcall(function() now = System.GetCurrTime() or 0 end)

    -- Recompute when there is no route, or the target has wandered off the one we
    -- have. The backoff matters: NavPathAround returns nil for several legitimate
    -- reasons (out of range, no graph, wall fully encloses one side), and without it
    -- a blocked NPC re-ran A* on every single tick forever.
    local needPath = (rec.path == nil)
    if needPath and rec.failAt and (now - rec.failAt) < self.NavFailBackoff then
        return self:NavAvoidSteer(rec, me, tp), false   -- still cooling off; head at the target
    end
    if not needPath and rec.lastTargetPos then
        local mx, my = tp.x - rec.lastTargetPos.x, tp.y - rec.lastTargetPos.y
        if (mx * mx + my * my) > (self.NavRecalcMove * self.NavRecalcMove) then needPath = true end
    end
    if needPath then
        rec.path = self:NavPathAround(me, tp)
        rec.idx = 1
        rec.lastTargetPos = { x = tp.x, y = tp.y, z = tp.z }
        if rec.path then
            rec.failAt = nil
            navLog("detour: " .. #rec.path .. " leg(s)")
        else
            rec.failAt = now
        end
    end

    local path = rec.path
    if not path or #path == 0 then return self:NavAvoidSteer(rec, me, tp), false end   -- no way around; do what we can

    -- advance through the legs, cutting each corner early
    local wp = path[rec.idx]
    while wp do
        local wx, wy = wp.x - me.x, wp.y - me.y
        local d2 = wx * wx + wy * wy
        local last = (rec.idx >= #path)
        local r = last and self.NavArriveR or self.NavSwitchR
        if d2 > (r * r) then break end
        if last then rec.path = nil; break end            -- end of detour, re-evaluate next tick
        -- The wide switch radius cuts smooth corners on open ground, but next to a
        -- palisade it cuts THROUGH it, so an early skip is only taken when the shortcut
        -- is clear. Standing ON the waypoint the skip must happen regardless: leg to leg
        -- is clear by construction, and refusing there leaves him steering at his own
        -- feet forever.
        if d2 > (self.NavArriveR * self.NavArriveR) then
            local nxt = path[rec.idx + 1]
            if nxt and self:NavPathBlocked(me, nxt) then break end
        end
        rec.idx = rec.idx + 1
        wp = path[rec.idx]
    end
    wp = rec.path and rec.path[rec.idx] or nil
    if not wp then return self:NavAvoidSteer(rec, me, tp), false end
    return self:NavAvoidSteer(rec, me, self:NavLaneOffset(rec, me, wp)), false
end

mercenaries.NavMinAim = 1.5   -- never steer at a point nearer than this while there is route left

-- The Move node ENDS when it reaches its destination, and the loop around it restarts it
-- from a standstill - that restart is the halt you see at every waypoint, and a man
-- marching in column hits it constantly because his destination is the spot he is
-- standing on. So while there is more route to walk, the aim is pushed on toward the
-- next point instead. Bounded by that point, so it cannot run away from him.
function mercenaries:NavAimAhead(rec, me, p)
    local dx, dy = p.x - me.x, p.y - me.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d >= self.NavMinAim then return p end

    -- where the route carries on after p
    local beyond
    if rec.path and rec.idx and rec.path[rec.idx + 1] then
        beyond = rec.path[rec.idx + 1]
    elseif rec.trailEnt and rec.trailAim then
        beyond = rec.trailAim
    end
    if not beyond then return p end          -- this is the end of the road: let him arrive

    local bx, by = beyond.x - p.x, beyond.y - p.y
    local L = math.sqrt(bx * bx + by * by)
    if L < 1e-3 then return p end
    local step = math.min(self.NavMinAim - d, L)
    local q = { x = p.x + (bx / L) * step, y = p.y + (by / L) * step, z = p.z }
    if self:NavPathBlocked(me, q) then return p end
    return q
end

-- One tick of nav_goto.xml: steer, and report arrival.
function mercenaries:NavGotoTick(data, ent)
    local k = navKey(ent); if not k then data.gotoDone = true; return end
    local rec = self.NavGoto[k]; if not rec then data.gotoDone = true; return end

    local me
    pcall(function() me = ent:GetWorldPos() end)
    local tp = targetPosOf(rec)
    if not (me and tp) then data.gotoDone = true; return end

    -- A DETOUR NEVER ENDS WHILE THE WALL IS STILL BETWEEN THEM.
    --
    -- This used to test straight-line distance first, so two men 2m apart on opposite
    -- sides of a palisade counted as "arrived": the detour ended, combat resumed, they
    -- shoved into the wall, the poll re-fired, and it arrived again on the next tick.
    -- That loop is what looked like bugging out and walking into the wall - and it only
    -- showed up close in, which is why the long approach looked fine.
    local blocked
    if rec.obsAware then blocked = self:NavPathBlocked(me, tp) else blocked = self:NavIsBlocked(me, tp) end

    if blocked then
        rec.clearTicks = 0
        -- Safety valve: if a route can never be found (walled in with no gate) do not
        -- hold him forever - give up so his normal behaviour resumes, and the wall
        -- guard still stops him passing through.
        rec.startedAt = rec.startedAt or (function()
            local t = 0; pcall(function() t = System.GetCurrTime() or 0 end); return t
        end)()
        local now = 0
        pcall(function() now = System.GetCurrTime() or 0 end)
        if (now - rec.startedAt) > (self.NavDetourMaxSeconds or 30) then
            navLog("detour gave up after " .. tostring(self.NavDetourMaxSeconds or 30) .. "s")
            data.gotoDone = true
            return
        end
    else
        -- The give-up clock measures one CONTINUOUS blocked stretch. On a long march a
        -- brief block early on would otherwise still be running an hour later and abort
        -- a route that has been clear the whole way.
        rec.startedAt = nil

        -- Line is open. Arrived, or (for a combat detour) clear long enough to hand back.
        -- A man marching in column never "arrives": his mark is a moving point behind the
        -- leader, and ending there would tear the order down and re-issue it every poll.
        local dx, dy = tp.x - me.x, tp.y - me.y
        if (not rec.trailEnt) and (dx * dx + dy * dy) <= (self.NavArriveR * self.NavArriveR) then
            data.gotoDone = true
            return
        end
        if rec.endWhenClear then
            rec.clearTicks = (rec.clearTicks or 0) + 1
            if rec.clearTicks >= (self.NavClearTicksToEnd or 4) then
                data.gotoDone = true
                return
            end
        end
    end

    data.navWalk = (rec.walk == true)      -- an order can change pace mid-walk
    local p = self:NavSteerPoint(rec, me, tp)
    p = self:NavAimAhead(rec, me, p)
    data.wpPos.x, data.wpPos.y, data.wpPos.z = p.x, p.y, p.z
end

-- Engine formation (FormationFollower / CrimeFollower) picks its own destinations
-- inside the engine - nothing in Lua or the tree can redirect it, so a merc in
-- formation cannot be walked around a wall. Near a walled camp it therefore stands
-- down and the slot follower takes over, which steers from a vec3 we own.
--
-- Decided from the PLAYER's position, not each merc's, so the whole squad switches
-- together instead of half-in/half-out. The two radii are hysteresis: without the gap
-- a merc hovering on the boundary would tear the formation down and rebuild it every
-- few seconds, which is exactly the churn this repo has been bitten by before.
mercenaries.NavFormationOffMargin = 15.0
mercenaries._navFormationOff = false

function mercenaries:NavSuppressFormation()
    if not (self.CampCenter and self:WallHasAny() and player) then
        self._navFormationOff = false
        return false
    end
    local p
    pcall(function() p = player:GetWorldPos() end)
    if not p then return self._navFormationOff end
    local c = self.CampCenter
    local dx, dy = p.x - c.x, p.y - c.y
    local d = math.sqrt(dx * dx + dy * dy)
    if self._navFormationOff then
        if d > (self.NavActiveRadius + self.NavFormationOffMargin) then
            self._navFormationOff = false
            navLog("left the camp - engine formation back on")
        end
    elseif d <= self.NavActiveRadius then
        self._navFormationOff = true
        navLog("near a walled camp - engine formation off, slot following takes over")
    end
    return self._navFormationOff
end

-- Per-merc version of the above, and the one UpdateFormationRole actually calls.
--
-- The squad-wide test is decided from the PLAYER's position against a 60m radius
-- (75m to come back). A camp is nowhere near 60m across, so sallying out of a walled
-- camp meant the whole squad marched the first 75m on the CrimeFollower chain with no
-- formation at all - and a hire made anywhere near the camp came out on the chain for
-- the same reason. That is the "they revert to crime follower when sallying out"
-- report, and it is this function's fault, not the formation's.
--
-- What the suppression is actually for is narrow: a merc who has to route AROUND the
-- camp wall cannot be steered there by an engine formation, so he drops to slot
-- following and the custom navmesh takes him. That is a fact about where THAT MAN is
-- standing, not about where the player is. A man already outside the walls and
-- marching away needs no such help.
--
-- Hysteresis is kept, and kept PER MERC (the original comment's warning about churn
-- is real - a man hovering on the boundary would otherwise tear the formation down
-- and rebuild it every few seconds). Position comes from the PerfPos cache, refreshed
-- every 50ms, so this costs nothing per call.
mercenaries._navFormationOffFor = {}   -- [wuidStr] = true while suppressed for that merc

-- How far the palisade actually reaches from the camp centre.
--
-- THE RADIUS HAS TO COME FROM THE WALL. Making the test per-merc (above) fixed half of the
-- "they revert to crime follower when sallying out" report and left the other half in place:
-- it kept measuring against NavActiveRadius, 60m, when a camp is nowhere near 60m across. A
-- palisade of 51 segments encloses a circle of roughly 22m, so every man deployed from a
-- walled camp - and the leader they form on, and the player who gave the order, all standing
-- inside it - was suppressed, and stayed suppressed until he was 75m out. The whole sortie
-- marched on the follow chain with no formation at all.
--
-- Cached against the shape of the wall tables, the only thing that can change the answer.
mercenaries.NavWallPadding = 8.0       -- clear of the palisade before it stops mattering

function mercenaries:NavWallRadius()
    local runs = #(self.WallRuns or {})
    local marks = #(self.WallMarks or {})
    if self._navWallR and self._navWallRuns == runs and self._navWallMarks == marks then
        return self._navWallR
    end
    local c = self.CampCenter
    if not c then return 0 end
    local far = 0
    local ok = pcall(function()
        for _, q in ipairs(self:WallAllPoints() or {}) do
            local dx, dy = q.x - c.x, q.y - c.y
            local dd = math.sqrt(dx * dx + dy * dy)
            if dd > far then far = dd end
        end
    end)
    if not ok then far = 0 end
    self._navWallR, self._navWallRuns, self._navWallMarks = far, runs, marks
    return far
end

-- Where the formation hangs from: the elected leader, or the player before one is elected.
local function navAnchorPos(self)
    local w = self.FormationLeader
    if w then
        local p = self:PerfMercPos(w)
        if p then return p end
    end
    local pp
    pcall(function() pp = player and player:GetWorldPos() end)
    return pp
end

-- OFF makes every man use the engine formation regardless of walls, as before this
-- suppression existed.
--
-- Worth knowing what this costs when it is on: the whole branch is dead until the FIRST
-- wall stands, and from then on every merc within `r` of the camp centre is taken out of
-- the engine formation and steered by the mod's own follow/nav instead - which is the
-- expensive path. `r` is the camp centre to the FARTHEST wall point, so one segment placed
-- well away from the middle makes that circle large. That is a fixed cost that appears with
-- the first wall and does not grow with the wall's length, which is the shape of the lag
-- reported at the palisade. `merc_nav_wallsuppress 0` is the A/B.
mercenaries.NavWallSuppress = (mercenaries.NavWallSuppress ~= false)

function mercenaries:NavWallSuppressSet(line)
    local v = tonumber(tostring(line or ""):match("%-?%d+"))
    if v == nil then
        System.LogAlways("[Nav] merc_nav_wallsuppress <0|1> - currently "
                         .. (self.NavWallSuppress and "1" or "0"))
        return
    end
    self.NavWallSuppress = (v ~= 0)
    self._navFormationOffFor = {}
    pcall(function() self:SaveString("MercNavWallSuppress", self.NavWallSuppress and "1" or "0") end)
    System.LogAlways("[Nav] wall formation suppression " ..
                     (self.NavWallSuppress and "on" or "off (everyone uses the engine formation)"))
end

mercenaries:PlayerCommand("merc_nav_wallsuppress", "mercenaries:NavWallSuppressSet('%line')",
                          "Drop men near a wall out of the engine formation: 1 on, 0 off")

function mercenaries:NavSuppressFormationFor(wuid)
    if not self.NavWallSuppress then
        if next(self._navFormationOffFor) then self._navFormationOffFor = {} end
        return false
    end
    if not (self.CampCenter and self:WallHasAny()) then
        if next(self._navFormationOffFor) then self._navFormationOffFor = {} end
        return false
    end
    if not wuid then return false end

    local key = tostring(wuid)
    local mp = self:PerfMercPos(wuid)
    if not mp then
        -- Not scanned yet: keep whatever we last decided rather than flipping him.
        return self._navFormationOffFor[key] == true
    end

    local r = self:NavWallRadius()
    if r <= 0 then
        self._navFormationOffFor[key] = nil
        return false
    end
    r = r + self.NavWallPadding

    local c = self.CampCenter
    local dx, dy = mp.x - c.x, mp.y - c.y
    local d = math.sqrt(dx * dx + dy * dy)

    -- SAME SIDE OF THE WALL AS THE ANCHOR: nothing to route around, so the formation can
    -- steer him normally. This is the sortie forming up inside its own camp before marching
    -- out of the gate, which is the case that was broken. The suppression is only for the man
    -- who has to come round the palisade to reach the shape - him inside and the anchor out,
    -- or the reverse - because an engine formation cannot steer him round it and the custom
    -- navmesh has to.
    local ap = navAnchorPos(self)
    if ap then
        local ax, ay = ap.x - c.x, ap.y - c.y
        local anchorInside = math.sqrt(ax * ax + ay * ay) <= r
        if (d <= r) == anchorInside then
            self._navFormationOffFor[key] = nil
            return false
        end
    end

    if self._navFormationOffFor[key] then
        if d > (r + self.NavFormationOffMargin) then
            self._navFormationOffFor[key] = nil
        end
    elseif d <= r then
        self._navFormationOffFor[key] = true
    end
    return self._navFormationOffFor[key] == true
end

-- Enemy approach poll, called from enemy_melee_scheduler.xml.
-- Sets data.navDetour (true while nav_goto owns him - the combat loop stands down on
-- this, or a 160 combat fire would replace the running 200 detour and restart it) and
-- data.navWanted (fire the detour now). Only ever true when a wall genuinely blocks
-- the way, so a fight in open country never touches any of this.
mercenaries.NavEnemyMinDist = 4.0     -- already on top of him: just fight

-- Who should this NPC be walking toward, even though a wall means he cannot currently
-- fight them? Targeting is gated on walls (NavTargetBlocked) so nobody locks on across
-- one - but that also means currentTarget goes nil, and an NPC with no target has no
-- reason to move, which is why they pressed against the wall instead of going round.
-- Approach is therefore decided HERE, independently of engagement: find the nearest
-- opponent that is only unreachable because of the wall, and route to him. Once the
-- line opens the detour ends (endWhenClear) and normal targeting takes the fight.
mercenaries.NavApproachRange = 45.0

function mercenaries:NavFindApproachTarget(ent, side)
    local me
    pcall(function() me = ent:GetWorldPos() end)
    if not me then return nil end

    local best, bestD2
    local function consider(cand)
        if not cand then return end
        local p
        pcall(function() p = cand:GetWorldPos() end)
        if not p then return end
        local dx, dy = p.x - me.x, p.y - me.y
        local d2 = dx * dx + dy * dy
        if d2 > (self.NavApproachRange * self.NavApproachRange) then return end
        if not self:NavIsBlocked(me, p) then return end      -- reachable already; not our problem
        if not self:IsAliveAndWell(cand, true) then return end
        if not bestD2 or d2 < bestD2 then best, bestD2 = cand, d2 end
    end

    if side == "enemy" then
        consider(player)
        for _, m in pairs(self.ActiveMercs or {}) do consider(m) end
    else
        -- our side: walk toward whichever of our spawned enemies is walled off
        local c = self.CampCenter
        local ents
        pcall(function() ents = System.GetEntitiesInSphere(c or me, self.NavApproachRange) end)
        for _, e in pairs(ents or {}) do
            pcall(function()
                if self.IsModEnemyName and self:IsModEnemyName(e:GetName() or "") then consider(e) end
            end)
        end
    end
    return best
end

-- Shared approach poll. `side` is "enemy" for our spawned enemies, anything else for
-- our own mercs/archers. Sets data.navDetour (loops that fire combat must stand down
-- on it) and data.navWanted (fire nav_goto now).
function mercenaries:NavApproachPoll(data, ent, side)
    data.navWanted = false
    data.navDetour = self:IsNavGotoActive(ent)
    if data.navDetour then return end
    -- During the battle nobody is re-routed; staging already put them where they
    -- belong and re-routing mid-fight is what made them run at walls.
    if self.WBWallRulesActive and not self:WBWallRulesActive() then return end
    if not (ent and self:WallHasAny() and self.CampCenter) then return end

    local me
    pcall(function() me = ent:GetWorldPos() end)
    if not me then return end
    local c = self.CampCenter
    local cx, cy = me.x - c.x, me.y - c.y
    if (cx * cx + cy * cy) > (self.NavActiveRadius * self.NavActiveRadius) then return end

    local target = self:NavFindApproachTarget(ent, side)
    if not target then return end

    -- No minimum distance here. NavFindApproachTarget only ever returns someone a WALL
    -- is blocking, and "he is only 3m away" is exactly the case that matters: enemy on
    -- one side, target on the other, close enough that a distance check would wave it
    -- through and leave him swinging at the palisade.
    local tp
    pcall(function() tp = target:GetWorldPos() end)
    if not tp then return end

    if self:NavGotoRequest(ent, target, { endWhenClear = true }) then
        data.navWanted = true
        data.navDetour = true
        navLog("approaching a walled-off opponent")
    end
end

-- Back-compat wrapper: the enemy schedulers call this.
function mercenaries:EnemyNavPoll(data, ent, _targetWuid)
    self:NavApproachPoll(data, ent, "enemy")
end

-- Follow detour. Engine formation and CrimeFollower both pick their own destinations
-- inside the engine, so a following merc cannot be steered round anything - which is why
-- a squad walks through the camp it just paid for. This hands him to nav_goto instead,
-- for as long as camp geometry is actually in his way, and gives him straight back.
--
-- It is deliberately grudging. Firing the interrupt evicts the follow behaviour and the
-- scheduler has to re-arm it, so a poll that fires readily trades the two back and forth
-- at the edge of every tent: hence near camp only, a confirmation tick, and a cooldown
-- after each detour ends (NavGotoEnd records it).
mercenaries.NavFollowEnabled  = true
mercenaries.NavFollowConfirm  = 2      -- consecutive blocked polls before the tree is touched
mercenaries.NavFollowCooldown = 5.0    -- seconds before the same man may detour again
mercenaries.NavFollowMinDist  = 3.0    -- on top of the player already: nothing to route around
mercenaries.NavFollowLast     = {}
mercenaries._navFollowSeen    = {}

function mercenaries:NavFollowPoll(data, ent)
    data.navFollowGo = false
    if not self.NavFollowEnabled then return end
    if _G.MercenariesDismissed then return end
    if not (ent and player and self.CampCenter) then return end
    if self:IsNavGotoActive(ent) then return end
    -- Once the fight is on, staging has already put everyone where they belong and
    -- re-routing mid-battle is what made them run at walls.
    if self.WBWallRulesActive and not self:WBWallRulesActive() then return end
    -- Re-firing an interrupt over a mounted merc throws him off the horse.
    if _G.PlayerMounted then return end
    if not (self:WallHasAny() or self:NavHasObstacles()) then return end

    local k = navKey(ent); if not k then return end
    local me, tp
    pcall(function() me = ent:GetWorldPos() end)
    pcall(function() tp = player:GetWorldPos() end)
    if not (me and tp) then return end

    local c = self.CampCenter
    local cx, cy = me.x - c.x, me.y - c.y
    local ex, ey = tp.x - me.x, tp.y - me.y
    if (cx * cx + cy * cy) > (self.NavActiveRadius * self.NavActiveRadius)
    or (ex * ex + ey * ey) < (self.NavFollowMinDist * self.NavFollowMinDist)
    or not self:NavPathBlocked(me, tp) then
        self._navFollowSeen[k] = nil
        return
    end

    -- A man mercenaries_solid.lua reports as STUCK is a different case from a man merely
    -- blocked. Blocked means the straight line crosses a wall and he would have clipped
    -- through it; the confirm count and the cooldown exist to stop that trading the tree
    -- back and forth at the edge of every tent. Stuck means his body is already against
    -- the timber and he is going nowhere, so both of those guards are only delaying the
    -- one thing that can help him. He gets the route on the next poll.
    local stuck = false
    pcall(function() stuck = self.SolidIsStuck and self:SolidIsStuck(ent) end)

    if not stuck then
        local now = 0
        pcall(function() now = System.GetCurrTime() or 0 end)
        local last = self.NavFollowLast[k]
        if last and (now - last) < self.NavFollowCooldown then return end

        local n = (self._navFollowSeen[k] or 0) + 1
        self._navFollowSeen[k] = n
        if n < self.NavFollowConfirm then return end
    end
    self._navFollowSeen[k] = nil

    if self:NavGotoRequest(ent, player, { endWhenClear = true, obsAware = true, mode = "followdetour" }) then
        data.navFollowGo = true
        if stuck then
            pcall(function() self:SolidDetourTaken(ent) end)
            navLog("follow detour: he was against the wall - rerouting him now")
        else
            navLog("follow detour: routing round camp geometry")
        end
    end
end

function mercenaries:SetNavFollow(v)
    self.NavFollowEnabled = (tostring(v or ""):match("0") == nil)
    navSay("follow detours " .. (self.NavFollowEnabled and "ON" or "off"))
end

function mercenaries:SetNavAvoid(v)
    v = tonumber(v)
    if v and v >= 0 then self.NavObsClearance = v end
    navSay(string.format("obstacle clearance %.2fm over %d footprint(s)",
        self.NavObsClearance, #(self.NavObstacles or {})))
end

function mercenaries:SetNavRadii(sw, ar)
    if sw and sw ~= "" and tonumber(sw) then self.NavSwitchR = tonumber(sw) end
    if ar and ar ~= "" and tonumber(ar) then self.NavArriveR = tonumber(ar) end
    navLog(string.format("switch %.1fm, arrive %.1fm", self.NavSwitchR, self.NavArriveR))
end

-- 0 lets the Move node decide it has arrived, which is what makes them halt at waypoints.
function mercenaries:SetNavAim(v)
    v = tonumber(v)
    if v and v >= 0 then self.NavMinAim = v end
    navSay(string.format("aim held %.1fm ahead", self.NavMinAim))
end

-- 0 puts everyone back on the shared line, single file.
function mercenaries:SetNavLane(w)
    w = tonumber(w)
    if w and w >= 0 then self.NavLaneWidth = w end
    for _, rec in pairs(self.NavGoto or {}) do rec.lane = nil end   -- redraw lanes now
    navSay(string.format("lane width %.1fm", self.NavLaneWidth))
end

-- ==== TARGETING THROUGH WALLS ====
-- A wall should break line of sight for picking a fight, not just for walking: two
-- sides that cannot reach each other should not lock on across it and stand there
-- swinging at nothing. This is the single test every target picker consults.
--
-- Anyone properly ABOVE the wall is exempt, so tower archers and men on a cart bed
-- still shoot over it. Height is used rather than a name check so it covers anything
-- elevated we add later.
mercenaries.NavSeeOverHeight = 2.0

function mercenaries:NavTargetBlocked(fromEnt, targetEnt)
    if not (fromEnt and targetEnt) then return false end

    -- Never at a siege. This rule exists for ONE thing: stopping a merc locking onto someone
    -- on the far side of the player's own camp palisade. At Raborsch every man is behind a
    -- barricade or a wall by design, so the only thing it can do there is refuse targets that
    -- ought to be fought. Checked before the wall test rather than relying on it.
    if self.RBQ and self.RBQ.active then return false end

    if not (self:WallHasAny() and self.CampCenter) then return false end
    -- Once the battle is joined the wall stops mattering: both sides were marshalled to
    -- the gaps first, so anything they can see now they have a right to fight.
    if self.WBWallRulesActive and not self:WBWallRulesActive() then return false end
    local a, b
    pcall(function() a = fromEnt:GetWorldPos() or fromEnt:GetPos() end)
    pcall(function() b = targetEnt:GetWorldPos() or targetEnt:GetPos() end)
    if not (a and b) then return false end
    -- shooting down from a tower/cart clears the wall
    if (a.z - b.z) > self.NavSeeOverHeight then return false end
    -- only bother near camp
    local c = self.CampCenter
    local dx, dy = a.x - c.x, a.y - c.y
    if (dx * dx + dy * dy) > (self.NavActiveRadius * self.NavActiveRadius) then return false end
    -- Margin 0: NavBlockMargin is ROUTE clearance (see :76-78), and the endpoint
    -- clearance it adds tests the asker's OWN position - so a man standing within
    -- 1.8m of his own palisade read as blocked from every opponent on the map and
    -- his whole candidate list was blanked. Targeting wants the exact crossing test.
    return self:NavIsBlocked(a, b, 0)
end

-- The push-back guard that used to shove NPCs back when they clipped a wall is
-- GONE. It fought the engine every tick and produced exactly the jitter and
-- rubber-banding it was meant to prevent. Walls are walk-through as far as the
-- engine is concerned; what keeps the two sides apart is the staged approach to
-- the gaps (mercenaries_wallbattle.lua), not a positional correction.

-- ==== patrol along the wall ====
-- With a wall up, the default circular patrol ring is the wrong route: it either sits
-- inside the wall and ignores it entirely, or crosses it. These points follow the wall
-- itself, set NavPatrolInset metres in from it, so guards walk the perimeter.
mercenaries.NavPatrolInset = 2.5

-- Walked against the LONGEST stretch. A patrol route only means anything along one
-- continuous line of wall; splicing several disconnected stretches into one loop would
-- march the guards through the gaps between them.
function mercenaries:NavWallPerimeterPoints(count, startFrac)
    local run = self:WallLongestRun()
    local m = run and run.pts or {}
    if #m < 3 then return nil end
    count = count or 8
    startFrac = startFrac or 0

    -- polygon edges (closing edge included when the ring is closed)
    local pts = {}
    for i = 1, #m do table.insert(pts, m[i]) end
    if run.closed then table.insert(pts, m[1]) end
    if #pts < 3 then return nil end

    -- centroid, used as the "inward" direction
    local cx, cy = 0, 0
    for i = 1, #m do cx, cy = cx + m[i].x, cy + m[i].y end
    cx, cy = cx / #m, cy / #m

    -- cumulative edge lengths
    local segs, total = {}, 0
    for i = 1, #pts - 1 do
        local a, b = pts[i], pts[i + 1]
        local dx, dy = b.x - a.x, b.y - a.y
        local L = math.sqrt(dx * dx + dy * dy)
        if L > 0.01 then
            table.insert(segs, { a = a, b = b, L = L, at = total })
            total = total + L
        end
    end
    if total < 1.0 then return nil end

    local out = {}
    for i = 0, count - 1 do
        local d = ((startFrac + i / count) % 1) * total
        for _, s in ipairs(segs) do
            if d <= s.at + s.L then
                local t = (d - s.at) / s.L
                local x = s.a.x + (s.b.x - s.a.x) * t
                local y = s.a.y + (s.b.y - s.a.y) * t
                -- step in toward the middle so the guard walks beside the wall, not in it
                local ix, iy = cx - x, cy - y
                local il = math.sqrt(ix * ix + iy * iy)
                if il > 0.01 then
                    x = x + (ix / il) * self.NavPatrolInset
                    y = y + (iy / il) * self.NavPatrolInset
                end
                local p = { x = x, y = y, z = s.a.z }
                if self.CampSnapToGround then p = self:CampSnapToGround(p) end
                table.insert(out, p)
                break
            end
        end
    end
    return (#out >= 3) and out or nil
end

-- Re-cut every guard's route. Called whenever the wall changes, so a wall built after
-- camp was pitched actually changes where the guards walk.
mercenaries.NavGateGuards = 2     -- sentries posted at the wall ends rather than patrolling
mercenaries.NavGateInset  = 2.0   -- how far inside the wall line they stand

-- The gateway is the two ends of the wall run - the rule that a corner may not be marked
-- within WallGateMin of the start is what guarantees they are a real gap apart. Posts sit
-- a little inside the line so a sentry is not standing in the palisade mesh.
function mercenaries:NavGatePosts()
    local c = self.CampCenter
    if not c then return {} end

    -- A real gate is a better post than the end of a wall run: once one is placed the
    -- sentries stand on it instead. Only when the camp has none does the old rule apply.
    local ends = {}
    for _, g in ipairs((self.GatePositions and self:GatePositions()) or {}) do
        table.insert(ends, g)
    end
    if #ends == 0 then
        local run = self:WallLongestRun()
        local m = run and run.pts or {}
        if #m < 2 then return {} end
        ends = { m[1], m[#m] }
    end

    local out = {}
    for _, e in ipairs(ends) do
        local dx, dy = c.x - e.x, c.y - e.y
        local L = math.sqrt(dx * dx + dy * dy)
        local p = { x = e.x, y = e.y, z = e.z }
        if L > 1e-3 then
            p.x = e.x + (dx / L) * self.NavGateInset
            p.y = e.y + (dy / L) * self.NavGateInset
        end
        if self.CampSnapToGround then p = self:CampSnapToGround(p) end
        table.insert(out, p)
    end
    return out
end

-- A route of one point is a sentry post: camp_actor walks there, AdvancePatrolWaypoint
-- leaves the index where it is, and he stands. No new behaviour tree work for a guard
-- who holds a position rather than walking a loop.
function mercenaries:NavRefreshPatrolRings()
    if not self.CampPatrollers then return end
    -- No wall: leave the guards on whatever ring the camp gave them. There is nothing
    -- to hug and nothing to stand a gate on.
    if not self:WallHasAny() then
        navSay("[Nav] no wall - guards keep their camp patrol")
        return
    end
    local n, g = 0, 0
    local guards = {}
    -- Only the PLAYER's guards. CampPatrollers is shared with the bandit-camp contract
    -- (docs/bandit-camp-quest.md), and those records belong to a camp on the other side of
    -- the map with no wall of its own - re-pointing them at this wall's gate posts would
    -- march them off to it.
    for k, rec in pairs(self.CampPatrollers) do
        if not (rec and rec.foreign) then table.insert(guards, k) end
    end
    table.sort(guards)

    local posts = self:NavGatePosts()
    local nGate = math.min(#posts, self.NavGateGuards, #guards)

    for i, k in ipairs(guards) do
        local rec = self.CampPatrollers[k]
        if rec then
            if i <= nGate then
                rec.waypoints = { posts[i] }
                rec.gate = true
                g = g + 1
            else
                local rest = math.max(#guards - nGate, 1)
                local pts = self:NavWallPerimeterPoints(8, (i - nGate - 1) / rest)
                if pts then rec.waypoints = pts end
                rec.gate = nil
                n = n + 1
            end
            rec.index = 1
            rec.nav = nil
            rec.onDetour = false
        end
    end
    if (n + g) > 0 then
        navSay("[Nav] " .. g .. " guard(s) on the gate, " .. n .. " patrolling the wall")
    end
end

-- ==== debug ====
function mercenaries:NavClearDebug()
    for _, id in ipairs(self.NavDebugEnts or {}) do pcall(function() System.RemoveEntity(id) end) end
    self.NavDebugEnts = {}
end

function mercenaries:NavMarker(p, model)
    local e
    pcall(function()
        e = System.SpawnEntity({
            class = "BasicEntity",
            name = "MercNavDbg_" .. tostring(math.random(100000, 999999)),
            position = p,
            properties = { object_Model = model, bMissionCritical = false,
                           bSaved_by_game = false, bSerialize = false },
        })
    end)
    if e then table.insert(self.NavDebugEnts, e.id) end
    return e
end

-- Show the graph: a marker on every node that lost at least one edge to a wall, i.e.
-- the nodes that line the wall. Marking all ~800 would be unreadable.
function mercenaries:NavShow()
    if not self.NavGraph then self:NavBuild() end
    local g = self.NavGraph
    if not g then return end
    self:NavClearDebug()
    local shown = 0
    for i, n in ipairs(g.nodes) do
        local full = 0
        for _, d in ipairs({ {1,0}, {0,1}, {1,1}, {1,-1}, {-1,0}, {0,-1}, {-1,-1}, {-1,1} }) do
            local q = { x = n.x + d[1] * g.spacing, y = n.y + d[2] * g.spacing, z = n.z }
            if self:NavIsBlocked(n, q) then full = full + 1 end
        end
        if full > 0 then
            self:NavMarker(n, "objects/manmade/common_furniture/barrels/barrel_a.cgf")
            shown = shown + 1
        end
    end
    navLog(shown .. " wall-adjacent nodes marked (merc_nav_clear to remove)")
end

-- Mark every camp footprint an NPC routes around, at the clearance he actually keeps.
function mercenaries:NavObsShow()
    self:NavClearDebug()
    local obs = self.NavObstacles or {}
    if #obs == 0 then navSay("no camp obstacles registered"); return end
    local pad = self.NavObsClearance or 0.45
    local byTag = {}
    for _, o in ipairs(obs) do
        byTag[o.tag] = (byTag[o.tag] or 0) + 1
        local c, s = math.cos(o.a), math.sin(o.a)
        local w, h = o.w + pad, o.h + pad
        for _, q in ipairs({ { w, h }, { -w, h }, { -w, -h }, { w, -h } }) do
            self:NavMarker({ x = o.x + (-s) * q[1] + c * q[2],
                             y = o.y + ( c) * q[1] + s * q[2], z = o.z },
                           "objects/manmade/common_furniture/barrels/barrel_a.cgf")
        end
    end
    navSay(string.format("%d obstacle(s), %.2fm clearance (merc_nav_clear to remove)", #obs, pad))
    for tag, n in pairs(byTag) do navSay(string.format("   %s x%d", tostring(tag), n)) end
end

-- Path from the player to whatever is under the crosshair, drawn with markers.
function mercenaries:NavTest()
    if not player then return end
    local to = self:TowerLookedAtPos()
    if not to then navSay("look at solid ground first"); return end
    if self.CampSnapToGround then to = self:CampSnapToGround(to) end
    local from = player:GetWorldPos()
    self:NavClearDebug()

    -- Report each stage, so a failure says WHICH step gave up rather than just "no path".
    navSay("--- path test ---")
    navSay(string.format("wall: %d run(s), %d corner(s), extent %.0fm",
        #self:WallAllRuns(), #self:WallAllPoints(), self:NavWallExtent()))
    navSay(string.format("obstacles: %d footprint(s), %.2fm clearance",
        #(self.NavObstacles or {}), self.NavObsClearance or 0))
    if not self.CampCenter then navSay("FAIL: no camp"); return end
    if not self:NavIsBlocked(from, to) then
        -- No wall, so no A* route is wanted; say whether a tent is being rounded instead.
        local o = self:NavObstacleHit(from, to)
        navSay(o and string.format("no wall - rounding a %s footprint locally", tostring(o.tag))
                 or "line is clear - no detour needed")
        return
    end
    if not self.NavGraph then self:NavBuild() end
    local g = self.NavGraph
    if not g then navSay("FAIL: no graph"); return end
    navSay(string.format("graph: %d nodes, %.0fm radius, %.1fm spacing", #g.nodes, g.radius, g.spacing))

    local s, sVis = self:NavNearestVisibleNode(from)
    local e, eVis = self:NavNearestVisibleNode(to)
    navSay("start node " .. tostring(s) .. (sVis and " (visible)" or " (NOT visible - suspect)"))
    navSay("goal  node " .. tostring(e) .. (eVis and " (visible)" or " (NOT visible - suspect)"))

    local path = self:NavPathAround(from, to)
    if not path then navSay("FAIL: no route (see the reason above)"); return end
    local bad = self:NavValidatePath(from, path)
    navSay("detour with " .. #path .. " leg(s)" .. (bad > 0 and (", " .. bad .. " BAD") or ", all clear") .. ":")
    for i, p in ipairs(path) do
        self:NavMarker(p, "objects/manmade/common_furniture/barrels/barrel_a.cgf")
        navSay(string.format("   %d (%.1f, %.1f)", i, p.x, p.y))
    end
end

function mercenaries:SetNavDebug(v)
    self.NavDebug = (tonumber(v) ~= 0)
    System.LogAlways("[Nav] debug logging " .. (self.NavDebug and "ON" or "off"))
end

-- ==== engine obstacle machinery (DIAGNOSTIC ONLY) ====
-- Everything below drives the ENGINE's own obstacle and navmesh systems rather than our
-- geometry. None of it is armed by the mod: these are the commands for answering "can the
-- engine be made to see a spawned wall", one console line at a time. Arming a global AI
-- cvar as shipped behaviour is not something a mod should do.
--
-- What the binary says exists (dumped from WHGame.dll, see docs/walls-and-sieges.md):
--   wh_ai_ObstaclesAddToCollisionAvoidance  "Add static obstacles to the collision
--                                            avoidance. 0 - no, 1 - yes, 2 - yes but
--                                            exclude obstacles with ignore radius"
--   wh_ai_FindPathUseObstacles              "Include obstacles when computing costs
--                                            within the nav mesh search"
--   wh_ai_AutomaticMNMRebuild               "Enables automatic rebuilding of nav mesh
--                                            when a change in level is detected"
--   ai_MovementSystemPathReplanningEnabled  re-plans actors when "a navigation-mesh
--                                            change at runtime affects their current path"
--   ai_DebugDrawNavigationWorldMonitor      "displaying bounding boxes for world changes"
mercenaries.NavEngineCVars = {
    "wh_ai_ObstaclesAddToCollisionAvoidance",
    "wh_ai_FindPathUseObstacles",
    "wh_ai_FindPathObstaclesMultiplier",
    "wh_ai_AutomaticMNMRebuild",
    "wh_ai_OverrideMNM",
    "ai_AdjustPathsAroundDynamicObstacles",
    "ai_ObstacleSizeThreshold",
    "ai_MinActorDynamicObstacleAvoidanceRadius",
    "ai_ExtraAvoidanceRadius",
    "ai_ExtraActorAvoidanceRadius",
    "ai_CollisionAvoidanceRange",
    "ai_MovementSystemPathReplanningEnabled",
    "ai_DebugDrawNavigationWorldMonitor",
    "ai_DebugDrawNavigation",
}

function mercenaries:NavEngineReport()
    navSay("--- engine obstacle cvars ---")
    for _, name in ipairs(self.NavEngineCVars) do
        local v
        pcall(function() v = System.GetCVar(name) end)
        navSay(string.format("   %-42s %s", name, v == nil and "MISSING" or tostring(v)))
    end
    navSay(string.format("wall: %d segment entities, %d corner(s)",
        #(self.WallSegEnts or {}), #self:WallAllPoints()))
end

-- Turn the obstacle systems on so a spawned wall has a chance of being seen. Reversible:
-- merc_nav_engine_arm 0 puts back what was there.
function mercenaries:NavEngineArm(v)
    local on = (tostring(v or ""):match("0") == nil)
    self._navEngineSaved = self._navEngineSaved or {}
    local want = {
        wh_ai_ObstaclesAddToCollisionAvoidance = 1,
        wh_ai_FindPathUseObstacles             = 1,
        wh_ai_AutomaticMNMRebuild              = 1,
        ai_AdjustPathsAroundDynamicObstacles   = 1,
        ai_MovementSystemPathReplanningEnabled = 1,
    }
    for name, val in pairs(want) do
        if on then
            if self._navEngineSaved[name] == nil then
                local cur
                pcall(function() cur = System.GetCVar(name) end)
                self._navEngineSaved[name] = cur
            end
            pcall(function() System.SetCVar(name, val) end)
        elseif self._navEngineSaved[name] ~= nil then
            pcall(function() System.SetCVar(name, self._navEngineSaved[name]) end)
            self._navEngineSaved[name] = nil
        end
    end
    navSay("engine obstacle cvars " .. (on and "ARMED" or "restored"))
    self:NavEngineReport()
end

-- AI.SetPFBlockerRadius(entityId, blocker, radius) - "PF" is pathfinding. It was written
-- off as inert once, but it acts on an entity's AI object and a plain prop has none, so
-- that test proved nothing. This tries it on every wall segment and says how many calls
-- the bind actually accepted.
function mercenaries:NavEngineBlockers(line)
    local radius, blocker = 1.5, 0
    local a, b = tostring(line or ""):match("([%d%.]+)%s*([%d]*)")
    if a and tonumber(a) then radius = tonumber(a) end
    if b and tonumber(b) then blocker = tonumber(b) end
    if not AI or not AI.SetPFBlockerRadius then navSay("AI.SetPFBlockerRadius is missing"); return end

    local tried, ok, firstErr = 0, 0, nil
    for _, id in ipairs(self.WallSegEnts or {}) do
        local ent
        pcall(function() ent = System.GetEntity(id) end)
        if ent then
            tried = tried + 1
            local good, err = pcall(function() AI.SetPFBlockerRadius(ent.id, blocker, radius) end)
            if good then ok = ok + 1 elseif not firstErr then firstErr = tostring(err) end
        end
    end
    navSay(string.format("SetPFBlockerRadius(blocker=%d, r=%.2f): %d/%d segment(s) accepted",
        blocker, radius, ok, tried))
    if firstErr then navSay("   first error: " .. firstErr) end
    navSay("now walk a merc at the wall; nothing changing means the bind needs an AI object")
end

mercenaries:DevCommand("merc_nav_engine",     "mercenaries:NavEngineReport()",
    "Report the engine obstacle/navmesh cvars and the wall size")
mercenaries:DevCommand("merc_nav_engine_arm", "mercenaries:NavEngineArm(%line)",
    "Turn the engine obstacle systems on (1) or put them back (0)")
mercenaries:DevCommand("merc_nav_blockers",   "mercenaries:NavEngineBlockers(%line)",
    "Try AI.SetPFBlockerRadius on every wall segment: merc_nav_blockers [radius] [blockerType]")

mercenaries:DevCommand("merc_nav_build",  "mercenaries:NavBuild(%line)", "Build the camp nav graph: merc_nav_build [radius] [spacing]")
mercenaries:DevCommand("merc_nav_show",   "mercenaries:NavShow()",       "Mark the nodes that sit against a wall")
mercenaries:DevCommand("merc_nav_test",   "mercenaries:NavTest()",       "Path from you to the crosshair, drawn with markers")
mercenaries:DevCommand("merc_nav_clear",  "mercenaries:NavClearDebug()", "Remove nav debug markers")
mercenaries:DevCommand("merc_nav_patrol", "mercenaries:NavRefreshPatrolRings()", "Re-cut the guards' patrol route along the wall")
mercenaries:DevCommand("merc_nav_debug",  "mercenaries:SetNavDebug(%line)", "Nav logging on the hot path: 0 or 1")
mercenaries:DevCommand("merc_nav_lane",   "mercenaries:SetNavLane(%line)",  "How far off the shared route each NPC walks: merc_nav_lane <metres>, 0 for single file")
mercenaries:DevCommand("merc_nav_aim",    "mercenaries:SetNavAim(%line)",   "How far ahead the steering point is held: merc_nav_aim <metres>, higher = smoother, 0 = halts at waypoints")
mercenaries:DevCommand("merc_nav_obs",    "mercenaries:NavObsShow()",       "Mark the tent/hut/fire footprints mercs route around")
mercenaries:DevCommand("merc_nav_avoid",  "mercenaries:SetNavAvoid(%line)", "How far outside a camp footprint a route is aimed: merc_nav_avoid <metres>")
mercenaries:DevCommand("merc_nav_follow", "mercenaries:SetNavFollow(%line)", "Route following mercs round camp geometry: 0 or 1")
