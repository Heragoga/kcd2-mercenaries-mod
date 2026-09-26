-- Who is the player actually fighting?
--
-- "Emerge from a fast travel already in combat with nothing nearby" has survived several
-- fixes to the patrol alert path, so this stops fixing and starts measuring. The player's
-- combat state is the ENGINE's verdict (player.soul:IsInCombatDanger) and it has no distance
-- term - an NPC engaged with him a kilometre away keeps him in it just as well as one in
-- front of him. So "there are no enemies nearby" is not evidence that nobody owns the state;
-- it is the reason we have to go and look for the owner.
--
-- Two records, both aimed straight at the standing theory that he passed somebody:
--   * a PASS LIST, sampled while the fast travel is actually running: every NPC the player
--     slid past, with where he passed them and how close.
--   * a rising-edge REPORT when combat starts, naming every NPC in combat anywhere in the
--     level, at what range, and cross-referenced against the pass list and the mod's own
--     aggro tables (ForcedTargetOf, LivePatrols alerts, ActiveMercs).
--
-- The enumeration is whole-level and therefore not cheap, but it runs once per fight on the
-- rising edge, not per tick - see mercenaries_solid.lua for what per-tick costs.

local function cwLog(s) System.LogAlways("[MercCombatWhy] " .. tostring(s)) end

-- OFF by default now the stalled-gang lock is diagnosed and leashed. The rising-edge report
-- walks every NPC in the level three times over (1755 of them in a real save), which is the
-- same cost class this mod just spent a week removing from SolidCandidates - fine as a probe
-- run on purpose, not something to leave firing on every fight for ever. The cheap half of the
-- diagnosis is always on regardless: the leash logs its own edges from mercenaries_patrols_live.
-- merc_combat_why 1 arms it again; with no argument it reports once, right now.
mercenaries.CombatWhyOn        = false
mercenaries.CombatWhyTickMs    = 500
mercenaries.CombatWhyPassRange = 150.0   -- how close counts as "passed him" during a travel.
-- Wide on purpose: the samples are taken a few per REAL second while the player crosses
-- kilometres, so consecutive spheres must overlap or he slides straight past somebody
-- between two of them and the pass list never sees the one that mattered.
mercenaries.CombatWhyPassKeep  = 40      -- most entries the pass list holds
mercenaries.CombatWhyFTWindow  = 120.0   -- a fight this soon after a travel is the one we mean
mercenaries.CombatWhyRepeat    = 30.0    -- re-report while combat drags on, to catch a stuck one
mercenaries.CombatWhyMaxList   = 25      -- lines per section

local NPC_CLASSES = { "NPC", "NPC_Female", "NPC_NAI" }

local function ekey(e) return e and tostring((e.this and e.this.id) or e.id) or nil end
local function nowT() local t = 0; pcall(function() t = System.GetCurrTime() or 0 end); return t end

local function ename(e)
    local n
    pcall(function() n = e:GetName() end)
    return n or "?"
end

-- IsInCombatDanger is NOT sufficient on an NPC, and the mod already measured that: see the
-- note in mercenaries_townwatch.lua, where it "read FALSE through an eight-merc massacre in
-- Kutna Hora". The first run of this probe reproduced it - 381 report lines, not one fighting
-- NPC found, including the player's OWN mercs during a live fight - so a bare "nobody is in
-- combat" from that call means nothing. Every signal the mod trusts elsewhere is asked here,
-- and which one answered is printed, so a false negative is visible instead of silent.
local COMBAT_CONTEXTS = {
    "combat_flee", "combat_surrender", "crime_interruptAttack", "crime_interruptFlee",
}

local function combatSignals(e)
    if not e then return nil end
    local sig = {}
    local v
    pcall(function() v = e.soul and e.soul:IsInCombatDanger() or false end)
    if v then sig[#sig + 1] = "danger" end
    v = nil
    pcall(function() v = e.human and e.human:IsWeaponDrawn() or false end)
    if v then sig[#sig + 1] = "weapon" end
    for _, ctx in ipairs(COMBAT_CONTEXTS) do
        local has
        pcall(function() has = e.soul and e.soul:HasScriptContext(ctx) or false end)
        if has then sig[#sig + 1] = ctx end
    end
    return (#sig > 0) and table.concat(sig, "+") or nil
end

local function inCombat(e)
    local v = false
    pcall(function() v = e.soul and e.soul:IsInCombatDanger() and true or false end)
    return v
end

local function dist2(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return dx * dx + dy * dy
end

mercenaries.CombatWhyPassed = {}     -- [key] = { name, x, y, at, near }
mercenaries._cwWasCombat    = false
mercenaries._cwLastReport   = nil

-- ==== the pass list ====
-- Sampled only while the fast-travel detector says a travel is running. Bounded sphere
-- queries, not a level walk: this one DOES run per tick.
function mercenaries:CombatWhySamplePass()
    local pp
    pcall(function() pp = player:GetWorldPos() end)
    if not pp then return end
    local t, r = nowT(), self.CombatWhyPassRange or 80.0
    local seen = self.CombatWhyPassed
    for _, cls in ipairs(NPC_CLASSES) do
        local ents
        pcall(function() ents = System.GetEntitiesInSphereByClass(pp, r, cls) end)
        for _, e in pairs(ents or {}) do
            local k = ekey(e)
            if k then
                local p
                pcall(function() p = e:GetWorldPos() end)
                if p then
                    local d = math.sqrt(dist2(pp, p))
                    local rec = seen[k]
                    -- keep the CLOSEST approach: that is what "passed him" means. The entity
                    -- itself is kept so the report can ask whether he is STILL fighting - the
                    -- key is a WUID string and System.GetEntity cannot resolve one.
                    if not rec then
                        seen[k] = { name = ename(e), x = p.x, y = p.y, at = t, near = d, ent = e }
                    elseif d < rec.near then
                        rec.near, rec.at, rec.x, rec.y, rec.ent = d, t, p.x, p.y, e
                    end
                end
            end
        end
    end
    -- bound it: drop the oldest once it outgrows the cap
    local n = 0
    for _ in pairs(seen) do n = n + 1 end
    while n > (self.CombatWhyPassKeep or 40) do
        local oldK, oldT = nil, nil
        for k, v in pairs(seen) do
            if not oldT or (v.at or 0) < oldT then oldK, oldT = k, v.at or 0 end
        end
        if not oldK then break end
        seen[oldK] = nil
        n = n - 1
    end
end

function mercenaries:CombatWhyPassClear(why)
    local n = 0
    for _ in pairs(self.CombatWhyPassed) do n = n + 1 end
    self.CombatWhyPassed = {}
    if n > 0 and why then cwLog("pass list cleared (" .. why .. "): " .. n .. " entry(s)") end
end

-- ==== the report ====
function mercenaries:CombatWhyReport(tag)
    local pp
    pcall(function() pp = player:GetWorldPos() end)
    if not pp then cwLog("no player position"); return end
    local t = nowT()

    local ftAgo = self.FastTravelLastDetected and (t - self.FastTravelLastDetected) or nil
    cwLog(string.format("==== %s ==== player signals: %s | last fast travel %s",
        tostring(tag),
        combatSignals(player) or "none",
        ftAgo and string.format("%.0fs ago", ftAgo) or "never this session"))

    -- 1. Everyone in the LEVEL, nearest first. No radius: the whole point is that the owner
    --    may be far away, which is exactly what "no enemies nearby" describes. The per-class
    --    totals are printed whether or not anything is fighting, because an empty enumeration
    --    and a peaceful level are indistinguishable otherwise - and the first run of this
    --    probe reported "NOBODY in combat" 381 times without ever saying how many it looked at.
    local all, counts = {}, {}
    for _, cls in ipairs(NPC_CLASSES) do
        local ents
        pcall(function() ents = System.GetEntitiesByClass(cls) end)
        local n = 0
        for _, e in pairs(ents or {}) do
            n = n + 1
            local p
            pcall(function() p = e:GetWorldPos() end)
            if p then
                all[#all + 1] = { k = ekey(e), name = ename(e),
                                  d = math.sqrt(dist2(pp, p)), sig = combatSignals(e) }
            end
        end
        counts[#counts + 1] = cls .. "=" .. n
    end
    table.sort(all, function(a, b) return a.d < b.d end)

    local fighting = {}
    for _, r in ipairs(all) do if r.sig then fighting[#fighting + 1] = r end end

    cwLog(string.format("   enumerated %d NPC(s) (%s); %d showing a combat signal",
                        #all, table.concat(counts, " "), #fighting))
    if #all == 0 then
        cwLog("   THE ENUMERATION CAME BACK EMPTY - this report proves nothing, not even absence.")
    end

    local ft, mt, att = self.ForcedTargetOf or {}, self.MercTargetOf or {}, self.AttackerSeen or {}
    local function tags(r)
        local s = ""
        if ft[r.k]  then s = s .. "  [forced target]" end
        if mt[r.k]  then s = s .. "  [a merc's target]" end
        if att[r.k] then s = s .. "  [attacked us]" end
        local passed = self.CombatWhyPassed[r.k]
        if passed then s = s .. string.format("  [PASSED at %.0fm]", passed.near) end
        return s
    end

    if #fighting > 0 then
        cwLog("   in combat, nearest first:")
        for i = 1, math.min(#fighting, self.CombatWhyMaxList or 25) do
            local f = fighting[i]
            cwLog(string.format("      %7.0fm  %-30s %-22s%s", f.d, f.name, f.sig, tags(f)))
        end
        if #fighting > (self.CombatWhyMaxList or 25) then
            cwLog(string.format("      ... and %d more", #fighting - (self.CombatWhyMaxList or 25)))
        end
    end

    -- The nearest handful regardless of state, so "no enemies nearby" stops being an
    -- impression and becomes a distance.
    cwLog("   nearest NPCs of any kind:")
    for i = 1, math.min(#all, 8) do
        local r = all[i]
        cwLog(string.format("      %7.0fm  %-30s %-22s%s", r.d, r.name, r.sig or "-", tags(r)))
    end

    -- 2. The mod's own aggro bookkeeping, so a stale entry is visible next to the fight.
    local nForced = 0
    for _ in pairs(self.ForcedTargetOf or {}) do nForced = nForced + 1 end
    local alerts = {}
    for _, rec in pairs(self.LivePatrols or {}) do
        if rec.alertAt then
            local q, d = nil, nil
            pcall(function() q = self:PatrolPointOf(rec) end)
            if q then d = math.sqrt(dist2(pp, q)) end
            alerts[#alerts + 1] = string.format("route %s slot %s: alerted %.0fs ago, spawned=%s, %s",
                tostring(rec.route), tostring(rec.slot), t - rec.alertAt,
                tostring(rec.spawned and true or false),
                d and string.format("%.0fm off", d) or "position unknown")
        end
    end
    local nMercs, nMercFight = 0, 0
    for _, e in pairs(self.ActiveMercs or {}) do
        nMercs = nMercs + 1
        if inCombat(e) then nMercFight = nMercFight + 1 end
    end
    local nAtt, nAttRecent = 0, 0
    for w in pairs(self.AttackerSeen or {}) do
        nAtt = nAtt + 1
        local recent = false
        pcall(function() recent = self:IsRecentAttacker(w) and true or false end)
        if recent then nAttRecent = nAttRecent + 1 end
    end
    cwLog(string.format("   ForcedTargetOf=%d  patrol alerts=%d  mercs %d/%d fighting  "
                        .. "attackers seen=%d (%d recent)",
                        nForced, #alerts, nMercFight, nMercs, nAtt, nAttRecent))
    for i = 1, math.min(#alerts, self.CombatWhyMaxList or 25) do cwLog("      " .. alerts[i]) end

    -- 3. What he passed on the way, whether or not any of them is fighting now.
    local passList = {}
    for k, v in pairs(self.CombatWhyPassed) do
        passList[#passList + 1] = { k = k, name = v.name, near = v.near, at = v.at, ent = v.ent }
    end
    table.sort(passList, function(a, b) return a.near < b.near end)
    if #passList == 0 then
        cwLog("   pass list empty - no NPC came within " ..
              tostring(self.CombatWhyPassRange) .. "m during the last travel")
    else
        cwLog(string.format("   passed %d NPC(s) during the last travel, closest first:", #passList))
        for i = 1, math.min(#passList, self.CombatWhyMaxList or 25) do
            local v = passList[i]
            local still = v.ent and inCombat(v.ent)
            cwLog(string.format("      %7.0fm  %-34s  %.0fs ago%s", v.near, v.name, t - (v.at or t),
                                still and "  [STILL IN COMBAT]" or ""))
        end
    end
    cwLog("==== end ====")
    self._cwLastReport = t
end

function mercenaries:CombatWhyTickDrive()
    if not self.CombatWhyOn then return end
    pcall(function()
        local t = nowT()
        local traveling = self.FastTravelLastDetected
                          and (t - self.FastTravelLastDetected) < 3.0
        if traveling then
            if not self._cwTraveling then
                self._cwTraveling = true
                self:CombatWhyPassClear("a new travel started")
            end
            self:CombatWhySamplePass()
        else
            self._cwTraveling = false
        end

        local now = inCombat(player)
        if now and not self._cwWasCombat then
            local ftAgo = self.FastTravelLastDetected and (t - self.FastTravelLastDetected)
            local tag = (ftAgo and ftAgo < (self.CombatWhyFTWindow or 120))
                        and "COMBAT STARTED after a fast travel" or "combat started"
            self:CombatWhyReport(tag)
        elseif now and self._cwLastReport
               and (t - self._cwLastReport) >= (self.CombatWhyRepeat or 30) then
            self:CombatWhyReport("still in combat")
        elseif (not now) and self._cwWasCombat then
            cwLog("combat ended")
            self._cwLastReport = nil
        end
        self._cwWasCombat = now
    end)
    self:ChainArm("CombatWhyTick", self.CombatWhyTickMs or 500)
end
mercenaries:ChainDef("CombatWhyTick", "CombatWhyTickDrive")

function mercenaries:CombatWhySet(line)
    local n = tonumber(tostring(line or ""):match("%-?%d+") or "")
    if n == nil then return self:CombatWhyReport("asked for") end
    self.CombatWhyOn = (n ~= 0)
    cwLog(self.CombatWhyOn and "on - will report whenever combat starts" or "off")
    if self.CombatWhyOn then self:ChainArm("CombatWhyTick", 500) end
end

System.AddCCommand("merc_combat_why", "mercenaries:CombatWhySet('%line')",
    "Who is the player actually fighting? No args reports now; 1/0 arms or stops the automatic report on every combat start")
