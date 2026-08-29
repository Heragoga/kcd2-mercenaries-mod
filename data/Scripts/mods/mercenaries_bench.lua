-- Automated in-game benchmark + POP-IN DETECTOR. See docs/performance.md.
--
-- Two jobs, one module:
--   1. Run a scripted scenario chain (hire men, spawn a fight) with a real frame-time
--      histogram per scenario - no human, no console typing: F9 starts it, F10 starts it
--      and QUITS THE GAME when done, so an external harness can cycle launch->bench->parse.
--   2. Measure the pop-in complaint OBJECTIVELY. Every sampled NPC is polled 4x/sec for the
--      three render states merc_lod_probe reads - IsHidden(), IsSlotCharacter(0) and
--      GetViewDistRatio() - and every TRANSITION is logged with distance and classified:
--        hidden flip  -> something called Hide(): the AI-LOD hide path
--        char flip    -> the entity is there but SKINLESS: the wh_cc_* clothing scheduler
--        vdr drop     -> something rewrote that entity's own view distance
--      "They pop in and out" becomes a per-system count instead of an eyewitness report.
--
-- Everything logs with the [Bench] prefix; the harness parses kcd.log for it.

mercenaries.BenchRunning   = false
mercenaries.BenchSlot      = 0
mercenaries.BenchTickMs    = 250
mercenaries.BenchAutoQuit  = false

-- Scenario chain. `setup` runs once, then `settle` seconds are ignored (dressing, spawn
-- churn), then `secs` are measured. Kept deliberately simple: add rows, not mechanisms.
-- v3: the full suite. Run 2 (army50/bigbattle/boostcycle) caught the pop-in red-handed:
-- every flip was a HIDDEN flip and they clustered on LOD-boost transitions (64 battle /
-- 86 aftermath / 182 while cycling the pin). The population-aware boost lifecycle is the
-- fix under test; the suite now also covers formations, the camp, a camp raid, a roaming
-- patrol and the siege of Raborsch (which raises around the player - no teleport needed).
--
-- The OBSERVER: during hover scenarios the player is held ~14m up looking down, re-pinned
-- every tick, so the whole field is in view - on the ground the company musters BEHIND the
-- camera and view-driven systems are never exercised. god-flagged scenarios get devmode god.
mercenaries.BenchHoverHeight = 14.0
mercenaries.BenchPlan = {
    { name = "baseline",   settle = 2,  secs = 15, setup = function(self) end },
    { name = "army50",     settle = 20, secs = 30, setup = function(self)
                               self:HireArcher(0, 15); self:Hire(0, 35, "medium") end },
    { name = "formations", settle = 3,  secs = 45, hover = true, setup = function(self)
                               self._benchFormCycle = { "line", "square", "wedge", "column" } end },
    { name = "camp",       settle = 15, secs = 30, hover = true, setup = function(self)
                               self:SpawnMercCamp(self._benchAnchor, true) end },
    { name = "campraid",   settle = 5,  secs = 60, hover = true, god = true, setup = function(self)
                               pcall(function() self:RaidLaunch() end) end },
    { name = "breakcamp",  settle = 8,  secs = 10, hover = true, setup = function(self)
                               self:BreakMercCamp(true) end },
    { name = "bigbattle",  settle = 5,  secs = 75, hover = true, god = true, setup = function(self)
                               self:SpawnEnemyGroup("bandit", 20); self:SpawnEnemyGroup("sigi", 15) end },
    { name = "aftermath",  settle = 5,  secs = 25, hover = true, setup = function(self) end },
    { name = "patrol",     settle = 8,  secs = 40, hover = true, god = true, setup = function(self)
                               pcall(function() self:LivePatrolHere() end) end },
    { name = "raborsch",   settle = 20, secs = 75, hover = true, god = true, setup = function(self)
                               pcall(function() self:SpawnRaborsch() end) end },
    { name = "raborschend",settle = 3,  secs = 15, hover = true, setup = function(self)
                               pcall(function() self:DespawnRaborsch() end) end },
    { name = "boostcycle", settle = 3,  secs = 45, hover = true, setup = function(self)
                               self._benchBoostCycle = true end },
}

-- Hold the observer aloft, looking down. Re-pinned every tick: the player falls ~0.3m
-- between 250ms ticks, which reads as a slight bob. Angle setting is best-effort - if the
-- camera ignores SetWorldAngles the flip counters still work, only view-driven streaming
-- sees less of the field.
function mercenaries:BenchHoverTick(S)
    if not (S.plan and S.plan.hover) then return end
    if not self._benchAnchor then return end
    pcall(function()
        local a = self._benchAnchor
        player:SetWorldPos({ x = a.x, y = a.y, z = a.z + (self.BenchHoverHeight or 14) })
    end)
    -- RADIANS, not degrees - measured: -80 here wrapped to ~+96 deg and the observer stared
    -- at the sky. -1.22 rad = 70 deg downward pitch.
    pcall(function() player:SetWorldAngles({ x = -1.22, y = 0, z = 0 }) end)
    if S.plan.god and not S.godTried then
        S.godTried = true
        pcall(function() System.ExecuteCommand("god 1") end)
        pcall(function() System.ExecuteCommand("god") end)
    end
end

-- Cycle the formation shape every ~10s during the formations scenario.
function mercenaries:BenchFormTick(now, S)
    if not self._benchFormCycle or S.plan.name ~= "formations" then return end
    if not S.nextFormAt or now >= S.nextFormAt then
        S.nextFormAt = now + 10
        local shape = table.remove(self._benchFormCycle, 1)
        if shape then
            bLog("formations: -> " .. shape)
            pcall(function() self:SetFormationShape(shape, true) end)
        end
    end
end

-- Drives the boostcycle scenario-- Drives the boostcycle scenario: every 10s flip the boost pin the other way.
function mercenaries:BenchBoostCycleTick(now, S)
    if not self._benchBoostCycle then return end
    if S.plan.name ~= "boostcycle" then
        if self._benchBoostWas ~= nil then
            self:LodBoostPin(false); self._benchBoostWas = nil; self._benchBoostCycle = false
        end
        return
    end
    if not S.nextFlipAt or now >= S.nextFlipAt then
        S.nextFlipAt = now + 10
        local on = not (self._benchBoostWas == true)
        self._benchBoostWas = on
        bLog("boostcycle: LodBoostPin(" .. tostring(on) .. ")")
        pcall(function() self:LodBoostPin(on) end)
    end
end

local function bLog(s) System.LogAlways("[Bench] " .. tostring(s)) end

local function bClock()
    local c = (os and os.clock) and os.clock() or nil
    if c then return c end
    local t = 0; pcall(function() t = System.GetCurrTime() or 0 end); return t
end

local function bFrame()
    local f; pcall(function() f = System.GetFrameID() end); return f
end

-- ---------------------------------------------------------------------------
-- The render-state sampler.
-- ---------------------------------------------------------------------------

-- [name] = { hid, char, vdr, at } - last observed state per tracked NPC.
mercenaries._benchSeen = {}
-- Who to watch: the squad, plus every mod enemy/patrolman near the player (refreshed on a
-- slow cadence - a box query 4x/sec would be its own perf bug).
mercenaries._benchWatch = {}
mercenaries._benchWatchAt = 0

function mercenaries:BenchRefreshWatch(now)
    if (now - (self._benchWatchAt or 0)) < 2.0 then return end
    self._benchWatchAt = now
    local w = {}
    for name, ent in pairs(self.ActiveMercs or {}) do w[name] = ent end
    local pp
    pcall(function() pp = player and player:GetWorldPos() end)
    if pp then
        local ents
        pcall(function() ents = System.GetPhysicalEntitiesInBoxByClass(pp, 120.0, "NPC") end)
        for _, e in pairs(ents or {}) do
            local nm
            pcall(function() nm = e:GetName() end)
            if nm and (self:IsModEnemyName(nm)
                       or string.find(nm, "SpawnedPatrolman_", 1, true)) then
                w[nm] = e
            end
        end
    end
    self._benchWatch = w
end

function mercenaries:BenchSampleEnt(name, ent, now, S)
    -- A DEAD man ragdolling detaches slots and toggles hidden state as part of dying -
    -- counting that as pop-in poisons the battle scenario's numbers, which are the whole
    -- point of the tool (review finding). Dead = dropped from tracking, no flip logged.
    local dead = false
    pcall(function() dead = (ent.actor and ent.actor.IsDead and ent.actor:IsDead()) or false end)
    if not dead then
        pcall(function()
            local hp = ent.soul and ent.soul:GetState("health")
            if hp ~= nil and hp <= 0 then dead = true end
        end)
    end
    if dead then
        self._benchSeen[name] = nil
        self._benchWatch[name] = nil
        return
    end
    local hid, char, vdr
    local okH = pcall(function() hid = ent:IsHidden() and 1 or 0 end)
    local okC = pcall(function() char = ent:IsSlotCharacter(0) and 1 or 0 end)
    pcall(function() vdr = ent:GetViewDistRatio() end)
    if not (okH and okC) then self._benchSeen[name] = nil; return end   -- entity gone

    local d = -1
    pcall(function()
        local p, q = player:GetWorldPos(), ent:GetWorldPos()
        d = math.sqrt((p.x-q.x)^2 + (p.y-q.y)^2 + (p.z-q.z)^2)
    end)

    local prev = self._benchSeen[name]
    -- Flips are LOGGED whenever they happen (a settle-phase flip is still worth seeing in
    -- the log) but only COUNTED while measuring - settle covers known dressing/spawn churn.
    -- Keeping the baseline updated through settle also means the first measured sample has
    -- a real prior, so a flip on the settle/measure boundary is not silently absorbed.
    local tag = S.measuring and "" or "  [settle]"
    tag = tag .. "  [boost=" .. tostring(self.LodBoostActive) ..
          " band=" .. tostring(self._lodRatioBand) .. "]"
    if prev then
        if prev.hid ~= hid then
            if S.measuring then S.flipsHidden = (S.flipsHidden or 0) + 1 end
            bLog(string.format("FLIP hidden %d->%d  d=%5.1fm  %s%s", prev.hid, hid, d, name, tag))
        end
        if prev.char ~= char then
            if S.measuring then S.flipsChar = (S.flipsChar or 0) + 1 end
            bLog(string.format("FLIP char   %d->%d  d=%5.1fm  %s  (skin attachment stream)%s", prev.char, char, d, name, tag))
        end
        if prev.vdr and vdr and vdr < prev.vdr and (prev.vdr - vdr) > 40 then
            if S.measuring then S.flipsVdr = (S.flipsVdr or 0) + 1 end
            bLog(string.format("FLIP vdr  %s->%s  d=%5.1fm  %s  (view distance rewritten)%s",
                 tostring(prev.vdr), tostring(vdr), d, name, tag))
        end
    end
    self._benchSeen[name] = { hid = hid, char = char, vdr = vdr, at = now }
end

-- ---------------------------------------------------------------------------
-- The tick.
-- ---------------------------------------------------------------------------

function mercenaries.BenchTick0() mercenaries.BenchBeat(0) end
function mercenaries.BenchTick1() mercenaries.BenchBeat(1) end

function mercenaries.BenchBeat(slot)
    local self = mercenaries
    if not self.BenchRunning or self.BenchSlot ~= slot then return end
    local ok, err = pcall(function() self:BenchStep() end)
    if not ok then bLog("tick error: " .. tostring(err)) end
    Script.SetTimerForFunction(self.BenchTickMs, "mercenaries.BenchTick" .. slot)
end

function mercenaries:BenchStep()
    local now = bClock()
    local S = self._benchState
    if not S then self.BenchRunning = false; return end

    -- Frame accounting for the current tick.
    local fid = bFrame()
    if S.lastFrame and fid and now > S.lastAt then
        local frames = fid - S.lastFrame
        local ms = (now - S.lastAt) * 1000.0 / math.max(frames, 1)
        if S.measuring and frames > 0 then
            S.frames = (S.frames or 0) + frames
            local b = 6
            local edges = { 16.7, 25, 33, 50, 100 }
            for i, e in ipairs(edges) do if ms <= e then b = i break end end
            S.hist[b] = (S.hist[b] or 0) + frames
            if ms > (S.worstMs or 0) then S.worstMs = ms end
        end
    end
    S.lastFrame, S.lastAt = fid, now

    -- Render-state sampling runs through settle AND measure - a flip during settle is
    -- still a flip worth seeing, it is just not counted against the scenario.
    self:BenchRefreshWatch(now)
    for name, ent in pairs(self._benchWatch) do
        self:BenchSampleEnt(name, ent, now, S)
    end

    -- A dead player hangs the run; abort visibly instead (god itself is handled per
    -- scenario in BenchHoverTick).
    do
        local dead = false
        pcall(function() dead = player.actor and player.actor:IsDead() or false end)
        if dead then
            bLog("ABORT: player died during '" .. tostring(S.plan and S.plan.name) .. "' - results above this line are valid")
            return self:BenchFinish()
        end
    end

    self:BenchBoostCycleTick(now, S)
    self:BenchHoverTick(S)
    self:BenchFormTick(now, S)

    -- Phase machine.
    if S.phase == "settle" then
        if now >= S.phaseUntil then
            S.phase, S.measuring = "measure", true
            S.phaseUntil = now + S.plan.secs
            S.frames, S.hist, S.worstMs = 0, {0,0,0,0,0,0}, 0
            S.flipsHidden, S.flipsChar, S.flipsVdr = 0, 0, 0
            S.measureFrom, S.measureFrame = now, fid
            bLog("measuring '" .. S.plan.name .. "' for " .. S.plan.secs .. "s")
        end
    elseif S.phase == "measure" then
        if now >= S.phaseUntil then
            self:BenchScenarioDone(now)
        end
    end
end

function mercenaries:BenchScenarioDone(now)
    local S = self._benchState
    local span = now - (S.measureFrom or now)
    local fps = (S.frames or 0) / math.max(span, 0.001)
    local n = math.max(S.frames or 0, 1)
    local labels = { "<=16.7", "<=25", "<=33", "<=50", "<=100", ">100" }
    local parts = {}
    for i = 1, 6 do parts[#parts+1] = string.format("%s %0.1f%%", labels[i], (S.hist[i] or 0) * 100.0 / n) end
    -- worstTickAvg is the worst AVERAGE ms/frame over a ~250ms tick, not a single frame -
    -- one 200ms hitch among 14 fast frames dilutes to ~+13ms here. The histogram has the
    -- same resolution. Good enough to rank scenarios; do not read it as a frame-time max.
    bLog(string.format("RESULT %-10s fps=%5.1f  worstTickAvg=%5.1fms  flips: hidden=%d char=%d vdr=%d  | %s",
        S.plan.name, fps, S.worstMs or 0, S.flipsHidden or 0, S.flipsChar or 0, S.flipsVdr or 0,
        table.concat(parts, "  ")))
    S.results[#S.results+1] = { name = S.plan.name, fps = fps,
        fh = S.flipsHidden or 0, fc = S.flipsChar or 0, fv = S.flipsVdr or 0 }

    -- Next scenario.
    S.idx = S.idx + 1
    local plan = self.BenchPlan[S.idx]
    if not plan then return self:BenchFinish() end
    S.plan, S.phase, S.measuring = plan, "settle", false
    S.phaseUntil = now + (plan.settle or 2)
    bLog("scenario '" .. plan.name .. "' setup...")
    local ok, err = pcall(plan.setup, self)
    if not ok then bLog("setup error: " .. tostring(err)) end
end

function mercenaries:BenchFinish()
    self.BenchRunning = false
    if self._benchBoostWas ~= nil then
        pcall(function() self:LodBoostPin(false) end)
        self._benchBoostWas, self._benchBoostCycle = nil, false
    end
    local S = self._benchState
    bLog("=================== summary ===================")
    for _, r in ipairs(S.results or {}) do
        bLog(string.format("  %-10s %5.1f fps   flips h=%d c=%d v=%d", r.name, r.fps, r.fh, r.fc, r.fv))
    end
    bLog("hidden flips -> AI-LOD Hide path; char flips -> wh_cc_* skin streaming; vdr -> view distance rewritten")
    bLog("COMPLETE")
    if self.BenchAutoQuit then
        bLog("auto-quit")
        pcall(function() System.ExecuteCommand("quit") end)
    end
end

function mercenaries:BenchStart(autoquit)
    if self.BenchRunning then bLog("already running"); return end
    if not player then bLog("no player - not in game yet"); return end
    self.BenchRunning  = true
    self.BenchAutoQuit = (autoquit == true)
    self.BenchSlot     = 1 - (self.BenchSlot or 0)
    self._benchSeen, self._benchWatch, self._benchWatchAt = {}, {}, 0
    self._benchAnchor = nil
    pcall(function()
        local p = player:GetWorldPos()
        self._benchAnchor = { x = p.x, y = p.y, z = p.z }
    end)
    local plan = self.BenchPlan[1]
    self._benchState = {
        idx = 1, plan = plan, phase = "settle", measuring = false,
        phaseUntil = bClock() + (plan.settle or 2), results = {},
        hist = {0,0,0,0,0,0},
    }
    bLog("=== bench starting: " .. #self.BenchPlan .. " scenario(s), autoquit=" .. tostring(self.BenchAutoQuit) .. " ===")
    bLog("scenario '" .. plan.name .. "' setup...")
    pcall(plan.setup, self)
    Script.SetTimerForFunction(self.BenchTickMs, "mercenaries.BenchTick" .. self.BenchSlot)
end

function mercenaries:BenchBindKeys()
    pcall(function() System.ExecuteCommand("bind f9 merc_bench") end)
    pcall(function() System.ExecuteCommand("bind f10 merc_bench_auto") end)
end

do
    local function c(n, b, d)
        if mercenaries.CmdHelpText then mercenaries.CmdHelpText[n] = d end
        pcall(function() System.AddCCommand(n, b, d) end)
    end
    c("merc_bench",      "mercenaries:BenchStart(false)", "Run the scripted perf bench + pop-in detector (also F9)")
    c("merc_bench_auto", "mercenaries:BenchStart(true)",  "Run the bench and QUIT the game at the end (harness mode; also F10)")
end
