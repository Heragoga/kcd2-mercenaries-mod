-- Automated functional QUEST plan - the third torture-test plan, after the camp campaign and
-- the field plan (both in mercenaries_torture.lua, whose conventions this file reuses whole:
-- plan steps { name, timeout, minSecs?, ground?, run, check }, TortureCheck/TortureInfo,
-- TortureArmSafety, TortureKeepSafe, TortureWalkTo, TorturePosLog, TortureEnemyLog,
-- TortureSetSquad, and the campaign's save step).
--
-- What it tests: a whole Kleinkrieg playthrough (mercenaries_banditcamp_quest.lua) across REAL
-- saves and REAL relaunches - accept, approach, spawn, fight, letter, hand-in, the counter
-- advancing - plus the three regressions that only exist across a load:
--
--   * a patrol contract restored from a save (Q2): contract alive, camp NOT rebuilt until the
--     player is near again;
--   * a SIEGE contract restored from a save (Q3): RaborschOnLoad drops RBQ to inactive, and the
--     old code read that zero-man siege as a won one and completed the contract on the spot;
--   * Aleksej's beat 8 (Q3): the camp spawns with no distance gate, so its progress must only
--     be judged from inside AlxProgressRange - the "castle is empty / objectives auto-complete
--     on load" report.
--
-- THREE STAGES, three game sessions, because a completed load kills every Lua timer:
--
--   Q1  fresh session  -> ends in a save stamped TortureStage="Q2", then "[Torture] SAVED"
--   Q2  after relaunch -> ends in a save stamped TortureStage="Q3", then "[Torture] SAVED"
--   Q3  after relaunch -> ends in "[Torture] COMPLETE"
--
-- The harness (tools/torturetest.ps1 -Plan quest) types merc_torture_quest_auto, waits for
-- SAVED or COMPLETE, and on SAVED relaunches + presses Continue + types the command again.
-- TortureStartQuest dispatches on the stamp in the loaded save, exactly as TortureStart does
-- for the campaign's phase B. Nothing here ever self-arms.
--
-- Henry HOVERS in god mode for everything except the disperse approach and the saves (an
-- airborne player cannot save). Teleports are fine and are the whole point of a quest plan -
-- the sites are up to 3.6 km apart - so every step sets TortureDrivesPlayer, which makes the
-- mod's own fast-travel detector stand down; without it MonitorMainQuestLoop reads each jump
-- as a fast travel and idles the squad, and a squad that was told to stand still cannot follow
-- Henry to a bandit camp.
--
-- All sites are on the KUTTENBERG level (mercenaries.BanditCampSites); the run assumes it
-- starts on a Kuttenberg save.

local function tLog(s) System.LogAlways("[Torture] " .. tostring(s)) end

local function qClock()
    local t = 0; pcall(function() t = System.GetCurrTime() or 0 end); return t
end

local function countTable(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

local function dist2(a, b)
    if not (a and b) then return -1 end
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

-- Rate limit for the POS trace, same 5s cadence and the same reason as the field plan's:
-- 24 mercs at 1 Hz for twenty minutes is tens of thousands of lines and kcd.log rotates.
local function posDue(S, every)
    local now = qClock()
    every = every or mercenaries.TortureLogEvery or 5.0
    if S.posAt and (now - S.posAt) < every then return false end
    S.posAt = now
    return true
end

-- Same idea for the INFO lines a long-running check wants to emit while it waits.
local function infoDue(S, every)
    local now = qClock()
    every = every or 15.0
    if S.qInfoAt and (now - S.qInfoAt) < every then return false end
    S.qInfoAt = now
    return true
end

-- ---------------------------------------------------------------------------
-- tunables (sized for a ~15fps notebook: nothing is judged on frames)
-- ---------------------------------------------------------------------------

-- Deliberately just under the harness's own per-stage wait, exactly as TortureFieldDeadline
-- is: a stage that is going to run out of time must be the one that says so, because a plan
-- killed by the harness reports nothing at all.
mercenaries.TortureQuestDeadline   = 1440
-- Where a jump lands relative to a site: inside BanditCampForgetRange (300m, so the monitor
-- builds the camp) and well outside BanditCampDespawnRange (50m, the "under his feet" range
-- that also makes BanditCampPickSite refuse a site).
mercenaries.TortureQuestApproachM  = 200.0
-- ...and where it goes to leave the area: past BanditCampForgetRange, so the camp unloads.
mercenaries.TortureQuestAwayM      = 700.0
mercenaries.TortureQuestScanRadius = 150.0   -- the enemy census box around a site anchor
mercenaries.TortureQuestFightSecs  = 120     -- how long the men get before the lever
mercenaries.TortureQuestSquadSize  = 8
mercenaries.TortureQuestDisperseM  = 6.0     -- the mod's own rule is 8m; walk inside it

-- ---------------------------------------------------------------------------
-- shared probes
-- ---------------------------------------------------------------------------

-- The Kleinkrieg slot, never the bare self.BCQ: the bounty binds self.BCQ to its own table
-- while it services it, and BanditCampMonitor only puts the arc back at the end of a pass.
function mercenaries:TortureQuestKK()
    return self.BCQ_KK or self.BCQ
end

local function squadCount(self)
    local n = 0
    for _, ent in pairs(self.ActiveMercs or {}) do
        if ent and self:IsAliveAndWell(ent, true) then n = n + 1 end
    end
    return n
end

-- Living men, mean and furthest distance from Henry. Written here rather than borrowed from
-- TortureWalkSample because that one also fills the follow-verdict sample ring, and a quest
-- step has no follow verdict to give.
function mercenaries:TortureQuestSquadDist()
    local pp
    pcall(function() pp = player:GetWorldPos() end)
    if not pp then return 0, -1, -1, nil end
    local n, sum, mx, worst = 0, 0, 0, nil
    for name, ent in pairs(self.ActiveMercs or {}) do
        local alive = false
        pcall(function() alive = self:IsAliveAndWell(ent, true) end)
        if alive then
            local q
            pcall(function() q = ent:GetWorldPos() end)
            if q then
                local d = dist2(q, pp)
                n, sum = n + 1, sum + d
                if d > mx then mx, worst = d, name end
            end
        end
    end
    if n == 0 then return 0, -1, -1, nil end
    return n, sum / n, mx, worst
end

function mercenaries:TortureQuestSquadLine()
    local n, mean, mx, worst = self:TortureQuestSquadDist()
    return string.format("%d man/men, mean %.0fm, furthest %.0fm (%s)", n, mean, mx,
        tostring(worst or "-"))
end

-- Living mod enemies inside `radius` of a point. By spatial query and NAME (ModEnemyPrefixes),
-- the same way TortureEnemyLog counts them, so "how many stand at the camp" does not depend on
-- any one roster being complete.
function mercenaries:TortureQuestLiving(at, radius)
    if not at then return -1 end
    local n = 0
    pcall(function()
        local ents = System.GetPhysicalEntitiesInBoxByClass(
            { x = at.x, y = at.y, z = at.z }, radius or self.TortureQuestScanRadius, "NPC")
        for _, e in pairs(ents or {}) do
            local nm
            pcall(function() nm = e:GetName() end)
            if nm and self:IsModEnemyName(nm) and self:IsAliveAndWell(e, true) then n = n + 1 end
        end
    end)
    return n
end

-- ...and the contract's own answer: how many of the band it is tracking are still up.
function mercenaries:TortureQuestBandLiving()
    local KK = self:TortureQuestKK()
    local n = 0
    for _, id in ipairs(KK.bandits or {}) do
        pcall(function()
            local e = System.GetEntity(id)
            if e and self:IsAliveAndWell(e, true) then n = n + 1 end
        end)
    end
    return n
end

function mercenaries:TortureQuestMoney()
    local m = -1
    pcall(function() m = player.inventory:GetMoney() end)
    return tonumber(m) or -1
end

-- A site row and its anchor, ALWAYS through BanditCampSiteAnchor: a road site's truth is its
-- recorded route point, not the cached x/y/z, and re-recording the routes moves the contract.
function mercenaries:TortureQuestAnchorOf(siteOrName)
    local site = siteOrName
    if type(siteOrName) == "string" then site = self:BanditCampSiteByName(siteOrName) end
    if not site then return nil, nil end
    local a
    pcall(function() a = self:BanditCampSiteAnchor(site) end)
    return a, site
end

-- Where to stand `want` metres from `anchor`. A recorded road point is preferred over a
-- bearing-and-distance guess for exactly the reason TortureFarRoutePoint gives: recorded routes
-- are ground the author actually rode, so a point on one is somewhere Henry can stand, while a
-- computed bearing lands in lakes, on cliffs and off the map.
function mercenaries:TortureQuestApproachPoint(anchor, want)
    want = want or self.TortureQuestApproachM
    -- No anchor is a broken site row, not a place to jump to: stand still rather than
    -- indexing nil (every caller is inside a step's run, where an error is a lost step).
    if not anchor then
        local pp
        pcall(function() pp = player:GetWorldPos() end)
        return { x = (pp and pp.x) or 0, y = (pp and pp.y) or 0, z = (pp and pp.z) or 0 },
               -1, "NO ANCHOR - staying put"
    end
    local lo, hi = want * 0.75, want * 1.35
    local best, bestErr, bestD
    for _, set in ipairs({ self.PatrolRouteData, self.PatrolRoutesKuttenberg }) do
        for _, r in ipairs(set or {}) do
            for _, p in ipairs(r.pts or {}) do
                local d = dist2(p, anchor)
                if d >= lo and d <= hi then
                    local err = math.abs(d - want)
                    if not bestErr or err < bestErr then best, bestErr, bestD = p, err, d end
                end
            end
        end
    end
    if best then
        return { x = best.x, y = best.y, z = best.z }, bestD, "road point"
    end
    -- Nothing recorded in the band: fall back to a bearing from the anchor towards wherever
    -- Henry is now (the direction he would have come from), z snapped to the terrain.
    local pp
    pcall(function() pp = player:GetWorldPos() end)
    local dx, dy = 1, 0
    if pp then
        local d = dist2(pp, anchor)
        if d > 1 then dx, dy = (pp.x - anchor.x) / d, (pp.y - anchor.y) / d end
    end
    local x, y = anchor.x + dx * want, anchor.y + dy * want
    return { x = x, y = y, z = anchor.z }, want, "bearing (no recorded road in range)"
end

-- Move Henry, and MOVE THE HOVER WITH HIM. TortureKeepSafe re-asserts S.anchor + TortureHover
-- every tick, so a jump that does not update S.anchor is undone on the very next tick.
function mercenaries:TortureQuestJump(S, pos, tag, why)
    local from
    pcall(function() from = player:GetWorldPos() end)
    local z = self:TortureGroundZ(pos.x, pos.y, (pos.z or (from and from.z)) or 0)
    pcall(function() player:SetWorldPos({ x = pos.x, y = pos.y, z = z }) end)
    S.anchor = { x = pos.x, y = pos.y, z = z }
    self:TortureInfo(tag, string.format("jump (%s): (%.1f,%.1f,%.1f) -> (%.1f,%.1f,%.1f), %.0fm",
        tostring(why),
        from and from.x or -1, from and from.y or -1, from and from.z or -1,
        pos.x, pos.y, z, from and dist2(from, pos) or -1))
end

-- The "kill everything now" lever: the function behind merc_clear_enemies. Bounds fight time
-- so a stubborn archer cannot eat a whole stage.
function mercenaries:TortureQuestClearLever(tag)
    local before = self:TortureQuestBandLiving()
    pcall(function() self:CmdEnemyClear() end)
    self:TortureInfo(tag, "merc_clear_enemies fired with " .. before .. " of the band still up")
    return before
end

-- The backstop, and a FINDING when it is needed: CmdClearPrefixes covers SpawnedEnemy_,
-- SpawnedRenegade_, SpawnedPatrol_ and SpawnedPatrolman_ only, so anything a camp adopted
-- under another name (tower archers, cart archers) survives the lever - and a contract whose
-- target includes them then never clears. This removes what the lever left, by roster.
function mercenaries:TortureQuestKillBand()
    local KK = self:TortureQuestKK()
    local n = 0
    for _, id in ipairs(KK.bandits or {}) do
        pcall(function()
            local e = System.GetEntity(id)
            if e and self:IsAliveAndWell(e, true) then
                System.RemoveEntity(id)
                n = n + 1
            end
        end)
    end
    -- A siege counts its dead out of RBQ, not S.bandits.
    pcall(function()
        if not (self.RBQ and self.RBQ.active) then return end
        for _, list in ipairs({ self.RBQ.foot, self.RBQ.archers }) do
            for _, id in ipairs(list or {}) do
                pcall(function()
                    local e = System.GetEntity(id)
                    if e and self:IsAliveAndWell(e, true) then
                        System.RemoveEntity(id)
                        n = n + 1
                    end
                end)
            end
        end
    end)
    return n
end

-- Every quest step's prelude. Clears the per-step scratch TortureNext does not know about
-- (it clears the campaign's and the field plan's), and re-asserts the fast-travel stand-down:
-- TortureNext sets TortureDrivesPlayer from plan.ground, and a quest step drives Henry whether
-- or not it is a `ground` step.
-- Put AlxSignalToken back if a step wrapped it to watch for a beat's down token. Called from
-- the watching step's own exits AND from every step after it, because a check that errors is
-- caught by TortureStep's pcall and moves straight on - which would otherwise leave the mod
-- running with a test's closure in place of one of its own methods for the rest of the session.
local function unwrapAlxSignal(self)
    if self._tortureQuestAlxSignal then
        self.AlxSignalToken, self._tortureQuestAlxSignal = self._tortureQuestAlxSignal, nil
    end
end

local function qReset(self, S)
    unwrapAlxSignal(self)
    S.siteAnchor, S.sitePos = nil, nil
    S.fightFrom, S.leverAt, S.backstopAt, S.killed0, S.enemy0 = nil, nil, nil, nil, nil
    S.spawnAt, S.money0, S.qInfoAt, S.holdTicks, S.arrivedAt = nil, nil, nil, nil, nil
    S.deliverAt, S.jumped, S.stage2, S.letterAt, S.fallbackTried = nil, nil, nil, nil, nil
    S.baseline, S.grantTried = nil, nil
    self.TortureDrivesPlayer = true
end

-- ---------------------------------------------------------------------------
-- the two bodies every contract shares
-- ---------------------------------------------------------------------------

-- APPROACH: land TortureQuestApproachM from the anchor, wait for the 1Hz monitor to build the
-- camp, then check the census against the contract's target. Tower and cart archers arrive on
-- their own deferred spawn and are ADOPTED into the target late (BanditCampAdoptTowerArchers),
-- so the count is allowed to sit two under - the exact numbers go out as INFO either way.
function mercenaries:TortureQuestApproachBody(S, tag)
    local KK  = self:TortureQuestKK()
    local now = qClock()
    if not S.siteAnchor then
        return false, "the contract has no site anchor to approach (BanditCampSiteAnchor returned nothing)"
    end
    if posDue(S) then self:TorturePosLog(S, tag) end

    if not KK.spawned then
        if infoDue(S, 20.0) then
            local pp
            pcall(function() pp = player:GetWorldPos() end)
            self:TortureInfo(tag, string.format(
                "waiting for the monitor at +%.0fs: spawned=false, anchor=(%.1f,%.1f,%.1f) player=(%.1f,%.1f,%.1f) d=%.0fm (forget range %.0fm); squad %s",
                now - S.stepFrom, S.siteAnchor.x, S.siteAnchor.y, S.siteAnchor.z,
                pp and pp.x or -1, pp and pp.y or -1, pp and pp.z or -1,
                pp and dist2(pp, S.siteAnchor) or -1, self.BanditCampForgetRange or -1,
                self:TortureQuestSquadLine()))
        end
        return nil
    end
    if not S.spawnAt then
        S.spawnAt = now
        self:TortureInfo(tag, string.format("camp spawned at +%.0fs", now - S.stepFrom))
    end
    -- Deferred tower/cart archers need a beat to exist and be adopted before the count means
    -- anything at all.
    if (now - S.spawnAt) < 15 then return nil end

    local near   = self:TortureQuestLiving(S.siteAnchor, self.TortureQuestScanRadius)
    local roster = self:TortureQuestBandLiving()
    local want   = KK.target or 0
    local pp
    pcall(function() pp = player:GetWorldPos() end)
    local line = string.format(
        "target=%d, living within %.0fm of the anchor=%d, contract roster still up=%d; anchor=(%.1f,%.1f,%.1f) player=(%.1f,%.1f,%.1f) d=%.0fm; squad %s",
        want, self.TortureQuestScanRadius, near, roster,
        S.siteAnchor.x, S.siteAnchor.y, S.siteAnchor.z,
        pp and pp.x or -1, pp and pp.y or -1, pp and pp.z or -1,
        pp and dist2(pp, S.siteAnchor) or -1, self:TortureQuestSquadLine())

    if near >= want - 2 or roster >= want - 2 then
        self:TortureInfo(tag, line)
        return true
    end
    if infoDue(S, 15.0) then self:TortureInfo(tag, line) end
    if (now - S.spawnAt) < 75 then return nil end
    return false, string.format(
        "only %d enemy/enemies stand within %.0fm of the anchor (contract roster says %d) for a target of %d",
        near, self.TortureQuestScanRadius, roster, want)
end

-- FIGHT: move the hover onto the camp so the squad walks in, give them
-- TortureQuestFightSecs of a REAL fight, report how many the men killed, then bound the time
-- with merc_clear_enemies and report how many that cleared. Judged on BCQ.cleared, which is
-- the contract's own verdict and lags the last death by up to BanditCampMissingTicks (5)
-- polls - hence the 60s grace.
function mercenaries:TortureQuestFightBody(S, tag)
    local KK  = self:TortureQuestKK()
    local now = qClock()
    local el  = now - S.stepFrom

    if posDue(S) then
        self:TorturePosLog(S, tag)
        self:TortureEnemyLog(S, tag)
    end

    if not S.fightFrom then
        -- Fifteen seconds for the squad's own catch-up to bring them onto the camp.
        if el < 15 then return nil end
        S.fightFrom = now
        S.killed0   = KK.killed or 0
        S.enemy0    = self:TortureQuestLiving(S.siteAnchor, self.TortureQuestScanRadius)
        self:TortureInfo(tag, string.format(
            "fight opens: %d enemy/enemies up, contract at %d/%d killed, alerted=%s; squad %s",
            S.enemy0, KK.killed or -1, KK.target or -1, tostring(KK.alerted),
            self:TortureQuestSquadLine()))
    end
    local fel = now - S.fightFrom

    if KK.cleared then
        self:TortureInfo(tag, string.format(
            "BCQ.cleared at +%.0fs of the fight (killed %d/%d; lever used=%s, roster backstop used=%s)",
            fel, KK.killed or -1, KK.target or -1,
            tostring(S.leverAt ~= nil), tostring(S.backstopAt ~= nil)))
        return true
    end

    if fel < (self.TortureQuestFightSecs or 120) then
        if infoDue(S, 30.0) then
            self:TortureInfo(tag, string.format("+%.0fs: %d/%d killed, %d still up near the anchor, alerted=%s",
                fel, KK.killed or -1, KK.target or -1,
                self:TortureQuestLiving(S.siteAnchor, self.TortureQuestScanRadius),
                tostring(KK.alerted)))
        end
        return nil
    end

    if not S.leverAt then
        local byMen = (KK.killed or 0) - (S.killed0 or 0)
        self:TortureInfo(tag, string.format(
            "%.0fs of real fighting: the men killed %d (contract %d -> %d of %d); %d of the band still up",
            fel, byMen, S.killed0 or -1, KK.killed or -1, KK.target or -1,
            self:TortureQuestBandLiving()))
        local cleared = self:TortureQuestClearLever(tag)
        S.leverAt = now
        S.leverCleared = cleared
        return nil
    end

    local lel = now - S.leverAt
    if lel > 30 and not S.backstopAt then
        S.backstopAt = now
        local left = self:TortureQuestBandLiving()
        if left > 0 then
            local n = self:TortureQuestKillBand()
            self:TortureInfo(tag, string.format(
                "FINDING: merc_clear_enemies left %d of the band standing 30s on - CmdClearPrefixes does not cover adopted tower/cart archers; removed %d by roster instead",
                left, n))
        end
        return nil
    end
    if lel < 60 then return nil end
    return false, string.format(
        "BCQ.cleared never latched: killed=%s of target=%s, %d of the band and %d mod enemy/enemies still living %.0fs after the field was cleared",
        tostring(KK.killed), tostring(KK.target), self:TortureQuestBandLiving(),
        self:TortureQuestLiving(S.siteAnchor, self.TortureQuestScanRadius), lel)
end

-- HAND-IN: walk off the field (past BanditCampDespawnRange, so the camp is cleaned up and the
-- contract can close), deliver, then check the purse and the counter. GiveMoney is chunked and
-- honest, so the delta must be the reward exactly; the purse is printed either way because it
-- stops accepting created coin around 9-10k (bug 1 in docs/torture-test.md).
function mercenaries:TortureQuestDeliverBody(S, tag, wantCleared)
    local KK  = self:TortureQuestKK()
    local now = qClock()
    if posDue(S, 10.0) then self:TorturePosLog(S, tag) end

    if not S.jumped then
        S.jumped = now
        local pt, d, how = self:TortureQuestApproachPoint(S.siteAnchor, self.TortureQuestApproachM)
        self:TortureQuestJump(S, pt, tag,
            string.format("off the field to hand in (%s, %.0fm from the anchor, despawn range %.0fm)",
                how, d, self.BanditCampDespawnRange or -1))
        return nil
    end
    -- Let the monitor unload the cleared camp before the hand-in, so BCQ.active can actually
    -- go false: a paid contract only closes out on a tick where the camp is no longer spawned.
    if (now - S.jumped) < 12 then return nil end

    if not S.deliverAt then
        S.money0 = self:TortureQuestMoney()
        S.reward = KK.reward or 0
        S.hadLetter = self:BanditCampHasLetter()
        self:TortureInfo(tag, string.format(
            "handing in: reward=%d, purse before=%d, hasLetter=%s, cleared=%s, active=%s, spawned=%s, contracts paid=%d",
            S.reward, S.money0, tostring(S.hadLetter), tostring(KK.cleared),
            tostring(KK.active), tostring(KK.spawned), self:BanditCampCleared()))
        pcall(function() self:BanditCampDeliverLetter() end)
        S.deliverAt = now
        return nil
    end
    -- GiveMoney is chunked over several calls and the monitor needs a tick or two to close the
    -- contract out; judged after both have had time.
    if (now - S.deliverAt) < 15 then return nil end

    local money1 = self:TortureQuestMoney()
    local delta  = money1 - (S.money0 or 0)
    local done   = self:BanditCampCleared()
    self:TortureInfo(tag, string.format(
        "paid: purse %d -> %d (delta %d, reward %d); contracts paid=%d (wanted %d); active=%s spawned=%s",
        S.money0 or -1, money1, delta, S.reward or -1, done, wantCleared,
        tostring(KK.active), tostring(KK.spawned)))

    if done ~= wantCleared then
        return false, string.format("BanditCampCleared() is %d after the hand-in, wanted %d", done, wantCleared)
    end
    -- One coin of slack, not exact: GetMoney is a FLOAT and the first live run read a
    -- freshly minted 275 back as 274.99, which the integer reads above floor to 274.
    -- Anything short by MORE than a coin is still the ceiling or a regression.
    if math.abs(delta - (S.reward or 0)) > 1 then
        return false, string.format(
            "the purse rose %d for a reward of %d (purse now %d - GiveMoney is chunked and honest, so a short pay here is either the ~10k purse ceiling or a real regression)",
            delta, S.reward or -1, money1)
    end
    if KK.active ~= false then
        return false, "BCQ.active is still true after payment - the contract never closed out"
    end
    return true
end

-- ---------------------------------------------------------------------------
-- the save step, shared by Q1 and Q2. The campaign's quicksave step verbatim: ground Henry
-- (the engine refuses to write a save while the player is airborne - five runs of
-- Game.QuickSave wrote nothing before that was found), stamp the stage, then
-- SaveGameViaResting with QuickSave as the fallback, in that order, exactly as CampBedSave
-- orders them. `awaitReload` hands control to the harness instead of to a next step.
-- ---------------------------------------------------------------------------

local function saveStep(name, stamp, note)
    return {
        name = name, timeout = 90, awaitReload = true,
        run = function(self, S)
            qReset(self, S)
            local KK = self:TortureQuestKK()
            self:TortureInfo(name, string.format(
                "stamping TortureStage=%s (%s): contract active=%s site=%s cleared=%s killed=%s/%s, contracts paid=%d",
                stamp, tostring(note), tostring(KK.active),
                tostring(KK.site and KK.site.name), tostring(KK.cleared),
                tostring(KK.killed), tostring(KK.target), self:BanditCampCleared()))
            self:SaveString("TortureStage", stamp)
            self:SaveString("TortureQSquad", tostring(squadCount(self)))
            pcall(function() self:BanditCampSave() end)
            pcall(function() self:SaveCampState() end)
            S.groundForSave = true
            S.actions = {
                function() end, function() end,   -- two grounded ticks to settle
                function()
                    local ok = false
                    pcall(function() ok = Game.SaveGameViaResting() end)
                    if not ok then pcall(function() Game.QuickSave() end) end
                end,
            }
        end,
        check = function(self, S)
            if S.actions and #S.actions > 0 then return nil end
            if (qClock() - S.stepFrom) < 10 then return nil end   -- let the save write out
            return true
        end,
    }
end

-- ---------------------------------------------------------------------------
-- STAGE Q1 - a fresh session on a Kuttenberg save
-- ---------------------------------------------------------------------------

mercenaries.TortureQuestPlanQ1 = {

    { name = "q_sanity", timeout = 120,
      run = function(self, S)
          qReset(self, S)
          local KK = self:TortureQuestKK()
          local tag, phase, disp = "?", "?", "?"
          pcall(function() tag   = tostring(self:LoadString("BCQuest")) end)
          pcall(function() phase = tostring(self:LoadString("KKPhase")) end)
          pcall(function() disp  = tostring(self:LoadString("KKDispersed")) end)
          self:TortureInfo("q_sanity", string.format(
              "start: squad=%d campActive=%s BCampDone=%d KKPhase=%s KKDispersed=%s BCQuest=%s",
              squadCount(self), tostring(self.CampActive), self:BanditCampCleared(),
              phase, disp, tag))
          if KK.active then
              self:TortureInfo("q_sanity", string.format(
                  "this save already carries a contract (site=%s cleared=%s) - abandoning it so the run starts from contract 1",
                  tostring(KK.site and KK.site.name), tostring(KK.cleared)))
          end
          -- Normalise: no camp (a standing camp turns every hire into a camp resident rather
          -- than a follower, and the squad has to WALK to these sites), no contract, and the
          -- counter back to zero so contract 1 really is the woodland camp.
          if self.CampActive then self:BreakMercCamp(true) end
          S.actions = {
              function() if self:TortureQuestKK().active then self:BanditCampAbandon() end end,
              function() self:SetState("follow") end,
              -- The recorded road network for this level, so TortureQuestApproachPoint has
              -- somewhere real to put Henry down. PatrolRoutesForLevel is the mod's own answer
              -- to "which road set is this map"; it clears LivePatrols on a set switch, which
              -- is harmless here because the plan turns roaming patrols off anyway.
              function() pcall(function() self:PatrolRoutesForLevel() end) end,
              function() self:SaveString("BCampDone", "0") end,
              function() self:BanditCampResync() end,
              function() self:TortureSetSquad(S, self.TortureQuestSquadSize or 8) end,
          }
      end,
      check = function(self, S)
          if S.actions and #S.actions > 0 then return nil end
          if (qClock() - S.stepFrom) < 20 then return nil end
          local KK = self:TortureQuestKK()
          local done, squad = self:BanditCampCleared(), squadCount(self)
          local routes = 0
          for _, r in ipairs(self.PatrolRouteData or self.PatrolRoutesKuttenberg or {}) do
              routes = routes + (r.pts and #r.pts or 0)
          end
          self:TortureInfo("q_sanity", string.format(
              "normalised: BCampDone=%d contract active=%s campActive=%s squad=%d, %d recorded road point(s) to jump between",
              done, tostring(KK.active), tostring(self.CampActive), squad, routes))
          if self.CampActive then return nil end
          if KK.active then return false, "a contract is still active after BanditCampAbandon" end
          if done ~= 0 then return false, "BanditCampCleared() is " .. done .. " after the reset, wanted 0" end
          if squad < (self.TortureQuestSquadSize or 8) then
              if (qClock() - S.stepFrom) < 90 then return nil end
              return false, "only " .. squad .. " merc(s) stand after hiring to " .. (self.TortureQuestSquadSize or 8)
          end
          return true
      end },

    { name = "kk1_accept", timeout = 45,
      run = function(self, S)
          qReset(self, S)
          S.actions = { function() self:BanditCampAccept() end }
      end,
      check = function(self, S)
          if S.actions and #S.actions > 0 then return nil end
          if (qClock() - S.stepFrom) < 4 then return nil end
          local KK = self:TortureQuestKK()
          local a = KK.site and self:BanditCampSiteAnchor(KK.site)
          self:TortureInfo("kk1_accept", string.format(
              "contract %s '%s': site=%s group=%s target=%d archers=%d reward=%d spawned=%s anchor=(%.1f,%.1f,%.1f)",
              tostring(KK.contractIdx), tostring((self:KleinkriegContract() or {}).name),
              tostring(KK.site and KK.site.name), tostring(KK.group), KK.target or -1,
              KK.archers or -1, KK.reward or -1, tostring(KK.spawned),
              a and a.x or -1, a and a.y or -1, a and a.z or -1))
          if not KK.active then return false, "BCQ.active is false after BanditCampAccept()" end
          if not (KK.site and KK.site.name == "woodland_camp") then
              return false, "contract 1 pitched at '" .. tostring(KK.site and KK.site.name)
                  .. "', expected woodland_camp"
          end
          if KK.spawned ~= false then
              return false, "the camp spawned on accept - it must not be built until the player is inside BanditCampForgetRange"
          end
          return true
      end },

    { name = "kk1_approach", timeout = 300,
      run = function(self, S)
          qReset(self, S)
          local KK = self:TortureQuestKK()
          S.siteAnchor = self:BanditCampSiteAnchor(KK.site)
          local pt, d, how = self:TortureQuestApproachPoint(S.siteAnchor, self.TortureQuestApproachM)
          self:TortureQuestJump(S, pt, "kk1_approach",
              string.format("%s, %.0fm from the woodland camp (spawn range %.0fm)",
                  how, d, self.BanditCampForgetRange or -1))
      end,
      check = function(self, S) return self:TortureQuestApproachBody(S, "kk1_approach") end },

    { name = "kk1_fight", timeout = 280,
      run = function(self, S)
          qReset(self, S)
          local KK = self:TortureQuestKK()
          S.siteAnchor = self:BanditCampSiteAnchor(KK.site)
          -- Onto the camp: the squad follows Henry, so the hover has to be over the fight or
          -- there is no fight. He is in god mode and 16m up; the men do the work.
          self:TortureQuestJump(S, S.siteAnchor, "kk1_fight", "onto the woodland camp")
      end,
      check = function(self, S) return self:TortureQuestFightBody(S, "kk1_fight") end },

    -- Contract 1 carries no `letter`, so KleinkriegLetterClass() is nil and BanditCampHasLetter()
    -- must answer TRUE immediately. Asserting that is the point: it documents the letterless
    -- path, where BanditCampComplete skips the search leg entirely instead of raising an
    -- objective and closing it in the same breath.
    { name = "kk1_letter_deliver", timeout = 140,
      run = function(self, S)
          qReset(self, S)
          local KK = self:TortureQuestKK()
          S.siteAnchor = self:BanditCampSiteAnchor(KK.site)
          S.hadLetter0 = self:BanditCampHasLetter()
          self:TortureInfo("kk1_letter_deliver", string.format(
              "letterless contract: KleinkriegLetterClass=%s BanditCampHasLetter()=%s letterTaken=%s",
              tostring(self:KleinkriegLetterClass()), tostring(S.hadLetter0), tostring(KK.letterTaken)))
      end,
      check = function(self, S)
          if S.hadLetter0 ~= true then
              return false, "contract 1 carries no letter, so BanditCampHasLetter() must be true on the spot - it answered "
                  .. tostring(S.hadLetter0)
          end
          return self:TortureQuestDeliverBody(S, "kk1_letter_deliver", 1)
      end },

    -- JUMP THE COUNTER. BCampDone is the ONLY piece of progress state the arc keeps
    -- (BanditCampCleared reads it, BanditCampAdvance writes it, KleinkriegContract picks the
    -- contract off it), so writing it and resyncing IS starting at contract 4 - there is no
    -- second bookkeeping to get out of step with. merc_banditcamp_reset does the same thing in
    -- the other direction.
    { name = "kk4_jump_accept", timeout = 60,
      run = function(self, S)
          qReset(self, S)
          S.actions = {
              function() self:SaveString("BCampDone", "3") end,
              function() self:BanditCampResync() end,
              function() self:BanditCampAccept() end,
          }
      end,
      check = function(self, S)
          if S.actions and #S.actions > 0 then return nil end
          if (qClock() - S.stepFrom) < 4 then return nil end
          local KK = self:TortureQuestKK()
          local c  = self:KleinkriegContract()
          local a  = KK.site and self:BanditCampSiteAnchor(KK.site)
          self:TortureInfo("kk4_jump_accept", string.format(
              "counter jumped to 3: contracts paid=%d, contract %s '%s' site=%s letter=%s patrol=%s target=%d reward=%d anchor=(%.1f,%.1f,%.1f)",
              self:BanditCampCleared(), tostring(KK.contractIdx), tostring(c and c.name),
              tostring(KK.site and KK.site.name), tostring(c and c.letter),
              tostring(c and c.patrol), KK.target or -1, KK.reward or -1,
              a and a.x or -1, a and a.y or -1, a and a.z or -1))
          if not KK.active then return false, "BCQ.active is false after the jumped accept" end
          if not (KK.site and KK.site.name == "patrol_company") then
              return false, "contract 4 pitched at '" .. tostring(KK.site and KK.site.name)
                  .. "', expected patrol_company"
          end
          return true
      end },

    { name = "kk4_approach", timeout = 300,
      run = function(self, S)
          qReset(self, S)
          local KK = self:TortureQuestKK()
          S.siteAnchor = self:BanditCampSiteAnchor(KK.site)
          local pt, d, how = self:TortureQuestApproachPoint(S.siteAnchor, self.TortureQuestApproachM)
          self:TortureQuestJump(S, pt, "kk4_approach",
              string.format("%s, %.0fm from the company's road", how, d))
      end,
      check = function(self, S) return self:TortureQuestApproachBody(S, "kk4_approach") end },

    { name = "kk4_fight", timeout = 280,
      run = function(self, S)
          qReset(self, S)
          local KK = self:TortureQuestKK()
          S.siteAnchor = self:BanditCampSiteAnchor(KK.site)
          self:TortureQuestJump(S, S.siteAnchor, "kk4_fight", "onto the company's column")
      end,
      check = function(self, S) return self:TortureQuestFightBody(S, "kk4_fight") end },

    -- THE LETTER PATH. Contract 4 carries TokenIDKKLetter1, which rides on the leader's body and
    -- is normally LOOTED. A hovering tester loots nothing, so this step records how the letter
    -- actually arrived: straight into the pack (the leader dropped it and something picked it
    -- up), via BanditCampGrantLetterFallback, or - when the fallback declines because
    -- S.letterOnLeader is true - via the direct grant behind merc_banditcamp_give_letter.
    -- Every one of those is a FINDING in the INFO line, not a failure; the failure is having no
    -- letter at all, which makes the contract uncompletable.
    { name = "kk4_letter", timeout = 120,
      run = function(self, S)
          qReset(self, S)
          local KK = self:TortureQuestKK()
          S.letterAt = qClock()
          self:TortureInfo("kk4_letter", string.format(
              "after the clear: letterClass=%s hasLetter=%s letterOnLeader=%s letterTaken=%s letterGranted=%s",
              tostring(self:KleinkriegLetterClass()), tostring(self:BanditCampHasLetter()),
              tostring(KK.letterOnLeader), tostring(KK.letterTaken), tostring(KK.letterGranted)))
      end,
      check = function(self, S)
          local KK  = self:TortureQuestKK()
          local now = qClock()
          local el  = now - (S.letterAt or now)
          if self:BanditCampHasLetter() then
              self:TortureInfo("kk4_letter", string.format(
                  "the letter is in Henry's pack at +%.0fs (fallback used=%s, direct grant used=%s)",
                  el, tostring(S.fallbackTried == true), tostring(S.grantTried == true)))
              return true
          end
          -- 20s for the loot sweep and the monitor's own letterTaken poll to have their chance.
          if el < 20 then return nil end
          if not S.fallbackTried then
              S.fallbackTried = true
              pcall(function() self:BanditCampGrantLetterFallback() end)
              self:TortureInfo("kk4_letter", string.format(
                  "FINDING: 20s after the clear the letter was still not in the pack - called BanditCampGrantLetterFallback() (letterOnLeader=%s)",
                  tostring(KK.letterOnLeader)))
              return nil
          end
          if el < 35 then return nil end
          if not S.grantTried then
              S.grantTried = true
              -- The fallback declines outright while the letter is on the leader's body ("let
              -- them loot it themselves"), which a hovering tester never will. The direct grant
              -- is the same call merc_banditcamp_give_letter makes, and it exists for exactly
              -- this: testing the hand-in half without the looting half.
              pcall(function() self:BanditCampGiveLetter() end)
              self:TortureInfo("kk4_letter",
                  "FINDING: the fallback declined too (it defers to looting while letterOnLeader is set) - granted the letter directly, as merc_banditcamp_give_letter does")
              return nil
          end
          if el < 50 then return nil end
          return false, "the contract's letter never reached Henry's pack - loot, fallback and direct grant all failed, so the hand-in is impossible"
      end },

    { name = "kk4_deliver", timeout = 140,
      run = function(self, S)
          qReset(self, S)
          local KK = self:TortureQuestKK()
          S.siteAnchor = self:BanditCampSiteAnchor(KK.site)
      end,
      check = function(self, S) return self:TortureQuestDeliverBody(S, "kk4_deliver", 4) end },

    -- Contract 10, the looter column, accepted and DELIBERATELY not approached: the camp must
    -- survive the save as a contract and be rebuilt only when the player comes back to it.
    { name = "kk10_accept", timeout = 60,
      run = function(self, S)
          qReset(self, S)
          S.actions = {
              function() self:SaveString("BCampDone", "9") end,
              function() self:BanditCampResync() end,
              function() self:BanditCampAccept() end,
          }
      end,
      check = function(self, S)
          if S.actions and #S.actions > 0 then return nil end
          if (qClock() - S.stepFrom) < 4 then return nil end
          local KK = self:TortureQuestKK()
          local c  = self:KleinkriegContract()
          local a  = KK.site and self:BanditCampSiteAnchor(KK.site)
          local pp
          pcall(function() pp = player:GetWorldPos() end)
          self:TortureInfo("kk10_accept", string.format(
              "contracts paid=%d, contract %s '%s' site=%s disperse=%s patrol=%s target=%d reward=%d; anchor=(%.1f,%.1f,%.1f) player=(%.1f,%.1f,%.1f) d=%.0fm - NOT approached on purpose",
              self:BanditCampCleared(), tostring(KK.contractIdx), tostring(c and c.name),
              tostring(KK.site and KK.site.name), tostring(c and c.disperse),
              tostring(c and c.patrol), KK.target or -1, KK.reward or -1,
              a and a.x or -1, a and a.y or -1, a and a.z or -1,
              pp and pp.x or -1, pp and pp.y or -1, pp and pp.z or -1,
              (a and pp) and dist2(a, pp) or -1))
          if not KK.active then return false, "BCQ.active is false after the jumped accept" end
          if not (KK.site and KK.site.name == "patrol_looters") then
              return false, "contract 10 pitched at '" .. tostring(KK.site and KK.site.name)
                  .. "', expected patrol_looters"
          end
          if not (c and c.disperse) then
              return false, "contract 10 is not flagged `disperse` - the Q2 disperse test would prove nothing"
          end
          if KK.spawned ~= false then
              return false, "the looter column spawned without the player ever going near it"
          end
          return true
      end },

    saveStep("q1_save_Q2", "Q2", "contract 10 accepted, never approached"),
}

-- ---------------------------------------------------------------------------
-- STAGE Q2 - after the relaunch and Continue
-- ---------------------------------------------------------------------------

mercenaries.TortureQuestPlanQ2 = {

    -- THE RESTORE REGRESSION. BanditCampRestore rebuilds the CONTRACT from the BCQuest blob
    -- with spawned=false; the camp itself is only rebuilt on a tick where the player is inside
    -- BanditCampForgetRange. A contract that came back "already standing", or a counter that
    -- did not survive, is the whole failure mode.
    { name = "q2_restore", timeout = 120,
      run = function(self, S)
          qReset(self, S)
          pcall(function() self:PatrolRoutesForLevel() end)
          local blob, phase, disp = "?", "?", "?"
          pcall(function() blob  = tostring(self:LoadString("BCQuest")) end)
          pcall(function() phase = tostring(self:LoadString("KKPhase")) end)
          pcall(function() disp  = tostring(self:LoadString("KKDispersed")) end)
          S.blob, S.phase, S.disp = blob, phase, disp
      end,
      check = function(self, S)
          -- The load's own restore chain (BanditCampRestore, BanditCampResync, the camp
          -- restore) is deferred by several seconds; nothing here is judged before it lands.
          if (qClock() - S.stepFrom) < 15 then return nil end
          local KK   = self:TortureQuestKK()
          local done = self:BanditCampCleared()
          local want = done + 1
          local phase = tonumber(S.phase) or -1
          local a = KK.site and self:BanditCampSiteAnchor(KK.site)
          local pp
          pcall(function() pp = player:GetWorldPos() end)
          self:TortureInfo("q2_restore", string.format(
              "restored: active=%s site=%s spawned=%s cleared=%s killed=%s/%s contractIdx=%s; BCampDone=%d KKPhase=%s (want >=%d) KKDispersed=%s; squad=%d",
              tostring(KK.active), tostring(KK.site and KK.site.name), tostring(KK.spawned),
              tostring(KK.cleared), tostring(KK.killed), tostring(KK.target),
              tostring(KK.contractIdx), done, S.phase, want, S.disp, squadCount(self)))
          self:TortureInfo("q2_restore", "saved BCQuest blob = " .. tostring(S.blob))
          if a and pp then
              self:TortureInfo("q2_restore", string.format(
                  "anchor=(%.1f,%.1f,%.1f) player=(%.1f,%.1f,%.1f) d=%.0fm (forget range %.0fm)",
                  a.x, a.y, a.z, pp.x, pp.y, pp.z, dist2(a, pp), self.BanditCampForgetRange or -1))
          end
          if not KK.active then return false, "the contract did not survive the save: BCQ.active is false" end
          if not (KK.site and KK.site.name == "patrol_looters") then
              return false, "the restored contract is at '" .. tostring(KK.site and KK.site.name)
                  .. "', expected patrol_looters"
          end
          if KK.spawned ~= false then
              return false, "the camp came back ALREADY SPAWNED - a restore must leave spawned=false and let the monitor rebuild it on approach"
          end
          if done ~= 9 then
              return false, "BanditCampCleared() is " .. done .. " after the reload, wanted 9"
          end
          if phase < want then
              return false, string.format(
                  "the KKPhase tag is %s but the quartermaster should be speaking for contract %d - the dialog gates and the counter are out of step",
                  S.phase, want)
          end
          return true
      end },

    { name = "kk10_approach", timeout = 300,
      run = function(self, S)
          qReset(self, S)
          local KK = self:TortureQuestKK()
          S.siteAnchor = self:BanditCampSiteAnchor(KK.site)
          local pt, d, how = self:TortureQuestApproachPoint(S.siteAnchor, self.TortureQuestApproachM)
          self:TortureQuestJump(S, pt, "kk10_approach",
              string.format("%s, %.0fm from the looters' road", how, d))
      end,
      check = function(self, S) return self:TortureQuestApproachBody(S, "kk10_approach") end },

    -- THE DISPERSE PATH, and the one step in this plan where Henry has to be ON HIS FEET:
    -- BanditCampService wants a bandit within 8m of the PLAYER with his weapon SHEATHED for
    -- four consecutive monitor ticks. `ground = true` makes TortureKeepSafe skip the hoist, so
    -- position belongs to this step (god mode stays on regardless).
    --
    -- Sheathing: the mod reads player.human:IsWeaponDrawn() and never sheathes anything - there
    -- is no sheathe binding anywhere in the codebase (human:DrawWeapon() exists, its inverse
    -- does not). This stage always begins on a FRESH LOAD, which starts Henry sheathed, so the
    -- test relies on that and merely reports the flag. If he ever comes back drawn, the step
    -- says so in its FAIL reason rather than pretending.
    --
    -- The squad is put on HOLD first: the disperse branch is gated on `not S.alerted`, and a
    -- merc claiming a looter alerts the column and turns the whole thing into a fight.
    { name = "kk10_disperse", timeout = 320, ground = true,
      run = function(self, S)
          qReset(self, S)
          local KK = self:TortureQuestKK()
          S.siteAnchor = self:BanditCampSiteAnchor(KK.site)
          S.drawn0 = true
          pcall(function() S.drawn0 = player.human:IsWeaponDrawn() end)
          self:TortureInfo("kk10_disperse", string.format(
              "walking in sheathed: IsWeaponDrawn()=%s (a fresh load starts sheathed; the mod has no sheathe call to make), alerted=%s, %d looter(s) up",
              tostring(S.drawn0), tostring(KK.alerted), self:TortureQuestBandLiving()))
          S.actions = { function() self:SetState("wait") end }
      end,
      check = function(self, S)
          if S.actions and #S.actions > 0 then return nil end
          local KK  = self:TortureQuestKK()
          local now = qClock()
          if posDue(S) then self:TorturePosLog(S, "kk10_disperse") end

          if KK.dispersed and KK.cleared then
              self:TortureInfo("kk10_disperse", string.format(
                  "dispersed and cleared: %d tick(s) held inside %.0fm (the rule is 4 consecutive ticks inside 8m, sheathed), %.0fs after arriving; killed=%s/%s",
                  S.holdTicks or 0, self.TortureQuestDisperseM or 6.0,
                  now - (S.arrivedAt or now), tostring(KK.killed), tostring(KK.target)))
              pcall(function() self:SetState("follow") end)
              return true
          end

          -- Nearest living man of the column, straight off the contract's roster.
          local pp
          pcall(function() pp = player:GetWorldPos() end)
          if not pp then return nil end   -- no position this tick: judge nothing off it
          local best, bestD
          for _, id in ipairs(KK.bandits or {}) do
              pcall(function()
                  local e = System.GetEntity(id)
                  if e and self:IsAliveAndWell(e, true) then
                      local q = e:GetWorldPos()
                      local d = dist2(q, pp)
                      if q and (not bestD or d < bestD) then best, bestD = q, d end
                  end
              end)
          end
          if not best then
              if (now - S.stepFrom) < 40 then return nil end
              return false, "no living looter to walk up to - the column is gone before the disperse could be tried"
          end

          local drawn = true
          pcall(function() drawn = player.human:IsWeaponDrawn() end)

          if bestD > (self.TortureQuestDisperseM or 6.0) then
              S.arrivedAt = nil
              self:TortureWalkTo(S, best)
              if infoDue(S, 20.0) then
                  self:TortureInfo("kk10_disperse", string.format(
                      "walking: nearest looter %.0fm off, drawn=%s alerted=%s disperseTicks=%s",
                      bestD, tostring(drawn), tostring(KK.alerted), tostring(KK.disperseTicks)))
              end
              return nil
          end

          -- Standing on him: hold position (no walk call) and let the monitor count.
          if not S.arrivedAt then
              S.arrivedAt, S.holdTicks = now, 0
              self:TortureInfo("kk10_disperse", string.format(
                  "arrived: %.1fm from the nearest looter, drawn=%s alerted=%s", bestD, tostring(drawn),
                  tostring(KK.alerted)))
          end
          S.holdTicks = (S.holdTicks or 0) + 1
          if infoDue(S, 10.0) then
              self:TortureInfo("kk10_disperse", string.format(
                  "holding %.1fm off for %d tick(s): drawn=%s alerted=%s disperseTicks=%s dispersed=%s",
                  bestD, S.holdTicks, tostring(drawn), tostring(KK.alerted),
                  tostring(KK.disperseTicks), tostring(KK.dispersed)))
          end
          if (now - S.arrivedAt) < 60 then return nil end
          pcall(function() self:SetState("follow") end)
          return false, string.format(
              "%d tick(s) held %.1fm from a looter and the column never dispersed (drawn=%s, alerted=%s, disperseTicks=%s, dispersed=%s, cleared=%s)",
              S.holdTicks or 0, bestD, tostring(drawn), tostring(KK.alerted),
              tostring(KK.disperseTicks), tostring(KK.dispersed), tostring(KK.cleared))
      end },

    { name = "kk10_deliver", timeout = 140,
      run = function(self, S)
          qReset(self, S)
          local KK = self:TortureQuestKK()
          S.siteAnchor = self:BanditCampSiteAnchor(KK.site)
          self:TortureInfo("kk10_deliver", "letterless contract: BanditCampHasLetter()="
              .. tostring(self:BanditCampHasLetter()) .. ", dispersed=" .. tostring(KK.dispersed))
          S.actions = { function() self:SetState("follow") end }
      end,
      check = function(self, S)
          if S.actions and #S.actions > 0 then return nil end
          return self:TortureQuestDeliverBody(S, "kk10_deliver", 10)
      end },

    { name = "kk12_siege_accept", timeout = 60,
      run = function(self, S)
          qReset(self, S)
          S.actions = {
              function() self:SaveString("BCampDone", "11") end,
              function() self:BanditCampResync() end,
              function() self:BanditCampAccept() end,
          }
      end,
      check = function(self, S)
          if S.actions and #S.actions > 0 then return nil end
          if (qClock() - S.stepFrom) < 4 then return nil end
          local KK = self:TortureQuestKK()
          local c  = self:KleinkriegContract()
          local a  = KK.site and self:BanditCampSiteAnchor(KK.site)
          self:TortureInfo("kk12_siege_accept", string.format(
              "contracts paid=%d, contract %s '%s' site=%s siege=%s target=%d reward=%d anchor=(%.1f,%.1f,%.1f)",
              self:BanditCampCleared(), tostring(KK.contractIdx), tostring(c and c.name),
              tostring(KK.site and KK.site.name), tostring(c and c.siege),
              KK.target or -1, KK.reward or -1,
              a and a.x or -1, a and a.y or -1, a and a.z or -1))
          if not KK.active then return false, "BCQ.active is false after the jumped accept" end
          if not (KK.site and KK.site.name == "raborsch") then
              return false, "contract 12 pitched at '" .. tostring(KK.site and KK.site.name)
                  .. "', expected raborsch"
          end
          if not (c and c.siege) then return false, "contract 12 is not flagged `siege`" end
          return true
      end },

    { name = "kk12_approach", timeout = 320,
      run = function(self, S)
          qReset(self, S)
          local KK = self:TortureQuestKK()
          S.siteAnchor = self:BanditCampSiteAnchor(KK.site)
          local pt, d, how = self:TortureQuestApproachPoint(S.siteAnchor, self.TortureQuestApproachM)
          self:TortureQuestJump(S, pt, "kk12_approach",
              string.format("%s, %.0fm from Raborsch", how, d))
      end,
      check = function(self, S)
          local KK  = self:TortureQuestKK()
          local now = qClock()
          if posDue(S) then self:TorturePosLog(S, "kk12_approach") end
          local R = self.RBQ or {}
          local foot, arch = #(R.foot or {}), #(R.archers or {})
          if R.active and foot > 0 then
              self:TortureInfo("kk12_approach", string.format(
                  "the siege stands at +%.0fs: RBQ.active=true foot=%d archers=%d, contract spawned=%s target=%d; %d mod enemy/enemies living within %.0fm; squad %s",
                  now - S.stepFrom, foot, arch, tostring(KK.spawned), KK.target or -1,
                  self:TortureQuestLiving(S.siteAnchor, self.TortureQuestScanRadius),
                  self.TortureQuestScanRadius, self:TortureQuestSquadLine()))
              -- Persisted, because Q3 is a DIFFERENT SESSION and has to compare the rebuilt
              -- siege against this one. Plain Lua would not survive the load.
              pcall(function() self:SaveString("TortureQSiege", foot .. "/" .. arch) end)
              return true
          end
          if infoDue(S, 20.0) then
              self:TortureInfo("kk12_approach", string.format(
                  "waiting at +%.0fs: RBQ.active=%s foot=%d archers=%d, contract spawned=%s",
                  now - S.stepFrom, tostring(R.active), foot, arch, tostring(KK.spawned)))
          end
          if (now - S.stepFrom) < 240 then return nil end
          return false, string.format("the siege never built: RBQ.active=%s foot=%d archers=%d, BCQ.spawned=%s",
              tostring(R.active), foot, arch, tostring(KK.spawned))
      end },

    { name = "kk12_hold", timeout = 120, minSecs = 60,
      run = function(self, S)
          qReset(self, S)
          local KK = self:TortureQuestKK()
          S.siteAnchor = self:BanditCampSiteAnchor(KK.site)
          local R = self.RBQ or {}
          S.foot0, S.arch0 = #(R.foot or {}), #(R.archers or {})
      end,
      check = function(self, S)
          local now = qClock()
          if posDue(S, 10.0) then self:TortureEnemyLog(S, "kk12_hold") end
          if (now - S.stepFrom) < 60 then return nil end
          local KK = self:TortureQuestKK()
          local R  = self.RBQ or {}
          local up = 0
          pcall(function()
              for _, list in ipairs({ R.foot, R.archers }) do
                  for _, id in ipairs(list or {}) do
                      local e = System.GetEntity(id)
                      if e and e.actor and e.soul and self:IsAliveAndWell(e, true) then up = up + 1 end
                  end
              end
          end)
          self:TortureInfo("kk12_hold", string.format(
              "60s held: rostered foot=%d archers=%d, %d of them streamed in and living; contract killed=%s/%s cleared=%s; %d mod enemy/enemies within %.0fm; squad %s",
              S.foot0 or -1, S.arch0 or -1, up, tostring(KK.killed), tostring(KK.target),
              tostring(KK.cleared), self:TortureQuestLiving(S.siteAnchor, self.TortureQuestScanRadius),
              self.TortureQuestScanRadius, self:TortureQuestSquadLine()))
          if KK.cleared then
              return false, "the siege contract completed itself inside 60s of standing there - nothing was fought"
          end
          return true
      end },

    -- The save is taken with the SIEGE CONTRACT LIVE and unfinished - which is all that can
    -- ever survive a save, since spawned NPCs do not. Henry walks off the field first, past
    -- BanditCampForgetRange: otherwise the monitor rebuilds the whole siege inside the twelve
    -- seconds between the load completing and Q3's first tick, and "spawned == false on
    -- restore" could never be observed at all.
    { name = "kk12_leave_field", timeout = 90,
      run = function(self, S)
          qReset(self, S)
          local KK = self:TortureQuestKK()
          S.siteAnchor = self:BanditCampSiteAnchor(KK.site)
          local pt, d, how = self:TortureQuestApproachPoint(S.siteAnchor, self.TortureQuestAwayM)
          self:TortureQuestJump(S, pt, "kk12_leave_field",
              string.format("%s, %.0fm off (forget range %.0fm)", how, d, self.BanditCampForgetRange or -1))
      end,
      check = function(self, S)
          local KK = self:TortureQuestKK()
          if (qClock() - S.stepFrom) < 20 then return nil end
          local pp
          pcall(function() pp = player:GetWorldPos() end)
          self:TortureInfo("kk12_leave_field", string.format(
              "%.0fm from the anchor: BCQ.spawned=%s cleared=%s killed=%s/%s, RBQ.active=%s",
              pp and dist2(pp, S.siteAnchor) or -1, tostring(KK.spawned), tostring(KK.cleared),
              tostring(KK.killed), tostring(KK.target), tostring(self.RBQ and self.RBQ.active)))
          if KK.cleared then
              return false, "walking away completed the siege contract - a camp the player left is not a camp he won"
          end
          if KK.spawned ~= false then
              if (qClock() - S.stepFrom) < 60 then return nil end
              return false, "the camp is still flagged spawned "
                  .. string.format("%.0fm", pp and dist2(pp, S.siteAnchor) or -1)
                  .. " away - the unload never ran"
          end
          return true
      end },

    saveStep("q2_save_Q3", "Q3", "the siege contract live and unfinished"),
}

-- ---------------------------------------------------------------------------
-- STAGE Q3 - after the second relaunch and Continue
-- ---------------------------------------------------------------------------

mercenaries.TortureQuestPlanQ3 = {

    -- THE REGRESSION THIS WHOLE PLAN EXISTS FOR. RaborschOnLoad resets RBQ = {active=false} on
    -- every load, because the siege's ENTITIES do not survive one; the contract does. The old
    -- code read that zero-man siege as a siege that had been WON and completed the contract on
    -- the spot - a Raborsch you never fought, paid out on the loading screen.
    { name = "q3_siege_restore", timeout = 120,
      run = function(self, S)
          qReset(self, S)
          pcall(function() self:PatrolRoutesForLevel() end)
          local KK = self:TortureQuestKK()
          local R  = self.RBQ or {}
          S.blob = "?"
          pcall(function() S.blob = tostring(self:LoadString("BCQuest")) end)
          S.siteAnchor = KK.site and self:BanditCampSiteAnchor(KK.site)
          local pp
          pcall(function() pp = player:GetWorldPos() end)
          self:TortureInfo("q3_siege_restore", string.format(
              "first look after the load: active=%s site=%s spawned=%s cleared=%s killed=%s/%s; RBQ.active=%s foot=%d archers=%d; player %.0fm from the anchor",
              tostring(KK.active), tostring(KK.site and KK.site.name), tostring(KK.spawned),
              tostring(KK.cleared), tostring(KK.killed), tostring(KK.target),
              tostring(R.active), #(R.foot or {}), #(R.archers or {}),
              (pp and S.siteAnchor) and dist2(pp, S.siteAnchor) or -1))
          self:TortureInfo("q3_siege_restore", "saved BCQuest blob = " .. tostring(S.blob))
          S.sawSpawned  = (KK.spawned == true)
          S.sawRbActive = (R.active == true)
      end,
      check = function(self, S)
          local KK  = self:TortureQuestKK()
          local R   = self.RBQ or {}
          local now = qClock()
          if KK.cleared then
              return false, string.format(
                  "THE REGRESSION IS BACK: the siege contract read as CLEARED %.0fs after the load with RBQ.active=%s and no man ever fought (killed=%s/%s)",
                  now - S.stepFrom, tostring(R.active), tostring(KK.killed), tostring(KK.target))
          end
          if infoDue(S, 10.0) then
              self:TortureInfo("q3_siege_restore", string.format(
                  "+%.0fs: cleared=%s spawned=%s RBQ.active=%s foot=%d",
                  now - S.stepFrom, tostring(KK.cleared), tostring(KK.spawned),
                  tostring(R.active), #(R.foot or {})))
          end
          if (now - S.stepFrom) < 30 then return nil end
          if not KK.active then return false, "the siege contract did not survive the save: BCQ.active is false" end
          if not (KK.site and KK.site.name == "raborsch") then
              return false, "the restored contract is at '" .. tostring(KK.site and KK.site.name)
                  .. "', expected raborsch"
          end
          if S.sawSpawned then
              return false, "the contract came back with spawned=true - a restore must leave the siege unbuilt until the player returns"
          end
          if S.sawRbActive then
              return false, "RBQ.active was true on the first look after the load - RaborschOnLoad must drop it, or SpawnRaborsch refuses to rebuild for the rest of the session"
          end
          self:TortureInfo("q3_siege_restore", string.format(
              "held 30s: cleared stayed false, spawned=false, RBQ.active=false, killed=%s/%s - the zero-man siege was not mistaken for a won one",
              tostring(KK.killed), tostring(KK.target)))
          return true
      end },

    { name = "q3_siege_rebuild", timeout = 320,
      run = function(self, S)
          qReset(self, S)
          local KK = self:TortureQuestKK()
          S.siteAnchor = self:BanditCampSiteAnchor(KK.site)
          S.before = "?"
          pcall(function() S.before = tostring(self:LoadString("TortureQSiege")) end)
          local pt, d, how = self:TortureQuestApproachPoint(S.siteAnchor, self.TortureQuestApproachM)
          self:TortureQuestJump(S, pt, "q3_siege_rebuild",
              string.format("%s, %.0fm from Raborsch (the siege before the save was %s foot/archers)",
                  how, d, S.before))
      end,
      check = function(self, S)
          local KK  = self:TortureQuestKK()
          local now = qClock()
          if posDue(S) then self:TorturePosLog(S, "q3_siege_rebuild") end
          local R = self.RBQ or {}
          local foot, arch = #(R.foot or {}), #(R.archers or {})
          if R.active and foot > 0 then
              -- Shipped behaviour, recorded rather than judged: RaborschOnLoad wipes the record,
              -- so a mid-siege reload rebuilds a FULL siege on approach rather than the remnant
              -- the player left. This line is the evidence for that sentence in the docs.
              self:TortureInfo("q3_siege_rebuild", string.format(
                  "rebuilt at +%.0fs: foot=%d archers=%d (before the save: %s) - a reload rebuilds the siege at FULL strength, since RaborschOnLoad drops the record with the entities; contract spawned=%s target=%s killed=%s",
                  now - S.stepFrom, foot, arch, tostring(S.before), tostring(KK.spawned),
                  tostring(KK.target), tostring(KK.killed)))
              return true
          end
          if infoDue(S, 20.0) then
              self:TortureInfo("q3_siege_rebuild", string.format(
                  "waiting at +%.0fs: RBQ.active=%s foot=%d, BCQ.spawned=%s",
                  now - S.stepFrom, tostring(R.active), foot, tostring(KK.spawned)))
          end
          if (now - S.stepFrom) < 240 then return nil end
          return false, string.format("the siege never came back: RBQ.active=%s foot=%d, BCQ.spawned=%s",
              tostring(R.active), foot, tostring(KK.spawned))
      end },

    { name = "kk12_fight", timeout = 300,
      run = function(self, S)
          qReset(self, S)
          local KK = self:TortureQuestKK()
          S.siteAnchor = self:BanditCampSiteAnchor(KK.site)
          self:TortureQuestJump(S, S.siteAnchor, "kk12_fight", "onto the siege line")
      end,
      check = function(self, S) return self:TortureQuestFightBody(S, "kk12_fight") end },

    { name = "kk12_deliver", timeout = 140,
      run = function(self, S)
          qReset(self, S)
          local KK = self:TortureQuestKK()
          S.siteAnchor = self:BanditCampSiteAnchor(KK.site)
      end,
      check = function(self, S) return self:TortureQuestDeliverBody(S, "kk12_deliver", 12) end },

    -- ALEKSEJ'S BEAT 8, at the ENCOUNTER level. The journal itself cannot be driven from Lua -
    -- the beats are opened by Skald from dialogue, and AlxSpawnBeat is the only entry point
    -- this side of the bridge - so what is testable here is the thing that was actually broken:
    -- a beat-8 camp raised at the Roman fort (3.6km from Raborsch) must not report ANY progress
    -- while the player stands beside it, because at that range System.GetEntity hands back
    -- handles whose actor/soul proxies never streamed in and IsAliveAndWell reads them as dead.
    -- That is the "castle is empty / objectives auto-complete on load" report in one line.
    { name = "alx_beat8_regression", timeout = 200,
      run = function(self, S)
          qReset(self, S)
          local a, site = self:TortureQuestAnchorOf("roman_fort")
          local ra = self:TortureQuestAnchorOf("raborsch")
          S.fortAnchor, S.rabAnchor = a, ra
          if a then self:TortureQuestJump(S, a, "alx_beat8_regression", "to the Roman fort") end
          self:TortureInfo("alx_beat8_regression", string.format(
              "fort=(%.1f,%.1f,%.1f) raborsch=(%.1f,%.1f,%.1f) - %.0fm apart, AlxProgressRange is %.0fm",
              a and a.x or -1, a and a.y or -1, a and a.z or -1,
              ra and ra.x or -1, ra and ra.y or -1, ra and ra.z or -1,
              (a and ra) and dist2(a, ra) or -1, self.AlxProgressRange or -1))
          -- Watch the ONE progress signal Lua still sends for a beat: AlxDownToken[8]. Wrapped
          -- rather than inferred, so "the leader was reported down" is caught even if the flag
          -- it sets were later cleared. Put back the moment this step returns a verdict.
          S.alxDownSeen = false
          local down8 = (self.AlxDownToken or {})[8]
          if down8 and not self._tortureQuestAlxSignal then
              self._tortureQuestAlxSignal = self.AlxSignalToken
              local orig, st = self.AlxSignalToken, S
              self.AlxSignalToken = function(me, cls)
                  if cls == down8 then st.alxDownSeen = true end
                  return orig(me, cls)
              end
          end
          S.actions = { function() self:AlxSpawnBeat(8) end }
      end,
      check = function(self, S)
          if S.actions and #S.actions > 0 then return nil end
          local C   = self.AlxCamp
          local now = qClock()
          local el  = now - S.stepFrom
          local unwrap = function() unwrapAlxSignal(self) end
          if not C then
              if el < 30 then return nil end
              unwrap()
              return false, "AlxSpawnBeat(8) raised no camp at all - there is nothing to judge"
          end
          if not S.beatUp then
              S.beatUp = true
              self:TortureInfo("alx_beat8_regression", string.format(
                  "beat 8 up at '%s': %d tracked, leaderId=%s, RBQ.active=%s foot=%d",
                  tostring(C.site and C.site.name), #(C.ids or {}), tostring(C.leaderId),
                  tostring(self.RBQ and self.RBQ.active), #((self.RBQ or {}).foot or {})))
          end
          if infoDue(S, 15.0) then
              self:TortureInfo("alx_beat8_regression", string.format(
                  "+%.0fs at the fort: living=%d leaderNoted=%s cleared=%s docNoted=%s downTokenSent=%s",
                  el, self:AlxLivingCount(C), tostring(C.leaderNoted), tostring(C.cleared),
                  tostring(C.docNoted), tostring(S.alxDownSeen)))
          end
          if C.leaderNoted or C.cleared or S.alxDownSeen then
              unwrap()
              return false, string.format(
                  "THE REGRESSION IS BACK: beat 8 reported progress from the Roman fort, %.0fm from its own site (leaderNoted=%s cleared=%s downTokenSent=%s at +%.0fs) - AlxProgressRange (%.0fm) is not gating it",
                  (S.fortAnchor and S.rabAnchor) and dist2(S.fortAnchor, S.rabAnchor) or -1,
                  tostring(C.leaderNoted), tostring(C.cleared), tostring(S.alxDownSeen), el,
                  self.AlxProgressRange or -1)
          end
          if el < 90 then return nil end
          unwrap()
          self:TortureInfo("alx_beat8_regression", string.format(
              "90s beside the fort with beat 8 live at Raborsch: leaderNoted=false, cleared=false, no beat-8 down token sent, %d man/men tracked",
              #(C.ids or {})))
          return true
      end },

    -- ...and the other half: the castle must actually be POPULATED when you get there. The bug
    -- report was "the castle is empty"; the beat closing itself from 3.6km away is exactly what
    -- emptied it.
    { name = "alx_beat8_populated", timeout = 180,
      run = function(self, S)
          qReset(self, S)
          local a = self:TortureQuestAnchorOf("raborsch")
          S.siteAnchor = a
          local pt, d, how = self:TortureQuestApproachPoint(a, self.TortureQuestApproachM)
          self:TortureQuestJump(S, pt, "alx_beat8_populated",
              string.format("%s, %.0fm from Raborsch", how, d))
      end,
      check = function(self, S)
          local C   = self.AlxCamp
          local now = qClock()
          local el  = now - S.stepFrom
          if posDue(S) then self:TorturePosLog(S, "alx_beat8_populated") end
          if not C then return false, "the beat-8 camp is gone before the player ever reached it" end
          local R = self.RBQ or {}
          local foot, arch = #(R.foot or {}), #(R.archers or {})
          local living = self:AlxLivingCount(C)
          if R.active and foot > 0 and living > 0 then
              self:TortureInfo("alx_beat8_populated", string.format(
                  "arrived at +%.0fs: RBQ.active=true foot=%d archers=%d, beat-8 camp %d of %d still standing, leaderNoted=%s cleared=%s",
                  el, foot, arch, living, #(C.ids or {}), tostring(C.leaderNoted), tostring(C.cleared)))
              -- Cleaned up: this beat was never opened by the journal, so nothing else will ever
              -- take it down. onLoad=true so the teardown reports no progress while doing it.
              pcall(function() self:AlxDespawnCamp(true) end)
              pcall(function() self:DespawnRaborsch() end)
              return true
          end
          if infoDue(S, 20.0) then
              self:TortureInfo("alx_beat8_populated", string.format(
                  "+%.0fs: RBQ.active=%s foot=%d, beat-8 living=%d", el, tostring(R.active), foot, living))
          end
          if el < 60 then return nil end
          pcall(function() self:AlxDespawnCamp(true) end)
          pcall(function() self:DespawnRaborsch() end)
          return false, string.format(
              "60s at Raborsch and the castle is not populated: RBQ.active=%s foot=%d archers=%d, beat-8 camp living=%d of %d",
              tostring(R.active), foot, arch, living, #(C.ids or {}))
      end },

    { name = "quest_health", timeout = 30,
      run = function(self, S) qReset(self, S) end,
      check = function(self, S)
          local KK     = self:TortureQuestKK()
          local stalls = countTable(self.FollowStallStreak)
          local poses  = countTable(self.CampPoseHoldFrom)
          local claims = countTable(self.MercTargetOf)
          local busy, why = self:PlayerBusyForSpawns()
          self:TortureInfo("quest_health", string.format(
              "squad=%d contractsPaid=%d contractActive=%s RBQ.active=%s AlxCamp=%s stallStreaks=%d poseHolds=%d claims=%d alerted=%s spawnGuard=%s(%s) camp=%s",
              squadCount(self), self:BanditCampCleared(), tostring(KK.active),
              tostring(self.RBQ and self.RBQ.active), tostring(self.AlxCamp ~= nil),
              stalls, poses, claims, tostring(self.EnemyAlerted), tostring(busy), tostring(why),
              tostring(self.CampActive)))
          if self:BanditCampCleared() ~= 12 then
              return false, "the run ends with " .. self:BanditCampCleared()
                  .. " contract(s) paid, expected 12"
          end
          if stalls > 3 then return false, stalls .. " concurrent stall streaks" end
          return true
      end },
}

mercenaries.TortureQuestStages = {
    Q1 = mercenaries.TortureQuestPlanQ1,
    Q2 = mercenaries.TortureQuestPlanQ2,
    Q3 = mercenaries.TortureQuestPlanQ3,
}

-- ---------------------------------------------------------------------------
-- starting a stage
-- ---------------------------------------------------------------------------

-- Whichever stage the loaded save's stamp names, or Q1 when it names none. The stamp is the
-- same self-validating trick the campaign's phase B uses: it exists only in the save the
-- previous stage wrote, so resuming the wrong one shows up as a timeout, never as a false pass.
function mercenaries:TortureStartQuest(autoquit)
    if self.TortureRunning then tLog("already running"); return end
    if not player then tLog("no player - not in game yet"); return end
    unwrapAlxSignal(self)

    local stamp
    pcall(function() stamp = self:LoadString("TortureStage") end)
    local stage = (stamp and self.TortureQuestStages[stamp]) and stamp or "Q1"
    self._tortureQuestStage = stage
    self._tortureQuestAuto  = (autoquit == true)

    tLog("=== torture QUEST plan: stage " .. stage .. ", "
         .. #self.TortureQuestStages[stage] .. " step(s), autoquit=" .. tostring(autoquit == true)
         .. (stamp and (", save stamp='" .. tostring(stamp) .. "'") or ", no stamp") .. " ===")

    if stage == "Q1" then
        mercenaries.TortureQuestBegin()
        return
    end
    -- Resumed from a stamped save. Clear the stamp first, exactly as phase B does - nothing may
    -- be able to re-arm off it - and give the load's own restore chain (BanditCampRestore,
    -- BanditCampResync, RaborschOnLoad, the camp restore) time to land before the first tick.
    pcall(function() self:SaveString("TortureStage", "done") end)
    pcall(function() System.ExecuteCommand("god 1") end)
    Script.SetTimerForFunction(12000, "mercenaries.TortureQuestBegin")
end

function mercenaries.TortureQuestBegin()
    local self  = mercenaries
    local stage = self._tortureQuestStage or "Q1"
    local list  = self.TortureQuestStages[stage]
    if not list then tLog("no such quest stage: " .. tostring(stage)); return end
    if self.TortureRunning then tLog("already running"); return end

    self.TortureRunning  = true
    self.TortureAutoQuit = (self._tortureQuestAuto == true)
    self.TortureSlot     = 1 - (self.TortureSlot or 0)
    local anchor = nil
    pcall(function()
        local p = player:GetWorldPos()
        anchor = { x = p.x, y = p.y, z = p.z }
    end)
    self._tortureState = {
        idx = 1, plan = list[1], planList = list, stepFrom = qClock(), startedAt = qClock(),
        anchor = anchor, pass = 0, fail = 0, skip = 0,
        deadline = self.TortureQuestDeadline, questStage = stage,
    }
    -- God and the hoist immediately, before the first tick - see TortureArmSafety.
    self:TortureArmSafety(self._tortureState, true)
    -- Scheduled raids and roaming patrols off for the whole run: a raid or a gang walking into
    -- a contract fight reads as an unrelated FAIL, and BanditCampAccept turns the patrols off
    -- for its own contracts anyway. Both are put back by TortureFinish.
    self._tortureRaidWas = self.RaidEnabled
    self.RaidEnabled = false
    self._torturePatrolWas = self.LivePatrolsEnabled
    pcall(function() self:LivePatrolSetEnabled(0) end)
    -- Every step of this plan drives Henry by SetWorldPos, `ground` or not, so the mod's own
    -- fast-travel detector stands down for the whole run (each step's qReset re-asserts it
    -- after TortureNext has set it from plan.ground).
    self.TortureDrivesPlayer = true
    tLog("stage " .. stage .. " step '" .. list[1].name .. "'")
    pcall(list[1].run, self, self._tortureState)
    Script.SetTimerForFunction(self.TortureTickMs, "mercenaries.TortureTick" .. self.TortureSlot)
end

-- Dev-gated like every other automated plan: merc_dev first, and merc_dev only works in a
-- -devmode launch. Typed into the console by the harness, never bound to a key (release
-- policy: nothing in this framework takes an F-key).
mercenaries:DevCommand("merc_torture_quest", "mercenaries:TortureStartQuest(false)",
                   "Quest plan: a Kleinkrieg playthrough across real saves and relaunches (stage from the save's stamp)")
mercenaries:DevCommand("merc_torture_quest_auto", "mercenaries:TortureStartQuest(true)",
                   "Run the quest plan's next stage and QUIT when done (harness mode)")
