-- Shared support for the reusable AI behavior modules (combat_melee,
-- combat_archer_dynamic, combat_archer_static, follow, camp_actor).
-- One combat-data updater per module kind; side differences (merc vs enemy)
-- are resolved here from the entity name, so the trees stay side-agnostic.
-- See docs/ai-modules.md.

-- Which side an AI-module NPC is on, from its spawn-name prefix.
-- 'friend' = the player's people, 'enemy' = the hostile groups,
-- 'patrol'  = the roaming road gangs.
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
function mercenaries:MeleePlayerLeash()
    local squad = self.SquadSize or 0
    local d = self.MeleePlayerLeashBase + squad * self.MeleePlayerLeashPerMerc
    local floor = self.EnemyAlertRadius or 60.0
    if d < floor then d = floor end
    if d > self.MeleePlayerLeashMax then d = self.MeleePlayerLeashMax end
    return d
end

-- The scheduler's de-target/sheathe threshold, kept in step with the melee module's player
-- leash so the two cannot disagree - one sheathing him while the other still wants him
-- fighting is exactly the draw/sheathe loop. A little wider, so combat ends before the
-- target is dropped rather than the other way round.
function mercenaries:MercLeashes(bt_data)
    bt_data.deTargetDist = self:MeleePlayerLeash() + 8.0
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
    if self.MercTargetOf then self.MercTargetOf[k] = nil end
    if self.EnemyTargetOf then self.EnemyTargetOf[k] = nil end
    if self.EnemyClaimWuid then self.EnemyClaimWuid[k] = nil end
    if self.StaticArcherTargetOf then self.StaticArcherTargetOf[k] = nil end
    -- ForcedTargetOf is otherwise only cleared when the TARGET dies, so an
    -- encounter override outlived the NPC that held it.
    if self.ForcedTargetOf then self.ForcedTargetOf[k] = nil end
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

        if data.isArcher then
            if (_G.ArcherStance or "skirmish") ~= "melee" then data.disengage = true end
            if distToTarget and distToTarget > (self.MeleeTargetLeash + 5.0) then data.disengage = true end
            if distToPlayer > (pLeash + 5.0) then data.disengage = true end
        else
            if distToTarget and distToTarget > self.MeleeTargetLeash then data.disengage = true end
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
        data.distanceToTarget = 9999.0

        local me = XGenAIModule.GetEntityByWUID(myWuid)
        if not me then return end
        local name = me:GetName() or ''
        local side = self:SideOf(name)
        local myPos = me:GetPos()

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

        -- Out of ammo: nothing left in any ranged ammo class (arrows, bolts, shot).
        data.outOfAmmo = false
        if me.inventory and me.inventory.GetCountOfClass then
            local total = 0
            local pools = { self.ArcherArrowClasses, self.ArcherBoltClasses, self.ArcherShotClasses }
            for _, pool in ipairs(pools) do
                if pool then
                    for _, cls in ipairs(pool) do
                        local ok2, c = pcall(function() return me.inventory:GetCountOfClass(cls) end)
                        if ok2 and c then total = total + c end
                    end
                end
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
            if distToPlayer > 40.0 then data.leashExceeded = true end
            if (_G.ArcherStance or "skirmish") ~= "skirmish" then data.stanceValid = false end
        else
            if data.isTargetAlive and data.distanceToTarget > 60.0 then data.leashExceeded = true end
        end

        -- Keep-distance retreat point (dynamic module only reads it in the 4.5-9m band).
        if data.isTargetAlive and tp and myPos
           and data.distanceToTarget >= 4.5 and data.distanceToTarget < 9.0
           and not (side == "friend" and distToPlayer > 35.0) then
            local ax, ay = myPos.x - tp.x, myPos.y - tp.y
            local len = math.sqrt(ax * ax + ay * ay)
            if len > 0.1 then
                ax, ay = ax / len, ay / len
                local raw = { x = myPos.x + ax * 4.0, y = myPos.y + ay * 4.0, z = myPos.z }
                -- Don't kite backwards through a camp wall: if the step crosses one,
                -- simply don't take it (the tree tolerates hasRetreat = false and just
                -- keeps shooting from where it stands).
                local blocked = false
                if self.NavIsBlocked then
                    pcall(function() blocked = self:NavIsBlocked(myPos, raw) end)
                end
                local ground = (not blocked) and self:FindValidGround(raw, myPos.z) or nil
                if ground then
                    data.retreatPos.x = ground.x
                    data.retreatPos.y = ground.y
                    data.retreatPos.z = ground.z
                    data.hasRetreat = true
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
