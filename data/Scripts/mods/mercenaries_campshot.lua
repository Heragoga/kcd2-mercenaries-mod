-- Looking at what the camp placement actually did, without a human at the keyboard.
--
-- The complaint this exists for is visual and per-prop: on hilly ground a smithy or a
-- tavern can end up part-buried, and tables, benches and racks stand bolt upright on a
-- slope instead of lying on it. Neither is visible in a log line, and neither is
-- reproducible by describing it - somebody has to look at the thing, from a few sides,
-- close to the ground.
--
-- Two ways of looking, and they answer different halves of the question:
--
--   merc_camp_geo    the NUMBERS. Every prop the camp put down, its measured footprint
--                    rotated into the world, and the terrain height at nine points under
--                    that footprint. That yields, per prop: how deep the ground stands
--                    over its base (buried), how far its base floats over the lowest
--                    ground (gap), and the tilt the ground has that the prop does not.
--                    This is the diagnosis - it covers all ~250 props at once and it is
--                    what a fix gets measured against.
--
--   merc_shot_orbit  the PICTURE. Puts the view camera on a circle around one prop and
--                    fires a screenshot at each step. This is the confirmation, and the
--                    thing to look at when the numbers say a prop is fine and it still
--                    looks wrong.
--
-- The camera is CryAction.SetViewCamera(pos, dir) - the same bind the game's own capture
-- scripts use (references/Scripts/CommandExecutor/cube.xml, sample_terrain.xml), confirmed
-- live in this build's Lua state dump. It is re-applied every tick while a run is going:
-- the player's view system owns the camera normally and takes it back the moment nothing
-- is fighting for it. CryAction.ResetToNormalCamera() hands it back.
--
-- NO KEYBOARD, NO FOREGROUND. Every command here is meant to arrive through the control
-- file poll (merc_dev, then merc_cmd_remote - see mercenaries_cmdui.lua and docs/ui.md),
-- so a host script drives a game it never has to focus or click. That poll re-executes the
-- file once a second, so EVERY COMMAND BELOW IS IDEMPOTENT: a run already in progress
-- ignores a second request to start it.
--
-- See docs/camp-inspection.md.

mercenaries.ShotRun        = nil     -- the live orbit, nil when idle
mercenaries.ShotTickMs     = 60      -- camera re-apply rate
mercenaries.ShotSettleMs   = 700     -- after a move, before the shutter
mercenaries.ShotWriteMs    = 1600    -- after the shutter, before moving again
mercenaries.ShotHudWasOn   = true
mercenaries.ShotGeo        = nil     -- the live geometry walk, nil when idle
mercenaries.ShotGeoRows    = {}      -- last completed geometry pass, worst-first
mercenaries.ShotDrawLines  = true    -- cleared if PersistantLine turns out not to take

-- A vector the engine's GetVec3 will accept whichever form it asks for. The capture
-- scripts pass positional triples ({256.0,256.0,500}), the game's own Lua passes entity
-- positions (named x/y/z). Carrying both costs nothing and removes the question.
local function V(x, y, z)
    return { x = x, y = y, z = z, [1] = x, [2] = y, [3] = z }
end

local function norm(x, y, z)
    local d = math.sqrt(x * x + y * y + z * z)
    if d < 1e-6 then return V(1, 0, 0) end
    return V(x / d, y / d, z / d)
end

local function log(fmt, ...)
    if select('#', ...) > 0 then fmt = string.format(fmt, ...) end
    System.LogAlways('[CampShot] ' .. fmt)
end

local function cvar(cmd)
    pcall(function() System.ExecuteCommand(cmd) end)
end

local function shortModel(model)
    return string.match(tostring(model or "?"), "([^/]+)%.cgf$") or tostring(model or "?")
end

-- ===================================================================== targets

-- Every prop the camp has put down, in layout order, as the placement recorded it.
-- CampPropLog is written by SpawnCampPropModel and carries the two things an entity
-- cannot be asked for afterwards: the model it was given, and the position the layout
-- wanted before the ground snap moved it.
function mercenaries:ShotProps()
    local out = {}
    for _, r in ipairs(self.CampPropLog or {}) do
        local p, up
        pcall(function()
            local e = System.GetEntity(r.id)
            -- COPIED, not kept. Several CryEngine Lua binds hand back a shared temporary
            -- vector that the next call overwrites, and this list is built across a couple
            -- of hundred entities before any of it is read - holding the reference would
            -- quietly give every prop the last one's position.
            if e and e.GetWorldPos then
                local w = e:GetWorldPos()
                if w then p = { x = w.x, y = w.y, z = w.z } end
            end
            -- The prop's own up axis, straight from the entity. Asking the engine what the
            -- prop's orientation ACTUALLY is - rather than re-deriving it from the angles we
            -- think we set - is what keeps the score below honest about a fix.
            if e and e.GetDirectionVector then
                local uv = e:GetDirectionVector(2)
                if uv and uv.z then up = { x = uv.x, y = uv.y, z = uv.z } end
            end
        end)
        -- An entity that has gone (torn down, never spawned) is skipped rather than
        -- reported at its intended position - a ghost row reads as a real placement.
        if p then
            out[#out + 1] = {
                id = r.id, model = r.model, angle = r.angle or 0,
                prefix = r.prefix or "", pos = p, want = r.want, got = r.got,
                up = up or { x = 0, y = 0, z = 1 },
            }
        end
    end
    return out
end

-- Resolve what the operator named into a point to look at and a label for the log.
-- Accepts: a 1-based index into the prop list, "camp" for the camp centre, "worst" for
-- the prop the last geometry pass liked least, or any substring of a prop's name prefix
-- or model.
function mercenaries:ShotResolve(what)
    local props = self:ShotProps()
    what = string.lower(tostring(what or ""))

    if what == "" or what == "camp" then
        local c = self.CampCenter or self.CampBuildOrigin
        if not c then return nil, "no camp - pitch one with merc_camp_make first" end
        return { pos = c, label = "camp", model = nil, angle = 0 }, nil
    end

    if what == "worst" then
        local r = (self.ShotGeoRows or {})[1]
        if not r then return nil, "no geometry pass yet - run merc_camp_geo first" end
        return { pos = r.pos, label = "worst:" .. shortModel(r.model),
                 model = r.model, angle = r.angle }, nil
    end

    local n = tonumber(what)
    if n and props[n] then
        local p = props[n]
        return { pos = p.pos, label = string.format("%d:%s", n, shortModel(p.model)),
                 model = p.model, angle = p.angle }, nil
    end

    local c = self.CampCenter or self.CampBuildOrigin
    local bestI, bestD
    for i, p in ipairs(props) do
        if string.find(string.lower(p.prefix), what, 1, true)
           or string.find(string.lower(tostring(p.model)), what, 1, true) then
            -- Nearest the camp centre, not merely first in the log: Aleksej's bed and stool
            -- are tracked in the same list and stand 2.8 km away, so "bed" could send the
            -- camera to another valley entirely.
            local d = 0
            if c then d = (p.pos.x - c.x) ^ 2 + (p.pos.y - c.y) ^ 2 end
            if not bestD or d < bestD then bestI, bestD = i, d end
        end
    end
    if bestI then
        local p = props[bestI]
        return { pos = p.pos, label = string.format("%d:%s", bestI, shortModel(p.model)),
                 model = p.model, angle = p.angle }, nil
    end
    return nil, "nothing in the camp matches '" .. what .. "'"
end

function mercenaries:ShotList(line)
    local props = self:ShotProps()
    if #props == 0 then
        log('no camp props tracked. Pitch a camp (merc_camp_make) - the list is built as it spawns.')
        return
    end
    local filter = string.lower(self:CmdClean(line))
    log('=== %d camp props ===', #props)
    for i, p in ipairs(props) do
        if filter == ""
           or string.find(string.lower(p.prefix), filter, 1, true)
           or string.find(string.lower(tostring(p.model)), filter, 1, true) then
            local tz = self:GroundTerrainAt(p.pos.x, p.pos.y, p.pos.z + 6)
            log('%3d  %-26s %-28s (%.1f, %.1f, %.2f)  dz=%s',
                i, p.prefix, shortModel(p.model), p.pos.x, p.pos.y, p.pos.z,
                tz and string.format("%+.2f", p.pos.z - tz) or "no-terrain")
        end
    end
    log('orbit one with:  merc_shot_orbit <index|substring|worst|camp>')
end

-- ============================================================ seeing the subject

-- 14 of 48 frames in the second survey were spent on a bush, a thatch roof, or empty field.
-- The camera was doing exactly what it was told - stand at radius R, look at the prop - and
-- the prop was behind something. Aiming is not the same as seeing.
--
-- So every pose is now checked: cast a ray from where the camera wants to stand to what it
-- is meant to be looking at, and if something is in the way, step back and up and try again.
-- Four candidates, cheapest first, and the last is used unconditionally so a prop that simply
-- cannot be seen from anywhere still produces a frame rather than nothing.
mercenaries.ShotLosTries = {
    { r = 1.00, h = 1.00 },
    { r = 1.35, h = 1.30 },
    { r = 0.70, h = 1.70 },
    { r = 1.90, h = 2.10 },
    { r = 2.40, h = 1.50 },
    { r = 0.55, h = 1.15 },
}

-- Is the camera standing inside a tree's crown? A ray cannot tell - leaves have no collision -
-- so three frames of one survey were shot from inside a willow and showed nothing. The bake
-- knows where every crown is; a pose inside one is refused like a pose behind a wall.
function mercenaries:ShotInCanopy(cam, groundZ)
    if not self.VegNear then return false end
    for _, e in ipairs(self:VegNear(cam.x, cam.y, 0.5)) do
        if e[1] == 1 and cam.x > e[4] + 0.8 and cam.x < e[6] - 0.8
           and cam.y > e[5] + 0.8 and cam.y < e[7] - 0.8
           and cam.z > groundZ + 2.2 and cam.z < groundZ + (e[8] or 0) then
            return true
        end
    end
    return false
end

-- Is the line from `from` to `to` clear? `slack` is how close to the target a hit may be and
-- still count as clear - the prop itself is at the target, and its own mesh must not be read
-- as an obstruction.
function mercenaries:ShotClearShot(from, to, slack)
    local dx, dy, dz = to.x - from.x, to.y - from.y, to.z - from.z
    local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
    if dist < 0.25 then return true end
    slack = slack or 1.2
    local blocked = false
    pcall(function()
        local hits = {}
        local n = Physics.RayWorldIntersection(
            { x = from.x, y = from.y, z = from.z },
            { x = dx, y = dy, z = dz },
            1, ent_terrain + ent_static, nil, nil, hits)
        if (tonumber(n) or 0) > 0 and hits[1] and hits[1].pos then
            local hx = hits[1].pos.x - from.x
            local hy = hits[1].pos.y - from.y
            local hz = hits[1].pos.z - from.z
            local hd = math.sqrt(hx * hx + hy * hy + hz * hz)
            if hd < dist - slack then blocked = true end
        end
    end)
    return not blocked
end

-- ====================================================================== camera

function mercenaries:ShotCam(pos, dir)
    local ok = pcall(function() CryAction.SetViewCamera(pos, dir) end)
    if not ok then
        -- Reported once, not once per tick: a failure here is structural, and sixteen
        -- identical lines a second buries whatever else the log was going to say.
        if not self.ShotCamWarned then
            self.ShotCamWarned = true
            log('CryAction.SetViewCamera refused - camera control is not available in this build')
        end
        return false
    end
    return true
end

-- The pose for step k of an orbit: on a circle of `radius` about the target, `height`
-- above the ground under the CAMERA (not above the target - on a slope those differ by
-- more than the height itself), looking at a point just above the target's base. Aiming
-- at the BASE rather than the middle is the whole point: a table floating four
-- centimetres over a slope is invisible from above and unmistakable from its own foot.
function mercenaries:ShotPose(run, k)
    local a = run.startAngle + (k - 1) * (2 * math.pi / run.steps)
    local lx, ly, lz = run.target.x, run.target.y, run.target.z + run.lookUp
    local look = V(lx, ly, lz)

    -- Try progressively further back and higher until the subject is actually visible.
    local best
    for i, t in ipairs(self.ShotLosTries) do
        local r = run.radius * t.r
        local cx = run.target.x + math.cos(a) * r
        local cy = run.target.y + math.sin(a) * r
        -- Stand the camera on the ground it is actually over, so a circle round a prop on a
        -- hillside keeps a level eye instead of burrowing into the uphill side.
        local gz = self:GroundTerrainAt(cx, cy, run.target.z + 40) or run.target.z
        local cam = V(cx, cy, gz + run.height * t.h)
        best = cam
        if self:ShotClearShot(cam, look) and not self:ShotInCanopy(cam, gz) then break end
    end

    return best, norm(lx - best.x, ly - best.y, lz - best.z), math.deg(a)
end

-- merc_shot_orbit <target> [radius] [height] [steps]
function mercenaries:ShotOrbit(line)
    -- Idempotent: the control-file poll re-runs this line every second, and a run that
    -- restarted every second would never reach its second frame.
    if self.ShotRun then return end

    local a = self:CmdArgs(line)
    local tgt, err = self:ShotResolve(a[1])
    if not tgt then log('%s', err); return end

    local run = {
        target     = V(tgt.pos.x, tgt.pos.y, tgt.pos.z),
        label      = tgt.label,
        radius     = tonumber(a[2]) or 4.5,
        height     = tonumber(a[3]) or 1.5,
        steps      = math.max(1, math.min(24, math.floor(tonumber(a[4]) or 8))),
        lookUp     = 0.35,
        startAngle = (tgt.angle or 0) + math.pi,   -- start face-on to the prop's front
        k          = 1,
        phase      = "move",
        waited     = 0,
    }
    -- Aim at the ground under the target, not at the entity origin. Several meshes are
    -- not centred on their own origin (see mercenaries_camp_footprints.lua) and one of
    -- the tents sits 0.69 m off along Y; the ground under it is the honest anchor.
    local tz = self:GroundTerrainAt(run.target.x, run.target.y, run.target.z + 20)
    if tz then run.target.z = tz end

    -- Clean plate: the HUD covers the bottom third and the debug overlay the top.
    self.ShotHudWasOn = true
    cvar("wh_ui_ShowHud 0")
    cvar("r_DisplayInfo 0")

    self.ShotRun = run
    log('orbit %s  r=%.1f h=%.1f steps=%d  at (%.1f, %.1f, %.2f)',
        run.label, run.radius, run.height, run.steps,
        run.target.x, run.target.y, run.target.z)
    mercenaries.ShotTick()
end

-- merc_shot_cam x y z [lookX lookY lookZ] - one fixed pose, held until merc_shot_end.
-- For the shot the orbit cannot frame: down a row of tents, or level with a table top.
function mercenaries:ShotCamAt(line)
    local a = self:CmdArgs(line)
    local x, y, z = tonumber(a[1]), tonumber(a[2]), tonumber(a[3])
    if not (x and y and z) then log('usage: merc_shot_cam x y z [lookX lookY lookZ]'); return end
    local lx, ly, lz = tonumber(a[4]), tonumber(a[5]), tonumber(a[6])
    local dir = V(1, 0, 0)
    if lx and ly and lz then dir = norm(lx - x, ly - y, lz - z) end
    self.ShotRun = { hold = true, pos = V(x, y, z), dir = dir }
    cvar("wh_ui_ShowHud 0")
    cvar("r_DisplayInfo 0")
    log('camera held at (%.1f, %.1f, %.2f)', x, y, z)
    mercenaries.ShotTick()
end

function mercenaries:ShotShutter()
    cvar("r_GetScreenShot 1")
end

-- merc_shot_snap - one frame from wherever the camera is, orbit or not.
function mercenaries:ShotSnap()
    self:ShotShutter()
    log('shutter')
end

mercenaries.ShotTick = function()
    local self = mercenaries
    local run = self.ShotRun
    if not run then return end

    if run.hold then
        self:ShotCam(run.pos, run.dir)
        Script.SetTimerForFunction(self.ShotTickMs, "mercenaries.ShotTick")
        return
    end

    -- Re-apply every tick. The player's view system reclaims the camera as soon as
    -- nothing else is setting it, so one call at the top of a step is not enough.
    local pos, dir, az = self:ShotPose(run, run.k)
    self:ShotCam(pos, dir)

    run.waited = run.waited + self.ShotTickMs
    if run.phase == "move" and run.waited >= self.ShotSettleMs then
        self:ShotShutter()
        log('shot %d/%d  az=%.0f  from (%.1f, %.1f, %.2f)',
            run.k, run.steps, az, pos.x, pos.y, pos.z)
        run.phase, run.waited = "write", 0
    elseif run.phase == "write" and run.waited >= self.ShotWriteMs then
        run.k = run.k + 1
        if run.k > run.steps then
            log('orbit %s done - %d shots', run.label, run.steps)
            self:ShotEnd()
            return
        end
        run.phase, run.waited = "move", 0
    end

    Script.SetTimerForFunction(self.ShotTickMs, "mercenaries.ShotTick")
end

function mercenaries:ShotEnd()
    self.ShotRun = nil
    pcall(function() CryAction.ResetToNormalCamera() end)
    if self.ShotHudWasOn then cvar("wh_ui_ShowHud 1") end
    log('camera released')
end

-- ==================================================================== geometry

-- The nine terrain heights under one prop's measured footprint: centre, four corners,
-- four edge midpoints, in the prop's own rotated frame. Nine is the smallest sample that
-- sees both a corner dipping into a hollow and a ridge running across the middle.
function mercenaries:ShotFootSamples(pos, angle, half)
    local fx, fy = math.cos(angle), math.sin(angle)
    local rx, ry = -fy, fx
    local centre = self:CampFootCentre(pos, angle, half)
    local out = {}
    local ring = { {0,0}, {-1,-1}, {1,-1}, {1,1}, {-1,1}, {0,-1}, {0,1}, {-1,0}, {1,0} }
    for _, s in ipairs(ring) do
        local px = centre.x + rx * (half.w * s[1]) + fx * (half.h * s[2])
        local py = centre.y + ry * (half.w * s[1]) + fy * (half.h * s[2])
        local z, surf = self:GroundTerrainAt(px, py, pos.z + 8)
        out[#out + 1] = { sx = s[1], sy = s[2], x = px, y = py, z = z, surf = surf }
    end
    return out, centre
end

-- What one prop's ground does, as numbers, measured against the prop's REAL orientation.
--
--   bury  how far the terrain rises above the prop's own surface, at its worst sample.
--         Positive means that much of the prop is inside the hill.
--   gap   how far the terrain falls below that surface, at its worst sample.
--   tilt  the MISMATCH: the angle between the prop's up axis and the ground plane's normal.
--         This is the number a fix has to drive to zero. Before the ground fit every prop
--         was spawned level, so the mismatch was simply the ground's own slope; once props
--         are laid on their plane the two part company, and only the mismatch is the fault.
--   gslope the ground's own slope, kept alongside so a flat site and a fixed prop on a steep
--         one can be told apart - both score tilt ~0, and they are not the same achievement.
--
-- Everything below is a comparison between two VECTORS and a set of heights. Nothing here
-- has to agree with the engine about which Euler component is pitch, which is roll, or what
-- order they compose in - which is exactly why the fix can be calibrated against it.
function mercenaries:ShotMeasure(p)
    local half = self:CampPropFootHalf(p.model, 0)
    local angle = p.angle or 0
    local samples, centre = self:ShotFootSamples(p.pos, angle, half)

    -- Plane through the terrain, fitted in the prop's own frame about the FOOTPRINT CENTRE,
    -- where the nine samples are symmetric and the normal equations decouple to three sums.
    local su, sv, sz, suu, svv, n = 0, 0, 0, 0, 0, 0
    local lo, hi
    for _, s in ipairs(samples) do
        if s.z then
            local u, v = (half.w or 0) * s.sx, (half.h or 0) * s.sy
            n = n + 1
            sz = sz + s.z
            su = su + u * s.z
            sv = sv + v * s.z
            suu = suu + u * u
            svv = svv + v * v
            if not lo or s.z < lo then lo = s.z end
            if not hi or s.z > hi then hi = s.z end
        end
    end
    if n < 4 then return nil end
    local b = (suu > 1e-4) and (su / suu) or 0
    local c = (svv > 1e-4) and (sv / svv) or 0

    -- That plane's normal, carried into world axes by the prop's yaw.
    local fx, fy = math.cos(angle), math.sin(angle)
    local rx, ry = -fy, fx
    local gx = (-b) * rx + (-c) * fx
    local gy = (-b) * ry + (-c) * fy
    local gz = 1.0
    local gl = math.sqrt(gx * gx + gy * gy + gz * gz)
    gx, gy, gz = gx / gl, gy / gl, gz / gl

    -- The prop's own up axis, as the engine reports it.
    local up = p.up or { x = 0, y = 0, z = 1 }
    local ul = math.sqrt((up.x or 0) ^ 2 + (up.y or 0) ^ 2 + (up.z or 1) ^ 2)
    if ul < 1e-6 then ul = 1 end
    local ux, uy, uz = (up.x or 0) / ul, (up.y or 0) / ul, (up.z or 1) / ul

    local dot = ux * gx + uy * gy + uz * gz
    if dot > 1 then dot = 1 elseif dot < -1 then dot = -1 end
    local mismatch = math.deg(math.acos(dot))

    -- Heights of the terrain relative to the PROP'S OWN surface - the plane through its
    -- origin with the prop's normal. A prop laid correctly on a slope scores zero here; the
    -- old flat-base version scored the whole fall of the hill.
    local bury, gap = nil, nil
    if math.abs(uz) > 1e-3 then
        for _, s in ipairs(samples) do
            if s.z then
                local propZ = p.pos.z - (ux * (s.x - p.pos.x) + uy * (s.y - p.pos.y)) / uz
                local resid = s.z - propZ
                if not bury or resid > bury then bury = resid end
                if not gap or resid < gap then gap = resid end
            end
        end
    end
    bury = bury or 0
    gap = -(gap or 0)

    return {
        id = p.id, model = p.model, prefix = p.prefix, angle = angle,
        pos = p.pos, centre = centre, half = half,
        lo = lo, hi = hi, samples = samples,
        bury = bury,
        gap  = gap,
        drop = hi - lo,
        tilt = mismatch,
        gslope = math.deg(math.atan(math.sqrt(b * b + c * c))),
        -- What the ground snap moved the layout's choice by. A large one is not a fault in
        -- itself, but it says the layout picked a spot the ground disagreed with.
        snapped = (p.want and p.got) and (p.got.z - p.want.z) or nil,
    }
end

-- merc_camp_geo [substring] - the whole camp, measured. Chunked across frames because a
-- full camp is ~250 props at nine rays each and the machines this mod is tuned for will
-- hitch visibly if that lands in one tick.
function mercenaries:CampGeo(line)
    if self.ShotGeo then return end        -- idempotent under the control-file poll
    local props = self:ShotProps()
    if #props == 0 then
        log('no camp props tracked - pitch a camp with merc_camp_make first')
        return
    end
    local filter = string.lower(self:CmdClean(line))
    self.ShotGeo = { props = props, i = 1, rows = {}, filter = filter, skipped = 0 }
    log('=== camp geometry: %d props, measuring ===', #props)
    mercenaries.CampGeoTick()
end

mercenaries.CampGeoTick = function()
    local self = mercenaries
    local g = self.ShotGeo
    if not g then return end

    local budget = 12
    while budget > 0 and g.i <= #g.props do
        local p = g.props[g.i]
        g.i = g.i + 1
        budget = budget - 1
        local pass = (g.filter == "")
            or string.find(string.lower(p.prefix), g.filter, 1, true)
            or string.find(string.lower(tostring(p.model)), g.filter, 1, true)
        if pass then
            local ok, row = pcall(self.ShotMeasure, self, p)
            if ok and row then
                g.rows[#g.rows + 1] = row
            else
                g.skipped = g.skipped + 1
            end
        end
    end

    if g.i <= #g.props then
        Script.SetTimerForFunction(100, "mercenaries.CampGeoTick")
        return
    end

    -- Worst first, by how much of the prop is underground, then by unmatched slope.
    -- Those are the two reported faults; ranking on their plain sum would let a wide
    -- shallow gap outvote a prop that is genuinely half-buried.
    table.sort(g.rows, function(a, b)
        local ka = math.max(a.bury, 0) * 2 + a.tilt / 45
        local kb = math.max(b.bury, 0) * 2 + b.tilt / 45
        return ka > kb
    end)
    self.ShotGeoRows = g.rows
    self.ShotGeo = nil
    self:CampGeoReport(g)
end

function mercenaries:CampGeoReport(g)
    local rows = g.rows
    local buried, tilted, floating = 0, 0, 0
    for _, r in ipairs(rows) do
        if r.bury > 0.05 then buried = buried + 1 end
        if r.tilt > 5.0 then tilted = tilted + 1 end
        if r.gap > 0.10 then floating = floating + 1 end
    end

    -- One line per prop, machine-readable, so the host can pull the whole table out of
    -- kcd.log without a human transcribing it. Fixed key=value fields, never reordered.
    for i, r in ipairs(rows) do
        System.LogAlways(string.format(
            '[CampGeo] %03d prefix=%s model=%s pos=%.2f,%.2f,%.2f yaw=%.0f foot=%.2fx%.2f '
            .. 'gz=%.2f..%.2f bury=%+.3f gap=%+.3f drop=%.3f tilt=%.1f gslope=%.1f snap=%s',
            i, tostring(r.prefix), shortModel(r.model),
            r.pos.x, r.pos.y, r.pos.z, math.deg(r.angle) % 360,
            (r.half.w or 0) * 2, (r.half.h or 0) * 2,
            r.lo, r.hi, r.bury, r.gap, r.drop, r.tilt, r.gslope or 0,
            r.snapped and string.format("%+.2f", r.snapped) or "-"))
    end

    local tSum, bSum, gSum = 0, 0, 0
    for _, r in ipairs(rows) do
        tSum = tSum + r.tilt
        bSum = bSum + math.max(r.bury, 0)
        gSum = gSum + math.max(r.gap, 0)
    end
    local m = math.max(#rows, 1)
    System.LogAlways(string.format(
        '[CampGeo] SUMMARY props=%d measured=%d skipped=%d buried>5cm=%d floating>10cm=%d tilt>5deg=%d',
        #g.props, #rows, g.skipped, buried, floating, tilted))
    -- DELTA is the calibration signal, and the only one that survives the layout being
    -- randomised between builds: per prop, how much the prop's mismatch differs from the
    -- ground's own slope. Spawning level gives 0. Tilting the right way drives it negative
    -- (down to minus the clamp). Tilting the wrong way drives it positive. Comparing raw
    -- mismatch across two rebuilds compares two different hillsides and says nothing.
    local sSum, dSum, fitted = 0, 0, 0
    for _, r in ipairs(rows) do
        local gs = r.gslope or 0
        sSum = sSum + gs
        if (r.half and (r.half.w or 0) >= 0.30 and (r.half.h or 0) >= 0.30) then
            fitted = fitted + 1
            dSum = dSum + (r.tilt - gs)
        end
    end
    System.LogAlways(string.format(
        '[CampGeo] MEANS tilt=%.2fdeg bury=%.3fm gap=%.3fm gslope=%.2fdeg delta=%+.2fdeg over=%d',
        tSum / m, bSum / m, gSum / m, sSum / m,
        dSum / math.max(fitted, 1), fitted))
    log('geometry done. Worst is #1 - look at it with:  merc_shot_orbit worst')
    log('draw the boxes in-world with:  merc_camp_geo_draw')
end

-- ================================================================ debug drawing

function mercenaries:ShotLine(a, b, colour, name, ttl)
    if self.ShotDrawLines then
        local ok = pcall(function() CryAction.PersistantLine(a, b, colour, name, ttl) end)
        if ok then return end
        self.ShotDrawLines = false
        log('PersistantLine not available - falling back to corner spheres')
    end
    pcall(function() CryAction.PersistantSphere(a, 0.06, colour, name, ttl) end)
end

-- merc_camp_geo_draw [seconds] - draw, for every measured prop, the footprint box at the
-- prop's own base height and the same box laid on the terrain. Where the two separate is
-- exactly the fault: a red box under a green one is a buried prop, a green box that is
-- not flat is ground the prop is ignoring. Then orbit it and the screenshots carry the
-- measurement with them.
function mercenaries:CampGeoDraw(line)
    local rows = self.ShotGeoRows or {}
    if #rows == 0 then log('no geometry pass yet - run merc_camp_geo first'); return end
    local ttl = tonumber(self:CmdClean(line)) or 180
    local drawn = 0
    local corners = { {-1,-1}, {1,-1}, {1,1}, {-1,1} }
    for i, r in ipairs(rows) do
        if i > 60 then break end       -- the draw list is not free; the worst 60 is plenty
        local fx, fy = math.cos(r.angle), math.sin(r.angle)
        local rx, ry = -fy, fx
        local c = r.centre
        local flat, land = {}, {}
        for k, s in ipairs(corners) do
            local px = c.x + rx * (r.half.w * s[1]) + fx * (r.half.h * s[2])
            local py = c.y + ry * (r.half.w * s[1]) + fy * (r.half.h * s[2])
            flat[k] = V(px, py, r.pos.z)
            land[k] = V(px, py, self:GroundTerrainAt(px, py, r.pos.z + 8) or r.pos.z)
        end
        for k = 1, 4 do
            local n = (k % 4) + 1
            self:ShotLine(flat[k], flat[n], { 1, 0.2, 0.2 }, "geoflat" .. i .. "_" .. k, ttl)
            self:ShotLine(land[k], land[n], { 0.2, 1, 0.3 }, "geoland" .. i .. "_" .. k, ttl)
        end
        drawn = drawn + 1
    end
    log('drew %d footprint boxes for %ds (red = prop base, green = terrain)', drawn, ttl)
end

-- ============================================================== finding a slope

-- The camp's own validator accepts ground up to CampMaxSlopeCos (28 degrees) and up to
-- CampMaxStep (1.2 m) of spread across a cell, so the worst LEGAL camp site is far steeper
-- than the meadow a camp usually gets pitched on. Measuring the fault honestly means
-- standing on that kind of ground, and the console cannot be asked to move the player -
-- `merc_lua` refuses any line containing `=`, which rules out every form of SetWorldPos.
-- Hence these two.

mercenaries.HillyScan = nil
mercenaries.HillyRows = {}

-- Terrain height with a deep reach. GroundTerrainAt only looks GroundProbeDepth (60 m)
-- below the height it is given, which is fine under your feet and misses entirely when the
-- cell being sampled is a hillside a hundred metres away and eighty below.
function mercenaries:ShotTerrainZ(x, y, fromZ)
    local hits = self:GroundRawHits(x, y, fromZ, 400, 1, ent_terrain)
    local h = hits[1]
    if h and h.pos then return h.pos.z end
    return nil
end

-- merc_shot_hilly [radius] [step] [go]
-- Sweeps a grid around the player for the steepest ground that the camp would still accept,
-- in two phases: a cheap terrain-only slope sample over every cell, then the real
-- CampValidateSpot on the best handful. Two phases because the validator costs ten rays a
-- call and the grid is several hundred cells.
function mercenaries:ShotHilly(line)
    if self.HillyScan then return end            -- idempotent under the control-file poll
    if not player then log('no player'); return end
    local a = self:CmdArgs(line)
    local radius = tonumber(a[1]) or 150
    local step   = tonumber(a[2]) or 12
    local go     = (a[3] ~= nil and a[3] ~= "" and a[3] ~= "0")

    local p = player:GetWorldPos()
    local n = math.max(1, math.floor(radius / step))
    self.HillyScan = {
        ox = p.x, oy = p.y, oz = p.z, step = step, n = n,
        gx = -n, gy = -n, rows = {}, go = go, tested = 0,
    }
    log('scanning %d m around you for the steepest ground the camp would accept...', radius)
    mercenaries.ShotHillyTick()
end

mercenaries.ShotHillyTick = function()
    local self = mercenaries
    local s = self.HillyScan
    if not s then return end

    local budget = 20
    while budget > 0 and s.gx <= s.n do
        local x = s.ox + s.gx * s.step
        local y = s.oy + s.gy * s.step
        local z0 = self:ShotTerrainZ(x, y, s.oz + 200)
        if z0 then
            -- Central differences over a 4 m arm: the same gradient the prop's own footprint
            -- would sit across, not a knife edge that no tent would ever span.
            local zx1 = self:ShotTerrainZ(x - 4, y, z0 + 60)
            local zx2 = self:ShotTerrainZ(x + 4, y, z0 + 60)
            local zy1 = self:ShotTerrainZ(x, y - 4, z0 + 60)
            local zy2 = self:ShotTerrainZ(x, y + 4, z0 + 60)
            if zx1 and zx2 and zy1 and zy2 then
                local gx = (zx2 - zx1) / 8.0
                local gy = (zy2 - zy1) / 8.0
                local deg = math.deg(math.atan(math.sqrt(gx * gx + gy * gy)))
                -- Under the camp's own 28 degree ceiling, or the site is not a camp site.
                if deg < 26.0 then
                    s.rows[#s.rows + 1] = { x = x, y = y, z = z0, deg = deg }
                end
            end
        end
        s.tested = s.tested + 1
        s.gy = s.gy + 1
        if s.gy > s.n then s.gy = -s.n; s.gx = s.gx + 1 end
        budget = budget - 1
    end

    if s.gx <= s.n then
        Script.SetTimerForFunction(60, "mercenaries.ShotHillyTick")
        return
    end

    table.sort(s.rows, function(p, q) return p.deg > q.deg end)

    -- Phase two: the real validator, walking DOWN the sorted list rather than testing only
    -- its head. Near a village the steepest ground is all roofs, banks and walls, so the
    -- first two dozen candidates can every one of them be rejected - which is exactly what
    -- happened on the first run (1225 cells sampled, nothing returned). 200 is still bounded
    -- work, and the list is sorted, so the first VALID one found is also the steepest valid one.
    local picked = {}
    for i = 1, math.min(#s.rows, 200) do
        local r = s.rows[i]
        -- refZ is the CELL's own height, not the player's. CampMaxRise/CampMaxDrop are
        -- measured against refZ, so passing the player's z would reject every candidate
        -- more than 2 m uphill of where the scan happens to have started.
        local ok = false
        pcall(function()
            ok = self:CampValidateSpot({ x = r.x, y = r.y, z = r.z }, r.z,
                                       self.CampClusterFootprint, true)
        end)
        if ok then
            picked[#picked + 1] = r
            if #picked >= 8 then break end
        end
    end

    self.HillyRows = picked
    self.HillyScan = nil

    if #picked == 0 then
        -- Say what was there even so. A silent "nothing found" is the least useful possible
        -- answer when the question is "where is there a hill".
        log('%d cells sampled, %d had terrain, none passed the camp validator.', s.tested, #s.rows)
        log('steepest ground found regardless (may be a roof, a bank or a wall):')
        for i = 1, math.min(#s.rows, 6) do
            local r = s.rows[i]
            log('  (%.1f, %.1f) z=%.1f slope=%.1f deg', r.x, r.y, r.z, r.deg)
        end
        if s.go and s.rows[1] then
            log('going to the steepest anyway - merc_camp_make will refuse if it is unusable')
            self:ShotTpTo(s.rows[1].x, s.rows[1].y)
        end
        return
    end
    log('=== steepest campable ground within reach (%d cells sampled) ===', s.tested)
    for i, r in ipairs(picked) do
        log('%d  (%.1f, %.1f) z=%.1f  slope=%.1f deg  %.0f m away', i, r.x, r.y, r.z, r.deg,
            math.sqrt((r.x - s.ox) ^ 2 + (r.y - s.oy) ^ 2))
    end
    if s.go then
        self:ShotTpTo(picked[1].x, picked[1].y)
    else
        log('go there with:  merc_shot_tp %d %d', math.floor(picked[1].x), math.floor(picked[1].y))
    end
end

function mercenaries:ShotTpTo(x, y)
    local z = self:ShotTerrainZ(x, y, (player and player:GetWorldPos().z or 0) + 300)
    if not z then log('no terrain at (%.1f, %.1f) - not moving you', x, y); return end
    local ok = pcall(function() player:SetWorldPos({ x = x, y = y, z = z + 0.4 }) end)
    if ok then
        log('moved you to (%.1f, %.1f, %.2f)', x, y, z + 0.4)
    else
        log('SetWorldPos refused')
    end
end

-- merc_shot_tp <x> <y> - stand on the ground at those coordinates.
function mercenaries:ShotTp(line)
    local a = self:CmdArgs(line)
    local x, y = tonumber(a[1]), tonumber(a[2])
    if not (x and y) then log('usage: merc_shot_tp <x> <y>'); return end
    self:ShotTpTo(x, y)
end

-- ============================================================= every upgrade

-- "Screenshot every upgrade" needs every upgrade to exist, and they are bought one at a
-- time from the quartermaster with money the bench save does not have. The ownership is
-- just fields on LogiState (see LogiRemoveUpgrade, which clears exactly these), so this
-- sets them and rebuilds. It is a harness command, not a cheat for players - dev tier.
--
-- The palisade and its gates are NOT here. Those are freehand-built by the player run by
-- run (WallRuns, GateCount); there is no "own a wall" flag to set, so they have to be drawn
-- by hand and are reported as skipped rather than silently missing.
function mercenaries:ShotUpgAll()
    local L = self:LogiState()
    if not L then log('no logistics state'); return end
    L.foodCartDays    = math.max(L.foodCartDays or 0, 30)
    L.innDays         = math.max(L.innDays or 0, 30)
    L.innActive       = true
    L.hunterSpots     = math.max(L.hunterSpots or 0, 3)
    L.hasSmithy       = true
    L.hasAlchemy      = true
    L.hasPracticeYard = true
    L.hasHouse        = true
    L.hasTower        = true
    L.hasArcherCart   = true
    L.hasTrader       = true
    pcall(function() self:LogiApplyBuffs() end)
    pcall(function() self:LogiSave() end)
    log('granted: cart, tavern, hunter, smithy, alchemy, practice yard, house, towers, archer carts, trader')
    log('NOT granted: palisade and gates - those are freehand-built, there is no ownership flag')
    pcall(function() self:LogiRebuildCampForUpgrade() end)
end

mercenaries:DevCommand("merc_shot_upg_all", "mercenaries:ShotUpgAll()",
    "Harness: grant every buyable camp upgrade and rebuild, so all of them can be inspected")

-- ============================================================ clearing the view

-- Grass is decorative and it is the single biggest obstacle to judging a placement. The
-- second survey lost frames to it and, worse, buried real props to mid-height so a shelter
-- that was seated perfectly still read as broken. Turning the merged-mesh grass off for the
-- duration of a capture shows what the PLACEMENT did, separately from what the meadow did.
--
-- Bushes and trees are a second switch, because "the prop is inside a bush" is a genuine
-- siting defect that should stay visible unless it is actively in the lens.
--
-- Neither of these touches the camp. They are render cvars, restored afterwards, and the
-- game looks normal again the moment they are put back.
-- Henry stands at the anchor for a quarter of an hour while the camera is elsewhere, and he
-- is mortal there: a survey ended on the game-over screen at shot 3 of 4 of the training
-- row, killed by whatever came by. The torture harness solved this already - 50 000 max
-- health, refilled every tick (see TortureInvulnerable; a heal at normal max health is not
-- enough, a knight killed him between two of them). The control-file poll re-executes its
-- line once a second, so `merc_shot_god 1` left in it IS the refill.
-- ...except that the poll only repeats its LAST line, and the survey's own commands replace
-- it within seconds. So the refill is a timer of its own, re-armed every second for as
-- long as the mode is on; the torture harness's read-back showed maxHealth=50000 with
-- health=100 in the same frame, so the fifth tick logs what the health really is.
mercenaries.ShotGodOn = false
mercenaries.ShotGodTicks = 0

function mercenaries:ShotGod(line)
    local a = self.CmdArgs and self:CmdArgs(line) or {}
    local on = tostring(a[1] or "1") ~= "0"
    -- player_immortality_nonpersistent (Libs/Tables/rpg/buff.xml: imm=1, upr=1, not saved) on
    -- top of the per-second refill below: the refill loses to a single blow over 100.
    local buff = "44e1ccc9-9252-48a9-922d-2ae4523c69a3"
    if on and not self.ShotGodOn then
        self.ShotGodOn = true
        self.ShotGodTicks = 0
        pcall(function() self.ShotGodBuffInst = player.soul:AddBuff(buff) end)
        Script.SetTimerForFunction(1000, "mercenaries.ShotGodTick")
    elseif not on then
        self.ShotGodOn = false
        -- RemoveBuff wants the instance AddBuff returned; the by-guid sweep is the backstop.
        if self.ShotGodBuffInst then pcall(function() player.soul:RemoveBuff(self.ShotGodBuffInst) end) end
        self.ShotGodBuffInst = nil
        pcall(function() player.soul:RemoveAllBuffsByGuid(buff) end)
    end
end

mercenaries.ShotGodTick = function()
    local self = mercenaries
    if not self.ShotGodOn then return end
    self.ShotGodTicks = self.ShotGodTicks + 1
    -- Measured 2026-09-21: actor:SetHealth(50000) never takes - the read-back stays at 100
    -- with maxHealth 50000, at tick 5 and at tick 300. The soul's own health state does
    -- take; it is the 0..100 the HUD shows. Refilled every second, and the max is left alone.
    pcall(function()
        local soul = player and player.soul
        if soul and soul.SetState then soul:SetState("health", 100) end
        local actor = player and player.actor
        if actor then
            local m = actor:GetMaxHealth()
            if m and m > 0 then pcall(function() actor:SetHealth(m) end) end
        end
        if self.ShotGodTicks == 5 or self.ShotGodTicks % 300 == 0 then
            local sh = "?"
            pcall(function() sh = tostring(soul:GetState("health")) end)
            log('god: tick %d soul health=%s actor health=%s max=%s', self.ShotGodTicks, sh,
                tostring(actor and actor:GetHealth()), tostring(actor and actor:GetMaxHealth()))
        end
    end)
    Script.SetTimerForFunction(1000, "mercenaries.ShotGodTick")
end

mercenaries:DevCommand("merc_shot_god", "mercenaries:ShotGod(%line)",
    "Make Henry unkillable (1) or mortal again (0) while a survey runs")

function mercenaries:ShotGrass(line)
    local on = self:CmdBool(line)
    cvar("e_MergedMeshes " .. (on and "1" or "0"))
    log("grass %s", on and "ON" or "OFF")
end

function mercenaries:ShotVeg(line)
    local on = self:CmdBool(line)
    cvar("e_Vegetation " .. (on and "1" or "0"))
    log("vegetation (bushes, trees) %s", on and "ON" or "OFF")
end

mercenaries:DevCommand("merc_shot_grass", "mercenaries:ShotGrass(%line)",
    "Merged-mesh grass on/off, so a capture shows the placement rather than the meadow")
mercenaries:DevCommand("merc_shot_veg",   "mercenaries:ShotVeg(%line)",
    "Bushes and trees on/off for a capture")

-- ========================================================== what the ground is

-- The judge's verdict after two rounds was that seating is solved and SITING is not: props
-- land in metre-high meadow and streambed gravel while mown ground sits twenty metres away.
-- To place on good ground the placer first has to be able to tell good ground from bad, and
-- it currently cannot - CampValidateSpot scores slope and obstacles and nothing else.
--
-- Terrain SURFACE TYPE is the candidate signal, because that is what vegetation layers are
-- keyed to: tall grass grows on the meadow material and not on the path material. The ground
-- guard already reads a surface id off every terrain ray (see docs/ground-guard.md, where it
-- is what tells terrain from a woodpile) and System.GetSurfaceTypeNameById resolves it.
--
-- This command changes nothing. It reports what is actually under the camp and around it, so
-- a rule can be written from data instead of from a guess about which id means grass.
function mercenaries:CampSurfScan(line)
    local a = self:CmdArgs(line)
    local radius = tonumber(a[1]) or 60
    local step   = tonumber(a[2]) or 4
    if not player then log('no player'); return end
    local p = player:GetWorldPos()

    local function nameOf(id)
        local n
        pcall(function() n = System.GetSurfaceTypeNameById(id) end)
        return n or ("id" .. tostring(id))
    end

    -- 1. what every camp prop is standing on
    local byProp = {}
    for _, r in ipairs(self:ShotProps()) do
        local _, surf = self:GroundTerrainAt(r.pos.x, r.pos.y, r.pos.z + 6)
        local key = nameOf(surf)
        byProp[key] = (byProp[key] or 0) + 1
    end
    System.LogAlways('[CampSurf] === surfaces under the camp props ===')
    for k, v in pairs(byProp) do
        System.LogAlways(string.format('[CampSurf]   %-28s %d prop(s)', k, v))
    end

    -- 2. what is available nearby, so "there was better ground 20 m away" can be checked
    local byCell, total = {}, 0
    local n = math.max(1, math.floor(radius / step))
    for i = -n, n do
        for j = -n, n do
            local x, y = p.x + i * step, p.y + j * step
            local _, surf = self:GroundTerrainAt(x, y, p.z + 60)
            if surf then
                local key = nameOf(surf)
                byCell[key] = (byCell[key] or 0) + 1
                total = total + 1
            end
        end
    end
    System.LogAlways(string.format(
        '[CampSurf] === ground available within %d m (%d cells) ===', radius, total))
    for k, v in pairs(byCell) do
        System.LogAlways(string.format('[CampSurf]   %-28s %4d cells  %5.1f%%',
            k, v, 100 * v / math.max(total, 1)))
    end
    log('surface scan done - correlate these names with the frames that looked wrong')
end

mercenaries:DevCommand("merc_camp_surfscan", "mercenaries:CampSurfScan(%line)",
    "Report the terrain surface type under every camp prop and across the ground nearby")

-- ============================================== what CAN be detected at a point

-- Placement keeps failing on things the tests cannot see. Terrain is easy, buildings were
-- solved by comparing a collision ray against a terrain ray - but a bush standing on ordinary
-- grass is invisible to every check the camp has, which is why a judged survey found a shrub
-- growing through the forge hearth and bedrolls lying inside thickets.
--
-- Rather than guess at another heuristic, this reports what each available method actually
-- returns at one spot. Stand in a bush, on open ground, against a building and in a stream,
-- run it in each, and the differences between the outputs ARE the detector - measured, not
-- assumed. Nothing here changes anything.
--
--   merc_camp_sitescan              at the player
--   merc_camp_sitescan <x> <y>      anywhere
mercenaries.SiteScanMasks = {
    { name = "terrain",     m = 256 },   -- ent_terrain
    { name = "static",      m = 1 },     -- ent_static: brushes, vegetation IF it is physicalised
    { name = "rigid",       m = 4 },     -- ent_rigid
    { name = "sleeping",    m = 2 },     -- ent_sleeping_rigid: the one never queried before
    { name = "independent", m = 16 },    -- ent_independent
    { name = "all",         m = 287 },   -- ent_all
}

function mercenaries:CampSiteScan(line)
    local a = self:CmdArgs(line)
    local x, y = tonumber(a[1]), tonumber(a[2])
    local p = player and player:GetWorldPos()
    if not x then
        if not p then System.LogAlways("[SiteScan] no player and no coordinates"); return end
        x, y = p.x, p.y
    end
    local topZ = (p and p.z or 0) + 20

    System.LogAlways(string.format("[SiteScan] ===== (%.2f, %.2f) =====", x, y))

    -- 1. One ray per entity-type mask, reported separately. Which masks see a thing is the
    --    whole question: if a bush shows up under `static` it can be rejected with a ray, and
    --    if it shows up under none of them no ray will ever find it.
    for _, spec in ipairs(self.SiteScanMasks) do
        local hits = {}
        local n = 0
        pcall(function()
            n = Physics.RayWorldIntersection({ x = x, y = y, z = topZ },
                                             { x = 0, y = 0, z = -60 },
                                             4, spec.m, nil, nil, hits) or 0
        end)
        n = tonumber(n) or 0
        if n == 0 then
            System.LogAlways(string.format("[SiteScan]  %-12s no hit", spec.name))
        else
            for i = 1, n do
                local h = hits[i]
                if h and h.pos then
                    local sname = "?"
                    pcall(function() sname = System.GetSurfaceTypeNameById(h.surface) or "?" end)
                    System.LogAlways(string.format(
                        "[SiteScan]  %-12s z=%.2f surface=%s(%s) entity=%s renderNode=%s",
                        spec.name, h.pos.z, tostring(sname), tostring(h.surface),
                        h.entity and "yes" or "-", h.renderNode and "yes" or "-"))
                end
            end
        end
    end

    -- 2. A VOLUME query rather than a line. A ray straight down the middle of a bush can miss
    --    every twig; a box around the prop's footprint cannot. This is also the natural test
    --    for clipping, which the camp currently only checks against its OWN props.
    local function box(tag, r, h)
        local ents
        pcall(function()
            ents = System.GetPhysicalEntitiesInBox(
                { x = x, y = y, z = (p and p.z or 0) - 1 }, r)
        end)
        if not ents then
            System.LogAlways(string.format("[SiteScan]  box(%s) returned nil - not usable", tag))
            return
        end
        local names = {}
        for _, e in ipairs(ents) do
            local nm
            pcall(function() nm = e:GetName() end)
            pcall(function()
                local cl = e.class or (e.GetClassName and e:GetClassName())
                if cl then nm = tostring(nm) .. "[" .. tostring(cl) .. "]" end
            end)
            names[#names + 1] = tostring(nm)
        end
        System.LogAlways(string.format("[SiteScan]  box(%s r=%.1f) %d entity(ies): %s",
            tag, r, #ents, table.concat(names, ", ")))
    end
    box("near", 2.0)
    box("wide", 4.0)

    -- 3. Entities by proximity, which finds things the physics world may not carry.
    local sph
    pcall(function() sph = System.GetEntitiesInSphere({ x = x, y = y, z = (p and p.z or 0) }, 3.0) end)
    if sph then
        local names = {}
        for _, e in ipairs(sph) do
            local nm; pcall(function() nm = e:GetName() end)
            names[#names + 1] = tostring(nm)
        end
        System.LogAlways(string.format("[SiteScan]  sphere(3.0) %d entity(ies): %s",
            #sph, table.concat(names, ", ")))
    else
        System.LogAlways("[SiteScan]  sphere returned nil - not usable")
    end

    -- 4. The surface material in RINGS, not just underfoot. Vegetation has no physics proxy
    --    at all in this build - proven above, every ray mask returns nothing at a spot where
    --    a bush visibly grows through the forge hearth - so the only signal correlated with
    --    vegetation is the terrain LAYER it is painted on. A prop's own centre can read
    --    mat_soil while the thicket it is standing in is rooted on mat_bushes a metre away,
    --    which a footprint-sized sample would never see. If that is what is happening, a
    --    wider surface check is the whole fix.
    for _, R in ipairs({ 0, 1.5, 3.0, 5.0 }) do
        local counts, total = {}, 0
        local n = (R == 0) and 1 or 8
        for k = 0, n - 1 do
            local px, py = x, y
            if R > 0 then
                local ang = k / n * 2 * math.pi
                px, py = x + math.cos(ang) * R, y + math.sin(ang) * R
            end
            local _, surf = self:GroundTerrainAt(px, py, topZ)
            if surf then
                local nm = "?"
                pcall(function() nm = System.GetSurfaceTypeNameById(surf) or "?" end)
                counts[nm] = (counts[nm] or 0) + 1
                total = total + 1
            end
        end
        local parts = {}
        for k, v in pairs(counts) do parts[#parts + 1] = string.format("%s x%d", k, v) end
        System.LogAlways(string.format("[SiteScan]  ring r=%.1f  %s", R,
            (#parts > 0) and table.concat(parts, ", ") or "no terrain"))
    end

    -- 5. Does the AI think this is walkable? A bush that blocks movement would show here even
    --    though it is invisible to physics. If it does not, nothing in the engine can see it.
    if player then
        local walk = "?"
        pcall(function()
            local pp = player:GetWorldPos()
            walk = tostring(AI.CanMoveStraightToPoint(player.id, { x = x, y = y, z = pp.z }))
        end)
        System.LogAlways("[SiteScan]  AI.CanMoveStraightToPoint = " .. walk)
    end

    System.LogAlways("[SiteScan] ===== end =====")
end

mercenaries:DevCommand("merc_camp_sitescan", "mercenaries:CampSiteScan(%line)",
    "Report what every detection method sees at a point - rays per entity mask, box and sphere queries")

-- ===================================================================== commands

mercenaries:DevCommand("merc_shot_list",     "mercenaries:ShotList(%line)",
    "List the camp props the layout put down, with their height over the terrain")
mercenaries:DevCommand("merc_shot_orbit",    "mercenaries:ShotOrbit(%line)",
    "Orbit the camera round a camp prop taking screenshots: <index|substring|worst|camp> [radius] [height] [steps]")
mercenaries:DevCommand("merc_shot_cam",      "mercenaries:ShotCamAt(%line)",
    "Hold the camera at x y z [lookX lookY lookZ] until merc_shot_end")
mercenaries:DevCommand("merc_shot_snap",     "mercenaries:ShotSnap()",
    "Take one screenshot from wherever the camera is")
mercenaries:DevCommand("merc_shot_end",      "mercenaries:ShotEnd()",
    "Give the camera back to the player and restore the HUD")
mercenaries:DevCommand("merc_camp_geo",      "mercenaries:CampGeo(%line)",
    "Measure every camp prop against the terrain under its own footprint; [substring] filters")
mercenaries:DevCommand("merc_camp_geo_draw", "mercenaries:CampGeoDraw(%line)",
    "Draw the measured footprints in-world: red at the prop's base, green on the terrain")
mercenaries:DevCommand("merc_shot_hilly",     "mercenaries:ShotHilly(%line)",
    "Find the steepest ground near you that the camp would still accept: [radius] [step] [go]")
mercenaries:DevCommand("merc_shot_tp",       "mercenaries:ShotTp(%line)",
    "Stand on the ground at <x> <y>")
