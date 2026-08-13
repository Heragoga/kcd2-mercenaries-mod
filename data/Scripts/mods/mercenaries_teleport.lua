-- How far a merc may trail before he is dragged back. This MUST scale with the squad: a
-- fifty-man line formation is enormous, the outer files are legitimately far from the player,
-- and a flat 50m gate had them teleporting continuously. Each teleport is a hard SetPos that
-- resets the merc's position mid-path, so continuous teleporting is continuous churn - and
-- churn is what breaks follow trees and leaves men standing about.
--
-- Line is the widest shape and column the deepest, so both need more room than a square.
mercenaries.TeleportDistBase    = 50.0
mercenaries.TeleportDistPerMerc = 1.4
mercenaries.TeleportDistMax     = 130.0

-- The LEADER is on a much shorter leash, and it does NOT scale. He is the formation anchor:
-- the whole shape hangs off him, so a leader who has dropped back takes fifty men with him,
-- and the followers' generous scaled gate exists precisely because they are measured from a
-- leader who is supposed to be near the player. He follows the player directly and normally
-- sits a few metres away, so this only fires when something is actually wrong.
mercenaries.TeleportLeaderDist = 20.0

function mercenaries:TeleportDistance(isLeader)
    if isLeader then return self.TeleportLeaderDist end
    local squad = self.SquadSize or 0
    local d = self.TeleportDistBase + squad * self.TeleportDistPerMerc
    if d > self.TeleportDistMax then d = self.TeleportDistMax end
    return d
end

-- Being teleported ONCE is normal - a straggler caught a bad path and got a lift. Being
-- teleported repeatedly means he is not actually following, and only then is his follow tree
-- worth restarting.
--
-- This used to raise FollowStalled on every single teleport, which was self-defeating: with a
-- big squad tripping the gate often, every one of those mercs had his follow behaviour evicted
-- and re-fired each time. That is precisely the churn that breaks follow trees and leaves men
-- standing about - the symptom the flag exists to cure.
mercenaries.TeleportStallCount = 3      -- this many teleports...
mercenaries.TeleportStallWindow = 45.0  -- ...inside this many seconds means he is not following
mercenaries._tpSeen = {}

function mercenaries:NoteTeleport(ent)
    local k = tostring((ent.this and ent.this.id) or ent.id)
    local now = 0
    pcall(function() now = System.GetCurrTime() or 0 end)

    local r = self._tpSeen[k]
    if not r or (now - r.at) > self.TeleportStallWindow then
        self._tpSeen[k] = { n = 1, at = now }
        return
    end

    r.n = r.n + 1
    if r.n >= self.TeleportStallCount then
        self._tpSeen[k] = nil
        pcall(function() self:FollowStalled(ent) end)
    end
end

-- How far behind the formation leader a teleported straggler must land, and how wide the
-- "in front of him" wedge is. A merc dropped ahead of the leader physically blocks the one
-- NPC the whole formation hangs off: he stalls, everyone behind him stalls, the gap to the
-- player grows, more mercs trip the 50m line and are teleported in front of him too - which
-- is how one straggler turns into a teleporting pile-up.
mercenaries.TeleportLeaderClear = 4.0    -- push at least this far behind the leader
mercenaries.TeleportLeaderGuard = true

-- Circle formation is the exception: it is defined by mercs standing all round the player,
-- so "behind the leader" is meaningless there and enforcing it would collapse the ring.
function mercenaries:TeleportGuardActive()
    if not self.TeleportLeaderGuard then return false end
    local shape = self.FormationShape
    if shape and string.find(tostring(shape), "circle", 1, true) then return false end
    return true
end

-- Nudge a teleport destination out of the wedge in front of the leader, along the axis he is
-- travelling (leader -> player), leaving everything else about the chosen spot alone.
function mercenaries:TeleportKeepBehindLeader(pos)
    if not (pos and self:TeleportGuardActive()) then return pos end

    local out = pos
    pcall(function()
        local lw = self.FormationLeader
        if not lw then return end
        local le = XGenAIModule.GetEntityByWUID(lw)
        local lp = le and le:GetWorldPos()
        local pp = player and player:GetWorldPos()
        if not (lp and pp) then return end

        -- Forward = the way the leader is heading, i.e. toward the player.
        local fx, fy = pp.x - lp.x, pp.y - lp.y
        local flen = math.sqrt(fx * fx + fy * fy)
        if flen < 0.5 then return end
        fx, fy = fx / flen, fy / flen

        -- How far along that axis the spot sits relative to the leader. Positive = ahead.
        local ax, ay = pos.x - lp.x, pos.y - lp.y
        local ahead = ax * fx + ay * fy
        if ahead <= -self.TeleportLeaderClear then return end   -- already safely behind

        local push = ahead + self.TeleportLeaderClear
        local cand = { x = pos.x - fx * push, y = pos.y - fy * push, z = pos.z }
        local g = self:FindValidGround(cand, pos.z)
        out = g or cand
    end)
    return out
end

-- Teleport any active merc that has fallen too far behind. One shared pass over
-- the roster (from MonitorLoop, once/sec), replacing a per-merc BT raycast loop.
function mercenaries:MonitorDistanceAndTeleport()
    local ok, err = pcall(function()
        if _G.MercIdle or _G.MercenariesDismissed then return end
        -- Never teleport while the player is mounted. A merc is either on his own
        -- horse or running to catch one, and SetPos does not bring the horse with
        -- him: it strands the rider beside a horse that is somewhere else, or drops
        -- a mounted merc who then has to remount. Riders legitimately trail much
        -- further than the 50m gate anyway - the mounted formation alone is 64m
        -- deep at 50 mercs - so on horseback this fires constantly and never helps.
        if _G.PlayerMounted then return end
        if not player then return end

        local playerPos = player:GetPos()
        if not playerPos then return end

        local gate       = self:TeleportDistance(false)
        local leaderGate = self:TeleportDistance(true)
        local leaderKey  = self.FormationLeader and tostring(self.FormationLeader) or nil

        -- The safe-position sweep (10 rays) runs at most once per pass and is
        -- shared by every straggler; jitter stops them stacking on one spot.
        local sharedSafePos = nil
        local sweepDone = false

        for name, ent in pairs(self.ActiveMercs) do
            -- A merc who stayed in camp must never be teleported to the player.
            local inCampProper = false
            pcall(function() inCampProper = self:IsMercInCampProper(ent.this and ent.this.id or ent.id) end)
            if ent and ent.actor and not inCampProper then
                -- Don't teleport a merc out of a fight mid-swing.
                local inCombat = false
                pcall(function() inCombat = ent.soul:HasScriptContext("crime_interruptAttack") end)

                if not inCombat then
                    local mp = ent:GetPos()
                    if mp then
                        local dx = playerPos.x - mp.x
                        local dy = playerPos.y - mp.y
                        local dz = playerPos.z - mp.z
                        local distance = math.sqrt(dx*dx + dy*dy + dz*dz)

                        local isLeader = leaderKey ~= nil
                            and tostring(ent.this and ent.this.id or ent.id) == leaderKey

                        if distance > (isLeader and leaderGate or gate) then
                            if not sweepDone then
                                sweepDone = true
                                sharedSafePos = self:GetSafeSpawnPosition(player, 10)
                            end
                            if sharedSafePos then
                                -- Validate the jittered spot so a straggler
                                -- isn't teleported onto a tree/rock (the jitter
                                -- and flat z alone could land on one).
                                local tp = self:FindValidGround({
                                    x = sharedSafePos.x + (math.random() - 0.5) * 3.0,
                                    y = sharedSafePos.y + (math.random() - 0.5) * 3.0,
                                    z = sharedSafePos.z
                                }, sharedSafePos.z)
                                -- Both of these are about the leader, so neither applies TO him:
                                -- pushing him behind himself is meaningless, and his follow tree
                                -- is the one that owns MakeFormation - restarting it destroys the
                                -- formation and drops every follower onto the chain until it is
                                -- rebuilt. His short leash means he teleports more often than the
                                -- rest, so flagging him would churn the whole squad.
                                if not isLeader then
                                    tp = self:TeleportKeepBehindLeader(tp) or tp
                                end
                                ent:SetPos(tp)
                                if not isLeader then
                                    pcall(function() self:NoteTeleport(ent) end)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    if not ok then
        System.LogAlways('[Mercenary Jeff] MonitorDistanceAndTeleport Error: ' .. tostring(err))
    end
end