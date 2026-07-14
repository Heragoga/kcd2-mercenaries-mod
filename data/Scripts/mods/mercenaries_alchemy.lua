-- =======================================================================
-- CAMP ALCHEMY BENCH  (Alchemy Bench upgrade made real)
--
-- Mirrors the camp forge (see mercenaries_forge.lua and docs/camp-forge.md).
-- Unlike the Smithery, the AlchemyTable entity renders its OWN table model AND
-- drives the brewing minigame / E prompt, so we just borrow the nearest loaded
-- village AlchemyTable and move it to the flattest patch near camp - dragging
-- its dressing entities (AlchemyItems: retort / mortar / bellows / pot / flasks;
-- boiling & fire particles; fireplace lights) along by the same offset so the
-- whole bench keeps its shape and the minigame's use helper (which is baked into
-- the entity) travels with it. Restored on camp break; auto-restored if the
-- player wanders back near the village it came from.
--
-- Reuses the forge's ForgeFindNearest / ForgeFindFlattest / ForgeFlatness.
-- =======================================================================

mercenaries.CampAlchemy = nil               -- borrow record while a camp bench is up
mercenaries.CampAlchemyAutoPackDist = 30.0  -- restore the borrowed table if player nears its village

-- The visible bench mesh spawned under the borrowed props (see SpawnCampAlchemy).
mercenaries.CampAlchemyTableModel = "objects/manmade/task_specific_props/alchemy/alchemy_table_a/alchemy_table_a.cgf"

-- The known alchemy-table meshes, for the merc_alchemy_variants test command.
mercenaries.CampAlchemyVariants = {
    "objects/manmade/task_specific_props/alchemy/alchemy_table_a/alchemy_table_a.cgf",
    "objects/manmade/task_specific_props/alchemy/alchemy_table_b/alchemy_table_b.cgf",
    "objects/manmade/task_specific_props/alchemy/alchemy_table_master/alchemy_table_master.cgf",
}
mercenaries.CampAlchemyVariantEnts = {}

-- Spawn every known alchemy-table model in a row to the player's right (labelled
-- in the log, left -> right = the list order above) so the good one can be
-- picked by eye. Re-running clears the previous row; merc_alchemy_variants_clear
-- removes them.
function mercenaries:AlchemyVariantTest()
    for _, id in ipairs(self.CampAlchemyVariantEnts) do pcall(function() System.RemoveEntity(id) end) end
    self.CampAlchemyVariantEnts = {}
    if not player then return end
    local o = player:GetWorldPos()
    local ang; pcall(function() ang = player:GetWorldAngles() end)
    local yaw = (ang and ang.z) or 0
    local fx, fy = math.cos(yaw), math.sin(yaw)    -- forward
    local rx, ry = -fy, fx                          -- player's left->right axis
    local n = #self.CampAlchemyVariants
    for i, model in ipairs(self.CampAlchemyVariants) do
        local off = (i - (n + 1) / 2) * 3.0
        local pos = { x = o.x + fx * 5.0 + rx * off, y = o.y + fy * 5.0 + ry * off, z = o.z }
        local e
        pcall(function()
            e = System.SpawnEntity({ class = "BasicEntity",
                name = "MercAlchemyVariant_" .. i .. "_" .. tostring(math.random(100000, 999999)),
                position = pos, orientation = { x = 0, y = 0, z = yaw + math.pi },
                properties = { object_Model = model, bMissionCritical = false } })
        end)
        if e then table.insert(self.CampAlchemyVariantEnts, e.id) end
        System.LogAlways(string.format("[AlchemyVariant] slot %d (from your left) = %s  [%s]",
            i, model:match("alchemy_table_[a-z]+") or model, e and "spawned" or "FAILED"))
    end
end

function mercenaries:AlchemyVariantClear()
    for _, id in ipairs(self.CampAlchemyVariantEnts) do pcall(function() System.RemoveEntity(id) end) end
    self.CampAlchemyVariantEnts = {}
end

System.AddCCommand("merc_alchemy_variants",       "mercenaries:AlchemyVariantTest()",  "Spawn all alchemy-table meshes in a row (left->right: a, b, master) to compare")
System.AddCCommand("merc_alchemy_variants_clear", "mercenaries:AlchemyVariantClear()", "Remove the alchemy-table test row")

-- The bench's dressing entities to drag along with the table, and how far from
-- the table they sit (the prefab keeps everything within ~2m).
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

    -- Flattest patch, avoiding the camp forge's spot if one is up (so the two
    -- upgrades don't land on top of each other).
    local avoid = self.CampForge and self.CampForge.anvilPos or nil
    local spot = self:ForgeFindFlattest(center, avoid)
    if not spot then
        spot = self:CampSnapToGround({ x = center.x - 8, y = center.y, z = center.z })
    end

    local origPos = at:GetWorldPos()
    local origAng
    pcall(function() origAng = at:GetWorldAngles() end)
    local rec = { at = at, atPos = origPos, moved = {}, spawned = {} }
    local dx, dy, dz = spot.x - origPos.x, spot.y - origPos.y, spot.z - origPos.z

    -- Drag the dressing entities: record each (for restore), then translate it by
    -- the same delta as the table so the layout is preserved. (Static Brush
    -- decorations aren't entities and can't be moved, so a few flasks/tripod stay
    -- behind - the table + AlchemyItems carry the bulk of the look.)
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

    -- Move the table itself last (the proximity search above used its real pos).
    pcall(function() at:SetWorldPos(spot) end)

    -- The AlchemyTable's E-prompt/minigame logic and the AlchemyItem props follow
    -- SetWorldPos, but its own table MESH is brush-rendered and stays behind (so
    -- the props end up floating). Spawn our own copy of the table model at the new
    -- spot, matched to the table's rotation, so there's a solid bench underneath.
    -- Table mesh model. alchemy_table_b is see-through from the back and
    -- alchemy_table_master rendered invisible when spawned as a BasicEntity, so we
    -- default to alchemy_table_a. Use the merc_alchemy_variants console command to
    -- compare all three in-game and change this if a different one looks better.
    local mesh
    pcall(function()
        mesh = System.SpawnEntity({ class = "BasicEntity",
            name = "MercCampAlchemyTable_" .. tostring(math.random(100000, 999999)),
            position = spot,
            properties = { object_Model = mercenaries.CampAlchemyTableModel, bMissionCritical = false } })
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
