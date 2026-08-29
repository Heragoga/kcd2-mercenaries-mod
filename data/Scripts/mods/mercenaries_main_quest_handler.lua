-- Detect wait/sleep/fast-travel/teleport interruptions and temp-idle the mercs
-- so they don't scramble to catch up mid-transition; clears when it's over.
function mercenaries:MonitorMainQuestLoop()
    if _G.MercPersistentIdleFlag then
        return
    end

    -- System.GetCurrTime() is engine-cached per frame (cheaper than os.clock()).
    local currentRealTime = System.GetCurrTime()
    local realTimeDelta = 1.0 
    
    if self.LastRealTime then
        realTimeDelta = currentRealTime - self.LastRealTime
    end
    self.LastRealTime = currentRealTime

    -- Physical distance moved, for teleport/fast-travel detection.
    local currentPos = nil
    local distanceMoved = 0
    pcall(function() currentPos = player:GetWorldPos() end)
    
    if currentPos then
        if self.LastPlayerPos then
            local dx = currentPos.x - self.LastPlayerPos.x
            local dy = currentPos.y - self.LastPlayerPos.y
            local dz = currentPos.z - self.LastPlayerPos.z
            distanceMoved = math.sqrt(dx*dx + dy*dy + dz*dz)
        end
        self.LastPlayerPos = {x = currentPos.x, y = currentPos.y, z = currentPos.z}
    end
    
    local playerSpeed = 10.0
    pcall(function()
        playerSpeed = player:GetSpeed()
    end)

    -- GetHorse() returns an invalid (empty/"0") WUID when not mounted.
    local isOnHorse = false
    pcall(function()
        local horseWuid = player.human:GetHorse()
        if horseWuid and tostring(horseWuid) ~= "" and tostring(horseWuid) ~= "0" then
            isOnHorse = true
        end
    end)

    -- Check A: ghost movement (a transition sliding Henry with ~zero speed) with a
    -- grace period. Skipped while mounted, where riding is a false positive; the
    -- >25m instant-teleport check below still applies since fast travel can too.
    local isGhostMovement = (not isOnHorse) and (distanceMoved > 0.5 and playerSpeed < 0.1 and realTimeDelta < 0.4)
    local isInstantTeleport = (distanceMoved > 25.0)

    if isGhostMovement then
        self.LastGhostTickTime = currentRealTime
        if not self.GhostMovementStartTime then
            self.GhostMovementStartTime = currentRealTime
        end
        -- Only treat it as fast travel after 0.75s of sustained ghost movement.
        if (currentRealTime - self.GhostMovementStartTime) > 0.75 then
            self.FastTravelLastDetected = currentRealTime
        end
    else
        -- Reset the grace period only when Henry is really walking, or no ghost
        -- movement has been seen for 1.5s (rides out brief gaps between ticks).
        local timeSinceLastGhostTick = 0
        if self.LastGhostTickTime then
            timeSinceLastGhostTick = currentRealTime - self.LastGhostTickTime
        end
        if playerSpeed > 0.1 or timeSinceLastGhostTick > 1.5 then
            self.GhostMovementStartTime = nil
        end
    end

    if isInstantTeleport then
        self.FastTravelLastDetected = currentRealTime
    end

    -- 3s debounce so loading screens don't drop the idle before the move settles.
    local inFastTravelCooldown = false
    if self.FastTravelLastDetected and (currentRealTime - self.FastTravelLastDetected < 3.0) then
        inFastTravelCooldown = true
    end

    -- Check B: a high world-time ratio catches waiting, sleeping, and jail.
    local inWaitSleep = false
    pcall(function()
        local timeRatio = Calendar.GetWorldTimeRatio()
        if timeRatio and timeRatio > 20.0 then 
            inWaitSleep = true
        end
    end)

    local inDialog = false
    local inCutscene = false

    -- The player's own persistent wait order is OR'd in so it survives an
    -- interruption ending - otherwise the falling edge below would clear it.
    local shouldBeIdle = inDialog or inCutscene or inFastTravelCooldown or inWaitSleep or _G.MercPersistentIdleFlag

    if not _G.MercIdle and shouldBeIdle then
        _G.MercIdle = true
        
        local reason = "Unknown"
        if inWaitSleep then reason = "Waiting/Sleeping"
        elseif inFastTravelCooldown then reason = "Fast Travel/Teleport" end
        
        System.LogAlways(string.format('[Mercenary] %s detected! Temp idling mercs.', reason))
        
    elseif _G.MercIdle and not shouldBeIdle then
        _G.MercIdle = false
        System.LogAlways('[Mercenary] Interruption ended. Resuming mercs.')
    end
end

-- ==== "Do not drop trouble on him right now" ====
-- Separate from _G.MercIdle on purpose. That flag is about what the SQUAD does and is
-- deliberately narrow - widening it would idle the men every time the player opens a
-- conversation. This is about what the WORLD is allowed to do to the player, which is a
-- different and much more cautious question: a roaming patrol that spawns while he is
-- asleep, mid-cutscene or fighting a quest battle is a fight he never chose and often
-- cannot see coming.
--
-- Every probe is wrapped: a scriptbind that does not exist on some build must read as
-- "not busy" and leave the old behaviour alone, never error. Confidence per probe:
--   IsLaying / GetWorldTimeRatio / IsInCombatDanger  - confirmed, used elsewhere in the mod
--   human:IsInDialog                                 - vanilla uses it (TriggerBase.lua); ours is the first call
--   Game.QueryBattleStatus                           - documented, unproven here, so it is
--                                                      opportunistic and gated on a real number
-- merc_spawnguard prints which probe answers true, so coverage can be checked in play
-- rather than assumed.
mercenaries.SpawnGuardBattleLevel = 0.5    -- QueryBattleStatus (0 quiet .. 1 full combat) at or above this is a fight
mercenaries.SpawnGuardClearSecs   = 6.0    -- stay shut this long after the last busy reading

-- Returns busy, reason. Cheap: a handful of pcalled reads, no scans.
function mercenaries:PlayerBusyForSpawns()
    local reason = nil

    -- Asleep, or lying down about to be.
    pcall(function()
        if player and player.player and player.player:IsLaying() then reason = "sleeping" end
    end)

    -- Waiting, sleeping or jailed: all three run the world clock far above real time.
    -- The same proxy MonitorMainQuestLoop uses - there is no IsWaiting binding.
    if not reason then
        pcall(function()
            local r = Calendar.GetWorldTimeRatio()
            if r and r > 20.0 then reason = "waiting" end
        end)
    end

    -- Mid-conversation: a cutscene-ish scene the player cannot break off from.
    if not reason then
        pcall(function()
            if player and player.human and player.human:IsInDialog() then reason = "in dialogue" end
        end)
    end

    -- In a fight of his own - which is what a scripted/quest battle looks like from here,
    -- there being no Lua-readable "a main quest battle is running" flag (docs/quest-override-battles.md).
    if not reason then
        pcall(function()
            if player and player.soul and player.soul:IsInCombatDanger() then reason = "in combat" end
        end)
    end

    -- The mod's own staged battles, which we DO have flags for.
    if not reason then
        pcall(function()
            if self.RBQ and self.RBQ.active then reason = "the siege of Raborsch" end
        end)
    end

    -- Opportunistic: a global battle meter. Only trusted when it answers with a number.
    if not reason then
        pcall(function()
            local b = Game.QueryBattleStatus()
            if type(b) == "number" and b >= (self.SpawnGuardBattleLevel or 0.5) then
                reason = "a battle in progress"
            end
        end)
    end

    -- Fast travel / a level transition, already tracked by the loop above.
    if not reason and self.FastTravelLastDetected then
        local now = 0
        pcall(function() now = System.GetCurrTime() or 0 end)
        if (now - self.FastTravelLastDetected) < 3.0 then reason = "fast travel" end
    end

    -- Hold the gate shut a little past the last busy reading, so nothing walks out of
    -- the bushes on the frame he wakes up or the fight ends.
    local now = 0
    pcall(function() now = System.GetCurrTime() or 0 end)
    if reason then
        self._spawnBusyUntil  = now + (self.SpawnGuardClearSecs or 6.0)
        self._spawnBusyReason = reason
        return true, reason
    end
    if self._spawnBusyUntil and now < self._spawnBusyUntil then
        return true, (self._spawnBusyReason or "busy") .. " (settling)"
    end
    return false, nil
end

function mercenaries:SpawnGuardReport()
    local busy, why = self:PlayerBusyForSpawns()
    System.LogAlways("[SpawnGuard] busy=" .. tostring(busy) .. " reason=" .. tostring(why))
    local function probe(name, fn)
        local v = "unavailable"
        pcall(function() v = tostring(fn()) end)
        System.LogAlways("[SpawnGuard]   " .. name .. " = " .. v)
    end
    probe("player:IsLaying", function() return player.player:IsLaying() end)
    probe("Calendar.GetWorldTimeRatio", function() return Calendar.GetWorldTimeRatio() end)
    probe("human:IsInDialog", function() return player.human:IsInDialog() end)
    probe("soul:IsInCombatDanger", function() return player.soul:IsInCombatDanger() end)
    probe("Game.QueryBattleStatus", function() return Game.QueryBattleStatus() end)
    probe("RBQ.active", function() return mercenaries.RBQ and mercenaries.RBQ.active end)
end

mercenaries:DevCommand("merc_spawnguard", "mercenaries:SpawnGuardReport()",
                   "Print whether patrols are held back right now, and what each probe answers")
