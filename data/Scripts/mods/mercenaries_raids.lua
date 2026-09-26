-- Random raids on the camp.
--
-- Someone has to want the company's baggage. Every couple of days, if the player is
-- actually in camp to see it, a hostile band forms up out on the edge of the world and
-- marches in - through a gate if the camp is walled, straight at it if not.
--
-- The force is sized off the company (a raid the player cannot lose is not a raid, and
-- one he cannot win is not fun either) and drawn from the group that matches how good
-- his men are. Everything after the decision is mercenaries_wallbattle.lua's WBRaid.
--
-- If the camp has a gate they always make for it, gather in front of it, and force it
-- open when the fight opens - barring the gate buys time to form up, not immunity.
-- See docs/walls-and-sieges.md.

mercenaries.RaidEnabled     = true
mercenaries.RaidDaysBetween = 2.0     -- average days between raids
mercenaries.RaidDayJitter   = 0.75    -- +/- this many days, so it is not clockwork
mercenaries.RaidMinCount    = 3
mercenaries.RaidMaxCount    = 14
mercenaries.RaidCampRange   = 45.0    -- the player must be this close to camp
-- A camp has to settle before anyone marches on it: it must have STOOD for
-- RaidCampGraceHours of world time, and the player must have been IN it for RaidDwellSecs
-- of REAL time unbroken, which a sleep, a wait or a fast travel resets. See
-- docs/walls-and-sieges.md, "A camp has to settle first".
mercenaries.RaidCampGraceHours = 12.0
mercenaries.RaidDwellSecs      = 60.0
-- World seconds per real second above which the clock was SKIPPED rather than run. This
-- build's normal ratio is 15 (measured, see mercenaries_travelwatch.lua).
mercenaries.RaidSkipRatio      = 40.0
mercenaries.RaidCampPitchTag   = "QMRaidCampAt"
-- Which groups have raided lately, so they take turns (PickRotatingGroup). Saved: raids
-- are days apart and a reload in between must not wipe the memory.
mercenaries.RaidRecentTag      = "QMRaidRecent"
mercenaries.RaidWallDist    = 120.0   -- they form up this far out when there is a wall
mercenaries.RaidNoWallDist  = 50.0    -- ...and this close when there is not
mercenaries.RaidTickMs      = 20000

-- Who turns up: drawn at random, every group equally likely. What differs is `share` -
-- how many of them per man in the company - because the groups are nowhere near each
-- other in worth. Knights at even numbers would be a massacre and looters at even
-- numbers a warm-up, so the count is what levels them: half a dozen knights and a full
-- dozen looters are both a fight for the same company.
mercenaries.RaidRoster = {
    { group = "knight", share = 0.5 },   -- Sigismund's knights: elite, health-boosted
    { group = "sigi",   share = 0.6 },   -- Sigismund's soldiers
    { group = "prague", share = 0.6 },   -- the Prague regiment, Kuttenberg's own
    { group = "cuman",  share = 0.7 },   -- Cumans
    { group = "bandit", share = 1.0 },   -- Bandits
    { group = "looter", share = 1.0 },   -- Looters
}

local function raidLog(s) System.LogAlways("[Raids] " .. s) end

-- ==== when ====
function mercenaries:RaidLoadNextDay()
    local s = self:LoadString("QMRaidNextDay")
    return tonumber(s or "")
end

function mercenaries:RaidSetNextDay(d)
    self.RaidNextDay = d
    self:SaveString("QMRaidNextDay", tostring(d))
end

function mercenaries:RaidScheduleNext(fromDay)
    local jitter = (math.random() * 2 - 1) * self.RaidDayJitter
    self:RaidSetNextDay(fromDay + self.RaidDaysBetween + jitter)
end

-- ==== who ====
-- How many of this group it takes to make a fight of it against the living company,
-- clamped so a four-man camp is not walked over and a full one is not besieged.
-- A raid is fought by the WHOLE company, including the men asleep in camp, so the
-- strength this is sized against is the full living roster and not the sortie.
function mercenaries:RaidForceSize(share)
    local n = 0
    pcall(function() n = self:LogiAliveCount() end)
    local want = math.floor(n * (share or 1.0) + 0.5)
    -- The tier scales the band and caps how badly the company may be outnumbered.
    pcall(function() want = self:DifficultyCount(want, n, self.RaidMinCount) end)
    if want < self.RaidMinCount then want = self.RaidMinCount end
    -- The ceiling rises with the tier, or a horde is clipped straight back to 14.
    local ceil_ = self.RaidMaxCount
    pcall(function() ceil_ = self:DifficultyCeil(self.RaidMaxCount) end)
    if want > ceil_ then want = ceil_ end
    return want
end

-- Roll the raid: which group, and how many of them. One call, because the size only
-- means anything alongside the group it was rolled for.
function mercenaries:RaidPick()
    local roster = self.RaidRoster or {}
    if #roster == 0 then return "bandit", self:RaidForceSize(1.0), 1.0 end
    -- Not a flat draw: the same banner twice running reads as one enemy rather than a
    -- world with six in it. PickRotatingGroup skips whoever raided last (mercenaries_spawning.lua).
    local r = self:PickRotatingGroup("raid", roster,
                                     function(e) return e.group end, self.RaidRecentTag)
              or roster[math.random(1, #roster)]
    return r.group, self:RaidForceSize(r.share), (r.share or 1.0)
end

-- The company's average quality, as one of the three tier names.
function mercenaries:RaidCompanyTier()
    local c = { weak = 0, medium = 0, strong = 0, total = 0 }
    pcall(function() c = self:LogiCountByTier() end)
    if (c.total or 0) == 0 then return "weak" end
    local score = (c.weak * 1 + c.medium * 2 + c.strong * 3) / c.total
    if score >= 2.5 then return "strong" end
    if score >= 1.5 then return "medium" end
    return "weak"
end

-- ==== conditions ====
-- A raid nobody is there to fight is just a pack of bandits standing in a field, so it
-- only fires with the player in camp. It also waits for any current fight to finish.
function mercenaries:RaidPlayerInCamp()
    if not (self.CampActive and self.CampCenter and player) then return false end
    local p
    pcall(function() p = player:GetWorldPos() end)
    if not p then return false end
    local dx, dy = p.x - self.CampCenter.x, p.y - self.CampCenter.y
    return (dx * dx + dy * dy) <= (self.RaidCampRange * self.RaidCampRange)
end

-- REAL seconds. System.GetCurrTime runs on the engine clock, which a wait or a sleep runs
-- ~29x fast - exactly the case the dwell has to notice - so the wall clock is used instead.
local raidRealClock = (os and os.clock) or function() return 0 end

-- Stamped when the camp is PITCHED. Not when it is rebuilt from the saved anchor on a
-- load, or when buying an upgrade takes it down and puts it straight back up: the same
-- camp coming back is not a new camp. Called from SpawnMercCamp.
function mercenaries:RaidNoteCampPitched(fresh)
    self._raidInCampSince = nil          -- a new camp is also a fresh minute to stand in it
    if not fresh then return end
    local t = self:LogiNow()
    self.RaidCampAt = t
    pcall(function() self:SaveString(self.RaidCampPitchTag, tostring(math.floor(t))) end)
    raidLog(string.format("camp pitched - no raid for %.0f in-game hours", self.RaidCampGraceHours))
end

-- World hours the camp has stood, or nil for a camp that was already up before any of
-- this existed - which counts as settled rather than blocking raids on it for ever.
function mercenaries:RaidCampStoodHours()
    if not self.RaidCampAt then
        local s
        pcall(function() s = self:LoadString(self.RaidCampPitchTag) end)
        self.RaidCampAt = tonumber(s or "")
        if not self.RaidCampAt then return nil end
    end
    local h = (self:LogiNow() - self.RaidCampAt) / 3600.0
    -- The clock went backwards (an older save loaded): re-stamp rather than treat a
    -- negative age as settled.
    if h < 0 then self.RaidCampAt = self:LogiNow(); return 0 end
    return h
end

-- Real seconds the player has stood in camp without a break. Must be called EVERY tick,
-- before any other gate: this is also what notices him leaving, and a version that only
-- ran while he was in camp kept a stale start time across an hour on the road.
function mercenaries:RaidDwellUpdate()
    local now, wt = raidRealClock(), self:LogiNow()
    local lastR, lastW = self._raidClockReal, self._raidClockWorld
    self._raidClockReal, self._raidClockWorld = now, wt

    if not self:RaidPlayerInCamp() then self._raidInCampSince = nil; return 0 end

    -- The world clock outrunning the wall clock is a sleep, a wait or a fast travel. The
    -- minute in camp has to be a minute he actually sat through.
    if lastR and lastW then
        local dtR, dtW = now - lastR, wt - lastW
        if dtR > 0.05 and (dtW / dtR) > self.RaidSkipRatio then
            self._raidInCampSince = nil
            return 0
        end
    end

    if not self._raidInCampSince then self._raidInCampSince = now; return 0 end
    return now - self._raidInCampSince
end

-- Everything above is session state about a camp and a clock that both belong to the save
-- just left: the dwell must not survive a load (the loading screen alone would pay for it),
-- and the two saved values have to be read again out of the save just loaded.
function mercenaries:RaidOnLoad()
    self._raidInCampSince, self._raidClockReal, self._raidClockWorld = nil, nil, nil
    self.RaidCampAt  = nil
    self.RaidNextDay = nil
    self.EnemyRecent = self.EnemyRecent or {}
    self.EnemyRecent["raid"] = nil
end

-- Shut gates no longer call the raid off. A raid marches on a gate whether it is barred
-- or not: it forms up in front of it, and the assault forces it open (WBForceGates).
-- Kept as a status line only - merc_raid_status still reports whether the camp is shut.
function mercenaries:RaidSealed()
    return (self.GateAllClosed ~= nil) and self:GateAllClosed()
end

-- A raid that has been standing this long is not a raid any more, whatever the wall
-- battle still thinks. Something wedged, or a handful of raiders broke off and wandered,
-- and neither may stop the company ever being raided again - RaidTick gates every
-- scheduled raid on RaidBusy, so a force that never dies is a permanent stop.
mercenaries.RaidStaleSecs = 300.0

function mercenaries:RaidBusy()
    -- Checked FIRST, and it clears the force rather than merely ignoring it: leaving a
    -- stale band standing about while a fresh one marches in stacks two raids on the camp.
    local at = self.WBRaidAt
    if at and self.WBRaidForce then
        local now = 0
        pcall(function() now = System.GetCurrTime() or 0 end)
        if (now - at) > self.RaidStaleSecs then
            raidLog(string.format("the last raid has been standing %.0fs - clearing it",
                                  now - at))
            pcall(function() self:WBRaidClear() end)
            return false
        end
    end

    if (self.WBPhase or "idle") ~= "idle" then return true end
    for _, e in ipairs(self.WBRaidForce or {}) do
        if e and self:IsAliveAndWell(e, true) then return true end
    end
    return false
end

-- ==== the raid ====
function mercenaries:RaidLaunch()
    local group, count, share = self:RaidPick()
    local walled = self:WallHasAny()
    local dist = walled and self.RaidWallDist or self.RaidNoWallDist

    raidLog(string.format("%d %s inbound at %.1f/man (company is %s%s)",
        count, group, share, self:RaidCompanyTier(), walled and ", walled camp" or ", open camp"))
    local n = self:WBRaid(count .. " " .. group .. " " .. dist)
    if n and n > 0 then
        Game.SendInfoText('merc_info_raid', false, 0, 6)
        return true
    end
    return false
end

-- The 5,472-timer save flood (see the SchedOnLoad block in mercenaries_scheduler.lua)
-- was this function's old self-arming chain compounding across saves. The bare
-- "mercenaries.RaidTick" name is now a drain tombstone (ChainDef below), so restored
-- timers from any infected save are counted and retired without running a thing.
function mercenaries.RaidTickBody()
    local self = mercenaries
    self._ftRaid = (self._ftRaid or 0) + 1
    pcall(function()
        if not self.RaidEnabled then return end
        -- The quartermaster's master switch for uninvited trouble.
        if self.EncountersOn and not self:EncountersOn() then return end
        -- Every tick, ahead of every other gate: this is the call that tracks him leaving
        -- camp and that resets on a time skip. It answers 0 when he is not in camp at all,
        -- which is the old RaidPlayerInCamp gate as well.
        if self:RaidDwellUpdate() < self.RaidDwellSecs then return end
        -- ...and the camp itself must have stood a while. A band does not hear of a camp,
        -- gather and march on it inside the hour it went up.
        local stood = self:RaidCampStoodHours()
        if stood and stood < self.RaidCampGraceHours then return end
        if self:RaidBusy() then return end

        local day = self:LogiUpkeepDay()
        if not self.RaidNextDay then
            self.RaidNextDay = self:RaidLoadNextDay()
            -- first camp of a playthrough: give the player a couple of days' grace
            if not self.RaidNextDay then self:RaidScheduleNext(day); return end
        end
        -- clock moved backwards (a load from an older save): re-arm rather than fire
        if day + self.RaidDaysBetween + self.RaidDayJitter < self.RaidNextDay then
            self:RaidScheduleNext(day)
            return
        end
        if day < self.RaidNextDay then return end

        if self:RaidLaunch() then self:RaidScheduleNext(day) end
    end)
end

-- Re-armed only when this is the legacy private chain. Under the master scheduler the
-- "raids" slot calls RaidTickBody and owns the cadence - measured at 3x its armed
-- interval when it drove itself, the same fault the patrol tick had.
function mercenaries:RaidTickDrive()
    mercenaries.RaidTickBody()
    if not self.SchedEnabled then
        self:ChainArm("RaidTick", self.RaidTickMs)
    end
end
mercenaries:ChainDef("RaidTick", "RaidTickDrive")

function mercenaries:RaidStart()
    if self.RaidRunning then return end
    self.RaidRunning = true
    if self.SchedEnabled then
        raidLog("watching for raid days (on the master tick)")
        return
    end
    self:ChainArm("RaidTick", self.RaidTickMs)
    raidLog("watching for raid days")
end

function mercenaries:RaidStatus()
    local day = self:LogiUpkeepDay()
    raidLog("enabled: " .. tostring(self.RaidEnabled))
    raidLog(string.format("day %d, next raid on day %s", day, tostring(self.RaidNextDay or self:RaidLoadNextDay() or "?")))
    raidLog("player in camp: " .. tostring(self:RaidPlayerInCamp()) .. ", busy: " .. tostring(self:RaidBusy())
        .. ", gates sealed: " .. tostring(self:RaidSealed()))
    local stood = self:RaidCampStoodHours()
    raidLog(string.format("camp has stood %s of %.0f in-game hours; %.0fs of %.0fs stood in it",
        stood and string.format("%.1f", stood) or "?", self.RaidCampGraceHours,
        self._raidInCampSince and (raidRealClock() - self._raidInCampSince) or 0,
        self.RaidDwellSecs))
    local recent = self:EnemyRecentList("raid", self.RaidRecentTag)
    raidLog("last to raid (they will not draw again yet): " ..
        (#recent > 0 and table.concat(recent, ", ") or "nobody"))
    -- The group is rolled at launch, so the best status can do is show the whole draw.
    local parts = {}
    for _, r in ipairs(self.RaidRoster or {}) do
        table.insert(parts, string.format("%d %s", self:RaidForceSize(r.share), r.group))
    end
    raidLog(string.format("company is %s; the draw is one of: %s",
        self:RaidCompanyTier(), table.concat(parts, ", ")))
end

function mercenaries:RaidSetEnabled(v)
    self.RaidEnabled = (tonumber(v) ~= 0)
    raidLog("raids " .. (self.RaidEnabled and "on" or "off"))
end

-- The console order to raid NOW. It REPLACES whatever is still standing rather than
-- refusing: this command exists to make a raid happen, and "a raid is already under way"
-- is not that - it is the answer that made the second merc_raid_now look like raids had
-- stopped working. The scheduled path (RaidTick) still defers to RaidBusy, because a
-- raid landing on top of the one the player is fighting is not something the clock
-- should be able to do on its own.
function mercenaries:RaidNow()
    if self:RaidBusy() then
        raidLog("a raid is still under way - clearing it and launching a fresh one")
        pcall(function() self:WBRaidClear() end)
    end
    self:RaidLaunch()
    self:RaidScheduleNext(self:LogiUpkeepDay())
end

mercenaries:DevCommand("merc_raid_status", "mercenaries:RaidStatus()",      "When the next raid is due, and what it will be")
mercenaries:DevCommand("merc_enemy_rotation", "mercenaries:EnemyRotationStatus()", "Which enemy groups raided and patrolled last (they will not draw again yet)")
mercenaries:DevCommand("merc_raid_arm",    "mercenaries:RaidSetEnabled(%line)", "Turn scheduled raids on or off: merc_raid_arm 0 | 1")
