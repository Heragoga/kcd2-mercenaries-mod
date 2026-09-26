-- A parade ground: one man per (style, tier), stood in a grid so every uniform in the
-- wardrobe can be compared side by side in one look.
--
-- Written for judging whether the armour mods in references/armor mods/ are worth new
-- styles, but it earns its keep on the 17 that already exist: the "Skalitz reverts to
-- generic" bug (docs/outfits.md) was two presets per tier being byte-identical, which is
-- invisible one merc at a time and obvious in a row of three.
--
--   merc_outfit_matrix          every style, all three tiers
--   merc_outfit_matrix 6        one style, all three tiers
--   merc_outfit_matrix 6 12     a range of styles
--   merc_outfit_matrix clear    take them away
--
-- These are NOT hires. They carry their own name prefix, so the company never counts
-- them, they do not follow, they are not saved, and merc_purge_npcs sweeps them with
-- everything else. The row is laid out to the player's RIGHT and marches forward, so it
-- never spawns on top of him.

mercenaries.MatrixNpcs      = {}
mercenaries.MatrixPrefix    = "MercShowcase_"
mercenaries.MatrixTiers     = { "weak", "medium", "strong" }
mercenaries.MatrixTierGap   = 2.2      -- metres between tiers of one style
mercenaries.MatrixStyleGap  = 3.0      -- metres between styles
mercenaries.MatrixStandoff  = 6.0      -- metres in front of the player

local function mLog(s) System.LogAlways("[Matrix] " .. tostring(s)) end

function mercenaries:MatrixStyleName(i)
    local names = {
        "Generic Mercs", "Bandits", "Cumans", "Leipa", "Kuttenberg", "Skalitz",
        "(custom uniform)", "Prague", "Sigismund", "Order of the Red Star", "Bergov",
        "Nebakov", "Semine", "Pisek", "Teutonic Order", "Ruthard", "Papal Legate",
    }
    return names[i] or ("style " .. tostring(i))
end

function mercenaries:MatrixSoulFor(tier)
    local list = (self.Souls or {})[tier] or (self.Souls or {})["weak"]
    if not list or #list == 0 then return nil end
    return list[math.random(#list)]
end

-- One man. The tier has to be in the NAME: EquipMercenary parses it out of there with a
-- plain string.find for '_medium_' / '_strong_', so a showcase merc is named to satisfy
-- exactly that and nothing else about the naming matters.
function mercenaries:MatrixSpawnOne(style, tier, pos, yaw)
    local soul = self:MatrixSoulFor(tier)
    if not soul then mLog("no soul pool for tier " .. tostring(tier)); return nil end
    local name = string.format("%s%s_s%02d_%d_%s", self.MatrixPrefix, tier, style,
                               math.random(1000, 9999), soul)
    local ent
    local ok, err = pcall(function()
        System.SpawnEntity({
            class = "NPC",
            name = name,
            position = pos,
            orientation = { x = math.cos(yaw + math.pi), y = math.sin(yaw + math.pi), z = 0 },
            -- Never written to a save: a parade ground is a diagnostic, and 51 NPCs in a
            -- save file is exactly the residue docs/save-footprint.md spent a day on.
            properties = self:NoSaveProps({ guidSharedSoulId = soul }),
        })
        ent = System.GetEntityByName(name)
    end)
    if not ok or not ent then
        mLog(string.format("style %d %s: spawn failed (%s)", style, tier, tostring(err)))
        return nil
    end
    -- The wardrobe itself. Style 7 has no pool - EquipMercenary falls through to the
    -- custom uniform, which is whatever the player last handed the quartermaster, so it
    -- is spawned and labelled rather than skipped: seeing it empty IS the information.
    pcall(function() self:EquipMercenary(ent, style) end)
    pcall(function() self:EquipMercenaryWeapon(ent, style, style) end)
    table.insert(self.MatrixNpcs, ent)
    return ent
end

function mercenaries:MatrixSpawn(line)
    local a = self:CmdArgs(line)
    local w = string.lower(tostring(a[1] or ""))
    if w == "clear" or w == "off" then return self:MatrixClear() end

    local first = tonumber(a[1]) or 1
    local last  = tonumber(a[2]) or (a[1] and first or 17)
    if first < 1 then first = 1 end
    if last > 17 then last = 17 end
    if last < first then last = first end

    if #self.MatrixNpcs > 0 then
        mLog("a parade is already standing - merc_outfit_matrix clear first")
        return
    end
    if not player then return end

    local o = player:GetWorldPos()
    local ang; pcall(function() ang = player:GetWorldAngles() end)
    local yaw = (ang and ang.z) or 0
    -- Forward is where the player looks; right is 90 degrees off it. Styles march
    -- forward, tiers spread to the right, so the whole grid is in front and readable.
    local fx, fy = math.cos(yaw), math.sin(yaw)
    local rx, ry = math.cos(yaw - math.pi / 2), math.sin(yaw - math.pi / 2)

    local n = 0
    for style = first, last do
        local row = (style - first) * (self.MatrixStyleGap or 3.0) + (self.MatrixStandoff or 6.0)
        for ti, tier in ipairs(self.MatrixTiers) do
            local col = (ti - 1) * (self.MatrixTierGap or 2.2)
            local pos = { x = o.x + fx * row + rx * col,
                          y = o.y + fy * row + ry * col,
                          z = o.z }
            if self.CampSnapToGround then
                pcall(function() pos = self:CampSnapToGround(pos) end)
            end
            if self:MatrixSpawnOne(style, tier, pos, yaw) then n = n + 1 end
        end
        mLog(string.format("row %2d at %4.1fm: %s", style, row, self:MatrixStyleName(style)))
    end
    mLog(string.format("%d man/men standing: styles %d-%d, tiers %s left to right",
                       n, first, last, table.concat(self.MatrixTiers, "/")))
    mLog("walk down the rows; merc_outfit_matrix clear takes them away.")
    if first <= 7 and last >= 7 then
        mLog("row 7 is the CUSTOM uniform - it has no preset pool, so it shows whatever")
        mLog("the quartermaster was last given. Bare is the correct answer if never set.")
    end
end

function mercenaries:MatrixClear()
    local n = 0
    for _, e in ipairs(self.MatrixNpcs or {}) do
        if e and e.id then
            pcall(function() System.RemoveEntity(e.id) end)
            n = n + 1
        end
    end
    self.MatrixNpcs = {}
    mLog(n .. " removed")
end

-- Belt and braces for a reload: the entities are not saved, but the Lua handles outlive
-- the load, and a stale handle in the list would make the next spawn refuse.
function mercenaries:MatrixOnLoad()
    self.MatrixNpcs = {}
end
