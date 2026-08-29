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
-- Applies LIVE in both directions, which is what makes it usable as an A/B. Clearing it used
-- to be a no-op until respawn ("cannot be un-applied"), which is wrong: 100 IS the entity
-- default ratio, so writing 100 restores engine behaviour on a live NPC. Never 0 - that is the
-- MINIMUM and is what sabotaged the original render experiment (see the note at the top).
function mercenaries:RenderLodSet(v)
    local raw = tostring(v or ''):gsub('%s+', '')
    if raw == '' then
        System.LogAlways('[Mercenary Jeff] merc_render_lod <n> - mesh detail, higher drops detail sooner. ' ..
            '100 = engine default, 130 mild, 180 aggressive, 255 puppet-grade. 0/off = hand back to the engine. ' ..
            '(now: ' .. (self.RenderLodRatio and tostring(self.RenderLodRatio) or 'engine default') .. ')')
        return
    end
    local n = tonumber(raw:match('%d+'))
    if n == 0 then n = nil end
    self.RenderLodRatio = n
    local applied = (n or 100)
    local ok = 0
    for _, ent in pairs(self.ActiveMercs or {}) do
        if pcall(function() ent:SetLodRatio(applied) end) then ok = ok + 1 end
    end
    System.LogAlways('[Mercenary Jeff] merc mesh LOD = ' ..
        (n and tostring(n) or 'engine default (100)') .. ' on ' .. ok .. ' merc(s). ' ..
        'Higher drops detail sooner; watch the frame buckets, not the fps counter.')
end

-- Registered at PLAYER tier in mercenaries_commands.lua (no merc_dev needed).

-- Movement speed + stamina, so the squad can stay with a sprinting player. Dash is the
-- highest RelativeSpeedLimit the engine has, so raising actual movement speed is the only
-- lever left. Applied once per entity and tracked here: AddBuff would otherwise stack a
-- fresh instance every refresh. Generic on purpose: RefreshRenderPins applies KeepUpBuff to
-- every merc's own soul, and follow.xml's horse lifecycle applies HorseKeepUpBuff (a
-- separate, stronger buff - 1.3x on the rider was not enough once mounted) to a mounted
-- merc's HORSE soul instead - riding, the merc's own rms is irrelevant, only the horse's
-- speed carries him, and vanilla's own horse gear buffs (item_horse_shoe, item_bridle) use
-- these same rms/mst codes, confirming they apply to horse souls exactly like human ones.
mercenaries.KeepUpBuff = "e5a10011-2c4b-4e6a-9f01-000000000011"
mercenaries.HorseKeepUpBuff = "e5a10013-2c4b-4e6a-9f01-000000000013"
mercenaries.KeepUpBuffOn = true
mercenaries._keepUpDone = {}

function mercenaries:ApplyKeepUpBuff(ent, buffId)
    if not (ent and ent.soul and self.KeepUpBuffOn) then return end
    local k = tostring((ent.this and ent.this.id) or ent.id)
    if self._keepUpDone[k] then return end
    local ok = pcall(function() ent.soul:AddBuff(buffId or self.KeepUpBuff) end)
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

-- Registered at PLAYER tier in mercenaries_commands.lua (no merc_dev needed).
-- Runtime NPCs whose RECORDS live in plain Lua and therefore die with every load, while the
-- ENTITIES are serialised into the save and come back without them. Nothing else ever removes
-- one of these: DespawnMerc fires only for a roster member who dies THIS session, the patrol
-- sweep is a 600m box, and the quartermaster sweep a 200m one. Measured across one playline:
-- 10 -> 41 -> 50 SpawnedFriend entities baked into consecutive saves of a squad that never
-- exceeded 8 - plus up to 27 patrolmen - every one of them respawned on every load as a full,
-- unmanaged NPC. That is the population the whole 2026-08 lag hunt could not see, because
-- neither MercCount nor ActiveMercs counts them. Swept once per load, from the full-class scan
-- this function already pays for. Their owners respawn what is genuinely wanted right after:
-- camp restore brings back the quartermaster and tower archers at +4s, patrols re-roll fresh.
mercenaries.LoadSweepPrefixes = {
    "SpawnedPatrolman_", "SpawnedPatrol_", "SpawnedTower_archer_",
    "MercQuartermaster_", "SpawnedEnemy_", "SpawnedRenegade_", "SpawnedFoe_",
}

function mercenaries:IsLoadSweepName(name)
    if not name or name == "" then return false end
    for _, p in ipairs(self.LoadSweepPrefixes) do
        if string.find(name, p, 1, true) then return true end
    end
    return false
end

function mercenaries:RebuildMercCache()
    self.ActiveMercs = {}
    -- Dismissed no longer skips the scan: the scan is also the load sweep, and a dismissed
    -- company is exactly the case with the most stale entities to remove - SetState pays the
    -- men off but the engine has already saved them, so they came back with this load.
    local dismissed = _G.MercenariesDismissed
    if dismissed then
        System.LogAlways('[Mercenary Jeff] Mercs dismissed - rebuilding nothing, sweeping instead.')
    end
    local stale = {}
    local ents = System.GetEntitiesByClass('NPC')
    if ents then
        for _, e in pairs(ents) do
            local name = e and e:GetName() or ""
            if string.find(name, 'SpawnedFriend') or string.find(name, 'MercenaryCustomCompanion') then
                -- Only cache entities that are actually alive
                if not dismissed and self:IsAliveAndWell(e, true) then
                    self.ActiveMercs[name] = e
                    mercenaries:EnsureMercIsAlwaysRendered(e)
                    -- Restore the interaction button that was injected at hire time.
                    -- Without this, GetActions is never overridden after a save/load.
                    self:InjectInteraction(e)
                    self:EquipMercenary(e, _G.MercCurrentOutfit or 1)
                    self:EquipMercenaryWeapon(e, _G.MercCurrentWeapon or 1)
                else
                    -- A corpse from a previous session, or a man who was paid off before the
                    -- save was written. Neither has any owner left to remove him.
                    stale[#stale + 1] = e.id
                end
            elseif self._loadSweep and self:IsLoadSweepName(name) then
                stale[#stale + 1] = e.id
            end
        end
    end
    self._loadSweep = false
    if #stale > 0 then
        for _, id in ipairs(stale) do
            pcall(function() System.RemoveEntity(id) end)
        end
        System.LogAlways('[Mercenary Jeff] load sweep: removed ' .. #stale ..
                         ' stale mod NPC(s) the save carried with no record behind them')
    end
    -- Always recount after rebuild so MercCount reflects reality
    local c = 0
    for _ in pairs(self.ActiveMercs) do c = c + 1 end
    _G.MercCount = c
    System.LogAlways('[Mercenary Jeff] Merc cache rebuilt. Active mercs: ' .. tostring(_G.MercCount))
end
function mercenaries.RebuildMercCacheDelayed()
    -- Armed only on the LOAD path: a mid-session rebuild (if one is ever added) must not
    -- delete live encounters, only the load may treat recordless NPCs as stale.
    mercenaries._loadSweep = true
    mercenaries:RebuildMercCache()
    mercenaries:Recount()
    -- The roster is only now known, so this is the first moment a torch left burning by the
    -- previous session can be taken off anyone. See CampTorchOnLoad.
    if mercenaries.CampTorchOnLoad then pcall(function() mercenaries:CampTorchOnLoad() end) end
end

function mercenaries:PruneMercCache()
    for name, ent in pairs(self.ActiveMercs) do
        if not self:IsAliveAndWell(ent, true) then
            self.ActiveMercs[name] = nil
            self:MercDropClaim(ent.this and ent.this.id or ent.id)
            Script.SetTimerForFunction(10000, "mercenaries.DespawnMerc", ent.id)
        elseif not self:IsCombatViable(ent) then
            -- Knocked out: keeps his roster slot (a false answer above schedules a
            -- despawn), but he is not fighting and must not hold a swarm-cap slot.
            self:MercDropClaim(ent.this and ent.this.id or ent.id)
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

    -- ...and the MERC side of the same bookkeeping. Nothing else prunes it: a claim is
    -- released by combat_melee's OnFail, which never runs for a merc who was KILLED
    -- holding one - so his entry sat in MercTargetOf for the rest of the session,
    -- counting against that enemy's swarm cap and quietly benching a living man.
    --
    -- Both keys here are tostring(wuid), not wuids, so they cannot be resolved back to
    -- entities; the live set is built from ActiveMercs instead. The TARGET side needs no
    -- pruning of its own - a claim on a dead enemy is released by the OnFail of the merc
    -- holding it, and that merc is alive by construction.
    if self.MercSetClaim then
        local live, ents = {}, {}
        for _, ent in pairs(self.ActiveMercs or {}) do
            local w = ent and (ent.this and ent.this.id or ent.id)
            if w and self:IsAliveAndWell(ent, true) then
                live[tostring(w)] = true
                ents[tostring(w)] = ent
            end
        end
        local now = 0
        pcall(function() now = System.GetCurrTime() or 0 end)
        for k in pairs(self.MercTargetOf or {}) do
            if not live[k] then
                self:MercSetClaim(k, nil)
            else
                -- A LIVING merc can hold a claim for ever too. OnFail is the only thing that
                -- releases one, and it does not run when his tree is evicted by another
                -- interrupt, swallowed by camp_actor, or simply replaced by the load of a
                -- save. That single orphaned entry is enough to hold EnemyAlerted true - see
                -- the MercTargetOf clause in UpdateEnemyCache - which pins the shared scan at
                -- EnemyAlertRadius for the rest of the session.
                --
                -- Time-boxed rather than immediate: a merc crossing open ground to a target
                -- is legitimately not in combat danger yet, and evicting him there would
                -- cancel every long approach. MercClaimGraceSecs is well past any of them.
                local at = (self.MercClaimAt or {})[k]
                if at and (now - at) > (self.MercClaimGraceSecs or 45.0) then
                    local fighting = false
                    pcall(function() fighting = ents[k].soul:IsInCombatDanger() end)
                    if not fighting then self:MercSetClaim(k, nil) end
                end
            end
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

-- Where men hired INDOORS muster.
-- Full write-up: docs/spawning-npcs.md "Spawning while the player is indoors".
--
-- GetSafeSpawnPosition only looks ~5m behind the player, so hiring from an
-- innkeeper put the squad in the tavern with him - and its ground snap starts 5m
-- above his feet, which inside a building is usually above the ceiling, so the
-- downward ray hits the roof and the men were placed on top of it. That is the
-- "they don't spawn at all" report: they did spawn, over the player's head.
--
-- So when the player is under a roof the muster point moves outside: rings of
-- bearings at growing radius, keeping the first candidate with open sky over it
-- and ground a man can stand on. Rejecting an indoor candidate costs ONE ray
-- (the roof probe), so the inside-the-building half of the search is cheap; only
-- open-sky candidates pay for CampValidateSpot's nine-ray footprint check.
--
-- The two checks use DIFFERENT reference heights on purpose:
--   * the roof probe is deliberately player-relative. The question it answers is
--     "is there still something over my head at this bearing", i.e. have we left
--     the building, and that is measured from the floor he is standing on.
--   * the standability check is candidate-relative, against the ground actually
--     under the candidate. Hired upstairs the street is several metres down, and
--     judging it against his floor would reject the whole street.
-- The cost of the player-relative roof probe is a slope bias: open ground more
-- than CampRoofDetectHeight (3m) ABOVE his feet reads as roofed and is skipped.
-- That is the safe direction to err in - it drops some bearings on hilly ground,
-- and there are 16 per ring - and it is not worth "fixing" by snapping first,
-- because a snap taken indoors lands on the roof and would make a rooftop
-- candidate look like open sky, which is the bug this whole function exists for.
mercenaries.OutdoorAnchorMin   = 4.0    -- first ring (still inside, but cheap to reject)
-- Far enough to clear a tavern common room, deliberately no further: men put down 30m
-- away can end up round the back of the building with an awkward path back, and the
-- ring search returns the NEAREST hit anyway, so a large cap only changes the
-- give-up case.
mercenaries.OutdoorAnchorMax   = 20.0   -- give up past this and let the caller fall back
mercenaries.OutdoorAnchorStep  = 2.0
mercenaries.OutdoorAnchorRays  = 16     -- bearings per ring
mercenaries.OutdoorAnchorDrop  = 10.0   -- ...but never this far above/below the player (cliff, wrong storey)
mercenaries.OutdoorAnchorTries = 24     -- footprint checks before giving up (bounds the raycast burst)
mercenaries.HireIndoorOffset   = 2.0    -- enclosed interior: how far behind the player to place them

-- Returns spot, underRoof:
--   nil, false  the player is outdoors - leave the normal placement alone
--   pos, true   he is indoors and this is the open ground to muster on
--   nil, true   he is indoors and there is no open ground within reach
function mercenaries:FindOutdoorSpawnAnchor(from)
    if not (from and self.CampDetectRoof) then return nil, false end
    local roofed = false
    pcall(function() roofed = self:CampDetectRoof(from) and true or false end)
    if not roofed then return nil, false end

    local ok, res = pcall(function()
        local tries, ring = 0, 0
        local r = self.OutdoorAnchorMin
        while r <= self.OutdoorAnchorMax + 1e-6 do
            ring = ring + 1
            -- Half-step alternate rings so the samples never line up in spokes,
            -- which would keep probing the same wall all the way out.
            local base = (ring % 2 == 0) and (math.pi / self.OutdoorAnchorRays) or 0
            for k = 0, self.OutdoorAnchorRays - 1 do
                local a  = base + (k / self.OutdoorAnchorRays) * 2 * math.pi
                local cx = from.x + math.cos(a) * r
                local cy = from.y + math.sin(a) * r
                if not self:CampDetectRoof({ x = cx, y = cy, z = from.z }) then
                    local g = self:CampSnapToGround({ x = cx, y = cy, z = from.z })
                    if g and math.abs(g.z - from.z) <= self.OutdoorAnchorDrop then
                        tries = tries + 1
                        local valid = self:CampValidateSpot({ x = cx, y = cy, z = g.z }, g.z,
                                                            self.CampMercFootprint)
                        if valid then return { x = cx, y = cy, z = g.z } end
                        if tries >= self.OutdoorAnchorTries then return nil end
                    end
                end
            end
            r = r + self.OutdoorAnchorStep
        end
        return nil
    end)

    return (ok and res) or nil, true
end

-- The single muster point every hire path uses. Returns nil only when there is no
-- player to measure from.
--
--   { pos =, rot =, outside =, snap = }
--
-- `snap = false` means "place them exactly here, do NOT ground-snap or validate".
-- That is the enclosed case - a mine, a keep, a cellar - where the player is under
-- a roof and no open ground is within reach. Falling through to the normal
-- placement there is what put men on the roof: both CampSnapToGround and
-- CampValidateSpot probe from above, so indoors they find the building's roof
-- rather than the floor the player is standing on. His own z is the one height we
-- know is a real floor, so we use it verbatim.
function mercenaries:HireSpawnAnchor()
    local pp
    pcall(function() pp = player and player:GetWorldPos() end)

    local base, rot = self:GetSafeSpawnPosition(player, 3)
    if not rot then pcall(function() rot = player and player:GetAngles() end) end
    if not pp then
        if not base then return nil end
        return { pos = base, rot = rot, outside = false, snap = true }
    end

    local out, underRoof = self:FindOutdoorSpawnAnchor(pp)
    -- Logged because which of the three branches fired is otherwise invisible, and the
    -- two indoor ones move men somewhere the player is not looking.
    if out then
        System.LogAlways(string.format(
            '[Mercenaries] hire indoors - mustering outside at %.1fm',
            math.sqrt((out.x - pp.x) ^ 2 + (out.y - pp.y) ^ 2)))
        return { pos = out, rot = rot, outside = true, snap = true }
    end
    if not underRoof then
        if not base then return nil end
        return { pos = base, rot = rot, outside = false, snap = true }
    end
    System.LogAlways('[Mercenaries] hire indoors with no open ground in reach - ' ..
                     'mustering on the player\'s own floor, unvalidated')

    -- Enclosed interior. This spot gets NO validation - every ground probe in the mod
    -- fires from above and would find the roof - so it has to be somewhere we already
    -- know is good rather than somewhere merely plausible.
    --
    -- The player's own feet are the only such point: he is standing on walkable floor,
    -- on the navmesh, by definition. GetSafeSpawnPosition's x/y is NOT good enough on
    -- its own - it picks a bearing by a SCORE (clear distance scaled by an angle
    -- penalty), not by true clearance, so in a cramped room its 0.5m margin can be
    -- optimistic, and an unvalidated spawn there can put a man inside geometry or off
    -- the mesh. An NPC off the navmesh cannot walk at all, which reads as "he never
    -- follows" rather than as a placement bug.
    --
    -- So: keep GetSafeSpawnPosition's BEARING (behind the player, away from the wall it
    -- liked least) but only step HireIndoorOffset along it. A couple of metres from a
    -- known-good point is as safe as placement gets without a navmesh query.
    local ox, oy = 0, 0
    if base then
        local dx, dy = base.x - pp.x, base.y - pp.y
        local L = math.sqrt(dx * dx + dy * dy)
        if L > 1e-3 then
            local r = math.min(L, self.HireIndoorOffset)
            ox, oy = (dx / L) * r, (dy / L) * r
        end
    end
    return {
        pos  = { x = pp.x + ox, y = pp.y + oy, z = pp.z },
        rot  = rot, outside = false, snap = false,
    }
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

-- A named companion. They are spawned as "SpawnedFriend_hero_<soul>_<n>" precisely so
-- that every system keying on SpawnedFriend picks them up for free - camp membership,
-- the look-at prompts, formations, the LOD boost, orders, the lot - exactly the trick
-- the archers use. `_hero_` then marks the two things they must NOT share: they keep
-- their own gear rather than the squad's, and they never talk.
--
-- "MercenaryCustomCompanion" was the old name. Saves taken before the rename still hold
-- entities called that, so it is still recognised here and nowhere else.
mercenaries.HeroNameMark = "_hero_"
mercenaries.HeroLegacyPrefix = "MercenaryCustomCompanion"

function mercenaries:IsHeroName(name)
    if not name or name == '' then return false end
    return string.find(name, self.HeroNameMark, 1, true) ~= nil
        or string.find(name, self.HeroLegacyPrefix, 1, true) ~= nil
end

function mercenaries:IsHero(ent)
    return ent ~= nil and self:IsHeroName(ent.GetName and ent:GetName() or '')
end

-- Identify whether an entity is a mercenary, returning its type or nil.
function mercenaries:GetMercType(ent)
    if not ent then return nil end
    local name = ent:GetName() or ''

    if self:IsHeroName(name) then return "hero" end
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

    -- ONE CreateItem does not reliably mint a large sum: the torture run asked for
    -- 60000 and the purse moved by only a fraction (a stack cap somewhere below the
    -- engine), silently - the verification here read "purse moved" and called that
    -- success. So the sum is created in chunks, the purse read back after each, and
    -- the loop keeps going until the target is reached or the purse stops moving.
    local target, tries = before + amount, 0
    local now = before
    while now < target and tries < 100 do
        tries = tries + 1
        local need = target - now
        pcall(function() player.inventory:CreateItem(self.MoneyItemClass, 1, math.min(need, 1000)) end)
        local after = now
        pcall(function() after = player.inventory:GetMoney() or after end)
        if after <= now then break end   -- not moving: stop rather than spin
        now = after
    end

    local got = now - before
    if got >= amount then return true, got end
    System.LogAlways("[Mercenaries] GiveMoney: asked " .. tostring(amount) .. ", purse took only "
                     .. tostring(got) .. " (" .. tostring(tries) .. " chunk(s)) - check MoneyItemClass")
    return got > 0, got
end
