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
function mercenaries:CmdArgs(line)
    local a = {}
    for w in tostring(line or ""):gmatch("%S+") do a[#a + 1] = w end
    return a
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
mercenaries.CmdOutfitMax = 6

function mercenaries:CmdOutfit(line)
    local n = tonumber(self:CmdArgs(line)[1])
    if not n or n < 1 or n > self.CmdOutfitMax then
        cLog("uniform 1-" .. self.CmdOutfitMax ..
             ": 1 Generic, 2 Bandit, 3 Cuman, 4 Leipa, 5 Kuttenberg, 6 Skalitz")
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
    { "HIRING",     { "merc_hire", "merc_hire_weak", "merc_hire_strong", "merc_hire_archers",
                      "merc_hire_army_small", "merc_hire_army_big" } },
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
                      "merc_gate_open", "merc_gate_close" } },
    { "FIGHTS",     { "merc_battle", "merc_raborsch", "merc_raborsch_clear", "merc_clear_enemies", "merc_raid_now" } },
    { "OPTIONS",    { "merc_difficulty", "merc_upkeep", "merc_encounters", "merc_patrols",
                      "merc_status_icons", "merc_horses", "merc_autodismount", "merc_lod_quality",
                      "merc_hide_others" } },
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
cmd("merc_outfit",             "mercenaries:CmdOutfit('%line')", "Uniform: merc_outfit 1-6 (Generic, Bandit, Cuman, Leipa, Kuttenberg, Skalitz)")
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
cmd("merc_encounters",   "mercenaries:EncountersSet(tonumber('%line') ~= 0)", "Random raids, patrols and ambushes: 0 | 1")
cmd("merc_patrols",      "mercenaries:LivePatrolSetEnabled(%line)", "Roaming road patrols: 0 | 1")
cmd("merc_status_icons", "mercenaries:StatusIconsSet(tonumber('%line') ~= 0)","Squad status icons on your HUD: 0 | 1")
cmd("merc_autodismount", "mercenaries:AutoDismountSet('%line')","Mercs get off their horses to fight: 0 | 1")
cmd("merc_horses",       "mercenaries:HorsesSet(tonumber('%line') ~= 0)", "Let the company use horses at all: 0 | 1 (saved)")
cmd("merc_lod_quality",  "mercenaries:LodQualitySet('%line')", "Mesh detail in big battles: crisp | balanced | performance")
cmd("merc_hide_others",  "mercenaries:ToggleHideOthers()",     "Hide every NPC that is not yours (clean shots)")

-- advanced
cmd("merc_dev",      "mercenaries:DevCommandsEnable()", "Register the authoring and diagnostic commands too")
cmd("merc_dev_list", "mercenaries:DevCommandList()",    "List the dev commands (after merc_dev)")
cmd("merc_lua",      "mercenaries:ExecString(%line)",   "Run a line of Lua (advanced)")
