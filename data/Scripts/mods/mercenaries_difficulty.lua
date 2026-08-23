-- One global difficulty setting, read by everything that fields hostiles: camp
-- raids, roaming patrols, and the bounty / Kleinkrieg contracts.
--
-- A tier says two things. `countMult` is how badly the player is allowed to be
-- outnumbered - a CAP relative to his own strength, not a flat headcount, so the
-- same setting means the same thing to a four-man company and a fifty-man one.
-- `quality` biases the wardrobe the enemy is dressed from.
--
-- Every system keeps its own notion of "the player's strength", because they
-- disagree for good reasons: a raid is fought by the whole company including the
-- men asleep in camp, a bounty is fought only by whoever walked out. The tier is
-- applied on top of whichever base the caller already uses.
--
-- See docs/difficulty.md.

mercenaries.DifficultyOrder = { "easy", "medium", "difficult", "extreme", "impossible", "horde" }

mercenaries.DifficultyTiers = {
    easy       = { countMult = 0.8, quality = "low",   label = "Easy" },
    medium     = { countMult = 1.2, quality = "mixed", label = "Medium" },
    difficult  = { countMult = 1.4, quality = "mixed", label = "Difficult" },
    extreme    = { countMult = 1.5, quality = "high",  label = "Extreme" },
    impossible = { countMult = 2.0, quality = "high",  label = "Impossible" },
    horde      = { countMult = 4.0, quality = "low",   label = "Horde" },
}

mercenaries.Difficulty = "medium"

-- Count-encoded from the quartermaster dialog: Amount 1..6 indexes DifficultyOrder.
mercenaries.TokenIDQMDifficulty = "679a655e-189d-4519-b437-ccc4b92bee8d"

-- Medium is the reference tier: at 1.2 every hard ceiling keeps the value it was
-- tuned with, and "mixed" quality is byte-identical to the old flat random draw.
-- Anything harsher scales the ceilings so the multiplier is not silently clipped.
mercenaries.DifficultyBaseMult = 1.2

-- How often a biased tier actually draws from its favoured half of the wardrobe.
-- Not 1.0: "favour low armour" should still put the odd decent breastplate in the
-- line, or every easy fight looks identically ragged.
mercenaries.DifficultyQualityBias = 0.7

local function diffLog(s) System.LogAlways("[Difficulty] " .. s) end

-- ==== the setting ====
function mercenaries:DifficultyLoad()
    if self._difficultyLoaded then return self.Difficulty end
    local v
    pcall(function() v = self:LoadString("MercDifficulty") end)
    if v and self.DifficultyTiers[v] then self.Difficulty = v end
    self._difficultyLoaded = true
    return self.Difficulty
end

function mercenaries:DifficultySet(name)
    name = tostring(name or ""):lower():gsub("%s", "")
    if not self.DifficultyTiers[name] then
        diffLog("unknown tier '" .. name .. "'; pick one of: " ..
                table.concat(self.DifficultyOrder, ", "))
        return false
    end
    self.Difficulty = name
    self._difficultyLoaded = true
    self:SaveString("MercDifficulty", name)
    local t = self.DifficultyTiers[name]
    diffLog(string.format("%s - up to %.1f enemies per man, %s armour",
        t.label, t.countMult, t.quality))
    Game.SendInfoText("Difficulty: " .. t.label, false, 0, 4)
    return true
end

-- Count-encoded from the quartermaster dialog: 1..6 index DifficultyOrder.
function mercenaries:DifficultySetByIndex(n)
    local key = self.DifficultyOrder[tonumber(n) or 0]
    if key then self:DifficultySet(key) end
end

function mercenaries:DifficultyTier()
    self:DifficultyLoad()
    return self.DifficultyTiers[self.Difficulty] or self.DifficultyTiers.medium
end

function mercenaries:DifficultyQuality()
    return self:DifficultyTier().quality or "mixed"
end

-- ==== counts ====
-- Scale a rolled enemy count, then hold it under the tier's cap. `base` is the
-- caller's own strength measure; `floorMin` keeps an easy tier from emptying an
-- encounter out entirely.
function mercenaries:DifficultyCount(want, base, floorMin)
    local mult = self:DifficultyTier().countMult or 1.0
    want = math.floor((tonumber(want) or 0) * mult + 0.5)
    local cap = math.max(1, math.floor((tonumber(base) or 0) * mult + 0.5))
    if want > cap then want = cap end
    local lo = math.max(1, tonumber(floorMin) or 1)
    if want < lo then want = lo end
    return want
end

-- Raise a hard ceiling in step with the tier. Ceilings were tuned at the medium
-- multiplier, so medium and anything gentler leave them exactly as authored.
function mercenaries:DifficultyCeil(base)
    local mult = self:DifficultyTier().countMult or 1.0
    if mult <= self.DifficultyBaseMult then return base end
    return math.floor((tonumber(base) or 0) * (mult / self.DifficultyBaseMult) + 0.5)
end

-- ==== wardrobe quality ====
-- mercenaries.Outfits already grades the same clothing GUIDs the enemy groups
-- dress from into weak/medium/strong, so the quality ladder is authored data
-- rather than a guess. Built once and cached.
function mercenaries:DiffClothingTierIndex()
    if self._diffClothTier then return self._diffClothTier end
    local idx = {}
    for _, set in pairs(self.Outfits or {}) do
        if type(set) == "table" then
            for tier, list in pairs(set) do
                if type(list) == "table" then
                    for _, guid in ipairs(list) do idx[guid] = tier end
                end
            end
        end
    end
    self._diffClothTier = idx
    return idx
end

-- Split a group's wardrobe into its raggedest and its best half. Outfits decides
-- where a GUID sits when it knows it; the rest fall back to their position in the
-- array, which every group authors worst-first (see EnemyGroups).
function mercenaries:DiffWardrobe(groupKey)
    self._diffWardrobe = self._diffWardrobe or {}
    if self._diffWardrobe[groupKey] then return self._diffWardrobe[groupKey] end

    local grp  = self.EnemyGroups and self.EnemyGroups[groupKey]
    local pool = (grp and grp.clothing) or {}
    local idx  = self:DiffClothingTierIndex()
    local rank = { weak = 1.0, medium = 2.0, strong = 3.0 }

    local scored = {}
    for i, guid in ipairs(pool) do
        local known = idx[guid]
        local r = known and (rank[known] or 2.0)
                  or (1.0 + 2.0 * ((i - 1) / math.max(1, #pool - 1)))
        table.insert(scored, { guid = guid, r = r, i = i })
    end
    -- Stable on ties: two GUIDs of the same graded tier keep their authored order.
    table.sort(scored, function(a, b)
        if a.r == b.r then return a.i < b.i end
        return a.r < b.r
    end)

    local n   = #scored
    local cut = math.max(1, math.floor(n / 2))
    local low, high = {}, {}
    for i, s in ipairs(scored) do
        if i <= cut then table.insert(low, s.guid) end
        if i > (n - cut) then table.insert(high, s.guid) end
    end

    local w = { low = low, high = high }
    self._diffWardrobe[groupKey] = w
    return w
end

-- The draw EquipEnemy makes. A "mixed" tier returns nil so the caller keeps its
-- own uniform pick and nothing about the old behaviour changes.
function mercenaries:DiffPickClothing(groupKey)
    local q = self:DifficultyQuality()
    if q ~= "low" and q ~= "high" then return nil end

    local grp  = self.EnemyGroups and self.EnemyGroups[groupKey]
    local pool = (grp and grp.clothing) or {}
    if #pool == 0 then return nil end

    local w    = self:DiffWardrobe(groupKey)
    local half = (q == "low") and w.low or w.high
    if #half > 0 and math.random() < self.DifficultyQualityBias then
        return half[math.random(1, #half)]
    end
    return nil
end

function mercenaries:MonitorDifficultyTokens(p)
    local n = p:GetCountOfClass(self.TokenIDQMDifficulty)
    if n and n > 0 then
        p:DeleteItemOfClass(self.TokenIDQMDifficulty, n)
        self:DifficultySetByIndex(n)
    end

    local e = p:GetCountOfClass(self.TokenIDQMEncounters)
    if e and e > 0 then
        p:DeleteItemOfClass(self.TokenIDQMEncounters, e)
        self:EncountersSet(e == 1)
    end

    local u = p:GetCountOfClass(self.TokenIDQMUpkeep)
    if u and u > 0 then
        p:DeleteItemOfClass(self.TokenIDQMUpkeep, u)
        self:UpkeepSetByIndex(u)
    end

    local s = p:GetCountOfClass(self.TokenIDQMStatusIcons)
    if s and s > 0 then
        p:DeleteItemOfClass(self.TokenIDQMStatusIcons, s)
        self:StatusIconsSet(s == 1)
    end
end

-- ==== encounters ====
-- The master switch for everything this mod puts in the player's way that he did not
-- ask for: camp raids, roaming patrols and roadside ambushes. Contracts he accepts
-- himself are NOT encounters and are unaffected.
mercenaries.EncountersEnabled  = true
mercenaries.TokenIDQMEncounters = "679a655e-189d-4519-b437-ccc4b92beead"

function mercenaries:EncountersOn()
    if self._encountersLoaded == nil then
        local v
        pcall(function() v = self:LoadString("MercEncounters") end)
        self.EncountersEnabled = (v ~= "0")
        self._encountersLoaded = true
    end
    return self.EncountersEnabled
end

function mercenaries:EncountersSet(on)
    self.EncountersEnabled = on and true or false
    self._encountersLoaded = true
    self:SaveString("MercEncounters", self.EncountersEnabled and "1" or "0")
    diffLog("random encounters " .. (self.EncountersEnabled and "on" or "off"))
    Game.SendInfoText(self.EncountersEnabled and 'merc_info_enc_on' or 'merc_info_enc_off', false, 0, 4)
end

-- ==== company survival ====
-- How hard the men are to keep. `feed` multiplies FeedRatio - how many mercs one unit
-- of food carries for a day - so a HIGHER feed is gentler. `yield` multiplies what a
-- body is worth after a fight. "off" stands the whole upkeep system down: no rations,
-- no wages, no morale drift.
mercenaries.UpkeepOrder = { "off", "lenient", "standard", "harsh" }
mercenaries.UpkeepModes = {
    off      = { label = "Upkeep off",       feed = 1.0,  yield = 1.0  },
    lenient  = { label = "Lenient upkeep",   feed = 1.4,  yield = 1.25 },
    standard = { label = "Standard upkeep",  feed = 1.0,  yield = 1.0  },
    harsh    = { label = "Harsh upkeep",     feed = 0.65, yield = 0.7  },
}
mercenaries.Upkeep = "standard"
mercenaries.TokenIDQMUpkeep = "679a655e-189d-4519-b437-ccc4b92beebd"

function mercenaries:UpkeepLoad()
    if self._upkeepLoaded then return self.Upkeep end
    local v
    pcall(function() v = self:LoadString("MercUpkeep") end)
    if v and self.UpkeepModes[v] then self.Upkeep = v end
    self._upkeepLoaded = true
    self:UpkeepApply()
    return self.Upkeep
end

function mercenaries:UpkeepMode()
    self:UpkeepLoad()
    return self.UpkeepModes[self.Upkeep] or self.UpkeepModes.standard
end

function mercenaries:UpkeepOn()
    return self:UpkeepLoad() ~= "off"
end

-- The rates are read straight off mercenaries.* by the logistics tick, so the mode is
-- applied by rewriting them - from a pristine copy taken the first time through, or
-- setting the mode twice would compound.
function mercenaries:UpkeepApply()
    self._upkeepBase = self._upkeepBase or {
        feed  = self.FeedRatio,
        food  = self.LootPerKillFood,
        drink = self.LootPerKillDrink,
        wages = self.LootPerKillWages,
    }
    local b, m = self._upkeepBase, (self.UpkeepModes[self.Upkeep] or self.UpkeepModes.standard)
    if not b.feed then return end
    self.FeedRatio        = math.max(1, b.feed * (m.feed or 1.0))
    self.LootPerKillFood  = (b.food  or 0) * (m.yield or 1.0)
    self.LootPerKillDrink = (b.drink or 0) * (m.yield or 1.0)
    self.LootPerKillWages = (b.wages or 0) * (m.yield or 1.0)
end

function mercenaries:UpkeepSet(name)
    name = tostring(name or ""):lower():gsub("%s", "")
    if not self.UpkeepModes[name] then
        diffLog("unknown upkeep mode '" .. name .. "'; pick one of: " ..
                table.concat(self.UpkeepOrder, ", "))
        return false
    end
    self.Upkeep = name
    self._upkeepLoaded = true
    self:SaveString("MercUpkeep", name)
    self:UpkeepApply()
    local m = self.UpkeepModes[name]
    diffLog(string.format("%s (one food unit feeds %.1f men a day, spoils x%.2f)",
        m.label, self.FeedRatio, m.yield or 1.0))
    Game.SendInfoText(m.label, false, 0, 4)
    return true
end

function mercenaries:UpkeepSetByIndex(n)
    local key = self.UpkeepOrder[tonumber(n) or 0]
    if key then self:UpkeepSet(key) end
end

-- ==== status icons ====
mercenaries.StatusIconsEnabled  = true
mercenaries.TokenIDQMStatusIcons = "679a655e-189d-4519-b437-ccc4b92beecd"

function mercenaries:StatusIconsOn()
    if self._statusIconsLoaded == nil then
        local v
        pcall(function() v = self:LoadString("MercStatusIcons") end)
        self.StatusIconsEnabled = (v ~= "0")
        self._statusIconsLoaded = true
    end
    return self.StatusIconsEnabled
end

function mercenaries:StatusIconsSet(on)
    self.StatusIconsEnabled = on and true or false
    self._statusIconsLoaded = true
    self:SaveString("MercStatusIcons", self.StatusIconsEnabled and "1" or "0")
    -- Take them off the HUD now rather than at the next logistics tick.
    pcall(function() self:LogiUpdateStatusBuffs() end)
    diffLog("status icons " .. (self.StatusIconsEnabled and "on" or "off"))
end

-- ==== status ====
function mercenaries:DifficultyStatus()
    local t = self:DifficultyTier()
    diffLog(string.format("%s (%s): up to %.1f enemies per man, %s armour",
        self.Difficulty, t.label, t.countMult, t.quality))
    diffLog(string.format("raid ceiling %d, patrol gang ceiling %d, live patrolmen %d",
        self:DifficultyCeil(self.RaidMaxCount or 14),
        self:DifficultyCeil(self.PatrolMaxMen or 16),
        self:DifficultyCeil(self.PatrolMaxLiveMen or 36)))
    local parts = {}
    for _, k in ipairs(self.DifficultyOrder) do
        table.insert(parts, k .. (k == self.Difficulty and " <-" or ""))
    end
    diffLog("tiers: " .. table.concat(parts, ", "))
end

System.AddCCommand("merc_difficulty", "mercenaries:DifficultySet('%line')",
    "Set global difficulty: easy | medium | difficult | extreme | impossible | horde")
System.AddCCommand("merc_difficulty_status", "mercenaries:DifficultyStatus()",
    "Report the difficulty tier and the ceilings it implies")
System.AddCCommand("merc_encounters", "mercenaries:EncountersSet(tonumber('%line') ~= 0)",
    "Random encounters (raids, patrols, ambushes) on or off: merc_encounters 0 | 1")
System.AddCCommand("merc_upkeep", "mercenaries:UpkeepSet('%line')",
    "Company survival: off | lenient | standard | harsh")
System.AddCCommand("merc_status_icons", "mercenaries:StatusIconsSet(tonumber('%line') ~= 0)",
    "Squad status HUD icons on or off: merc_status_icons 0 | 1")
