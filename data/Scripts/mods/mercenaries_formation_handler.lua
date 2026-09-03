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
    -- THE LEADER FIRES FIRST. Vanilla (erik_armyMovement, moveUtils formation_follow)
    -- gates every follower on an external lock the leader releases only after his
    -- MakeFormation, so a follower never asks GetMemberFormation for a handle that does
    -- not exist yet. This stagger was pairs() order - the leader anywhere in it - so
    -- whoever re-fired before him got a null handle and sat 4 s on the follow chain
    -- (`inFormation=false` in every STALL report after a hold release, 2026-09-03).
    -- Slot 0 for him is the same guarantee without the lock.
    local leader = self.FormationLeader and tostring(self.FormationLeader) or nil
    if leader then
        self.FollowBlockUntil[leader] = now
        i = 1
    end
    for _, ent in pairs(self.ActiveMercs or {}) do
        local k = fhKey(ent)
        if k and k ~= leader then
            self.FollowBlockUntil[k] = now + i * step
            i = i + 1
        end
    end
    return (i - 1) * step
end

-- One call per merc per scheduler tick: publishes the guard above into the BT.
--
-- It also takes the SCHEDULER's own heartbeat and the value of the follow latch. Those
-- two, against the FOLLOW TREE's heartbeat (FormationSlotAt, stamped by
-- UpdateFormationRole from follow.xml's own always-on loop), are what makes the race
-- described above visible instead of inferred - see FollowGhostSweep.
mercenaries.FollowLatchOf  = {}   -- [k] = the merc's own $isFollowingActive, as he sees it
mercenaries.FollowSchedAt  = {}   -- [k] = when his SCHEDULER last ran (this function)

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
        self.FollowSchedAt[k] = now
        self.FollowLatchOf[k] = (bt_data.isFollowingActive == true)
    end)
    if not ok then System.LogAlways('[MercForm] FollowGate error') end
end

-- ---------------------------------------------------------------------------
-- THE GHOST LATCH - a merc who believes he is following with nothing running.
--
-- The eviction race documented above ends with `$isFollowingActive = true` and no follow
-- behaviour underneath it. The follow arm only ever retries on a FALSE latch, so he stands
-- there for good. Until now the only thing that could rescue him was the scheduler's 35 m
-- self-heal, which by construction cannot see a man who stopped NEXT TO the player - and
-- that is exactly the report: a handful of men in a fifty-man column standing about,
-- sometimes recovering (when they drift past 35 m) and sometimes not.
--
-- It is directly observable, no distance and no movement involved, because there are two
-- independent heartbeats:
--
--   FollowSchedAt   - his scheduler ran (FollowGate, ~600ms). Proves the merc is ticking.
--   FormationSlotAt - his FOLLOW TREE ran (UpdateFormationRole, ~1s, in follow.xml's own
--                     always-on loop, whichever locomotion arm is active).
--
-- Scheduler fresh + latch true + follow tree silent = the race, caught wherever he stands.
mercenaries.FollowTreeStaleSecs = 6.0    -- follow tree silent this long while latched
mercenaries.FollowGhostLogEvery = 10.0   -- per merc, so a persistent one cannot spam
mercenaries.FollowGhostEvery    = 3.0    -- how often the sweep runs
mercenaries.FollowGhostAt = {}

function mercenaries:FollowGhostSweep()
    if _G.MercIdle or _G.MercenariesDismissed then return end
    if self.HoldActive or self.EscortEnt then return end
    if self.WBPhase and self.WBPhase ~= "idle" then return end
    local now = fhNow()

    for _, ent in pairs(self.ActiveMercs or {}) do
        local k = fhKey(ent)
        local schedAt = k and self.FollowSchedAt[k]
        -- Only judge a merc whose scheduler is demonstrably running. No stamp at all means
        -- he has not been seen yet, not that he is stuck.
        if k and schedAt and (now - schedAt) <= 3.0 and self.FollowLatchOf[k] then
            local treeAt  = (self.FormationSlotAt or {})[k]
            local treeAge = treeAt and (now - treeAt) or 9999
            if treeAge >= (self.FollowTreeStaleSecs or 6.0) then
                -- Everything that legitimately replaces the follow tree.
                local busy, why = false, nil
                pcall(function()
                    local w = ent.this and ent.this.id or ent.id
                    if self:IsCampActor(w) then busy, why = true, "camp actor"
                    elseif self:IsMercInCampProper(w) then busy, why = true, "in camp"
                    elseif self:IsNavGotoActive(ent) then busy, why = true, "nav order"
                    elseif (self.MercTargetOf or {})[tostring(w)] ~= nil then busy, why = true, "has a target"
                    elseif ent.soul:HasScriptContext("crime_interruptAttack") then busy, why = true, "in combat"
                    end
                end)
                if not busy then
                    local last = self.FollowGhostAt[k]
                    if not last or (now - last) >= (self.FollowGhostLogEvery or 10.0) then
                        self.FollowGhostAt[k] = now
                        local nm, dP = "?", -1
                        pcall(function()
                            nm = ent:GetName()
                            local mp, pp = ent:GetWorldPos(), player:GetWorldPos()
                            dP = math.sqrt((pp.x - mp.x) ^ 2 + (pp.y - mp.y) ^ 2)
                        end)
                        System.LogAlways(string.format(
                            "[MercForm] GHOST LATCH: %s says he is following but his follow tree has not run in %.1fs "
                            .. "(scheduler %.1fs ago, %.0fm from the player) - evicting and re-firing",
                            tostring(nm), treeAge, now - schedAt, dP))
                    end
                    -- The existing cure: FollowStalled raises the flag the scheduler's
                    -- re-fire arm consumes (teleport to evict, then follow fresh).
                    pcall(function() self:FollowStalled(ent) end)
                end
            end
        end
    end
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

        -- The ghost-latch sweep runs on its own cadence and is NOT subject to the settle
        -- window: a latched merc whose follow tree is silent is wrong whatever the squad
        -- is doing, and a tree that is merely walking to a new slot still stamps every
        -- second. It is also the one check that works at zero distance.
        if not self._fgNextAt or now >= self._fgNextAt then
            self._fgNextAt = now + (self.FollowGhostEvery or 3.0)
            self:FollowGhostSweep()
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
mercenaries.FollowEscalateFormAt    = 3    -- stalls before the STALL report (and, if enabled, the drop-out)
mercenaries.FollowEscalateTeleAt    = 6    -- ...and before hauling him to the player
mercenaries.FollowFormationOffSecs  = 30.0
-- TIER 2 IS OFF. Dropping a man out of the engine formation for 30 s and re-admitting him
-- is, seen from the saddle, a man who "breaks formation and then returns" - and at fifty
-- men one or two were always doing it (2026-09-03). The log shows why: a formation REBUILD
-- deals every follower a new slot, they all take a few seconds to walk to it, the watch
-- flagged 49 of 50 as stalled, and the ladder ejected them six at a time. A man slow to
-- reach his slot is better left in it than thrown out of it. The tier is kept behind this
-- flag for diagnosis; the report it printed still prints.
mercenaries.FollowDropOutEnabled    = false
-- After any rebuild (epoch change) the watch does nothing for this long: base plus per man,
-- since fifty men re-acquiring slots takes longer than six. 13.5 s at fifty.
mercenaries.FollowSettleBaseSecs    = 6.0
mercenaries.FollowSettlePerMercSecs = 0.15
-- The player-drift stall test, as a fraction of the shape's capacity. A column of fifty is
-- ~45 m deep: when the player takes his first five metres the rear ranks are SUPPOSED to
-- stand still - that is the slack in the shape - so a flat 5 m read the whole back half as
-- stalled. 0.25 x cap = 12.5 m at fifty, and the flat value still applies to small squads.
mercenaries.DismountVerifyPlayerPerCap = 0.25
-- The haul is refused for a man this close to the player, or this close to the man ahead
-- of him in the chain - he is where he was put, not wedged.
mercenaries.FollowHaulMinFromPlayer = 15.0
mercenaries.FollowHaulMinFromAhead  = 8.0
-- merc_formprobe 0|1: every watch pass prints a summary and one line per flagged man
-- (distance to the player, to the man ahead, slot, in-formation flag, stamp age, streak).
mercenaries.FormProbe = false

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
        -- The two distances that decide whether a stall is a problem at all.
        local mp, pp = ent:GetWorldPos(), player:GetWorldPos()
        add("dPlayer", string.format("%.0f", math.sqrt((pp.x - mp.x) ^ 2 + (pp.y - mp.y) ^ 2)))
        local t = d and d.followTarget and XGenAIModule.GetEntityByWUID(d.followTarget)
        local tp = t and t:GetWorldPos()
        add("dAhead", tp and string.format("%.0f", math.sqrt((tp.x - mp.x) ^ 2 + (tp.y - mp.y) ^ 2)) or "-")
        local at = (self.FormationSlotAt or {})[k]
        add("stampAge", at and string.format("%.1fs", fhNow() - at) or "-")
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
        if self.FollowDropOutEnabled then
            self.FollowFormationOffUntil[k] = fhNow() + self.FollowFormationOffSecs
            -- Deliberately NOT a CampFormationDirty: that nulls the leader and re-elects,
            -- which drops the WHOLE squad onto the chain to fix one man. UpdateFormationSlots
            -- rebuilds from scratch every pass and UpdateFormationRole publishes per merc, so
            -- he leaves the formation on his own next tick and the chain re-packs itself.
            System.LogAlways("[MercForm] " .. k .. " stalled " .. n ..
                             "x - dropping him out of the formation onto the follow chain")
        else
            System.LogAlways("[MercForm] " .. k .. " stalled " .. n ..
                             "x - left in his slot (drop-out is off); hauled at " .. tostring(self.FollowEscalateTeleAt))
        end
    elseif n >= self.FollowEscalateTeleAt then
        self:FollowStallReport(ent, k)
        self.FollowStallStreak[k] = 0          -- one haul per streak, then judge him afresh
        -- A man standing where the chain wants him is not wedged, however still he is: the
        -- rear of a fifty-man column queues behind the man ahead. Hauling him then is the
        -- most visible thing this mod does - he vanishes and reappears at the player - for
        -- nothing. Only a man far from BOTH the player and the man ahead of him is hauled.
        local dP, dT = -1, -1
        pcall(function()
            local mp = ent:GetWorldPos()
            local pp = player:GetWorldPos()
            dP = math.sqrt((pp.x - mp.x) ^ 2 + (pp.y - mp.y) ^ 2)
            local d = (self.FormationSlots or {})[k]
            local t = d and d.followTarget and XGenAIModule.GetEntityByWUID(d.followTarget)
            local tp = t and t:GetWorldPos()
            if tp then dT = math.sqrt((tp.x - mp.x) ^ 2 + (tp.y - mp.y) ^ 2) end
        end)
        if (dP >= 0 and dP <= (self.FollowHaulMinFromPlayer or 15.0))
           or (dT >= 0 and dT <= (self.FollowHaulMinFromAhead or 8.0)) then
            System.LogAlways(string.format("[MercForm] %s stalled %dx - NOT hauled: %.0fm from the player, %.0fm from the man ahead - he is where the chain put him",
                                           k, n, dP, dT))
            return n
        end
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
-- ---------------------------------------------------------------------------
-- "THE WHOLE WORLD STOPPED" IS NOT "THIS MAN STOPPED".
--
-- The watch judges a merc from positions, and positions cannot tell the two apart. On
-- the map screen - which is where a fast travel spends its ENTIRE duration - the
-- behaviour trees stop running: nobody moves, and nobody stamps a slot claim, so
-- FormationSlotFresh goes false squad-wide and the far-but-stationary test flags every
-- man in the rear of the column, every sample, for as long as the map is up.
--
-- Measured from one session's kcd.log: 3,163 follow re-fires, 527 escalations and 59
-- MakeFormation rebuilds, of which 131 of the 133 sampling passes fell inside the map
-- screen and 2 outside it. That is not Lua time - a tier-3 escalation is a 10-ray
-- GetSafeSpawnPosition sweep plus a SetPos, per man - which is why fast travel dragged.
--
-- Two independent stand-downs, because the freeze has two shapes:
--   * the trees are not ticking at all -> the heartbeat goes stale (map screen, a load)
--   * the trees ARE ticking but the world is not simulating the men -> no heartbeat
--     evidence, so fall back to the shape of the answer: a pass that indicts half the
--     squad at once is describing the world, not the men.
-- Both drop the anchors, so the squad is judged afresh from where it stands when the
-- world comes back rather than against where it stood before it stopped.
mercenaries.FollowWatchBtStaleSecs  = 2.5   -- no MercIsIdle call in this long = trees frozen
mercenaries.FollowWatchSystemicFrac = 0.5   -- this share of the squad flagged at once...
mercenaries.FollowWatchSystemicMin  = 5     -- ...and at least this many men, is systemic
mercenaries.FollowWatchSystemicLog  = 15.0  -- seconds between systemic stand-down log lines
mercenaries.FollowWatchSystemicRepair = 6   -- ...repaired per pass when the world is NOT frozen

function mercenaries:FollowWatchWorldFrozen()
    local at = self.BtHeartbeatAt
    if at and (fhNow() - at) > (self.FollowWatchBtStaleSecs or 2.5) then return true end
    -- Second, independent read of the same fact, and the one the logs actually show: if
    -- the squad holds engine-formation slots and NOT ONE of them has been stamped
    -- recently, every follow tree in the company stopped in the same instant. That is
    -- the world, not thirty separate failures. One fresh claim anywhere disproves it.
    local inSlot = 0
    for k, v in pairs(self.FormationInSlot or {}) do
        if v then
            if self:FormationSlotFresh(k) then return false end
            inSlot = inSlot + 1
        end
    end
    return inSlot >= (self.FollowWatchSystemicMin or 5)
end

-- The heartbeat and the anchors are plain Lua tables, so they survive the load that
-- kills the trees and moves every merc. Left alone they describe a world that no longer
-- exists, which is the same false-stall storm one level up. Cleared here; both
-- re-establish themselves within a scheduler poll.
function mercenaries:FollowWatchOnLoad()
    self.BtHeartbeatAt   = nil
    self._dvPos          = nil
    self._dvUntil        = nil
    self._dvSysLoggedAt  = nil
    self._dvEpochSeen    = nil     -- the first pass after a load is a rebuild, and settles
    self._dvSettleUntil  = nil
    self._dvSettleWhy    = nil
    self._fgNextAt       = nil
    self.FollowStallStreak = {}
    -- Both heartbeats are per-session and meaningless across a load: a stale stamp from
    -- before it would read as a ghost latch on the first sweep.
    self.FollowLatchOf, self.FollowSchedAt, self.FollowGhostAt = {}, {}, {}
end

function mercenaries:FormProbeSet(on)
    self.FormProbe = on and true or false
    System.LogAlways("[FormProbe] " .. (self.FormProbe and "ON - every watch pass is logged" or "off"))
end

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
    -- Nothing moved because nothing is running. See the block comment above.
    if self:FollowWatchWorldFrozen() then self._dvPos = nil; return end

    -- A REBUILD is not a stall. Every epoch change deals every follower a new slot and they
    -- all walk to it, which the watch used to read as the whole squad stalling at once
    -- (49 of 50, 2026-09-03) and then eject men six at a time. Sit the whole settle window
    -- out, anchors and streaks dropped, and judge them afresh from where they stand after.
    -- The same window is opened by BeginFollowVerify for every other whole-squad re-fire
    -- (a hold or escort released, a dismount, a hire): those are rebuild-sized bursts that
    -- bump no epoch, and the first version of this window missed them - the very next test
    -- released a fifty-man hold and hauled six men twelve seconds later.
    local nowS = fhNow()
    if self.FormationEpoch ~= self._dvEpochSeen then
        self._dvEpochSeen = self.FormationEpoch
        self:FollowSettle("rebuild #" .. tostring(self.FormationEpoch))
    end
    if self._dvSettleUntil and nowS < self._dvSettleUntil then
        self._dvPos = nil
        if self.FormProbe and (not self._fpSettleLogAt or (nowS - self._fpSettleLogAt) >= 2.0) then
            self._fpSettleLogAt = nowS
            System.LogAlways(string.format("[FormProbe] settling: %.1fs left (%s)",
                                           self._dvSettleUntil - nowS, tostring(self._dvSettleWhy)))
        end
        return
    end
    -- Inside a verification window the watch only RE-FIRES. The window exists to catch a
    -- man who silently failed to start walking after a burst; hauling him belongs to the
    -- continuous watch, once the squad has had its settle and is plainly formed up.
    local windowOnly = (self._dvUntil ~= nil) and (nowS <= self._dvUntil)

    local pp
    pcall(function() pp = player and player:GetWorldPos() end)
    if not pp then return end

    local leader = self.FormationLeader and tostring(self.FormationLeader) or nil
    -- The drift gate scales with the shape: the rear of a deep column stands still while
    -- the player walks its slack. See DismountVerifyPlayerPerCap.
    local driftGate = math.max(self.DismountVerifyPlayer,
                               (self.FormationCap or 0) * (self.DismountVerifyPlayerPerCap or 0))
    self._dvPos = self._dvPos or {}
    -- Indicted first, acted on afterwards: the count is what decides whether this pass
    -- is describing the men or the world, and it is not known until the sweep is done.
    local cand, squad = {}, 0
    for _ in pairs(self.ActiveMercs or {}) do squad = squad + 1 end

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
                    if drift >= driftGate or farCounts then
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
                            cand[#cand + 1] = { ent = ent, k = k }
                        end
                        -- Re-anchor either way, so one stall is one reset.
                        self._dvPos[k] = { x = mp.x, y = mp.y, px = pp.x, py = pp.y }
                    end
                end
            end
        end
    end

    if #cand == 0 then return end
    local systemicOnly = false

    -- Half the company indicted on one sample is not half the company failing; it is the
    -- world not running under them. Everyone has already been re-anchored, so standing
    -- down here costs one pass and the genuinely stuck are picked up on the next.
    local systemic = math.max(self.FollowWatchSystemicMin or 5,
                              squad * (self.FollowWatchSystemicFrac or 0.5))
    if #cand >= systemic then
        local now = fhNow()
        -- ...unless the two POSITIVE reads above say the world is running fine. Then half
        -- the company really is stranded, and standing down every pass means it stays that
        -- way. Measured 2026-09-03 on a fifty-man hire: 23 of 46 flagged, stood down, and
        -- the archers among them never moved again - FormationFollower is their only
        -- locomotion, so a man dropped out of it during a rebuild simply stops. Repair a
        -- few per pass instead: the thundering herd this guard exists to prevent is the
        -- reason for the bound, not a reason to do nothing.
        if self:FollowWatchWorldFrozen() then
            if not self._dvSysLoggedAt or (now - self._dvSysLoggedAt) >= (self.FollowWatchSystemicLog or 15.0) then
                self._dvSysLoggedAt = now
                System.LogAlways('[MercForm] ' .. tostring(#cand) .. ' of ' .. tostring(squad) ..
                                 ' merc(s) flagged at once - the world is not running under them, standing down')
            end
            return
        end
        if not self._dvSysLoggedAt or (now - self._dvSysLoggedAt) >= (self.FollowWatchSystemicLog or 15.0) then
            self._dvSysLoggedAt = now
            System.LogAlways('[MercForm] ' .. tostring(#cand) .. ' of ' .. tostring(squad) ..
                             ' merc(s) flagged at once but the world IS running under them - repairing ' ..
                             tostring(self.FollowWatchSystemicRepair or 6) .. ' per pass')
        end
        local keep = {}
        for i = 1, math.min(#cand, self.FollowWatchSystemicRepair or 6) do keep[i] = cand[i] end
        cand = keep
        -- A mass flag is a transient - a rebuild the settle window did not cover, a
        -- stream-in, a hitch - and NEVER a dozen individually stuck men. Re-fire follow on
        -- the few taken, and do not climb the ladder on any of them: the ladder is what
        -- turned "49 flagged after a rebuild" into men ejected from the formation.
        systemicOnly = true
    else
        self._dvSysLoggedAt = nil
    end

    for _, c in ipairs(cand) do
        self:FollowStalled(c.ent)
        -- ESCALATE ONLY ON A DEAD TREE. A re-fire is cheap and harmless, so everyone
        -- judged stuck gets one - but the escalation takes a man out of the formation,
        -- and doing that to somebody who is fine is far worse than the stall it is meant
        -- to cure. A FRESH slot claim is positive proof his tree is running (follow.xml
        -- stamps it every pass), and the drift test alone flags the front ranks of a deep
        -- column whenever the player pauses - the first version escalated four healthy men
        -- in one session on exactly that, one of them the man who had just been elected
        -- leader. The leader is never escalated at all: he owns MakeFormation, so
        -- suppressing him takes the whole formation down with him.
        if not systemicOnly and not windowOnly and not self:FormationSlotFresh(c.k) and c.k ~= leader then
            pcall(function() self:FollowEscalate(c.ent, c.k) end)
        end
    end

    if self.FormProbe then
        local inF, onChain = 0, 0
        for k2, v in pairs(self.FormationInSlot or {}) do if v then inF = inF + 1 else onChain = onChain + 1 end end
        System.LogAlways(string.format(
            "[FormProbe] pass: squad=%d inFormation=%d onChain=%d flagged=%d mode=%s epoch=%s leader=%s window=%s driftGate=%.1f",
            squad, inF, onChain, #cand,
            systemicOnly and "mass-refire" or (windowOnly and "verify-window" or "watch"),
            tostring(self.FormationEpoch), tostring(leader), tostring(self._dvReason),
            driftGate))
        for _, c in ipairs(cand) do
            local dP, dT, name = -1, -1, "?"
            pcall(function()
                name = c.ent:GetName()
                local mp = c.ent:GetWorldPos()
                dP = math.sqrt((pp.x - mp.x) ^ 2 + (pp.y - mp.y) ^ 2)
                local d = (self.FormationSlots or {})[c.k]
                local t = d and d.followTarget and XGenAIModule.GetEntityByWUID(d.followTarget)
                local tp = t and t:GetWorldPos()
                if tp then dT = math.sqrt((tp.x - mp.x) ^ 2 + (tp.y - mp.y) ^ 2) end
            end)
            local age = "-"
            pcall(function()
                local at = (self.FormationSlotAt or {})[c.k]
                if at then age = string.format("%.1fs", nowS - at) end
            end)
            System.LogAlways(string.format(
                "[FormProbe]   %s: dPlayer=%.1f dAhead=%.1f slot=%s inFormation=%s slotStamp=%s streak=%d",
                tostring(name), dP, dT,
                tostring(((self.FormationSlots or {})[c.k] or {}).slot),
                tostring((self.FormationInSlot or {})[c.k]), age,
                self.FollowStallStreak[c.k] or 0))
        end
    end

    System.LogAlways('[MercForm] ' .. tostring(#cand) .. ' merc(s) were not following (' ..
                     tostring(self._dvReason or 'dismount') .. ') - re-firing follow on them')
end

-- The settle window: after any whole-squad re-fire the watch does nothing for base plus
-- per-man seconds, with anchors and streaks dropped. Opened by an epoch change and by
-- BeginFollowVerify, which is the funnel every other burst already goes through.
function mercenaries:FollowSettle(why)
    local squadN = 0
    for _ in pairs(self.ActiveMercs or {}) do squadN = squadN + 1 end
    local secs = (self.FollowSettleBaseSecs or 6.0) + squadN * (self.FollowSettlePerMercSecs or 0.15)
    local now  = fhNow()
    local until_ = now + secs
    if not self._dvSettleUntil or until_ > self._dvSettleUntil then self._dvSettleUntil = until_ end
    self._dvSettleWhy = why
    self._dvPos = nil
    self.FollowStallStreak = {}
    System.LogAlways(string.format("[MercForm] settle %.1fs for %d men (%s) - the watch stands down while they form up",
                                   secs, squadN, tostring(why)))
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
    -- Every caller of this is a rebuild-sized burst. Settle first, verify after.
    self:FollowSettle(self._dvReason)
    -- ...and the window itself must outlast the settle, or it closes before it looked.
    if self._dvSettleUntil and self._dvUntil < self._dvSettleUntil + 10.0 then
        self._dvUntil = self._dvSettleUntil + 10.0
    end
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
-- WHY IS HE STANDING. One line per merc, with both heartbeats and a verdict, so the
-- answer does not have to be inferred from a STALL record that only prints on escalation.
-- The verdict names the state, not a guess: LATCHED-NO-TREE is the eviction race,
-- NOT-LATCHED means the scheduler has not re-fired him yet, and so on.
function mercenaries:FollowWhyStand()
    local now = fhNow()
    local pp
    pcall(function() pp = player:GetWorldPos() end)
    System.LogAlways(string.format('[WhyStand] leader=%s epoch=%s squad=%s off=%s settle=%s',
        tostring(self.FormationLeader), tostring(self.FormationEpoch), tostring(self.SquadSize),
        tostring(self._formationOffReason or 'no - formation is on'),
        (self._dvSettleUntil and now < self._dvSettleUntil)
            and string.format('%.1fs left', self._dvSettleUntil - now) or 'no'))
    local n, ghosts, standing = 0, 0, 0
    for _, ent in pairs(self.ActiveMercs or {}) do
        local k = fhKey(ent)
        if k then
            n = n + 1
            local schedAt = self.FollowSchedAt[k]
            local treeAt  = (self.FormationSlotAt or {})[k]
            local schedAge = schedAt and (now - schedAt) or -1
            local treeAge  = treeAt and (now - treeAt) or -1
            local latched  = self.FollowLatchOf[k] == true
            local inSlot   = (self.FormationInSlot or {})[k] == true
            local nm, dP, mp = "?", -1, nil
            pcall(function()
                nm = ent:GetName()
                mp = ent:GetWorldPos()
                if pp and mp then dP = math.sqrt((pp.x - mp.x) ^ 2 + (pp.y - mp.y) ^ 2) end
            end)
            -- Did he move since the last time this was asked?
            local moved = -1
            local a = (self._wsPos or {})[k]
            if a and mp then moved = math.sqrt((mp.x - a.x) ^ 2 + (mp.y - a.y) ^ 2) end
            self._wsPos = self._wsPos or {}
            if mp then self._wsPos[k] = { x = mp.x, y = mp.y } end

            local busy = nil
            pcall(function()
                local w = ent.this and ent.this.id or ent.id
                if self:IsCampActor(w) then busy = "camp actor"
                elseif self:IsMercInCampProper(w) then busy = "in camp"
                elseif self:IsNavGotoActive(ent) then busy = "nav order"
                elseif (self.MercTargetOf or {})[tostring(w)] ~= nil then busy = "has a target"
                elseif ent.soul:HasScriptContext("crime_interruptAttack") then busy = "in combat"
                end
            end)

            local verdict
            if busy then verdict = "BUSY (" .. busy .. ")"
            elseif schedAge < 0 or schedAge > 3.0 then verdict = "SCHEDULER SILENT - his host tree is not running"
            elseif latched and treeAge >= 0 and treeAge < (self.FollowTreeStaleSecs or 6.0) then
                verdict = inSlot and "OK - in formation" or "OK - following on the chain"
            elseif latched then
                verdict = "LATCHED-NO-TREE - the eviction race; the sweep will re-fire him"
                ghosts = ghosts + 1
            else
                verdict = "NOT LATCHED - waiting for the scheduler to fire follow"
            end
            if moved >= 0 and moved < 0.5 then standing = standing + 1 end

            System.LogAlways(string.format(
                '[WhyStand] %-42s d=%5.1fm moved=%5.1f latch=%-5s inSlot=%-5s sched=%4.1fs tree=%5.1fs slot=%-4s block=%-5s :: %s',
                tostring(nm), dP, moved, tostring(latched), tostring(inSlot), schedAge, treeAge,
                tostring(((self.FormationSlots or {})[k] or {}).slot),
                tostring(self.FollowBlockUntil[k] ~= nil), verdict))
        end
    end
    System.LogAlways(string.format('[WhyStand] %d merc(s): %d ghost-latched, %d had not moved since the last call',
                                   n, ghosts, standing))
end

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
