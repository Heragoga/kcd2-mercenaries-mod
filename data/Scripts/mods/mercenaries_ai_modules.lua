-- Shared support for the reusable AI behavior modules (combat_melee,
-- combat_archer_dynamic, combat_archer_static, follow, camp_actor).
-- One combat-data updater per module kind; side differences (merc vs enemy)
-- are resolved here from the entity name, so the trees stay side-agnostic.
-- See docs/ai-modules.md.

-- Which side an AI-module NPC is on, from its spawn-name prefix.
-- 'friend' = the player's people, 'enemy' = the hostile groups,
-- 'patrol'  = the roaming road gangs.
-- How long an archer's kite-retreat point stays valid before it is searched again.
mercenaries.RetreatCacheSecs = 2.0

-- Archer engagement bands, per ranged weapon. See docs/archers.md.
--   melee   - inside this, drop to the sidearm
--   keepMin - inside this, step back (the kite band is melee..keepMin)
--   keepMax - beyond this, walk in to keepMin before firing
mercenaries.ArcherBands = {
    bow        = { melee = 4.5, keepMin = 9.0, keepMax = 35.0 },
    crossbow   = { melee = 4.5, keepMin = 9.0, keepMax = 35.0 },
    handcannon = { melee = 3.0, keepMin = 5.0, keepMax = 12.0 },
}

-- Only the player's archers carry a chosen weapon type; every other side spawns
-- with bows, so they take the bow band.
function mercenaries:ArcherBand(side)
    if side == "friend" and self.GetArcherWeaponType then
        return self.ArcherBands[self:GetArcherWeaponType()] or self.ArcherBands.bow
    end
    return self.ArcherBands.bow
end
mercenaries.FriendPrefixes = { "SpawnedFriend_", "MercenaryCustomCompanion", "MercQuartermaster" }
mercenaries.EnemyPrefixes  = { "SpawnedEnemy_", "SpawnedRenegade_" }

-- Patrols are a THIRD side, not a flavour of the other two. They are hostile, but
-- they belong to a ROUTE, not to the player's squad:
--   * as "friend" (which is what the fall-through below used to give them) they
--     inherited the merc leash to the PLAYER, so a gang fighting 30m up the road
--     failed its combat on the first tick, every tick - the start-stop loop.
--   * as "enemy" they would get no leash at all and chase the player across
--     Kuttenberg, and PatrolSyncIndex would then rewrite the gang's notional route
--     index to wherever the chase ended, with PatrolDespawnRange deleting them
--     mid-fight on screen.
-- They leash to their own TARGET instead, like the enemy archer does.
-- Deliberately NOT added to ModEnemyPrefixes: loot sweep, wall battle and tower
-- archers are all documented as ignoring patrols (docs/patrols.md).
mercenaries.PatrolPrefixes = { "SpawnedPatrolman_", "SpawnedPatrol_" }
-- How far a patrolman may chase his own target before breaking off.
mercenaries.PatrolCombatLeash = 120.0

-- Merc melee leashes. Target leash is what actually matters in a fight; the player leash is a
-- backstop, and it MUST scale with squad size - the rear of a fifty-man column is legitimately
-- far from the player and a flat limit makes those men draw and sheathe on a loop.
-- Must be at least EnemyAlertRadius: once alerted the squad acquires targets up to 60m out,
-- and a leash shorter than the acquisition range disengages a merc on the first tick of the
-- charge - he would be told to fight something he is not allowed to walk to.
mercenaries.MeleeTargetLeash      = 70.0
mercenaries.MeleePlayerLeashBase  = 25.0
mercenaries.MeleePlayerLeashPerMerc = 0.7
mercenaries.MeleePlayerLeashMax   = 70.0

-- THE player leash, in one place. Both the melee module's disengage test and the scheduler's
-- de-target threshold read it, because two copies of the formula is how they drift apart.
--
-- The floor is the fix for a real bug: the comment above has always REQUIRED this to be at
-- least the acquisition range, but the constants never delivered it. 25 + 0.7/merc does not
-- reach 50 until about thirty-six mercs, while targets are acquired out to 50 m from the
-- PLAYER (UpdateEnemyCache scans around the player; IsValidEnemy then gates on
-- TargetDetectionRadius). So with any normal squad a merc could be handed a target 45 m out,
-- charge it, cross his own 32 m leash on the way, be told to disengage, sheathe, re-acquire
-- the same man - who is still the nearest - and draw again. That is the "they stand off and
-- draw and sheathe on a loop" report, and it was never about squad size being wrong.
--
-- EnemyAlertRadius is the number the comment names, and it sits inside the existing Max, so
-- the per-merc scaling still does its job for very large columns.
--
-- ORDER MATTERS, and getting it wrong put the bug straight back at Raborsch. The floor used
-- to be applied and then the Max clamp applied over it, which is only harmless while the
-- floor is below the Max. It stopped being harmless the moment a siege raised
-- EnemyAlertRadius to RaborschEngageRadius (160): the floor computed 160 and the very next
-- line cut it back to 70, so the squad acquired targets out to 160 m while being forbidden to
-- walk past 70 - the exact "handed a target he is not allowed to reach, so he draws, crosses
-- his leash, disengages, re-acquires the same man and draws again" loop this floor exists to
-- prevent. The Max bounds the SQUAD-SIZE SCALING; it was never meant to bound the acquisition
-- floor. So clamp first, floor second, and the floor always wins.
function mercenaries:MeleePlayerLeash()
    local squad = self.SquadSize or 0
    local d = self.MeleePlayerLeashBase + squad * self.MeleePlayerLeashPerMerc
    if d > self.MeleePlayerLeashMax then d = self.MeleePlayerLeashMax end
    local floor = self.EnemyAlertRadius or 60.0
    if d < floor then d = floor end
    return d
end

-- The TARGET leash, by the same rule. A flat 70 has the same defect as the player leash had:
-- during a siege the squad is handed targets out to EnemyAlertRadius (160) and then told to
-- disengage at 70. Read through this rather than the raw constant so the two cannot diverge.
function mercenaries:MeleeTargetLeashNow()
    local d = self.MeleeTargetLeash or 70.0
    local floor = self.EnemyAlertRadius or 60.0
    if d < floor then d = floor end
    return d
end

-- The scheduler's de-target/sheathe threshold, kept in step with the melee module's player
-- leash so the two cannot disagree - one sheathing him while the other still wants him
-- fighting is exactly the draw/sheathe loop. A little wider, so combat ends before the
-- target is dropped rather than the other way round.
-- ---------------------------------------------------------------------------
-- BEHAVIOUR LOD
--
-- Every merc runs the full acquisition pass on every poll, whether or not there is anything
-- in the world to acquire. That cost scales with squad size and is paid hardest exactly where
-- it is least useful: fifty men standing in a peaceful market. This is the one lever in the
-- mod that scales DOWN with squad size instead of up.
--
-- The gate is deliberately SQUAD-WIDE and pessimistic, not per-merc-distance. Distance would
-- be the obvious proxy - a man forty metres back cannot see much - but it is the wrong one: a
-- merc at the back is exactly who gets jumped first, and a distance gate would blind him. What
-- actually makes the pass pointless is that there is NOTHING TO FIND, and the mod already
-- computes that squad-wide, every 300ms, authoritatively:
--
--   * CachedEnemies empty  - ScanForEnemies reads that very table, so with it empty the whole
--     acquisition block is provably a no-op: the enemies array comes back empty, the For loop
--     never iterates, and PickCombatTarget has nothing to pick from.
--   * EnemyAlerted false   - nothing armed has been seen recently anywhere near the squad.
--   * this merc not in combat, not holding a claim, and no forced/focus target.
--
-- Even then it is not skipped outright: MercCheapSkip lets a FULL pass through every Nth poll
-- (see the BT), so anything the squad-wide signals could miss - a town guard turning on one
-- man with nothing yet cached - is still picked up within a couple of seconds instead of
-- never. That is the difference between an optimisation and a merc who stands and watches.
mercenaries.BehaviourLodOn   = true
mercenaries.MercCheapSkip    = 3      -- full passes: 1 in (this + 1)

function mercenaries:MercCheapMode(bt_data, myWuid)
    if not self.BehaviourLodOn then bt_data.cheapMode = false; return end
    local cheap = true
    -- Anything at all going on squad-wide takes every man back to full rate.
    if self.EnemyAlerted then cheap = false end
    if cheap and next(self.CachedEnemies or {}) ~= nil then cheap = false end
    if cheap and next(self.MaybeEnemies or {}) ~= nil then cheap = false end
    if cheap and _G.MercFocusTarget then cheap = false end
    if cheap and bt_data.inCombat == true then cheap = false end
    if cheap and myWuid then
        local k = tostring(myWuid)
        if (self.MercTargetOf or {})[k] or (self.ForcedTargetOf or {})[k] then cheap = false end
    end
    bt_data.cheapMode = cheap
    bt_data.cheapEvery = self.MercCheapSkip or 3
end

function mercenaries:MercLeashes(bt_data)
    bt_data.deTargetDist = self:MeleePlayerLeash() + 8.0
    -- Gates the one BT node that asks the ENGINE what the player is fighting. That node
    -- reports "Cannot find host NPC" on every poll of every merc - the player is not an NPC
    -- host, so it cannot resolve him - which at a 300ms poll and twenty men is dozens of
    -- failed engine lookups a second, and in the dev build dozens of log lines a second on
    -- top. The AI log channel is off in the release build, so the visible half is dev-only;
    -- the failed call is not. Reading the flag the combat scan has already computed costs a
    -- table lookup, and outside a fight there is no player target to ask about anyway.
    -- See PlayerCombatTargetProbe for whether the node has ever actually answered.
    bt_data.playerFighting = (_G.MercSquadThreat == true)
end

function mercenaries:SideOf(name)
    name = name or ''
    for _, p in ipairs(self.EnemyPrefixes) do
        if string.find(name, p, 1, true) then return "enemy" end
    end
    for _, p in ipairs(self.PatrolPrefixes) do
        if string.find(name, p, 1, true) then return "patrol" end
    end
    for _, p in ipairs(self.FriendPrefixes) do
        if string.find(name, p, 1, true) then return "friend" end
    end
    return "friend" -- unknown spawns (e.g. quartermaster variants) err friendly
end

-- Per-entity forced target, settable from encounter code: as long as the entry
-- is set and alive, FindEnemyTarget returns it instead of scanning.
-- mercenaries.ForcedTargetOf[tostring(wuid)] = targetWuid
mercenaries.ForcedTargetOf = {}

-- Clear every combat claim an NPC holds, whichever pool it used. Called from
-- the modules' OnFail so one cleanup works for both sides (and tower archers).
function mercenaries:ClearCombatClaim(wuid)
    local k = tostring(wuid)
    if self.MercDropClaim then self:MercDropClaim(k) end
    if self.EnemyTargetOf then self.EnemyTargetOf[k] = nil end
    if self.EnemyClaimWuid then self.EnemyClaimWuid[k] = nil end
    -- Combat ending is the one moment he should look again immediately, and it is also
    -- what keeps this table from growing an entry per NPC the mod ever spawned.
    if self.StaticArcherTargetOf then self.StaticArcherTargetOf[k] = nil end
    -- ForcedTargetOf is otherwise only cleared when the TARGET dies, so an
    -- encounter override outlived the NPC that held it.
    if self.ForcedTargetOf then self.ForcedTargetOf[k] = nil end
end

-- Should an NPC leaving a fight put his weapon away? Shared by combat_melee and
-- combat_archer_dynamic - both end on their target's death and both used to sheathe
-- unconditionally for anyone who was not an enemy.
--
--
-- Not while the battle is still going on around him. combat_melee ends every time its
-- TARGET dies - which in a big fight is every few seconds per man - and the OnFail
-- sheathe then ran with enemies still swinging a few metres off, so he sheathed,
-- re-acquired and drew again. Across a squad that is the "half of them keep drawing and
-- sheathing in the middle of a battle" report; foe_combat never sheathes for the same
-- reason, and the note there says so.
--
-- The weapon still goes away, just not here. The scheduler sheathes on idleTicks (~16s
-- with nothing to do) and on crossing the player leash, which are the two cases the
-- sheathe actually exists for - a man standing about in camp with his sword out.
mercenaries.SheatheClearRange = 25.0

function mercenaries:CombatMaySheathe(data, ent)
    -- combat_melee publishes isEnemy; the archer module does not, so derive it there.
    local isEnemy = data and data.isEnemy
    if isEnemy == nil then
        pcall(function() isEnemy = (self:SideOf(ent:GetName() or '') ~= "friend") end)
    end
    if isEnemy then return false end
    local may = true
    pcall(function()
        local mp = ent and ent:GetPos()
        if not mp then return end
        local r2 = (self.SheatheClearRange or 25.0) ^ 2
        for _, e in ipairs(self.CachedEnemies or {}) do
            local ep = e.pos or (e.entity and e.entity:GetPos())
            if ep and e.entity and self:IsCombatViable(e.entity) then
                local dx, dy, dz = ep.x - mp.x, ep.y - mp.y, ep.z - mp.z
                if (dx * dx + dy * dy + dz * dz) <= r2 then may = false return end
            end
        end
    end)
    return may
end

-- ---------------------------------------------------------------------------
-- combat_melee support. Sets: isTargetAlive, disengage, isArcher.
-- Disengage is distance/orders only - nobody breaks off over health. A merc that
-- dropped combat when hurt just trailed the player unarmed in the middle of a
-- fight, which read as cowardice and got him killed anyway; fighting on is both
-- better-looking and no worse for survival.
--   friend melee:  >20m from player
--   friend archer (melee stance): >25m from player, or archer stance left melee
--   patrol:        >60m from its own TARGET (never from the player)
--   enemy:         never (target death ends the burst)
-- ---------------------------------------------------------------------------
function mercenaries:UpdateMeleeCombatData(data, myWuid)
    local ok, err = pcall(function()
        data.isTargetAlive = false
        data.disengage = false

        local me = XGenAIModule.GetEntityByWUID(myWuid)
        local name = (me and me:GetName()) or ''
        local side = self:SideOf(name)
        data.isArcher = (string.find(name, '_archer_', 1, true) ~= nil)
        -- Anything that is not the player's own man draws its weapon explicitly
        -- before the approach (combat_melee.xml) - patrols included.
        data.isEnemy = (side ~= "friend")

        -- ...but only if it is not already out. The explicit DrawAction is a full
        -- animation that halts the NPC, and combat_melee replays it on every re-fire,
        -- which reads as a pause part-way through the charge. See docs/foe-ai.md.
        data.needsDraw = true
        if me and me.human then
            local drawn = false
            pcall(function() drawn = me.human:IsWeaponDrawn() end)
            if drawn then data.needsDraw = false end
        end

        local mp = me and me:GetPos()
        local tp = nil
        if data.attackData and data.attackData.target then
            local t = XGenAIModule.GetEntityByWUID(data.attackData.target)
            if t and self:IsCombatViable(t) then
                data.isTargetAlive = true
                tp = t:GetPos()
            end
        end

        if side == "enemy" then return end

        if side == "patrol" then
            -- Leash to the TARGET, not the player: a road gang has no business
            -- measuring anything against where the player happens to be standing.
            -- Generous, because a gang-wide alert hands the tail of a long column a
            -- target well beyond their own detect range and they have to be allowed
            -- to close on it; still far inside PatrolDespawnRange, so it cannot turn
            -- into a cross-map chase.
            if tp and mp then
                local dx, dy, dz = tp.x - mp.x, tp.y - mp.y, tp.z - mp.z
                if math.sqrt(dx * dx + dy * dy + dz * dz) > (self.PatrolCombatLeash or 120.0) then
                    data.disengage = true
                end
            end
            return
        end

        local distToPlayer = 0
        if player and mp then
            local pp = player:GetPos()
            if pp then
                local dx, dy, dz = pp.x - mp.x, pp.y - mp.y, pp.z - mp.z
                distToPlayer = math.sqrt(dx * dx + dy * dy + dz * dz)
            end
        end

        -- Leash to the TARGET first, and to the player only as a far backstop. Both the value
        -- and the reasoning live in MeleePlayerLeash - it is shared with the scheduler's
        -- de-target threshold so the two can never disagree, which is itself a way to produce
        -- the draw/sheathe loop.
        local pLeash = self:MeleePlayerLeash()

        local distToTarget = nil
        if tp and mp then
            local dx, dy, dz = tp.x - mp.x, tp.y - mp.y, tp.z - mp.z
            distToTarget = math.sqrt(dx * dx + dy * dy + dz * dz)
        end

        local tLeash = self:MeleeTargetLeashNow()
        if data.isArcher then
            if (_G.ArcherStance or "skirmish") ~= "melee" then data.disengage = true end
            if distToTarget and distToTarget > (tLeash + 5.0) then data.disengage = true end
            if distToPlayer > (pLeash + 5.0) then data.disengage = true end
        else
            if distToTarget and distToTarget > tLeash then data.disengage = true end
            if distToPlayer > pLeash then data.disengage = true end
        end
    end)
    if not ok then System.LogAlways('[AI] UpdateMeleeCombatData error: ' .. tostring(err)) end
end

-- ---------------------------------------------------------------------------
-- combat_archer_dynamic support. Sets: isTargetAlive, distanceToTarget,
-- outOfAmmo, stanceValid, leashExceeded, hasRetreat (+retreatPos vec3).
--   friend: leashes to the player at 40m, invalid when the archer stance
--           leaves skirmish (the merc archers' stance toggle). Never breaks off
--           over health - our side fights to the death, same as the melee mercs.
--   enemy:  leashes to its own target at 60m, stance-free, still flees when hurt
-- Retreat: when the target closes into 4.5-9m, offer a ground-validated point
-- ~4m further away so the archer keeps its distance while shooting.
-- ---------------------------------------------------------------------------
function mercenaries:UpdateRangedCombatData(data, myWuid)
    local ok, err = pcall(function()
        data.isTargetAlive = false
        data.stanceValid = true
        data.leashExceeded = false
        data.hasRetreat = false
        data.hasApproach = false
        data.distanceToTarget = 9999.0

        local me = XGenAIModule.GetEntityByWUID(myWuid)
        if not me then return end
        local name = me:GetName() or ''
        local side = self:SideOf(name)
        local myPos = me:GetPos()

        -- The tree's own thresholds come from here, so one band table drives the
        -- whole engagement. reengage = the gap the sidearm burst must reopen before
        -- the ranged weapon comes back out.
        local band = self:ArcherBand(side)
        data.meleeRange = band.melee
        data.reengageRange = band.melee + 7.5

        local tp = nil
        if data.attackData and data.attackData.target then
            local t = XGenAIModule.GetEntityByWUID(data.attackData.target)
            if t and self:IsCombatViable(t) then
                data.isTargetAlive = true
                tp = t:GetPos()
                if tp and myPos then
                    local dx, dy, dz = tp.x - myPos.x, tp.y - myPos.y, tp.z - myPos.z
                    data.distanceToTarget = math.sqrt(dx * dx + dy * dy + dz * dz)
                end
            end
        end

        -- Out of ammo: friends carry the one weapon type the player selected
        -- (GetArcherWeaponType), so only that pool needs checking. Other sides always
        -- spawn with bows but aren't tracked by that global, so keep scanning every pool.
        data.outOfAmmo = false
        if me.inventory and me.inventory.GetCountOfClass then
            local pools
            if side == "friend" then
                local weaponType = self:GetArcherWeaponType()
                if weaponType == "crossbow" then pools = { self.ArcherBoltClasses }
                elseif weaponType == "handcannon" then pools = { self.ArcherShotClasses }
                else pools = { self.ArcherArrowClasses } end
            else
                pools = { self.ArcherArrowClasses, self.ArcherBoltClasses, self.ArcherShotClasses }
            end
            local total = 0
            for _, pool in ipairs(pools) do
                if pool then
                    for _, cls in ipairs(pool) do
                        local ok2, c = pcall(function() return me.inventory:GetCountOfClass(cls) end)
                        if ok2 and c then total = total + c end
                        if total > 0 then break end
                    end
                end
                if total > 0 then break end
            end
            data.outOfAmmo = (total == 0)
        end

        -- Health flee, enemies only. Our archers hold their ground and die shooting.
        if side ~= "friend" then
            local hp = nil
            pcall(function() hp = me.soul:GetState('health') end)
            if hp ~= nil and hp <= 12 then data.leashExceeded = true return end
        end

        local distToPlayer = 0
        if player and myPos then
            local pp = player:GetPos()
            if pp then
                local dx, dy, dz = pp.x - myPos.x, pp.y - myPos.y, pp.z - myPos.z
                distToPlayer = math.sqrt(dx * dx + dy * dy + dz * dz)
            end
        end

        if side == "friend" then
            -- The same leash the melee module uses, for the same reason: a flat 40m sat
            -- below the acquisition range, so an archer was handed a target and told to
            -- break off on the same tick, over and over. See MeleePlayerLeash.
            if distToPlayer > self:MeleePlayerLeash() then data.leashExceeded = true end
            if (_G.ArcherStance or "skirmish") ~= "skirmish" then data.stanceValid = false end
        else
            if data.isTargetAlive and data.distanceToTarget > 60.0 then data.leashExceeded = true end
        end

        -- Keep-distance retreat point (dynamic module only reads it in the melee..keepMin band).
        if data.isTargetAlive and tp and myPos
           and data.distanceToTarget >= band.melee and data.distanceToTarget < band.keepMin
           and not (side == "friend" and distToPlayer > 35.0) then
            local ax, ay = myPos.x - tp.x, myPos.y - tp.y
            local len = math.sqrt(ax * ax + ay * ay)
            if len > 0.1 then
                ax, ay = ax / len, ay / len
                -- Step just past the near edge of the band, not a fixed 4m: a hand
                -- cannon's band is 5m wide and a fixed step overshot it entirely.
                local step = (band.keepMin + 1.0) - data.distanceToTarget
                if step < 1.5 then step = 1.5 end
                local raw = { x = myPos.x + ax * step, y = myPos.y + ay * step, z = myPos.z }
                -- Don't kite backwards through a camp wall: if the step crosses one,
                -- simply don't take it (the tree tolerates hasRetreat = false and just
                -- keeps shooting from where it stands).
                local blocked = false
                if self.NavIsBlocked then
                    pcall(function() blocked = self:NavIsBlocked(myPos, raw) end)
                end
                -- FindValidGround's defaults (3.0m radius, 0.5m step) spiral over 132
                -- candidate points, and each one costs up to 9 physics raycasts - ~1,188
                -- rays, every BT cycle, per archer being kited. A retreat step is only
                -- 4m, so a 1.2m search is ample. The result is also cached briefly: the
                -- archer has not moved far between cycles, and recomputing it from
                -- scratch every 300ms was the whole cost. See docs/performance.md.
                local ground = nil
                if not blocked then
                    local key   = tostring(myWuid)
                    local now   = 0
                    pcall(function() now = System.GetCurrTime() or 0 end)
                    self._retreatCache = self._retreatCache or {}
                    local c = self._retreatCache[key]
                    if c and (now - c.at) < self.RetreatCacheSecs
                       and math.abs(c.fx - raw.x) < 0.75 and math.abs(c.fy - raw.y) < 0.75 then
                        ground = c.pos
                    else
                        ground = self:FindValidGround(raw, myPos.z, 1.2, 0.6)
                        if ground then
                            self._retreatCache[key] =
                                { pos = ground, at = now, fx = raw.x, fy = raw.y }
                        end
                    end
                end
                if ground then
                    data.retreatPos.x = ground.x
                    data.retreatPos.y = ground.y
                    data.retreatPos.z = ground.z
                    data.hasRetreat = true
                end
            end
        end

        -- Approach point: beyond keepMax the module used to stand and fire anyway, so
        -- the engagement distance was simply wherever the follow formation had left the
        -- archer. That is fine with a bow and useless with a hand cannon. Walk in to
        -- just outside keepMin instead. See docs/archers.md.
        if data.isTargetAlive and tp and myPos and not data.hasRetreat
           and data.distanceToTarget > band.keepMax then
            local ax, ay = myPos.x - tp.x, myPos.y - tp.y
            local len = math.sqrt(ax * ax + ay * ay)
            if len > 0.1 then
                ax, ay = ax / len, ay / len
                local want = band.keepMin + 1.0
                local raw = { x = tp.x + ax * want, y = tp.y + ay * want, z = tp.z }

                -- A friendly archer is leashed to the player, so the spot he closes on
                -- has to be inside that leash - otherwise he walks himself out of the
                -- squad, trips the 40m leash and disengages the moment he arrives.
                local allowed = true
                if side == "friend" and player then
                    local pp = player:GetPos()
                    if pp then
                        local px, py = pp.x - raw.x, pp.y - raw.y
                        allowed = math.sqrt(px * px + py * py) <= 35.0
                    end
                end
                if allowed and self.NavIsBlocked then
                    pcall(function() if self:NavIsBlocked(myPos, raw) then allowed = false end end)
                end

                if allowed then
                    -- Cached on the same terms as the retreat point, and for the same
                    -- reason: FindValidGround is raycast-heavy and this runs per archer
                    -- every BT cycle. See docs/performance.md.
                    local key = tostring(myWuid)
                    local now = 0
                    pcall(function() now = System.GetCurrTime() or 0 end)
                    self._approachCache = self._approachCache or {}
                    local c = self._approachCache[key]
                    local ground
                    if c and (now - c.at) < self.RetreatCacheSecs
                       and math.abs(c.fx - raw.x) < 1.5 and math.abs(c.fy - raw.y) < 1.5 then
                        ground = c.pos
                    else
                        ground = self:FindValidGround(raw, tp.z, 1.5, 0.6)
                        if ground then
                            self._approachCache[key] =
                                { pos = ground, at = now, fx = raw.x, fy = raw.y }
                        end
                    end
                    if ground then
                        data.approachPos.x = ground.x
                        data.approachPos.y = ground.y
                        data.approachPos.z = ground.z
                        data.hasApproach = true
                    end
                end
            end
        end
    end)
    if not ok then System.LogAlways('[AI] UpdateRangedCombatData error: ' .. tostring(err)) end
end

-- ---------------------------------------------------------------------------
-- NPC-led formations (patrols following a knight, etc.). Same chain layout as
-- UpdateFormationSlots, but keyed to an arbitrary leader and kept in its own
-- table so the per-tick player-squad rebuild can't wipe it. The follow module
-- reads these first (see CalculateFormationTarget).
-- ---------------------------------------------------------------------------
mercenaries.NpcFormations = {}

function mercenaries:AssignNpcFormation(leaderWuid, memberWuids, width)
    width = width or 2
    for i, w in ipairs(memberWuids) do
        local slot = i - 1
        local followTarget = leaderWuid
        if slot >= width then
            followTarget = memberWuids[slot - width + 1] or leaderWuid
        end
        self.NpcFormations[tostring(w)] = {
            slot = slot, followTarget = followTarget, totalMercs = #memberWuids,
        }
    end
end

function mercenaries:ClearNpcFormation(memberWuids)
    for _, w in ipairs(memberWuids) do
        self.NpcFormations[tostring(w)] = nil
    end
end

function mercenaries:BehaviourLodSet(on)
    self.BehaviourLodOn = (on == true)
    System.LogAlways("[MercBTLod] behaviour LOD " ..
        (self.BehaviourLodOn and ("ON - 1 full acquisition pass in " .. ((self.MercCheapSkip or 3) + 1) ..
                                  " while the squad has nothing to fight")
                             or "OFF - full acquisition pass every poll, every merc"))
end

function mercenaries:BehaviourLodStatus()
    local hot = {}
    if self.EnemyAlerted then hot[#hot+1] = "alerted" end
    if next(self.CachedEnemies or {}) ~= nil then hot[#hot+1] = "#CachedEnemies>0" end
    if next(self.MaybeEnemies or {}) ~= nil then hot[#hot+1] = "#MaybeEnemies>0" end
    if _G.MercFocusTarget then hot[#hot+1] = "focus target" end
    local claims = 0
    for _ in pairs(self.MercTargetOf or {}) do claims = claims + 1 end
    System.LogAlways("[MercBTLod] enabled=" .. tostring(self.BehaviourLodOn) ..
        "  fullPassEvery=" .. tostring((self.MercCheapSkip or 3) + 1) ..
        "  squad=" .. (#hot > 0 and ("HOT (" .. table.concat(hot, ", ") .. ")") or "quiet - mercs are cheap") ..
        "  claims=" .. claims)
    System.LogAlways("[MercBTLod] quiet means CachedEnemies/MaybeEnemies are empty and no alert - " ..
                     "the acquisition pass reads those tables, so with them empty it can find nothing.")
end
