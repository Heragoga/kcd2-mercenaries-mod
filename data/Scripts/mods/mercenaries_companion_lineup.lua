-- Custom-companion lineup. Spawns one NPC per entry in CustomCompanionsData in a
-- row so the whole roster can be inspected side by side. Debug only.
--
-- These are NOT squad members: they use their own entity prefix, never enter
-- ActiveMercs, cost nothing and ignore MaxCompanions. Their looks and gear come
-- from the storm rules keyed on the soul, so what stands here is exactly what a
-- hire produces.

mercenaries.CCLineupPrefix  = "MercCCLineup_"
mercenaries.CCLineupRowSize = 11
mercenaries.CCLineupSpacing = 2.2
mercenaries.CCLineupRankGap = 3.5
mercenaries.CCLineupSpawned = {}   -- [entityName] = { ccID, name, ent }

local function ccLog(msg)
    System.LogAlways("[Mercenaries][cclineup] " .. tostring(msg))
end

function mercenaries:CCLineupClear()
    local n = 0
    for name, _ in pairs(self.CCLineupSpawned) do
        local ent = System.GetEntityByName(name)
        if ent then
            pcall(function() System.RemoveEntity(ent.id) end)
            n = n + 1
        end
    end
    self.CCLineupSpawned = {}
    if n > 0 then ccLog("cleared " .. n .. " lineup NPCs.") end
end

-- startID/count let a long roster be split over several rows-of-rows; both
-- default to "all of them".
function mercenaries:CCLineupSpawn(startID, count)
    startID = tonumber(startID) or 1

    local ids = {}
    for ccID, _ in pairs(self.CustomCompanionsData) do ids[#ids + 1] = ccID end
    table.sort(ids)

    local wanted = {}
    for _, ccID in ipairs(ids) do
        if ccID >= startID then wanted[#wanted + 1] = ccID end
    end
    count = tonumber(count) or #wanted
    while #wanted > count do table.remove(wanted) end

    if #wanted == 0 then ccLog("nothing to spawn") return end

    self:CCLineupClear()

    local ok, err = pcall(function()
        local spawnPos, playerRot = self:GetSafeSpawnPosition(player, 6)
        if not spawnPos then ccLog("no safe spawn position") return end

        -- Lay the row across the player's facing, first rank nearest him, so the
        -- whole line is readable from where he is standing.
        local playerPos = player:GetWorldPos()
        local awayX, awayY = 0, 1
        if playerPos then
            awayX, awayY = spawnPos.x - playerPos.x, spawnPos.y - playerPos.y
            local len = math.sqrt(awayX * awayX + awayY * awayY)
            if len > 0.01 then awayX, awayY = awayX / len, awayY / len
            else awayX, awayY = 0, 1 end
        end
        local rightX, rightY = awayY, -awayX

        local rowSize = self.CCLineupRowSize
        local spawned, failed = 0, 0

        for n, ccID in ipairs(wanted) do
            local data = self.CustomCompanionsData[ccID]
            local label = (data.name or ("cc" .. ccID)):gsub("[^%w]", "")
            local col = (n - 1) % rowSize
            local row = math.floor((n - 1) / rowSize)
            local colOffset = (col - (rowSize - 1) / 2) * self.CCLineupSpacing
            local rowOffset = row * self.CCLineupRankGap
            local pos = self:FindValidGround({
                x = spawnPos.x + rightX * colOffset + awayX * rowOffset,
                y = spawnPos.y + rightY * colOffset + awayY * rowOffset,
                z = spawnPos.z
            }, spawnPos.z)

            local entityName = self.CCLineupPrefix .. string.format("%02d", ccID) .. "_" .. label
            System.SpawnEntity({
                class = "NPC",
                name = entityName,
                position = pos,
                orientation = { x = 0, y = 0, z = (playerRot and playerRot.z) or 0 },
                properties = { guidSharedSoulId = data.guid }
            })

            local ent = System.GetEntityByName(entityName)
            if ent then
                pcall(function() self:EnsureMercIsAlwaysRendered(ent) end)
                self.CCLineupSpawned[entityName] = { ccID = ccID, name = data.name, ent = ent }
                spawned = spawned + 1
                ccLog(string.format("ok    #%02d r%dc%-2d %-24s %s",
                    ccID, row + 1, col + 1, data.name or "?", data.guid))
            else
                failed = failed + 1
                ccLog(string.format("FAIL  #%02d %-24s entity did not spawn (soul %s)",
                    ccID, data.name or "?", data.guid))
            end
        end

        ccLog(string.format("lineup: %d spawned, %d failed. Rows of %d, rank 1 nearest "
            .. "you, numbered left to right by companion id.", spawned, failed, rowSize))
    end)
    if not ok then ccLog("spawn error: " .. tostring(err)) end
end

-- An NPC that spawns but never renders reads exactly like one that failed to
-- spawn, so name whoever is standing closest and say what he should look like.
function mercenaries:CCLineupWho()
    local pos = player:GetWorldPos()
    if not pos then return end
    local best, bestName, bestDist = nil, nil, 9999
    for name, rec in pairs(self.CCLineupSpawned) do
        local ent = System.GetEntityByName(name)
        if ent then
            local p = ent:GetWorldPos()
            local d = math.sqrt((p.x - pos.x) ^ 2 + (p.y - pos.y) ^ 2 + (p.z - pos.z) ^ 2)
            if d < bestDist then best, bestName, bestDist = rec, name, d end
        end
    end
    if not best then ccLog("no lineup NPC nearby - spawn one with merc_cc_lineup") return end
    local hp = "?"
    pcall(function() hp = tostring(best.ent.soul:GetState("health")) end)
    ccLog(string.format("#%02d %s (%.1fm) soul=%s health=%s entity=%s",
        best.ccID, best.name or "?", bestDist,
        self.CustomCompanionsData[best.ccID].guid, hp, bestName))
end

function mercenaries:CCLineupDraw()
    local n = 0
    for name, _ in pairs(self.CCLineupSpawned) do
        local ent = System.GetEntityByName(name)
        if ent then
            pcall(function() ent.human:DrawWeapon() end)
            n = n + 1
        end
    end
    ccLog("told " .. n .. " to draw; give it a few seconds before judging empty hands.")
end

mercenaries:DevCommand("merc_cc_lineup",    "mercenaries:CCLineupSpawn()",       "Spawn every custom companion in a row in front of you (free, not squad members)")
mercenaries:DevCommand("merc_cc_lineup_p1", "mercenaries:CCLineupSpawn(1, 11)",  "Lineup, companions 1-11 only")
mercenaries:DevCommand("merc_cc_lineup_p2", "mercenaries:CCLineupSpawn(12, 11)", "Lineup, companions 12-22 only")
mercenaries:DevCommand("merc_cc_lineup_p3", "mercenaries:CCLineupSpawn(23, 11)", "Lineup, companions 23-33 only")
mercenaries:DevCommand("merc_cc_lineup_p4", "mercenaries:CCLineupSpawn(34, 11)", "Lineup, companions 34-44 only")
mercenaries:DevCommand("merc_cc_draw",      "mercenaries:CCLineupDraw()",        "Make the lineup draw, so an empty hand means something is really wrong")
mercenaries:DevCommand("merc_cc_who",       "mercenaries:CCLineupWho()",         "Name the lineup NPC you are standing next to")
mercenaries:DevCommand("merc_cc_clear",     "mercenaries:CCLineupClear()",       "Despawn the lineup")

-- Why is this companion not behaving like a merc? Every gate that stands between an
-- entity and the squad systems, reported for each companion AND for one regular merc
-- as a control - a companion line means nothing on its own, only the difference does.
--
-- getActions is the hold-E prompt: InjectInteraction overrides GetActions on the entity
-- table, so "no" there means the injection never ran or did not stick.
local function ccDiagOne(self, label, name, ent)
    local wuid = ent and (ent.this and ent.this.id or ent.id)
    local key  = tostring(wuid)
    local function yes(f)
        local ok, v = pcall(f)
        if not ok then return "err" end
        return v and "yes" or "no "
    end
    ccLog(string.format(
        "%-8s %s\n"
        .. "         type=%-8s alive=%s  wuid=%s\n"
        .. "         getActions=%s campContext=%s  <- the hold-E prompt\n"
        .. "         formationEligible=%s slot=%-5s inCampProper=%s campActor=%s npcFormation=%s\n"
        .. "         campMember=%s campOut=%s sortie=%s",
        label, name,
        tostring(self:GetMercType(ent)),
        yes(function() return self:IsAliveAndWell(ent, false) end),
        key,
        yes(function() return type(ent.GetActions) == "function" end),
        yes(function() return type(ent.CampContextAction) == "function" end),
        yes(function() return self:IsFormationEligible(ent, wuid) end),
        (self.FormationSlots and self.FormationSlots[key]) and "set" or "none",
        yes(function() return self:IsMercInCampProper(wuid) end),
        yes(function() return self:CampActorGet(wuid) ~= nil end),
        yes(function() return self.NpcFormations and self.NpcFormations[key] ~= nil end),
        yes(function() return self:CampIsMember(key) end),
        yes(function() return self:IsCampOut(wuid) end),
        yes(function() return self:IsMercInSortie(wuid) end)))
end

function mercenaries:CCDiag()
    local heroes, control = 0, nil
    for name, ent in pairs(self.ActiveMercs or {}) do
        if self:IsHeroName(name) then
            heroes = heroes + 1
            ccDiagOne(self, "COMPANION", name, ent)
        elseif not control then
            control = { name = name, ent = ent }
        end
    end
    if control then
        ccDiagOne(self, "CONTROL", control.name, control.ent)
    else
        ccLog("no regular merc to compare against - hire one and run this again")
    end
    ccLog(string.format("%d companion(s), squad total %d, camp=%s inCamp=%s idle=%s "
        .. "dismissed=%s. Every line above should read the same as CONTROL.",
        heroes, tostring(_G.MercCount), tostring(self.CampActive),
        tostring(_G.MercInCamp), tostring(_G.MercIdle),
        tostring(_G.MercenariesDismissed)))
end

mercenaries:DevCommand("merc_cc_diag", "mercenaries:CCDiag()",
                   "Report every gate between each companion and the squad systems, "
                   .. "next to a regular merc as a control")
