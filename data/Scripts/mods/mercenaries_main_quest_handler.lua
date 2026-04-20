function mercenaries:MonitorMainQuestLoop()
    -- 1. Check intended persistent state FIRST
    if _G.MercPersistentIdleFlag then
        return
    end

    -- 2. Track Real Time & Calculate Delta
    -- PERFORMANCE: System.GetCurrTime() is already cached by the engine each frame,
    -- avoiding the overhead of os.clock() going through the Lua/C bridge.
    local currentRealTime = System.GetCurrTime()
    local realTimeDelta = 1.0 
    
    if self.LastRealTime then
        realTimeDelta = currentRealTime - self.LastRealTime
    end
    self.LastRealTime = currentRealTime

    -- 3. Calculate Physical Distance Moved (For Teleport/Fast Travel)
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
    
    -- 4. Get the engine's official speed for Henry
-- 4. Get the engine's official speed for Henry
    local playerSpeed = 10.0
    pcall(function() 
        playerSpeed = player:GetSpeed() 
    end)

    -- 4b. Check if player is mounted on a horse.
    -- GetHorse() returns an invalid WUID when not mounted, so we check if
    -- the result is non-nil and non-empty as a proxy for "is on horse".
    local isOnHorse = false
    pcall(function()
        local horseWuid = player.human:GetHorse()
        if horseWuid and tostring(horseWuid) ~= "" and tostring(horseWuid) ~= "0" then
            isOnHorse = true
        end
    end)

    -- ========================================================================
    -- CHECK A: GHOST MOVEMENT & TELEPORT DETECTION (SMART GRACE PERIOD)
    -- ========================================================================

    -- Skip ghost movement detection entirely while mounted. Horse riding causes
    -- large position deltas with near-zero Henry speed, which is a false positive.
    -- Instant teleport threshold (>25m) is still checked since fast travel can
    -- occur from horseback too.
    local isGhostMovement = (not isOnHorse) and (distanceMoved > 0.5 and playerSpeed < 0.1 and realTimeDelta < 0.4)
    local isInstantTeleport = (distanceMoved > 25.0)

    if isGhostMovement then
        self.LastGhostTickTime = currentRealTime
        
        -- Start the grace period timer if it isn't already running
        if not self.GhostMovementStartTime then
            self.GhostMovementStartTime = currentRealTime
        end
        
        -- GRACE PERIOD: Has it been 0.75 real-world seconds since the weirdness started?
        if (currentRealTime - self.GhostMovementStartTime) > 0.75 then
            self.FastTravelLastDetected = currentRealTime
        end
    else
        -- SMART CANCEL: Only reset the grace period if Henry is actually walking/running normally,
        -- OR if the engine hasn't seen any ghost movement in the last 1.5 seconds.
        local timeSinceLastGhostTick = 0
        if self.LastGhostTickTime then
            timeSinceLastGhostTick = currentRealTime - self.LastGhostTickTime
        end
        
        if playerSpeed > 0.1 or timeSinceLastGhostTick > 1.5 then
            self.GhostMovementStartTime = nil
        end
    end

    -- Instant teleports (>25m in one tick) bypass the grace period entirely
    if isInstantTeleport then
        self.FastTravelLastDetected = currentRealTime
    end

    -- Apply the 3-second Debounce Cooldown shield to protect against loading screens
    local inFastTravelCooldown = false
    if self.FastTravelLastDetected and (currentRealTime - self.FastTravelLastDetected < 3.0) then
        inFastTravelCooldown = true
    end

    -- ========================================================================
    -- CHECK B: TIME RATIO (Catches Waiting, Sleeping, and Jail)
    -- ========================================================================
    local inWaitSleep = false
    pcall(function()
        local timeRatio = Calendar.GetWorldTimeRatio()
        if timeRatio and timeRatio > 20.0 then 
            inWaitSleep = true
        end
    end)

    -- Initialize other states
    local inDialog = false
    local inCutscene = false

    -- Combine ALL checks into the Master Idle Switch
    local shouldBeIdle = inDialog or inCutscene or inFastTravelCooldown or inWaitSleep

    -- 8. Handle State Transitions
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