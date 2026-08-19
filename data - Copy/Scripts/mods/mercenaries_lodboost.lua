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
-- Held on by a caller that KNOWS the crowd is there. LodBoostTick sizes the crowd from
-- CachedEnemies, which is built around the PLAYER and drops anyone suppressed - so a siege a
-- hundred metres off, or one still holding fire, reads as an empty field and the tick switches
-- the boost straight back off under whoever asked for it.
mercenaries.LodBoostPinned   = false

-- Mesh detail by crowd size. Bigger crowd -> HIGHER ratio (detail drops sooner) -> affordable.
-- 100 is the engine default, 200 is medium, 300 leaves ~3m detailed and the rest clay figures;
-- docs/npc-lod.md separately records 255 as "puppets at arm's length".
--
-- SOFTENED, and the reason is worth keeping: the ladder used to start at crowd 30 and top out
-- at 300, so simply HIRING fifty mercs put the whole company past puppet-grade - and left it
-- there, because a squad that size never lets the crowd fall back through the lower bands. A
-- big company is ordinary play, not a battle. The ladder now starts where a real battle does
-- and stops below 255, so a fifty-man squad on the road draws at the engine's own mesh LOD.
--
-- BANDED, not interpolated, and only changed when the band changes: scaling a LOD ratio
-- continuously off a live count is what caused pop-in the last time it was tried
-- (see RenderLodSet in mercenaries_util.lua).
mercenaries.LodRatioBands = {
    { crowd = 150, ratio = 200 },   -- a full siege, ~190 NPCs
    { crowd = 100, ratio = 160 },
    { crowd =  70, ratio = 130 },
}
mercenaries.LodRatioAuto  = true
mercenaries._lodRatioBand = nil

function mercenaries:LodRatioForCrowd(crowd)
    for _, b in ipairs(self.LodRatioBands) do
        if crowd >= b.crowd then return b.ratio end
    end
    return nil   -- under the smallest band: hand mesh LOD back to the engine
end
-- Trigger on CROWD, not on combat. The first version fired only on >=3 live hostiles, and a
-- log with ~50 mercs and no enemies showed it never engaging at all - yet that is exactly the
-- case that oversubscribes the budget, because the Detail budget is a COUNT and the mod's own
-- mercs consume it just as enemies do. A 50-man squad in a city is 50 slots out of 70 before
-- a single bandit turns up.
mercenaries.LodBoostMinCrowd = 8      -- our mercs + nearby hostiles past this = raise the budget
mercenaries.LodBoostHoldSecs = 20.0   -- stay boosted this long after it drops, so it cannot flap
mercenaries._lodSaved        = nil
mercenaries._lodLastFoeAt    = nil

-- Boosted values. Deliberately below the 300/400 the research bundle used: the point is to
-- cover ~100-150 NPCs around a fight, and every extra Detail slot is full AI simulation.
-- Deliberately below the 300/400 the research bundle used: every Detail slot is FULL AI
-- simulation, and 300 of them costs more framerate than the demotions cost fidelity. Raising
-- these to 300/1000/400 for the siege made it visibly worse, not better - the fix was never
-- bigger numbers, it was stopping the tick from switching the boost off (see LodBoostPinned).
mercenaries.LodBoostCvars = {
    -- 260, not 150. A siege fields ~100 foot, ~43 archers and a 50-man company: about 193
    -- NPCs against a 150-slot Detail budget, so a good forty of them were demoted to the LOD
    -- tier - where movement is fake jumps and behaviour is coarsely simulated. That is what
    -- "the besiegers are unresponsive" was. 300 was tried before and hurt, but that was with
    -- mesh detail still at full quality for every one of them; with LodRatioBands turning the
    -- far ones into clay figures the simulation budget is the affordable half of the trade.
    { "WH_AI_LOD_MaxCountDetail",            260 },   -- stock 70
    { "WH_AI_LOD_MaxCountLOD",               600 },   -- stock 400
    { "WH_AI_LOD_MaxDetailDistance",         250 },   -- stock 120
    { "WH_AI_LOD_Areas",                       0 },   -- stock 2 (visibility areas); 0 = distance only
    { "WH_AI_LOD_HysteresisMultiplierDetail",  1 },   -- stock 0.8, which biases NPCs out of Detail
    { "wh_ai_Lod_MoveIntervalLOD",          0.05 },   -- stock 1   - fake movement jumps -> continuous
    { "wh_ai_Lod_MoveIntervalMonsterLOD",   0.05 },   -- stock 10

    -- RENDERER side (docs/npc-lod.md section 4). These were missing, which is why raising the
    -- AI budget "did nothing": WH_AI_LOD_* governs how well an NPC is SIMULATED, not whether
    -- he is DRAWN. A live log measured e_ViewDistRatio = 50 and
    -- e_LodFaceAreaTargetSizeCharacterWH = 0.00305 - a battle context tightens both - so the
    -- men on the far wall were being culled and coarsened by the renderer no matter how many
    -- Detail slots the AI had.
    { "e_ViewDistRatio",                     200 },   -- measured 50; Battle.cfg uses 80
    { "e_ViewDistRatioCustom",               200 },   -- measured 60
    { "e_ViewDistRatioVegetation",           100 },   -- so the fort is not floating in bare ground
    { "e_LodFaceAreaTargetSizeCharacterWH", 0.0006 }, -- measured 0.00305; LOWER keeps detail further
    { "e_CharRenderLodMin",                    0 },   -- e_CharsRenderLodMin does NOT exist: it
    { "e_CharLodMin",                          0 },   -- read back nil in game. These two do.

    -- Clothing / uberlod distance (docs/npc-lod.md section 2). A KCD2 character is ASSEMBLED
    -- from skin attachments, and past a distance the engine swaps to a merged "uberlod" mesh
    -- or stops loading the outfit at all - which is a separate pipeline from both the AI tier
    -- and the view distance, and the likeliest remaining reason distant men look wrong when
    -- every cvar above has already taken.
    -- wh_cc_LodForUberlod is "a LOD number from where we start showing the uberlod (-1
    -- disables the feature)". The UBERLOD IS THE WANTED THING - the merged, low-polygon
    -- version of an outfit - so a distant man is a cheap solid figure instead of nothing.
    -- -1 was tried and is wrong twice over: it does not force the uberlod, it turns the swap
    -- OFF, and doing that with one already loaded drew the merged mesh and the separate
    -- attachments simultaneously (the two versions blended together). A LOW NUMBER is the
    -- setting: swap to the cheap mesh from LOD 1 rather than never.
    { "wh_cc_LodForUberlod",                   1 },
    { "wh_cc_UberlodLoadDistRatio",          100 },   -- % of max view distance uberlods load at
    { "wh_cc_UnloadHysteresisDist",           80 },   -- metres before an outfit is unloaded
    { "ca_AttachmentCullingRation",         1000 },   -- system.cfg raises this as a "missing eyes fix"
    { "wh_item_ViewDistRatio",               200 },   -- weapons vanish separately from bodies
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
    lbLog("battle LOD raised - AI Detail " .. tostring(saved["WH_AI_LOD_MaxCountDetail"]) ..
          " -> " .. tostring(self.LodBoostCvars[1][2]) ..
          ", view dist " .. tostring(saved["e_ViewDistRatio"]) .. " -> 200")
end

-- Put the values back on EVERY tick while boosted, rather than once when it starts.
-- Libs/Tables/CVarOverride.xml maps a game context to an override file with a PRIORITY, and
-- entering one (Battle, performanceDemandingArea, a level) re-applies its own numbers over
-- the top of ours - performanceDemandingArea.cfg alone clamps MaxDetailDistance=150,
-- MaxCountDetail=70 and e_ViewDistRatioCustom=80. Setting them once and walking away means
-- the boost survives only until the next context change, which in a battle is immediately.
function mercenaries:LodBoostReassert()
    if not self.LodBoostActive then return end
    for _, e in ipairs(self.LodBoostCvars) do
        setCVar(e[1], e[2])
    end
    self:LodRatioAutoApply()
end

-- Pick the band for the current crowd and, only if it CHANGED, push it to every mod NPC.
-- Re-applying the same number every tick would be pointless work; changing it every tick
-- would be the pop-in bug.
function mercenaries:LodRatioAutoApply()
    if not self.LodRatioAuto then return end
    local crowd = (_G.MercCount or 0) + #(self.CachedEnemies or {})
    -- The siege knows its own headcount; CachedEnemies only sees what is near the player.
    pcall(function()
        local S = self.RBQ
        if S and S.active then
            crowd = (_G.MercCount or 0) + #(S.foot or {}) + #(S.archers or {})
        end
    end)
    local want = self:LodRatioForCrowd(crowd)
    if want == self._lodRatioBand then return end
    self._lodRatioBand = want
    local list, n = self:LodModNpcs(), 0
    for _, e in ipairs(list) do
        local ok = false
        if want then pcall(function() e:SetLodRatio(want); ok = true end)
        else pcall(function() e:SetLodRatio(100); ok = true end) end
        if ok then n = n + 1 end
    end
    lbLog("crowd " .. crowd .. " -> mesh LOD ratio " ..
          (want and tostring(want) or "engine default") .. " on " .. n .. " NPC(s)")
end

-- Put every mod NPC back on the engine's own mesh LOD. LodRatioAutoApply only ever runs from
-- LodBoostReassert, i.e. while the boost is on, so without this the last band it picked stays
-- on the whole squad for the rest of the session.
function mercenaries:LodRatioReset()
    if self._lodRatioBand == nil then return end
    self._lodRatioBand = nil
    local n = 0
    for _, e in ipairs(self:LodModNpcs()) do
        if pcall(function() e:SetLodRatio(100) end) then n = n + 1 end
    end
    lbLog("mesh LOD handed back to the engine on " .. n .. " NPC(s)")
end

function mercenaries:LodBoostOff()
    if not self.LodBoostActive then return end
    for n, v in pairs(self._lodSaved or {}) do
        if v ~= nil then setCVar(n, v) end
    end
    self._lodSaved      = nil
    self.LodBoostActive = false
    self:LodRatioReset()
    lbLog("battle LOD budget restored")
end

-- Driven from CombatScanLoop (300ms). CachedEnemies is already built by that pass, so this
-- costs a table length and a clock read.
function mercenaries:LodBoostTick()
    if not self.LodBoostEnabled then
        if self.LodBoostActive then self:LodBoostOff() end
        return
    end

    -- Pinned: somebody has told us there is a battle on. Never argue with them.
    if self.LodBoostPinned then
        if not self.LodBoostActive then self:LodBoostOn() end
        self:LodBoostReassert()
        return
    end

    local crowd = (_G.MercCount or 0) + #(self.CachedEnemies or {})
    local now   = 0
    pcall(function() now = System.GetCurrTime() or 0 end)

    if crowd >= self.LodBoostMinCrowd then
        self._lodLastFoeAt = now
        if not self.LodBoostActive then self:LodBoostOn() end
        self:LodBoostReassert()
    elseif self.LodBoostActive then
        local last = self._lodLastFoeAt
        if not last or (now - last) >= self.LodBoostHoldSecs then self:LodBoostOff() end
    end
end

-- Put the engine back if the mod is torn down mid-fight; leaving global cvars raised would
-- outlive the mod itself.
-- Hold the boost on regardless of what the crowd count thinks.
function mercenaries:LodBoostPin(on)
    self.LodBoostPinned = (on == true)
    if self.LodBoostPinned then
        self:LodBoostOn()
        lbLog("boost PINNED on")
    else
        lbLog("boost unpinned - the crowd count decides again")
    end
end

-- PER-ENTITY render pin. The cvars above are GLOBAL; an entity's own max view distance is
-- derived from its personal ViewDistRatio scaled by e_ViewDistRatio, so a global raise does
-- nothing for an NPC whose own ratio is low. SetViewDistUnlimited is used on every prop this
-- mod spawns (towers, carts, beds, the house) and on NO NPC anywhere - which is the one lever
-- in docs/npc-lod.md that has never actually been pulled for characters.
--
-- NOTE the disproved experiment in that doc: the old EnsureMercIsAlwaysRendered called
-- SetViewDistRatio(254) and then SetViewDistRatio(0) on the next line, clamping every merc to
-- the MINIMUM. Any "view distance calls do not help" conclusion drawn from it is void. Do not
-- call SetViewDistRatio(0) here or anywhere.
mercenaries.LodPinnedEnts = {}

function mercenaries:LodPinEntity(ent)
    if not ent then return false end
    local ok = false
    pcall(function() ent:SetViewDistUnlimited(); ok = true end)
    if ok and ent.id then self.LodPinnedEnts[tostring(ent.id)] = true end
    return ok
end

-- Every NPC the mod is responsible for right now: the squad, and anything a caller passes in.
function mercenaries:LodPinAllMercs()
    local n = 0
    for _, e in pairs(self.ActiveMercs or {}) do
        if self:LodPinEntity(e) then n = n + 1 end
    end
    lbLog("view distance unlimited on " .. n .. " merc(s)")
    return n
end

-- The doc's own probe, so this stops being guesswork: it separates "hidden" from "unhidden
-- but skinless", which are different systems with different fixes.
function mercenaries:LodProbe(radius)
    local r = tonumber(tostring(radius or ''):match('%d+')) or 80
    if not player then return end
    local pp
    pcall(function() pp = player:GetWorldPos() end)
    if not pp then lbLog("no player position"); return end

    local ents = System.GetPhysicalEntitiesInBoxByClass(pp, r, "NPC") or {}
    lbLog("probe: " .. #ents .. " NPC(s) within " .. r .. "m")
    local shown = 0
    for _, e in pairs(ents) do
        if shown < 25 and e and type(e) == "table" and e.GetName then
            local nm, hid, vdr, ch, vis, d = "?", "?", "?", "?", "?", -1
            pcall(function() nm = e:GetName() or "?" end)
            pcall(function() hid = tostring(e:IsHidden()) end)
            pcall(function() vdr = tostring(e:GetViewDistRatio()) end)
            pcall(function() ch = tostring(e:IsSlotCharacter(0)) end)
            -- Action.IsGameObjectProbablyVisible read back "?" in game, so it is not queried.
            pcall(function() vis = tostring(e:GetLodRatio()) end)
            pcall(function()
                local q = e:GetWorldPos()
                d = math.sqrt((q.x-pp.x)^2 + (q.y-pp.y)^2 + (q.z-pp.z)^2)
            end)
            lbLog(string.format("  %5.1fm hidden=%s vdr=%s char=%s lodratio=%s  %s",
                                d, hid, vdr, ch, vis, string.sub(nm, 1, 42)))
            shown = shown + 1
        end
    end
    lbLog("  hidden=1 -> something called Hide() (AI LOD / HideNearbyNPCs)")
    lbLog("  hidden=0 but char=false -> present but SKINLESS: the clothing scheduler (wh_cc_*)")
    lbLog("  low vdr -> that entity's OWN view distance is short; merc_lod_pinall fixes it")
end

-- ==== live controls ====
-- The probe showed mercs at vdr=1000 (pinned) and tower archers at vdr=100 (not), with
-- nothing hidden and every character present. So the remaining levers are worth having under
-- direct control rather than another guess-and-rebuild cycle.

-- Every NPC this mod is responsible for: the squad, static archers (tower, cart, placed) and
-- anything spawned as an enemy. Named prefixes, because there is no one table holding them all.
function mercenaries:LodModNpcs()
    local out = {}
    for _, e in pairs(self.ActiveMercs or {}) do if e then table.insert(out, e) end end
    if not player then return out end
    local pp; pcall(function() pp = player:GetWorldPos() end)
    if not pp then return out end
    local ents = System.GetPhysicalEntitiesInBoxByClass(pp, 300, "NPC") or {}
    for _, e in pairs(ents) do
        if e and type(e) == "table" and e.GetName then
            local n = e:GetName() or ""
            if self:IsStaticArcherName(n) or self:IsModEnemyName(n)
               or string.find(n, "SpawnedFriend_", 1, true)
               or string.find(n, "SpawnedPatrolman_", 1, true) then
                table.insert(out, e)
            end
        end
    end
    return out
end

-- merc_lod_vdr <n>   0 or "max" = SetViewDistUnlimited (reads back as 1000)
--                    1..254     = that exact ratio, so it can be compared against
function mercenaries:LodVdrSet(v)
    local raw = tostring(v or ""):gsub("%s+", "")
    local n = tonumber(raw:match("%d+"))
    local unlimited = (raw == "" or raw == "max" or n == 0)
    local list, ok = self:LodModNpcs(), 0
    for _, e in ipairs(list) do
        local done = false
        if unlimited then
            pcall(function() e:SetViewDistUnlimited(); done = true end)
        else
            pcall(function() e:SetViewDistRatio(n); done = true end)
        end
        if done then ok = ok + 1 end
    end
    lbLog("view dist ratio -> " .. (unlimited and "UNLIMITED" or tostring(n)) ..
          " on " .. ok .. "/" .. #list .. " mod NPC(s)")
    lbLog("  NEVER pass 0 to SetViewDistRatio itself - 0 is the MINIMUM and is what sabotaged")
    lbLog("  the original experiment. 0 here means unlimited, handled separately.")
end

-- merc_lod_lodratio <n>  mesh detail pin, higher drops detail sooner (100 default, 255 puppet)
function mercenaries:LodRatioSet(v)
    local n = tonumber(tostring(v or ""):match("%d+"))
    if not n then lbLog("merc_lod_lodratio <n>  (100 = default, higher drops detail sooner)"); return end
    local list, ok = self:LodModNpcs(), 0
    for _, e in ipairs(list) do
        local done = false
        pcall(function() e:SetLodRatio(n); done = true end)
        if done then ok = ok + 1 end
    end
    lbLog("mesh LOD ratio -> " .. n .. " on " .. ok .. "/" .. #list .. " mod NPC(s)")
end

-- merc_lod_cvar <name> <value>   set any cvar AND keep it: it joins the boost table, so the
-- per-tick reassert holds it against the engine's own context overrides.
function mercenaries:LodCvarSet(line)
    local name, val = tostring(line or ""):match("^%s*([%w_]+)%s+(-?[%d%.]+)%s*$")
    if not name then
        lbLog("merc_lod_cvar <name> <value>   e.g. merc_lod_cvar e_ViewDistRatio 300")
        lbLog("  it is remembered, so the per-tick reassert keeps it applied")
        return
    end
    val = tonumber(val)
    local before = getCVar(name)
    setCVar(name, val)
    for _, e in ipairs(self.LodBoostCvars) do
        if e[1] == name then e[2] = val
            lbLog(name .. ": " .. tostring(before) .. " -> " .. tostring(getCVar(name)) .. " (updated in the boost set)")
            return
        end
    end
    table.insert(self.LodBoostCvars, { name, val })
    lbLog(name .. ": " .. tostring(before) .. " -> " .. tostring(getCVar(name)) .. " (ADDED to the boost set)")
end

function mercenaries:LodBoostShutdown()
    self:LodBoostOff()
end

function mercenaries:LodBoostSet(v)
    local on = (tostring(v or ''):match('1') ~= nil)
    self.LodBoostEnabled = on
    if not on then self:LodBoostOff() end
    lbLog("battle LOD boost " .. (on and "ENABLED" or "DISABLED"))
end

function mercenaries:LodRatioAutoSet(v)
    self.LodRatioAuto = (tostring(v or ''):match('0') == nil)
    lbLog("crowd-scaled mesh LOD " .. (self.LodRatioAuto and "ON" or "OFF"))
    if self.LodRatioAuto then
        self._lodRatioBand = nil
        self:LodRatioAutoApply()
    else
        self:LodRatioReset()   -- ...and undo whatever the last band left on them
    end
end

function mercenaries:LodBoostStatus()
    lbLog("enabled=" .. tostring(self.LodBoostEnabled) ..
          " pinned=" .. tostring(self.LodBoostPinned) ..
          " active=" .. tostring(self.LodBoostActive) ..
          " crowd=" .. tostring((_G.MercCount or 0) + #(self.CachedEnemies or {})))
    for _, e in ipairs(self.LodBoostCvars) do
        lbLog("  " .. e[1] .. " = " .. tostring(getCVar(e[1])) .. " (boost " .. tostring(e[2]) .. ")")
    end
end

System.AddCCommand("merc_lod_auto",     "mercenaries:LodRatioAutoSet('%line')", "Crowd-scaled mesh LOD on/off: merc_lod_auto 0 | 1")
System.AddCCommand("merc_lod_vdr",      "mercenaries:LodVdrSet('%line')",   "Per-NPC view distance: merc_lod_vdr 254 | merc_lod_vdr max")
System.AddCCommand("merc_lod_lodratio", "mercenaries:LodRatioSet('%line')", "Per-NPC mesh detail: merc_lod_lodratio 100 (higher = drops sooner)")
System.AddCCommand("merc_lod_cvar",     "mercenaries:LodCvarSet('%line')",  "Set and KEEP any cvar: merc_lod_cvar e_ViewDistRatio 300")
System.AddCCommand("merc_lod_probe",   "mercenaries:LodProbe('%line')",  "Per-NPC render state: hidden / view-dist ratio / has-character / lod ratio")
System.AddCCommand("merc_lod_pinall",  "mercenaries:LodPinAllMercs()",   "Unlimited view distance on every merc (per-entity, not a cvar)")
System.AddCCommand("merc_lod_pin",    "mercenaries:LodBoostPin(true)",  "Hold the LOD boost on regardless of crowd")
System.AddCCommand("merc_lod_unpin",  "mercenaries:LodBoostPin(false)", "Let the crowd count decide again")
System.AddCCommand("merc_lod_boost",  "mercenaries:LodBoostSet('%line')",
                   "Battle AI-LOD budget boost on or off: merc_lod_boost 1 | 0")
System.AddCCommand("merc_lod_status", "mercenaries:LodBoostStatus()",
                   "Show the battle LOD boost state and the live cvar values")
