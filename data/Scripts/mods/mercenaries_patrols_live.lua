-- Roaming patrols.
--
-- One or two gangs per recorded route (long ones carry two), walking it back and forth. They are hostile to the
-- player, to his mercenaries and to the mod's bandit groups, and neutral to everyone else -
-- that is all decided by patrolFaction in FactionTree__mercenaries.xml, not here.
--
-- Only patrols near the player exist as NPCs. Routes are 1-2 km long and there are 26 of
-- them, so spawning every gang would put hundreds of NPCs in the world; instead each patrol
-- keeps a notional POSITION that advances on a timer whether or not it is spawned, and the
-- men are created when the player comes within PatrolSpawnRange and removed when he leaves.
-- A patrol therefore appears roughly where it should be rather than where it was left.
--
-- Movement and formation are the tester's (patrol_scheduler.xml + patrol_follow.xml). The
-- difference is the soul: patrolguard_* carries patrolFaction and a combat-capable brain,
-- while the tester's patrol_* souls sit on testFaction and never find a target.

mercenaries.LivePatrolsEnabled = true
-- A gang materialises only inside the BAND between these two, never on top of the player.
-- See docs/patrols.md, "Never in your lap".
mercenaries.PatrolSpawnRange   = 250.0   -- spawn the gang when the player is this close...
mercenaries.PatrolNoSpawnRange = 200.0   -- ...but never closer than this
mercenaries.PatrolDespawnRange = 330.0   -- ...and take it away again out here (hysteresis)
-- The line nothing may EVER cross, whatever the band above says. The band is tested on the
-- gang's notional point up to a tick (3s) before the men are actually created, and only for
-- the LEAD man - a player riding at the gang closes most of a 50m band in that time, and the
-- rest of the column is laid out BEHIND the lead, which can be his side of it. So the floor
-- is re-tested inside PatrolSpawnGang against a freshly read player position, and again for
-- every man's final ground-snapped spot. See docs/patrols.md, "Never in your lap".
-- 150, not 100: a galloping horse covers ~50m in the 3s between the band test and the men
-- being created, and 100m of open road reads as "that just appeared". See docs/patrols.md.
mercenaries.PatrolMinPlayerDist = 150.0
-- What a player with no mercenaries meets: a handful of men, never a company.
mercenaries.PatrolSoloMinMen   = 3
mercenaries.PatrolSoloMaxMen   = 5
mercenaries.PatrolFreshMinDist = 450.0   -- a newly rolled record starts at least this far off
mercenaries.PatrolFreshTries   = 8       -- ...best of this many random start points
-- Nothing spawns for this long after a load. Loading in is the one moment the player has no
-- bearings and the squad is not there yet - the cache rebuild is 2s behind him and the camp
-- restore 4s, so a gang met in the first seconds is met alone.
mercenaries.PatrolLoadGraceSecs = 45.0
mercenaries.PatrolMinMen       = 3
-- Per-gang ceiling. Was 50: at a 20-merc company the size roll produced ~26-man gangs and
-- several gangs are normally in range together, so the road fielded more men than a siege.
-- A patrol is meant to be an encounter, not a battle; the aggregate caps below are what
-- actually bound the cost, and this stops any single roll from eating the whole budget.
mercenaries.PatrolMaxMen       = 16

-- Ceiling on the TOTAL live patrol population, across every gang at once. Each gang was
-- capped individually but nothing capped the sum, and several routes are usually inside
-- the spawn band together: measured against the recorded Kuttenberg network, a player
-- typically has 3 gang slots in range and up to 9. At a 20-merc squad (gangs of ~26) that
-- is a median of 78 extra full NPCs and a worst case over 200 - each one a behaviour tree,
-- a navigation agent and an assembled character. Gangs still scale with the party; only
-- the total is bounded. merc_patrols 0 turns the whole system off.
mercenaries.PatrolMaxLiveMen   = 36
-- ...and a ceiling on how many GANGS can be live at once, which is the one that bites at a
-- road junction: the recorded networks have positions where 9 (Kuttenberg) and 12 (Trosky)
-- gang slots sit inside the band simultaneously, and every one of them used to spawn.
mercenaries.PatrolMaxLiveGangs = 3
-- Spawning is staggered across ticks. A gang is a burst of SpawnEntity + ground-probe +
-- clothing/weapon equips per man; letting three gangs land on one frame is a visible hitch
-- even when the steady-state population is fine.
mercenaries.PatrolSpawnPerTick = 1

-- Encounter pacing. The caps above bound how many gangs may STAND in the world at once;
-- these bound how OFTEN a new one may appear. Without them a freed gang slot was refilled
-- on the next 3s tick, which at a junction is an endless conveyor. See docs/patrols.md,
-- "Pacing".
mercenaries.PatrolQuietSecs     = 180.0   -- floor on the gap between any two gangs
mercenaries.PatrolPostFightSecs = 480.0   -- ...and the longer silence a wipe buys
-- How many gangs a player who has not travelled PatrolAnchorRadius may meet before the
-- road falls silent until he does. Bounds standing still (a camp); never limits travel.
mercenaries.PatrolAnchorCap    = 2
mercenaries.PatrolAnchorRadius = 500.0
-- No gang spawns this close to the camp: raids are what visits the camp, not the roads.
mercenaries.PatrolCampClearance = 350.0
-- Multiplies both quiet clocks per difficulty tier; >1 is longer silences.
mercenaries.PatrolQuietByTier = {
    easy = 2.0, medium = 1.0, difficult = 0.85,
    extreme = 0.7, impossible = 0.6, horde = 0.35,
}
-- Ground-search budget for the men BEHIND the lead, in CampValidateSpot candidates. The
-- whole gang is placed in one frame, so this is the one number that bounds that frame's
-- raycast cost; see the note at the call site in PatrolSpawnGang. 40 (the FindValidGround
-- default) is for a single placement with a frame to itself, not for sixteen of them.
mercenaries.PatrolGroundTries = 6
-- Total lingering corpses across every wiped gang. Bodies are deliberately lootable for a
-- while, but a hotspot could stack several full gangs of ragdolls with nothing bounding the
-- sum while fresh gangs kept spawning alongside them.
mercenaries.PatrolMaxCorpses   = 12
-- The pile the player just made is exempt from the CAP for this long, so the fight he has
-- only just won is not swept out from under him. Recency, not distance: a "never evict
-- within 60m" rule was tried and is unbounded - standing and fighting in one place
-- accumulates corpses with nothing to stop it. At most a pile or two is ever fresh, and
-- they age out. The walked-away and timeout rules are unaffected either way.
mercenaries.PatrolCorpseGraceSecs = 30.0
-- Seconds after a gang dies before its ragdolls are frozen. Long enough for the bodies to
-- finish falling and settle naturally; after that they are static scenery that still loots.
mercenaries.PatrolCorpseFreezeSecs = 5.0
-- Size as a multiple of the player's fighting strength. The CEILING scales with the party:
-- see PatrolMaxMultFor.
mercenaries.PatrolPartyMin     = 0.5
mercenaries.PatrolPartyMaxSolo = 1.2     -- ceiling at a party of one
mercenaries.PatrolPartyMax     = 2.0     -- ceiling at PatrolPartyMaxAt and above
mercenaries.PatrolPartyMaxAt   = 20
mercenaries.PatrolRespawnDays  = 1.0     -- a wiped patrol is back after this long
mercenaries.PatrolCorpseSecs   = 180.0   -- bodies stay lootable this long if the player stays put
mercenaries.PatrolGhostSpeed   = 1.4     -- m/s the unspawned patrol advances along its route
mercenaries.PatrolLiveTickMs   = 3000
-- How far a patrolman notices a target ON HIS OWN. It was 12, on the principle that a gang
-- walking a road should have to come across you - but 12m is inside the distance you close in
-- a couple of seconds, so they only ever reacted once you were on top of them, and a man
-- hovering at the edge of that range flickered in and out of detection, stopping and
-- restarting the column. The gang alert carries it from there, so this only has to be far
-- enough that the FIRST man reacts while there is still a fight to have.
mercenaries.PatrolDetectRange  = 25.0
mercenaries.PatrolAlertSecs    = 45.0    -- ...once one of them makes contact, the gang joins in for this long
-- Routes at least this long (METRES of road, not points) carry two gangs. It used to be a
-- point count, PatrolTwoAtPoints = 150, which is only a proxy for length while every map is
-- recorded at the same marker spacing - and they are not. The recorder drops a marker every
-- AT LEAST PatrolRouteStep (10 m), so riding faster spaces them further apart: measured,
-- Kuttenberg averages 11.1 m between points and Trosky 15.9 m. The same 150-point bar
-- therefore meant 1665 m on one map and 2385 m on the other. 1650 m is the Kuttenberg
-- equivalent of the old rule, so this is a correctness fix, not a rebalance.
mercenaries.PatrolTwoAtMetres  = 1650
mercenaries.PatrolTwoAtPoints  = 150     -- legacy fallback, used only if a set was not measured
mercenaries.PatrolPairSpacing  = 0.4     -- ...started this far apart along the route (fraction)
-- Route sets, keyed by LEVEL. Each entry lists the level-name substrings that select it and
-- the table holding its routes. The two maps' coordinates OVERLAP, so a merged list would
-- put Trosky's gangs on Kuttenberg roads - the set has to be chosen, not filtered.
-- Add a map by recording routes, dumping them into their own file, and adding a row here.
-- `locations` are RPG location names that exist ONLY on that map. RPG.GetLocations() returns a
-- different list per level (measured: 45 entries on Kuttenberg, 33 on Trosky), which makes it
-- an authoritative level test - unlike road proximity, it does not care where the player is
-- standing. Add more names per map as they are confirmed; any one match is enough.
mercenaries.PatrolRouteSets = {
    { levels = { "kutnohorsko", "kuttenberg" }, key = "PatrolRoutesKuttenberg",
      locations = { "location_pritoky" } },
    { levels = { "trosecko", "trosky" },        key = "PatrolRoutesTrosky",
      locations = { "location_cikanskyTabor" } },
}

-- Kept for anything that still reads the old name; PatrolRouteData is now whatever set the
-- current level selected (see PatrolRoutesForLevel).
mercenaries.PatrolLevels = { "kutnohorsko", "kuttenberg", "trosecko", "trosky" }

-- Which gangs walk the roads. Weighted by how ordinary they should feel.
-- Only groups that have their own souls above; adding one here without souls to
-- match would silently fall back to the wrong name.
mercenaries.PatrolGroupPool = { "bandit", "bandit", "looter", "looter", "sigi", "prague" }

mercenaries.LivePatrols = {}   -- ["route:slot"] = { see PatrolMakeRecord }

-- Session route escalation: a road the player has just cleared sends a slightly tougher
-- reprisal later in the same session. Session-only, plain Lua state, NOT SaveString - same
-- non-persistence as LivePatrols itself (see the note near ClearAnyLeftoverPatrols). Applied
-- to the size roll BEFORE the difficulty tier (PatrolRollSize), so DifficultyCount/
-- DifficultyCeil still have the final say on the ceiling.
mercenaries.PatrolEscalationCap      = 0.35   -- hard ceiling on the size bonus, ever (+35%)
mercenaries.PatrolEscalationPerKill  = 0.05   -- size bonus per patrolman killed on that route
mercenaries.PatrolEscalationHalfLife = 900.0  -- seconds for a route's heat to decay by half
mercenaries.PatrolRouteHeat = {}   -- [route] = { kills = <decayed float>, at = <last touched> }

-- Measure a route set once, when it goes live: each route's length in metres and its OWN
-- mean marker spacing. Both are read back per tick, and neither can be assumed from the
-- point count - the recorder's 10 m step is a minimum, not a guarantee (see PatrolTwoAtMetres).
-- Idempotent and cheap: a few thousand points, only on a set switch.
function mercenaries:PatrolMeasureRoutes(data)
    for _, r in ipairs(data or {}) do
        if not r.len then
            local L, n = 0, 0
            local pts = r.pts or {}
            for i = 1, #pts - 1 do
                local a, b = pts[i], pts[i + 1]
                L = L + math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
                n = n + 1
            end
            r.len   = L
            r.stepM = (n > 0) and (L / n) or 10.0
        end
    end
    local total = 0
    for _, r in ipairs(data or {}) do total = total + (r.len or 0) end
    return total
end

-- How many gangs walk this route. A 2km road with one patrol on it feels empty, and the
-- two start half a route apart so they are not shadowing each other - so the test is the
-- road's LENGTH, which is what that sentence is about. Falls back to the old point count
-- for any set that was never measured.
function mercenaries:PatrolCountFor(i)
    local r = self.PatrolRouteData and self.PatrolRouteData[i]
    if not r then return 0 end
    if r.len then return (r.len >= self.PatrolTwoAtMetres) and 2 or 1 end
    return (#r.pts >= self.PatrolTwoAtPoints) and 2 or 1
end

local function lLog(s) System.LogAlways("[Patrols] " .. s) end
local function lKey(ent) return ent and tostring((ent.this and ent.this.id) or ent.id) or nil end
local function nowT() local t = 0; pcall(function() t = System.GetCurrTime() or 0 end); return t end
-- Kuttenberg is its own LEVEL, not an area of one, so this is a level test rather than a
-- coordinate box - Trosky's coordinates overlap Kuttenberg's and a box would fire there.
--
-- No level API is exposed to Lua, so this is best-effort, exactly as mercenaries_ambush.lua
-- does it. "unknown" is treated as "allow": better a patrol on the wrong map than none on
-- the right one, and the routes still have to be within PatrolSpawnRange to appear at all.
local function levelName()
    for _, get in ipairs({
        function() return System.GetCurrLevelName() end,
        function() return Game.GetLevelName() end,
        function() return System.GetCurrAsyncLevelName() end,
    }) do
        local ok, v = pcall(get)
        if ok and v and v ~= "" then return tostring(v) end
    end
    return "unknown"
end

-- Which recorded road network is the player actually standing in? Used when the level name is
-- unavailable, which in practice is always.
--
-- Throttled and short-circuited: while the live set still has road within reach there is
-- nothing to decide, so the full scan only runs when the current choice looks wrong (or when
-- there is no choice yet). That keeps a ~5000-point sweep off the 3s tick.
mercenaries.PatrolSetProbeSecs = 5.0
mercenaries.PatrolSetNearEnough = 400.0   -- road this close means we are on that map
mercenaries.PatrolSetSwitchMargin = 300.0 -- ...and a rival must beat it by this much to take over

-- The names of the RPG locations on the CURRENT level. The Location objects do not expose a
-- name field, but their tostring is "Location[name=location_pritoky]", so the name is parsed
-- out of that. Cached briefly: the list only changes on a level load, and this is called from
-- a 3s tick.
mercenaries.PatrolLocProbeSecs = 10.0

function mercenaries:PatrolLevelLocations()
    local now = nowT()
    if self._locNames and self._locAt and (now - self._locAt) < self.PatrolLocProbeSecs then
        return self._locNames
    end

    local names = nil
    pcall(function()
        local locs = RPG.GetLocations()
        if type(locs) ~= "table" then return end
        names = {}
        for _, v in pairs(locs) do
            local n = tostring(v):match("name=([%w_]+)")
            if n then names[n] = true end
        end
    end)

    self._locNames, self._locAt = names, now
    return names
end

-- Which route set does this level's location list identify? nil if it cannot tell.
function mercenaries:PatrolLocationRouteSet()
    local names = self:PatrolLevelLocations()
    if not names then return nil end
    for _, set in ipairs(self.PatrolRouteSets or {}) do
        for _, want in ipairs(set.locations or {}) do
            if names[want] then return set end
        end
    end
    return nil
end

function mercenaries:PatrolNearestRouteSet()
    local pp
    pcall(function() pp = player and player:GetWorldPos() end)
    if not pp then return nil end

    local now = nowT()
    if self._setProbeAt and (now - self._setProbeAt) < self.PatrolSetProbeSecs then
        return self._setProbeChoice
    end
    self._setProbeAt = now

    local function nearest(data)
        local best = nil
        for _, r in ipairs(data or {}) do
            for _, p in ipairs(r.pts or {}) do
                local dx, dy = p.x - pp.x, p.y - pp.y
                local d2 = dx * dx + dy * dy
                if not best or d2 < best then best = d2 end
            end
        end
        return best and math.sqrt(best) or nil
    end

    -- Still near the live set's roads: nothing has changed, do not rescan.
    if self._patrolRouteKey then
        local cur = nearest(self[self._patrolRouteKey])
        if cur and cur <= self.PatrolSetNearEnough then
            self._setProbeChoice = nil
            for _, s in ipairs(self.PatrolRouteSets or {}) do
                if s.key == self._patrolRouteKey then self._setProbeChoice = s end
            end
            return self._setProbeChoice
        end
    end

    local bestSet, bestD = nil, nil
    for _, set in ipairs(self.PatrolRouteSets or {}) do
        local d = nearest(self[set.key])
        if d and (not bestD or d < bestD) then bestSet, bestD = set, d end
    end

    -- Switching sets wipes every live patrol, so an incumbent is not given up lightly: the
    -- challenger has to be clearly closer, not merely closer. Without this, wandering well
    -- off-road on the right map could hand over to the other map's network on a tie.
    if bestSet and self._patrolRouteKey and bestSet.key ~= self._patrolRouteKey then
        local cur = nearest(self[self._patrolRouteKey])
        if cur and (cur - bestD) < self.PatrolSetSwitchMargin then
            for _, s in ipairs(self.PatrolRouteSets or {}) do
                if s.key == self._patrolRouteKey then bestSet, bestD = s, cur end
            end
        end
    end

    self._setProbeChoice = bestSet
    if bestSet then
        lLog(string.format("no level name; nearest recorded road is %s at %.0fm - using it",
                           bestSet.key, bestD or -1))
    end
    return bestSet
end

-- Pick the route set for the level we are on, and make it live. Returns false when this map
-- has no routes at all, which is the "do nothing here" answer.
--
-- Switching sets CLEARS LivePatrols: records are keyed "route:slot" and a route index means a
-- different road on each map, so carrying them across a level change would march Trosky's
-- gangs along Kuttenberg indices.
function mercenaries:PatrolRoutesForLevel()
    local n = string.lower(levelName())

    local chosen = nil
    for _, set in ipairs(self.PatrolRouteSets or {}) do
        for _, want in ipairs(set.levels) do
            if string.find(n, want, 1, true) then chosen = set break end
        end
        if chosen then break end
    end

    -- The level NAME is always "unknown": every candidate API errors (confirmed in game), and
    -- CurrentLevelIsTrosecko is a Skald node, not a Lua binding. The ladder stays only in case
    -- a working API ever appears.
    --
    -- Second: the RPG LOCATION LIST. RPG.GetLocations() returns a different list per level, so
    -- the presence of a map-exclusive location name identifies the map outright - and unlike
    -- proximity it does not care where the player is standing, which matters in wilderness far
    -- from any recorded road.
    if not chosen then
        chosen = self:PatrolLocationRouteSet()
        if chosen and self._patrolRouteKey ~= chosen.key then
            lLog("level identified by RPG locations -> " .. chosen.key)
        end
    end

    -- Last: ask the ROUTES where we are. Self-validating in the way that matters, since
    -- patrols only ever spawn within PatrolSpawnRange of the player - the set worth using is
    -- the one with road near him. Bounding boxes overlap between maps, whole road networks do
    -- not. Measured 4m vs 266m on Trosky, 52m vs 1322m on Kuttenberg: decisive either way.
    if not chosen then chosen = self:PatrolNearestRouteSet() end
    if not chosen then return false end

    local data = self[chosen.key]
    if not (data and #data > 0) then return false end

    if self._patrolRouteKey ~= chosen.key then
        if self._patrolRouteKey then
            for _, rec in pairs(self.LivePatrols or {}) do
                if rec.spawned then self:PatrolDespawnGang(rec, "level changed") else self:PatrolClearCorpses(rec) end
            end
            self.LivePatrols = {}
            -- Route index means a different road on each map, same as LivePatrols above -
            -- carrying heat across would escalate the wrong road on the new map.
            self.PatrolRouteHeat = {}
        end
        self._patrolRouteKey = chosen.key
        self.PatrolRouteData = data
        local km = self:PatrolMeasureRoutes(data) / 1000.0
        local slots = 0
        for i = 1, #data do slots = slots + self:PatrolCountFor(i) end
        lLog(string.format("route set = %s (%d routes, %.1f km of road, %d gang slots) for level '%s'",
                           chosen.key, #data, km, slots, n))
    end
    return true
end

function mercenaries:PatrolLevelAllowed()
    return self:PatrolRoutesForLevel()
end

-- merc_level_probe: dump what every candidate level API actually returns, plus how far the
-- player is from each recorded road network. The name ladder returns nothing on either map,
-- so the route sets are selected by proximity instead; if a working API ever turns up here,
-- add it to levelName() and the guessing stops.
function mercenaries:PatrolLevelProbe()
    -- Resolve the set as part of probing, so the answer is never "nil" merely because the
    -- 3s tick has not come round yet - and so running the probe is itself a repair.
    pcall(function() self:PatrolRoutesForLevel() end)

    -- Declared up here so everything below can use it; a `local` used above its declaration
    -- silently reads a nil global instead (the exact trap that made route-set selection fail).
    local pp; pcall(function() pp = player and player:GetWorldPos() end)

    local cands = {
        { "System.GetCurrLevelName",      function() return System.GetCurrLevelName() end },
        { "Game.GetLevelName",            function() return Game.GetLevelName() end },
        { "System.GetCurrAsyncLevelName", function() return System.GetCurrAsyncLevelName() end },
        { "System.GetLevelPath",          function() return System.GetLevelPath() end },
        { "Game.GetLevelPath",            function() return Game.GetLevelPath() end },
        { "System.GetCurrentLevelName",   function() return System.GetCurrentLevelName() end },
        { "Level.GetName",                function() return Level.GetName() end },
    }
    for _, c in ipairs(cands) do
        local ok, v = pcall(c[2])
        lLog(string.format("  %-30s ok=%s value=%s", c[1], tostring(ok), tostring(v)))
    end

    -- RPG LOCATIONS - the promising lead.
    --
    -- The engine binds C_ScriptBindRPGModule onto the Lua global `RPG` (confirmed by vanilla
    -- usage: RPG.GetFactions, RPG.AddLocationPoint...) and GetLocations() returns a different
    -- list per level, which is what level detection now keys off.
    --
    -- LocationPoint ENTITIES were tried first and are a dead end - 2 on Trosky with guid=nil,
    -- 0 on Kuttenberg. The location LIST is the thing that works.
    local ok, fns = pcall(function()
        local names = {}
        for k, v in pairs(RPG or {}) do
            if type(v) == "function" then names[#names + 1] = k end
        end
        table.sort(names)
        return table.concat(names, ", ")
    end)
    lLog("  _G.RPG functions: " .. (ok and tostring(fns) or "unavailable"))

    -- Full name list, so map-exclusive names can be added to PatrolRouteSets[].locations.
    local names = self:PatrolLevelLocations()
    if names then
        local sorted = {}
        for n in pairs(names) do sorted[#sorted + 1] = n end
        table.sort(sorted)
        lLog("  RPG locations on this level: " .. #sorted)
        -- Chunked: one line per 6 names keeps them readable in the log.
        local line = {}
        for i, n in ipairs(sorted) do
            line[#line + 1] = n
            if #line == 6 or i == #sorted then
                lLog("    " .. table.concat(line, ", "))
                line = {}
            end
        end
        local hit = self:PatrolLocationRouteSet()
        lLog("  location signature matches: " .. (hit and hit.key or "NONE - add a name to PatrolRouteSets"))
    else
        lLog("  RPG.GetLocations unavailable")
    end

    if pp then
        for _, set in ipairs(self.PatrolRouteSets or {}) do
            local best = nil
            for _, r in ipairs(self[set.key] or {}) do
                for _, p in ipairs(r.pts or {}) do
                    local dx, dy = p.x - pp.x, p.y - pp.y
                    local d2 = dx * dx + dy * dy
                    if not best or d2 < best then best = d2 end
                end
            end
            lLog(string.format("  nearest road in %-24s %s m",
                set.key, best and string.format("%.0f", math.sqrt(best)) or "n/a"))
        end
    end
    lLog("live set = " .. tostring(self._patrolRouteKey))
end

mercenaries:DevCommand("merc_level_probe", "mercenaries:PatrolLevelProbe()",
                   "Dump every level-name API's return plus distance to each recorded road network")

-- ==== session escalation ====
-- Settle a route's heat to the current time (exponential decay by half-life) and return
-- the settled kill count. Also writes the settled value back, so two reads in the same
-- tick do not each re-derive from the same stale base.
function mercenaries:PatrolHeatDecay(route)
    local h = self.PatrolRouteHeat[route]
    if not h then return 0 end
    local now = nowT()
    local dt = now - (h.at or now)
    if dt > 0 and (self.PatrolEscalationHalfLife or 0) > 0 then
        h.kills = h.kills * (0.5 ^ (dt / self.PatrolEscalationHalfLife))
    end
    h.at = now
    -- Below this, the multiplier it would produce rounds away to nothing anyway -
    -- drop the entry instead of carrying a shrinking float forever.
    if h.kills < 0.01 then
        self.PatrolRouteHeat[route] = nil
        return 0
    end
    return h.kills
end

-- A kill just happened near this route's notional position.
function mercenaries:PatrolHeatAdd(route, n)
    if not (route and n and n > 0) then return end
    self:PatrolHeatDecay(route)   -- settle whatever heat is already there before adding
    local h = self.PatrolRouteHeat[route]
    if not h then h = { kills = 0, at = nowT() }; self.PatrolRouteHeat[route] = h end
    h.kills = h.kills + n
    h.at = nowT()
end

-- The size multiplier this route's recent kills earn. Capped well short of the difficulty
-- tier's own range - this is flavour on a route the player just fought, not a substitute
-- for the difficulty setting.
function mercenaries:PatrolEscalationMultFor(route)
    if not route then return 1.0 end
    local kills = self:PatrolHeatDecay(route)
    return 1.0 + math.min(self.PatrolEscalationCap or 0, kills * (self.PatrolEscalationPerKill or 0))
end

function mercenaries:PatrolEscalationStatus()
    local any = false
    for route, _ in pairs(self.PatrolRouteHeat or {}) do
        local kills = self:PatrolHeatDecay(route)
        if kills > 0.01 then
            any = true
            lLog(string.format("  route %s: heat %.2f kill(s) -> size x%.2f",
                tostring(route), kills, self:PatrolEscalationMultFor(route)))
        end
    end
    if not any then lLog("  no route is currently escalated") end
end

-- ==== sizing ====
-- A multiple of the player's fighting strength - himself plus his living mercs.
function mercenaries:PatrolPartySize()
    local n = 1
    pcall(function() n = 1 + (self:LogiAliveCount() or 0) end)
    return math.max(1, n)
end

-- True with zero living mercenaries. This used to withhold roaming patrols entirely, which
-- emptied the roads for exactly the player who is out there alone. It now sizes them
-- instead: a solo player meets PatrolSoloMinMen..PatrolSoloMaxMen men (see PatrolRollSize),
-- which is an encounter he can fight or run from rather than a company that ends him.
function mercenaries:PatrolPlayerAlone()
    local n = 0
    pcall(function() n = self:LogiAliveCount() or 0 end)
    return n <= 0
end

-- How far a gang is allowed to OUTNUMBER the party, scaled by how big the party is. A flat
-- 3x ceiling with a floor of five men meant a lone rider always met five and a party of four
-- met up to twelve - a mugging, not an encounter, and the case the player is in most often.
-- A big company can afford the full multiple; a small one cannot. Ramped, not stepped, so
-- there is no size at which hiring one more merc doubles what walks down the road.
function mercenaries:PatrolMaxMultFor(party)
    local at = math.max(2, self.PatrolPartyMaxAt)
    local t  = (math.max(1, party) - 1) / (at - 1)
    if t > 1 then t = 1 end
    return self.PatrolPartyMaxSolo + t * (self.PatrolPartyMax - self.PatrolPartyMaxSolo)
end

-- route is optional (nil for anything rolling a size outside a route context, e.g. the
-- status line) - PatrolMakeRecord/PatrolRollIdentity pass rec.route so a road just
-- cleared can send a tougher reprisal.
function mercenaries:PatrolRollSize(route)
    local party = self:PatrolPartySize()
    local hi    = self:PatrolMaxMultFor(party)
    local mult  = self.PatrolPartyMin + math.random() * math.max(0, hi - self.PatrolPartyMin)
    local n     = math.floor(party * mult + 0.5)
    -- Session escalation BEFORE difficulty, so the difficulty tier's own ceiling still
    -- has the final say over how far a hot route can push a gang.
    if route then n = math.floor(n * self:PatrolEscalationMultFor(route) + 0.5) end
    -- The difficulty tier rides on top of the roll rather than replacing it, so a
    -- gang is still sometimes small on a hard setting and sometimes big on an easy one.
    pcall(function() n = self:DifficultyCount(n, party, self.PatrolMinMen) end)
    if n < self.PatrolMinMen then n = self.PatrolMinMen end
    local ceil_ = self.PatrolMaxMen
    pcall(function() ceil_ = self:DifficultyCeil(self.PatrolMaxMen) end)
    if n > ceil_ then n = ceil_ end
    -- LAST, so neither the difficulty tier nor a hot route's escalation can push a gang
    -- past what a man with nobody behind him is meant to meet.
    if self:PatrolPlayerAlone() then
        local lo = self.PatrolSoloMinMen or 3
        local hi = math.max(lo, self.PatrolSoloMaxMen or 5)
        if n < lo then n = lo end
        if n > hi then n = hi end
    end
    return n
end

-- Strength varies per patrol: which tier (combat_level 0.4 .. 1.0) the whole gang uses.
-- The soul must come from the gang's OWN group, or his name will not match his kit.
function mercenaries:PatrolRollSoul(group)
    local set = self.PatrolGuardSouls[group] or self.PatrolGuardSouls.bandit
    return set[math.random(1, #set)]
end

-- Souls per GROUP per strength tier. The soul carries the skald character, which is what
-- the game calls him on screen - one shared set of looter souls made every patrol read as
-- "looter" no matter whose colours EquipEnemy dressed him in.
mercenaries.PatrolGuardSouls = {
    looter = {
        "f1e2d3c4-0020-4a00-8b00-000000000021",   -- combat_level 0.4
        "f1e2d3c4-0020-4a00-8b00-000000000022",   -- combat_level 0.7
        "f1e2d3c4-0020-4a00-8b00-000000000023",   -- combat_level 0.9
        "f1e2d3c4-0020-4a00-8b00-000000000024",   -- combat_level 1.0
    },
    bandit = {
        "f1e2d3c4-0020-4a00-8b00-000000000025",   -- combat_level 0.4
        "f1e2d3c4-0020-4a00-8b00-000000000026",   -- combat_level 0.7
        "f1e2d3c4-0020-4a00-8b00-000000000027",   -- combat_level 0.9
        "f1e2d3c4-0020-4a00-8b00-000000000028",   -- combat_level 1.0
    },
    sigi = {
        "f1e2d3c4-0020-4a00-8b00-000000000029",   -- combat_level 0.4
        "f1e2d3c4-0020-4a00-8b00-00000000002a",   -- combat_level 0.7
        "f1e2d3c4-0020-4a00-8b00-00000000002b",   -- combat_level 0.9
        "f1e2d3c4-0020-4a00-8b00-00000000002c",   -- combat_level 1.0
    },
    prague = {
        "f1e2d3c4-0020-4a00-8b00-00000000002d",   -- combat_level 0.4
        "f1e2d3c4-0020-4a00-8b00-00000000002e",   -- combat_level 0.7
        "f1e2d3c4-0020-4a00-8b00-00000000002f",   -- combat_level 0.9
        "f1e2d3c4-0020-4a00-8b00-000000000030",   -- combat_level 1.0
    },
}

-- ==== records ====
function mercenaries:PatrolMakeRecord(i, slot)
    local route = self.PatrolRouteData and self.PatrolRouteData[i]
    if not route then return nil end
    slot = slot or 1

    -- the second gang starts well down the route from the first
    local function roll()
        local s = math.random(1, #route.pts)
        if slot > 1 then
            s = 1 + ((s - 1 + math.floor(#route.pts * self.PatrolPairSpacing)) % #route.pts)
        end
        return s
    end

    -- Start well away from the player. Every record is rolled fresh on a load, so without this
    -- a road the player saved on hands him a gang at point-blank range. Measured on the point
    -- the slot offset actually lands on; best of a few tries, so a short route still yields the
    -- farthest point it has instead of looping.
    local start, bestD = roll(), nil
    local pp; pcall(function() pp = player and player:GetWorldPos() end)
    if pp then
        for _ = 1, self.PatrolFreshTries do
            local s = roll()
            local q = route.pts[s]
            local d = q and math.sqrt((q.x - pp.x) ^ 2 + (q.y - pp.y) ^ 2) or 0
            if not bestD or d > bestD then start, bestD = s, d end
            if bestD >= self.PatrolFreshMinDist then break end
        end
    end
    -- An unspawned patrol knows only WHERE it is. Group, strength and size are rolled at
    -- spawn time (PatrolRollIdentity), so a patrol the player has never met scales with the
    -- party he has NOW - hire five mercs and the gangs you meet next are sized for five.
    -- A gang that is already standing keeps what it was given; it does not grow around him.
    return {
        route   = i,
        slot    = slot,
        key     = i .. ":" .. slot,
        idx     = start,
        dir     = (math.random(2) == 1) and 1 or -1,
        group   = nil,         -- rolled on spawn
        soul    = nil,
        size    = nil,
        men     = {},          -- spawned entities, leader first
        spawned = false,
        deadAt  = nil,         -- set when wiped; respawns PatrolRespawnDays later
        moveAt  = nowT(),
    }
end

function mercenaries:PatrolRouteOf(rec)
    return self.PatrolRouteData and self.PatrolRouteData[rec.route]
end

function mercenaries:PatrolPointOf(rec)
    local r = self:PatrolRouteOf(rec)
    return r and r.pts[rec.idx]
end

-- Back and forth, not round and round: reverse at each end.
function mercenaries:PatrolAdvance(rec, steps)
    local r = self:PatrolRouteOf(rec)
    if not r then return end
    for _ = 1, math.max(1, steps or 1) do
        local nxt = rec.idx + rec.dir
        if nxt < 1 or nxt > #r.pts then
            rec.dir = -rec.dir
            nxt = rec.idx + rec.dir
            if nxt < 1 or nxt > #r.pts then nxt = rec.idx end
        end
        rec.idx = nxt
    end
end

-- Heading of the route at the gang's current point, in the direction it is travelling.
-- Looks a few points ahead rather than at the very next one: the recorder drops a marker
-- every ~10m but they are player-walked, so consecutive points can be almost coincident or
-- jitter sideways, and a one-point heading would sometimes aim the column off the road
-- anyway. Falls back to the point behind, then to a random bearing if the route is unusable.
mercenaries.PatrolHeadingLook = 3   -- points to look ahead when taking the heading

function mercenaries:PatrolHeading(rec)
    local r = self:PatrolRouteOf(rec)
    local a = r and r.pts[rec.idx]
    if not (r and a) then return math.random() * 2 * math.pi end

    local dir  = (rec.dir ~= nil and rec.dir ~= 0) and rec.dir or 1
    local look = math.max(1, self.PatrolHeadingLook)

    for step = look, 1, -1 do
        -- Ahead first: heading is current -> ahead.
        local b = r.pts[rec.idx + dir * step]
        if b then
            local dx, dy = b.x - a.x, b.y - a.y
            if (dx * dx + dy * dy) > 1.0 then return math.atan2(dy, dx) end
        end
        -- Else behind: same line, so take behind -> current to keep the sense of travel.
        local c = r.pts[rec.idx - dir * step]
        if c then
            local dx, dy = a.x - c.x, a.y - c.y
            if (dx * dx + dy * dy) > 1.0 then return math.atan2(dy, dx) end
        end
    end
    return math.random() * 2 * math.pi
end

-- ==== spawning ====
-- Decide who this gang is, at the moment it becomes real.
-- Set by the merc_patrol_<group> commands for the length of one spawn, so a player can
-- call for a specific gang instead of taking whatever the pool rolls.
mercenaries.PatrolForceGroup = nil

function mercenaries:PatrolRollIdentity(rec)
    rec.group = self.PatrolForceGroup or self.PatrolGroupPool[math.random(1, #self.PatrolGroupPool)]
    rec.soul  = self:PatrolRollSoul(rec.group)
    rec.size  = self:PatrolBudgetFor(self:PatrolRollSize(rec.route))
end

-- How far from the player a single spot is, or nil when there is no player to measure
-- against (in which case nothing is refused - see PatrolSpotClear).
function mercenaries:PatrolPlayerDist(q)
    if not (q and player) then return nil end
    local pp
    pcall(function() pp = player:GetWorldPos() end)
    if not pp then return nil end
    local dx, dy = q.x - pp.x, q.y - pp.y
    return math.sqrt(dx * dx + dy * dy)
end

-- Is this spot outside the hard floor? Reads the player's position NOW rather than
-- trusting the one the tick sampled before it sorted its candidates.
function mercenaries:PatrolSpotClear(q, floor)
    local d = self:PatrolPlayerDist(q)
    if not d then return true end
    return d >= (floor or self.PatrolMinPlayerDist or 0)
end

-- `force` is the console's own door (merc_patrols_here, merc_patrol_<group>), which exists
-- precisely to put a gang on top of you. Nothing in the tick passes it.
function mercenaries:PatrolSpawnGang(rec, force)
    local p = self:PatrolPointOf(rec)
    if not p then return false end
    -- The band test in PatrolTickOne ran up to a tick ago, on the point rather than on the
    -- men. Re-test here, or a player who rode 40m at the gang in those 3s gets it in his lap.
    if not force and not self:PatrolSpotClear(p) then
        return false
    end
    -- The ghost still creeps through the camp; it just never becomes men inside it.
    if not force and self:PatrolNearCamp(p) then
        return false
    end
    self:PatrolRollIdentity(rec)
    -- The roll is clamped to whatever budget is left, which can be nothing if another gang
    -- took it since this record was picked. A one- or two-man "gang" is worse than none, so
    -- the record simply stays notional and is reconsidered next tick.
    if (rec.size or 0) < (self.PatrolMinMen or 3) then
        rec.size = nil
        return false
    end

    -- Face along the ROUTE, in the direction of travel. This used to be
    -- `math.random() * 2 * math.pi` - a random bearing - so the column was laid out across
    -- the road as often as along it and most of the gang spawned in the trees. The men are
    -- placed BEHIND the lead man (back) and abreast of him (lat), so the bearing has to be
    -- the heading he is about to walk, not an arbitrary one.
    local yaw = self:PatrolHeading(rec)
    local fx, fy = math.cos(yaw), math.sin(yaw)
    local rx, ry = -fy, fx

    rec.men = {}
    local function one(pos, isLead)
        local name = "SpawnedPatrolman_" .. tostring(math.random(10000, 99999)) .. "_" .. rec.soul
        local e
        local ok, err = pcall(function()
            System.SpawnEntity({
                class = "NPC", name = name, position = pos,
                -- orientation is a DIRECTION VECTOR, not Euler angles. It was
                -- { 0, 0, yaw }, which points straight up and gave every gang a default
                -- facing regardless of the road. Hand it the heading as a vector so they
                -- actually face the way they are about to walk.
                orientation = { x = fx, y = fy, z = 0 },
                properties = { guidSharedSoulId = rec.soul },
            })
            e = System.GetEntityByName(name)
            if e and self.EquipEnemy then self:EquipEnemy(e, rec.group, false) end
        end)
        if not ok then lLog("spawn error: " .. tostring(err)) end
        return e
    end

    local lead = { x = p.x, y = p.y, z = p.z }
    if self.FindValidGround then lead = self:FindValidGround(lead, p.z) end
    -- FindValidGround may have walked the lead a few metres off the route point the test
    -- above cleared, so the man who is actually about to exist is tested too.
    if not force and not self:PatrolSpotClear(lead) then
        rec.size = nil
        return false
    end
    local L = one(lead, true)
    if not L then return false end
    table.insert(rec.men, L)

    -- The column is laid out BEHIND the lead, which is his side of it as often as not, so
    -- every man is measured in his own right. A man inside the floor is simply left out:
    -- the gang is one shorter, which nobody can see, where a man materialising at the
    -- player's shoulder is the whole complaint.
    local dropped = 0
    for i = 1, rec.size - 1 do
        local back, lat = self:PatrolSlot(i, rec.size - 1)
        local q = { x = lead.x - fx * back + rx * lat, y = lead.y - fy * back + ry * lat, z = lead.z }
        -- Budgeted, unlike the lead man's search above. A gang is spawned ENTIRELY within one
        -- tick, so the raycasts of every follower land in a single frame: at the default
        -- maxTries of 40 (up to 9 rays each via CampValidateSpot) a 16-man gang could ask for
        -- thousands of synchronous rays before the frame ended, which is the hitch behind
        -- "enemies appeared right in front of me while I was riding". These men are being
        -- placed a couple of metres behind a lead whose ground is already validated, so the
        -- hopeless case is not worth 40 tries - and exhausting the budget falls through to
        -- the same plain ground snap an exhausted spiral did, with PatrolSpotClear below
        -- still deciding whether the man exists at all. See docs/performance.md.
        if self.FindValidGround then
            q = self:FindValidGround(q, lead.z, nil, nil, self.PatrolGroundTries)
        end
        if force or self:PatrolSpotClear(q) then
            local e = one(q, false)
            if e then table.insert(rec.men, e) end
        else
            dropped = dropped + 1
        end
    end
    if dropped > 0 then
        lLog(string.format("route %d: %d man/men left out - inside the %.0fm floor",
            rec.route, dropped, self.PatrolMinPlayerDist or 0))
    end

    self:PatrolIndexGang(rec)
    rec.spawned = true
    -- Baseline for the kill-escalation diff in PatrolTickOne - it only knows a man died
    -- by the living headcount dropping since the last tick it looked.
    rec.lastAlive = #rec.men
    lLog(string.format("route %d: %d %s spawned at point %d/%d",
        rec.route, #rec.men, rec.group, rec.idx, #self:PatrolRouteOf(rec).pts))
    return true
end

function mercenaries:PatrolDespawnGang(rec, why)
    for _, e in ipairs(rec.men or {}) do
        pcall(function() System.RemoveEntity(e.id) end)
    end
    rec.men = {}
    self:PatrolIndexClear(rec)
    rec.spawned = false
    self:PatrolClearCorpses(rec)
    if why then lLog("route " .. rec.route .. ": despawned (" .. why .. ")") end
end

-- Bodies left standing after a wipe. They are NOT removed with the record: killing
-- the last man used to delete the whole gang inside one 3s tick, corpses included,
-- so a patrol you had just fought could not be looted at all. They are cleared once
-- the player has left the area, or after PatrolCorpseSecs if he stays.
function mercenaries:PatrolClearCorpses(rec)
    for _, e in ipairs((rec and rec.corpses) or {}) do
        pcall(function() System.RemoveEntity(e.id) end)
    end
    if rec then rec.corpses = nil; rec.corpsesAt = nil end
end

-- Every living patrolman currently in the world, across all gangs.
function mercenaries:PatrolLiveMenCount()
    local n = 0
    for _, rec in pairs(self.LivePatrols or {}) do
        if rec.spawned then n = n + self:PatrolAliveCount(rec) end
    end
    return n
end

-- Counts rec.spawned, NOT living men. A wiped gang releasing its slot the instant its last
-- man dies lets a replacement spawn alongside the corpse pile, so the world briefly holds
-- both - which is more entities at once, not fewer. The slot frees on the next tick anyway.
-- It also keeps this off IsAliveAndWell, since PatrolBudgetFor calls it per candidate.
function mercenaries:PatrolLiveGangCount()
    local n = 0
    for _, rec in pairs(self.LivePatrols or {}) do
        if rec.spawned then n = n + 1 end
    end
    return n
end

function mercenaries:PatrolCorpseCount()
    local n = 0
    for _, rec in pairs(self.LivePatrols or {}) do
        n = n + #(rec.corpses or {})
    end
    return n
end

-- The difficulty tier's effect on how OFTEN, as opposed to how many.
function mercenaries:PatrolQuietMult()
    local tier = "medium"
    pcall(function() tier = self:DifficultyLoad() or "medium" end)
    return (self.PatrolQuietByTier or {})[tier] or 1.0
end

-- Push the "no gang before" clock out. Only ever moves it forward, so a plain spawn cannot
-- shorten the longer silence a wipe has already paid for.
function mercenaries:PatrolQuietFor(secs, why)
    local until_ = nowT() + (secs or 0) * self:PatrolQuietMult()
    if until_ <= (self._patrolQuietUntil or 0) then return end
    self._patrolQuietUntil = until_
    if why then
        lLog(string.format("the roads are quiet for %.0fs (%s)", until_ - nowT(), why))
    end
end

function mercenaries:PatrolQuietLeft()
    local until_ = self._patrolQuietUntil
    if not until_ then return nil end
    local now  = nowT()
    local left = until_ - now
    if left <= 0 then return nil end
    -- Longer than any silence that could have been bought means the clock moved.
    local most = math.max(self.PatrolQuietSecs or 0, self.PatrolPostFightSecs or 0)
                 * math.max(1, self:PatrolQuietMult())
    if left > most then self._patrolQuietUntil = nil; return nil end
    return left
end

-- The standing-player anchor, re-seated once the player has travelled PatrolAnchorRadius
-- from where it was last set. Moving through the world clears the count constantly.
function mercenaries:PatrolAnchorTouch(pp)
    local a = self._patrolAnchor
    if not a then
        self._patrolAnchor = { x = pp.x, y = pp.y, n = 0 }
        return self._patrolAnchor
    end
    local dx, dy = pp.x - a.x, pp.y - a.y
    if (dx * dx + dy * dy) >= (self.PatrolAnchorRadius or 500.0) ^ 2 then
        a.x, a.y, a.n = pp.x, pp.y, 0
    end
    return a
end

-- Is the camp close enough to this spot that a gang appearing here would walk into it?
function mercenaries:PatrolNearCamp(q)
    if not (self.CampActive and self.CampCenter and q) then return false end
    local r = self.PatrolCampClearance or 0
    if r <= 0 then return false end
    local dx, dy = q.x - self.CampCenter.x, q.y - self.CampCenter.y
    return (dx * dx + dy * dy) < (r * r)
end

-- May ANY gang be created right now? PatrolBudgetFor asks whether there is ROOM for one;
-- this asks whether it is TIME for one.
function mercenaries:PatrolMayEncounter(pp)
    if self:PatrolQuietLeft() then return false end
    local cap = self.PatrolAnchorCap or 0
    if cap > 0 and pp then
        local a = self:PatrolAnchorTouch(pp)
        if (a.n or 0) >= cap then return false end
    end
    return true
end

-- What this gang is allowed to be, given what is already out there. Returns 0 when there
-- is no room for even a minimum gang, and the caller simply does not spawn it.
function mercenaries:PatrolBudgetFor(want)
    -- Both aggregate caps scale with the tier. Raising only the per-gang size would
    -- be a no-op: the population budget would swallow the extra men on the way out.
    local gangCap = self.PatrolMaxLiveGangs or 0
    pcall(function() gangCap = self:DifficultyCeil(gangCap) end)
    if gangCap > 0 and self:PatrolLiveGangCount() >= gangCap then return 0 end
    local cap = self.PatrolMaxLiveMen or 0
    pcall(function() cap = self:DifficultyCeil(cap) end)
    if cap <= 0 then return want end
    local room = cap - self:PatrolLiveMenCount()
    if room < (self.PatrolMinMen or 3) then return 0 end
    return math.min(want, room)
end

function mercenaries:PatrolAliveCount(rec)
    local n = 0
    for _, e in ipairs(rec.men or {}) do
        if e and self:IsAliveAndWell(e, true) then n = n + 1 end
    end
    return n
end

-- Living men, in marching order. A corpse must not lead or hold a link in the
-- chain: the follow chain is only re-read when a man's TARGET changes, and a dead
-- man's key never changes, so a corpse anchors the whole column where it fell.
-- Only mattered once patrols could actually fight.
function mercenaries:PatrolLivingMen(rec)
    local out = {}
    for _, e in ipairs((rec and rec.men) or {}) do
        if e and self:IsAliveAndWell(e, true) then table.insert(out, e) end
    end
    return out
end

-- ==== the tick ====
-- Each patrol advances along its route whether or not it is spawned, so it is always
-- roughly where it ought to be. Spawned ones are steered by the patrol tester's own
-- machinery (PatrolPoints/PatrolLeader) - see PatrolDrive.
-- MEASURED: 63 firings in a 20.7s window where 7 were due, in a session with exactly one
-- load, one "roaming patrols armed" line and no watchdog re-arm - about nine chains driving
-- one tick. LootSweepTick, the one chain that had already been given an identity, was exact
-- (20 firings, 20 due) in the same window. So duplicate chains are real and the arming latch
-- alone does not stop them.
--
-- Same device as LootSweepArm: the generation rides in the FUNCTION NAME, because a chain
-- carries no other state of its own and a time-based duplicate guard is known to retire the
-- only chain there is (see MasterTick). A chain that is not the current slot stops without
-- re-arming, so the extras drain away within one period.
--
-- This is not a bookkeeping nicety. Every extra chain is another pass over the whole route
-- set AND another chance per period to spawn a gang - and a gang spawn is NPC creation,
-- ground raycasts and character assembly, which is engine time the Lua profiler cannot see.
mercenaries.LivePatrolSlot = 0

-- The WORK. Called from the master scheduler's "patrols" slot, which is the only tick in the
-- mod proven to exist exactly once (measured: 108ms observed against 100ms armed, in the same
-- session where this chain was running five times over). Nothing here arms a timer.
function mercenaries.LivePatrolBody()
    local self = mercenaries
    -- Stamped before any guard, so it means "the tick ran", not "the tick did work".
    self._liveTickAt = nowT()
    pcall(function()
        -- PatrolRouteData is deliberately NOT part of this guard: it is set by the level check
        -- below, so testing it here would mean the check never ran and no map ever had routes.
        if not (self.LivePatrolsEnabled and player) then return end
        -- The quartermaster's master switch for uninvited trouble.
        if self.EncountersOn and not self:EncountersOn() then return end
        -- Not while he is asleep, waiting out the clock, in a conversation or already in
        -- a fight he did not pick. A patrol that spawns in those moments is an ambush the
        -- player never had a chance to see coming - and one that spawns during a quest
        -- battle joins a fight that is not ours. Standing patrols are untouched: this only
        -- stops NEW ones being raised, so anything already on the road keeps walking.
        if self.PlayerBusyForSpawns then
            local busy, why = self:PlayerBusyForSpawns()
            if busy then
                if why ~= self._patrolHeldWhy then
                    self._patrolHeldWhy = why
                    System.LogAlways("[Patrol] holding spawns - player is " .. tostring(why))
                end
                return
            elseif self._patrolHeldWhy then
                self._patrolHeldWhy = nil
                System.LogAlways("[Patrol] spawns released")
            end
        end
        local pp; pcall(function() pp = player:GetWorldPos() end)
        if not pp then return end
        local t = nowT()

        -- Which map's routes apply is a LEVEL check, never a coordinate box: Kuttenberg and
        -- Trosky coordinates overlap, so a box would spawn one map's gangs on the other.
        if not (self:PatrolLevelAllowed() and self.PatrolRouteData) then
            for _, rec in pairs(self.LivePatrols) do
                if rec.spawned then
                    self:PatrolDespawnGang(rec, "no routes on this level")
                else
                    self:PatrolClearCorpses(rec)   -- a wiped record is not "spawned"
                end
            end
            return
        end

        -- Candidates are collected rather than spawned inline. Spawning inside the loop
        -- meant pairs() order decided who appeared, so at a junction the gang that won was
        -- arbitrary rather than the nearest, and every eligible record spawned on the same
        -- frame. Now the tick does its bookkeeping first and spawns the closest eligible
        -- gang (or PatrolSpawnPerTick of them) afterwards.
        local wants = {}
        for i = 1, #self.PatrolRouteData do
            for slot = 1, self:PatrolCountFor(i) do
                local key = i .. ":" .. slot
                local rec = self.LivePatrols[key]
                if not rec then
                    rec = self:PatrolMakeRecord(i, slot)
                    self.LivePatrols[key] = rec
                end
                if rec then
                    local d = self:PatrolTickOne(rec, pp, t)
                    if d then wants[#wants + 1] = { rec = rec, d = d } end
                end
            end
        end
        -- Checked before the sort, so a quiet road costs nothing.
        if #wants > 0 and self:PatrolMayEncounter(pp) then
            table.sort(wants, function(a, b) return a.d < b.d end)
            local placed = 0
            local perTick = self.PatrolSpawnPerTick or 1
            for _, w in ipairs(wants) do
                if placed >= perTick then break end
                if self:PatrolBudgetFor(self.PatrolMinMen or 3) <= 0 then break end
                -- Here rather than inside PatrolSpawnGang, so the console's forced spawn
                -- (merc_patrols_here) does not silence the road behind it.
                if self:PatrolSpawnGang(w.rec) then
                    placed = placed + 1
                    self:PatrolQuietFor(self.PatrolQuietSecs, "a gang has taken the road")
                    local a = self._patrolAnchor
                    if a then a.n = (a.n or 0) + 1 end
                end
            end
        end
    end)
end

-- Legacy chain, used only when the master scheduler is off (merc_sched 0). The slot rides in
-- the function name so a chain from a previous arm retires on its next firing; see
-- LootSweepArm. Under the scheduler neither of these is ever armed.
function mercenaries.LivePatrolTick0() mercenaries.LivePatrolBeat(0) end
function mercenaries.LivePatrolTick1() mercenaries.LivePatrolBeat(1) end

function mercenaries.LivePatrolBeat(slot)
    local self = mercenaries
    if not self.LivePatrolRunning or self.LivePatrolSlot ~= slot then return end
    mercenaries.LivePatrolBody()
    Script.SetTimerForFunction(self.PatrolLiveTickMs, "mercenaries.LivePatrolTick" .. slot)
end

function mercenaries:PatrolTickOne(rec, pp, t)
    -- wiped: hold it dead until the respawn day comes round
    if rec.deadAt then
        -- Clear the bodies once the player has walked off, or after the linger time
        -- if he camps on them. Must happen before the record is replaced below, or
        -- the corpses lose their owner and stand for ever.
        if rec.corpses then
            local q = self:PatrolPointOf(rec)
            local dist = nil
            if q then
                local cx, cy = pp.x - q.x, pp.y - q.y
                dist = math.sqrt(cx * cx + cy * cy)
            end
            local far   = (dist == nil) or (dist > self.PatrolDespawnRange)
            local fresh = (t - (rec.corpsesAt or 0)) < (self.PatrolCorpseGraceSecs or 0)
            -- A ragdoll is a 20-30 part ARTICULATED physics body, and a wiped gang leaves a
            -- pile of them touching each other - CryPhysics' worst case, since interpenetrating
            -- bodies never settle - right where the player is standing, for PatrolCorpseSecs.
            -- Freezing costs nothing anyone can see: they have finished falling. Looting reads
            -- SOUL state, not physics (LootCaptureBodies/IsCorpse), so they stay lootable, and
            -- the sweep still removes them on the same schedule. EnablePhysics(0) is the call
            -- the tower hold-test proved works on a live entity in this codebase.
            if not rec.corpsesFrozen
               and (t - (rec.corpsesAt or t)) >= (self.PatrolCorpseFreezeSecs or 5.0) then
                rec.corpsesFrozen = true
                local n = 0
                for _, e in ipairs(rec.corpses or {}) do
                    if e then
                        if pcall(function() e:AwakePhysics(0) end) then n = n + 1 end
                        pcall(function() e:EnablePhysics(0) end)
                    end
                end
                if n > 0 then lLog("route " .. tostring(rec.route) .. ": froze " .. n .. " corpse ragdoll(s)") end
            end
            local over  = (self.PatrolMaxCorpses or 0) > 0
                          and self:PatrolCorpseCount() > self.PatrolMaxCorpses
                          and not fresh
            if far or over or (t - (rec.corpsesAt or t)) >= self.PatrolCorpseSecs then
                self:PatrolClearCorpses(rec)
            end
        end

        if (t - rec.deadAt) >= (self.PatrolRespawnDays * (self.SecondsPerDay or 86400)) then
            self:PatrolClearCorpses(rec)
            local fresh = self:PatrolMakeRecord(rec.route, rec.slot)
            if fresh then
                self.LivePatrols[rec.key] = fresh
                lLog("route " .. rec.route .. ": a fresh patrol has taken the road")
            end
        end
        return
    end

    local p = self:PatrolPointOf(rec)
    if not p then return end
    local dx, dy = pp.x - p.x, pp.y - p.y
    local d = math.sqrt(dx * dx + dy * dy)

    if rec.spawned then
        -- Alert expiry: the target is gone, or it has run long enough.
        if rec.alertAt then
            local t2 = nil
            pcall(function() t2 = XGenAIModule.GetEntityByWUID(rec.alertTarget) end)
            if (t - rec.alertAt) >= self.PatrolAlertSecs
               or not (t2 and self:IsCombatViable(t2)) then
                self:PatrolAlertClear(rec)
            end
        end

        local alive = self:PatrolAliveCount(rec)
        -- Kill escalation: the cheapest existing look at this gang's headcount is this
        -- tick's own alive count, taken every 3s regardless - no new timer needed. Counts
        -- however many died since the last tick noticed, not just the wipe-out case below.
        local diedNow = math.max(0, (rec.lastAlive or alive) - alive)
        if diedNow > 0 then self:PatrolHeatAdd(rec.route, diedNow) end
        rec.lastAlive = alive
        if alive == 0 then
            -- Hand the bodies to the corpse list instead of deleting them with the
            -- record, so the fight you just won can be looted. Swept above.
            rec.corpses  = rec.men
            rec.corpsesAt = t
            rec.corpsesFrozen = false
            rec.men      = {}
            self:PatrolIndexClear(rec)
            rec.spawned  = false
            rec.deadAt   = t
            self:PatrolQuietFor(self.PatrolPostFightSecs, "a gang has been wiped out")
            lLog("route " .. rec.route .. ": patrol wiped out - back in " ..
                 self.PatrolRespawnDays .. " day(s)")
            return
        end
        -- follow the living leader, so the notional position tracks where they really are
        local L = self:PatrolLivingMen(rec)[1]
        if L and self:IsAliveAndWell(L, true) then
            local lp; pcall(function() lp = L:GetWorldPos() end)
            if lp then self:PatrolSyncIndex(rec, lp) end
        end
        if d > self.PatrolDespawnRange then
            self:PatrolDespawnGang(rec, "player left the area")
        end
    else
        -- unspawned: creep along the route on the clock
        local dt = t - (rec.moveAt or t)
        rec.moveAt = t
        local r = self:PatrolRouteOf(rec)
        -- This route's OWN mean marker spacing, not a hard-coded 10 m. PatrolAdvance steps by
        -- one INDEX, so dividing the creep by the wrong step scales the ghost's real ground
        -- speed by (actual spacing / step): on Trosky, whose markers average 15.9 m, a
        -- hard-coded 10 drifted the notional patrol at 2.23 m/s instead of PatrolGhostSpeed's
        -- 1.4 - 59% too fast, which is 59% less time spent inside the 200-250m spawn band.
        local stepM = (r and r.stepM) or 10.0
        -- The remainder has to CARRY. A 3s tick at PatrolGhostSpeed covers 4.2m of a 10m
        -- step, so flooring one tick's travel on its own is always 0 and moveAt is stamped
        -- every pass regardless - the notional patrol never moved at all, and every gang sat
        -- on the point it was rolled at for the whole session.
        rec.creep = (rec.creep or 0) + dt * self.PatrolGhostSpeed
        local steps = math.floor(rec.creep / stepM)
        if steps > 0 then
            rec.creep = rec.creep - steps * stepM
            self:PatrolAdvance(rec, steps)
            -- Re-measure against the point the men would actually appear at, not the one
            -- the gang stood on before it crept.
            local q = self:PatrolPointOf(rec)
            if q then d = math.sqrt((pp.x - q.x) ^ 2 + (pp.y - q.y) ^ 2) end
        end

        -- The floor matters as much as the range: a gang must never appear on top of the
        -- player. Inside it the record just stays notional until the gap opens again.
        -- The grace is the same idea in time rather than distance - see PatrolLoadGraceSecs.
        -- Eligible, but the caller decides: it spawns the nearest few, not everyone.
        if d <= self.PatrolSpawnRange and d >= self.PatrolNoSpawnRange
           and not self:PatrolInLoadGrace() then
            return d
        end
    end
end

-- Keep the notional index on the point nearest the real leader, so despawning and
-- respawning does not teleport the patrol back down the road.
--
-- It may only move the index FORWARD along the direction of travel unless forced.
-- PatrolWalkTick takes the next point well before the leader reaches the current one -
-- that lookahead is what makes the route walk smooth - so the nearest point is normally
-- one or two behind the index, and putting it back republished a point he had already
-- walked past, braking and turning him. See docs/patrols.md.
function mercenaries:PatrolSyncIndex(rec, lp, force)
    local r = self:PatrolRouteOf(rec)
    if not r then return end
    local best, bestD2 = rec.idx, nil
    for i, q in ipairs(r.pts) do
        local dx, dy = q.x - lp.x, q.y - lp.y
        local d2 = dx * dx + dy * dy
        if not bestD2 or d2 < bestD2 then best, bestD2 = i, d2 end
    end
    if not force then
        local dir = (rec.dir ~= nil and rec.dir ~= 0) and rec.dir or 1
        if ((best - rec.idx) * dir) < 0 then return end
    end
    rec.idx = best
end

-- MEASURED: nine arms inside the first two seconds of a single load, from two call sites that
-- can each run once - so the caller was never the real problem and the latch was never going to
-- hold. Under the master scheduler this arms NOTHING: the "patrols" slot owns the cadence, and
-- however many times this is called there is exactly one tick. The private chain survives only
-- for merc_sched 0.
--
-- (The previous log showed one arm line for nine arms because CryEngine collapses consecutive
-- identical lines; the slot number in the message is what made them distinct and visible.)
function mercenaries:LivePatrolStart()
    if self.LivePatrolRunning then return end
    self.LivePatrolRunning = true
    if self.SchedEnabled then
        lLog("roaming patrols armed (" .. #(self.PatrolRouteData or {}) .. " route(s)), on the master tick")
        return
    end
    self.LivePatrolSlot = 1 - (self.LivePatrolSlot or 0)
    Script.SetTimerForFunction(self.PatrolLiveTickMs, "mercenaries.LivePatrolTick" .. self.LivePatrolSlot)
    lLog("roaming patrols armed (" .. #(self.PatrolRouteData or {}) .. " route(s)), legacy slot " ..
         tostring(self.LivePatrolSlot))
end

-- Watchdog. LivePatrolRunning is a latch, and a latch plus a timer that can die (level
-- change, script reload) is a tick that never comes back: nothing would ever clear the flag,
-- so LivePatrolStart would refuse to re-arm and the patrols would be silently gone for the
-- rest of the session. LivePatrolTick stamps _liveTickAt every pass; if that stamp goes
-- stale the timer is not running whatever the flag says, so clear it and start again.
mercenaries.PatrolTickStaleSecs = 15.0

function mercenaries:LivePatrolWatchdog()
    -- Cheap safety net: rebuilds PatrolMemberIndex from LivePatrols every pass, so any
    -- future desync between rec.men and the index self-heals within one watchdog tick.
    self:PatrolIndexRebuild()
    local now = nowT()
    local last = self._liveTickAt
    -- Under the master scheduler there is no private chain to resurrect, and the scheduler has
    -- a watchdog of its own. Re-arming here is how a second chain was born.
    if self.SchedEnabled then return end
    if last and (now - last) < self.PatrolTickStaleSecs then return end
    lLog("tick stalled - re-arming (last stamp " .. tostring(last) .. ")")
    self.LivePatrolRunning = false
    self:LivePatrolStart()
end

-- Patrols are NOT save-persistent. The men are ordinary spawned NPCs so the engine serialises
-- them, but LivePatrols is plain Lua state and does not survive - what comes back is a hostile
-- gang with no record, no leader and no route, standing where the player saved and despawned by
-- nothing. Swept on load (OnGameplayStarted); the tick re-rolls fresh records straight after.
-- Corpses go too: their record is gone, so PatrolClearCorpses can never reach them.
--
-- Scanned in a box rather than by class: nothing of ours can be further out than
-- PatrolDespawnRange, and a full-world NPC scan on load is already spoken for by the merc cache.
mercenaries.PatrolSweepRadius = 600.0

-- Seconds left of the post-load grace, or nil. Ghosts keep creeping through it, so when it
-- lifts the gangs are where they should be rather than all queued at the player.
function mercenaries:PatrolLoadGraceLeft()
    local t = self._patrolGraceUntil
    if not t then return nil end
    local left = t - nowT()
    if left <= 0 then self._patrolGraceUntil = nil; return nil end
    return left
end

function mercenaries:PatrolInLoadGrace()
    return self:PatrolLoadGraceLeft() ~= nil
end

function mercenaries:ClearAnyLeftoverPatrols()
    self._patrolGraceUntil = nowT() + self.PatrolLoadGraceSecs
    -- Both pacing clocks are stamped from System.GetCurrTime, which does not survive the
    -- level we just left, so neither may cross a load. The grace above covers the gap.
    self._patrolQuietUntil = nil
    self._patrolAnchor     = nil
    local swept = 0
    pcall(function()
        local pp; pcall(function() pp = player and player:GetWorldPos() end)
        local ents = pp and System.GetPhysicalEntitiesInBoxByClass(pp, self.PatrolSweepRadius, "NPC")
                        or System.GetEntitiesByClass("NPC")
        for _, e in pairs(ents or {}) do
            local n = (e and e.GetName and e:GetName()) or ""
            for _, p in ipairs(self.PatrolPrefixes or {}) do
                if string.sub(n, 1, #p) == p then
                    pcall(function() System.RemoveEntity(e.id) end)
                    swept = swept + 1
                    break
                end
            end
        end
    end)
    self.LivePatrols = {}
    -- After the reset, not before: rebuilding from the old table just to discard it was a
    -- no-op that only self-healed on the next watchdog pass.
    if self.PatrolIndexRebuild then self:PatrolIndexRebuild() end
    if swept > 0 then lLog("swept " .. swept .. " leftover patrolman/men from the save") end
end

-- ==== controls ====
function mercenaries:LivePatrolStatus()
    local party = self:PatrolPartySize()
    local left  = self:PatrolLoadGraceLeft()
    local lo = self.PatrolMinMen
    local hi = math.max(self.PatrolMinMen,
                        math.min(self.PatrolMaxMen,
                                 math.floor(party * self:PatrolMaxMultFor(party) + 0.5)))
    local solo = self:PatrolPlayerAlone()
    if solo then
        lo = self.PatrolSoloMinMen or lo
        hi = math.max(lo, self.PatrolSoloMaxMen or hi)
    end
    lLog("enabled: " .. tostring(self.LivePatrolsEnabled) ..
         ", party strength " .. party ..
         string.format(" (gangs %d-%d men%s)", lo, hi, solo and ", alone" or "") ..
         string.format(", band %.0f-%.0fm, floor %.0fm",
                       self.PatrolNoSpawnRange or 0, self.PatrolSpawnRange or 0,
                       self.PatrolMinPlayerDist or 0) ..
         (left and string.format(", load grace %.0fs left", left) or ""))
    lLog(string.format("live: %d men in %d gang(s), %d corpse(s)  |  caps: %d men, %d gangs, %d per gang",
        self:PatrolLiveMenCount(), self:PatrolLiveGangCount(), self:PatrolCorpseCount(),
        self.PatrolMaxLiveMen or 0, self.PatrolMaxLiveGangs or 0, self.PatrolMaxMen or 0))
    local q = self:PatrolQuietLeft()
    local a = self._patrolAnchor
    lLog(string.format("pacing: %s  |  gap %.0fs, post-fight %.0fs (x%.2f for %s)  |  standing here: %d/%d gang(s)",
        q and string.format("QUIET for %.0fs more", q) or "a gang may spawn now",
        self.PatrolQuietSecs or 0, self.PatrolPostFightSecs or 0,
        self:PatrolQuietMult(), tostring(self.Difficulty),
        a and (a.n or 0) or 0, self.PatrolAnchorCap or 0))
    if self.CampActive and self.CampCenter then
        lLog(string.format("camp is up: no gang spawns within %.0fm of it",
                           self.PatrolCampClearance or 0))
    end
    lLog("level '" .. levelName() .. "' -> " ..
         (self:PatrolLevelAllowed() and "patrols allowed" or "WRONG LEVEL, no patrols"))
    for i, rec in pairs(self.LivePatrols) do
        local r = self:PatrolRouteOf(rec)
        lLog(string.format("  %s: %s x%d, point %d/%d dir %+d, %s%s",
            tostring(rec.key), tostring(rec.group or "unrolled"), rec.size or 0,
            rec.idx, r and #r.pts or 0, rec.dir,
            rec.spawned and (self:PatrolAliveCount(rec) .. " alive") or "not spawned",
            rec.deadAt and "  (wiped, respawning)" or ""))
    end
end

function mercenaries:LivePatrolSetEnabled(v)
    self.LivePatrolsEnabled = (tonumber(v) ~= 0)
    if not self.LivePatrolsEnabled then
        for _, rec in pairs(self.LivePatrols) do self:PatrolDespawnGang(rec) end
    end
    lLog("roaming patrols " .. (self.LivePatrolsEnabled and "on" or "off"))
end

-- Force the nearest patrol to spawn on top of you, for testing.
function mercenaries:LivePatrolHere()
    if not player then return end
    local pp; pcall(function() pp = player:GetWorldPos() end)
    if not pp then return end
    local best, bestD2
    for i = 1, #(self.PatrolRouteData or {}) do
      for slot = 1, self:PatrolCountFor(i) do
        local key = i .. ":" .. slot
        local rec = self.LivePatrols[key] or self:PatrolMakeRecord(i, slot)
        self.LivePatrols[key] = rec
        local p = rec and self:PatrolPointOf(rec)
        if p then
            local d2 = (p.x - pp.x) ^ 2 + (p.y - pp.y) ^ 2
            if not bestD2 or d2 < bestD2 then best, bestD2 = rec, d2 end
        end
      end
    end
    if not best then lLog("no routes loaded"); return end
    best.deadAt = nil
    self:PatrolDespawnGang(best)
    self:PatrolSyncIndex(best, pp, true)   -- forced: this gang is deliberately re-seated on the player
    if not self:PatrolSpawnGang(best, true) then
        lLog("nothing spawned - population budget is full (merc_patrols_status shows the caps)")
    end
end

function mercenaries:LivePatrolClear()
    for _, rec in pairs(self.LivePatrols) do self:PatrolDespawnGang(rec) end
    self.LivePatrols = {}
    lLog("all patrols cleared and re-rolled")
end

-- ==== detection ====
-- BT hook: FindEnemyTarget with a short leash. The mod's enemies notice the player from a
-- long way off, which is right for an ambush and wrong for men walking a road - a patrol
-- should have to come across you. Anything further than PatrolDetectRange is dropped.
--
-- ...but that range is PER MAN, and a gang can be fifty strong strung out along a road, so
-- only the few at the point were ever inside it: the front rank fought and the rest walked
-- on past. Once ANY man makes contact the whole gang is ALERTED - the target is pushed to
-- every living member through ForcedTargetOf, which FindEnemyTarget honours ahead of its own
-- scan and without any distance limit, so the tail turns round and comes too.
-- livingMen is optional: pass it when the caller already has PatrolLivingMen(rec) on
-- hand (see PatrolFindTarget) to skip recomputing it here. Falls back to computing its
-- own when omitted, so any other caller keeps working unchanged.
function mercenaries:PatrolAlert(rec, targetWuid, livingMen)
    if not (rec and targetWuid) then return end
    local now   = nowT()
    local first = (rec.alertAt == nil)

    -- Contact is reported every tick by every man in range. Refresh the clock cheaply and
    -- only rewrite the whole gang's forced targets when the target actually changes, or
    -- occasionally to cover men who have joined since - fifty men re-tagging fifty entries
    -- every second is thousands of pointless writes.
    if not first and rec.alertTarget == targetWuid and (now - (rec.alertSyncAt or 0)) < 3.0 then
        rec.alertAt = now
        return
    end

    rec.alertAt     = now
    rec.alertSyncAt = now
    rec.alertTarget = targetWuid
    local living = livingMen or self:PatrolLivingMen(rec)
    for _, e in ipairs(living) do
        local k = lKey(e)
        if k then self.ForcedTargetOf[k] = targetWuid end
    end
    if first then
        lLog("route " .. tostring(rec.route) .. ": gang alerted, " ..
             tostring(#living) .. " man(men) closing")
    end
end

-- Drop the alert: the fight is over, or it has run its course. Only clears the entries this
-- gang owns, so a man who has since picked his own target keeps it. livingMen is optional,
-- same as PatrolAlert above.
function mercenaries:PatrolAlertClear(rec, livingMen)
    if not (rec and rec.alertAt) then return end
    for _, e in ipairs(livingMen or self:PatrolLivingMen(rec)) do
        local k = lKey(e)
        if k and self.ForcedTargetOf[k] == rec.alertTarget then self.ForcedTargetOf[k] = nil end
    end
    rec.alertAt, rec.alertTarget, rec.alertSyncAt = nil, nil, nil
end

function mercenaries:PatrolFindTarget(bt_data, myWuid)
    self:FindEnemyTarget(bt_data, myWuid)
    if bt_data.currentTarget == nil then return end

    local me, tgt
    pcall(function() me = XGenAIModule.GetEntityByWUID(myWuid) end)
    pcall(function() tgt = XGenAIModule.GetEntityByWUID(bt_data.currentTarget) end)
    if not (me and tgt) then return end

    -- PatrolCtx already builds the living-members list internally (leader + followers);
    -- rebuild it here from those two return values instead of asking PatrolAlert/Clear
    -- to walk the gang again a moment later.
    local rec, living
    pcall(function()
        local leader, followers, _, _, r = self:PatrolCtx(me)
        rec = r
        if leader then
            living = { leader }
            for _, e in ipairs(followers or {}) do living[#living + 1] = e end
        end
    end)

    -- An alerted gang keeps whatever the alert handed it, however far off it is - that is
    -- the whole point of the alert, and ForcedTargetOf is what got him this target.
    if rec and rec.alertAt and self.ForcedTargetOf[lKey(me) or ''] ~= nil then
        if (nowT() - rec.alertAt) < self.PatrolAlertSecs then return end
        self:PatrolAlertClear(rec, living)
    end

    local a, b
    pcall(function() a = me:GetWorldPos(); b = tgt:GetWorldPos() end)
    if not (a and b) then return end
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    if (dx * dx + dy * dy + dz * dz) > (self.PatrolDetectRange * self.PatrolDetectRange) then
        bt_data.currentTarget = nil
    elseif rec then
        self:PatrolAlert(rec, bt_data.currentTarget, living)   -- contact: bring the rest of them
    end
end

-- ==== the bridge to the tester's movement hooks ====
-- patrol_scheduler.xml and patrol_follow.xml call one set of Lua hooks. Those hooks used
-- the tester's single PatrolLeader/PatrolMembers/PatrolPoints, which cannot serve eight
-- gangs at once - so they now ask this for the context the man in front of them belongs to.
--
-- Returns: leader entity, member list (followers only), route points, current index, and
-- the record (nil for the tester, which has no ping-pong state).
function mercenaries:PatrolCtx(ent)
    local k = lKey(ent)
    if not k then return nil end

    -- the hand-placed tester patrol
    if self.PatrolLeader and lKey(self.PatrolLeader) == k then
        return self.PatrolLeader, self.PatrolMembers, self.PatrolPoints, self.PatrolIndex, nil
    end
    for _, e in ipairs(self.PatrolMembers or {}) do
        if lKey(e) == k then
            return self.PatrolLeader, self.PatrolMembers, self.PatrolPoints, self.PatrolIndex, nil
        end
    end

    -- a roaming patrol, found via PatrolMemberIndex (O(1) instead of scanning every
    -- LivePatrols record - see mercenaries_perf.lua). Membership still covers a downed
    -- man (the index is kept for the whole rec.men list, corpses included), but the
    -- leader and the chain are built from the living only - see PatrolLivingMen.
    -- Deliberately no PatrolEpoch bump: that counter is global across every gang and
    -- the tester, so bumping it would restart every CrimeFollower on the map at once.
    local rec = self.PatrolMemberIndex[k]
    if rec then
        local living = self:PatrolLivingMen(rec)
        if #living == 0 then return nil end
        -- Rebuilt only when the living list itself was, so a steady gang stops allocating a
        -- followers table on every one of the ~5 asks per man per second. Tied to the same
        -- table identity, so it cannot go stale independently of it.
        local followers = {}
        for j = 2, #living do table.insert(followers, living[j]) end
        local r = self:PatrolRouteOf(rec)
        return living[1], followers, (r and r.pts or {}), rec.idx, rec
    end
    return nil
end

-- A roaming patrol walks its route back and forth; the tester loops. Called by
-- PatrolWalkTick once the leader is within the switch radius of his point.
function mercenaries:PatrolStepIndex(rec, ptsCount, idx)
    if rec then
        self:PatrolAdvance(rec, 1)
        return rec.idx
    end
    if idx >= ptsCount then
        return self.PatrolLoop and 1 or idx
    end
    return idx + 1
end

mercenaries:DevCommand("merc_patrols_status", "mercenaries:LivePatrolStatus()",        "Where every roaming patrol is and what it is")
mercenaries:DevCommand("merc_patrols_here",   "mercenaries:LivePatrolHere()",          "Spawn the nearest patrol on top of you")
mercenaries:DevCommand("merc_patrols_budget", "mercenaries:PatrolBudgetSet('%line')",
                   "Population caps: merc_patrols_budget <maxMen> [maxGangs] [maxPerGang]")
mercenaries:DevCommand("merc_patrols_escalation", "mercenaries:PatrolEscalationStatus()",
                   "Per-route session kill escalation: heat and the size multiplier it earns")
mercenaries:DevCommand("merc_patrols_floor", "mercenaries:PatrolFloorSet('%line')",
                   "How near a gang may ever be created: merc_patrols_floor <metres> [bandFloor] [bandCeil]")
mercenaries:DevCommand("merc_patrols_pace", "mercenaries:PatrolPaceSet('%line')",
                   "How OFTEN a gang may turn up: merc_patrols_pace <gapSecs> [postFightSecs] [standingCap]")

-- The distance knobs, tunable in-game for the same reason as the caps below. The first
-- number is the hard floor no gang may ever be created inside; the other two are the band
-- the tick prefers to place one in. No argument reports.
function mercenaries:PatrolFloorSet(v)
    local a, b, c = string.match(tostring(v or ""), "(%d+)%s*(%d*)%s*(%d*)")
    if a then
        self.PatrolMinPlayerDist = tonumber(a)
        if b and b ~= "" then self.PatrolNoSpawnRange = tonumber(b) end
        if c and c ~= "" then self.PatrolSpawnRange   = tonumber(c) end
    end
    lLog(string.format("floor %.0fm, band %.0f-%.0fm, despawn %.0fm",
        self.PatrolMinPlayerDist or 0, self.PatrolNoSpawnRange or 0,
        self.PatrolSpawnRange or 0, self.PatrolDespawnRange or 0))
end

-- One knob for the three caps, so the cost can be tuned in-game against a real scene
-- rather than by editing and repackaging. merc_patrols_budget with no argument reports.
function mercenaries:PatrolBudgetSet(v)
    local a, b, c = string.match(tostring(v or ""), "(%d+)%s*(%d*)%s*(%d*)")
    if a then
        self.PatrolMaxLiveMen = tonumber(a)
        if b and b ~= "" then self.PatrolMaxLiveGangs = tonumber(b) end
        if c and c ~= "" then self.PatrolMaxMen       = tonumber(c) end
    end
    lLog(string.format("caps: %d men total, %d gangs, %d per gang  (live now: %d men in %d gang(s), %d corpse(s))",
        self.PatrolMaxLiveMen or 0, self.PatrolMaxLiveGangs or 0, self.PatrolMaxMen or 0,
        self:PatrolLiveMenCount(), self:PatrolLiveGangCount(), self:PatrolCorpseCount()))
end

-- The pacing knobs, alongside the distance and population ones. No argument reports.
function mercenaries:PatrolPaceSet(v)
    local a, b, c = string.match(tostring(v or ""), "(%d+)%s*(%d*)%s*(%d*)")
    if a then
        self.PatrolQuietSecs = tonumber(a)
        if b and b ~= "" then self.PatrolPostFightSecs = tonumber(b) end
        if c and c ~= "" then self.PatrolAnchorCap     = tonumber(c) end
        self._patrolQuietUntil = nil   -- or a change means waiting out the one it replaced
    end
    local q = self:PatrolQuietLeft()
    lLog(string.format("gap %.0fs, post-fight %.0fs, standing cap %d per %.0fm  (x%.2f for %s)  |  %s",
        self.PatrolQuietSecs or 0, self.PatrolPostFightSecs or 0,
        self.PatrolAnchorCap or 0, self.PatrolAnchorRadius or 0,
        self:PatrolQuietMult(), tostring(self.Difficulty),
        q and string.format("quiet for %.0fs more", q) or "a gang may spawn now"))
end
