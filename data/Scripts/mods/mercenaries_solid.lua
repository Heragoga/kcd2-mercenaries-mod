-- =============================================================================
-- NPC-vs-world collision: why men walk through walls, and the switch that stops it.
--
-- The palisade is solid. `palisade_wall_a_v3.cgf` carries a real `$physics_proxy`,
-- `mercenaries_Prop` physicalises it PE_STATIC, and a ray fired across a built wall at
-- ankle, hip and chest height hits the timber every time. The player is stopped by it.
-- The reason an NPC is not has nothing to do with the navmesh:
--
--     ac_disableLivingVsRigidCollisions
--       "Disable collisions between living and rigid entities.
--        Must reload level (or update collider mode otherwise) to work."
--
-- KCD2 ships that ON. An NPC's living entity is built with rigid and static entities
-- filtered OUT of the set it resolves against, so it walks through anything - ours and
-- the base game's alike. The player's is not. That is the whole of "NPC collision is not
-- player collision", and no amount of navmesh work would ever have reached it.
--
-- The wall lab measured eleven other candidates first: every collider mode (0-7) forced
-- globally with `ac_ColliderModeAI` and per entity with `SetColliderMode`, both movement
-- control methods, the extra solid collider, and the collision classes before them.
-- Every one walked through at the control's own lateral. Turning this cvar off stopped
-- the walker dead at the timber on both trials and pushed him 5.5 m along the wall face
-- where a straight line was 2.9 m. See docs/walls-and-sieges.md.
--
-- ==== HOW IT IS SCOPED, AND WHY IT IS THIS WAY ROUND ====
--
-- Two facts, and they pull in opposite directions.
--
-- The flag is read when a character is PHYSICALISED. So leaving it armed is RELIABLE -
-- everything that streams in or spawns is born solid, with nothing for us to miss - and
-- that is the version that was confirmed working in play.
--
-- A collider-mode change also re-applies it, to one man, leaving everyone else alone
-- (`ac_ColliderModeAI` is the same thing spelled globally, and measured inert here). So
-- the flag can be SCOPED per man - but only as reliably as our own bookkeeping, and a
-- first attempt that scoped it by arming the flag for one pulse at a time missed men
-- constantly: a sprinting man covers more ground between ticks than the band is wide,
-- and anything spawning between two ticks is born permeable.
--
-- So it is done the way round that fails safe. While the player is anywhere near a wall
-- of ours the flag is ARMED and left armed, which is the reliable half; the per-man pulse
-- is then used only to HAND BACK men who are not near a wall. Steady state is what was
-- asked for - only men close to a wall are solid - and the failure mode is a man being
-- solid for one tick longer than he needed to be, instead of not being solid when it
-- mattered. Away from every wall the flag goes back to its shipping value and everyone
-- is handed back, so the rest of the world is untouched.
-- =============================================================================

local function solidSay(s) System.LogAlways("[MercSolid] " .. s) end

-- ==== WHICH OF OUR PROPS ARE SOLID AT ALL ====
--
-- Separate question from the cvar above, and a performance one rather than a behaviour one.
-- A fully-upgraded camp puts about 250 physicalised props inside 50 m - every tent, table,
-- rack and wood pile - and each pays broadphase for ever, whether or not anything ever
-- touches it.
--
--   palisade   walls only: the things whose whole purpose is to stop somebody  (default)
--   all        everything, as it was
--   none       nothing of ours is solid
--
-- "palisade" covers the stone curtain too: both are built through the same wall system, and
-- a wall you can walk through is not a wall. Everything else - camp dressing, gates, archer
-- carts, the player house - spawns with no physics at all. Change it with `merc_collision`.
mercenaries.CollisionMode = mercenaries.CollisionMode or "palisade"

function mercenaries:PropSolid(kind)
    local m = self.CollisionMode
    if m == "all" then return true end
    if m == "none" then return false end
    return kind == "wall"
end

-- The static physics table this mod uses everywhere, or the table that spawns with no
-- physics. NOT nil for the non-solid case: a spawn that omits Physics inherits BasicEntity's
-- class default (bPhysicalize = true, bRigidBody = true, bPushableByPlayers = true), so
-- leaving it out asked for a pushable rigid body rather than a ghost.
function mercenaries:PropPhysics(kind)
    if not self:PropSolid(kind) then return { bPhysicalize = false, bRigidBody = false } end
    return { bPhysicalize = true, bRigidBody = false, bPushableByPlayers = false,
             Mass = -1, Density = -1 }
end

function mercenaries:CollisionSet(line)
    local v = tostring(line or ""):gsub("[\"']", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if v ~= "palisade" and v ~= "all" and v ~= "none" then
        solidSay("merc_collision <palisade|all|none> - currently " .. tostring(self.CollisionMode))
        solidSay("   palisade = walls only (default), all = every prop, none = nothing")
        solidSay("   takes effect on the next camp build; re-pitch or buy something to see it")
        return
    end
    self.CollisionMode = v
    solidSay("prop collision: " .. v)
end

mercenaries:PlayerCommand("merc_collision", "mercenaries:CollisionSet('%line')",
                          "Which of the mod's props are solid: palisade | all | none")

mercenaries.SolidCvar   = "ac_disableLivingVsRigidCollisions"
-- 0 = never touch anything
-- 1 = solid only for men near a wall of ours  (default)
-- 2 = solid for everyone near the company, wall or no wall - the blunt version, kept
--     because it is the one that was proved in play
mercenaries.SolidMode     = 1
mercenaries.SolidWallNear = 20.0    -- a man this close to a wall of ours stays solid
mercenaries.SolidGate     = 140.0   -- player further than this from every wall: hands everyone back
mercenaries.SolidRegion   = 150.0   -- how far around the player men are bookkept at all
mercenaries.SolidTickMs   = 1000    -- while armed. A running man covers ~6m of the band per tick.
mercenaries.SolidIdleMs   = 4000    -- while there is nothing to do

mercenaries.SolidShipped  = nil     -- the value the game booted with, read once per level
mercenaries.SolidArmed    = false   -- is the flag currently left at 0?
mercenaries.SolidWatch    = {}      -- [key] = { ent=, soft=, walked=, still=, x=, y=, asked= }
mercenaries.SolidStuckAsk = {}      -- [key] = ticks left in which a detour may claim him

local NPC_CLASSES = { "NPC", "NPC_Female", "NPC_NAI" }

-- Declared before the closures that use them.
local function mercKey(ent)
    return ent and tostring((ent.this and ent.this.id) or ent.id) or nil
end

local function pointSegDist2(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local L2 = dx * dx + dy * dy
    local t = 0
    if L2 > 1e-6 then
        t = ((px - ax) * dx + (py - ay) * dy) / L2
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
    end
    local cx, cy = ax + dx * t, ay + dy * t
    return (px - cx) ^ 2 + (py - cy) ^ 2
end

-- ==== pressed against the wall ====
-- Making a man solid tells the pathfinder nothing. The navmesh is baked, so he still
-- AIMS through the palisade and now his body stops him. Out of combat the mod's own
-- steering can take him round (mercenaries_navmesh.lua); a man it cannot reach leans on
-- the timber, which used to be invisible because he walked through it.
--
-- IN COMBAT HE IS LEFT THERE, and that is deliberate. The scheduler's detour arm is
-- gated `~$inCombat`, so a fighting man's reroute can never be granted - and the first
-- version of this file let him through instead, which is precisely "during battles they
-- still phase through walls". A man shoving at a palisade during a siege is what a siege
-- looks like; a man teleporting through it is not. If he has nobody he can reach, that
-- is the target picker's business (see "TARGETING THROUGH WALLS" in the navmesh module),
-- not something to fix by opening the wall.
mercenaries.SolidStuckNear   = 1.8   -- this close to the wall line counts as pressed against it
mercenaries.SolidStuckMin    = 0.5   -- ground he must cover between ticks to count as moving
mercenaries.SolidStuckTicks  = 4     -- stuck ticks before a reroute is asked for
mercenaries.SolidDetourGrace = 5     -- ticks a reroute has to take him before he is let through
mercenaries.SolidFreeTicks   = 5     -- ticks he stays permeable once let through
mercenaries.SolidReleaseInCombat = false   -- never let a fighting man through a wall

function mercenaries:SolidShippedValue()
    if self.SolidShipped == nil then
        local v
        pcall(function() v = System.GetCVar(self.SolidCvar) end)
        self.SolidShipped = v
    end
    return self.SolidShipped
end

function mercenaries:SolidWriteCvar(armed)
    local shipped = self:SolidShippedValue()
    if shipped == nil then return false end
    local ok = pcall(function() System.SetCVar(self.SolidCvar, armed and 0 or shipped) end)
    return ok
end

-- ==== the per-man latch ====
-- A collider-mode change is what makes a character re-read the flag. It has to be a real
-- CHANGE: re-requesting the mode a man is already in can be dropped, which is why this
-- steps through 3 (Pushable) and back to 0 (Undefined, the engine's own choice) rather
-- than setting one value. The shipping door smart object does the same thing with 7 and
-- 0. The lab measured both 3 and 0 as inert on their own, so this cannot change anything
-- by itself - all it does is re-apply whatever the flag currently says.
local function pulse(ent)
    local ok = false
    pcall(function() ent:SetColliderMode(3); ent:SetColliderMode(0); ok = true end)
    return ok
end

-- Pulse a list of men with the flag held at one value, then put the flag back to whatever
-- the sweep wants it at. One pair of cvar writes for the whole list.
function mercenaries:SolidLatch(list, solid)
    if #list == 0 then return 0 end
    if not self:SolidWriteCvar(solid) then return 0 end
    local n = 0
    for _, c in ipairs(list) do
        if pulse(c.ent) then
            n = n + 1
            local w = self.SolidWatch[c.key] or {}
            w.soft = not solid
            self.SolidWatch[c.key] = w
        end
    end
    self:SolidWriteCvar(self.SolidArmed)
    return n
end

-- ==== who is near a wall ====
function mercenaries:SolidWallSegs()
    if not self.NavWallSegments then return nil, nil end
    local segs, box
    pcall(function() segs, box = self:NavWallSegments() end)
    if not segs or #segs == 0 then return nil, nil end
    return segs, box
end

local function distToWalls2(p, segs, box, pad)
    if box then
        if p.x < box.minx - pad or p.x > box.maxx + pad
        or p.y < box.miny - pad or p.y > box.maxy + pad then return nil end
    end
    local best
    for i = 1, #segs do
        local s = segs[i]
        local d2 = pointSegDist2(p.x, p.y, s.ax, s.ay, s.bx, s.by)
        if (not best) or d2 < best then best = d2 end
    end
    return best
end

-- Everyone within SolidRegion of the player, plus the company wherever it is. While the
-- flag is armed any of these may have been born solid, so all of them have to be bookkept
-- or a man a long way from the wall stays solid and nobody notices.
function mercenaries:SolidCandidates()
    local out, seen = {}, {}
    for _, ent in pairs(self.ActiveMercs or {}) do
        local k = mercKey(ent)
        local p
        pcall(function() p = ent:GetWorldPos() end)
        if k and p and not seen[k] then
            seen[k] = true
            out[#out + 1] = { ent = ent, key = k, pos = p, merc = true }
        end
    end
    local pp
    pcall(function() pp = player and player:GetWorldPos() end)
    if not pp then return out end
    local radius = self.SolidRegion or 150.0
    local r2 = radius ^ 2

    -- The mod keeps ONE shared box query around the player (mercenaries_perf.lua); reuse it
    -- rather than enumerating the whole level three times over, every second, for as long as
    -- the player stands at his own camp. PerfNpcsNear returns nil for "not covered" - never
    -- for "nobody there" - so the fallback below still runs when the cache cannot answer.
    local cached = nil
    if self.PerfNpcsNear then
        pcall(function() cached = self:PerfNpcsNear(pp, radius, 1500) end)
    end
    if cached then
        for _, rec in ipairs(cached) do
            local e = rec.entity
            local k = e and mercKey(e)
            if k and not seen[k] then
                seen[k] = true
                out[#out + 1] = { ent = e, key = k,
                                  pos = { x = rec.pos.x, y = rec.pos.y, z = rec.pos.z } }
            end
        end
        return out
    end

    -- A SPHERE query, not a whole-level enumeration. GetEntitiesByClass returns every NPC of
    -- that class in the level and leaves the distance filter to Lua; three of those ran on
    -- every call here, and the cache above can never prevent it: PerfNpcsNear refuses unless
    -- `distance + radius <= scan.r`, and scan.r is EnemyScanRadius (18 m) while this asks for
    -- SolidRegion (150 m) - so `0 + 150 > 18` is false-by-construction on every single call.
    -- merc_verbose caught the result: System.GetEntitiesByClass ran exactly 3x per
    -- SolidCandidates, 45-54 per window, and dropped to ZERO the moment the palisade came
    -- down - because Solid only arms near our walls. That is the whole of "the second even
    -- one single wall is up it lags".
    for _, cls in ipairs(NPC_CLASSES) do
        local ents
        pcall(function() ents = System.GetEntitiesInSphereByClass(pp, radius, cls) end)
        for _, e in pairs(ents or {}) do
            local k = mercKey(e)
            if k and not seen[k] then
                local p
                pcall(function() p = e:GetWorldPos() end)
                if p and ((p.x - pp.x) ^ 2 + (p.y - pp.y) ^ 2) <= r2 then
                    seen[k] = true
                    out[#out + 1] = { ent = e, key = k, pos = p }
                end
            end
        end
    end
    return out
end

-- ==== reroute ====
-- The router cannot be fired from here: a behaviour only ever runs if an INTERRUPT fires
-- it, and that interrupt lives in the scheduler. So this raises a flag NavFollowPoll
-- reads, which is what lets that poll skip its confirm count and its cooldown for a man
-- who is genuinely stuck rather than merely blocked.
function mercenaries:SolidAskDetour(key)
    self.SolidStuckAsk[key] = (self.SolidDetourGrace or 5) + 1
end

function mercenaries:SolidIsStuck(ent)
    local k = mercKey(ent)
    return (k ~= nil) and (self.SolidStuckAsk[k] ~= nil)
end

function mercenaries:SolidDetourTaken(ent)
    local k = mercKey(ent)
    if k then self.SolidStuckAsk[k] = nil end
end

-- Is this man fighting? A fighting man is never let through a wall.
local function inCombat(ent)
    local hot = false
    pcall(function() hot = ent.soul and ent.soul:IsInCombatDanger() or false end)
    return hot
end

-- ==== teardown ====
function mercenaries:SolidTeardown(why)
    local undo = {}
    for k, w in pairs(self.SolidWatch) do
        if w.ent and not w.soft then undo[#undo + 1] = { ent = w.ent, key = k } end
    end
    self.SolidArmed = false
    local n = self:SolidLatch(undo, false)
    self:SolidWriteCvar(false)
    self.SolidWatch, self.SolidStuckAsk = {}, {}
    if n > 0 then solidSay(string.format("%d handed back (%s)", n, tostring(why))) end
end

-- ==== one pass ====
function mercenaries:SolidSweep()
    local mode = self.SolidMode or 0
    local segs, box = self:SolidWallSegs()

    local region = false
    if mode == 2 then
        region = true
    elseif mode == 1 and segs then
        local p
        pcall(function() p = player and player:GetWorldPos() end)
        if p then
            local d2 = distToWalls2(p, segs, box, self.SolidGate or 140.0)
            region = (d2 ~= nil and d2 <= (self.SolidGate or 140.0) ^ 2)
        end
    end

    if not region then
        if self.SolidArmed or next(self.SolidWatch) then
            self:SolidTeardown(mode == 0 and "switched off" or "away from every wall")
        end
        return false
    end

    -- Armed and left armed: this is the half that cannot miss anybody.
    if not self.SolidArmed then
        self.SolidArmed = true
        self:SolidWriteCvar(true)
        solidSay("armed at the wall - men here are solid; men away from it are handed back")
    end

    local near2   = (self.SolidWallNear or 20.0) ^ 2
    local stuck2  = (self.SolidStuckNear or 1.8) ^ 2
    local min2    = (self.SolidStuckMin or 0.5) ^ 2
    local handBack, takeBack, seen = {}, {}, {}
    local freed, asked, pressing, held, skipped = 0, 0, 0, 0, 0

    for _, c in ipairs(self:SolidCandidates()) do
        local k, w = c.key, (self.SolidWatch[c.key] or {})
        seen[k] = true
        w.ent = c.ent

        local d2 = segs and distToWalls2(c.pos, segs, box, self.SolidWallNear or 20.0)
        local nearWall = (d2 ~= nil and d2 <= near2)
        local want = (mode == 2) or nearWall

        if w.free then
            w.free = w.free - 1
            if w.free <= 0 then w.free = nil end
            want = false
        end

        if want and w.soft then takeBack[#takeBack + 1] = c
        elseif (not want) and (w.soft ~= true) then handBack[#handBack + 1] = c end

        -- Stuck only counts for a man who is solid, right up against the wall, and has
        -- been SEEN walking - a gate sentry stands NavGateInset (2 m) inside the line and
        -- is not going anywhere.
        if want and not w.soft and d2 and d2 <= stuck2 then
            local moved2 = w.x and ((c.pos.x - w.x) ^ 2 + (c.pos.y - w.y) ^ 2) or 1e9
            if moved2 >= min2 then w.walked = true end
            w.still = (w.walked and moved2 < min2) and ((w.still or 0) + 1) or 0

            if w.still >= (self.SolidStuckTicks or 4) then
                pressing = pressing + 1
                if inCombat(c.ent) and not self.SolidReleaseInCombat then
                    -- A siege. Leave him shoving at it; do not open the wall.
                    held = held + 1
                    self.SolidStuckAsk[k] = nil
                elseif w.still == (self.SolidStuckTicks or 4) then
                    self:SolidAskDetour(k)
                    asked = asked + 1
                else
                    local routing = false
                    pcall(function() routing = self.IsNavGotoActive and self:IsNavGotoActive(c.ent) end)
                    -- A camp sentry is routed by his own patrol logic, not by NavGoto:
                    -- GetPatrolWaypoint hands him NavSteerPoint corners and sets onDetour.
                    -- Asking only NavGoto reported "nothing is routing him" while the mod was
                    -- walking him round the wall, and then let him through on that basis.
                    if not routing then
                        pcall(function()
                            routing = (self.IsPatrolDetouring and self:IsPatrolDetouring(k)) or false
                        end)
                    end
                    if routing then
                        w.still = 0
                        self.SolidStuckAsk[k] = nil
                    else
                        local left = (self.SolidStuckAsk[k] or 0) - 1
                        self.SolidStuckAsk[k] = (left > 0) and left or nil
                        if left <= 0 then
                            -- NEVER release a camp actor, for the same reason a fighting man is
                            -- never released: the scheduler's detour arm is gated ~$isCampActor,
                            -- so the reroute this grace is waiting for can never be granted and
                            -- the release is a phase-through on a fixed timer. The camp owns his
                            -- route, so drop the waypoint instead - GetPatrolWaypoint already
                            -- skips one that is walled off, so this cannot park him.
                            local camper = false
                            pcall(function()
                                camper = (self.IsCampActor and self:IsCampActor(k)) and true or false
                            end)
                            local moved = false
                            if camper then
                                pcall(function()
                                    moved = (self.PatrolSkipWaypoint and self:PatrolSkipWaypoint(k)) or false
                                end)
                            end
                            if moved then
                                -- he had a waypoint to give up, so he keeps his collision
                                w.still = 0
                                self.SolidStuckAsk[k] = nil
                                skipped = skipped + 1
                            else
                                -- No route of ours to take away - a camp actor who is not a
                                -- guard owns no waypoint list. Release as before rather than
                                -- invent a new way to park a man against a wall for ever.
                                handBack[#handBack + 1] = c
                                w.free, w.still = (self.SolidFreeTicks or 5), 0
                                freed = freed + 1
                            end
                        end
                    end
                end
            end
        else
            w.still = 0
        end

        w.x, w.y = c.pos.x, c.pos.y
        self.SolidWatch[k] = w
    end

    for k in pairs(self.SolidWatch) do
        if not seen[k] then self.SolidWatch[k] = nil; self.SolidStuckAsk[k] = nil end
    end

    local nBack = self:SolidLatch(handBack, false)
    local nSolid = self:SolidLatch(takeBack, true)
    if nBack > 0 or nSolid > 0 then
        solidSay(string.format("%d handed back, %d taken again", nBack, nSolid))
    end
    if asked > 0 then solidSay(asked .. " leaning on the wall - asked for a reroute") end
    if freed > 0 then solidSay(freed .. " let through: nothing would route them") end
    if skipped > 0 then solidSay(skipped .. " sentry waypoint(s) dropped - walled off, guard moved on") end
    if held > 0 then solidSay(held .. " shoving at the wall in combat - left there") end
    return true
end

function mercenaries:SolidTickDrive()
    local busy = false
    pcall(function() busy = self:SolidSweep() end)
    self:ChainArm("SolidTick", busy and (self.SolidTickMs or 1000) or (self.SolidIdleMs or 4000))
end
mercenaries:ChainDef("SolidTick", "SolidTickDrive")

-- The cvar is global and survives nothing: a level load re-applies that level's own cvar
-- context, and the chain died with the level. Both are re-established here.
function mercenaries:SolidOnLoad()
    self.SolidWatch, self.SolidStuckAsk = {}, {}
    self.SolidArmed = false
    self.SolidShipped = nil        -- re-read: the level just re-applied its own cvar context
    local saved
    pcall(function() saved = tonumber(self:LoadString("MercSolidMode") or "") end)
    if saved and saved >= 0 and saved <= 2 then self.SolidMode = saved end
    solidSay(string.format("%s ships as %s in this level; mode %d",
        self.SolidCvar, tostring(self:SolidShippedValue()), self.SolidMode or 0))
    self:ChainArm("SolidTick", 3000)
end

function mercenaries:SolidSetMode(line)
    local v = tonumber(tostring(line or ""):match("%-?%d+"))
    if not v or v < 0 or v > 2 then
        solidSay("merc_solid <0|1|2>   0 = off, 1 = solid near our walls (default), 2 = solid everywhere near the company")
        return self:SolidStatus()
    end
    self.SolidMode = v
    pcall(function() self:SaveString("MercSolidMode", tostring(v)) end)
    solidSay("mode " .. v .. " (remembered)")
    if v == 0 then pcall(function() self:SolidTeardown("switched off") end) end
    self:SolidTickDrive()
end

function mercenaries:SolidStatus()
    local live
    pcall(function() live = System.GetCVar(self.SolidCvar) end)
    local men, solid, soft, freed, stuck = 0, 0, 0, 0, 0
    for _ in pairs(self.ActiveMercs or {}) do men = men + 1 end
    for _, w in pairs(self.SolidWatch or {}) do
        if w.soft then soft = soft + 1 else solid = solid + 1 end
        if w.free then freed = freed + 1 end
    end
    for _ in pairs(self.SolidStuckAsk or {}) do stuck = stuck + 1 end
    solidSay(string.format("mode %d, armed %s; %s reads %s (ships %s)",
        self.SolidMode or 0, tostring(self.SolidArmed), self.SolidCvar,
        tostring(live), tostring(self:SolidShippedValue())))
    solidSay(string.format("company %d; bookkept %d - solid %d, handed back %d, let through %d",
        men, solid + soft, solid, soft, freed))
    solidSay(string.format("awaiting a reroute: %d   (a fighting man is never let through)", stuck))
end

-- ==== self test ====
-- The risk was never that walls stop working, it is that men stop walking: a solid NPC
-- can catch on clutter he used to pass through. Measure it on the company, who follow the
-- player with no BT interrupt in the way - unlike the wall lab's test NPC, whose walk
-- order silently fails to take often enough to void whole runs.
mercenaries.SolidTestSecs   = 15
mercenaries.SolidTestTickMs = 500

function mercenaries:SolidTestSnapshot(T)
    T.start, T.ents = {}, {}
    for _, ent in pairs(self.ActiveMercs or {}) do
        local k = mercKey(ent)
        local p
        pcall(function() p = ent:GetWorldPos() end)
        if k and p then
            T.start[k] = { x = p.x, y = p.y }
            T.ents[k] = ent
        end
    end
end

function mercenaries:SolidTestMeasure(T)
    local total, n, worst = 0, 0, nil
    for k, p0 in pairs(T.start) do
        local p
        pcall(function() p = T.ents[k]:GetWorldPos() end)
        if p then
            local d = math.sqrt((p.x - p0.x) ^ 2 + (p.y - p0.y) ^ 2)
            total = total + d
            n = n + 1
            if (not worst) or d < worst then worst = d end
        end
    end
    return (n > 0) and (total / n) or 0, n, worst or 0
end

function mercenaries:SolidTestStart()
    if self.SolidTest then solidSay("self test already running"); return end
    local men = 0
    for _ in pairs(self.ActiveMercs or {}) do men = men + 1 end
    if men == 0 then solidSay("no company to measure - hire some men first"); return end
    self.SolidTest = { phase = "control", t = 0, result = {}, wasMode = self.SolidMode }
    self.SolidMode = 0
    pcall(function() self:SolidTeardown("self test control") end)
    self:SolidTestSnapshot(self.SolidTest)
    solidSay(string.format("self test: %d man/men. WALK AROUND for %d seconds - CONTROL, nobody solid",
        men, self.SolidTestSecs))
    self:ChainArm("SolidTest", self.SolidTestTickMs or 500)
end

function mercenaries:SolidTestDrive()
    local T = self.SolidTest
    if not T then return end
    T.t = T.t + (self.SolidTestTickMs or 500) / 1000
    if T.t >= (self.SolidTestSecs or 15) then
        local mean, n, worst = self:SolidTestMeasure(T)
        T.result[T.phase] = mean
        solidSay(string.format("   %-7s %d man/men, %.1fm moved on average, least %.1fm",
            T.phase, n, mean, worst))
        if T.phase == "control" then
            T.phase = "solid"
            T.t = 0
            self.SolidMode = 2
            pcall(function() self:SolidSweep() end)
            self:SolidTestSnapshot(T)
            solidSay("self test: now SOLID - keep walking the same way for " ..
                tostring(self.SolidTestSecs) .. " seconds")
        else
            local c, a = T.result.control or 0, T.result.solid or 0
            solidSay("--- self test ---")
            solidSay(string.format("   control %.1fm   solid %.1fm", c, a))
            if c < 3.0 then
                solidSay("   INCONCLUSIVE: they barely moved in the control either - walk further next time")
            elseif a >= c * 0.6 then
                solidSay("   they walk as well solid as not: this costs the company nothing")
            else
                solidSay("   THEY MOVE LESS WHEN SOLID - they are catching on something; merc_solid 0")
            end
            self.SolidMode = T.wasMode
            self.SolidTest = nil
            self:SolidTickDrive()
            return
        end
    end
    self:ChainArm("SolidTest", self.SolidTestTickMs or 500)
end
mercenaries:ChainDef("SolidTest", "SolidTestDrive")

-- Registered outright rather than behind merc_dev: this is a switch a player may need.
System.AddCCommand("merc_solid", "mercenaries:SolidSetMode('%line')",
    "NPCs collide with walls we spawn: 0 off, 1 only near our walls (default), 2 everywhere near the company")
System.AddCCommand("merc_solid_status", "mercenaries:SolidStatus()",
    "Print the NPC-vs-world collision state")
System.AddCCommand("merc_solid_selftest", "mercenaries:SolidTestStart()",
    "Walk about for 30s: measures how far the company moves with nobody solid, then with everyone solid")
