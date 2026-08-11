-- Random raids on the camp.
--
-- Someone has to want the company's baggage. Every couple of days, if the player is
-- actually in camp to see it, a hostile band forms up out on the edge of the world and
-- marches in - through a gate if the camp is walled, straight at it if not.
--
-- The force is sized off the company (a raid the player cannot lose is not a raid, and
-- one he cannot win is not fun either) and drawn from the group that matches how good
-- his men are. Everything after the decision is mercenaries_wallbattle.lua's WBRaid.
-- See docs/walls-and-sieges.md.

mercenaries.RaidEnabled     = true
mercenaries.RaidDaysBetween = 2.0     -- average days between raids
mercenaries.RaidDayJitter   = 0.75    -- +/- this many days, so it is not clockwork
mercenaries.RaidShare       = 0.8     -- raiders as a fraction of the company
mercenaries.RaidMinCount    = 3
mercenaries.RaidMaxCount    = 14
mercenaries.RaidCampRange   = 45.0    -- the player must be this close to camp
mercenaries.RaidWallDist    = 120.0   -- they form up this far out when there is a wall
mercenaries.RaidNoWallDist  = 50.0    -- ...and this close when there is not
mercenaries.RaidTickMs      = 20000

-- Which enemies turn up, by how good the company is. Same mapping the old renegade
-- tiers used, so "strong company draws knights" stays consistent across the mod.
mercenaries.RaidGroupByTier = { weak = "looter", medium = "bandit", strong = "knight" }

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
-- 80% of the company, so a raid is a real fight but the defenders keep the edge the
-- wall and their archers are supposed to give them.
function mercenaries:RaidForceSize()
    local n = 0
    pcall(function() n = self:LogiAliveCount() end)
    local want = math.floor(n * self.RaidShare + 0.5)
    if want < self.RaidMinCount then want = self.RaidMinCount end
    if want > self.RaidMaxCount then want = self.RaidMaxCount end
    return want
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

function mercenaries:RaidGroup()
    return self.RaidGroupByTier[self:RaidCompanyTier()] or "bandit"
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

function mercenaries:RaidBusy()
    if (self.WBPhase or "idle") ~= "idle" then return true end
    for _, e in ipairs(self.WBRaidForce or {}) do
        if e and self:IsAliveAndWell(e, true) then return true end
    end
    return false
end

-- ==== the raid ====
function mercenaries:RaidLaunch()
    local count = self:RaidForceSize()
    local group = self:RaidGroup()
    local walled = (self.WallMarks and #self.WallMarks >= 2)
    local dist = walled and self.RaidWallDist or self.RaidNoWallDist

    raidLog(string.format("%d %s inbound (company is %s%s)",
        count, group, self:RaidCompanyTier(), walled and ", walled camp" or ", open camp"))
    local n = self:WBRaid(count .. " " .. group .. " " .. dist)
    if n and n > 0 then
        Game.SendInfoText('merc_info_raid', false, 0, 6)
        return true
    end
    return false
end

function mercenaries.RaidTick()
    local self = mercenaries
    pcall(function()
        if not self.RaidEnabled then return end
        if not self:RaidPlayerInCamp() then return end
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
    Script.SetTimerForFunction(mercenaries.RaidTickMs, "mercenaries.RaidTick")
end

function mercenaries:RaidStart()
    if self.RaidRunning then return end
    self.RaidRunning = true
    Script.SetTimerForFunction(self.RaidTickMs, "mercenaries.RaidTick")
    raidLog("watching for raid days")
end

function mercenaries:RaidStatus()
    local day = self:LogiUpkeepDay()
    raidLog("enabled: " .. tostring(self.RaidEnabled))
    raidLog(string.format("day %d, next raid on day %s", day, tostring(self.RaidNextDay or self:RaidLoadNextDay() or "?")))
    raidLog("player in camp: " .. tostring(self:RaidPlayerInCamp()) .. ", busy: " .. tostring(self:RaidBusy()))
    raidLog(string.format("next force: %d x %s (company is %s)",
        self:RaidForceSize(), self:RaidGroup(), self:RaidCompanyTier()))
end

function mercenaries:RaidSetEnabled(v)
    self.RaidEnabled = (tonumber(v) ~= 0)
    raidLog("raids " .. (self.RaidEnabled and "on" or "off"))
end

function mercenaries:RaidNow()
    if self:RaidBusy() then raidLog("a raid is already under way"); return end
    self:RaidLaunch()
    self:RaidScheduleNext(self:LogiUpkeepDay())
end

System.AddCCommand("merc_raid_now",    "mercenaries:RaidNow()",         "Launch the scheduled raid immediately")
System.AddCCommand("merc_raid_status", "mercenaries:RaidStatus()",      "When the next raid is due, and what it will be")
System.AddCCommand("merc_raid_arm",    "mercenaries:RaidSetEnabled(%line)", "Turn scheduled raids on or off: merc_raid_arm 0 | 1")
