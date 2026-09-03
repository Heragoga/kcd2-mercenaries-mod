-- One global difficulty setting, read by everything that fields hostiles: camp
-- raids, roaming patrols, and the bounty / Kleinkrieg contracts.
--
-- A tier says three things. `countMult` is how badly the player is allowed to be
-- outnumbered - a CAP relative to his own strength, not a flat headcount, so the
-- same setting means the same thing to a four-man company and a fifty-man one.
-- `quality` biases the wardrobe the enemy is dressed from. PatrolQuietByTier, over in
-- mercenaries_patrols_live.lua, scales how OFTEN the roads produce a gang at all.
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
    -- Interleaved @-keys, not "Difficulty: " .. label: SendInfoText resolves each
    -- WORD as a string id, so a raw sentence renders untranslated at best.
    Game.SendInfoText("@merc_info_difficulty @merc_diff_" .. name, false, 0, 4)
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
-- Grades clothing GUIDs into weak/medium/strong. Outfits covers what the squad
-- wears; OutfitTierHints covers the vanilla presets only the enemy groups still
-- use, so both have to be folded in or half the enemy wardrobe loses its grade
-- and falls back to array position. Built once and cached.
function mercenaries:DiffClothingTierIndex()
    if self._diffClothTier then return self._diffClothTier end
    local idx = {}
    local function grade(set)
        if type(set) ~= "table" then return end
        for tier, list in pairs(set) do
            if type(list) == "table" then
                for _, guid in ipairs(list) do idx[guid] = tier end
            end
        end
    end
    for _, set in pairs(self.Outfits or {}) do grade(set) end
    grade(self.OutfitTierHints)
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

    local h = p:GetCountOfClass(self.TokenIDQMHorses)
    if h and h > 0 then
        p:DeleteItemOfClass(self.TokenIDQMHorses, h)
        self:HorsesSet(h == 1)
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

-- ==== horses ====
-- Off means the company marches on foot whatever the player is riding. The lever is
-- _G.PlayerMounted, not the horse spawn: that global is what the whole mod reads as "the
-- squad is operating mounted", and it independently selects the mounted formation preset,
-- widens the leader-swap margin and DISABLES the fall-behind teleport - so blocking only
-- the spawn leaves men on foot in a 64m cavalry column with no way to catch up. Held false
-- at the single place that publishes it (MercPlayerMountSeen), which makes everything
-- downstream follow, including the orphan sweep that despawns horses already standing.
mercenaries.HorsesEnabled  = true
-- Men out with the player above which nobody rides (see MercPlayerMountSeen). 0 = no limit,
-- and that is the default: capping it at 30 was tried on 2026-09-03 against the riderless
-- horses at fifty men and the report was simply "the mercs didn't mount up", which is worse
-- than the thing it fixed. The AI-LOD budget raise (LodBoostCompanyMin) is the real answer
-- to a big mounted company; this is here for whoever still wants the hard limit.
mercenaries.HorsesMaxCompany = 0
mercenaries.TokenIDQMHorses = "679a655e-189d-4519-b437-ccc4b92beefd"

function mercenaries:HorsesMaxSet(line)
    local n = tonumber(tostring(line or ""):match("%d+"))
    if not n then
        diffLog("riders limit: " .. tostring(self.HorsesMaxCompany or 0) .. " men out (0 = no limit)")
        return
    end
    self.HorsesMaxCompany = n
    self._horsesCapNoted = false
    pcall(function() self:SaveString("MercHorsesMax", tostring(n)) end)
    diffLog("riders limit set to " .. tostring(n) .. (n == 0 and " (no limit)" or " men out"))
end

function mercenaries:HorsesAllowed()
    if self._horsesLoaded == nil then
        local v
        pcall(function() v = self:LoadString("MercHorses") end)
        self.HorsesEnabled = (v ~= "0")
        local m; pcall(function() m = tonumber(self:LoadString("MercHorsesMax")) end)
        if m then self.HorsesMaxCompany = m end
        self._horsesLoaded = true
    end
    return self.HorsesEnabled
end

function mercenaries:HorsesSet(on)
    self.HorsesEnabled = on and true or false
    self._horsesLoaded = true
    self:SaveString("MercHorses", self.HorsesEnabled and "1" or "0")
    -- Takes effect now rather than at the next mount poll: dropping the global puts every
    -- merc's tree back on its on-foot arm and hands the standing horses to the orphan
    -- sweep in mercenaries_target_selection.lua, which despawns them within a tick.
    if not self.HorsesEnabled then _G.PlayerMounted = false end
    diffLog("merc horses " .. (self.HorsesEnabled and "on" or "off"))
    Game.SendInfoText(self.HorsesEnabled and 'merc_info_horses_on' or 'merc_info_horses_off', false, 0, 4)
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
    if self.PatrolQuietMult then
        local m = self:PatrolQuietMult()
        diffLog(string.format("roads: a gang at most every %.0fs, %.0fs after a fight (x%.2f)",
            (self.PatrolQuietSecs or 0) * m, (self.PatrolPostFightSecs or 0) * m, m))
    end
    local parts = {}
    for _, k in ipairs(self.DifficultyOrder) do
        table.insert(parts, k .. (k == self.Difficulty and " <-" or ""))
    end
    diffLog("tiers: " .. table.concat(parts, ", "))
end
