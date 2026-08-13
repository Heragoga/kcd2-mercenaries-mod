-- Crowd-scoped AI-LOD budget boost.
--
-- KCD2 puts NPCs in one of three AI tiers - Detail, LOD, MonsterLOD - and the split is a
-- BUDGET (a count), not just a distance. Stock is WH_AI_LOD_MaxCountDetail = 70. An NPC that
-- loses its Detail slot is demoted to LOD, where movement becomes fake jumps
-- (wh_ai_Lod_MoveIntervalLOD, "Time between fake movement jumps in LOD") and behaviour is
-- coarsely simulated. See docs/npc-lod.md for the full measurements.
--
-- The mod can field a 50-man squad, an enemy group, a wall battle and a roaming patrol at once,
-- comfortably past 100 NPCs, so that 70-slot budget is oversubscribed and the losers are picked
-- by distance with hysteresis. This raises it while the crowd is large and puts it straight back
-- afterwards, because these are global engine settings and holding them high permanently is a
-- framerate cost paid while nothing is happening.
--
-- IMPORTANT - do not read this as a fix for merc invisibility. docs/npc-lod.md run 13 applied
-- this exact tier and ruled it out as the cause of that bug: mercs standing at 3m cannot be
-- evicted from a 400m/300-slot Detail budget, and they were demoted anyway. This is only about
-- keeping a big battle simulated properly.
--
-- wh_ai_LOD_Hide is deliberately absent: it is not reachable through GetCVar/SetCVar at all
-- (run 13 reported "nil -> nil <-- DID NOT TAKE").

mercenaries.LodBoostEnabled  = true
mercenaries.LodBoostActive   = false
-- Trigger on CROWD, not on combat. The first version fired only on >=3 live hostiles, and a
-- log with ~50 mercs and no enemies showed it never engaging at all - yet that is exactly the
-- case that oversubscribes the budget, because the Detail budget is a COUNT and the mod's own
-- mercs consume it just as enemies do. A 50-man squad in a city is 50 slots out of 70 before
-- a single bandit turns up.
mercenaries.LodBoostMinCrowd = 12     -- our mercs + nearby hostiles past this = raise the budget
mercenaries.LodBoostHoldSecs = 20.0   -- stay boosted this long after it drops, so it cannot flap
mercenaries._lodSaved        = nil
mercenaries._lodLastFoeAt    = nil

-- Boosted values. Deliberately below the 300/400 the research bundle used: the point is to
-- cover ~100-150 NPCs around a fight, and every extra Detail slot is full AI simulation.
mercenaries.LodBoostCvars = {
    { "WH_AI_LOD_MaxCountDetail",            150 },   -- stock 70
    { "WH_AI_LOD_MaxCountLOD",               600 },   -- stock 400
    { "WH_AI_LOD_MaxDetailDistance",         250 },   -- stock 120
    { "WH_AI_LOD_Areas",                       0 },   -- stock 2 (visibility areas); 0 = distance only
    { "WH_AI_LOD_HysteresisMultiplierDetail",  1 },   -- stock 0.8, which biases NPCs out of Detail
    { "wh_ai_Lod_MoveIntervalLOD",          0.05 },   -- stock 1   - fake movement jumps -> continuous
    { "wh_ai_Lod_MoveIntervalMonsterLOD",   0.05 },   -- stock 10
}

local function lbLog(s) System.LogAlways("[MercLOD] " .. s) end

local function getCVar(n)
    local v = nil
    pcall(function() v = System.GetCVar(n) end)
    return v
end

local function setCVar(n, v)
    pcall(function() System.SetCVar(n, v) end)
end

-- Saves what is live RIGHT NOW rather than a hardcoded stock table: the game loads different
-- cvar overrides per context (Battle.cfg, performanceDemandingArea.cfg...), so the value to
-- restore is whatever was in force when the fight started, not what the docs measured once.
function mercenaries:LodBoostOn()
    if self.LodBoostActive or not self.LodBoostEnabled then return end

    local saved = {}
    for _, e in ipairs(self.LodBoostCvars) do
        saved[e[1]] = getCVar(e[1])
    end
    self._lodSaved = saved

    for _, e in ipairs(self.LodBoostCvars) do
        setCVar(e[1], e[2])
    end
    self.LodBoostActive = true
    lbLog("battle LOD budget raised (Detail " .. tostring(saved["WH_AI_LOD_MaxCountDetail"]) ..
          " -> " .. tostring(self.LodBoostCvars[1][2]) .. ")")
end

function mercenaries:LodBoostOff()
    if not self.LodBoostActive then return end
    for n, v in pairs(self._lodSaved or {}) do
        if v ~= nil then setCVar(n, v) end
    end
    self._lodSaved      = nil
    self.LodBoostActive = false
    lbLog("battle LOD budget restored")
end

-- Driven from CombatScanLoop (300ms). CachedEnemies is already built by that pass, so this
-- costs a table length and a clock read.
function mercenaries:LodBoostTick()
    if not self.LodBoostEnabled then
        if self.LodBoostActive then self:LodBoostOff() end
        return
    end

    local crowd = (_G.MercCount or 0) + #(self.CachedEnemies or {})
    local now   = 0
    pcall(function() now = System.GetCurrTime() or 0 end)

    if crowd >= self.LodBoostMinCrowd then
        self._lodLastFoeAt = now
        if not self.LodBoostActive then self:LodBoostOn() end
    elseif self.LodBoostActive then
        local last = self._lodLastFoeAt
        if not last or (now - last) >= self.LodBoostHoldSecs then self:LodBoostOff() end
    end
end

-- Put the engine back if the mod is torn down mid-fight; leaving global cvars raised would
-- outlive the mod itself.
function mercenaries:LodBoostShutdown()
    self:LodBoostOff()
end

function mercenaries:LodBoostSet(v)
    local on = (tostring(v or ''):match('1') ~= nil)
    self.LodBoostEnabled = on
    if not on then self:LodBoostOff() end
    lbLog("battle LOD boost " .. (on and "ENABLED" or "DISABLED"))
end

function mercenaries:LodBoostStatus()
    lbLog("enabled=" .. tostring(self.LodBoostEnabled) ..
          " active=" .. tostring(self.LodBoostActive) ..
          " crowd=" .. tostring((_G.MercCount or 0) + #(self.CachedEnemies or {})))
    for _, e in ipairs(self.LodBoostCvars) do
        lbLog("  " .. e[1] .. " = " .. tostring(getCVar(e[1])) .. " (boost " .. tostring(e[2]) .. ")")
    end
end

System.AddCCommand("merc_lod_boost",  "mercenaries:LodBoostSet('%line')",
                   "Battle AI-LOD budget boost on or off: merc_lod_boost 1 | 0")
System.AddCCommand("merc_lod_status", "mercenaries:LodBoostStatus()",
                   "Show the battle LOD boost state and the live cvar values")
