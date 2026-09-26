-- Can Lua see which quest or objective is active?
--
-- Nobody knows yet. The mod has always called QuestSystem.IsQuestStarted, but nothing in the
-- game's own 290 Lua files references a QuestSystem global, and docs/general/lua-skald-
-- communication.md says flatly that Skald and Lua have no direct bridge - which is why this
-- mod passes messages through the player's INVENTORY. Meanwhile IsQuestStarted has never
-- once matched a name, including during a Malesov assault that was demonstrably running.
--
-- So this file assumes no API. It enumerates the live Lua state and reports what is actually
-- there. One run settles whether an objective-driven stash is possible at all, which is the
-- question the whole approach rests on.
--
--   merc_questprobe          what exists, and what every candidate call answers
--   merc_questprobe <name>   also dump every member of that one global
--
-- If something answers, the plan is a list of the fights that hide mercenaries, keyed on
-- whatever identifier that call returns. If nothing answers, the inventory-token bridge is
-- the fallback: a Skald node in each battle quest hands Henry a token and the mod reads it,
-- the same trick the rest of the mod already uses.

local function qLog(s) System.LogAlways("[QuestProbe] " .. tostring(s)) end

-- Globals worth looking at even where the name says nothing about quests.
mercenaries.QuestProbeGlobals = {
    "QuestSystem", "Quest", "Quests", "QuestManager", "Journal", "Skald", "Story",
    "Game", "WHGame", "RPG", "Director", "BattleDirector", "Mission", "MissionSystem",
    "XGenAIModule", "Level",
}

-- Nullary calls that would name the current quest or objective if any of them exist.
mercenaries.QuestProbeCalls = {
    "GetActiveQuests", "GetActiveQuest", "GetStartedQuests", "GetRunningQuests",
    "GetAllQuests", "GetQuests", "GetQuestList", "GetCurrentQuest",
    "GetActiveObjectives", "GetActiveObjective", "GetCurrentObjective",
    "GetObjectives", "GetTrackedQuest", "GetTrackedObjective",
    "GetQuestCount", "GetObjectiveCount",
}

local function typeOf(v)
    local t = type(v)
    if t == "table" then
        local n = 0
        for _ in pairs(v) do n = n + 1 end
        return "table(" .. n .. ")"
    end
    return t
end

-- Members of a table, or of a userdata whose metatable exposes an __index table. Script
-- binds are usually the latter, so this reaches them where plain pairs() cannot.
local function membersOf(v)
    local out = {}
    if type(v) == "table" then
        for k, vv in pairs(v) do
            if type(k) == "string" then out[#out + 1] = { k, typeOf(vv) } end
        end
    elseif type(v) == "userdata" then
        local mt = getmetatable(v)
        local idx = mt and rawget(mt, "__index")
        if type(idx) == "table" then
            for k, vv in pairs(idx) do
                if type(k) == "string" then out[#out + 1] = { k, typeOf(vv) } end
            end
        end
    end
    table.sort(out, function(a, b) return a[1] < b[1] end)
    return out
end

-- Short, safe rendering of whatever a probe call handed back.
local function describe(v)
    local t = type(v)
    if t == "table" then
        local n, first = 0, nil
        for k, vv in pairs(v) do
            n = n + 1
            if not first then
                first = tostring(k) .. "=" .. (type(vv) == "table" and "{...}" or tostring(vv))
            end
        end
        return "table(" .. n .. ")" .. (first and ("  first: " .. first) or "  EMPTY")
    end
    return t .. " " .. tostring(v)
end

function mercenaries:QuestProbe(line)
    local only = self:CmdClean(line)
    if only == "" then only = nil end

    qLog("==== what this Lua state exposes about quests ====")

    -- 1. Everything in _G whose NAME suggests quests. Found, not assumed.
    local byName = {}
    pcall(function()
        for k, v in pairs(_G) do
            if type(k) == "string" then
                local lk = string.lower(k)
                if string.find(lk, "quest", 1, true) or string.find(lk, "object", 1, true)
                   or string.find(lk, "skald", 1, true) or string.find(lk, "journal", 1, true)
                   or string.find(lk, "mission", 1, true) or string.find(lk, "story", 1, true) then
                    byName[#byName + 1] = { k, typeOf(v) }
                end
            end
        end
    end)
    table.sort(byName, function(a, b) return a[1] < b[1] end)
    qLog("-- globals whose name mentions quest/objective/skald/journal/mission/story:")
    if #byName == 0 then qLog("     (none at all)") end
    for _, r in ipairs(byName) do qLog(string.format("     %-28s %s", r[1], r[2])) end

    -- 2. The named candidates: present or absent, and what they hold.
    qLog("-- named candidates:")
    local live = {}
    for _, name in ipairs(self.QuestProbeGlobals) do
        local v = rawget(_G, name)
        if v == nil then
            qLog(string.format("     %-16s ABSENT", name))
        else
            live[name] = v
            local ms = membersOf(v)
            qLog(string.format("     %-16s %s, %d member(s)", name, typeOf(v), #ms))
            for _, m in ipairs(ms) do
                local lm = string.lower(m[1])
                if only == name or string.find(lm, "quest", 1, true)
                   or string.find(lm, "object", 1, true) then
                    qLog(string.format("         %-40s %s", m[1], m[2]))
                end
            end
        end
    end

    -- 3. Call every candidate that exists. This is the part that answers the question.
    qLog("-- candidate calls (a table or a string here means YES, quest state is readable):")
    local answered = 0
    for name, obj in pairs(live) do
        for _, fn in ipairs(self.QuestProbeCalls) do
            local f
            pcall(function() f = obj[fn] end)
            if type(f) == "function" then
                -- Method form first, then plain: script binds want the self, Lua tables do not.
                local ok, res = pcall(function() return obj[fn](obj) end)
                if not ok or res == nil then
                    local ok2, res2 = pcall(function() return obj[fn]() end)
                    if ok2 and res2 ~= nil then ok, res = ok2, res2 end
                end
                if ok and res ~= nil then
                    answered = answered + 1
                    qLog(string.format("     %s.%s() -> %s", name, fn, describe(res)))
                else
                    qLog(string.format("     %s.%s() exists but errored or returned nil", name, fn))
                end
            end
        end
    end

    -- 4. The call the mod has always relied on, tested honestly: if a name that cannot exist
    -- answers the same as a real one, the function is not telling us anything at all.
    qLog("-- IsQuestStarted sanity:")
    local function tryQ(n)
        local v = "unavailable"
        pcall(function() v = tostring(QuestSystem.IsQuestStarted(n)) end)
        qLog(string.format("     IsQuestStarted(%-38s) = %s", n, v))
    end
    tryQ("utokNaMalesov")
    tryQ("q_utokNaMalesov")
    tryQ("Final/Barbora/Kutnohorsko/utokNaMalesov")
    tryQ("definitely_not_a_real_quest_name")

    -- 5. What IS available to key a fight list on. RPG locations are the mod's existing
    -- substitute for a level name (mercenaries_patrols_live.lua identifies the map by them),
    -- and they are the only named, stable, per-place identifier this Lua state exposes.
    -- Run this DURING a battle and the position below is the battle's own coordinates.
    qLog("-- what IS available to key a fight list on:")
    local locs
    pcall(function() locs = RPG.GetLocations() end)
    if type(locs) == "table" then
        local n = 0
        for _ in pairs(locs) do n = n + 1 end
        qLog("     RPG.GetLocations() -> " .. n .. " location(s):")
        local line, count = "", 0
        for k, v in pairs(locs) do
            local nm = (type(v) == "table" and (v.name or v.Name)) or (type(v) == "string" and v) or tostring(k)
            line = line .. tostring(nm) .. "  "
            count = count + 1
            if count % 6 == 0 then qLog("       " .. line); line = "" end
        end
        if line ~= "" then qLog("       " .. line) end
    else
        qLog("     RPG.GetLocations() unavailable")
    end
    local pp
    pcall(function() pp = player:GetWorldPos() end)
    if pp then
        qLog(string.format("     player is at (%.0f, %.0f, %.0f)  <- run this INSIDE a battle to", pp.x, pp.y, pp.z))
        qLog("       capture that fight's coordinates for an area-based trigger")
    end

    if answered == 0 then
        qLog("VERDICT: nothing answered. No quest or objective is readable from Lua on this")
        qLog("build, so an objective-driven stash cannot be built as it stands. The fallback")
        qLog("is the inventory-token bridge (docs/general/lua-skald-communication.md): a Skald")
        qLog("node in each battle quest hands Henry a token and the mod reads it - the same")
        qLog("trick the rest of this mod already uses, at the cost of one quest edit per fight.")
    else
        qLog("VERDICT: " .. answered .. " call(s) answered - read them above. Whichever returns a")
        qLog("stable identifier is what the fight list should be keyed on.")
    end
end
