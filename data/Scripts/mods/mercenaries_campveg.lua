-- ======================================================= vegetation, baked
--
-- A bush is invisible to everything a running game can ask. It has no physics proxy, so no
-- ray and no box query touches it; the ground under it is plain grass, so the surface rule
-- cannot see it; the AI walks straight through it. Two judged surveys found a shrub through
-- the forge hearth, bedrolls in a thicket and a tree trunk standing in the tent's own dirt
-- apron, and not one of those spots failed a single runtime test. See merc_camp_sitescan.
--
-- So the vegetation is read OFFLINE, from the level files the game itself loads, and shipped
-- with the mod as a set of tiles (tools/bake_vegetation.py, docs/camp-inspection.md). Every
-- tree, bush, bramble, stump, fallen trunk, rock and tall undergrowth on the map is in them,
-- with the box it renders in. The camp asks these tables the question the engine cannot
-- answer: "does anything grow here?"
--
-- One file per 128 m tile, loaded the first time a camp is pitched near it and kept. An
-- entry is { kind, x, y, x0, y0, x1, y1, height, trunk }:
--   kind   1 tree  2 bush/bramble/reed  3 stump  4 fallen trunk  5 rock  6 tall undergrowth
--   x, y   where the plant stands (a tree's trunk; a bush's centre)
--   x0..y1 the box it fills, on the ground plane
--   trunk  a tree's trunk radius (a guess from its size; the canopy is the box)
--
-- What counts as IN THE WAY differs by kind. A tree blocks with its trunk, not its canopy: a
-- tent under a beech is a fine camp, a tent with the beech in it is not. Everything else
-- blocks with its whole box - a prop inside a bush is the defect this exists to stop.

mercenaries.VegTiles    = mercenaries.VegTiles or {}   -- ["tx_ty"] = { entries }
mercenaries.VegField    = mercenaries.VegField or {}   -- ["tx_ty"] = 32x32 '0'/'1' string, 4 m cells of ploughed field
mercenaries.VegTried    = {}                            -- ["tx_ty"] = true once a load was attempted
mercenaries.VegTileSize = 128
mercenaries.VegRule     = true      -- merc_camp_vegrule 0/1: the whole thing, on or off
mercenaries.VegTrunkClear = 0.5     -- ground kept clear around a trunk, beyond its radius
mercenaries.VegBoxClear   = 0.15    -- and around a bush's box
mercenaries.VegKindName = { "tree", "bush", "stump", "fallen trunk", "rock", "undergrowth" }

local function vLog(s) System.LogAlways("[CampVeg] " .. tostring(s)) end

-- The tile holding world (x, y), loaded on first use. nil where nothing was baked (off the
-- map, or a level without a bake).
function mercenaries:VegTile(tx, ty)
    local key = tx .. "_" .. ty
    local t = self.VegTiles[key]
    if t then return t end
    if self.VegTried[key] then return nil end
    self.VegTried[key] = true
    pcall(function() Script.LoadScript("Scripts/mods/mercveg/t_" .. key .. ".lua") end)
    t = self.VegTiles[key]
    if t then
        vLog(string.format("tile %s: %d plants", key, #t))
    end
    return t
end

-- Is (x, y) on a ploughed field? From the tile's 4 m bitmap of soil-layer cells. A yard or
-- a cart track reads the same, so this is a preference, never a veto.
function mercenaries:VegFieldAt(x, y)
    if not self.VegRule then return false end
    local s = self.VegTileSize
    local tx, ty = math.floor(x / s), math.floor(y / s)
    self:VegTile(tx, ty)
    local bits = self.VegField[tx .. "_" .. ty]
    if not bits then return false end
    local i = math.floor((x - tx * s) / 4)
    local j = math.floor((y - ty * s) / 4)
    local b = string.byte(bits, i * 32 + j + 1)
    return b == 49   -- '1'
end

-- Squared distance from (x, y) to an entry's box (0 inside it).
local function boxDist2(e, x, y)
    local cx = x < e[4] and e[4] or (x > e[6] and e[6] or x)
    local cy = y < e[5] and e[5] or (y > e[7] and e[7] or y)
    local dx, dy = x - cx, y - cy
    return dx * dx + dy * dy
end

-- Every baked entry whose box comes within `r` of (x, y). Cheap enough to call per prop; the
-- map sampler calls it once for the whole camp and tests its cells against the result.
function mercenaries:VegNear(x, y, r)
    local out = {}
    if not self.VegRule then return out end
    local s = self.VegTileSize
    local r2 = r * r
    for tx = math.floor((x - r) / s), math.floor((x + r) / s) do
        for ty = math.floor((y - r) / s), math.floor((y + r) / s) do
            local t = self:VegTile(tx, ty)
            if t then
                for i = 1, #t do
                    local e = t[i]
                    if boxDist2(e, x, y) <= r2 then out[#out + 1] = e end
                end
            end
        end
    end
    return out
end

-- The hard part of an entry: a circle for a tree (its trunk), a box for the rest.
-- Returns cx, cy, radius for a circle, or nil and the box grown by the clearance.
local function hardShape(self, e)
    if e[1] == 1 then
        return e[2], e[3], (e[9] or 0.3) + (self.VegTrunkClear or 0.5)
    end
    local c = self.VegBoxClear or 0.15
    return nil, nil, nil, e[4] - c, e[5] - c, e[6] + c, e[7] + c
end

-- Does the hard part of `e` cover the point (x, y)?
function mercenaries:VegEntryCovers(e, x, y)
    local cx, cy, r, x0, y0, x1, y1 = hardShape(self, e)
    if cx then
        local dx, dy = x - cx, y - cy
        return dx * dx + dy * dy <= r * r
    end
    return x >= x0 and x <= x1 and y >= y0 and y <= y1
end

-- Separating-axis test between an oriented box (centre, yaw, half extents: forward carries
-- the depth, right the width - the convention every footprint in the camp uses) and an
-- axis-aligned one.
local function obbHitsAabb(px, py, ang, hw, hh, x0, y0, x1, y1)
    local fx, fy = math.cos(ang), math.sin(ang)
    local rx, ry = -fy, fx
    local bx, by = (x0 + x1) / 2, (y0 + y1) / 2
    local bw, bh = (x1 - x0) / 2, (y1 - y0) / 2
    local dx, dy = bx - px, by - py
    local axes = { { 1, 0 }, { 0, 1 }, { rx, ry }, { fx, fy } }
    for _, u in ipairs(axes) do
        local ux, uy = u[1], u[2]
        local ra = math.abs((rx * ux + ry * uy) * hw) + math.abs((fx * ux + fy * uy) * hh)
        local rb = math.abs(ux * bw) + math.abs(uy * bh)
        if math.abs(dx * ux + dy * uy) > ra + rb then return false end
    end
    return true
end

-- ...and between that oriented box and a circle: the nearest point of the box to the centre.
local function obbHitsCircle(px, py, ang, hw, hh, cx, cy, r)
    local fx, fy = math.cos(ang), math.sin(ang)
    local rx, ry = -fy, fx
    local dx, dy = cx - px, cy - py
    local lr = dx * rx + dy * ry      -- along right (width)
    local lf = dx * fx + dy * fy      -- along forward (depth)
    if lr > hw then lr = hw elseif lr < -hw then lr = -hw end
    if lf > hh then lf = hh elseif lf < -hh then lf = -hh end
    local nx = px + rx * lr + fx * lf
    local ny = py + ry * lr + fy * lf
    local ex, ey = cx - nx, cy - ny
    return ex * ex + ey * ey <= r * r
end

-- The first baked plant standing in a footprint, or nil. `half` is { w, h } as CampPropFootHalf
-- returns it; `near` may be a list from VegNear already in hand.
function mercenaries:VegFootprintHit(pos, angle, half, near)
    if not (self.VegRule and pos and half) then return nil end
    local reach = math.sqrt(half.w * half.w + half.h * half.h) + 1.0
    near = near or self:VegNear(pos.x, pos.y, reach)
    for i = 1, #near do
        local e = near[i]
        local cx, cy, r, x0, y0, x1, y1 = hardShape(self, e)
        local hit
        if cx then
            hit = obbHitsCircle(pos.x, pos.y, angle or 0, half.w, half.h, cx, cy, r)
        else
            hit = obbHitsAabb(pos.x, pos.y, angle or 0, half.w, half.h, x0, y0, x1, y1)
        end
        if hit then return e end
    end
    return nil
end

-- A round version for the callers that think in radii: anything within `radius` of (x, y)?
function mercenaries:VegSpotBlocked(x, y, radius)
    if not self.VegRule then return nil end
    local near = self:VegNear(x, y, (radius or 1.0) + 1.0)
    for i = 1, #near do
        local e = near[i]
        local cx, cy, r, x0, y0, x1, y1 = hardShape(self, e)
        if cx then
            local dx, dy = x - cx, y - cy
            local rr = r + (radius or 0)
            if dx * dx + dy * dy <= rr * rr then return e end
        else
            local qx = x < x0 and x0 or (x > x1 and x1 or x)
            local qy = y < y0 and y0 or (y > y1 and y1 or y)
            local dx, dy = x - qx, y - qy
            if dx * dx + dy * dy <= (radius or 0) * (radius or 0) then return e end
        end
    end
    return nil
end

function mercenaries:VegDescribe(e)
    if not e then return "nothing" end
    return string.format("%s at (%.1f, %.1f), %.1f x %.1f m, %.1f m tall",
        self.VegKindName[e[1]] or "plant", e[2], e[3], e[6] - e[4], e[7] - e[5], e[8] or 0)
end

-- Mark the cells of a sampled camp map that a plant stands on. Called by CampBuildMap right
-- after the sampler; the classifier then treats a marked cell as unbuildable, so every tile,
-- tent and prop that consults the map routes round the vegetation without knowing it exists.
function mercenaries:VegMarkMap(hm)
    if not (self.VegRule and hm and hm.z) then return 0 end
    local r, sp, o = hm.r, hm.spacing, hm.origin
    local reach = r * sp * 1.4143 + 2.0
    local near = self:VegNear(o.x, o.y, reach)
    hm.veg = {}
    if #near == 0 then return 0 end
    local n = 0
    for i = 0, 2 * r do
        hm.veg[i] = {}
        local wx = o.x + (i - r) * sp
        for j = 0, 2 * r do
            local wy = o.y + (j - r) * sp
            for k = 1, #near do
                if self:VegEntryCovers(near[k], wx, wy) then
                    hm.veg[i][j] = near[k][1]
                    n = n + 1
                    break
                end
            end
        end
    end
    vLog(string.format("map: %d plants within %.0f m, %d cells under them", #near, reach, n))
    return n
end

-- ---------------------------------------------------------------- commands

-- What the bake knows about the ground round the player. The check for the bake itself:
-- stand next to a bush, run it, and the bush should be in the list.
function mercenaries:VegReport(line)
    local a = self.CmdArgs and self:CmdArgs(line) or {}
    local radius = tonumber(a[1]) or 8.0
    local p = player and player:GetWorldPos()
    if not p then vLog("no player"); return end
    local near = self:VegNear(p.x, p.y, radius)
    vLog(string.format("===== (%.1f, %.1f) within %.1f m: %d plant(s) =====", p.x, p.y, radius, #near))
    table.sort(near, function(u, v) return boxDist2(u, p.x, p.y) < boxDist2(v, p.x, p.y) end)
    for i = 1, math.min(#near, 40) do
        local e = near[i]
        vLog(string.format("  %5.1f m  %s%s", math.sqrt(boxDist2(e, p.x, p.y)), self:VegDescribe(e),
            e[1] == 1 and string.format(" trunk r=%.2f", e[9] or 0) or ""))
    end
    local blocked = self:VegSpotBlocked(p.x, p.y, 0.5)
    vLog("standing in: " .. self:VegDescribe(blocked))
end

mercenaries:DevCommand("merc_camp_veg", "mercenaries:VegReport(%line)",
    "List the baked vegetation around the player: merc_camp_veg [radius]")
mercenaries:DevCommand("merc_camp_vegrule", "mercenaries:VegRuleSet(%line)",
    "Turn the vegetation bake on (1) or off (0) for camp placement")

function mercenaries:VegRuleSet(line)
    local a = self.CmdArgs and self:CmdArgs(line) or {}
    if a[1] ~= nil then self.VegRule = (tostring(a[1]) ~= "0") end
    vLog("vegetation rule " .. (self.VegRule and "on" or "OFF"))
end
