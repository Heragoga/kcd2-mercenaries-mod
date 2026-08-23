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
-- are separate knobs, and ONLY THE VIEW DISTANCE IS TOUCHED. That is the configuration that
-- was measured good in game: everybody renders, detail is the engine's own choice.
--
-- DO NOT drive SetLodRatio from a crowd count. It was tried - a ratio interpolated 100..130
-- from (mercs + nearby hostiles), re-applied to every merc on the 5s sweep - and it brought
-- back the popping in and out that the view-distance pin had fixed. Two reasons, and both
-- would apply to any variant of the idea:
--   * the crowd count moves constantly, so the ratio moves with it, and every change makes
--     every merc re-evaluate which mesh LOD to draw;
--   * it was re-applied on a timer even when unchanged, so the churn had a floor.
-- KCD2 assembles characters from clothing skins and swaps in a merged "uberlod" from a
-- configurable LOD number, so nudging LOD selection on a character is nothing like doing it
-- on a wall segment - which is where these calls were copied from. 255 made mercs low-detail
-- puppets at arm's length; leaving it alone looks right.
--
-- If mesh detail ever genuinely needs cutting for performance, do it with a FIXED value set
-- once (merc_render_lod), never a value that tracks a live count.
--
-- Separate pcalls on purpose: these are entity-class methods and a missing one on the NPC
-- class must not skip the others. No RenderShadow here - fifty extra shadow casters is a real
-- cost and shadows are not the reported symptom.
mercenaries.RenderPin      = true
mercenaries.RenderLodRatio = nil     -- nil = leave mesh LOD to the engine (the good state)

function mercenaries:EnsureMercIsAlwaysRendered(ent)
    if not (ent and self.RenderPin) then return end
    pcall(function() ent:SetViewDistUnlimited() end)
    pcall(function() ent:SetViewDistRatio(255) end)
    -- Only ever a fixed, manually-set value, and only when one has been asked for.
    if self.RenderLodRatio then
        pcall(function() ent:SetLodRatio(self.RenderLodRatio) end)
    end
end

-- merc_render_lod <n>  - pin mesh detail to a fixed ratio (higher drops detail sooner).
-- merc_render_lod      - or 0/off: hand mesh LOD back to the engine. This is the default and
--                        the state that looked right in game.
function mercenaries:RenderLodSet(v)
    local n = tonumber(tostring(v or ''):match('%d+'))
    if n == 0 then n = nil end
    self.RenderLodRatio = n
    System.LogAlways('[Mercenary Jeff] merc mesh LOD = ' ..
        (n and tostring(n) or 'engine default') ..
        ' (fixed; never scaled from a live count - that caused pop-in). ' ..
        'Reference: 100 is default, 255 was puppet-grade.')
    -- A cleared ratio cannot be un-applied on live entities; it takes effect on respawn.
    if n then self:RefreshRenderPins() end
end

System.AddCCommand("merc_render_lod", "mercenaries:RenderLodSet('%line')",
                   "Fixed merc mesh detail, or 0 for engine default: merc_render_lod 130")

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
    for _, ent in pairs(self.ActiveMercs or {}) do
        if self.RenderPin then self:EnsureMercIsAlwaysRendered(ent) end
        self:ApplyKeepUpBuff(ent)
    end
end

-- Turning the pin off now actually un-pins the live squad, so this is a usable A/B:
-- pinned mercs are never distance-culled and never LOD-reduced, which is the mod's
-- largest standing per-merc engine cost. 100 is the entity default ratio (never pass 0,
-- that is the MINIMUM - see the note at the top of this file). docs/performance.md.
function mercenaries:RenderPinSet(v)
    self.RenderPin = (tostring(v or ''):match('1') ~= nil)
    if self.RenderPin then
        self:RefreshRenderPins()
        System.LogAlways('[Mercenary Jeff] render pin ON')
    else
        local n = 0
        for _, ent in pairs(self.ActiveMercs or {}) do
            if pcall(function() ent:SetViewDistRatio(100) end) then n = n + 1 end
        end
        System.LogAlways('[Mercenary Jeff] render pin OFF - restored default view distance on '
                         .. n .. ' merc(s); they can be distance-culled again')
    end
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
            -- Param 5 is a skip-entity ID, not an entity table. Passing the table made
            -- the engine log a parameter-type warning per ray AND ignore the skip, so the
            -- ray could hit the very entity it was cast from. Vanilla passes self.id.
            local hits = Physics.RayWorldIntersection(eyePos, checkVec, 2,
                ent_terrain + ent_static, (pe and pe.id) or nil, nil, hitTable)

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
        ent_terrain + ent_static, nil, nil, groundHitTable)

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
-- maxTries bounds the WORST case. Each candidate costs up to 9 physics raycasts via
-- CampValidateSpot, and the full 3.0m/0.5m spiral is 132 candidates - 1,188 rays for a
-- single call, synchronous, and 19 call sites used the bare defaults. The burst callers
-- are the problem: a camp raid places up to 14 units and an ambush scene 12, all in one
-- frame. Keeping the fine 0.5m step preserves precision near the origin, where almost
-- every call succeeds; the budget only truncates the hopeless case (dense forest), which
-- then falls through to the plain ground snap below exactly as an exhausted spiral did.
-- See docs/performance.md.
function mercenaries:FindValidGround(pos, refZ, maxRadius, step, maxTries)
    if not pos then return pos end
    refZ = refZ or pos.z
    maxRadius = maxRadius or 3.0
    step = step or 0.5
    maxTries = maxTries or 40
    local foot = self.CampMercFootprint or 0.6
    local tries = 0

    local function try(x, y)
        if tries >= maxTries then return nil end
        tries = tries + 1
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
    while r <= maxRadius + 1e-6 and tries < maxTries do
        local n = math.max(8, math.floor((2 * math.pi * r) / step))
        for k = 0, n - 1 do
            local a = (k / n) * 2 * math.pi
            hit = try(pos.x + math.cos(a) * r, pos.y + math.sin(a) * r)
            if hit then return hit end
            if tries >= maxTries then break end
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

    -- pcall(method, obj, arg) rather than pcall(function() ... end): the closure form
    -- allocates on every call, and this is the single most-called predicate in the mod -
    -- once per nearby NPC per combat scan, so its garbage scales with crowd density.
    local ok, hp = pcall(ent.soul.GetState, ent.soul, 'health')
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
        if mercenaries.PerfUnregister then mercenaries:PerfUnregister(horseName) end
        System.RemoveEntity(horseEnt.id)
        System.LogAlways('[MercHorse] Deferred despawn complete: ' .. horseName)
    else
        System.LogAlways('[MercHorse] Deferred despawn: already gone: ' .. horseName)
    end
end



-- ==== paying the player ====
-- player.inventory:AddMoney DOES NOT EXIST. Every call to it in this mod sat inside a pcall,
-- threw, and was swallowed - the bandit-camp contract, the logistics coffer and Aleksej's beats
-- all reported success and paid nothing. GetMoney/RemoveMoney are real (the hire and heal costs
-- have always used them), so money goes IN as the vanilla money item - item__system.xml, one
-- groschen a unit, divisible, which is the same class the camp chests are stocked with - and the
-- transfer is verified by reading the purse back rather than assumed.
mercenaries.MoneyItemClass = "5ef63059-322e-4e1b-abe8-926e100c770e"

function mercenaries:GiveMoney(amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true, 0 end
    if not (player and player.inventory) then return false, 0 end

    local before = 0
    pcall(function() before = player.inventory:GetMoney() or 0 end)
    pcall(function() player.inventory:CreateItem(self.MoneyItemClass, 1, amount) end)
    local after = before
    pcall(function() after = player.inventory:GetMoney() or 0 end)

    if after > before then return true, after - before end
    System.LogAlways("[Mercenaries] GiveMoney: purse did not move for " .. tostring(amount) ..
                     " groschen - check MoneyItemClass")
    return false, 0
end
