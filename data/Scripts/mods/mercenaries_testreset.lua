-- Per-module resets for every test / harness / dev / debug mode in the mod.
--
-- THE RULE (mod author): a save loaded while any test is active - or written while one was -
-- must come up CLEAN. The Lua VM and the cvars survive a load, pending timers are restored out
-- of the save, and a harness stamps its stage into the store, so nothing may be left to chance.
-- mercenaries.lua's ResetAllTestState (called first thing in OnGameplayStarted) runs every
-- reset registered here, each pcall'd, then removes the entities tests TRACKED, restores every
-- cvar a test changed to its pre-test value, releases test key binds and lifts the harness
-- stamps out of the store. This file is only the per-module part, and it is loaded LAST so
-- every module it names already exists.
--
-- Conventions:
--   * A reset touches only what its module's test mode itself changed. A step that has nothing
--     to undo is a cheap no-op, so the reset is safe on every load of every player.
--   * Timers cannot be cancelled. A chain that checks a Running flag dies the moment the flag is
--     cleared (a timer restored out of a save then finds the flag false and does nothing); a
--     one-shot that DOES something (TorturePhaseB, TortureQuestBegin) carries an armed flag.
--   * Entity ids are recycled across a load. Anything held by id is removed only through
--     TestRemoveById, which checks the NAME carries a test prefix; anything held by name goes
--     through TestTrack / System.GetEntityByName. Never a blind RemoveEntity(oldId).
--   * Never delete a real mercenary or a vanilla NPC.
--   * Never bind an F key. Test binds go through TestBindKey, which refuses them.
--
-- Log prefix: [Merc].

local function rLog(s) System.LogAlways("[Merc] " .. tostring(s)) end

-- One named step inside a module's reset: pcall'd and logged, so one failure never stops the rest.
local function try(label, fn)
    local ok, err = pcall(fn)
    if not ok then rLog("test reset step '" .. tostring(label) .. "' failed: " .. tostring(err)) end
    return ok
end

-- Remove every entity in `list` (ids or entity tables) whose name carries a test prefix.
local function rmList(self, list, prefixes)
    local n = 0
    for _, v in pairs(list or {}) do
        if self:TestRemoveById(v, prefixes) then n = n + 1 end
    end
    return n
end

local function reg(name, fn) mercenaries:RegisterTestReset(name, fn) end

-- =============================================================================
-- Torture harness (mercenaries_torture.lua, mercenaries_torture_quest.lua)
-- State: TortureRunning + the 1 s tick chain, TortureAutoQuit (QUITS THE GAME when a run
-- finishes), TortureDrivesPlayer (blinds the fast-travel detector), the player's god-mode
-- maximum health (50000), RaidEnabled / LivePatrolsEnabled switched off for the run, the
-- AlxSignalToken wrapper, the resume timers, _tortureState. Persisted: the stage stamps in the
-- store (lifted out by ResetAllTestState).
-- =============================================================================
function mercenaries:TortureReset(reason)
    local was = self.TortureRunning
    self.TortureRunning       = false       -- the tick chain (and any restored timer) stops here
    self.TortureAutoQuit      = false       -- a stale true quits the loaded game
    self.TortureDrivesPlayer  = false
    self._torturePhaseBArmed       = false  -- a restored phase-B timer would QUIT the game
    self._tortureQuestBeginArmed   = false
    self._tortureQuestStage, self._tortureQuestAuto = nil, nil

    try("torture: player health", function()
        local a = player and player.actor
        local god = self.TortureGodHealth or 50000
        if a then
            local real = self._tortureRealMaxHp
            local mx = a:GetMaxHealth()
            if mx and mx >= god - 1 then
                if real and real > 0 then
                    a:SetMaxHealth(real)
                    local h = a:GetHealth()
                    if h and h > real then a:SetHealth(real) end
                    rLog("test reset: player max health put back to " .. tostring(real))
                else
                    -- A fresh process loaded a save written mid-test: the real maximum is not
                    -- recorded anywhere (recording it would put a test flag in the save). The
                    -- engine recomputes it from stats on a load, so this is only a warning.
                    rLog("test reset: WARNING player max health reads " .. tostring(mx) ..
                         " (torture god mode) and the real value is unknown")
                end
            end
        end
        self._tortureRealMaxHp = nil
    end)
    try("torture: raid/patrol switches", function()
        if self._tortureRaidWas ~= nil then
            self.RaidEnabled, self._tortureRaidWas = self._tortureRaidWas, nil
        end
        if self._torturePatrolWas ~= nil then
            self.LivePatrolsEnabled, self._torturePatrolWas = self._torturePatrolWas, nil
        end
    end)
    try("torture: AlxSignalToken wrapper", function()
        if self._tortureQuestAlxSignal then
            self.AlxSignalToken, self._tortureQuestAlxSignal = self._tortureQuestAlxSignal, nil
        end
    end)
    self._tortureState = nil
    if was then rLog("test reset: torture harness stopped") end
end
reg("torture", function(self, reason) self:TortureReset(reason) end)

-- =============================================================================
-- Bench (mercenaries_bench.lua)
-- State: BenchRunning + tick chain, BenchAutoQuit (quits the game), the LOD-boost pin the
-- boostcycle scenario flips, the formation cycle, the texture pool cvar (TestCvarSet).
-- =============================================================================
function mercenaries:BenchReset(reason)
    local was = self.BenchRunning
    self.BenchRunning, self.BenchAutoQuit = false, false
    try("bench: lod boost pin", function()
        if self._benchBoostWas ~= nil and self.LodBoostPin then self:LodBoostPin(false) end
    end)
    if was then
        -- The scale ladder flips the render pin and the behaviour LOD for its A/Bs; a run cut
        -- short mid-ladder would leave either off. Both ship ON. Fields, not RenderPinSet: that
        -- walks ActiveMercs, whose entities are stale at this point of a load.
        self.RenderPin, self.BehaviourLodOn = true, true
    end
    self._benchBoostWas, self._benchBoostCycle, self._benchFormCycle = nil, false, nil
    self._benchState, self._benchPlanActive, self._benchAnchor = nil, nil, nil
    self._benchSeen, self._benchWatch, self._benchWatchAt = {}, {}, 0
    if was then rLog("test reset: bench stopped") end
end
reg("bench", function(self, reason) self:BenchReset(reason) end)

-- =============================================================================
-- Wall lab (mercenaries_navlab.lua) and the test NPC (mercenaries_testnpc.lua)
-- State: LabRun (case state, the cvar snapshot, saved waypoints), LabLocate, LabAutoQuit
-- (quits the game), the lab wall / marker entities, the test NPCs, NavWaypoints.
-- =============================================================================
function mercenaries:LabReset(reason)
    local run = self.LabRun
    self.LabAutoQuit = false
    self.LabLocate = nil
    try("lab: cvars", function()
        if run and run.snap then
            for name, v in pairs(run.snap) do
                if v ~= nil then pcall(function() System.SetCVar(name, v) end) end
            end
        end
    end)
    try("lab: wall", function()
        -- LabWallEnts can alias the REAL wall's segment list (LabBuildWall swaps them around a
        -- build), and its pieces carry the real wall's name, so: never mutate the list, and
        -- never remove an id the live wall owns.
        local real = {}
        for _, id in ipairs(self.WallSegEnts or {}) do real[id] = true end
        if self.LabWallEnts ~= self.WallSegEnts then
            for _, id in ipairs(self.LabWallEnts or {}) do
                if not real[id] then
                    self:TestRemoveById(id, { "MercWallSeg_", "MercNavLab_" })
                end
            end
        end
        self.LabWallEnts = {}
    end)
    if run then
        self.NavWaypoints = run.savedWps or {}
        self.LabResults = run.results
    end
    self.NavWalkRequested = false
    self.LabRun = nil
    try("lab: harness key", function()
        -- numpad-9 -> merc_wall_lab_auto, bound once at load in a -devmode launch only. Nothing
        -- else in the mod uses np_9, and UnbindKey only touches a key BindKey bound.
        if self:UnbindKey("np_9") then rLog("test reset: released the wall-lab harness key (np_9)") end
    end)
    if run then rLog("test reset: wall lab stopped, its cvars put back") end
end
reg("navlab", function(self, reason) self:LabReset(reason) end)

function mercenaries:TestNpcReset(reason)
    -- The NPCs themselves are tracked by name (SpawnTestNpc -> TestTrack) and removed centrally.
    self.TestNpcs = {}
    self.TestNpcRetreating = {}
    self.NavWalkRequested = false
end
reg("testnpc", function(self, reason) self:TestNpcReset(reason) end)

-- Wall-battle test raid (merc_wb_raid): the force is tracked by name (TestTrack in WBRaid).
function mercenaries:WallBattleTestReset(reason)
    if self.WBRaidForce ~= nil then
        self.WBRaidForce, self.WBRaidStaged, self.WBRaidAt = nil, false, nil
    end
end
reg("wallbattle", function(self, reason) self:WallBattleTestReset(reason) end)

-- =============================================================================
-- Navmesh lab bits (mercenaries_navmesh.lua): the engine obstacle cvars merc_nav_engine_arm
-- raises (it keeps its own saved values), the debug markers, the debug-log flag.
-- =============================================================================
function mercenaries:NavMeshTestReset(reason)
    try("navmesh: engine cvars", function()
        local saved = self._navEngineSaved
        if saved then
            for name, v in pairs(saved) do
                if v ~= nil then pcall(function() System.SetCVar(name, v) end) end
            end
        end
        self._navEngineSaved = nil
    end)
    try("navmesh: debug markers", function()
        rmList(self, self.NavDebugEnts, { "MercNavDbg_" })
        self.NavDebugEnts = {}
    end)
    self.NavDebug = false
end
reg("navmesh", function(self, reason) self:NavMeshTestReset(reason) end)

-- =============================================================================
-- AI probe (mercenaries_aiprobe.lua): test walls / crossing subjects / blocker checks, the
-- MNM rebuild cvars (TestCvarSet), the census chain, the headless on-load switches.
-- =============================================================================
function mercenaries:AIProbeReset(reason)
    self.AIProbeOnLoadRun, self.AIProbeCrossOnLoad, self.AIProbeCensusOnLoad = false, false, false
    self.AIProbeSpawnTest, self.AIProbeMNMTest = false, false
    try("aiprobe: entities", function()
        rmList(self, self.AIProbeMNMEnts,    { "MercMNMTest_" })
        rmList(self, self.AIProbeCrossEnts,  { "MercCrossWall_" })
        rmList(self, self.AIProbeExtentEnts, { "MercExtent_" })
        if self.AIProbeBlockerEnt then
            self:TestRemoveById(self.AIProbeBlockerEnt, { "MercBlockerCheck_" })
        end
    end)
    self.AIProbeMNMEnts, self.AIProbeCrossEnts, self.AIProbeExtentEnts = {}, {}, {}
    self.AIProbeBlockerEnt, self.AIProbeBlockerWant = nil, nil
    self.AIProbeCrossState, self.AIProbeCrossLine = nil, nil
    -- AIProbeWallEnts are segments built through the REAL wall spawner (WallSpawnSegment); they
    -- are not removed by id here (they live in WallSegEnts), only forgotten.
    self.AIProbeWallEnts = {}
    self.CensusLast = nil
end
reg("aiprobe", function(self, reason) self:AIProbeReset(reason) end)

-- =============================================================================
-- Camp inspection (mercenaries_campshot.lua)
-- State: the view camera override (CryAction.SetViewCamera, re-applied every 60 ms), the
-- orbit / hold / geometry / hilly scans and their timers, the player's immortality buff and
-- 1 s refill (merc_shot_god), the HUD / debug-overlay / grass / vegetation cvars (TestCvarExec).
-- =============================================================================
function mercenaries:CampShotReset(reason)
    self.ShotRun, self.ShotGeo, self.HillyScan = nil, nil, nil
    try("campshot: camera", function()
        if self._shotCamTouched and CryAction and CryAction.ResetToNormalCamera then
            CryAction.ResetToNormalCamera()
        end
        self._shotCamTouched = false
    end)
    try("campshot: player god", function()
        local buff = "44e1ccc9-9252-48a9-922d-2ae4523c69a3"
        local had = self.ShotGodOn or self.ShotGodBuffInst
        self.ShotGodOn, self.ShotGodTicks = false, 0
        if had and player and player.soul then
            if self.ShotGodBuffInst then
                pcall(function() player.soul:RemoveBuff(self.ShotGodBuffInst) end)
            end
            pcall(function() player.soul:RemoveAllBuffsByGuid(buff) end)
        end
        self.ShotGodBuffInst = nil
    end)
end
reg("campshot", function(self, reason) self:CampShotReset(reason) end)

-- =============================================================================
-- Camp debug (mercenaries_camp_debug.lua): activity-test anchors, ground-scan markers, the
-- seat watch.
-- =============================================================================
function mercenaries:CampDebugReset(reason)
    try("camp_debug: activity test", function()
        if #(self.ActivityTestEntities or {}) > 0 then
            rmList(self, self.ActivityTestEntities, { "MercActTest_" })
            self.ActivityTestEntities = {}
            self.CampActivities = {}
            _G.MercCampChat = nil
            self.CampChatTicks = 0
        end
    end)
    try("camp_debug: scan markers", function()
        rmList(self, self.ScanTestEntities, { "MercCampScan_" })
        self.ScanTestEntities = {}
    end)
    self.SeatWatchOn = false
end
reg("camp_debug", function(self, reason) self:CampDebugReset(reason) end)

-- =============================================================================
-- Lineups and previews: weapon audit, companion lineup, upgrade / forge preview.
-- =============================================================================
function mercenaries:LineupReset(reason)
    -- Both lineups track their NPCs by name, so the existing clear functions are safe.
    try("weapon_audit", function()
        if next(self.WeaponAuditSpawned or {}) then self:WeaponAuditClear() end
    end)
    try("cc_lineup", function()
        if next(self.CCLineupSpawned or {}) then self:CCLineupClear() end
    end)
end
reg("lineups", function(self, reason) self:LineupReset(reason) end)

function mercenaries:UpgradePreviewReset(reason)
    try("upgrade_preview: props", function()
        local pfx = { "MercUpgPreview_", "MercUpgPrefab_", "MercSmithery_", "MercSmithAlign_",
                      "MercSmithyBase_", "MercAnvilAlign_", "MercForgeRig_" }
        for _, id in ipairs(self.UpgradePreviewEntities or {}) do
            if self.UpgradePreviewPrefabHosts and self.UpgradePreviewPrefabHosts[id] then
                -- a prefab host: Game.DeletePrefab only if the id still names OUR host
                local ent
                pcall(function() ent = System.GetEntity(id) end)
                local nm
                pcall(function() nm = ent and ent:GetName() end)
                if type(nm) == "string" and string.find(nm, "MercUpgPrefab_", 1, true) == 1 then
                    pcall(function() Game.DeletePrefab(id) end)
                end
            end
            self:TestRemoveById(id, pfx)
        end
        self.UpgradePreviewEntities, self.UpgradePreviewPrefabHosts = {}, {}
        rmList(self, self.PartInstances, { "MercPart_" })
        self.PartInstances, self.PartParams, self.PartAnchor = {}, {}, nil
    end)
    try("upgrade_preview: borrowed anvil", function()
        -- The forge R&D borrows a vanilla Smithery and moves it. Put it back BY NAME: the
        -- record's entity table is stale after a load.
        local rec = self.AnvilBorrow
        if rec then
            local nm
            pcall(function() nm = rec.sm:GetName() end)
            local sm
            if type(nm) == "string" then pcall(function() sm = System.GetEntityByName(nm) end) end
            if sm and rec.smPos then pcall(function() sm:SetWorldPos(rec.smPos) end) end
            for _, v in ipairs(rec.visuals or {}) do
                if v.e then self:TestRemoveById(v.e.id, { "MercForgeRig_", "MercUpgPreview_" }) end
            end
            self.AnvilBorrow = nil
            rLog("test reset: borrowed smithery put back")
        end
    end)
end
reg("upgrade_preview", function(self, reason) self:UpgradePreviewReset(reason) end)

-- =============================================================================
-- UI test bench (mercenaries_uitest.lua) and Scaleform test (mercenaries_swftest.lua)
-- State: the test menu / modal / LockPicking / bubbles / world-label tracker / overlay, the
-- immediate-mode draw entity and its frame hook, the HUD, the 'menu' action map, the aux-geom
-- and bubble cvars (TestCvarSet), the SWF stress / pin / spin entities and frame hooks.
-- =============================================================================
function mercenaries:UITestReset(reason)
    local T = self.UIT
    if not T then return end
    local dirty = T.dirty or T.tracking or T.overlay or T.drawing or T.bubbling or T.lockOn
    T.pending = nil
    mercenaries.FrameHooks = mercenaries.FrameHooks or {}
    mercenaries.FrameHooks["uitest"] = nil
    try("uitest: draw entity", function()
        if T.drawEnt then self:TestRemoveById(T.drawEnt, { "merc_uidraw_" }) end
        T.drawEnt = nil
        T.drawing = false
    end)
    try("uitest: key binds", function()
        if T.keysBound then
            -- np_7 / np_8 are also the command interface's own keys: leave those while it is on.
            local shared = self.CMD and self.CMD.on
            for _, k in ipairs({ "np_6", "np_9" }) do self:UnbindKey(k) end
            if not shared then
                for _, k in ipairs({ "np_7", "np_8" }) do self:UnbindKey(k) end
            end
            T.keysBound = false
            rLog("test reset: UI test key binds released")
        end
    end)
    if dirty then
        -- UIOff hides the test screens, restores the HUD and switches the 'menu' action map off.
        try("uitest: UIOff", function() self:UIOff() end)
        T.dirty, T.lockOn = false, false
        rLog("test reset: UI test screens closed, HUD and menu action map restored")
    end
end
reg("uitest", function(self, reason) self:UITestReset(reason) end)

function mercenaries:SwfTestReset(reason)
    local H = mercenaries.FrameHooks
    local hooked = H and (H["swfstress"] or H["swfpin"] or H["imgspin"])
    if H then H["swfstress"], H["swfpin"], H["imgspin"] = nil, nil, nil end
    try("swftest: entities", function()
        -- Class sweep: these entities are of the mod's own class mercenaries_UIDraw and carry
        -- test names; the command UI's own draw entity is named differently and is left alone.
        local pfx = { "merc_swfstress_", "merc_swfpin_", "merc_imgspin_", "merc_uidraw_" }
        for _, e in pairs(System.GetEntitiesByClass("mercenaries_UIDraw") or {}) do
            self:TestRemoveById(e, pfx)
        end
    end)
    try("swftest: state", function()
        local S = self.SWF
        local was = S and S.on
        if S then S.ent, S.on = nil, false end
        if self.IMG then self.IMG.ent = nil end
        if self.SWFW then self.SWFW.on = false end
        if was or hooked then
            pcall(function() UIAction.HideElement(S.element, 0) end)
            pcall(function() UIAction.HideElement(self.IMG.element, 0) end)
        end
    end)
end
reg("swftest", function(self, reason) self:SwfTestReset(reason) end)

-- =============================================================================
-- Command interface remote-control poll / calibration (mercenaries_cmdui.lua)
-- The interface itself is a shipping feature (BLOnLoad / CUOnLoad own it); only the dev
-- control-file poll and the calibration draws are test state.
-- =============================================================================
function mercenaries:CmdUiTestReset(reason)
    if self.CMD then self.CMD.remoteOn, self.CMD.stats = false, false end   -- poll + draw-call readout
    if mercenaries.FrameHooks then
        mercenaries.FrameHooks["cmdcal"], mercenaries.FrameHooks["cmdchars"] = nil, nil
    end
end
reg("cmdui", function(self, reason) self:CmdUiTestReset(reason) end)

-- =============================================================================
-- Profiling and tracing: profiler, verbose counters, fast-travel tracer, combat probe.
-- State: wrapped mod methods, replaced System.* query globals (verbose), a stopped Lua GC, the
-- heartbeat chain, the FtTrace / CombatWhy switches that OnGameplayStarted would re-arm.
-- =============================================================================
function mercenaries:ProfilerTestReset(reason)
    try("profiler", function()
        local was = self.ProfEnabled
        local wrapped = next(self._profWrapped or {}) ~= nil
        self.ProfEnabled = false
        if wrapped and self.ProfUninstrumentAll then self:ProfUninstrumentAll() end
        pcall(collectgarbage, "restart")            -- merc_gc 0 stops it
        self._profHbArmed = false
        if was or wrapped then rLog("test reset: profiler off, instrumentation removed") end
    end)
end
reg("profiler", function(self, reason) self:ProfilerTestReset(reason) end)

function mercenaries:VerboseTestReset(reason)
    try("verbose", function()
        -- Puts back the System.GetEntitiesInSphere / ...ByClass globals and every wrapped method.
        if self.VerboseOn then self:VerboseArm(false) end
    end)
end
reg("verbose", function(self, reason) self:VerboseTestReset(reason) end)

function mercenaries:TraceTestReset(reason)
    self.FtTraceOn, self._ftState = false, nil
    self.CombatWhyOn = false
    try("combatwhy", function()
        if self.CombatWhyPassClear then self:CombatWhyPassClear("reset") end
    end)
end
reg("tracers", function(self, reason) self:TraceTestReset(reason) end)

-- merc_battlecvar: hand-applied scripted-battle render cvars (kept in CvarOverride, and the
-- watchdog's cvar detection is suppressed while any is applied).
function mercenaries:BattleCvarTestReset(reason)
    try("battlecvar", function()
        if next(self.BattleCvarApplied or {}) and self.BattleCvarOff then
            self:BattleCvarOff()
        end
        self.MQWCvarSuppressed = false
    end)
end
reg("battlecvar", function(self, reason) self:BattleCvarTestReset(reason) end)

-- =============================================================================
-- Hide-others (mercenaries_hide_others.lua): hides + deactivates every vanilla NPC and is
-- documented NOT save-safe - the hidden state is written into the save. Restores BY NAME
-- (ids are recycled).
-- =============================================================================
function mercenaries:HideOthersTestReset(reason)
    local was = self.HideOthersActive
    self.HideOthersActive = false           -- the rescan chain stops
    local names, n = self.HiddenOthersNames or {}, 0
    try("hide_others: restore", function()
        if not next(names) then return end
        local want = {}
        for _, nm in pairs(names) do want[nm] = true end
        -- One class pass instead of a GetEntityByName scan per hidden man.
        for _, ent in pairs(System.GetEntitiesByClass("NPC") or {}) do
            local nm
            pcall(function() nm = ent:GetName() end)
            if nm and want[nm] and ent ~= player then
                pcall(function() ent:Activate(1) end)
                pcall(function() ent:Hide(0) end)
                n = n + 1
            end
        end
    end)
    self.HiddenOthersSet, self.HiddenOthersNames = {}, {}
    if was or n > 0 then rLog("test reset: hide-others off, " .. n .. " NPC(s) un-hidden") end
end
reg("hide_others", function(self, reason) self:HideOthersTestReset(reason) end)

-- =============================================================================
-- Editors: bandit-camp builder, siege builder, Aleksej lodging editor, patrol route recorder
-- (their F-key binders are gone; the editors still hold a category, a placement ghost, an undo
-- stack and a recording). The "EditorOwner" store tag is lifted by ResetAllTestState.
-- =============================================================================
function mercenaries:EditorsTestReset(reason)
    local editing = (self.BCampCat or 0) ~= 0 or (self.SiegeCat or 0) ~= 0 or (self.AlxCat or 0) ~= 0
    try("editors: placement ghost", function()
        if editing then
            -- not EndPlacement/GhostClear: those RemoveEntity by (possibly stale) id
            for _, g in ipairs(self.GhostParts or {}) do
                if g.ent then self:TestRemoveById(g.ent, { "MercPlaceGhost_" }) end
            end
            self.GhostParts = {}
            self.ActivePlacement = nil
        end
    end)
    self.BCampCat, self.SiegeCat, self.AlxCat = 0, 0, 0
    -- Placed pieces are plain world props flagged out of the save; only the undo stacks are dropped.
    if editing then
        self.BCampPieces, self.SiegePieces, self.AlxPieces = {}, {}, {}
        rLog("test reset: editor categories and undo stacks cleared")
    end
    try("editors: route recorder", function()
        local rec = self.RouteRecording
        if rec then
            rmList(self, rec.ents, { "MercRouteMk_" })
            self.RouteRecording = nil
            rLog("test reset: route recording discarded")
        end
        for _, r in ipairs(self.PatrolRoutes or {}) do
            if r.ents and #r.ents > 0 then
                rmList(self, r.ents, { "MercRouteMk_" })
                r.ents = {}
            end
        end
    end)
end
reg("editors", function(self, reason) self:EditorsTestReset(reason) end)
