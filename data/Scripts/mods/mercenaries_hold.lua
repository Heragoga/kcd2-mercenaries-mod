-- Standing orders that put the squad somewhere specific: hold this ground, or
-- escort that man.
--
-- Neither is an engine formation. MakeFormation anchors on whichever entity ran it
-- and the engine chooses which man lands in which spot, so it can do neither of the
-- two things these orders need: stand still, and put a named merc on a named side.
-- This is the wall-battle staging pattern instead - one world point computed per merc
-- in Lua, each man walked to it by NavGotoRequest and the stock nav_goto tree. Proven
-- under load with mixed melee/archer defenders; see docs/squad-orders.md.

mercenaries.HoldActive   = false
mercenaries.HoldAnchor   = nil    -- {x,y,z} the order was given at
mercenaries.HoldFacing   = nil    -- unit {x,y}: the way the player was looking
mercenaries.HoldStations = {}     -- [wuidStr] = {x,y,z}

-- How far a holding man may leave his own station to take a fight. This is the whole
-- point of the order: the squad stops chasing. Measured from his STATION, not from
-- the player, so the line does not drift downfield with him.
--
-- It has to clear an ARCHER'S range, not a swordsman's. At 13m the men held their
-- ground perfectly and were shot to pieces by bowmen standing 25m off who were never
-- inside anyone's leash. This is "hold this ground", not "stand here and die".
mercenaries.HoldLeash       = 30.0
mercenaries.HoldArriveDist  = 2.2
-- Deliberately wider than HoldArriveDist. "Close enough to stop walking" and "close
-- enough to count as standing on my mark" must not be the same number, or a man
-- parked a hair outside it flips between idling and re-walking every poll.
mercenaries.HoldStationSlack = 4.0

-- The shape: a square block of melee centred on the anchor, with the archers in two
-- files on its flanks. Spacing between neighbouring men, and the gap between the edge
-- of the block and the archer files.
mercenaries.HoldPitch       = 2.2
mercenaries.HoldArcherFlank = 3.0

mercenaries.TokenIDEscort = "679a655e-189d-4519-b437-ccc4b92bee7d"
mercenaries.EscortEnt     = nil
mercenaries.EscortSpacing = 3.2
mercenaries.EscortWidth   = 2

-- NOTE ON THE "WAIT HERE" LABEL: the prompt whose text changes is the LOOK-AT
-- interactor action in mercenaries_lookatinteraction.lua, not the Skald order wheel.
-- It labels itself from mercenaries:SquadIsWaiting() below. An earlier attempt drove
-- the wheel's label instead, through a marker item and an ItemDescriptorTrigger, and
-- was backed out: it was the wrong menu, and it left a visible item in the player's
-- inventory for as long as the order stood.
local function holdLog(s) System.LogAlways("[MercHold] " .. s) end

local function navKeyOf(ent)
    if not ent then return nil end
    return tostring((ent.this and ent.this.id) or ent.id)
end

-- ==== who is eligible ====
-- The men actually out with the player. Anyone holding the camp keeps holding it:
-- a hold order is for the sortie, not for the cooks.
function mercenaries:HoldRoster()
    local out = {}
    pcall(function()
        for _, ent in pairs(self.ActiveMercs or {}) do
            local wuid = ent and (ent.this and ent.this.id or ent.id)
            if wuid and self:IsAliveAndWell(ent, false)
               and not self:IsMercInCampProper(wuid)
               and not self:IsCampActor(wuid) then
                table.insert(out, { ent = ent, wuid = wuid, key = tostring(wuid) })
            end
        end
    end)
    -- Sorted by key so the same man draws the same station every time the line is
    -- rebuilt. Rebuilding into a reshuffled lattice is what makes a squad mill about.
    table.sort(out, function(a, b) return a.key < b.key end)
    return out
end

function mercenaries:HoldIsArcher(rec)
    local n
    pcall(function() n = rec.ent:GetName() end)
    return (n ~= nil) and self:IsArcherName(n) or false
end

-- ==== the shape ====
-- A square block of melee centred on the anchor, archers in two files on its flanks.
-- Every man gets one exact point; nothing is left to the engine to arrange, which is
-- what made the first version read as a scatter rather than a formation.
function mercenaries:HoldBuildStations()
    local a = self.HoldAnchor
    local f = self.HoldFacing
    if not (a and f) then return end

    -- Forward and right, in the plane. Everything below is anchor + fwd*ahead + right*lat.
    local fx, fy = f.x, f.y
    local rx, ry = fy, -fx

    local archers, melee = {}, {}
    for _, r in ipairs(self:HoldRoster()) do
        if self:HoldIsArcher(r) then table.insert(archers, r) else table.insert(melee, r) end
    end

    local st = {}
    local function place(rec, ahead, lat)
        st[rec.key] = { x = a.x + fx * ahead + rx * lat,
                        y = a.y + fy * ahead + ry * lat,
                        z = a.z }
    end

    -- The block. side x side, centred both ways on the anchor, filled front rank
    -- first. A part-filled back rank is centred on its own count so it does not sit
    -- lopsided under the ranks above it.
    local n    = #melee
    local side = math.max(1, math.ceil(math.sqrt(n)))
    local rows = math.max(1, math.ceil(n / side))
    local halfRow = (rows - 1) / 2
    for i, r in ipairs(melee) do
        local row   = math.floor((i - 1) / side)
        local col   = (i - 1) % side
        local inRow = math.min(side, n - row * side)
        place(r, (halfRow - row) * self.HoldPitch,
                 (col - (inRow - 1) / 2) * self.HoldPitch)
    end

    -- Archers: a file down each flank, clear of the block's edge so they are shooting
    -- past it rather than over their own front rank. Alternating sides keeps the two
    -- files even.
    local edge = ((side - 1) / 2) * self.HoldPitch + self.HoldArcherFlank
    for i, r in ipairs(archers) do
        local sideSign = ((i % 2) == 1) and 1 or -1
        local depth    = math.floor((i - 1) / 2)
        place(r, (halfRow * self.HoldPitch) - depth * self.HoldPitch, sideSign * edge)
    end

    self.HoldStations = st
    holdLog(string.format("square formed: %d melee (%dx%d), %d archers on the flanks",
        n, side, rows, #archers))
end

-- ==== orders ====
function mercenaries:HoldBegin(pos, facing)
    local a = pos
    if not a then pcall(function() a = player:GetWorldPos() end) end
    if not a then holdLog("no anchor"); return false end

    local f = facing
    if not f then
        pcall(function()
            local d = player:GetDirectionVector()
            if d then
                local L = math.sqrt(d.x * d.x + d.y * d.y)
                if L > 1e-3 then f = { x = d.x / L, y = d.y / L } end
            end
        end)
    end
    f = f or { x = 0, y = 1 }

    self.HoldAnchor = { x = a.x, y = a.y, z = a.z }
    self.HoldFacing = f
    self.HoldActive = true
    self.EscortEnt  = nil
    self._holdBuiltAt, self._escRoster = nil, nil
    self:HoldBuildStations()

    -- The engine formation and the straggler sweep both pull men back to the player,
    -- which is exactly what a hold order must not do. Both check HoldActive.
    Game.SendInfoText('merc_info_hold', false, 0, 3)
    self:OrderBarkSome("merc_bark_wait", 2)
    holdLog(string.format("holding at %.1f, %.1f", a.x, a.y))
    return true
end

function mercenaries:HoldEnd(silent)
    if not self.HoldActive then return end
    self.HoldActive   = false
    self.HoldAnchor   = nil
    self.HoldStations = {}
    self:HoldReleaseAll()
    if not silent then
        Game.SendInfoText('merc_info_following', false, 0, 3)
        holdLog("released")
    end
end

-- A nav order leaves the scheduler still believing follow is running, so the men
-- stand where they were released. FollowStalled is the existing one-shot signal for
-- exactly that: it evicts the stale tree and re-fires follow.
function mercenaries:HoldReleaseAll()
    pcall(function()
        for _, ent in pairs(self.ActiveMercs or {}) do
            local k = navKeyOf(ent)
            if k and self.NavGoto and self.NavGoto[k] then
                local m = self.NavGoto[k].mode
                if m == "hold" or m == "escort" then self.NavGoto[k] = nil end
            end
            pcall(function() self:FollowStalled(ent) end)
        end
    end)
end

-- Is this man standing on his mark?
function mercenaries:HoldAtStation(ent)
    if not (self.HoldActive and ent) then return false end
    local st = self.HoldStations[tostring((ent.this and ent.this.id) or ent.id)]
    if not st then return false end
    local p
    pcall(function() p = ent:GetWorldPos() end)
    if not p then return false end
    local dx, dy = p.x - st.x, p.y - st.y
    return (dx * dx + dy * dy) <= (self.HoldStationSlack * self.HoldStationSlack)
end

-- What the schedulers ask instead of reading _G.MercIdle directly.
--
-- The idle arm is the PROVEN way to make a merc stand: it evicts the follow tree and
-- parks him on an endless Wait. A hold order needs exactly that, but only once the
-- man is actually on his station - idle him before he gets there and he stands
-- wherever the order caught him.
--
-- Getting this wrong is what broke "wait here": with nothing holding an arrived merc,
-- nav_goto ended, the scheduler re-fired follow, and he walked straight back to the
-- player. The two states are mutually exclusive by construction - walking, or stood
-- on the mark - so the nav arm and the idle arm can never fight over him.
-- Wrapped: this runs for every merc on every scheduler tick, and it is read straight
-- into a BT variable. An error here would fail the ExecuteLua, and its Sequence, and
-- the arm - which in a failureMode="Any" Parallel takes the whole tree with it.
function mercenaries:MercIsIdle(ent)
    if _G.MercIdle then return true end
    local ok, idle = pcall(function()
        if not self.HoldActive then return false end
        return self:HoldAtStation(ent)
    end)
    return (ok and idle) or false
end

-- "Are the men stopped?", for anything that has to label a toggle or decide which way
-- one should go.
--
-- ASK THIS, never _G.MercPersistentIdleFlag on its own. A hold order deliberately
-- leaves that flag false (see MercIsIdle), so a caller reading it alone thinks the
-- squad is following no matter what - which pinned the look-at prompt to "Wait here"
-- and made every press compute "not false" and order another halt.
function mercenaries:SquadIsWaiting()
    return (self.HoldActive == true) or (_G.MercPersistentIdleFlag == true)
end

-- ==== the leash ====
-- Called from TryClaimTarget, the single choke point every claim goes through, so
-- there is no acquisition path that can smuggle a man off his station.
function mercenaries:HoldOutOfLeash(myWuid, targetWuid)
    if not self.HoldActive then return false end
    local st = self.HoldStations[tostring(myWuid)]
    if not st then return false end

    local tp
    pcall(function()
        local te = XGenAIModule.GetEntityByWUID(targetWuid)
        tp = te and te:GetWorldPos()
    end)
    if not tp then return false end

    local dx, dy = tp.x - st.x, tp.y - st.y
    return (dx * dx + dy * dy) > (self.HoldLeash * self.HoldLeash)
end

-- ==== escort ====
function mercenaries:EscortBegin(ent)
    ent = ent or self:OrderRememberedEntity()
    if not ent then
        Game.SendInfoText('merc_info_escort_none', false, 0, 3)
        holdLog("escort: nothing to escort")
        return false
    end
    self.EscortEnt  = ent
    self.HoldActive = false
    self.HoldStations = {}
    self._holdBuiltAt, self._escRoster = nil, nil
    local nm = "him"
    pcall(function() nm = ent:GetName() or nm end)
    Game.SendInfoText('merc_info_escort', false, 0, 3)
    self:OrderBarkSome("merc_bark_ack", 2)
    holdLog("escorting " .. tostring(nm))
    return true
end

function mercenaries:EscortEnd(silent)
    if not self.EscortEnt then return end
    self.EscortEnt = nil
    self:HoldReleaseAll()
    if not silent then
        Game.SendInfoText('merc_info_following', false, 0, 3)
        holdLog("escort ended")
    end
end

-- targetPosOf reads trailDir and trailAim off the live record every tick, so
-- refreshing them in place turns the whole column with the man being escorted
-- without tearing down anyone's route and restarting them from a standstill.
function mercenaries:EscortRefresh(ent, dir, aim)
    local k = navKeyOf(ent)
    local rec = k and self.NavGoto and self.NavGoto[k]
    if not rec or not rec.trailEnt then return false end
    if dir then rec.trailDir = dir end
    rec.trailAim = aim
    return true
end

-- ==== per-merc poll, from the scheduler ====
function mercenaries:HoldPoll(bt_data, ent)
    local wuid = ent and (ent.this and ent.this.id or ent.id)
    if not wuid then return end
    local key = tostring(wuid)

    local st = self.HoldStations[key]
    if not st then
        -- Someone joined the squad, or came back up, after the line was drawn.
        -- Throttled: a man who is never eligible for a station (a camp actor, say)
        -- would otherwise ask for a full rebuild on every poll, and a rebuild walks
        -- the whole roster - that is O(squad^2) a second at fifty men.
        local now = 0
        pcall(function() now = System.GetCurrTime() or 0 end)
        if (now - (self._holdBuiltAt or -999)) < 2.0 then return end
        self._holdBuiltAt = now
        self:HoldBuildStations()
        st = self.HoldStations[key]
        if not st then return end
    end

    -- Already stood on his mark: do not re-issue, or he restarts the walk every poll
    -- and shuffles on the spot forever.
    local p
    pcall(function() p = ent:GetWorldPos() end)
    if p then
        local dx, dy = p.x - st.x, p.y - st.y
        if (dx * dx + dy * dy) <= (self.HoldArriveDist * self.HoldArriveDist) then return end
    end

    if self:IsNavGotoActive(ent) and self:NavGotoMode(ent) == "hold" then
        bt_data.navOrderGo = false
        return
    end

    if self:NavGotoRequest(ent, { x = st.x, y = st.y, z = st.z }, { mode = "hold" }) then
        bt_data.navOrderGo = true
    end
end

function mercenaries:EscortPoll(bt_data, ent)
    local subject = self.EscortEnt
    if not subject then return end

    local sp, sd
    pcall(function() sp = subject:GetWorldPos() end)
    if not sp then self:EscortEnd(); return end
    pcall(function() sd = subject:GetDirectionVector() end)

    local dir = { x = 0, y = 1 }
    if sd then
        local L = math.sqrt(sd.x * sd.x + sd.y * sd.y)
        if L > 1e-3 then dir = { x = sd.x / L, y = sd.y / L } end
    end
    -- Aim at a point ahead of him rather than at him: targetPosOf measures the
    -- column's heading off this, and a heading of zero collapses the whole file
    -- onto his own position.
    local aim = { x = sp.x + dir.x * 10.0, y = sp.y + dir.y * 10.0 }

    if self:IsNavGotoActive(ent) and self:NavGotoMode(ent) == "escort" then
        self:EscortRefresh(ent, dir, aim)
        bt_data.navOrderGo = false
        return
    end

    -- Rank and file, stable per merc so the column keeps its order. The roster is
    -- cached for a beat: this runs per merc, and rebuilding it each time is
    -- O(squad^2) for a list that barely changes.
    local now = 0
    pcall(function() now = System.GetCurrTime() or 0 end)
    if not self._escRoster or (now - (self._escRosterAt or -999)) > 2.0 then
        self._escRoster, self._escRosterAt = self:HoldRoster(), now
    end
    local roster, idx = self._escRoster, 0
    local myKey = tostring(ent.this and ent.this.id or ent.id)
    for i, r in ipairs(roster) do if r.key == myKey then idx = i break end end
    if idx == 0 then return end

    local row = math.floor((idx - 1) / self.EscortWidth)
    local col = (idx - 1) % self.EscortWidth
    local lat = (col - (self.EscortWidth - 1) / 2) * self.EscortSpacing

    if self:NavGotoRequest(ent, nil, {
        mode      = "escort",
        trailEnt  = subject,
        trailBack = self.EscortSpacing * (row + 1),
        trailLat  = lat,
        trailAim  = aim,
        trailDir  = dir,
    }) then
        bt_data.navOrderGo = true
    end
end

-- The one entry point the schedulers call. Keeps the BT ignorant of which order is
-- running: it only ever learns "fire nav_goto now" or "do not".
function mercenaries:NavOrderPoll(bt_data, ent)
    bt_data.navOrderGo = false
    if _G.MercenariesDismissed then return end
    local ok, err = pcall(function()
        if self.HoldActive then
            self:HoldPoll(bt_data, ent)
        elseif self.EscortEnt then
            self:EscortPoll(bt_data, ent)
        end
    end)
    if not ok then holdLog("NavOrderPoll error: " .. tostring(err)) end
end

function mercenaries:MonitorHoldTokens(p)
    local n = p:GetCountOfClass(self.TokenIDEscort)
    if n and n > 0 then
        p:DeleteItemOfClass(self.TokenIDEscort, n)
        self:EscortBegin()
    end
end

function mercenaries:HoldStatus()
    holdLog(string.format("hold=%s escort=%s stations=%d leash=%.1f",
        tostring(self.HoldActive),
        self.EscortEnt and "yes" or "no",
        (function() local c = 0 for _ in pairs(self.HoldStations or {}) do c = c + 1 end return c end)(),
        self.HoldLeash))
    if self.HoldAnchor then
        holdLog(string.format("anchor %.1f, %.1f facing %.2f, %.2f",
            self.HoldAnchor.x, self.HoldAnchor.y,
            (self.HoldFacing or {}).x or 0, (self.HoldFacing or {}).y or 0))
    end
end

System.AddCCommand("merc_hold",        "mercenaries:HoldBegin()",   "Hold this ground: the squad forms a line here and stops chasing")
System.AddCCommand("merc_hold_end",    "mercenaries:HoldEnd()",     "Release a hold order and resume following")
System.AddCCommand("merc_escort",      "mercenaries:EscortBegin()", "Escort whoever you are looking at, in column")
System.AddCCommand("merc_escort_end",  "mercenaries:EscortEnd()",   "Stop escorting")
System.AddCCommand("merc_hold_status", "mercenaries:HoldStatus()",  "Report the hold/escort order state")
