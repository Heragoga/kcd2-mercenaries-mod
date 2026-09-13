-- Verbose instrumentation for the camp lag.
--
-- merc_prof times the mod's own calls and reports ~0 ms for all of them, while the frame
-- histogram shows a quarter of frames in the 50-100 ms band. That combination means the cost is
-- not Lua CPU inside a mod function - it is work the mod ASKS THE ENGINE to do (raycasts,
-- sphere queries, physics) or garbage it hands the collector. Neither is visible to a timer.
--
-- So this counts the expensive primitives instead of timing the functions that call them. A
-- storm shows up as a number in the thousands per window; anything innocent stays small.
--
-- merc_verbose 1 to arm, 0 to stop. Off by default: the wrappers cost something themselves, and
-- one of them replaces a System global for as long as it is on.

local function vLog(msg) System.LogAlways("[MercVerbose] " .. tostring(msg)) end

-- REAL time. System.GetCurrTime is ENGINE time, and a KCD wait/sleep runs the engine clock
-- fast - which silently wrecked the first reading: every window taken during a wait reported
-- "2.0 fps" because it was dividing real frames by ~29x-inflated seconds. 2.0 x 29.4 = 59, so
-- the game was in fact running at ~60 fps the whole time and the metric was measuring the time
-- scale, not the frame rate. os.clock() is wall time on Windows and is what the profiler
-- already uses, so the same numbers mean the same thing in both tools.
local realClock = (os and os.clock) or
                  (System.GetCurrAsyncTime and function() return System.GetCurrAsyncTime() end) or
                  function() return (System.GetCurrTime and System.GetCurrTime()) or 0 end

mercenaries.VerboseOn     = false
mercenaries.VerboseEvery  = 10.0     -- seconds between reports
mercenaries.VerboseLast   = nil
mercenaries.VerboseCounts = {}
mercenaries.VerbosePrev   = {}
mercenaries._verboseSaved = nil

local function bump(k, n)
    local c = mercenaries.VerboseCounts
    c[k] = (c[k] or 0) + (n or 1)
end
mercenaries.VerboseBump = bump

-- Wrap a mercenaries method so every call is counted. Returns the original.
local function wrapMethod(name)
    local orig = mercenaries[name]
    if type(orig) ~= "function" then return nil end
    mercenaries[name] = function(self, ...)
        bump(name)
        return orig(self, ...)
    end
    return orig
end

-- The primitives worth counting. CampSnapToGround is the prime suspect: the A* graph does one
-- per node and rebuilds whenever WallTouched fires, which includes any gate change.
mercenaries.VerboseMethods = {
    "CampSnapToGround",   -- a ground RAYCAST each
    "NavIsBlocked",       -- 2D segment tests, one per graph edge per wall segment
    "NavBuild",           -- full graph rebuild: one raycast per node
    "WallTouched",        -- invalidates the graph - who keeps bumping it?
    "NavPathAround",      -- an A* search
    "NavSteerPoint",
    "NavWallSegments",
    "SolidCandidates",
    "SolidSweep",
    "WBAttackersNearCamp",
    "PerfScanNpcs",
    "PatrolTickOne",
    -- Every tick chain that only does work while a wall stands. If the wall cost is in Lua
    -- after all, it is one of these, and the rate per REAL second is what names it - the
    -- first reading could not, because its window was measured on the engine clock and a
    -- wait made every window a third of a second long.
    "WBTickDrive",
    "SolidTickDrive",
    "NavObstTickDrive",
    "NavObstAgentPass",
    "FormationLoopDrive",
    "RaidTickDrive",
    "MonitorLoopDrive",
    "CombatScanLoopDrive",
}

function mercenaries:VerboseArm(on)
    on = (on ~= false)
    if on == self.VerboseOn then
        vLog("already " .. (on and "on" or "off"))
        return
    end

    if on then
        self._verboseSaved = { methods = {}, sphere = nil, sphereByClass = nil, byClass = nil }
        for _, n in ipairs(self.VerboseMethods) do
            local orig = wrapMethod(n)
            if orig then self._verboseSaved.methods[n] = orig end
        end

        -- Engine entity queries: the mod makes a lot of these and they are pure engine cost, so
        -- a timer around the caller shows nothing. Restored verbatim when verbose stops.
        local s1 = System.GetEntitiesInSphere
        if s1 then
            self._verboseSaved.sphere = s1
            System.GetEntitiesInSphere = function(...)
                bump("System.GetEntitiesInSphere")
                return s1(...)
            end
        end
        local s2 = System.GetEntitiesInSphereByClass
        if s2 then
            self._verboseSaved.sphereByClass = s2
            System.GetEntitiesInSphereByClass = function(...)
                bump("System.GetEntitiesInSphereByClass")
                return s2(...)
            end
        end
        local s3 = System.GetEntitiesByClass
        if s3 then
            self._verboseSaved.byClass = s3
            System.GetEntitiesByClass = function(...)
                bump("System.GetEntitiesByClass")
                return s3(...)
            end
        end

        self.VerboseCounts, self.VerbosePrev, self.VerboseLast = {}, {}, nil
        self.VerboseOn = true
        vLog("armed - counting engine primitives; report every " .. self.VerboseEvery .. "s")
        vLog("counting: " .. table.concat(self.VerboseMethods, ", "))
        self:ChainArm("VerboseTick", 2000)
    else
        local sv = self._verboseSaved or {}
        for n, orig in pairs(sv.methods or {}) do mercenaries[n] = orig end
        if sv.sphere then System.GetEntitiesInSphere = sv.sphere end
        if sv.sphereByClass then System.GetEntitiesInSphereByClass = sv.sphereByClass end
        if sv.byClass then System.GetEntitiesByClass = sv.byClass end
        self._verboseSaved = nil
        self.VerboseOn = false
        vLog("stopped - everything restored")
    end
end

function mercenaries:VerboseReport()
    local c, prev = self.VerboseCounts, self.VerbosePrev
    local keys = {}
    for k in pairs(c) do keys[#keys + 1] = k end
    if #keys == 0 then vLog("nothing counted yet"); return end
    table.sort(keys, function(a, b) return ((c[a] or 0) - (prev[a] or 0)) > ((c[b] or 0) - (prev[b] or 0)) end)

    local where = "?"
    pcall(function()
        local p, cc = player:GetWorldPos(), self.CampCenter
        if p and cc then
            where = string.format("%.0fm from camp", math.sqrt((p.x - cc.x) ^ 2 + (p.y - cc.y) ^ 2))
        end
    end)
    local ratio = "?"
    pcall(function() ratio = string.format("%.1f", Calendar.GetWorldTimeRatio() or 1) end)

    local walls = 0
    pcall(function() walls = #(self.WallSegEnts or {}) end)
    vLog(string.format("---- last %.0fs | %s | world/real x%s | %d wall segment(s) ----",
                       self.VerboseEvery or 10.0, where, ratio, walls))
    pcall(function() vLog(self:VerboseFrameLine()) end)
    for _, k in ipairs(keys) do
        local d = (c[k] or 0) - (prev[k] or 0)
        if d > 0 then
            vLog(string.format("   %-34s %6d  (total %d)", k, d, c[k]))
        end
    end
    for _, k in ipairs(keys) do prev[k] = c[k] end
end

-- FPS per window, so "with wall" and "without wall" can be compared as numbers instead of as
-- impressions. System.GetFrameID is the frame counter (confirmed live in retail); frames
-- divided by elapsed real seconds is the average, and the worst 2 s sample in the window is the
-- stutter. Counters alone could not answer this: they were small in BOTH halves of the last A/B.
function mercenaries:VerboseFrameSample()
    local f, t, g = nil, realClock(), 0
    pcall(function() f = System.GetFrameID() end)
    pcall(function() g = System.GetCurrTime() or 0 end)
    if not (f and t > 0) then return end
    if self._vfLastF and t > self._vfLastT then
        local df, dt = f - self._vfLastF, t - self._vfLastT
        if df > 0 and dt > 0.02 then
            local fps = df / dt
            self._vfFrames = (self._vfFrames or 0) + df
            self._vfTime   = (self._vfTime or 0) + dt
            self._vfEngine = (self._vfEngine or 0) + (g - (self._vfLastG or g))
            if (not self._vfWorst) or fps < self._vfWorst then self._vfWorst = fps end
        end
    end
    self._vfLastF, self._vfLastT, self._vfLastG = f, t, g
end

function mercenaries:VerboseFrameLine()
    local avg = (self._vfTime and self._vfTime > 0) and (self._vfFrames / self._vfTime) or nil
    local line
    if avg then
        -- engine seconds per real second: 1.0 in normal play, ~29 during a wait or a sleep.
        -- Printed because it is the thing that made the first reading unreadable, and because
        -- a window taken during a wait is not comparable to one taken while walking about.
        local scale = (self._vfTime > 0) and ((self._vfEngine or 0) / self._vfTime) or 1
        line = string.format("   %-34s avg %.1f fps (%.1f ms), worst %.1f fps (%.1f ms), timescale x%.1f",
                             "FRAMES", avg, 1000 / avg,
                             self._vfWorst or avg, 1000 / (self._vfWorst or avg), scale)
    else
        line = "   FRAMES                             (no frame data)"
    end
    self._vfFrames, self._vfTime, self._vfWorst, self._vfEngine = 0, 0, nil, 0
    return line
end

function mercenaries:VerboseTickDrive()
    if not self.VerboseOn then return end
    -- real seconds, not engine seconds: during a wait the engine clock runs ~29x, so a window
    -- measured on it was a third of a second long and every counter in it read ~29x low.
    local t = realClock()
    pcall(function() self:VerboseFrameSample() end)
    if not self.VerboseLast then self.VerboseLast = t end
    if (t - self.VerboseLast) >= (self.VerboseEvery or 10.0) then
        self.VerboseLast = t
        pcall(function() self:VerboseReport() end)
    end
    self:ChainArm("VerboseTick", 2000)
end
mercenaries:ChainDef("VerboseTick", "VerboseTickDrive")

function mercenaries:VerboseSet(line)
    local n = tonumber(tostring(line or ""):match("%-?%d+") or "")
    self:VerboseArm(n ~= 0)
end

System.AddCCommand("merc_verbose", "mercenaries:VerboseSet('%line')",
                   "Count the engine primitives the mod asks for (raycasts, sphere queries, graph rebuilds): 1 on, 0 off")
System.AddCCommand("merc_verbose_now", "mercenaries:VerboseReport()",
                   "Print the verbose counters immediately")

-- ==== what does a wall actually cost? ====
--
-- Every Lua counter is innocent: NavIsBlocked runs about 50 times per window against 30 cached
-- segments, and merc_prof times every mod function at ~0 ms. So if a palisade costs frame rate
-- the cost is engine-side, in one of three things a wall segment is:
--     a drawn mesh        - 30 never-culling entity render nodes
--     a shadow caster     - SetViewDistUnlimited + RenderShadow(true), so they are submitted
--                           to every cascade at any range
--     a physical body     - collision, and the dynamic-obstacle registration that feeds
--                           collision avoidance for every agent near it
-- These switch each one off in place, without removing the entities, rebuilding the camp or
-- touching the saved layout. Flip one, read the FRAMES line, flip it back: whichever restores
-- the frame rate is the subsystem paying. Nothing here persists - a camp rebuild or a load
-- puts every segment back exactly as it was spawned.

function mercenaries:WallEachSeg(fn)
    local n = 0
    for _, id in ipairs(self.WallSegEnts or {}) do
        local e
        pcall(function() e = System.GetEntity(id) end)
        if e and pcall(function() fn(e) end) then n = n + 1 end
    end
    return n
end

function mercenaries:WallDrawSet(line)
    local on = (tonumber(tostring(line or ""):match("%-?%d+") or "1") ~= 0)
    local n = self:WallEachSeg(function(e) e:DrawSlot(0, on and 1 or 0) end)
    vLog(string.format("wall mesh %s on %d segment(s) - physics and obstacles untouched",
                       on and "DRAWN" or "HIDDEN", n))
end

function mercenaries:WallShadowSet(line)
    local on = (tonumber(tostring(line or ""):match("%-?%d+") or "1") ~= 0)
    local n = self:WallEachSeg(function(e)
        e:RenderShadow(on and 1 or 0)
        -- the never-cull flag goes with it: an unlimited view distance is what forces a
        -- segment into the distant cascades in the first place
        if on then e:SetViewDistUnlimited() else e:SetViewDistRatio(100) end
    end)
    vLog(string.format("wall shadows %s on %d segment(s) (view distance %s)",
                       on and "ON" or "OFF", n, on and "unlimited" or "ratio 100"))
end

function mercenaries:WallPhysSet(line)
    local on = (tonumber(tostring(line or ""):match("%-?%d+") or "1") ~= 0)
    local n = self:WallEachSeg(function(e) e:EnablePhysics(on and 1 or 0) end)
    vLog(string.format("wall physics %s on %d segment(s) - the mesh still draws; NPCs and the "
                       .. "player will walk through while this is off", on and "ON" or "OFF", n))
end

System.AddCCommand("merc_wall_draw", "mercenaries:WallDrawSet('%line')",
                   "Wall segments: 0 stops drawing the mesh (physics kept), 1 draws it again")
System.AddCCommand("merc_wall_shadow", "mercenaries:WallShadowSet('%line')",
                   "Wall segments: 0 stops shadow casting and unlimited view distance, 1 restores")
System.AddCCommand("merc_wall_phys", "mercenaries:WallPhysSet('%line')",
                   "Wall segments: 0 switches physics off (mesh kept), 1 back on")
