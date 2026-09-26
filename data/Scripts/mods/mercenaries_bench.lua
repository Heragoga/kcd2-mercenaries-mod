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

-- Declared at the TOP of the chunk: several functions below (BenchFormTick,
-- BenchBoostCycleTick, BenchCensus) are defined before the old mid-file definition
-- and were resolving bLog as a nil GLOBAL at runtime - their log lines (and in
-- BenchFormTick's case the SetFormationShape call after it) died inside the tick's
-- pcall as "tick error" spam. Lexical scope, not load order, decides upvalue capture.
local function bLog(s) System.LogAlways("[Bench] " .. tostring(s)) end

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
    -- at the sky. -1.22 rad = 70 deg downward pitch. A `lookup` scenario pitches UP instead:
    -- sky-only view, squad and crowd out of frame - the render-side/simulation-side
    -- discriminator for any cost under test.
    local pitch = S.plan.lookup and 1.10 or -1.22
    pcall(function() player:SetWorldAngles({ x = pitch, y = 0, z = 0 }) end)
    if S.plan.god and not S.godTried then
        S.godTried = true
        pcall(function() System.ExecuteCommand("god 1") end)
        pcall(function() System.ExecuteCommand("god") end)
    end
end

-- SCALE plan: the per-merc cost ladder, for the "one fps per merc, particularly in
-- Kuttenberg" report. Run it standing IN the city (a Kuttenberg save), not a field:
-- city NPC density is the axis the field suite cannot exercise. Cumulative hires
-- (0 -> 5 -> 10 -> 20), then live A/Bs of the two per-merc levers at 20 men, then a
-- full dismissal - if 'dismissed' does not return to 'm0', something is left behind.
mercenaries.BenchScalePlan = {
    { name = "m0",         settle = 6,  secs = 20, hover = true, setup = function(self) end },
    { name = "m5",         settle = 20, secs = 25, hover = true, setup = function(self)
                               self:Hire(0, 5, "medium") end },
    { name = "m10",        settle = 20, secs = 25, hover = true, setup = function(self)
                               self:Hire(0, 5, "medium") end },
    { name = "m20",        settle = 25, secs = 25, hover = true, setup = function(self)
                               self:Hire(0, 10, "medium") end },
    { name = "m20pinoff",  settle = 8,  secs = 25, hover = true, setup = function(self)
                               self:RenderPinSet('0') end },
    { name = "m20pinon",   settle = 8,  secs = 25, hover = true, setup = function(self)
                               self:RenderPinSet('1') end },
    { name = "m20btfull",  settle = 6,  secs = 25, hover = true, setup = function(self)
                               self:BehaviourLodSet(false) end },
    { name = "m20btlod",   settle = 6,  secs = 25, hover = true, setup = function(self)
                               self:BehaviourLodSet(true) end },
    { name = "dismissed",  settle = 30, secs = 25, hover = true, setup = function(self)
                               self:SetState('dismiss') end },
}

-- RESIDUE plan: run 2 measured hire->dismiss leaving ~10fps on the floor (31.1 -> 20.7
-- with the roster empty and npcWorld back at baseline). This plan attributes it:
--   * away scenarios (sky-only view) split render-side from simulation-side cost;
--   * rdis/rdis2 give the residue ~2.5 minutes to decay;
--   * rre5's second hire-step size tests asset/VRAM residency (a small second step
--     means the first hire's cost was streaming assets in, not simulating men).
mercenaries.BenchResiduePlan = {
    { name = "r0",       settle = 6,  secs = 20, hover = true, setup = function(self) end },
    { name = "r0away",   settle = 4,  secs = 15, hover = true, lookup = true, setup = function(self) end },
    { name = "r5",       settle = 20, secs = 20, hover = true, setup = function(self)
                             self:Hire(0, 5, "medium") end },
    { name = "r5away",   settle = 4,  secs = 15, hover = true, lookup = true, setup = function(self) end },
    { name = "rdis",     settle = 45, secs = 25, hover = true, setup = function(self)
                             self:SetState('dismiss') end },
    { name = "rdis2",    settle = 60, secs = 25, hover = true, setup = function(self) end },
    { name = "rdisaway", settle = 4,  secs = 15, hover = true, lookup = true, setup = function(self) end },
    { name = "rre5",     settle = 20, secs = 20, hover = true, setup = function(self)
                             self:Hire(0, 5, "medium") end },
    { name = "rdis3",    settle = 45, secs = 20, hover = true, setup = function(self)
                             self:SetState('dismiss') end },
}

-- TEXTURE plan: run 3 localized the hire cost to RENDERING the street view (sky view is
-- squad-invariant; re-hiring costs ~3fps where the first hire cost 17; recovery is slow).
-- That is the profile of texture-streaming-pool pressure: every merc rolls a DIFFERENT
-- preset, so 5 men stream ~5 distinct armour texture sets into a lowest-settings pool
-- that already holds Kuttenberg. This plan holds NPC count constant and varies only
-- texture VARIETY: x5same dresses all five in ONE identical preset, x5rand2 re-rolls
-- them, and the xrec tail traces pool recovery after dismissal.
mercenaries.BenchTexPlan = {
    { name = "x0",      settle = 6,  secs = 15, hover = true, setup = function(self) end },
    { name = "x5rand",  settle = 20, secs = 20, hover = true, setup = function(self)
                            self:Hire(0, 5, "medium") end },
    { name = "x5same",  settle = 18, secs = 25, hover = true, setup = function(self)
                            local styleData = self.Outfits[1] or {}
                            local pool = styleData["medium"] or styleData["weak"] or {}
                            local pid = pool[1]
                            if pid then
                                for nm, ent in pairs(self.ActiveMercs or {}) do
                                    if ent and ent.actor then
                                        pcall(function() ent.actor:EquipClothingPreset(pid) end)
                                    end
                                end
                                System.LogAlways("[Bench] x5same: all mercs -> " .. tostring(pid))
                            end end },
    { name = "x5rand2", settle = 18, secs = 25, hover = true, setup = function(self)
                            self:ChangeMercOutfit(1, true) end },
    { name = "xdis",    settle = 45, secs = 20, hover = true, setup = function(self)
                            self:SetState('dismiss') end },
    { name = "xrec1",   settle = 25, secs = 20, hover = true, setup = function(self) end },
    { name = "xrec2",   settle = 25, secs = 20, hover = true, setup = function(self) end },
    { name = "xrec3",   settle = 25, secs = 20, hover = true, setup = function(self) end },
}

-- POOL plan: run 4's GPU log showed the card pegged at its full 2GB dedicated VRAM with
-- r_TexturesStreamPoolSize=2536 - the engine promises itself 500MB more texture pool
-- than the card holds, so every unique merc armour set evicts in-view city textures and
-- the whole street view pays residency churn for minutes. This plan clamps the pool to
-- fit real VRAM mid-run (A/B/A) and re-runs the hire ladder against the clamp.
mercenaries.BenchPoolPlan = {
    { name = "p0",       settle = 6,  secs = 15, hover = true, setup = function(self) end },
    { name = "p5rand",   settle = 20, secs = 20, hover = true, setup = function(self)
                             self:Hire(0, 5, "medium") end },
    { name = "ppool",    settle = 20, secs = 25, hover = true, setup = function(self)
                             pcall(function() System.SetCVar("r_TexturesStreamPoolSize", 1200) end) end },
    { name = "ppool2",   settle = 4,  secs = 20, hover = true, setup = function(self) end },
    { name = "p20",      settle = 25, secs = 25, hover = true, setup = function(self)
                             self:Hire(0, 15, "medium") end },
    { name = "ppoolback",settle = 20, secs = 25, hover = true, setup = function(self)
                             pcall(function() System.SetCVar("r_TexturesStreamPoolSize", 2536) end) end },
    { name = "ppoolre",  settle = 20, secs = 25, hover = true, setup = function(self)
                             pcall(function() System.SetCVar("r_TexturesStreamPoolSize", 1200) end) end },
    { name = "pdis",     settle = 45, secs = 20, hover = true, setup = function(self)
                             self:SetState('dismiss') end },
    { name = "prec",     settle = 30, secs = 20, hover = true, setup = function(self) end },
}

-- One line of population truth per scenario: if fps falls while these hold flat, the
-- cost is per-merc engine work; if npcWorld/horses climb across scenarios that should
-- be flat (or 'dismissed' fails to return to the m0 numbers), something is LEAKING.
function mercenaries:BenchCensus(label)
    local nWorld, nNear, nHorse, nMercs = -1, -1, -1, 0
    pcall(function() local t = System.GetEntitiesByClass("NPC");   nWorld = t and #t or 0 end)
    pcall(function() local t = System.GetEntitiesByClass("Horse"); nHorse = t and #t or 0 end)
    pcall(function()
        local pp = player:GetWorldPos()
        local t = System.GetPhysicalEntitiesInBoxByClass(pp, 60.0, "NPC")
        nNear = t and #t or 0
    end)
    for _ in pairs(self.ActiveMercs or {}) do nMercs = nMercs + 1 end
    local vdr, aiDet
    pcall(function() vdr = System.GetCVar("e_ViewDistRatio") end)
    pcall(function() aiDet = System.GetCVar("WH_AI_LOD_MaxCountDetail") end)
    local wt = -1
    pcall(function() wt = (Calendar.GetWorldTime() or 0) / 3600.0 end)
    local sPool
    pcall(function() sPool = System.GetCVar("r_TexturesStreamPoolSize") end)
    local nOv = 0
    for _ in pairs(self.CvarOverride or {}) do nOv = nOv + 1 end
    bLog(string.format("CENSUS %-10s mercs=%d npcWorld=%d npcNear60=%d horses=%d eVDR=%s aiDetail=%s boost=%s"
        .. " wt=%.2fh idle=%s alert=%s leader=%s pinned=%s tw=%d streamPool=%s",
        tostring(label), nMercs, nWorld, nNear, nHorse, tostring(vdr), tostring(aiDet),
        tostring(self.LodBoostActive), wt, tostring(_G.MercIdle), tostring(self.EnemyAlerted),
        tostring(self.FormationLeader ~= nil), tostring(self.LodBoostPinned), nOv, tostring(sPool)))
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
    pcall(function() self:BenchCensus(S.plan.name) end)

    -- Next scenario.
    S.idx = S.idx + 1
    local plan = (self._benchPlanActive or self.BenchPlan)[S.idx]
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

function mercenaries:BenchStart(autoquit, planTable)
    if self.BenchRunning then bLog("already running"); return end
    if not player then bLog("no player - not in game yet"); return end
    self.BenchRunning  = true
    self.BenchAutoQuit = (autoquit == true)
    self.BenchSlot     = 1 - (self.BenchSlot or 0)
    self._benchPlanActive = planTable or self.BenchPlan
    self._benchSeen, self._benchWatch, self._benchWatchAt = {}, {}, 0
    self._benchAnchor = nil
    pcall(function()
        local p = player:GetWorldPos()
        self._benchAnchor = { x = p.x, y = p.y, z = p.z }
    end)
    local plan = self._benchPlanActive[1]
    self._benchState = {
        idx = 1, plan = plan, phase = "settle", measuring = false,
        phaseUntil = bClock() + (plan.settle or 2), results = {},
        hist = {0,0,0,0,0,0},
    }
    bLog("=== bench starting: " .. #self._benchPlanActive .. " scenario(s), autoquit=" .. tostring(self.BenchAutoQuit) .. " ===")
    pcall(function() self:BenchCensus("start") end)
    bLog("scenario '" .. plan.name .. "' setup...")
    pcall(plan.setup, self)
    Script.SetTimerForFunction(self.BenchTickMs, "mercenaries.BenchTick" .. self.BenchSlot)
end

-- Test-harness convenience: put the bench triggers back on F8/F9/F10 for a session.
-- NEVER called automatically - several of these QUIT the game, and players kept firing
-- them by accident when the binds were applied on every load. The harness types
-- merc_dev + merc_bench_bindkeys into the console (or just runs the command itself).
function mercenaries:BenchBindKeys()
    pcall(function() System.ExecuteCommand("bind f9 merc_bench") end)
    pcall(function() System.ExecuteCommand("bind f10 merc_bench_auto") end)
    pcall(function() System.ExecuteCommand("bind f8 merc_bench_scale_auto") end)
    System.LogAlways("[Bench] dev binds applied: F9=merc_bench F10=merc_bench_auto F8=merc_bench_scale_auto")
end

-- Dev-gated: the whole bench family is an automated-test surface (harness modes quit
-- the game when done), so none of it is registered until merc_dev - which itself only
-- works in a -devmode launch. See docs/console.md.
mercenaries:DevCommand("merc_bench",      "mercenaries:BenchStart(false)", "Run the scripted perf bench + pop-in detector")
mercenaries:DevCommand("merc_bench_auto", "mercenaries:BenchStart(true)",  "Run the bench and QUIT the game at the end (harness mode)")
mercenaries:DevCommand("merc_bench_scale",      "mercenaries:BenchStart(false, mercenaries.BenchScalePlan)", "Per-merc cost ladder: 0/5/10/20 mercs + pin/btlod A-Bs + dismissal")
mercenaries:DevCommand("merc_bench_scale_auto", "mercenaries:BenchStart(true,  mercenaries.BenchScalePlan)", "The scale ladder, then QUIT (harness mode)")
mercenaries:DevCommand("merc_bench_residue",      "mercenaries:BenchStart(false, mercenaries.BenchResiduePlan)", "Attribute the hire->dismiss fps residue: away-view probes + recovery windows + re-hire")
mercenaries:DevCommand("merc_bench_residue_auto", "mercenaries:BenchStart(true,  mercenaries.BenchResiduePlan)", "The residue plan, then QUIT (harness mode)")
mercenaries:DevCommand("merc_bench_tex",      "mercenaries:BenchStart(false, mercenaries.BenchTexPlan)", "Texture-variety A/B: same NPCs, one shared preset vs randomized, + recovery tail")
mercenaries:DevCommand("merc_bench_tex_auto", "mercenaries:BenchStart(true,  mercenaries.BenchTexPlan)", "The texture plan, then QUIT (harness mode)")
mercenaries:DevCommand("merc_bench_pool",      "mercenaries:BenchStart(false, mercenaries.BenchPoolPlan)", "Texture stream pool clamp A/B/A against the hire ladder")
mercenaries:DevCommand("merc_bench_pool_auto", "mercenaries:BenchStart(true,  mercenaries.BenchPoolPlan)", "The pool plan, then QUIT (harness mode)")
mercenaries:DevCommand("merc_bench_bindkeys", "mercenaries:BenchBindKeys()", "Bind F9/F10/F8 to the bench triggers for this session (harness use)")
