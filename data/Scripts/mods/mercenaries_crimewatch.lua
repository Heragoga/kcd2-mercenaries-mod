-- Crime watchdog. Diagnostic only: it spawns nothing, changes no state and touches no
-- vanilla table. It watches and it logs.
--
-- Two passes share one scheduler slot:
--   CrimeKillPass  a census of the vanilla NPCs around the party. Anyone who was alive
--                  last pass and is a corpse this pass is a death - classified,
--                  attributed to the player or to a merc, and logged.
--   CrimeHeatPass  the player's standing with the crowd he is actually standing in,
--                  logged on CHANGE rather than every tick.
--
-- Classification is the engine's own, not ours. crime_isAuthority / crime_isSecurity /
-- crime_isCivilian are Entity script contexts that vanilla's own crime AI branches on
-- (references/AI/crime/getAuthorityKindByContext.xml), so soul:HasScriptContext answers
-- "is this a guard" exactly the way the game answers it.
--
-- Names are the fallback, because they only half carry the role: quest-scene NPCs are
-- named for their job (setkaniVRatbori1_ratiborGuard, prepadeniVlasskehoDvora_civilian)
-- but the ambient town population is kkut_man_412, not kkut_guard_412. What the name
-- DOES carry reliably is the SETTLEMENT - every level NPC is <4-letter place>_<role>_<n>
-- and the prefix maps 1:1 onto the editor layer it lives in. That is CrimePlaces, and it
-- is how the heat pass knows which village the player is standing in.
--
-- There is no Lua bind for the player's angriness/crime rating - the whole reputation
-- surface is write-only from Lua (soul:ModifyPlayerReputation) and readable only from a
-- behaviour tree (CheckAngrinessInterval). So heat is measured from the crowd instead:
-- how many of the townsfolk around the player have gone to the hostile floor, whether he
-- is a public enemy, and whether he is under arrest.

local function cwLog(s) System.LogAlways("[CrimeWatch] " .. tostring(s)) end

local function nowT()
    local t = 0
    pcall(function() t = System.GetCurrTime() or 0 end)
    return t
end

local function dist(a, b)
    if not (a and b) then return nil end
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- ==== config ====

-- OFF by default. The crime watchdog and the town watch it feeds are unfinished and are
-- shipped dormant: the scheduler gates on this flag, so while it is false neither costs a
-- single scan. Turn the pair on for a session with `merc_dev` then `merc_townwatch_enable`
-- (mercenaries_townwatch.lua). See docs/town-watch.md.
mercenaries.CrimeWatchEnabled = false

mercenaries.CrimeScanRadius   = 45.0   -- census sphere around the player
mercenaries.CrimeAttribRange  = 25.0   -- a body further than this from all of us is not ours
mercenaries.CrimeClaimMemory  = 12.0   -- seconds a merc's target claim still counts as evidence
mercenaries.CrimeSeenExpiry   = 90.0   -- forget a living NPC we have not seen for this long
mercenaries.CrimeDeadExpiry   = 600.0  -- ...and a body, so one corpse is never counted twice
mercenaries.CrimeHeatSecs     = 5.0    -- how often the standing pass runs
-- How many locals of one settlement have to be in the sphere before we call it that
-- settlement. Two, not one: a single Kutna Hora carter met on a forest road should not
-- turn the forest into a town, and any inhabited place has more than one inhabitant.
mercenaries.CrimeSettlementQuorum = 2
mercenaries.CrimeHostileFloor = -0.99  -- relationship at or below this is "he has turned on us"
mercenaries.CrimeEventLogMax  = 40     -- ring buffer the status command prints

-- Log deaths we cannot pin on the company. Off by default: a battle two streets away
-- would otherwise fill the log with other people's business.
mercenaries.CrimeLogUnattributed = false

-- ==== state ====

mercenaries.CWSeen   = {}   -- [wuidStr] = { name, at }        living NPCs, last pass they were seen
mercenaries.CWDead   = {}   -- [wuidStr] = time                bodies already accounted for
mercenaries.CWClaim  = {}   -- [wuidStr] = time                last time a merc held this one as its target
mercenaries.CWTally  = { guard = 0, civilian = 0, other = 0, unattributed = 0 }
mercenaries.CWEvents = {}   -- ring buffer of formatted kill lines
mercenaries.CWHeat   = { placeKey = nil, place = nil, isCity = false, locals = 0,
                         crowd = 0, guards = 0, hostiles = 0, publicEnemy = false,
                         underArrest = false, inTown = false, at = 0 }
mercenaries._cwHeatAt = 0
mercenaries._cwHeatSig = nil

-- ==== who is a townsman, and where ====

-- Level NPC name prefixes. Both maps were read straight off the EditorLayer paths in
-- references/*level data*/objects_mission0.xml, where every NPC's name prefix and its
-- layer agree (kboh_man_10 lives under Main/kboh_bohounovice/...).
mercenaries.CrimePlaces = {
    -- Kuttenberg
    kkut = "Kutna Hora",   ksta = "Stara Kutna",  kgru = "Grunta",
    kpri = "Pritoky",      kvrc = "Vrchlicko",    kmis = "Miskovice",
    khor = "Horany",       klor = "Lorec",        kbyl = "Bylany",
    krab = "Rabstejnsko",  krat = "Ratboricko",   kvys = "Vysoka",
    kmez = "Mezholezsko",  kkuk = "Kuklicko",     knab = "Na Bylance",
    ksuc = "Suchdol",      kboh = "Bohounovice",  kvlc = "Vlci Hory",
    kmal = "Malesov",      ksed = "Sedlcko",      kopa = "Opatovicko",
    kcer = "Certovka",     ksus = "Sukov",        kzik = "Sigismund's camp",
    -- Trosky
    ttkc = "Troskovice",   tvez = "Vezicko",      tzel = "Zelejov",
    tpod = "Podseminsko",  ttac = "Tachov",       tzda = "Zdar",
    tsem = "Semin",        tvid = "Vidlak",       tneb = "Nebakov",
    tbuk = "Bukovina",     tsla = "Slatejov",     tkop = "Kopanina",
    tkrc = "Krcak",        ttro = "Trosky",       tapo = "Apolena",
}

function mercenaries:CrimePlaceOf(name)
    if not name or name == '' then return nil end
    local p = string.match(name, "^([a-z][a-z][a-z][a-z])_")
    if not p then return nil end
    return self.CrimePlaces[p], p
end

-- ==== the faction path ====
-- soul:GetFactionID() answers with the faction's NAME, not an integer - measured live:
-- "kutnohorsko_settlements_kutnaHora_commonFolk_peasants_additiveNPCs". That path is a
-- taxonomy, and it is better evidence than anything in the entity name:
--
--   <region>_settlements_<place>_<estate>_...   a townsman or a town guard
--   <region>_outskirts_... | _enemies_... | _allies_...
--   estate = commonFolk (peasants, tradersAndCraftmans, tavern, millers) | nobility | soldiers
--
-- So "is he a guard", "is he a townsman" and "am I in a village" all fall out of one call.

-- Every <region>_settlements_<place> root in the vanilla faction tree. This is the GAME's
-- own definition of a village or town, which is what a defence force has to be gated on -
-- counting heads in a crowd calls a battlefield a village.
mercenaries.CrimeSettlements = {
    -- Kuttenberg
    kutnaHora = "Kutna Hora", staraKutna = "Stara Kutna", suchdol = "Suchdol",
    pritoky = "Pritoky",      grunta = "Grunta",          miskovice = "Miskovice",
    bylany = "Bylany",        bylanya = "Bylany",         horany = "Horany",
    lorec = "Lorec",          ratbor = "Ratbor",          ratboricko = "Ratboricko",
    vysoka = "Vysoka",        mezholezy = "Mezholezy",    sedlec = "Sedlec",
    malesov = "Malesov",      certovka = "Certovka",      bohounovice = "Bohounovice",
    dolany = "Dolany",        pecky = "Pecky",            sukov = "Sukov",
    vrchlicko = "Vrchlicko",  opatovicko = "Opatovicko",
    -- Trosky
    semin = "Semin",          slatejov = "Slatejov",      tachov = "Tachov",
    troskovice = "Troskovice", trosky = "Trosky",         tvrzNebakov = "Tvrz Nebakov",
    zelejov = "Zelejov",
}

-- Kutna Hora is the only faction in the tree carrying Labels="city"; the rest are
-- Labels="settlement".
mercenaries.CrimeCities = { kutnaHora = true }

-- Labelled a settlement in the faction tree, but it is Sigismund's army camp. A siege
-- camp has no town watch to turn out, so it is deliberately not a settlement here.
mercenaries.CrimeNotSettlement = { zikmundovo = true }

-- Which village or town does this faction belong to? nil for open country.
-- `_enemies_` anywhere disqualifies: one bandit faction (kutnohorsko_enemies_bandits_
-- opatoviceEndgame) carries Labels="settlement" in the vanilla tree.
function mercenaries:CrimeSettlementOf(faction)
    if not faction then return nil end
    if string.find(faction, "_enemies_", 1, true) then return nil end
    local place = string.match(faction, "_settlements_([A-Za-z0-9]+)")
    if not place or self.CrimeNotSettlement[place] then return nil end
    local disp = self.CrimeSettlements[place]
    if not disp then return nil end
    return place, disp, self.CrimeCities[place] == true
end

-- The mod's own factions. Aleksej is named AleksejLodging_25222, which matches none of
-- the spawn-name prefixes, so he walked into the census as a townsman until this went in.
mercenaries.CrimeOwnFactions = {
    mercenariesFaction = true, enemiesFaction = true, foeFaction = true,
    patrolFaction = true, testFaction = true,
}

function mercenaries:CrimeFactionOf(ent)
    if not (ent and ent.soul) then return nil end
    local raw
    local ok = pcall(function() raw = ent.soul:GetFactionID() end)
    if not ok or raw == nil then return nil end
    local s = tostring(raw)
    -- It answers with the name on this build. Anything that stringifies to a handle
    -- instead is no use here, and the context/name paths still cover the NPC.
    if s == '' or s == 'nil' or string.find(s, 'userdata', 1, true)
       or string.find(s, 'table:', 1, true) then return nil end
    return s
end

-- Name fallbacks, matched in this order. Hostiles go first because "cuman" contains
-- "man" and "bandit" reads as nobody's civilian.
mercenaries.CrimeHostileWords = {
    "bandit", "cuman", "lapka", "poacher", "deserter", "smuggler", "raider",
    "enemy", "attacker", "neprat", "vagabond",
}
mercenaries.CrimeGuardWords = {
    "guard", "soldier", "strazn", "bailiff", "watchman", "shooter", "halberd",
    "retinue", "executioner",
}
mercenaries.CrimeCivilianWords = {
    "townsman", "villager", "artisan", "citizen", "civilian", "peasant", "burgher",
    "miller", "coalman", "innkeeper", "priest", "monk", "beggar", "merchant",
    "trader", "smith", "baker", "woodcutter", "spectator", "man", "woman", "girl",
    "boy", "child",
}

local function matchesAny(lower, words)
    for _, w in ipairs(words) do
        if string.find(lower, w, 1, true) then return true end
    end
    return false
end

-- Faction path segments, matched against the lowercased faction name. Guard is tested
-- before civilian because a merchant's bodyguard sits under ..._commonFolk_..._bodyguards
-- and is a guard, not a shopper.
mercenaries.CrimeFactionHostileWords = {
    "_enemies_", "bandit", "lapka", "cuman", "raider", "poacher",
}
mercenaries.CrimeFactionGuardWords = {
    "soldier", "guard", "militia", "security", "watchman", "executioner",
}
mercenaries.CrimeFactionCivilianWords = {
    "commonfolk", "peasant", "trader", "craftman", "craftmen", "tavern", "miller",
    "nobility", "civilian", "clergy", "priest", "staff", "guest", "vineyard",
}

-- What is he, and how did we decide? Returns kind ("guard"/"civilian"/"hostile"/
-- "unknown") and the evidence, so a wrong call in the log can be traced to its source.
--
-- Order is by measured reliability, not by neatness. crime_isAuthority DOES fire on a
-- real town guard (kkut_man_302 was caught by it); crime_isCivilian fires on almost
-- nobody, so the faction path carries the civilian side. A live census of a Kutna Hora
-- tavern left 5 of 9 NPCs "unknown" on names alone and none on faction.
function mercenaries:CrimeClassify(ent, name, faction)
    local soul = ent and ent.soul
    if soul then
        local ctx = nil
        pcall(function()
            if soul:HasScriptContext("crime_isAuthority")
            or soul:HasScriptContext("crime_isAuthorityOnDuty")
            or soul:HasScriptContext("crime_isAuthorityOnStationaryDuty")
            or soul:HasScriptContext("crime_isSecurity") then
                ctx = "guard"
            elseif soul:HasScriptContext("crime_isCivilian") then
                ctx = "civilian"
            end
        end)
        if ctx then return ctx, "ctx" end
    end

    local fac = string.lower(faction or '')
    if fac ~= '' then
        if matchesAny(fac, self.CrimeFactionHostileWords)  then return "hostile",  "faction" end
        if matchesAny(fac, self.CrimeFactionGuardWords)    then return "guard",    "faction" end
        if matchesAny(fac, self.CrimeFactionCivilianWords) then return "civilian", "faction" end
    end

    local lower = string.lower(name or '')
    if lower ~= '' then
        if matchesAny(lower, self.CrimeHostileWords)  then return "hostile",  "name" end
        if matchesAny(lower, self.CrimeGuardWords)    then return "guard",    "name" end
        if matchesAny(lower, self.CrimeCivilianWords) then return "civilian", "name" end
    end

    -- Under a settlement faction with no estate we recognise: still a townsman.
    if fac ~= '' and self:CrimeSettlementOf(faction) then return "civilian", "settlement" end
    return "unknown", "none"
end

-- Anything the mod put in the world is not a townsman and never counts as a crime. The
-- faction test is the backstop the names miss: Aleksej is AleksejLodging_25222 and
-- matches no spawn prefix, so he was being censused as a local until this went in.
function mercenaries:CrimeIsVanillaNpc(ent, name, faction)
    if not name or name == '' then return false end
    if faction and self.CrimeOwnFactions[faction] then return false end
    if self:IsModEnemyName(name) then return false end
    if self:IsHeroName(name) then return false end
    if self:IsOwnSide(ent) then return false end
    if string.find(name, "SpawnedPatrol", 1, true) then return false end
    if string.find(name, "SpawnedFoe_", 1, true) then return false end
    if string.find(name, "Mercenary", 1, true) then return false end
    return true
end

-- Contexts that mean this man knows something is happening. IsInCombatDanger and
-- weapon-drawn alone were WRONG and measured so: a massacre in a Kutna Hora street logged
-- four civilian kills at 1.3-1.5m from an armed player and marked every one STEALTH.
-- Townsfolk carry no weapons and do not "fight" - they run. Fleeing is exactly the
-- awareness the test was looking for.
mercenaries.CrimeAwareContexts = {
    "crime_interruptAttack", "crime_interruptFlee", "crime_indifferentFlee",
    "combat_flee", "combat_surrender",
}

-- Does he know a fight is on? Sampled every pass while he lives and latched, so that at
-- the moment of death we can say whether he ever saw it coming.
function mercenaries:CrimeIsAware(ent)
    if not ent or not ent.soul then return false end
    local hot = false
    pcall(function() hot = ent.soul:IsInCombatDanger() or false end)
    if hot then return true end
    pcall(function() hot = ent.human and ent.human:IsWeaponDrawn() or false end)
    if hot then return true end
    for _, ctx in ipairs(self.CrimeAwareContexts) do
        local has = false
        pcall(function() has = ent.soul:HasScriptContext(ctx) or false end)
        if has then return true end
    end
    return false
end

-- Is the company fighting, right now? Nobody dies unaware in the middle of one, which is
-- the second half of the stealth test - the census only samples once a second, and a
-- civilian cut down inside a single tick would otherwise be scored as an assassination.
--
-- Four sources, because no single one covers the case where WE are the aggressors: the
-- BT-confirmed attacker register only fills when something locks on to US, and an unarmed
-- townsman never does. A merc holding a combat target is the reading that actually fires
-- in a massacre.
function mercenaries:CrimeFightOn()
    local hot = false
    pcall(function() hot = player.soul and player.soul:IsInCombatDanger() or false end)
    if hot then return true, "player in danger" end

    pcall(function()
        hot = player.soul and player.soul:HasScriptContext("crime_interruptAttack") or false
    end)
    if hot then return true, "player mid-attack" end

    for _, targetWuidStr in pairs(self.MercTargetOf or {}) do
        if targetWuidStr then return true, "a merc is engaged" end
    end

    for w in pairs(self.AttackerSeen or {}) do
        if self:IsRecentAttacker(w) then return true, "somebody is fighting us" end
    end
    return false, nil
end

-- ==== attribution ====

-- Was this death ours, and whose? Ordered by strength of evidence, because none of the
-- engine's kill callbacks reach a mod: SoulDeathTrigger does not fire for anyone we did
-- not spawn, so a body is all we ever get and proximity is all we can prove.
function mercenaries:CrimeAttribute(pos, wuidStr)
    local out = { by = "unattributed", who = nil, dist = nil, evidence = "none" }
    if not pos then return out end

    -- Strongest: a merc was holding him as its combat target within living memory.
    local claimAt = self.CWClaim[wuidStr]
    if claimAt and (nowT() - claimAt) <= self.CrimeClaimMemory then
        out.by, out.evidence = "merc", "claim"
    end

    -- Or the behaviour tree confirmed he was swinging at us.
    if out.by == "unattributed" and self.IsRecentAttacker and self:IsRecentAttacker(wuidStr) then
        out.by, out.evidence = "fight", "attacker"
    end

    -- Who of ours is nearest the body, and is anyone near enough at all.
    local bestD, bestWho, bestIsPlayer = nil, nil, false
    local pp
    pcall(function() pp = player and player:GetWorldPos() end)
    local d = dist(pp, pos)
    if d then bestD, bestWho, bestIsPlayer = d, "player", true end

    for _, ent in pairs(self.ActiveMercs or {}) do
        if ent and self:IsAliveAndWell(ent, true) then
            local q
            pcall(function() q = ent:GetWorldPos() end)
            local dm = dist(q, pos)
            if dm and (not bestD or dm < bestD) then
                bestD, bestIsPlayer = dm, false
                pcall(function() bestWho = ent:GetName() end)
            end
        end
    end

    out.dist, out.who = bestD, bestWho

    -- Nobody of ours standing over him: a claim or a confirmed fight from a moment ago
    -- still counts (he may have broken off and died out of the ring), a bare proximity
    -- guess does not.
    if not bestD or bestD > self.CrimeAttribRange then return out end

    if out.by == "unattributed" then
        local armed = false
        pcall(function() armed = player.human and player.human:IsWeaponDrawn() or false end)
        if bestIsPlayer and armed then
            out.by, out.evidence = "player", "armed+near"
        elseif bestIsPlayer then
            out.by, out.evidence = "near", "player near"
        else
            out.by, out.evidence = "merc", "merc near"
        end
    end
    return out
end

-- ==== the kill pass ====

function mercenaries:CrimeNoteClaims()
    local t = nowT()
    for _, targetWuidStr in pairs(self.MercTargetOf or {}) do
        if targetWuidStr then self.CWClaim[tostring(targetWuidStr)] = t end
    end
end

function mercenaries:CrimeRecordKill(ent, name, wuidStr, pos, faction, stealth)
    local kind, how = self:CrimeClassify(ent, name, faction)
    local att = self:CrimeAttribute(pos, wuidStr)
    -- The faction knows the settlement exactly; the name prefix is the fallback for the
    -- quest NPCs that carry no place prefix at all (rvacka_firstCzech_3).
    local placeKey, place = self:CrimeSettlementOf(faction)
    if not place then place = self:CrimePlaceOf(name) end

    if att.by == "unattributed" and not self.CrimeLogUnattributed then
        self.CWTally.unattributed = self.CWTally.unattributed + 1
        return
    end

    local bucket = (kind == "guard" and "guard") or (kind == "civilian" and "civilian") or "other"
    self.CWTally[bucket] = (self.CWTally[bucket] or 0) + 1

    -- Hand it to the town watch BEFORE the log line, so the line can report whether it
    -- went on the village's account or was written off as a quiet one.
    if self.TownWatchNoteKill then
        pcall(function() self:TownWatchNoteKill(kind, placeKey, stealth) end)
    end

    local line = string.format(
        "%s %-8s %-34s by=%s(%s) d=%s %s[%s]%s",
        (kind == "guard" or kind == "civilian") and "KILL" or "kill",
        kind, name,
        att.by, att.evidence,
        att.dist and string.format("%.1fm", att.dist) or "?",
        place and ("in " .. place .. " ") or "",
        how,
        stealth and " STEALTH" or "")

    cwLog(line)
    table.insert(self.CWEvents, string.format("[%.0f] %s", nowT(), line))
    while #self.CWEvents > self.CrimeEventLogMax do table.remove(self.CWEvents, 1) end

    -- The headline the whole watchdog exists for.
    if kind == "guard" or kind == "civilian" then
        cwLog(string.format("  running total: %d guard(s), %d civilian(s), %d other",
                            self.CWTally.guard, self.CWTally.civilian, self.CWTally.other))
    end
end

function mercenaries:CrimeKillPass()
    local pp
    pcall(function() pp = player and player:GetWorldPos() end)
    if not pp then return end

    self:CrimeNoteClaims()

    local ents
    pcall(function()
        ents = System.GetEntitiesInSphereByClass(pp, self.CrimeScanRadius, 'NPC')
    end)
    if not ents then return end

    local t = nowT()
    for _, ent in pairs(ents) do
        local name
        pcall(function() name = ent.GetName and ent:GetName() end)
        local faction = self:CrimeFactionOf(ent)
        if name and self:CrimeIsVanillaNpc(ent, name, faction) then
            local w = ent.this and ent.this.id or ent.id
            local wuidStr = w and tostring(w) or nil
            if wuidStr and not self.CWDead[wuidStr] then
                if self:IsCorpse(ent) then
                    -- A body we never saw standing is somebody else's business - it was
                    -- lying there before we walked up.
                    local prev = self.CWSeen[wuidStr]
                    if prev then
                        local pos
                        pcall(function() pos = ent:GetWorldPos() end)
                        -- Stealth needs BOTH: he never saw it coming, AND no fight was
                        -- on to see. Either alone is wrong - see CrimeFightOn.
                        local quiet = (not prev.aware) and not self:CrimeFightOn()
                        self:CrimeRecordKill(ent, name, wuidStr, pos or pp, faction, quiet)
                    end
                    self.CWDead[wuidStr] = t
                    self.CWSeen[wuidStr] = nil
                else
                    -- `aware` is what separates a murder from an assassination, and it
                    -- latches: a man who ever knew a fight was on did not die unaware,
                    -- however quiet the moment of the blow was.
                    local rec = self.CWSeen[wuidStr] or { name = name, aware = false }
                    rec.name, rec.at = name, t
                    if not rec.aware then rec.aware = self:CrimeIsAware(ent) end
                    self.CWSeen[wuidStr] = rec
                end
            end
        end
    end

    -- Expiry. Without it both tables grow for the length of the session, and CWDead is
    -- the one that must not: a body whose entry has been dropped and which is then seen
    -- alive again (a streamed-out NPC reusing a wuid) would be counted a second time.
    for k, v in pairs(self.CWSeen) do
        if (t - (v.at or 0)) > self.CrimeSeenExpiry then self.CWSeen[k] = nil end
    end
    for k, at in pairs(self.CWDead) do
        if (t - at) > self.CrimeDeadExpiry then self.CWDead[k] = nil end
    end
    for k, at in pairs(self.CWClaim) do
        if (t - at) > self.CrimeClaimMemory then self.CWClaim[k] = nil end
    end
end

-- ==== the standing pass ====

-- How the crowd around the player feels about him. This is the closest thing to a crime
-- rating a mod can read: relationship is a scriptbind, angriness is not.
function mercenaries:CrimeHeatPass()
    local pp
    pcall(function() pp = player and player:GetWorldPos() end)
    if not pp then return end

    local playerWuid = player.this and player.this.id or player.id

    local ents
    pcall(function()
        ents = System.GetEntitiesInSphereByClass(pp, self.CrimeScanRadius, 'NPC')
    end)

    local crowd, hostiles, guards = 0, 0, 0
    local places = {}          -- [placeKey] = how many of the crowd belong to it
    for _, ent in pairs(ents or {}) do
        local name
        pcall(function() name = ent.GetName and ent:GetName() end)
        local faction = self:CrimeFactionOf(ent)
        if name and self:CrimeIsVanillaNpc(ent, name, faction) and self:IsAliveAndWell(ent, true) then
            crowd = crowd + 1
            local key = self:CrimeSettlementOf(faction)
            if key then places[key] = (places[key] or 0) + 1 end

            local rel
            pcall(function() rel = ent.soul:GetRelationship(playerWuid, "Current") end)
            if rel and rel <= self.CrimeHostileFloor then hostiles = hostiles + 1 end

            local kind = self:CrimeClassify(ent, name, faction)
            if kind == "guard" then guards = guards + 1 end
        end
    end

    -- WHERE WE ARE, and the gate a defence force must hang off. The settlement is the one
    -- most of the locals belong to - a majority, not a single stray, so a lone Kutna Hora
    -- carter met on a forest road does not make the forest a town. Note this is the
    -- FACTION's answer, not a headcount: a battle in open country is a big crowd and no
    -- settlement, and an empty hamlet at night is a small crowd that is still a village.
    local topPlace, topN = nil, 0
    for p, n in pairs(places) do
        if n > topN then topPlace, topN = p, n end
    end
    local inTown = topPlace ~= nil and topN >= self.CrimeSettlementQuorum

    local publicEnemy, underArrest = false, false
    pcall(function() publicEnemy = RPG.IsPublicEnemy(playerWuid) and true or false end)
    if not publicEnemy then
        pcall(function() publicEnemy = player.soul:IsPublicEnemy() and true or false end)
    end
    pcall(function()
        underArrest = player.soul:HasScriptContext("crime_playerUnderArrestByAuthority") and true or false
    end)

    local h = self.CWHeat
    h.placeKey    = topPlace
    h.place       = topPlace and self.CrimeSettlements[topPlace] or nil
    h.isCity      = topPlace ~= nil and self.CrimeCities[topPlace] == true
    h.locals      = topN
    h.crowd       = crowd
    h.guards      = guards
    h.hostiles    = hostiles
    h.publicEnemy = publicEnemy
    h.underArrest = underArrest
    h.inTown      = inTown
    h.at          = nowT()

    -- Edge-triggered: a settlement tick every five seconds for the whole of a market
    -- visit is noise, and the only interesting moments are the changes.
    local sig = string.format("%s|%s|%d|%s|%s",
                              tostring(h.place), tostring(h.inTown),
                              hostiles, tostring(publicEnemy), tostring(underArrest))
    if sig ~= self._cwHeatSig then
        self._cwHeatSig = sig
        cwLog(string.format("heat: %s crowd=%d locals=%d guards=%d hostile-to-player=%d%s%s",
              inTown and ((h.isCity and "in the city of " or "in ") .. tostring(h.place)) or "open country",
              crowd, topN, guards, hostiles,
              publicEnemy and " PUBLIC ENEMY" or "",
              underArrest and " UNDER ARREST" or ""))
    end
end

-- Is the player standing in a village or town, and which one? THE gate for anything that
-- turns out a town watch - a defence force must never form up in open country. Answers
-- from the last heat pass, so it is free to call.
--
--   local inTown, place, isCity = mercenaries:CrimeInSettlement()
--
function mercenaries:CrimeInSettlement()
    local h = self.CWHeat or {}
    if not h.inTown then return false, nil, false end
    return true, h.place, h.isCity == true
end

-- ==== tick ====

function mercenaries:CrimeWatchTick()
    if not self.CrimeWatchEnabled then return end
    self:CrimeKillPass()

    local t = nowT()
    if (t - (self._cwHeatAt or 0)) >= self.CrimeHeatSecs then
        self._cwHeatAt = t
        self:CrimeHeatPass()
    end
end

-- Timers and behaviour trees die with the level; the plain Lua tables above do not, and a
-- census carried across a level change would attribute a body in Kuttenberg to a merc
-- standing in Trosky. Cleared the same way every other module clears its cache.
function mercenaries:CrimeWatchOnLoad()
    self.CWSeen, self.CWDead, self.CWClaim = {}, {}, {}
    self._cwHeatAt, self._cwHeatSig = 0, nil
end

-- ==== commands ====

function mercenaries:CrimeWatchStatus()
    if not self.CrimeWatchEnabled then
        cwLog("the crime watchdog is OFF - merc_townwatch_enable turns the feature on")
    end
    local h = self.CWHeat or {}
    cwLog(string.format("enabled=%s  tracking %d living / %d bodies",
          tostring(self.CrimeWatchEnabled),
          self:_TableCount(self.CWSeen), self:_TableCount(self.CWDead)))
    cwLog(string.format("killed by the company: %d guard(s), %d civilian(s), %d other, %d unattributed",
          self.CWTally.guard, self.CWTally.civilian, self.CWTally.other, self.CWTally.unattributed))
    cwLog(string.format("standing: %s crowd=%d locals=%d guards=%d hostile-to-player=%d publicEnemy=%s underArrest=%s",
          h.inTown and ((h.isCity and "in the city of " or "in ") .. tostring(h.place)) or "open country",
          h.crowd or 0, h.locals or 0, h.guards or 0, h.hostiles or 0,
          tostring(h.publicEnemy), tostring(h.underArrest)))
    if #self.CWEvents > 0 then
        cwLog("recent:")
        for _, l in ipairs(self.CWEvents) do cwLog("  " .. l) end
    end
end

-- Every vanilla NPC around the player with everything we can read off him. This is the
-- command that settles what the names and factions actually look like in a live game.
function mercenaries:CrimeWatchDump()
    local pp
    pcall(function() pp = player and player:GetWorldPos() end)
    if not pp then cwLog("no player") return end
    local playerWuid = player.this and player.this.id or player.id

    local ents
    pcall(function()
        ents = System.GetEntitiesInSphereByClass(pp, self.CrimeScanRadius, 'NPC')
    end)
    cwLog(string.format("census within %.0fm:", self.CrimeScanRadius))

    local n = 0
    for _, ent in pairs(ents or {}) do
        local name
        pcall(function() name = ent.GetName and ent:GetName() end)
        local faction = self:CrimeFactionOf(ent)
        if name and self:CrimeIsVanillaNpc(ent, name, faction) then
            n = n + 1
            local kind, how = self:CrimeClassify(ent, name, faction)
            local rel, roles
            pcall(function() rel = ent.soul:GetRelationship(playerWuid, "Current") end)
            pcall(function()
                local m = ent.soul:GetMetaRoles()
                if type(m) == "table" then roles = table.concat(m, ",") end
            end)
            local _, place = self:CrimeSettlementOf(faction)
            cwLog(string.format("  %-34s %-8s [%s] rel=%s faction=%s place=%s%s%s",
                  name, kind, how,
                  rel and string.format("%.2f", rel) or "?",
                  tostring(faction), tostring(place),
                  self:IsCorpse(ent) and " DEAD" or "",
                  roles and (" roles=" .. roles) or ""))
        end
    end
    cwLog(string.format("  %d vanilla NPC(s)", n))
end

function mercenaries:CrimeWatchReset()
    self.CWTally = { guard = 0, civilian = 0, other = 0, unattributed = 0 }
    self.CWEvents = {}
    cwLog("tallies cleared")
end

function mercenaries:CrimeWatchToggle(on)
    self.CrimeWatchEnabled = on and true or false
    cwLog("watchdog " .. (self.CrimeWatchEnabled and "on" or "off"))
end

mercenaries:DevCommand("merc_crime_status", "mercenaries:CrimeWatchStatus()",
                       "Who the company has killed in a settlement, and the town's standing")
mercenaries:DevCommand("merc_crime_dump",   "mercenaries:CrimeWatchDump()",
                       "Every vanilla NPC around you: name, guard/civilian, relationship, faction, metaroles")
mercenaries:DevCommand("merc_crime_reset",  "mercenaries:CrimeWatchReset()",
                       "Zero the crime tallies")
mercenaries:DevCommand("merc_crime_on",     "mercenaries:CrimeWatchToggle(true)",  "Start the crime watchdog")
mercenaries:DevCommand("merc_crime_off",    "mercenaries:CrimeWatchToggle(false)", "Stop the crime watchdog")
