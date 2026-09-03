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

function mercenaries.MasterTick(token)
    local self = mercenaries
    -- Each chain carries the token it was armed under (a closure, see SchedArm) and
    -- retires the moment it is not the current one. A chain cannot be told apart from
    -- its twin by timing - a time-based guard was tried and killed the ONLY chain after a
    -- hitch fired two queued ticks back to back - but it can by identity, and this is the
    -- identity. It matters because the engine writes pending NAMED timers into the save
    -- and restores them on load: three sessions that each loaded the previous one's save
    -- ran 1, 2 and 3 watchdog pollers, and every watchdog re-arm added one more master
    -- tick that never went away - some 65 by the end of the third session, every slot
    -- firing 65 times too often (2026-09-02). A chain restored from an older build's save
    -- arrives here with the timer id in place of a token and retires the same way. See
    -- docs/performance.md.
    if token ~= self._schedToken then
        self:SchedRetire("master tick", token)
        return
    end
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
    self:SchedArm(self.MasterTickMs, "MasterTick", token)
end

-- One firing of `fn` (a mercenaries.* name) under `token`. Script.SetTimer takes a Lua
-- closure, so the chain knows what armed it - and a closure is nothing the engine can
-- write into a save, so the chain ends with the session that armed it instead of coming
-- back on every load of every save made while it was pending. The name is resolved when
-- the timer fires, as the engine does for a named timer, so a reloaded script is picked up.
function mercenaries:SchedArm(ms, fn, token)
    Script.SetTimer(ms, function()
        local f = mercenaries[fn]
        if f then f(token) end
    end)
end

-- Said once per retired chain: the token is a table, so its address is the chain's name.
function mercenaries:SchedRetire(what, token)
    schLog(string.format("%s chain retired - armed under %s, current token is %s (epoch %s)",
                         what, tostring(token), tostring(self._schedToken), tostring(self.SchedEpoch)))
end

-- One master tick means one point of failure for four subsystems, which the legacy
-- independent timers did not have. This buys that robustness back.
function mercenaries.SchedWatchdog(token)
    local self = mercenaries
    -- The same identity check as the master tick. Before it, the watchdog was the thing
    -- multiplying: every load of a save made while a poller was pending restored that
    -- poller beside the fresh one, all landing within the same 100 ms - the second copy
    -- saw tick == lastSeen every 5 s (a false strike 1 that never escalated), and with a
    -- third copy the false strike 2 re-armed the master tick every 5 s, each re-arm
    -- leaving the previous chain running. Now a poll from a stale token retires and the
    -- strike count is the reading of one poller.
    if token ~= self._schedToken then
        self:SchedRetire("watchdog", token)
        return
    end
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
                -- SchedStart(true) issues a new token, so the stalled chain - if it is
                -- merely late rather than dead - retires on its next firing instead of
                -- running beside the new one.
                schLog("master tick stalled twice - re-arming")
                self.SchedRunning = false
                self:SchedStart(true)
                return   -- SchedStart armed a fresh watchdog under the new token
            else
                local now = 0
                pcall(function() now = System.GetCurrTime() or 0 end)
                schLog(string.format(
                    "master tick missed an advance - watching (strike 1) tick=%s lastSeen=%s t=%.1f",
                    tostring(self.SchedTick), tostring(self._schedLastSeenTick), now))
            end
        else
            self._schedStrikes = 0
        end
        self._schedLastSeenTick = self.SchedTick
    end
    self:SchedArm(5000, "SchedWatchdog", token)
end

-- The pre-scheduler timers. Each loop's wrapper re-arms itself only while
-- SchedRunning is false, so this is safe to call exactly once.
function mercenaries:SchedArmLegacy()
    Script.SetTimerForFunction(1000, "mercenaries.MonitorLoop")
    Script.SetTimerForFunction(300,  "mercenaries.CombatScanLoop")
    Script.SetTimerForFunction(5000, "mercenaries.LowPriorityMonitorLoop")
    Script.SetTimerForFunction(self.FormationTickMs or 150, "mercenaries.FormationLoop")
    -- Patrols and raids are slots now, so they died with the master tick. Hand them back
    -- their private chains, which is what SchedEnabled=false above has just re-enabled.
    self.LivePatrolRunning, self.RaidRunning = false, false
    pcall(function() self:LivePatrolStart() end)
    pcall(function() self:RaidStart() end)
    schLog("legacy timers armed")
end

-- ---------------------------------------------------------------------------
-- LOAD GENERATION. Call this at the top of OnGameplayStarted, before anything arms
-- a timer.
--
-- Script.SetTimerForFunction chains are BELIEVED not to survive a save load - the engine
-- drops them with the level - but this table is plain Lua and survives everything, so any
-- latch guarding a timer has to be reset per load or it locks the timer out for the rest of
-- the session.
--
-- Believed, not measured. The argument used to be "LootSweepLoop re-arms itself with no
-- guard at all, so if timers survived it would double every load, and it does not" - which
-- is circular (nothing was watching it) and was the only evidence there was. LootSweepArm
-- no longer relies on the answer: consecutive loads alternate between two entry points, so
-- a chain from the previous load retires on its next firing either way. Anything else added
-- here should do the same rather than inherit the assumption.
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
    "SchedRunning",
    "LivePatrolRunning", "RaidRunning", "WBRunning",
    "FoeLoopArmed", "GearTickArmed", "_profHbArmed",
    -- The custom-uniform chains. GearArmKeep and GearArmFinish are called on demand (the
    -- next time the squad is dressed), so a latch left set from the previous load meant the
    -- keep pass simply never came back for the rest of the session and gear stopped being
    -- re-asserted - silent, and indistinguishable from the feature not working.
    "GearKeepArmed", "GearFinishArmed",
    -- Not a latch in the same sense: LootSweepArm is idempotent per load on its own. Cleared
    -- here so the arm is unambiguous rather than depending on the generation compare alone.
    "LootSweepArmed",
}

function mercenaries:SchedOnLoad()
    self.SchedLoadGen = (self.SchedLoadGen or 0) + 1
    for _, k in ipairs(self.TimerLatches) do self[k] = false end
    self._schedStrikes, self._schedLastSeenTick = 0, nil
    -- Whatever chain the previous load left running now holds a stale token and retires
    -- on its next firing, whether or not SchedStart arms a new one for this load.
    self._schedToken = nil
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
    self._schedLastSeenTick, self._schedStrikes = nil, 0
    -- A fresh table: nothing a restored timer can hand back (it gets the numeric timer id
    -- as its argument) and nothing an older chain still holds. Both chains are armed under
    -- it every time, and every chain armed before it retires on its next firing.
    self._schedToken = {}
    self:SchedArm(self.MasterTickMs, "MasterTick", self._schedToken)
    self:SchedArm(5000, "SchedWatchdog", self._schedToken)
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

    -- 100ms, and that number is the entire point. The ghost-movement test this drives -
    -- position moving while the engine reports Henry's own speed as zero - is guarded by
    -- `realTimeDelta < 0.4`, and it lived in the 1Hz monitor loop from the first commit to
    -- 2026-09-03, where that condition can never be true. It has therefore never fired
    -- once, in any version. See TravelWatchTick.
    self:SchedRegister("travelwatch", {
        periodMs = 100,
        gate = function(s) return player ~= nil end,
        fn = function(s) s:TravelWatchTick() end,
    })

    self:SchedRegister("lowpriority", {
        periodMs = 5000,
        fn = function(s) s:LowPriorityMonitorLoopBody() end,
    })

    -- Roaming patrols and camp raids used to drive themselves. Both were MEASURED running
    -- several times over - the patrol tick at 615ms against an armed 3000ms (five chains) and
    -- the raid tick at 6545ms against 20000ms (three) - in a session where this scheduler's own
    -- tick was exactly right at 108ms against 100ms. A private self-arming chain has no way to
    -- count itself; a slot cannot be duplicated without duplicating the master tick, which the
    -- watchdog already covers. So they moved here. See docs/performance.md.
    --
    -- This matters far past the Lua: an extra patrol chain is another chance per period to
    -- spawn a GANG, and a gang spawn is NPC creation, ground raycasts and character assembly -
    -- main-thread engine time no Lua profiler can see.
    self:SchedRegister("patrols", {
        periodMs = mercenaries.PatrolLiveTickMs or 3000,
        gate = function(s) return s.LivePatrolsEnabled and player ~= nil end,
        fn = function(s) if s.LivePatrolBody then mercenaries.LivePatrolBody() end end,
    })

    self:SchedRegister("raids", {
        periodMs = mercenaries.RaidTickMs or 20000,
        fn = function(s) if s.RaidTick then mercenaries.RaidTick() end end,
    })

    -- Ungated by ActiveMercs: the player murdering a guard on his own is exactly the
    -- case worth catching. One sphere query per second, same shape as combatscan's.
    self:SchedRegister("crimewatch", {
        periodMs = 1000,
        gate = function(s) return s.CrimeWatchEnabled and player ~= nil end,
        fn = function(s) s:CrimeWatchTick() end,
    })

    -- Reads what crimewatch published, so it runs a beat behind it rather than beside it.
    -- Its own TWTickSecs throttles the real work; 1000ms here just keeps the two in step.
    self:SchedRegister("townwatch", {
        periodMs = 1000,
        gate = function(s) return s.TWEnabled and player ~= nil end,
        fn = function(s) s:TownWatchTick() end,
    })
end
