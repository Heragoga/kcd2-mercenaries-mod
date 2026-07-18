-- Camp forge: borrows a village Smithery's minigame logic onto the flattest
-- patch near camp, dresses it with props, and seats a merc smith. See
-- docs/camp-forge.md for the full design and the NPC-smith postmortem.

-- Henry-relative prop layout (fwd = toward interaction anvil, lat = +left,
-- up = height, yaw = deg CCW).
mercenaries.CampForgeLayout = {
    { name = "anvil_interact", model = "objects/manmade/task_specific_props/metal_industry/smithing/armourer_anvil.cgf", fwd =  2.74, lat =  0.00, up = -0.11, yaw =   0 },
    { name = "anvil_forge",    model = "objects/manmade/task_specific_props/metal_industry/smithing/anvil.cgf",           fwd = -0.23, lat = -2.56, up = -0.11, yaw =   0 },
    { name = "forge",          model = "objects/manmade/task_specific_props/metal_industry/smithing/forge_small_a.cgf",   fwd = -0.82, lat =  0.58, up = -0.06, yaw =  90 },
    { name = "coal",           model = "objects/manmade/structures/industrial/smitheries/coal_forge_small_a.cgf",         fwd = -0.98, lat =  0.66, up =  0.63, yaw =  90, s = 0.875 },
    { name = "water",          model = "objects/manmade/task_specific_props/metal_industry/smithing/water_container.cgf", fwd =  1.74, lat = -1.75, up =  0.00, yaw =   0 },
    { name = "barrel",         model = "objects/manmade/task_specific_props/metal_industry/smithing/barrel_forging.cgf",  fwd =  2.19, lat = -1.23, up =  0.00, yaw =   0 },
    { name = "grindstone",     borrow = "Grindstone",                                                                     fwd =  0.90, lat =  2.30, up =  0.00, yaw =   0 },
}

mercenaries.CampForge = nil
mercenaries.CampForgeAutoPackDist = 30.0

-- Rate a candidate patch by the ground's height spread over a small grid
-- (smaller = flatter). Returns the spread in metres, or nil if too holey.
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
-- (plus a facing that points the forge AWAY from the camp centre). Optional
-- `avoid` is a single position OR a list of them (e.g. already-placed stations);
-- nearby candidates are skipped so camp structures don't land on the same patch.
function mercenaries:ForgeFindFlattest(center, avoid)
    -- Normalize to a list: a single {x,y,z} has no [1]; a list of positions does.
    local avoids = avoid and (avoid[1] and avoid or { avoid }) or nil
    local best, bestSpread, bestAng
    -- Rings pulled in close to camp (halved from the original 9/11/13).
    for _, R in ipairs({ 4.5, 5.5, 6.5 }) do
        for a = 0, 7 do
            local ang = a * (math.pi / 4)
            local cand = self:CampSnapToGround({ x = center.x + math.cos(ang) * R, y = center.y + math.sin(ang) * R, z = center.z })
            local skip = false
            if avoids then
                for _, av in ipairs(avoids) do
                    if av and av.x then
                        local ad = math.sqrt((cand.x - av.x) ^ 2 + (cand.y - av.y) ^ 2 + (cand.z - av.z) ^ 2)
                        if ad < 7.0 then skip = true; break end   -- keep stations' props apart
                    end
                end
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
        -- Set orientation at spawn time: a StanceSmartObject seat caches its sit
        -- helper facing here, and SetAngles afterwards won't move it.
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

    -- The camp reserves a grid tile per upgrade (see CampStationTiles); only fall
    -- back to a flat-patch scan if there wasn't one.
    local spot, ang = self:CampStationSpot("forge")
    if not spot then spot, ang = self:ForgeFindFlattest(center) end
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
                             position = w, properties = { object_Model = p.model, bMissionCritical = false, bSaved_by_game = false, bSerialize = false } }
            if p.s then params.scale = p.s end
            local e; pcall(function() e = System.SpawnEntity(params) end)
            if e then
                pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw + math.rad(p.yaw or 0) }) end)
                if p.s then pcall(function() e:SetScale(p.s) end) end
                table.insert(rec.visuals, { e = e })
            end
        end
    end

    -- Retarget the Smithery's "alignment" link to a holder at the working spot;
    -- left pointing at its village TagPoint, pressing E teleports Henry there.
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

-- Camp smith: a merc seated by the anvil sharpening a conjured sword, driven as
-- camp activity mode 10 in camp_actor.xml. See docs/camp-forge.md.

-- Spawn the smith's bench: a stool prop + a sitting StanceSmartObject (CampChairSO
-- properties), by the anvil facing it. Entities tracked in rec.smithSeatIds.
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

-- Pin one living camped merc as the smith, preferring a patrolling guard: an
-- NPC already mid in-place animation (or a walk) can't be redirected from Lua,
-- so a guard (idle executor) takes over cleanly.
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
    -- Teleport onto the bench (the forge patch may be off-navmesh; a BT Move
    -- could never reach it, but Lua SetPos works).
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

-- Restore the borrowed forge if the player travels back near its home village.
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
