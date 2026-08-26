-- One master tick drives the always-on subsystems instead of each re-arming its own
-- timer. Slots are phase-offset so they never land on the same frame, gated so they
-- skip when there is nothing to do, and amortized (perNpc) so per-merc work is spread
-- across ticks rather than done for everyone at once. See docs/performance.md.
--
-- merc_sched 0 falls back to the legacy independent timers without a code change.

-- 50ms was tried and measured: Script.SetTimerForFunction will not go below roughly
-- 100ms here (a 250ms timer landed at 252ms, a 50ms one at 113ms), so every slot ran
-- ~2.3x slower than configured - combatscan at 678ms instead of 300ms. 100 is the
-- lowest base that the engine actually honours. See docs/performance.md.
mercenaries.MasterTickMs   = 100
mercenaries.SchedTick      = 0
mercenaries.SchedSlots     = {}
mercenaries.SchedEnabled   = true    -- flipped by merc_sched; read at OnGameplayStarted
mercenaries.SchedRunning   = false
mercenaries.SchedErrors    = {}

local function schLog(s) System.LogAlways("[MercSched] " .. tostring(s)) end

local function ticksOf(ms)
    return math.max(1, math.floor((ms or 1000) / mercenaries.MasterTickMs + 0.5))
end

-- def = { periodMs, fn, gate, backoff = {idleMs, factor}, perNpc = {table, budget, fn}, phaseTicks }
function mercenaries:SchedRegister(name, def)
    def = def or {}
    local period = ticksOf(def.periodMs)
    local phase = def.phaseTicks
    if not phase then
        self._schedPhaseCursor = (self._schedPhaseCursor or 0) + 1
        phase = self._schedPhaseCursor
    end
    self.SchedSlots[name] = {
        name = name, fn = def.fn, gate = def.gate,
        periodTicks = period, phaseTicks = phase % period,
        backoff = def.backoff, idle = false, idleSince = nil,
        perNpc = def.perNpc, cursor = 1, runs = 0,
    }
end

-- Only the subsystem knows whether its last pass found anything. Re-evaluated every
-- master tick and never latched, so a squad going hot mid-backoff is caught next tick.
function mercenaries:SchedMarkIdle(name, idle)
    local s = self.SchedSlots[name]
    if not s then return end
    if idle then
        if not s.idle then s.idle = true; s.idleSince = self.SchedTick end
    else
        s.idle, s.idleSince = false, nil
    end
end

local function effectivePeriod(self, s)
    if not (s.backoff and s.idle) then return s.periodTicks end
    if (self.SchedTick - (s.idleSince or 0)) < ticksOf(s.backoff.idleMs or 0) then
        return s.periodTicks
    end
    return math.max(s.periodTicks, math.floor(s.periodTicks * (s.backoff.factor or 1)))
end

-- Round-robin over a table of entities: `budget` of them per firing, so the cost per
-- tick is flat regardless of squad size.
local function runPerNpc(self, s)
    local pn = s.perNpc
    local t = self[pn.table]
    if type(t) ~= "table" then return end
    if not s._keys or s._keysDirty then
        s._keys, s._keysDirty = {}, false
        for k in pairs(t) do s._keys[#s._keys + 1] = k end
        s.cursor = 1
    end
    local n = #s._keys
    if n == 0 then s._keysDirty = true; return end
    for _ = 1, math.min(pn.budget or n, n) do
        local k = s._keys[s.cursor]
        local ent = k ~= nil and t[k] or nil
        if ent then pcall(pn.fn, self, ent, k) end
        s.cursor = s.cursor + 1
        if s.cursor > n then s.cursor = 1; s._keysDirty = true end
    end
end

function mercenaries.MasterTick()
    local self = mercenaries
    -- No duplicate-chain guard here, deliberately. A time-based one was tried - exit
    -- without re-arming if this tick landed within 40ms of the last - and it killed the
    -- ONLY chain: after any hitch the engine fires queued timers back to back, two ticks
    -- land close together, and the survivor removed itself. That produced 12 watchdog
    -- re-arms in a single session. Duplicates are prevented at the source instead, by the
    -- latch in SchedStart. A third argument to Script.SetTimerForFunction is also not an
    -- option: it silently stops the timer re-firing at all. See docs/performance.md.
    self.SchedTick = self.SchedTick + 1
    local t = self.SchedTick

    -- Gap between ticks catches main-thread stalls the mod may only be witnessing. GC
    -- sampling and the periodic report live on ProfHeartbeat instead, so they keep
    -- running when this tick is disabled or has stalled.
    if self.ProfEnabled then self:ProfTickGap() end

    for name, s in pairs(self.SchedSlots) do
        local period = effectivePeriod(self, s)
        if (t + s.phaseTicks) % period == 0 then
            local pass = true
            if s.gate then
                local ok, allowed = pcall(s.gate, self)
                pass = ok and allowed and true or false
            end
            if pass then
                s.runs = s.runs + 1
                s._profFiredTick = t
                local ok, err
                local t0 = self.ProfEnabled and self.ProfClock and self:ProfClock() or nil
                if s.perNpc then ok, err = pcall(runPerNpc, self, s)
                elseif s.fn    then ok, err = pcall(s.fn, self) end
                if t0 then self:ProfRecord("slot:" .. name, (self:ProfClock() - t0) * 1000.0) end
                if ok == false then
                    self.SchedErrors[name] = tostring(err)
                    schLog('slot "' .. name .. '" error: ' .. tostring(err))
                end
            end
        end
    end

    -- Re-armed unconditionally and outside the slot loop: a slot that throws must
    -- never be able to stop the master tick.
    Script.SetTimerForFunction(self.MasterTickMs, "mercenaries.MasterTick")
end

-- One master tick means one point of failure for four subsystems, which the legacy
-- independent timers did not have. This buys that robustness back.
function mercenaries.SchedWatchdog()
    local self = mercenaries
    if self.SchedRunning then
        if self.SchedTick == self._schedLastSeenTick then
            self._schedStrikes = (self._schedStrikes or 0) + 1
            -- Strike 1 only warns. Re-arming on a single missed advance is how a merely
            -- slow frame turns into a second live chain, and nothing can detect that
            -- afterwards. Strike 3 gives up on the master tick entirely: with it dead and
            -- the legacy timers never armed, the core loops do not run at all, which is
            -- worse than any performance problem.
            if self._schedStrikes >= 3 then
                schLog("master tick will not run - FALLING BACK to legacy timers for this session")
                self.SchedRunning = false
                self.SchedEnabled = false
                self:SchedArmLegacy()
            elseif self._schedStrikes >= 2 then
                schLog("master tick stalled twice - re-arming")
                self.SchedRunning = false
                self:SchedStart(true)
            else
                schLog("master tick missed an advance - watching (strike 1)")
            end
        else
            self._schedStrikes = 0
        end
        self._schedLastSeenTick = self.SchedTick
    end
    Script.SetTimerForFunction(5000, "mercenaries.SchedWatchdog")
end

-- The pre-scheduler timers. Each loop's wrapper re-arms itself only while
-- SchedRunning is false, so this is safe to call exactly once.
function mercenaries:SchedArmLegacy()
    Script.SetTimerForFunction(1000, "mercenaries.MonitorLoop")
    Script.SetTimerForFunction(300,  "mercenaries.CombatScanLoop")
    Script.SetTimerForFunction(5000, "mercenaries.LowPriorityMonitorLoop")
    Script.SetTimerForFunction(self.FormationTickMs or 150, "mercenaries.FormationLoop")
    schLog("legacy timers armed")
end

-- ---------------------------------------------------------------------------
-- LOAD GENERATION. Call this at the top of OnGameplayStarted, before anything arms
-- a timer.
--
-- Script.SetTimerForFunction chains DO NOT survive a save load - the engine drops
-- them with the level - but this table is plain Lua and survives everything, so any
-- latch guarding a timer has to be reset per load or it locks the timer out for the
-- rest of the session. That is not a theory: LootSweepLoop is armed unconditionally on
-- every load and re-arms itself unconditionally, so if timers survived it would double
-- every single load, and it does not.
--
-- Getting this wrong killed the whole mod on the second save loaded in one session.
-- SchedRunning was still true from the first, SchedStart refused to arm, the master
-- tick never ran again - and with it went MonitorInventory, so the hire tokens were
-- never consumed and hiring silently did nothing. _schedWatchdogArmed was latched the
-- same way, so the one thing that could have noticed was dead too. The log says
-- "master tick already running - refusing to arm a second chain" and then nothing.
-- ---------------------------------------------------------------------------
mercenaries.SchedLoadGen = 0

-- Every latch in the mod that guards a timer chain. They are plain Lua fields, so each
-- one outlives the chain it guards and, left set, means that tick never comes back.
-- The scheduler is the one module that already knows timers die on load, so it clears
-- the lot rather than each module growing its own half-remembered load hook.
--
-- Only latches whose chain is re-armed somewhere belong here: WBRunning and
-- LivePatrolRunning are re-armed by the camp/wall build and by LivePatrolStart in
-- OnGameplayStarted, RaidRunning by OnGameplayStarted, FoeLoopArmed and GearTickArmed
-- on demand the next time there is a foe or an open wardrobe.
mercenaries.TimerLatches = {
    "SchedRunning", "_schedWatchdogArmed",
    "LivePatrolRunning", "RaidRunning", "WBRunning",
    "FoeLoopArmed", "GearTickArmed", "_profHbArmed",
}

function mercenaries:SchedOnLoad()
    self.SchedLoadGen = (self.SchedLoadGen or 0) + 1
    for _, k in ipairs(self.TimerLatches) do self[k] = false end
    self._schedStrikes, self._schedLastSeenTick = 0, nil
end

-- Latched, like WBStart and LivePatrolStart elsewhere in this codebase, but the latch is
-- per LOAD and not per session (see SchedOnLoad). Within one load it still refuses a
-- second chain: OnGameplayStarted arming twice for the same load would leave two ghosts
-- independently driving every slot, doubling the box queries, soul-API validation and
-- formation passes - invisible with no mercs (the slot bodies all gate on ActiveMercs)
-- and compounding with them. Pass force=true to re-arm deliberately.
function mercenaries:SchedStart(force)
    if self.SchedRunning and self._schedArmedGen == self.SchedLoadGen and not force then
        schLog("master tick already running - refusing to arm a second chain")
        return
    end
    self._schedArmedGen = self.SchedLoadGen
    self.SchedEpoch = (self.SchedEpoch or 0) + 1
    self.SchedRunning = true
    self.SchedTick = 0
    self._schedLastSeenTick = nil
    Script.SetTimerForFunction(self.MasterTickMs, "mercenaries.MasterTick")
    if not self._schedWatchdogArmed then
        self._schedWatchdogArmed = true
        Script.SetTimerForFunction(5000, "mercenaries.SchedWatchdog")
    end
    schLog("master tick armed at " .. self.MasterTickMs .. "ms, epoch " ..
           tostring(self.SchedEpoch) .. ", " .. self:_TableCount(self.SchedSlots) .. " slot(s)")
end

function mercenaries:SchedStatus()
    schLog(string.format("enabled=%s running=%s tick=%d",
                         tostring(self.SchedEnabled), tostring(self.SchedRunning), self.SchedTick or 0))
    for name, s in pairs(self.SchedSlots) do
        schLog(string.format("  %-18s every %4dms%s runs=%d%s",
            name, s.periodTicks * self.MasterTickMs,
            s.idle and " (idle-backoff)" or "",
            s.runs or 0,
            self.SchedErrors[name] and ("  LAST ERROR: " .. self.SchedErrors[name]) or ""))
    end
end

function mercenaries:SchedSet(v)
    local raw = tostring(v or ""):gsub("%s+", "")
    local on = not (raw == "0" or raw == "off" or raw == "false")
    self.SchedEnabled = on
    schLog("scheduler " .. (on and "ENABLED" or "DISABLED") ..
           " - takes effect on the next load (legacy timers are used when disabled)")
end

mercenaries:DevCommand("merc_sched", "mercenaries:SchedSet('%line')",
                   "Master scheduler on/off, applied at next load: merc_sched 1 | 0")
mercenaries:DevCommand("merc_sched_status", "mercenaries:SchedStatus()",
                   "Report master scheduler slots, rates and any slot errors")

-- ---------------------------------------------------------------------------
-- Slot registration. Bodies live in their own modules; this only says when they run.
-- ---------------------------------------------------------------------------

function mercenaries:SchedRegisterAll()
    self.SchedSlots = {}
    self._schedPhaseCursor = 0

    local function haveMercs(s) return next(s.ActiveMercs or {}) ~= nil end

    self:SchedRegister("mercpos", {
        periodMs = 50, gate = haveMercs,
        fn = function(s) s:PerfScanMercs() end,
    })

    -- Flat 150ms, never backed off: squad responsiveness is the one thing that must
    -- not lag. Its win comes from the caches, not from running less often.
    self:SchedRegister("formation", {
        periodMs = 150,
        gate = function(s) return next(s.ActiveMercs or {}) ~= nil and player ~= nil end,
        fn = function(s) s:FormationLoopBody() end,
    })

    -- Four mercs per 50ms tick: a 50-man company is fully refreshed inside ~0.6s.
    self:SchedRegister("campactorsweep", {
        periodMs = 50, gate = haveMercs,
        perNpc = { table = "ActiveMercs", budget = 4,
                   fn = function(s, ent)
                            local w = ent and (ent.this and ent.this.id or ent.id)
                            if w then s:CampActorRefresh(w) end
                        end },
    })

    self:SchedRegister("combatscan", {
        periodMs = 300,
        backoff = { idleMs = 5000, factor = 2 },
        fn = function(s) s:CombatScanLoopBody() end,
    })

    self:SchedRegister("monitor", {
        periodMs = 1000,
        fn = function(s) s:MonitorLoopBody() end,
    })

    self:SchedRegister("lowpriority", {
        periodMs = 5000,
        fn = function(s) s:LowPriorityMonitorLoopBody() end,
    })
end
