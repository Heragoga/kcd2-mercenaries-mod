-- Follow chain: the fallback locomotion for any merc with no formation handle.
-- Each merc follows either the player or another merc a couple of places ahead,
-- so the squad trails in a rough line.
--
-- The squad's real formation is mercenaries_formation.lua (docs/formations.md):
-- one merc is elected to anchor an engine formation and everyone else joins it.
-- This chain is what a merc falls back to when that is unavailable - leader in
-- combat, mid-handoff, startup race, or a walled camp where the formation cannot
-- be steered around the wall - so it must never be removed.
-- IsFormationEligible lives here because both systems use it. FormationRank is
-- chain-only now: the formation picks its leader by distance to the player, not by
-- merc type, so that whoever anchors it is always at the front of the pack.

-- Formation rank: heroes lead, melee regulars next, archers at the back.
function mercenaries:FormationRank(mercType)
    if mercType == "hero" then return 0 end
    if mercType == "archer" then return 2 end
    return 1
end

-- One membership rule, shared by the slot formation and the follow chain. Keeping
-- two copies is how they once diverged on IsCampActor, which let a merc be picked
-- for a formation he was never eligible to join.
function mercenaries:IsFormationEligible(ent, wuid)
    if not wuid then return false end
    if ent and not self:IsAliveAndWell(ent, false) then return false end
    if self:IsMercInCampProper(wuid) then return false end
    if self:CampActorGet(wuid) then return false end
    if self.NpcFormations and self.NpcFormations[tostring(wuid)] then return false end
    -- Stalled repeatedly while in formation: keep him out of it for a while so his follow
    -- tree takes the plain-chain arm instead (see FollowEscalate).
    if self.FollowFormationSuppressed and self:FollowFormationSuppressed(wuid) then return false end
    return true
end


function mercenaries:UpdateFormationSlots()
    local ok, err = pcall(function()
        self.FormationSlots = {}

        local mounted   = {}
        local unmounted = {}

        for name, ent in pairs(self.ActiveMercs) do
            local entWuid  = ent and (ent.this and ent.this.id or ent.id)
            -- ONE membership rule, the same one the engine formation elects from.
            -- This used to test only IsMercInCampProper while IsFormationEligible
            -- also excluded camp actors, and that gap is a blob generator: a merc
            -- the chain skipped got no FormationSlots entry, so
            -- CalculateFormationTarget fell through to followTarget = the player
            -- and he walked straight at him instead of holding a place in the
            -- queue. Enough of them and the whole squad piles onto the player.
            if self:IsFormationEligible(ent, entWuid) then
                local mercType = self:GetMercType(ent)
                local entName  = ent:GetName() or name
                local hp       = 0
                local isMounted = false

                pcall(function()
                    local rawHp = ent.soul:GetState('health')
                    hp = tonumber(rawHp) or 0
                end)

                pcall(function()
                    isMounted = ent.human:IsMounted()
                end)

                local entry = { wuid = entWuid, name = entName, hp = hp, mercType = mercType }

                if isMounted then
                    table.insert(mounted, entry)
                else
                    table.insert(unmounted, entry)
                end
            end
        end

        local function formationRank(mercType) return mercenaries:FormationRank(mercType) end

        -- Mounted mercs: heroes first by name, then regulars, archers last
        table.sort(mounted, function(a, b)
            local aRank = formationRank(a.mercType)
            local bRank = formationRank(b.mercType)
            if aRank ~= bRank then return aRank < bRank end
            return a.name < b.name
        end)

        -- Unmounted mercs: heroes first by name, then regulars by descending health, archers last
        table.sort(unmounted, function(a, b)
            local aRank = formationRank(a.mercType)
            local bRank = formationRank(b.mercType)
            if aRank ~= bRank then return aRank < bRank end
            if a.mercType == "hero" then return a.name < b.name end
            if a.hp == b.hp then return a.name < b.name end
            return a.hp > b.hp
        end)

        local alive = {}
        for _, v in ipairs(mounted)   do table.insert(alive, v) end
        for _, v in ipairs(unmounted) do table.insert(alive, v) end

        local totalMercs = #alive
        local width = (totalMercs >= 15) and 3 or 2

        for i, v in ipairs(alive) do
            local slot = i - 1
            local followTarget = nil

            if slot >= width then
                local targetIndex = slot - width + 1
                local targetData  = alive[targetIndex]
                if targetData then
                    followTarget = targetData.wuid
                end
            end

            self.FormationSlots[tostring(v.wuid)] = {
                slot         = slot,
                followTarget = followTarget,
                totalMercs   = totalMercs,
            }
        end
    end)

    if not ok then
        System.LogAlways('[Mercenary Jeff] UpdateFormationSlots Error: ' .. tostring(err))
    end
end

-- ---------------------------------------------------------------------------
-- MOUNTED LEADER GAIT.
--
-- The formation anchor is the one rider who cannot use FormationFollower, so he
-- drives himself with a Move - and `speed` is an enum ATTRIBUTE, not a variable,
-- so each gait has to be its own node behind a switch.
--
-- He used to pick between exactly two: Dash beyond 10m, Walk inside it, sampled
-- once a second. That cannot help but surge - dash until inside 10m, drop to a
-- walk, fall behind, dash again - and every follower replays his path through
-- MoveHistory, so the whole column concertinas behind him.
--
-- Instead: MATCH THE PLAYER'S ACTUAL SPEED, and use distance only as a small
-- trim. Measuring the player rather than reacting to the gap is what makes the
-- speed constant: at a true match the gap simply holds, and the trim is then
-- doing almost nothing.
-- ---------------------------------------------------------------------------
mercenaries.MountGaitBands = { 2.0, 4.5, 7.5 }  -- m/s cuts between Walk/Run/Dash/Sprint
mercenaries.MountStandoff  = 7.0                -- metres the leader aims to sit behind the player
mercenaries.MountTrimBack  = 4.0                -- beyond standoff+this, take one gait more
mercenaries.MountTrimNear  = 3.0                -- inside standoff-this, take one gait less
mercenaries.PlayerSpeed    = 0.0

-- Once per CombatScanLoop pass (300ms). Smoothed, because a raw per-tick delta
-- jitters enough to flip a gait band on its own.
function mercenaries:UpdatePlayerSpeed()
    pcall(function()
        local p = player and player:GetWorldPos()
        local t = System.GetCurrTime() or 0
        local prev = self._psPrev
        self._psPrev = { x = p and p.x, y = p and p.y, t = t }
        if not (p and prev and prev.x) then return end
        local dt = t - (prev.t or t)
        if dt <= 0.01 then return end
        local dx, dy = p.x - prev.x, p.y - prev.y
        local inst = math.sqrt(dx * dx + dy * dy) / dt
        if inst > 20.0 then return end          -- teleport / stream-in, not travel
        self.PlayerSpeed = 0.6 * (self.PlayerSpeed or 0) + 0.4 * inst
    end)
end

-- BT hook, every 300ms. Sets data.mountGait: 3 Sprint, 2 Dash, 1 Run, 0 Walk, -1 hold.
-- Runs for every merc, not just the leader: a mounted FOLLOWER whose formation handle
-- is momentarily null falls through to these same gait arms, and leaving him on a
-- default Walk would drop him out of the column.
function mercenaries:MountedLeaderGait(bt_data, ent)
    local ok = pcall(function()
        local b = self.MountGaitBands
        local s = self.PlayerSpeed or 0
        local g = 0
        if s >= b[3] then g = 3 elseif s >= b[2] then g = 2 elseif s >= b[1] then g = 1 end

        local mp = ent and ent:GetWorldPos()
        local pp = player and player:GetWorldPos()
        if mp and pp then
            local dx, dy = pp.x - mp.x, pp.y - mp.y
            local d = math.sqrt(dx * dx + dy * dy)
            if d > (self.MountStandoff + self.MountTrimBack) then g = g + 1
            elseif d < (self.MountStandoff - self.MountTrimNear) then g = g - 1 end
            -- Standing player: hold station rather than creep the last metres onto him.
            if s < 0.4 and d <= self.MountStandoff then g = -1 end
        end

        if g > 3 then g = 3 end
        if g < -1 then g = -1 end
        bt_data.mountGait = g
    end)
    if not ok then System.LogAlways('[MercForm] MountedLeaderGait error') end
end

-- ---------------------------------------------------------------------------
-- Follow-behaviour refire: the safety net for a merc who stops following.
--
-- The scheduler's own self-heal is gated on being >35m from the player, so a
-- merc who halts next to him is never rescued by it.
--
-- The follow tree is still RUNNING but producing no movement. Clearing the
-- scheduler's latch alone does not help: re-firing 'follow' over an already-running
-- 'follow' does not reliably displace it. The cure players found by hand is
-- toggling idle, which works because the idle arm fires the 'teleport' behaviour
-- first - a different behaviour, so it definitely evicts the stuck tree - and only
-- then lets 'follow' start fresh. The scheduler mirrors exactly that for this flag.
--
-- This flag is raised ONLY by external triggers (the teleporter, the dismount
-- watch). It must never be raised by the follow tree's own ending: an interrupt
-- deliberately replacing follow ends it too, so re-arming from there re-arms the
-- re-fire that ended it, and follow restarts once a second for ever - which churns
-- the formation, because every restart re-runs GetMemberFormation. That was tried.
mercenaries.FollowStuck = {}   -- [wuidStr] = earliest time his re-fire may run

local function fhKey(ent)
    local w = ent and ((ent.this and ent.this.id) or ent.id)
    return w and tostring(w) or nil
end

local function fhNow()
    local t = 0
    pcall(function() t = System.GetCurrTime() or 0 end)
    return t
end

-- Called by the teleporter. A merc who had to be dragged back to the player is by
-- definition not following, and the teleport itself is what HID him from the
-- scheduler's 35m self-heal: it resets his distance every pass, so the stuck
-- merc never stays far enough away long enough to be noticed. Gate is already
-- tight upstream - out of combat, not idle, not in camp, player not mounted.
--
-- Raising it is a QUEUE, not a flag. Each refire evicts one behaviour tree and starts
-- another, and the engine applies interrupts on its own update rather than where they
-- are queued - so a whole squad raised in the same instant (which is what releasing a
-- hold order used to do) puts fifty evictions and fifty re-fires into the same couple
-- of frames. Men who are already queued keep the slot they were given.
mercenaries.FollowRefireStagger = 0.30

function mercenaries:FollowStalled(ent)
    local ok = pcall(function()
        local k = fhKey(ent)
        if not k then return end
        if self.FollowStuck[k] then return end
        local now  = fhNow()
        local slot = math.max(now, self._fsNextSlot or 0)
        self._fsNextSlot   = slot + self.FollowRefireStagger
        self.FollowStuck[k] = slot
    end)
    if not ok then System.LogAlways('[MercForm] FollowStalled error') end
end

-- Same signal, for callers that hold a wuid rather than an entity.
function mercenaries:FollowStalledWuid(wuid)
    if not wuid then return end
    local ent
    pcall(function() ent = XGenAIModule.GetEntityByWUID(wuid) end)
    if ent then self:FollowStalled(ent) end
end

-- BT hook, polled by mercenary_scheduler.xml. Sets data.followStuck. READ-ONLY:
-- the scheduler also gates on ~inCombat, and clearing here would throw the signal
-- away during a fight instead of acting on it the moment the fight ends.
-- Never reports true while a nav_goto is running: walled-battle staging replaces
-- follow on purpose, and re-arming there would fight the staging move.
function mercenaries:PollFollowRefire(bt_data, myWuid)
    bt_data.followStuck = false
    local ok = pcall(function()
        local k = tostring(myWuid)
        local due = self.FollowStuck[k]
        if not due then return end
        if fhNow() < due then return end
        local me = XGenAIModule.GetEntityByWUID(myWuid)
        if me and self.IsNavGotoActive and self:IsNavGotoActive(me) then return end
        bt_data.followStuck = true
    end)
    if not ok then System.LogAlways('[MercForm] PollFollowRefire error') end
end

function mercenaries:ConsumeFollowRefire(myWuid)
    self.FollowStuck[tostring(myWuid)] = nil
end

-- ---------------------------------------------------------------------------
-- EVICTION GUARD - the race that leaves a merc standing for ever.
--
-- Replacing a stalled follow tree takes two steps in two INDEPENDENT scheduler arms:
-- the re-fire arm fires 'teleport' to evict whatever is running, and the follow arm
-- fires 'follow' the next time it sees $isFollowingActive false. An interrupt is not
-- applied where it is queued - the engine applies it on its own update - so when the
-- follow arm's timer lands inside that gap the order becomes
--
--     queue teleport  ->  fire follow, latch = true  ->  teleport lands, evicts follow
--
-- and the latch now claims he is following with nothing running. The follow arm only
-- ever retries on a FALSE latch, so he stands there for good; the 35m self-heal is the
-- only thing left, and it cannot see a man who stopped next to the player.
--
-- The gap widens with squad size (more interrupts per engine update), which is why it
-- only bites at forty or fifty men, and it fires en masse on a hold release - the one
-- moment the whole squad re-fires at once. See docs/squad-orders.md.
--
-- So: whoever queues an eviction stamps a block here, and the follow arm will not fire
-- 'follow' until it expires. Deliberately time-based and self-expiring - a BT latch
-- held across a Wait would strand a merc for good if his branch were abandoned
-- mid-wait, which is the same class of bug one level down.
-- ---------------------------------------------------------------------------
mercenaries.FollowEvictBlockSecs = 0.75
mercenaries.FollowBlockUntil = {}      -- [wuidStr] = no 'follow' interrupt before this time

function mercenaries:NoteFollowEviction(myWuid)
    pcall(function()
        self.FollowBlockUntil[tostring(myWuid)] = fhNow() + self.FollowEvictBlockSecs
    end)
end

-- Ripple the squad into motion instead of letting fifty follow interrupts land inside
-- the same half second. Total spread is capped, so a small squad still starts at once
-- and a big one takes about a second and a half to get going - which is both kinder to
-- the interrupt queue and closer to how a column actually moves off.
mercenaries.FollowStaggerTotal = 1.5

function mercenaries:FollowStaggerSquad()
    local n = 0
    for _ in pairs(self.ActiveMercs or {}) do n = n + 1 end
    if n < 2 then return 0 end
    local step = math.min(0.05, self.FollowStaggerTotal / n)
    local now, i = fhNow(), 0
    for _, ent in pairs(self.ActiveMercs or {}) do
        local k = fhKey(ent)
        if k then
            self.FollowBlockUntil[k] = now + i * step
            i = i + 1
        end
    end
    return (i - 1) * step
end

-- One call per merc per scheduler tick: publishes the guard above into the BT.
function mercenaries:FollowGate(bt_data, myWuid)
    -- Cleared FIRST, in its own pcall, so that any failure below leaves the gate OPEN.
    -- A gate that fails shut is a merc who never follows again, which is the bug this
    -- exists to fix.
    pcall(function() bt_data.refireBlock = false end)
    local ok = pcall(function()
        local k      = tostring(myWuid)
        local until_ = self.FollowBlockUntil[k]
        local now    = fhNow()
        if until_ and now < until_ then
            bt_data.refireBlock = true
        elseif until_ then
            self.FollowBlockUntil[k] = nil
        end
    end)
    if not ok then System.LogAlways('[MercForm] FollowGate error') end
end

-- ---------------------------------------------------------------------------
-- Dismount follow reset.
--
-- After the squad comes off its horses, one merc reliably ends up in a follow
-- tree that is RUNNING but produces no movement. Two attempts at the underlying
-- stall missed it: containment on the tree (it never fails, so OnFail never runs)
-- and a stuck flag off the teleporter (he stalls within 50m, so he is never
-- teleported and never flagged).
--
-- The cure done by hand is idling the squad and setting it following again. What
-- actually does the work there is per merc: the idle arm clears
-- $isFollowingActive and fires the 'teleport' behaviour, which evicts the stalled
-- follow tree, and un-idling then starts 'follow' fresh. So this raises exactly
-- that, per merc, without ever touching _G.MercIdle.
--
-- Driving it through the global idle flag was tried and is WRONG:
-- UpdateFormationRole returns early on _G.MercIdle, so useFormation goes false for
-- the whole squad, the leader's SubtreeDecorator runs its EndFormation cleanup,
-- and everyone drops to the CrimeFollower chain. The formation came back only
-- after a full rebuild. Never idle the squad to fix following.
--
-- The formation LEADER is deliberately skipped: his tree is the one that owns
-- MakeFormation, so restarting him destroys the formation handle and forces every
-- follower onto the chain until it is rebuilt - the same regression by another
-- route. Followers restart against a formation that is still standing and re-join
-- it directly.
--
-- It NO LONGER resets the squad on every dismount. That was needed while the real
-- cause was unknown, and it cost what it was meant to save: forcing a teleport and
-- a follow restart on mercs who were already following fine is itself a stall of a
-- second or two, every time. Now that the mounted leader's flee-parameter bug is
-- fixed (docs/formations.md) the squad recovers on its own, so a dismount only
-- OPENS A VERIFICATION WINDOW, and only a merc who demonstrably fails to move is
-- reset. Nothing happens at all in the normal case.
--
-- This is not the general movement/velocity stuck detector that was removed for
-- causing twitching and horse churn, and it must not be widened into one. It is
-- bounded on all sides: it only runs inside a WINDOW, it only judges a merc on a tick
-- where the PLAYER has actually moved (so a squad standing still with a standing
-- player is never touched), and it cannot spawn horses because it only runs while the
-- player is on foot.
--
-- A dismount is no longer the only thing that opens the window. Releasing a hold or
-- escort order opens it too (BeginFollowVerify), for the same reason and with the same
-- bounds: that is the other moment the whole squad re-fires follow at once, and it is
-- exactly where a man who silently fails to start walking is invisible - he is stood
-- next to the player, so no distance rule can ever see him.
-- ---------------------------------------------------------------------------
mercenaries.DismountResetDelay   = 2.0   -- seconds after dismount before watching
mercenaries.DismountVerifySecs   = 25.0  -- keep verifying this long
mercenaries.DismountVerifyEvery  = 2.0   -- how often to sample inside that window
mercenaries.DismountVerifyMoved  = 1.0   -- a merc covering less than this has not moved
mercenaries.DismountVerifyPlayer = 5.0   -- ...judged stuck once the player has covered this much
mercenaries.DismountVerifyFar    = 22.0  -- ...or if he is simply this far away and stationary

-- How often the same sampler runs OUTSIDE those windows. The four triggers above only cover
-- the moments a stall was known to be likely, and the scheduler's own self-heal needs the
-- merc 35m away - so a man who halts beside the player was watched by nothing. 0 disables
-- the continuous watch. See docs/formations.md, "When a merc stops following".
mercenaries.FollowWatchEvery = 4.0

-- THE FAR TEST DOES NOT APPLY TO A MAN HOLDING A FORMATION SLOT. 22m is shorter than the
-- formation itself: merc_column40 is 36m deep, so the rear half of a CORRECTLY formed column
-- is beyond it, and when the player pauses those men are stationary because they are standing
-- exactly where they were told to. The verify then evicted and re-fired every one of them
-- every 2s for the whole window, which drops a man out of his slot to re-acquire it - the
-- squad churns instead of settling. Deploying 38 men into merc_column40 made it unmissable:
-- 17 men, matching the 17 spots at or past 22m, "not following" and climbing.
--
-- Freshness is what makes this safe rather than a blind spot. FormationSlotAt is stamped from
-- follow.xml every pass, so a claim this recent proves the man's tree is RUNNING. A genuinely
-- stalled merc stops stamping, his claim expires, and the far test picks him up again. The
-- player-drift test is never waived: if the player moves and a man does not, he is stuck
-- whatever he believes about his slot.
mercenaries.FormationSlotFreshSecs = 2.5

function mercenaries:FormationSlotFresh(k)
    if not (self.FormationInSlot or {})[k] then return false end
    local at = (self.FormationSlotAt or {})[k]
    if not at then return false end
    local now = fhNow()
    return (now - at) <= self.FormationSlotFreshSecs
end

function mercenaries:DismountWatch()
    local ok = pcall(function()
        local mounted = _G.PlayerMounted and true or false
        local was     = self._fhWasMounted and true or false
        self._fhWasMounted = mounted

        -- Re-mounted while waiting: the reset is no longer wanted.
        if mounted then self.DismountResetAt = nil; return end

        if was then self.DismountResetAt = fhNow() + self.DismountResetDelay end

        local now = fhNow()
        if self.DismountResetAt and now >= self.DismountResetAt then
            self.DismountResetAt = nil
            self:BeginFollowVerify("dismount")
        end

        -- Verification window: did the reset actually take?
        if self._dvUntil then
            if now > self._dvUntil then
                self._dvUntil, self._dvPos = nil, nil
            elseif not self._dvNextAt or now >= self._dvNextAt then
                self._dvNextAt = now + self.DismountVerifyEvery
                self:DismountVerify()
            end
        -- ...and the same sampler, always, at a slower cadence.
        elseif (self.FollowWatchEvery or 0) > 0
               and (not self._dvNextAt or now >= self._dvNextAt) then
            self._dvNextAt = now + self.FollowWatchEvery
            self._dvReason = "the follow watch"
            self:DismountVerify()
        end
    end)
    if not ok then System.LogAlways('[MercForm] DismountWatch error') end
end

-- ---------------------------------------------------------------------------
-- WHEN RE-FIRING DOES NOT WORK.
--
-- The eviction+re-fire above cures a merc whose follow tree DIED. It cannot cure one
-- whose tree is alive and running an arm that produces no movement, because a re-fire
-- restarts that same tree into that same state - so the log fills with "N mercs were
-- not following" for the same man every few seconds and he never takes a step. That is
-- the reported bug, and its tell is exactly that repetition.
--
-- So repeated failure ESCALATES rather than repeats. Each tier changes something the
-- next re-fire will read, instead of asking the same question again:
--
--   tier 1  evict + re-fire                 (what already happened)
--   tier 2  drop him out of the ENGINE FORMATION for a while. follow.xml dispatches on
--           $useFormation, so this puts the re-fired tree down a completely different
--           arm - the plain CrimeFollower chain instead of FormationFollower. If the
--           stall has anything to do with the formation (a stale handle, a slot he
--           cannot reach, a chain parked behind another stalled man) that is the cure;
--           if it does not, he still follows, just out of shape for half a minute.
--   tier 3  put him beside the player by hand. MonitorDistanceAndTeleport would do it
--           on its own, but only past its distance gate - and a man stalled AT the
--           player's heel is never far enough for it to see, which is exactly why this
--           bug slips through every other net in the mod.
--
-- The streak resets the moment he is seen to move, so a merc who recovers at tier 1
-- never reaches tier 2 and normal play never touches any of it.
mercenaries.FollowStallStreak       = {}   -- [k] = consecutive stalls with no movement between
mercenaries.FollowFormationOffUntil = {}   -- [k] = keep him off the engine formation until this time
mercenaries.FollowEscalateFormAt    = 3    -- stalls before dropping him from the formation
mercenaries.FollowEscalateTeleAt    = 5    -- ...and before hauling him to the player
mercenaries.FollowFormationOffSecs  = 30.0

-- Read by IsFormationEligible, so one flag takes him out of BOTH the slot chain and his
-- own $useFormation in the same pass.
function mercenaries:FollowFormationSuppressed(wuid)
    if not wuid then return false end
    local k = tostring(wuid)
    -- He was elected while suppressed (or elected since): the formation hangs off him, so
    -- honouring the suppression now would take the shape down for everybody.
    if self.FormationLeader and tostring(self.FormationLeader) == k then
        self.FollowFormationOffUntil[k] = nil
        return false
    end
    local until_ = self.FollowFormationOffUntil[k]
    if not until_ then return false end
    if fhNow() >= until_ then
        self.FollowFormationOffUntil[k] = nil
        System.LogAlways("[MercForm] " .. k .. " back in the formation (stall suppression expired)")
        return false
    end
    return true
end

-- Everything that decides WHICH arm of follow.xml a merc is in, on one line. Printed at
-- the first escalation: without it the next report of this bug is another guess, because
-- the state is gone by the time anyone goes looking.
function mercenaries:FollowStallReport(ent, k)
    local f = {}
    local function add(n, v) f[#f + 1] = n .. "=" .. tostring(v) end
    pcall(function()
        local w = ent.this and ent.this.id or ent.id
        local d = (self.FormationSlots or {})[k]
        add("inSlotChain", d ~= nil)
        add("isLeader", self.FormationLeader and tostring(self.FormationLeader) == k)
        add("leader", self.FormationLeader)
        add("inFormation", (self.FormationInSlot or {})[k])
        add("slotFresh", self:FormationSlotFresh(k))
        add("slot", d and d.slot)
        add("chainTarget", d and d.followTarget)
        add("campActor", self:IsCampActor(w))
        add("campOut", self:IsCampOut(w))
        add("navGoto", self:IsNavGotoActive(ent))
        add("target", (self.MercTargetOf or {})[tostring(w)])
        add("mounted", ent.human and ent.human:IsMounted())
        add("playerMounted", _G.PlayerMounted)
        add("hold", self.HoldActive)
        add("escort", self.EscortEnt ~= nil)
    end)
    System.LogAlways("[MercForm] STALL " .. tostring(ent and ent.GetName and ent:GetName())
                     .. " :: " .. table.concat(f, " "))
end

-- Record one stall and act on the streak. Returns the streak length.
function mercenaries:FollowEscalate(ent, k)
    local n = (self.FollowStallStreak[k] or 0) + 1
    self.FollowStallStreak[k] = n

    if n == self.FollowEscalateFormAt then
        self:FollowStallReport(ent, k)
        self.FollowFormationOffUntil[k] = fhNow() + self.FollowFormationOffSecs
        -- Deliberately NOT a CampFormationDirty: that nulls the leader and re-elects,
        -- which drops the WHOLE squad onto the chain to fix one man. UpdateFormationSlots
        -- rebuilds from scratch every pass and UpdateFormationRole publishes per merc, so
        -- he leaves the formation on his own next tick and the chain re-packs itself.
        System.LogAlways("[MercForm] " .. k .. " stalled " .. n ..
                         "x - dropping him out of the formation onto the follow chain")
    elseif n >= self.FollowEscalateTeleAt then
        self:FollowStallReport(ent, k)
        self.FollowStallStreak[k] = 0          -- one haul per streak, then judge him afresh
        local moved = false
        pcall(function()
            local base = self:GetSafeSpawnPosition(player, 10)
            if not base then return end
            local tp = self:FindValidGround({
                x = base.x + (math.random() - 0.5) * 3.0,
                y = base.y + (math.random() - 0.5) * 3.0,
                z = base.z,
            }, base.z)
            tp = self:TeleportKeepBehindLeader(tp) or tp
            ent:SetPos(tp)
            pcall(function() self:NoteTeleport(ent) end)
            moved = true
        end)
        System.LogAlways("[MercForm] " .. k .. " stalled " .. n .. "x - " ..
                         (moved and "hauled him to the player" or "found nowhere to haul him to"))
    end
    return n
end

-- One sample of the verification window.
--
-- Each merc carries an ANCHOR: where he was when he was last seen to move, and
-- where the player was at that same moment. Comparing against a per-merc anchor
-- rather than against the previous sample is what makes this work at all - the
-- old per-sample test demanded the player cover 5m inside one 3s sample, so
-- walking slowly, or stopping to look at the merc who is not following, meant it
-- could never judge anyone. It logged zero hits in a session with a visibly
-- stuck merc.
--
-- Two independent ways to be judged stuck; both require him to have covered no
-- ground since his anchor:
--   * the PLAYER has covered ground since that anchor - he is being left behind;
--   * or he is simply far away and stationary, which is wrong regardless of what
--     the player does. This is the case the old rule could never see, because a
--     player standing still watching a stranded merc is exactly when it is most
--     obvious and least detectable by player movement.
function mercenaries:DismountVerify()
    -- A standing order re-issued inside the window: the men are MEANT to be still.
    if self.HoldActive or self.EscortEnt then self._dvUntil, self._dvPos = nil, nil; return end
    -- A wall battle owns everyone: wbLocked freezes the schedulers, so follow trees
    -- legitimately stop stamping their slots - and on the fortified-camp probe the watch
    -- read that as 44 stalls and HAULED 18 men to the player mid-battle. Stand down for
    -- the battle and let the men re-anchor fresh afterwards.
    if self.WBPhase and self.WBPhase ~= "idle" then self._dvPos = nil; return end
    -- BeginFollowVerify tested these before opening a window; the continuous watch has no
    -- such caller, so they belong here too.
    if _G.MercIdle or _G.MercenariesDismissed then self._dvPos = nil; return end

    local pp
    pcall(function() pp = player and player:GetWorldPos() end)
    if not pp then return end

    local leader = self.FormationLeader and tostring(self.FormationLeader) or nil
    self._dvPos = self._dvPos or {}
    local n = 0

    for _, ent in pairs(self.ActiveMercs or {}) do
        local k = fhKey(ent)
        local mp
        pcall(function() mp = ent:GetWorldPos() end)

        if k and mp and k ~= leader then
            local a = self._dvPos[k]
            if not a then
                self._dvPos[k] = { x = mp.x, y = mp.y, px = pp.x, py = pp.y }
            else
                local dx, dy = mp.x - a.x, mp.y - a.y
                local moved = math.sqrt(dx * dx + dy * dy)

                if moved >= self.DismountVerifyMoved then
                    -- He is following. Re-anchor here, and forget any escalation - the
                    -- streak only means anything while it is unbroken.
                    self._dvPos[k] = { x = mp.x, y = mp.y, px = pp.x, py = pp.y }
                    self.FollowStallStreak[k] = nil
                else
                    local qx, qy = pp.x - a.px, pp.y - a.py
                    local drift  = math.sqrt(qx * qx + qy * qy)
                    local ex, ey = pp.x - mp.x, pp.y - mp.y
                    local far    = math.sqrt(ex * ex + ey * ey)

                    -- Far-but-stationary means nothing for a man demonstrably in his slot.
                    local farCounts = (far >= self.DismountVerifyFar)
                                      and not self:FormationSlotFresh(k)
                    if drift >= self.DismountVerifyPlayer or farCounts then
                        -- A man walking a nav order (hold station, wall staging) is not
                        -- following by design, and re-firing follow would fight the walk.
                        local busy = false
                        pcall(function()
                            local w = ent.this and ent.this.id or ent.id
                            busy = self:IsCampActor(w)
                                or self:IsNavGotoActive(ent)
                                or ent.soul:HasScriptContext("crime_interruptAttack")
                                -- Committed to an enemy: the approach to one is legitimately
                                -- slow. Only reachable now the watch runs outside a window.
                                or (self.MercTargetOf or {})[tostring(w)] ~= nil
                        end)
                        if not busy then
                            self:FollowStalled(ent)
                            -- ESCALATE ONLY ON A DEAD TREE. A re-fire is cheap and harmless,
                            -- so everyone judged stuck gets one - but the escalation takes a
                            -- man out of the formation, and doing that to somebody who is
                            -- fine is far worse than the stall it is meant to cure. A FRESH
                            -- slot claim is positive proof his tree is running (follow.xml
                            -- stamps it every pass), and the drift test alone flags the front
                            -- ranks of a deep column whenever the player pauses - the first
                            -- version escalated four healthy men in one session on exactly
                            -- that, one of them the man who had just been elected leader.
                            -- The leader is never escalated at all: he owns MakeFormation, so
                            -- suppressing him takes the whole formation down with him.
                            if not self:FormationSlotFresh(k) and k ~= leader then
                                pcall(function() self:FollowEscalate(ent, k) end)
                            end
                            n = n + 1
                        end
                        -- Re-anchor either way, so one stall is one reset.
                        self._dvPos[k] = { x = mp.x, y = mp.y, px = pp.x, py = pp.y }
                    end
                end
            end
        end
    end

    if n > 0 then
        System.LogAlways('[MercForm] ' .. tostring(n) .. ' merc(s) were not following (' ..
                         tostring(self._dvReason or 'dismount') .. ') - re-firing follow on them')
    end
end

-- Opens the verification window. Resets nobody by itself - see the block comment.
function mercenaries:BeginFollowVerify(reason)
    -- They are meant to be standing, or there is no squad.
    if _G.MercIdle or _G.MercenariesDismissed then return end
    if self.HoldActive or self.EscortEnt then return end
    if not next(self.ActiveMercs or {}) then return end

    local now = fhNow()
    self._dvUntil  = now + self.DismountVerifySecs
    self._dvNextAt = now + self.DismountVerifyEvery
    self._dvPos    = nil
    self._dvReason = reason or "dismount"
end

function mercenaries:CalculateFormationTarget(bt_data, myWuid)
    local ok, err = pcall(function()
        local key = tostring(myWuid)

        -- NPC-led formations (patrols etc., see AssignNpcFormation) win over the
        -- player-squad slots; their followTarget is always explicit, so nothing
        -- here ever routes an enemy toward the player.
        local npc = self.NpcFormations and self.NpcFormations[key]
        if npc then
            bt_data.formationSlot = npc.slot
            bt_data.followTarget  = npc.followTarget
            return
        end

        local data = self.FormationSlots and self.FormationSlots[key]

        -- The formation ANCHOR always chases the player. Chain order (mounted-first /
        -- rank / hp / name) is unrelated to who leads (nearest to the player), so the
        -- leader's slot is usually past the formation width and his chain followTarget
        -- is one of his own followers. On foot this never showed, because the leader
        -- arm of follow.xml hardcodes $playerWUID - but every MOUNTED node reads
        -- $followTarget, so the anchor rode at a squadmate a few metres away, his Move
        -- succeeded on entry, and the whole MoveHistory column parked with him.
        -- Below the NpcFormations branch on purpose: those set their leader explicitly.
        if self.FormationLeader and tostring(self.FormationLeader) == key then
            bt_data.formationSlot = (data and data.slot) or 0
            bt_data.followTarget  = bt_data.playerWUID
            return
        end

        if data then
            bt_data.formationSlot = data.slot
            bt_data.followTarget  = data.followTarget or bt_data.playerWUID
        else
            bt_data.formationSlot = 0
            bt_data.followTarget  = bt_data.playerWUID
        end
    end)

    if not ok then
        System.LogAlways('[Mercenary Jeff] CalculateFormationTarget Error: ' .. tostring(err))
    end
end

-- Print the follow state of every merc on demand, plus any stall streak and suppression
-- currently in force. The same line FollowStallReport prints on an escalation, but for
-- the whole squad and without having to wait for one - the first thing to run when
-- somebody reports a merc standing still.
function mercenaries:FollowStallStatus()
    System.LogAlways('[MercForm] leader=' .. tostring(self.FormationLeader)
                     .. ' epoch=' .. tostring(self.FormationEpoch)
                     .. ' squad=' .. tostring(self.SquadSize)
                     .. ' off=' .. tostring(self._formationOffReason or 'no - formation is on'))
    local n = 0
    for _, ent in pairs(self.ActiveMercs or {}) do
        local k = ent and (ent.this and ent.this.id or ent.id)
        if k then
            k = tostring(k)
            n = n + 1
            local streak = self.FollowStallStreak[k]
            local off    = self.FollowFormationOffUntil[k]
            self:FollowStallReport(ent, k)
            if streak or off then
                System.LogAlways('[MercForm]     stallStreak=' .. tostring(streak or 0)
                                 .. ' formationSuppressed=' .. tostring(off ~= nil))
            end
        end
    end
    System.LogAlways('[MercForm] ' .. n .. ' merc(s) reported')
end

-- Clear every stall streak and suppression by hand (after fixing something, or to
-- re-test from a clean slate).
function mercenaries:FollowStallReset()
    self.FollowStallStreak       = {}
    self.FollowFormationOffUntil = {}
    self.FollowStuck             = {}
    System.LogAlways('[MercForm] stall streaks and formation suppressions cleared')
end

mercenaries:DevCommand("merc_follow_why", "mercenaries:FollowStallStatus()",
                   "Print every merc's follow state, stall streak and formation suppression")
mercenaries:DevCommand("merc_follow_reset", "mercenaries:FollowStallReset()",
                   "Clear all follow stall streaks and formation suppressions")
