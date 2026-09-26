-- Camp forge: borrows a village Smithery's minigame logic onto the flattest
-- patch near camp, dresses it with props, and seats a merc smith. See
-- docs/camp-forge.md for the full design and the NPC-smith postmortem.

-- Henry-relative prop layout (fwd = toward interaction anvil, lat = +left,
-- up = height, yaw = deg CCW).
-- Pulled in round the working anvil (2026-09-20): the hearth stood 3.6 m from it and the
-- second anvil 3.2 m from the hearth, and a judged survey read the yard as "6 m of sprawl,
-- grindstone off on its own". A village smithy keeps everything within a stride of the fire.
-- Henry's own spot (fwd 0, lat 0) and his walk to the anvil stay clear.
mercenaries.CampForgeLayout = {
    { name = "anvil_interact", model = "objects/manmade/task_specific_props/metal_industry/smithing/armourer_anvil.cgf", fwd =  2.74, lat =  0.00, up = -0.11, yaw =   0 },
    { name = "anvil_forge",    model = "objects/manmade/task_specific_props/metal_industry/smithing/anvil.cgf",           fwd =  0.90, lat = -1.90, up = -0.11, yaw =   0 },
    { name = "forge",          model = "objects/manmade/task_specific_props/metal_industry/smithing/forge_small_a.cgf",   fwd =  0.30, lat =  1.20, up = -0.06, yaw =  90 },
    { name = "coal",           model = "objects/manmade/structures/industrial/smitheries/coal_forge_small_a.cgf",         fwd =  0.14, lat =  1.28, up =  0.63, yaw =  90, s = 0.875 },
    { name = "water",          model = "objects/manmade/task_specific_props/metal_industry/smithing/water_container.cgf", fwd =  1.90, lat = -1.55, up =  0.00, yaw =   0 },
    { name = "barrel",         model = "objects/manmade/task_specific_props/metal_industry/smithing/barrel_forging.cgf",  fwd =  2.30, lat = -1.05, up =  0.00, yaw =   0 },
    { name = "grindstone",     borrow = "Grindstone",                                                                     fwd =  1.70, lat =  2.10, up =  0.00, yaw =   0 },
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
    -- The close rings (4.5-6.5m) sit INSIDE the camp - between the player tent and the
    -- first 10.5m grid ring - and this fallback used to check only the caller's avoid
    -- list (other stations, and SpawnCampForge passes none at all), so whatever station
    -- fell back here landed on tents and fire rings: the "improvements overlap the
    -- camp" report. The rings stay (a close spot is the nicest one when it is genuinely
    -- free) but every candidate now has to clear CampSpotClearOfProps - the real world,
    -- not just the station list - and the ring set extends outward so there is always
    -- somewhere legal to fall through to.
    -- Rings stop at 12 m. They used to reach 20, and a station that takes the far ring is
    -- a station in the next field - the forge was measured 20-30 m out across ploughed
    -- soil with nothing else in frame.
    for _, R in ipairs({ 4.5, 5.5, 6.5, 8.0, 10.0, 12.0 }) do
        for a = 0, 7 do
            local ang = a * (math.pi / 4)
            local cand, candClear = self:CampSnapToGround({ x = center.x + math.cos(ang) * R, y = center.y + math.sin(ang) * R, z = center.z }, true)
            -- Flatness alone said nothing about WHAT is flat: a roof, a cart bed and a wall
            -- walk are all perfectly level, and a station whose ring happened to cross one
            -- was built on it. Only candidates standing on open ground get scored now.
            local skip = (candClear == false)
            if avoids then
                for _, av in ipairs(avoids) do
                    if av and av.x then
                        local ad = math.sqrt((cand.x - av.x) ^ 2 + (cand.y - av.y) ^ 2 + (cand.z - av.z) ^ 2)
                        if ad < 7.0 then skip = true; break end   -- keep stations' props apart
                    end
                end
            end
            if not skip and self.CampSpotClearOfProps
               and not self:CampSpotClearOfProps(cand, 3.0) then
                skip = true
            end
            -- ...and what the ground is MADE of. This chooser is outside CampValidateSpot, so
            -- the camp's surface rule never reached it: the fourth judged survey found the
            -- anvil block standing among wet cobbles with the stream running past its foot,
            -- on `mat_mudwater`, which is one of the four materials the rule already refuses.
            if not skip and self.CampSurfaceOK then
                local sOK = self:CampSurfaceOK(cand.x, cand.y, cand.z + 4)
                if not sOK then skip = true end
            end
            -- THE LEASH, APPLIED AT CHOICE TIME. It used to live only inside
            -- CampNudgeClearOfStructures, which runs afterwards and only when the chosen spot
            -- is unusable - so a station whose first pick was merely FAR was never distance
            -- checked at all. That is why the forge kept ending up 15-25 m out on the stream
            -- bank while the cap said 11.
            if not skip then
                local c0 = self.CampCenter or self.CampBuildOrigin
                local cap = self.CampStationLeash or 11.0
                if c0 then
                    local dx, dy = cand.x - c0.x, cand.y - c0.y
                    if (dx * dx + dy * dy) > (cap * cap) then skip = true end
                end
            end
            local spread = (not skip) and self:ForgeFlatness(cand) or nil
            if spread then
                -- Mild distance penalty so a clear close spot still beats a marginally
                -- flatter far one - the wide rings are a fallback, not the preference.
                local scored = spread + R * 0.02
                if not bestSpread or scored < bestSpread then
                    best, bestSpread, bestAng = cand, scored, ang
                end
            end
        end
    end
    if best then
        System.LogAlways(string.format("[CampForge] flattest patch: spread %.2fm at angle %.0fdeg", bestSpread or -1, math.deg(bestAng or 0)))
    end
    -- The chooser scores flatness and clearance but can still settle on a pocket
    -- boxed in by scrub and a stream bank, which is where a judged survey found the
    -- whole forge yard. Same spiral the tavern now uses.
    if best and self.CampNudgeClearOfStructures then
        best = self:CampNudgeClearOfStructures(best, 3.0)
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

-- The home of a borrowed village entity - the place it is put back when the camp breaks
-- and the place the return watch means by "the player is back near its village".
--
--   key   the saver tag the home is kept under
--   e     the entity ForgeFindNearest found
--   spot  where the camp is about to put it
--
-- A saved home is used only when the entity is found standing near the camp spot: that is
-- ours, restored by the engine where we left it, and its current position says nothing
-- about where it came from. Found anywhere else it is a fresh borrow - its position IS the
-- home, and is saved so the next load still knows it. Used by the forge, the alchemy bench
-- and the forge's borrowed grindstone.
mercenaries.StationHomeNearCamp = 60.0

function mercenaries:StationHome(key, e, spot)
    local cur
    pcall(function() cur = e:GetWorldPos() end)
    cur = cur or spot
    local saved = self:StationHomeLoad(key)
    if saved and spot and cur then
        local d = math.sqrt((cur.x - spot.x) ^ 2 + (cur.y - spot.y) ^ 2)
        if d <= (self.StationHomeNearCamp or 60) then
            System.LogAlways(string.format("[Camp] %s found at the camp (%.0fm from its spot) - its home is the saved %.0f, %.0f",
                                           key, d, saved.x, saved.y))
            return saved
        end
    end
    self:StationHomeSave(key, cur)
    return { x = cur.x, y = cur.y, z = cur.z }
end

-- A home within packing distance of the camp: the camp is pitched beside the village that
-- owns the entity, and packing it "on approach" would pack it every two seconds.
function mercenaries:StationHomeIsHere(home, spot)
    if not (home and spot) then return false end
    local d = math.sqrt((home.x - spot.x) ^ 2 + (home.y - spot.y) ^ 2)
    return d <= (self.CampForgeAutoPackDist or 30) + 10
end

function mercenaries:StationHomeLoad(key)
    local s
    pcall(function() s = self:LoadString(key) end)
    if not s or s == "-" then return nil end
    local x, y, z = string.match(s, "^([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)$")
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not (x and y and z) then return nil end
    return { x = x, y = y, z = z }
end

function mercenaries:StationHomeSave(key, p)
    if not p then return end
    pcall(function() self:SaveString(key, string.format("%.2f,%.2f,%.2f", p.x, p.y, p.z)) end)
end

-- "-" rather than a delete: the saver has no delete, and refuses an empty value.
function mercenaries:StationHomeForget(key)
    pcall(function() self:SaveString(key, "-") end)
end

-- Spawn one entity, logging success/failure.
function mercenaries:ForgeSpawnEnt(cls, name, pos, props, yaw, track)
    local e
    pcall(function()
        -- Set orientation at spawn time: a StanceSmartObject seat caches its sit
        -- helper facing here, and SetAngles afterwards won't move it.
        e = System.SpawnEntity({ class = cls, name = name .. "_" .. tostring(math.random(100000, 999999)),
                                 position = pos, orientation = { x = 0, y = 0, z = yaw or 0 },
                                 properties = mercenaries:NoSaveProps(props) })
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
    -- A reserved tile is a grid cell, and the grid spreads to keep the tent rings apart - at
    -- 13 m spacing the forge's cell is past the leash before anything has checked it. The
    -- tavern is pulled in the same way; the forge was measured 12-15 m out beyond the bush
    -- line in a judged survey while everything else stood together.
    if spot and self.CampLeashToCamp then spot = self:CampLeashToCamp(spot) end
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

    -- Where the Smithery really lives. Its position NOW is not the answer after a reload:
    -- the engine restores a moved level entity where it was moved to, so the one found
    -- "nearest" is our own, already standing at the camp - and recording THAT as home made
    -- the return watch below tear the forge down two seconds after every load (the player
    -- is always within 30 m of a home that is the camp), while CampStationRetryTick put it
    -- back up every five seconds for a minute before giving up. "Present for the first few
    -- seconds after a load, then flickering, then gone" (2026-09-03). The home is saved
    -- with the camp on the first borrow and read back whenever the entity is found
    -- standing at the camp. See StationHome and docs/camp-forge.md.
    local smPos = self:StationHome("CampForgeHome", sm, anvilPos)
    local rec = { sm = sm, smPos = smPos, visuals = {}, stand = standPos, anvilPos = anvilPos }
    if self:StationHomeIsHere(smPos, anvilPos) then
        rec.noAutoPack = true
        System.LogAlways("[CampForge] the village smithy is within reach of the camp - it will not be packed on approach")
    end
    pcall(function() sm:SetWorldPos(anvilPos) end)

    -- Each prop is tested where it will stand and slid in toward the smith if a bush or a
    -- tent is there already (CampSatelliteSpot); the claims go down after the whole yard.
    local claimsBefore = self.CampPlacedFoot and #self.CampPlacedFoot or 0
    local placed = {}
    for _, p in ipairs(self.CampForgeLayout) do
        local w = { x = standPos.x + F.x * p.fwd + L.x * p.lat,
                    y = standPos.y + F.y * p.fwd + L.y * p.lat,
                    z = standPos.z + (p.up or 0) }
        if self.CampSatelliteSpot and p.name ~= "anvil_interact" and p.name ~= "coal" then
            -- A borrowed village entity (the grindstone) has no measured footprint; a
            -- generous box stands in for it.
            w = self:CampSatelliteSpot(w, yaw + math.rad(p.yaw or 0), p.model, standPos, "forge " .. tostring(p.name),
                                       claimsBefore, p.borrow and { w = 0.7, h = 0.7 } or nil)
        end
        if not w then
            -- left out; a forge with one barrel fewer beats a barrel in a bush
        elseif p.borrow then
            local e = self:ForgeFindNearest(p.borrow)
            if e then
                local homeKey = "CampForgeHome_" .. tostring(p.borrow)
                local origPos = self:StationHome(homeKey, e, w)
                pcall(function() e:SetWorldPos(w) end)
                pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw + math.rad(p.yaw or 0) }) end)
                table.insert(rec.visuals, { e = e, borrowed = true, origPos = origPos, homeKey = homeKey })
                table.insert(placed, { pos = w, yaw = yaw + math.rad(p.yaw or 0), half = { w = 0.6, h = 0.6 }, what = "forge " .. tostring(p.name) })
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
                if p.name ~= "coal" then
                    table.insert(placed, { pos = w, yaw = yaw + math.rad(p.yaw or 0), model = p.model, what = "forge " .. tostring(p.name) })
                end
            end
        end
    end
    if self.CampClaimFoot and self.CampPropFootHalf then
        for _, q in ipairs(placed) do
            self:CampClaimFoot(q.pos, q.yaw, q.half or self:CampPropFootHalf(q.model, 0), q.what)
        end
    end

    -- Retarget the Smithery's "alignment" link to a holder at the working spot;
    -- left pointing at its village TagPoint, pressing E teleports Henry there.
    local holder
    pcall(function()
        holder = System.SpawnEntity({ class = "SmartObjectHolder",
            name = "MercCampForgeAlign_" .. tostring(math.random(100000, 999999)),
            position = standPos, properties = mercenaries:NoSaveProps({}) })
    end)
    if holder then
        pcall(function() holder:SetAngles({ x = 0, y = 0, z = yaw }) end)
        -- Remember where the link pointed, to put it back. Left on our holder - an entity
        -- that is never saved - the next load found the village Smithery linked to nothing,
        -- and pressing E at it did nothing: "after the update I can't use Henry's forge, all
        -- the other forges work" is a Smithery that was once borrowed and never re-linked.
        -- The id is kept in the save too, so a forge found standing at the camp after a
        -- load still knows what to give back.
        local origTarget
        -- The binds may answer with the entity's script table or with a bare entity id;
        -- either is taken. Measured 2026-09-22: `t.id` on the answer read nothing, twice.
        local function linkId(t)
            if type(t) == "table" then return t.id end
            if t ~= nil and type(t) ~= "boolean" then return t end
            return nil
        end
        pcall(function()
            local t = sm:GetLinkTarget("alignment")
            System.LogAlways("[CampForge] GetLinkTarget('alignment') answered " .. type(t) .. ": " .. tostring(t))
            local id = linkId(t)
            if id and id ~= holder.id then origTarget = id end
        end)
        -- A holder of OURS left over from an earlier camp (or a save) is not the answer.
        if origTarget then
            local t
            pcall(function() t = System.GetEntity(origTarget) end)
            local nm = ""
            pcall(function() nm = t and t:GetName() or "" end)
            if string.find(nm, "MercCampForgeAlign_", 1, true) then origTarget = nil end
        end
        if not origTarget then origTarget = self:ForgeVillageHolder(sm, holder.id) end
        System.LogAlways("[CampForge] Smithery alignment link " .. (origTarget and ("captured (" .. tostring(origTarget) .. ")") or "not readable - keeping the saved id"))
        if origTarget then
            rec.alignTargetId = origTarget
            pcall(function() self:SaveString("CampForgeAlignId", tostring(origTarget)) end)
        else
            local sid
            pcall(function() sid = self:LoadString("CampForgeAlignId") end)
            rec.alignTargetId = tonumber(sid)
        end
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

-- The village Smithery's own SmartObjectHolder, found among its links whatever the link is
-- called. Measured 2026-09-22 (merc_smithery_dump): after a camp forge the 'alignment' link
-- points at OUR holder (MercCampForgeAlign_*, never saved - so after a load it points at
-- nothing, and GetLinkTarget answers nil), while an UNNAMED link still points at the
-- smithy's original "smartObjectHolder[profession/blacksmith/...]". That entity is what the
-- alignment link has to be given back, and it is findable even from a save in which the
-- capture had already been lost.
function mercenaries:ForgeVillageHolder(sm, skipId)
    local found
    pcall(function()
        local n = sm:CountLinks() or 0
        for i = 0, n - 1 do
            local l = sm:GetLink(i)
            if l and l.id and l.id ~= skipId then
                local cls, nm = "", ""
                pcall(function() cls = l.class or (l.GetClass and l:GetClass()) or "" end)
                pcall(function() nm = l.GetName and l:GetName() or "" end)
                if cls == "SmartObjectHolder" and not string.find(nm, "MercCampForgeAlign_", 1, true) then
                    found = l.id
                end
            end
        end
    end)
    return found
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
    if not rec.alignTargetId and rec.sm then
        rec.alignTargetId = self:ForgeVillageHolder(rec.sm, rec.holder and rec.holder.id)
    end
    if rec.alignTargetId then
        -- The village TagPoint gets its Smithery back; the holder can go.
        local ok = pcall(function() rec.sm:SetLinkTarget("alignment", rec.alignTargetId) end)
        if ok and rec.holder then pcall(function() System.RemoveEntity(rec.holder.id) end) end
        pcall(function() self:SaveString("CampForgeAlignId", "-") end)
        System.LogAlways("[CampForge] Smithery re-linked to its own alignment point")
    elseif rec.holder then
        if rec.alignOrig then pcall(function() rec.holder:SetWorldPos(rec.alignOrig) end)
        else pcall(function() rec.holder:SetWorldPos(rec.smPos) end) end
    end
    -- Remove the smith's bench (stool prop + seat smart object).
    for _, entId in ipairs(rec.smithSeatIds or {}) do
        pcall(function() System.RemoveEntity(entId) end)
    end
    self.CampForge = nil
    self:StationHomeForget("CampForgeHome")
    for _, v in ipairs(rec.visuals or {}) do
        if v.homeKey then self:StationHomeForget(v.homeKey) end
    end
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
        if player and rec.smPos and not rec.noAutoPack then
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
