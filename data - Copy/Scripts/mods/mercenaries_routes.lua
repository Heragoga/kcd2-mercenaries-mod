-- Patrol route recorder.
--
-- Ride the route you want a patrol to walk and it drops a marker every PatrolRouteStep
-- metres. F5 starts a new recording, F6 keeps it, F7 throws it away, F8 dumps everything
-- recorded so far in a form that can be pasted into the mod.
--
-- Routes are saved as flat text (SaveString "QMRoutes") so they survive a reload while
-- they are being collected. They are working data for authoring, not a shipping feature -
-- the end state is a table of routes baked into the mod, which is what merc_route_dump
-- exists to produce.

mercenaries.PatrolRoutes     = {}     -- { { name=, pts={ {x,y,z}, ... } }, ... }
mercenaries.RouteRecording   = nil    -- { name=, pts={}, ents={} } while F5 is active
mercenaries.PatrolRouteStep  = 10.0   -- metres between markers
mercenaries.RouteTickMs      = 250

local function rLog(s) System.LogAlways("[Routes] " .. s) end

local ROUTE_MARKER = "objects/manmade/common_furniture/barrels/barrel_a.cgf"

local function spawnMarker(p)
    local e
    pcall(function()
        e = System.SpawnEntity({
            class = "BasicEntity",
            name = "MercRouteMk_" .. tostring(math.random(100000, 999999)),
            position = p,
            properties = { object_Model = ROUTE_MARKER, bMissionCritical = false,
                           bSaved_by_game = false, bSerialize = false },
        })
    end)
    return e
end

-- ==== recording ====
function mercenaries:RouteNew()
    if self.RouteRecording then
        rLog("already recording '" .. tostring(self.RouteRecording.name) .. "' - F6 saves, F7 cancels")
        return
    end
    if not player then return end

    local n = #self.PatrolRoutes + 1
    self.RouteRecording = { name = "route" .. n, pts = {}, ents = {} }
    self:RouteDrop()                       -- the spot you start from is the first point
    self:RouteStart()
    rLog("recording '" .. self.RouteRecording.name .. "' - a marker every " ..
         self.PatrolRouteStep .. "m. F6 save, F7 cancel")
end

function mercenaries:RouteDrop()
    local rec = self.RouteRecording
    if not (rec and player) then return end
    local p; pcall(function() p = player:GetWorldPos() end)
    if not p then return end
    local q = { x = p.x, y = p.y, z = p.z }
    table.insert(rec.pts, q)
    local e = spawnMarker(q)
    if e then table.insert(rec.ents, e) end
end

function mercenaries.RouteTick()
    local self = mercenaries
    pcall(function()
        local rec = self.RouteRecording
        if not (rec and player) then return end
        local last = rec.pts[#rec.pts]
        local p; pcall(function() p = player:GetWorldPos() end)
        if not (p and last) then return end
        local dx, dy = p.x - last.x, p.y - last.y
        if (dx * dx + dy * dy) >= (self.PatrolRouteStep * self.PatrolRouteStep) then
            self:RouteDrop()
        end
    end)
    if mercenaries.RouteRecording then
        Script.SetTimerForFunction(mercenaries.RouteTickMs, "mercenaries.RouteTick")
    end
end

function mercenaries:RouteStart()
    Script.SetTimerForFunction(self.RouteTickMs, "mercenaries.RouteTick")
end

function mercenaries:RouteSave()
    local rec = self.RouteRecording
    if not rec then rLog("not recording - F5 starts a route"); return end
    if #rec.pts < 2 then
        rLog("only " .. #rec.pts .. " point(s) - ride further before saving, or F7 to cancel")
        return
    end
    -- markers stay standing so the finished route is visible; merc_route_clear removes them
    table.insert(self.PatrolRoutes, { name = rec.name, pts = rec.pts, ents = rec.ents })
    rLog("saved '" .. rec.name .. "' with " .. #rec.pts .. " point(s)")
    self.RouteRecording = nil
    self:RoutePersist()
end

function mercenaries:RouteCancel()
    local rec = self.RouteRecording
    if not rec then rLog("not recording"); return end
    for _, e in ipairs(rec.ents or {}) do pcall(function() System.RemoveEntity(e.id) end) end
    rLog("cancelled '" .. rec.name .. "' (" .. #rec.pts .. " point(s) discarded)")
    self.RouteRecording = nil
end

-- ==== output ====
-- Prints the routes as a Lua table, ready to paste into the mod once the shapes are right.
function mercenaries:RouteDump()
    if #self.PatrolRoutes == 0 and not self.RouteRecording then
        rLog("no routes recorded yet - F5 starts one")
        return
    end
    rLog("---- " .. #self.PatrolRoutes .. " route(s) ----")
    -- Routes are stored PER LEVEL (the maps' coordinates overlap), so the dump cannot know
    -- which table it belongs to. Name it after the level it was recorded on and register it
    -- in PatrolRouteSets - see mercenaries_patrols_live.lua.
    rLog("-- rename to the per-level table, e.g. PatrolRoutesKuttenberg / PatrolRoutesTrosky")
    rLog("mercenaries.PatrolRoutes_RENAME_ME = {")
    for _, r in ipairs(self.PatrolRoutes) do
        rLog(string.format('    { name = "%s", pts = {', r.name))
        for i, p in ipairs(r.pts) do
            rLog(string.format("        { x = %.2f, y = %.2f, z = %.2f },   -- %d", p.x, p.y, p.z, i))
        end
        rLog("    } },")
    end
    rLog("}")
    if self.RouteRecording then
        rLog("(still recording '" .. self.RouteRecording.name .. "', " ..
             #self.RouteRecording.pts .. " point(s) so far - not included)")
    end
end

-- ==== persistence ====
-- Flat text: routes separated by ';', points by '|', components by ','.
function mercenaries:RoutePersist()
    local out = {}
    for _, r in ipairs(self.PatrolRoutes) do
        local pts = {}
        for _, p in ipairs(r.pts) do
            table.insert(pts, string.format("%.2f,%.2f,%.2f", p.x, p.y, p.z))
        end
        table.insert(out, r.name .. "=" .. table.concat(pts, "|"))
    end
    self:SaveString("QMRoutes", table.concat(out, ";"))
end

function mercenaries:RouteLoad()
    local s = self:LoadString("QMRoutes")
    if not s or s == "" then return end
    self.PatrolRoutes = {}
    for chunk in s:gmatch("[^;]+") do
        local name, body = chunk:match("^([^=]+)=(.*)$")
        if name and body then
            local r = { name = name, pts = {}, ents = {} }
            for trip in body:gmatch("[^|]+") do
                local x, y, z = trip:match("([^,]+),([^,]+),([^,]+)")
                if x then
                    table.insert(r.pts, { x = tonumber(x), y = tonumber(y), z = tonumber(z) })
                end
            end
            if #r.pts > 0 then table.insert(self.PatrolRoutes, r) end
        end
    end
    rLog(#self.PatrolRoutes .. " route(s) loaded")
end

-- ==== housekeeping ====
function mercenaries:RouteShow(which)
    local i = tonumber(which)
    for n, r in ipairs(self.PatrolRoutes) do
        if (not i) or i == n then
            for _, p in ipairs(r.pts) do
                local e = spawnMarker(p)
                if e then table.insert(r.ents, e) end
            end
        end
    end
    rLog("markers placed")
end

function mercenaries:RouteHide()
    for _, r in ipairs(self.PatrolRoutes) do
        for _, e in ipairs(r.ents or {}) do pcall(function() System.RemoveEntity(e.id) end) end
        r.ents = {}
    end
    if self.RouteRecording then
        for _, e in ipairs(self.RouteRecording.ents or {}) do pcall(function() System.RemoveEntity(e.id) end) end
        self.RouteRecording.ents = {}
    end
    rLog("markers removed (routes kept)")
end

function mercenaries:RouteForget()
    self:RouteHide()
    self.PatrolRoutes = {}
    self.RouteRecording = nil
    self:SaveString("QMRoutes", " ")
    rLog("all routes forgotten")
end

-- Hand a recorded route to the patrol tester, so it can be walked immediately.
function mercenaries:RouteToPatrol(which)
    local i = tonumber(which) or 1
    local r = self.PatrolRoutes[i]
    if not r then rLog("no route " .. tostring(i)); return end
    pcall(function() self:PatrolClearWaypoints() end)
    self.PatrolPoints = {}
    for _, p in ipairs(r.pts) do
        table.insert(self.PatrolPoints, { x = p.x, y = p.y, z = p.z })
    end
    self.PatrolIndex = 1
    rLog("route '" .. r.name .. "' loaded into the patrol tester (" .. #r.pts ..
         " waypoints) - merc_patrol_go to walk it")
end

function mercenaries:RouteStatus()
    rLog(#self.PatrolRoutes .. " saved route(s), step " .. self.PatrolRouteStep .. "m")
    for i, r in ipairs(self.PatrolRoutes) do
        rLog(string.format("  %d: %s, %d point(s)", i, r.name, #r.pts))
    end
    if self.RouteRecording then
        rLog("recording '" .. self.RouteRecording.name .. "': " .. #self.RouteRecording.pts .. " point(s)")
    end
end

function mercenaries:RouteSetStep(v)
    v = tonumber(v)
    if v and v > 0 then self.PatrolRouteStep = v end
    rLog("marker every " .. self.PatrolRouteStep .. "m")
end

System.AddCCommand("merc_route_new",    "mercenaries:RouteNew()",       "F5 - start recording a patrol route")
System.AddCCommand("merc_route_save",   "mercenaries:RouteSave()",      "F6 - keep the route being recorded")
System.AddCCommand("merc_route_cancel", "mercenaries:RouteCancel()",    "F7 - discard the route being recorded")
System.AddCCommand("merc_route_dump",   "mercenaries:RouteDump()",      "F8 - print every recorded route")
System.AddCCommand("merc_route_status", "mercenaries:RouteStatus()",    "How many routes, and what is being recorded")
System.AddCCommand("merc_route_show",   "mercenaries:RouteShow(%line)", "Re-place the markers: merc_route_show [n]")
System.AddCCommand("merc_route_hide",   "mercenaries:RouteHide()",      "Remove the markers, keep the routes")
System.AddCCommand("merc_route_forget", "mercenaries:RouteForget()",    "Delete every recorded route")
System.AddCCommand("merc_route_walk",   "mercenaries:RouteToPatrol(%line)", "Load a route into the patrol tester: merc_route_walk [n]")
System.AddCCommand("merc_route_step",   "mercenaries:RouteSetStep(%line)",  "Metres between markers: merc_route_step <m>")
