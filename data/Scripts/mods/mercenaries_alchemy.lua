-- Camp alchemy bench: borrows a village AlchemyTable, moves it near camp, and
-- drags its dressing props along. See docs/mercenaries/camp/camp-alchemy.md.

mercenaries.CampAlchemy = nil
-- REMOVED in 3.2.1. The bench was a real village AlchemyTable carried to the camp, and the
-- brewing minigame never accepted the move: the pot vanished the moment you brewed at camp,
-- and the village it came from was left without a working bench. Off: nothing is borrowed any
-- more, and AlchemyRetire (run on every load) refunds a bench a save still owns and sends a
-- table an older version borrowed back to its village, reset.
mercenaries.CampAlchemyEnabled = false
mercenaries.CampAlchemyAutoPackDist = 30.0
mercenaries.CampAlchemyTableModel = "objects/manmade/task_specific_props/alchemy/alchemy_table_a/alchemy_table_a.cgf"
mercenaries.CampAlchemyPropClasses = { "AlchemyItem", "ParticleEffect", "Light", "GeomEntity" }
mercenaries.CampAlchemyPropRadius = 3.5
-- How far from the table a LINKED entity may stand and still be one of its own (see below).
mercenaries.CampAlchemyLinkRadius = 12.0

-- Everything the table is LINKED to - the same lesson as the forge's `alignment` link. The
-- brewing minigame (Alchemy.StartAlchemy) drives the entities the table links to: its pot,
-- its tools, the point the player is stood at. Moving only what stood within a few metres
-- of the table left any linked piece further out behind in the village, so the moment you
-- brewed at camp the pot "disappeared" (it was being used where it had always been), and
-- that village's bench was left short of it too. Every linked entity near the table now
-- travels with it and comes home with it. NPCs are never moved.
local function linkedEntities(at, home, radius)
    local out = {}
    pcall(function()
        local n = at:CountLinks() or 0
        for i = 0, n - 1 do
            local l
            pcall(function() l = at:GetLink(i) end)
            if l and l.id and l ~= at then
                local cls, nm, p = "", "", nil
                pcall(function() cls = l.class or (l.GetClass and l:GetClass()) or "" end)
                pcall(function() nm = l.GetName and l:GetName() or "" end)
                pcall(function() p = l:GetWorldPos() end)
                local d = p and home and math.sqrt((p.x - home.x) ^ 2 + (p.y - home.y) ^ 2 + (p.z - home.z) ^ 2) or -1
                local take = p and cls ~= "NPC" and d >= 0 and d <= radius
                System.LogAlways(string.format("[CampAlchemy] link %d: %s '%s' %.1fm from home%s",
                    i, tostring(cls), tostring(nm), d, take and "" or " - left alone"))
                if take then out[#out + 1] = { e = l, pos = p } end
            end
        end
    end)
    return out
end

-- Build the camp alchemy bench near `center`. Returns true on success.
function mercenaries:SpawnCampAlchemy(center)
    if not self.CampAlchemyEnabled then return false end
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

    -- Home is the SAVED home when the table is found already standing at the camp after
    -- a load - see StationHome in mercenaries_forge.lua and the note in SpawnCampForge:
    -- recording the camp as home is what tore the bench down two seconds after every load.
    local origPos = self:StationHome("CampAlchemyHome", at, spot)
    local origAng
    pcall(function() origAng = at:GetWorldAngles() end)
    local rec = { at = at, atPos = origPos, moved = {}, spawned = {}, spot = spot }
    if self:StationHomeIsHere(origPos, spot) then
        rec.noAutoPack = true
        System.LogAlways("[CampAlchemy] the village table is within reach of the camp - it will not be packed on approach")
    end
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

    -- Then everything the table is linked to (see linkedEntities), wherever it stands.
    -- After a load the table is already at camp but its links may not be - a 2.5 bench left
    -- its pot in the village - so they are measured from the table's HOME and moved by the
    -- same delta, which brings a stranded pot to the bench as well.
    local seen = {}
    for _, m in ipairs(rec.moved) do seen[m.e.id] = true end
    local nlinks = 0
    for _, lk in ipairs(linkedEntities(at, origPos, self.CampAlchemyLinkRadius)) do
        if not seen[lk.e.id] then
            seen[lk.e.id] = true
            table.insert(rec.moved, { e = lk.e, origPos = lk.pos })
            pcall(function() lk.e:SetWorldPos({ x = lk.pos.x + dx, y = lk.pos.y + dy, z = lk.pos.z + dz }) end)
            nlinks = nlinks + 1
        end
    end
    if nlinks > 0 then System.LogAlways("[CampAlchemy] " .. nlinks .. " linked entit(ies) moved with the table") end

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
    -- Bottles dragged here in an EARLIER session came back with the save already at the
    -- bench, so they are in nobody's `moved` list: whatever AlchemyItem is still at the
    -- bench goes home by the same offset the table does. Only that class - the camp's own
    -- lights and particles can stand within a bench-length of the tile.
    if rec.spot and rec.atPos then
        local dx, dy, dz = rec.atPos.x - rec.spot.x, rec.atPos.y - rec.spot.y, rec.atPos.z - rec.spot.z
        local sent = 0
        local ok, list = pcall(function() return System.GetEntitiesByClass("AlchemyItem") end)
        if ok and list then
            for _, e in pairs(list) do
                local p = e.GetWorldPos and e:GetWorldPos()
                if p and e ~= rec.at then
                    local d = math.sqrt((p.x - rec.spot.x) ^ 2 + (p.y - rec.spot.y) ^ 2 + (p.z - rec.spot.z) ^ 2)
                    if d <= (self.CampAlchemyPropRadius or 3.5) then
                        pcall(function() e:SetWorldPos({ x = p.x + dx, y = p.y + dy, z = p.z + dz }) end)
                        sent = sent + 1
                    end
                end
            end
        end
        -- ...and the table's linked entities still standing at camp from an earlier session.
        for _, lk in ipairs(linkedEntities(rec.at, rec.spot, self.CampAlchemyLinkRadius)) do
            pcall(function() lk.e:SetWorldPos({ x = lk.pos.x + dx, y = lk.pos.y + dy, z = lk.pos.z + dz }) end)
            sent = sent + 1
        end
        if sent > 0 then System.LogAlways("[CampAlchemy] " .. sent .. " item(s) left from an earlier session sent home") end
    end
    -- The game's own reset: every linked alchemy item back on its default spot at the
    -- village bench, whatever the camp or an interrupted brew left it doing.
    pcall(function() Alchemy.ResetTable(rec.at.id) end)
    for _, id in ipairs(rec.spawned or {}) do
        pcall(function() System.RemoveEntity(id) end)
    end
    self.CampAlchemy = nil
    self:StationHomeForget("CampAlchemyHome")
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
        if player and rec.atPos and not rec.noAutoPack then
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

-- ==== retiring the bench (3.2.1) ====
local function dist2d(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end

function mercenaries:AlchemyRetire()
    if self.CampAlchemyEnabled then return end
    -- 1. A save that owns the upgrade: the money back into the war chest, once.
    pcall(function()
        local L = self:LogiState()
        if L.hasAlchemy then
            L.hasAlchemy = false
            L.coffer = (L.coffer or 0) + (self.UpgAlchemyCost or 0)
            self:LogiSave()
            System.LogAlways("[CampAlchemy] the alchemy bench is gone from the mod - "
                .. tostring(self.UpgAlchemyCost or 0) .. " groschen refunded to the war chest")
        end
    end)
    -- 2. A village table an older version carried to the camp: the engine restored it there.
    local home = self:StationHomeLoad("CampAlchemyHome")
    if not home then return end
    local cx, cy
    pcall(function()
        cx = tonumber(self:LoadString("MercCampX"))
        cy = tonumber(self:LoadString("MercCampY"))
    end)
    if not (cx and cy) then return end
    local best, bestD
    pcall(function()
        for _, t in pairs(System.GetEntitiesByClass("AlchemyTable") or {}) do
            local p = t:GetWorldPos()
            if p and dist2d(p, home) > 5 then
                local d = dist2d(p, { x = cx, y = cy })
                if d <= (self.StationHomeNearCamp or 60) + 20 and (not bestD or d < bestD) then
                    best, bestD = t, d
                end
            end
        end
    end)
    if not best then
        self:StationHomeForget("CampAlchemyHome")
        return
    end
    local at = best:GetWorldPos()
    local dx, dy, dz = home.x - at.x, home.y - at.y, home.z - at.z
    local sent = 0
    local function send(e)
        local p
        pcall(function() p = e:GetWorldPos() end)
        if p then
            pcall(function() e:SetWorldPos({ x = p.x + dx, y = p.y + dy, z = p.z + dz }) end)
            sent = sent + 1
        end
    end
    local seen = {}
    pcall(function()
        for _, e in pairs(System.GetEntitiesByClass("AlchemyItem") or {}) do
            local p = e:GetWorldPos()
            if p and dist2d(p, at) <= (self.CampAlchemyPropRadius or 3.5) then seen[e.id] = true; send(e) end
        end
    end)
    for _, lk in ipairs(linkedEntities(best, at, self.CampAlchemyLinkRadius or 12)) do
        if not seen[lk.e.id] then seen[lk.e.id] = true; send(lk.e) end
    end
    pcall(function() best:SetWorldPos(home) end)
    pcall(function() Alchemy.ResetTable(best.id) end)
    self:StationHomeForget("CampAlchemyHome")
    System.LogAlways(string.format("[CampAlchemy] borrowed AlchemyTable sent home (%.0f, %.0f) with %d item(s), and reset",
                                   home.x, home.y, sent))
end

function mercenaries.AlchemyRetireTick()
    pcall(function() mercenaries:AlchemyRetire() end)
end
