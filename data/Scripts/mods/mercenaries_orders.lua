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
            end
        end
    end)
end

-- Is anything currently locked onto this merc? Used so "defend only" does not
-- yank a man out of a fight somebody else started with him.
-- Is this merc in a fight somebody else started with him? Used so "defend only" does not
-- yank a man out of one.
--
-- Asks the MERC, not the enemies. The old version walked CachedEnemies calling
-- soul:GetTarget() on each - a bind that does not exist, so it answered false for
-- everyone and the defend stance dropped claims it was meant to keep.
-- HasScriptContext("crime_interruptAttack") is the same test every scheduler already
-- uses for $inCombat, and it is proven.
function mercenaries:EngageBeingAttacked(myWuidStr)
    local hit = false
    pcall(function()
        for _, ent in pairs(self.ActiveMercs or {}) do
            local w = ent and (ent.this and ent.this.id or ent.id)
            if w and tostring(w) == myWuidStr then
                hit = ent.soul and ent.soul:HasScriptContext("crime_interruptAttack") or false
                return
            end
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
-- The two hostility gates are never both waived on the RELATIONSHIP paths - the
-- relationship floor and the drawn-weapon proof are each other's safety net (see
-- docs/combat-target-selection.md). LockedOntoUs is a third gate, not a waiver of
-- those two: see below.
-- Returns accepted, viaLockOn. The second tells UpdateEnemyCache this man is confirmed
-- to be FIGHTING us, which is what its second pass grows the rest of the battle from.
-- `armed` is read once by the caller and handed down rather than re-queried here.
function mercenaries:EngageCacheAccepts(ent, playerWuid, armed, confirmed)
    if self:IsValidEnemy(ent, player, playerWuid, false, true) then return true, false end
    -- Someone with his weapon out and OUR name on it, whatever the relationship table
    -- says. This is what base-game enemies need: the relationship floor demands exactly
    -- -1 to the player, and a vanilla hostile does not necessarily sit there until he has
    -- actually picked the fight - so he never entered the cache, and a cache miss is
    -- total. ScanForEnemies feeds the BT's candidate array from the cache, so the
    -- lock-on pass (EvaluateCombatTarget) could not see him either, and the ONLY way in
    -- was the player's own target - which is why the squad waited for the player to
    -- commit ("not instantly") and then only put the cap's worth of men on that one man
    -- ("not all of them").
    if not self:IsOwnSide(ent) and (confirmed or self:LockedOntoUs(ent, armed)) then
        -- His camp is awake, whatever its own alarm still thinks. IsValidEnemy refuses
        -- every member of an unalerted bandit camp - which is right for a camp nobody
        -- has touched, and completely wrong once one of its men is swinging at us: the
        -- squad then stood watching a fight it was not allowed to see. Waking the camp
        -- rather than exempting the one man is deliberate - the rest of them are in it
        -- too, and the whole point is that the squad engages the CAMP, not one bandit.
        if self.BanditCampAlertFor then
            self:BanditCampAlertFor(tostring(ent.this and ent.this.id or ent.id),
                                    "a bandit is fighting us")
        end
        if self:IsValidEnemy(ent, player, playerWuid, true, true) then return true, true end
    end
    if self:EngageCode() ~= 1 then return false, false end
    if self:IsOwnSide(ent) then return false, false end
    return self:IsValidEnemy(ent, player, playerWuid, true, false), false
end

-- Is this NPC armed and targeting the player or one of the squad?
--
-- BEST EFFORT ONLY, and nothing may depend on it. `soul:GetTarget()` is not a Lua
-- scriptbind in this engine - it appears nowhere in vanilla's own scripts - so this
-- silently answers "no" for everybody and always has. The working answer comes from the
-- behaviour tree's GetTarget node via NoteAttacker, which is what the `confirmed`
-- argument above carries; this is kept only so that it starts contributing for free if
-- the bind ever exists. Do NOT build anything new on it.
--
-- Gated on the weapon first so it costs nothing in a town, where every NPC in the scan
-- reaches this line.
function mercenaries:LockedOntoUs(ent, armed)
    if armed == false then return false end
    local hit = false
    pcall(function()
        if armed == nil and ent.human and not ent.human:IsWeaponDrawn() then return end
        local t = ent.soul and ent.soul:GetTarget()
        if t and self:IsOneOfOurs(t) then hit = true end
    end)
    return hit
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
    -- Best effort, and it never fires: soul:GetTarget() is not a Lua scriptbind (see
    -- LockedOntoUs above), so in practice the look-at memory below IS this order's
    -- input. Left in place because it costs nothing and would be the better source if
    -- the bind ever existed.
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

function mercenaries:OrderBarkSome(alias, count)
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
                self:OrderBarkFire(wuid, alias)
            else
                -- Staggered by hand rather than by timer id: SetTimerForFunction
                -- takes a function NAME, so the delay is carried in a queue the
                -- monitor tick drains.
                self.OrderBarkQueue = self.OrderBarkQueue or {}
                table.insert(self.OrderBarkQueue, {
                    at = nowSecs() + (i - 1) * (0.55 + math.random() * 0.5),
                    wuid = wuid, alias = alias,
                })
            end
        end
    end
    return n
end

function mercenaries:OrderBarkFire(wuid, alias)
    if alias then self:RequestBark(wuid, alias) end
end

-- The one bark consumer, shared by follow.xml, camp_actor.xml and
-- mercenary_scheduler.xml. An alias names one of this mod's own dialogs.
--
-- THERE IS NO VANILLA-METAROLE PATH. A combat-start shout was built on
-- schedulerMonolog with alias="" and metarole='NPC_VIDI_NEPRITELE_A_BUDE_UTOCIT' -
-- casting from the base game's own pool, the way foe_combat.xml does - and it never
-- produced a sound on a merc. Removed rather than left in mute: the requirement is
-- that the speaking soul has a skald_character row whose voice carries those
-- recordings, and the merc souls do not.
function mercenaries:BarkPoll(bt_data, myWuid)
    bt_data.hasBarkReq   = false
    bt_data.barkReqAlias = ''
    local k = tostring(myWuid)

    local br = _G.MercBarkReq
    if br then
        local a = br[k]
        if a and a ~= '' then
            bt_data.barkReqAlias = a
            bt_data.hasBarkReq   = true
            br[k] = nil
        end
    end
end

function mercenaries:OrderBarkDrain()
    local q = self.OrderBarkQueue
    if not q or #q == 0 then return end
    local t, keep = nowSecs(), {}
    for _, r in ipairs(q) do
        if t >= r.at then self:OrderBarkFire(r.wuid, r.alias)
        else table.insert(keep, r) end
    end
    self.OrderBarkQueue = keep
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
    mercenaries:DevCommand("merc_engage_" .. k, "mercenaries:SetEngageStance('" .. k .. "')",
        "Engagement stance: " .. (mercenaries.EngageLabel[k] or k))
end
for _, k in ipairs(mercenaries.AggroOrder) do
    mercenaries:DevCommand("merc_aggro_" .. k, "mercenaries:SetAggroPreset('" .. k .. "')",
        "Anti-swarm preset: " .. (mercenaries.AggroPresets[k].label or k))
end
mercenaries:DevCommand("merc_orders_status", "mercenaries:OrderStatus()", "Report the squad's combat orders")

-- ==== Idle-bark pacing ====
-- The bark loop in mercenary_scheduler.xml paces itself with `Wait 1200s GameTime`, which
-- is ~20 in-game minutes and exactly right during normal play. It is NOT right while the
-- world clock is racing: sleeping or waiting runs game time at a huge ratio (the mod's own
-- wait/sleep test is `GetWorldTimeRatio() > 20`, and a night's sleep is far above that), so
-- the wait expires in a fraction of a real second and every merc in the squad free-runs his
-- monolog loop. Forty men doing that is dozens of schedulerMonolog calls a second.
--
-- The scheduler now also refuses to bark while the squad is idle, which covers sleep and
-- wait directly. This is the floor underneath that: a REAL-time minimum between one merc's
-- barks, so no clock ratio and no missed idle flag can make the loop spin. System.GetCurrTime
-- is real seconds - the same clock the eviction and camp-busy windows use.
mercenaries.BarkRealMinSecs  = 240      -- real seconds a merc must wait between his own barks
mercenaries.BarkRealJitter   = 180      -- ...plus up to this, so the squad does not sync up
mercenaries.BarkNextAt       = {}       -- [wuidStr] = earliest real time he may bark again

function mercenaries:MercBarkDue(bt_data, myWuid)
    bt_data.barkDue = false
    pcall(function()
        local k   = tostring(myWuid)
        local now = System.GetCurrTime() or 0
        local due = self.BarkNextAt[k]
        if due and now < due then return end
        -- Claimed on the CHECK, not on the bark: a merc the speaking lock turns away has
        -- still had his turn, which is what stops the whole squad queueing on one lock.
        self.BarkNextAt[k] = now + self.BarkRealMinSecs + math.random(0, self.BarkRealJitter)
        bt_data.barkDue = true
    end)
end

-- ==== Hardcore mode vs the order wheel ====
-- Hardcore gives every friendly man the MUZ_UKAZUJE_CESTU metarole (vanilla
-- Libs/Storm/roles/world/hardcoreMode.xml), which makes its "ask for directions" chat a
-- candidate on our mercs too. Two Type="chat" dialogues of the same ClashPriority cannot
-- both show, and that one wins - the wheel is replaced by a single "Ask for directions".
-- Taking the metarole off the man leaves the wheel as the only chat he has. Storm does the
-- same thing declaratively with hardcoreMode_disableDirectionsChat
-- (libs/Storm/contexts/mercenariescontexts.xml); this is the runtime half, so a man who is
-- already in the world when the rule has not run is covered too. See docs/order-wheel.md.
mercenaries.DirectionsChatRoles = { "MUZ_UKAZUJE_CESTU", "ZENA_UKAZUJE_CESTU" }

function mercenaries:StripDirectionsChat(entity)
    if not (entity and entity.soul) then return end
    for _, role in ipairs(self.DirectionsChatRoles) do
        pcall(function()
            if entity.soul:HasMetaRoleByName(role) then
                entity.soul:RemoveMetaRoleByName(role)
            end
        end)
    end
end

function mercenaries:WheelChatStatus()
    local n, blocked = 0, 0
    for name, ent in pairs(self.ActiveMercs or {}) do
        if ent and ent.soul then
            local muz, zena, ctx
            pcall(function() muz  = ent.soul:HasMetaRoleByName("MUZ_UKAZUJE_CESTU") end)
            pcall(function() zena = ent.soul:HasMetaRoleByName("ZENA_UKAZUJE_CESTU") end)
            pcall(function() ctx  = ent.soul:HasScriptContext("hardcoreMode_disableDirectionsChat") end)
            n = n + 1
            if muz or zena then blocked = blocked + 1 end
            System.LogAlways(string.format("[MercOrders] %-44s directionsRole=%s/%s disableCtx=%s",
                name, tostring(muz), tostring(zena), tostring(ctx)))
        end
    end
    System.LogAlways(string.format("[MercOrders] wheel check: %d merc(s), %d still carrying the directions chat", n, blocked))
end

mercenaries:DevCommand("merc_wheel_status", "mercenaries:WheelChatStatus()",
    "Whether the hardcore directions chat is still on the men (it hides the order wheel)")
