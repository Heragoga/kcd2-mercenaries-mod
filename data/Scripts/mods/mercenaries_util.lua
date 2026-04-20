-- =======================================================================
-- PERFORMANCE: Cache management
-- RebuildMercCache: called once on game load (the only full NPC scan).
-- PruneMercCache:   called once per second in MonitorLoop to remove dead refs.
-- All hot-path functions iterate ActiveMercs instead of GetEntitiesByClass.
-- =======================================================================
function mercenaries:RebuildMercCache()
    self.ActiveMercs = {}
     if _G.MercenariesDismissed then
        System.LogAlways('[Mercenary Jeff] Mercs dismissed, skipping cache rebuild.')
        return
    end
    local ents = System.GetEntitiesByClass('NPC')
    if ents then
        for _, e in pairs(ents) do
            local name = e and e:GetName() or ""
            if string.find(name, 'SpawnedFriend') or string.find(name, 'MercenaryCustomCompanion') then
                -- Only cache entities that are actually alive
                if self:IsAliveAndWell(e, true) then
                    self.ActiveMercs[name] = e
                    -- Restore the interaction button that was injected at hire time.
                    -- Without this, GetActions is never overridden after a save/load.
                    self:InjectInteraction(e)
                end
            end
        end
    end
    System.LogAlways('[Mercenary Jeff] Merc cache rebuilt. Active mercs: ' .. tostring(self:_TableCount(self.ActiveMercs)))
end
function mercenaries.RebuildMercCacheDelayed()
    mercenaries:RebuildMercCache()
    mercenaries:Recount()
end

function mercenaries:PruneMercCache()
    for name, ent in pairs(self.ActiveMercs) do
        if not self:IsAliveAndWell(ent, true) then
            self.ActiveMercs[name] = nil
        end
    end
end

-- Internal helper — counts entries in any table
function mercenaries:_TableCount(t)
    local c = 0
    for _ in pairs(t) do c = c + 1 end
    return c
end

-- Recount using the already-pruned cache — no world scan needed
function mercenaries:Recount()
    self:PruneMercCache()
    local c = 0
    for _ in pairs(self.ActiveMercs) do c = c + 1 end
    _G.MercCount = c
end

-- Helper function to identify a mercenary's tier based on their GUID
function mercenaries:GetMercTier(soulGuidStr)
    if not soulGuidStr then return "weak" end
    
    for tierName, guidList in pairs(self.Souls) do
        for _, guid in ipairs(guidList) do
            if string.find(soulGuidStr, guid) then
                return tierName
            end
        end
    end
    return "weak" -- Failsafe default for confirmed mercs
end

-- Very important helper function, used in merc spawning and emergency teleport
function mercenaries:GetSafeSpawnPosition(pe, distance)
    if not pe then return nil, nil end
    distance = distance or 3

    local playerPos = pe:GetWorldPos()
    local playerDir = pe:GetDirectionVector()
    local playerRot = pe:GetAngles()

    -- Guard: if direction is zero (cutscene, transition), bail out
    if not playerDir or (playerDir.x == 0 and playerDir.y == 0) then
        return nil, nil
    end

    local eyePos = { x = playerPos.x, y = playerPos.y, z = playerPos.z + 1.6 }
    local rayDistance = distance + 2
    local hitTable = {}
    local numRays = 10
    local arcAngle = 100
    local startAngle = -arcAngle / 2
    local angleStep = arcAngle / (numRays - 1)
    local bestDir = nil
    local bestDist = -1
    local backDir = { x = -playerDir.x, y = -playerDir.y, z = -playerDir.z }

    for i = 0, numRays - 1 do
        local angleOffset = startAngle + (i * angleStep)
        local rotatedDir = VectorUtils.Rotate2D(backDir, angleOffset)
        if rotatedDir then
            local checkVec = VectorUtils.Scale(rotatedDir, rayDistance)
            -- Use ent_terrain + ent_static: ignore dynamic entities (NPCs, horses, etc.)
            local hits = Physics.RayWorldIntersection(eyePos, checkVec, 2,
                ent_terrain + ent_static, pe.id, nil, hitTable)

            local clearDist = rayDistance
            if hits > 0 and hitTable[1] and hitTable[1].dist then
                clearDist = hitTable[1].dist
            end

            -- Prefer directions more directly behind the player
            local anglePenalty = (math.abs(angleOffset) / arcAngle) * 0.5
            local score = clearDist * (1.0 - anglePenalty)

            if score > bestDist then
                bestDist = score
                bestDir = rotatedDir
            end
        end
    end

    -- Guard: no valid direction found
    if not bestDir then return nil, nil end

    -- Calculate spawn distance: pull back from geometry, don't exceed requested distance
    local spawnDist
    if bestDist < rayDistance then
        -- Clamp: stay 0.5m clear of the nearest hit, but don't exceed requested distance
        spawnDist = math.max(math.min(bestDist - 0.5, distance), 0.8)
    else
        spawnDist = distance
    end

    local spawnPos = {
        x = playerPos.x + bestDir.x * spawnDist,
        y = playerPos.y + bestDir.y * spawnDist,
        z = playerPos.z,
    }

    -- Ground snap: start higher to avoid interior ceiling hits, use a separate hitTable
    local groundHitTable = {}
    local groundCheckStart = { x = spawnPos.x, y = spawnPos.y, z = spawnPos.z + 5.0 }
    local groundCheckDir  = { x = 0, y = 0, z = -100 }
    local groundHits = Physics.RayWorldIntersection(groundCheckStart, groundCheckDir, 2,
        ent_terrain + ent_static, 0, nil, groundHitTable)

    if groundHits > 0 and groundHitTable[1] and groundHitTable[1].pos then
        spawnPos.z = groundHitTable[1].pos.z
    else
        spawnPos.z = playerPos.z
    end

    return spawnPos, playerRot
end

-- =======================================================================
-- HELPER: Bulletproof check to see if an entity is alive and well
-- =======================================================================
function mercenaries:IsAliveAndWell(ent, allowUnconscious)
    if not ent or not ent.actor or not ent.soul then return false end
    
    -- Engine level death checks
    if ent.actor.IsDead and ent.actor:IsDead() then return false end
    if not allowUnconscious and ent.actor:IsUnconscious() then return false end
    
    -- Skald level health check
    local ok, hp = pcall(function() return ent.soul:GetState('health') end)
    if not ok or hp == nil or hp <= 0 then return false end
    
    return true
end

-- =======================================================================
-- HELPER: Identifies if an entity is a mercenary, and returns their type
-- =======================================================================
function mercenaries:GetMercType(ent)
    if not ent then return nil end
    local name = ent:GetName() or ''
    
    if string.find(name, 'MercenaryCustomCompanion') then return "hero" end
    if string.find(name, 'SpawnedFriend') then return "regular" end
    
    return nil -- Not a mercenary
end

-- Global speaking lock release — called via Script.SetTimerForFunction.
-- Safe to call even if the lock has already been reassigned (e.g. owner died).
function mercenaries.ReleaseSpeakingLock()
    _G.MercSpeakingLock = false
    _G.MercSpeakingOwner = nil
    -- System.LogAlways('[Mercenary] Speaking lock released.')
end