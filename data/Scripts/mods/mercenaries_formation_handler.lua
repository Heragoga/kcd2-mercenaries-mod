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
    return true
end


function mercenaries:UpdateFormationSlots()
    local ok, err = pcall(function()
        self.FormationSlots = {}

        local mounted   = {}
        local unmounted = {}

        for name, ent in pairs(self.ActiveMercs) do
            local entWuid  = ent and (ent.this and ent.this.id or ent.id)
            -- Mercs holding the camp aren't part of the marching formation; only
            -- sortie mercs (and the whole squad when there's no camp) form up.
            if self:IsAliveAndWell(ent, false) and not self:IsMercInCampProper(entWuid) then
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
mercenaries.FollowStuck = {}   -- [wuidStr] = true

local function fhKey(ent)
    local w = ent and ((ent.this and ent.this.id) or ent.id)
    return w and tostring(w) or nil
end

-- Called by the teleporter. A merc who had to be dragged back to the player is by
-- definition not following, and the teleport itself is what HID him from the
-- scheduler's 35m self-heal: it resets his distance every pass, so the stuck
-- merc never stays far enough away long enough to be noticed. Gate is already
-- tight upstream - out of combat, not idle, not in camp, player not mounted.
function mercenaries:FollowStalled(ent)
    local ok = pcall(function()
        local k = fhKey(ent)
        if k then self.FollowStuck[k] = true end
    end)
    if not ok then System.LogAlways('[MercForm] FollowStalled error') end
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
        if not self.FollowStuck[k] then return end
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
-- bounded on all sides: it only runs inside a window after a dismount, it only
-- judges a merc on a tick where the PLAYER has actually moved (so a squad standing
-- still with a standing player is never touched), and it cannot spawn horses
-- because it only runs while the player is on foot.
-- ---------------------------------------------------------------------------
mercenaries.DismountResetDelay   = 2.0   -- seconds after dismount before watching
mercenaries.DismountVerifySecs   = 25.0  -- keep verifying this long
mercenaries.DismountVerifyEvery  = 2.0   -- how often to sample inside that window
mercenaries.DismountVerifyMoved  = 1.0   -- a merc covering less than this has not moved
mercenaries.DismountVerifyPlayer = 5.0   -- ...judged stuck once the player has covered this much
mercenaries.DismountVerifyFar    = 22.0  -- ...or if he is simply this far away and stationary

local function fhNow()
    local t = 0
    pcall(function() t = System.GetCurrTime() or 0 end)
    return t
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
            self:BeginDismountReset()
        end

        -- Verification window: did the reset actually take?
        if self._dvUntil then
            if now > self._dvUntil then
                self._dvUntil, self._dvPos = nil, nil
            elseif not self._dvNextAt or now >= self._dvNextAt then
                self._dvNextAt = now + self.DismountVerifyEvery
                self:DismountVerify()
            end
        end
    end)
    if not ok then System.LogAlways('[MercForm] DismountWatch error') end
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
                    -- He is following. Re-anchor here.
                    self._dvPos[k] = { x = mp.x, y = mp.y, px = pp.x, py = pp.y }
                else
                    local qx, qy = pp.x - a.px, pp.y - a.py
                    local drift  = math.sqrt(qx * qx + qy * qy)
                    local ex, ey = pp.x - mp.x, pp.y - mp.y
                    local far    = math.sqrt(ex * ex + ey * ey)

                    if drift >= self.DismountVerifyPlayer or far >= self.DismountVerifyFar then
                        local busy = false
                        pcall(function()
                            busy = self:IsCampActor(ent.this and ent.this.id or ent.id)
                                or ent.soul:HasScriptContext("crime_interruptAttack")
                        end)
                        if not busy then
                            self.FollowStuck[k] = true
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
        System.LogAlways('[MercForm] dismount verify: ' .. tostring(n) ..
                         ' merc(s) still not following - resetting again')
    end
end

-- Opens the verification window. Resets nobody by itself - see the block comment.
function mercenaries:BeginDismountReset()
    -- They are meant to be standing, or there is no squad.
    if _G.MercIdle or _G.MercenariesDismissed then return end
    if not next(self.ActiveMercs or {}) then return end

    local now = fhNow()
    self._dvUntil  = now + self.DismountVerifySecs
    self._dvNextAt = now + self.DismountVerifyEvery
    self._dvPos = nil
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