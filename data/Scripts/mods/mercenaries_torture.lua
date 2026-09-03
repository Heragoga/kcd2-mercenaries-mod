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
-- Read by mercenaries_main_quest_handler.lua's MonitorMainQuestLoop: while a `ground` step
-- is walking Henry by SetWorldPos, its ghost-movement and instant-teleport checks must not
-- read that as a fast travel and idle the squad. Set/cleared only by the plan machine.
mercenaries.TortureDrivesPlayer = false

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

-- Arm the safety NOW, before the first tick - not on it. A run where the trigger did not
-- take (the game's own bindings shadow the F-keys, so a tapped F8 can do nothing at all)
-- left Henry standing unprotected in the open and he was killed, because god mode was only
-- ever armed by a tick that never came. Arming it in the starter means the worst a dead
-- trigger can now cost is time.
function mercenaries:TortureArmSafety(S, hoist)
    S.godTried = true
    -- `god` is NOT a console command on this build ("[Warning] Unknown command: god" in
    -- every run's log) - the two lines below are kept only so an older build that has it
    -- still benefits. The real thing is GameRules.SetInvulnerability, a documented
    -- scriptbind (references/kcd2-mod-docs-main: "GameRules.SetInvulnerability(
    -- ScriptHandle playerId, bool invulnerable)"), found only after the second run in
    -- which Henry died. Its answer is logged so a build where it does nothing is visible.
    pcall(function() System.ExecuteCommand("god 1") end)
    pcall(function() System.ExecuteCommand("god") end)
    self:TortureInvulnerable(true)
    if not (hoist and S.anchor) then return end
    self:TortureHoist(S.anchor)
end

-- There is NO player invulnerability on this build. Run 3 proved it: `GameRules` exposes no
-- methods to Lua here, and the only SetInvulnerability in the whole Lua state belongs to
-- BreakableObject/DestroyableObject. What the player does have is the same Actor bind the
-- quest camps use to buff their leaders (SetMaxHealth/SetHealth/GetMaxHealth), so god mode
-- is arithmetic: max health raised to a number no fight can take off in the second between
-- two heals, and TortureKeepSafe refilling it every tick. The original maximum is kept and
-- put back by TortureFinish for a run that does not quit the game.
mercenaries.TortureGodHealth = 50000

function mercenaries:TortureInvulnerable(on)
    local a = player and player.actor
    if not a then tLog("invulnerability: player.actor is nil - Henry is MORTAL"); return end
    if on then
        pcall(function()
            if not self._tortureRealMaxHp then self._tortureRealMaxHp = a:GetMaxHealth() end
            a:SetMaxHealth(self.TortureGodHealth)
            a:SetHealth(self.TortureGodHealth)
        end)
    else
        pcall(function()
            local m = self._tortureRealMaxHp
            if m and m > 0 then a:SetMaxHealth(m); a:SetHealth(m) end
            self._tortureRealMaxHp = nil
        end)
    end
    local mx, hp = "?", "?"
    pcall(function() mx = tostring(a:GetMaxHealth()); hp = tostring(a:GetHealth()) end)
    tLog("invulnerability " .. (on and "ON" or "OFF") .. " -> maxHealth=" .. mx .. " health=" .. hp)
end

-- Hover ABOVE THE GROUND, not above the anchor's own z. The quest plan learned this the
-- hard way: patrol_company's cached site z is ~15 m below the road that is actually there,
-- so "anchor z + 16" put Henry two metres off the ground beside a knight, and he died.
-- TortureGroundZ reads the terrain (falling back to the camp's own downward ray).
function mercenaries:TortureHoist(a)
    if not a then return end
    pcall(function()
        local gz = self:TortureGroundZ(a.x, a.y, a.z) or a.z
        player:SetWorldPos({ x = a.x, y = a.y, z = gz + self.TortureHover })
    end)
    pcall(function() player:SetWorldAngles({ x = -1.22, y = 0, z = 0 }) end)
end

function mercenaries:TortureKeepSafe()
    local S = self._tortureState
    if not (S and S.anchor) then return end
    -- God is armed FIRST and unconditionally. It used to be armed after the hoist, which
    -- was fine while every step hovered; a `ground` step returns below without touching
    -- Henry at all, and the field plan's very first walking step must not run him across
    -- open country mortal.
    if not S.godTried then
        S.godTried = true
        pcall(function() System.ExecuteCommand("god 1") end)
        pcall(function() System.ExecuteCommand("god") end)
    end
    -- THERE IS NO GOD MODE ON THIS BUILD. The field run of 2026-09-02 logged
    -- "[Warning] Unknown command: god" for both attempts above - so every "god mode"
    -- this file ever claimed was a no-op, and the hover alone is what kept Henry alive
    -- (and the one time a plan failed to start he stood on the ground and died). The
    -- real protection is this: full health re-asserted every tick, through the same
    -- actor:SetHealth/GetMaxHealth pair the quest camps use on their leaders. It runs
    -- for hovering AND ground steps, before either returns below, and it is what lets
    -- the quest plan walk him up to a bandit for the disperse test.
    pcall(function()
        local a = player and player.actor
        if not a then return end
        local m = a:GetMaxHealth()
        -- A load or a scripted event can put the real maximum back; re-raise it so the
        -- refill below always has the whole 50k to fill (see TortureInvulnerable).
        if self._tortureRealMaxHp and m and m < (self.TortureGodHealth or 50000) then
            a:SetMaxHealth(self.TortureGodHealth)
            m = self.TortureGodHealth
        end
        -- Read BEFORE the refill, a few ticks in: the arm-time read-back showed
        -- maxHealth=50000 but health=100 in the same frame, so whether SetHealth actually
        -- takes on the player is unproven. This line answers it on the next run.
        S.healTicks = (S.healTicks or 0) + 1
        if S.healTicks == 5 or S.healTicks == 60 then
            tLog(string.format("health check at tick %d: health=%s max=%s (refilled every tick)",
                S.healTicks, tostring(a:GetHealth()), tostring(m)))
        end
        if m and m > 0 then a:SetHealth(m) end
    end)
    -- A `ground = true` step DRIVES Henry itself (TortureWalkTo / TortureWalkRoute): he has
    -- to be on his feet for the squad to have anything to follow, and the hoist would fight
    -- the walk metre for metre. Position and angles are left entirely to the step; only god
    -- mode is asserted, so no field test can kill him either.
    if S.plan and S.plan.ground then return end
    -- The save step lands Henry: the engine refuses to write a save while the player
    -- is airborne, and he hovers for the whole campaign - which is why Game.QuickSave
    -- never produced a file in five runs. God stays on either way.
    if S.groundForSave then
        pcall(function()
            local a = S.anchor
            player:SetWorldPos({ x = a.x, y = a.y, z = self:TortureGroundZ(a.x, a.y, a.z) or a.z })
        end)
        return
    end
    self:TortureHoist(S.anchor)
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

    -- S.deadline lets a plan set its own cap (the field plan runs far longer than the
    -- campaign); nil keeps the campaign's, so nothing about it changes.
    if now - S.startedAt > (S.deadline or self.TortureDeadline) then
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
    -- A third verdict, used only by the field plan's aggro-gated step: NOT APPLICABLE here.
    -- It must not read as a PASS (nothing was proved) and must not read as a FAIL (nothing
    -- was broken), so it gets its own line and its own counter.
    if verdict == "skip" then
        S.skip = (S.skip or 0) + 1
        tLog("SKIP " .. plan.name .. (detail and (" - " .. tostring(detail)) or ""))
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

    -- The quicksave step hands control to the harness rather than to a next step. The quest
    -- plan (mercenaries_torture_quest.lua) saves twice, in the middle of its own stage lists,
    -- so it marks those steps `awaitReload` instead of relying on the campaign's step name.
    if S.plan and (S.plan.name == "quicksave" or S.plan.awaitReload == true) then
        S.awaitReload, S.awaitFrom = true, tClock()
        tLog("SAVED - awaiting reload")
        return
    end

    S.idx = S.idx + 1
    local plan = (S.planList or self.TorturePlan)[S.idx]
    if not plan then return self:TortureFinish() end
    S.plan, S.stepFrom, S.actions = plan, tClock(), nil
    S.oneKey, S.oneEnt, S.sawBusy, S.restored, S.before = nil, nil, nil, nil, nil
    -- Per-step walk/sample state (the field plan's). Cleared here rather than in each step's
    -- run, so a step can never inherit the previous one's distance samples or walk cursor.
    S.walkFrom, S.samples, S.farStreak, S.maxFarStreak, S.maxFarName = nil, nil, nil, 0, nil
    S.maxEver, S.maxEverName, S.posAt, S.shapeIdx, S.shapeAt, S.shapeKey = 0, nil, nil, nil, nil, nil
    -- The provoke and leave-the-area bookkeeping. Cleared BEFORE run, which is where the
    -- probe's provoke_test fills targetName/forcedKeys in, so that step is unaffected.
    -- S.fieldStart deliberately survives every step: it is the save's start position, and
    -- fight_base_enemies has to be able to get back to it after a kilometre of walking.
    S.provoked, S.provokeAt, S.homeAt, S.targetName, S.forcedKeys = nil, nil, nil, nil, nil
    S.preJump, S.preJumpN, S.newGangKey, S.newGangAt, S.awayLogged = nil, nil, nil, nil, nil
    S.killedAt, S.lootOpenedAt, S.lootIdleFrom = nil, nil, nil
    -- One flag, one place: a `ground` step drives Henry, so the fast-travel detector must
    -- stand down for exactly its duration (see mercenaries_main_quest_handler.lua).
    self.TortureDrivesPlayer = (plan.ground == true)
    tLog("step '" .. plan.name .. "'")
    local ok, err = pcall(plan.run, self, S)
    if not ok then tLog("run error in '" .. plan.name .. "': " .. tostring(err)) end
end

function mercenaries:TortureFinish()
    local S = self._tortureState
    self.TortureRunning = false
    -- Hand the player back to the game: nothing beyond a running plan may keep the
    -- fast-travel detector switched off - nor keep him immortal.
    self.TortureDrivesPlayer = false
    pcall(function() self:TortureInvulnerable(false) end)
    if self._tortureRaidWas ~= nil then
        self.RaidEnabled, self._tortureRaidWas = self._tortureRaidWas, nil
    end
    if self._torturePatrolWas ~= nil then
        self.LivePatrolsEnabled, self._torturePatrolWas = self._torturePatrolWas, nil
    end
    tLog(string.format("=========== %d passed, %d failed ===========",
        (S and S.pass) or 0, (S and S.fail) or 0))
    -- Only printed when there is something to print, so the campaign's summary is
    -- byte-for-byte what it always was.
    if S and (S.skip or 0) > 0 then
        tLog(string.format("=========== %d skipped (not applicable to this save) ===========", S.skip))
    end
    tLog("COMPLETE")
    if self.TortureAutoQuit then
        tLog("auto-quit")
        pcall(function() System.ExecuteCommand("quit") end)
    end
end

function mercenaries:TortureStart(autoquit)
    if self.TortureRunning then tLog("already running"); return end
    if not player then tLog("no player - not in game yet"); return end
    -- A stamped save means this is the harness's SECOND merc_torture_auto, after its
    -- relaunch: run the persistence checks instead of a fresh campaign. It only ever happens
    -- because somebody asked for it - a player loading a stamped save is never hijacked.
    local stage = self:LoadString("TortureStage")
    if stage == "B" then
        self:SaveString("TortureStage", "done")
        tLog("=== phase B: verifying the reloaded world (merc_torture_auto on a stamped save) ===")
        pcall(function() System.ExecuteCommand("god 1") end)
        Script.SetTimerForFunction(12000, "mercenaries.TorturePhaseB")
        return
    end
    -- ...and a "Q..." stamp belongs to the QUEST plan (mercenaries_torture_quest.lua), which
    -- runs across three sessions of its own. Hand straight over rather than starting a fresh
    -- camp campaign on top of a live Kleinkrieg contract. Same doctrine as phase B: this only
    -- ever happens because somebody typed merc_torture_auto on a stamped save.
    if stage and string.sub(tostring(stage), 1, 1) == "Q" and self.TortureQuestStages
       and self.TortureQuestStages[stage] then
        return self:TortureStartQuest(autoquit)
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
    -- God and the hoist immediately, so Henry is safe from this instant rather than from the
    -- first tick - see TortureArmSafety.
    self:TortureArmSafety(self._tortureState, true)
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
    self:TortureArmSafety(self._tortureState, true)
    -- Organic raids off for the probe too (raid_test launches its own where applicable).
    self._tortureRaidWas = self.RaidEnabled
    self.RaidEnabled = false
    tLog("=== scenario probe: " .. #self.TortureProbePlan .. " step(s), autoquit=" .. tostring(self.TortureAutoQuit) .. " ===")
    tLog("step '" .. self.TortureProbePlan[1].name .. "'")
    pcall(self.TortureProbePlan[1].run, self, self._tortureState)
    Script.SetTimerForFunction(self.TortureTickMs, "mercenaries.TortureTick" .. self.TortureSlot)
end

-- ---------------------------------------------------------------------------
-- THE FIELD PLAN (merc_torture_field / merc_torture_field_auto, plus the aggro pair).
--
-- The campaign tests the CAMP with Henry pinned 16m above it. This one tests everything
-- that only exists while he is WALKING: follow at three squad sizes and three formation
-- shapes, a fight in the open and the loot-and-reform cycle after it, a camp raised and
-- struck in the field, patrol pressure on a real recorded road, and a raid. One session,
-- no save, no reload - so nothing here depends on the save/relaunch machinery.
--
-- Every step carries `ground = true`: Henry stays on his feet, in god mode, for the whole
-- run, and is moved TortureWalkStep metres per tick along a patrol route. That is the whole
-- point - a squad following a hovering player is not a follow test - and it is also why
-- TortureDrivesPlayer exists, because the mod's own fast-travel detector reads a
-- SetWorldPos walk as a teleport and would idle the squad for the entire run.
--
-- Timeouts are sized for a ~15fps notebook: nothing below is judged on frames, every
-- window is real seconds, and every limit is two to three times what the same thing takes
-- on a healthy machine.
-- ---------------------------------------------------------------------------

mercenaries.TortureWalkStep       = 1.5    -- metres per 1s tick - a walk, not a sprint
mercenaries.TortureWalkSettleSecs = 25.0   -- after a hire or a jump, before a walk is judged
mercenaries.TortureFollowNear     = 35.0   -- every man must be this close when a walk ends
mercenaries.TortureFollowMean     = 20.0   -- ...and the mean over the last 30s this close
mercenaries.TortureFollowFar      = 80.0   -- a man beyond this is "left behind"...
mercenaries.TortureFollowFarSecs  = 15.0   -- ...and may not stay there longer than this
mercenaries.TortureMeanWindow     = 30.0
mercenaries.TortureLogEvery       = 5.0    -- seconds between POS traces while walking/fighting
-- Deliberately just under the harness's own 1500s wait for "[Torture] COMPLETE": if the
-- plan is going to run out of time, it must be the one that says so - a plan killed by the
-- harness reports nothing at all, and a truncated report is worth more than no report.
mercenaries.TortureFieldDeadline  = 1620   -- happy path ~1300-1400s at 15fps once the loot window was added

-- Ground height under (x,y). System.GetTerrainElevation is the engine's cheap answer and is
-- pcalled because it is the one call in this file with no prior use anywhere in the mod; the
-- camp's own downward ray (CampSnapToGround, behind every prop placement in the game) is the
-- proven fallback, and the walker's previous z is the last resort. A walk that steps a metre
-- wrong is still a walk; a walk that drops Henry through the world is not.
function mercenaries:TortureGroundZ(x, y, prevZ)
    local z
    pcall(function() z = System.GetTerrainElevation(x, y) end)
    if type(z) == "number" and z > 0 then return z + 0.05 end
    local snap
    pcall(function() snap = self:CampSnapToGround({ x = x, y = y, z = prevZ }) end)
    if snap and type(snap.z) == "number" then return snap.z + 0.05 end
    return prevZ
end

-- One tick of walking: TortureWalkStep metres towards `target`, z snapped to the ground.
-- Returns true once he is standing on it.
function mercenaries:TortureWalkTo(S, target)
    if not target then return true end
    local pp
    pcall(function() pp = player:GetWorldPos() end)
    if not pp then return false end
    local step = self.TortureWalkStep or 1.5
    local dx, dy = target.x - pp.x, target.y - pp.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d <= step then
        pcall(function()
            player:SetWorldPos({ x = target.x, y = target.y,
                                 z = self:TortureGroundZ(target.x, target.y, pp.z) })
        end)
        return true
    end
    local nx, ny = pp.x + dx * (step / d), pp.y + dy * (step / d)
    pcall(function()
        player:SetWorldPos({ x = nx, y = ny, z = self:TortureGroundZ(nx, ny, pp.z) })
    end)
    -- Deliberately NO SetWorldAngles here. The formation hangs off the elected LEADER's
    -- heading, not the player's, so his facing buys the test nothing - and the yaw
    -- convention is unverified in this codebase (the hover step only ever sets pitch), so
    -- a guess could aim him at the sky and make the trace unreadable.
    return false
end

-- Follow a polyline the same way, one point at a time. `fromIdx`/`toIdx` bound the stretch;
-- the cursor lives on S (and is deliberately NOT reset between steps, so follow_5,
-- follow_12_shapes and follow_24 keep going down the SAME road instead of restarting).
function mercenaries:TortureWalkRoute(S, pts, fromIdx, toIdx)
    if not (pts and #pts > 0) then return true end
    if not S.walkIdx then S.walkIdx = math.max(1, fromIdx or 1) end
    local last = math.min(toIdx or #pts, #pts)
    if S.walkIdx > last then return true end
    if self:TortureWalkTo(S, pts[S.walkIdx]) then
        S.walkIdx = S.walkIdx + 1
    end
    return S.walkIdx > last
end

-- Mean of the per-tick means inside the last `window` seconds. The end-of-walk distance on
-- its own is a snapshot and a squad can be lucky in it; the tail mean is what says they kept
-- up all the way.
local function tailMean(S, window)
    local now = tClock()
    local n, sum = 0, 0
    for _, s in ipairs(S.samples or {}) do
        if (now - s.t) <= window then n, sum = n + 1, sum + s.mean end
    end
    if n == 0 then return nil end
    return sum / n
end

-- Is a POS trace due? Rate-limited because 50 mercs at 1Hz for twenty minutes is tens of
-- thousands of lines and kcd.log rotates.
local function posDue(S, every)
    local now = tClock()
    every = every or mercenaries.TortureLogEvery or 5.0
    if S.posAt and (now - S.posAt) < every then return false end
    S.posAt = now
    return true
end

-- The route set for the level we are actually on, and the route whose FIRST point is
-- nearest Henry. Resolved at RUNTIME because the plan has to work on either map and on
-- whatever save it is pointed at: PatrolRoutesForLevel is the mod's own answer to "which
-- recorded road network is this", so the test asks it rather than guessing from coordinates.
function mercenaries:TorturePickRoute(S)
    local ok = false
    pcall(function() ok = self:PatrolRoutesForLevel() end)
    local data = self.PatrolRouteData
    if not (ok and data and #data > 0) then
        S.routePts, S.routeIdx, S.routeFrom = nil, nil, nil
        self:TortureInfo("route", "no recorded routes on this level - the follow steps will stand still")
        return false
    end
    local pp
    pcall(function() pp = player:GetWorldPos() end)
    if not pp then return false end
    local best, bestD, bestI
    for i, r in ipairs(data) do
        local p = r.pts and r.pts[1]
        if p then
            local d = math.sqrt((p.x - pp.x) ^ 2 + (p.y - pp.y) ^ 2)
            if not bestD or d < bestD then best, bestD, bestI = r, d, i end
        end
    end
    if not best then return false end
    S.routePts, S.routeIdx, S.routeFrom, S.walkIdx = best.pts, bestI, 1, 1
    self:TortureInfo("route", string.format(
        "route %d of %d, %d point(s), %.0fm of road; its start is %.0fm off - one jump there",
        bestI, #data, #best.pts, best.len or -1, bestD or -1))
    -- The ONE teleport in the whole plan; everything after it is walked. The fast-travel
    -- detector is already standing down for this step, so it does not idle the squad.
    local p = best.pts[1]
    pcall(function()
        player:SetWorldPos({ x = p.x, y = p.y, z = self:TortureGroundZ(p.x, p.y, p.z) })
    end)
    return true
end

-- The index that sits roughly `metres` along a route from its start.
local function indexAlong(pts, metres)
    local run = 0
    for i = 2, #(pts or {}) do
        local a, b = pts[i - 1], pts[i]
        run = run + math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
        if run >= metres then return i end
    end
    return math.max(1, #(pts or {}))
end

-- A point on the recorded road network at least `minDist` from Henry, else the farthest one
-- there is. Recorded routes are ground the author actually rode, so a point on one is always
-- somewhere he can stand - which a bearing-and-distance jump is not (those land in lakes,
-- on cliffs and off the map).
function mercenaries:TortureFarRoutePoint(minDist)
    local pp
    pcall(function() pp = player:GetWorldPos() end)
    if not pp then return nil end
    local best, bestD
    for _, r in ipairs(self.PatrolRouteData or {}) do
        for _, p in ipairs(r.pts or {}) do
            local d = math.sqrt((p.x - pp.x) ^ 2 + (p.y - pp.y) ^ 2)
            if d >= (minDist or 700) then return p, d end
            if not bestD or d > bestD then best, bestD = p, d end
        end
    end
    return best, bestD
end

-- Hire or pay off until exactly `want` men stand. Paying off removes the surplus entities
-- directly rather than going through SetState('dismiss'): dismiss flips MercenariesDismissed,
-- schedules a 15s despawn and leaves the men counting against MaxCompanions in the meantime,
-- so a dismiss-then-hire inside one step is either refused outright or hires on top of the
-- old company. RemoveEntity plus a roster wipe is the same teardown PruneMercCache performs
-- for a merc who dies, run one step early.
function mercenaries:TortureSetSquad(S, want)
    local have = squadCount(self)
    if have < want then
        self:TortureInfo("squad", "hiring " .. (want - have) .. " to reach " .. want)
        self:Hire(0, want - have, "medium")
        return
    end
    if have == want then
        self:TortureInfo("squad", "squad already at " .. have)
        return
    end
    local drop, removed = have - want, 0
    for name, ent in pairs(self.ActiveMercs or {}) do
        if removed >= drop then break end
        local alive = false
        pcall(function() alive = self:IsAliveAndWell(ent, true) end)
        if alive then
            local id = ent.id
            pcall(function() self:MercDropClaim(ent.this and ent.this.id or ent.id) end)
            self.ActiveMercs[name] = nil
            pcall(function() System.RemoveEntity(id) end)
            removed = removed + 1
        end
    end
    pcall(function() self:Recount() end)
    self:TortureInfo("squad", "paid off " .. removed .. " to come down to " .. want
        .. " (now " .. squadCount(self) .. ")")
end

-- One tick's distance sample: mean and max merc-to-Henry, plus the per-man "left behind"
-- streak. The tick is 1Hz real time (Script.SetTimerForFunction, not frames), so a streak
-- counted in ticks IS the streak in seconds even at 15fps.
function mercenaries:TortureWalkSample(S)
    local pp
    pcall(function() pp = player:GetWorldPos() end)
    if not pp then return end
    S.farStreak = S.farStreak or {}
    local n, sum, mx, worst = 0, 0, 0, nil
    for name, ent in pairs(self.ActiveMercs or {}) do
        local alive = false
        pcall(function() alive = self:IsAliveAndWell(ent, true) end)
        if alive then
            local q
            pcall(function() q = ent:GetWorldPos() end)
            if q then
                local d = math.sqrt((q.x - pp.x) ^ 2 + (q.y - pp.y) ^ 2)
                n, sum = n + 1, sum + d
                if d > mx then mx, worst = d, name end
                if d > (self.TortureFollowFar or 80.0) then
                    local st = (S.farStreak[name] or 0) + 1
                    S.farStreak[name] = st
                    if st > (S.maxFarStreak or 0) then S.maxFarStreak, S.maxFarName = st, name end
                else
                    S.farStreak[name] = 0
                end
            end
        end
    end
    if n == 0 then return end
    S.samples = S.samples or {}
    table.insert(S.samples, { t = tClock(), mean = sum / n })
    if mx > (S.maxEver or 0) then S.maxEver, S.maxEverName = mx, worst end
    S.lastN, S.lastMean, S.lastMax, S.lastWorst = n, sum / n, mx, worst
end

-- The three-part verdict a walk gets: everybody close at the END, the tail MEAN inside the
-- limit, and nobody stranded beyond TortureFollowFar for longer than TortureFollowFarSecs.
-- `scale` widens all of it for the big squads, which are legitimately more strung out.
function mercenaries:TortureFollowVerdict(S, tag, scale)
    scale = scale or 1.0
    local near    = (self.TortureFollowNear or 35.0) * scale
    local meanLim = (self.TortureFollowMean or 20.0) * scale
    local window  = self.TortureMeanWindow or 30.0
    local mean30  = tailMean(S, window)
    self:TortureInfo(tag, string.format(
        "squad=%d meanNow=%.1fm mean%.0fs=%s maxNow=%.1fm maxEver=%.1fm(%s) longestBeyond%.0fm=%ds stallStreaks=%d",
        S.lastN or 0, S.lastMean or -1, window,
        mean30 and string.format("%.1fm", mean30) or "n/a",
        S.lastMax or -1, S.maxEver or -1, tostring(S.maxEverName or "-"),
        self.TortureFollowFar or 80.0, S.maxFarStreak or 0,
        countTable(self.FollowStallStreak)))
    if (S.lastN or 0) == 0 then return false, "no living merc left to measure" end
    if (S.lastMax or 0) > near then
        return false, string.format("%s ended the walk %.0fm from Henry (limit %.0fm)",
            tostring(S.lastWorst or "?"), S.lastMax or -1, near)
    end
    if mean30 and mean30 > meanLim then
        return false, string.format("mean distance over the last %.0fs was %.1fm (limit %.0fm)",
            window, mean30, meanLim)
    end
    if (S.maxFarStreak or 0) > (self.TortureFollowFarSecs or 15.0) then
        return false, string.format("%s stayed more than %.0fm behind for %ds (limit %.0fs)",
            tostring(S.maxFarName or "?"), self.TortureFollowFar or 80.0,
            S.maxFarStreak or 0, self.TortureFollowFarSecs or 15.0)
    end
    return true
end

-- The verbose position trace: one line for Henry, one per merc. This is what turns "the
-- follow test failed" into "this man peeled off at t=140 and never came back".
function mercenaries:TorturePosLog(S, tag)
    local pp
    pcall(function() pp = player:GetWorldPos() end)
    if not pp then return end
    tLog(string.format("POS %s t=%.0f player=(%.1f,%.1f,%.1f)",
        tostring(tag), tClock() - (S.startedAt or tClock()), pp.x, pp.y, pp.z))
    for name, ent in pairs(self.ActiveMercs or {}) do
        local q
        pcall(function() q = ent:GetWorldPos() end)
        if q then
            local alive = false
            pcall(function() alive = self:IsAliveAndWell(ent, true) end)
            local ka = self:CampMercKeys(ent)
            local tgt = ka and (self.MercTargetOf or {})[ka] or nil
            tLog(string.format("  %s (%.1f,%.1f,%.1f) d=%.1fm alive=%s target=%s",
                tostring(name), q.x, q.y, q.z,
                math.sqrt((q.x - pp.x) ^ 2 + (q.y - pp.y) ^ 2),
                tostring(alive), tostring(tgt or "-")))
        end
    end
end

-- ...and the other half of a fight trace: how many mod enemies are still up, and how far
-- off. Capped at sixteen names per line so a raid does not bury the log.
function mercenaries:TortureEnemyLog(S, tag)
    local pp
    pcall(function() pp = player:GetWorldPos() end)
    if not pp then return end
    local n, parts = 0, {}
    pcall(function()
        local ents = System.GetPhysicalEntitiesInBoxByClass(pp, 150.0, "NPC")
        for _, e in pairs(ents or {}) do
            local nm
            pcall(function() nm = e:GetName() end)
            if nm and self:IsModEnemyName(nm) and self:IsAliveAndWell(e, true) then
                n = n + 1
                if #parts < 16 then
                    local q
                    pcall(function() q = e:GetWorldPos() end)
                    if q then
                        table.insert(parts, string.format("%s d=%.0fm", nm,
                            math.sqrt((q.x - pp.x) ^ 2 + (q.y - pp.y) ^ 2)))
                    end
                end
            end
        end
    end)
    tLog(string.format("POS %s enemies=%d  %s", tostring(tag), n, table.concat(parts, ", ")))
end

-- Camp props standing within `radius` of Henry, counted by the same name prefixes the camp
-- teardown sweeps (CampPropPrefixes). By spatial query and NAME, never by one id list: each
-- upgrade tracks its props in its own table, so no single list is complete - which is why
-- the tower placement code counts them this way too.
-- Second return says whether the QUERY itself ran: a build without GetEntitiesInSphere must
-- not turn "cannot see the props" into "there are no props", which would hang camp_cycle on
-- a timeout and fail camp_break for free. The callers fall back to CampEntities there.
function mercenaries:TortureCampProps(radius)
    local n, queried = 0, false
    pcall(function()
        local pp = player:GetWorldPos()
        local ents = System.GetEntitiesInSphere(pp, radius or 40.0)
        queried = true
        for _, e in pairs(ents or {}) do
            local nm
            pcall(function() nm = e:GetName() end)
            if nm then
                for _, p in ipairs(self.CampPropPrefixes or {}) do
                    if string.sub(nm, 1, #p) == p then n = n + 1 break end
                end
            end
        end
    end)
    return n, queried
end

-- The deployed men, and how far the furthest of them is from Henry.
local function outPartyFar(self)
    local pp
    pcall(function() pp = player:GetWorldPos() end)
    if not pp then return 0, 0, nil end
    local n, mx, worst = 0, 0, nil
    for name, ent in pairs(self.ActiveMercs or {}) do
        local ka = self:CampMercKeys(ent)
        local alive = false
        pcall(function() alive = self:IsAliveAndWell(ent, true) end)
        if ka and alive and self:IsCampOut(ka) then
            local q
            pcall(function() q = ent:GetWorldPos() end)
            if q then
                n = n + 1
                local d = math.sqrt((q.x - pp.x) ^ 2 + (q.y - pp.y) ^ 2)
                if d > mx then mx, worst = d, name end
            end
        end
    end
    return n, mx, worst
end

-- The nearest LIVING patrolman to Henry, or nil when no gang is out. Read on the tick a
-- gang's count RISES, which is the only moment the spawn floor can honestly be judged -
-- a second later they are walking towards him and any distance is legitimate.
function mercenaries:TorturePatrolNearest()
    local pp
    pcall(function() pp = player:GetWorldPos() end)
    if not pp then return nil end
    local best
    for _, rec in pairs(self.LivePatrols or {}) do
        if rec.spawned then
            for _, e in ipairs(rec.men or {}) do
                local alive = false
                pcall(function() alive = self:IsAliveAndWell(e, true) end)
                if alive then
                    local q
                    pcall(function() q = e:GetWorldPos() end)
                    if q then
                        local d = math.sqrt((q.x - pp.x) ^ 2 + (q.y - pp.y) ^ 2)
                        if not best or d < best then best = d end
                    end
                end
            end
        end
    end
    return best
end

-- The body every straight walking step shares: settle, walk for `secs` while sampling and
-- tracing, then judge. Returns exactly what a step's `check` must return.
function mercenaries:TortureFieldWalk(S, tag, secs, scale, settle)
    local now = tClock()
    if not S.walkFrom then
        if (now - S.stepFrom) < (settle or self.TortureWalkSettleSecs or 25.0) then return nil end
        S.walkFrom = now
        S.samples, S.farStreak, S.maxFarStreak, S.maxEver, S.maxEverName = nil, nil, 0, 0, nil
        self:TortureInfo(tag, string.format("walk starts: squad=%d shape=%s route=%s point=%s",
            squadCount(self), tostring(self.FormationShape),
            tostring(S.routeIdx or "-"), tostring(S.walkIdx or "-")))
    end
    if (now - S.walkFrom) < secs then
        if S.routePts then self:TortureWalkRoute(S, S.routePts, S.routeFrom, nil) end
        self:TortureWalkSample(S)
        if posDue(S) then self:TorturePosLog(S, tag) end
        return nil
    end
    return self:TortureFollowVerdict(S, tag, scale)
end

-- Find the nearest base-game NPC inside `radius`, log the nearest five WITH DISTANCES so a
-- miss is diagnosable ("nobody in range" told the first live run nothing about why), and call
-- five mercs onto the closest. Sets S.targetName / S.forcedKeys, or leaves them nil.
--
-- SAME DANGER AS THE PROBE'S provoke_test: "base-game NPC" means anyone who is not ours, so
-- on a save with civilians nearby this attacks a civilian. Only ever reached under S.aggro.
function mercenaries:TortureProvokeNearest(S, radius)
    radius = radius or 120.0
    local found = {}
    pcall(function()
        local pp = player:GetWorldPos()
        local ents = System.GetPhysicalEntitiesInBoxByClass(pp, radius, "NPC")
        for _, e in pairs(ents or {}) do
            local nm
            pcall(function() nm = e:GetName() end)
            if nm and not string.find(nm, "Spawned", 1, true)
               and not string.find(nm, "Merc", 1, true)
               and self:IsAliveAndWell(e, true) then
                local q
                pcall(function() q = e:GetWorldPos() end)
                if q then
                    table.insert(found, { ent = e, name = nm,
                        d = math.sqrt((q.x - pp.x) ^ 2 + (q.y - pp.y) ^ 2) })
                end
            end
        end
    end)
    table.sort(found, function(a, b) return a.d < b.d end)
    local shown = {}
    for i = 1, math.min(5, #found) do
        table.insert(shown, string.format("%s %.0fm", found[i].name, found[i].d))
    end
    self:TortureInfo("fight_base", string.format("%d base-game NPC(s) within %.0fm; nearest: %s",
        #found, radius, (#shown > 0) and table.concat(shown, ", ") or "none"))
    local best = found[1]
    if not best then return end
    local tw
    pcall(function() tw = XGenAIModule.GetMyWUID(best.ent) end)
    if not tw then
        self:TortureInfo("fight_base", "'" .. tostring(best.name) .. "' has no WUID - nobody can be called onto him")
        return
    end
    S.targetName = best.name
    self:TortureInfo("fight_base", string.format("calling five mercs onto '%s' at %.0fm", best.name, best.d))
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
end

mercenaries.TortureFieldPlan = {

    { name = "field_sanity", timeout = 45, ground = true,
      run = function(self, S)
          S.startSquad = squadCount(self)
          -- Where the SAVE put Henry, kept for the whole run. The follow walks carry him
          -- most of a kilometre down a patrol route, and the purpose-built saves put their
          -- interesting furniture - the vanilla bandit camp on save492 - beside the start.
          -- The first live run failed fight_base_enemies with "no base-game NPC within 80m"
          -- purely because it was measured from the far end of route 21.
          pcall(function()
              local p = player:GetWorldPos()
              S.fieldStart = { x = p.x, y = p.y, z = p.z }
          end)
          self:TortureInfo("field_sanity", "squad at start = " .. S.startSquad
              .. ", campActive = " .. tostring(self.CampActive)
              .. ", aggro armed = " .. tostring(S.aggro == true)
              .. ", start pos = " .. (S.fieldStart
                    and string.format("(%.1f,%.1f,%.1f)", S.fieldStart.x, S.fieldStart.y, S.fieldStart.z)
                    or "unknown"))
          -- Normalise WITHOUT paying anybody off: a standing camp turns every new hire into
          -- a camp resident rather than a follower (by design) and would invalidate every
          -- measurement below. SetState('follow') additionally lifts a hold or escort order
          -- the save may be carrying - a squad that was told to wait cannot fail a follow
          -- test honestly.
          if self.CampActive then self:BreakMercCamp(true) end
          S.actions = {
              function() self:SetState("follow") end,
              function() self:SetFormationShape((self.FormationShapeOrder or {})[1] or "column", true) end,
          }
      end,
      check = function(self, S)
          if S.actions and #S.actions > 0 then return nil end
          if self.CampActive then return nil end
          local fid
          pcall(function() fid = System.GetFrameID() end)
          if not fid then return nil end
          if _G.MercenariesDismissed then
              self:TortureInfo("field_sanity", "this save has the company dismissed - the hire steps re-raise it")
          end
          return true
      end },

    { name = "follow_5", timeout = 200, ground = true,
      run = function(self, S)
          -- Route FIRST, hires second: the men muster on the player, so jumping to the road
          -- after hiring would leave five fresh mercs half a kilometre behind the start.
          S.actions = {
              function() self:TorturePickRoute(S) end,
              function() end,
              function() self:TortureSetSquad(S, 5) end,
              function() self:SetFormationShape((self.FormationShapeOrder or {})[1] or "column", true) end,
          }
      end,
      check = function(self, S)
          if S.actions and #S.actions > 0 then return nil end
          return self:TortureFieldWalk(S, "follow_5", 90, 1.0)
      end },

    { name = "follow_12_shapes", timeout = 400, ground = true,
      run = function(self, S)
          -- Shape keys are READ from the formation module, never spelled out here: the
          -- catalogue has been regenerated more than once, and a name that no longer exists
          -- resolves to a null handle and silently drops the squad onto the follow chain -
          -- which looks like a column and would quietly pass this test.
          S.shapes = {}
          for i = 1, 3 do
              local k = (self.FormationShapeOrder or {})[i]
              if k then table.insert(S.shapes, k) end
          end
          S.actions = { function() self:TortureSetSquad(S, 12) end }
      end,
      check = function(self, S)
          if S.actions and #S.actions > 0 then return nil end
          if #(S.shapes or {}) == 0 then return false, "the formation module lists no shapes to test" end
          local now = tClock()
          S.shapeIdx = S.shapeIdx or 0
          if not S.walkFrom then
              if not S.shapeAt then
                  S.shapeIdx = S.shapeIdx + 1
                  S.shapeKey = S.shapes[S.shapeIdx]
                  if not S.shapeKey then
                      if S.shapeFail then return false, S.shapeFail end
                      return true
                  end
                  S.shapeAt = now
                  pcall(function() self:SetFormationShape(S.shapeKey, true) end)
                  self:TortureInfo("follow_12_shapes", "shape '" .. tostring(S.shapeKey) .. "' set - letting it rebuild")
                  return nil
              end
              -- The first shape also waits out the fresh hires; the later two only have to
              -- wait for a formation rebuild, which is one epoch bump plus the re-join.
              local settle = (S.shapeIdx == 1) and (self.TortureWalkSettleSecs or 25.0) or 15.0
              if (now - S.shapeAt) < settle then return nil end
              S.walkFrom = now
              S.samples, S.farStreak, S.maxFarStreak, S.maxEver, S.maxEverName = nil, nil, 0, 0, nil
              self:TortureInfo("follow_12_shapes", string.format(
                  "walk starts in '%s': squad=%d preset=%s", tostring(S.shapeKey),
                  squadCount(self), tostring(self.FormationName)))
              return nil
          end
          local tag = "follow_12_" .. tostring(S.shapeKey)
          if (now - S.walkFrom) < 60 then
              if S.routePts then self:TortureWalkRoute(S, S.routePts, S.routeFrom, nil) end
              self:TortureWalkSample(S)
              if posDue(S) then self:TorturePosLog(S, tag) end
              return nil
          end
          local ok, why = self:TortureFollowVerdict(S, tag, 1.0)
          -- The FIRST shape that fails is the reason the step fails; the rest still walk, so
          -- one bad shape does not hide the others' measurements.
          if ok ~= true and not S.shapeFail then
              S.shapeFail = "shape '" .. tostring(S.shapeKey) .. "': " .. tostring(why)
          end
          S.walkFrom, S.shapeAt = nil, nil
          return nil
      end },

    { name = "follow_24", timeout = 260, ground = true,
      run = function(self, S)
          S.actions = {
              function() self:TortureSetSquad(S, 24) end,
              function() self:SetFormationShape((self.FormationShapeOrder or {})[1] or "column", true) end,
          }
      end,
      check = function(self, S)
          if S.actions and #S.actions > 0 then return nil end
          -- x1.5 on both distance limits: twenty-four men in a column are legitimately
          -- strung out further than five. The test is "the tail keeps up", not "the
          -- formation is small".
          return self:TortureFieldWalk(S, "follow_24", 90, 1.5, 30.0)
      end },

    -- Two halves, and the second one is why the timeout is not 240: the FIGHT is still judged
    -- on "all eight down inside 240s", but the loot sweep can only be observed AFTER the last
    -- kill, so the step then watches for up to a further 45s before it hands over.
    { name = "fight_mod_enemies_field", timeout = 320, ground = true,
      run = function(self, S)
          if self.CampActive then self:BreakMercCamp(true) end
          S.sawClaim, S.lootMax = false, 0
          S.killedAt, S.lootOpenedAt, S.lootIdleFrom = nil, nil, nil
          S.actions = {
              function() self:SetState("follow") end,
              function() end,
              function() self:SpawnEnemyGroup("bandit", 8) end,
          }
      end,
      check = function(self, S)
          if S.actions and #S.actions > 0 then return nil end
          local now = tClock()
          if countTable(self.MercTargetOf) > 0 then S.sawClaim = true end
          if posDue(S) then
              self:TorturePosLog(S, "fight_mod")
              self:TortureEnemyLog(S, "fight_mod")
          end

          -- ---- the fight. Criteria unchanged: all eight down inside 240s, and at least one
          -- merc must have claimed a target somewhere along the way.
          if not S.killedAt then
              if (now - S.stepFrom) < 20 then return nil end
              local left = liveEnemies(self)
              if left > 0 then
                  if (now - S.stepFrom) > 240 then
                      return false, left .. " of the 8 bandits still standing after 240s"
                  end
                  return nil
              end
              S.killedAt = now
              self:TortureInfo("fight_mod", string.format(
                  "8 bandits down at +%.0fs - now watching for the loot sweep",
                  now - S.stepFrom))
              return nil
          end

          -- ---- the loot half. "follow -> fight -> loot -> back into formation" is the
          -- behaviour under test, so whether they went to loot at all is a RESULT.
          --
          -- The first live run reported "loot sweep opened=false, most men on loot duty at
          -- once=0" and called LootSweepStop on the SAME tick it declared the fight over -
          -- a reading that could never have been anything else. LootSweepBody only builds
          -- LootBattle on the tick the mod's OWN enemy cache (CachedEnemies) empties, which
          -- trails the last death, and it then holds every man off until
          -- LootBattle.opensAt = that moment + LootSettleDelay (5s, "weapons go away first").
          -- So the window has to be WATCHED after the last kill, never sampled at it.
          local since = now - S.killedAt
          local busy  = countTable(self.LootActivities)
          if busy > (S.lootMax or 0) then S.lootMax = busy end
          if self.LootBattle and not S.lootOpenedAt then
              S.lootOpenedAt = since
              local opensIn = "?"
              pcall(function()
                  opensIn = string.format("%.1fs", self.LootBattle.opensAt - now)
              end)
              self:TortureInfo("fight_mod", string.format(
                  "loot sweep opened %.0fs after the last kill (men released in %s, %d body/bodies captured)",
                  since, opensIn, #(self.LootBodies or {})))
          end
          -- Done early when the cycle has visibly completed: the sweep opened, men worked it,
          -- and they have all been off it for five seconds. Otherwise the full 45s.
          if S.lootOpenedAt and (S.lootMax or 0) > 0 and busy == 0 then
              S.lootIdleFrom = S.lootIdleFrom or now
          else
              S.lootIdleFrom = nil
          end
          local done = (S.lootIdleFrom and (now - S.lootIdleFrom) >= 5.0) or (since >= 45)
          if not done then return nil end

          if not S.lootOpenedAt then
              -- A real finding, not a measurement artefact: bodies were made and the sweep
              -- never opened over them.
              self:TortureInfo("fight_mod", "loot sweep never opened within 45s of the last kill")
          end
          self:TortureInfo("fight_mod", string.format(
              "loot: opened=%s%s, peak men on loot duty=%d, watched %.0fs after the last kill",
              tostring(S.lootOpenedAt ~= nil),
              S.lootOpenedAt and string.format(" (+%.0fs)", S.lootOpenedAt) or "",
              S.lootMax or 0, since))
          -- Only NOW is the sweep shut down: a man standing over a body is a camp actor, and
          -- post_fight_reform has to measure following rather than looting.
          pcall(function() self:LootSweepStop() end)
          if not S.sawClaim then
              return false, "the bandits died but no merc ever claimed a target (MercTargetOf never filled)"
          end
          return true
      end },

    { name = "post_fight_reform", timeout = 200, ground = true,
      run = function(self, S)
          local pp
          pcall(function() pp = player:GetWorldPos() end)
          S.reformFrom = pp and { x = pp.x, y = pp.y } or nil
      end,
      check = function(self, S)
          local now = tClock()
          if posDue(S) then self:TorturePosLog(S, "reform") end
          -- Walk him 40m clear of the bodies first: "they came back" has to mean they
          -- FOLLOWED, not that they happened to be standing where the fight ended.
          if not S.reformDone then
              if S.routePts then self:TortureWalkRoute(S, S.routePts, S.routeFrom, nil) end
              local pp
              pcall(function() pp = player:GetWorldPos() end)
              local moved = 0
              if pp and S.reformFrom then
                  moved = math.sqrt((pp.x - S.reformFrom.x) ^ 2 + (pp.y - S.reformFrom.y) ^ 2)
              end
              if moved >= 40.0 or (now - S.stepFrom) > 70 then
                  S.reformDone, S.reformAt = true, now
                  self:TortureInfo("reform", string.format(
                      "walked %.0fm on from the fight - now watching them re-form", moved))
              end
              return nil
          end
          -- Sample count comes from the SAME pass as the distance: TortureWalkSample returns
          -- without touching either when nobody is left, and a stale lastMax from the last
          -- walk would then read as "everybody is close" - a wiped squad passing the reform
          -- test is the one false PASS this step could produce.
          S.lastN = 0
          self:TortureWalkSample(S)
          local el   = now - (S.reformAt or now)
          local near = (S.lastN or 0) > 0 and (S.lastMax or 9999) <= (self.TortureFollowNear or 35.0)
          if near and not self.EnemyAlerted then
              self:TortureInfo("reform", string.format(
                  "whole squad back inside %.0fm at +%.0fs, EnemyAlerted cleared",
                  self.TortureFollowNear or 35.0, el))
              return true
          end
          if el < 90 then return nil end
          if (S.lastN or 0) == 0 then return false, "no living merc left after the fight" end
          return false, string.format(
              "%.0fs after the fight the furthest man is %.0fm away (%s) and EnemyAlerted=%s",
              el, S.lastMax or -1, tostring(S.lastWorst or "?"), tostring(self.EnemyAlerted))
      end },

    -- ARMED ONLY BY merc_torture_field_aggro, never by the plain command. Same mechanism and
    -- the same danger as the probe's provoke_test: it calls five mercs onto the nearest
    -- NON-MOD NPC, so on a save with civilians nearby THIS ATTACKS A CIVILIAN. That is
    -- exactly why the arming is a separate command and not a heuristic - a heuristic cannot
    -- tell a bandit from a miller. Meant for save492 (banditcamp), where the nearest vanilla
    -- NPCs are the declared enemy.
    { name = "fight_base_enemies", timeout = 260, ground = true,
      run = function(self, S)
          if not S.aggro then return end
          -- Go home first. Everything before this walked Henry a long way down a patrol
          -- route (measured: route 21 on save492), and the vanilla bandit camp this step
          -- exists to fight is beside the save's START - which is why the first live run
          -- failed with "no base-game NPC within 80m" while standing in an empty field.
          -- One jump, then the squad is given time to close up before anyone is provoked:
          -- five men called in from four hundred metres is not a fight, it is a jog.
          if S.fieldStart then
              pcall(function()
                  player:SetWorldPos({ x = S.fieldStart.x, y = S.fieldStart.y,
                                       z = self:TortureGroundZ(S.fieldStart.x, S.fieldStart.y, S.fieldStart.z) })
              end)
              self:TortureInfo("fight_base", string.format(
                  "jumped back to the save's start (%.1f,%.1f) - waiting for the squad to close up",
                  S.fieldStart.x, S.fieldStart.y))
          else
              self:TortureInfo("fight_base", "no recorded start position - provoking from wherever Henry stands")
          end
          S.homeAt = tClock()
      end,
      check = function(self, S)
          if not S.aggro then
              self:TortureInfo("fight_base", "not armed - run merc_torture_field_aggro on a bandit save for this one")
              return "skip", "aggro not armed"
          end
          local now = tClock()
          if posDue(S) then self:TorturePosLog(S, "fight_base") end

          -- Regroup phase, capped at 60s: they came from a long way off and some of them
          -- will still be running, but the step must not stall on one straggler.
          if not S.provoked then
              self:TortureWalkSample(S)
              local waited = now - (S.homeAt or now)
              local closed = (S.lastN or 0) > 0
                             and (S.lastMean or 9999) <= (self.TortureFollowNear or 35.0)
              if not closed and waited < 60 then return nil end
              self:TortureInfo("fight_base", string.format(
                  "squad %s after %.0fs: %d men, mean %.1fm, furthest %.1fm (%s)",
                  closed and "regrouped" or "still strung out", waited,
                  S.lastN or 0, S.lastMean or -1, S.lastMax or -1, tostring(S.lastWorst or "-")))
              S.provoked, S.provokeAt = true, now
              self:TortureProvokeNearest(S, 120.0)
          end

          if not S.targetName then
              return false, "no base-game NPC within 120m of the save's start to call the squad onto"
          end
          local el = now - (S.provokeAt or S.stepFrom)
          local dead = true
          pcall(function()
              local e = System.GetEntityByName(S.targetName)
              if e and self:IsAliveAndWell(e, true) then dead = false end
          end)
          if not dead and el < 120 then return nil end
          -- Stand the squad down again whatever happened.
          for _, k in ipairs(S.forcedKeys or {}) do self.ForcedTargetOf[k] = nil end
          if dead then
              self:TortureInfo("fight_base", string.format("'%s' down at +%.0fs", S.targetName, el))
              return true
          end
          return false, "'" .. tostring(S.targetName) .. "' still standing after 120s of a called attack"
      end },

    { name = "camp_cycle", timeout = 90, ground = true,
      run = function(self, S)
          local pp
          pcall(function() pp = player:GetWorldPos() end)
          self:SpawnMercCamp(pp and { x = pp.x, y = pp.y, z = pp.z, ang = 0 } or nil, true)
      end,
      check = function(self, S)
          if not self.CampActive then return nil end
          -- CampActive can be true a beat before the props are down, so the prop COUNT is
          -- what actually says a camp stands here. Two independent counts, because neither
          -- is complete on its own: a spatial name sweep (which also catches props no list
          -- tracks) and the camp's own teardown list.
          local props, queried = self:TortureCampProps(60.0)
          local tracked = #(self.CampEntities or {})
          if props <= 0 and tracked <= 0 then return nil end
          self:TortureInfo("camp_cycle", string.format(
              "%d prop(s) within 60m by name%s, %d tracked in CampEntities",
              props, queried and "" or " (sphere query unavailable)", tracked))
          return true
      end },

    { name = "sortie_fight", timeout = 240, ground = true,
      run = function(self, S)
          S.sawClaim = false
          S.actions = {
              function() self:CampTakeParty(0.5) end,
              function() end, function() end,
              function()
                  local out, arch = outPartyStats(self)
                  S.sortieOut = out
                  self:TortureInfo("sortie_fight", "deployed " .. out .. " (" .. arch
                      .. " archer(s)) out of " .. squadCount(self))
              end,
              function() self:SpawnEnemyGroup("bandit", 6) end,
          }
      end,
      check = function(self, S)
          if S.actions and #S.actions > 0 then return nil end
          if (S.sortieOut or 0) == 0 then return false, "deploy-half put nobody out of camp" end
          local now = tClock()
          if countTable(self.MercTargetOf) > 0 then S.sawClaim = true end
          if posDue(S) then
              self:TorturePosLog(S, "sortie")
              self:TortureEnemyLog(S, "sortie")
          end
          if (now - S.stepFrom) < 25 then return nil end
          if liveEnemies(self) > 0 then return nil end
          local n, mx, worst = outPartyFar(self)
          if n == 0 then
              self:TortureInfo("sortie_fight", "the whole sortie is already back in camp")
              return true
          end
          if mx <= (self.TortureFollowNear or 35.0) then
              self:TortureInfo("sortie_fight", string.format(
                  "6 bandits down at +%.0fs; sortie of %d back within %.0fm (furthest %.0fm, %s, claims seen=%s)",
                  now - S.stepFrom, n, self.TortureFollowNear or 35.0, mx,
                  tostring(worst or "-"), tostring(S.sawClaim)))
              return true
          end
          return nil
      end },

    { name = "camp_return_all", timeout = 60, ground = true,
      run = function(self, S) self:CampReturnAll() end,
      check = function(self, S)
          if (tClock() - S.stepFrom) < 6 then return nil end
          if select(1, outPartyStats(self)) == 0 then return true end
      end },

    { name = "camp_break", timeout = 90, ground = true,
      run = function(self, S) self:BreakMercCamp(true) end,
      check = function(self, S)
          if self.CampActive then return nil end
          -- The teardown is staggered across ticks, so nothing is judged for 20s.
          if (tClock() - S.stepFrom) < 20 then return nil end
          local left, queried = self:TortureCampProps(40.0)
          local tracked = #(self.CampEntities or {})
          if not queried then
              self:TortureInfo("camp_break", "sphere query unavailable - judging on CampEntities alone")
              if tracked > 0 then return false, tracked .. " camp entity/entities still tracked after breaking camp" end
              return true
          end
          if left > 0 then
              return false, left .. " camp prop(s) still standing within 40m after breaking camp"
          end
          self:TortureInfo("camp_break", "camp down, no props within 40m, " .. tracked .. " tracked")
          return true
      end },

    -- The "not overwhelming, not too frequent" test. Everything the pacing rules promise is
    -- checked here: one gang at a time, never inside the floor, and a measured gap between
    -- encounters - then the despawn, and the regression where the world went on thinking it
    -- was in a fight after the gang that started it was deleted.
    { name = "patrol_pressure", timeout = 420, ground = true,
      run = function(self, S)
          pcall(function() self:LivePatrolSetEnabled(1) end)
          -- The two WAITING clocks are cleared once, here: the post-load grace and the
          -- post-load quiet exist so a player can get his bearings, and sitting them out
          -- would eat the observation window. The PACING clock is deliberately left to run
          -- from now on - how long the road stays quiet between gangs is exactly what this
          -- step measures.
          self._patrolGraceUntil = nil
          self._patrolQuietUntil = nil
          self._patrolAnchor     = nil
          S.gangAt, S.gangGaps, S.gangMen = {}, {}, {}
          S.lastGangs, S.maxLiveMen, S.tooClose, S.obsDone = 0, 0, nil, false
          -- Stand him ON the road, ~350m along it: a gang only becomes men when its notional
          -- point falls inside PatrolNoSpawnRange..PatrolSpawnRange of the player, so he has
          -- to be somewhere the network actually passes.
          if S.routePts and #S.routePts > 1 then
              local i = indexAlong(S.routePts, 350)
              local p = S.routePts[i]
              if p then
                  pcall(function()
                      player:SetWorldPos({ x = p.x, y = p.y, z = self:TortureGroundZ(p.x, p.y, p.z) })
                  end)
                  S.walkIdx = i
                  self:TortureInfo("patrol_pressure", string.format(
                      "standing on route %s at point %d/%d", tostring(S.routeIdx), i, #S.routePts))
              end
          else
              self:TortureInfo("patrol_pressure", "no route to stand on - observing from wherever Henry is")
          end
          self:TortureInfo("patrol_pressure", string.format(
              "band %.0f-%.0fm, floor %.0fm, despawn %.0fm, caps %d gang(s)/%d men, gap %.0fs, standing cap %d per %.0fm",
              self.PatrolNoSpawnRange or 0, self.PatrolSpawnRange or 0, self.PatrolMinPlayerDist or 0,
              self.PatrolDespawnRange or 0, self.PatrolMaxLiveGangs or 0, self.PatrolMaxLiveMen or 0,
              self.PatrolQuietSecs or 0, self.PatrolAnchorCap or 0, self.PatrolAnchorRadius or 0))
          -- Recorded because a save with the quartermaster's encounters switch OFF spawns
          -- nothing at all, and a window of zero gangs then reads as a calm road rather
          -- than as a system that was never allowed to run.
          local enc = "n/a"
          pcall(function() enc = tostring(self:EncountersOn()) end)
          self:TortureInfo("patrol_pressure", "encounters switch = " .. enc
              .. ", squad = " .. squadCount(self) .. " (gang size scales with it)")
      end,
      check = function(self, S)
          local now = tClock()
          local el  = now - S.stepFrom
          local g, men = 0, 0
          pcall(function() g   = self:PatrolLiveGangCount() end)
          pcall(function() men = self:PatrolLiveMenCount() end)
          if men > (S.maxLiveMen or 0) then S.maxLiveMen = men end

          -- The hard rule: a patrol is an encounter, singular. Two gangs at once IS the
          -- "endless waves of enemies" report, and it fails on the spot.
          if g > 1 then
              return false, g .. " patrol gangs live at once (PatrolMaxLiveGangs = "
                  .. tostring(self.PatrolMaxLiveGangs) .. ")"
          end

          -- ---- phase 1: five minutes standing on the road, watching what comes down it
          if not S.obsDone then
              if g > (S.lastGangs or 0) then
                  table.insert(S.gangAt, el)
                  if #S.gangAt > 1 then table.insert(S.gangGaps, el - S.gangAt[#S.gangAt - 1]) end
                  table.insert(S.gangMen, men)
                  local nearest = self:TorturePatrolNearest()
                  self:TortureInfo("patrol_pressure", string.format(
                      "gang %d spawned at +%.0fs: %d man/men, nearest %.0fm (floor %.0fm)",
                      #S.gangAt, el, men, nearest or -1, self.PatrolMinPlayerDist or 0))
                  if nearest and nearest < (self.PatrolMinPlayerDist or 0) then
                      S.tooClose = string.format(
                          "a patrolman stood %.0fm from Henry on the tick his gang spawned (floor is %.0fm)",
                          nearest, self.PatrolMinPlayerDist or 0)
                  end
              end
              S.lastGangs = g
              if S.tooClose then return false, S.tooClose end
              -- 30s, not 5: this step stands still for five minutes and a per-merc dump every
              -- five seconds would be the biggest thing in the log by an order of magnitude.
              if posDue(S, 30.0) then self:TorturePosLog(S, "patrol") end
              if el < 300 then return nil end

              S.obsDone = true
              local gaps, mens = {}, {}
              for _, v in ipairs(S.gangGaps) do table.insert(gaps, string.format("%.0fs", v)) end
              for _, v in ipairs(S.gangMen) do table.insert(mens, tostring(v)) end
              self:TortureInfo("patrol_pressure", string.format(
                  "300s window: %d gang(s); gaps between them [%s]; live men at each spawn [%s]; most live men at once %d",
                  #S.gangAt, table.concat(gaps, ", "), table.concat(mens, ", "), S.maxLiveMen or 0))

              -- WHICH gangs are standing here, by key, not how many. The first live run failed
              -- "1 gang / 16 men still live" when the log showed the original route-21 gang had
              -- despawned exactly as it should and a DIFFERENT gang had spawned on route 1 at
              -- the destination - two events a headcount cannot tell apart.
              S.preJump, S.preJumpN = {}, 0
              local keys = {}
              for k, rec in pairs(self.LivePatrols or {}) do
                  if rec.spawned then
                      S.preJump[k] = "live"
                      S.preJumpN = S.preJumpN + 1
                      table.insert(keys, tostring(k))
                  end
              end
              self:TortureInfo("patrol_pressure", "gang(s) standing here before the jump: "
                  .. ((#keys > 0) and table.concat(keys, ", ") or "none"))

              local far, d = self:TortureFarRoutePoint(700)
              if far then
                  -- The flag comes OFF for the jump, deliberately. While it is set,
                  -- MonitorMainQuestLoop cannot see the teleport at all, so the mod's
                  -- transition teardown (despawn every gang) and PatrolTravelGraceSecs never
                  -- arm - and the first live run then watched a fresh gang spawn at the
                  -- destination on arrival and called it a failed despawn. Leaving it off is
                  -- also the honest test: this is exactly what a real fast travel does.
                  -- Nothing walks after this point in the step, so it is never turned back
                  -- on here; TortureNext re-arms it for the next ground step.
                  self.TortureDrivesPlayer = false
                  pcall(function()
                      player:SetWorldPos({ x = far.x, y = far.y, z = self:TortureGroundZ(far.x, far.y, far.z) })
                  end)
                  self:TortureInfo("patrol_pressure", string.format(
                      "left the area - %.0fm off now (despawn range %.0fm), fast-travel detector re-enabled for the jump",
                      d or -1, self.PatrolDespawnRange or 0))
              else
                  self:TortureInfo("patrol_pressure", "no road point far enough to leave from - the despawn half is weak here")
              end
              S.awayAt = now
              return nil
          end

          -- ---- phase 2: did the world let go of us?
          local away = now - (S.awayAt or now)

          -- The first tick after the jump is the only place the transition is visible: it
          -- says whether MonitorMainQuestLoop saw the teleport at all, which is the whole
          -- mechanism the despawn hangs off.
          if not S.awayLogged then
              S.awayLogged = true
              local busy0, why0 = self:PlayerBusyForSpawns()
              self:TortureInfo("patrol_pressure", string.format(
                  "first tick after the jump: spawn guard busy=%s (%s), travel grace %.0fs, grace left %s",
                  tostring(busy0), tostring(why0), self.PatrolTravelGraceSecs or 0,
                  tostring(self:PatrolLoadGraceLeft())))
          end

          -- Old gangs versus new ones, by key. A key that goes quiet and later spawns again
          -- counts as NEW - that is a fresh gang on the same road, not a survivor.
          local stillOld = 0
          for k, rec in pairs(self.LivePatrols or {}) do
              if rec.spawned then
                  if S.preJump[k] == "live" then
                      stillOld = stillOld + 1
                  elseif not S.newGangKey then
                      S.newGangKey, S.newGangAt = k, away
                      local grace = self.PatrolTravelGraceSecs or 30.0
                      self:TortureInfo("patrol_pressure", string.format(
                          "a new gang (%s, %d men, nearest %.0fm) spawned %.0fs after the jump - %s the %.0fs travel grace",
                          tostring(k), men, self:TorturePatrolNearest() or -1, away,
                          (away < grace) and "INSIDE" or "after", grace))
                  end
              elseif S.preJump[k] == "live" then
                  S.preJump[k] = "gone"
              end
          end
          if posDue(S, 15.0) then self:TorturePosLog(S, "patrol_away") end

          if away < 20 then return nil end
          if stillOld > 0 then
              if away < 60 then return nil end
              return false, string.format(
                  "%d of the %d gang(s) that were standing here before the jump are STILL live %.0fs after it",
                  stillOld, S.preJumpN or 0, away)
          end
          -- A gang that appears inside the travel grace means the transition teardown never
          -- armed: the road is supposed to stay quiet while the player gets his bearings on
          -- the other side. One that appears AFTER the grace is the system working, and is
          -- INFO (logged above), never a failure.
          local grace = self.PatrolTravelGraceSecs or 30.0
          if S.newGangAt and S.newGangAt < grace then
              return false, string.format(
                  "a new gang (%s) spawned %.0fs after the jump, inside the %.0fs travel grace",
                  tostring(S.newGangKey), S.newGangAt, grace)
          end
          -- ...and the regression this step exists for. A despawn that deletes the men
          -- without scrubbing their combat claims left EnemyAlerted and the spawn guard
          -- latched open: "the game still thinks I am in a fight" long after the fight.
          local busy, why = self:PlayerBusyForSpawns()
          local inCombat = (tostring(why or ""):find("combat", 1, true) ~= nil)
          if not inCombat and not self.EnemyAlerted then
              self:TortureInfo("patrol_pressure", string.format(
                  "all %d pre-jump gang(s) gone at +%.0fs; new gang since: %s; spawn guard busy=%s (%s), EnemyAlerted=false",
                  S.preJumpN or 0, away,
                  S.newGangKey and string.format("%s at +%.0fs", tostring(S.newGangKey), S.newGangAt or -1) or "none",
                  tostring(busy), tostring(why)))
              return true
          end
          if away < 50 then return nil end
          return false, string.format(
              "%.0fs after the patrols despawned the game still reads combat (guard=%s, EnemyAlerted=%s)",
              away, tostring(why), tostring(self.EnemyAlerted))
      end },

    { name = "raid_camp_make", timeout = 90, ground = true,
      run = function(self, S)
          pcall(function() self:LivePatrolSetEnabled(0) end)   -- a gang wandering into a raid is not this test
          local pp
          pcall(function() pp = player:GetWorldPos() end)
          self:SpawnMercCamp(pp and { x = pp.x, y = pp.y, z = pp.z, ang = 0 } or nil, true)
      end,
      check = function(self, S)
          if not self.CampActive then return nil end
          if self:TortureCampProps(60.0) <= 0 and #(self.CampEntities or {}) <= 0 then return nil end
          return true
      end },

    { name = "raid_on_camp", timeout = 300, ground = true,
      run = function(self, S)
          S.raidDefenders0 = squadCount(self)
          S.lastPhase, S.sawBattle = nil, false
          self:RaidNow()
      end,
      check = function(self, S)
          -- Judged off the wall battle's OWN phase machine, exactly as the probe's raid_test
          -- is: two instrument versions built on entity scans were blind to raiders that
          -- spawned, fought and LOST inside one window, and called a won battle "no raiders
          -- ever spawned". An unwalled camp still goes through the machine - WBTick marshals
          -- a deliberate raid whether or not there is a palisade.
          local el = tClock() - S.stepFrom
          local ph = self.WBPhase or "idle"
          if ph ~= "idle" and ph ~= S.lastPhase then
              S.lastPhase, S.sawBattle = ph, true
              self:TortureInfo("raid_on_camp", "wall battle phase '" .. ph .. "' at +"
                  .. string.format("%.0f", el) .. "s")
          end
          if posDue(S, 10.0) then self:TortureEnemyLog(S, "raid") end
          if not S.sawBattle then
              if el > 120 then return false, "the raid never left idle (nobody spawned, or they never marched in)" end
              return nil
          end
          if ph ~= "idle" then return nil end
          self:TortureInfo("raid_on_camp", string.format(
              "battle resolved at +%.0fs: raiders left near camp=%d, defenders %d -> %d",
              el, liveEnemies(self), S.raidDefenders0 or -1, squadCount(self)))
          return true
      end },

    { name = "raid_camp_break", timeout = 90, ground = true,
      run = function(self, S) self:BreakMercCamp(true) end,
      check = function(self, S)
          if self.CampActive then return nil end
          if (tClock() - S.stepFrom) < 20 then return nil end
          local left, queried = self:TortureCampProps(40.0)
          if queried and left > 0 then return false, left .. " camp prop(s) still standing within 40m" end
          local tracked = #(self.CampEntities or {})
          if tracked > 0 then return false, tracked .. " camp entity/entities still tracked" end
          return true
      end },

    { name = "field_health", timeout = 20, ground = true,
      run = function(self, S) end,
      check = function(self, S)
          local stalls = countTable(self.FollowStallStreak)
          local poses  = countTable(self.CampPoseHoldFrom)
          local claims = countTable(self.MercTargetOf)
          local gangs  = 0
          pcall(function() gangs = self:PatrolLiveGangCount() end)
          local busy, why = self:PlayerBusyForSpawns()
          self:TortureInfo("field_health", string.format(
              "squad=%d stallStreaks=%d poseHolds=%d claims=%d alerted=%s spawnGuard=%s(%s) camp=%s patrolGangs=%d",
              squadCount(self), stalls, poses, claims, tostring(self.EnemyAlerted),
              tostring(busy), tostring(why), tostring(self.CampActive), gangs))
          if stalls > 3 then return false, stalls .. " concurrent stall streaks" end
          if poses > 0 then return false, poses .. " pose-hold(s) still armed after the camp came down" end
          return true
      end },
}

function mercenaries:TortureStartField(autoquit, aggro)
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
        idx = 1, plan = self.TortureFieldPlan[1], planList = self.TortureFieldPlan,
        stepFrom = tClock(), startedAt = tClock(), anchor = anchor,
        pass = 0, fail = 0, skip = 0,
        aggro = (aggro == true), deadline = self.TortureFieldDeadline,
    }
    -- God NOW, hoist never: every step of this plan is `ground`, so Henry stays on his feet -
    -- but he must be immortal from this instant, not from the first tick.
    self:TortureArmSafety(self._tortureState, false)
    -- Scheduled raids off for the whole run (raid_on_camp launches its own), and roaming
    -- patrols off until patrol_pressure switches them back on: a gang wandering into a
    -- follow measurement turns it into a battle and reads as an unrelated FAIL. Both are
    -- restored in TortureFinish. LivePatrolSetEnabled rather than the bare flag, because
    -- the flag alone leaves any gang that is ALREADY standing exactly where it is.
    self._tortureRaidWas = self.RaidEnabled
    self.RaidEnabled = false
    self._torturePatrolWas = self.LivePatrolsEnabled
    pcall(function() self:LivePatrolSetEnabled(0) end)
    self.TortureDrivesPlayer = (self.TortureFieldPlan[1].ground == true)
    tLog("=== torture FIELD plan: " .. #self.TortureFieldPlan .. " step(s), autoquit="
         .. tostring(self.TortureAutoQuit) .. ", aggro=" .. tostring(aggro == true) .. " ===")
    tLog("step '" .. self.TortureFieldPlan[1].name .. "'")
    pcall(self.TortureFieldPlan[1].run, self, self._tortureState)
    Script.SetTimerForFunction(self.TortureTickMs, "mercenaries.TortureTick" .. self.TortureSlot)
end

-- ---------------------------------------------------------------------------
-- wiring
-- ---------------------------------------------------------------------------

-- MANUAL convenience only: put the torture triggers back on F6/F7/F8 for a session.
-- NEVER called automatically - every one of these ends in quit, and F6 sends the squad
-- at an innocent NPC. Players firing them by accident is exactly the bug that got the
-- automatic binds removed.
--
-- The HARNESS no longer uses this at all. Measured: a run typed merc_dev and
-- merc_torture_bindkeys, logged "dev binds applied", tapped F8 - and nothing happened, not
-- one [Torture] line, because the game's own bindings shadow the F-keys (the same thing
-- autobench's -ConsoleCmd was added for). Every trigger the harness fires is TYPED into the
-- console now; a typed command cannot be shadowed by a keybind.
function mercenaries:TortureBindKeys()
    pcall(function() System.ExecuteCommand("bind f8 merc_torture_auto") end)
    pcall(function() System.ExecuteCommand("bind f7 merc_torture_probe") end)
    pcall(function() System.ExecuteCommand("bind f6 merc_torture_probe_aggro") end)
    System.LogAlways("[Torture] dev binds applied: F8=merc_torture_auto F7=merc_torture_probe F6=merc_torture_probe_aggro")
end

-- Dev-gated: automated tests, all of which quit the game when done. Not registered
-- until merc_dev, which itself only works in a -devmode launch. See docs/console.md.
mercenaries:DevCommand("merc_torture",       "mercenaries:TortureStart(false)",      "Run the functional torture-test campaign")
mercenaries:DevCommand("merc_torture_auto",  "mercenaries:TortureStart(true)",       "Run the torture campaign and QUIT when done (harness mode)")
mercenaries:DevCommand("merc_torture_probe", "mercenaries:TortureStartProbe(true)",  "Adaptive scenario probe: observe this save's world and QUIT")
mercenaries:DevCommand("merc_torture_probe_aggro", "mercenaries:TortureStartProbe(true, true)", "Scenario probe + call the squad onto the nearest vanilla NPC (bandit saves ONLY)")
mercenaries:DevCommand("merc_torture_bindkeys", "mercenaries:TortureBindKeys()", "Bind F8/F7/F6 to the torture triggers for this session (harness use)")
-- The field plan is typed into the console by the harness, never bound to a key: it is a
-- single-session plan with no reload, so it needs no keystroke arming, and the release
-- policy is that nothing here takes an F-key.
mercenaries:DevCommand("merc_torture_field",      "mercenaries:TortureStartField(false)",
                   "Field plan: walk, follow at 5/12/24, fight, camp, patrols and a raid - one session")
mercenaries:DevCommand("merc_torture_field_auto", "mercenaries:TortureStartField(true)",
                   "Run the field plan and QUIT when done (harness mode)")
mercenaries:DevCommand("merc_torture_field_aggro", "mercenaries:TortureStartField(false, true)",
                   "Field plan + call the squad onto the nearest BASE-GAME NPC (bandit saves ONLY - it would murder a civilian)")
mercenaries:DevCommand("merc_torture_field_aggro_auto", "mercenaries:TortureStartField(true, true)",
                   "Field plan with the base-game fight armed, and QUIT when done (bandit saves ONLY)")
