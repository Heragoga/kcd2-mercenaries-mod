--Hire regular mercs
function mercenaries:Hire(cost, amount, tier)
    local p = player.inventory

    self:Recount()
    if not _G.MercCount then _G.MercCount = 0 end

    -- Check limits and cost first (Early Exit)
    if _G.MercCount + amount > self.MaxCompanions then
        Game.SendInfoText('merc_info_too_many', false, 0, 3)
        return
    end

    if p:GetMoney() < cost then
        Game.SendInfoText('merc_info_not_enough_money', false, 0, 3)
        return
    end

    -- Apply costs and update variables
    p:RemoveMoney(cost)

    -- Gate SaveString: only write if state actually needs to change
    if _G.MercenariesDismissed ~= false then
        _G.MercenariesDismissed = false
        self:SaveString("MercenariesDismissed", "0")
    end
    if _G.MercIdle ~= false then
        _G.MercIdle = false
        _G.MercPersistentIdleFlag = false
        self:SaveString("MercIdlePersistent", "0")
    end

    _G.MercCount = _G.MercCount + amount

    local ok, err = pcall(function()
        local spawnPos, playerRot = self:GetSafeSpawnPosition(player, 3)
        if not spawnPos then return end

        local soulList = self.Souls[tier] or self.Souls["weak"]

        local currentPreset = _G.MercCurrentOutfit or 1
        local currentWeaponPreset = _G.MercCurrentWeapon or 1

        for i=1, amount do
            local idx = self.SoulIndex[tier]
            local soulGuid = soulList[idx]
            
            self.SoulIndex[tier] = idx + 1
            if self.SoulIndex[tier] > #soulList then 
                self.SoulIndex[tier] = 1 
            end
            
            local offsetPos = self:FindValidGround({
                x = spawnPos.x + (math.random() - 0.5) * 1.5,
                y = spawnPos.y + (math.random() - 0.5) * 1.5,
                z = spawnPos.z
            }, spawnPos.z)

            local safeRot = {x = 0, y = 0, z = playerRot.z}
            local entityName = "SpawnedFriend_" .. tier .. "_" .. tostring(math.random(10000, 99999)) .. "_" .. soulGuid

            -- Spawn the entity
            System.SpawnEntity({
                class = "NPC", 
                name = entityName, 
                position = offsetPos, 
                orientation = safeRot, 
                properties = {guidSharedSoulId = soulGuid}
            })
            
            local ent = System.GetEntityByName(entityName)

            if ent then
                mercenaries:EnsureMercIsAlwaysRendered(ent)

                self:EquipMercenary(ent, currentPreset)
                self:EquipMercenaryWeapon(ent, currentWeaponPreset)
                -- PERFORMANCE: Register in cache immediately so the next
                -- MonitorLoop tick doesn't need a full world scan to find them.
                self.ActiveMercs[entityName] = ent
                self:InjectInteraction(ent)

            end

        end

    end)
    
    if not ok then System.LogAlways('[Mercenaries] Teleport Error: ' .. tostring(err)) end

    if amount == 1 then
        Game.SendInfoText('merc_info_hired_single', false, 0, 3)
    else
        Game.SendInfoText('merc_info_hired_multiple', false, 0, 3)
    end
end


function mercenaries:HireCustomCompanion(ccID)
    local p = player.inventory
    local amount = 1
    
    local heroData = self.CustomCompanionsData[ccID]
    if not heroData then 
        System.LogAlways('[Mercenaries] Error: Invalid custom companion ID passed: ' .. tostring(ccID))
        return 
    end

    local cost = heroData.cost
    local soulGuid = heroData.guid

    -- Check if this hero is already alive in the world using the cache first
    for name, ent in pairs(self.ActiveMercs) do
        if string.find(name, soulGuid, 1, true) then
            local ok, hp = pcall(function() return ent.soul:GetState('health') end)
            if (ok and hp and hp > 0) or not ok then
                Game.SendInfoText('merc_info_already_hired', false, 0, 3)
                return
            end
        end
    end

    self:Recount()
    if not _G.MercCount then _G.MercCount = 0 end

    -- Check limits and cost first (Early Exit)
    if _G.MercCount + amount > self.MaxCompanions then
        Game.SendInfoText('merc_info_too_many', false, 0, 3)
        return
    end

    if p:GetMoney() < cost then
        Game.SendInfoText('merc_info_not_enough_money', false, 0, 3)
        return
    end

    -- Apply costs and update variables
    p:RemoveMoney(cost)

    -- Gate SaveString: only write if state actually needs to change
    if _G.MercenariesDismissed ~= false then
        _G.MercenariesDismissed = false
        self:SaveString("MercenariesDismissed", "0")
    end
    if _G.MercIdle ~= false then
        _G.MercIdle = false
        self:SaveString("MercIdlePersistent", "0")
    end

    _G.MercCount = _G.MercCount + amount

    local ok, err = pcall(function()
        local spawnPos, playerRot = self:GetSafeSpawnPosition(player, 3)
        if not spawnPos then return end
        
        local offsetPos = self:FindValidGround({
            x = spawnPos.x + (math.random() - 0.5) * 1.5,
            y = spawnPos.y + (math.random() - 0.5) * 1.5,
            z = spawnPos.z
        }, spawnPos.z)

        local safeRot = {x = 0, y = 0, z = playerRot.z}
        local entityName = "MercenaryCustomCompanion_" .. soulGuid .. "_" .. tostring(math.random(10000, 99999))

        System.SpawnEntity({
            class = "NPC", 
            name = entityName, 
            position = offsetPos, 
            orientation = safeRot, 
            properties = {guidSharedSoulId = soulGuid}
        })

        -- PERFORMANCE: Register in cache immediately
        local ent = System.GetEntityByName(entityName)
        if ent then
            mercenaries:EnsureMercIsAlwaysRendered(ent)

            self.ActiveMercs[entityName] = ent
            self:InjectInteraction(ent)

        end
    end)
    
    if not ok then System.LogAlways('[Mercenaries] Teleport Error: ' .. tostring(err)) end

    Game.SendInfoText('merc_info_hired_special', false, 0, 3)
end

-- Debug: spawns a battle line of mercs facing a line of renegades, for
-- combat testing. Player ends up centered in the merc line. The enemy
-- side is spawned as renegades (see below) rather than raw bandit souls,
-- so they get the same "attack everyone, don't gang up" AI already built
-- for renegades instead of needing their own separate combat wiring.
--
-- mercCounts / enemyCounts: { weak = N, medium = N, strong = N } - how
--   many of each tier on each side. Defaults to 7/7/6 per side (20 total),
--   matching the old fixed 20v20.
-- mercOutfit / mercWeapon: preset indexes (mercenaries.Outfits /
--   mercenaries.WeaponSets) for the merc side. Default to whatever the
--   squad is currently wearing.
-- enemyOutfit / enemyWeapon: same, for the renegade side. Default to
--   GetRenegadeOutfitFor(mercOutfit) / mercWeapon, so the two sides are
--   visually distinct even if you don't specify anything.
--
-- Within each side, tiers are laid out strongest-first, so the front
-- row(s) - closest to the other side - always get the better troops
-- instead of a random weak/medium/strong mix along the whole line.
function mercenaries:SpawnTestBattle(mercCounts, mercOutfit, mercWeapon, enemyCounts, enemyOutfit, enemyWeapon)
    local pos = player:GetWorldPos()
    local dir = player:GetDirectionVector()
    if not pos or not dir or (dir.x == 0 and dir.y == 0) then return end

    local playerAngleZ = player:GetAngles().z

    -- Perpendicular to facing direction, used to lay out a row across the player's front.
    local rightX, rightY = dir.y, -dir.x

    mercCounts = mercCounts or { weak = 7, medium = 7, strong = 6 }
    enemyCounts = enemyCounts or { weak = 7, medium = 7, strong = 6 }

    mercOutfit = mercOutfit or _G.MercCurrentOutfit or 1
    mercWeapon = mercWeapon or _G.MercCurrentWeapon or 1
    enemyOutfit = enemyOutfit or self:GetRenegadeOutfitFor(mercOutfit)
    enemyWeapon = enemyWeapon or mercWeapon

    local colSpacing = 1.2
    local rowSpacing = 1.5
    local rowSize = 10
    local enemyDistance = 18.0

    -- Strongest first, so filling row-by-row (front row = lowest index)
    -- naturally puts the better troops at the front of the line.
    local function buildTierOrder(counts)
        local order = {}
        for _ = 1, (counts.strong or 0) do table.insert(order, "strong") end
        for _ = 1, (counts.medium or 0) do table.insert(order, "medium") end
        for _ = 1, (counts.weak or 0) do table.insert(order, "weak") end
        return order
    end

    local mercTierOrder = buildTierOrder(mercCounts)
    local enemyTierOrder = buildTierOrder(enemyCounts)

    local ok, err = pcall(function()
        for i, tier in ipairs(mercTierOrder) do
            local col = ((i - 1) % rowSize) + 1
            local row = math.floor((i - 1) / rowSize)
            local colOffset = (col - (rowSize + 1) / 2) * colSpacing
            local rowOffset = row * rowSpacing

            local mx = pos.x + rightX * colOffset - dir.x * rowOffset
            local my = pos.y + rightY * colOffset - dir.y * rowOffset

            local soulList = self.Souls[tier]
            local soulGuid = soulList[((i - 1) % #soulList) + 1]

            local entityName = "SpawnedFriend_" .. tier .. "_" .. tostring(math.random(10000, 99999)) .. "_" .. soulGuid

            System.SpawnEntity({
                class = "NPC",
                name = entityName,
                position = { x = mx, y = my, z = pos.z },
                orientation = { x = 0, y = 0, z = playerAngleZ },
                properties = { guidSharedSoulId = soulGuid }
            })

            local ent = System.GetEntityByName(entityName)
            if ent then
                mercenaries:EnsureMercIsAlwaysRendered(ent)
                self:EquipMercenary(ent, mercOutfit)
                self:EquipMercenaryWeapon(ent, mercWeapon)
                self.ActiveMercs[entityName] = ent
                self:InjectInteraction(ent)
            end
        end

        if _G.MercenariesDismissed ~= false then
            _G.MercenariesDismissed = false
            self:SaveString("MercenariesDismissed", "0")
        end
        if _G.MercIdle ~= false then
            _G.MercIdle = false
            self:SaveString("MercIdlePersistent", "0")
        end
        self:Recount()

        local enemyRowX = pos.x + dir.x * enemyDistance
        local enemyRowY = pos.y + dir.y * enemyDistance
        local enemyFacingAngle = playerAngleZ + math.pi
        if enemyFacingAngle > math.pi then enemyFacingAngle = enemyFacingAngle - (2 * math.pi) end

        for i, tier in ipairs(enemyTierOrder) do
            local col = ((i - 1) % rowSize) + 1
            local row = math.floor((i - 1) / rowSize)
            local colOffset = (col - (rowSize + 1) / 2) * colSpacing
            local rowOffset = row * rowSpacing

            local ex = enemyRowX + rightX * colOffset + dir.x * rowOffset
            local ey = enemyRowY + rightY * colOffset + dir.y * rowOffset

            local soulGuid = self.RenegadeSouls[self.RenegadeSoulIndex]
            self.RenegadeSoulIndex = self.RenegadeSoulIndex + 1
            if self.RenegadeSoulIndex > #self.RenegadeSouls then
                self.RenegadeSoulIndex = 1
            end

            local entityName = "SpawnedRenegade_" .. tier .. "_" .. tostring(math.random(10000, 99999)) .. "_" .. soulGuid

            System.SpawnEntity({
                class = "NPC",
                name = entityName,
                position = { x = ex, y = ey, z = pos.z },
                orientation = { x = 0, y = 0, z = enemyFacingAngle },
                properties = { guidSharedSoulId = soulGuid }
            })

            local ent = System.GetEntityByName(entityName)
            if ent then
                self:EquipMercenary(ent, enemyOutfit)
                self:EquipMercenaryWeapon(ent, enemyWeapon)
                -- No manual DrawWeapon() - see the matching comment in
                -- SpawnRenegade; renegade_attack.xml's automation decorators
                -- own weapon draw, and forcing it here races spawn init.
            end
        end
    end)

    if not ok then System.LogAlways('[Mercenaries] SpawnTestBattle error: ' .. tostring(err)) end

    System.LogAlways('[Mercenary Jeff] Spawned test battle: ' .. #mercTierOrder .. ' mercs vs ' .. #enemyTierOrder .. ' renegades.')
end

-- Console-friendly wrapper around SpawnTestBattle: plain numeric args
-- instead of Lua tables, so it works as a normal AddCCommand (%1..%5)
-- rather than needing merc_lua. Splits countPerSide evenly across the
-- three tiers (any remainder goes to the strong tier).
-- Outfits: 1 Generic, 2 Bandits, 3 Cumans, 4 Leipa, 5 Kuttenberg, 6 Skalitz.
-- Weapons: 2 Sword+shield, 3 Axe+shield, 4 Longsword, 5 Mace+shield,
--          6 Shortsword, 7 Mace, 8 Axe, 9 Polearm.
function mercenaries:SpawnBattle(mercOutfit, mercWeapon, enemyOutfit, enemyWeapon, countPerSide)
    mercOutfit = tonumber(mercOutfit)
    mercWeapon = tonumber(mercWeapon)
    enemyOutfit = tonumber(enemyOutfit)
    enemyWeapon = tonumber(enemyWeapon)
    countPerSide = tonumber(countPerSide) or 20

    local third = math.floor(countPerSide / 3)
    local remainder = countPerSide - (third * 3)
    local counts = { weak = third, medium = third, strong = third + remainder }

    self:SpawnTestBattle(counts, mercOutfit, mercWeapon, counts, enemyOutfit, enemyWeapon)
end

-- =======================================================================
-- Renegades: a separate, hostile-to-everyone NPC type (own brain, own
-- souls, own faction). See docs/xml/add-new-npc.md and
-- docs/xml/make-npc-brain.md for how they're wired up. Their brain is a
-- custom switch (data/AI/renegade_scheduler.xml) that fires a stripped
-- attack interrupt (data/AI/renegade_attack.xml) - no follow, no stance,
-- no schedule. Target selection (FindRenegadeTarget, below) is
-- indiscriminate: any living NPC or the player within 50m, no faction
-- filtering, only avoiding piling more than RenegadeSwarmCap of them onto
-- the same target while another target is available.
--
-- They borrow their look and loadout from the normal mercenary preset
-- tables (mercenaries.Outfits / mercenaries.WeaponSets), same as
-- EquipMercenary/EquipMercenaryWeapon use for real mercs, so spawning one
-- lets you hand it any existing mercenary outfit/weapon preset.
-- =======================================================================

mercenaries.RenegadeSouls = {
    "c4b2d8e3-5f0a-4b69-9c7e-2d4f8a0b3c51",
    "d5c3e9f4-601b-4c7a-ad8f-3e5a9b1c4d62",
    "e6d4f0a5-712c-4d8b-be90-4f6b0c2d5e73",
    "f7e5a1b6-823d-4e9c-cfa1-507c1d3e6f84",
    "08f6b2c7-934e-4fad-d0b2-618d2e4f7095"
}
mercenaries.RenegadeSoulIndex = 1

-- Keeps renegades looking distinct from whatever the mercs are currently
-- wearing: given a mercenaries.Outfits index, look up the outfit
-- renegades should wear instead. 1 Generic, 2 Bandits, 3 Cumans, 4 Leipa,
-- 5 Kuttenberg, 6 Skalitz. There's no "Prague" preset - any reference to
-- one in design notes means Kuttenberg.
mercenaries.RenegadeOutfitOverride = {
    [1] = 5, -- Generic -> Kuttenberg
    [2] = 5, -- Bandits -> Kuttenberg
    [3] = 1, -- Cumans -> Generic
    [4] = 2, -- Leipa -> Bandits
    [5] = 2, -- Kuttenberg -> Bandits
    [6] = 2  -- Skalitz -> Bandits
}

-- Returns the outfit index renegades should wear given what the mercs
-- are wearing. Falls back to "next preset over" for anything not covered
-- above, so it's always guaranteed to differ from mercOutfit.
function mercenaries:GetRenegadeOutfitFor(mercOutfit)
    local override = self.RenegadeOutfitOverride[mercOutfit]
    if override then return override end

    local outfitCount = 0
    for _ in pairs(self.Outfits) do outfitCount = outfitCount + 1 end
    if outfitCount < 2 then return mercOutfit end

    return ((mercOutfit % outfitCount) + 1)
end

-- Anti-swarm bookkeeping for renegades, same shape as the mercs' own
-- MercTargetOf/TargetLoad (see mercenaries_target_selection.lua) but kept
-- separate since renegades and mercs claim against two different pools.
mercenaries.RenegadeSwarmCap = 2
mercenaries.RenegadeTargetOf = {}   -- [renegadeWuidStr] = targetWuidStr
mercenaries.RenegadeTargetLoad = {} -- [targetWuidStr] = number of renegades currently on it

-- amount: how many to spawn (default 1)
-- outfitPreset: index into mercenaries.Outfits (default: whatever GetRenegadeOutfitFor picks for the squad's current outfit, so renegades never default to looking like the mercs)
-- tier: "weak" / "medium" / "strong" - which preset variant array to pull gear from (default "strong")
-- weaponPreset: index into mercenaries.WeaponSets, same numbering as the weapon dialogue (default: squad's current weapon)
function mercenaries:SpawnRenegade(amount, outfitPreset, tier, weaponPreset)
    amount = amount or 1
    tier = tier or "strong"
    outfitPreset = outfitPreset or self:GetRenegadeOutfitFor(_G.MercCurrentOutfit or 1)
    weaponPreset = weaponPreset or _G.MercCurrentWeapon or 1

    local ok, err = pcall(function()
        -- Find ONE safe spot behind the player, then fan the whole group out
        -- from there. Calling GetSafeSpawnPosition per-unit instead would
        -- return nearly the same point every time (player hasn't moved
        -- between iterations), stacking everyone on top of each other.
        local spawnPos, playerRot = self:GetSafeSpawnPosition(player, 8)
        if not spawnPos then return end

        local playerPos = player:GetWorldPos()
        local awayX, awayY = 0, 1
        if playerPos then
            awayX, awayY = spawnPos.x - playerPos.x, spawnPos.y - playerPos.y
            local awayLen = math.sqrt(awayX * awayX + awayY * awayY)
            if awayLen > 0.01 then
                awayX, awayY = awayX / awayLen, awayY / awayLen
            else
                awayX, awayY = 0, 1
            end
        end
        local rightX, rightY = awayY, -awayX

        local spacing = 1.8
        local rowSize = 5

        for i = 1, amount do
            local col = ((i - 1) % rowSize) + 1
            local row = math.floor((i - 1) / rowSize)
            local colOffset = (col - (rowSize + 1) / 2) * spacing
            local rowOffset = row * spacing

            local px = spawnPos.x + rightX * colOffset + awayX * rowOffset
            local py = spawnPos.y + rightY * colOffset + awayY * rowOffset
            local unitPos = self:FindValidGround({ x = px, y = py, z = spawnPos.z }, spawnPos.z)

            local soulGuid = self.RenegadeSouls[self.RenegadeSoulIndex]
            self.RenegadeSoulIndex = self.RenegadeSoulIndex + 1
            if self.RenegadeSoulIndex > #self.RenegadeSouls then
                self.RenegadeSoulIndex = 1
            end

            -- The tier has to live in the entity name: EquipMercenary/
            -- EquipMercenaryWeapon parse it back out of the name string
            -- (same convention real mercs are spawned with).
            local entityName = "SpawnedRenegade_" .. tier .. "_" .. tostring(math.random(10000, 99999)) .. "_" .. soulGuid

            System.SpawnEntity({
                class = "NPC",
                name = entityName,
                position = unitPos,
                orientation = { x = 0, y = 0, z = playerRot.z },
                properties = { guidSharedSoulId = soulGuid }
            })

            local ent = System.GetEntityByName(entityName)
            if ent then
                self:EquipMercenary(ent, outfitPreset)
                self:EquipMercenaryWeapon(ent, weaponPreset)
                -- No manual DrawWeapon() here on purpose: renegade_attack.xml's
                -- MeleeOffenseAutomationDecorator/WeaponAutomationDecorator own
                -- weapon draw once combat starts, same as every other combat
                -- tree in this mod. Forcing a draw here races the entity's
                -- just-spawned init and can leave it stuck in a state the
                -- automation doesn't expect - the likely cause of renegades
                -- that spawn in and never react.
            end
        end
    end)

    if not ok then System.LogAlways('[Mercenaries] SpawnRenegade error: ' .. tostring(err)) end

    System.LogAlways('[Mercenary Jeff] Spawned ' .. amount .. ' renegade(s), tier ' .. tostring(tier) .. ', outfit preset ' .. tostring(outfitPreset) .. '.')
end

-- Called every ~1s from renegade_scheduler.xml (data.currentTarget).
-- Renegades attack indiscriminately - anything alive within 50m, player
-- included, no faction/hostility filtering. The only restraint is the
-- swarm cap: prefer a target fewer than RenegadeSwarmCap renegades are
-- already on. If everything in range is already at cap, gang up anyway
-- rather than a renegade just standing there with nothing to do.
--
-- Sticks with the current target as long as it's alive and still close
-- (within RenegadeTargetStickRange) instead of re-rolling every tick -
-- only actually rescans once the target dies, despawns, or gets far
-- enough away that it's worth reconsidering.
mercenaries.RenegadeTargetStickRange = 5.0

function mercenaries:FindRenegadeTarget(data, myWuid)
    local ok, err = pcall(function()
        local me = XGenAIModule.GetEntityByWUID(myWuid)
        if not me then return end
        local mp = me:GetPos()
        if not mp then return end

        if data.currentTarget then
            local curEnt = XGenAIModule.GetEntityByWUID(data.currentTarget)
            if curEnt and self:IsAliveAndWell(curEnt, true) then
                local cp = curEnt:GetPos()
                if cp then
                    local dx, dy, dz = cp.x - mp.x, cp.y - mp.y, cp.z - mp.z
                    local d2 = dx * dx + dy * dy + dz * dz
                    if d2 <= (self.RenegadeTargetStickRange * self.RenegadeTargetStickRange) then
                        return -- current target still alive and close - keep it, skip rescanning
                    end
                end
            end
        end

        local myWuidStr = tostring(myWuid)
        local radius = 50.0
        local radiusSq = radius * radius

        -- Rebuild the swarm-load table from current claims before picking.
        self.RenegadeTargetLoad = {}
        for _, targetWuidStr in pairs(self.RenegadeTargetOf) do
            self.RenegadeTargetLoad[targetWuidStr] = (self.RenegadeTargetLoad[targetWuidStr] or 0) + 1
        end

        local candidates = {}

        if player then
            local pp = player:GetPos()
            if pp and self:IsAliveAndWell(player, true) then
                local dx, dy, dz = pp.x - mp.x, pp.y - mp.y, pp.z - mp.z
                local d2 = dx * dx + dy * dy + dz * dz
                if d2 <= radiusSq then
                    table.insert(candidates, { wuid = player.this.id, distSq = d2 })
                end
            end
        end

        local ents = System.GetPhysicalEntitiesInBoxByClass(mp, radius, "NPC")
        if ents then
            for _, ent in pairs(ents) do
                if ent and type(ent) == "table" and ent.soul and ent.this and ent.this.id then
                    local entWuidStr = tostring(ent.this.id)
                    -- Skip self and other renegades - they fight everyone else, not each other.
                    if entWuidStr ~= myWuidStr and not string.find(ent:GetName() or '', 'SpawnedRenegade_', 1, true) then
                        if self:IsAliveAndWell(ent, true) then
                            local ep = ent:GetPos()
                            if ep then
                                local dx, dy, dz = ep.x - mp.x, ep.y - mp.y, ep.z - mp.z
                                local d2 = dx * dx + dy * dy + dz * dz
                                if d2 <= radiusSq then
                                    table.insert(candidates, { wuid = ent.this.id, distSq = d2 })
                                end
                            end
                        end
                    end
                end
            end
        end

        if #candidates == 0 then
            data.currentTarget = nil
            self.RenegadeTargetOf[myWuidStr] = nil
            return
        end

        table.sort(candidates, function(a, b) return a.distSq < b.distSq end)

        local chosen = nil
        for _, c in ipairs(candidates) do
            local load = self.RenegadeTargetLoad[tostring(c.wuid)] or 0
            if load < self.RenegadeSwarmCap then
                chosen = c.wuid
                break
            end
        end
        if not chosen then
            -- Everyone in range is already at the swarm cap - gang up on
            -- the nearest one rather than idling.
            chosen = candidates[1].wuid
        end

        data.currentTarget = chosen
        self.RenegadeTargetOf[myWuidStr] = tostring(chosen)
    end)

    if not ok then System.LogAlways('[Mercenaries] FindRenegadeTarget error: ' .. tostring(err)) end
end