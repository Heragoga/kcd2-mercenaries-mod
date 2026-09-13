-- FAST-TRAVEL / WORLD-FREEZE TRACER. Always on, one pass per second, near-zero cost.
--
-- Fast travel is where every timing assumption in the mod goes to die: the map screen
-- freezes the behaviour trees and the world clock while real time (and Lua timers, once
-- the engine unpauses) march on, arrival teleports the player hundreds of metres, and
-- the frozen window's queued timer firings land back to back in the first frames after.
-- The follow-watch storm hid in exactly that blind spot, and so did the restored-timer
-- flood (see the SchedOnLoad block in mercenaries_scheduler.lua). This module makes the
-- window observable: it detects freezes, teleports and time skips, and while one is in
-- progress - and for a tail after it - logs per second what the mod actually did.
--
-- Counters it reads (incremented at the source, one add each):
--   _mtFired          master-tick firings           (mercenaries_scheduler.lua)
--   _ftRaid           raid-tick body runs           (mercenaries_raids.lua)
--   _ftFollowRefires  follow re-fires               (mercenaries_formation_handler.lua)
--   _ftStanddowns     systemic stand-down passes    (mercenaries_formation_handler.lua)
--   ChainDrained      stale/restored timer drains   (mercenaries.lua)
--
-- Everything logs with the [FTTrace] prefix.

-- OFF by default. This armed itself on every load with no switch at all and logged at 1 Hz
-- for the whole session (171 lines in the user's last one). It is the right tool for a
-- fast-travel or time-skip investigation and nothing else, so it waits to be asked.
mercenaries.FtTraceOn       = false
mercenaries.FtTraceTickMs   = 1000
mercenaries.FtJumpMeters    = 150.0   -- position delta in one tick that means teleport
mercenaries.FtTimeSkipSecs  = 300.0   -- world-clock delta in one tick that means time skip
mercenaries.FtTailSecs      = 15      -- verbose seconds after an event
mercenaries.FtWindowMaxLogs = 25      -- per event, so a wedged window cannot flood the log

local function ftLog(s) System.LogAlways("[FTTrace] " .. tostring(s)) end

local function ftClock()
    local c = (os and os.clock) and os.clock() or nil
    if c then return c end
    local t = 0
    pcall(function() t = System.GetCurrTime() or 0 end)
    return t
end

local function ftWorld()
    local t = 0
    pcall(function() t = System.GetCurrTime() or 0 end)
    return t
end

-- Sum of slot run counters; the per-second delta says how busy the scheduler really was.
local function ftSlotRuns()
    local n = 0
    for _, s in pairs(mercenaries.SchedSlots or {}) do n = n + (s.runs or 0) end
    return n
end

function mercenaries:FtSnapshot()
    return {
        master  = self._mtFiredTotal or 0,
        raid    = self._ftRaid or 0,
        refires = self._ftFollowRefires or 0,
        stand   = self._ftStanddowns or 0,
        drains  = (self.ChainDrained and self.ChainDrained._total) or 0,
        slots   = ftSlotRuns(),
    }
end

local function ftDelta(a, b)
    return string.format("master=%d raid=%d slots=+%d drains=+%d refires=+%d standdown=+%d",
        b.master - a.master, b.raid - a.raid, b.slots - a.slots,
        b.drains - a.drains, b.refires - a.refires, b.stand - a.stand)
end

function mercenaries:FtOpenWindow(reason)
    local S = self._ftState
    S.windowUntil = ftClock() + self.FtTailSecs
    S.windowLogs = 0
    S.windowSnap = self:FtSnapshot()
    ftLog("VERBOSE WINDOW OPEN: " .. reason)
end

function mercenaries:FtTraceBody()
    local S = self._ftState
    if not S then return end

    local real  = ftClock()
    local world = ftWorld()
    local pos
    pcall(function() pos = player and player:GetWorldPos() end)

    local realDt  = S.real  and (real  - S.real)  or 0
    local worldDt = S.world and (world - S.world) or 0

    -- The three event edges. Frozen = the world clock stopped while real time ran: the
    -- map screen, a menu, a loading fade. A teleport or a time skip is a fast travel,
    -- a sleep or a scripted move; all of them open the verbose window.
    local frozen = (realDt > 0.8) and (worldDt < realDt * 0.25)
    if frozen and not S.frozen then
        S.frozen, S.frozenAt = true, real
        ftLog(string.format("world FROZEN (map/menu/dialog?) - world clock +%.2fs against real +%.2fs",
                            worldDt, realDt))
        self:FtOpenWindow("freeze started")
    elseif not frozen and S.frozen then
        S.frozen = false
        ftLog(string.format("world RESUMED after %.1fs frozen - watching the catch-up burst", real - (S.frozenAt or real)))
        self:FtOpenWindow("freeze ended")
    end

    if pos and S.pos then
        local dx, dy = pos.x - S.pos.x, pos.y - S.pos.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d > self.FtJumpMeters then
            ftLog(string.format("PLAYER JUMPED %.0fm (fast travel / teleport) to (%.0f, %.0f)", d, pos.x, pos.y))
            self:FtOpenWindow("position jump")
        end
    end
    if worldDt > self.FtTimeSkipSecs then
        ftLog(string.format("GAME TIME SKIPPED +%.1fh (fast travel / sleep) - GameTime waits all expire now", worldDt / 3600.0))
        self:FtOpenWindow("time skip")
    end

    -- Inside a window: one accounting line per second, capped.
    if S.windowUntil and real < S.windowUntil and S.windowLogs < self.FtWindowMaxLogs then
        S.windowLogs = S.windowLogs + 1
        local snap = self:FtSnapshot()
        ftLog(string.format("+%2ds %s | world+%.1fs%s",
            math.floor(real - (S.windowUntil - self.FtTailSecs)),
            ftDelta(S.windowSnap, snap), worldDt, S.frozen and " [frozen]" or ""))
        S.windowSnap = snap
    elseif S.windowUntil and real >= S.windowUntil then
        S.windowUntil = nil
        ftLog("verbose window closed")
    end

    S.real, S.world, S.pos = real, world, pos
end

function mercenaries:FtTraceDrive()
    pcall(function() self:FtTraceBody() end)
    self:ChainArm("FtTrace", self.FtTraceTickMs)
end
mercenaries:ChainDef("FtTrace", "FtTraceDrive")

function mercenaries:FtTraceArm()
    self:ChainArm("FtTrace", self.FtTraceTickMs)
end

-- Per load: fresh state, fresh chain. The previous load's chain carries a stale
-- generation and drains itself on its next firing.
function mercenaries:FtTraceOnLoad()
    if not self.FtTraceOn then return end
    self._ftState = { windowLogs = 0 }
    self._ftRaid, self._ftFollowRefires, self._ftStanddowns = 0, 0, 0
    self._mtFiredTotal = 0
    self:FtTraceArm()
    local drained = (self.ChainDrained and self.ChainDrained._total) or 0
    ftLog("armed (1s cadence)" .. (drained > 0 and (" - " .. drained .. " stale timer(s) drained so far this session") or ""))
end
