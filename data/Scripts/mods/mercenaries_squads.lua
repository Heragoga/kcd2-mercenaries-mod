-- Squads: the company divided into the four units the command interface gives orders to.
--
-- The mod has always fielded one blob - ActiveMercs with a single formation leader. Squads
-- sit on top of that without replacing it: a squad is a named set of WUIDs, and an order
-- issued to a squad is applied to exactly those men.
--
--   merc_squads          print the current division
--   merc_squads_rebuild  re-deal the company from scratch
--
-- See docs/command-ui.md.

-- Four squads, always: two melee and two archer. An army with no archers fields two
-- empty archer cards rather than renumbering everything.
mercenaries.SquadCount = 4
mercenaries.SquadMax   = 4

-- [i] = { key -> true }. Keyed by WUID string, because entity refs do not survive a level
-- change and the roster is rebuilt constantly.
mercenaries.Squads = mercenaries.Squads or {}
mercenaries.SquadOrder = mercenaries.SquadOrder or {}   -- [i] = movement order key
mercenaries.SquadDeaths = mercenaries.SquadDeaths or {}  -- [i] = men lost since the fight began

local function log(s) System.LogAlways("[MercSquad] " .. tostring(s)) end

local function squadTable(i)
    mercenaries.Squads[i] = mercenaries.Squads[i] or {}
    return mercenaries.Squads[i]
end

-- ---------------------------------------------------------------- the division

-- Squads have FIXED ROLES: 1 and 2 are melee, 3 and 4 are archers. Men are only ever dealt
-- into a squad of their own kind, so an army with no archers simply leaves squads 3 and 4
-- empty rather than diluting the melee line - and the player always knows which card is which.
mercenaries.SquadRole = { "melee", "melee", "archer", "archer" }

function mercenaries:SquadAssign(force)
    local archers, melee, live = {}, {}, {}

    pcall(function()
        for _, ent in pairs(self.ActiveMercs or {}) do
            local wuid = ent and (ent.this and ent.this.id or ent.id)
            if wuid and self:IsAliveAndWell(ent, false) then
                local key = tostring(wuid)
                live[key] = true
                local name
                pcall(function() name = ent:GetName() end)
                local rec = { key = key, archer = self:IsArcherName(name) }
                table.insert(rec.archer and archers or melee, rec)
            end
        end
    end)

    -- Stable order, so the same man lands in the same squad every re-deal and the cards do
    -- not reshuffle every time someone dies.
    local bykey = function(a, b) return a.key < b.key end
    table.sort(archers, bykey)
    table.sort(melee, bykey)

    -- Drop the dead, anyone who left, and anyone sitting in a squad of the wrong kind.
    local placed, counts = {}, {}
    local kindOf = {}
    for _, r in ipairs(archers) do kindOf[r.key] = "archer" end
    for _, r in ipairs(melee) do kindOf[r.key] = "melee" end
    for i = 1, self.SquadMax do
        local t, role = squadTable(i), self.SquadRole[i]
        counts[i] = 0
        for key in pairs(t) do
            if force or not live[key] or kindOf[key] ~= role then
                -- Gone and not merely reassigned: that is a casualty, and the card says so
                -- until the fighting stops.
                if not force and not live[key] and kindOf[key] == nil then
                    self.SquadDeaths[i] = (self.SquadDeaths[i] or 0) + 1
                end
                t[key] = nil
            else
                placed[key] = i
                counts[i] = counts[i] + 1
            end
        end
    end

    local function dealInto(list, slots)
        for _, rec in ipairs(list) do
            if not placed[rec.key] then
                local best = slots[1]
                for _, i in ipairs(slots) do
                    if counts[i] < counts[best] then best = i end
                end
                squadTable(best)[rec.key] = true
                placed[rec.key] = best
                counts[best] = counts[best] + 1
            end
        end
    end

    local meleeSlots, archerSlots = {}, {}
    for i = 1, self.SquadMax do
        table.insert(self.SquadRole[i] == "archer" and archerSlots or meleeSlots, i)
    end
    dealInto(melee, meleeSlots)
    dealInto(archers, archerSlots)
    return self.SquadMax, #archers + #melee
end

-- ---------------------------------------------------------------- accessors

function mercenaries:SquadMembers(i)
    local out = {}
    pcall(function()
        local t = self.Squads[i] or {}
        for _, ent in pairs(self.ActiveMercs or {}) do
            local wuid = ent and (ent.this and ent.this.id or ent.id)
            if wuid and t[tostring(wuid)] and self:IsAliveAndWell(ent, false) then
                table.insert(out, ent)
            end
        end
    end)
    return out
end

-- Every WUID key across the given squad indices, in the shape HoldMembers wants.
function mercenaries:SquadKeySet(indices)
    local out, any = {}, false
    for _, i in ipairs(indices or {}) do
        for key in pairs(self.Squads[i] or {}) do out[key], any = true, true end
    end
    return any and out or nil
end

-- What the squad mostly is, for the card glyph.
function mercenaries:SquadType(i)
    return (self.SquadRole[i] == "archer") and "archer" or "infantry"
end

-- Mean health across the squad, 0..1, for the card's bar.
function mercenaries:SquadHealth(i)
    local sum, n = 0, 0
    for _, ent in ipairs(self:SquadMembers(i)) do
        local h
        pcall(function() h = ent.actor:GetHealth() / math.max(1, ent.actor:GetMaxHealth()) end)
        if h then sum, n = sum + math.max(0, math.min(1, h)), n + 1 end
    end
    if n == 0 then return 1 end
    return sum / n
end

-- ---------------------------------------------------------------- state

-- Is anyone in this squad actually fighting? soul:IsInCombatDanger is the working check -
-- soul:GetTarget is not a real bind and answers "no target" for everyone.
function mercenaries:SquadInCombat(i)
    for _, ent in ipairs(self:SquadMembers(i)) do
        local hot = false
        pcall(function() hot = ent.soul:IsInCombatDanger() end)
        if hot then return true end
    end
    return false
end

-- Have they got where they were sent? A man is there when he is standing on his station.
function mercenaries:SquadArrived(i)
    local st = self.HoldStations or {}
    local near, total = 0, 0
    for _, ent in ipairs(self:SquadMembers(i)) do
        local w = ent and (ent.this and ent.this.id or ent.id)
        local s = w and st[tostring(w)]
        if s then
            total = total + 1
            local p
            pcall(function() p = ent:GetWorldPos() end)
            if p then
                local dx, dy = p.x - s.x, p.y - s.y
                if (dx * dx + dy * dy) <= (self.HoldArriveDist or 2.2) ^ 2 then
                    near = near + 1
                end
            end
        end
    end
    if total == 0 then return false end
    return near >= math.ceil(total * 0.7)
end

-- Is this squad quartered? A man is in camp when the camp is standing and he is not in the
-- out-party, which is the camp's own "this man is out with the player" flag.
function mercenaries:SquadInCamp(i)
    local men = self:SquadMembers(i)
    if #men == 0 then return false end
    local inside = 0
    for _, ent in ipairs(men) do
        local w = ent and (ent.this and ent.this.id or ent.id)
        if w and self:IsMercInCampProper(w) then inside = inside + 1 end
    end
    return inside >= math.ceil(#men * 0.5)
end

-- What the card's little glyph underneath should say. Mostly the movement icons; camp gets
-- the tent, because being quartered is a state no movement order describes.
--
-- Combat comes first: a squad fighting in camp is fighting, and that is the thing the player
-- needs to see.
function mercenaries:SquadState(i)
    if #self:SquadMembers(i) == 0 then return nil end
    if self:SquadInCombat(i) then return "charge" end          -- fighting
    if self:SquadInCamp(i) then return "camp" end
    local o = self.SquadOrder[i]
    if o == "move" or o == "retreat" then
        return self:SquadArrived(i) and "stop" or "move"
    end
    if o == "stop" then return "stop" end
    return "follow"
end

-- Casualties are shown until the fighting is over, then the slate is wiped: the bar is
-- meant to report "this fight cost you four men", not to accumulate for ever.
function mercenaries:SquadDeathTick()
    local anyFight = false
    for i = 1, self.SquadMax do
        if self:SquadInCombat(i) then anyFight = true break end
    end
    if anyFight then
        self._squadCalm = 0
        return
    end
    self._squadCalm = (self._squadCalm or 0) + 1
    if self._squadCalm >= 2 then
        for i = 1, self.SquadMax do self.SquadDeaths[i] = 0 end
    end
end

-- ---------------------------------------------------------------- reporting

function mercenaries:SquadStatus()
    local n = self:SquadAssign()
    log("fielding " .. n .. " squad(s) - 1,2 melee / 3,4 archers:")
    for i = 1, n do
        local men = self:SquadMembers(i)
        local arc = 0
        for _, ent in ipairs(men) do
            local nm
            pcall(function() nm = ent:GetName() end)
            if self:IsArcherName(nm) then arc = arc + 1 end
        end
        log(string.format("  %d [%-6s] %2d men (%d archer, %d melee)  order=%-10s hp=%.0f%%",
            i, self.SquadRole[i], #men, arc, #men - arc,
            tostring(self.SquadOrder[i] or "follow"), self:SquadHealth(i) * 100))
    end
end

mercenaries:PlayerCommand("merc_squads", "mercenaries:SquadStatus()", "Print the squad division")
mercenaries:PlayerCommand("merc_squads_rebuild", "mercenaries:SquadAssign(true)",
                       "Re-deal the company into squads from scratch")
