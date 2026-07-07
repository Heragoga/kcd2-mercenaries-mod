kcdcompanion = {}

kcdcompanion.SoulId = "c0a9a0b1-0004-4c0a-9a01-0000000c0004"
kcdcompanion.SoulIds = {
    "c0a9a0b1-0004-4c0a-9a01-0000000c0004", "c0a9a0b1-0004-4c0a-9a01-0000000c0005",
    "c0a9a0b1-0004-4c0a-9a01-0000000c0006", "c0a9a0b1-0004-4c0a-9a01-0000000c0007",
    "c0a9a0b1-0004-4c0a-9a01-0000000c0008", "c0a9a0b1-0004-4c0a-9a01-0000000c0009",
    "c0a9a0b1-0004-4c0a-9a01-0000000c000a", "c0a9a0b1-0004-4c0a-9a01-0000000c000b",
    "c0a9a0b1-0004-4c0a-9a01-0000000c000c", "c0a9a0b1-0004-4c0a-9a01-0000000c000d",
}
kcdcompanion.SpawnCursor = 0
kcdcompanion.ClothingPreset = {
    ["c0a9a0b1-0004-4c0a-9a01-0000000c0004"] = "c0a9a0b1-c101-4c0a-9a01-0000000cd001",
    ["c0a9a0b1-0004-4c0a-9a01-0000000c0005"] = "c0a9a0b1-c101-4c0a-9a01-0000000cd002",
    ["c0a9a0b1-0004-4c0a-9a01-0000000c0006"] = "c0a9a0b1-c101-4c0a-9a01-0000000cd003",
    ["c0a9a0b1-0004-4c0a-9a01-0000000c0007"] = "c0a9a0b1-c101-4c0a-9a01-0000000cd004",
    ["c0a9a0b1-0004-4c0a-9a01-0000000c0008"] = "c0a9a0b1-c101-4c0a-9a01-0000000cd005",
    ["c0a9a0b1-0004-4c0a-9a01-0000000c0009"] = "c0a9a0b1-c101-4c0a-9a01-0000000cd006",
    ["c0a9a0b1-0004-4c0a-9a01-0000000c000a"] = "c0a9a0b1-c101-4c0a-9a01-0000000cd007",
    ["c0a9a0b1-0004-4c0a-9a01-0000000c000b"] = "c0a9a0b1-c101-4c0a-9a01-0000000cd008",
    ["c0a9a0b1-0004-4c0a-9a01-0000000c000c"] = "c0a9a0b1-c101-4c0a-9a01-0000000cd009",
    ["c0a9a0b1-0004-4c0a-9a01-0000000c000d"] = "c0a9a0b1-c101-4c0a-9a01-0000000cd00a",
}
kcdcompanion.Spawned = {}
kcdcompanion.SquadMax = 10

kcdcompanion.StatePrefix = 'kcdcompanion_state_'

function kcdcompanion:SaveString(tag, value)
    pcall(function()
        if not tag or tag == '' or value == nil or tostring(value) == '' then return end
        local prefix = self.StatePrefix .. tag .. '__'
        for _, e in pairs(System.GetEntitiesByClass('BasicEntity') or {}) do
            local nm = e.GetName and e:GetName()
            if nm and string.sub(nm, 1, #prefix) == prefix then System.RemoveEntity(e.id) end
        end
        System.SpawnEntity({ class = 'BasicEntity', name = prefix .. tostring(value),
            position = { x = 0, y = 0, z = -100 }, orientation = { x = 0, y = 0, z = 0 } })
    end)
end

function kcdcompanion:LoadString(tag)
    local result = nil
    pcall(function()
        local prefix = self.StatePrefix .. tag .. '__'
        for _, e in pairs(System.GetEntitiesByClass('BasicEntity') or {}) do
            local nm = e.GetName and e:GetName()
            if nm and string.sub(nm, 1, #prefix) == prefix then
                result = string.sub(nm, #prefix + 1)
                break
            end
        end
    end)
    return result
end

function kcdcompanion:SaveState()
    pcall(function()
        local idx = {}
        for name, _ in pairs(self.Spawned) do
            if System.GetEntityByName(name) then
                local sid = string.match(name, 'kcdcompanion_(.-)_%d+$')
                for i, g in ipairs(self.SoulIds) do if g == sid then table.insert(idx, i) end end
            end
        end
        table.sort(idx)
        self:SaveString('roster', (#idx > 0) and table.concat(idx, '-') or 'x')
        self:SaveString('flags', (_G.CompanionWait and '1' or '0') .. (_G.CompanionAggro and '1' or '0'))
    end)
end

function kcdcompanion.RestoreSquad()
    pcall(function()
        pcall(function()
            for _, e in pairs(System.GetEntitiesByClass('NPC') or {}) do
                local nm = e.GetName and e:GetName()
                if nm and string.find(nm, 'kcdcompanion_', 1, true) and not kcdcompanion.Spawned[nm] then
                    System.RemoveEntity(e.id)
                    System.LogAlways('[companion] RESTORE: removed ghost ' .. nm)
                end
            end
            for _, e in pairs(System.GetEntitiesByClass('Horse') or {}) do
                local nm = e.GetName and e:GetName()
                if nm and string.find(nm, 'CompanionHorse_', 1, true) then System.RemoveEntity(e.id) end
            end
        end)
        local r = kcdcompanion:LoadString('roster')
        if not r or r == 'x' or r == '' then return end
        local present = {}
        for name, _ in pairs(kcdcompanion.Spawned) do
            if System.GetEntityByName(name) then
                local sid = string.match(name, 'kcdcompanion_(.-)_%d+$')
                for i, g in ipairs(kcdcompanion.SoulIds) do if g == sid then present[i] = true end end
            end
        end
        local wanted, missing = 0, 0
        for idxStr in string.gmatch(r, '[^-]+') do
            local i = tonumber(idxStr)
            if i and kcdcompanion.SoulIds[i] then
                wanted = wanted + 1
                if not present[i] then
                    missing = missing + 1
                    kcdcompanion.SpawnCursor = i - 1
                    kcdcompanion:SpawnCompanion(2.0 + wanted * 1.2)
                end
            end
        end
        System.LogAlways('[companion] RESTORE: roster=' .. r .. ' missing=' .. missing)
        if missing > 0 and not kcdcompanion._restoreRetried then
            kcdcompanion._restoreRetried = true
            Script.SetTimerForFunction(4000, "kcdcompanion.RestoreSquad")
        end
    end)
end

System.LogAlways("[companion] kcdcompanion.lua LOADED")

function kcdcompanion:OnGameplayStarted(actionName, eventName, argTable)
    System.LogAlways("[companion] OnGameplayStarted - mod ready")

    local okBind = pcall(function()
        System.ExecuteCommand("bind f5 companion_menu")
        System.ExecuteCommand("bind f6 companion_mode")
        System.ExecuteCommand("bind f7 companion_summon")
        System.ExecuteCommand("bind f8 companion_toggle")
        System.ExecuteCommand("bind f9 companion_regroup")
        System.ExecuteCommand("bind f10 companion_order")
        System.ExecuteCommand("bind f11 companion_remove")
    end)
    System.LogAlways("[companion] keybinds F5-F11: " .. (okBind and "OK" or "FAILED - use console commands"))

    if not kcdcompanion._loopsStarted then
        kcdcompanion._loopsStarted = true
        Script.SetTimerForFunction(1500, "kcdcompanion.FormationTick")
        Script.SetTimerForFunction(2000, "kcdcompanion.EnemyCacheTick")
        Script.SetTimerForFunction(1500, "kcdcompanion.HorseTick")
        Script.SetTimerForFunction(5000, "kcdcompanion.ChatTick")
    end

    kcdcompanion.MenuReady = true
    kcdcompanion.MenuPaused = false
    if kcdcompanion.MenuOpen then pcall(function() kcdcompanion:MenuClose() end) end
    if not kcdcompanion._menuHooked then
        kcdcompanion._menuHooked = true
        pcall(function() PlayerEventDispatcher:Register("OnActionEvent", kcdcompanion.MenuActionListener) end)
    end

    kcdcompanion.Spawned = {}
    kcdcompanion._restoreRetried = false
    _G.CompanionOrders = {}
    _G.CompanionRage = {}
    _G.CompanionRecall = false
    _G.CompanionChat = nil
    _G.CompanionSpeakLock = false
    _G.CompanionVictim = nil
    pcall(function()
        local boot = tonumber(kcdcompanion:LoadString('boot') or '0') + 1
        kcdcompanion:SaveString('boot', tostring(boot))
        System.LogAlways('[companion] STATE boot=' .. boot .. ' (counter survived save/load = KV works)')
        local f = kcdcompanion:LoadString('flags')
        if f then
            _G.CompanionWait = (string.sub(f, 1, 1) == '1')
            _G.CompanionAggro = (string.sub(f, 2, 2) == '1')
            System.LogAlways('[companion] STATE flags: wait=' .. tostring(_G.CompanionWait) .. ' aggro=' .. tostring(_G.CompanionAggro))
        end
    end)
    Script.SetTimerForFunction(2500, "kcdcompanion.RestoreSquad")
end

function kcdcompanion.SpawnCompanionTimer()
    kcdcompanion:SpawnCompanion()
end

function kcdcompanion:GetSafeSpawnPosition(pe, distance)
    if not pe then return nil, nil end
    distance = distance or 3

    local origin = pe:GetWorldPos()
    local facing = pe:GetDirectionVector()
    local rot    = pe:GetAngles()
    if not origin or not facing or (facing.x == 0 and facing.y == 0) then
        return nil, nil
    end

    local backAngle = math.atan2(-facing.y, -facing.x)
    local offsetsDeg = { 0, 45, -45, 90, -90, 135, -135, 180 }
    local eye = { x = origin.x, y = origin.y, z = origin.z + 1.5 }

    local spawnPos = nil
    for _, deg in ipairs(offsetsDeg) do
        local a = backAngle + math.rad(deg)
        local dir = { x = math.cos(a), y = math.sin(a) }
        local ray = { x = dir.x * (distance + 1), y = dir.y * (distance + 1), z = 0 }
        local hits = {}
        local n = Physics.RayWorldIntersection(eye, ray, 2, ent_terrain + ent_static, pe, nil, hits)
        local blocked = (n and n > 0) and hits[1] and hits[1].dist and hits[1].dist < distance
        if not blocked then
            spawnPos = { x = origin.x + dir.x * distance, y = origin.y + dir.y * distance, z = origin.z }
            break
        end
    end
    if not spawnPos then
        spawnPos = { x = origin.x + math.cos(backAngle) * 0.8, y = origin.y + math.sin(backAngle) * 0.8, z = origin.z }
    end

    local ghits = {}
    local gn = Physics.RayWorldIntersection({ x = spawnPos.x, y = spawnPos.y, z = spawnPos.z + 3.0 },
        { x = 0, y = 0, z = -30 }, 2, ent_terrain + ent_static, 0, nil, ghits)
    if gn and gn > 0 and ghits[1] and ghits[1].pos then spawnPos.z = ghits[1].pos.z end

    return spawnPos, rot
end

function kcdcompanion:SpawnCompanion(distance)
    local ok, err = pcall(function()
        local spawnPos, playerRot = self:GetSafeSpawnPosition(player, distance or 3)
        if not spawnPos then
            System.LogAlways("[companion] No safe spawn position (cutscene/terrain?)")
            return
        end

        self.SpawnCursor = (self.SpawnCursor or 0) + 1
        local soulId = self.SoulIds[((self.SpawnCursor - 1) % #self.SoulIds) + 1]
        local name = "kcdcompanion_" .. soulId .. "_" .. tostring(math.random(10000, 99999))
        System.SpawnEntity({
            class       = "NPC",
            name        = name,
            position    = spawnPos,
            orientation = { x = 0, y = 0, z = playerRot.z },
            properties  = { guidSharedSoulId = soulId, bSaved_by_game = false },
        })

        local ent = System.GetEntityByName(name)
        if ent then
            self.Spawned[name] = ent
            local presetId = self.ClothingPreset[soulId]
            if presetId then pcall(function() ent.actor:EquipClothingPreset(presetId) end) end
            pcall(function() ent.inventory:CreateItem('5ef63059-322e-4e1b-abe8-926e100c770e', 100, 10000) end)
            pcall(function() ent.inventory:CreateItem('e95bb3ae-38ce-41fd-948a-e471673b47e5', 100, 1) end)
            self:InjectInteraction(ent)
            pcall(function() Script.SetTimerForFunction(800, "kcdcompanion.RedressAll") end)
            System.LogAlways("[companion] Spawned: " .. name)
        else
            System.LogAlways("[companion] SPAWN FAILED (check soul/appearance): " .. name)
        end
    end)
    if not ok then System.LogAlways("[companion] SpawnCompanion error: " .. tostring(err)) end
end

function kcdcompanion.RedressAll()
    pcall(function()
        for nm, _ in pairs(kcdcompanion.Spawned) do
            local e = System.GetEntityByName(nm)
            if e and e.actor then
                local sid = string.match(nm, "kcdcompanion_(.-)_%d+$")
                local preset = sid and kcdcompanion.ClothingPreset[sid]
                if preset then pcall(function() e.actor:EquipClothingPreset(preset) end) end
            end
        end
    end)
end

function kcdcompanion:CountSquad()
    local n = 0
    local purged = false
    for name, _ in pairs(self.Spawned) do
        local ent = System.GetEntityByName(name)
        local dead = true
        if ent and ent.actor then
            dead = (ent.actor.IsDead and ent.actor:IsDead()) or false
            if not dead then
                local ok, h = pcall(function() return ent.soul:GetState('health') end)
                if ok and h ~= nil and h <= 0 then dead = true end
            end
        end
        if ent and not dead then
            n = n + 1
        else
            self.Spawned[name] = nil
            if _G.CompanionOrders then _G.CompanionOrders[name] = nil end
            if _G.CompanionRage then _G.CompanionRage[name] = nil end
            purged = true
        end
    end
    if purged then pcall(function() self:SaveState() end) end
    return n
end

function kcdcompanion:SummonOne(silent)
    local n = self:CountSquad()
    if n >= self.SquadMax then
        if not silent then pcall(function() Game.SendInfoText("ui_squad_full", false, 0, 1) end) end
        System.LogAlways("[companion] Squad full: " .. n .. "/" .. self.SquadMax)
        return
    end
    self:SpawnCompanion(2.5 + n * 1.3)
    local now = self:CountSquad()
    self:SaveState()
    if not silent then pcall(function() Game.SendInfoText("ui_squad_" .. now, false, 0, 1) end) end
    System.LogAlways("[companion] Squad: " .. now .. "/" .. self.SquadMax)
end

function kcdcompanion:RemoveCompanions()
    local n = 0
    for name, _ in pairs(self.Spawned) do
        pcall(function()
            local h = System.GetEntityByName('CompanionHorse_' .. name)
            if h then System.RemoveEntity(h.id) end
        end)
        local ent = System.GetEntityByName(name)
        local dead = true
        if ent and ent.actor then dead = (ent.actor.IsDead and ent.actor:IsDead()) or false end
        if ent and not dead and ent.id then
            pcall(function() System.RemoveEntity(ent.id) end)
            n = n + 1
        end
        self.Spawned[name] = nil
    end
    _G.CompanionOrders = {}
    _G.CompanionRage = {}
    self:SaveState()
    System.LogAlways("[companion] Dismissed alive: " .. tostring(n) .. " (horses removed too, corpses left)")
end

function kcdcompanion:Regroup()
    _G.CompanionWait = false
    _G.CompanionOrders = {}
    _G.CompanionRage = {}
    _G.CompanionAggro = false
    _G.CompanionRecall = true
    pcall(function() kcdcompanion.EndChat() end)
    pcall(function()
        local tid = Sound.GetAudioTriggerID('v_horse_whistle')
        if tid then player:ExecuteAudioTrigger(tid, player:GetDefaultAuxAudioProxyID()) end
    end)
    _G.CompanionAck = true
    pcall(function()
        Script.SetTimerForFunction(2600, "kcdcompanion.AckAgain")
        if math.random(1, 2) == 1 then Script.SetTimerForFunction(5400, "kcdcompanion.AckAgain") end
    end)
    _G.CompanionVictim = nil
    pcall(function() Script.SetTimerForFunction(8000, "kcdcompanion.EndRecall") end)
    pcall(function()
        local pl = player or (Game and Game.GetPlayer and Game.GetPlayer())
        if not pl then return end
        local pp = pl:GetWorldPos()
        local i = 0
        for name, _ in pairs(self.Spawned) do
            local e = System.GetEntityByName(name)
            if e then
                i = i + 1
                local ep = e:GetWorldPos()
                local dx, dy = ep.x - pp.x, ep.y - pp.y
                if (dx*dx + dy*dy) > (18*18) then
                    local a = i * 1.1
                    pcall(function() e:SetWorldPos({ x = pp.x + math.cos(a) * 3.0, y = pp.y + math.sin(a) * 3.0, z = pp.z }) end)
                end
            end
        end
    end)
    System.LogAlways("[companion] Regroup - near ones run back, far ones pulled")
    pcall(function() Game.SendInfoText("ui_regroup", false, 0, 1) end)
end

kcdcompanion.FormationSlots = {}
kcdcompanion.FormationWidth = 2

function kcdcompanion:UpdateFormationSlots()
    pcall(function()
        self.FormationSlots = {}
        local alive = {}
        for name, _ in pairs(self.Spawned) do
            local ent = System.GetEntityByName(name)
            if ent then
                table.insert(alive, { wuid = ent.this and ent.this.id or ent.id, name = name })
            else
                self.Spawned[name] = nil
                if _G.CompanionOrders then _G.CompanionOrders[name] = nil end
                if _G.CompanionRage then _G.CompanionRage[name] = nil end
            end
        end
        table.sort(alive, function(a, b) return tostring(a.name) < tostring(b.name) end)
        local n = #alive
        local width = 1
        if n >= 8 then width = 3 elseif n >= 4 then width = 2 end
        for i, v in ipairs(alive) do
            local slot = i - 1
            local followTarget = nil
            if slot >= width then
                local ahead = alive[slot - width + 1]
                if ahead then followTarget = ahead.wuid end
            end
            self.FormationSlots[tostring(v.wuid)] = { followTarget = followTarget }
        end
    end)
end

function kcdcompanion:CalculateFormationTarget(bt_data, myWuid)
    pcall(function()
        local d = self.FormationSlots and self.FormationSlots[tostring(myWuid)]
        bt_data.followTarget = (d and d.followTarget) or bt_data.playerWUID
    end)
end

function kcdcompanion.FormationTick()
    kcdcompanion:UpdateFormationSlots()
    Script.SetTimerForFunction(1500, "kcdcompanion.FormationTick")
end

kcdcompanion.CachedEnemies = {}
kcdcompanion.TargetDetectionRadius = 20.0

function kcdcompanion:IsAliveAndWell(ent)
    if not ent or not ent.actor then return false end
    if ent.actor.IsDead and ent.actor:IsDead() then return false end
    if ent.actor.IsUnconscious and ent.actor:IsUnconscious() then return false end
    local ok, health = pcall(function() return ent.soul:GetState('health') end)
    if not ok or health == nil or health <= 0 then return false end
    return true
end

function kcdcompanion:IsMyCompanion(ent)
    if not ent then return false end
    local n = ent.GetName and ent:GetName() or nil
    if n and (string.find(n, 'kcdcompanion_', 1, true) or string.find(n, 'CompanionHorse_', 1, true)) then return true end
    local ok, sid = pcall(function() return tostring(ent.soul:GetId()) end)
    if ok and sid then
        for _, g in ipairs(self.SoulIds) do
            if string.find(sid, g, 1, true) then return true end
        end
    end
    return false
end

function kcdcompanion:IsTargetable(ent)
    if not ent or not ent.soul then return false end
    if player and ent.id == player.id then return false end
    if self:IsMyCompanion(ent) then return false end
    if not self:IsAliveAndWell(ent) then return false end
    return true
end

function kcdcompanion:IsHostileThreat(ent, playerWuid)
    if ent.soul:HasScriptContext("combat_surrender")
    or ent.soul:HasScriptContext("crime_fleeAfterSurrender")
    or ent.soul:HasScriptContext("combat_immortalityProtection") then return false end
    if _G.CompanionVictim and tostring(_G.CompanionVictim.w) == tostring(ent.this and ent.this.id or ent.id) then return true end
    local relP = nil
    pcall(function() relP = ent.soul:GetRelationship(playerWuid, "Current") end)
    if relP ~= nil and relP < 0.5 then return true end
    local armed = (ent.human ~= nil) and ent.human:IsWeaponDrawn() or false
    local fleeingCtx = ent.soul:HasScriptContext("combat_flee") or ent.soul:HasScriptContext("crime_interruptFlee")
    if relP ~= nil and relP < 0.95 and fleeingCtx then return true end
    if relP ~= nil and relP < 1 and armed then return true end
    if not armed or fleeingCtx then return false end
    local hostileToComp = false
    pcall(function()
        for name, _ in pairs(self.Spawned) do
            local c = System.GetEntityByName(name)
            local cw = c and c.this and c.this.id
            if cw then
                local relC = ent.soul:GetRelationship(cw, "Current")
                if relC and relC < 1 then hostileToComp = true; break end
            end
        end
    end)
    return hostileToComp
end

function kcdcompanion:UpdateEnemyCache()
    local ok, err = pcall(function()
        if not player then return end
        local playerPos = player:GetPos()
        if not playerPos then return end
        local playerWuid = player.this and player.this.id or player.id
        local ents = System.GetPhysicalEntitiesInBoxByClass(playerPos, self.TargetDetectionRadius, "NPC")
        local fresh = {}
        self.HealthMemo = self.HealthMemo or {}
        if _G.CompanionVictim then
            _G.CompanionVictim.ttl = (_G.CompanionVictim.ttl or 0) - 1
            if _G.CompanionVictim.ttl <= 0 then _G.CompanionVictim = nil end
        end
        if ents then
            for _, ent in pairs(ents) do
                if ent and type(ent) == "table" and ent.soul and self:IsTargetable(ent) then
                    local w = ent.this and ent.this.id or ent.id
                    pcall(function()
                        local ws = tostring(w)
                        local h = ent.soul:GetState('health')
                        local prev = self.HealthMemo[ws]
                        if h and prev and h < prev - 0.2 then
                            local ep = ent:GetPos()
                            local dx, dy = ep.x - playerPos.x, ep.y - playerPos.y
                            if (dx*dx + dy*dy) < 100 then
                                _G.CompanionVictim = { w = w, ttl = 20 }
                                System.LogAlways('[companion] VICTIM: ' .. tostring(ent:GetName()) .. ' HP ' .. tostring(prev) .. ' -> ' .. tostring(h))
                            end
                        end
                        if h then self.HealthMemo[ws] = h end
                    end)
                    local vsP = false
                    local relPv = nil
                    pcall(function()
                        relPv = ent.soul:GetRelationship(playerWuid, "Current")
                        vsP = (relPv ~= nil and relPv < 0.5) or false
                    end)
                    if _G.CompanionVictim and tostring(_G.CompanionVictim.w) == tostring(w) then vsP = true end
                    local host = self:IsHostileThreat(ent, playerWuid)
                    table.insert(fresh, {
                        entity = ent,
                        wuid = w,
                        hostile = host,
                        vsPlayer = vsP,
                        comradeOnly = host and (not vsP) and (relPv == nil or relPv >= 1),
                    })
                end
            end
        end
        self.CachedEnemies = fresh
    end)
    if not ok then System.LogAlways('[companion] UpdateEnemyCache err: ' .. tostring(err)) end
end

function kcdcompanion:PickTarget(bt_data, myWuid)
    pcall(function()
        local me = XGenAIModule.GetEntityByWUID(myWuid)
        local myName = me and me:GetName()
        if _G.CompanionRecall then bt_data.playerTarget = nil; return end
        if myName and _G.CompanionOrders and _G.CompanionOrders[myName] then
            local ot = _G.CompanionOrders[myName]
            local te = XGenAIModule.GetEntityByWUID(ot)
            if te and self:IsAliveAndWell(te) then
                bt_data.playerTarget = ot
                bt_data.isFriendly = false
                return
            else
                _G.CompanionOrders[myName] = nil
            end
        end
        do
            local myPos = me and me:GetPos()
            local pPos = player and player:GetPos()
            if myPos and pPos then
                local dx, dy = myPos.x - pPos.x, myPos.y - pPos.y
                local leash = _G.CompanionAggro and 25.0 or 20.0
                if (dx*dx + dy*dy) > (leash*leash) then bt_data.playerTarget = nil; return end
            end
        end
        self:UpdateEnemyCache()
        local ordered = {}
        for _, tw in pairs(_G.CompanionOrders or {}) do ordered[tostring(tw)] = true end
        local raging = _G.CompanionAggro or (myName and _G.CompanionRage and _G.CompanionRage[myName]) or false
        local refPos
        if _G.CompanionAggro then refPos = player and player:GetPos()
        else refPos = (me and me:GetPos()) or (player and player:GetPos()) end
        local myPos = me and me:GetPos()
        local best, bestDist = nil, nil
        for pass = 1, 2 do
            for _, entry in ipairs(self.CachedEnemies or {}) do
                local tierOk = (pass == 1 and entry.vsPlayer) or (pass == 2)
                if tierOk and entry.entity and entry.wuid and not ordered[tostring(entry.wuid)] and (raging or entry.hostile) then
                    local skip = false
                    if entry.comradeOnly and not raging and myPos then
                        local ep = entry.entity:GetPos()
                        if ep then
                            local myD = (myPos.x-ep.x)^2 + (myPos.y-ep.y)^2
                            local closer = 0
                            for nm, _ in pairs(self.Spawned) do
                                if nm ~= myName then
                                    local c = System.GetEntityByName(nm)
                                    local cp = c and c:GetWorldPos()
                                    if cp and ((cp.x-ep.x)^2 + (cp.y-ep.y)^2) < myD then closer = closer + 1 end
                                end
                            end
                            if closer >= 3 then skip = true end
                        end
                    end
                    if not skip then
                        local d = 0
                        if refPos then
                            local ep = entry.entity:GetPos()
                            if ep then local dx,dy,dz = ep.x-refPos.x, ep.y-refPos.y, ep.z-refPos.z; d = dx*dx+dy*dy+dz*dz end
                        end
                        if not bestDist or d < bestDist then bestDist = d; best = entry.wuid end
                    end
                end
            end
            if best then break end
        end
        if best then
            bt_data.playerTarget = best
            bt_data.isFriendly = false
        else
            bt_data.playerTarget = nil
        end
    end)
end

_G.CompanionOrders = _G.CompanionOrders or {}

function kcdcompanion:GetCrosshairTarget()
    local target = nil
    pcall(function()
        local camPos, camDir
        pcall(function() camPos = System.GetViewCameraPos() end)
        pcall(function() camDir = System.GetViewCameraDir() end)
        if not (camPos and camDir) then
            local pp = player:GetWorldPos(); local d = player:GetDirectionVector()
            if pp and d then camPos = { x=pp.x, y=pp.y, z=pp.z + 1.7 }; camDir = d end
        end
        if not (camPos and camDir) then return end
        local range = 80
        local hits = {}
        local n = Physics.RayWorldIntersection(camPos, { x=camDir.x*range, y=camDir.y*range, z=camDir.z*range }, 1, ent_all, player.id, nil, hits)
        System.LogAlways("[companion] order raycast n=" .. tostring(n))
        if n and n > 0 and hits[1] then
            local h = hits[1]
            local e = h.entity
            if not e and h.entityId then pcall(function() e = System.GetEntity(h.entityId) end) end
            target = e
        end
    end)
    if target and target.soul and player and target.id ~= player.id and not self:IsMyCompanion(target) and self:IsAliveAndWell(target) then
        return target
    end
    return nil
end

function kcdcompanion:OrderAttack()
    pcall(function()
        _G.CompanionOrders = _G.CompanionOrders or {}
        local target = self:GetCrosshairTarget()
        if not target then
            System.LogAlways("[companion] order: no target under crosshair")
            pcall(function() Game.SendInfoText("ui_order_notarget", false, 0, 1) end)
            return
        end
        local freeName = nil
        for name, _ in pairs(self.Spawned) do
            if System.GetEntityByName(name) and not _G.CompanionOrders[name] then freeName = name; break end
        end
        if not freeName then
            System.LogAlways("[companion] order: everyone busy")
            pcall(function() Game.SendInfoText("ui_order_allbusy", false, 0, 1) end)
            return
        end
        _G.CompanionOrders[freeName] = target.this and target.this.id or target.id
        System.LogAlways("[companion] order: " .. freeName .. " -> " .. tostring(target:GetName()))
        pcall(function() Game.SendInfoText("ui_order_sent", false, 0, 1) end)
    end)
end

function kcdcompanion.EnemyCacheTick()
    if next(kcdcompanion.Spawned) then kcdcompanion:UpdateEnemyCache() else kcdcompanion.CachedEnemies = {} end
    Script.SetTimerForFunction(1000, "kcdcompanion.EnemyCacheTick")
end

function kcdcompanion:UpdateStillness(data)
    pcall(function()
        local hostiles = 0
        for _, x in ipairs(self.CachedEnemies or {}) do if x.hostile then hostiles = hostiles + 1 end end
        local p = player and player:GetWorldPos()
        if not p or hostiles > 0 then data.playerStillTicks = 0; data.lastPX = nil; return end
        if (data.mountedDistToTarget or 0) > 6.0 then data.playerStillTicks = 0; data.lastPX = p.x; data.lastPY = p.y; return end
        if data.lastPX and data.lastPY then
            local dx, dy = p.x - data.lastPX, p.y - data.lastPY
            if (dx*dx + dy*dy) < 0.25 then data.playerStillTicks = (data.playerStillTicks or 0) + 2
            else data.playerStillTicks = 0 end
        else
            data.playerStillTicks = 0
        end
        data.lastPX = p.x; data.lastPY = p.y
    end)
end

_G.CompanionSpeakLock = _G.CompanionSpeakLock or false
function kcdcompanion.ReleaseSpeakLock() _G.CompanionSpeakLock = false end

function kcdcompanion.ChatTick()
    pcall(function()
        local force = _G.CompanionChatTest or false
        _G.CompanionChatTest = false
        local moved = false
        pcall(function()
            local p = player and player:GetWorldPos()
            if p then
                local lp = _G.ChatLastPPos
                if lp then
                    local dx, dy = p.x - lp.x, p.y - lp.y
                    moved = (dx*dx + dy*dy) > 4.0
                end
                _G.ChatLastPPos = { x = p.x, y = p.y }
            end
        end)
        if moved and _G.CompanionChat then kcdcompanion.EndChat() end
        if moved and not force then return end
        if _G.CompanionChat then
            _G.CompanionChatTicks = (_G.CompanionChatTicks or 0) + 1
            if _G.CompanionChatTicks > 9 then kcdcompanion.EndChat() end
        elseif force or ((not _G.PlayerMounted) and (not _G.CompanionSpeakLock) and math.random(1, 3) == 1) then
            local hostiles = 0
            for _, x in ipairs(kcdcompanion.CachedEnemies or {}) do if x.hostile then hostiles = hostiles + 1 end end
            if hostiles == 0 or force then
                local list = {}
                for n, _ in pairs(kcdcompanion.Spawned) do
                    local e = System.GetEntityByName(n)
                    if e then table.insert(list, e) end
                end
                local pairs_ = {}
                for i = 1, #list do
                    for j = i + 1, #list do
                        local pa, pb = list[i]:GetWorldPos(), list[j]:GetWorldPos()
                        if pa and pb then
                            local pp = player and player:GetWorldPos()
                            local nearP = pp and ((pa.x-pp.x)^2+(pa.y-pp.y)^2) < 144 and ((pb.x-pp.x)^2+(pb.y-pp.y)^2) < 144
                            local dx, dy = pa.x - pb.x, pa.y - pb.y
                            if nearP and (dx*dx + dy*dy) < 64 then table.insert(pairs_, {list[i], list[j]}) end
                        end
                    end
                end
                local ba, bb = nil, nil
                if #pairs_ > 0 then
                    local pick = pairs_[math.random(1, #pairs_)]
                    ba, bb = pick[1], pick[2]
                end
                if ba and bb then
                    _G.CompanionChat = { a = ba.this.id, b = bb.this.id }
                    _G.CompanionChatTicks = 0
                    _G.CompanionSpeakLock = true
                    System.LogAlways('[companion] CHAT pair: ' .. tostring(ba:GetName()) .. ' <-> ' .. tostring(bb:GetName()))
                end
            end
        end
    end)
    Script.SetTimerForFunction(5000, "kcdcompanion.ChatTick")
end
function kcdcompanion.AckAgain() _G.CompanionAck = true end

function kcdcompanion.EndChat()
    _G.CompanionChat = nil
    _G.CompanionChatTicks = 0
    _G.CompanionSpeakLock = false
end

function kcdcompanion.HorseTick()
    pcall(function()
        if not _G.PlayerMounted then
            for name, _ in pairs(kcdcompanion.Spawned) do
                local h = System.GetEntityByName('CompanionHorse_' .. name)
                if h then System.RemoveEntity(h.id) end
            end
        end
        if not _G.CompanionWait then
            local pp = player and player:GetWorldPos()
            if pp then
                kcdcompanion.StuckMemo = kcdcompanion.StuckMemo or {}
                for name, _ in pairs(kcdcompanion.Spawned) do
                    local e = System.GetEntityByName(name)
                    if e then
                        local ep = e:GetWorldPos()
                        local dP = (ep.x-pp.x)^2 + (ep.y-pp.y)^2
                        local m = kcdcompanion.StuckMemo[name]
                        local movedSq = m and ((ep.x-m.x)^2 + (ep.y-m.y)^2) or 999
                        local hasOrder = _G.CompanionOrders and _G.CompanionOrders[name]
                        if dP > 400 and movedSq < 0.25 and not hasOrder then
                            m.cnt = (m.cnt or 0) + 1
                            if m.cnt >= 4 then
                                pcall(function() e:SetWorldPos({ x = pp.x + 2.0, y = pp.y + 2.0, z = pp.z }) end)
                                System.LogAlways('[companion] ANTISTUCK: pulled ' .. name)
                                m.cnt = 0
                            end
                        elseif m then m.cnt = 0 end
                        kcdcompanion.StuckMemo[name] = { x = ep.x, y = ep.y, cnt = (m and m.cnt) or 0 }
                    end
                end
            end
        end
    end)
    Script.SetTimerForFunction(1500, "kcdcompanion.HorseTick")
end

_G.CompanionAggro = _G.CompanionAggro or false
_G.CompanionRecall = _G.CompanionRecall or false
function kcdcompanion.EndRecall() _G.CompanionRecall = false; System.LogAlways("[companion] recall over") end
_G.CompanionRage = _G.CompanionRage or {}
function kcdcompanion:SetAggroMode(on)
    _G.CompanionAggro = on and true or false
    pcall(function() self:SaveState() end)
    System.LogAlways("[companion] mode: " .. (_G.CompanionAggro and "BANDIT (attack everyone)" or "DEFENSIVE"))
    pcall(function()
        local key = _G.CompanionAggro and "ui_mode_bandit" or "ui_mode_defensive"
        Game.SendInfoText(key, false, 0, 1)
    end)
end

_G.CompanionWait = _G.CompanionWait or false
function kcdcompanion:SetWaitState(wait)
    _G.CompanionWait = wait and true or false
    pcall(function() self:SaveState() end)
    System.LogAlways("[companion] state: " .. (_G.CompanionWait and "WAIT" or "FOLLOW"))
    pcall(function()
        local key = _G.CompanionWait and "ui_companion_wait_action" or "ui_companion_follow_action"
        Game.SendInfoText(key, false, 0, 1)
    end)
end

function kcdcompanion:ShowCommandMenu()
    local n = self:CountSquad()
    local key = (n >= 1 and n <= 10) and ("ui_companion_menu_" .. n) or "ui_companion_menu"
    pcall(function() Game.SendInfoText(key, false, 0, 5) end)
end

function kcdcompanion:InjectInteraction(ent)
    if not ent then return end
    ent.ToggleWaitFollow = function(self, user)
        kcdcompanion:SetWaitState(not _G.CompanionWait)
    end
    ent.HealSelf = function(self, user)
        pcall(function() self.soul:SetState('health', 100) end)
        pcall(function() self.actor:WashDirtAndBlood(1, 1) end)
        pcall(function() self.soul:AddBlood({"torso","head","arm_left","arm_right","leg_left","leg_right"}, {-1,-1,-1,-1,-1,-1}, true) end)
        pcall(function() self.soul:AddDirt(-1, true) end)
        for i = 1, 6 do pcall(function() self.soul:HealBleeding(1.0, i) end) end
        pcall(function() Game.SendInfoText("ui_companion_healed", false, 0, 1) end)
    end
    ent.ToggleRage = function(self, user)
        _G.CompanionRage = _G.CompanionRage or {}
        local nm = tostring(self:GetName())
        if _G.CompanionRage[nm] then _G.CompanionRage[nm] = nil else _G.CompanionRage[nm] = true end
        pcall(function() Game.SendInfoText(_G.CompanionRage[nm] and "ui_companion_rage_on" or "ui_companion_rage_off", false, 0, 1) end)
    end
    ent.DismissSelf = function(self, user)
        local nm = tostring(self:GetName())
        pcall(function()
            kcdcompanion.Spawned[nm] = nil
            if _G.CompanionOrders then _G.CompanionOrders[nm] = nil end
            if _G.CompanionRage then _G.CompanionRage[nm] = nil end
            if self.id then System.RemoveEntity(self.id) end
        end)
        pcall(function() kcdcompanion:SaveState() end)
        pcall(function() Game.SendInfoText("ui_companion_dismissed", false, 0, 1) end)
    end
    ent.GetActions = function(self, user, firstFast)
        local output = {}
        if BasicAIActions and BasicAIActions.GetActions then
            local base = BasicAIActions.GetActions(self, user, firstFast)
            for _, a in pairs(base) do table.insert(output, a) end
        end
        if self.actor and not self.actor:IsDead() and not self.actor:IsUnconscious() then
            local prompt = _G.CompanionWait and "ui_companion_follow_action" or "ui_companion_wait_action"
            AddInteractorAction(output, firstFast,
                Action():hint(prompt):hintType(AHT_RELEASE):action("companion_bond"):uiOrder(3):func(self.ToggleWaitFollow):interaction(inr_loot)
            )
            AddInteractorAction(output, firstFast,
                Action():hint("ui_companion_heal_action"):hintType(AHT_RELEASE):action("use_horse"):uiOrder(4):func(self.HealSelf):interaction(inr_loot)
            )
            AddInteractorAction(output, firstFast,
                Action():hint("ui_companion_rage_action"):hintType(AHT_RELEASE):action("use"):uiOrder(5):func(self.ToggleRage):interaction(inr_loot)
            )
        end
        return output
    end
end

kcdcompanion.MenuPID     = 47001
kcdcompanion.MenuOpen    = false
kcdcompanion.MenuReady   = false
kcdcompanion.MenuPaused  = false
kcdcompanion.MenuButtons = {}
kcdcompanion.MenuStack   = {}

kcdcompanion.NameBySoul = {
    ["c0a9a0b1-0004-4c0a-9a01-0000000c0004"] = "Hynek",
    ["c0a9a0b1-0004-4c0a-9a01-0000000c0005"] = "Radim",
    ["c0a9a0b1-0004-4c0a-9a01-0000000c0006"] = "Bohuslav",
    ["c0a9a0b1-0004-4c0a-9a01-0000000c0007"] = "Jaromir",
    ["c0a9a0b1-0004-4c0a-9a01-0000000c0008"] = "Ctibor",
    ["c0a9a0b1-0004-4c0a-9a01-0000000c0009"] = "Zdenek",
    ["c0a9a0b1-0004-4c0a-9a01-0000000c000a"] = "Ondrej",
    ["c0a9a0b1-0004-4c0a-9a01-0000000c000b"] = "Matous",
    ["c0a9a0b1-0004-4c0a-9a01-0000000c000c"] = "Vaclav",
    ["c0a9a0b1-0004-4c0a-9a01-0000000c000d"] = "Prokop",
}
function kcdcompanion:MenuDisplayName(name)
    local sid = string.match(name or "", "kcdcompanion_(.-)_%d+$")
    return (sid and self.NameBySoul[sid]) or "Companion"
end
function kcdcompanion:MenuHP(e)
    local hp = nil
    pcall(function() hp = e.soul:GetState("health") end)
    if not hp then return nil end
    if hp <= 1.0 then hp = hp * 100 end
    return math.floor(hp + 0.5)
end

function kcdcompanion:MenuPageMain()
    local B = {}
    local function add(label, tip, fn) B[#B + 1] = { label = label, tooltip = tip or "", fn = fn } end
    add("@ui_menu_regroup  (F9)", "@ui_menu_tt_regroup", function() self:Regroup() end)
    add((_G.CompanionAggro and "@ui_menu_combat_ban" or "@ui_menu_combat_def") .. "  (F6)",
        "@ui_menu_tt_combat", function() self:SetAggroMode(not _G.CompanionAggro) end)
    if _G.CompanionWait then
        add("@ui_menu_follow  (F8)", "@ui_menu_tt_follow", function() self:SetWaitState(false) end)
    else
        add("@ui_menu_wait  (F8)", "@ui_menu_tt_wait", function() self:SetWaitState(true) end)
    end
    add("@ui_menu_summon (" .. self:CountSquad() .. "/" .. self.SquadMax .. ")  (F7)",
        "@ui_menu_tt_summon", function() self:SummonOne(true); self:MenuShow("main", true, 4) end)
    B[#B].navigates = true
    add("@ui_menu_individual", "@ui_menu_tt_individual", function() self.MenuIndPage = 0; self:MenuShow("individual") end)
    B[#B].navigates = true
    add("@ui_menu_dismiss_squad  (F11)", "@ui_menu_tt_dismiss_squad", function() self:RemoveCompanions() end)
    return B, (_G.CompanionMenuTitle or "Companion Squad")
end

function kcdcompanion:MenuPageIndividual()
    local all = {}
    for name, _ in pairs(self.Spawned) do
        local e = System.GetEntityByName(name)
        if e then all[#all + 1] = { name = name, e = e } end
    end
    table.sort(all, function(a, b) return self:MenuDisplayName(a.name) < self:MenuDisplayName(b.name) end)
    if #all == 0 then
        return { { label = "@ui_menu_no_comp", tooltip = "", fn = function() end, disabled = true } }, "@ui_menu_roster_title"
    end
    local pageSize = _G.CompanionRosterPageSize or 5
    local pageCount = math.max(1, math.ceil(#all / pageSize))
    local page = self.MenuIndPage or 0
    if page >= pageCount then page = pageCount - 1 end
    if page < 0 then page = 0 end
    self.MenuIndPage = page
    local B = {}
    local startI = page * pageSize + 1
    local endI = math.min(startI + pageSize - 1, #all)
    for i = startI, endI do
        local item = all[i]
        local disp = self:MenuDisplayName(item.name)
        local hp = self:MenuHP(item.e)
        local label = hp and (disp .. "   -   " .. hp .. "% @ui_menu_hp") or disp
        local nm = item.name
        B[#B + 1] = { label = label, tooltip = "@ui_menu_tt_roster", navigates = true,
                      fn = function() self.MenuTargetName = nm; self:MenuShow("man") end }
    end
    if page > 0 then
        B[#B + 1] = { label = "@ui_menu_prev", tooltip = "@ui_menu_tt_prev", navigates = true,
                      fn = function() self.MenuIndPage = page - 1; self:MenuShow("individual", true) end }
    end
    if page < pageCount - 1 then
        B[#B + 1] = { label = "@ui_menu_more", tooltip = "@ui_menu_tt_more", navigates = true,
                      fn = function() self.MenuIndPage = page + 1; self:MenuShow("individual", true) end }
    end
    local title = "@ui_menu_roster_title"
    if pageCount > 1 then title = title .. "   (" .. (page + 1) .. "/" .. pageCount .. ")" end
    return B, title
end

function kcdcompanion:MenuPageMan()
    local nm = self.MenuTargetName
    local e = nm and System.GetEntityByName(nm)
    local B = {}
    local function add(label, tip, fn, nav) B[#B + 1] = { label = label, tooltip = tip or "", fn = fn, navigates = nav } end
    if not e then return B, "Companion" end
    local disp = self:MenuDisplayName(nm)
    local hp = self:MenuHP(e)
    add("@ui_menu_come", "@ui_menu_tt_come", function()
        pcall(function()
            local p = player:GetWorldPos()
            if p then e:SetWorldPos({ x = p.x + 1.5, y = p.y + 1.5, z = p.z }) end
        end)
    end)
    add("@ui_menu_heal", "@ui_menu_tt_heal", function() pcall(function() e:HealSelf() end) end)
    add("@ui_menu_rage", "@ui_menu_tt_rage", function()
        _G.CompanionRage = _G.CompanionRage or {}; _G.CompanionRage[nm] = true
        pcall(function() Game.SendInfoText("ui_companion_rage_on", false, 0, 1) end)
    end)
    add("@ui_menu_change_helmet", "@ui_menu_tt_change_helmet", function() self:MenuShow("helmet") end, true)
    add("@ui_menu_dismiss_man", "@ui_menu_tt_dismiss_man", function()
        pcall(function()
            self.Spawned[nm] = nil
            if _G.CompanionOrders then _G.CompanionOrders[nm] = nil end
            if _G.CompanionRage then _G.CompanionRage[nm] = nil end
            if e.id then System.RemoveEntity(e.id) end
            self:SaveState()
        end)
    end)
    local title = hp and (disp .. "   (" .. hp .. "% @ui_menu_hp)") or disp
    return B, title
end

function kcdcompanion:MenuPageHelmet()
    local nm = self.MenuTargetName
    local e = nm and System.GetEntityByName(nm)
    local B = {}
    if not e then return B, "Helmet" end
    local helmets = {
        { "@ui_menu_helm_visored", "c0a9a0b1-c101-4c0a-9a01-0000000cd001" },
        { "@ui_menu_helm_kettle",       "c0a9a0b1-c101-4c0a-9a01-0000000cd002" },
        { "@ui_menu_helm_closed",  "c0a9a0b1-c101-4c0a-9a01-0000000cd006" },
        { "@ui_menu_helm_open",    "c0a9a0b1-c101-4c0a-9a01-0000000cd004" },
    }
    for _, h in ipairs(helmets) do
        local preset = h[2]
        B[#B + 1] = {
            label = h[1], tooltip = "@ui_menu_tt_helmet", navigates = true,
            fn = function()
                pcall(function() e.actor:EquipClothingPreset(preset) end)
                self:MenuShow("helmet", true)
            end,
        }
    end
    return B, "@ui_menu_choose_helmet"
end

function kcdcompanion:MenuResolve(pageName)
    if pageName == "individual" then return self:MenuPageIndividual() end
    if pageName == "man"        then return self:MenuPageMan() end
    if pageName == "helmet"     then return self:MenuPageHelmet() end
    return self:MenuPageMain()
end

function kcdcompanion:MenuShow(pageName, isBack, focusIdx)
    if not self.MenuReady or self.MenuPaused then return end
    local pid = self.MenuPID
    local B, title = self:MenuResolve(pageName)
    self.MenuButtons = B
    self.MenuPage = pageName
    if not isBack then table.insert(self.MenuStack, pageName) end
    local ok = pcall(function()
        UIAction.HideElement("hud", -1)
        UIAction.HideElement("Menu", -1)
        UIAction.CallFunction("Menu", pid, "ClearAll")
        UIAction.HideElement("Menu", pid)
        pcall(function() UIAction.UnregisterElementListener(self, "MenuOnButton") end)
        local extra = 1
        if #self.MenuStack > 1 then extra = extra + 1 end
        local screenY = System.GetCVar("r_height") or 1080
        local shown = #B + extra
        if shown > 10 then shown = 10 end
        UIAction.CallFunction("Menu", pid, "PreparePage", 0, math.floor(screenY * 0.325), shown, tostring(title), 1)
        ActionMapManager.EnableActionMap("menu", true)
        UIAction.CallFunction("Menu", pid, "SetActiveUser", "")
        for i, el in ipairs(B) do
            UIAction.CallFunction("Menu", pid, "AddBasicButton", "cmp_" .. i, 0, tostring(el.label), tostring(el.tooltip), el.disabled == true)
        end
        if #self.MenuStack > 1 then
            UIAction.CallFunction("Menu", pid, "AddBasicButton", "cmp_back", 1, "@ui_menu_back", "@ui_menu_tt_back", false)
        end
        UIAction.CallFunction("Menu", pid, "AddBasicButton", "cmp_close", 1, "@ui_menu_close", "@ui_menu_tt_close", false)
        UIAction.HideElement("hud", -1)
        UIAction.ShowElement("Menu", pid)
        UIAction.RegisterElementListener(self, "Menu", pid, "OnButton", "MenuOnButton")
        UIAction.CallFunction("Menu", pid, "ShowPage")
        if focusIdx then
            pcall(function() UIAction.CallFunction("Menu", pid, "SelectButton", "cmp_" .. focusIdx, 0) end)
        end
        self.MenuOpen = true
    end)
    if not ok then pcall(function() self:MenuClose() end) end
end

function kcdcompanion:ToggleSquadMenu()
    if self.MenuOpen then self:MenuClose(); return end
    self.MenuStack = {}
    self:MenuShow("main")
end

function kcdcompanion:MenuBack()
    table.remove(self.MenuStack)
    local prev = self.MenuStack[#self.MenuStack] or "main"
    self:MenuShow(prev, true)
end

function kcdcompanion:MenuClose()
    self.MenuOpen = false
    self.MenuStack = {}
    pcall(function()
        UIAction.CallFunction("Menu", self.MenuPID, "ClearAll")
        UIAction.HideElement("Menu", self.MenuPID)
        UIAction.ShowElement("hud", 0)
        ActionMapManager.EnableActionMap("menu", false)
    end)
end

function kcdcompanion.MenuOnButton(func, elementName, instanceId, eventName, argTable)
    local self = kcdcompanion
    local id = ""
    if argTable then for _, v in pairs(argTable) do if v ~= nil then id = tostring(v); break end end end
    if id == "cmp_close" then self:MenuClose(); return end
    if id == "cmp_back" then self:MenuDefer(function() self:MenuBack() end); return end
    local idx = tonumber(string.match(id, "^cmp_(%d+)$"))
    if idx and self.MenuButtons[idx] then
        local el = self.MenuButtons[idx]
        if el.disabled then return end
        if el.navigates then
            self:MenuDefer(function() if el.fn then el.fn() end end)
        else
            self:MenuClose()
            pcall(function() if el.fn then el.fn() end end)
        end
    end
end

function kcdcompanion:MenuDefer(fn)
    self._pendingNav = fn
    pcall(function() Script.SetTimerForFunction(1, "kcdcompanion.RunPendingNav") end)
end
function kcdcompanion.RunPendingNav()
    local fn = kcdcompanion._pendingNav
    kcdcompanion._pendingNav = nil
    if fn then pcall(fn) end
end

function kcdcompanion.MenuActionListener(action, activation, value)
    if kcdcompanion.MenuOpen and tostring(activation) == "release" and tostring(action) == "menu_back" then
        kcdcompanion:MenuClose()
    end
end

function kcdcompanion.MenuOnPause()  if kcdcompanion.MenuOpen then kcdcompanion:MenuClose() end; kcdcompanion.MenuPaused = true end
function kcdcompanion.MenuOnResume() kcdcompanion.MenuPaused = false end

System.AddCCommand("companion_spawn",  "kcdcompanion:SpawnCompanion()",   "Spawn one companion behind player")
System.AddCCommand("companion_summon", "kcdcompanion:SummonOne()",        "Summon one companion (up to squad max)")
System.AddCCommand("companion_remove", "kcdcompanion:RemoveCompanions()", "Despawn session companions")
System.AddCCommand("companion_toggle", "kcdcompanion:SetWaitState(not _G.CompanionWait)", "Toggle wait/follow")
System.AddCCommand("companion_regroup","kcdcompanion:Regroup()",             "Regroup squad to player")
System.AddCCommand("companion_menu",   "kcdcompanion:ToggleSquadMenu()", "Open the native companion squad menu")
System.AddCCommand("companion_mode",   "kcdcompanion:SetAggroMode(not _G.CompanionAggro)", "Toggle defensive/bandit combat mode")
System.AddCCommand("companion_order",  "kcdcompanion:OrderAttack()",      "Send one companion to attack the crosshair target")

UIAction.RegisterEventSystemListener(kcdcompanion, "", "OnGameplayStarted", "OnGameplayStarted")

pcall(function()
    UIAction.RegisterEventSystemListener(kcdcompanion, "", "OnGamePause",  "MenuOnPause")
    UIAction.RegisterEventSystemListener(kcdcompanion, "", "OnGameResume", "MenuOnResume")
    local screens = { "ApseInventoryList", "ApseMap", "ApseCharacter", "ApseQuestLogList",
                      "GeneralBook", "ApseModalDialog", "LockPicking", "Pickpocketing",
                      "ItemTransfer", "SkipTime", "LoadingScreen", "GameOver" }
    for _, el in ipairs(screens) do
        UIAction.RegisterElementListener(kcdcompanion, el, -1, "OnShow", "MenuOnPause")
        UIAction.RegisterElementListener(kcdcompanion, el, -1, "OnHide", "MenuOnResume")
    end
end)

System.LogAlways("[companion] console commands registered")
