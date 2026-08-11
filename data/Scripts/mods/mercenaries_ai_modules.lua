-- Shared support for the reusable AI behavior modules (combat_melee,
-- combat_archer_dynamic, combat_archer_static, follow, camp_actor).
-- One combat-data updater per module kind; side differences (merc vs enemy)
-- are resolved here from the entity name, so the trees stay side-agnostic.
-- See docs/ai-modules.md.

-- Which side an AI-module NPC is on, from its spawn-name prefix.
-- 'friend' = the player's people, 'enemy' = the hostile groups.
mercenaries.FriendPrefixes = { "SpawnedFriend_", "MercenaryCustomCompanion", "MercQuartermaster" }
mercenaries.EnemyPrefixes  = { "SpawnedEnemy_", "SpawnedRenegade_" }

function mercenaries:SideOf(name)
    name = name or ''
    for _, p in ipairs(self.EnemyPrefixes) do
        if string.find(name, p, 1, true) then return "enemy" end
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
    if self.StaticArcherTargetOf then self.StaticArcherTargetOf[k] = nil end
end

-- ---------------------------------------------------------------------------
-- combat_melee support. Sets: isTargetAlive, disengage, isArcher.
-- Disengage is distance/orders only - nobody breaks off over health. A merc that
-- dropped combat when hurt just trailed the player unarmed in the middle of a
-- fight, which read as cowardice and got him killed anyway; fighting on is both
-- better-looking and no worse for survival.
--   friend melee:  >20m from player
--   friend archer (melee stance): >25m from player, or archer stance left melee
--   enemy:         never (target death ends the burst)
-- ---------------------------------------------------------------------------
function mercenaries:UpdateMeleeCombatData(data, myWuid)
    local ok, err = pcall(function()
        data.isTargetAlive = false
        data.disengage = false

        local me = XGenAIModule.GetEntityByWUID(myWuid)
        local name = (me and me:GetName()) or ''
        data.isArcher = (string.find(name, '_archer_', 1, true) ~= nil)
        data.isEnemy = (self:SideOf(name) == "enemy")

        if data.attackData and data.attackData.target then
            local t = XGenAIModule.GetEntityByWUID(data.attackData.target)
            if t and self:IsAliveAndWell(t, true) then data.isTargetAlive = true end
        end

        if data.isEnemy then return end

        local distToPlayer = 0
        if player and me then
            local pp, mp = player:GetPos(), me:GetPos()
            if pp and mp then
                local dx, dy, dz = pp.x - mp.x, pp.y - mp.y, pp.z - mp.z
                distToPlayer = math.sqrt(dx * dx + dy * dy + dz * dz)
            end
        end

        if data.isArcher then
            if distToPlayer > 25.0 then data.disengage = true end
            if (_G.ArcherStance or "skirmish") ~= "melee" then data.disengage = true end
        else
            if distToPlayer > 20.0 then data.disengage = true end
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
            if t and self:IsAliveAndWell(t, true) then
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
