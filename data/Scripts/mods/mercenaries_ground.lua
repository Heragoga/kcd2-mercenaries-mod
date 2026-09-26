-- What the mod is allowed to call "the ground".
--
-- Every placement in the mod - camp props, stations, patrol waypoints, a teleported
-- straggler - ends in a downward raycast, and the answer was always the FIRST surface the
-- ray met. On open terrain that surface IS the ground. Over a house it is the roof, on a log
-- it is the log, over our own tents it is the tent, and the prop or the man is put on top of
-- whatever happened to be in the way.
--
-- THE TEST IS WHAT THE SURFACE IS MADE OF, NOT HOW HIGH IT IS.
--
-- Two earlier versions of this module passed everything, and a third tried to fix it with a
-- height threshold. Height cannot work: a straw mat is two centimetres thick, a cloth or a
-- sack less, and any threshold low enough to catch them throws out every path and kerb in
-- the game. There is no height that separates "a thing lying on the ground" from "the
-- ground".
--
-- What separates them is the material, and the engine reports it. A ray restricted to
-- ent_terrain hits the heightmap by construction, so it says both how high the ground is at
-- this exact column AND what the ground is made of. Anything lying on top of it is made of
-- something else. From the probe that settled this, standing on a woodpile:
--
--   terrain ray      z = 56.26   surface = 1
--   the pile on top  z = 57.86   surface = 138
--
-- A straw mat would read as straw at two centimetres just as loudly as the pile reads at
-- 1.60m, so the rule carries no height term at all. Height survives only as a backstop for
-- the one case material cannot see: something made of what the ground is made of, standing
-- proud of it - a stone block on stony ground.
--
-- The edge test (ring a point, see whether every side drops away) is kept for the case the
-- terrain ray cannot answer: a column with no heightmap under it at all, a bridge deck or an
-- interior with the terrain cut away.
--
-- WHAT DOES NOT WORK, all of it measured rather than assumed:
--   * System.GetTerrainElevation returns NIL in this build, on every call. That was the
--     original bug - the comparison had nothing to compare against and defaulted to "fine".
--   * The hit's `renderNode` is set on the TERRAIN hit too, so entity/renderNode separates
--     nothing here whatever the bind's code suggests.
--   * RayWorldIntersection returns ONE hit however many are asked for. It does not pierce,
--     so a column cannot be walked down; the terrain ray is what supplies the height
--     underneath an obstruction.
--
-- `merc_groundprobe` prints all of it, surface NAMES included, so the next surprise is one
-- command away rather than three rewrites away.
--
-- See docs/ground-guard.md.

mercenaries.GroundGuard = true        -- master switch, merc_groundguard

mercenaries.GroundProbeStart  = 50.0  -- rays start this far above the asked-for z...
mercenaries.GroundProbeDepth  = 60.0  -- ...and reach this far below it
mercenaries.GroundProbeHits   = 1     -- the engine returns one hit however many are asked for

-- WHICH THINGS A PROBE CAN SEE AT ALL. Not the cause of the "everything is firm ground"
-- reports - the log pile came back as a hit either way, because it is static geometry - but
-- wrong all the same, and it is what made carts and barrels invisible.
--
-- Every probe in the mod asked for `ent_terrain + ent_static`. From the live Lua state dump
-- (references/kcd2-mod-docs-main/lua_dump_state) those are 256 and 1, so the mask was 257 -
-- the heightmap and static geometry, and NOTHING ELSE. A log, a barrel, a crate, a cart, a
-- corpse are rigid bodies (ent_rigid 4, ent_sleeping_rigid 2) and the ray went straight
-- through them - so a probe over a cart answered about the terrain underneath it.
--
-- ent_living (8) is deliberately left out: a passing merc is not an obstruction to place
-- around, and a ray that hits one would condemn whatever ground he happens to be on.
-- ent_independent (16) is ropes and the like.
mercenaries.GroundObjectMask = nil    -- built below, once the ent_* globals are readable

-- Everything EXCEPT the terrain, for rays cast sideways. A horizontal ray that can see the
-- heightmap hits the hillside a few metres on and reports an obstruction that is just the
-- ground rising; what such a ray is asking about is things standing ON it.
function mercenaries:GroundObstacleMask()
    return ent_static + ent_sleeping_rigid + ent_rigid
end

-- With the guard off, probes see what they always saw, so nothing moves.
function mercenaries:GroundMask()
    if not self.GroundGuard then return ent_terrain + ent_static end
    if not self.GroundObjectMask then
        self.GroundObjectMask = ent_terrain + ent_static + ent_sleeping_rigid + ent_rigid
    end
    return self.GroundObjectMask
end

-- The edge test. A log is about 0.35m across and 0.3m tall, a crate 0.5m, a cart bed 0.9m,
-- so the ring has to reach past the widest thing we mean to catch and the drop has to be
-- smaller than the shortest thing we mean to catch is tall. A HILLSIDE drops on at most half
-- the ring - one side is uphill - which is what keeps slopes, where camping is fine, out of
-- this. That is also why the validator's cheap 4-probe version demands all four: on any
-- slope at least one of them is above you.
mercenaries.GroundEdgeRadius = 1.25
mercenaries.GroundEdgeRays   = 8      -- full ring, for the probe and for verified snaps
mercenaries.GroundEdgeMin    = 6      -- ...of which this many must drop
mercenaries.GroundEdgeDrop   = 0.25
mercenaries.GroundEdgeFast   = 4      -- the validator's ring: 4 probes, all of which must drop

-- WHAT the surface is, not how high it is.
--
-- Height was tried as the test and is wrong: a straw mat is two centimetres thick, a cloth,
-- a plank, a sack lower still, and the threshold that would catch them would throw out every
-- path and kerb in the game. There is no height that separates "an object lying on the
-- ground" from "the ground".
--
-- The material does. The terrain ray reports what the ground at this exact column is made of;
-- anything lying on it is made of something else. In the probe that settled this the ground
-- read surface 1 and the woodpile on it read 138 - and a straw mat would read as straw at two
-- centimetres just as loudly as the pile does at 1.60m. So the rule carries NO height term:
-- a different surface type is an object, however thin.
--
-- Height is kept only as a backstop for the case material cannot see: something made of what
-- the ground is made of, standing on it. A stone block on stony ground, a dirt ramp.
mercenaries.GroundSameRise    = 0.80  -- same surface type as the ground, but perched this high
mercenaries.GroundBelowDrop   = 2.0   -- under the terrain by this much is a pit or a cellar
mercenaries.GroundFallbackRise = 5.0  -- with nothing to go on, the old +5m snap's answer

-- Learned at runtime. The terrain ray sets this true the first time it hits anything.
mercenaries.GroundTerrainLive = nil

mercenaries.GroundRejects   = 0       -- lifetime count, for merc_groundprobe
mercenaries.GroundLastLogAt = nil
mercenaries.GroundLogEvery  = 5.0     -- seconds between rejection log lines

-- Rejections are worth seeing in kcd.log but a camp pitch asks thousands of times.
function mercenaries:GroundNote(msg)
    self.GroundRejects = (self.GroundRejects or 0) + 1
    -- Wall clock, not the engine's: engine time runs ~29x fast through a wait/sleep and the
    -- throttle would stop throttling exactly when a rebuild floods it. See docs/performance.md.
    local now = (os and os.clock) and os.clock() or nil
    if now and self.GroundLastLogAt and (now - self.GroundLastLogAt) < self.GroundLogEvery then return end
    self.GroundLastLogAt = now
    System.LogAlways('[Mercenaries] ground guard: ' .. tostring(msg))
end

-- ==== the raw probe ====

-- Every surface under (x, y), topmost-first, as the raw hit tables the engine filled. One
-- ray. The engine returns ONE hit however many are asked for - it does not pierce - so
-- this is a list of one in practice, and walking down a column is not on offer.
function mercenaries:GroundRawHits(x, y, fromZ, depth, maxHits, mask)
    local up   = self.GroundProbeStart
    local down = depth or self.GroundProbeDepth
    local out  = {}
    pcall(function()
        -- A FRESH table every time. `entity` and `renderNode` are optional keys, so a reused
        -- hit table would keep the previous hit's and every surface would read as an object.
        local hitTable = {}
        local hits = Physics.RayWorldIntersection(
            { x = x, y = y, z = fromZ + up }, { x = 0, y = 0, z = -(up + down) },
            maxHits or self.GroundProbeHits, mask or self:GroundMask(), nil, nil, hitTable)
        for i = 1, (tonumber(hits) or 0) do
            if hitTable[i] and hitTable[i].pos then table.insert(out, hitTable[i]) end
        end
    end)
    return out
end

-- A label for the probe's dump, and nothing more. This looks like it ought to separate an
-- entity, a brush and the terrain, and in the bind it does - but in this build `renderNode`
-- is set on the TERRAIN hit as well, so as a discriminator it is worthless. Recorded here so
-- the next reader does not rediscover it the expensive way; the terrain ray is the test.
function mercenaries:GroundHitKind(hit)
    if not hit then return nil end
    if hit.entity ~= nil then return "entity" end
    if hit.renderNode ~= nil then return "brush" end
    return "terrain"
end

-- The name behind a surface-type index, for the log. System.GetSurfaceTypeNameById is in the
-- live Lua state dump; pcall'd because nothing in the mod had called it before.
function mercenaries:GroundSurfaceName(id)
    if id == nil then return 'nil' end
    local n
    pcall(function() n = System.GetSurfaceTypeNameById(id) end)
    if type(n) == 'string' and n ~= '' then return string.format('%s (%s)', tostring(id), n) end
    return tostring(id)
end

-- THE TERRAIN UNDER A COLUMN: height, and the surface type standing there.
--
-- `System.GetTerrainElevation` returns nil in this build - every call, everywhere. That is
-- not a quirk to work around, it is the whole reason the first two versions of this module
-- passed everything: with no terrain height there was nothing to compare a surface against,
-- and the comparison defaulted to "fine". A ray restricted to ent_terrain does the same job
-- and works: whatever it hits is the heightmap by construction. It costs one ray, and it is
-- worth it - it is the only signal here that has been watched working.
--
-- The hit's `surface` (a surface-type index) comes back with it, which is the second half:
-- in the log that settled this, the terrain read surface 1 and the woodpile on top of it
-- read 138. A surface that is BOTH proud of the terrain AND made of something else is not
-- the ground, however little it is standing proud by.
--
-- Returns z, surfaceId - or nil when the column has no terrain at all (a bridge over water,
-- an interior with the heightmap cut away), in which case there is nothing to compare with
-- and the caller must fall back on the edge test.
function mercenaries:GroundTerrainAt(x, y, fromZ)
    local hits = self:GroundRawHits(x, y, fromZ, nil, 1, ent_terrain)
    local h = hits[1]
    if not (h and h.pos) then return nil, nil end
    self.GroundTerrainLive = true
    return h.pos.z, h.surface
end

-- ==== the edge test ====

-- Is the surface at (x, y, z) the top of something? Rings the point with GroundEdgeRays
-- probes and counts how many sit clearly below it. Returns isTop, drops, samples.
-- Costs GroundEdgeRays rays, so it belongs in a validator, not in a snap.
function mercenaries:GroundEdgeCheck(x, y, z, rays, need)
    local drops, samples = 0, 0
    local n = rays or self.GroundEdgeRays
    need = need or self.GroundEdgeMin
    for k = 0, n - 1 do
        local a  = (k / n) * 2 * math.pi
        local px = x + math.cos(a) * self.GroundEdgeRadius
        local py = y + math.sin(a) * self.GroundEdgeRadius
        -- Probe from just above the surface we are testing, so a neighbouring wall or tree
        -- registers as "not below" rather than being missed above the ray start.
        local col = self:GroundRawHits(px, py, z, nil, 1)
        if col[1] then
            samples = samples + 1
            if (z - col[1].pos.z) >= self.GroundEdgeDrop then drops = drops + 1 end
        end
    end
    return (samples > 0 and drops >= math.min(need, samples)), drops, samples
end

-- ==== the verdict ====

-- Is a surface standing on the ground rather than being it? `terrainZ` / `terrainSurface`
-- come from the terrain ray; nil means the column has no terrain to compare against and only
-- the edge test can answer. Returns isObject, why.
function mercenaries:GroundSurfaceLooksLikeObject(z, surfaceId, terrainZ, terrainSurface)
    if not terrainZ then return false, nil end

    -- Material, with no height term at all. See the note by GroundSameRise: this is the half
    -- that catches a straw mat, and the reason the test is not a height comparison.
    if surfaceId ~= nil and terrainSurface ~= nil and surfaceId ~= terrainSurface then
        return true, string.format('surface %s lying on ground made of %s, %.2fm up',
            tostring(surfaceId), tostring(terrainSurface), z - terrainZ)
    end

    local rise = z - terrainZ
    if rise < -self.GroundBelowDrop then
        return true, string.format('%.2fm below the terrain', -rise)
    end
    -- Backstop: made of what the ground is made of, but standing well proud of it.
    if rise > self.GroundSameRise then
        return true, string.format('%.2fm above the terrain', rise)
    end
    return false, nil
end

-- The ground under (x, y).
--   returns z, info, clear
--     z      the height to place on, or nil when the column is empty
--     info   { surface=, terrainZ=, terrainSurface=, rise= } - what the verdict was made on
--     clear  true when the top surface IS the ground. False means something is standing here,
--            and then `z` is the terrain height underneath it rather than the top of it.
-- `fromZ` only aims the ray. It is never treated as a floor, so a man already stranded on a
-- roof cannot make the roof read as ground by asking from up there.
--
-- Two rays: one for the topmost surface, one restricted to the terrain. The engine returns a
-- single hit however many are asked for - it does not pierce - so walking down a column is
-- not available, and the terrain ray is what supplies the height underneath an obstruction.
function mercenaries:GroundUnder(x, y, fromZ, depth)
    local col = self:GroundRawHits(x, y, fromZ, depth, 1)
    local top = col[1]
    if not (top and top.pos) then return nil, nil, false end
    local info = { surface = top.surface }

    if not self.GroundGuard then return top.pos.z, info, true end

    local tz, tSurf = self:GroundTerrainAt(x, y, fromZ)
    info.terrainZ, info.terrainSurface = tz, tSurf
    if tz then info.rise = top.pos.z - tz end

    local isObj = self:GroundSurfaceLooksLikeObject(top.pos.z, top.surface, tz, tSurf)
    if not isObj then return top.pos.z, info, true end

    -- Something is standing here. The terrain under it is where anything we put down belongs;
    -- the caller decides whether to use the spot at all.
    return (tz or top.pos.z), info, false
end

-- Snap a position onto the ground. `verify` pays GroundEdgeFast extra rays to also run the
-- edge test, which covers the one case the terrain ray cannot: a column with no terrain in
-- it. For callers that put something solid down, not for the thousands of snaps a camp pitch
-- does while working out its layout.
-- Returns pos, clear, info.
function mercenaries:GroundSnap(pos, verify, depth)
    if not pos then return pos, false, nil end
    local z, info, clear = self:GroundUnder(pos.x, pos.y, pos.z, depth)
    if not z then return { x = pos.x, y = pos.y, z = pos.z }, false, nil end
    if clear and verify and self.GroundGuard and not (info and info.terrainZ) then
        -- Only worth paying for where the terrain ray had nothing to say.
        if self:GroundEdgeCheck(pos.x, pos.y, z, self.GroundEdgeFast, self.GroundEdgeFast) then
            clear = false
        end
    end
    return { x = pos.x, y = pos.y, z = z }, clear and true or false, info
end

-- ==== is the guard right about this world? ====
--
-- The rule is that a surface standing proud of the terrain is not the ground. That holds
-- wherever people walk on the heightmap. If some region were built on static meshes standing
-- clear of it, the guard would rule out ground that is perfectly good.
--
-- The player settles it: he is standing on real ground by definition, so the guard's verdict
-- on his own column has a right answer already. Once a second from the monitor loop, two
-- rays, skipped while mounted or under a roof - and skipped on a stationary player, because
-- a man who parks himself on a woodpile for two minutes would otherwise disarm the guard.
mercenaries.GroundSelfChecks = 0
mercenaries.GroundSelfFails  = 0
-- Set high on purpose. This is meant to catch a REGION where the rule does not hold, not a
-- stroll past some crates, so it takes about 200m of walking with four fifths of it reading
-- "on an object" - and it disables the guard until merc_groundguard 1, which is not something
-- to trip lightly.
mercenaries.GroundSelfMin    = 200    -- samples before a verdict
mercenaries.GroundSelfMaxBad = 0.8    -- ...and the share of them that has to be wrong
mercenaries.GroundSelfMinMove = 1.0   -- metres he must have moved since the last sample
mercenaries._groundSelfLast  = nil

function mercenaries:GroundSelfCheck()
    if not (self.GroundGuard and player) then return end
    local ok = pcall(function()
        local p = player:GetWorldPos()
        if not p then return end
        -- Mounted, in a cart, on a ladder, indoors: all legitimately "on an object", and
        -- none of them says anything about the terrain.
        if _G.PlayerMounted then return end
        if self.CampDetectRoof and self:CampDetectRoof(p) then return end

        local last = self._groundSelfLast
        if last then
            local dx, dy = p.x - last.x, p.y - last.y
            if (dx * dx + dy * dy) < (self.GroundSelfMinMove * self.GroundSelfMinMove) then return end
        end
        self._groundSelfLast = { x = p.x, y = p.y }

        local _, _, clear = self:GroundUnder(p.x, p.y, p.z)
        self.GroundSelfChecks = self.GroundSelfChecks + 1
        if not clear then self.GroundSelfFails = self.GroundSelfFails + 1 end

        if self.GroundSelfChecks >= self.GroundSelfMin then
            if (self.GroundSelfFails / self.GroundSelfChecks) > self.GroundSelfMaxBad then
                self.GroundGuard = false
                System.LogAlways(string.format(
                    '[Mercenaries] ground guard DISABLED: it called the ground the player was ' ..
                    'walking on an object on %d of %d samples, so its idea of the ground does ' ..
                    'not match this region. Stand somewhere ordinary, run merc_groundprobe, and ' ..
                    'merc_groundguard 1 to put it back.',
                    self.GroundSelfFails, self.GroundSelfChecks))
            end
            self.GroundSelfChecks, self.GroundSelfFails = 0, 0
        end
    end)
    if not ok then self.GroundSelfChecks, self.GroundSelfFails = 0, 0 end
end

-- ==== diagnostics ====

-- Everything the module can see about a column, raw. This is the instrument: when a
-- placement lands somewhere silly, or when the guard waves through something it should not,
-- this says which of the three signals is answering and what it is answering.
function mercenaries:GroundProbeHere()
    if not player then return end
    local ok, err = pcall(function()
        local function dump(label, p)
            if not p then return end
            System.LogAlways(string.format(
                '[Mercenaries] --- ground %s: (%.2f, %.2f) asked at z=%.2f',
                label, p.x, p.y, p.z))

            local raw = self:GroundRawHits(p.x, p.y, p.z)
            local tz, tSurf = self:GroundTerrainAt(p.x, p.y, p.z)
            System.LogAlways(string.format(
                '[Mercenaries]   terrain ray: %s (surface %s)   |   GetTerrainElevation: %s',
                tz and string.format('z=%.2f', tz) or 'NO TERRAIN IN THIS COLUMN',
                self:GroundSurfaceName(tSurf),
                (function() local v; pcall(function() v = System.GetTerrainElevation(p.x, p.y) end)
                    return v and string.format('%.2f', v) or 'nil (unusable in this build)' end)()))
            System.LogAlways(string.format(
                '[Mercenaries]   %d surface(s) returned, probe mask %d',
                #raw, self:GroundMask()))

            for i, h in ipairs(raw) do
                -- Every key the engine actually put in the hit. This is the only way to find
                -- out what a build reports, and it is what finally settled this one.
                local keys = {}
                for k, v in pairs(h) do
                    if k ~= 'pos' and k ~= 'normal' then
                        table.insert(keys, tostring(k) .. '=' .. tostring(v))
                    end
                end
                table.sort(keys)
                System.LogAlways(string.format(
                    '[Mercenaries]   %d. z=%8.2f  %s above terrain  surface %s  [%s]',
                    i, h.pos.z,
                    tz and string.format('%+6.2f', h.pos.z - tz) or '  n/a ',
                    self:GroundSurfaceName(h.surface),
                    table.concat(keys, ' ')))
            end

            if raw[1] then
                local isObj, why = self:GroundSurfaceLooksLikeObject(raw[1].pos.z, raw[1].surface, tz, tSurf)
                System.LogAlways(string.format('[Mercenaries]   terrain test: %s',
                    tz and (isObj and ('OBJECT - ' .. tostring(why)) or 'this IS the ground')
                       or 'no terrain here - falling back on the edge test'))
                local isTop, drops, samples = self:GroundEdgeCheck(p.x, p.y, raw[1].pos.z)
                System.LogAlways(string.format(
                    '[Mercenaries]   edge test: %d of %d probes at %.2fm drop %.2fm+ -> %s',
                    drops, samples, self.GroundEdgeRadius, self.GroundEdgeDrop,
                    isTop and 'ON TOP OF SOMETHING' or 'not a plateau'))
                local gz, _, clear = self:GroundUnder(p.x, p.y, p.z)
                System.LogAlways(string.format('[Mercenaries]   VERDICT: %s; ground is z=%.2f',
                    clear and 'open ground' or 'NOT open ground', gz or 0))
            end
        end

        dump('under the player', player:GetWorldPos())
        if self.TowerLookedAtPos then
            local lp
            pcall(function() lp = self:TowerLookedAtPos() end)
            dump('at the look-at point', lp)
        end

        System.LogAlways(string.format(
            '[Mercenaries] guard %s | terrain ray %s | rule: a different surface type is an ' ..
            'object at any height, same type only past %.2fm | %d rejection(s) this session',
            self.GroundGuard and 'ON' or 'OFF',
            self.GroundTerrainLive and 'has hit terrain' or 'has never hit terrain',
            self.GroundSameRise, self.GroundRejects or 0))
        Game.SendInfoText('@merc_logi_msg Ground probe written to the log', false, 0, 4)
    end)
    if not ok then System.LogAlways('[Mercenaries] GroundProbeHere error: ' .. tostring(err)) end
end

-- Grid sweep: how many columns around the player the guard calls open ground. The edge test
-- is included, so this is what the validators would actually accept.
function mercenaries:GroundScan(line)
    if not player then return end
    local radius = tonumber(line) or 6
    radius = math.max(1, math.min(radius, 12))
    local ok, err = pcall(function()
        local o = player:GetWorldPos()
        local clear, onObject, empty = 0, 0, 0
        for i = -radius, radius do
            for j = -radius, radius do
                -- kind is nil only when the column had no surface at all.
                local _, isClear, kind = self:GroundSnap({ x = o.x + i, y = o.y + j, z = o.z }, true)
                if not kind then empty = empty + 1
                elseif isClear then clear = clear + 1
                else onObject = onObject + 1 end
            end
        end
        System.LogAlways(string.format(
            '[Mercenaries] ground scan %dm: %d open ground, %d blocked by an object, %d empty',
            radius, clear, onObject, empty))
        Game.SendInfoText(string.format('@merc_logi_msg Ground: %d open / %d blocked', clear, onObject),
            false, 0, 5)
    end)
    if not ok then System.LogAlways('[Mercenaries] GroundScan error: ' .. tostring(err)) end
end

function mercenaries:GroundGuardSet(line)
    local v = tostring(line or ''):match('%S+')
    if v == '0' or v == 'off' or v == 'false' then
        self.GroundGuard = false
    elseif v == '1' or v == 'on' or v == 'true' then
        self.GroundGuard = true
    end
    System.LogAlways('[Mercenaries] ground guard ' .. (self.GroundGuard and 'ON' or 'OFF'))
    Game.SendInfoText('@merc_logi_msg Ground guard ' .. (self.GroundGuard and 'on' or 'off'), false, 0, 4)
end

mercenaries:DevCommand("merc_groundprobe", "mercenaries:GroundProbeHere()",
    "Dump everything the mod can see under you and under the spot you are looking at: every surface, every key the engine put in the hit, the heightmap reading, the edge test, and which of the three signals are alive")
mercenaries:DevCommand("merc_groundscan", "mercenaries:GroundScan('%line')",
    "Count open-ground vs blocked columns around you, edge test included. Usage: merc_groundscan [radius]")
mercenaries:DevCommand("merc_groundguard", "mercenaries:GroundGuardSet('%line')",
    "Turn the 'never place on top of an object' guard on or off. Usage: merc_groundguard 0|1")
