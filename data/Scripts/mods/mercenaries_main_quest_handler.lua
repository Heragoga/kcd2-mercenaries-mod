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