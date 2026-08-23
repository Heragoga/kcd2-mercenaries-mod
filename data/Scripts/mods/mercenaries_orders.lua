-- Squad combat orders: how freely the men pick fights, how hard they pile onto
-- one enemy, and who the player has singled out.
--
-- All three are plain globals read by the existing target-selection passes rather
-- than new behaviour-tree state. A merc who is refused a target never sets
-- playerTarget, and the scheduler's fire branch is gated on playerTarget being
-- non-null - so withholding a claim is enough to stand a man down, and no
-- scheduler XML has to learn about stances at all.
--
-- See docs/squad-orders.md.

-- ==== engagement stance ====
-- default    - the behaviour the squad has always had
-- aggressive - also takes on armed neutrals, not only declared enemies
-- defend     - only ever hits back; never starts anything
-- hold       - never engages at all, even under attack
mercenaries.EngageOrder     = { "default", "aggressive", "defend", "hold" }
mercenaries.EngageCodeOf    = { default = 0, aggressive = 1, defend = 2, hold = 3 }
mercenaries.EngageLabel     = {
    default    = "Engage at will",
    aggressive = "Attack anyone",
    defend     = "Defend only",
    hold       = "Hold fire",
}

mercenaries.TokenIDEngage = "679a655e-189d-4519-b437-ccc4b92bee4d"

function mercenaries:EngageCode()
    return self.EngageCodeOf[_G.MercEngage or "default"] or 0
end

function mercenaries:SetEngageStance(stance)
    if not self.EngageCodeOf[stance] then stance = "default" end
    _G.MercEngage = stance
    self:SaveString("MercEngagePersistent", stance)
    -- Standing down means dropping what they are already on, or a man mid-fight
    -- keeps swinging until his own watchdog notices. Claims are re-acquired
    -- immediately on the permissive stances, so this is only ever a real change
    -- for defend/hold.
    if stance == "hold" or stance == "defend" then
        self:EngageDropClaims(stance == "hold")
    end
    Game.SendInfoText(self.EngageLabel[stance] or stance, false, 0, 3)
    System.LogAlways("[MercOrders] engagement = " .. stance)
end

-- Release current targets so a stance change bites now. `all` drops everyone;
-- otherwise only the men who picked their own fight keep being dropped, and the
-- ones actually being swung at are left alone to defend themselves.
function mercenaries:EngageDropClaims(all)
    pcall(function()
        for myWuidStr, _ in pairs(self.MercTargetOf or {}) do
            if all or not self:EngageBeingAttacked(myWuidStr) then
                if self.ClearCombatClaim then self:ClearCombatClaim(myWuidStr) end
                self.MercTargetOf[myWuidStr] = nil
            end
        end
    end)
end

-- Is anything currently locked onto this merc? Used so "defend only" does not
-- yank a man out of a fight somebody else started with him.
function mercenaries:EngageBeingAttacked(myWuidStr)
    local hit = false
    pcall(function()
        for _, e in ipairs(self.CachedEnemies or {}) do
            local ent = e and e.entity
            if ent then
                local t
                pcall(function() t = ent.soul and ent.soul:GetTarget() end)
                if t and tostring(t) == tostring(myWuidStr) then hit = true end
            end
            if hit then break end
        end
    end)
    return hit
end

-- Acquisition gates, called from the two target-selection passes.
-- Pass 1 is retaliation; pass 2 is picking a fight.
function mercenaries:EngageAllowsRetaliation()
    return self:EngageCode() ~= 3
end

function mercenaries:EngageAllowsInitiative()
    local c = self:EngageCode()
    return c ~= 2 and c ~= 3
end

-- Widen the enemy cache on the aggressive stance. Additive on purpose: the normal
-- pass still runs first, so declared hostiles who have not drawn yet stay in the
-- cache exactly as before, and the aggressive pass only ADDS armed neutrals.
--
-- The two hostility gates are never both waived in one call - the relationship
-- floor and the drawn-weapon proof are each other's safety net (see
-- docs/combat-target-selection.md).
function mercenaries:EngageCacheAccepts(ent, playerWuid)
    if self:IsValidEnemy(ent, player, playerWuid, false, true) then return true end
    if self:EngageCode() ~= 1 then return false end
    if self:IsOwnSide(ent) then return false end
    return self:IsValidEnemy(ent, player, playerWuid, true, false)
end

-- Never turn on our own, whatever the stance says. IsValidEnemy filters by soul
-- id, which misses the quartermaster and any spawned friend that is not on a merc
-- soul - harmless while the relationship floor was doing the work, load-bearing
-- once the aggressive stance waives it.
mercenaries.OwnSideNamePrefixes = { "SpawnedFriend_", "MercenaryCustomCompanion", "MercQuartermaster" }

function mercenaries:IsOwnSide(ent)
    local n
    pcall(function() n = ent and ent.GetName and ent:GetName() end)
    if not n then return false end
    for _, p in ipairs(self.OwnSideNamePrefixes) do
        if string.find(n, p, 1, true) then return true end
    end
    return false
end

-- ==== aggression preset ====
-- The anti-swarm caps as three named settings. EffectiveSwarmCap is recomputed
-- from these every cache pass, so writing them is the whole change.
mercenaries.AggroOrder   = { "tight", "balanced", "loose" }
mercenaries.AggroPresets = {
    tight    = { cap = 1, max = 2, hard = 4,  label = "Tight ranks" },
    balanced = { cap = 2, max = 4, hard = 10, label = "Balanced" },
    loose    = { cap = 3, max = 7, hard = 16, label = "Swarm them" },
}

mercenaries.TokenIDAggro = "679a655e-189d-4519-b437-ccc4b92bee5d"

function mercenaries:SetAggroPreset(name)
    local p = self.AggroPresets[name]
    if not p then name, p = "balanced", self.AggroPresets.balanced end
    _G.MercAggro    = name
    self.SwarmCap     = p.cap
    self.SwarmCapMax  = p.max
    self.SwarmCapHard = p.hard
    self:SaveString("MercAggroPersistent", name)
    Game.SendInfoText(p.label, false, 0, 3)
    System.LogAlways(string.format("[MercOrders] aggression = %s (cap %d, ceiling %d, hard %d)",
        name, p.cap, p.max, p.hard))
end

-- ==== what the player is looking at ====
-- The order wheel opens on a MERC, so by the time an option is picked the player
-- is no longer looking at the enemy he meant. The crosshair is therefore sampled
-- every tick and the last worthwhile thing under it remembered, so an order fired
-- a second later still knows what he meant.
mercenaries.LookMaxDist    = 60.0
mercenaries.LookConeDeg    = 12.0
mercenaries.LookMemorySecs = 12.0

local function nowSecs()
    local t = 0
    pcall(function() t = System.GetCurrTime() or 0 end)
    return t
end

-- Nearest NPC to the view ray, by angle rather than by raycast: a ray test against
-- a moving body misses far more often than it hits, and this also works when the
-- crosshair is on the man's feet or his horse.
function mercenaries:OrderLookedAtNpc()
    local best, bestDot
    pcall(function()
        local camPos, camDir
        pcall(function() camPos = System.GetViewCameraPos() end)
        pcall(function() camDir = System.GetViewCameraDir() end)
        if not (camPos and camDir) then
            local pp = player and player:GetWorldPos()
            local d  = player and player:GetDirectionVector()
            if not (pp and d) then return end
            camPos, camDir = { x = pp.x, y = pp.y, z = pp.z + 1.7 }, d
        end

        local dl = math.sqrt(camDir.x ^ 2 + camDir.y ^ 2 + camDir.z ^ 2)
        if dl <= 1e-4 then return end
        local dx, dy, dz = camDir.x / dl, camDir.y / dl, camDir.z / dl

        local minDot = math.cos(math.rad(self.LookConeDeg))
        local pp = player:GetWorldPos()
        if not pp then return end

        local list = self.PerfNpcsNear and self:PerfNpcsNear(pp, self.LookMaxDist, 200)
        local ents = {}
        if list then
            for _, e in ipairs(list) do if e.entity then table.insert(ents, e.entity) end end
        else
            local box = System.GetPhysicalEntitiesInBoxByClass(pp, self.LookMaxDist, "NPC")
            for _, e in pairs(box or {}) do table.insert(ents, e) end
        end

        for _, ent in ipairs(ents) do
            if ent and ent.id ~= player.id then
                local q
                pcall(function() q = ent:GetWorldPos() end)
                if q then
                    -- Aim at the chest, not the feet: the crosshair sits on a man's
                    -- torso and a feet-anchored angle drifts badly up close.
                    local vx, vy, vz = q.x - camPos.x, q.y - camPos.y, (q.z + 1.0) - camPos.z
                    local L = math.sqrt(vx * vx + vy * vy + vz * vz)
                    if L > 1.0 and L <= self.LookMaxDist then
                        local dot = (vx * dx + vy * dy + vz * dz) / L
                        if dot >= minDot and (not bestDot or dot > bestDot) then
                            best, bestDot = ent, dot
                        end
                    end
                end
            end
        end
    end)
    return best
end

-- Sampled from the 1s monitor tick. Keeps two memories: the last NPC of any kind
-- (an escort subject) and the last one that was a valid enemy (an attack order).
function mercenaries:OrderLookTick()
    if _G.MercenariesDismissed then return end
    local ent = self:OrderLookedAtNpc()
    if not ent then return end

    local wuid = ent.this and ent.this.id or ent.id
    if not wuid then return end
    -- Looking at one of our own is how the wheel is opened in the first place;
    -- never let that overwrite the memory of a real subject.
    if self:IsOwnSide(ent) then return end
    local isMerc = false
    pcall(function()
        isMerc = (self.ActiveMercs and self.ActiveMercs[ent:GetName() or ""] ~= nil)
                 or (ent.soul and self:IsOwnSoulId(tostring(ent.soul:GetId()))) or false
    end)
    if isMerc then return end

    local t = nowSecs()
    self.LookLastEnt, self.LookLastAt = ent, t

    local playerWuid = player and (player.this and player.this.id or player.id)
    if playerWuid and self:IsValidEnemy(ent, nil, playerWuid, false, true) then
        self.LookLastEnemy, self.LookLastEnemyAt = ent, t
    end
end

local function freshOrNil(ent, at, ttl)
    if not (ent and at) then return nil end
    if (nowSecs() - at) > ttl then return nil end
    local alive = false
    pcall(function() alive = ent:GetWorldPos() ~= nil end)
    return alive and ent or nil
end

function mercenaries:OrderRememberedEnemy()
    return freshOrNil(self.LookLastEnemy, self.LookLastEnemyAt, self.LookMemorySecs)
end

function mercenaries:OrderRememberedEntity()
    return freshOrNil(self.LookLastEnt, self.LookLastAt, self.LookMemorySecs)
end

-- ==== focus fire ====
-- The player's own lock-on wins when he has one: in a fight that is exactly the
-- man he means, and it needs no memory at all. The crosshair memory is the
-- fallback for calling a target before the fighting starts.
mercenaries.TokenIDFocus  = "679a655e-189d-4519-b437-ccc4b92bee6d"
mercenaries.FocusHoldSecs = 45.0

function mercenaries:OrderFocusTarget()
    local ent
    pcall(function()
        local t = player and player.soul and player.soul:GetTarget()
        if t then ent = XGenAIModule.GetEntityByWUID(t) end
    end)
    if not ent then ent = self:OrderRememberedEnemy() end
    if not ent then
        Game.SendInfoText('merc_info_focus_none', false, 0, 3)
        System.LogAlways("[MercOrders] focus: nothing to call")
        return false
    end

    local wuid = ent.this and ent.this.id or ent.id
    _G.MercFocusTarget   = wuid
    _G.MercFocusTargetAt = nowSecs()
    -- A called target overrides the stance's own restraint: ordering a man to
    -- kill someone and then refusing him the claim would read as a broken order.
    if (_G.MercEngage or "default") == "hold" then self:SetEngageStance("default") end
    -- Everyone re-picks now rather than at the end of their current approach.
    self:EngageDropClaims(true)

    local nm = "target"
    pcall(function() nm = ent:GetName() or nm end)
    Game.SendInfoText('merc_info_focus', false, 0, 3)
    System.LogAlways("[MercOrders] focus target = " .. tostring(nm))
    self:OrderBarkSome("merc_bark_ack", 2)
    return true
end

function mercenaries:OrderFocusClear(why)
    if _G.MercFocusTarget == nil then return end
    _G.MercFocusTarget, _G.MercFocusTargetAt = nil, nil
    System.LogAlways("[MercOrders] focus cleared (" .. tostring(why or "?") .. ")")
end

-- The called target, while it is still worth calling. Dropped when it dies, goes
-- out of reach, or the order simply gets old.
function mercenaries:OrderFocusLive()
    local w = _G.MercFocusTarget
    if not w then return nil end
    if (nowSecs() - (_G.MercFocusTargetAt or 0)) > self.FocusHoldSecs then
        self:OrderFocusClear("expired"); return nil
    end
    local ent
    pcall(function() ent = XGenAIModule.GetEntityByWUID(w) end)
    if not (ent and self:IsCombatViable(ent)) then
        self:OrderFocusClear("target down"); return nil
    end
    if not self:IsWithinAggroRange(ent) then return nil end
    return w
end

-- ==== barks ====
-- Several men, not one, and not all at once: pick from across the squad rather
-- than the three standing nearest each other, then stagger them so it reads as a
-- line passing word along instead of a chord.
mercenaries.OrderBarkMinGap = 6.0

function mercenaries:OrderBarkSome(alias, count, metarole)
    count = math.max(1, tonumber(count) or 3)
    local pool = {}
    pcall(function()
        for _, ent in pairs(self.ActiveMercs or {}) do
            if ent and self:IsAliveAndWell(ent, false) then
                local p = ent.GetWorldPos and ent:GetWorldPos()
                if p then table.insert(pool, { ent = ent, p = p }) end
            end
        end
    end)
    if #pool == 0 then return 0 end

    -- Farthest-point selection: each speaker is the man furthest from everyone
    -- already speaking, so the shout comes from across the formation.
    local picked = {}
    table.insert(picked, table.remove(pool, math.random(#pool)))
    while #picked < count and #pool > 0 do
        local bi, bd
        for i, c in ipairs(pool) do
            local nearest
            for _, s in ipairs(picked) do
                local dx, dy = c.p.x - s.p.x, c.p.y - s.p.y
                local d = dx * dx + dy * dy
                if not nearest or d < nearest then nearest = d end
            end
            if nearest and (not bd or nearest > bd) then bi, bd = i, nearest end
        end
        if not bi then break end
        table.insert(picked, table.remove(pool, bi))
    end

    local n = 0
    for i, s in ipairs(picked) do
        local wuid = s.ent.this and s.ent.this.id or s.ent.id
        if wuid then
            n = n + 1
            if i == 1 then
                self:OrderBarkFire(wuid, alias, metarole)
            else
                -- Staggered by hand rather than by timer id: SetTimerForFunction
                -- takes a function NAME, so the delay is carried in a queue the
                -- monitor tick drains.
                self.OrderBarkQueue = self.OrderBarkQueue or {}
                table.insert(self.OrderBarkQueue, {
                    at = nowSecs() + (i - 1) * (0.55 + math.random() * 0.5),
                    wuid = wuid, alias = alias, metarole = metarole,
                })
            end
        end
    end
    return n
end

-- `metarole` is a boolean request for THE vanilla combat shout, not a name - the tree
-- spells the metarole out as a literal. Wiring a second one means a second node.
-- See docs/squad-orders.md.
function mercenaries:OrderBarkFire(wuid, alias, metarole)
    if metarole then
        _G.MercMetaBarkReq = _G.MercMetaBarkReq or {}
        _G.MercMetaBarkReq[tostring(wuid)] = true
    elseif alias then
        self:RequestBark(wuid, alias)
    end
end

-- One consumer for both bark queues, shared by follow.xml, camp_actor.xml and
-- mercenary_scheduler.xml. An alias names one of our own dialogs; a metarole casts
-- from the base game's own pool for that role instead, which is how a merc shouts a
-- real voiced line with no mod dialog and no shipped audio. Exactly one of the two
-- is ever non-empty, because schedulerMonolog treats a set alias as the pin.
function mercenaries:BarkPoll(bt_data, myWuid)
    bt_data.hasBarkReq   = false
    bt_data.hasMetaBark  = false
    bt_data.barkReqAlias = ''
    local k = tostring(myWuid)

    local br = _G.MercBarkReq
    if br then
        local a = br[k]
        if a and a ~= '' then
            bt_data.barkReqAlias = a
            bt_data.hasBarkReq   = true
            br[k] = nil
            return
        end
    end

    -- A flag, not a name: the metarole itself is a LITERAL in the tree. schedulerMonolog
    -- takes it as a node attribute and there is no shipped example anywhere of one being
    -- fed from a variable, so it stays spelled out the way foe_combat.xml does it.
    local mr = _G.MercMetaBarkReq
    if mr and mr[k] then
        bt_data.hasMetaBark = true
        mr[k] = nil
    end
end

function mercenaries:OrderBarkDrain()
    local q = self.OrderBarkQueue
    if not q or #q == 0 then return end
    local t, keep = nowSecs(), {}
    for _, r in ipairs(q) do
        if t >= r.at then self:OrderBarkFire(r.wuid, r.alias, r.metarole)
        else table.insert(keep, r) end
    end
    self.OrderBarkQueue = keep
end

-- Shout on a fresh alert, and again if a fight simply drags on.
--
-- Latching on the rising edge ALONE was wrong: EnemyAlerted holds for 20s after the
-- last armed hostile and barely ever falls on a road with patrols about, so the
-- squad shouted once and then stayed silent for the rest of the session.
mercenaries.OrderAlertRepeatSecs = 45.0

function mercenaries:OrderAlertBarkTick()
    if not self.EnemyAlerted then
        self._alertBarked = false
        return
    end
    local t    = nowSecs()
    local last = self._alertBarkAt or -999
    if self._alertBarked and (t - last) < self.OrderAlertRepeatSecs then return end
    if (t - last) < self.OrderBarkMinGap then return end
    self._alertBarked = true
    self._alertBarkAt = t
    self:OrderBarkSome(nil, math.random(3, 5), true)
end

-- Told, at most once a minute, that the men are standing there being hit because the
-- player told them to. The situation lasts as long as the fight does, so this has to
-- be throttled hard or it is a wall of text.
mercenaries.HoldFireWarnSecs = 60.0

function mercenaries:HoldFireWarn()
    local t = nowSecs()
    if (t - (self._holdFireWarnAt or -999)) < self.HoldFireWarnSecs then return end
    self._holdFireWarnAt = t
    Game.SendInfoText('merc_info_holdfire_hit', false, 0, 4)
    System.LogAlways("[MercOrders] under attack with hold fire on - they are not fighting back")
end

-- ==== state ====
function mercenaries:LoadOrderState()
    local s = self:LoadString("MercEngagePersistent")
    _G.MercEngage = (s and self.EngageCodeOf[s]) and s or "default"

    local a = self:LoadString("MercAggroPersistent")
    local name = (a and self.AggroPresets[a]) and a or "balanced"
    local p = self.AggroPresets[name]
    _G.MercAggro    = name
    self.SwarmCap     = p.cap
    self.SwarmCapMax  = p.max
    self.SwarmCapHard = p.hard

    _G.MercFocusTarget, _G.MercFocusTargetAt = nil, nil
    self.OrderBarkQueue = {}
end

function mercenaries:MonitorOrderTokens(p)
    local nEngage = p:GetCountOfClass(self.TokenIDEngage)
    if nEngage and nEngage > 0 then
        p:DeleteItemOfClass(self.TokenIDEngage, nEngage)
        self:SetEngageStance(self.EngageOrder[nEngage] or "default")
    end

    local nAggro = p:GetCountOfClass(self.TokenIDAggro)
    if nAggro and nAggro > 0 then
        p:DeleteItemOfClass(self.TokenIDAggro, nAggro)
        self:SetAggroPreset(self.AggroOrder[nAggro] or "balanced")
    end

    local nFocus = p:GetCountOfClass(self.TokenIDFocus)
    if nFocus and nFocus > 0 then
        p:DeleteItemOfClass(self.TokenIDFocus, nFocus)
        self:OrderFocusTarget()
    end
end

function mercenaries:OrderStatus()
    System.LogAlways(string.format("[MercOrders] engagement=%s aggression=%s (cap %d/%d/%d) focus=%s",
        tostring(_G.MercEngage), tostring(_G.MercAggro),
        self.SwarmCap or 0, self.SwarmCapMax or 0, self.SwarmCapHard or 0,
        tostring(_G.MercFocusTarget or "none")))
end

for _, k in ipairs(mercenaries.EngageOrder) do
    System.AddCCommand("merc_engage_" .. k, "mercenaries:SetEngageStance('" .. k .. "')",
        "Engagement stance: " .. (mercenaries.EngageLabel[k] or k))
end
for _, k in ipairs(mercenaries.AggroOrder) do
    System.AddCCommand("merc_aggro_" .. k, "mercenaries:SetAggroPreset('" .. k .. "')",
        "Anti-swarm preset: " .. (mercenaries.AggroPresets[k].label or k))
end
System.AddCCommand("merc_focus", "mercenaries:OrderFocusTarget()",
    "Call the target you are looking at (or locked onto) for the whole squad")
System.AddCCommand("merc_focus_clear", "mercenaries:OrderFocusClear('console')", "Drop the called target")
System.AddCCommand("merc_orders_status", "mercenaries:OrderStatus()", "Report the squad's combat orders")
