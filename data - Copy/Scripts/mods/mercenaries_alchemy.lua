-- Camp alchemy bench: borrows a village AlchemyTable, moves it near camp, and
-- drags its dressing props along. See docs/camp-alchemy.md.

mercenaries.CampAlchemy = nil
mercenaries.CampAlchemyAutoPackDist = 30.0
mercenaries.CampAlchemyTableModel = "objects/manmade/task_specific_props/alchemy/alchemy_table_a/alchemy_table_a.cgf"
mercenaries.CampAlchemyPropClasses = { "AlchemyItem", "ParticleEffect", "Light", "GeomEntity" }
mercenaries.CampAlchemyPropRadius = 3.5

-- Build the camp alchemy bench near `center`. Returns true on success.
function mercenaries:SpawnCampAlchemy(center)
    if self.CampAlchemy then return true end
    if not center then return false end
    local at, dist = self:ForgeFindNearest("AlchemyTable")
    if not at then
        System.LogAlways("[CampAlchemy] no loaded AlchemyTable to borrow - bench not built (camp too far from any settlement)")
        return false
    end

    -- The camp reserves a grid tile per upgrade (see CampStationTiles); only fall
    -- back to a flat-patch scan (clear of the forge) if there wasn't one.
    local spot = self:CampStationSpot("alchemy")
    if not spot then
        spot = self:ForgeFindFlattest(center, self.CampForge and self.CampForge.anvilPos or nil)
    end
    if not spot then
        spot = self:CampSnapToGround({ x = center.x - 8, y = center.y, z = center.z })
    end

    local origPos = at:GetWorldPos()
    local origAng
    pcall(function() origAng = at:GetWorldAngles() end)
    local rec = { at = at, atPos = origPos, moved = {}, spawned = {}, spot = spot }
    local dx, dy, dz = spot.x - origPos.x, spot.y - origPos.y, spot.z - origPos.z

    -- Drag the dressing props: record each (for restore), then translate by the
    -- same delta as the table so the layout is preserved.
    local nprops = 0
    for _, cls in ipairs(self.CampAlchemyPropClasses) do
        local ok, list = pcall(function() return System.GetEntitiesByClass(cls) end)
        if ok and list then
            for _, e in pairs(list) do
                local p = e.GetWorldPos and e:GetWorldPos()
                if p and e ~= at then
                    local d = math.sqrt((p.x - origPos.x) ^ 2 + (p.y - origPos.y) ^ 2 + (p.z - origPos.z) ^ 2)
                    if d <= self.CampAlchemyPropRadius then
                        table.insert(rec.moved, { e = e, origPos = p })
                        pcall(function() e:SetWorldPos({ x = p.x + dx, y = p.y + dy, z = p.z + dz }) end)
                        nprops = nprops + 1
                    end
                end
            end
        end
    end

    -- Move the table last (the proximity search above needed its real pos).
    pcall(function() at:SetWorldPos(spot) end)

    -- The table's mesh is brush-rendered and stays behind, so spawn our own copy
    -- of the model at the destination as a solid bench under the props.
    local mesh
    pcall(function()
        mesh = System.SpawnEntity({ class = "BasicEntity",
            name = "MercCampAlchemyTable_" .. tostring(math.random(100000, 999999)),
            position = spot,
            properties = { object_Model = mercenaries.CampAlchemyTableModel, bMissionCritical = false, bSaved_by_game = false, bSerialize = false } })
    end)
    if mesh then
        if origAng then pcall(function() mesh:SetAngles(origAng) end) end
        table.insert(rec.spawned, mesh.id)
    end

    self.CampAlchemy = rec
    System.LogAlways(string.format("[CampAlchemy] built (borrowed AlchemyTable %.0fm away, dragged %d props)", dist or -1, nprops))
    Script.SetTimerForFunction(2000, "mercenaries.CampAlchemyMonitor")
    return true
end

function mercenaries:DespawnCampAlchemy()
    local rec = self.CampAlchemy
    if not rec then return end
    pcall(function() rec.at:SetWorldPos(rec.atPos) end)
    for _, m in ipairs(rec.moved or {}) do
        pcall(function() m.e:SetWorldPos(m.origPos) end)
    end
    for _, id in ipairs(rec.spawned or {}) do
        pcall(function() System.RemoveEntity(id) end)
    end
    self.CampAlchemy = nil
    System.LogAlways("[CampAlchemy] torn down, village AlchemyTable restored")
end

-- Auto-restore the borrowed table if the player travels back near its village
-- (so that settlement's alchemy bench isn't left missing).
function mercenaries.CampAlchemyMonitor()
    local self = mercenaries
    local rec = self.CampAlchemy
    if not rec then return end
    local restore = false
    pcall(function()
        if player and rec.atPos then
            local o = player:GetWorldPos()
            local dd = (o.x - rec.atPos.x) ^ 2 + (o.y - rec.atPos.y) ^ 2 + (o.z - rec.atPos.z) ^ 2
            if dd < (self.CampAlchemyAutoPackDist * self.CampAlchemyAutoPackDist) then
                self:DespawnCampAlchemy()
                restore = true
            end
        end
    end)
    if self.CampAlchemy and not restore then Script.SetTimerForFunction(2000, "mercenaries.CampAlchemyMonitor") end
end
