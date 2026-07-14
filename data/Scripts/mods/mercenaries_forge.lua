-- =======================================================================
-- CAMP FORGE  (Portable Smithy upgrade made real)
--
-- When the camp is pitched and the smithy upgrade is owned, we build a usable
-- blacksmith's forge on the FLATTEST patch we can find near the camp (the
-- smithing minigame needs level ground). It reuses the "Forge Anywhere" trick:
-- borrow the nearest loaded village Smithery's logic (its hidden tool slots
-- feed the minigame), retarget its alignment to a holder we place, dress the
-- scene with our own props, and borrow a real Grindstone too. Broken down when
-- camp is broken; also auto-restores the borrowed forge if the player wanders
-- back to the village it came from.
--
-- A merc "smith" sits at a spawned bench by the anvil and sharpens a sword
-- (camper_knifeSharpening with a conjured sword in hand, driven as camp
-- activity mode 10 in mercenary_follow.xml). Real smith animations proved
-- impossible for NPCs at a moved forge - see docs/camp-forge.md for the full
-- postmortem of what was tried and why only this works.
-- =======================================================================

-- Henry-relative prop layout (fwd = toward interaction anvil, lat = +left,
-- up = height, yaw = deg CCW). Same tuned values as the Forge Anywhere mod.
mercenaries.CampForgeLayout = {
    { name = "anvil_interact", model = "objects/manmade/task_specific_props/metal_industry/smithing/armourer_anvil.cgf", fwd =  2.74, lat =  0.00, up = -0.11, yaw =   0 },
    { name = "anvil_forge",    model = "objects/manmade/task_specific_props/metal_industry/smithing/anvil.cgf",           fwd = -0.23, lat = -2.56, up = -0.11, yaw =   0 },
    { name = "forge",          model = "objects/manmade/task_specific_props/metal_industry/smithing/forge_small_a.cgf",   fwd = -0.82, lat =  0.58, up = -0.06, yaw =  90 },
    { name = "coal",           model = "objects/manmade/structures/industrial/smitheries/coal_forge_small_a.cgf",         fwd = -0.98, lat =  0.66, up =  0.63, yaw =  90, s = 0.875 },
    { name = "water",          model = "objects/manmade/task_specific_props/metal_industry/smithing/water_container.cgf", fwd =  1.74, lat = -1.75, up =  0.00, yaw =   0 },
    { name = "barrel",         model = "objects/manmade/task_specific_props/metal_industry/smithing/barrel_forging.cgf",  fwd =  2.19, lat = -1.23, up =  0.00, yaw =   0 },
    { name = "grindstone",     borrow = "Grindstone",                                                                     fwd =  0.90, lat =  2.30, up =  0.00, yaw =   0 },
}

mercenaries.CampForge = nil               -- borrow record while a camp forge is up
mercenaries.CampForgeAutoPackDist = 30.0  -- restore borrowed forge if player nears its village

-- The sword conjured into the smith's hand comes from this item class (a real
-- sword the base game itself CreateItems in nebakovObrana) - see mode 10 in
-- mercenary_follow.xml, which does the CreateItem+EquipItem.
-- (Kept here as documentation; the guid lives in the BT.)

-- =======================================================================
-- Flatness scan: rate a candidate patch by the height spread of the ground
-- across a small grid (smaller = flatter). Reuses CampSampleHeightmap. Returns
-- the spread in metres, or nil if the patch has too many holes / no ground.
-- =======================================================================
function mercenaries:ForgeFlatness(pos)
    local spread
    pcall(function()
        local hm = self:CampSampleHeightmap(pos, 4, 0.7, false)   -- ~5.6m patch
        if not hm or not hm.z then return end
        local mn, mx, n = nil, nil, 0
        for i = 0, 2 * hm.r do
            for j = 0, 2 * hm.r do
                local z = hm.z[i] and hm.z[i][j]
                if z then
                    n = n + 1
                    if not mn or z < mn then mn = z end
                    if not mx or z > mx then mx = z end
                end
            end
        end
        local total = (2 * hm.r + 1) * (2 * hm.r + 1)
        if mn and n >= total * 0.85 then spread = mx - mn end   -- need mostly-solid ground
    end)
    return spread
end

-- Try a ring of candidate spots around the camp and return the flattest one
-- (plus a facing that points the forge AWAY from the camp centre). An optional
-- `avoid` position (e.g. an already-placed forge) makes nearby candidates be
-- skipped, so two camp structures don't land on the same patch.
function mercenaries:ForgeFindFlattest(center, avoid)
    local best, bestSpread, bestAng
    -- Rings pushed out (was 6.5/8.5/10.5) so the forge/alchemy props - which
    -- reach ~3.7m back toward camp - clear the tent ring (3.9m) with >=2m to
    -- spare instead of overlapping it.
    for _, R in ipairs({ 9.0, 11.0, 13.0 }) do
        for a = 0, 7 do
            local ang = a * (math.pi / 4)
            local cand = self:CampSnapToGround({ x = center.x + math.cos(ang) * R, y = center.y + math.sin(ang) * R, z = center.z })
            local skip = false
            if avoid then
                local ad = math.sqrt((cand.x - avoid.x) ^ 2 + (cand.y - avoid.y) ^ 2 + (cand.z - avoid.z) ^ 2)
                -- 7m spot-to-spot keeps the two benches' own props >=2m apart.
                if ad < 7.0 then skip = true end
            end
            local spread = (not skip) and self:ForgeFlatness(cand) or nil
            if spread and (not bestSpread or spread < bestSpread) then
                best, bestSpread, bestAng = cand, spread, ang
            end
        end
    end
    if best then
        System.LogAlways(string.format("[CampForge] flattest patch: spread %.2fm at angle %.0fdeg", bestSpread or -1, math.deg(bestAng or 0)))
    end
    return best, bestAng, bestSpread
end

-- =======================================================================
-- Build / tear down
-- =======================================================================
function mercenaries:ForgeFindNearest(cls)
    if not player then return nil end
    local o = player:GetWorldPos()
    local list = System.GetEntitiesByClass and System.GetEntitiesByClass(cls)
    if not list then return nil end
    local best, bestD
    for _, e in pairs(list) do
        local p = e.GetWorldPos and e:GetWorldPos()
        if p then
            local dd = (p.x - o.x) ^ 2 + (p.y - o.y) ^ 2 + (p.z - o.z) ^ 2
            if not bestD or dd < bestD then best, bestD = e, dd end
        end
    end
    return best, bestD and math.sqrt(bestD)
end

-- Spawn one entity, logging success/failure.
function mercenaries:ForgeSpawnEnt(cls, name, pos, props, yaw, track)
    local e
    pcall(function()
        -- orientation at spawn time so a StanceSmartObject seat caches its sit
        -- helper facing correctly (SetAngles-after-spawn doesn't move that cached
        -- transform - see SpawnCampFurnitureSO).
        e = System.SpawnEntity({ class = cls, name = name .. "_" .. tostring(math.random(100000, 999999)),
                                 position = pos, orientation = { x = 0, y = 0, z = yaw or 0 }, properties = props })
    end)
    if e then
        if yaw then pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw }) end) end
        if track then table.insert(track, e.id) end
    else
        System.LogAlways("[CampForge] spawn " .. cls .. " '" .. name .. "' FAILED")
    end
    return e
end

-- Spawn the camp forge near `center`. Returns true on success.
function mercenaries:SpawnCampForge(center)
    if self.CampForge then return true end
    if not center then return false end
    local sm, dist = self:ForgeFindNearest("Smithery")
    if not sm then
        System.LogAlways("[CampForge] no loaded Smithery to borrow - forge not built (camp too far from any settlement)")
        return false
    end

    -- Flattest patch, or fall back to a fixed offset if the scan found nothing.
    local spot, ang = self:ForgeFindFlattest(center)
    if not spot then
        ang = 0
        spot = self:CampSnapToGround({ x = center.x + 8, y = center.y, z = center.z })
    end
    -- Forge faces outward from camp: forward = the ring direction.
    local F = { x = math.cos(ang), y = math.sin(ang) }
    local L = { x = -F.y, y = F.x }
    -- `spot` is where the anvil goes; the player works 2.74m back toward camp.
    local anvilPos = spot
    local standPos = self:CampSnapToGround({ x = anvilPos.x - F.x * 2.74, y = anvilPos.y - F.y * 2.74, z = anvilPos.z })
    local yaw = math.atan2(anvilPos.y - standPos.y, anvilPos.x - standPos.x)

    local rec = { sm = sm, smPos = sm:GetWorldPos(), visuals = {}, stand = standPos, anvilPos = anvilPos }
    pcall(function() sm:SetWorldPos(anvilPos) end)

    for _, p in ipairs(self.CampForgeLayout) do
        local w = { x = standPos.x + F.x * p.fwd + L.x * p.lat,
                    y = standPos.y + F.y * p.fwd + L.y * p.lat,
                    z = standPos.z + (p.up or 0) }
        if p.borrow then
            local e = self:ForgeFindNearest(p.borrow)
            if e then
                local origPos = e:GetWorldPos()
                pcall(function() e:SetWorldPos(w) end)
                pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw + math.rad(p.yaw or 0) }) end)
                table.insert(rec.visuals, { e = e, borrowed = true, origPos = origPos })
            end
        else
            local params = { class = "BasicEntity", name = "MercCampForge_" .. tostring(math.random(100000, 999999)),
                             position = w, properties = { object_Model = p.model, bMissionCritical = false } }
            if p.s then params.scale = p.s end
            local e; pcall(function() e = System.SpawnEntity(params) end)
            if e then
                pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw + math.rad(p.yaw or 0) }) end)
                if p.s then pcall(function() e:SetScale(p.s) end) end
                table.insert(rec.visuals, { e = e })
            end
        end
    end

    -- Alignment anchor for the PLAYER minigame: the Smithery's "alignment" link
    -- normally points at a level-baked TagPoint that stays in the village (which
    -- used to teleport Henry there mid-minigame) - retarget it to a holder we
    -- place at the working spot.
    local holder
    pcall(function()
        holder = System.SpawnEntity({ class = "SmartObjectHolder",
            name = "MercCampForgeAlign_" .. tostring(math.random(100000, 999999)),
            position = standPos, properties = {} })
    end)
    if holder then
        pcall(function() holder:SetAngles({ x = 0, y = 0, z = yaw }) end)
        pcall(function() sm:SetLinkTarget("alignment", holder.id) end)
        rec.holder = holder
        pcall(function()
            local wang = sm:GetWorldAngles()
            local baseYaw = (wang and wang.z or 0) - math.rad(63)
            local c2, s2 = math.cos(baseYaw), math.sin(baseYaw)
            local lx, ly, lz = 0.046, -2.706, -0.178
            rec.alignOrig = { x = rec.smPos.x - (lx * c2 - ly * s2), y = rec.smPos.y - (lx * s2 + ly * c2), z = rec.smPos.z - lz }
        end)
    end

    self.CampForge = rec
    -- Put a merc to work at the forge bench.
    pcall(function() self:ForgeAssignSmith(rec) end)
    System.LogAlways(string.format("[CampForge] built (borrowed Smithery %.0fm away)", dist or -1))
    Script.SetTimerForFunction(2000, "mercenaries.CampForgeMonitor")
    return true
end

function mercenaries:DespawnCampForge()
    local rec = self.CampForge
    if not rec then return end
    pcall(function() self:ForgeClearSmith(rec) end)
    pcall(function() rec.sm:SetWorldPos(rec.smPos) end)
    for _, v in ipairs(rec.visuals or {}) do
        if v.borrowed then pcall(function() v.e:SetWorldPos(v.origPos) end)
        else pcall(function() System.RemoveEntity(v.e.id) end) end
    end
    if rec.holder then
        if rec.alignOrig then pcall(function() rec.holder:SetWorldPos(rec.alignOrig) end)
        else pcall(function() rec.holder:SetWorldPos(rec.smPos) end) end
    end
    -- Remove the smith's bench (stool prop + seat smart object).
    for _, entId in ipairs(rec.smithSeatIds or {}) do
        pcall(function() System.RemoveEntity(entId) end)
    end
    self.CampForge = nil
    System.LogAlways("[CampForge] torn down, village Smithery restored")
end

-- =======================================================================
-- CAMP SMITH  (a merc works at the forge bench)
--
-- The smith sits on a spawned seat by the anvil and sharpens a sword:
-- camp activity mode 10 (mercenary_follow.xml) sits him on the seat
-- (StanceElement, the proven runtime-seat mechanism), conjures a sword into
-- his hand (CreateItem+EquipItem) and plays camper_knifeSharpening - a camper
-- unstance built for HELD items. Real smith unstances are engine-locked to
-- level-baked ItemSlots and cannot work at a moved/spawned forge
-- (docs/camp-forge.md has the full story).
-- =======================================================================

-- Spawn the smith's bench: a stool prop + a sitting StanceSmartObject
-- (CampChairSO properties - runtime-spawned seats provably work), placed by the
-- anvil facing it. Entities tracked in rec.smithSeatIds for teardown.
function mercenaries:ForgeSpawnSmithSeat(rec)
    if rec.smithSeat then return true end
    rec.smithSeatIds = rec.smithSeatIds or {}
    local ax, ay = rec.anvilPos.x, rec.anvilPos.y
    local dx, dy = rec.stand.x - ax, rec.stand.y - ay
    local dlen = math.sqrt(dx * dx + dy * dy); if dlen < 0.01 then dx, dy, dlen = 1, 0, 1 end
    dx, dy = dx / dlen, dy / dlen
    -- Seat 0.69m from the anvil toward the stand, facing the anvil.
    local seatPos = self:CampSnapToGround({ x = ax + dx * 0.69, y = ay + dy * 0.69, z = rec.anvilPos.z })
    local seatYaw = math.atan2(ay - seatPos.y, ax - seatPos.x)
    pcall(function() self:SpawnCampPropModel(self.CampModels.Stool, seatPos, seatYaw, "MercForgeSmithStool", rec.smithSeatIds) end)
    local seat = self:ForgeSpawnEnt("StanceSmartObject", "MercForgeSmithSeat", seatPos, {
        guidSmartObjectType = self.CampChairSO.guidSmartObjectType,
        soclass_SmartObjectHelpers = self.CampChairSO.soclass_SmartObjectHelpers,
        sWH_AI_EntityCategory = self.CampChairSO.sWH_AI_EntityCategory,
        Script = self.CampChairSO.Script,
        Bed = self.CampChairSO.Bed,
    }, seatYaw, rec.smithSeatIds)
    if not seat then return false end
    pcall(function() rec.smithSeat = XGenAIModule.GetMyWUID(seat) end)
    rec.smithSeatPos = seatPos
    return rec.smithSeat ~= nil
end

-- Choose one living camped merc and pin them as the smith. PREFER a patrolling
-- guard: sit/train/eat mercs are mid a long in-place activity animation that
-- lingers over the new one. NOTE: an NPC action already in flight (e.g. a walk
-- started by an unstance) cannot be cancelled from Lua - a freshly-picked merc
-- has an idle action executor, which is why the pick matters.
function mercenaries:ForgeAssignSmith(rec)
    if not rec or not rec.stand then return end
    if not self:ForgeSpawnSmithSeat(rec) then
        System.LogAlways("[CampForge] smith bench failed to spawn - no smith assigned")
        return
    end
    local pick, pickWs
    for _, ent in pairs(self.ActiveMercs or {}) do
        if ent and self:IsAliveAndWell(ent, false) then
            local ws = tostring(ent.this and ent.this.id or ent.id)
            if self.CampPatrollers and self.CampPatrollers[ws] then pick, pickWs = ent, ws; break end
        end
    end
    if not pick then
        for _, ent in pairs(self.ActiveMercs or {}) do
            if ent and self:IsAliveAndWell(ent, false) then
                local ws = tostring(ent.this and ent.this.id or ent.id)
                if not (self.CampActivities and self.CampActivities[ws]) then pick, pickWs = ent, ws; break end
                pick = pick or ent; pickWs = pickWs or ws
            end
        end
    end
    if not pick then
        System.LogAlways("[CampForge] no merc available to work the forge")
        return
    end
    rec.smithWuid = pickWs
    rec.smithEnt = pick
    self.CampForgeSmithWuid = pickWs   -- excluded from role rotation (RotateCampRoles)
    -- Drop any leftover camp activity/patrol - it's the smith now.
    self.CampActivities = self.CampActivities or {}
    self.CampActivities[pickWs] = nil
    if self.CampPatrollers then self.CampPatrollers[pickWs] = nil end
    -- Teleport him onto the bench (the forge patch may be off-navmesh, so a BT
    -- Move could never reach it; Lua SetPos works) and assign the activity.
    pcall(function() pick:SetPos(rec.smithSeatPos) end)
    self.CampActivities[pickWs] = { unstance = "camper_knifeSharpening", mode = 10, pos = rec.smithSeatPos, locWuid = rec.smithSeat }
    pcall(function() System.LogAlways("[CampForge] " .. tostring(pick:GetName()) .. " set to work at the forge bench") end)
end

-- Release the smith (on teardown).
function mercenaries:ForgeClearSmith(rec)
    local ws = (rec and rec.smithWuid) or self.CampForgeSmithWuid
    if ws and self.CampActivities then self.CampActivities[ws] = nil end
    self.CampForgeSmithWuid = nil
    if rec then rec.smithWuid = nil; rec.smithEnt = nil end
end

-- If the player travels back toward the village the forge was borrowed from,
-- restore it so that smithy isn't left broken. (The camp forge stays down until
-- the next camp is made - a simple, safe rule.)
function mercenaries.CampForgeMonitor()
    local self = mercenaries
    local rec = self.CampForge
    if not rec then return end
    local restore = false
    pcall(function()
        if player and rec.smPos then
            local o = player:GetWorldPos()
            local sp = rec.smPos
            local dd = (o.x - sp.x) ^ 2 + (o.y - sp.y) ^ 2 + (o.z - sp.z) ^ 2
            if dd < (self.CampForgeAutoPackDist * self.CampForgeAutoPackDist) then
                self:DespawnCampForge()
                restore = true
            end
        end
    end)
    if self.CampForge and not restore then Script.SetTimerForFunction(2000, "mercenaries.CampForgeMonitor") end
end
