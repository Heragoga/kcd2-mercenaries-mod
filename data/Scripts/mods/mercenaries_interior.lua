-- Is the player inside a building?
--
-- This asks the engine rather than guessing. KCD2 tags the enterable volume of its
-- building prefabs with an area label called `interior`, and that same label is what the
-- shipped InteriorCrouch / ExteriorCrouch / InteriorDrunk stealth buffs test. So the
-- answer here is the game's own answer, not a raycast approximation of it.
--
-- What it drives: the men who are ACTIVELY FOLLOWING are parked where they stand when
-- the player steps into a building, and only those same men are released when he comes
-- back out. Anyone who was already doing something else - camping, holding a station,
-- fighting, walking a nav order - is never touched, and so is never "restored" into a
-- follow he was not on. See InteriorParkFollowers.
--
-- `interior` means "inside a real, enterable building" - it is NOT "under a roof". It
-- misses castles and churches, porches and gate passages, and everything the mod spawns
-- itself (camp tents, the player house). For shelter, CampDetectRoof is the right test.
-- The full write-up, including the behaviour-tree and Skald routes for when this drives
-- gameplay instead of a log line, is docs/interior-detection.md.

local function inLog(s) System.LogAlways("[Interior] " .. tostring(s)) end

-- Real seconds. The engine clock runs at game rate and collapses during a sleep or a
-- wait, which would report an hour indoors for a three-second visit.
local realClock = (os and os.clock) or function() return 0 end

mercenaries.InteriorEnabled = true
mercenaries.InteriorLabel   = "interior"
mercenaries.InteriorVerbose = false     -- log every sample, not just the edges

-- Two agreeing samples before an edge is believed. Area membership flickers on the
-- threshold of a doorway, and one line per flicker is not a log worth reading.
mercenaries.InteriorConfirm = 2

-- Probed once per entry, never per tick: they say WHAT kind of building it is. Any of
-- these that answers true is printed on the enter line.
mercenaries.InteriorContextLabels = {
    "private", "personal", "semipersonal", "semipublic", "public", "household",
    "kitchen", "cellar", "attic", "pantry", "barn", "workshop", "office", "bedside",
    "castle", "settlement", "prohibited",
}

mercenaries.InteriorState = nil     -- nil until the first confirmed sample

-- ---------------------------------------------------------------------------
-- Parking the followers at the door
-- ---------------------------------------------------------------------------
mercenaries.InteriorParkMercs = true    -- the behaviour; the log runs either way
mercenaries.InteriorParked    = mercenaries.InteriorParked or {}   -- [wuidStr] = true
mercenaries.InteriorSuppress  = false   -- an explicit "follow me" beat the doorway

-- A man's scheduler must have run this recently for his follow latch to mean anything.
mercenaries.InteriorSchedFresh = 3.0

local function playerWuid()
    if not player then return nil end
    return (player.this and player.this.id) or player.id
end

-- The one engine call. true / false, or NIL when the bind does not answer - and nil must
-- never be collapsed into "outdoors", which is how a detector ends up looking alive while
-- reporting nothing (see docs/travel-detection.md for the version of that bug we shipped).
function mercenaries:InteriorHasLabel(wuid, label)
    if not (wuid and label) then return nil end
    if not (XGenAIModule and XGenAIModule.IsPointInAreaWithLabelWUID) then return nil end
    local v
    local ok = pcall(function() v = XGenAIModule.IsPointInAreaWithLabelWUID(wuid, label) end)
    if not ok or v == nil then return nil end
    return v and true or false
end

-- Every context label that answers true at the player's position, as "private, household".
function mercenaries:InteriorContextOf(wuid)
    local hits = {}
    for _, l in ipairs(self.InteriorContextLabels or {}) do
        if self:InteriorHasLabel(wuid, l) then hits[#hits + 1] = l end
    end
    if #hits == 0 then return "none" end
    return table.concat(hits, ", ")
end

local function posStr(p)
    if not p then return "?" end
    return string.format("%.1f, %.1f, %.1f", p.x or 0, p.y or 0, p.z or 0)
end

local function mercKey(ent)
    local w = ent and ((ent.this and ent.this.id) or ent.id)
    return w and tostring(w) or nil
end

-- Is this man ACTIVELY FOLLOWING right now - not merely enrolled in the company?
--
-- The answer is the mod's own, not a new one: FollowGate republishes every merc's
-- `$isFollowingActive` into FollowLatchOf on each scheduler tick, and that latch is true
-- only while the follow tree is the behaviour running on him. A merc who is fighting,
-- camping, walking a nav order or standing on a hold station reads false, which is
-- exactly the set that must not be parked - and, on the way out, must not be "restored"
-- into a follow he was never on.
function mercenaries:InteriorIsFollowing(ent)
    local k = mercKey(ent)
    if not k then return false end
    if not self:IsAliveAndWell(ent, false) then return false end
    -- camp_actor carries its own follow arm, and the scheduler's idle branch skips camp
    -- actors outright (`$isIdle & ~$isCampActor`), so parking one sets a flag nothing reads.
    if self:IsCampActor((ent.this and ent.this.id) or ent.id) then return false end
    -- NOT MercIsIdle: that is the behaviour trees' own entry point and it stamps
    -- BtHeartbeatAt, which the follow watch reads as proof the trees are ticking. Calling
    -- it from Lua would forge that proof. The two states it would have caught here - a
    -- global idle and a hold station - are squad-wide and already turned away by
    -- InteriorParkBlocked, so nothing is lost.
    local schedAt = (self.FollowSchedAt or {})[k]
    if not schedAt then return false end
    local now = 0
    pcall(function() now = System.GetCurrTime() or 0 end)
    if (now - schedAt) > (self.InteriorSchedFresh or 3.0) then return false end
    return (self.FollowLatchOf or {})[k] == true
end

-- Squad-wide states in which the doorway has no business giving orders.
function mercenaries:InteriorParkBlocked()
    if not self.InteriorParkMercs then return "parking off" end
    if _G.MercenariesDismissed then return "dismissed" end
    if _G.MercIdle then return "squad already idle" end
    if self.HoldActive then return "hold order standing" end
    if self.EscortEnt then return "escort order standing" end
    if self.WBPhase and self.WBPhase ~= "idle" then return "battle in progress" end
    return nil
end

function mercenaries:InteriorParkFollowers()
    if self.InteriorSuppress then return 0, "follow order overrides the door" end
    local blocked = self:InteriorParkBlocked()
    if blocked then return 0, blocked end

    local n = 0
    for _, ent in pairs(self.ActiveMercs or {}) do
        local following = false
        pcall(function() following = self:InteriorIsFollowing(ent) end)
        if following then
            local k = mercKey(ent)
            if k then self.InteriorParked[k] = true; n = n + 1 end
        end
    end
    return n, nil
end

function mercenaries:InteriorParkedCount()
    local n = 0
    for _ in pairs(self.InteriorParked or {}) do n = n + 1 end
    return n
end

-- Release EXACTLY the men this parked, and nobody else.
function mercenaries:InteriorReleaseParked(why)
    local n = self:InteriorParkedCount()
    self.InteriorParked = {}
    if n == 0 then return 0 end

    -- No FollowStalled here, and that is deliberate. Parking a man ran the scheduler's
    -- idle arm, which already evicted his follow tree and cleared his latch - so he
    -- re-fires follow by himself the moment MercIsIdle goes false. A second eviction
    -- queued on top lands ON that re-fire and pins him standing for good; that is the
    -- bug HoldReleaseAll documents at length, and it cost a third of the squad.
    --
    -- The two things that are safe at fifty men are the two HoldReleaseAll keeps: a
    -- staggered start, so the interrupts do not all land in the same half second, and a
    -- verification window that re-fires anyone who demonstrably fails to walk.
    pcall(function() self:FollowStaggerSquad() end)
    pcall(function() self:BeginFollowVerify("interior release") end)
    inLog(string.format("released %d man/men (%s)", n, why or "left the building"))
    return n
end

-- Every tick, parked or not: anything that takes the squad out of a plain follow hands
-- them back, and a man who died or left the roster stops being ours.
function mercenaries:InteriorParkMaintain()
    if self:InteriorParkedCount() == 0 then return end

    local blocked = (not self.InteriorEnabled) and "detection off" or self:InteriorParkBlocked()
    if blocked then self:InteriorReleaseParked(blocked); return end

    local live = {}
    for _, ent in pairs(self.ActiveMercs or {}) do
        local k = mercKey(ent)
        if k then live[k] = ent end
    end
    for k in pairs(self.InteriorParked) do
        local ent = live[k]
        local ok = false
        if ent then pcall(function() ok = self:IsAliveAndWell(ent, true) end) end
        if not ok then self.InteriorParked[k] = nil end
    end
end

-- An explicit order beats the doorway. Called from SetState and SetSortieWait.
function mercenaries:InteriorOrderOverride(state)
    local n = self:InteriorParkedCount()
    -- Cleared without the stagger/verify of InteriorReleaseParked: the order itself is
    -- about to do both, and doing them twice is the double-eviction that pins men.
    self.InteriorParked = {}
    if state == "follow" then
        -- ...and the door does not get to park them again until he has been outside once.
        self.InteriorSuppress = (self.InteriorState == true)
        if n > 0 then inLog(n .. " man/men released with the follow order") end
    else
        self.InteriorSuppress = false
        if n > 0 then inLog(n .. " man/men released by an explicit order") end
    end
end

-- Nothing here survives a load: the behaviour trees come back fresh, so no merc is
-- parked and the first sample re-establishes where the player is.
function mercenaries:InteriorOnLoad()
    self.InteriorParked   = {}
    self.InteriorSuppress = false
    self.InteriorState    = nil
    self._interiorRaw, self._interiorRun, self._interiorNoAnswer = nil, nil, nil
    self._interiorSince = nil
end

function mercenaries:InteriorTick()
    if not self.InteriorEnabled then self:InteriorParkMaintain(); return end

    local wuid = playerWuid()
    if not wuid then return end

    self:InteriorParkMaintain()

    local pos
    pcall(function() pos = player:GetWorldPos() end)

    local inside = self:InteriorHasLabel(wuid, self.InteriorLabel)

    if inside == nil then
        -- Not on the first miss: the player entity can exist a beat before the area
        -- system will answer for it. Five in a row is the bind genuinely not being there.
        self._interiorNoAnswer = (self._interiorNoAnswer or 0) + 1
        if self._interiorNoAnswer == 5 then
            inLog("XGenAIModule.IsPointInAreaWithLabelWUID is not answering - detection is OFF.")
            inLog("The behaviour-tree and Skald routes in docs/interior-detection.md do not")
            inLog("go through Lua at all.")
            -- Never leave men standing on an answer that stopped coming.
            self:InteriorReleaseParked("the area-label bind stopped answering")
        end
        return
    end
    if (self._interiorNoAnswer or 0) >= 5 then
        inLog("the area-label bind is answering again - detection is back on")
    end
    self._interiorNoAnswer = 0

    if self.InteriorVerbose then
        inLog(string.format("sample: inside=%s", tostring(inside)))
    end

    -- Debounce: count how long the raw reading has held its value.
    if inside == self._interiorRaw then
        self._interiorRun = (self._interiorRun or 0) + 1
    else
        self._interiorRaw, self._interiorRun = inside, 1
    end
    if self._interiorRun < (self.InteriorConfirm or 1) then return end

    if self.InteriorState == inside then return end

    local first = (self.InteriorState == nil)
    self.InteriorState = inside

    if inside then
        self._interiorSince = realClock()
        inLog(string.format("%s a building at (%s) - labels: %s",
              first and "started inside" or "ENTERED", posStr(pos),
              self:InteriorContextOf(wuid)))
        local n, why = self:InteriorParkFollowers()
        if n > 0 then
            inLog(string.format("parked %d man/men who were following", n))
        elseif why then
            inLog("nobody parked: " .. why)
        else
            inLog("nobody parked: no one was actively following")
        end
    else
        local held = self._interiorSince and (realClock() - self._interiorSince) or nil
        self._interiorSince = nil
        self.InteriorSuppress = false
        if first then
            inLog(string.format("started outdoors at (%s)", posStr(pos)))
        else
            inLog(string.format("LEFT a building at (%s)%s", posStr(pos),
                  held and string.format(" after %.1fs inside", held) or ""))
        end
        self:InteriorReleaseParked("player came back out")
    end
end

-- ---------------------------------------------------------------------------
-- Commands
-- ---------------------------------------------------------------------------

function mercenaries:InteriorStatus()
    local wuid = playerWuid()
    if not wuid then inLog("no player"); return end
    local raw = self:InteriorHasLabel(wuid, self.InteriorLabel)
    local pos
    pcall(function() pos = player:GetWorldPos() end)
    inLog("enabled=" .. tostring(self.InteriorEnabled) ..
          "  verbose=" .. tostring(self.InteriorVerbose) ..
          "  confirm=" .. tostring(self.InteriorConfirm))
    inLog("bind answers: " .. (raw == nil and "NO - IsPointInAreaWithLabelWUID returned nothing"
                                          or tostring(raw)))
    inLog("debounced state: " .. (self.InteriorState == nil and "not sampled yet"
                                  or (self.InteriorState and "INSIDE" or "outdoors")))
    inLog("position: (" .. posStr(pos) .. ")   labels here: " .. self:InteriorContextOf(wuid))

    inLog("parking=" .. tostring(self.InteriorParkMercs) ..
          "  suppressed=" .. tostring(self.InteriorSuppress) ..
          "  parked=" .. self:InteriorParkedCount() ..
          "  blocked=" .. tostring(self:InteriorParkBlocked() or "no"))
    local n = 0
    for _, ent in pairs(self.ActiveMercs or {}) do
        local k, following = mercKey(ent), false
        pcall(function() following = self:InteriorIsFollowing(ent) end)
        local parked = k and self.InteriorParked[k] and true or false
        if following or parked then
            n = n + 1
            local nm
            pcall(function() nm = ent:GetName() end)
            inLog(string.format("  %-28s following=%s parked=%s",
                  tostring(nm or k), tostring(following), tostring(parked)))
        end
    end
    if n == 0 then inLog("  no merc is following or parked") end
end

function mercenaries:InteriorParkSet(on)
    self.InteriorParkMercs = on and true or false
    if not self.InteriorParkMercs then self:InteriorReleaseParked("parking turned off") end
    inLog("parking followers " .. (self.InteriorParkMercs and "on" or "off"))
end

function mercenaries:InteriorToggle(on)
    self.InteriorEnabled = on and true or false
    -- The scheduler slot is gated on InteriorEnabled, so the tick's own maintenance pass
    -- will never run again to hand these men back. Do it here or they stand for good.
    if not self.InteriorEnabled then self:InteriorReleaseParked("detection turned off") end
    inLog("detection " .. (self.InteriorEnabled and "on" or "off"))
end

function mercenaries:InteriorVerboseSet(on)
    self.InteriorVerbose = on and true or false
    inLog("verbose " .. (self.InteriorVerbose and "on - a line every sample" or "off"))
end

-- Answer for one arbitrary label, for exploring the vocabulary in docs/interior-detection.md.
function mercenaries:InteriorLabelProbe(line)
    local label = tostring(line or ""):match("^%s*(%S+)")
    if not label then inLog("usage: merc_interior_label <label>   e.g. private, stealthArea_crouch"); return end
    local wuid = playerWuid()
    local v = wuid and self:InteriorHasLabel(wuid, label)
    inLog(string.format("label '%s' here: %s", label,
          v == nil and "bind did not answer" or tostring(v)))
end

mercenaries:DevCommand("merc_interior", "mercenaries:InteriorStatus()",
    "Is the player inside a building right now, and which area labels cover him")
mercenaries:DevCommand("merc_interior_on",  "mercenaries:InteriorToggle(true)",  "Start interior detection")
mercenaries:DevCommand("merc_interior_off", "mercenaries:InteriorToggle(false)", "Stop interior detection")
mercenaries:DevCommand("merc_interior_verbose", "mercenaries:InteriorVerboseSet(mercenaries:CmdBool('%line'))",
    "Log every interior sample, not just enter/leave: 0 | 1")
mercenaries:DevCommand("merc_interior_label", "mercenaries:InteriorLabelProbe('%line')",
    "Test one area label at the player's position: merc_interior_label private")
mercenaries:DevCommand("merc_interior_park", "mercenaries:InteriorParkSet(mercenaries:CmdBool('%line'))",
    "Park the following mercs outside when you enter a building: 0 | 1")
