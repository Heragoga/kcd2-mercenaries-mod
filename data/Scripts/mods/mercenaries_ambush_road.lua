-- Road ambush (test command).
--
-- Spawns an ambush around the player's party on whichever recorded patrol route he is
-- standing near: melee blocking the road ahead and behind, archers off both flanks.
--
-- The layout is measured from the PARTY, not from the player alone. A twenty-man squad
-- strung out along a road has a real extent, and an ambush placed off the player's own
-- position would drop archers inside the column. So the party is projected onto the road
-- axis, and every spawn sits outside that box by a margin - a surround that does not
-- intersect whoever it is surrounding.
--
-- Ambushers are ordinary enemy-group NPCs (SpawnEnemyAt), NOT patrol souls: that path
-- already picks archer souls and the ranged brain for isArcher, which patrolguard_brain
-- has no equivalent of. They fight and get looted like any other mod enemy.

mercenaries.AmbRoadMeleeGap   = 8.0    -- melee this far beyond the party, along the road
mercenaries.AmbRoadArcherGap  = 14.0   -- archers this far out to the side
mercenaries.AmbRoadSpread     = 2.0    -- spacing between men in a group
mercenaries.AmbRoadNearRoute  = 30.0   -- how close to a route counts as "on the road"
mercenaries.AmbRoadEnts       = {}

local function aLog(s) System.LogAlways("[Ambush] " .. s) end

-- The party: the player and every living merc with him.
function mercenaries:AmbRoadParty()
    local out = {}
    pcall(function()
        local p = player:GetWorldPos()
        if p then table.insert(out, p) end
    end)
    for _, m in pairs(self.ActiveMercs or {}) do
        if m and self:IsAliveAndWell(m, true) then
            pcall(function()
                local q = m:GetWorldPos()
                if q then table.insert(out, q) end
            end)
        end
    end
    return out
end

-- Nearest point on any route of the current set, and the road's direction there.
function mercenaries:AmbRoadAxis(pp)
    local routes = self.PatrolRouteData
    if not routes then return nil end
    local bR, bI, bD2
    for ri, r in ipairs(routes) do
        for i, q in ipairs(r.pts) do
            local dx, dy = q.x - pp.x, q.y - pp.y
            local d2 = dx * dx + dy * dy
            if not bD2 or d2 < bD2 then bR, bI, bD2 = ri, i, d2 end
        end
    end
    if not bR then return nil end
    if math.sqrt(bD2) > self.AmbRoadNearRoute then return nil, math.sqrt(bD2) end

    -- tangent from the neighbouring points, so the axis follows the road rather than
    -- whichever way the player happens to be facing
    local pts = routes[bR].pts
    local a = pts[math.max(1, bI - 1)]
    local b = pts[math.min(#pts, bI + 1)]
    local tx, ty = b.x - a.x, b.y - a.y
    local L = math.sqrt(tx * tx + ty * ty)
    if L < 1e-3 then tx, ty, L = 1, 0, 1 end
    return { x = tx / L, y = ty / L }, math.sqrt(bD2), pts[bI]
end

function mercenaries:AmbRoadSpawn(line)
    local a = {}
    for w in tostring(line or ""):gmatch("%S+") do a[#a + 1] = w end
    local total   = tonumber(a[1])           -- optional override; otherwise party + 1
    local group   = (a[2] ~= nil and a[2] ~= "") and a[2] or "bandit"

    if not player then return end
    if not self.EnemyGroups[group] then aLog("unknown group '" .. group .. "'"); return end

    local pp; pcall(function() pp = player:GetWorldPos() end)
    if not pp then return end

    local axis, dist, onRoad = self:AmbRoadAxis(pp)
    if not axis then
        aLog(string.format("no recorded route within %.0fm (nearest %.0fm) - stand on a patrol road",
            self.AmbRoadNearRoute, dist or -1))
        return
    end

    local nx, ny = -axis.y, axis.x          -- across the road
    local party = self:AmbRoadParty()
    if #party == 0 then return end

    -- Enough of them to be a fight: one more than the party they are jumping. Half melee,
    -- half archers, with an odd man going to the melee blocking the road.
    total = total or (#party + 1)
    if total < 2 then total = 2 end
    local nArcherAll = math.floor(total / 2)
    local nMeleeAll  = total - nArcherAll
    local meleeFront, meleeBack = math.ceil(nMeleeAll / 2), math.floor(nMeleeAll / 2)
    local archRight, archLeft   = math.ceil(nArcherAll / 2), math.floor(nArcherAll / 2)

    -- the party's box in road space: how far it reaches along the road and across it
    local minT, maxT, minN, maxN
    local originX, originY = onRoad.x, onRoad.y
    for _, q in ipairs(party) do
        local dx, dy = q.x - originX, q.y - originY
        local tproj = dx * axis.x + dy * axis.y
        local nproj = dx * nx + dy * ny
        minT = math.min(minT or tproj, tproj); maxT = math.max(maxT or tproj, tproj)
        minN = math.min(minN or nproj, nproj); maxN = math.max(maxN or nproj, nproj)
    end

    self:AmbRoadClear()
    local made = 0
    local function put(tOff, nOff, isArcher, faceT)
        local x = originX + axis.x * tOff + nx * nOff
        local y = originY + axis.y * tOff + ny * nOff
        local pos = { x = x, y = y, z = pp.z }
        if self.FindValidGround then pos = self:FindValidGround(pos, pp.z) end
        local yaw = math.atan2(-axis.y * faceT - ny * nOff, -axis.x * faceT - nx * nOff)
        local e = self:SpawnEnemyAt(group, isArcher, pos, yaw)
        if e then table.insert(self.AmbRoadEnts, e); made = made + 1 end
    end

    -- melee: on the road, blocking both ways out, just beyond the column's ends
    for i = 1, meleeFront do
        put(maxT + self.AmbRoadMeleeGap, (i - (meleeFront + 1) / 2) * self.AmbRoadSpread, false, 1)
    end
    for i = 1, meleeBack do
        put(minT - self.AmbRoadMeleeGap, (i - (meleeBack + 1) / 2) * self.AmbRoadSpread, false, -1)
    end

    -- archers: off both flanks, clear of the column's width, spread along its length
    local function flank(n, side)
        for i = 1, n do
            local along = (n == 1) and ((minT + maxT) / 2)
                          or (minT + (maxT - minT) * ((i - 0.5) / n))
            put(along, side, true, 0)
        end
    end
    flank(archRight, maxN + self.AmbRoadArcherGap)
    flank(archLeft,  minN - self.AmbRoadArcherGap)

    aLog(string.format("%d %s ambush %d in the party: %d+%d melee front/back, %d+%d archers; "
        .. "party spans %.0fm of road, %.0fm wide",
        made, group, #party, meleeFront, meleeBack, archRight, archLeft,
        maxT - minT, maxN - minN))
end

function mercenaries:AmbRoadClear()
    local n = 0
    for _, e in ipairs(self.AmbRoadEnts or {}) do
        pcall(function() System.RemoveEntity(e.id) end); n = n + 1
    end
    self.AmbRoadEnts = {}
    if n > 0 then aLog("removed " .. n .. " ambusher(s)") end
end

mercenaries:DevCommand("merc_ambush_road",       "mercenaries:AmbRoadSpawn('%line')",
    "Ambush your party on the road you are standing on: merc_ambush_road [total] [group] - total defaults to your party + 1, half melee half archers")
mercenaries:DevCommand("merc_ambush_road_clear", "mercenaries:AmbRoadClear()", "Remove the road ambush")
