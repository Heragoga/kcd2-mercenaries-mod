-- Merc cache: RebuildMercCache does the only full NPC scan (on load);
-- PruneMercCache drops dead refs each second. Hot paths iterate ActiveMercs.

-- Pin a merc's RENDERER view distance, so he is never culled by distance.
--
-- This is separate from the AI LOD tiers (mercenaries_lodboost.lua): that decides how much
-- an NPC is SIMULATED, this decides whether he is DRAWN. Same three calls that already fixed
-- wall segments, towers and camp props dropping out at distance (mercenaries_wall.lua).
--
-- It was previously a no-op, on the strength of "forcing RenderAlways caused more trouble
-- than it solved". That verdict came from a broken test - the original body was, verbatim:
--
--     ent:SetViewDistRatio(254)
--     ent:SetViewDistRatio(0)
--
-- i.e. it set the maximum and then immediately the MINIMUM on the next line, so the function
-- named "always rendered" was culling mercs as hard as the engine allows. docs/npc-lod.md
-- records the gap this leaves: a clean retry with no follow-up zeroing was never attempted.
--
-- Separate pcalls on purpose: these are entity-class methods and a missing one on the NPC
-- class must not skip the others. No RenderShadow here - fifty extra shadow casters is a real
-- cost and shadows are not the reported symptom.
--
-- View distance decides WHETHER a merc is drawn; the LOD ratio decides WHICH MESH LOD. They
-- are separate knobs and only the first was ever needed for "they do not render at all".
--
-- The LOD ratio SCALES WITH THE CROWD, because the whole reason to give up detail is that
-- there are a lot of NPCs to draw. With a handful of mercs there is nothing to save and they
-- should look their best; with fifty, a little fidelity buys headroom.
--
-- Calibration, from what has actually been seen in game: 255 (copied from the wall-segment
-- code) made mercs low-detail puppets at arm's length - KCD2 assembles characters from
-- clothing skins and swaps in a merged "uberlod" from a configurable LOD number, so
-- distorting LOD selection on a character is nothing like doing it on a wall. Unset looked
-- right but is more than a big squad needs. 140 was "just about bearable", so that is the
-- WORST this is now allowed to get, and only at full crowd; small squads sit at the engine
-- default. The scale runs "higher = drops detail sooner".
mercenaries.RenderPin       = true
mercenaries.RenderLodBest   = 100    -- engine default: small squads, full detail
mercenaries.RenderLodWorst  = 130    -- big crowd; below the 140 that was merely "bearable"
mercenaries.RenderLodCrowdLo = 10    -- at or under this many mod NPCs, best detail
mercenaries.RenderLodCrowdHi = 45    -- at or over this, worst
mercenaries.RenderLodRatio  = nil    -- computed; nil = leave the engine alone

function mercenaries:UpdateRenderLod()
    local crowd = (_G.MercCount or 0) + #(self.CachedEnemies or {})
    local lo, hi = self.RenderLodCrowdLo, self.RenderLodCrowdHi
    local t = 0.0
    if hi > lo then t = (crowd - lo) / (hi - lo) end
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    local r = math.floor(self.RenderLodBest + (self.RenderLodWorst - self.RenderLodBest) * t + 0.5)
    self.RenderLodRatio = r
    return r
end

function mercenaries:EnsureMercIsAlwaysRendered(ent)
    if not (ent and self.RenderPin) then return end
    pcall(function() ent:SetViewDistUnlimited() end)
    pcall(function() ent:SetViewDistRatio(255) end)
    if self.RenderLodRatio then
        pcall(function() ent:SetLodRatio(self.RenderLodRatio) end)
    end
end

-- Set the WORST the scaling is allowed to get (the value used at full crowd). Small squads
-- keep RenderLodBest regardless, so this is the one number worth tuning by eye.
function mercenaries:RenderLodSet(v)
    local n = tonumber(tostring(v or ''):match('%d+'))
    if n then self.RenderLodWorst = n end
    local now = self:UpdateRenderLod()
    System.LogAlways('[Mercenary Jeff] merc LOD: best=' .. tostring(self.RenderLodBest) ..
                     ' worst=' .. tostring(self.RenderLodWorst) ..
                     ' currently=' .. tostring(now) ..
                     ' (higher drops detail sooner; 255 was puppet-grade, 100 is engine default)')
    self:RefreshRenderPins()
end

System.AddCCommand("merc_render_lod", "mercenaries:RenderLodSet('%line')",
                   "Worst-case merc mesh detail at full crowd, e.g. merc_render_lod 130")

-- Movement speed + stamina, so the squad can stay with a sprinting player. Dash is the
-- highest RelativeSpeedLimit the engine has, so raising actual movement speed is the only
-- lever left. Applied once per merc and tracked here: AddBuff would otherwise stack a fresh
-- instance every refresh.
mercenaries.KeepUpBuff = "e5a10011-2c4b-4e6a-9f01-000000000011"
mercenaries.KeepUpBuffOn = true
mercenaries._keepUpDone = {}

function mercenaries:ApplyKeepUpBuff(ent)
    if not (ent and ent.soul and self.KeepUpBuffOn) then return end
    local k = tostring((ent.this and ent.this.id) or ent.id)
    if self._keepUpDone[k] then return end
    local ok = pcall(function() ent.soul:AddBuff(self.KeepUpBuff) end)
    if ok then self._keepUpDone[k] = true end
end

-- Re-applied on a slow tick as well as at spawn: equipping clothing, a save/load, or anything
-- that rebuilds the entity can drop these, and the whole symptom is something undoing render
-- state behind us. The keep-up buff rides along on the same sweep so newly hired mercs and
-- reloaded saves pick it up without another loop.
function mercenaries:RefreshRenderPins()
    if self.RenderPin then self:UpdateRenderLod() end
    for _, ent in pairs(self.ActiveMercs or {}) do
        if self.RenderPin then self:EnsureMercIsAlwaysRendered(ent) end
        self:ApplyKeepUpBuff(ent)
    end
end

function mercenaries:RenderPinSet(v)
    self.RenderPin = (tostring(v or ''):match('1') ~= nil)
    System.LogAlways('[Mercenary Jeff] render pin ' .. (self.RenderPin and 'ON' or 'OFF (restart to fully clear)'))
    if self.RenderPin then self:RefreshRenderPins() end
end

System.AddCCommand("merc_render_pin", "mercenaries:RenderPinSet('%line')",
                   "Pin merc renderer view distance so they are never distance-culled: merc_render_pin 1 | 0")
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
                    mercenaries:EnsureMercIsAlwaysRendered(e)
                    -- Restore the interaction button that was injected at hire time.
                    -- Without this, GetActions is never overridden after a save/load.
                    self:InjectInteraction(e)
                    self:EquipMercenary(e, _G.MercCurrentOutfit or 1)
                    self:EquipMercenaryWeapon(e, _G.MercCurrentWeapon or 1)
                end
            end
        end
    end
    -- Always recount after rebuild so MercCount reflects reality
    local c = 0
    for _ in pairs(self.ActiveMercs) do c = c + 1 end
    _G.MercCount = c
    System.LogAlways('[Mercenary Jeff] Merc cache rebuilt. Active mercs: ' .. tostring(_G.MercCount))
end
function mercenaries.RebuildMercCacheDelayed()
    mercenaries:RebuildMercCache()
    mercenaries:Recount()
end

function mercenaries:PruneMercCache()
    for name, ent in pairs(self.ActiveMercs) do
        if not self:IsAliveAndWell(ent, true) then
            self.ActiveMercs[name] = nil
            local wuid = ent.this and ent.this.id or ent.id
            self.MercTargetOf[tostring(wuid)] = nil
            Script.SetTimerForFunction(10000, "mercenaries.DespawnMerc", ent.id)
        elseif not self:IsCombatViable(ent) then
            -- Knocked out: keeps his roster slot (a false answer above schedules a
            -- despawn), but he is not fighting and must not hold a swarm-cap slot.
            local wuid = ent.this and ent.this.id or ent.id
            self.MercTargetOf[tostring(wuid)] = nil
        end
    end
end

-- Combat claims are released by the combat modules' OnFail, which does not run
-- when an NPC simply dies or is streamed out. The load tables are rebuilt from
-- these every pass, so a ghost claim permanently eats a swarm-cap slot and the
-- caps quietly stop binding - one of the ways a fighter ends up with no target
-- and stands there. Swept from LowPriorityMonitorLoop.
function mercenaries:PruneCombatClaims()
    for k, w in pairs(self.EnemyClaimWuid or {}) do
        local live = false
        pcall(function()
            local e = XGenAIModule.GetEntityByWUID(w)
            live = (e ~= nil) and self:IsAliveAndWell(e, true)
        end)
        if not live then
            self.EnemyTargetOf[k] = nil
            self.EnemyClaimWuid[k] = nil
            if self.ForcedTargetOf then self.ForcedTargetOf[k] = nil end
        end
    end
end

-- Dot syntax on purpose: invoked by name from Script.SetTimerForFunction,
-- which passes the entity id as the FIRST argument. With colon syntax the
-- id would land in `self` and entID would always be nil (corpses would
-- never despawn).
function mercenaries.DespawnMerc(entID)
    if entID then
        System.RemoveEntity(entID)
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

-- Parses tier straight from an entity's spawn name (every merc/archer/
-- renegade is spawned as "..._<tier>_..." - see Hire/HireArcher/
-- SpawnRenegade), instead of matching against a soul GUID list. Shared by
-- the archer equipment code and the camp housing-tier assignment.
function mercenaries:GetTierFromName(name)
    name = name or ''
    if string.find(name, '_medium_') then return "medium" end
    if string.find(name, '_strong_') then return "strong" end
    return "weak"
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

-- Snap a position onto valid, obstacle-free ground: CampValidateSpot rejects
-- tree/rock/roof tops, and if blocked we spiral out in `step` rings up to
-- `maxRadius` for a clear tile. Pass the squad's z as `refZ` so "valid" means
-- near their level, not a ledge above. Falls back to a plain snap.
function mercenaries:FindValidGround(pos, refZ, maxRadius, step)
    if not pos then return pos end
    refZ = refZ or pos.z
    maxRadius = maxRadius or 3.0
    step = step or 0.5
    local foot = self.CampMercFootprint or 0.6

    local function try(x, y)
        local okv, v, gz = pcall(function()
            local valid, groundZ = self:CampValidateSpot({ x = x, y = y, z = refZ }, refZ, foot)
            return valid, groundZ
        end)
        if okv and v then return { x = x, y = y, z = gz } end
        return nil
    end

    local hit = try(pos.x, pos.y)
    if hit then return hit end

    local r = step
    while r <= maxRadius + 1e-6 do
        local n = math.max(8, math.floor((2 * math.pi * r) / step))
        for k = 0, n - 1 do
            local a = (k / n) * 2 * math.pi
            hit = try(pos.x + math.cos(a) * r, pos.y + math.sin(a) * r)
            if hit then return hit end
        end
        r = r + step
    end

    -- Nothing clear nearby: best-effort plain snap.
    local ok, snapped = pcall(function() return self:CampSnapToGround({ x = pos.x, y = pos.y, z = refZ }) end)
    if ok and snapped then return snapped end
    return pos
end

-- Check that an entity is alive and well (engine death/unconscious + health).
function mercenaries:IsAliveAndWell(ent, allowUnconscious)
    if not ent or not ent.actor or not ent.soul then return false end

    if ent.actor.IsDead and ent.actor:IsDead() then return false end
    if not allowUnconscious and ent.actor:IsUnconscious() then return false end

    local ok, hp = pcall(function() return ent.soul:GetState('health') end)
    if not ok or hp == nil or hp <= 0 then return false end

    return true
end

-- A downed man is not an opponent. Every COMBAT path asks this; roster and
-- bookkeeping paths keep IsAliveAndWell(ent, true), because "is he still on the
-- books" is a different question - PruneMercCache schedules a despawn on a false
-- answer, so a knocked-out merc must still read as alive there.
-- See docs/combat-target-selection.md.
function mercenaries:IsCombatViable(ent)
    return self:IsAliveAndWell(ent, false)
end

-- Identify whether an entity is a mercenary, returning its type or nil.
function mercenaries:GetMercType(ent)
    if not ent then return nil end
    local name = ent:GetName() or ''

    if string.find(name, 'MercenaryCustomCompanion') then return "hero" end
    if string.find(name, 'SpawnedFriend') then
        if string.find(name, '_archer_') then return "archer" end
        return "regular"
    end

    return nil -- Not a mercenary
end

-- Global speaking lock release — called via Script.SetTimerForFunction.
-- Safe to call even if the lock has already been reassigned (e.g. owner died).
function mercenaries.ReleaseSpeakingLock()
    _G.MercSpeakingLock = false
    _G.MercSpeakingOwner = nil
    -- System.LogAlways('[Mercenary] Speaking lock released.')
end


function mercenaries.DespawnHorseByName(horseName)
    if not horseName then return end
    local horseEnt = System.GetEntityByName(horseName)
    if horseEnt then
        System.RemoveEntity(horseEnt.id)
        System.LogAlways('[MercHorse] Deferred despawn complete: ' .. horseName)
    else
        System.LogAlways('[MercHorse] Deferred despawn: already gone: ' .. horseName)
    end
end

