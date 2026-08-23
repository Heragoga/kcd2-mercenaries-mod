-- Diagnostic profiler. Built for one symptom: periodic hitching at CONSTANT fps.
-- A steady per-frame load lowers fps; a hitch at steady fps means something expensive
-- fires on an INTERVAL. So this measures spikes and their PERIOD, not averages.
--
-- System.GetCurrTime() is engine-cached per frame and returns the same value all frame,
-- so it cannot time anything inside a frame. os.clock() is the only usable source here.
-- Run merc_prof_timer once before trusting a single number below.
--
-- Off by default; merc_prof 1 turns it on and instruments in one step.
-- See docs/performance.md.

-- OFF by default. Instrumentation wraps ~74 functions and allocates a table per call
-- to preserve return arity, which is real cost in normal play. merc_prof 1 turns it on
-- and instruments in one step.
mercenaries.ProfEnabled     = false
mercenaries.ProfHitchMs     = 6.0    -- a single wrapped call slower than this is logged
mercenaries.ProfGapMs       = 300.0  -- master-tick gap over this = a real stall. Must stay well
                                     -- above the engine's ~100ms timer floor or every tick 'stalls'.
mercenaries.ProfElevatedMul = 1.3    -- gaps over this multiple of schedule are counted quietly
mercenaries.ProfHeartbeatMs = 250
mercenaries.ProfReportSec   = 30.0
mercenaries.ProfStats       = {}
mercenaries.ProfHitches     = {}
mercenaries.ProfMaxHitchLog = 40
mercenaries._profWrapped    = mercenaries._profWrapped or {}
mercenaries._profDepth      = 0

local function pLog(s) System.LogAlways("[MercProf] " .. tostring(s)) end

local clock =
    (os and os.clock) or
    (System.GetCurrAsyncTime and function() return System.GetCurrAsyncTime() end) or
    function() return 0 end

mercenaries.ProfClockName =
    (os and os.clock) and "os.clock" or
    (System.GetCurrAsyncTime and "System.GetCurrAsyncTime" or "NONE - timings are meaningless")

function mercenaries:ProfClock() return clock() end

-- Lua 5.1 has no table.pack. Preserves embedded nils and the exact return count, which
-- matters because some instrumented functions return 5 values (PatrolCtx).
local unpk = unpack or table.unpack
local function pack(...) return { n = select("#", ...), ... } end

local function stat(name)
    local s = mercenaries.ProfStats[name]
    if not s then
        s = { n = 0, total = 0, max = 0, last = 0, hitches = 0, lastHitchAt = nil,
              periodSum = 0, periodN = 0 }
        mercenaries.ProfStats[name] = s
    end
    return s
end

-- nested=true means this call ran inside another timed call, so its time is already
-- counted in the outer one. Nested calls never log a hitch: the inner and outer entries
-- would appear ~0ms apart and read exactly like a heartbeat that isn't there.
-- Gauges, not durations: their normal value IS their schedule, so the duration hitch
-- threshold is meaningless for them. They have their own STALL thresholds instead.
mercenaries.ProfGauges = { ["~mastertick gap"] = true, ["~heartbeat gap"] = true }

function mercenaries:ProfRecord(name, ms, nested)
    local s = stat(name)
    if self.ProfGauges[name] then
        s.n = s.n + 1; s.total = s.total + ms; s.last = ms
        if ms > s.max then s.max = ms end
        return
    end
    s.n     = s.n + 1
    s.total = s.total + ms
    s.last  = ms
    if ms > s.max then s.max = ms end
    if nested then s.nested = true; return end
    if ms < self.ProfHitchMs then return end

    s.hitches = s.hitches + 1
    local now = clock()
    -- Period is measured PER NAME. One shared timestamp would report the gap since some
    -- other source's hitch, which is not a period for either of them.
    local sinceSame = s.lastHitchAt and ((now - s.lastHitchAt) * 1000.0) or -1
    s.lastHitchAt = now
    if sinceSame > 0 then s.periodSum = s.periodSum + sinceSame; s.periodN = s.periodN + 1 end

    local prevAny = self._profLastHitchAt
    local sinceAny = prevAny and ((now - prevAny) * 1000.0) or -1
    self._profLastHitchAt = now

    pLog(string.format("HITCH %-30s %7.2fms  (%.0fms since last of THIS, %.0fms since any)",
                       name, ms, sinceSame, sinceAny))
    local h = self.ProfHitches
    h[#h + 1] = { name = name, ms = ms, same = sinceSame, any = sinceAny }
    if #h > self.ProfMaxHitchLog then table.remove(h, 1) end
end

-- Always pcalls, profiling on or off: 15 of the call sites this replaced were already
-- pcall-wrapped, and dropping that under merc_prof 0 would remove protection they had
-- before the profiler existed.
function mercenaries:ProfCall(name, method, ...)
    local f = self[method]
    if not f then return nil end
    local t0 = self.ProfEnabled and clock() or nil
    local r = pack(pcall(f, self, ...))
    if t0 then self:ProfRecord(name, (clock() - t0) * 1000.0) end
    if not r[1] then
        pLog("error inside " .. name .. ": " .. tostring(r[2]))
        return nil
    end
    return unpk(r, 2, r.n)
end

-- Wraps a method in place, so behaviour-tree ExecuteLua hooks get timed without editing
-- a single XML file. Deliberately NOT pcalled: the originals let errors propagate and
-- their callers already pcall where they need to.
function mercenaries:ProfInstrumentMethod(method, label, isBt)
    if self._profWrapped[method] then return true end
    local orig = self[method]
    if type(orig) ~= "function" then return false end
    self._profWrapped[method] = orig
    label = label or method
    self[method] = function(...)
        local M = mercenaries
        if not M.ProfEnabled then return orig(...) end
        local d = M._profDepth or 0
        M._profDepth = d + 1
        local t0 = clock()
        local r = pack(orig(...))
        local ms = (clock() - t0) * 1000.0
        M._profDepth = d
        if isBt and d == 0 then M._profBtMs = (M._profBtMs or 0) + ms end
        M:ProfRecord(label, ms, d > 0)
        return unpk(r, 1, r.n)
    end
    return true
end

function mercenaries:ProfUninstrumentAll()
    for m, orig in pairs(self._profWrapped) do self[m] = orig end
    self._profWrapped = {}
    pLog("method instrumentation removed")
end

-- ---------------------------------------------------------------------------
-- Stall detection
-- ---------------------------------------------------------------------------

-- Called from MasterTick. The gap between consecutive ticks should be ~MasterTickMs; far
-- over means the main thread stalled, and whatever ran on the PREVIOUS tick is the
-- suspect - that tick's work is what occupied the gap being measured.
function mercenaries:ProfTickGap()
    if not self.ProfEnabled then return end
    local now  = clock()
    local prev = self._profLastTickAt
    self._profLastTickAt = now
    if not prev then return end

    local gapMs = (now - prev) * 1000.0
    local sched = self.MasterTickMs or 50
    self:ProfRecord("~mastertick gap", gapMs)
    if gapMs > sched * (self.ProfElevatedMul or 1.3) then
        local e = stat("~mastertick gap")
        e.elevated = (e.elevated or 0) + 1
    end
    if gapMs >= self.ProfGapMs then
        local fired = {}
        for name, sl in pairs(self.SchedSlots or {}) do
            -- A slot that fires every tick appears in every stall regardless of cause,
            -- so it is not evidence. Only periodic slots are named.
            if sl._profFiredTick == (self.SchedTick - 1) and (sl.periodTicks or 1) > 1 then
                fired[#fired + 1] = name
            end
        end
        pLog(string.format("STALL %.0fms between master ticks (scheduled %dms). Ran on the previous tick: %s",
                           gapMs, sched,
                           #fired > 0 and table.concat(fired, ", ")
                                       or "NOTHING - the stall is outside this mod"))
    end
end

-- ---------------------------------------------------------------------------
-- Independent heartbeat. Deliberately NOT inside MasterTick: if the scheduler is off
-- (merc_sched 0) or has stalled, that is exactly when observation matters most.
-- ---------------------------------------------------------------------------

function mercenaries.ProfHeartbeat()
    local self = mercenaries
    -- Chain ENDS when profiling is off, rather than re-arming a no-op timer 4x a second for
    -- the whole session. The latch is cleared so ProfSet can start it again. Everything
    -- below this point only ever ran with ProfEnabled true anyway.
    if not self.ProfEnabled then
        self._profHbArmed = false
        return
    end
    if self.ProfEnabled then
        local now  = clock()
        local prev = self._profHbAt
        self._profHbAt = now
        if prev then
            local gap = (now - prev) * 1000.0
            self:ProfRecord("~heartbeat gap", gap)
            if gap >= (self.ProfHeartbeatMs * 2) then
                pLog(string.format("STALL %.0fms on the independent heartbeat (scheduled %dms) - "
                                   .. "the main thread stopped regardless of the scheduler",
                                   gap, self.ProfHeartbeatMs))
            end
        end

        -- Many per-NPC BT hooks, each far under the hitch threshold, can still add up to a
        -- real frame spike when they land together. Only the aggregate shows that.
        local btMs = self._profBtMs or 0
        self._profBtMs = 0
        self:ProfRecord("~bt hooks per window", btMs)

        -- An error inside a non-pcalled instrumented method would leave depth stuck.
        self._profDepth = 0

        self:ProfGCSample()
        self:ProfAuto()
    end
    Script.SetTimerForFunction(self.ProfHeartbeatMs, "mercenaries.ProfHeartbeat")
end

-- Lua's GC runs on the main thread and is periodic by nature - a textbook cause of this
-- exact symptom. Note this answers "did the heap shrink", not "did GC cost CPU": an
-- incremental cycle can free less than it allocates and hide entirely. merc_gc 0 is the
-- definitive test - stop the collector and see whether the heartbeat changes.
function mercenaries:ProfGCSample()
    if not collectgarbage then return end
    local ok, kb = pcall(collectgarbage, "count")
    if not ok or type(kb) ~= "number" then return end

    if not self._profPeakKb or kb > self._profPeakKb then self._profPeakKb = kb end
    local prev = self._profLastKb
    self._profLastKb = kb
    if not prev then return end

    -- Measured against the running peak, not just the previous sample, so a
    -- shrink-then-reallocate between two samples is still visible.
    local drop = (self._profPeakKb or kb) - kb
    if drop > 8 then
        self._profGcCount   = (self._profGcCount or 0) + 1
        self._profGcFreedKb = (self._profGcFreedKb or 0) + drop
        self._profPeakKb    = kb
        local now  = clock()
        local last = self._profLastGcAt
        self._profLastGcAt = now
        local since = last and ((now - last) * 1000.0) or -1
        local s = stat("~gc period ms")
        s.n = s.n + 1
        s.total = s.total + (since > 0 and since or 0)
        if since > s.max then s.max = since end
        pLog(string.format("GC  freed %.0fKB (heap %.0fKB)   %.0fms since last GC", drop, kb, since))
    elseif kb > prev then
        self._profAllocKb = (self._profAllocKb or 0) + (kb - prev)
    end
end

-- The clean A/B the passive detector cannot give: stop the collector and play. If the
-- heartbeat vanishes or changes period, GC is the cause. Heap grows while stopped, so
-- this is a test, not a setting.
function mercenaries:ProfGCSet(v)
    local raw = tostring(v or ""):gsub("%s+", "")
    if raw == "0" or raw == "stop" then
        pcall(collectgarbage, "stop")
        pLog("automatic GC STOPPED. Heap will grow - diagnostic only. merc_gc 1 restarts it.")
    else
        pcall(collectgarbage, "restart")
        pLog("automatic GC restarted")
    end
end

-- ---------------------------------------------------------------------------
-- Reporting
-- ---------------------------------------------------------------------------

function mercenaries:ProfReport(sortByMax)
    local rows = {}
    for name, s in pairs(self.ProfStats) do rows[#rows + 1] = { name = name, s = s } end
    if sortByMax then table.sort(rows, function(a, b) return a.s.max > b.s.max end)
    else                table.sort(rows, function(a, b) return a.s.total > b.s.total end) end

    local span = self._profStartedAt and (clock() - self._profStartedAt) or 0
    pLog("=================== profile ===================")
    pLog(string.format("timer=%s  window=%.1fs  hitch>=%.1fms  stall>=%.0fms",
                       self.ProfClockName, span, self.ProfHitchMs, self.ProfGapMs))
    pLog("rows marked (nest) run inside another timed function; their time is already")
    pLog("included in the caller's, and they never raise a hitch.")
    pLog(string.format("%-32s %7s %9s %8s %8s %6s %9s",
                       "name", "calls", "total ms", "avg ms", "max ms", "hitch", "period ms"))
    for _, r in ipairs(rows) do
        local s = r.s
        if s.n > 0 then
            local period = (s.periodN > 0) and (s.periodSum / s.periodN) or 0
            pLog(string.format("%-32s %7d %9.1f %8.3f %8.2f %6d %9.0f%s",
                               string.sub(r.name, 1, 32), s.n, s.total, s.total / s.n, s.max,
                               s.hitches, period, s.nested and "  (nest)" or ""))
        end
    end
    local gap = self.ProfStats["~mastertick gap"]
    if gap and gap.elevated then
        pLog(string.format("mastertick gaps over %.1fx schedule: %d of %d",
                           self.ProfElevatedMul, gap.elevated, gap.n))
    end
    pLog(string.format("GC: %d collection(s), %.0fKB freed, %.0fKB allocated, heap %.0fKB",
                       self._profGcCount or 0, self._profGcFreedKb or 0,
                       self._profAllocKb or 0, self._profLastKb or 0))
    if #self.ProfHitches > 0 then
        pLog("---- recent hitches; a repeating 'thisAfter' names the heartbeat ----")
        for _, h in ipairs(self.ProfHitches) do
            pLog(string.format("   %-30s %7.2fms  thisAfter=%.0fms anyAfter=%.0fms",
                               string.sub(h.name, 1, 30), h.ms, h.same, h.any))
        end
    end
    pLog("===============================================")
end

function mercenaries:ProfReset()
    self.ProfStats   = {}
    self.ProfHitches = {}
    self._profStartedAt   = clock()
    self._profReportAt    = clock()
    self._profLastHitchAt = nil
    self._profLastTickAt  = nil
    self._profHbAt        = nil
    self._profLastKb      = nil
    self._profPeakKb      = nil
    self._profLastGcAt    = nil
    self._profGcCount     = 0
    self._profGcFreedKb   = 0
    self._profAllocKb     = 0
    self._profBtMs        = 0
    self._profDepth       = 0
    pLog("counters reset")
end

function mercenaries:ProfAuto()
    if not self._profStartedAt then self:ProfReset(); return end
    local now  = clock()
    local last = self._profReportAt or self._profStartedAt
    if (now - last) >= self.ProfReportSec then
        self._profReportAt = now
        self:ProfReport(true)
    end
end

function mercenaries:ProfSet(v)
    local raw = tostring(v or ""):gsub("%s+", "")
    self.ProfEnabled = not (raw == "0" or raw == "off" or raw == "false")
    if self.ProfEnabled then
        -- Wrapping happens here rather than at load, since load-time instrumentation
        -- would defeat the point of defaulting off.
        if self.ProfInstrumentAll then self:ProfInstrumentAll() end
        self:ProfReset()
        -- The heartbeat is armed HERE, not at load: with profiling off it had nothing to
        -- observe and simply re-armed itself forever. Latched so merc_prof 1 twice does
        -- not leave two chains running.
        if not self._profHbArmed then
            self._profHbArmed = true
            Script.SetTimerForFunction(self.ProfHeartbeatMs or 250, "mercenaries.ProfHeartbeat")
        end
    end
    pLog("profiling " .. (self.ProfEnabled and "ON" or "OFF") ..
         (self.ProfEnabled and "" or " - wrappers stay in place but do nothing; merc_prof_off removes them"))
end

function mercenaries:ProfHitchSet(v)
    local n = tonumber(tostring(v or ""):match("[%d%.]+"))
    if n then self.ProfHitchMs = n; pLog("hitch threshold = " .. n .. "ms")
    else pLog("merc_prof_hitch <ms>  (current " .. self.ProfHitchMs .. ")") end
end

-- If the smallest non-zero delta reads 0.000ms the clock is quantised and every timing
-- above is worthless. Check this once before believing any of it.
function mercenaries:ProfTimerCheck()
    local t0 = clock()
    local minD = nil
    for _ = 1, 100000 do
        local a, b = clock(), clock()
        local d = b - a
        if d > 0 and (not minD or d < minD) then minD = d end
    end
    pLog("timer source: " .. self.ProfClockName)
    pLog(string.format("  100000 samples in %.2fms; smallest non-zero delta %.6fms",
                       (clock() - t0) * 1000.0, (minD or 0) * 1000.0))
    if not minD then pLog("  WARNING: clock never advanced - every timing here is meaningless") end
    pLog("  GetCurrTime() = " .. tostring(System.GetCurrTime and System.GetCurrTime()) ..
         "  (frame-cached, NOT usable for durations)")
end

System.AddCCommand("merc_prof",        "mercenaries:ProfSet('%line')",      "Profiling on/off: merc_prof 1 | 0")
System.AddCCommand("merc_prof_report", "mercenaries:ProfReport(true)",      "Dump profile sorted by worst spike")
System.AddCCommand("merc_prof_total",  "mercenaries:ProfReport(false)",     "Dump profile sorted by total time")
System.AddCCommand("merc_prof_reset",  "mercenaries:ProfReset()",           "Reset profiling counters")
System.AddCCommand("merc_prof_hitch",  "mercenaries:ProfHitchSet('%line')", "Set hitch log threshold in ms")
System.AddCCommand("merc_prof_timer",  "mercenaries:ProfTimerCheck()",      "Verify the profiling clock resolves sub-ms")
System.AddCCommand("merc_gc",          "mercenaries:ProfGCSet('%line')",    "Stop/restart Lua GC to A/B it: merc_gc 0 | 1")

-- ---------------------------------------------------------------------------
-- What gets instrumented
-- ---------------------------------------------------------------------------

-- Every function the behaviour trees call from an ExecuteLua node. These run PER NPC per
-- BT tick on the engine's own AI scheduler, entirely outside the master tick - so the
-- aggregate "~bt hooks per window" matters more here than any single call.
mercenaries.ProfBtHooks = {
    "ScanForEnemies", "PickCombatTarget", "EvaluateCombatTarget", "ClearCombatClaim",
    "UpdateMeleeCombatData", "UpdateRangedCombatData", "UpdateStaticArcherCombatData",
    "FindEnemyTarget", "FindQuartermasterTarget", "FindStaticArcherTarget",
    "UpdateFormationRole", "CalculateFormationTarget", "FormationMade", "MercLeashes",
    "MountedLeaderGait", "PollFollowRefire", "ConsumeFollowRefire", "IsMercInSortie",
    "IsCampActor", "IsCampGuard", "GetCampActivity", "GetCampFurniture", "CampActorYield",
    "ColumnFollowRole", "EndCampChat", "CampActorGet",
    "PatrolRole", "PatrolWalkTick", "PatrolChainPoll", "PatrolFollowRole", "PatrolFindTarget",
    "PatrolCtx", "PatrolChain", "PatrolLivingMen", "GetPatrolWaypoint", "AdvancePatrolWaypoint",
    "IsPatrolNoPause",
    "ForceTalkWanted", "ForceTalkRole", "ForceTalkPull", "ForceTalkDone",
    "WBStagePoll", "WBCombatPoll",
    "FoeOnFired", "FoeCombatTick", "FoePoll", "FoeIdleTick", "FoeBeat",
    "GetArcherStanceCode", "GetQuartermasterPost", "PerfEntityByName",
}

-- Timers still running outside the master scheduler. Each is a candidate heartbeat.
mercenaries.ProfTimerFns = {
    "LootSweepLoop", "RaidTick", "LivePatrolTick", "WBTick", "RouteTick",
    "StaticArcherPinTick", "StaticArcherPlaceTick", "HideOthersTick", "AnimPollTick",
    "CampForgeMonitor", "CampAlchemyMonitor", "FoeLoop",
    "ForgeCensusStep", "ForgeRigStep",
}

-- MonitorCamp, LogiTick, PerfScanNpcs, UpdateEnemyCache and LivePatrolWatchdog are
-- deliberately absent: already timed at their call sites in mercenaries.lua, and wrapping
-- them again would report the same time under two names.
mercenaries.ProfHeavyFns = {
    "RebuildMercCache", "SpawnMercCamp", "BreakMercCamp",
    "RotateCampRoles", "CampChatTick", "PerfScanMercs", "UpdateFormationLeader",
    "PatrolIndexRebuild", "ClearAnyLeftoverPatrols",
}

-- SaveString/LoadString each run a world-wide GetEntitiesByClass("BasicEntity"), and
-- SaveString also destroys and respawns an entity and writes a log line - per call.
-- Recorded per TAG, because "which tag is rewritten on a timer" is the actionable fact.
-- LogiSave alone calls SaveString for 18 tags, from LogiTick, every 5 seconds.
function mercenaries:ProfInstrumentPersistence()
    for _, m in ipairs({ "SaveString", "LoadString" }) do
        if not self._profWrapped[m] then
            local orig = self[m]
            if type(orig) == "function" then
                self._profWrapped[m] = orig
                local prefix = (m == "SaveString") and "save:" or "load:"
                self[m] = function(slf, tag, ...)
                    local M = mercenaries
                    if not M.ProfEnabled then return orig(slf, tag, ...) end
                    local t0 = clock()
                    local r = pack(orig(slf, tag, ...))
                    local ms = (clock() - t0) * 1000.0
                    M:ProfRecord(prefix .. tostring(tag), ms)
                    M:ProfRecord(prefix .. "*ALL*", ms, true)
                    return unpk(r, 1, r.n)
                end
            end
        end
    end
end

function mercenaries:ProfInstrumentAll()
    local n, miss = 0, {}
    local function apply(list, prefix, isBt)
        for _, m in ipairs(list) do
            if self:ProfInstrumentMethod(m, prefix .. m, isBt) then n = n + 1
            else miss[#miss + 1] = m end
        end
    end
    apply(self.ProfBtHooks,  "bt.",    true)
    apply(self.ProfTimerFns, "timer.", false)
    apply(self.ProfHeavyFns, "heavy.", false)
    self:ProfInstrumentPersistence()
    pLog("instrumented " .. n .. " function(s) + persistence (per tag)")
    if #miss > 0 then pLog("  not found (fine if that feature is absent): " .. table.concat(miss, ", ")) end
    self:ProfReset()
end

System.AddCCommand("merc_prof_instrument", "mercenaries:ProfInstrumentAll()",
                   "Wrap BT hooks and timers with timing (done automatically at load)")
System.AddCCommand("merc_prof_off",        "mercenaries:ProfUninstrumentAll()",
                   "Remove method instrumentation entirely")
