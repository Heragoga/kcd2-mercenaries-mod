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

-- The scripted-battle contexts, taken from the game's OWN table rather than guessed:
-- Libs/Tables/CVarOverride.xml (Data/Tables.pak) binds each GameContext to a cfg file, and
-- entering one is what puts `Loading config file 'Config/CVarOverrides/utokNaMalesov_battle.cfg'`
-- in kcd.log. Those names are therefore exactly "a scripted battle is running", and the
-- engine never enters one for a roadside ambush.
--
--   kutnohorsko(1) performanceDemandingArea(2) klaster(1) klaster_chram(2)
--   Battle(3) oblehaniSuchdole_nightAttackTargetingRange(4)
--   oblehaniSuchdole_Battle(5) utokNaMalesov_battle(4)
--
-- The four crime_global_* / ForceCombat* names below are the older guesses from the
-- battleInProgress preset. Kept: one hit is a hit, and they cost a pcall each.
mercenaries.MQWContexts = {
    "utokNaMalesov_battle",
    "Battle",
    "oblehaniSuchdole_Battle",
    "oblehaniSuchdole_nightAttackTargetingRange",
    "crime_global_ignoreCombatSounds",
    "crime_global_dontGreetPlayer",
    "ForceCombatSystemAmbientLOD",
}

-- No automatic detector is known yet. Measured 2026-09-04, during the real assault with
-- utokNaMalesov_battle.cfg plainly loaded in kcd.log: every HasScriptContext probe read
-- false, so the CVarOverride GameContexts are not script contexts on the player's soul; and
-- IsQuestStarted never matched any of the twelve names. The cvar footprint would match, but
-- it is not evidence - the same numbers can be pushed with no battle in sight.
--
-- The next thing to try is the ACTIVE OBJECTIVE, if the Lua state exposes one at all:
-- merc_questprobe answers that in one run. See docs/malesov-test.md.

mercenaries.MQWQuestPollSecs = 10.0  -- how often the 12-quest sweep runs (cached between)
mercenaries.MQWEnterTicks    = 2     -- consecutive busy reads before entering (blip filter)
mercenaries.MQWExitSecs      = 20.0  -- all-quiet this long before leaving the state
mercenaries.MQWTraceSecs     = 15.0  -- how often the near-miss line may repeat

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
    if self.MQW.simFight then self.MQW.fight = "simulated"; return "simulated" end
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

-- Say why we are NOT entering while any battle signal is showing. Without this the tick is
-- completely silent on a near miss, and a test run that fails tells you nothing - which is
-- exactly how this watchdog reached 2026-09-04 having never once been observed to fire.
-- Rate-limited, because a battle quest stays "started" for hours of ordinary play.
function mercenaries:MQWTrace(q, c, f, cv)
    local S = self.MQW
    local now = wNow()
    if S._traceAt and (now - S._traceAt) < (self.MQWTraceSecs or 15.0) then return end
    S._traceAt = now
    wLog(string.format(
        "NOT entering: quest=%s context=%s fight=%s cvars=%s streak=%d/%d",
        tostring(q), tostring(c), tostring(f), tostring(cv),
        S.enterCount or 0, self.MQWEnterTicks or 2))
end

-- The tick. Called at 1 Hz from MonitorMainQuestLoop; every probe is cheap or cached.
function mercenaries:MQWTick()
    local S = self.MQW
    if S.simUntil and wNow() >= S.simUntil then self:MQWSimEnd() end

    local q  = self:MQWQuestActive()
    local c  = self:MQWContextActive()
    local f  = self:MQWFightSignal()
    -- Signal 4 (the battle cvar profile) is NOT a detector. Those numbers can be pushed by
    -- anything - a graphics preset, this mod's own LOD bench - so matching them would stash
    -- the company outside any battle at all. Ruled out by decision, 2026-09-04. What is left
    -- of it is merc_battlecvar, a bench for applying the values by hand, and the simulation
    -- flag below, which stands in for a detection that has not been found yet.
    local cv = S.simBattle and "simulated" or nil
    S.cvar = cv

    -- Entry used to require a QUEST NAME match before anything else could count, and at
    -- Malesov on 2026-09-04 `IsQuestStarted('utokNaMalesov')` never answered true - so the
    -- watchdog could not fire however plainly the battle was running. The quest list is now
    -- corroboration, never a gate. The context is authoritative on its own: CVarOverride.xml
    -- binds those names to the battle cfg files, so the engine is only in one during a
    -- scripted battle.
    local busy, why = false, nil
    if c then
        busy = true
        why  = "context " .. c .. (q and (" (quest " .. q .. ")") or "")
    elseif cv then
        busy = true
        why  = "simulated battle (merc_mqsimulate)"
    elseif q and f then
        busy = true
        why  = q .. " + fight (" .. tostring(f) .. ")"
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
        -- Trace on ANY signal, not just a quest match: keying it to the quest was why the
        -- Malesov run produced a completely silent log while the battle was plainly on.
        if q or c or f or cv then self:MQWTrace(q, c, f, cv) end
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

-- `force` is the manual path (merc_mqstash_now). The automatic path insists on the
-- engine's Battle context even though the TICK can enter on quest+fight alone: a battle
-- quest counts as started from the moment it is accepted, so quest+fight would empty the
-- company out of an ordinary road ambush hours away from the battle. The consequence is
-- that "MAIN-QUEST BATTLE detected" can be followed by a refusal - which is why the
-- refusal says so out loud, and why the manual command exists to test the mechanism on
-- its own.
function mercenaries:MQWStash(why, force)
    local S = self.MQW
    if S.stashed then wLog("already stashed - nothing to do"); return end
    if not force and not self.MQWStashEnabled then wLog("stash is off (merc_mqstash) - the company stays"); return end
    -- A scripted-battle marker of EITHER kind will do: the context, or the cfg file's cvar
    -- footprint. What is still refused is quest+fight alone, because a battle quest counts
    -- as started from the moment it is accepted and that would empty the company out of any
    -- roadside ambush for the hours it stays open.
    if not force and not (S.ctx or S.simBattle) then
        wLog("no scripted-battle marker - the company stays")
        return
    end
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
    -- A new level applies its own CVarOverride, so last level's baseline means nothing.
    S.cvar, S.cvarWhy, S._traceAt = nil, nil, nil
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

-- ==== manual test path ====
-- The stash has two independent failure modes: the watchdog may never detect the battle,
-- or the stash itself may not work. Testing them together means a failed run cannot say
-- which broke. These two force the mechanism so it can be proven on any quiet hillside,
-- before Malesov, and they are player-tier because merc_dev is not something to be typing
-- with an assault under way. See docs/malesov-test.md.
function mercenaries:MQWStashNow()
    self:MQWStash("forced by hand (merc_mqstash_now)", true)
end

-- Drive the WHOLE chain without a battle: cvar signal -> entry -> stash -> exit -> unstash.
--
-- Needed because the one battle this was written for, utokNaMalesov, cannot be replayed
-- without redoing a very long quest (2026-09-04). So the automatic path cannot be proven
-- against the real thing - but it can be proven against the mechanism, which is what this
-- does. It moves the four watched cvars off their quiet-play baseline exactly as the battle
-- cfg would, and holds a fight signal up, then puts everything back after MQWSimSecs so the
-- exit and the unstash are exercised too.
--
-- It cannot tell you whether the ENGINE will flag the battle. Only the real assault can, and
-- the context probes in merc_mqwatch are how you would read that.
mercenaries.MQWSimSecs = 30.0

function mercenaries:MQWSimulate()
    local S = self.MQW
    if S.simUntil then wLog("a simulation is already running"); return end
    if S.active or S.stashed then wLog("already in the battle state - merc_mqunstash_now first"); return end
    S.simBattle = true
    S.simFight  = true
    S.simUntil  = wNow() + (self.MQWSimSecs or 30.0)
    wLog(string.format("SIMULATION: standing in for a detected battle for %.0fs.", self.MQWSimSecs or 30.0))
    wLog("expect within ~2s: 'MAIN-QUEST BATTLE detected: simulated battle' then the stash,")
    wLog("and the company home again ~20s after the simulation ends.")
end

function mercenaries:MQWSimEnd()
    local S = self.MQW
    S.simBattle, S.simFight, S.simUntil, S.simRestore = nil, nil, nil, nil
    wLog("SIMULATION over - the watchdog should leave the battle state after MQWExitSecs" ..
         " and bring the men back.")
end

function mercenaries:MQWUnstashNow()
    if not self.MQW.stashed then wLog("not stashed - nothing to bring back"); return end
    self:MQWUnstash("forced by hand (merc_mqunstash_now)")
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

    -- The cfg-file footprint. `base` is what quiet play looked like this session; a value
    -- that has moved is the battle override in force. If every context above reads false
    -- while these have all moved, HasScriptContext does not see GameContexts on this build
    -- and the cvar route is the one to trust.
    -- Informational only. These numbers DO track the battle, but they are not evidence:
    -- anything can push them, so they are not wired to detection (merc_battlecvar applies
    -- them by hand; that is all they are for now).
    local spec; pcall(function() spec = System.GetCVar("sys_spec") end)
    local key = string.gsub(tostring(tonumber(spec) or spec or ""), "%.0$", "")
    local want = (self.BattleCvarAnchors or {})[key]
    wLog("  battle cvar profile for sys_spec " .. key .. " (informational, NOT a detector):")
    for n, accepted in pairs(want or {}) do
        local v; pcall(function() v = System.GetCVar(n) end)
        local vs, ok = tostring(v), false
        for _, a2 in ipairs(accepted) do if vs == a2 then ok = true end end
        wLog(string.format("    %-46s now=%-10s battle=%s%s", n, vs,
             table.concat(accepted, "|"), ok and "   (at battle value)" or ""))
    end
    wLog("  simulated=" .. tostring(S.simBattle))
end

-- merc_mqwatch, merc_mqstash_now and merc_mqunstash_now are registered PLAYER-tier in
-- mercenaries_commands.lua: they are the instruments for the Malesov test and must not
-- need merc_dev first, mid-battle.
