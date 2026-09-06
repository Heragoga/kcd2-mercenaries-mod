-- Every console command a player can type, in one file. See docs/console.md.
--
-- Loaded FIRST (mercenaries.lua's LoadScript block), because every other module
-- registers its authoring/diagnostic commands through mercenaries:DevCommand as it
-- loads. Those are collected, not registered: the console shows the player set only
-- until someone types merc_dev.
--
-- Command bodies are strings the engine evaluates when the command is typed, so a
-- body may name a function that is defined in a module loaded after this one.
--
-- Arguments: '%line' (the whole argument line) is the ONLY substitution the engine
-- performs - %1, %2 are silently left as literal text. Commands that take arguments
-- therefore pass '%line' and split it themselves.

-- ==== dev command gate ====
-- The collector itself (DevCommands, DevCommand) lives at the top of mercenaries.lua:
-- that file registers commands of its own before it loads this one.

function mercenaries:DevCommandsEnable()
    if self.DevCommandsOn then
        System.LogAlways("[MercCmd] dev commands already on (" .. #self.DevCommands .. ")")
        return
    end
    -- Only in a -devmode launch. The dev set includes the automated test campaigns
    -- (bench/torture), several of which QUIT the game when they finish - a player who
    -- types merc_dev out of curiosity in a normal launch must not get those armed.
    -- Fail-open only when the scriptbind itself is missing on some build (pcall fails):
    -- an explicit false is an explicit refusal.
    local isDev = nil
    local ok = pcall(function() isDev = System.IsDevModeEnable() end)
    if ok and isDev == false then
        System.LogAlways("[MercCmd] merc_dev refused: not a -devmode launch. Start the game")
        System.LogAlways("[MercCmd] with the -devmode command line switch to use dev commands.")
        return
    end
    self.DevCommandsOn = true
    local n = 0
    for _, c in ipairs(self.DevCommands) do
        local ok = pcall(function() System.AddCCommand(c.name, c.body, c.desc) end)
        if ok then n = n + 1 end
    end
    System.LogAlways("[MercCmd] " .. n .. " of " .. #self.DevCommands .. " dev command(s) registered")
    System.LogAlways("[MercCmd] merc_dev_list prints them; anything that fails to register is still")
    System.LogAlways("[MercCmd] reachable as: merc_lua mercenaries:TheFunction()")
end

function mercenaries:DevCommandList()
    System.LogAlways("[MercCmd] " .. #self.DevCommands .. " dev command(s):")
    for _, c in ipairs(self.DevCommands) do
        System.LogAlways(string.format("  %-32s %s", c.name, c.desc))
    end
end

-- ==== shared helpers ====

local function cLog(msg)
    System.LogAlways("[MercCmd] " .. tostring(msg))
end

-- Split an argument line into words. Every command that takes arguments goes
-- through this, so they all accept the same "merc_x 12 bandit" shape.
-- The console hands arguments back ALREADY QUOTED. Typing `merc_purge_savers yes`
-- substitutes %line as  "yes"  - quotes included - so a body written Func('%line')
-- receives five characters where it wanted three. Measured 2026-09-04, straight off the
-- echo in needYes:  (received ""yes"" - that is not a confirmation).
--
-- Every argument in this mod comes through here, so the quotes come off once, here.
function mercenaries:CmdClean(line)
    local s = tostring(line or "")
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    local inner = string.match(s, '^"(.*)"$') or string.match(s, "^'(.*)'$")
    if inner then s = inner end
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    return s
end

function mercenaries:CmdArgs(line)
    local a = {}
    for w in string.gmatch(self:CmdClean(line), "%S+") do
        a[#a + 1] = self:CmdClean(w)
    end
    return a
end

-- Boolean switches. This used to be written inline as `mercenaries:CmdBool('%line')`, which
-- with the quotes in play evaluated tonumber('"0"') = nil, and nil ~= 0 is TRUE: nine
-- switches could be turned on and never off. No argument still means on, as before.
function mercenaries:CmdBool(line)
    local s = string.lower(self:CmdClean(line))
    return not (s == "0" or s == "off" or s == "false" or s == "no")
end

-- The enemy groups a player gets a command family for, and the word used in the
-- command name. Deliberately a literal list rather than a read of EnemyGroups:
-- this file loads before mercenaries_spawning.lua, and the console command names
-- must be stable anyway. `recruit` (siege levy filler) is not offered.
mercenaries.CmdGroups = {
    { word = "bandit",    key = "bandit",    label = "Bandits" },
    { word = "looter",    key = "looter",    label = "Looters" },
    { word = "sigismund", key = "sigi",      label = "Sigismund's soldiers" },
    { word = "knight",    key = "knight",    label = "Sigismund's knights" },
    { word = "prague",    key = "prague",    label = "Prague regiment" },
    { word = "cuman",     key = "cuman",     label = "Cumans" },
    { word = "ruthenian", key = "ruthenian", label = "Ruthenians" },
}

-- ==== hiring ====

function mercenaries:CmdHire(tier, line)
    local n = tonumber(self:CmdArgs(line)[1]) or 5
    if n < 1 then n = 1 end
    self:Hire(0, n, tier)
end

function mercenaries:CmdHireArchers(line)
    local n = tonumber(self:CmdArgs(line)[1]) or 5
    if n < 1 then n = 1 end
    self:HireArcher(0, n)
end

-- A whole company in one command. Archers first: both hires check the same cap, and
-- a full company of foot would leave no room for the bowmen the army is named for.
function mercenaries:CmdHireArmy(archers, melee, tier)
    self:HireArcher(0, archers)
    self:Hire(0, melee, tier or "medium")
    cLog(string.format("army: %d archer(s) + %d foot (cap %d)", archers, melee, self.MaxCompanions))
end

-- Uniform by number, validated: ChangeMercOutfit takes an index and a console
-- argument arrives as text.
--
-- The cap was 6 and stayed there while eleven more liveries were added, so the console
-- could not reach styles 8-17 that the dialogue wheel offers. 17 is the real ceiling;
-- 7 is the custom uniform, which is not a wardrobe entry and is rejected by name.
-- See docs/outfits.md for the numbering (do not renumber - EnemyOutfitOverride and the
-- merc_battle commands assume it).
mercenaries.CmdOutfitMax = 17

mercenaries.CmdOutfitNames = {
    "Generic", "Bandit", "Cuman", "Leipa", "Kuttenberg", "Skalitz",
    "(custom uniform - use the quartermaster)", "Prague", "Sigismund",
    "Order of the Red Star", "Bergov", "Nebakov", "Semine", "Pisek",
    "Teutonic Order", "Ruthard", "Papal Legate",
}

function mercenaries:CmdOutfit(line)
    local n = tonumber(self:CmdArgs(line)[1])
    if not n or n < 1 or n > self.CmdOutfitMax or n == (self.CustomOutfitIndex or 7) then
        cLog("uniform 1-" .. self.CmdOutfitMax .. ":")
        for i, nm in ipairs(self.CmdOutfitNames) do
            cLog(string.format("  %2d %s", i, nm))
        end
        return
    end
    self:ChangeMercOutfit(n)
end

-- ==== enemies ====

-- A row of them in front of you. The sandbox spawn: no march, no orders, no camp
-- needed - they are simply there and hostile.
function mercenaries:CmdSpawnGroup(groupKey, line, default)
    local n = tonumber(self:CmdArgs(line)[1]) or default or 10
    if n < 1 then n = 1 end
    self:SpawnEnemyGroup(groupKey, n)
end

-- How far out a raid forms up when there is no camp to march on.
mercenaries.CmdRaidDistance = 80.0
mercenaries.CmdRaidSpacing  = 1.8
mercenaries.CmdRaidRank     = 10

-- An attack, not a spawn. With a camp standing this is the wall battle's own raid
-- (formed up out of sight, marched to a gate); without one they form up at distance
-- and are pointed at the player, which is what ForcedTargetOf is for - left to their
-- own scan the far half of the block never sees anybody and stands there.
function mercenaries:CmdRaid(groupKey, line)
    local a = self:CmdArgs(line)
    local n = tonumber(a[1]) or 12
    if n < 1 then n = 1 end

    if self.CampActive and self.CampCenter and self.WBRaid then
        self:WBRaid(n .. " " .. groupKey)
        return
    end

    if not player then return end
    local pp = player:GetWorldPos()
    if not pp then return end

    local ang = math.random() * 2 * math.pi
    local ax, ay = math.cos(ang), math.sin(ang)
    local rx, ry = -ay, ax
    local dist = self.CmdRaidDistance
    local origin = { x = pp.x + ax * dist, y = pp.y + ay * dist, z = pp.z }
    if self.CampSnapToGround then origin = self:CampSnapToGround(origin) end
    local yaw = math.atan2(-ay, -ax)

    local tgt
    pcall(function() tgt = player.this and player.this.id end)

    local spawned = 0
    for i = 1, n do
        local rank = math.floor((i - 1) / self.CmdRaidRank)
        local file = (i - 1) % self.CmdRaidRank
        local inRank = math.min(n - rank * self.CmdRaidRank, self.CmdRaidRank)
        local lat = (file - (inRank - 1) / 2) * self.CmdRaidSpacing
        local dep = rank * self.CmdRaidSpacing
        local p = { x = origin.x + rx * lat + ax * dep, y = origin.y + ry * lat + ay * dep, z = origin.z }
        if self.FindValidGround then p = self:FindValidGround(p, origin.z, 3.0, 0.5, 16) end
        local e = self:SpawnEnemyAt(groupKey, (i % 4 == 0), p, yaw)
        if e then
            spawned = spawned + 1
            if tgt and self.ForcedTargetOf then
                if e.this and e.this.id then self.ForcedTargetOf[tostring(e.this.id)] = tgt end
                local w = XGenAIModule.GetMyWUID(e)
                if w then self.ForcedTargetOf[tostring(w)] = tgt end
            end
            pcall(function() if self.LodPinEntity then self:LodPinEntity(e) end end)
        end
    end
    cLog(string.format("%d %s marching on you from %dm", spawned, groupKey, math.floor(dist)))
end

-- A gang of them walking a real road route near you. Falls back to a formed-up
-- group where the level has no recorded routes.
function mercenaries:CmdPatrol(groupKey, line)
    local n = tonumber(self:CmdArgs(line)[1])
    local haveRoutes = (self.PatrolRouteData and #self.PatrolRouteData > 0)

    if haveRoutes and not n and self.LivePatrolHere then
        self.PatrolForceGroup = groupKey
        local ok, err = pcall(function() self:LivePatrolHere() end)
        self.PatrolForceGroup = nil
        if ok then return end
        cLog("roaming patrol failed (" .. tostring(err) .. ") - forming one up instead")
    end

    if self.PatrolSpawn then self:PatrolSpawn((n or 6) .. " " .. groupKey) end
end

-- Remove everything the enemy commands put on the ground: group spawns, raids,
-- patrol men and their leaders. Bodies included - a battlefield of corpses is the
-- other half of "clear it up".
mercenaries.CmdClearRadius = 400.0
mercenaries.CmdClearPrefixes = { "SpawnedEnemy_", "SpawnedRenegade_", "SpawnedPatrol_", "SpawnedPatrolman_" }

function mercenaries:CmdEnemyClear()
    local n = 0
    pcall(function()
        if self.WBRaidClear then pcall(function() self:WBRaidClear() end) end
        if self.PatrolClearMen then pcall(function() self:PatrolClearMen() end) end
        if self.LivePatrolClear then pcall(function() self:LivePatrolClear() end) end

        local pp = player and player:GetWorldPos()
        local ents = pp and System.GetPhysicalEntitiesInBoxByClass(pp, self.CmdClearRadius, "NPC")
                        or System.GetEntitiesByClass("NPC")
        for _, e in pairs(ents or {}) do
            local name = (e and e.GetName and e:GetName()) or ""
            for _, prefix in ipairs(self.CmdClearPrefixes) do
                if string.find(name, prefix, 1, true) == 1 then
                    pcall(function() System.RemoveEntity(e.id) end)
                    n = n + 1
                    break
                end
            end
        end
    end)
    cLog("removed " .. n .. " spawned enemy/patrol NPC(s)")
end

-- ==== set-piece battle ====

-- Two armies drawn up facing each other with their archers behind, the player
-- standing between them. The mercs are real hires (they join the squad and the
-- survivors follow you home); the enemy side comes out of the enemy-group system.
--
--   merc_battle [foot per side] [enemy group] [archers per side] [metres apart]
--
-- Defaults are a fight that fits inside the companion cap with room to spare.
mercenaries.CmdBattleFoot    = 12
mercenaries.CmdBattleArchers = 4
mercenaries.CmdBattleGap     = 34.0
mercenaries.CmdBattleFile    = 1.4     -- side to side, within a rank
mercenaries.CmdBattleRank    = 1.8     -- front to back, between ranks
mercenaries.CmdBattleWidth   = 10      -- men per rank
mercenaries.CmdBattleArcherBack = 7.0  -- how far the bowmen stand behind their foot

function mercenaries:CmdBattle(line)
    local a = self:CmdArgs(line)
    local foot    = tonumber(a[1]) or self.CmdBattleFoot
    local group   = (a[2] and a[2] ~= "") and a[2] or "bandit"
    local archers = tonumber(a[3]) or self.CmdBattleArchers
    local gap     = tonumber(a[4]) or self.CmdBattleGap

    if not (player and self.EnemyGroups and self.EnemyGroups[group]) then
        local names = {}
        for _, g in ipairs(self.CmdGroups) do table.insert(names, g.key) end
        cLog("unknown group '" .. tostring(group) .. "' - try: " .. table.concat(names, ", "))
        return
    end
    if foot < 1 then foot = 1 end
    if archers < 0 then archers = 0 end

    self:Recount()
    local room = self.MaxCompanions - (_G.MercCount or 0)
    if (foot + archers) > room then
        cLog(string.format("company cap: room for %d more, asked for %d - trimming the merc line",
                           room, foot + archers))
        archers = math.min(archers, math.max(room - 1, 0))
        foot = math.max(math.min(foot, room - archers), 0)
        if foot < 1 then cLog("no room for a merc line at all - dismiss some men first"); return end
    end

    local pos = player:GetWorldPos()
    local ang; pcall(function() ang = player:GetWorldAngles() end)
    local yaw = (ang and ang.z) or 0
    local fx, fy = math.cos(yaw), math.sin(yaw)      -- towards the enemy line
    local rx, ry = -fy, fx                            -- across both fronts
    local enemyYaw = yaw + math.pi
    if enemyYaw > math.pi then enemyYaw = enemyYaw - 2 * math.pi end

    -- Rank/file offset for the i-th man of a block, measured from the block's centre.
    local function slot(i, count, sign)
        local rank = math.floor((i - 1) / self.CmdBattleWidth)
        local file = (i - 1) % self.CmdBattleWidth
        local inRank = math.min(count - rank * self.CmdBattleWidth, self.CmdBattleWidth)
        return (file - (inRank - 1) / 2) * self.CmdBattleFile, rank * self.CmdBattleRank * sign
    end

    local function place(baseFwd, lat, back)
        local p = { x = pos.x + fx * (baseFwd + back) + rx * lat,
                    y = pos.y + fy * (baseFwd + back) + ry * lat,
                    z = pos.z }
        if self.FindValidGround then p = self:FindValidGround(p, pos.z, 3.0, 0.5, 16) end
        return p
    end

    local half = gap / 2
    -- Strongest to the front rank, as a line of battle is actually drawn up.
    local tiers = {}
    for i = 1, foot do
        tiers[i] = (i <= foot / 3 and "strong") or (i <= (2 * foot) / 3 and "medium") or "weak"
    end

    local ok, err = pcall(function()
        for i = 1, foot do
            local lat, back = slot(i, foot, -1)
            self:SpawnMercAt(tiers[i], place(-half, lat, back), yaw)
        end
        for i = 1, archers do
            local lat, back = slot(i, archers, -1)
            self:SpawnArcherAt(place(-half, lat, back - self.CmdBattleArcherBack), yaw)
        end
        for i = 1, foot do
            local lat, back = slot(i, foot, 1)
            self:SpawnEnemyAt(group, false, place(half, lat, back), enemyYaw)
        end
        for i = 1, archers do
            local lat, back = slot(i, archers, 1)
            self:SpawnEnemyAt(group, true, place(half, lat, back + self.CmdBattleArcherBack), enemyYaw)
        end
    end)
    if not ok then cLog("battle error: " .. tostring(err)); return end

    -- The men just spawned are hires like any other: the squad must know it has them.
    if _G.MercenariesDismissed ~= false then
        _G.MercenariesDismissed = false
        self:SaveString("MercenariesDismissed", "0")
    end
    if _G.MercIdle ~= false then
        _G.MercIdle = false
        _G.MercPersistentIdleFlag = false
        self:SaveString("MercIdlePersistent", "0")
    end
    self:Recount()
    pcall(function() self:BeginFollowVerify("battle") end)

    cLog(string.format("battle: %d foot + %d archers a side, %s, %dm apart",
                       foot, archers, group, math.floor(gap)))
end

-- ==== help ====

mercenaries.CmdHelpSections = {
    { "SQUAD",      { "merc_status", "merc_heal", "merc_follow", "merc_wait", "merc_dismiss", "merc_loot", "merc_loot_stop" } },
    { "HIRING",     { "merc_hire", "merc_hire_weak", "merc_hire_strong", "merc_hire_female",
                      "merc_hire_archers", "merc_hire_army_small", "merc_hire_army_big" } },
    { "ORDERS",     { "merc_hold", "merc_hold_end", "merc_escort", "merc_escort_end",
                      "merc_focus", "merc_focus_clear",
                      "merc_stance_attack", "merc_stance_default", "merc_stance_defend", "merc_stance_holdfire" } },
    { "FORMATION",  { "merc_form_column", "merc_form_line", "merc_form_square", "merc_form_wedge",
                      "merc_form_circle", "merc_form_escort", "merc_form_vanilla",
                      "merc_form_keepshape", "merc_form_relaxed", "merc_form_movehistory" } },
    { "GEAR",       { "merc_outfit", "merc_weapon_random", "merc_weapon_swordshield", "merc_weapon_axeshield",
                      "merc_weapon_longsword", "merc_weapon_maceshield", "merc_weapon_shortsword",
                      "merc_weapon_mace", "merc_weapon_axe", "merc_weapon_polearm",
                      "merc_gear_open", "merc_gear_close", "merc_gear_apply", "merc_gear_clear" } },
    { "ARCHERS",    { "merc_archer_skirmish", "merc_archer_melee", "merc_archer_hold",
                      "merc_archer_bow", "merc_archer_crossbow", "merc_archer_handcannon" } },
    { "CAMP",       { "merc_camp_make", "merc_camp_break", "merc_camp_recall",
                      "merc_camp_deploy_all", "merc_camp_deploy_half", "merc_camp_return_all",
                      "merc_camp_remove", "merc_camp_party",
                      "merc_camp_marker", "merc_camp_compass",
                      "merc_gate_open", "merc_gate_close" } },
    { "FIGHTS",     { "merc_battle", "merc_raborsch", "merc_raborsch_clear", "merc_clear_enemies", "merc_raid_now" } },
    { "OPTIONS",    { "merc_difficulty", "merc_upkeep", "merc_encounters", "merc_patrols", "merc_patrols_perday",
                      "merc_status_icons", "merc_horses", "merc_horses_max", "merc_autodismount", "merc_lod_quality",
                      "merc_mqstash", "merc_travel_stow", "merc_travelprobe", "merc_travelstate", "merc_horsestats", "merc_whystand", "merc_formprobe", "merc_roster", "merc_roster_nosave",
                      "merc_hide_others" } },
    { "UNINSTALL",  { "merc_uninstall", "merc_save_audit", "merc_items",
                      "merc_purge_world", "merc_purge_savers" } },
    { "ADVANCED",   { "merc_dev", "merc_lua" } },
}

function mercenaries:PrintHelp()
    System.LogAlways("=== MERCENARIES - console commands ===")
    for _, section in ipairs(self.CmdHelpSections) do
        System.LogAlways("-- " .. section[1])
        for _, name in ipairs(section[2]) do
            System.LogAlways(string.format("  %-24s %s", name, self.CmdHelpText[name] or ""))
        end
    end
    System.LogAlways("-- ENEMIES  (one per group: " .. self:CmdGroupWords() .. ")")
    System.LogAlways("  merc_spawn_<group> [n]   a row of them in front of you (default 10)")
    System.LogAlways("  merc_raid_<group> [n]    they form up at distance and come for you (default 12)")
    System.LogAlways("  merc_patrol_<group>      a gang of them walking a road nearby")
    System.LogAlways("  merc_spawn_heinrich      one overpowered champion")
    System.LogAlways("=== see docs/console.md for the full reference ===")
end

function mercenaries:CmdGroupWords()
    local w = {}
    for _, g in ipairs(self.CmdGroups) do table.insert(w, g.word) end
    return table.concat(w, ", ")
end

-- ==== registration ====
-- One line per command. This block IS the player-facing command list; anything not
-- here is a dev command and needs merc_dev.

mercenaries.CmdHelpText = {}

local function cmd(name, body, desc)
    mercenaries.CmdHelpText[name] = desc
    System.AddCCommand(name, body, desc)
end

-- squad
cmd("merc_help",    "mercenaries:PrintHelp()",        "List the mercenary commands")
cmd("merc_status",  "mercenaries:ShowSquadStatus()",  "Squad report: count, health, orders, archer stance")
cmd("merc_heal",    "mercenaries:HealMercsForFlatFee()", "Heal and wash the whole company for a flat fee")
cmd("merc_follow",  "mercenaries:SetState('follow')", "Everyone falls in behind you")
cmd("merc_wait",    "mercenaries:SetState('wait')",   "Everyone holds where they are")
cmd("merc_dismiss", "mercenaries:SetState('dismiss')","Pay off the whole company")
cmd("merc_loot",    "mercenaries:LootSweepForce()",   "Send the men to strip the bodies around you")
cmd("merc_loot_stop", "mercenaries:LootSweepStop()",  "Call off the loot sweep")

-- hiring
cmd("merc_hire",         "mercenaries:CmdHire('medium', '%line')", "Hire seasoned foot: merc_hire [count] (default 5)")
cmd("merc_hire_weak",    "mercenaries:CmdHire('weak', '%line')",   "Hire raw foot: merc_hire_weak [count]")
cmd("merc_hire_strong",  "mercenaries:CmdHire('strong', '%line')", "Hire veteran foot: merc_hire_strong [count]")
cmd("merc_hire_female",  "mercenaries:CmdHireFemale('%line')",     "Hire women: merc_hire_female [count]")
cmd("merc_hire_archers", "mercenaries:CmdHireArchers('%line')",    "Hire archers: merc_hire_archers [count]")
cmd("merc_hire_army_small", "mercenaries:CmdHireArmy(10, 20, 'medium')", "A company: 10 archers and 20 foot")
cmd("merc_hire_army_big",   "mercenaries:CmdHireArmy(15, 35, 'medium')", "A full army: 15 archers and 35 foot")

-- orders
cmd("merc_hold",       "mercenaries:HoldBegin()",   "Hold this ground: nobody chases")
cmd("merc_hold_end",   "mercenaries:HoldEnd()",     "Release the hold and follow again")
cmd("merc_escort",     "mercenaries:EscortBegin()", "Escort whoever you are looking at")
cmd("merc_escort_end", "mercenaries:EscortEnd()",   "Stop escorting")
cmd("merc_focus",      "mercenaries:OrderFocusTarget()",  "Call the target you are looking at for the whole company")
cmd("merc_focus_clear","mercenaries:OrderFocusClear('console')", "Drop the called target")
cmd("merc_stance_attack",  "mercenaries:SetEngageStance('aggressive')", "Attack anything hostile on sight")
cmd("merc_stance_default", "mercenaries:SetEngageStance('default')",    "Fight whoever fights you or the player")
cmd("merc_stance_defend",  "mercenaries:SetEngageStance('defend')",     "Never start a fight; defend yourselves")
cmd("merc_stance_holdfire","mercenaries:SetEngageStance('hold')",       "Hold fire even under attack")

-- formation
cmd("merc_form_column", "mercenaries:SetFormationShape('column')", "Formation: column of twos")
cmd("merc_form_line",   "mercenaries:SetFormationShape('line')",   "Formation: ranks abreast")
cmd("merc_form_square", "mercenaries:SetFormationShape('square')", "Formation: square block")
cmd("merc_form_wedge",  "mercenaries:SetFormationShape('wedge')",  "Formation: arrowhead")
cmd("merc_form_circle", "mercenaries:SetFormationShape('circle')", "Formation: ring around you")
cmd("merc_form_escort", "mercenaries:SetFormationShape('escort')", "Formation: flanking files")
cmd("merc_form_vanilla","mercenaries:SetFormationShape('vanilla')","Formation: the stock game preset")
cmd("merc_form_keepshape",   "mercenaries:SetFormationMode(1)", "Hold the shape rigidly (default)")
cmd("merc_form_relaxed",     "mercenaries:SetFormationMode(0)", "Loose escort instead of a rigid shape")
cmd("merc_form_movehistory", "mercenaries:SetFormationMode(2)", "Follow in your footsteps")

-- gear
cmd("merc_outfit",             "mercenaries:CmdOutfit('%line')", "Uniform: merc_outfit 1-17 (type merc_outfit for the list)")
cmd("merc_weapon_random",      "mercenaries:ChangeMercWeapon(1)", "Loadout: mixed")
cmd("merc_weapon_swordshield", "mercenaries:ChangeMercWeapon(2)", "Loadout: sword and shield")
cmd("merc_weapon_axeshield",   "mercenaries:ChangeMercWeapon(3)", "Loadout: axe and shield")
cmd("merc_weapon_longsword",   "mercenaries:ChangeMercWeapon(4)", "Loadout: longsword")
cmd("merc_weapon_maceshield",  "mercenaries:ChangeMercWeapon(5)", "Loadout: mace and shield")
cmd("merc_weapon_shortsword",  "mercenaries:ChangeMercWeapon(6)", "Loadout: shortsword")
cmd("merc_weapon_mace",        "mercenaries:ChangeMercWeapon(7)", "Loadout: mace")
cmd("merc_weapon_axe",         "mercenaries:ChangeMercWeapon(8)", "Loadout: axe")
cmd("merc_weapon_polearm",     "mercenaries:ChangeMercWeapon(9)", "Loadout: polearm")
cmd("merc_gear_open",  "mercenaries:GearOpenWardrobe()",  "Put down the wardrobe chest to build a custom uniform")
cmd("merc_gear_close", "mercenaries:GearCloseWardrobe()", "Take the wardrobe chest away")
cmd("merc_gear_apply", "mercenaries:ChangeMercOutfit(mercenaries.CustomOutfitIndex)", "Put the whole company into the custom uniform")
cmd("merc_gear_clear", "mercenaries:GearClear()","Forget the custom uniform")

-- archers
cmd("merc_archer_skirmish",  "mercenaries:SetArcherStance('skirmish')", "Archers: shoot, fall back, keep shooting")
cmd("merc_archer_melee",     "mercenaries:SetArcherStance('melee')",    "Archers: close and fight hand to hand")
cmd("merc_archer_hold",      "mercenaries:SetArcherStance('hold')",     "Archers: stand and shoot, never advance")
cmd("merc_archer_bow",       "mercenaries:SetArcherWeaponType('bow')",       "Archers carry bows")
cmd("merc_archer_crossbow",  "mercenaries:SetArcherWeaponType('crossbow')",  "Archers carry crossbows")
cmd("merc_archer_handcannon","mercenaries:SetArcherWeaponType('handcannon')","Archers carry hand cannons")

-- camp
cmd("merc_camp_make",       "mercenaries:SpawnMercCamp()",   "Pitch the company camp here")
cmd("merc_camp_break",      "mercenaries:BreakMercCamp()",   "Break camp and march")
cmd("merc_camp_recall",     "mercenaries:RecallMercs()", "Call every man to you without breaking camp")
cmd("merc_camp_deploy_all", "mercenaries:CampTakeParty(1.0)",     "Take everyone the camp can spare")
cmd("merc_camp_deploy_half","mercenaries:CampTakeParty(0.5)",    "Take the best-equipped half out with you")
cmd("merc_camp_return_all", "mercenaries:CampReturnAll()",   "Send every deployed man back to camp")
cmd("merc_camp_remove",     "mercenaries:CmdRemoveUpgrade('%line')",
    "Take one camp improvement down: merc_camp_remove [1-11] (no argument lists them)")
cmd("merc_camp_party",      "mercenaries:CmdComposition('%line')",
    "Set what a deployed party is made of: merc_camp_party [1-8] (no argument lists them)")
cmd("merc_gate_open",       "mercenaries:GateSetAllOpen(true)",     "Open the camp gates")
cmd("merc_gate_close",      "mercenaries:GateSetAllOpen(false)",    "Shut the camp gates")

-- fights
cmd("merc_battle", "mercenaries:CmdBattle('%line')",
    "Two armies facing off, archers behind: merc_battle [foot] [group] [archers] [metres]")
cmd("merc_raborsch",       "mercenaries:SpawnRaborsch()",   "Raise the siege of Raborsch around you")
cmd("merc_raborsch_clear", "mercenaries:DespawnRaborsch()", "Strike the siege")
cmd("merc_clear_enemies",  "mercenaries:CmdEnemyClear()",   "Remove every spawned enemy, raid and patrol nearby")
cmd("merc_raid_now",       "mercenaries:RaidNow()",         "Launch the next scheduled camp raid immediately")

-- enemies, one family per group
for _, g in ipairs(mercenaries.CmdGroups) do
    cmd("merc_spawn_" .. g.word,
        "mercenaries:CmdSpawnGroup('" .. g.key .. "', '%line')",
        g.label .. ": a row of them in front of you (default 10)")
    cmd("merc_raid_" .. g.word,
        "mercenaries:CmdRaid('" .. g.key .. "', '%line')",
        g.label .. ": form up at distance and attack you or your camp (default 12)")
    cmd("merc_patrol_" .. g.word,
        "mercenaries:CmdPatrol('" .. g.key .. "', '%line')",
        g.label .. ": a gang of them walking a road nearby")
end
cmd("merc_spawn_heinrich", "mercenaries:SpawnEnemyGroup('heinrich', 1)",
    "One overpowered champion: best armour, St. George's sword")

-- options
cmd("merc_difficulty",   "mercenaries:DifficultySet('%line')", "Difficulty: easy | medium | difficult | extreme | impossible | horde")
cmd("merc_upkeep",       "mercenaries:UpkeepSet('%line')",     "Company survival: off | lenient | standard | harsh")
cmd("merc_encounters",   "mercenaries:EncountersSet(mercenaries:CmdBool('%line'))", "Random raids, patrols and ambushes: 0 | 1")
cmd("merc_patrols",      "mercenaries:LivePatrolSetEnabled(%line)", "Roaming road patrols: 0 | 1")
cmd("merc_patrols_perday", "mercenaries:PatrolPerDaySet('%line')", "Roaming gangs per day at most, 0 = no cap; no argument reports (saved)")
cmd("merc_mqstash",      "mercenaries:MQWStashSet(mercenaries:CmdBool('%line'))", "Send the company out of main-quest battles: 0 | 1 (saved)")
-- Player-tier on purpose: these are the instruments for the Malesov battle-stash test and
-- nobody should be typing merc_dev with an assault under way. See docs/malesov-test.md.
cmd("merc_mqwatch",      "mercenaries:MQWReport()",    "Main-quest battle watchdog: state + every probe's answer. Changes nothing")
cmd("merc_mqstash_now",  "mercenaries:MQWStashNow()",  "Force the company out of a battle now, without waiting for detection")
cmd("merc_mqunstash_now","mercenaries:MQWUnstashNow()","Bring a stashed company back to you now")
cmd("merc_status_icons", "mercenaries:StatusIconsSet(mercenaries:CmdBool('%line'))","Squad status icons on your HUD: 0 | 1")
-- The camp on the world map. On by default; it costs nothing until the map is opened.
cmd("merc_camp_marker",  "mercenaries:CampMarkerSet(mercenaries:CmdBool('%line'))", "Show the camp on the world map: 0 | 1 (saved)")
-- The compass marker is opt-in: its bearing carries an unverified offset (see
-- mercenaries_mapmarker.lua) and it costs a four-times-a-second redraw while it is up.
cmd("merc_camp_compass", "mercenaries:CampCompassSet(mercenaries:CmdBool('%line'))", "Also point at the camp on your compass: 0 | 1 (saved)")
cmd("merc_torches",      "mercenaries:CampTorchMaxSet('%line')", "Lit torches carried at night, 0 = none (each is a shadow-casting light): merc_torches 2")
-- Performance experiment knobs. Player-tier on purpose: these are what a user with a weaker
-- machine is told to try, and merc_dev should not stand between them and a playable framerate.
-- NO ARGUMENT. %line substitution has now failed twice on this console for these toggles,
-- and a toggle that silently does nothing is worse than no toggle: bake the value in.
cmd("merc_formation_off", "mercenaries:FormationEnabledSet(false)", "Engine formation OFF - squad reverts to the plain follow chain")
cmd("merc_formation_on",  "mercenaries:FormationEnabledSet(true)",  "Engine formation back ON")
cmd("merc_formation_status", "mercenaries:FormationEnabledStatus()", "Is the engine formation on, and if not, why")
cmd("merc_render_lod",   "mercenaries:RenderLodSet('%line')",  "Merc mesh detail, higher = coarser sooner (100 default, 0 = engine): merc_render_lod 150")
cmd("merc_render_pin",   "mercenaries:RenderPinSet('%line')",  "Never distance-cull mercs: merc_render_pin 1 | 0")
-- Simulation budget. Player-tier and no-argument for the same reason as merc_formation_off:
-- these are what a weak-CPU user is told to try, and they must not silently no-op.
cmd("merc_sim_trim",   "mercenaries:SimTierApply('trim')",   "Perf: stop simulating cloth that is far or tiny (visually free)")
cmd("merc_sim_lean",   "mercenaries:SimTierApply('lean')",   "Perf: simulate cloth only close and large")
cmd("merc_sim_off",    "mercenaries:SimTierApply('off')",    "Perf: cloth/socket SIMULATION off, skinning stays - best fps for least ugliness")
cmd("merc_sim_normal", "mercenaries:SimTierApply('normal')", "Simulation back to engine defaults")
cmd("merc_sim_status", "mercenaries:SimTierApply('')",       "Show simulation tiers and live cvar values")
cmd("merc_lowspec_on",     "mercenaries:LowSpecSet(true)",  "Weak CPU preset: cut AI detail budget, no battle LOD boost, lean cloth, no torches")
cmd("merc_lowspec_off",    "mercenaries:LowSpecSet(false)", "Undo the weak-CPU preset")
cmd("merc_lowspec_status", "mercenaries:LowSpecStatus()",   "What the weak-CPU preset is currently doing")
cmd("merc_detail_floor_off", "mercenaries:LodDetailFloorSet(true)",  "Battle: stop pinning every character to max detail - they LOD by distance, still fully visible")
cmd("merc_detail_floor_on",  "mercenaries:LodDetailFloorSet(false)", "Battle: pin every character to max detail again (default)")
cmd("merc_encounter_scale_half", "mercenaries:EncounterScaleSet(0.5)", "Spawn half the bodies in sieges/raids")
cmd("merc_encounter_scale_full", "mercenaries:EncounterScaleSet(1.0)", "Full authored encounter populations (default)")
cmd("merc_lod_boost_off",  "mercenaries:LodBoostSet(false)","Battle LOD boost fully off - WARNING: far ranks of a siege stop rendering. Prefer merc_lowspec_on")
cmd("merc_lod_boost_on",   "mercenaries:LodBoostSet(true)", "Battle AI LOD boost back on")
cmd("merc_btlod_on",     "mercenaries:BehaviourLodSet(true)",  "Behaviour LOD ON (default): idle mercs poll target acquisition less often")
cmd("merc_btlod_off",    "mercenaries:BehaviourLodSet(false)", "Behaviour LOD OFF - every merc runs the full acquisition pass every poll")
cmd("merc_btlod_status", "mercenaries:BehaviourLodStatus()",   "Is behaviour LOD on, and is the squad currently cheap or hot")
cmd("merc_scan_lean",  "mercenaries:ScanCandidatesSet(4)", "Combat: 4 target candidates per merc per poll (default)")
cmd("merc_scan_full",  "mercenaries:ScanCandidatesSet(8)", "Combat: 8 candidates - the old value, for A/B")
cmd("merc_scan_tiny",  "mercenaries:ScanCandidatesSet(2)", "Combat: 2 candidates - cheapest, watch for missed attackers")
cmd("merc_autodismount", "mercenaries:AutoDismountSet('%line')","Mercs get off their horses to fight: 0 | 1")
cmd("merc_horses",       "mercenaries:HorsesSet(mercenaries:CmdBool('%line'))", "Let the company use horses at all: 0 | 1 (saved)")
cmd("merc_horses_max",   "mercenaries:HorsesMaxSet('%line')", "Men out with you above which nobody rides, 0 = no limit (default); no argument reports (saved)")
cmd("merc_whystand",     "mercenaries:FollowWhyStand()", "One line per merc: distance, whether he moved, both heartbeats, and a verdict on why he is standing")
cmd("merc_formprobe",    "mercenaries:FormProbeSet(mercenaries:CmdBool('%line'))", "Log every formation-watch pass: who is flagged, how far from the player and the man ahead, and why")
cmd("merc_horsestats",    "mercenaries:TravelStaminaReport()", "Every horse reading the detector can see: its own speed and velocity, stamina, health, plus the player's speed and stamina")
cmd("merc_travelstate", "mercenaries:TravelStateReport()", "What every candidate actor-state getter answers right now (fastTravel=33, cutscene=34)")
cmd("merc_travelprobe", "mercenaries:TravelProbeSet(mercenaries:CmdBool('%line'))", "Log every travel-watch sample: dt, distance, Henry's own speed, mounted, clock ratio. For diagnosing fast travel")
cmd("merc_travel_stow",  "mercenaries:TravelStowSet(mercenaries:CmdBool('%line'))", "Bring the men who are with you along when you fast travel or sleep: 0 | 1 (saved)")
cmd("merc_roster",       "mercenaries:RosterSet(mercenaries:CmdBool('%line'))", "Rebuild the company from the saved roster on load: 0 | 1 (saved)")
cmd("merc_roster_nosave", "mercenaries:RosterNoSaveSet(mercenaries:CmdBool('%line'))", "Keep hired mercs out of the save entirely and rebuild them from the roster: 0 | 1 (saved). See docs/save-footprint.md")
cmd("merc_lod_quality",  "mercenaries:LodQualitySet('%line')", "Mesh detail in big battles: crisp | balanced | performance")
cmd("merc_hide_others",  "mercenaries:ToggleHideOthers()",     "Hide every NPC that is not yours (clean shots)")

-- ==== uninstall / save-footprint diagnostics ====
--
-- THE PROBLEM. "I hired a mercenary once, uninstalled the mod, and now my saves take a
-- minute to load instead of five seconds." The mod leaves three different kinds of thing
-- in a savegame, and each is a different suspect:
--
--   A. NPCs, horses and serialising props. Every merc/patrolman/enemy is a full NPC
--      entity whose soul, brain, faction and skald character are defined in this mod's
--      XML tables. Without the mod those lookups all fail, per entity. Saves have been
--      measured holding 50 mercs + 27 patrolmen with a live roster of 8 (docs/performance.md).
--   B. The saver entities. ~60 hidden BasicEntity objects whose NAMES carry the mod's
--      state (mercenaries_saving.lua). BasicEntity is a VANILLA class, so these resolve
--      fine without the mod - they are the cheap suspect, and the one most likely to be
--      innocent.
--   C. Item classes in the player's inventory (tokens, quest documents, the mod's armour).
--      176 classes, all defined in item__mercenaries.xml.
--
-- WHICH ONE ACTUALLY COSTS THE MINUTE IS NOT KNOWN, so this is built as a bisection kit
-- rather than one button. Measure a normal load first, then for each stage: load the
-- ORIGINAL save, run the stage, save to a NEW slot, quit, uninstall the mod, load that
-- slot, and time it.
--
--   merc_save_audit     count everything (A, B and C) - changes nothing
--   merc_items          just the inventory side (C) in detail - changes nothing
--   merc_purge_world    remove A and C: NPCs, horses, props, inventory items, buffs
--   merc_purge_savers   remove B only: the hidden saver entities
--   merc_uninstall      remove all of it (A + B + C), the shipping user-facing path
--
-- Every step is pcall'd: a scrub that dies halfway is worse than one that never ran.

-- What counts as OURS, in one place, because there are two quite different kinds.
--
-- 1. Classes that exist only because this mod defines them. Every instance is ours and
--    no name test is wanted. These are also the WHITE PYRAMIDS a player sees in a save
--    the mod no longer backs: the class is gone, so the engine has nothing to draw.
mercenaries.UninstallOwnClasses = { "mercenaries_Prop", "mercenaries_Gate" }

-- 2. Vanilla classes we spawn INTO. Here only the name tells ours from the level's own,
--    so the test has to be exact - deleting a vanilla Light or Stash damages the save.
mercenaries.UninstallScanClasses = {
    "NPC", "Horse", "BasicEntity", "Stash", "Light", "Smithery", "SmartObjectHolder",
    "StanceSmartObject", "TagPoint", "ItemSlot", "ParticleEffect", "GeomEntity",
    "Ladder", "BedTrigger",
}

-- Names we give things. One flat list: what KIND a match is comes from its class, not
-- from which line matched, so no entry can be filed under two categories at once.
mercenaries.UninstallPrefixes = {
    -- squad, friends and the men who serve them
    "SpawnedFriend", "MercenaryCustomCompanion", "MercenaryHorse_", "MercQuartermaster_",
    -- roads and encounters
    "SpawnedPatrolman_", "SpawnedPatrol_", "SpawnedEnemy_", "SpawnedRenegade_",
    "SpawnedFoe_", "SpawnedTestNpc_",
    -- stations and the Aleksej arc
    "SpawnedTower_archer_", "AleksejTest_", "AleksejLodging_",
    "AlxChest_", "AlxSurcoatChest_", "AlxStool", "AlxBed", "AlxLodgeChest_",
    -- bandit camps, their quest variants, and the siege
    "BCampLight_", "BCampChest_", "BCampStation_",
    "BCampQLight_", "BCampQChest_", "BCampQStation_", "BCampQTowerCol_",
    "RaborschLight_", "RaborschChest_", "SiegeLight_", "SiegeChest_",
}

-- The workhorse. "Merc" followed by a CAPITAL covers some forty spawn sites - MercCamp*,
-- MercTower*, MercWall*, MercGate*, MercForgeRig_*, MercUpg*, MercNav*, MercPatrolWP_ -
-- without a list that goes stale the moment someone adds a prop. It is written as a
-- pattern rather than a prefix for one reason: "Merchant..." must not match it.
mercenaries.UninstallNamePattern = "^Merc%u"

-- Which item classes count as ours is decided by ONE list: mercenaries.ModItemIds,
-- generated from item__mercenaries.xml (tools/gen_item_ids.py). It is deliberately not
-- a guid-prefix test - this mod also references VANILLA items by guid (groschen, torch,
-- hammer, tongs) and deleting one of those out of a player's inventory would rob him.
-- Add rows to the XML and the generator must be re-run, or they are invisible here.
-- Same story for mercenaries.ModBuffIds (tools/gen_buff_ids.py).

-- Is this one of ours? Name only - the caller supplies the class.
function mercenaries:IsOurEntityName(name)
    if not name or name == "" then return false end
    for _, p in ipairs(self.UninstallPrefixes) do
        if string.find(name, p, 1, true) == 1 then return true end
    end
    return string.find(name, self.UninstallNamePattern) ~= nil
end

-- "npc" | "horse" | "prop" | "saver", or nil for not ours. The class decides the
-- category, so a chest named after a person is still a prop and a merc is still a merc.
function mercenaries:UninstallCategoryOf(name, class)
    if not name or name == "" then return nil end
    local pfx = self.SaverPrefix
    if pfx and string.sub(name, 1, string.len(pfx)) == pfx then return "saver" end
    if not self:IsOurEntityName(name) then return nil end
    if class == "NPC"   then return "npc"   end
    if class == "Horse" then return "horse" end
    return "prop"
end

-- ---- counting (read-only) ----

-- ONE scan of the world, shared by the audit and by every purge - they disagreed before,
-- which is exactly how mercenaries_Prop came to be counted by neither.
--
-- `remove` is the set of categories to delete, e.g. { prop = true }; pass nil to count
-- only. Returns found-counts, removed-counts and a per-class breakdown, since which
-- CLASS survives a save is the whole question the load-time hunt turns on.
function mercenaries:UninstallSweep(remove)
    local n    = { npc = 0, horse = 0, prop = 0, saver = 0 }
    local gone = { npc = 0, horse = 0, prop = 0, saver = 0 }
    local byClass = {}

    local function visit(cls, e, forced)
        local name = (e and e.GetName and e:GetName()) or ""
        local cat = forced or self:UninstallCategoryOf(name, cls)
        if not cat then return end
        n[cat] = (n[cat] or 0) + 1
        -- Savers are reported on their own line, so they must not swell the A breakdown:
        -- 25 of them under BasicEntity is what made "5 prop(s)" sit over a row reading 27.
        if cat ~= "saver" then byClass[cls] = (byClass[cls] or 0) + 1 end
        if remove and remove[cat] then
            pcall(function() System.RemoveEntity(e.id) end)
            gone[cat] = gone[cat] + 1
        end
    end

    for _, cls in ipairs(self.UninstallOwnClasses) do
        pcall(function()
            for _, e in pairs(System.GetEntitiesByClass(cls) or {}) do visit(cls, e, "prop") end
        end)
    end
    for _, cls in ipairs(self.UninstallScanClasses) do
        pcall(function()
            for _, e in pairs(System.GetEntitiesByClass(cls) or {}) do visit(cls, e) end
        end)
    end
    return n, gone, byClass
end

-- Kept for callers that predate the sweep. byClass replaces the old per-prefix table:
-- the class is what a save stores and what breaks when the mod is gone.
function mercenaries:CountWorldFootprint()
    local n, _, byClass = self:UninstallSweep(nil)
    return n.npc, n.horse, n.prop, byClass
end

-- How many saver entities are baked in. Counts the WORLD, not the cached map, because
-- older builds could leave duplicates the map collapses to one entry per tag.
function mercenaries:CountSaverEntities()
    local n, tags = 0, 0
    pcall(function()
        local pfx, plen = self.SaverPrefix, string.len(self.SaverPrefix)
        for _, e in pairs(System.GetEntitiesByClass("BasicEntity") or {}) do
            local name = e and e:GetName()
            if name and string.sub(name, 1, plen) == pfx then n = n + 1 end
        end
    end)
    pcall(function()
        self:SaverMap()
        for _ in pairs(self.SaverIds or {}) do tags = tags + 1 end
    end)
    return n, tags
end

-- Every mod item class the player is carrying. Returns total count, a list of
-- {id, n, note} rows, and how many distinct classes were found.
function mercenaries:CountModItems()
    if not (player and player.inventory) then return 0, {}, 0 end
    -- Friendly labels: the Lua constants name what a token actually DOES, which the
    -- item table's rows (all called loot_sackOfNails) do not.
    local label = {}
    for k, v in pairs(self) do
        if type(k) == "string" and type(v) == "string"
           and string.find(k, "TokenID", 1, true) == 1 then
            label[v] = k
        end
    end
    for k, v in pairs(self.AlxDocs or {}) do
        if type(v) == "string" then label[v] = "AlxDocs." .. tostring(k) end
    end

    local total, rows, classes = 0, {}, 0
    for _, r in ipairs(self.ModItemIds or {}) do
        local c = 0
        pcall(function() c = player.inventory:GetCountOfClass(r.id) or 0 end)
        if c > 0 then
            total = total + c
            classes = classes + 1
            rows[#rows + 1] = { id = r.id, n = c, tag = r.tag,
                                note = label[r.id] or r.name or "" }
        end
    end
    return total, rows, classes
end

function mercenaries:ItemAudit()
    local total, rows, classes = self:CountModItems()
    cLog("---- mod items in Henry's inventory ----")
    cLog(string.format("%d item(s) across %d of %d known mod item class(es)",
        total, classes, #(self.ModItemIds or {})))
    for _, r in ipairs(rows) do
        cLog(string.format("  %3d x %-9s %s  [%s]", r.n, r.tag, r.id, r.note))
    end
    if total == 0 then cLog("  (none - nothing of ours is in the inventory)") end
    -- Context only. GetCount is documented but unproven on this build, so it is printed
    -- rather than trusted: the count above comes from GetCountOfClass, which the mod
    -- already relies on everywhere else.
    local invTotal = nil
    pcall(function() invTotal = player.inventory:GetCount() end)
    if invTotal then
        cLog(string.format("  (inventory holds %s item(s) in total, ours and vanilla)",
             tostring(invTotal)))
    end
    return total
end

function mercenaries:SaveAudit()
    local found, _, byClass = self:UninstallSweep(nil)
    local savers, tags = self:CountSaverEntities()
    local items, _, classes = self:CountModItems()
    local persistentBuffs = 0
    for _, bf in ipairs(self.ModBuffIds or {}) do
        if bf.persistent then persistentBuffs = persistentBuffs + 1 end
    end

    cLog("==== what this mod has in the world right now ====")
    cLog(string.format("A. world entities : %d NPC(s), %d horse(s), %d prop(s)",
        found.npc, found.horse, found.prop))
    -- Per CLASS, not per prefix. A class is what the save stores and what goes missing
    -- when the mod does, so this is the line that says what a modless load has to cope
    -- with. Anything under mercenaries_Prop or mercenaries_Gate draws as a white pyramid.
    local names = {}
    for cls in pairs(byClass) do names[#names + 1] = cls end
    table.sort(names)
    for _, cls in ipairs(names) do
        local own = ""
        for _, o in ipairs(self.UninstallOwnClasses) do
            if o == cls then own = "   <- OUR class: white pyramid without the mod" end
        end
        cLog(string.format("     %-20s %4d%s", cls, byClass[cls], own))
    end
    if found.npc + found.horse + found.prop == 0 then
        cLog("     (nothing - the world is clean)")
    end
    cLog(string.format("B. saver entities : %d (holding %d tag(s))", savers, tags))
    cLog(string.format("C. inventory items: %d across %d class(es)", items, classes))
    cLog(string.format("D. buffs          : %d defined, %d persistent - only persistent ones",
        #(self.ModBuffIds or {}), persistentBuffs))
    cLog("                    can reach a save, so D is ruled out by construction.")

    -- The distinction that decides whether any of this matters.
    local nosave = self.RosterNoSave and "ON" or "OFF"
    cLog(string.format("Save-footprint switch (merc_roster_nosave): %s", nosave))
    -- The single most important line here when something "will not save": once this is on,
    -- the mod writes nothing at all for the rest of the session.
    if self.UninstallScrubbed then
        cLog("PERSISTENCE IS OFF (merc_purge_savers / merc_uninstall was run this session).")
        cLog("  Nothing is being written. Restart the game before playing on.")
    end
    cLog("COUNTED HERE means present in the world. Whether a thing is also WRITTEN to the")
    cLog("save is a different question - load a save and run this again: what comes back")
    cLog("is what was stored. That is the only honest measurement of the footprint.")
    cLog("Surgical: merc_purge_npcs / _horses / _props / _items / _buffs / _savers.")
    cLog("Blunt: merc_purge_world (A+C), merc_uninstall (everything).")
    return found.npc, found.horse, found.prop, savers, items
end

-- ---- the stages ----

-- Each destructive stage is a confirm wrapper plus a worker. The wrapper is what the
-- console calls (so no one deletes their company with a typo); the worker is what
-- merc_uninstall chains. Same "yes" gesture as merc_uninstall, for the same reason.
local function confirmed(line)
    local s = string.lower(mercenaries:CmdClean(line))
    -- Some console paths hand the command name back along with the arguments.
    s = string.gsub(s, "^merc_[%a_]+%s+", "")
    return s == "yes" or s == "y" or s == "confirm"
end

-- Print the refusal. Deliberately says what it RECEIVED, because "I typed it and
-- nothing happened" is the most expensive bug report there is and the answer is always
-- one of two things: the yes never arrived, or the console ate the argument. One run of
-- this tells you which. The command to type goes LAST, where the console still shows it
-- after a long blurb has scrolled.
local function needYes(name, line, why)
    for _, l in ipairs(why or {}) do cLog(l) end
    local raw = tostring(line or "")
    if raw ~= "" then
        cLog(string.format('(received "%s" - that is not a confirmation)', raw))
    end
    cLog("TYPE THIS TO PROCEED:  " .. name .. " yes")
end

function mercenaries:PurgeWorld(line)
    if not confirmed(line) then
        needYes("merc_purge_world", line, {
            "merc_purge_world removes every mercenary, horse, camp structure, patrol and",
            "spawned enemy of this mod, plus its items and status effects on Henry. The",
            "hidden saver entities are KEPT (that is merc_purge_savers) so the two can be",
            "measured separately - see merc_save_audit.",
        })
        return
    end
    return self:PurgeWorldNow()
end

-- Stage A+C. Everything of ours that lives in the WORLD or in Henry's pockets. Does NOT
-- touch the saver entities, so the mod still knows about the camp, the contracts and the
-- upgrades if the player carries on - and so this stage can be measured on its own.
function mercenaries:PurgeWorldNow(quiet)
    cLog("purge: removing mod NPCs, horses, props and items...")

    -- 1. Quiet everything that would put things back while we sweep.
    self.LivePatrolsEnabled = false
    pcall(function() for _, rec in pairs(self.LivePatrols or {}) do self:PatrolDespawnGang(rec) end end)
    pcall(function() self:LootSweepStop() end)

    -- 2. Staged content: the siege, the Aleksej camp, the contract camps.
    pcall(function() self:DespawnRaborsch() end)
    pcall(function() self:AlxDespawnCamp(true) end)          -- onLoad: report no progress
    pcall(function() self:ClearAnyLeftoverBanditCamp() end)
    pcall(function() self:ClearAnyLeftoverPatrols() end)

    -- 3. The camp and its defences.
    pcall(function() if self.CampActive then self:BreakMercCamp(true) end end)
    pcall(function() self:DefClearWorld() end)
    pcall(function() self:ClearAnyLeftoverCamp() end)

    -- 4. Whatever is still standing. One sweep over every class we spawn into, which
    -- is the part that used to miss: the old scan looked at NPC, Horse, BasicEntity and
    -- Stash only, so mercenaries_Prop - the camp walls, gates, towers and archer carts,
    -- and the white pyramids a modless load draws in their place - was never removed.
    local _, gone = self:UninstallSweep({ npc = true, horse = true, prop = true })
    local npcGone, horseGone, propGone = gone.npc, gone.horse, gone.prop

    self.ActiveMercs = {}
    _G.MercCount = 0
    -- Tell the logistics tick these men were TAKEN, not killed - the same guard MercStow
    -- carries. Without it the live count drops to zero between two ticks and the death
    -- detector books the whole company as casualties: "Morale 0 -> -50 (10 merc death(s))".
    pcall(function()
        local L = self:LogiState()
        L.selfRemoved = (L.selfRemoved or 0) + (npcGone or 0)
        L.lastAliveCount = 0
    end)

    -- Reads as "the company is gone" to every monitor - RestoreCampDelayed in
    -- particular, which must not stand the camp back up behind the purge.
    _G.MercenariesDismissed = true

    -- 5. Henry: the status buffs, then every mod item class he is carrying.
    local buffsGone = self:PurgeBuffsNow(true)
    local itemsGone = self:PurgeItemsNow(true)

    if not quiet then
        cLog(string.format("purge done: %d NPC(s), %d horse(s), %d prop(s), %d item(s), %d buff(s) removed",
            npcGone, horseGone, propGone, itemsGone, buffsGone or 0))
        cLog("The saver entities are UNTOUCHED (merc_purge_savers removes those).")
        cLog("To measure: save to a NEW slot, quit, uninstall, then time that load.")
    end
    return npcGone, horseGone, propGone, itemsGone
end

-- ---- the surgical stages ----
--
-- One category each, so a load-time hunt can take exactly one thing out and measure it.
-- merc_purge_world is still the blunt A+C instrument; these are the scalpel. Every one
-- of them is safe to run twice and reports what it actually removed, not what it meant to.

-- Shared body for the three world categories. `what` is the category set, `label` is
-- what to call it in the log.
function mercenaries:PurgeCategory(what, label, quiet)
    local found, gone, byClass = self:UninstallSweep(what)
    local total = 0
    for cat in pairs(what) do total = total + (gone[cat] or 0) end
    if not quiet then
        cLog(string.format("purge %s: %d removed", label, total))
        for cls, n in pairs(byClass) do cLog(string.format("     %-20s %d", cls, n)) end
        if total == 0 then cLog("     (nothing of ours was there)") end
    end
    return total, found, byClass
end

function mercenaries:PurgeNpcs(line)
    if not confirmed(line) then
        needYes("merc_purge_npcs", line, {
            "merc_purge_npcs deletes every PERSON this mod put in the world - mercenaries,",
            "the quartermaster, patrolmen, spawned enemies, tower archers, Aleksej's camp.",
            "Horses, camp structures and saved state are left alone. Your men are GONE, not",
            "stowed: this is the uninstall path, not merc_stow.",
        })
        return
    end
    -- The company must be told, or the monitors put men back within a tick.
    self.LivePatrolsEnabled = false
    pcall(function() for _, rec in pairs(self.LivePatrols or {}) do self:PatrolDespawnGang(rec) end end)
    local n = self:PurgeCategory({ npc = true }, "NPCs")
    self.ActiveMercs = {}
    _G.MercCount = 0
    _G.MercenariesDismissed = true
    -- Tell the logistics tick these men were TAKEN, not killed - the same guard MercStow
    -- carries. Without it the live count drops to zero between two ticks and the death
    -- detector books the whole company as casualties: "Morale 0 -> -50 (10 merc death(s))".
    pcall(function()
        local L = self:LogiState()
        L.selfRemoved = (L.selfRemoved or 0) + (n or 0)
        L.lastAliveCount = 0
    end)
    return n
end

function mercenaries:PurgeHorses(line)
    if not confirmed(line) then
        needYes("merc_purge_horses", line, {
            "merc_purge_horses deletes the mounts this mod spawned (MercenaryHorse_*).",
            "Henry's own horse and every stable horse are untouched - the name is the test.",
        })
        return
    end
    return self:PurgeCategory({ horse = true }, "horses")
end

function mercenaries:PurgeProps(line)
    if not confirmed(line) then
        needYes("merc_purge_props", line, {
            "merc_purge_props deletes every STRUCTURE and marker of this mod: camp walls,",
            "gates, towers, the forge and its rig, carts, beds, chests, lights, alignment",
            "helpers. This is the category that draws as white pyramids in a save the mod",
            "no longer backs, because mercenaries_Prop is a class only this mod defines.",
            "The camp is torn down first so nothing rebuilds it.",
        })
        return
    end
    pcall(function() if self.CampActive then self:BreakMercCamp(true) end end)
    pcall(function() self:DefClearWorld() end)
    pcall(function() self:ClearAnyLeftoverCamp() end)
    return self:PurgeCategory({ prop = true }, "props")
end

function mercenaries:PurgeItems(line)
    if not confirmed(line) then
        local total, _, classes = self:CountModItems()
        needYes("merc_purge_items", line, {
            "merc_purge_items deletes the mod's own items out of Henry's pockets",
            string.format("(%d item(s) across %d class(es) right now - merc_items lists them).", total, classes),
            "Vanilla items the mod merely references - groschen, torches, hammer, tongs -",
            "are NOT touched.",
        })
        return
    end
    return self:PurgeItemsNow()
end

function mercenaries:PurgeItemsNow(quiet)
    local gone = 0
    for _, r in ipairs(self.ModItemIds or {}) do
        pcall(function()
            local c = player.inventory:GetCountOfClass(r.id)
            if c and c > 0 then
                player.inventory:DeleteItemOfClass(r.id, c)
                gone = gone + c
            end
        end)
    end
    if not quiet then cLog(string.format("purge items: %d removed", gone)) end
    return gone
end

function mercenaries:PurgeBuffs(line)
    if not confirmed(line) then
        needYes("merc_purge_buffs", line, {
            "not just the five status effects the script tracks by name.",
            "Worth knowing before you spend a test on it: every one is is_persistent=false,",
            "so none of them is written to a save and none can be costing you load time.",
        })
        return
    end
    return self:PurgeBuffsNow()
end

function mercenaries:PurgeBuffsNow(quiet)
    local gone = 0
    for _, b in ipairs(self.ModBuffIds or {}) do
        if pcall(function() player.soul:RemoveAllBuffsByGuid(b.id) end) then gone = gone + 1 end
    end
    -- The tracked instances too, or the next tick reads its own stale table and skips
    -- re-applying a buff that is no longer there.
    self.PlayerStatusBuffInst = {}
    if not quiet then
        cLog(string.format("purge buffs: %d buff guid(s) cleared off Henry", gone))
    end
    return gone
end

function mercenaries:PurgeSavers(line)
    if not confirmed(line) then
        needYes("merc_purge_savers", line, {
            "merc_purge_savers deletes the mod's hidden save-state entities (camp anchor,",
            "upgrades, contracts, options) and turns persistence OFF for this session, so",
            "nothing writes them back. Your men and camp stay standing but will not come",
            "back after a reload.",
        })
        return
    end
    return self:PurgeSaversNow()
end

-- Stage B. The hidden state entities only. Latches SaveString off so nothing writes one
-- back before the player saves - which is why this is not reversible in-session.
function mercenaries:PurgeSaversNow(quiet)
    local before = self:CountSaverEntities()
    local gone = 0
    pcall(function()
        local pfx, plen = self.SaverPrefix, string.len(self.SaverPrefix)
        for _, e in pairs(System.GetEntitiesByClass("BasicEntity") or {}) do
            local name = e and e:GetName()
            if name and string.sub(name, 1, plen) == pfx then
                pcall(function() System.RemoveEntity(e.id) end)
                gone = gone + 1
            end
        end
    end)
    pcall(function() self:SaverForget() end)
    -- No tick may quietly re-create one between here and the player's save.
    self.UninstallScrubbed = true
    if not quiet then
        cLog(string.format("purge done: %d saver entit(ies) removed (found %d)", gone, before))
        cLog("Persistence is now OFF for this session - nothing more will be written.")
        cLog("To measure: save to a NEW slot, quit, uninstall, then time that load.")
    end
    return gone
end

-- Everything. The user-facing uninstall path (README points here).
function mercenaries:UninstallScrub(line)
    if not confirmed(line) then
        needYes("merc_uninstall", line, {
            "merc_uninstall prepares THIS SAVE for removing the mod. It will:",
            "  - remove every mercenary, horse, patrol, camp structure and spawned enemy",
            "  - take the mod's items and status effects off Henry",
            "  - delete the mod's hidden save-state entities",
            "Without this, saves that ever held a mercenary can load VERY slowly once",
            "the mod is gone. Then SAVE, exit, and delete the mod. Carry on playing",
            "instead and the mod rebuilds what it needs - nothing is lost but the scrub.",
        })
        return
    end

    cLog("uninstall: taking the mod out of the world...")
    local npcGone, horseGone, propGone, itemsGone = self:PurgeWorldNow(true)
    local tagsGone = self:PurgeSaversNow(true)
    cLog(string.format("done: %d NPC(s), %d horse(s), %d prop(s), %d item(s), %d saver(s) removed",
        npcGone or 0, horseGone or 0, propGone or 0, itemsGone or 0, tagsGone or 0))
    cLog("NOW: save the game, exit, and delete the mod. That save loads clean without it.")
end

-- uninstall + save-footprint diagnostics. Player-tier on purpose: merc_uninstall is the
-- supported way to leave, and the audits are what a user is asked to paste into a bug
-- report about load times. The two purge STAGES are the bisection kit - see the block
-- above and docs/save-footprint.md.
cmd("merc_uninstall",   "mercenaries:UninstallScrub('%line')", "Prepare this save for REMOVING the mod (type merc_uninstall for details)")
cmd("merc_save_audit",  "mercenaries:SaveAudit()", "Count everything the mod would leave in a save (changes nothing)")
cmd("merc_items",       "mercenaries:ItemAudit()", "List the mod's items in Henry's inventory (changes nothing)")
cmd("merc_purge_world", "mercenaries:PurgeWorld('%line')", "Bisection: remove mod NPCs/horses/props/items, KEEP the saver entities")
cmd("merc_purge_savers","mercenaries:PurgeSavers('%line')", "Bisection: remove ONLY the mod's hidden saver entities")
cmd("merc_purge_npcs",  "mercenaries:PurgeNpcs('%line')",  "Surgical: remove only the PEOPLE this mod spawned")
cmd("merc_purge_horses","mercenaries:PurgeHorses('%line')","Surgical: remove only the mod's horses")
cmd("merc_purge_props", "mercenaries:PurgeProps('%line')", "Surgical: remove only the mod's structures and markers (the white pyramids)")
cmd("merc_purge_items", "mercenaries:PurgeItems('%line')", "Surgical: remove only the mod's items from Henry's inventory")
cmd("merc_purge_buffs", "mercenaries:PurgeBuffs('%line')", "Surgical: remove only the mod's buffs from Henry")
-- Diagnostics and bench tools: dev tier, so a normal launch never sees them. Each was
-- written to answer one question during development and is kept for the next time that
-- question comes up. merc_dev arms them; it needs -devmode.
mercenaries:DevCommand("merc_outfit_matrix", "mercenaries:MatrixSpawn('%line')", "Parade ground: one man per style+tier. [first] [last] | clear")
mercenaries:DevCommand("merc_save_probe", "mercenaries:SaveProbe('%line')", "Does the mod's save mechanism survive a reload? Write, then 'check' after reloading")
mercenaries:DevCommand("merc_kk_stage", "mercenaries:KKStageReport()", "Kleinkrieg: which encounter stage this save records")
mercenaries:DevCommand("merc_battlecvar", "mercenaries:BattleCvarCmd('%line')", "Apply a scripted battle's render cvars one at a time: <n> | <n> <value> | all | off")
mercenaries:DevCommand("merc_questprobe", "mercenaries:QuestProbe('%line')", "Can Lua read the active quest/objective? Enumerates the live state and says. Changes nothing")
mercenaries:DevCommand("merc_mqsimulate", "mercenaries:MQWSimulate()", "Rehearse a scripted battle for 30s to prove detection->stash->unstash, no quest needed")
mercenaries:DevCommand("merc_map_idbase", "mercenaries:MapIdBaseSet('%line')",
                       "Marker id band start (default 666). Low ids crash the map, very high ones draw nothing; no argument reports")
mercenaries:DevCommand("merc_map_pushes", "mercenaries:MapPushesSet('%line')",
                       "How many times the markers are pushed per map opening (default 6); no argument reports")
mercenaries:DevCommand("merc_map_probe", "mercenaries:MapProbeSet(mercenaries:CmdBool('%line'))",
                       "Log every ApseMap event and the PoiMarkers readback while the camp marker draws: 0 | 1")
mercenaries:DevCommand("merc_camp_compass_offset", "mercenaries:CampCompassOffsetSet('%line')",
                       "Turn the camp compass bearing while you watch it, in degrees (default 45); no argument reports")
cmd("merc_dev",      "mercenaries:DevCommandsEnable()", "Register the authoring and diagnostic commands too")
cmd("merc_dev_list", "mercenaries:DevCommandList()",    "List the dev commands (after merc_dev)")
cmd("merc_lua",      "mercenaries:ExecString(%line)",   "Run a line of Lua (advanced)")
