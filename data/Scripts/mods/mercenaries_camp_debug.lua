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
-- =======================================================================
mercenaries.ActivityTestEntities = {}

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

System.AddCCommand("merc_camp_activity_list", "mercenaries:ListCampActivities()", "List the camp activity catalogue (index, name, mode) for merc_camp_activity_test")
System.AddCCommand("merc_camp_activity_test", "mercenaries:SpawnCampActivityTest(%1)", "Spawn what an activity needs and make a merc play it. Usage: merc_camp_activity_test <index or name>")
System.AddCCommand("merc_camp_activity_test_clear", "mercenaries:ClearCampActivityTest()", "Stop the activity test and remove its props")
System.AddCCommand("merc_camp_furniture_debug", "mercenaries:DebugCampFurniture()", "Dump the merc sit/sleep smart-object state (spawned SOs, per-merc assignments, guard count)")
