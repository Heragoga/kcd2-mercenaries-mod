-- Slot formation: the mod's own formation system, anchored on the PLAYER.
--
-- The engine's formation system could never do this - a formation anchors on
-- whatever entity ran MakeFormation, and the player has no behaviour tree, so
-- the best it could manage was electing a merc to stand in for him. See
-- docs/formations.md for that dead end.
--
-- Here Lua computes a world position per merc from the player's position and
-- heading, and each merc runs ONE continuous <Move> at a vec3 that this file
-- rewrites in place. Because the destination is retargeted rather than the node
-- re-issued (destChangedThreshold), the merc corners smoothly and never stops
-- between legs. That mechanism is not new - nav_goto.xml/mercenaries_navmesh.lua
-- already ship it, play-tuned; this is the same trick pointed at a formation
-- offset instead of a detour waypoint.
--
-- Offsets use the convention the vanilla catalogue uses: +x is the anchor's
-- RIGHT, +y is BEHIND it, metres. Here the anchor is the player himself.

-- ===== Shapes =====
-- fn(i, total) -> offsetX, offsetY  for 1-based slot i.
-- Procedural rather than tabulated so a shape works at any squad size; the old
-- 6/12/20/30 size ladder only existed because the engine picked spots for us.
--
-- The three numbers that stop a squad milling about (docs/formations.md):
--   PITCH     2.0m  neighbour spacing - must clear an NPC footprint plus slack
--   STANDOFF  3.4m  clear gap in front of the first rank, so nobody shoves the
--                   player; that shove was the old system's feedback loop
--   the arrival tolerance is stopWithinDistance on the Move node, not here
local PITCH, STANDOFF = 2.0, 3.4

mercenaries.SlotShapes = {
    -- Column of twos. Narrow enough for roads and forest tracks.
    column = function(i, _)
        local rank = math.floor((i - 1) / 2)
        local side = ((i - 1) % 2 == 0) and -1 or 1
        return side * 1.2, STANDOFF + rank * PITCH
    end,

    -- Two ranks abreast. A battle line.
    line = function(i, total)
        local per  = math.max(1, math.ceil(total / 2))
        local rank = math.floor((i - 1) / per)
        local idx  = (i - 1) % per
        return (idx - (per - 1) / 2) * PITCH, STANDOFF + rank * PITCH
    end,

    -- Block, roughly square at any size.
    square = function(i, total)
        local w   = math.max(2, math.floor(math.sqrt(total * 1.25) + 0.5))
        local col = (i - 1) % w
        local row = math.floor((i - 1) / w)
        return (col - (w - 1) / 2) * PITCH, STANDOFF + row * PITCH
    end,

    -- Cone opening backwards, player at the tip.
    wedge = function(i, _)
        local pair = math.floor((i - 1) / 2)
        local side = ((i - 1) % 2 == 0) and -1 or 1
        return side * (1.4 + pair * 1.1), STANDOFF + pair * 1.3
    end,

    -- Ring. Anchored on the player, so unlike the engine version this actually
    -- surrounds him rather than surrounding a merc standing near him.
    circle = function(i, total)
        local n = math.max(1, total)
        local r = (n <= 12) and 4.5 or (((i - 1) < math.floor(n * 0.4)) and 4.5 or 7.0)
        local a = 2 * math.pi * (i - 1) / n
        return r * math.sin(a), r * math.cos(a)
    end,

    -- Two flanking files, middle left open.
    escort = function(i, _)
        local pair = math.floor((i - 1) / 2)
        local side = ((i - 1) % 2 == 0) and -1 or 1
        return side * 4.0, 1.0 + pair * PITCH
    end,
}

mercenaries.SlotShapeOrder = { "column", "line", "square", "wedge", "circle", "escort" }
mercenaries.SlotShape = "column"

mercenaries.SlotAssign = {}     -- [mercName] = 1-based slot index
mercenaries.SlotCount  = 0      -- how many slots the current shape is sized for
mercenaries.SlotFrame  = nil    -- shared per-tick { px, py, pz, fx, fy }
mercenaries.SlotHeading = nil   -- damped unit XY heading, persisted across ticks
mercenaries.SlotDebug = false

-- Probe mode: every merc is sent to one fixed point 3m behind the player. Used
-- to answer "does a live-rewritten vec3 retarget a running Move, or restart it"
-- without any formation logic in the way. merc_slot_probe.
mercenaries.SlotProbe = false

-- changeNPCState on the Move node: camp_actor.xml calls it "required for
-- move-to-a-point", nav_goto.xml and the mounted branch both use false, and
-- docs/behaviour-trees/movement.md claims true crashes inside a switch tree.
-- They cannot all be right, so both variants ship and this picks one live.
mercenaries.SlotChangeState = false

-- Heading damping. The player can spin on the spot faster than any formation
-- should rotate; without this the squad whips around him.
mercenaries.SlotMoveThreshold = 0.2     -- below this speed the heading is frozen
mercenaries.SlotTurnDeadband  = 0.20    -- rad, ignore jitter under ~12 degrees
mercenaries.SlotTurnRate      = 1.6     -- rad/sec cap, so a 180 takes ~2s
mercenaries.SlotTickMs        = 150

-- ===== Assignment =====
-- Stable and keyed by NAME: ActiveMercs is name-keyed, and the name is the only
-- identity that survives a save/load. A merc keeps his slot for as long as he is
-- eligible; only genuinely new mercs take free indices. Reshuffling assignments
-- is what makes a squad walk across each other for no reason.
function mercenaries:UpdateSlotAssignments()
    local ok, err = pcall(function()
        local eligible = {}

        for name, ent in pairs(self.ActiveMercs) do
            local wuid = ent and (ent.this and ent.this.id or ent.id)
            if self:IsFormationEligible(ent, wuid) then
                table.insert(eligible, {
                    name = name,
                    rank = self:FormationRank(self:GetMercType(ent)),
                })
            end
        end

        table.sort(eligible, function(a, b)
            if a.rank ~= b.rank then return a.rank < b.rank end
            return a.name < b.name
        end)

        local keep, used = {}, {}
        for _, e in ipairs(eligible) do
            local prev = self.SlotAssign[e.name]
            if prev and not used[prev] then
                keep[e.name] = prev
                used[prev] = true
            end
        end

        local next_free = 1
        for _, e in ipairs(eligible) do
            if not keep[e.name] then
                while used[next_free] do next_free = next_free + 1 end
                keep[e.name] = next_free
                used[next_free] = true
            end
        end

        self.SlotAssign = keep
        self.SlotCount  = #eligible
    end)

    if not ok then
        System.LogAlways('[MercSlots] UpdateSlotAssignments Error: ' .. tostring(err))
    end
end

-- ===== Shared frame =====
-- One global tick, not one per merc: the heading damping below is stateful, and
-- running it once per merc per tick would apply the slew-rate limit N times and
-- cancel it out.
function mercenaries.SlotFrameLoop()
    local ok, err = pcall(function() mercenaries:SlotFrameTick() end)
    if not ok then System.LogAlways('[MercSlots] SlotFrameTick Error: ' .. tostring(err)) end
    Script.SetTimerForFunction(mercenaries.SlotTickMs, "mercenaries.SlotFrameLoop")
end

function mercenaries:SlotFrameTick()
    if not next(self.ActiveMercs) then self.SlotFrame = nil return end
    if not player then self.SlotFrame = nil return end

    self:UpdateSlotAssignments()
    self:UpdateFormationLeader()

    local pp
    pcall(function() pp = player:GetWorldPos() end)
    if not pp then self.SlotFrame = nil return end

    -- Prefer the direction the player is TRAVELLING over the direction he is
    -- looking: it is inherently smooth and cannot spin on the spot. Facing is
    -- only the seed and the standing-still fallback.
    local target = nil
    local last = self.SlotLastPos
    if last then
        local dx, dy = pp.x - last.x, pp.y - last.y
        local moved = math.sqrt(dx * dx + dy * dy)
        -- SlotTickMs is fixed, so distance-per-tick stands in for speed.
        if moved > (self.SlotMoveThreshold * self.SlotTickMs / 1000.0) then
            target = math.atan2(dy, dx)
        end
    end
    self.SlotLastPos = { x = pp.x, y = pp.y, z = pp.z }

    if not self.SlotHeading then
        local d
        pcall(function() d = player:GetDirectionVector() end)
        local fl = d and math.sqrt(d.x * d.x + d.y * d.y) or 0
        -- GetDirectionVector's XY projection is not unit length (it shortens as
        -- Henry looks up or down) and is zero during cutscenes.
        self.SlotHeading = (fl > 0.0001) and math.atan2(d.y / fl, d.x / fl) or 0
    end

    if target then
        -- Shortest arc, then deadband, then slew-rate limit.
        local cur = self.SlotHeading
        local d = math.atan2(math.sin(target - cur), math.cos(target - cur))
        if math.abs(d) > self.SlotTurnDeadband then
            local maxStep = self.SlotTurnRate * (self.SlotTickMs / 1000.0)
            if d > maxStep then d = maxStep elseif d < -maxStep then d = -maxStep end
            self.SlotHeading = cur + d
        end
    end

    local h = self.SlotHeading
    self.SlotFrame = {
        px = pp.x, py = pp.y, pz = pp.z,
        fx = math.cos(h), fy = math.sin(h),
    }
end

-- ===== Per-merc =====
-- Called from follow.xml's slot loop. Writes data.slotPos IN PLACE - rebinding
-- it (data.slotPos = {...}) would drop the behaviour tree's proxy object and the
-- Move would keep steering at the old one.
function mercenaries:UpdateSlotTarget(bt_data, myWuid, ent)
    local ok, err = pcall(function()
        bt_data.hasSlot = false

        local F = self.SlotFrame
        if not F then return end
        if _G.MercenariesDismissed then return end
        if _G.MercIdle then return end
        if _G.PlayerMounted then return end
        if self:IsCampActor(myWuid) then return end

        local name = ent and ent:GetName()
        if not name then return end
        if self.NpcFormations and self.NpcFormations[tostring(myWuid)] then return end

        local sx, sy
        if self.SlotProbe then
            sx, sy = 0, 3.0
        else
            local idx = self.SlotAssign[name]
            if not idx then return end
            local shape = self.SlotShapes[self.SlotShape] or self.SlotShapes.column
            sx, sy = shape(idx, math.max(self.SlotCount, 1))
            bt_data.slotIndex = idx
        end

        -- Rotate the offset into world space. right = (fy, -fx), which is
        -- Rotate90AroundZ in references/Scripts/Utils/VectorUtils.lua - note that
        -- mercenaries_camp.lua labels the opposite expression "right" and is wrong.
        local ix = F.px + sx * F.fy - sy * F.fx
        local iy = F.py - sx * F.fx - sy * F.fy
        -- Flat z: the merc paths on the navmesh to get there, and the mod's own
        -- follow distances are 2-D (follow.xml MeasureDistance TwoDimensions).
        -- Ground-snapping every tick would be a raycast per merc AND jitter -
        -- FindValidGround displaces up to 3m along a spiral and cannot report
        -- failure, so two adjacent ticks can pick different answers.
        local iz = F.pz

        -- Camp walls: if the straight line from the merc to his slot crosses one, aim
        -- him at the next corner of a route around it instead. Nothing is re-issued -
        -- this is the same vec3 the Move node already re-reads every 150ms
        -- (destChangedThreshold), so there is no interrupt churn. Costs one segment
        -- test per merc per tick while no wall is in the way.
        if self.NavSteerPoint and self.WallMarks and #self.WallMarks >= 2 then
            local me
            pcall(function() me = ent:GetWorldPos() end)
            if me then
                self.SlotNav = self.SlotNav or {}
                local key = tostring(myWuid)
                local rec = self.SlotNav[key]
                if not rec then rec = {}; self.SlotNav[key] = rec end
                local p = self:NavSteerPoint(rec, me, { x = ix, y = iy, z = iz })
                if p then ix, iy, iz = p.x, p.y, p.z end
            end
        end

        bt_data.slotPos.x = ix
        bt_data.slotPos.y = iy
        bt_data.slotPos.z = iz

        -- Must stay true for every tick of a detour: if this is ever skipped the
        -- slot branch (follow.xml, "$hasSlot & ~$useFormation") drops out mid-walk.
        bt_data.hasSlot = true
    end)

    if not ok then
        System.LogAlways('[MercSlots] UpdateSlotTarget Error: ' .. tostring(err))
    end
end

-- ===== Engine formation =====
-- The other system, kept switchable. The engine's own formation handles NPC-on-NPC
-- avoidance internally, which is the one thing 30 independent Move commands to
-- nearby points cannot do - they just shove each other. It pays for that by
-- anchoring on a merc rather than the player.
--
-- Deliberately minimal. Every earlier version churned: re-electing, re-resolving
-- the preset from a live count, or gating on a heartbeat, each of which rebuilt the
-- formation and made every follower re-join into a newly assigned spot. Here the
-- leader and the preset are LATCHED and only three things ever rebuild it: the
-- leader becoming ineligible, the shape being switched, or the squad outgrowing the
-- preset. FormationEpoch is the rebuild signal and it is logged with a reason.
mercenaries.UseEngineFormation = true

mercenaries.FormationLeader = nil
mercenaries.FormationEpoch  = 0
mercenaries.FormationName   = nil
mercenaries.FormationCap    = 0
mercenaries.FormationModeCode = 1        -- 0 Relaxed, 1 KeepShape, 2 MoveHistory
mercenaries.FormationRelocate = false    -- AllowRelocation: let a follower swap spots
-- Finer steps than the old {6,12,20,30}: under KeepShape a spot's pose is a rigid
-- rotation about the anchor, so a spot d metres out swings 2*d*sin(theta/2) when
-- the leader turns. A ladder that jumps 60% in one step jumps the lever arm with
-- it. Six steps keep each promotion to ~1.5m of extra reach.
mercenaries.FormationSizes = { 6, 10, 14, 18, 24, 30, 40, 50 }
mercenaries.FormationModeNames = { [0] = "Relaxed", [1] = "KeepShape", [2] = "MoveHistory" }

-- Build a preset name that is guaranteed to exist in data/AI/FormationDefinitions.xml.
-- NEVER hardcode one: the size ladder has changed three times, and a name with a size
-- that is no longer generated resolves to nothing, MakeFormation hands back a null
-- handle, and the whole squad silently falls through to the follow chain - which looks
-- like a column and is indistinguishable from "the formation system stopped working".
function mercenaries:FormationPresetName(size)
    if self.SlotShape == "vanilla" then
        return ((size or 0) <= 8) and "followNPC" or "infantryMen20"
    end
    local sizes = self.FormationSizes
    local pick = sizes[#sizes]
    for _, n in ipairs(sizes) do
        if (size or 0) <= n then pick = n break end
    end
    -- Mounted has exactly one shape: a triple column at horse spacing. The
    -- infantry shapes are authored for a 2m footprint and a body that can turn on
    -- the spot; a horse needs 3.5m files and 4m ranks and corners wide.
    local shape = _G.PlayerMounted and "mounted" or self.SlotShape
    return "merc_" .. shape .. tostring(pick)
end

function mercenaries:UpdateFormationRole(bt_data, myWuid)
    local ok, err = pcall(function()
        bt_data.useFormation      = false
        bt_data.isFormationLeader = false
        bt_data.formationEpoch    = self.FormationEpoch or 0
        bt_data.formationModeCode = self.FormationModeCode or 1
        bt_data.formationRelocate = self.FormationRelocate or false
        -- Derive the fallback rather than hardcoding it, so it always names a preset
        -- that exists for the CURRENT shape and ladder.
        bt_data.formationName     = self.FormationName
                                    or self:FormationPresetName(math.max((self.SlotCount or 1) - 1, 0))

        if not self.UseEngineFormation then return end
        -- Near a walled camp the engine formation cannot be steered around the wall,
        -- so it stands down and slot following (a vec3 we own) takes over.
        if self.NavSuppressFormation and self:NavSuppressFormation() then return end
        -- Mounted is IN. The formation now survives mounting (its owner loop has no
        -- locomotion of its own, so preempting the leader's walk no longer destroys
        -- it) and mounted followers run FormationFollower inside the horse
        -- StanceElement, which is vanilla's own mounted idiom.
        if _G.MercenariesDismissed or _G.MercIdle then return end
        if not self.FormationLeader then return end
        if not self:IsFormationEligible(nil, myWuid) then return end
        if self:IsCampActor(myWuid) then return end
        if (self.SlotCount or 0) < 2 then return end

        bt_data.useFormation      = true
        bt_data.formationLeader   = self.FormationLeader
        bt_data.isFormationLeader = (tostring(self.FormationLeader) == tostring(myWuid))
    end)
    if not ok then System.LogAlways('[MercSlots] UpdateFormationRole Error: ' .. tostring(err)) end
end

-- Runs from SlotFrameTick, after assignments. Latches; rebuilds only for a reason.
function mercenaries:UpdateFormationLeader()
    if not self.UseEngineFormation then self.FormationLeader = nil return end

    local best, bestRank, bestName, count = nil, nil, nil, 0
    local leaderStillOk = false

    for name, ent in pairs(self.ActiveMercs) do
        local wuid = ent and (ent.this and ent.this.id or ent.id)
        if self:IsFormationEligible(ent, wuid) and not self:IsCampActor(wuid) then
            count = count + 1
            if self.FormationLeader and tostring(wuid) == tostring(self.FormationLeader) then
                leaderStillOk = true
            end
            local rank = self:FormationRank(self:GetMercType(ent))
            if not bestRank or rank < bestRank or (rank == bestRank and name < bestName) then
                best, bestRank, bestName = wuid, rank, name
            end
        end
    end

    local reason = nil
    if not leaderStillOk then
        if tostring(best or '') ~= tostring(self.FormationLeader or '') then
            reason = "leader"
        end
        self.FormationLeader = best
    end

    -- Preset sizing. Grows immediately, shrinks only with hysteresis: a merc
    -- blipping in and out of eligibility must never flip the name, because the
    -- name changing rebuilds the formation and re-seats every follower. Without
    -- the shrink at all, a squad that peaks at 24 and then loses 8 keeps a
    -- 24-spot template and scatters the survivors across it.
    local followers = math.max(count - 1, 0)
    local cap = self.FormationCap or 0

    -- Mounting swaps the whole shape (infantry spacing -> horse spacing), so it has
    -- to defeat the grow-only latch. Everything else about the latch stays: this is
    -- a real state change, not the eligibility noise the latch exists to absorb.
    local mounted = _G.PlayerMounted and true or false
    if mounted ~= self.FormationMounted then
        self.FormationMounted = mounted
        self.FormationName = nil
        self.FormationCap = 0
        cap = 0
        reason = reason or (mounted and "mounted" or "dismounted")
    end

    local want_size = nil
    if followers > cap or not self.FormationName then
        want_size = self.FormationSizes[#self.FormationSizes]
        for _, n in ipairs(self.FormationSizes) do
            if followers <= n then want_size = n break end
        end
    else
        -- Shrink only once the squad is clearly inside the next size down, so
        -- hovering on a boundary cannot oscillate.
        local smaller = nil
        for _, n in ipairs(self.FormationSizes) do
            if n < cap then smaller = n end
        end
        if smaller and followers <= (smaller - 2) then want_size = smaller end
    end

    if want_size then
        local want = self:FormationPresetName(want_size)
        if want ~= self.FormationName then
            reason = reason or ((want_size > cap) and "grow" or "shrink")
            self.FormationName = want
            self.FormationCap  = want_size
        end
    end

    if reason then
        self.FormationEpoch = (self.FormationEpoch or 0) + 1
        System.LogAlways(string.format('[MercForm] rebuild #%d (%s) preset=%s leader=%s',
            self.FormationEpoch, reason, tostring(self.FormationName), tostring(self.FormationLeader)))
    end
end

-- Called by the leader's tree right after MakeFormation. This is the ONE fact the
-- whole system rests on and it has never been verified: data/AI/FormationDefinitions.xml
-- is a whole-file override of the vanilla catalogue, no mod in the reference set has
-- ever overridden it, and it is read once at AI-system init rather than lazily - so
-- whether the engine picks up a mod copy at all is unproven.
--
-- If the name does not resolve, the handle comes back null, every follower's
-- GetMemberFormation returns null, and they all drop to the CrimeFollower fallback -
-- which IS the follow chain, i.e. a single-file queue behind the leader. That failure
-- looks exactly like "every shape is a column".
function mercenaries:FormationMade(bt_data)
    local ok = bt_data and bt_data.formationWUID ~= nil
    local name = tostring(bt_data and bt_data.formationName)
    if ok ~= self._lastFormationOk or name ~= self._lastFormationName then
        self._lastFormationOk, self._lastFormationName = ok, name
        System.LogAlways(string.format(
            '[MercForm] MakeFormation %s -> %s%s',
            name, ok and "OK" or "NULL HANDLE",
            ok and "" or "  <-- preset not found; squad will fall back to the follow chain (a column)"))
    end
end

function mercenaries:SetFormationMode(code)
    code = tonumber(code) or 1
    if not self.FormationModeNames[code] then code = 1 end
    self.FormationModeCode = code
    Game.SendInfoText("Mode: " .. self.FormationModeNames[code], false, 0, 3)
    System.LogAlways('[MercForm] mode = ' .. self.FormationModeNames[code])
end

function mercenaries:SetFormationRelocate(on)
    self.FormationRelocate = on and true or false
    Game.SendInfoText("Relocation: " .. tostring(self.FormationRelocate), false, 0, 3)
    System.LogAlways('[MercForm] AllowRelocation = ' .. tostring(self.FormationRelocate))
end

function mercenaries:SetFormationSystem(useEngine)
    self.UseEngineFormation = useEngine and true or false
    self.FormationCap  = 0
    self.FormationName = self:FormationPresetName(math.max((self.SlotCount or 1) - 1, 0))
    self.FormationEpoch = (self.FormationEpoch or 0) + 1
    Game.SendInfoText(self.UseEngineFormation and "Engine formation" or "Slot formation", false, 0, 3)
    System.LogAlways('[MercForm] system = ' .. (self.UseEngineFormation and "engine" or "slot"))
end

-- ===== Controls =====
-- Formation chosen from dialogue. Count-encoded on one token the way the archer
-- stance is: the quest grants Amount = N and N indexes SlotShapeOrder, so six
-- shapes need one item class instead of six. Fed by both the E-dialog and the
-- silent order wheel.
mercenaries.TokenIDFormation = "679a655e-189d-4519-b437-ccc4b92be51d"

function mercenaries:MonitorFormationTokens(p)
    local n = p:GetCountOfClass(self.TokenIDFormation)
    if n and n > 0 then
        p:DeleteItemOfClass(self.TokenIDFormation, n)
        local key = self.SlotShapeOrder[n]
        if key then self:SetSlotShape(key) end
    end
end

function mercenaries:SetSlotShape(key)
    if key ~= "vanilla" and not self.SlotShapes[key] then key = "column" end
    self.SlotShape = key
    -- Resolve the new preset name RIGHT HERE. Leaving FormationName nil for even one
    -- tick is a live bug: the per-merc updater runs on its own 150ms loop, sees nil,
    -- and falls back - and if the leader's branch happens to re-enter in that window
    -- it calls MakeFormation with the fallback instead of the shape you just picked.
    -- That is why only the first shape command appeared to work.
    self.FormationCap  = 0
    self.FormationName = self:FormationPresetName(math.max((self.SlotCount or 1) - 1, 0))
    self.FormationEpoch = (self.FormationEpoch or 0) + 1
    Game.SendInfoText("Formation: " .. key, false, 0, 3)
    System.LogAlways('[MercForm] shape = ' .. key .. ' preset=' .. tostring(self.FormationName))
end

function mercenaries:SlotStatus()
    System.LogAlways(string.format(
        '[MercForm] system=%s shape=%s mode=%s relocate=%s preset=%s leader=%s epoch=%d squad=%d',
        self.UseEngineFormation and "engine" or "slot",
        tostring(self.SlotShape),
        tostring(self.FormationModeNames[self.FormationModeCode or 1]),
        tostring(self.FormationRelocate),
        tostring(self.FormationName), tostring(self.FormationLeader),
        self.FormationEpoch or 0, self.SlotCount or 0))
    System.LogAlways(string.format(
        '[MercForm] slot-only: probe=%s changeNPCState=%s heading=%.2f',
        tostring(self.SlotProbe), tostring(self.SlotChangeState), self.SlotHeading or 0))
end
