-- Console-only debug tooling for the camp activity/ground systems; none of it
-- runs during normal play. Command descriptions are on the AddCCommands below.
mercenaries.ActivityTestEntities = {}
mercenaries.ScanTestEntities = {}

-- Ground-scan markers, one per class CampClassifyHeightmap produces.
mercenaries.ScanFlagModel     = "objects/manmade/common_decorations/flags/flag_temporary.cgf"  -- valid ground
mercenaries.ScanBarrelModel   = "objects/manmade/common_furniture/barrels/barrel_a.cgf"        -- small obstacle clump (tree/rock)
mercenaries.ScanBuildingModel = "objects/manmade/common_furniture/crates/crate_box_c.cgf"      -- building-sized clump
-- Default scan grid, overridable per-call; spec was worked out at "21 0.5".
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

-- Spawn a bare transform anchor for mode-3 `UnstanceAction locationObject=...`,
-- preferring SmartObjectHolder with StanceSmartObject as the proven fallback.
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
            -- Conversation: publish the pair as _G.MercCampChat; the follow BT's
            -- chatRole cases run the GOSSIP polylog (same path as CampChatTick).
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

-- === WHY A SITTER FLOATS ABOVE HIS LOG ===
--
-- Three heights have to agree and one report says they do not, so measure all three rather
-- than reason about them. Per seat:
--   prop   the visible stump's own world z
--   SO     the StanceSmartObject's world z - the seated pose's floor, since the
--          Sit_1Place_Bench_Low helper's Place0 is at 0,0,0 (references/Libs/SmartObjects.xml)
--          and all the seat height lives in the animation
--   merc   the occupant's world z, which is the one the player actually sees
--   top    the topmost physics surface at that column, and its material
--   terr   the ent_terrain ray's height and material - what CampSnapToGround placed on
-- Read-only: no entity is spawned, moved or removed. Run it while a merc is visibly floating.
function mercenaries:SeatProbe()
    local ok, err = pcall(function()
        local function z(e)
            local p
            pcall(function() p = e and e:GetWorldPos() end)
            return p and p.z or nil
        end
        local function f(v) return v and string.format("%.2f", v) or "--" end

        -- Occupant key -> entity, so a seat can name the man on it.
        local byKey = {}
        for _, e in pairs(self.ActiveMercs or {}) do
            local ka, kb = self:CampMercKeys(e)
            if ka then byKey[ka] = e end
            if kb then byKey[kb] = e end
        end

        -- Every stump prop and every smart object we spawned, by name, so a seat can be
        -- paired with both even if GetEntityByWUID declines a smart-object holder handle.
        local props, soEnts = {}, {}
        for _, id in ipairs(self.CampEntities or {}) do
            local e
            pcall(function() e = System.GetEntity(id) end)
            local n = e and e:GetName() or ""
            local pp
            pcall(function() pp = e and e:GetWorldPos() end)
            if pp then
                if string.find(n, "_SO_", 1, true) then
                    table.insert(soEnts, { x = pp.x, y = pp.y, z = pp.z, n = n })
                elseif string.find(n, "LogSO", 1, true) then
                    table.insert(props, { x = pp.x, y = pp.y, z = pp.z, n = n })
                end
            end
        end
        local function nearest(list, x, y)
            local best, bestD = nil, 9999
            for _, q in ipairs(list) do
                local dx, dy = q.x - (x or 0), q.y - (y or 0)
                local d = dx * dx + dy * dy
                if d < bestD then bestD, best = d, q end
            end
            return best, math.sqrt(bestD)
        end

        System.LogAlways('[SeatProbe] === seats: ' .. tostring(#(self.CampSeats or {})) ..
                         ', stump props found: ' .. tostring(#props) .. ' ===')
        local pz = z(player)
        System.LogAlways('[SeatProbe] player z=' .. f(pz) ..
                         '  ground guard ' .. (self.GroundGuard and 'on' or 'OFF'))

        for i, seat in ipairs(self.CampSeats or {}) do
            local sp = seat.pos or {}
            local soEnt
            pcall(function() soEnt = XGenAIModule.GetEntityByWUID(seat.wuid) end)
            local soZ = z(soEnt)
            local soNear = nearest(soEnts, sp.x, sp.y)
            if not soZ then soZ = soNear and soNear.z end
            local best, bestD = nearest(props, sp.x, sp.y)

            local topZ, topS, terrZ, terrS
            pcall(function()
                local hits = self:GroundRawHits(sp.x, sp.y, sp.z or 0, nil, 1)
                if hits[1] and hits[1].pos then topZ, topS = hits[1].pos.z, hits[1].surface end
                terrZ, terrS = self:GroundTerrainAt(sp.x, sp.y, sp.z or 0)
            end)

            local occ = seat.occupant and byKey[tostring(seat.occupant)]
            local mz = z(occ)
            local gap = (mz and soZ) and (mz - soZ) or nil

            System.LogAlways(string.format(
                '[SeatProbe] %2d%s stored=%s SO=%s prop=%s(%.2fm away) top=%s/%s terr=%s/%s merc=%s gap=%s %s',
                i, seat.tavern and ' TAVERN' or '',
                f(sp.z), f(soZ), f(best and best.z), bestD,
                f(topZ), tostring(topS), f(terrZ), tostring(terrS),
                f(mz), f(gap),
                seat.occupant and ((occ and occ:GetName() or 'occupant not in ActiveMercs')) or 'free'))
        end
        System.LogAlways('[SeatProbe] gap is merc z minus smart object z. A seated merc should read about 0.')
    end)
    if not ok then System.LogAlways('[SeatProbe] error: ' .. tostring(err)) end
end

-- The snapshot above needs the player to catch a floater. This watches instead: once a
-- second it compares every occupied seat's smart object z with the man on it and logs only
-- the ones clearly off. Read-only; merc_seat_watch again to stop.
mercenaries.SeatWatchOn  = false
mercenaries.SeatWatchTol = 0.25     -- metres of disagreement worth a line
mercenaries.SeatWatchSaid = {}

function mercenaries:SeatWatchTick()
    if not self.SeatWatchOn then return end
    -- Engine time runs ~29x fast through a sleep/wait, so pace the work on the wall clock
    -- and let the timer itself fire as often as it likes (see docs/performance.md).
    local now = (os and os.clock) and os.clock() or nil
    local due = (not now) or (not self.SeatWatchLast) or (now - self.SeatWatchLast) >= 1.0
    if due then
    self.SeatWatchLast = now
    pcall(function()
        local byKey = {}
        for _, e in pairs(self.ActiveMercs or {}) do
            local ka, kb = self:CampMercKeys(e)
            if ka then byKey[ka] = e end
            if kb then byKey[kb] = e end
        end
        for i, seat in ipairs(self.CampSeats or {}) do
            local occ = seat.occupant and byKey[tostring(seat.occupant)]
            if occ then
                local soEnt, mp, sp
                pcall(function() soEnt = XGenAIModule.GetEntityByWUID(seat.wuid) end)
                pcall(function() mp = occ:GetWorldPos() end)
                pcall(function() sp = soEnt and soEnt:GetWorldPos() end)
                if mp and sp then
                    local dz = mp.z - sp.z
                    local flat = (mp.x - sp.x) ^ 2 + (mp.y - sp.y) ^ 2
                    -- Only while he is actually AT the seat: a man still walking to it is
                    -- allowed to be at a different height.
                    if flat < 1.5 and math.abs(dz) > self.SeatWatchTol then
                        local k = tostring(i) .. ':' .. string.format('%.1f', dz)
                        if not self.SeatWatchSaid[k] then
                            self.SeatWatchSaid[k] = true
                            System.LogAlways(string.format(
                                '[SeatProbe] FLOATER seat %d: %s is %.2fm off his smart object (%.2fm away flat), merc z=%.2f SO z=%.2f',
                                i, tostring(occ:GetName()), dz, math.sqrt(flat), mp.z, sp.z))
                        end
                    end
                end
            end
        end
    end)
    end
    Script.SetTimerForFunction(1000, "mercenaries.SeatWatchTick")
end

function mercenaries:SeatWatchToggle()
    self.SeatWatchOn = not self.SeatWatchOn
    self.SeatWatchSaid = {}
    self.SeatWatchLast = nil
    System.LogAlways('[SeatProbe] seat watch ' .. (self.SeatWatchOn and 'ON - floaters will be logged' or 'off'))
    if self.SeatWatchOn then self:SeatWatchTick() end
end

-- Visualise the heightmap classifier (see docs/camp.md "Ground validation"):
-- drops a marker per cell - flag = valid ground (at its real height, so slope
-- reads), barrel = small clump (tree/rock), crate = building; void = no marker.
-- This is only the detector; the live camp spawn still uses per-cluster
-- CampValidateSpot, so the scan can show more nuance than the camp acts on.
function mercenaries:CampScan(radius, spacing)
    if not player then return end
    radius  = tonumber(radius)  or self.ScanGridRadius
    spacing = tonumber(spacing) or self.ScanGridSpacing
    radius  = math.max(1, math.min(radius, 25))   -- (2*25+1)^2 = 2601 markers - keep it bounded

    local ok, err = pcall(function()
        self:ClearCampScan()

        local origin = player:GetWorldPos()
        local refZ = origin.z

        -- Under a roof, the sampler marks columns that hit it (the footprint)
        -- invalid while open ground outside the walls stays valid.
        local underRoof, ceilingZ = self:CampDetectRoof(origin)

        local hm = self:CampSampleHeightmap(origin, radius, spacing, underRoof)
        local cls, counts = self:CampClassifyHeightmap(hm, radius, radius)

        -- Direct spawn (no re-snap) so we set each marker's height exactly.
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

        -- How many cells the ground guard took out on its own, so the scan says whether a
        -- gap in the flags is a step the classifier refused or a material it did.
        local objCells = 0
        for i = 0, 2 * radius do
            for j = 0, 2 * radius do
                if hm.obj and hm.obj[i] and hm.obj[i][j] then objCells = objCells + 1 end
            end
        end

        local total = (2 * radius + 1) * (2 * radius + 1)
        local roofNote = underRoof and string.format(" [UNDER-ROOF: ceiling +%.1fm, building columns marked invalid (crate)]", (ceilingZ or refZ) - refZ) or ""
        System.LogAlways(string.format(
            "[Mercenaries] camp scan: %dx%d @ %.2fm (%d cells / rays) -> valid %d (flag), small-clump %d (barrel), building %d (crate), void %d%s; %d cell(s) are made of something the ground there is not (ground guard %s)",
            radius * 2 + 1, radius * 2 + 1, spacing, total,
            counts.valid, counts.small, counts.building, counts.void, roofNote,
            objCells, mercenaries.GroundGuard and "on" or "OFF"))
        Game.SendInfoText(string.format(
            "@merc_logi_msg Camp scan%s: %d valid / %d tree / %d building / %d void",
            underRoof and " (indoors)" or "", counts.valid, counts.small, counts.building, counts.void), false, 0, 5)
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

mercenaries:DevCommand("merc_camp_scan", "mercenaries:CampScan(%1, %2)", "Probe a grid around you with the camp ground validator: flag = valid spot, barrel = rejected. Usage: merc_camp_scan [radius] [spacing]")
mercenaries:DevCommand("merc_camp_scan_clear", "mercenaries:ClearCampScan()", "Remove the merc_camp_scan markers")
mercenaries:DevCommand("merc_camp_activity_list", "mercenaries:ListCampActivities()", "List the camp activity catalogue (index, name, mode) for merc_camp_activity_test")
mercenaries:DevCommand("merc_camp_activity_test", "mercenaries:SpawnCampActivityTest(%1)", "Spawn what an activity needs and make a merc play it. Usage: merc_camp_activity_test <index or name>")
mercenaries:DevCommand("merc_camp_activity_test_clear", "mercenaries:ClearCampActivityTest()", "Stop the activity test and remove its props")
mercenaries:PlayerCommand("merc_seat_probe", "mercenaries:SeatProbe()", "Measure every camp seat: stump z, smart object z, seated merc z, and the ground under it")
mercenaries:PlayerCommand("merc_seat_watch", "mercenaries:SeatWatchToggle()", "Watch occupied seats once a second and log any merc sitting clear of his smart object")
mercenaries:DevCommand("merc_camp_furniture_debug", "mercenaries:DebugCampFurniture()", "Dump the merc sit/sleep smart-object state (spawned SOs, per-merc assignments, guard count)")
