-- Automated FUNCTIONAL test campaign ("torture test"). Where mercenaries_bench.lua
-- measures frame time, this one checks BEHAVIOUR: hire, follow, camp, upgrades, the
-- deploy composition, the sit/sleep combat handoff, the time-skip guards, single-upgrade
-- removal, and - across a quicksave the harness reloads mid-run - camp persistence.
--
-- Runs unattended: F8 / merc_torture_auto starts it, every step logs
-- [Torture] PASS/FAIL/INFO lines the harness (tools/torturetest.ps1) collects, and the
-- run quits the game when done so the harness can cycle. The player is held ~16m above
-- the field in god mode for the whole run - no test may ever endanger or need Henry.
--
-- Two phases, because a save load kills every timer:
--   A: the scenario chain below, ending in SaveString("TortureStage","B") + QuickSave +
--      the "[Torture] SAVED - awaiting reload" line the harness watches for. The harness
--      then drives the Escape-menu reload by keystroke.
--   B: TortureOnLoad (armed from OnGameplayStarted, a fresh timer) sees stage "B" in the
--      save, waits for the camp restore to settle, and verifies persistence.

mercenaries.TortureRunning  = false
mercenaries.TortureSlot     = 0
mercenaries.TortureTickMs   = 1000
mercenaries.TortureAutoQuit = false
mercenaries.TortureHover    = 16.0
mercenaries.TortureDeadline = 900     -- phase A hard cap, seconds

local function tLog(s) System.LogAlways("[Torture] " .. tostring(s)) end

local function tClock()
    local t = 0; pcall(function() t = System.GetCurrTime() or 0 end); return t
end

-- ---------------------------------------------------------------------------
-- verdict bookkeeping
-- ---------------------------------------------------------------------------

function mercenaries:TortureCheck(name, ok, detail)
    local S = self._tortureState
    if S then
        if ok then S.pass = (S.pass or 0) + 1 else S.fail = (S.fail or 0) + 1 end
    end
    tLog((ok and "PASS " or "FAIL ") .. name .. (detail and (" - " .. tostring(detail)) or ""))
end

function mercenaries:TortureInfo(name, detail)
    tLog("INFO " .. name .. (detail and (" - " .. tostring(detail)) or ""))
end

-- ---------------------------------------------------------------------------
-- shared probes
-- ---------------------------------------------------------------------------

-- Alive squad count, straight off the cache.
local function squadCount(self)
    local n = 0
    for _, ent in pairs(self.ActiveMercs or {}) do
        if ent and self:IsAliveAndWell(ent, true) then n = n + 1 end
    end
    return n
end

-- Deployed (out-party) count and how many of them are archers.
local function outPartyStats(self)
    local out, arch = 0, 0
    for name, ent in pairs(self.ActiveMercs or {}) do
        local ka = self:CampMercKeys(ent)
        if ka and self:IsCampOut(ka) then
            out = out + 1
            if self:IsArcherName(name) then arch = arch + 1 end
        end
    end
    return out, arch
end

-- Living mod enemies near the player (the fight-over test).
local function liveEnemies(self)
    local n = 0
    pcall(function()
        local pp = player:GetWorldPos()
        local ents = System.GetPhysicalEntitiesInBoxByClass(pp, 150.0, "NPC")
        for _, e in pairs(ents or {}) do
            local nm; pcall(function() nm = e:GetName() end)
            if nm and self:IsModEnemyName(nm) and self:IsAliveAndWell(e, true) then
                n = n + 1
            end
        end
    end)
    return n
end

-- Names of nearby NPCs that are neither ours nor our enemies: base-game bystanders.
-- Snapshotted before a staged fight; anybody missing afterwards died in it.
local function vanillaBystanders(self)
    local out = {}
    pcall(function()
        local pp = player:GetWorldPos()
        local ents = System.GetPhysicalEntitiesInBoxByClass(pp, 100.0, "NPC")
        for _, e in pairs(ents or {}) do
            local nm; pcall(function() nm = e:GetName() end)
            -- "ours" = every mod spawn: Spawned* covers friends/enemies/foes/patrols/
            -- tower archers, Merc* the quartermaster + camp anchors, Alx*/Aleksej* his
            -- quest camps; horses are excluded so a merc's mount dying in the scrum
            -- does not read as a murdered villager.
            if nm and not string.find(nm, "Spawned", 1, true)
               and not string.find(nm, "Merc", 1, true)
               and not string.find(nm, "Alx", 1, true)
               and not string.find(nm, "Aleksej", 1, true)
               and not string.find(nm, "orse", 1, true)
               and not string.find(nm, "Dude", 1, true)
               and self:IsAliveAndWell(e, true) then
                out[nm] = true
            end
        end
    end)
    return out
end

local function tileSnapshot(self)
    local snap = {}
    for name, t in pairs(self.CampStationTiles or {}) do
        snap[name] = { x = t.x, y = t.y }
    end
    return snap
end

-- ---------------------------------------------------------------------------
-- player safety: held aloft, immortal, re-asserted every tick
-- ---------------------------------------------------------------------------

function mercenaries:TortureKeepSafe()
    local S = self._tortureState
    if not (S and S.anchor) then return end
    -- The save step lands Henry: the engine refuses to write a save while the player
    -- is airborne, and he hovers for the whole campaign - which is why Game.QuickSave
    -- never produced a file in five runs. God stays on either way.
    if S.groundForSave then
        pcall(function()
            local a = S.anchor
            player:SetWorldPos({ x = a.x, y = a.y, z = a.z })
        end)
        return
    end
    pcall(function()
        local a = S.anchor
        player:SetWorldPos({ x = a.x, y = a.y, z = a.z + self.TortureHover })
    end)
    pcall(function() player:SetWorldAngles({ x = -1.22, y = 0, z = 0 }) end)
    if not S.godTried then
        S.godTried = true
        pcall(function() System.ExecuteCommand("god 1") end)
        pcall(function() System.ExecuteCommand("god") end)
    end
end

-- ---------------------------------------------------------------------------
-- the scenario chain. Each step: `run` once on entry (may queue `actions`, executed
-- one per tick to stagger heavy calls), then `check` every tick until it returns
-- true (pass), false (fail), or the timeout lapses (fail unless `soft`).
-- ---------------------------------------------------------------------------

mercenaries.TorturePlan = {

    { name = "sanity", timeout = 40,
      run = function(self, S)
          S.startSquad = squadCount(self)
          self:TortureInfo("sanity", "squad at start = " .. S.startSquad
              .. ", campActive = " .. tostring(self.CampActive))
          -- Normalise the world: a camp left standing by a previous run's save makes
          -- every new hire join camp life instead of following (by design), which
          -- invalidates the follow test. Start from open ground.
          if self.CampActive then self:BreakMercCamp(true) end
      end,
      check = function(self, S)
          if self.CampActive then return nil end
          local fid; pcall(function() fid = System.GetFrameID() end)
          if fid then return true end
      end },

    { name = "hire", timeout = 60,
      run = function(self, S)
          S.wantSquad = S.startSquad + 15
          self:Hire(0, 10, "medium")
          self:HireArcher(0, 5)
      end,
      check = function(self, S)
          if squadCount(self) >= S.wantSquad then
              self:TortureInfo("hire", "squad now " .. squadCount(self))
              return true
          end
      end },

    { name = "follow_settle", timeout = 50, minSecs = 30,
      run = function(self, S) end,
      check = function(self, S)
          -- Judged only after minSecs: give the squad time to spawn horses, form up.
          if (tClock() - S.stepFrom) < 30 then return nil end
          local stalls = 0
          for _ in pairs(self.FollowStallStreak or {}) do stalls = stalls + 1 end
          local leader = self.FormationLeader ~= nil
          if not leader then return false, "no formation leader elected" end
          if stalls > 2 then return false, stalls .. " stall streak(s) while merely following" end
          self:TortureInfo("follow_settle", "leader=" .. tostring(self.FormationLeader)
              .. " squadSize=" .. tostring(self.SquadSize) .. " stallStreaks=" .. stalls)
          return true
      end },

    { name = "camp_make", timeout = 30,
      run = function(self, S)
          self:SpawnMercCamp(S.anchor and { x = S.anchor.x, y = S.anchor.y, z = S.anchor.z,
                                            ang = 0 } or nil, true)
      end,
      check = function(self, S)
          if self.CampActive then return true end
      end },

    { name = "upgrades", timeout = 120,
      run = function(self, S)
          -- The purse hard-caps at 10000 (run 2: ten 1000-chunks then it stopped
          -- moving, and five purchases spent it to the groschen). So fund and buy
          -- pay-as-you-go: a top-up before every purchase.
          local okM, got = self:GiveMoney(9000)
          local purse = "?"
          pcall(function() purse = tostring(player.inventory:GetMoney()) end)
          self:TortureInfo("funding", "GiveMoney ok=" .. tostring(okM) .. " got=" .. tostring(got)
              .. " purse=" .. purse)
          -- One action per tick: each purchase tears the camp down and rebuilds it,
          -- and firing six rebuilds into the same second is not a test of anything.
          local function topup() self:GiveMoney(6000) end
          S.actions = {
              function() self:LogiBuySmithy() end,
              function() end, function() end, topup,           -- let the rebuild land
              function() self:LogiBuyAlchemy() end,
              function() end, function() end, topup,
              function() self:LogiBuyInn() end,
              function() end, function() end, topup,
              function() self:LogiBuyHunter() end,
              function() end, function() end, topup,
              function() self:LogiBuyPractice() end,
              function() end, function() end, topup,
              function() self:LogiBuyFoodCart() end,
          }
      end,
      check = function(self, S)
          if S.actions and #S.actions > 0 then return nil end
          if (tClock() - S.stepFrom) < 60 then return nil end   -- station retry window
          local L = self:LogiState()
          if not (L.hasSmithy and L.hasAlchemy and L.innActive and (L.hunterSpots or 0) > 0
                  and L.hasPracticeYard and (L.foodCartDays or 0) > 0) then
              local purse = "?"
              pcall(function() purse = tostring(player.inventory:GetMoney()) end)
              return false, "an upgrade flag never set (money? " .. purse .. ")"
          end
          local missing = {}
          for _, name in ipairs(self:CampActiveStations()) do
              if not (self.CampStationTiles or {})[name] then table.insert(missing, name) end
          end
          if #missing > 0 then return false, "no tile reserved for: " .. table.concat(missing, ",") end
          -- Borrow-dependent stations may legitimately not stand (no village near) - INFO.
          self:TortureInfo("stations", string.format("forge=%s alchemy=%s inn=%s hunt=%s cart=%s yard=%s",
              tostring(self.CampForge ~= nil), tostring(self.CampAlchemy ~= nil),
              tostring(self.CampInn ~= nil), tostring(self.CampHunt ~= nil),
              tostring(self.CampFoodCart ~= nil), tostring(self.CampPracticeYard ~= nil)))
          return true
      end },

    { name = "composition_half_archers", timeout = 40,
      run = function(self, S)
          self:CampSetComposition(4)          -- archers: half the party
          S.actions = { function() self:CampTakeParty(0.5) end }
      end,
      check = function(self, S)
          if S.actions and #S.actions > 0 then return nil end
          if (tClock() - S.stepFrom) < 8 then return nil end
          local out, arch = outPartyStats(self)
          if out == 0 then return false, "nobody deployed" end
          local want = math.floor(out * 0.5 + 0.5)
          -- Capped by how many archers exist at all.
          local totalArch = 0
          for name in pairs(self.ActiveMercs or {}) do
              if self:IsArcherName(name) then totalArch = totalArch + 1 end
          end
          want = math.min(want, totalArch)
          if math.abs(arch - want) <= 1 then
              self:TortureInfo("composition", "out=" .. out .. " archers=" .. arch .. " (wanted ~" .. want .. ")")
              return true
          end
          return false, "out=" .. out .. " archers=" .. arch .. " wanted ~" .. want
      end },

    { name = "composition_no_archers", timeout = 40,
      run = function(self, S)
          self:CampSetComposition(2)          -- archers: none
          S.actions = { function() self:CampTakeParty(0.5) end }
      end,
      check = function(self, S)
          if S.actions and #S.actions > 0 then return nil end
          if (tClock() - S.stepFrom) < 8 then return nil end
          local out, arch = outPartyStats(self)
          if out == 0 then return false, "nobody deployed" end
          if arch == 0 then return true end
          return false, arch .. " archer(s) deployed under 'none'"
      end },

    { name = "per_merc_stay", timeout = 25,
      run = function(self, S)
          self:CampSetComposition(1)          -- back to default for later phases
          -- Send ONE deployed man back by name, remember who.
          S.oneKey = nil
          for name, ent in pairs(self.ActiveMercs or {}) do
              local ka = self:CampMercKeys(ent)
              if ka and self:IsCampOut(ka) then
                  S.oneKey, S.oneEnt = ka, ent
                  break
              end
          end
          if S.oneEnt then self:CampStayOne(S.oneEnt) end
      end,
      check = function(self, S)
          if not S.oneKey then return false, "no deployed merc to test with" end
          if not self:IsCampOut(S.oneKey) then return true end
      end },

    { name = "per_merc_join", timeout = 25,
      run = function(self, S)
          S.oneKey = nil
          for name, ent in pairs(self.ActiveMercs or {}) do
              local ka = self:CampMercKeys(ent)
              if ka and not self:IsCampOut(ka)
                 and ka ~= self.CampForgeSmithWuid then
                  S.oneKey, S.oneEnt = ka, ent
                  break
              end
          end
          if S.oneEnt then self:CampDeployOne(S.oneEnt) end
      end,
      check = function(self, S)
          if not S.oneKey then return false, "no camped merc to test with" end
          if self:IsCampOut(S.oneKey) then return true end
      end },

    { name = "return_all", timeout = 40,
      run = function(self, S) self:CampReturnAll() end,
      check = function(self, S)
          if (tClock() - S.stepFrom) < 6 then return nil end
          local out = select(1, outPartyStats(self))
          if out == 0 then return true end
      end },

    { name = "camp_fight", timeout = 200,
      run = function(self, S)
          S.bystanders = vanillaBystanders(self)
          local n = 0; for _ in pairs(S.bystanders) do n = n + 1 end
          self:TortureInfo("camp_fight", n .. " base-game bystander(s) on record before the fight")
          S.maxPoseHolds = 0
          self:SpawnEnemyGroup("bandit", 6)
      end,
      check = function(self, S)
          -- Track how many pose-holds are in force at once (each should clear <= 4s).
          local holds = 0
          for _ in pairs(self.CampPoseHoldFrom or {}) do holds = holds + 1 end
          if holds > (S.maxPoseHolds or 0) then S.maxPoseHolds = holds end
          if (tClock() - S.stepFrom) < 20 then return nil end
          if liveEnemies(self) > 0 then return nil end
          -- Fight over: did any base-game bystander die in it?
          local after = vanillaBystanders(self)
          local lost = {}
          for nm in pairs(S.bystanders or {}) do
              if not after[nm] then table.insert(lost, nm) end
          end
          self:TortureInfo("camp_fight", "max simultaneous pose-holds = " .. tostring(S.maxPoseHolds))
          if #lost > 0 then
              return false, #lost .. " base-game NPC(s) died in our staged fight: " .. table.concat(lost, ", ")
          end
          return true
      end },

    { name = "post_fight_settle", timeout = 60,
      run = function(self, S) end,
      check = function(self, S)
          if (tClock() - S.stepFrom) < 25 then return nil end
          local claims = 0
          for _ in pairs(self.MercTargetOf or {}) do claims = claims + 1 end
          if claims > 0 then return nil end   -- keep waiting inside the timeout
          local poses = 0
          for _ in pairs(self.CampPoseHoldFrom or {}) do poses = poses + 1 end
          if poses > 0 then return false, poses .. " pose-hold(s) still armed after the fight" end
          return true
      end },

    { name = "timeskip_guards", timeout = 90,
      run = function(self, S)
          S.skipFrom = tClock()
          -- Restore the ORIGINAL ratio afterwards, not 1: the world clock does not run
          -- 1:1 by default, and leaving it at 1 slows the whole world down.
          S.origRatio = nil
          pcall(function() S.origRatio = Calendar.GetWorldTimeRatio() end)
          pcall(function() Calendar.SetWorldTimeRatio(300) end)
      end,
      check = function(self, S)
          local el = tClock() - S.skipFrom
          if el < 12 then
              -- While the clock races: the spawn guard must read busy.
              if el > 4 and not S.sawBusy then
                  local busy, why = self:PlayerBusyForSpawns()
                  if busy then
                      S.sawBusy = true
                      self:TortureInfo("timeskip", "spawn guard reads busy (" .. tostring(why) .. ")")
                  end
              end
              return nil
          end
          if not S.restored then
              S.restored = true
              pcall(function() Calendar.SetWorldTimeRatio(S.origRatio or 15) end)
              return nil
          end
          -- The ratio can take a few seconds to decay, and every busy reading re-arms
          -- the 6s trailing hold (by design), so allow a wide settle before judging.
          if el < 45 then
              local busy = select(1, self:PlayerBusyForSpawns())
              if not busy and not _G.MercIdle then
                  if not S.sawBusy then return false, "spawn guard never read busy at ratio 300" end
                  return true
              end
              return nil
          end
          local ratio = "?"
          pcall(function() ratio = tostring(Calendar.GetWorldTimeRatio()) end)
          local busy, why = self:PlayerBusyForSpawns()
          return false, "still busy 33s after restore (busy=" .. tostring(busy) .. " why="
              .. tostring(why) .. " ratio=" .. ratio .. " idle=" .. tostring(_G.MercIdle) .. ")"
      end },

    { name = "remove_one_upgrade", timeout = 60,
      run = function(self, S)
          S.before = tileSnapshot(self)
          self:LogiRemoveUpgrade(6)           -- the practice yard
      end,
      check = function(self, S)
          if (tClock() - S.stepFrom) < 20 then return nil end
          local L = self:LogiState()
          if L.hasPracticeYard then return false, "hasPracticeYard still true" end
          for name, t in pairs(S.before or {}) do
              local live = (self.CampStationTiles or {})[name]
              if live then
                  local d = math.sqrt((live.x - t.x) ^ 2 + (live.y - t.y) ^ 2)
                  if d > 1.0 then
                      return false, "station '" .. name .. "' moved " .. string.format("%.1f", d) .. "m on removal rebuild"
                  end
              end
          end
          return true
      end },

    { name = "quicksave", timeout = 40,
      run = function(self, S)
          local out = select(1, outPartyStats(self))
          self:SaveString("TortureStage", "B")
          self:SaveString("TortureSquad", tostring(squadCount(self)))
          self:SaveString("TortureOut", tostring(out))
          local pack = nil
          pcall(function() pack = self:CampPackStationTiles() end)
          if pack then self:SaveString("TortureTiles", pack) end
          pcall(function() self:SaveCampState() end)
          pcall(function() self:LogiSave() end)
          -- Land Henry first - an airborne player cannot save - then the resting
          -- autosave (the binding the camp bed save has proven in live play), with
          -- QuickSave as the fallback, exactly as CampBedSave orders them.
          S.groundForSave = true
          S.actions = {
              function() end, function() end,     -- two grounded ticks to settle
              function()
                  local ok = false
                  pcall(function() ok = Game.SaveGameViaResting() end)
                  if not ok then pcall(function() Game.QuickSave() end) end
              end,
          }
      end,
      check = function(self, S)
          if S.actions and #S.actions > 0 then return nil end
          if (tClock() - S.stepFrom) < 10 then return nil end   -- let the save write out
          return true
      end },
}

-- ---------------------------------------------------------------------------
-- the tick
-- ---------------------------------------------------------------------------

function mercenaries.TortureTick0() mercenaries.TortureBeat(0) end
function mercenaries.TortureTick1() mercenaries.TortureBeat(1) end

function mercenaries.TortureBeat(slot)
    local self = mercenaries
    if not self.TortureRunning or self.TortureSlot ~= slot then return end
    local ok, err = pcall(function() self:TortureStep() end)
    if not ok then tLog("tick error: " .. tostring(err)) end
    Script.SetTimerForFunction(self.TortureTickMs, "mercenaries.TortureTick" .. slot)
end

function mercenaries:TortureStep()
    local S = self._tortureState
    if not S then self.TortureRunning = false; return end
    local now = tClock()

    self:TortureKeepSafe()

    -- Saved and stamped; phase B belongs to the HARNESS now: it kills this session,
    -- relaunches, and presses Continue at the main menu - which resumes the newest
    -- save by time, i.e. the autosave Game.QuickSave() just wrote. (Tried and
    -- rejected: Game.QuickLoad() exists but no-ops - QuickSave writes an AUTOSAVE
    -- slot and no quicksave file ever exists for it to load; and driving the pause
    -- menu by keystroke landed in the SAVE list often enough to overwrite saves.)
    -- The short timeout just closes this session out if the harness never acts.
    if S.awaitReload then
        if now - S.awaitFrom > 90 then
            tLog("no reload after 90s - quitting so the harness can relaunch")
            return self:TortureFinish()
        end
        return
    end

    if now - S.startedAt > self.TortureDeadline then
        self:TortureCheck(S.plan and S.plan.name or "?", false, "campaign deadline hit mid-step")
        return self:TortureFinish()
    end

    -- One queued action per tick (staggers the heavy setup calls).
    if S.actions and #S.actions > 0 then
        local fn = table.remove(S.actions, 1)
        local ok, err = pcall(fn)
        if not ok then tLog("action error in '" .. S.plan.name .. "': " .. tostring(err)) end
        return
    end

    local plan = S.plan
    if not plan then return self:TortureFinish() end

    local ok, verdict, detail = pcall(plan.check, self, S)
    if not ok then
        self:TortureCheck(plan.name, false, "check errored: " .. tostring(verdict))
        return self:TortureNext()
    end
    if verdict == true then
        self:TortureCheck(plan.name, true)
        return self:TortureNext()
    elseif verdict == false then
        self:TortureCheck(plan.name, false, detail)
        return self:TortureNext()
    end
    if now - S.stepFrom > (plan.timeout or 60) then
        self:TortureCheck(plan.name, false, "timed out after " .. tostring(plan.timeout) .. "s")
        return self:TortureNext()
    end
end

function mercenaries:TortureNext()
    local S = self._tortureState

    -- The quicksave step hands control to the harness rather than to a next step.
    if S.plan and S.plan.name == "quicksave" then
        S.awaitReload, S.awaitFrom = true, tClock()
        tLog("SAVED - awaiting reload")
        return
    end

    S.idx = S.idx + 1
    local plan = (S.planList or self.TorturePlan)[S.idx]
    if not plan then return self:TortureFinish() end
    S.plan, S.stepFrom, S.actions = plan, tClock(), nil
    S.oneKey, S.oneEnt, S.sawBusy, S.restored, S.before = nil, nil, nil, nil, nil
    tLog("step '" .. plan.name .. "'")
    local ok, err = pcall(plan.run, self, S)
    if not ok then tLog("run error in '" .. plan.name .. "': " .. tostring(err)) end
end

function mercenaries:TortureFinish()
    local S = self._tortureState
    self.TortureRunning = false
    if self._tortureRaidWas ~= nil then
        self.RaidEnabled, self._tortureRaidWas = self._tortureRaidWas, nil
    end
    tLog(string.format("=========== %d passed, %d failed ===========",
        (S and S.pass) or 0, (S and S.fail) or 0))
    tLog("COMPLETE")
    if self.TortureAutoQuit then
        tLog("auto-quit")
        pcall(function() System.ExecuteCommand("quit") end)
    end
end

function mercenaries:TortureStart(autoquit)
    if self.TortureRunning then tLog("already running"); return end
    if not player then tLog("no player - not in game yet"); return end
    -- A stamped save means this F8 is the harness's second press, after its relaunch:
    -- run the persistence checks instead of a fresh campaign. Explicitly keyed to F8 so
    -- a player loading a stamped save is never hijacked - nothing here runs un-asked.
    if self:LoadString("TortureStage") == "B" then
        self:SaveString("TortureStage", "done")
        tLog("=== phase B: verifying the reloaded world (F8 on a stamped save) ===")
        pcall(function() System.ExecuteCommand("god 1") end)
        Script.SetTimerForFunction(12000, "mercenaries.TorturePhaseB")
        return
    end
    self.TortureRunning  = true
    self.TortureAutoQuit = (autoquit == true)
    self.TortureSlot     = 1 - (self.TortureSlot or 0)
    local anchor = nil
    pcall(function()
        local p = player:GetWorldPos()
        anchor = { x = p.x, y = p.y, z = p.z }
    end)
    self._tortureState = {
        idx = 1, plan = self.TorturePlan[1], planList = self.TorturePlan, stepFrom = tClock(),
        startedAt = tClock(), anchor = anchor, pass = 0, fail = 0,
    }
    -- The campaign stages its own fights; an unscheduled raid landing mid-step would
    -- read as an unrelated FAIL. Put back on finish.
    self._tortureRaidWas = self.RaidEnabled
    self.RaidEnabled = false
    tLog("=== torture campaign: " .. #self.TorturePlan .. " step(s), autoquit=" .. tostring(self.TortureAutoQuit) .. " ===")
    tLog("step '" .. self.TorturePlan[1].name .. "'")
    pcall(self.TorturePlan[1].run, self, self._tortureState)
    Script.SetTimerForFunction(self.TortureTickMs, "mercenaries.TortureTick" .. self.TortureSlot)
end

-- ---------------------------------------------------------------------------
-- phase B: after the harness reloads the quicksave. Armed from OnGameplayStarted
-- (a fresh timer, so the load killing phase A's chain does not matter).
-- ---------------------------------------------------------------------------

-- Retired: this used to arm phase B from OnGameplayStarted, which hijacked the USER'S
-- own sessions (Continue onto a stamped save -> checks run -> auto-quit; reported as
-- "the mod keeps crashing"). Kept as a stub so any stale timer naming it is a no-op.
function mercenaries.TortureOnLoad() end

function mercenaries.TorturePhaseB()
    local self = mercenaries
    local ok, err = pcall(function()
        self._tortureState = self._tortureState or { pass = 0, fail = 0 }

        self:TortureCheck("B_camp_restored", self.CampActive == true,
            self.CampActive ~= true and "CampActive false after reload" or nil)

        local wantSquad = tonumber(self:LoadString("TortureSquad") or "") or -1
        local haveSquad = squadCount(self)
        self:TortureCheck("B_squad_restored", wantSquad < 0 or haveSquad >= wantSquad - 1,
            "saved " .. wantSquad .. ", have " .. haveSquad)

        local wantOut = tonumber(self:LoadString("TortureOut") or "") or -1
        local haveOut = select(1, outPartyStats(self))
        self:TortureCheck("B_outparty_restored", wantOut < 0 or haveOut == wantOut,
            "saved " .. wantOut .. " deployed, have " .. haveOut)

        -- Tiles: every station saved before the reload must be within a metre of where
        -- it was. This is the whole "upgrades shuffle around after a reload" regression.
        local saved = self:LoadString("TortureTiles")
        local worst, worstName, missing = 0, nil, {}
        if saved then
            local body = string.match(saved, "^[^|]*|(.*)$") or ""
            for chunk in string.gmatch(body, "[^;]+") do
                local name, rest = string.match(chunk, "^([^:]+):(.*)$")
                if name then
                    local x, y = string.match(rest, "([^,]+),([^,]+)")
                    x, y = tonumber(x), tonumber(y)
                    local live = (self.CampStationTiles or {})[name]
                    if not live then table.insert(missing, name)
                    elseif x and y then
                        local d = math.sqrt((live.x - x) ^ 2 + (live.y - y) ^ 2)
                        if d > worst then worst, worstName = d, name end
                    end
                end
            end
            self:TortureCheck("B_tiles_stable", #missing == 0 and worst <= 1.0,
                string.format("worst drift %.2fm (%s), missing: %s",
                    worst, tostring(worstName), #missing > 0 and table.concat(missing, ",") or "none"))
        else
            self:TortureInfo("B_tiles_stable", "no saved tile pack to compare against")
        end

        local S = self._tortureState
        tLog(string.format("=========== phase B: %d passed, %d failed ===========",
            S.pass or 0, S.fail or 0))
        tLog("COMPLETE")
        tLog("auto-quit")
        pcall(function() System.ExecuteCommand("quit") end)
    end)
    if not ok then
        tLog("TorturePhaseB error: " .. tostring(err))
        tLog("COMPLETE")
        pcall(function() System.ExecuteCommand("quit") end)
    end
end

-- ---------------------------------------------------------------------------
-- THE ADAPTIVE SCENARIO PROBE (F7 / merc_torture_probe).
--
-- For the purpose-built saves (a vanilla bandit camp, mid-Kuttenberg, the fortified
-- 50-merc camp, an ambush in progress, Trosky): load one, press F7, and it reads the
-- world it landed in and runs only the checks that apply. Observation first: it never
-- saves, never breaks a camp, never normalises anything - the save stays exactly as
-- the player made it. Henry hovers in god mode throughout, as ever.
-- ---------------------------------------------------------------------------

-- Non-mod NPCs near the player, with names - the census that teaches us what the
-- base game calls its people in each scenario.
local function nonModCensus(self)
    local names, n = {}, 0
    pcall(function()
        local pp = player:GetWorldPos()
        local ents = System.GetPhysicalEntitiesInBoxByClass(pp, 120.0, "NPC")
        for _, e in pairs(ents or {}) do
            local nm; pcall(function() nm = e:GetName() end)
            if nm and not string.find(nm, "Spawned", 1, true)
               and not string.find(nm, "Merc", 1, true)
               and not string.find(nm, "Alx", 1, true)
               and not string.find(nm, "Aleksej", 1, true)
               and not string.find(nm, "Dude", 1, true)
               and self:IsAliveAndWell(e, true) then
                n = n + 1
                if #names < 15 then table.insert(names, nm) end
            end
        end
    end)
    return n, names
end

local function countTable(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

mercenaries.TortureProbePlan = {

    { name = "census", timeout = 20,
      run = function(self, S)
          if (tClock() - S.stepFrom) < 0 then return end
      end,
      check = function(self, S)
          if (tClock() - S.stepFrom) < 8 then return nil end   -- let the world stream in
          local nVan, names = nonModCensus(self)
          S.bystanders0 = nVan
          self:TortureInfo("census", string.format(
              "squad=%d campActive=%s towers=%d carts=%d wallRuns=%d gates=%d vanillaNear=%d",
              (function() local c=0 for _,e in pairs(self.ActiveMercs or {}) do if e then c=c+1 end end return c end)(),
              tostring(self.CampActive),
              #(self.TowerStations or {}), #(self.ArcherCarts or {}),
              #(self.WallRuns or {}), #(self.Gates or {}), nVan))
          if #names > 0 then
              self:TortureInfo("census_names", table.concat(names, ", "))
          end
          return true
      end },

    -- A save with no company tells us nothing about the squad: hire one. In the city
    -- this IS the test (street spawning, the indoor/roof trap, formation in lanes).
    { name = "ensure_squad", timeout = 70,
      run = function(self, S)
          S.had = 0
          for _, e in pairs(self.ActiveMercs or {}) do
              if e and self:IsAliveAndWell(e, true) then S.had = S.had + 1 end
          end
          if S.had == 0 then
              self:TortureInfo("ensure_squad", "no company in this save - hiring 8 foot + 4 archers here")
              self:Hire(0, 8, "medium")
              self:HireArcher(0, 4)
          end
      end,
      check = function(self, S)
          if S.had > 0 then
              self:TortureInfo("ensure_squad", S.had .. " merc(s) already present")
              return true
          end
          if (tClock() - S.stepFrom) < 20 then return nil end
          local n = 0
          for _, e in pairs(self.ActiveMercs or {}) do
              if e and self:IsAliveAndWell(e, true) then n = n + 1 end
          end
          if n >= 10 then
              self:TortureInfo("ensure_squad", "hired here: squad now " .. n)
              return true
          end
          if (tClock() - S.stepFrom) > 60 then
              return false, "hired 12 but only " .. n .. " stand (spawn failed here?)"
          end
      end },

    -- The fortified-camp save: were the walls/towers/carts the player built actually
    -- put back by DefRestore? Judged only where the save's own stamps say they belong.
    { name = "defence_restore", timeout = 60,
      run = function(self, S) end,
      check = function(self, S)
          if (tClock() - S.stepFrom) < 20 then return nil end  -- DefRestore is deferred + watchdogged
          local belongs = false
          pcall(function() belongs = self:DefBelongToCurrentCamp() end)
          if not belongs then
              self:TortureInfo("defence_restore", "no defences belong to this pitch - skipped")
              return true
          end
          local savedTowers = (self:LoadString("QMTowers") or ""):gsub("%s", "")
          local savedWall   = (self:LoadString("QMWallPts") or ""):gsub("%s", "")
          local wantTowers  = savedTowers ~= "" and select(2, savedTowers:gsub(";", ";")) + 1 or 0
          local haveTowers  = #(self.TowerStations or {})
          local haveWall    = #(self.WallRuns or {})
          if savedWall ~= "" and haveWall == 0 then
              return false, "a wall is saved for this pitch but none stands"
          end
          if wantTowers > 0 and haveTowers == 0 then
              return false, wantTowers .. " tower(s) saved for this pitch but none stands"
          end
          self:TortureInfo("defence_restore", string.format("towers=%d/%d wallRuns=%d gates=%d carts=%d",
              haveTowers, wantTowers, haveWall, #(self.Gates or {}), #(self.ArcherCarts or {})))
          return true
      end },

    -- Watch the world fight (or hold the peace). The ambush save aggros on its own;
    -- the bandit-camp save may stay quiet - both outcomes are valid, and both are
    -- judged: no bystander may die, no merc may ignore a fight for its whole span,
    -- and nobody gets attacked by our men unprovoked.
    { name = "engagement_watch", timeout = 150,
      run = function(self, S)
          S.firstClaimAt = nil
          S.maxClaims = 0
          S.startSquad = 0
          for _, e in pairs(self.ActiveMercs or {}) do
              if e and self:IsAliveAndWell(e, true) then S.startSquad = S.startSquad + 1 end
          end
          S.bystanderNames = {}
          pcall(function()
              local pp = player:GetWorldPos()
              local ents = System.GetPhysicalEntitiesInBoxByClass(pp, 120.0, "NPC")
              for _, e in pairs(ents or {}) do
                  local nm; pcall(function() nm = e:GetName() end)
                  if nm and not string.find(nm, "Spawned", 1, true)
                     and not string.find(nm, "Merc", 1, true)
                     and self:IsAliveAndWell(e, true) then
                      S.bystanderNames[nm] = true
                  end
              end
          end)
      end,
      check = function(self, S)
          local el = tClock() - S.stepFrom
          local claims = countTable(self.MercTargetOf)
          if claims > (S.maxClaims or 0) then S.maxClaims = claims end
          if claims > 0 and not S.firstClaimAt then
              S.firstClaimAt = el
              self:TortureInfo("engagement", string.format("first merc claim at +%.0fs (%d claim(s))", el, claims))
          end
          if el < 120 then return nil end
          -- Count only men who are provably dead or gone entirely: a walker who left
          -- the scan box is not a casualty (count-deltas failed a run on exactly that).
          local lost = 0
          for nm in pairs(S.bystanderNames or {}) do
              local gone = true
              pcall(function()
                  local e = System.GetEntityByName(nm)
                  if e and self:IsAliveAndWell(e, true) then gone = false end
              end)
              if gone then lost = lost + 1 end
          end
          local endSquad = 0
          for _, e in pairs(self.ActiveMercs or {}) do
              if e and self:IsAliveAndWell(e, true) then endSquad = endSquad + 1 end
          end
          local mercLoss = (S.startSquad or 0) - endSquad
          S.watchClaims, S.watchDeaths = S.maxClaims or 0, lost
          self:TortureInfo("engagement", string.format(
              "maxClaims=%d mercLosses=%d bystandersDeadOrGone=%d over 120s",
              S.maxClaims or 0, mercLoss, lost))
          -- On an aggro-armed scenario the non-mod NPCs ARE the declared enemy (a bandit
          -- camp): their deaths are combat results, not casualties. The first run here
          -- FAILED the squad for winning a fight the bandits started.
          if S.provoke then
              if mercLoss > 5 then
                  return false, mercLoss .. " merc(s) lost - the squad is being routed"
              end
              return true
          end
          -- Peaceful scenarios: claims stayed 0 and nobody died - the squad held the
          -- peace next to base-game NPCs, which is the non-aggression result we want.
          if lost > 1 then
              return false, lost .. " base-game NPC(s) died near our squad in 120s"
          end
          return true
      end },

    -- The staged wall battle, only where the save provides a fortified active camp.
    { name = "raid_test", timeout = 240,
      run = function(self, S)
          S.applicable = self.CampActive and #(self.WallRuns or {}) > 0
          if S.applicable then
              self:TortureInfo("raid_test", "fortified camp found - launching a raid at it")
              pcall(function() self:RaidLaunch() end)
          end
      end,
      check = function(self, S)
          if not S.applicable then
              self:TortureInfo("raid_test", "no fortified active camp - skipped")
              return true
          end
          -- Judged off the wall battle's OWN phase machine (idle -> staging -> battle ->
          -- idle), not entity scans: two instrument versions were blind to raiders that
          -- had spawned, fought and LOST while liveEnemies read zero - the camp beat 14
          -- Prague men inside 75s and the test called it "no raiders ever spawned".
          local el = tClock() - S.stepFrom
          local ph = self.WBPhase or "idle"
          if ph ~= "idle" and ph ~= S.lastPhase then
              S.lastPhase = ph
              S.sawBattle = true
              self:TortureInfo("raid_test", "wall battle phase '" .. ph .. "' at +" .. string.format("%.0f", el) .. "s")
          end
          if not S.sawBattle then
              if el > 75 then return false, "wall battle never left idle (gates shut? raid declined?)" end
              return nil
          end
          if ph ~= "idle" and el < 240 then return nil end
          if ph == "idle" then
              self:TortureInfo("raid_test", string.format("battle resolved at +%.0fs, raiders left near player=%d", el, liveEnemies(self)))
              return true
          end
          return false, "wall battle still in phase '" .. ph .. "' at timeout"
      end },

    -- ARMED ONLY BY F6 (the aggro probe), never by F7: send five mercs at the nearest
    -- non-mod NPC. On the bandit-camp save that is a kgru bandit and this is the
    -- merc-versus-vanilla combat test; on a civilian save it would be an atrocity,
    -- which is why the arming is a separate keybind rather than a heuristic.
    { name = "provoke_test", timeout = 150,
      run = function(self, S)
          if not S.provoke then return end
          -- Nearest non-mod NPC inside 80m becomes the called target.
          local best, bd, bestName
          pcall(function()
              local pp = player:GetWorldPos()
              local ents = System.GetPhysicalEntitiesInBoxByClass(pp, 80.0, "NPC")
              for _, e in pairs(ents or {}) do
                  local nm; pcall(function() nm = e:GetName() end)
                  if nm and not string.find(nm, "Spawned", 1, true)
                     and not string.find(nm, "Merc", 1, true)
                     and self:IsAliveAndWell(e, true) then
                      local q = e:GetWorldPos()
                      local d = (q.x - pp.x) ^ 2 + (q.y - pp.y) ^ 2
                      if not bd or d < bd then best, bd, bestName = e, d, nm end
                  end
              end
          end)
          if not best then return end
          S.targetName = bestName
          local tw; pcall(function() tw = XGenAIModule.GetMyWUID(best) end)
          if not tw then return end
          self:TortureInfo("provoke", "calling the squad onto '" .. tostring(bestName) .. "'")
          S.forcedKeys = {}
          local n = 0
          for _, ent in pairs(self.ActiveMercs or {}) do
              if n >= 5 then break end
              local ka, kb = self:CampMercKeys(ent)
              for _, k in ipairs({ ka, kb }) do
                  if k then
                      self.ForcedTargetOf[k] = tw
                      table.insert(S.forcedKeys, k)
                  end
              end
              n = n + 1
          end
      end,
      check = function(self, S)
          if not S.provoke then
              self:TortureInfo("provoke", "not armed (F7 probe) - skipped")
              return true
          end
          if not S.targetName then
              -- The squad may already have settled it: the bandits aggroed the fresh
              -- hires on their own and were dead before this step could arm.
              if (S.watchClaims or 0) > 0 or (S.watchDeaths or 0) > 0 then
                  self:TortureInfo("provoke", string.format(
                      "nothing left to call - the fight already happened (claims=%d, enemy dead=%d)",
                      S.watchClaims or 0, S.watchDeaths or 0))
                  return true
              end
              return false, "no vanilla NPC in range to call"
          end
          local el = tClock() - S.stepFrom
          local dead = true
          pcall(function()
              local e = System.GetEntityByName(S.targetName)
              if e and self:IsAliveAndWell(e, true) then dead = false end
          end)
          if not dead and el < 120 then return nil end
          -- Stand the squad down again whatever happened.
          for _, k in ipairs(S.forcedKeys or {}) do self.ForcedTargetOf[k] = nil end
          if dead then
              self:TortureInfo("provoke", string.format("'%s' down at +%.0fs", S.targetName, el))
              return true
          end
          return false, "target '" .. tostring(S.targetName) .. "' still standing after 120s of a called attack"
      end },

    -- Render-flip sampling on whatever the scene contains, borrowed whole from the
    -- bench: hidden flips = the AI-LOD hide path (the invisible-merc complaint).
    { name = "flip_watch", timeout = 80,
      run = function(self, S)
          self._benchSeen, self._benchWatch, self._benchWatchAt = {}, {}, 0
          S.fs = { measuring = true, flipsHidden = 0, flipsChar = 0, flipsVdr = 0 }
      end,
      check = function(self, S)
          local now = tClock()
          pcall(function()
              self:BenchRefreshWatch(now)
              for name, ent in pairs(self._benchWatch or {}) do
                  self:BenchSampleEnt(name, ent, now, S.fs)
              end
          end)
          if (now - S.stepFrom) < 60 then return nil end
          self:TortureInfo("flip_watch", string.format("60s flips: hidden=%d char=%d vdr=%d over %d tracked",
              S.fs.flipsHidden or 0, S.fs.flipsChar or 0, S.fs.flipsVdr or 0,
              countTable(self._benchWatch)))
          return true
      end },

    { name = "health_summary", timeout = 15,
      run = function(self, S) end,
      check = function(self, S)
          local stalls = countTable(self.FollowStallStreak)
          local poses  = countTable(self.CampPoseHoldFrom)
          local busy, why = self:PlayerBusyForSpawns()
          self:TortureInfo("health", string.format("stallStreaks=%d poseHolds=%d spawnGuard=%s(%s)",
              stalls, poses, tostring(busy), tostring(why)))
          if stalls > 3 then return false, stalls .. " concurrent stall streaks" end
          return true
      end },
}

function mercenaries:TortureStartProbe(autoquit, provoke)
    if self.TortureRunning then tLog("already running"); return end
    if not player then tLog("no player - not in game yet"); return end
    self.TortureRunning  = true
    self.TortureAutoQuit = (autoquit == true)
    self.TortureSlot     = 1 - (self.TortureSlot or 0)
    local anchor = nil
    pcall(function()
        local p = player:GetWorldPos()
        anchor = { x = p.x, y = p.y, z = p.z }
    end)
    self._tortureState = {
        idx = 1, plan = self.TortureProbePlan[1], planList = self.TortureProbePlan,
        stepFrom = tClock(), startedAt = tClock(), anchor = anchor, pass = 0, fail = 0,
        provoke = (provoke == true),
    }
    -- Organic raids off for the probe too (raid_test launches its own where applicable).
    self._tortureRaidWas = self.RaidEnabled
    self.RaidEnabled = false
    tLog("=== scenario probe: " .. #self.TortureProbePlan .. " step(s), autoquit=" .. tostring(self.TortureAutoQuit) .. " ===")
    tLog("step '" .. self.TortureProbePlan[1].name .. "'")
    pcall(self.TortureProbePlan[1].run, self, self._tortureState)
    Script.SetTimerForFunction(self.TortureTickMs, "mercenaries.TortureTick" .. self.TortureSlot)
end

-- ---------------------------------------------------------------------------
-- wiring
-- ---------------------------------------------------------------------------

function mercenaries:TortureBindKeys()
    pcall(function() System.ExecuteCommand("bind f8 merc_torture_auto") end)
    pcall(function() System.ExecuteCommand("bind f7 merc_torture_probe") end)
    pcall(function() System.ExecuteCommand("bind f6 merc_torture_probe_aggro") end)
end

do
    local function c(n, b, d)
        if mercenaries.CmdHelpText then mercenaries.CmdHelpText[n] = d end
        pcall(function() System.AddCCommand(n, b, d) end)
    end
    c("merc_torture",       "mercenaries:TortureStart(false)",      "Run the functional torture-test campaign (also F8)")
    c("merc_torture_auto",  "mercenaries:TortureStart(true)",       "Run the torture campaign and QUIT when done (harness mode)")
    c("merc_torture_probe", "mercenaries:TortureStartProbe(true)",  "Adaptive scenario probe: observe this save's world and QUIT (also F7)")
    c("merc_torture_probe_aggro", "mercenaries:TortureStartProbe(true, true)", "Scenario probe + call the squad onto the nearest vanilla NPC (bandit saves ONLY; also F6)")
end
