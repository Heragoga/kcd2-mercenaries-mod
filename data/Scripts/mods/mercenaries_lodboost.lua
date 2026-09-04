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
-- BANDED, not interpolated, and only changed when the band changes: scaling a LOD ratio
-- continuously off a live count is what caused pop-in the last time it was tried
-- (see RenderLodSet in mercenaries_util.lua).
--
-- SOFTENED TWICE. The first ladder started at crowd 30 and topped out at 300 - past the 255
-- this doc records as puppets at arm's length - so simply HIRING fifty men turned the company
-- into clay figures and left it there. The second (150/200, 100/160, 70/130) still coarsened
-- ordinary play: a company plus one raid clears crowd 70 without being a battle. The default
-- ladder now starts at a hundred bodies and tops out at 150, which is a visible cut only at
-- ranges where a man is a few pixels wide.
--
-- The trade is real - a softer ladder costs framerate in a big siege - so it is a SETTING
-- rather than a constant. merc_lod_quality picks the ladder; `performance` is the old one.
mercenaries.LodQualityPresets = {
    -- Never coarsen anything: mesh LOD stays exactly where the engine puts it, whatever the
    -- crowd. The AI-tier boost below still applies, so a siege is still simulated properly.
    crisp = {
        bands = {},
        uberlod = 3,
    },
    -- Default. Only a real battle coarsens, and never past 150.
    balanced = {
        bands = {
            { crowd = 190, ratio = 150 },   -- a full siege, ~190 NPCs
            { crowd = 140, ratio = 130 },
            { crowd = 100, ratio = 115 },
        },
        uberlod = 2,
    },
    -- What the mod shipped before: cheaper, and visibly so.
    performance = {
        bands = {
            { crowd = 150, ratio = 200 },
            { crowd = 100, ratio = 160 },
            { crowd =  70, ratio = 130 },
        },
        uberlod = 1,
    },
}
mercenaries.LodQualityDefault = "balanced"
mercenaries.LodQuality        = nil     -- resolved from the save on first use
mercenaries._lodQualityLoaded = false

mercenaries.LodRatioBands = mercenaries.LodQualityPresets.balanced.bands
mercenaries.LodRatioAuto  = true
mercenaries._lodRatioBand = nil

-- A band change is expensive: a 300m NPC query, a SetLodRatio per NPC and a log write.
-- The crowd count it keys off is live and noisy (CachedEnemies gains and loses entries
-- every scan as enemies close, die or re-engage), so a fight sitting near 70, 100 or 150
-- re-crossed the edge and paid that cost every 300ms tick. Hysteresis plus a dwell time
-- makes a band change a real event rather than jitter. See docs/performance.md.
mercenaries.LodRatioMargin    = 12     -- must clear the edge by this much to drop a band
mercenaries.LodRatioDwellSecs = 8.0    -- and no two changes closer together than this
mercenaries._lodRatioAt       = nil

-- Asymmetric on purpose: rising to a bigger crowd takes effect immediately, falling has
-- to clear the margin, so a fight that thins out briefly does not drop a band and bounce.
function mercenaries:LodRatioForCrowd(crowd, current)
    local margin = self.LodRatioMargin or 0
    for _, b in ipairs(self.LodRatioBands) do
        local edge = b.crowd
        if current and current == b.ratio then edge = edge - margin end
        if crowd >= edge then return b.ratio end
    end
    return nil   -- under the smallest band: hand mesh LOD back to the engine
end
-- Trigger on CROWD, but crowd must not be squad size alone: MercCount is a raw,
-- distance-unfiltered headcount, so at the old threshold of 8 simply HIRING that many mercs
-- latched the boost on permanently - in town, in camp, everywhere. Same false-trigger the
-- mesh-LOD ladder above already had and was banded to fix (see LodRatioBands and
-- docs/npc-lod.md:69-80). Mirrored here the same way: the threshold now sits well past
-- MaxCompanions, and mercs only join the count once there is something to fight. See
-- docs/performance.md, "The AI-LOD cvar boost".
mercenaries.LodBoostMinCrowd    = 70     -- our mercs + nearby hostiles past this = raise the budget
mercenaries.LodBoostRequireFoes = true   -- mercs count toward crowd only while CachedEnemies is non-empty
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
    -- AI half (ai=true). Pure CPU: how many NPCs the engine fully SIMULATES. Third field is
    -- the LOW-SPEC value used instead when LowSpecOn - see LodBoostValueFor. Splitting this
    -- from the renderer half below is the whole point: MEASURED, turning the boost off wholesale
    -- made parts of a siege STOP RENDERING (the renderer half is what draws the far ranks),
    -- while leaving the AI half at 260 is what pins a weak CPU at 15fps. They are opposite
    -- trades and were bundled into one switch, so neither could be made without the other.
    { "WH_AI_LOD_MaxCountDetail",            260, ai = true, low =  40 },   -- stock 70
    { "WH_AI_LOD_MaxCountLOD",               600, ai = true, low = 400 },   -- stock 400
    { "WH_AI_LOD_MaxDetailDistance",         250, ai = true, low =  70 },   -- stock 120
    { "WH_AI_LOD_Areas",                       0, ai = true, low =   2 },   -- stock 2 (visibility areas); 0 = distance only
    { "WH_AI_LOD_HysteresisMultiplierDetail",  1, ai = true, low = 0.8 },   -- stock 0.8, which biases NPCs out of Detail
    { "wh_ai_Lod_MoveIntervalLOD",          0.05, ai = true, low =   1 },   -- stock 1   - fake movement jumps -> continuous
    { "wh_ai_Lod_MoveIntervalMonsterLOD",   0.05, ai = true, low =  10 },   -- stock 10

    -- RENDERER side (docs/npc-lod.md section 4). These were missing, which is why raising the
    -- AI budget "did nothing": WH_AI_LOD_* governs how well an NPC is SIMULATED, not whether
    -- he is DRAWN. A live log measured e_ViewDistRatio = 50 and
    -- e_LodFaceAreaTargetSizeCharacterWH = 0.00305 - a battle context tightens both - so the
    -- men on the far wall were being culled and coarsened by the renderer no matter how many
    -- Detail slots the AI had.
    { "e_ViewDistRatio",                     200 },   -- measured 50; Battle.cfg uses 80
    { "e_ViewDistRatioCustom",               200 },   -- measured 60
    { "e_ViewDistRatioVegetation",           100 },   -- so the fort is not floating in bare ground
    -- DETAIL FLOOR (detail=true). Not "can you see them" but "how good does every one of them
    -- look", and it is applied BY RADIUS AND SCREEN SIZE, not by count:
    --   e_CharRenderLodMin  "Min LOD for character objects (used for rendering)"  -> 0 = every
    --                       character pinned to its HIGHEST detail mesh, whatever the distance
    --   e_LodFaceAreaTargetSizeCharacterWH  "Target radian span for LOD vertices for Characters"
    --                       -> 5x lower than measured stock, so detail is held 5x further out
    --
    -- MEASURED, and this is the whole siege story: a full battle ten metres off runs 30-50fps
    -- on two cores and the SAME battle with the player inside it runs 10-15. Bodies and AI
    -- budget are identical either way - what changes is how many characters are close enough
    -- to be held at LOD 0 by these three. And because wh_ca_PendulumMaxLodToSimulate only
    -- disables simulation "if animation lod of the character is HIGHER than this value",
    -- pinning LOD to 0 keeps cloth and pendulum simulation ON for every one of them - which is
    -- also why merc_render_lod (a per-entity SetLodRatio) did nothing during a siege: this
    -- global floor overrode it, re-pushed every 300ms by LodBoostReassert.
    --
    -- Under low spec these are handed straight back to the engine so distance LOD works again.
    -- The view-distance entries below are NOT touched - the battle stays visible.
    { "e_LodFaceAreaTargetSizeCharacterWH", 0.0006, detail = true }, -- measured 0.00305
    { "e_CharRenderLodMin",                    0, detail = true },
    { "e_CharLodMin",                          0, detail = true },

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
    -- Preset-driven (LodQualityPresets.uberlod): 1 swaps to the merged mesh as early as the
    -- engine offers it, 3 keeps the assembled outfit two LOD levels longer. Never -1.
    { "wh_cc_LodForUberlod",                   2 },
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

-- System.GetCVar can hand back a number or a string depending on the cvar, so compare
-- tolerantly - a float formatting mismatch (e.g. "0.05" vs 0.05) must not force a write.
local function cvarSame(cur, want)
    if cur == want then return true end
    local cn, wn = tonumber(cur), tonumber(want)
    if cn and wn then return cn == wn end
    return tostring(cur) == tostring(want)
end

-- Saves what is live RIGHT NOW rather than a hardcoded stock table: the game loads different
-- cvar overrides per context (Battle.cfg, performanceDemandingArea.cfg...), so the value to
-- restore is whatever was in force when the fight started, not what the docs measured once.
-- Which value this entry wants RIGHT NOW. The renderer half is unconditional - it is what
-- keeps a siege visible, and a battle you cannot see is not a performance win. The AI half
-- drops to its low-spec value under merc_lowspec_on, so the boost and low spec can be on at
-- the same time and mean "draw the whole battle, simulate less of it".
--
-- Without this, LodBoostReassert re-pushed 260 over low spec's 40 every 300ms and low spec's
-- main lever silently did nothing - which is exactly what the 2-core siege bench measured as
-- "no real improvement".
function mercenaries:LodBoostValueFor(e)
    -- A hand-set tweak outranks everything, including the boost's own value. Without this the
    -- 300ms reassert silently reverted anything typed at the console within a third of a second.
    local ov = (self.CvarOverride or {})[e[1]]
    if ov ~= nil then return ov end
    -- Armed by the company alone: the AI budget is the whole point, the renderer half (view
    -- distance 200 against a city's own 50) is exactly what makes the mod heavy in a town.
    if self.LodBoostAiOnly and not e.ai then return nil end
    if e.ai and self.LowSpecOn and e.low ~= nil then return e.low end
    -- nil = "do not boost this one at all"; the caller leaves whatever the engine has.
    if e.detail and (self.LowSpecOn or self.LodDetailFloorOff) then return nil end
    return e[2]
end

function mercenaries:LodBoostOn()
    if self.LodBoostActive or not self.LodBoostEnabled then return end

    local saved = {}
    for _, e in ipairs(self.LodBoostCvars) do
        saved[e[1]] = getCVar(e[1])
    end
    self._lodSaved = saved

    for _, e in ipairs(self.LodBoostCvars) do
        local want = self:LodBoostValueFor(e)
        if want ~= nil then setCVar(e[1], want) end
    end
    self.LodBoostActive = true
    if self.LodBoostAiOnly then
        lbLog("big company - AI Detail " .. tostring(saved["WH_AI_LOD_MaxCountDetail"]) ..
              " -> " .. tostring(self.LodBoostCvars[1][2]) .. " (AI half only, renderer untouched)")
    else
        lbLog("battle LOD raised - AI Detail " .. tostring(saved["WH_AI_LOD_MaxCountDetail"]) ..
              " -> " .. tostring(self.LodBoostCvars[1][2]) ..
              ", view dist " .. tostring(saved["e_ViewDistRatio"]) .. " -> 200")
    end
end

-- Put the values back on EVERY tick while boosted, rather than once when it starts.
-- Libs/Tables/CVarOverride.xml maps a game context to an override file with a PRIORITY, and
-- entering one (Battle, performanceDemandingArea, a level) re-applies its own numbers over
-- the top of ours - performanceDemandingArea.cfg alone clamps MaxDetailDistance=150,
-- MaxCountDetail=70 and e_ViewDistRatioCustom=80. Setting them once and walking away means
-- the boost survives only until the next context change, which in a battle is immediately.
--
-- Compare-before-write: read each cvar back and only call SetCVar when it actually differs, so
-- a tick nothing has reset costs ~22 reads instead of ~22 writes. Cadence stays 300ms - that is
-- what stops the LOD popping this system exists to fix. docs/performance.md.
function mercenaries:LodBoostReassert()
    if not self.LodBoostActive then return end
    for _, e in ipairs(self.LodBoostCvars) do
        local want = self:LodBoostValueFor(e)
        if want ~= nil and not cvarSame(getCVar(e[1]), want) then setCVar(e[1], want) end
    end
    -- Overrides for cvars the boost does not own (the cloth/pendulum budget, mostly). Same
    -- 300ms cadence, same compare-before-write, so a tweak sticks through a level's own
    -- CVarOverride re-application exactly like the boost does.
    for n, v in pairs(self.CvarOverride or {}) do
        if not (self._boostOwns or {})[n] and not cvarSame(getCVar(n), v) then setCVar(n, v) end
    end
    self:LodRatioAutoApply()
end

-- Pick the band for the current crowd and, only if it CHANGED, push it to every mod NPC.
-- Re-applying the same number every tick would be pointless work; changing it every tick
-- would be the pop-in bug.
-- Which ladder is in force. Loaded lazily from the save the first time anything asks,
-- the same way the difficulty and status-icon settings do it.
function mercenaries:LodQualityName()
    if not self._lodQualityLoaded then
        self._lodQualityLoaded = true
        local v
        pcall(function() v = self:LoadString("MercLodQuality") end)
        if not (v and self.LodQualityPresets[v]) then v = self.LodQualityDefault end
        self:LodQualityApply(v, true)
    end
    return self.LodQuality or self.LodQualityDefault
end

-- Swap ladders. `quiet` is the load path: no log line and nothing written back.
function mercenaries:LodQualityApply(name, quiet)
    local preset = self.LodQualityPresets[name]
    if not preset then return false end
    self.LodQuality    = name
    self.LodRatioBands = preset.bands
    for _, e in ipairs(self.LodBoostCvars) do
        if e[1] == "wh_cc_LodForUberlod" then e[2] = preset.uberlod end
    end
    -- Whatever band is currently pushed onto the NPCs belongs to the old ladder, and the
    -- dwell timer would otherwise hold the new one off for LodRatioDwellSecs.
    self._lodRatioAt = nil
    self:LodRatioReset()
    if self.LodBoostActive then self:LodBoostReassert() end
    if not quiet then
        lbLog("mesh LOD quality = " .. name)
    end
    return true
end

function mercenaries:LodQualitySet(v)
    local name = tostring(v or ""):match("%a+")
    if not (name and self.LodQualityPresets[name]) then
        lbLog("merc_lod_quality crisp | balanced | performance   (now: " ..
              tostring(self:LodQualityName()) .. ")")
        lbLog("  crisp       never coarsen mesh detail, whatever the crowd")
        lbLog("  balanced    only a real battle coarsens, and never past 150 (default)")
        lbLog("  performance the older, cheaper ladder")
        return
    end
    self._lodQualityLoaded = true
    self:LodQualityApply(name)
    self:SaveString("MercLodQuality", name)
end

function mercenaries:LodRatioAutoApply()
    if not self.LodRatioAuto then return end
    self:LodQualityName()      -- resolve the saved ladder before the first band is picked
    local crowd = (_G.MercCount or 0) + #(self.CachedEnemies or {})
    -- The siege knows its own headcount; CachedEnemies only sees what is near the player.
    pcall(function()
        local S = self.RBQ
        if S and S.active then
            crowd = (_G.MercCount or 0) + #(S.foot or {}) + #(S.archers or {})
        end
    end)
    local want = self:LodRatioForCrowd(crowd, self._lodRatioBand)
    if want == self._lodRatioBand then return end

    local now = 0
    pcall(function() now = System.GetCurrTime() or 0 end)
    if self._lodRatioAt and (now - self._lodRatioAt) < (self.LodRatioDwellSecs or 0) then
        return
    end
    self._lodRatioAt   = now
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

-- Called by the enemy-group spawner on a big burst: the bench measured 64 hidden-flips
-- DURING a battle, most at its start - the gap before CachedEnemies fills and the crowd
-- estimate arms the boost. A spawn of n knows the population is about to jump by n; arming
-- now means the budgets are already up when the men appear.
function mercenaries:LodBoostPrime(n)
    if not self.LodBoostEnabled then return end
    if (tonumber(n) or 0) < 10 then return end
    local now = 0
    pcall(function() now = System.GetCurrTime() or 0 end)
    self._lodLastFoeAt = now
    if not self.LodBoostActive then self:LodBoostOn() end
end

function mercenaries:LodBoostOff()
    if not self.LodBoostActive then return end
    for n, v in pairs(self._lodSaved or {}) do
        if v ~= nil then setCVar(n, v) end
    end
    self._lodSaved      = nil
    self.LodBoostActive = false
    self.LodBoostAiOnly = false
    self:LodRatioReset()
    lbLog("battle LOD budget restored")
end

-- crowd = mercs + nearby hostiles, but mercs only join the count once there is something to
-- fight (LodBoostRequireFoes) - otherwise a big idle squad alone latches the boost on. Second
-- return is the foe count, for callers that want to explain the number. docs/performance.md.
-- Third return: the company ALONE armed it (see LodBoostCompanyMin) - the caller then raises
-- only the AI half of the cvar set, never the renderer half.
mercenaries.LodBoostCompanyMin = 30   -- a company this big is simulated in full even with nobody to fight; 0 = never

function mercenaries:LodBoostCrowd()
    local foes  = #(self.CachedEnemies or {})
    local n     = _G.MercCount or 0
    local mercs = (self.LodBoostRequireFoes and foes == 0) and 0 or n
    -- The company on its own, out on the road, past LodBoostCompanyMin: the engine's 70-slot
    -- Detail budget cannot hold fifty men and their horses, and what falls out of it stands
    -- still or moves in jumps - "half the line follows, the rest stand about" (2026-09-03:
    -- 50 men, 30 of them flagged stalled at once). Not while camped: in camp they idle, and
    -- the sortie is smaller than the roster.
    local companyOnly = false
    local minN = self.LodBoostCompanyMin or 0
    if foes == 0 and minN > 0 and n >= minN and not self.CampActive then
        mercs, companyOnly = n, true
    end
    return mercs + foes, foes, companyOnly
end

-- Driven from CombatScanLoop (300ms). CachedEnemies is already built by that pass, so this
-- costs a table length and a clock read.
-- The ACTUAL population near the player, corpses included - counted only while it can
-- matter (boost active, or the cheap crowd estimate is near the threshold), because a wide
-- box query on every tick in a city is its own perf bug. The bench proved why this exists:
-- every recorded pop-in flip was a HIDDEN flip, and they clustered on boost transitions -
-- 64 in a big battle, 86 in its aftermath, 182 while deliberately cycling the pin. The
-- engine hides whatever exceeds the AI-LOD budgets, so dropping the budgets from 260/600
-- back to 70/400 while ~100 NPCs and corpses still stand HIDES the overflow in front of
-- the player. The budgets must never collapse below the standing population.
--
-- RELEASE ONLY - population may never ARM the boost. A 120m box in Kuttenberg holds 65+
-- NPCs with nobody fighting anybody, so arming on it meant walking into town overrode the
-- player's own quality settings and then re-pushed them against the engine's CVarOverride
-- three times a second. Crowd (which needs foes in it) is the only thing that arms.
-- See docs/performance.md, "The AI-LOD cvar boost".
mercenaries.LodBoostPopRelease   = 50   -- boost may only drop once population is below this
-- ...but for at most this long with no foes anywhere in the cache. The hold exists to cover
-- a battle's bodies while they still stand, so this has to clear PatrolCorpseSecs (180s)
-- with margin; it is a BOUND on the pathological case, not a tuning. A town's living
-- population sits above LodBoostPopRelease permanently, so without it a boost armed there
-- never came down again.
mercenaries.LodBoostPopHoldMax   = 240.0

function mercenaries:LodBoostPopulation()
    if not player then return 0 end
    local pp
    pcall(function() pp = player:GetWorldPos() end)
    if not pp then return 0 end
    local n = 0
    pcall(function()
        local ents = System.GetPhysicalEntitiesInBoxByClass(pp, 120.0, "NPC")
        for _ in pairs(ents or {}) do n = n + 1 end
    end)
    return n
end

function mercenaries:LodBoostTick()
    if not self.LodBoostEnabled then
        if self.LodBoostActive then self:LodBoostOff() end
        return
    end

    -- Pinned: somebody has told us there is a battle on. Never argue with them - but do ask
    -- whether the thing that pinned it still exists.
    --
    -- The pin is set when the Raborsch siege is built and released ONLY on the path where
    -- the siege is struck. Reach the end of that siege any other way - load a save from
    -- before it, die, walk away - and LodBoostPinned stays true with no siege standing, so
    -- every cvar in LodBoostCvars is re-pushed three times a second for the rest of the
    -- session. That includes e_ViewDistRatio at 200 against a measured 50, and it is
    -- deliberately fighting the game's own CVarOverride: performanceDemandingArea.cfg
    -- clamps exactly these numbers, and the dense areas it clamps them for are cities.
    -- A pin nobody is holding is the difference between "the mod is heavy in Kuttenberg"
    -- and not. See docs/performance.md.
    if self.LodBoostPinned then
        local held = true
        if self.LodBoostPinReason == "siege" then
            pcall(function() held = (self.RBQ and self.RBQ.active) and true or false end)
        end
        if not held then
            self:LodBoostPin(false)
            lbLog("boost was pinned by a siege that is no longer standing - unpinned")
        else
            if not self.LodBoostActive then self:LodBoostOn() end
            self:LodBoostReassert()
            return
        end
    end

    local crowd, _, companyOnly = self:LodBoostCrowd()
    local now   = 0
    pcall(function() now = System.GetCurrTime() or 0 end)

    -- Only the OFF decision reads this now, so a peaceful town no longer runs a 120m NPC
    -- query three times a second.
    local pop = 0
    if self.LodBoostActive then
        pop = self:LodBoostPopulation()
    end

    if crowd >= self.LodBoostMinCrowd or companyOnly then
        self._lodLastFoeAt = now
        -- Foes arriving while the company had it armed widen it to the full set on the next
        -- reassert; the renderer half is not narrowed again until the boost drops.
        if companyOnly and not self.LodBoostAiOnly and not self.LodBoostActive then
            self.LodBoostAiOnly = true
        elseif not companyOnly then
            self.LodBoostAiOnly = false
        end
        if not self.LodBoostActive then self:LodBoostOn() end
        self:LodBoostReassert()
    elseif self.LodBoostActive then
        -- Dropping the boost is what HIDES people when done too early: the budgets fall
        -- below the standing population and the engine hides the overflow (bench-measured:
        -- 86 hidden-flips in a battle's aftermath). Hold until the field itself has thinned.
        --
        -- BOUNDED, and it does not restamp: a town's population never falls below the
        -- release line at all, so a boost armed there (by LodBoostPrime, say, for a town
        -- watch muster) would have held for the rest of the session.
        local dry = self._lodLastFoeAt and (now - self._lodLastFoeAt)
                    or (self.LodBoostPopHoldMax or 240.0)
        if pop >= self.LodBoostPopRelease and dry < (self.LodBoostPopHoldMax or 240.0) then
            return
        end
        if dry >= self.LodBoostHoldSecs then self:LodBoostOff() end
    end
end

-- Put the engine back if the mod is torn down mid-fight; leaving global cvars raised would
-- outlive the mod itself.
-- Hold the boost on regardless of what the crowd count thinks.
-- `reason` names who is holding it, so LodBoostTick can check that they still exist. "siege"
-- is checked against RBQ.active; anything else (the console) is taken on trust and held until
-- it is released by hand.
function mercenaries:LodBoostPin(on, reason)
    self.LodBoostPinned = (on == true)
    if self.LodBoostPinned then
        self.LodBoostPinReason = reason or "console"
        self:LodBoostOn()
        lbLog("boost PINNED on by " .. self.LodBoostPinReason)
    else
        self.LodBoostPinReason = nil
        lbLog("boost unpinned - the crowd count decides again")
    end
end

-- Every field below is plain Lua and survives the level it was set in; the siege that set
-- them does not. Released unconditionally on load, because both are self-healing upward:
-- LodBoostTick re-raises the boost inside 300ms if the crowd is genuinely there, and
-- RaborschMonitor re-pins at 1Hz while a siege really is standing. Left alone, a save loaded
-- from before a siege carries the siege's global cvars for the rest of the session.
function mercenaries:LodBoostOnLoad()
    self.LodBoostPinned    = false
    self.LodBoostPinReason = nil
    self._lodLastFoeAt     = nil

    -- Deliberately NOT LodBoostOff(). _lodSaved holds what was live in the level we just
    -- LEFT, and the level we just entered has already applied its own CVarOverride set -
    -- so replaying the old numbers over it would be the same overreach in the other
    -- direction. Only a cvar still sitting at OUR boosted value is ours to hand back.
    if self.LodBoostActive then
        for _, e in ipairs(self.LodBoostCvars) do
            local prev = (self._lodSaved or {})[e[1]]
            local want = self:LodBoostValueFor(e)
            if prev ~= nil and want ~= nil and cvarSame(getCVar(e[1]), want) then setCVar(e[1], prev) end
        end
        self._lodSaved      = nil
        self.LodBoostActive = false
        self:LodRatioReset()
        lbLog("boost state dropped on load")
    end
    self._lodRatioBand = nil
    self._lodRatioAt   = nil
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

-- Takes a REAL boolean from the no-argument commands; the %line form silently no-opped.
function mercenaries:LodBoostSet(on)
    on = (on == true) or (tostring(on or ''):match('1') ~= nil)
    self.LodBoostEnabled = on
    self.LodBoostPinned  = self.LodBoostPinned and on or false
    if not on then self:LodBoostOff() end
    lbLog("battle LOD boost " .. (on and "ENABLED" or "DISABLED - AI stays on the engine's own budget"))
end

-- ---------------------------------------------------------------------------
-- LOW SPEC.
--
-- MEASURED on a 2-core-restricted machine: cloth simulation is worth ~5fps of ~25 with a
-- 50-man squad in a city, and NOTHING - not merc_render_lod 200, not merc_sim_off, not
-- merc_formation_off - moved the siege of Raborsch off ~15fps. That is the tell: the siege
-- is the one scene where the mod PINS the AI-LOD boost (RaborschStandUp -> LodBoostPin), and
-- the boost's entire job is to force more NPCs into the engine's expensive Detail tier -
-- MaxCountDetail 70 -> 260, MaxDetailDistance 120 -> 250, fake-move interval 1s -> 0.05s.
-- Mesh LOD and cloth sim cannot touch AI-tier cost, which is exactly why every knob failed.
--
-- On a strong CPU that trade is right (a siege where the far ranks actually fight). On a weak
-- one it is backwards, so this goes the OTHER way: it takes the boost off AND cuts the Detail
-- budget below stock, handing the engine's own crowd mechanism back the job it was built for.
--
-- Deliberately NOT automatic. Core count is not a reliable proxy for a CPU's single-thread
-- speed, and silently degrading a strong machine's siege is worse than a command nobody runs.
-- MEASURED AND REJECTED: cutting the AI Detail budget below stock (40 NPCs / 70m).
-- On a 2-core siege bench it produced "massive pop in and out" and NO framerate change -
-- 10-15fps at 40/70, at stock 70/120, and at the boost's own 260/250 alike. The AI tier
-- controls VISIBILITY as much as simulation (docs/npc-lod.md: four systems that stop an NPC
-- rendering while it keeps fighting), so cutting it makes the battle flicker and buys nothing.
-- Left here as a warning, deliberately empty: do not re-add an AI-budget cut to low spec.
mercenaries.LowSpecCvars = {}

-- How much of an encounter's authored population actually spawns under low spec. THE one
-- lever the bench left standing: a 190-NPC siege 10 metres away is 10-15fps on two cores, and
-- the same siege from a little further off is 30-50 - it is proximity x bodies, and no cvar
-- reaches it. Halving the bodies is the only honest fix, and it is a fair one: the siege
-- already scales to the company you bring.
-- Hand the character DETAIL FLOOR back to the engine while leaving view distance boosted:
-- the battle stays fully visible, but characters LOD by distance again instead of every one
-- of them being pinned to LOD 0. Standalone so it can be A/B'd on its own.
mercenaries.LodDetailFloorOff = false

function mercenaries:LodDetailFloorSet(off)
    self.LodDetailFloorOff = (off == true)
    if self.LodBoostActive then
        -- Put the three back before re-asserting, or they keep the boosted value we just
        -- stopped writing.
        if self.LodDetailFloorOff then
            for _, e in ipairs(self.LodBoostCvars) do
                if e.detail then
                    local prev = (self._lodSaved or {})[e[1]]
                    if prev ~= nil then setCVar(e[1], prev) end
                end
            end
        end
        self:LodBoostReassert()
    end
    lbLog("character detail floor " .. (self.LodDetailFloorOff and
          "OFF - characters LOD by distance again (battle still fully visible)" or
          "ON - every character pinned to max detail while a battle is up"))
end

mercenaries.EncounterScale        = 1.0
mercenaries.LowSpecEncounterScale = 0.5

-- Applied by every population count that spawns a crowd. Floors at 1 so an encounter never
-- becomes empty, and is a no-op at scale 1.
function mercenaries:ScaleEncounterCount(n)
    local s = self.EncounterScale or 1.0
    if s >= 1.0 or not n or n <= 1 then return n end
    local out = math.floor(n * s + 0.5)
    if out < 1 then out = 1 end
    return out
end

mercenaries.LowSpecOn = false
mercenaries._lowSpecSaved = nil

function mercenaries:LowSpecSet(on)
    on = (on == true)
    if on == self.LowSpecOn then lbLog("low spec already " .. (on and "ON" or "OFF")); return end
    if on then
        -- The boost stays entirely alone. Every AI-budget variant was measured and none moved
        -- the framerate; the only thing low spec can honestly cut is per-character work
        -- (cloth, torches) and the NUMBER OF CHARACTERS - see EncounterScale.
        pcall(function() self:SimTierApply("lean") end)
        pcall(function() self.CampTorchMax = 0; self:CampStripAllTorches(true) end)
        -- Population is deliberately NOT cut here. It was the fallback when the detail
        -- floor had not yet been found, and cutting the field is a design change the
        -- author has ruled out. merc_encounter_scale still exists for anyone who wants it.
        self:LodDetailFloorSet(true)
        self.LowSpecOn = true
        -- Re-push immediately so a siege already standing switches to the low AI values this
        -- tick instead of at the next 300ms reassert.
        if self.LodBoostActive then self:LodBoostReassert() end
        lbLog("LOW SPEC on: character detail floor OFF, cloth sim lean, torches off")
        lbLog("  AI-LOD budgets are deliberately untouched - every variant was benched and none")
        lbLog("  changed the framerate, while cutting them made the battle pop in and out.")
        lbLog("  The battle stays fully VISIBLE - only the max-detail pin is released, so the")
        lbLog("  men around you LOD by distance like every other character in the game.")
    else
        self:LodDetailFloorSet(false)
        self.LowSpecOn = false
        pcall(function() self:SimTierApply("normal") end)
        pcall(function() self.CampTorchMax = 2 end)
        self.LodBoostEnabled = true
        if self.LodBoostActive then self:LodBoostReassert() end
        lbLog("LOW SPEC off: everything handed back")
    end
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
    local crowd, foes = self:LodBoostCrowd()
    local why
    if self.LodBoostPinned then
        why = "pinned"
    elseif not self.LodBoostEnabled then
        why = "disabled"
    elseif crowd >= self.LodBoostMinCrowd then
        why = "crowd >= min"
    elseif self.LodBoostActive then
        local now = 0
        pcall(function() now = System.GetCurrTime() or 0 end)
        local left = self.LodBoostHoldSecs - (now - (self._lodLastFoeAt or now))
        why = string.format("holding, crowd < min, %.0fs left", math.max(0, left))
    elseif self.LodBoostRequireFoes and foes == 0 then
        why = "crowd < min (no hostiles, mercs not counted)"
    else
        why = "crowd < min"
    end
    lbLog("enabled=" .. tostring(self.LodBoostEnabled) ..
          " pinned=" .. tostring(self.LodBoostPinned) ..
          " active=" .. tostring(self.LodBoostActive) ..
          " crowd=" .. tostring(crowd) .. " foes=" .. tostring(foes) ..
          " min=" .. tostring(self.LodBoostMinCrowd) ..
          " why=" .. why)
    lbLog("mesh LOD quality=" .. tostring(self:LodQualityName()) ..
          " band=" .. (self._lodRatioBand and tostring(self._lodRatioBand) or "engine default"))
    for _, e in ipairs(self.LodBoostCvars) do
        lbLog("  " .. e[1] .. " = " .. tostring(getCVar(e[1])) .. " (boost " .. tostring(e[2]) .. ")")
    end
end

mercenaries:DevCommand("merc_lod_auto",     "mercenaries:LodRatioAutoSet('%line')", "Crowd-scaled mesh LOD on/off: merc_lod_auto 0 | 1")
mercenaries:DevCommand("merc_lod_vdr",      "mercenaries:LodVdrSet('%line')",   "Per-NPC view distance: merc_lod_vdr 254 | merc_lod_vdr max")
mercenaries:DevCommand("merc_lod_lodratio", "mercenaries:LodRatioSet('%line')", "Per-NPC mesh detail: merc_lod_lodratio 100 (higher = drops sooner)")
mercenaries:DevCommand("merc_lod_cvar",     "mercenaries:LodCvarSet('%line')",  "Set and KEEP any cvar: merc_lod_cvar e_ViewDistRatio 300")
mercenaries:DevCommand("merc_lod_probe",   "mercenaries:LodProbe('%line')",  "Per-NPC render state: hidden / view-dist ratio / has-character / lod ratio")
mercenaries:DevCommand("merc_lod_pinall",  "mercenaries:LodPinAllMercs()",   "Unlimited view distance on every merc (per-entity, not a cvar)")
mercenaries:DevCommand("merc_lod_pin",    "mercenaries:LodBoostPin(true)",  "Hold the LOD boost on regardless of crowd")
mercenaries:DevCommand("merc_lod_unpin",  "mercenaries:LodBoostPin(false)", "Let the crowd count decide again")
-- merc_lod_boost_on/off are registered at PLAYER tier in mercenaries_commands.lua (no-arg).
mercenaries:DevCommand("merc_lod_status", "mercenaries:LodBoostStatus()",
                   "Show the battle LOD boost state and the live cvar values")

-- ---------------------------------------------------------------------------
-- SIMULATION BUDGET - "decent visuals, less simulation"
--
-- The measured shape of the mid-range problem (32 cores = 60fps with 50 mercs full-view;
-- 2 cores = immediate collapse; looking AWAY recovers ~10fps; merc_render_lod 200 recovers
-- ~10fps while they stay visible) is a per-character CPU cost that is occluded when they are
-- not on screen and reduced when their LOD index rises. That is character SIMULATION, not
-- draw: KCD2 gates it on LOD and screen size, and the engine's own help text says so.
--
--   wh_ca_PendulumMaxLodToSimulate   "Disable simulation of pendulums if animation lod of the
--                                     character is higher than this value."
--   wh_ca_ClothDisableSimulationAtDistance
--                                    "Distance at which cloth simulation is disabled..."
--   ca_ClothBypassSimulation         "if this is 1 actual cloth simulation is disabled
--                                     (WRAP SKINNING STILL WORKS)"
--   wh_ca_SocketsBypassSimulation    socket/pendulum sim off, collisions still resolved
--
-- That last pair is the important discovery: bypassing cloth SIMULATION is not the same as
-- dropping mesh detail. Wrap skinning keeps the garment deforming with the body, so the men
-- still look like men - unlike merc_render_lod 200, which buys the same framerate by making
-- them ugly. These are ENGINE-GLOBAL, so they also cheapen the hundreds of vanilla NPCs in a
-- city, which is where the cost actually lives.
--
-- Tiers, cheapest visual damage first. Values are restored from what was live when the tier
-- was applied, exactly like LodBoostOn.
mercenaries.SimTiers = {
    -- Trim the far/small end only. Should be visually free: it only stops simulating cloth
    -- that is already distant or tiny on screen, and lets the adaptive budget skip more frames.
    trim = {
        { "wh_ca_ClothDisableSimulationAtDistance", 12 },
        { "wh_ca_ClothEnableSimulationSSaxisSizePerc", 12 },
        { "wh_ca_ClothBudgetMaxFramesToSkip", 6 },
        { "wh_ca_PendulumMaxLodToSimulate", 1 },
    },
    -- Cloth simulated only on what is close and large; pendulums (scabbards, pouches, hair)
    -- only at LOD 0. The squad marching beside you still simulates.
    lean = {
        { "wh_ca_ClothDisableSimulationAtDistance", 6 },
        { "wh_ca_ClothEnableSimulationSSaxisSizePerc", 25 },
        { "wh_ca_ClothBudgetMaxFramesToSkip", 10 },
        { "wh_ca_PendulumMaxLodToSimulate", 0 },
    },
    -- Simulation off, skinning on. The garments still follow the body; they just stop
    -- swinging. This is the one to reach for on a weak CPU - it is what merc_render_lod was
    -- approximating, without the visual cost.
    off = {
        { "ca_ClothBypassSimulation", 1 },
        { "wh_ca_SocketsBypassSimulation", 1 },
        { "wh_ca_PendulumMaxLodToSimulate", 0 },
    },
}
mercenaries.SimTierOrder = { "trim", "lean", "off" }
mercenaries.SimTier      = nil
mercenaries._simSaved    = nil

function mercenaries:SimTierApply(name)
    if name == nil or name == "" then
        lbLog("merc_sim trim | lean | off | normal   (now: " .. tostring(self.SimTier or "normal") .. ")")
        lbLog("  trim    stop simulating cloth that is far away or tiny on screen - visually free")
        lbLog("  lean    simulate only what is close and large; pendulums at LOD 0 only")
        lbLog("  off     cloth/socket SIMULATION off, wrap skinning still on - they look right,")
        lbLog("          they just stop swinging. Best framerate for the least ugliness.")
        lbLog("  normal  hand every value back to the engine")
        for _, k in ipairs(self.SimTierOrder) do
            for _, e in ipairs(self.SimTiers[k]) do
                lbLog(string.format("    [%s] %-42s now %s", k, e[1], tostring(getCVar(e[1]))))
            end
        end
        return
    end

    -- Always restore first, so tiers do not stack and "normal" is exact.
    if self._simSaved then
        for n, v in pairs(self._simSaved) do if v ~= nil then setCVar(n, v) end end
        self._simSaved, self.SimTier = nil, nil
    end
    if name == "normal" then lbLog("simulation budget: back to engine defaults"); return end

    local tier = self.SimTiers[name]
    if not tier then lbLog("unknown tier '" .. tostring(name) .. "' - try trim | lean | off | normal"); return end

    local saved = {}
    for _, e in ipairs(tier) do saved[e[1]] = getCVar(e[1]) end
    self._simSaved = saved
    for _, e in ipairs(tier) do setCVar(e[1], e[2]) end
    self.SimTier = name
    lbLog("simulation budget: " .. name .. " (" .. #tier .. " cvar(s)); mesh detail untouched")
end

-- merc_sim_* are registered at PLAYER tier in mercenaries_commands.lua.

function mercenaries:LowSpecStatus()
    lbLog("low spec: " .. (self.LowSpecOn and "ON" or "off"))
    lbLog("  cloth sim tier      : " .. tostring(self.SimTier or "normal"))
    lbLog("  night torches       : " .. tostring(self.CampTorchMax or 0))
    lbLog("  char detail floor   : " .. (self.LodDetailFloorOff and "OFF (LOD by distance)" or "on (pinned max)"))
    lbLog("  encounter scale     : " .. tostring(math.floor((self.EncounterScale or 1) * 100)) .. "%")
    lbLog("  battle LOD boost    : " .. (self.LodBoostEnabled and "enabled" or "DISABLED") ..
          (self.LodBoostActive and " (active now)" or ""))
    lbLog("  NOTE: AI-LOD budgets are untouched by design - benched, no fps effect, and cutting")
    lbLog("  them makes NPCs pop in and out. Population is the lever that works.")
end

function mercenaries:EncounterScaleSet(f)
    self.EncounterScale = tonumber(f) or 1.0
    lbLog("encounter population scale = " .. tostring(math.floor(self.EncounterScale * 100)) ..
          "% (read at SPAWN - retrigger the encounter for it to apply)")
end

-- ---------------------------------------------------------------------------
-- TWEAK BENCH
--
-- Every cvar this investigation touches, as a stepped ladder with NO-ARGUMENT commands. No
-- %line anywhere: the key and the direction are baked into each command body, because %line
-- substitution has silently no-opped twice on this console and a benchmark knob that does
-- nothing is worse than no knob at all.
--
-- Every set goes through CvarOverride, which LodBoostValueFor consults FIRST - so a tweak
-- outranks the battle boost and survives its 300ms reassert instead of being reverted within
-- a third of a second. merc_tw_reset drops the lot.
mercenaries.CvarOverride = {}
mercenaries._boostOwns   = {}

mercenaries.TweakDefs = {
  -- ---- character detail: how good every character looks. Applied BY RADIUS, not by count ----
  { key="charrender", cvar="e_CharRenderLodMin",                       boost=0,      stock=nil,
    ladder={0,1,2,3},
    note="min LOD for character RENDERING; 0 pins every character to max detail" },
  { key="charlod",    cvar="e_CharLodMin",                             boost=0,      stock=nil,
    ladder={0,1,2,3},
    note="min LOD for character objects" },
  { key="facearea",   cvar="e_LodFaceAreaTargetSizeCharacterWH",       boost=0.0006, stock=0.00305,
    ladder={0.0006,0.001,0.0015,0.002,0.00305,0.005,0.008},
    note="radian span for character LOD; LOWER holds detail further out" },

  -- ---- uberlod / outfit streaming: prime suspect for vanish-and-reappear popping ----
  { key="uberlod",    cvar="wh_cc_LodForUberlod",                      boost=2,      stock=nil,
    ladder={0,1,2,3,4,5},
    note="LOD at which the merged uberlod mesh takes over; NEVER -1" },
  { key="uberdist",   cvar="wh_cc_UberlodLoadDistRatio",               boost=100,    stock=nil,
    ladder={25,50,75,100},
    note="percent of max view distance at which uberlods load" },
  { key="unloadhyst", cvar="wh_cc_UnloadHysteresisDist",               boost=80,     stock=nil,
    ladder={20,40,60,80,120,160},
    note="metres of hysteresis before an outfit is unloaded" },
  { key="attachcull", cvar="ca_AttachmentCullingRation",               boost=1000,   stock=1000,
    ladder={100,300,600,1000},
    note="attachment culling ratio (system.cfg itself ships 1000)" },

  -- ---- view distance: whether distant things draw AT ALL ----
  { key="viewdist",   cvar="e_ViewDistRatio",                          boost=200,    stock=50,
    ladder={50,80,100,150,200,300},
    note="global view distance ratio" },
  { key="viewdistc",  cvar="e_ViewDistRatioCustom",                    boost=200,    stock=60,
    ladder={50,80,100,150,200,300},
    note="custom-object view distance ratio" },
  { key="itemdist",   cvar="wh_item_ViewDistRatio",                    boost=200,    stock=nil,
    ladder={50,100,150,200},
    note="weapons and items view distance" },

  -- ---- simulation: cloth and pendulums, gated on LOD INDEX ----
  { key="pendulum",   cvar="wh_ca_PendulumMaxLodToSimulate",           boost=nil,    stock=nil,
    ladder={0,1,2,3,4},
    note="simulate pendulums only while LOD is <= this" },
  { key="clothdist",  cvar="wh_ca_ClothDisableSimulationAtDistance",   boost=nil,    stock=nil,
    ladder={3,6,12,20,40,80},
    note="metres past which cloth simulation is dropped" },
  { key="clothsize",  cvar="wh_ca_ClothEnableSimulationSSaxisSizePerc", boost=nil,   stock=nil,
    ladder={5,12,25,40,60},
    note="screen-size percent below which cloth simulation is dropped" },
  { key="clothskip",  cvar="wh_ca_ClothBudgetMaxFramesToSkip",         boost=nil,    stock=nil,
    ladder={1,3,6,10,20},
    note="frames the adaptive cloth budget may skip" },
  { key="clothoff",   cvar="ca_ClothBypassSimulation",                 boost=nil,    stock=0,
    ladder={0,1},
    note="1 = cloth SIMULATION off, wrap skinning still on" },
  { key="socketoff",  cvar="wh_ca_SocketsBypassSimulation",            boost=nil,    stock=0,
    ladder={0,1},
    note="1 = socket/pendulum simulation off" },

  -- ---- animation and job scheduling: a DIFFERENT system from mesh LOD, never benched ----
  { key="animbatch",  cvar="wh_ca_AnimationComputationJobBatchSize",   boost=nil,    stock=nil,
    ladder={1,2,4,8,16,32},
    note="job batch size for animation computation; pure dispatch granularity, same maths" },
  { key="jointmask",  cvar="ca_UseJointMasking",                       boost=nil,    stock=nil,
    ladder={0,1},
    note="use joint masking to speed up motion decoding (skeleton CPU, not render)" },
  { key="shadowmerge", cvar="ca_DrawAttachmentsMergedForShadows",      boost=nil,    stock=nil,
    ladder={0,1},
    note="merge worn pieces into one shadow submission per character" },
  { key="xformforce", cvar="wh_ai_TransformManagerForceUpdateCloseObjects", boost=nil, stock=nil,
    ladder={0,1},
    note="force-update nearby AI actors every tick regardless of visibility" },
  { key="xformbudget", cvar="wh_ai_TransformManagerUpdateBudget",      boost=nil,    stock=nil,
    ladder={50,100,200,-1},
    note="per-frame budget for AI transform updates; -1 is uncapped" },

  -- ---- AI tier: benched flat for fps, but it gates VISIBILITY ----
  { key="aidetail",   cvar="WH_AI_LOD_MaxCountDetail",                 boost=260,    stock=70,
    ladder={40,70,120,180,260},
    note="how many NPCs are fully simulated; cutting it makes them pop in and out" },
  { key="aidist",     cvar="WH_AI_LOD_MaxDetailDistance",              boost=250,    stock=120,
    ladder={70,120,180,250},
    note="metres within which an NPC may hold the Detail tier" },
}

function mercenaries:TweakFind(key)
    for _, t in ipairs(self.TweakDefs) do if t.key == key then return t end end
    return nil
end

-- Nearest ladder rung to whatever the cvar reads RIGHT NOW, so stepping starts from reality
-- rather than from an assumed default.
local function ladderIndex(t, cur)
    cur = tonumber(cur)
    if cur == nil then return 1 end
    local best, bestD = 1, nil
    for i, v in ipairs(t.ladder) do
        local dd = math.abs(v - cur)
        if bestD == nil or dd < bestD then best, bestD = i, dd end
    end
    return best
end

function mercenaries:TweakStep(key, dir)
    local t = self:TweakFind(key)
    if not t then lbLog("unknown tweak: " .. tostring(key) .. " - merc_tw lists them"); return end
    local i = ladderIndex(t, getCVar(t.cvar)) + dir
    if i < 1 then i = 1 end
    if i > #t.ladder then i = #t.ladder end
    self:TweakSet(key, t.ladder[i])
end

function mercenaries:TweakSet(key, val)
    local t = self:TweakFind(key)
    if not t then return end
    local before = getCVar(t.cvar)
    self.CvarOverride[t.cvar] = val
    setCVar(t.cvar, val)
    local got = getCVar(t.cvar)
    local warn = ""
    if tostring(got) == tostring(before) and tostring(before) ~= tostring(val) then
        warn = "   <-- DID NOT TAKE (cvar may not exist in this build)"
    end
    lbLog(string.format("%-44s %s -> %s%s", t.cvar, tostring(before), tostring(got), warn))
    lbLog("    " .. t.note)
end

function mercenaries:TweakClear(key)
    local t = self:TweakFind(key)
    if not t then return end
    self.CvarOverride[t.cvar] = nil
    lbLog(t.cvar .. ": override dropped - the boost or the engine owns it again")
    if self.LodBoostActive then self:LodBoostReassert() end
end

function mercenaries:TweakReset()
    local n = 0
    for _ in pairs(self.CvarOverride) do n = n + 1 end
    self.CvarOverride = {}
    lbLog("dropped " .. n .. " cvar override(s); boost and engine values apply again")
    if self.LodBoostActive then self:LodBoostReassert() end
end

function mercenaries:TweakList()
    lbLog("=== tweak bench ===   merc_tw_KEY_up | _down | _reset      merc_tw_reset = all")
    for _, t in ipairs(self.TweakDefs) do
        local cur = getCVar(t.cvar)
        local i   = ladderIndex(t, cur)
        local ov  = (self.CvarOverride[t.cvar] ~= nil) and "  [OVERRIDE]" or ""
        lbLog(string.format("%-11s %-44s = %-9s step %d/%d%s",
              t.key, t.cvar, tostring(cur), i, #t.ladder, ov))
        lbLog(string.format("            %s%s%s", t.note,
              t.boost and ("   (boost " .. tostring(t.boost) .. ")") or "",
              t.stock and ("   (stock " .. tostring(t.stock) .. ")") or ""))
    end
    lbLog("boostActive=" .. tostring(self.LodBoostActive) ..
          "  lowspec=" .. tostring(self.LowSpecOn) ..
          "  detailFloorOff=" .. tostring(self.LodDetailFloorOff) ..
          "  simTier=" .. tostring(self.SimTier or "normal"))
end

-- Which cvars the boost set already owns, so the reassert knows which overrides it must
-- carry itself (the cloth and pendulum budget is not in the boost table).
for _, e in ipairs(mercenaries.LodBoostCvars) do mercenaries._boostOwns[e[1]] = true end

-- Registered here, not in mercenaries_commands.lua: TweakDefs is defined in this file and
-- commands.lua loads first. cmd() there is only AddCCommand plus a help-table entry.
do
    local function twCmd(name, body, desc)
        if mercenaries.CmdHelpText then mercenaries.CmdHelpText[name] = desc end
        pcall(function() System.AddCCommand(name, body, desc) end)
    end
    for _, t in ipairs(mercenaries.TweakDefs) do
        twCmd("merc_tw_" .. t.key .. "_up",
              "mercenaries:TweakStep('" .. t.key .. "', 1)",
              t.cvar .. " one step UP - " .. t.note)
        twCmd("merc_tw_" .. t.key .. "_down",
              "mercenaries:TweakStep('" .. t.key .. "', -1)",
              t.cvar .. " one step DOWN - " .. t.note)
        twCmd("merc_tw_" .. t.key .. "_reset",
              "mercenaries:TweakClear('" .. t.key .. "')",
              t.cvar .. " - drop the override")
    end
    twCmd("merc_tw",       "mercenaries:TweakList()",  "List every tweakable cvar, its live value and ladder position")
    twCmd("merc_tw_reset", "mercenaries:TweakReset()", "Drop every cvar override")
end

-- ---------------------------------------------------------------------------
-- AUTO-TUNER
--
-- Walks the tweak bench looking for the cheapest configuration that still looks acceptable,
-- measuring real frames between every change.
--
-- COORDINATE DESCENT, not gradient descent: the search space is a set of discrete ladders,
-- so there is no gradient to follow. It takes one cvar at a time, steps it in the direction
-- that makes it CHEAPER, keeps the step if the framerate actually improved by more than the
-- noise floor, and moves on when it stops paying. Repeats until a whole pass buys nothing.
--
-- It deliberately does NOT maximise fps. A pure fps search has one answer - everything at
-- minimum - and that is the ugly result merc_render_lod 200 already gave. Each cvar carries a
-- VISUAL COST, and a step is only accepted if it earns more fps than that cost demands, so
-- free wins (simulation nobody can see) are taken first and expensive ones (view distance,
-- character detail) have to justify themselves.
--
-- MEASUREMENT is frames per second over a fixed window, from System.GetFrameID - the same
-- source as the profiler's frame histogram. That makes it only as good as the scene: STAND
-- STILL, DO NOT MOVE THE CAMERA. A turn mid-window is worth more fps than any cvar here and
-- will be attributed to whatever was being tested.
mercenaries.OptRunning     = false
mercenaries.OptWindowSecs  = 5.0     -- measurement window per configuration
mercenaries.OptSettleSecs  = 1.0     -- discarded after a change, so a swap is not measured
-- MEASURED noise floor: 19 control trials in a scene the tuner itself called stable drifted
-- -5.7%..+3.1%, mean absolute 2.2%. A 2.0% acceptance bar was BELOW that, so the tuner could
-- and did accept pure noise. 6% is comfortably outside it - which also means any real win
-- smaller than ~6% is simply not measurable with a 5s window in a live game, and pretending
-- otherwise is how a run ends up reporting three disjoint sets of winners.
mercenaries.OptMinGainPct  = 6.0
mercenaries.OptVCostPct    = 2.5     -- extra gain demanded per point of visual cost
mercenaries.OptSlot        = 0

-- vcost: 0 = invisible (simulation only), 1 = subtle, 2 = clearly visible, 3 = drastic.
-- cheap: the ladder direction that REDUCES cost.
-- Ordered deliberately: everything invisible is tried before anything anyone can see.
mercenaries.OptPlan = {
    { key="clothskip",  cheap= 1, vcost=0 },
    { key="clothsize",  cheap= 1, vcost=0 },
    { key="clothdist",  cheap=-1, vcost=0 },
    { key="pendulum",   cheap=-1, vcost=0 },
    { key="socketoff",  cheap= 1, vcost=1 },
    { key="clothoff",   cheap= 1, vcost=1 },
    { key="unloadhyst", cheap=-1, vcost=1 },
    { key="uberdist",   cheap=-1, vcost=1 },
    { key="attachcull", cheap=-1, vcost=1 },
    -- Animation/job levers. Invisible by construction (batching and masking change how the
    -- same maths is scheduled, not what it produces), so they are tried early with the other
    -- free wins. shadowmerge is vcost 1: watch for seams at helmet/pauldron boundaries.
    { key="animbatch",  cheap= 1, vcost=0 },
    { key="jointmask",  cheap= 1, vcost=0 },
    { key="xformforce", cheap=-1, vcost=0 },
    { key="xformbudget", cheap=-1, vcost=0 },
    { key="shadowmerge", cheap= 1, vcost=1 },
    { key="uberlod",    cheap=-1, vcost=2 },
    { key="facearea",   cheap= 1, vcost=2 },
    { key="charrender", cheap= 1, vcost=2 },
    { key="charlod",    cheap= 1, vcost=2 },
    { key="itemdist",   cheap=-1, vcost=2 },
    { key="viewdistc",  cheap=-1, vcost=3 },
    { key="viewdist",   cheap=-1, vcost=3 },
    -- aidetail / aidist are deliberately absent: benched flat for framerate across a 6.5x
    -- range, and cutting them makes NPCs pop in and out. See docs/performance.md.
}

local function optClock()
    local c = (os and os.clock) and os.clock() or nil
    if c then return c end
    local t = 0; pcall(function() t = System.GetCurrTime() or 0 end); return t
end

local function optFrame()
    local f; pcall(function() f = System.GetFrameID() end); return f
end

function mercenaries:OptLog(s) System.LogAlways("[MercOpt] " .. tostring(s)) end

-- Snapshot every cvar the plan can touch, so merc_opt_revert is exact.
function mercenaries:OptSnapshot()
    local snap = {}
    for _, step in ipairs(self.OptPlan) do
        local t = self:TweakFind(step.key)
        if t then snap[step.key] = getCVar(t.cvar) end
    end
    return snap
end

function mercenaries:OptStart()
    if self.OptRunning then self:OptLog("already running - merc_opt_stop first"); return end
    if not self.TweakDefs then self:OptLog("tweak bench missing"); return end

    self.OptRunning   = true
    self.OptSlot      = 1 - (self.OptSlot or 0)
    self.OptStartCfg  = self:OptSnapshot()
    self.OptBestCfg   = self:OptSnapshot()
    self.OptIdx       = 0            -- 0 = still measuring the baseline
    self.OptBestFps   = nil
    self.OptBaseFps   = nil
    self.OptPass      = 1
    self.OptChanged   = 0            -- accepted THIS pass (drives another pass)
    self.OptChangedAll = 0           -- accepted in total (what the summary should report)
    self.OptTrials    = 0
    self.OptPending   = nil          -- the step being evaluated right now
    self.OptControlIn = self.OptControlEvery or 4   -- probes until the next control trial
    self.OptDrift     = 0            -- how many times the scene moved under us

    self:OptLog("=== auto-tune starting ===")
    self:OptLog("STAND STILL AND DO NOT MOVE THE CAMERA, and do not do this during a fight.")
    -- Print the starting configuration. Successive runs in one session are NOT independent
    -- unless you reset: a previous run's accepted overrides are still applied, so run two
    -- starts from run one's answer. Values that are not on a ladder (seen in a real session:
    -- clothsize 0.04, facearea 0.0013, uberdist 1.1) are the tell that this happened.
    -- merc_tw_reset before merc_opt for a clean, comparable run.
    local off = 0
    for _, step in ipairs(self.OptPlan) do
        local t = self:TweakFind(step.key)
        if t and self.CvarOverride[t.cvar] ~= nil then off = off + 1 end
    end
    if off > 0 then
        self:OptLog("NOTE: starting from " .. off .. " override(s) left by an earlier run or by hand.")
        self:OptLog("      merc_tw_reset first if you want a run comparable with a previous one.")
    end
    self:OptLog("A camera turn is worth more fps than any cvar here and will be blamed on")
    self:OptLog("whatever was being tested at the time.")
    self:OptLog(string.format("window %.0fs + %.0fs settle, %d knobs, needs +%.1f%% (plus %.1f%% per point of visual cost)",
        self.OptWindowSecs, self.OptSettleSecs, #self.OptPlan, self.OptMinGainPct, self.OptVCostPct))
    self:OptLog(string.format("a control trial re-measures the kept config every %d probes; a %.0f%% swing there "
        .. "means the SCENE moved, not the settings", self.OptControlEvery or 4, self.OptDriftPct or 8))
    self:OptLog("merc_opt_stop aborts, merc_opt_revert puts everything back.")
    self:OptBeginWindow()
end

function mercenaries:OptBeginWindow()
    self._optWinStartAt = optClock() + (self.OptSettleSecs or 0)
    self._optWinFrame   = nil
    Script.SetTimerForFunction(250, "mercenaries.OptTick" .. self.OptSlot)
end

-- Returns fps for the window, or nil while it is still filling.
function mercenaries:OptSampleWindow()
    local now, fr = optClock(), optFrame()
    if not fr then return -1 end                    -- no frame counter: abort upstream
    if now < self._optWinStartAt then return nil end -- settling; ignore
    if not self._optWinFrame then
        self._optWinFrame, self._optWinFrom = fr, now
        return nil
    end
    local dt = now - self._optWinFrom
    if dt < (self.OptWindowSecs or 5) then return nil end
    return (fr - self._optWinFrame) / dt
end

function mercenaries:OptApplyCfg(cfg)
    for key, val in pairs(cfg or {}) do
        if val ~= nil then self:TweakSet(key, tonumber(val) or val) end
    end
end

function mercenaries:OptFinish(why)
    self.OptRunning = false
    self:OptApplyCfg(self.OptBestCfg)
    self:OptLog("=== auto-tune " .. why .. " ===")
    if self.OptBaseFps and self.OptBestFps then
        self:OptLog(string.format("fps %.1f -> %.1f  (%+.1f%%) after %d trial(s), %d change(s)",
            self.OptBaseFps, self.OptBestFps,
            (self.OptBestFps - self.OptBaseFps) / math.max(self.OptBaseFps, 0.001) * 100,
            self.OptTrials or 0, self.OptChangedAll or 0))
        if (self.OptDrift or 0) > 0 then
            self:OptLog(string.format("WARNING: the scene moved under the test %d time(s). A fight ending, "
                .. "NPCs dying or the camera turning is worth more fps than any cvar here - treat this "
                .. "run's numbers as suspect and re-run somewhere quiet.", self.OptDrift))
        end
    end
    self:OptLog("settings kept (merc_opt_revert restores what you started with):")
    for _, step in ipairs(self.OptPlan) do
        local t = self:TweakFind(step.key)
        local was, now = self.OptStartCfg[step.key], self.OptBestCfg[step.key]
        if t and tostring(was) ~= tostring(now) then
            self:OptLog(string.format("   %-11s %-42s %s -> %s", step.key, t.cvar, tostring(was), tostring(now)))
        end
    end
end

function mercenaries:OptStop()
    if not self.OptRunning then self:OptLog("not running"); return end
    self:OptFinish("STOPPED by hand")
end

function mercenaries:OptRevert()
    if self.OptRunning then self.OptRunning = false end
    if not self.OptStartCfg then self:OptLog("nothing to revert to"); return end
    self:OptApplyCfg(self.OptStartCfg)
    self:OptLog("reverted to the configuration auto-tune started from")
end

-- One measurement window has completed; decide what it means and set up the next.
-- How often to re-measure the CURRENT BEST configuration as a control, and how far it may
-- drift before the scene is declared to have moved.
--
-- MEASURED THE HARD WAY: a run in a town with a fight going on in the background reported
-- 20.7 -> 60.1 fps (+190.9%) and credited it to two cvars. The log line immediately after was
-- "[LootSweep] Battle over" - the fight had ended, which is worth three times any cvar here.
-- Four runs of the same plan in the same session then picked three disjoint sets of winners.
-- Without a control, coordinate descent does not optimise the settings; it optimises the
-- noise, and every accepted step is whatever happened to coincide with the scene getting
-- easier.
--
-- The control re-measures the configuration already accepted. If the world has not changed it
-- reproduces OptBestFps. If it does not, the difference is the SCENE, not the settings, so
-- OptBestFps is renormalised to it - otherwise every later comparison is against a number
-- that no longer exists, and the run either accepts everything (scene got easier) or nothing
-- (scene got harder).
mercenaries.OptControlEvery   = 4      -- probes between control trials
mercenaries.OptDriftPct       = 8.0    -- control this far from best = the scene moved
mercenaries.OptDriftAbort     = 6      -- give up after this many drifts

function mercenaries:OptOnResult(fps)
    self.OptTrials = (self.OptTrials or 0) + 1

    -- Baseline.
    if self.OptIdx == 0 then
        self.OptBaseFps, self.OptBestFps = fps, fps
        self.OptIdx = 1
        self:OptLog(string.format("baseline %.1f fps", fps))
        return self:OptNextProbe()
    end

    -- Control trial: nothing was changed for it, so any difference is the world moving.
    if self.OptControlPending then
        self.OptControlPending = false
        local drift = (fps - self.OptBestFps) / math.max(self.OptBestFps, 0.001) * 100
        if math.abs(drift) >= (self.OptDriftPct or 8) then
            self.OptDrift = (self.OptDrift or 0) + 1
            self:OptLog(string.format("  [control]   %.1f fps vs %.1f expected (%+.1f%%) - THE SCENE MOVED, "
                .. "rebaselining (drift %d/%d)", fps, self.OptBestFps, drift, self.OptDrift, self.OptDriftAbort or 6))
            self.OptBestFps = fps
            if (self.OptDrift or 0) >= (self.OptDriftAbort or 6) then
                self:OptLog("too much scene drift to measure anything - find somewhere quiet, no fighting, and re-run")
                return self:OptFinish("ABORTED - scene too unstable")
            end
        else
            self:OptLog(string.format("  [control]   %.1f fps vs %.1f expected (%+.1f%%) - stable", fps, self.OptBestFps, drift))
            -- Track the best estimate anyway; a small honest drift still moves the target.
            self.OptBestFps = (self.OptBestFps + fps) * 0.5
        end
        return self:OptNextProbe()
    end

    local p = self.OptPending
    if p then
        local need = (self.OptMinGainPct or 2) + (p.vcost or 0) * (self.OptVCostPct or 2.5)
        local gain = (fps - self.OptBestFps) / math.max(self.OptBestFps, 0.001) * 100
        if gain >= need then
            self.OptBestFps = fps
            self.OptBestCfg[p.key] = getCVar(self:TweakFind(p.key).cvar)
            self.OptChanged = (self.OptChanged or 0) + 1
            self.OptChangedAll = (self.OptChangedAll or 0) + 1
            self:OptLog(string.format("  %-11s -> %-9s %.1f fps  (%+.1f%%, needed %+.1f%%)  KEPT",
                p.key, tostring(self.OptBestCfg[p.key]), fps, gain, need))
            -- Still paying: take another step the same way before moving on.
            p.steps = (p.steps or 0) + 1
            if p.steps < 4 then return self:OptProbeStep(p) end
        else
            self:OptLog(string.format("  %-11s -> %-9s %.1f fps  (%+.1f%%, needed %+.1f%%)  reverted",
                p.key, tostring(getCVar(self:TweakFind(p.key).cvar)), fps, gain, need))
            -- Put this one back to the best-known value and stop exploring it.
            local t = self:TweakFind(p.key)
            if t and self.OptBestCfg[p.key] ~= nil then
                self:TweakSet(p.key, tonumber(self.OptBestCfg[p.key]) or self.OptBestCfg[p.key])
            end
        end
        self.OptIdx = self.OptIdx + 1
    end
    return self:OptNextProbe()
end

-- Move one rung in the cheap direction and measure.
function mercenaries:OptProbeStep(p)
    local t = self:TweakFind(p.key)
    if not t then self.OptIdx = self.OptIdx + 1; return self:OptNextProbe() end
    local before = getCVar(t.cvar)
    self:TweakStep(p.key, p.cheap)
    local after = getCVar(t.cvar)
    if tostring(before) == tostring(after) then
        -- Ladder end, or the cvar does not exist in this build. Nothing to learn here.
        self.OptIdx = self.OptIdx + 1
        return self:OptNextProbe()
    end
    self.OptPending = p
    return self:OptBeginWindow()
end

function mercenaries:OptNextProbe()
    if not self.OptRunning then return end
    if self.OptIdx > #self.OptPlan then
        if (self.OptChanged or 0) > 0 and (self.OptPass or 1) < 3 then
            self.OptPass    = (self.OptPass or 1) + 1
            self.OptIdx     = 1
            self.OptChanged = 0
            self:OptLog("--- pass " .. self.OptPass .. " (something was still paying) ---")
        else
            return self:OptFinish("converged")
        end
    end
    -- Due a control? Measure the accepted configuration again, changing nothing.
    self.OptControlIn = (self.OptControlIn or 0) - 1
    if self.OptControlIn <= 0 and self.OptBestFps then
        self.OptControlIn = self.OptControlEvery or 4
        self.OptControlPending = true
        self.OptPending = nil
        self:OptApplyCfg(self.OptBestCfg)
        return self:OptBeginWindow()
    end

    local step = self.OptPlan[self.OptIdx]
    if not step then return self:OptFinish("converged") end
    local p = { key = step.key, cheap = step.cheap, vcost = step.vcost, steps = 0 }
    return self:OptProbeStep(p)
end

function mercenaries.OptBeat(slot)
    local self = mercenaries
    if not self.OptRunning or self.OptSlot ~= slot then return end
    local fps = self:OptSampleWindow()
    if fps == -1 then
        self:OptLog("System.GetFrameID unavailable - cannot measure, aborting")
        self.OptRunning = false
        return
    end
    if fps == nil then
        Script.SetTimerForFunction(250, "mercenaries.OptTick" .. slot)
        return
    end
    self:OptOnResult(fps)
end

function mercenaries.OptTick0() mercenaries.OptBeat(0) end
function mercenaries.OptTick1() mercenaries.OptBeat(1) end

do
    local function optCmd(name, body, desc)
        if mercenaries.CmdHelpText then mercenaries.CmdHelpText[name] = desc end
        pcall(function() System.AddCCommand(name, body, desc) end)
    end
    optCmd("merc_opt",        "mercenaries:OptStart()",  "Auto-tune the render/simulation cvars by measuring fps. STAND STILL.")
    optCmd("merc_opt_stop",   "mercenaries:OptStop()",   "Stop auto-tuning and keep the best configuration found")
    optCmd("merc_opt_revert", "mercenaries:OptRevert()", "Undo everything auto-tune changed")
end

-- ---------------------------------------------------------------------------
-- SHIPPED SIMULATION DEFAULTS
--
-- The three cvars mod.cfg sets, mirrored here so they can be turned off in game and so they
-- survive anything that overwrites them mid-session (a level's own CVarOverride, or the
-- battle boost's reassert). mod.cfg applies them at launch; this keeps them applied.
--
-- Measured by merc_opt in the siege of Raborsch on two cores: 21.6 -> 29.3 fps, +35.7%, over
-- 46 trials. All three are SIMULATION cuts. Every detail/LOD/view-distance knob was tried in
-- the same run and none survived its threshold. See mod.cfg for the full write-up.
mercenaries.PerfDefaults = {
    { "wh_ca_ClothBudgetMaxFramesToSkip", 20 },
    { "wh_ca_PendulumMaxLodToSimulate",    1 },
    { "ca_ClothBypassSimulation",          1 },
}
mercenaries.PerfDefaultsOn    = true
mercenaries._perfDefaultsRead = false
mercenaries._perfPreset       = nil    -- what was live before we first applied them

-- Loaded lazily from the save the first time anything asks, the same way the LOD quality and
-- difficulty settings do it.
function mercenaries:PerfDefaultsLoad()
    if self._perfDefaultsRead then return end
    self._perfDefaultsRead = true
    local v
    pcall(function() v = self:LoadString("MercPerfDefaults") end)
    if v == "0" then self.PerfDefaultsOn = false end
end

function mercenaries:PerfDefaultsApply()
    self:PerfDefaultsLoad()
    if not self.PerfDefaultsOn then return end
    if not self._perfPreset then
        local pre = {}
        for _, e in ipairs(self.PerfDefaults) do pre[e[1]] = getCVar(e[1]) end
        self._perfPreset = pre
    end
    for _, e in ipairs(self.PerfDefaults) do
        if not cvarSame(getCVar(e[1]), e[2]) then setCVar(e[1], e[2]) end
    end
end

-- READ-ONLY unless something actually moved. mod.cfg already sets these at launch and is the
-- documented place that survives CVarOverride re-application, so in the normal case this
-- never writes anything - it exists only to catch a context switch (Battle.cfg,
-- performanceDemandingArea.cfg) that stomps them mid-session.
--
-- Deliberately NOT on a fast tick. Re-pushing engine cvars three times a second is exactly
-- the kind of thing that can cost more than it saves: a write to a character cvar may make
-- the engine re-evaluate every character, and if some context re-applies its own value every
-- frame the two would fight, re-initialising cloth on every pass. Three reads every five
-- seconds cannot do that, and the first repair is logged so we find out whether mod.cfg alone
-- was sufficient all along.
--
-- pcall(System.GetCVar, n) rather than pcall(function() ... end): the closure form allocates
-- on every call, which is the per-tick garbage this codebase has already had to remove once.
function mercenaries:PerfDefaultsVerify()
    if not self.PerfDefaultsOn or not self._perfDefaultsRead then return end
    for _, e in ipairs(self.PerfDefaults) do
        local ok, cur = pcall(System.GetCVar, e[1])
        if ok and not cvarSame(cur, e[2]) then
            setCVar(e[1], e[2])
            if not self._perfDriftSeen then
                self._perfDriftSeen = true
                lbLog("NOTE: " .. e[1] .. " was changed to " .. tostring(cur) ..
                      " by something else and has been put back - mod.cfg alone is not enough here")
            end
        end
    end
end

function mercenaries:PerfDefaultsSet(on)
    on = (on == true)
    self:PerfDefaultsLoad()
    self.PerfDefaultsOn = on
    pcall(function() self:SaveString("MercPerfDefaults", on and "1" or "0") end)
    if on then
        self:PerfDefaultsApply()
        lbLog("simulation defaults ON - cloth budget 20, pendulums at LOD 0 only, cloth sim off")
        lbLog("  measured +35.7% (21.6 -> 29.3 fps) in a siege on two cores; no visual LOD changed")
    else
        for _, e in ipairs(self.PerfDefaults) do
            local prev = (self._perfPreset or {})[e[1]]
            if prev ~= nil then setCVar(e[1], prev) end
        end
        lbLog("simulation defaults OFF - cloth simulates normally again (costs framerate on a weak CPU)")
    end
end

function mercenaries:PerfDefaultsStatus()
    self:PerfDefaultsLoad()
    lbLog("simulation defaults: " .. (self.PerfDefaultsOn and "ON" or "off"))
    for _, e in ipairs(self.PerfDefaults) do
        lbLog(string.format("   %-38s = %-8s (want %s)", e[1], tostring(getCVar(e[1])), tostring(e[2])))
    end
    lbLog("   merc_perf_defaults_off restores the engine's own values for these three.")
end

do
    local function pdCmd(name, body, desc)
        if mercenaries.CmdHelpText then mercenaries.CmdHelpText[name] = desc end
        pcall(function() System.AddCCommand(name, body, desc) end)
    end
    pdCmd("merc_perf_defaults_on",     "mercenaries:PerfDefaultsSet(true)",  "Shipped simulation savings ON (default): cloth budget, pendulum LOD, cloth sim off")
    pdCmd("merc_perf_defaults_off",    "mercenaries:PerfDefaultsSet(false)", "Shipped simulation savings OFF - full cloth simulation, lower framerate")
    pdCmd("merc_perf_defaults_status", "mercenaries:PerfDefaultsStatus()",   "Are the shipped simulation savings applied, and what are they")
end

-- Clean run: drop every override, then tune from the engine's own values. This is the one to
-- use when comparing runs, or when a previous run left the config somewhere odd.
function mercenaries:OptFresh()
    self:TweakReset()
    self:OptStart()
end
do
    local function c(n,b,d)
        if mercenaries.CmdHelpText then mercenaries.CmdHelpText[n]=d end
        pcall(function() System.AddCCommand(n,b,d) end)
    end
    c("merc_opt_fresh", "mercenaries:OptFresh()",
      "Drop every cvar override, then auto-tune from a clean state (use this to compare runs)")
end

-- ==== the battle cvar bench ====
--
-- A scripted battle pushes a whole cfg of rendering numbers (see
-- mercenaries_battle_cvars.lua, generated from the game's own files). One of them may well
-- be why mercenaries vanish in those battles: e_LodFaceAreaTargetSizeCharacterWH is a
-- CHARACTER lod lever that only changes when a battle cfg loads, and the ~44-session
-- investigation in docs/npc-lod.md ruled out the AI lod system but never this.
--
-- So: apply them ONE AT A TIME in ordinary play, with the company standing in front of you,
-- and watch for the moment they go. Values go through CvarOverride, not a bare SetCVar,
-- because LodBoostReassert re-writes every cvar it owns every 300ms and would otherwise
-- undo the experiment within a third of a second.
mercenaries.BattleCvarApplied = {}   -- [cvar] = value it held before we touched it

local function bcLog(s) System.LogAlways("[BattleCvar] " .. tostring(s)) end

function mercenaries:BattleCvarSpecKey()
    local spec; pcall(function() spec = System.GetCVar("sys_spec") end)
    return string.gsub(tostring(tonumber(spec) or spec or ""), "%.0$", "")
end

function mercenaries:BattleCvarWanted(name)
    local key = self:BattleCvarSpecKey()
    local blk = (self.BattleCvarBySpec or {})[key] or (self.BattleCvarBySpec or {})["default"] or {}
    local v = blk[name]
    if v == nil then v = ((self.BattleCvarBySpec or {})["default"] or {})[name] end
    return v
end

function mercenaries:BattleCvarList()
    local key = self:BattleCvarSpecKey()
    bcLog("=== battle cvars (sys_spec " .. key .. ") ===")
    bcLog("merc_battlecvar <n> | <n> <value> | all | off        (off restores everything)")
    for i, n in ipairs(self.BattleCvarOrder or {}) do
        local cur; pcall(function() cur = System.GetCVar(n) end)
        local want = self:BattleCvarWanted(n)
        local mark = self.BattleCvarApplied[n] and "  [APPLIED]" or ""
        local own  = (self._boostOwns or {})[n] and "  (boost owns)" or ""
        bcLog(string.format("%2d  %-46s now=%-12s battle=%-12s%s%s",
              i, n, tostring(cur), tostring(want), mark, own))
    end
    local n = 0
    for _ in pairs(self.BattleCvarApplied) do n = n + 1 end
    bcLog(n .. " applied by hand. Watchdog cvar detection is " ..
          (self.MQWCvarSuppressed and "SUPPRESSED while any is applied" or "live"))
end

function mercenaries:BattleCvarApply(name, val)
    local before; pcall(function() before = System.GetCVar(name) end)
    if self.BattleCvarApplied[name] == nil then self.BattleCvarApplied[name] = before end
    -- CvarOverride first: LodBoostValueFor consults it before the boost's own number, and
    -- LodBoostReassert carries the ones the boost does not own. Without this the 300ms
    -- reassert silently puts the old value back and the test reads as "no effect".
    self.CvarOverride[name] = val
    pcall(function() System.SetCVar(name, val) end)
    local got; pcall(function() got = System.GetCVar(name) end)
    local warn = ""
    if tostring(got) ~= tostring(val) then warn = "   <-- DID NOT TAKE" end
    bcLog(string.format("%-46s %s -> %s%s", name, tostring(before), tostring(got), warn))
    -- The watchdog matches on these very numbers, so a hand-applied profile would read as a
    -- real battle and teleport the company away mid-experiment.
    self.MQWCvarSuppressed = true
end

function mercenaries:BattleCvarOff()
    local n = 0
    for name, before in pairs(self.BattleCvarApplied) do
        self.CvarOverride[name] = nil
        if before ~= nil then pcall(function() System.SetCVar(name, before) end) end
        n = n + 1
    end
    self.BattleCvarApplied = {}
    self.MQWCvarSuppressed = false
    bcLog(n .. " cvar(s) put back; watchdog cvar detection is live again")
    if self.LodBoostActive then self:LodBoostReassert() end
end

function mercenaries:BattleCvarCmd(line)
    local a = self:CmdArgs(line)
    local w = string.lower(tostring(a[1] or ""))
    if w == "" then return self:BattleCvarList() end
    if w == "off" or w == "reset" then return self:BattleCvarOff() end
    if w == "all" then
        for _, n in ipairs(self.BattleCvarOrder or {}) do
            local want = self:BattleCvarWanted(n)
            if want ~= nil then self:BattleCvarApply(n, want) end
        end
        bcLog("the whole battle profile is now on. merc_battlecvar off puts it back.")
        return
    end
    local i = tonumber(w)
    local name = i and (self.BattleCvarOrder or {})[i]
    if not name then
        -- Also accept the cvar's own name, which is what anyone reading the list will type.
        for _, n in ipairs(self.BattleCvarOrder or {}) do
            if string.lower(n) == w then name = n; break end
        end
    end
    if not name then
        bcLog("no such entry: " .. tostring(a[1]) .. "   (merc_battlecvar lists them)")
        return
    end
    local val = a[2]
    if val == nil then val = self:BattleCvarWanted(name) end
    if val == nil then bcLog("no battle value for " .. name .. " at this spec - give one explicitly"); return end
    self:BattleCvarApply(name, val)
end
