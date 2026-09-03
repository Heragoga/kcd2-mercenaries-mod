-- ==== main-quest battle watchdog ====
--
-- "During main quests the mercs disappear" is the invisible-mercenaries problem
-- (docs/quest-override-battles.md), and the coming answer is to take the squad and the
-- patrols OFF the board while a scripted main-quest battle runs, then put them back.
-- This file is the RECOGNISER for that: a state machine that decides "we are inside a
-- main-quest fight right now", with entry/exit hooks the despawn/respawn will hang off.
-- The hooks only log for now - detection has to be proven in play before anything acts
-- on it (same doctrine as SpawnGuardReport: ship probes, check coverage, then trust).
--
-- There is no Lua-readable "a main quest battle is running" flag, so the state is
-- triangulated from three independent signals:
--
--   1. QUEST  - one of the twelve battle quests is started and not finished. The list is
--               the measured set from docs/quest-override-battles.md: exactly the quests
--               that carry battle machinery / SetGameContextPreset battleInProgress,
--               derived two independent ways. QuestSystem.IsQuestStarted/IsQuestCompleted
--               are documented scriptbinds (references/kcd2-mod-docs-main), first use in
--               this mod - hence pcall-wrapped and self-reporting.
--   2. CONTEXT - the crime_global_battleInProgress preset (which all twelve set) applies
--               a bundle of script contexts, "Battle" among them. soul:HasScriptContext
--               is vanilla-proven per-soul; whether a Game-class (global) preset answers
--               on the PLAYER's soul is the unproven half, so it is opportunistic.
--   3. FIGHT  - the player is in combat danger, or the battle meter reads high. Proven
--               probes, but they fire for ANY fight, so alone they mean nothing here.
--
-- Decision: QUEST plus either other signal = a main-quest fight. If the quest scriptbind
-- turns out not to exist on some build, CONTEXT plus FIGHT is accepted instead - context
-- carries the "this is scripted, not a road ambush" meaning on that path. FIGHT alone
-- never enters: that is every bandit on every road.
--
-- merc_mqwatch prints every probe's answer so coverage can be checked in play.

-- The twelve, exact folder-name casing from Quests/Final/Barbora/<region>/.
mercenaries.MQWBattleQuests = {
    "utokNaNebakov", "utokNaMalesov", "nebakovObrana", "prepadeniVlasskehoDvora",
    "pogrom", "hladAZmar", "zoufalaObranaZaBohutu", "setkaniVRatbori2",
    "finale", "oblehaniSuchdole", "rutinaAVypad", "posledniPomazani",
}

-- Contexts the battleInProgress preset applies (Libs/Tables/ai/ScriptContextPreset.xml).
-- A subset is probed, not all ten: one hit is a hit.
mercenaries.MQWContexts = {
    "Battle",
    "crime_global_ignoreCombatSounds",
    "crime_global_dontGreetPlayer",
    "ForceCombatSystemAmbientLOD",
}

mercenaries.MQWQuestPollSecs = 10.0  -- how often the 12-quest sweep runs (cached between)
mercenaries.MQWEnterTicks    = 2     -- consecutive busy reads before entering (blip filter)
mercenaries.MQWExitSecs      = 20.0  -- all-quiet this long before leaving the state

mercenaries.MQW = {
    active     = false,  -- the one output: are we inside a main-quest fight
    quest      = nil,    -- name of the live battle quest, or nil
    questApi   = nil,    -- did QuestSystem answer at all (nil = never asked yet)
    ctx        = nil,    -- which context answered true, or nil
    fight      = nil,    -- "combat" | "meter" | nil
    enterCount = 0,
    lastBusyAt = nil,
    enteredAt  = nil,
}

local function wLog(s) System.LogAlways("[MQWatch] " .. tostring(s)) end
local function wNow() local t = 0; pcall(function() t = System.GetCurrTime() or 0 end); return t end

-- Signal 1: the quest sweep, cached. Twelve pcalls every MQWQuestPollSecs, table reads
-- between - this rides the 1s monitor loop and must stay invisible in a profile.
function mercenaries:MQWQuestActive()
    local S = self.MQW
    local now = wNow()
    if S._questAt and (now - S._questAt) < (self.MQWQuestPollSecs or 10.0) then
        return S.quest
    end
    S._questAt = now
    S.quest = nil
    local answered = false
    for _, q in ipairs(self.MQWBattleQuests or {}) do
        local live = false
        local ok = pcall(function()
            if QuestSystem.IsQuestStarted(q) then
                answered = true
                if not QuestSystem.IsQuestCompleted(q)
                   and not QuestSystem.IsQuestCanceled(q) then live = true end
            else
                answered = true
            end
        end)
        if ok and live then
            S.quest = q
            break
        end
    end
    -- Only flip questApi on a definitive read; a single failed pcall must not erase
    -- "the API worked earlier this session".
    if answered then S.questApi = true
    elseif S.questApi == nil then S.questApi = false end
    return S.quest
end

-- Signal 2: the battle context bundle, on the player's soul.
function mercenaries:MQWContextActive()
    local hit = nil
    pcall(function()
        if not (player and player.soul) then return end
        for _, c in ipairs(self.MQWContexts or {}) do
            if player.soul:HasScriptContext(c) then hit = c; break end
        end
    end)
    self.MQW.ctx = hit
    return hit
end

-- Signal 3: an actual fight, by whatever answers.
function mercenaries:MQWFightSignal()
    local sig = nil
    pcall(function()
        if player and player.soul and player.soul:IsInCombatDanger() then sig = "combat" end
    end)
    if not sig then
        pcall(function()
            local b = Game.QueryBattleStatus()
            if type(b) == "number" and b >= (self.SpawnGuardBattleLevel or 0.5) then
                sig = "meter"
            end
        end)
    end
    self.MQW.fight = sig
    return sig
end

-- The tick. Called at 1 Hz from MonitorMainQuestLoop; every probe is cheap or cached.
function mercenaries:MQWTick()
    local S = self.MQW
    local q = self:MQWQuestActive()
    local c = self:MQWContextActive()
    local f = self:MQWFightSignal()

    local busy, why = false, nil
    if q and (c or f) then
        busy = true
        why  = q .. " + " .. (c and ("context " .. c) or ("fight (" .. tostring(f) .. ")"))
    elseif (S.questApi == false) and c and f then
        -- No quest API on this build: context carries the "scripted, not a road
        -- ambush" meaning, and the fight signal confirms it is live.
        busy = true
        why  = "context " .. c .. " + fight (" .. tostring(f) .. "), no quest api"
    end

    local now = wNow()
    if busy then
        S.lastBusyAt = now
        if not S.active then
            S.enterCount = (S.enterCount or 0) + 1
            if S.enterCount >= (self.MQWEnterTicks or 2) then
                S.active, S.enteredAt = true, now
                self:MQWOnBattleEnter(why)
            end
        end
    else
        S.enterCount = 0
        if S.active and S.lastBusyAt and (now - S.lastBusyAt) >= (self.MQWExitSecs or 20.0) then
            S.active = false
            self:MQWOnBattleExit(now - (S.enteredAt or now))
        end
        -- Loaded with the company stashed and no battle re-detected: bring them back.
        if S.stashed and not S.active and S.loadedAt and (now - S.loadedAt) >= (self.MQWStashLoadSecs or 45.0) then
            self:MQWUnstash("no battle after the load")
        end
    end
end

-- ==== hooks ====
-- _G.MercMQBattle is the flag other modules read (PlayerBusyForSpawns does, so patrols
-- stay away during the battle). The stash below is the temporary answer to the company
-- fighting a scripted battle invisibly (docs/quest-override-battles.md): the men are put
-- out of the battle and told to hold there, and come back when it is over.
function mercenaries:MQWOnBattleEnter(why)
    _G.MercMQBattle = true
    wLog("MAIN-QUEST BATTLE detected: " .. tostring(why))
    self:MQWStash(why)
end

function mercenaries:MQWOnBattleExit(dur)
    _G.MercMQBattle = false
    wLog(string.format("main-quest battle over (state held %.0fs)", tonumber(dur) or 0))
    self:MQWUnstash("the battle is over")
end

-- ==== the stash ====
-- The company cannot be made visible in a scripted battle (soul membership is the render
-- gate), so for its duration they are not in it: teleported MQWStashDist behind the
-- player - or to the camp, if one stands far enough away - and given a hold order there,
-- which is what keeps the formation and the straggler sweep from pulling them straight
-- back. Standing patrols are taken down with them. When the watchdog sees the battle end
-- they are brought to the player and released to follow.
--
-- Only with the engine's own Battle context. A battle quest is "started" from the moment
-- it is accepted, so quest + any fight would stash the company out of an ordinary road
-- ambush anywhere inside that quest's span.
--
-- The stash is written to the save (MQWStash) so a load in the middle of it knows: if the
-- battle is not re-detected within MQWStashLoadSecs of the load, the men come back.
mercenaries.MQWStashEnabled  = true     -- merc_mqstash 0|1 (saved)
mercenaries.MQWStashDist     = 400.0    -- metres behind the player
mercenaries.MQWStashLoadSecs = 45.0

function mercenaries:MQWStash(why)
    local S = self.MQW
    if S.stashed then return end
    if not self.MQWStashEnabled then wLog("stash is off (merc_mqstash) - the company stays"); return end
    if not S.ctx then wLog("no scripted-battle context on the player - the company stays"); return end
    local pp, dir
    pcall(function() pp = player:GetWorldPos(); dir = player:GetDirectionVector() end)
    if not pp then return end
    local L = dir and math.sqrt(dir.x * dir.x + dir.y * dir.y) or 0
    local bx, by = 0, -1
    if L > 1e-3 then bx, by = -dir.x / L, -dir.y / L end
    local dist = self.MQWStashDist or 400
    local spot = { x = pp.x + bx * dist, y = pp.y + by * dist, z = pp.z }
    pcall(function() spot.z = System.GetTerrainElevation(spot.x, spot.y) or spot.z end)
    local where = "behind the player"
    if self.CampActive and self.CampCenter then
        local c = self.CampCenter
        if math.sqrt((c.x - pp.x) ^ 2 + (c.y - pp.y) ^ 2) >= dist then
            spot, where = { x = c.x, y = c.y, z = c.z }, "the camp"
        end
    end
    local n = 0
    for _, ent in pairs(self.ActiveMercs or {}) do
        pcall(function()
            ent:SetPos({ x = spot.x + (math.random() - 0.5) * 12.0, y = spot.y + (math.random() - 0.5) * 12.0, z = spot.z })
            if self.NoteTeleport then self:NoteTeleport(ent) end
            n = n + 1
        end)
    end
    pcall(function() self:HoldBegin(spot) end)
    local gangs = 0
    for _, rec in pairs(self.LivePatrols or {}) do
        if rec.spawned then
            gangs = gangs + 1
            pcall(function() self:PatrolDespawnGang(rec, "a main-quest battle") end)
        end
    end
    S.stashed = true
    pcall(function() self:SaveString("MQWStash", "1") end)
    wLog(string.format("%d men sent %.0fm out of the battle to %s (%.0f, %.0f) and told to hold; %d patrol gang(s) taken down (%s)",
                       n, dist, where, spot.x, spot.y, gangs, tostring(why)))
end

function mercenaries:MQWUnstash(why)
    local S = self.MQW
    if not S.stashed then return end
    S.stashed = false
    pcall(function() self:SaveString("MQWStash", "0") end)
    pcall(function() self:HoldEnd(true) end)
    local pp; pcall(function() pp = player:GetWorldPos() end)
    local n = 0
    if pp then
        for _, ent in pairs(self.ActiveMercs or {}) do
            pcall(function()
                ent:SetPos({ x = pp.x + (math.random() - 0.5) * 16.0, y = pp.y + (math.random() - 0.5) * 16.0, z = pp.z })
                if self.NoteTeleport then self:NoteTeleport(ent) end
                n = n + 1
            end)
        end
    end
    pcall(function() self:SetState("follow") end)
    wLog(string.format("%s - %d men brought back to the player and following", tostring(why), n))
end

-- Hiring while the company is out of a battle put the new men wherever the muster point
-- was - in the battle, invisible, and under the hold order the stash had already given the
-- rest, so nothing appeared to happen (2026-09-03, Malesov). They join the men who are
-- waiting instead, and the player is told where they went.
function mercenaries:MQWOnHire(ent)
    if not (self.MQW and self.MQW.stashed and self.HoldAnchor) then return false end
    local a = self.HoldAnchor
    pcall(function()
        ent:SetPos({ x = a.x + (math.random() - 0.5) * 12.0, y = a.y + (math.random() - 0.5) * 12.0, z = a.z })
        if self.NoteTeleport then self:NoteTeleport(ent) end
    end)
    return true
end

function mercenaries:MQWStashSet(on)
    self.MQWStashEnabled = on and true or false
    pcall(function() self:SaveString("MQWStashOn", self.MQWStashEnabled and "1" or "0") end)
    wLog("stash " .. (self.MQWStashEnabled and "on" or "off") .. " - the company " ..
         (self.MQWStashEnabled and "leaves" or "stays in") .. " main-quest battles")
end

-- Called from OnGameplayStarted. The watchdog's state is plain Lua and outlives the level;
-- the stash flag comes from the save.
function mercenaries:MQWOnLoad()
    local S = self.MQW
    S.active, S.enterCount, S.lastBusyAt, S.enteredAt = false, 0, nil, nil
    _G.MercMQBattle = false
    local v; pcall(function() v = self:LoadString("MQWStash") end)
    S.stashed = (v == "1")
    S.loadedAt = wNow()
    local on; pcall(function() on = self:LoadString("MQWStashOn") end)
    if on == "0" then self.MQWStashEnabled = false elseif on == "1" then self.MQWStashEnabled = true end
    if S.stashed then
        wLog(string.format("loaded with the company stashed out of a main-quest battle - they come back unless it is re-detected within %.0fs",
                           self.MQWStashLoadSecs or 45))
    end
end

-- ==== diagnostics ====
function mercenaries:MQWReport()
    local S = self.MQW
    wLog("active=" .. tostring(S.active) ..
         " quest=" .. tostring(S.quest) ..
         " questApi=" .. tostring(S.questApi) ..
         " ctx=" .. tostring(S.ctx) ..
         " fight=" .. tostring(S.fight))
    local function probe(name, fn)
        local v = "unavailable"
        pcall(function() v = tostring(fn()) end)
        wLog("  " .. name .. " = " .. v)
    end
    for _, q in ipairs(self.MQWBattleQuests or {}) do
        probe("IsQuestStarted(" .. q .. ")", function()
            return tostring(QuestSystem.IsQuestStarted(q)) ..
                   " done=" .. tostring(QuestSystem.IsQuestCompleted(q))
        end)
    end
    for _, c in ipairs(self.MQWContexts or {}) do
        probe("HasScriptContext(" .. c .. ")", function()
            return player.soul:HasScriptContext(c)
        end)
    end
    probe("IsInCombatDanger", function() return player.soul:IsInCombatDanger() end)
    probe("QueryBattleStatus", function() return Game.QueryBattleStatus() end)
end

mercenaries:DevCommand("merc_mqwatch", "mercenaries:MQWReport()",
                   "Main-quest battle watchdog: state + every probe's answer")
