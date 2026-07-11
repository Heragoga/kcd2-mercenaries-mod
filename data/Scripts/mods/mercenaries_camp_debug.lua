-- =======================================================================
-- MERCENARY CAMP - debug / diagnostic helpers
--
-- Loaded after mercenaries_camp.lua. Everything here is console-only tooling
-- for inspecting the camp activity system; none of it runs during normal play.
--
--   merc_camp_activity_list            - print the activity catalogue
--   merc_camp_activity_test <n|name>   - spawn + play one activity on a merc
--   merc_camp_activity_test_clear      - stop it and remove the props
--   merc_camp_furniture_debug          - dump sit/sleep smart-object state
--   merc_camp_scan [radius] [spacing]  - classify ground: flag=valid,
--                                        barrel=tree/rock, crate=building
--   merc_camp_scan_clear               - remove the scan markers
-- =======================================================================
mercenaries.ActivityTestEntities = {}
mercenaries.ScanTestEntities = {}

-- Ground-scan debug markers (see CampScan below), one per class the
-- heightmap classifier (CampClassifyHeightmap) produces:
mercenaries.ScanFlagModel     = "objects/manmade/common_decorations/flags/flag_temporary.cgf"  -- valid ground
mercenaries.ScanBarrelModel   = "objects/manmade/common_furniture/barrels/barrel_a.cgf"        -- small obstacle clump (tree/rock)
mercenaries.ScanBuildingModel = "objects/manmade/common_furniture/crates/crate_box_c.cgf"      -- building-sized clump (the big crate)
-- Default scan grid: (2*radius+1) squared cells, `spacing` metres apart,
-- centred on the player. 12 * 0.5m -> a 25x25 grid spanning ~12m. Both are
-- overridable per-call (merc_camp_scan <radius> <spacing>); the spec was
-- worked out at "merc_camp_scan 21 0.5" (a ~21m field).
mercenaries.ScanGridRadius  = 12
mercenaries.ScanGridSpacing = 0.5

function mercenaries:ListCampActivities()
    System.LogAlways('[Mercenaries] === camp activity catalogue ===')
    for i, a in ipairs(self.CampActivityCatalogue) do
        System.LogAlways(string.format('[Mercenaries]  %2d  %-16s mode=%d  %s', i, a.name, a.mode, tostring(a.note or "")))
    end
    System.LogAlways('[Mercenaries] modes: 1=sit on seat, 2=stand (no prop needed), 3=stand aligned to anchor, 4=duo anim (dead), 5/6=conversation speaker/listener (needs 2 mercs)')
    System.LogAlways('[Mercenaries] usage: merc_camp_activity_test <index or name>')
end

-- Spawns a bare transform anchor for `UnstanceAction locationObject=...`
-- (mode 3). SmartObjectHolder is the vanilla "dummy for a smart object which
-- cannot be attached to real geometry" class; StanceSmartObject derives from
-- it and is the one we already know spawns, so it's the fallback.
function mercenaries:SpawnCampAnchorSO(pos, angleZ, namePrefix)
    local groundPos = self:CampSnapToGround(pos)
    local wuid, ent = nil, nil
    for _, cls in ipairs({ "SmartObjectHolder", "StanceSmartObject" }) do
        pcall(function()
            if wuid then return end
            ent = System.SpawnEntity({
                class = cls,
                name = namePrefix .. "_" .. cls .. "_" .. tostring(math.random(100000, 999999)),
                position = groundPos,
                properties = {}
            })
            if ent then
                pcall(function() ent:SetAngles({ x = 0, y = 0, z = angleZ or 0 }) end)
                wuid = XGenAIModule.GetMyWUID(ent)
                if wuid then
                    table.insert(self.ActivityTestEntities, ent.id)
                    System.LogAlways('[Mercenaries] activity anchor spawned as ' .. cls)
                end
            end
        end)
        if wuid then break end
    end
    if not wuid then
        System.LogAlways('[Mercenaries] could not spawn an activity anchor (neither SmartObjectHolder nor StanceSmartObject)')
    end
    return wuid, groundPos
end

function mercenaries:SpawnCampActivityTest(which)
    if not player then return end

    local ok, err = pcall(function()
        self:ClearCampActivityTest()

        -- Resolve the activity by 1-based index or by name.
        local act = nil
        local n = tonumber(which)
        if n then
            act = self.CampActivityCatalogue[n]
        else
            for _, a in ipairs(self.CampActivityCatalogue) do
                if a.name == tostring(which) then act = a break end
            end
        end
        if not act then
            System.LogAlways('[Mercenaries] unknown activity "' .. tostring(which) .. '" - run merc_camp_activity_list')
            return
        end

        -- Gather live mercs (duo/conversation activities need two).
        local mercs = {}
        for _, ent in pairs(self.ActiveMercs) do
            if ent and self:IsAliveAndWell(ent, false) then table.insert(mercs, ent) end
        end
        local isChat = (act.mode == 5)
        local isDuo = (act.mode == 4)
        local needed = (isChat or isDuo) and 2 or 1
        if #mercs < needed then
            System.LogAlways('[Mercenaries] activity "' .. act.name .. '" needs ' .. needed .. ' merc(s), you have ' .. #mercs)
            return
        end

        local function entWuid(e) return e.this and e.this.id or e.id end

        local origin = player:GetWorldPos()
        local dir = player:GetDirectionVector()
        local spot = self:CampSnapToGround({ x = origin.x + dir.x * 4.0, y = origin.y + dir.y * 4.0, z = origin.z })
        -- Face the merc back toward the player so the animation is visible.
        local faceAngle = math.atan2(-dir.y, -dir.x)

        self.CampActivities = {}

        if isChat then
            -- Conversation: place two mercs facing spot and publish them as a
            -- chat pair - the follow BT's chatRole cases (fed by _G.MercCampChat)
            -- do the GOSSIP polylog, the same path the automatic CampChatTick
            -- pairing uses. No activity records needed.
            local right = { x = -dir.y, y = dir.x }
            local aPos = self:CampSnapToGround({ x = spot.x + right.x * 0.8, y = spot.y + right.y * 0.8, z = spot.z })
            local bPos = self:CampSnapToGround({ x = spot.x - right.x * 0.8, y = spot.y - right.y * 0.8, z = spot.z })
            local aW, bW = entWuid(mercs[1]), entWuid(mercs[2])
            pcall(function() mercs[1]:SetPos(aPos) end)
            pcall(function() mercs[2]:SetPos(bPos) end)
            _G.MercCampChat = { a = aW, b = bW }
            self.CampChatTicks = 0
            System.LogAlways('[Mercenaries] conversation started between ' .. tostring(mercs[1]:GetName()) .. ' and ' .. tostring(mercs[2]:GetName()) .. ' (GOSSIP polylog)')
        elseif isDuo then
            -- Legacy animation-duo (mode 4, confirmed dead); kept only so the
            -- catalogue entry doesn't error if invoked.
            local right = { x = -dir.y, y = dir.x }
            local aPos = self:CampSnapToGround({ x = spot.x + right.x * 0.8, y = spot.y + right.y * 0.8, z = spot.z })
            local bPos = self:CampSnapToGround({ x = spot.x - right.x * 0.8, y = spot.y - right.y * 0.8, z = spot.z })
            local aW, bW = entWuid(mercs[1]), entWuid(mercs[2])
            self.CampActivities[tostring(aW)] = { unstance = act.unstance, mode = 4, pos = aPos, slaveWuid = bW }
            self.CampActivities[tostring(bW)] = { unstance = act.partner, mode = act.partnerMode or 2, pos = bPos, slaveWuid = aW }
            pcall(function() mercs[1]:SetPos(aPos) end)
            pcall(function() mercs[2]:SetPos(bPos) end)
            System.LogAlways('[Mercenaries] activity "' .. act.name .. '" (duo anim, likely dead)')
        else
            local m = mercs[1]
            local mW = entWuid(m)
            local locWuid = nil

            if act.prop then
                self:SpawnCampPropModel(act.prop, spot, faceAngle, "MercActTest_Prop", self.ActivityTestEntities)
            end
            if act.prop2 then
                self:SpawnCampPropModel(act.prop2, spot, faceAngle, "MercActTest_Prop", self.ActivityTestEntities)
            end

            if act.mode == 1 then
                -- Needs a seat smart object to sit on.
                locWuid, spot = self:SpawnCampFurnitureSO(self.CampModels.Stool, spot, faceAngle, "MercActTest_Seat", self.CampChairSO, nil, self.ActivityTestEntities)
            elseif act.mode == 3 then
                locWuid = self:SpawnCampAnchorSO(spot, faceAngle, "MercActTest_Anchor")
            end

            self.CampActivities[tostring(mW)] = { unstance = act.unstance, mode = act.mode, pos = spot, locWuid = locWuid, drawWeapon = act.drawWeapon }
            pcall(function() m:SetPos(spot) end)
            System.LogAlways('[Mercenaries] activity "' .. act.name .. '" mode=' .. act.mode .. ' unstance=' .. tostring(act.unstance) .. ' anchor=' .. tostring(locWuid) .. ' drawWeapon=' .. tostring(act.drawWeapon == true))
        end

        System.LogAlways('[Mercenaries] assigned to ' .. tostring(needed) .. ' merc(s). Note: the merc holds each pose for ~' .. tostring(self.CampActivityHoldSeconds) .. 's, so _clear can take that long to visibly stop it.')
    end)

    if not ok then
        System.LogAlways('[Mercenaries] SpawnCampActivityTest error: ' .. tostring(err))
    end
end

function mercenaries:ClearCampActivityTest()
    local ok, err = pcall(function()
        for _, entId in ipairs(self.ActivityTestEntities) do
            pcall(function() System.RemoveEntity(entId) end)
        end
    end)
    if not ok then
        System.LogAlways('[Mercenaries] ClearCampActivityTest error: ' .. tostring(err))
    end
    self.ActivityTestEntities = {}
    self.CampActivities = {}
    _G.MercCampChat = nil
    self.CampChatTicks = 0
end

-- Dumps the state of the merc sit/sleep pipeline so a failure can be pinned to
-- a specific stage: did the StanceSmartObject entities spawn, did each merc get
-- a furniture assignment with a real WUID, are the camp-state globals set.
function mercenaries:DebugCampFurniture()
    local ok, err = pcall(function()
        System.LogAlways('[Mercenaries] === camp furniture debug ===')
        System.LogAlways('[Mercenaries] MercInCamp=' .. tostring(_G.MercInCamp) .. '  MercIdle=' .. tostring(_G.MercIdle) .. '  CampActive=' .. tostring(self.CampActive))

        local soCount = 0
        local sos = System.GetEntitiesByClass("StanceSmartObject")
        if sos then
            for _, e in pairs(sos) do
                local n = (e and e:GetName()) or ""
                if string.find(n, "MercCampProp_", 1, true) then soCount = soCount + 1 end
            end
        end
        System.LogAlways('[Mercenaries] StanceSmartObject entities spawned by us: ' .. tostring(soCount) .. '  (0 here = the class did not spawn)')

        local assigned, withWuid = 0, 0
        for wuidStr, rec in pairs(self.CampFurniture or {}) do
            assigned = assigned + 1
            if rec.wuid then withWuid = withWuid + 1 end
            System.LogAlways('[Mercenaries]   merc ' .. tostring(wuidStr) .. ' -> ' .. tostring(rec.kind) .. '  wuid=' .. tostring(rec.wuid))
        end
        System.LogAlways('[Mercenaries] furniture assignments: ' .. tostring(assigned) .. ', of which have a WUID: ' .. tostring(withWuid))

        local acts = 0
        for wuidStr, a in pairs(self.CampActivities or {}) do
            acts = acts + 1
            System.LogAlways('[Mercenaries]   merc ' .. tostring(wuidStr) .. ' -> activity ' .. tostring(a.unstance) .. ' (mode ' .. tostring(a.mode) .. ')')
        end
        System.LogAlways('[Mercenaries] activity assignments: ' .. tostring(acts))

        local guards = 0
        for _ in pairs(self.CampPatrollers or {}) do guards = guards + 1 end
        System.LogAlways('[Mercenaries] guards (patrollers): ' .. tostring(guards))
    end)
    if not ok then
        System.LogAlways('[Mercenaries] DebugCampFurniture error: ' .. tostring(err))
    end
end

-- =======================================================================
-- GROUND SCAN - visualise the phase-1 heightmap classifier.
--
-- Samples a dense 0.5m heightmap centred on the player (CampSampleHeightmap),
-- runs the connectivity classifier from the player's own cell
-- (CampClassifyHeightmap), and drops a colour-coded marker per cell:
--   FLAG   -> valid ground (walkable surface connected to where you stand;
--             gentle slopes included)
--   BARREL -> small obstacle clump (<= CampSmallClumpMax cells): tree, rock
--   CRATE  -> building-sized clump (> CampSmallClumpMax): wall / building
--   (void) -> no ground under the column: no marker, counted only
--
-- Valid flags sit at their sampled ground height so you can read the slope;
-- obstacle markers sit at the player's level so a wall/tree reads as a line at
-- eye height regardless of how tall it is. merc_camp_scan_clear removes them.
--
-- NOTE: this is the phase-1 DETECTOR. The real camp spawn still uses the
-- simpler per-cluster CampValidateSpot for now; wiring tile selection onto this
-- classifier is phase 2. So the scan can legitimately show more nuance (trees
-- vs buildings) than the current live camp acts on.
--
-- Usage: merc_camp_scan [radius] [spacing]   (spec was worked out at "21 0.5")
-- =======================================================================
function mercenaries:CampScan(radius, spacing)
    if not player then return end
    radius  = tonumber(radius)  or self.ScanGridRadius
    spacing = tonumber(spacing) or self.ScanGridSpacing
    radius  = math.max(1, math.min(radius, 25))   -- (2*25+1)^2 = 2601 markers - keep it bounded

    local ok, err = pcall(function()
        self:ClearCampScan()

        local origin = player:GetWorldPos()
        local refZ = origin.z

        -- Detect under-roof: if so, the sampler flags every column that hits a
        -- roof (the building footprint) as invalid, while columns outside the
        -- walls stay valid ground - same as the real camp spawn, which then
        -- forms the camp on that open ground.
        local underRoof, ceilingZ = self:CampDetectRoof(origin)

        -- Sample + classify (seed = centre cell = the player's own feet).
        local hm = self:CampSampleHeightmap(origin, radius, spacing, underRoof)
        local cls, counts = self:CampClassifyHeightmap(hm, radius, radius)

        -- Direct BasicEntity spawn (no re-snapping) so we control each marker's
        -- exact height: valid on the ground, obstacles at player level.
        local function mark(model, wx, wy, wz, prefix)
            local ent = System.SpawnEntity({
                class = "BasicEntity",
                name = prefix .. "_" .. tostring(math.random(100000, 999999)),
                position = { x = wx, y = wy, z = wz },
                properties = { object_Model = model, bMissionCritical = false },
            })
            if ent then table.insert(self.ScanTestEntities, ent.id) end
        end

        for i = 0, 2 * radius do
            for j = 0, 2 * radius do
                local wx = origin.x + (i - radius) * spacing
                local wy = origin.y + (j - radius) * spacing
                local c = cls[i][j]
                if c == "valid" then
                    mark(self.ScanFlagModel, wx, wy, hm.z[i][j], "MercCampScan_Flag")
                elseif c == "small" then
                    mark(self.ScanBarrelModel, wx, wy, refZ, "MercCampScan_Barrel")
                elseif c == "building" then
                    mark(self.ScanBuildingModel, wx, wy, refZ, "MercCampScan_Crate")
                end
                -- "void": no marker.
            end
        end

        local total = (2 * radius + 1) * (2 * radius + 1)
        local roofNote = underRoof and string.format(" [UNDER-ROOF: ceiling +%.1fm, building columns marked invalid (crate)]", (ceilingZ or refZ) - refZ) or ""
        System.LogAlways(string.format(
            "[Mercenaries] camp scan: %dx%d @ %.2fm (%d cells / rays) -> valid %d (flag), small-clump %d (barrel), building %d (crate), void %d%s",
            radius * 2 + 1, radius * 2 + 1, spacing, total,
            counts.valid, counts.small, counts.building, counts.void, roofNote))
        Game.SendInfoText(string.format(
            "Camp scan%s: %d valid / %d tree / %d building / %d void",
            underRoof and " (indoors)" or "", counts.valid, counts.small, counts.building, counts.void), false, nil, 5)
    end)
    if not ok then
        System.LogAlways("[Mercenaries] CampScan error: " .. tostring(err))
    end
end

function mercenaries:ClearCampScan()
    for _, id in ipairs(self.ScanTestEntities or {}) do
        pcall(function() System.RemoveEntity(id) end)
    end
    self.ScanTestEntities = {}
end

System.AddCCommand("merc_camp_scan", "mercenaries:CampScan(%1, %2)", "Probe a grid around you with the camp ground validator: flag = valid spot, barrel = rejected. Usage: merc_camp_scan [radius] [spacing]")
System.AddCCommand("merc_camp_scan_clear", "mercenaries:ClearCampScan()", "Remove the merc_camp_scan markers")
System.AddCCommand("merc_camp_activity_list", "mercenaries:ListCampActivities()", "List the camp activity catalogue (index, name, mode) for merc_camp_activity_test")
System.AddCCommand("merc_camp_activity_test", "mercenaries:SpawnCampActivityTest(%1)", "Spawn what an activity needs and make a merc play it. Usage: merc_camp_activity_test <index or name>")
System.AddCCommand("merc_camp_activity_test_clear", "mercenaries:ClearCampActivityTest()", "Stop the activity test and remove its props")
System.AddCCommand("merc_camp_furniture_debug", "mercenaries:DebugCampFurniture()", "Dump the merc sit/sleep smart-object state (spawned SOs, per-merc assignments, guard count)")
