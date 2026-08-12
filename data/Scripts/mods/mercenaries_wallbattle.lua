-- Walled battles, staged.
--
-- Continuous wall-aware pathfinding during a fight never held up: an NPC would run
-- along the wall for a bit and then turn into it, because engine combat movement keeps
-- steering at the target and no amount of re-routing outvotes it every tick.
--
-- So the fight is staged instead. We know when an attack starts and we control where
-- everyone is, so before any blows are exchanged both sides walk to sensible places -
-- the gaps in the wall, with the defenders spread to match where the attackers are
-- going - and only then does combat open. Once it is open the wall discipline is
-- dropped entirely: a bit of clipping mid-melee is not worth fighting the engine over.
--
-- Phases:
--   idle    no attackers near a walled camp. Wall rules apply (patrol, no cross-wall
--           targeting) but nothing is being marshalled.
--   staging both sides routed to their gap positions; targeting across the wall stays
--           blocked and our combat fires are suppressed so nobody starts early. Nothing
--           physically stops a man walking through the wall - only his orders do.
--   battle  everyone is in place (or staging timed out). All wall rules OFF - normal
--           combat, clipping tolerated.

mercenaries.WBPhase = "idle"          -- idle | staging | battle
mercenaries.WBGaps = nil              -- cached gap list for the current wall version
mercenaries.WBGapsVersion = nil
mercenaries.WBAssign = {}             -- [entKey] = { gap =, pos =, side = }
mercenaries.WBStartedAt = 0
mercenaries.WBTickMs = 700

mercenaries.WBTriggerRange   = 55.0   -- an attacker this close to camp starts staging
mercenaries.WBStageTimeout   = 12.0   -- seconds before we start the fight regardless
mercenaries.WBStageQuorum    = 0.9    -- once this share is in place, the rest get WBStageGrace
mercenaries.WBStageGrace     = 2.0    -- ...and then the fight opens without the stragglers
mercenaries.WBStagedDist     = 3.0    -- close enough to a staging spot to count as ready
mercenaries.WBLineSpacing    = 1.8    -- shoulder to shoulder along the line
mercenaries.WBLineWidth      = 12     -- hard cap on men per rank; the gap width normally decides
mercenaries.WBRankSpacing    = 2.2    -- depth between ranks
mercenaries.WBColumnSpacing  = 2.5    -- file spacing while marching in column
mercenaries.WBFormBreak      = 10.0   -- leader this close to his mark: column breaks into line
mercenaries.WBOutsideOffset  = 7.0    -- attackers form up this far outside the gap
mercenaries.WBInsideOffset   = 5.0    -- defenders this far inside it
mercenaries.WBBattleEndDelay = 8.0    -- seconds with no attackers before going back to idle
mercenaries.WBMarchSpeed     = 2.5    -- assumed m/s, only used to budget staging time
-- A man this far off his place: the leader stands fast. Kept high, and only acted on
-- after WBStretchTicks consecutive checks, because a leader who halts the moment the
-- block loosens produces a rhythmic stop-go march - they close up, he starts, they
-- string out, he stops. Holding should be the exception, not the cadence.
mercenaries.WBColumnStretch  = 14.0
mercenaries.WBStretchTicks   = 3      -- consecutive over-threshold checks before he halts
mercenaries.WBHoldMax        = 5.0    -- and he never waits longer than this
-- Attacker this close to a defender: the fight is on. Worth keeping at roughly
-- WBOutsideOffset + WBInsideOffset - the width of no-man's-land between the two lines -
-- so the first man to reach the gap starts it and the rest walk in behind him.
mercenaries.WBEngageDist     = 12.0
mercenaries.WBRaidForce      = nil    -- a spawned raid: counts as attackers at any range
mercenaries.WBOpenCampRadius = 12.0   -- stand-in wall radius for a camp with no wall
mercenaries.WBOpenBearing    = nil    -- which way an unwalled camp is being attacked from

local function wbLog(s) System.LogAlways("[WallBattle] " .. s) end
local function wbKey(ent) return ent and tostring((ent.this and ent.this.id) or ent.id) or nil end
local function nowT() local t = 0; pcall(function() t = System.GetCurrTime() or 0 end); return t end

-- How far from the camp centre is the wall along this bearing? Nil if the ray escapes.
-- Muster points are placed off this, not off NavWallExtent(): see docs/walls-and-sieges.md.
function mercenaries:WBWallRayDist(c, ang, maxR)
    local segs = self:NavWallSegments()
    local ex, ey = math.cos(ang) * maxR, math.sin(ang) * maxR
    local best
    for i = 1, #segs do
        local w = segs[i]
        local r1x, r1y = ex, ey
        local s1x, s1y = w.bx - w.ax, w.by - w.ay
        local den = r1x * s1y - r1y * s1x
        if math.abs(den) > 1e-9 then
            local qpx, qpy = w.ax - c.x, w.ay - c.y
            local t = (qpx * s1y - qpy * s1x) / den      -- along the ray, 0..1
            local u = (qpx * r1y - qpy * r1x) / den      -- along the wall, 0..1
            if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
                local d = t * maxR
                if not best or d < best then best = d end
            end
        end
    end
    return best
end

-- ==== gaps ====
-- A gap is a direction in which you can walk out of camp without crossing a wall.
-- Found by sweeping rays from the camp centre rather than by reading the corner list,
-- so it works for a ring left open, several separate runs, or a deliberate gateway.
function mercenaries:NavFindGaps()
    if self.WBGaps and self.WBGapsVersion == self.WallVersion then return self.WBGaps end
    local c = self.CampCenter
    local m = self.WallMarks or {}
    if not c then self.WBGaps = {}; self.WBGapsVersion = self.WallVersion; return self.WBGaps end

    -- No wall at all: the whole camp is one open approach. One notional gap on the
    -- bearing the attack is coming from gives both sides somewhere sensible to form up,
    -- and since NavIsBlocked has no segments to test they simply walk straight there.
    if #m < 2 then
        local a = self.WBOpenBearing or 0
        local dir = { x = math.cos(a), y = math.sin(a) }
        local edge = self.WBOpenCampRadius
        local g = {
            dir = dir, width = math.pi / 2, gateR = edge,
            right = { x = -dir.y, y = dir.x },
            outside = { x = c.x + dir.x * (edge + self.WBOutsideOffset),
                        y = c.y + dir.y * (edge + self.WBOutsideOffset), z = c.z },
            inside  = { x = c.x + dir.x * math.max(edge - self.WBInsideOffset, 2.0),
                        y = c.y + dir.y * math.max(edge - self.WBInsideOffset, 2.0), z = c.z },
        }
        if self.CampSnapToGround then
            g.outside = self:CampSnapToGround(g.outside)
            g.inside  = self:CampSnapToGround(g.inside)
        end
        self.WBGaps, self.WBGapsVersion = { g }, self.WallVersion
        return self.WBGaps
    end

    local R = self:NavWallExtent() + 8.0
    local N = 72                                    -- 5 degree sweep
    local open = {}
    for i = 0, N - 1 do
        local a = 2 * math.pi * i / N
        local p = { x = c.x + math.cos(a) * R, y = c.y + math.sin(a) * R, z = c.z }
        open[i] = not self:NavIsBlocked(c, p, 0)   -- exact: the margin must not seal a narrow gate
    end

    -- contiguous open runs -> one gap each (wrapping around 0)
    local gaps = {}
    local start = nil
    for i = 0, N - 1 do
        if open[i] and not start then start = i end
        if start and (not open[(i + 1) % N] or i == N - 1) then
            local last = i
            local mid = (start + last) / 2
            local width = (last - start + 1) * (2 * math.pi / N)
            local a = 2 * math.pi * mid / N
            local dir = { x = math.cos(a), y = math.sin(a) }

            -- the gate radius: how far out the wall stands on either side of the opening.
            -- The gap bearing itself never hits a wall (that is what makes it a gap), so
            -- measure the closed bearings that flank it.
            local edge, n = 0, 0
            for _, k in ipairs({ start - 1, last + 1 }) do
                local d = self:WBWallRayDist(c, 2 * math.pi * (k % N) / N, R)
                if d then edge = edge + d; n = n + 1 end
            end
            edge = (n > 0) and (edge / n) or self:NavWallExtent()

            table.insert(gaps, {
                dir = dir,
                width = width,
                gateR = edge,
                right = { x = -dir.y, y = dir.x },        -- along the wall: the battle line
                outside = { x = c.x + dir.x * (edge + self.WBOutsideOffset),
                            y = c.y + dir.y * (edge + self.WBOutsideOffset), z = c.z },
                inside  = { x = c.x + dir.x * math.max(edge - self.WBInsideOffset, 2.0),
                            y = c.y + dir.y * math.max(edge - self.WBInsideOffset, 2.0), z = c.z },
            })
            start = nil
        end
    end
    -- wholly enclosed: no way in at all. Treat the whole perimeter as one notional gap
    -- so the sides still form up somewhere sensible instead of milling about.
    if #gaps == 0 then
        local dir = { x = 1, y = 0 }
        local edge = self:WBWallRayDist(c, 0, R) or self:NavWallExtent()
        gaps = { { dir = dir, width = 0, gateR = edge, right = { x = 0, y = 1 },
                   outside = { x = c.x + (edge + self.WBOutsideOffset), y = c.y, z = c.z },
                   inside  = { x = c.x + math.max(edge - self.WBInsideOffset, 2.0), y = c.y, z = c.z } } }
    end
    for _, g in ipairs(gaps) do
        if self.CampSnapToGround then
            g.outside = self:CampSnapToGround(g.outside)
            g.inside  = self:CampSnapToGround(g.inside)
        end
    end
    self.WBGaps = gaps
    self.WBGapsVersion = self.WallVersion
    wbLog(#gaps .. " gap(s) in the wall")
    return gaps
end

-- ==== who is around ====
function mercenaries:WBAttackersNearCamp()
    local out = {}
    local c = self.CampCenter
    if not c then return out end
    local seen = {}

    -- A raid force counts from the moment it lands, however far out it is: the whole
    -- point is that it marches in from the horizon rather than appearing at the wall.
    -- Not once the fighting starts, though, or one survivor running for the hills would
    -- hold the camp at battle stations forever.
    if self.WBPhase ~= "battle" then
        for _, e in ipairs(self.WBRaidForce or {}) do
            if e and self:IsAliveAndWell(e, true) then
                local k = wbKey(e)
                if k and not seen[k] then seen[k] = true; table.insert(out, e) end
            end
        end
    end

    local ents
    pcall(function() ents = System.GetEntitiesInSphere(c, self.WBTriggerRange) end)
    for _, e in pairs(ents or {}) do
        pcall(function()
            local k = wbKey(e)
            if k and seen[k] then return end
            local nm = e:GetName() or ""
            if self.IsModEnemyName and self:IsModEnemyName(nm) and self:IsAliveAndWell(e, true) then
                table.insert(out, e)
            end
        end)
    end
    return out
end

function mercenaries:WBDefenders()
    local out = {}
    for _, m in pairs(self.ActiveMercs or {}) do
        if m and self:IsAliveAndWell(m, true) then table.insert(out, m) end
    end
    -- the quartermaster defends his own camp too, and is not in ActiveMercs
    if self.QuartermasterName then
        local qm
        pcall(function() qm = System.GetEntityByName(self.QuartermasterName) end)
        if qm and self:IsAliveAndWell(qm, true) then table.insert(out, qm) end
    end
    return out
end

-- ==== staging ====
-- Where the k-th of n men on this side of a gap stands. Slots run along the wall rather
-- than all on the gap centre, so the two sides form facing lines instead of a scrum.
-- Ranks fill front to back once a line is WBLineWidth wide.
-- Men per rank at this gap: as wide as the opening, so the block fits the gateway and
-- runs back as many ranks as it needs rather than spilling along the wall.
function mercenaries:WBRankWidth(gap, n)
    local chord = 2 * (gap.gateR or 0) * math.sin((gap.width or 0) / 2)
    local per = math.floor(chord / self.WBLineSpacing)
    if per < 1 then per = 1 end
    if per > self.WBLineWidth then per = self.WBLineWidth end
    if n and per > n then per = n end
    return per
end

-- Where the k-th of n men on one side of a gap stands. depSign pushes the back ranks
-- away from the wall: +1 outward for attackers, -1 further into camp for defenders.
function mercenaries:WBLineSlot(gap, base, k, n, depSign)
    local per  = self:WBRankWidth(gap, n)
    local rank = math.floor((k - 1) / per)
    local file = (k - 1) % per
    local inRank = math.min(n - rank * per, per)          -- men in this rank, to centre it
    local lat = (file - (inRank - 1) / 2) * self.WBLineSpacing
    local dep = rank * self.WBRankSpacing * (depSign or 1)
    local r, d = gap.right, gap.dir
    local p = {
        x = base.x + r.x * lat + d.x * dep,
        y = base.y + r.y * lat + d.y * dep,
        z = base.z,
    }
    if self.CampSnapToGround then p = self:CampSnapToGround(p) end
    return p
end

-- Attackers go to the nearest gap. Defenders are then spread over the gaps that are
-- actually being attacked, most-threatened first, so the line is balanced rather than
-- everyone piling onto one entrance.
function mercenaries:WBAssignPositions(attackers, defenders)
    local gaps = self:NavFindGaps()
    if #gaps == 0 then return end
    self.WBAssign = {}

    -- pass 1: who stands at which gap
    local load, atGap = {}, {}
    for i = 1, #gaps do load[i] = 0; atGap[i] = { enemy = {}, merc = {} } end

    for _, e in ipairs(attackers) do
        local p; pcall(function() p = e:GetWorldPos() end)
        if p then
            local best, bestD2 = 1, nil
            for i, g in ipairs(gaps) do
                local dx, dy = g.outside.x - p.x, g.outside.y - p.y
                local d2 = dx * dx + dy * dy
                if not bestD2 or d2 < bestD2 then best, bestD2 = i, d2 end
            end
            load[best] = load[best] + 1
            table.insert(atGap[best].enemy, e)
        end
    end

    -- defenders proportional to attackers per gap; every threatened gap gets at least one
    local threatened = {}
    for i, n in ipairs(load) do if n > 0 then table.insert(threatened, { i = i, n = n }) end end
    if #threatened == 0 then threatened = { { i = 1, n = 1 } } end
    table.sort(threatened, function(a, b) return a.n > b.n end)

    local di = 1
    for _, d in ipairs(defenders) do
        local t = threatened[((di - 1) % #threatened) + 1]
        table.insert(atGap[t.i].merc, d)
        di = di + 1
    end

    -- pass 2: now that each gap knows its headcount, give every man his own place in
    -- the line. One shared point per gap is what made them pile into a heap.
    for i, g in ipairs(gaps) do
        for _, side in ipairs({ "enemy", "merc" }) do
            local list = atGap[i][side]
            local base = (side == "enemy") and g.outside or g.inside
            local sign = (side == "enemy") and 1 or -1
            -- order along the wall so nobody crosses a comrade to reach his place.
            -- Projections up front: a comparator that re-queries positions is unstable.
            local ord = {}
            for _, ent in ipairs(list) do
                local t = 0
                pcall(function()
                    local p = ent:GetWorldPos()
                    t = (p.x - base.x) * g.right.x + (p.y - base.y) * g.right.y
                end)
                table.insert(ord, { ent = ent, t = t })
            end
            table.sort(ord, function(a, b) return a.t < b.t end)

            -- the man who has least ground to cover leads the column
            local leadK, leadD2 = 1, nil
            for k, o in ipairs(ord) do
                local d2
                pcall(function()
                    local p = o.ent:GetWorldPos()
                    d2 = (p.x - base.x) ^ 2 + (p.y - base.y) ^ 2
                end)
                if d2 and (not leadD2 or d2 < leadD2) then leadK, leadD2 = k, d2 end
            end
            local leadKey = wbKey(ord[leadK] and ord[leadK].ent)

            -- Marching order: the same block they will fight in, leader at its head.
            -- A single file of eight is nearly twenty metres long and comes apart the
            -- moment one man is slow; ranks keep the body a couple of metres deep.
            local per = self:WBRankWidth(g, #ord)
            local function colSlot(s)                 -- s = 0 is the leader
                local rank   = math.floor(s / per)
                local fileN  = s % per
                local inRank = math.min(#ord - rank * per, per)
                return rank * self.WBColumnSpacing, (fileN - (inRank - 1) / 2) * self.WBLineSpacing
            end
            local _, leadLat = colSlot(0)

            local s = 0
            for k, o in ipairs(ord) do
                local isLead = (k == leadK)
                local cb, cl = 0, 0
                if not isLead then
                    s = s + 1
                    cb, cl = colSlot(s)
                    cl = cl - leadLat                 -- offsets are relative to the leader
                end
                self.WBAssign[wbKey(o.ent)] = {
                    gap = i, side = side,
                    pos = self:WBLineSlot(g, base, k, #ord, sign),
                    lead = isLead,
                    leadKey = (not isLead) and leadKey or nil,
                    colBack = cb, colLat = cl,        -- his place in the marching block
                    dir = { x = g.dir.x * -sign, y = g.dir.y * -sign },  -- their line of march
                }
            end
        end
    end
    wbLog(#attackers .. " attacker(s), " .. #defenders .. " defender(s) over " .. #threatened .. " contested gap(s)")
end

-- Orders themselves are issued by WBStagePoll, which is the only place that knows whether
-- a man should be marching in column or walking to his own place in the line. This just
-- readies the ground and counts who is being marshalled.
function mercenaries:WBDispatch()
    local n = 0
    -- cut the graph now rather than on whoever's steering tick happens to need it first
    if (not self.NavGraph) or (self.NavGraphWallVersion ~= self.WallVersion) then
        pcall(function() self:NavBuild() end)
    end
    for key in pairs(self.WBAssign) do
        if self.WBEntByKey and self.WBEntByKey[key] then n = n + 1 end
    end
    return n
end

-- Everyone in place? Also reports per side, because the two sides arrive at very
-- different times: the defenders are already standing in camp while a raid force is
-- still half a field away, and a pooled count would open the fight on their behalf.
function mercenaries:WBAllStaged()
    local total, ready = 0, 0
    local per = { enemy = { r = 0, t = 0 }, merc = { r = 0, t = 0 } }
    for key, a in pairs(self.WBAssign) do
        local ent = self.WBEntByKey and self.WBEntByKey[key]
        if ent then
            total = total + 1
            local s = per[a.side]
            if s then s.t = s.t + 1 end
            local p; pcall(function() p = ent:GetWorldPos() end)
            if p then
                local dx, dy = p.x - a.pos.x, p.y - a.pos.y
                if (dx * dx + dy * dy) <= (self.WBStagedDist * self.WBStagedDist) then
                    ready = ready + 1
                    if s then s.r = s.r + 1 end
                end
            end
        end
    end
    return (total > 0 and ready >= total), ready, total, per
end

-- Column discipline: how far is the worst-placed man from where he should be marching?
-- A leader whose block has come apart stands fast until it closes up again, with enough
-- hysteresis that he does not stutter every few steps.
function mercenaries:WBColumnCheck()
    self.WBHold = self.WBHold or {}
    local worst = {}
    for key, a in pairs(self.WBAssign) do
        if a.leadKey then
            local ent  = self.WBEntByKey and self.WBEntByKey[key]
            local lead = self.WBEntByKey and self.WBEntByKey[a.leadKey]
            if ent and lead then
                pcall(function()
                    local p, lp = ent:GetWorldPos(), lead:GetWorldPos()
                    local d = math.sqrt((p.x - lp.x) ^ 2 + (p.y - lp.y) ^ 2)
                    local lag = d - math.sqrt((a.colBack or 0) ^ 2 + (a.colLat or 0) ^ 2)
                    if lag > (worst[a.leadKey] or -1e9) then worst[a.leadKey] = lag end
                end)
            end
        end
    end
    self.WBStretchRun = self.WBStretchRun or {}
    self.WBHoldSince = self.WBHoldSince or {}
    local t = nowT()
    for lk, lag in pairs(worst) do
        if lag > self.WBColumnStretch then
            local run = (self.WBStretchRun[lk] or 0) + 1
            self.WBStretchRun[lk] = run
            if run >= self.WBStretchTicks and not self.WBHold[lk] then
                self.WBHold[lk] = true
                self.WBHoldSince[lk] = t
            end
        else
            self.WBStretchRun[lk] = 0
            if lag < (self.WBColumnStretch * 0.5) then self.WBHold[lk] = nil end
        end
        -- A straggler who can never close up (stuck on scenery, no route) would otherwise
        -- hold his whole column at a standstill for the rest of the approach.
        if self.WBHold[lk] and (t - (self.WBHoldSince[lk] or t)) > self.WBHoldMax then
            wbLog("column waited long enough - moving on without the straggler")
            self.WBHold[lk] = nil
            self.WBStretchRun[lk] = 0
        end
    end
end

-- Contact: any attacker close enough to any defender opens the fight, wherever the rest
-- of them have got to. They then walk in under their own steam like any other fight.
function mercenaries:WBContact()
    local r2 = self.WBEngageDist * self.WBEngageDist
    for ka, a in pairs(self.WBAssign) do
        if a.side == "enemy" then
            local ea = self.WBEntByKey and self.WBEntByKey[ka]
            if ea then
                for kd, d in pairs(self.WBAssign) do
                    if d.side == "merc" then
                        local ed = self.WBEntByKey and self.WBEntByKey[kd]
                        if ed then
                            local hit = false
                            pcall(function()
                                local p, q = ea:GetWorldPos(), ed:GetWorldPos()
                                hit = ((p.x - q.x) ^ 2 + (p.y - q.y) ^ 2) <= r2
                            end)
                            if hit then return true end
                        end
                    end
                end
            end
        end
    end
    return false
end

-- Both sides must be mostly formed before the fight opens.
function mercenaries:WBQuorumMet(per)
    local any = false
    for _, s in pairs(per or {}) do
        if s.t > 0 then
            any = true
            if (s.r / s.t) < self.WBStageQuorum then return false end
        end
    end
    return any
end

-- How long staging may take. A force marching in from 150m cannot form up inside a flat
-- 12s, so the allowance scales with the ground the furthest man has to cover.
function mercenaries:WBStageAllowance()
    local far = 0
    for key, a in pairs(self.WBAssign) do
        local ent = self.WBEntByKey and self.WBEntByKey[key]
        if ent then
            pcall(function()
                local p = ent:GetWorldPos()
                local d = math.sqrt((p.x - a.pos.x) ^ 2 + (p.y - a.pos.y) ^ 2)
                if d > far then far = d end
            end)
        end
    end
    return self.WBStageTimeout + far / (self.WBMarchSpeed or 2.5)
end

-- ==== phase machine ====
function mercenaries:WBSetPhase(p)
    if self.WBPhase == p then return end
    self.WBPhase = p
    wbLog("phase -> " .. p)
    if p == "battle" then
        -- release everyone: wall rules off, fight normally. Men still short of the gap
        -- simply walk the rest of the way under their own behaviour.
        for key in pairs(self.WBAssign) do
            local ent = self.WBEntByKey and self.WBEntByKey[key]
            if ent then pcall(function() self:NavGotoEnd(ent, "battle") end) end
        end
        self.WBAssign = {}
        self.WBHold = {}
    end
end

-- True while the wall must be respected. Battle turns everything off deliberately.
function mercenaries:WBWallRulesActive()
    return self.WBPhase ~= "battle"
end

-- Nobody starts a fight while forming up. This is what lets the staging walk finish:
-- our own combat fires carry IgnorePriorityOnPreviousInterrupt, so a priority-160
-- combat interrupt happily replaces the priority-200 staging move - which is why they
-- set off toward a gap and then stopped partway and turned on whoever was nearest.
--
-- Only OUR fires are suppressed. If somebody actually swings at him the engine's own
-- reaction still starts a fight, so a man being cut down while marching does defend
-- himself; he simply will not go looking.
function mercenaries:WBCombatLocked(ent)
    if self.WBPhase ~= "staging" then return false end
    if not ent then return false end
    return self.WBAssign[wbKey(ent)] ~= nil
end

-- BT hook: sets data.wbLocked for the combat-fire conditions.
function mercenaries:WBCombatPoll(data, ent)
    data.wbLocked = self:WBCombatLocked(ent)
end

-- Is this man's leader still marching? While he is, the file follows him in column;
-- once he is on his mark everyone peels off to his own place in the line.
function mercenaries:WBColumnLeader(a)
    if a.lead or not a.leadKey then return nil end
    local lead = self.WBEntByKey and self.WBEntByKey[a.leadKey]
    if not lead then return nil end
    local la = self.WBAssign[a.leadKey]
    if not (la and self:IsAliveAndWell(lead, true)) then return nil end
    local p; pcall(function() p = lead:GetWorldPos() end)
    if not p then return nil end
    local d2 = (p.x - la.pos.x) ^ 2 + (p.y - la.pos.y) ^ 2
    if d2 <= (self.WBFormBreak * self.WBFormBreak) then return nil end   -- he has arrived
    return lead, la
end

-- BT hook: does this NPC need the nav_goto interrupt fired? NavGotoRequest only records
-- the destination; a tree has to fire the move. Also decides column vs line.
function mercenaries:WBStagePoll(data, ent)
    data.wbStageGo = false
    if self.WBPhase ~= "staging" then return end
    if not ent then return end

    -- Heartbeat. If a man is standing still, the first question is whether his tree is
    -- even asking for orders: no beat means the scheduler loop is not running for him,
    -- and nothing in the nav code can be the cause.
    local k = wbKey(ent)
    self.WBBeat = self.WBBeat or {}
    self.WBBeat[k] = (self.WBBeat[k] or 0) + 1

    local a = self.WBAssign[k]
    if not a then
        self.WBNoAssign = self.WBNoAssign or {}
        self.WBNoAssign[k] = (pcall(function() return ent:GetName() end) and ent:GetName()) or k
        return
    end

    -- his block has strung out behind him: stand fast until they close up
    if a.lead and self.WBHold and self.WBHold[wbKey(ent)] then
        if self:IsNavGotoActive(ent) then self:NavGotoEnd(ent, "waiting for the column") end
        return
    end

    local lead, la = self:WBColumnLeader(a)
    local want = lead and "column" or "line"

    -- Already walking under the right kind of order: leave it alone. Re-issuing would
    -- restart the Move and cost him the smooth corner he is in the middle of.
    if self:IsNavGotoActive(ent) and self:NavGotoMode(ent) == want then return end

    if want == "line" then
        -- standing on his spot: leave him be, or he re-fires the walk every poll
        local p; pcall(function() p = ent:GetWorldPos() end)
        if p then
            local dx, dy = p.x - a.pos.x, p.y - a.pos.y
            if (dx * dx + dy * dy) <= (self.WBStagedDist * self.WBStagedDist) then return end
        end
        if self:NavGotoRequest(ent, { x = a.pos.x, y = a.pos.y, z = a.pos.z }, { mode = "line" }) then
            data.wbStageGo = true
        end
    else
        if self:NavGotoRequest(ent, nil, {
            mode      = "column",
            trailEnt  = lead,
            trailBack = a.colBack or self.WBColumnSpacing,
            trailLat  = a.colLat or 0,
            trailAim  = la.pos,
            trailDir  = a.dir,
        }) then
            data.wbStageGo = true
        end
    end
end

function mercenaries.WBTick()
    local self = mercenaries
    pcall(function()
        if not (self.CampActive and self.CampCenter) then
            self:WBSetPhase("idle")
            return
        end
        -- A wall is not required. Without one there is nothing to route around, but the
        -- attackers still have to be MARCHED IN: a raid that spawns out of perception
        -- range and is never marshalled simply stands in a field forever, which is
        -- exactly what happened. Ordinary wandering enemies are left alone though -
        -- only a deliberate raid marshals an unwalled camp.
        local walled = (self.WallMarks and #self.WallMarks >= 2)
        if not walled and not self:WBRaidAlive() then
            self:WBSetPhase("idle")
            return
        end

        local attackers = self:WBAttackersNearCamp()

        if self.WBPhase == "idle" then
            if #attackers > 0 then
                local defenders = self:WBDefenders()
                -- index entities so the staging helpers can find them again
                self.WBEntByKey = {}
                for _, e in ipairs(attackers) do self.WBEntByKey[wbKey(e)] = e end
                for _, d in ipairs(defenders) do self.WBEntByKey[wbKey(d)] = d end
                self:WBAssignPositions(attackers, defenders)
                local n = self:WBDispatch()
                self.WBStartedAt = nowT()
                self.WBQuorumAt = nil
                self.WBStageAllowed = self:WBStageAllowance()
                self.WBBeat, self.WBNoAssign = {}, {}   -- counters are per staging
                self:WBSetPhase("staging")
                wbLog("marshalling " .. n .. " fighter(s) to the wall gaps")
            end

        elseif self.WBPhase == "staging" then
            if #attackers == 0 then self:WBSetPhase("idle"); return end
            self:WBColumnCheck()
            local all, ready, total, per = self:WBAllStaged()
            if self:WBContact() then
                wbLog("contact - the fight is on")
                self:WBSetPhase("battle")
            elseif all then
                wbLog("everyone in position (" .. ready .. "/" .. total .. ")")
                self:WBSetPhase("battle")
            elseif (nowT() - self.WBStartedAt) > (self.WBStageAllowed or self.WBStageTimeout) then
                wbLog("staging timed out at " .. ready .. "/" .. total .. " - starting anyway")
                self:WBSetPhase("battle")
            elseif self:WBQuorumMet(per) then
                -- once both lines are mostly formed the stragglers get a moment, then it opens
                self.WBQuorumAt = self.WBQuorumAt or nowT()
                if (nowT() - self.WBQuorumAt) > self.WBStageGrace then
                    wbLog("lines formed (" .. ready .. "/" .. total .. ") - engaging")
                    self:WBSetPhase("battle")
                end
            else
                self.WBQuorumAt = nil
            end

        elseif self.WBPhase == "battle" then
            if #attackers == 0 then
                self.WBQuietSince = self.WBQuietSince or nowT()
                if (nowT() - self.WBQuietSince) > self.WBBattleEndDelay then
                    self.WBQuietSince = nil
                    self:WBSetPhase("idle")
                end
            else
                self.WBQuietSince = nil
            end
        end
    end)
    Script.SetTimerForFunction(mercenaries.WBTickMs, "mercenaries.WBTick")
end

function mercenaries:WBStart()
    if self.WBRunning then return end
    self.WBRunning = true
    Script.SetTimerForFunction(self.WBTickMs, "mercenaries.WBTick")
    wbLog("watching for attacks on the walled camp")
end

function mercenaries:WBStatus()
    wbLog("phase: " .. tostring(self.WBPhase) .. (self.WBRunning and "" or "  (WATCHER NOT RUNNING - merc_wb_start)"))
    wbLog("gaps: " .. #(self:NavFindGaps() or {}))
    local all, ready, total = self:WBAllStaged()
    wbLog("staged: " .. tostring(ready) .. "/" .. tostring(total))
    wbLog("attackers near camp: " .. #self:WBAttackersNearCamp())
    if self.WBPhase == "staging" then
        wbLog("elapsed: " .. string.format("%.0f", nowT() - self.WBStartedAt) .. "s of " .. self.WBStageTimeout .. "s")
    end
    -- who is actually moving, and how far he still has to go
    for key, a in pairs(self.WBAssign) do
        local ent = self.WBEntByKey and self.WBEntByKey[key]
        local nm, d = "<gone>", -1
        if ent then
            pcall(function()
                nm = ent:GetName()
                local p = ent:GetWorldPos()
                d = math.sqrt((p.x - a.pos.x) ^ 2 + (p.y - a.pos.y) ^ 2)
            end)
            local blocked = false
            pcall(function() blocked = self:NavIsBlocked(ent:GetWorldPos(), a.pos) end)
            local beat = (self.WBBeat and self.WBBeat[key]) or 0
            wbLog(string.format("  %-24s %s gap %d %5.1fm  %-14s beats %d%s%s",
                nm, a.side, a.gap, d, self:NavGotoState(ent), beat,
                (beat == 0) and "  <- TREE NOT POLLING" or "",
                blocked and "  (wall in the way)" or ""))
        else
            wbLog("  " .. key .. " " .. a.side .. " - entity lost")
        end
    end

    -- Men whose tree IS polling but who have no assignment under the key it hands us.
    -- That means WBAssign is keyed differently from the behaviour tree's entity, which
    -- would leave them locked out of combat with nowhere to go - i.e. standing about.
    local orphans = {}
    for k, nm in pairs(self.WBNoAssign or {}) do
        if not self.WBAssign[k] then table.insert(orphans, nm) end
    end
    if #orphans > 0 then
        wbLog("KEY MISMATCH - polling but unassigned: " .. table.concat(orphans, ", "))
    end
end

-- ==== raids ====
-- Spawn a hostile force out of sight of the camp, already drawn up in the block it will
-- fight in, and let the staging machinery march it in. Everything after the spawn is the
-- ordinary path: the force counts as attackers (WBAttackersNearCamp), staging assigns it
-- the nearest gap, it marches in column, and the fight opens when both lines are formed.
--
-- This is the piece the random-encounter bandit attacks should eventually call.
function mercenaries:WBRaid(line)
    local a = {}
    for w in tostring(line or ""):gmatch("%S+") do a[#a + 1] = w end
    local count = tonumber(a[1]) or 8
    local group = (a[2] ~= nil and a[2] ~= "") and a[2] or "bandit"
    local dist  = tonumber(a[3]) or 120

    local c = self.CampCenter
    if not (self.CampActive and c) then wbLog("no camp"); return end
    if not self.EnemyGroups[group] then
        local names = {}
        for k in pairs(self.EnemyGroups) do table.insert(names, k) end
        table.sort(names)
        wbLog("unknown group '" .. tostring(group) .. "' - try: " .. table.concat(names, ", "))
        return
    end

    local gaps = self:NavFindGaps()
    local walled = (self.WallMarks and #self.WallMarks >= 2 and #gaps > 0)

    -- With a wall: approach opposite a real gap, so the march reads as an approach to a
    -- gate rather than a lap of the palisade. Without one there is nothing to march to,
    -- so they simply come out of a random quarter and the staged system stays out of it.
    local gi, g, ang, per
    if walled then
        gi = math.random(1, #gaps)
        g = gaps[gi]
        local spread = (g.width or 0) / 2 + math.pi / 8
        ang = math.atan2(g.dir.y, g.dir.x) + (math.random() * 2 - 1) * spread
        per = self:WBRankWidth(g, count)
    else
        ang = math.random() * 2 * math.pi
        per = math.max(1, math.ceil(math.sqrt(count)))       -- a squarish block
    end

    local ax, ay = math.cos(ang), math.sin(ang)
    local origin = { x = c.x + ax * dist, y = c.y + ay * dist, z = c.z }
    if self.CampSnapToGround then origin = self:CampSnapToGround(origin) end

    -- drawn up facing the camp, in the same block they will fight in
    local rx, ry = -ay, ax                                  -- across their front
    local yaw = math.atan2(-ay, -ax)
    local force = {}
    for i = 1, count do
        local rank = math.floor((i - 1) / per)
        local file = (i - 1) % per
        local inRank = math.min(count - rank * per, per)
        local lat = (file - (inRank - 1) / 2) * self.WBLineSpacing
        local dep = rank * self.WBRankSpacing
        local p = { x = origin.x + rx * lat + ax * dep, y = origin.y + ry * lat + ay * dep, z = origin.z }
        if self.FindValidGround then p = self:FindValidGround(p, origin.z) end
        local e = self:SpawnEnemyAt(group, (i % 4 == 0), p, yaw)
        if e then table.insert(force, e) end
    end

    if #force == 0 then wbLog("raid spawned nobody"); return end

    self.WBRaidForce = force
    self.WBOpenBearing = ang            -- unwalled camps form up facing this way
    self.WBGaps, self.WBGapsVersion = nil, nil
    self:WBSetPhase("idle")                                 -- make the next tick marshal them
    self:WBStart()
    if walled then
        wbLog(string.format("%d %s raiding from %.0fm out, making for gap %d of %d",
            #force, group, dist, gi, #gaps))
    else
        wbLog(string.format("%d %s raiding from %.0fm out - no wall, straight in", #force, group, dist))
    end
    return #force
end

function mercenaries:WBRaidAlive()
    for _, e in ipairs(self.WBRaidForce or {}) do
        if e and self:IsAliveAndWell(e, true) then return true end
    end
    return false
end

function mercenaries:WBRaidClear()
    for _, e in ipairs(self.WBRaidForce or {}) do
        pcall(function() System.RemoveEntity(e.id) end)
    end
    self.WBRaidForce = nil
    self:WBSetPhase("idle")
    wbLog("raid force removed")
end

-- Mark the gaps so the staging spots can be eyeballed. Marks a full rank on each side,
-- which is what the men will actually form up on.
function mercenaries:WBShowGaps(n)
    n = tonumber(n) or self.WBLineWidth
    self:NavClearDebug()
    for i, g in ipairs(self:NavFindGaps() or {}) do
        for k = 1, n do
            self:NavMarker(self:WBLineSlot(g, g.outside, k, n, 1),
                "objects/manmade/common_furniture/barrels/barrel_a.cgf")
            self:NavMarker(self:WBLineSlot(g, g.inside, k, n, -1),
                "objects/manmade/common_furniture/barrels/barrel_b.cgf")
        end
        wbLog(string.format("gap %d: width %.0f deg, wall %.1fm from centre", i, math.deg(g.width), g.gateR or -1))
    end
end

-- Battle-line shape, tuned in play. One string, split here: AddCCommand only hands over
-- %line, so a bare %line with two arguments pastes "2 6" into the call and will not compile.
function mercenaries:WBSetLine(line)
    -- 0 for unparseable: fails the >0 test below, keeps the current value, holds position
    local a = {}
    for w in tostring(line or ""):gmatch("%S+") do a[#a + 1] = tonumber(w) or 0 end
    local function num(v, cur) return (v and v > 0) and v or cur end
    self.WBLineSpacing   = num(a[1], self.WBLineSpacing)
    self.WBLineWidth     = math.floor(num(a[2], self.WBLineWidth))
    self.WBRankSpacing   = num(a[3], self.WBRankSpacing)
    self.WBOutsideOffset = num(a[4], self.WBOutsideOffset)
    self.WBInsideOffset  = num(a[5], self.WBInsideOffset)
    self.WBColumnSpacing = num(a[6], self.WBColumnSpacing)
    self.WBGaps, self.WBGapsVersion = nil, nil                -- offsets moved: re-cut the gaps
    wbLog(string.format("line: %.1fm apart, max %d per rank, %.1fm deep, standing %.1fm out / %.1fm in; column file %.1fm",
        self.WBLineSpacing, self.WBLineWidth, self.WBRankSpacing,
        self.WBOutsideOffset, self.WBInsideOffset, self.WBColumnSpacing))
end

System.AddCCommand("merc_wb_status", "mercenaries:WBStatus()",   "Wall-battle phase, gaps and staging progress")
System.AddCCommand("merc_wb_gaps",   "mercenaries:WBShowGaps('%line')", "Mark the battle lines at each gap: merc_wb_gaps [menPerSide]")
System.AddCCommand("merc_wb_line",   "mercenaries:WBSetLine('%line')",  "Line shape: merc_wb_line [spacing] [maxPerRank] [rankDepth] [outOffset] [inOffset] [columnFile]")
System.AddCCommand("merc_raid",       "mercenaries:WBRaid('%line')", "Raid the camp: merc_raid [count] [group] [distance] - spawns them in formation far out and marches them to a gate")
System.AddCCommand("merc_raid_clear", "mercenaries:WBRaidClear()",   "Remove the current raid force")
System.AddCCommand("merc_wb_start",  "mercenaries:WBStart()",    "Start watching for attacks on the walled camp")
System.AddCCommand("merc_wb_battle", "mercenaries:WBSetPhase('battle')", "Force the battle phase (drops all wall rules)")
System.AddCCommand("merc_wb_idle",   "mercenaries:WBSetPhase('idle')",   "Force back to idle")
