-- Camp navmesh: a small node graph laid over the camp so mod NPCs can walk AROUND
-- camp walls, which the engine's own baked navmesh knows nothing about.
--
-- Deliberately narrow. It is only consulted when a straight line from an NPC to its
-- target crosses one of our wall lines, and only near camp; everywhere else the
-- engine paths as it always has. That keeps the interrupt churn (and the risk of
-- behaviour-tree restart thrash) to the one situation this exists for.
--
-- Wall geometry comes from the wall builder's CORNERS (WallMarks + WallClosed), not
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

    local segs, m = {}, self.WallMarks or {}
    local minx, miny, maxx, maxy
    local function acc(x, y)
        if not minx or x < minx then minx = x end
        if not maxx or x > maxx then maxx = x end
        if not miny or y < miny then miny = y end
        if not maxy or y > maxy then maxy = y end
    end
    if #m >= 2 then
        for i = 1, #m - 1 do
            table.insert(segs, { ax = m[i].x, ay = m[i].y, bx = m[i + 1].x, by = m[i + 1].y })
            acc(m[i].x, m[i].y); acc(m[i + 1].x, m[i + 1].y)
        end
        if self.WallClosed and #m > 2 then
            table.insert(segs, { ax = m[#m].x, ay = m[#m].y, bx = m[1].x, by = m[1].y })
        end
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
    for _, m in ipairs(self.WallMarks or {}) do
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
            if not self:NavIsBlocked(anchor, pts[j]) then pick = j; break end
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

-- Sanity check: no leg of the finished route may cross a wall.
function mercenaries:NavValidatePath(from, path)
    local prev, bad = from, 0
    for _, p in ipairs(path or {}) do
        if self:NavIsBlocked(prev, p) then bad = bad + 1 end
        prev = p
    end
    return bad
end

-- THE ENTRY POINT. Returns a list of waypoints from `fromPos` to `toPos` that avoids
-- the walls, or nil when the direct line is already clear / the system does not apply.
function mercenaries:NavPathAround(fromPos, toPos)
    if not (fromPos and toPos) then return nil end
    if not self:NavIsBlocked(fromPos, toPos) then return nil end     -- nothing in the way
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
    self.NavGoto[k] = nil
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
    if self:NavIsBlocked(me, p) then return wp end         -- lane runs into the wall
    return p
end

-- THE SHARED STEERING CORE. Given a caller-owned record, where am I heading right now?
-- Returns the point to steer at, plus true when the target itself is reachable in a
-- straight line. Everything that wants wall-aware movement (nav_goto, the merc slot
-- hook, camp patrol) calls this rather than duplicating the logic.
--
-- `rec` is any table the caller keeps per NPC; this owns the fields path/idx/
-- lastTargetPos/failAt inside it.
function mercenaries:NavSteerPoint(rec, me, tp)
    if not (rec and me and tp) then return tp, true end

    -- Straight line clear? No navmesh at all - the common case, one segment test.
    if not self:NavIsBlocked(me, tp) then
        rec.path, rec.failAt = nil, nil
        return tp, true
    end

    local now = 0
    pcall(function() now = System.GetCurrTime() or 0 end)

    -- Recompute when there is no route, or the target has wandered off the one we
    -- have. The backoff matters: NavPathAround returns nil for several legitimate
    -- reasons (out of range, no graph, wall fully encloses one side), and without it
    -- a blocked NPC re-ran A* on every single tick forever.
    local needPath = (rec.path == nil)
    if needPath and rec.failAt and (now - rec.failAt) < self.NavFailBackoff then
        return tp, false                        -- still cooling off; head at the target
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
    if not path or #path == 0 then return tp, false end   -- no way around; do what we can

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
            if nxt and self:NavIsBlocked(me, nxt) then break end
        end
        rec.idx = rec.idx + 1
        wp = path[rec.idx]
    end
    wp = rec.path and rec.path[rec.idx] or nil
    if not wp then return tp, false end
    return self:NavLaneOffset(rec, me, wp), false
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
    if self:NavIsBlocked(me, q) then return p end
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
    local blocked = self:NavIsBlocked(me, tp)

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
    if not (self.CampCenter and self.WallMarks and #self.WallMarks >= 2 and player) then
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
    if not (ent and self.WallMarks and #self.WallMarks >= 2 and self.CampCenter) then return end

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
    if not (self.WallMarks and #self.WallMarks >= 2 and self.CampCenter) then return false end
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

function mercenaries:NavWallPerimeterPoints(count, startFrac)
    local m = self.WallMarks or {}
    if #m < 3 then return nil end
    count = count or 8
    startFrac = startFrac or 0

    -- polygon edges (closing edge included when the ring is closed)
    local pts = {}
    for i = 1, #m do table.insert(pts, m[i]) end
    if self.WallClosed then table.insert(pts, m[1]) end
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
    local m = self.WallMarks or {}
    local c = self.CampCenter
    if #m < 2 or not c then return {} end
    local out = {}
    for _, e in ipairs({ m[1], m[#m] }) do
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
    if not (self.WallMarks and #self.WallMarks >= 2) then
        navSay("[Nav] no wall - guards keep their camp patrol")
        return
    end
    local n, g = 0, 0
    local guards = {}
    for k in pairs(self.CampPatrollers) do table.insert(guards, k) end
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
    navSay(string.format("wall: %d corner(s)%s, extent %.0fm",
        #(self.WallMarks or {}), self.WallClosed and " closed" or " open", self:NavWallExtent()))
    if not self.CampCenter then navSay("FAIL: no camp"); return end
    if not self:NavIsBlocked(from, to) then navSay("line is clear - no detour needed"); return end
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

System.AddCCommand("merc_nav_build",  "mercenaries:NavBuild(%line)", "Build the camp nav graph: merc_nav_build [radius] [spacing]")
System.AddCCommand("merc_nav_show",   "mercenaries:NavShow()",       "Mark the nodes that sit against a wall")
System.AddCCommand("merc_nav_test",   "mercenaries:NavTest()",       "Path from you to the crosshair, drawn with markers")
System.AddCCommand("merc_nav_clear",  "mercenaries:NavClearDebug()", "Remove nav debug markers")
System.AddCCommand("merc_nav_patrol", "mercenaries:NavRefreshPatrolRings()", "Re-cut the guards' patrol route along the wall")
System.AddCCommand("merc_nav_debug",  "mercenaries:SetNavDebug(%line)", "Nav logging on the hot path: 0 or 1")
System.AddCCommand("merc_nav_lane",   "mercenaries:SetNavLane(%line)",  "How far off the shared route each NPC walks: merc_nav_lane <metres>, 0 for single file")
System.AddCCommand("merc_nav_aim",    "mercenaries:SetNavAim(%line)",   "How far ahead the steering point is held: merc_nav_aim <metres>, higher = smoother, 0 = halts at waypoints")
