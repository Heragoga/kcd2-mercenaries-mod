-- The quartermaster's standing bounty: clear a bandit camp, get paid, ask again.
--
-- Same shape as the Kleinkrieg contract and deliberately built on the same machinery - the
-- camp itself is spawned, watched, counted and torn down by mercenaries_banditcamp_quest.lua,
-- which now services two camps at once through its slot pointer (self.BCQ). This file owns
-- only what makes a bounty a bounty: which site it picks, what it pays, its own journal
-- quest, and its own pair of dialog gates.
--
-- Differences from Kleinkrieg, all of them deliberate:
--   * the site is drawn at RANDOM rather than walked in a fixed order,
--   * it is infinitely repeatable - there is no run to finish and no arc to close,
--   * there is no letter and no leader gear: clear the camp, report back, get paid,
--   * Kleinkrieg has first claim on the ground (BountyReservedSites / BountyYieldSite).
--
-- Kuttenberg only. See docs/bounty.md.

local function boLog(s) System.LogAlways("[Bounty] " .. s) end

local function levelName()
    for _, get in ipairs({
        function() return System.GetCurrLevelName() end,
        function() return Game.GetLevelName() end,
        function() return System.GetCurrAsyncLevelName() end,
    }) do
        local ok, v = pcall(get)
        if ok and v and v ~= "" then return tostring(v) end
    end
    return "unknown"
end

-- ==== tokens ====
-- Same two-way item-token bridge every other Skald conversation in this mod uses
-- (item__mercenaries.xml declares them all as the reusable sack-of-nails MiscItem).
mercenaries.TokenIDBountyAccept  = "679a655e-189d-4519-b437-ccc4b92bed9d"  -- dialog -> Lua
mercenaries.TokenIDBountyUp      = "679a655e-189d-4519-b437-ccc4b92bedad"  -- Lua -> Skald
mercenaries.TokenIDBountyCleared = "679a655e-189d-4519-b437-ccc4b92bedbd"  -- Lua -> Skald
mercenaries.TokenIDBountyHandIn  = "679a655e-189d-4519-b437-ccc4b92bedcd"  -- dialog -> Lua
mercenaries.TokenIDBountyPaid    = "679a655e-189d-4519-b437-ccc4b92beddd"  -- Lua -> Skald

-- The two dialog gates: is a bounty running, and is it ready to report. Each has its own set
-- and clear token for the same reason Kleinkrieg's do - Lua owns them outright instead of
-- riding on tokens whose lifetime belongs to something else.
mercenaries.TokenIDBountyOpen    = "679a655e-189d-4519-b437-ccc4b92beded"
mercenaries.TokenIDBountyShut    = "679a655e-189d-4519-b437-ccc4b92bedfd"
mercenaries.TokenIDBountyReady   = "679a655e-189d-4519-b437-ccc4b92bee0d"
mercenaries.TokenIDBountyUnready = "679a655e-189d-4519-b437-ccc4b92bee1d"

-- Everything Lua drops for Skald has to come back out of the pack once it has been seen, or
-- the next contract fires on the leftover. BanditCampSweepTokens picks this list up.
mercenaries.BountySweepTokens = {
    mercenaries.TokenIDBountyUp,    mercenaries.TokenIDBountyCleared,
    mercenaries.TokenIDBountyOpen,  mercenaries.TokenIDBountyShut,
    mercenaries.TokenIDBountyReady, mercenaries.TokenIDBountyUnready,
}

-- His own soul, so the bounty camp's map marker resolves to HIS leader and Kleinkrieg's to
-- its own. A SoulAsset marker binds to whichever NPC carries the guid, so two leaders
-- sharing one soul would leave both quests pointing at an arbitrary one of them.
mercenaries.BountyLeaderSoul = "5c8f2b91-7d34-4e06-a1f8-2b96d4e70c53"
mercenaries.BCQ_BO.leaderSoul = mercenaries.BountyLeaderSoul

-- Kuttenberg only: every authored site is there, the quest graph is registered in
-- kutnohorsko.xml, and only the Kuttenberg quartermaster dialog carries the two options.
mercenaries.BountyLevel = "kutnohorsko"

-- ==== what the job is worth ====
-- Picked by how many men will ACTUALLY turn up (BanditCampFollowerCount - the payroll asleep
-- in camp does not count), then run through BanditCampScale exactly like an arc contract.
-- A bounty pays a little over the arc's rate for the same men: it is piecework, and nobody is
-- handing over a letter at the end of it.
mercenaries.BountyTiers = {
    { upTo = 3,  group = "looter", ratio = 1.1, min = 4, archerFrac = 0.0,  payMult = 1.3 },
    { upTo = 7,  group = "bandit", ratio = 1.0, min = 5, archerFrac = 0.15, payMult = 1.3 },
    { upTo = 99, group = "sigi",   ratio = 1.1, min = 7, archerFrac = 0.20, payMult = 1.4 },
}

-- Stands in whenever the bounty slot is bound but has no descriptor of its own yet, so
-- KleinkriegContract never hands back nil.
mercenaries.BountyContractStub = { name = "bounty", group = "bandit", ratio = 1.0, min = 4,
                                  archerFrac = 0.15, payMult = 1.3 }

function mercenaries:BountyTierFor(followers)
    for _, t in ipairs(self.BountyTiers) do
        if followers <= t.upTo then return t end
    end
    return self.BountyTiers[#self.BountyTiers]
end

-- The descriptor KleinkriegContract hands out while the bounty slot is bound. Rebuilt from
-- the group alone on a reload, which is all the save blob carries and all that still matters
-- once the contract has been sized.
function mercenaries:BountyContractFor(group)
    for _, t in ipairs(self.BountyTiers) do
        if t.group == group then
            return { name = "bounty", group = t.group, ratio = t.ratio, min = t.min,
                     archerFrac = t.archerFrac, payMult = t.payMult }
        end
    end
    return self.BountyContractStub
end

-- ==== how many have been paid out ====
-- Kept only so the quartermaster's line can count them and so merc_bounty_status has
-- something to report. Nothing gates on it: the job is infinitely repeatable.
function mercenaries:BountyDone()
    if self._bountyDone == nil then
        local v
        pcall(function() v = self:LoadString("BountyDone") end)
        self._bountyDone = tonumber(v) or 0
    end
    return self._bountyDone
end

-- ==== picking the camp ====

function mercenaries:BountyLevelOK()
    local lvl = levelName()
    -- Trosky has no authored camps, no quest graph and no dialog option. The name bindings
    -- are unreliable enough to answer "unknown", and a wildcard match there would drop a
    -- camp at Kuttenberg coordinates on the wrong map - so name the one map that is allowed
    -- rather than the one that is not.
    return lvl == self.BountyLevel or lvl == "unknown"
end

-- Camps only. A patrol site is a column on a road, not somewhere to pitch a camp, and
-- raborsch is the siege - which mercenaries_raborsch.lua owns and the bounty must never
-- touch. Both carry layout "patrol", and raborsch is named out as well so a future layout
-- rename cannot quietly hand the siege to a bounty.
function mercenaries:BountyEligibleSites()
    local lvl = levelName()
    local out = {}
    for _, s in ipairs(self.BanditCampSites) do
        local sl = s.level
        local onMap = (sl == nil or sl == "" or sl == "unknown" or lvl == "unknown" or sl == lvl)
        local isCamp = (s.layout or "default") ~= "patrol" and s.route == nil
        if onMap and isCamp and s.name ~= "raborsch" then table.insert(out, s) end
    end
    return out
end

-- Kleinkrieg gets first claim on the ground. Its beats draw from this same site table, so a
-- bounty is never pitched where one is already standing.
--
-- Only the LIVE beat can be reserved: the progression is Skald's, and Lua sees nothing but the
-- camp that is currently up (self.AlxCamp). Which beat opens next is unknowable from here - the
-- yield below is what covers that, and it is why it exists.
--
-- The quartermaster's old twelve-contract run is no longer issued at all (his accept lines are
-- gone; Aleksej's nine beats are the Kleinkrieg quest), so its NEXT site is not reserved any
-- more - that would have held woodland_camp out of the pool for a contract nobody can take. A
-- contract still in flight from an older save is honoured.
function mercenaries:BountyReservedSites()
    local r = {}
    local K = self.BCQ_KK
    if K.active and K.site and K.site.name then r[K.site.name] = true end
    local A = self.AlxCamp
    if A and A.site and A.site.name then r[A.site.name] = true end
    return r
end

-- A random eligible camp. Two passes: the first also skips the site the last bounty used and
-- anything close enough to be underfoot, and only if that leaves nothing does it fall back to
-- the bare reservations - a repeat beats refusing the job.
-- `avoid` names one more site to stay off (BountyYieldSite passes the one it is vacating).
function mercenaries:BountyPickSite(avoid)
    local sites = self:BountyEligibleSites()
    if #sites == 0 then return nil end
    local reserved = self:BountyReservedSites()
    local last = self.BCQ_BO.lastSite
    local p = player and player:GetWorldPos()

    local function gather(strict)
        local out = {}
        for _, s in ipairs(sites) do
            local ok = not reserved[s.name] and s.name ~= avoid
            if ok and strict then
                if s.name == last then ok = false end
                if ok and p then
                    local a = self:BanditCampSiteAnchor(s)
                    local d = math.sqrt((a.x - p.x) ^ 2 + (a.y - p.y) ^ 2)
                    if d <= self.BanditCampForgetRange then ok = false end
                end
            end
            if ok then table.insert(out, s) end
        end
        return out
    end

    local pool = gather(true)
    if #pool == 0 then pool = gather(false) end
    if #pool == 0 then return nil end
    return pool[math.random(#pool)]
end

-- ==== taking the job ====

function mercenaries:BountyAccept()
    local B = self.BCQ_BO
    if B.active then
        Game.SendInfoText('merc_info_bounty_already', false, 0, 4)
        return
    end
    if not self:BountyLevelOK() then
        Game.SendInfoText('merc_info_bounty_nosite', false, 0, 5)
        boLog("no bounty work on '" .. levelName() .. "'")
        return
    end

    local site = self:BountyPickSite()
    if not site then
        Game.SendInfoText('merc_info_bounty_nosite', false, 0, 5)
        boLog("no free camp to offer: every eligible site is reserved by Kleinkrieg")
        return
    end

    local F = self:BanditCampFollowerCount()
    B.contract = self:BountyContractFor(self:BountyTierFor(F).group)

    -- Bound, because BanditCampScale sizes through KleinkriegContract() - which is what hands
    -- back the descriptor above - and BanditCampSave writes this slot's blob.
    self:BanditCampWith(B, function()
        local group, count, archers, reward = self:BanditCampScale()

        B.active, B.site, B.group = true, site, group
        -- Every per-contract flag reset explicitly, the same discipline the arc's accept
        -- learned the hard way: a stale `paid` closes the next job unpaid the moment the
        -- player walks away from the camp they just cleared.
        B.paid, B.cleared, B.spawned, B.leaderDead = false, false, false, false
        -- No letter on a bounty, so the "find it" leg is closed before it can open.
        B.letterTaken, B.letterGranted, B.letterOnLeader, B.warnedLetter = true, true, false, false
        B.target, B.killed, B.reward, B.archers = count, 0, reward, archers
        B.entities, B.bandits, B.spots, B.actorSet = {}, {}, {}, {}
        B.health, B.missing, B.chatCooldown, B.alerted = {}, {}, {}, false
        B.letterChestPlaced, B.letterChestId = false, nil
        B.chestStocked, B.stockTries = false, 0

        boLog(string.format("%s: %d %s, %d archer(s), %d groschen (%d follower(s))",
              tostring(site.name), count, tostring(group), archers, reward, F))

        -- Not spawned here. The camp is somewhere else on the map; BanditCampService builds
        -- it once the player is inside BanditCampForgetRange.
        self:BanditCampSave()
    end)

    self:BanditCampSignal(self.TokenIDBountyUp)
    self:BountySyncGates()
    Game.SendInfoText('merc_info_bounty_taken', false, 0, 5)
end

-- ==== reporting back ====

function mercenaries:BountyReport()
    local B = self.BCQ_BO
    if not (B.active and B.cleared) then
        Game.SendInfoText('merc_info_bounty_notdone', false, 0, 4)
        return
    end
    if B.paid then return end

    self:GiveMoney(B.reward or 0)
    B.paid = true
    B.lastSite = B.site and B.site.name

    self._bountyDone = self:BountyDone() + 1
    pcall(function() self:SaveString("BountyDone", tostring(self._bountyDone)) end)

    self:BanditCampSignal(self.TokenIDBountyPaid)
    -- Straight away rather than on the next monitor tick: the player is still in the dialog,
    -- and the option they just used has to stop being offered before it can be picked twice.
    self:BountySyncGates()
    self:BanditCampWith(B, function() self:BanditCampSave() end)

    Game.SendInfoText('merc_info_bounty_paid', false, 0, 6)
    boLog(string.format("paid %d groschen for %s (%d bounties done)",
          B.reward or 0, tostring(B.lastSite), self._bountyDone))
end

-- ==== dialog gates ====
-- Pushed whenever they change. _boOpen/_boReady start nil, so the first tick after a load
-- re-asserts both and the dialog cannot come back out of step with the contract.
function mercenaries:BountySyncGates()
    local B = self.BCQ_BO
    -- `open` tracks B.active, NOT "unpaid": a paid bounty stays active until its camp has
    -- been torn down (the props wait for the player to walk BanditCampDespawnRange away), and
    -- offering a new one before then would repoint the slot and strand the old camp's props
    -- in the world with nothing tracking them. This is exactly the guard BountyAccept uses,
    -- so the dialog and Lua can never disagree about whether a job can be taken.
    local open  = (B.active == true)
    local ready = (open and B.cleared == true and B.paid ~= true)
    if self._boOpen ~= open then
        self:BanditCampSignal(open and self.TokenIDBountyOpen or self.TokenIDBountyShut)
        self._boOpen = open
    end
    if self._boReady ~= ready then
        self:BanditCampSignal(ready and self.TokenIDBountyReady or self.TokenIDBountyUnready)
        self._boReady = ready
        boLog("report " .. (ready and "available" or "not available"))
    end
end

-- ==== Kleinkrieg's first claim ====
-- Called from AlxSpawnBeat the moment a Kleinkrieg beat picks its ground (and from
-- BanditCampAccept, for a legacy arc contract still in flight). The reservation above cannot
-- cover this on its own: which beat opens next is Skald's business and invisible from Lua, so
-- the collision has to be resolved when it actually happens.
function mercenaries:BountyYieldSite(siteName)
    local B = self.BCQ_BO
    if not (B.active and B.site and B.site.name == siteName) then return end

    -- Already cleared: nothing is left but the walk home, so the props can simply come down
    -- and the arc can have the ground. `true` keeps the contract alive for the report.
    if B.cleared then
        self:BanditCampWith(B, function() self:DespawnBanditCamp(true) end)
        boLog("bounty camp cleared away so Kleinkrieg can use " .. tostring(siteName))
        return
    end

    local site = self:BountyPickSite(siteName)
    if not site then
        -- Nowhere else to put it. Two contracts counting kills at one camp would pay out both
        -- on one fight, so the bounty is called off instead - unpaid, and the journal entry
        -- closes with it.
        self:BanditCampWith(B, function() self:DespawnBanditCamp(false) end)
        B.contract = nil
        self:BanditCampSignal(self.TokenIDBountyPaid)
        self:BountySyncGates()
        Game.SendInfoText('merc_info_bounty_calledoff', false, 0, 6)
        boLog("bounty called off: no free camp left once Kleinkrieg took " .. tostring(siteName))
        return
    end

    self:BanditCampWith(B, function()
        self:DespawnBanditCamp(true)
        B.site = site
        -- A fresh camp: the old one's dead do not carry over, and its leader is gone with it.
        B.killed, B.leaderId, B.leaderDead, B.alerted = 0, nil, false, false
        B.spawned = false
        self:BanditCampSave()
    end)
    Game.SendInfoText('merc_info_bounty_moved', false, 0, 6)
    boLog("bounty moved to " .. tostring(site.name) .. "; Kleinkrieg took " .. tostring(siteName))
end

-- ==== console ====

function mercenaries:BountyStatus()
    local B = self.BCQ_BO
    boLog(string.format("%d bounty contract(s) paid; %d camp(s) eligible here",
          self:BountyDone(), #self:BountyEligibleSites()))
    if not B.active then
        local res = {}
        for name in pairs(self:BountyReservedSites()) do table.insert(res, name) end
        boLog("no bounty running; Kleinkrieg holds: " .. table.concat(res, ", "))
        return
    end
    boLog(string.format("site=%s group=%s %d/%d killed reward=%d spawned=%s cleared=%s alerted=%s paid=%s",
          tostring(B.site and B.site.name), tostring(B.group), B.killed or 0, B.target or 0,
          B.reward or 0, tostring(B.spawned), tostring(B.cleared), tostring(B.alerted),
          tostring(B.paid)))
end

function mercenaries:BountyAbandon()
    local B = self.BCQ_BO
    if not B.active then boLog("no bounty running"); return end
    self:BanditCampWith(B, function() self:DespawnBanditCamp(false) end)
    B.cleared, B.contract = false, nil
    self:BanditCampSignal(self.TokenIDBountyPaid)
    self:BountySyncGates()
    boLog("bounty abandoned and camp removed")
end

function mercenaries:BountyForceClear()
    local B = self.BCQ_BO
    if not B.active then boLog("no bounty running"); return end
    self:BanditCampWith(B, function() self:BanditCampComplete() end)
end

mercenaries:DevCommand("merc_bounty_start",   "mercenaries:BountyAccept()",  "Take a bandit-camp bounty (same as the quartermaster dialog)")
mercenaries:DevCommand("merc_bounty_status",  "mercenaries:BountyStatus()",  "Bounty state: site, group, kills, reward")
mercenaries:DevCommand("merc_bounty_report",  "mercenaries:BountyReport()",  "Report the bounty in and collect (debug)")
mercenaries:DevCommand("merc_bounty_clear",   "mercenaries:BountyForceClear()", "Force-complete the bounty camp (debug)")
mercenaries:DevCommand("merc_bounty_abandon", "mercenaries:BountyAbandon()", "Drop the bounty and remove its camp")
mercenaries:DevCommand("merc_bounty_reset",   "mercenaries:SaveString('BountyDone','0')", "Zero the paid-bounty counter (debug)")
