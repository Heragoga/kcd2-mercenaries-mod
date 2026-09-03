-- THE COMPANY AS DATA.
--
-- A hired merc is an NPC entity, and the engine writes every NPC into the save. Fifty of
-- them is fifty NPCs, their souls, their inventories and their AI state in every save the
-- player makes - which is the save footprint, and why a save made with the mod loads slowly
-- once the mod is gone (docs/save-footprint.md): the entities are still in it with nothing
-- left to explain them, which is what "white pyramids and generic townsmen" was.
--
-- The roster is the answer. The company is a LIST - tier and health per man - and the men
-- are put back into the world from it. Where the list lives (a saver string) the engine
-- writes a few hundred bytes instead of fifty NPCs.
--
-- Two callers today:
--
--   TRAVEL   fast travel and sleep. The men are taken out of the world for the crossing and
--            put back when it ends - which is what the mod did in its early versions and
--            what stopped: 2026-09-03 a fast travel arrived with one of five men left, and
--            he had stopped following. A man who is not in the world cannot be lost by one.
--
--   LOAD     whatever the engine did or did not restore, the roster is the truth: the men
--            standing are counted and only the shortfall is spawned. That makes this safe
--            whether or not the spawn flags below keep mercs out of the save at all - if
--            they are still in it, nothing is spawned twice.
--
-- Not wired to saving itself. There is no Lua hook the engine calls before it writes a
-- save, so "despawn on save" cannot be done by watching for one; it is done by keeping the
-- men out of the save in the first place (bSaved_by_game = false where they are spawned)
-- and rebuilding them here on load. See docs/save-footprint.md.

mercenaries.RosterTag     = "MercRoster"
mercenaries.RosterEnabled = true     -- merc_roster 0|1 (saved): the load-time rebuild
mercenaries.TravelStow    = true     -- merc_travel_stow 0|1 (saved): the travel stow

-- THE SAVE-FOOTPRINT SWITCH, and the whole point of the roster - but OFF until the rebuild
-- above has been watched working, because it is the half that cannot be undone by a reload.
--
-- On, mercs are spawned with bSaved_by_game = false and the engine never writes one into a
-- save: the footprint drops from fifty NPCs to one string, and a save made with the mod
-- loads clean once the mod is gone. The cost is that EVERY load then depends on
-- RosterOnLoad putting the company back, and the men come back around the player rather
-- than where they stood - a camp full of men would re-form on the player and have to walk
-- home. Prove the rebuild first (merc_stow / merc_unstow, and a fast travel), then flip it.
mercenaries.RosterNoSave  = false    -- merc_roster_nosave 0|1 (saved)

-- Spawn properties for a merc NPC, so the two spawn paths cannot drift apart.
function mercenaries:RosterSpawnProps(soulGuid)
    return self:NoSaveProps({ guidSharedSoulId = soulGuid })
end

-- ...and the same stamp for everything else the mod puts in the world that it can rebuild
-- for itself. This is the general form, and it is what the switch is actually FOR.
--
-- merc_roster_nosave covered the mercs alone and so appeared to do nothing (2026-09-03):
-- 43 of the mod's 77 SpawnEntity sites never set the flag at all, and the ones a player
-- sees in an uninstalled save are not the mercs. "White pyramids where the camp was" is
-- `mercenaries_Prop` - an entity class that only exists inside this mod, so without it the
-- engine has nothing to build - plus the camp's own BasicEntity props and Lights. "Generic
-- townsmen" is every NPC whose soul came from soul__mercenaries: the quartermaster, camp
-- staff, patrol gangs.
--
-- Only things the mod REBUILDS on its own are stamped. Deliberately NOT stamped:
--   * the saver entities (mercenaries_saving.lua) - they ARE the persistence;
--   * enemies and quest NPCs whose being dead is quest state a reload must not undo.
-- Returns a COPY: some callers hand in a shared table (CampNightLightProps), and stamping
-- that in place would flip the flag for every later spawn even after the switch is off.
function mercenaries:NoSaveProps(p)
    if not self.RosterNoSave then return p or {} end
    local out = {}
    for k, v in pairs(p or {}) do out[k] = v end
    out.bSaved_by_game = false
    out.bSerialize     = false
    return out
end

local function rLog(s) System.LogAlways("[Roster] " .. tostring(s)) end

-- ---------------------------------------------------------------------------
-- The list
-- ---------------------------------------------------------------------------

-- The entity name carries everything needed to build the man again:
-- SpawnedFriend_<tier>_<rand>_<soulGuid>, or SpawnedFriend_archer_medium_<rand>_<guid>.
function mercenaries:RosterTierOf(name)
    name = tostring(name or "")
    if self.IsArcherName and self:IsArcherName(name) then return "archer" end
    local tier = string.match(name, "^SpawnedFriend_([a-z]+)_")
    if tier == "archer" then return "archer" end
    return tier or "medium"
end

function mercenaries:RosterCapture()
    local out = {}
    for name, ent in pairs(self.ActiveMercs or {}) do
        local hp = 0
        pcall(function() hp = math.floor(ent.actor:GetHealth() or 0) end)
        out[#out + 1] = self:RosterTierOf(name) .. "," .. tostring(hp)
    end
    local blob = (#out > 0) and table.concat(out, ";") or "none"
    pcall(function() self:SaveString(self.RosterTag, blob) end)
    return #out, blob
end

function mercenaries:RosterRead()
    local blob
    pcall(function() blob = self:LoadString(self.RosterTag) end)
    local list = {}
    if not blob or blob == "" or blob == "none" then return list end
    for entry in string.gmatch(blob, "[^;]+") do
        local tier, hp = string.match(entry, "^([a-z_]+),(%-?%d+)$")
        if tier then list[#list + 1] = { tier = tier, hp = tonumber(hp) or 0 } end
    end
    return list
end

-- Put `n` men of a tier into the world around the player. Returns how many stood up.
function mercenaries:RosterSpawn(list)
    local pp
    pcall(function() pp = player:GetWorldPos() end)
    if not pp then return 0 end
    local yaw = 0
    pcall(function() local a = player:GetWorldAngles(); yaw = a and a.z or 0 end)
    local outfit = _G.MercCurrentOutfit or 1
    local weapon = _G.MercCurrentWeapon or 1
    local made = 0
    for _, m in ipairs(list) do
        -- Spread them behind the player rather than on him: fifty men on one point is a
        -- physics pile, and the formation puts them in order within a tick anyway.
        local ang  = math.random() * math.pi * 2
        local rad  = 3.0 + math.random() * 7.0
        local spot = { x = pp.x + math.cos(ang) * rad, y = pp.y + math.sin(ang) * rad, z = pp.z }
        pcall(function()
            local gz = System.GetTerrainElevation(spot.x, spot.y)
            if gz and math.abs(gz - pp.z) < 8.0 then spot.z = gz end
        end)
        local ent
        if m.tier == "archer" then
            pcall(function() ent = self:SpawnArcherAt(spot, yaw, outfit) end)
        else
            pcall(function() ent = self:SpawnMercAt(m.tier, spot, yaw, outfit, weapon) end)
        end
        if ent then
            made = made + 1
            if m.hp and m.hp > 0 then pcall(function() ent.actor:SetHealth(m.hp) end) end
        end
    end
    return made
end

-- Keep the list current. Without this the roster only ever held what the last STOW put
-- there, so the load-time rebuild had nothing to read during ordinary play and the
-- save-footprint switch would have restored a stale company or none at all. On the 5s
-- low-priority tick, and it writes only when the count has actually changed - a saver
-- write spawns and drops an entity, which is not something to do every five seconds for
-- no reason.
function mercenaries:RosterKeepTick()
    if not self.RosterEnabled or self.RosterStowed then return end
    local n = 0
    for _ in pairs(self.ActiveMercs or {}) do n = n + 1 end
    if n == (self._rosterLastN or -1) then return end
    self._rosterLastN = n
    self:RosterCapture()
end

-- ---------------------------------------------------------------------------
-- Stow and unstow
-- ---------------------------------------------------------------------------

function mercenaries:MercStow(why)
    if self.RosterStowed then return 0 end
    local n = self:RosterCapture()
    if n <= 0 then
        self.RosterStowed = true
        pcall(function() self:SaveString("MercRosterStowed", "1") end)
        return 0
    end
    local gone = 0
    for name, ent in pairs(self.ActiveMercs or {}) do
        pcall(function()
            if ent and ent.id then System.RemoveEntity(ent.id); gone = gone + 1 end
        end)
        self.ActiveMercs[name] = nil
    end
    self.ActiveMercs = {}
    -- Tell the logistics tick these men were TAKEN, not killed. Without this the live count
    -- drops by ten between two ticks and the death detector books ten casualties: measured
    -- 2026-09-03, "Morale 0 -> -50 (10 merc death(s))" the instant a crossing stowed the
    -- company. LogiRemoveOneMerc marks a desertion the same way.
    pcall(function()
        local L = self:LogiState()
        L.selfRemoved = (L.selfRemoved or 0) + gone
        L.lastAliveCount = 0
    end)
    pcall(function() self:Recount() end)
    self.RosterStowed = true
    pcall(function() self:SaveString("MercRosterStowed", "1") end)
    rLog(string.format("%d man/men stowed (%s) - the company is a list until it is put back", gone, tostring(why)))
    return gone
end

function mercenaries:MercUnstow(why)
    if not self.RosterStowed then return 0 end
    self.RosterStowed = false
    pcall(function() self:SaveString("MercRosterStowed", "0") end)
    local list = self:RosterRead()
    if #list == 0 then rLog("nothing on the roster to put back (" .. tostring(why) .. ")"); return 0 end
    local made = self:RosterSpawn(list)
    -- ...and the other side of the same coin: the count jumping back up must not be read as
    -- anything either. Re-baseline it to what is actually standing.
    pcall(function() self:LogiState().lastAliveCount = self:LogiAliveCount() end)
    rLog(string.format("%d of %d man/men put back (%s)", made, #list, tostring(why)))
    -- They arrive as a batch, which is exactly the burst the follow verify exists for.
    pcall(function() self:BeginFollowVerify("unstow") end)
    return made
end

-- ---------------------------------------------------------------------------
-- The load-time rebuild
-- ---------------------------------------------------------------------------
--
-- Called after RebuildMercCache, so ActiveMercs holds whatever the engine really restored.
-- Only the SHORTFALL is spawned, so this is correct whether the engine kept every merc,
-- some of them, or none.
function mercenaries:RosterOnLoad()
    if not self.RosterEnabled then return end
    if _G.MercenariesDismissed then return end
    local list = self:RosterRead()
    if #list == 0 then return end
    local live = 0
    for _ in pairs(self.ActiveMercs or {}) do live = live + 1 end
    -- Always said out loud, because this one line answers the question the whole
    -- save-footprint switch turns on: how many of the company did the ENGINE restore?
    -- With merc_roster_nosave working, that is 0 and the roster rebuilds all of them; if
    -- it reads the full count, the flag is not being honoured and nothing else matters.
    rLog(string.format("load: the engine restored %d merc(s); the roster says %d (no-save is %s)",
                       live, #list, tostring(self.RosterNoSave)))
    if live >= #list then
        if live > #list then
            rLog(string.format("%d men standing against a roster of %d - the roster is stale, rewriting it", live, #list))
            self:RosterCapture()
        end
        self.RosterStowed = false
        pcall(function() self:SaveString("MercRosterStowed", "0") end)
        return
    end
    -- Spawn only the men the world is missing, cheapest tiers last so a partial restore
    -- keeps the veterans.
    local want = {}
    for i = live + 1, #list do want[#want + 1] = list[i] end
    local made = self:RosterSpawn(want)
    self.RosterStowed = false
    pcall(function() self:SaveString("MercRosterStowed", "0") end)
    rLog(string.format("load: %d man/men were in the world, roster says %d - put %d back", live, #list, made))
    pcall(function() self:BeginFollowVerify("roster restore") end)
end

-- ---------------------------------------------------------------------------
-- Travel
-- ---------------------------------------------------------------------------
--
-- Fast travel in KCD2 is not a teleport: the player is walked along the road on the map
-- screen, which is why a per-tick position JUMP is never seen (the 2026-09-03 detector
-- looked for one and never fired once). What is unmistakable is the SPEED, and the world
-- clock running far above real time - the same proxy the spawn guard uses for sleeping.
--
function mercenaries:RosterOnGameplayLoad()
    self._travelPP, self._travelT = nil, nil
    self._travelSeen, self._travelQuiet = 0, 0
    local v
    pcall(function() v = self:LoadString("MercRosterStowed") end)
    self.RosterStowed = (v == "1")
    pcall(function()
        local s = self:LoadString("MercTravelStow"); if s == "0" then self.TravelStow = false end
    end)
    pcall(function()
        local s = self:LoadString("MercRosterOn"); if s == "0" then self.RosterEnabled = false end
    end)
    pcall(function()
        local s = self:LoadString("MercRosterNoSave"); if s then self.RosterNoSave = (s == "1") end
    end)
    if self.RosterStowed then
        rLog("loaded with the company stowed - it is put back on the first tick that is not a crossing")
    end
end

-- ---------------------------------------------------------------------------
-- Console
-- ---------------------------------------------------------------------------

function mercenaries:TravelStowSet(on)
    self.TravelStow = on and true or false
    pcall(function() self:SaveString("MercTravelStow", self.TravelStow and "1" or "0") end)
    rLog("travel stow " .. (self.TravelStow and "on - the company leaves the world while you cross" or "off"))
end

function mercenaries:RosterSet(on)
    self.RosterEnabled = on and true or false
    pcall(function() self:SaveString("MercRosterOn", self.RosterEnabled and "1" or "0") end)
    rLog("roster rebuild on load " .. (self.RosterEnabled and "on" or "off"))
end

function mercenaries:RosterNoSaveSet(on)
    local was = self.RosterNoSave
    self.RosterNoSave = on and true or false
    pcall(function() self:SaveString("MercRosterNoSave", self.RosterNoSave and "1" or "0") end)
    rLog("keeping the mod's own entities out of the save " .. (self.RosterNoSave and
         "ON - mercs, the quartermaster, camp props and lights, gate collars and patrol gangs are rebuilt rather than saved" or
         "off - everything is saved as before"))
    -- A spawn flag can only be set AT spawn, so the company standing right now was made
    -- under the old setting. That is the whole reason the switch looked like it did
    -- nothing (2026-09-03). Re-make them: stow captures the roster and removes them, and
    -- unstow spawns them again a tick later under the new flag.
    if self.RosterNoSave ~= (was and true or false) then
        local n = 0
        for _ in pairs(self.ActiveMercs or {}) do n = n + 1 end
        if n > 0 and not self.RosterStowed then
            rLog("re-spawning the " .. n .. " man/men already standing so the new setting applies to them too")
            pcall(function() self:MercStow("the no-save setting changed") end)
            pcall(function() self:MercUnstow("the no-save setting changed") end)
        end
        rLog("the camp, if one is up, keeps the props it already spawned - break and re-pitch it to re-make those")
    end
end

function mercenaries:RosterReport()
    local list = self:RosterRead()
    local live = 0
    for _ in pairs(self.ActiveMercs or {}) do live = live + 1 end
    local byTier = {}
    for _, m in ipairs(list) do byTier[m.tier] = (byTier[m.tier] or 0) + 1 end
    local parts = {}
    for t, n in pairs(byTier) do parts[#parts + 1] = t .. " x" .. n end
    rLog(string.format("roster %d (%s), standing %d, stowed=%s, travel stow=%s, load rebuild=%s",
        #list, (#parts > 0) and table.concat(parts, ", ") or "-", live,
        tostring(self.RosterStowed), tostring(self.TravelStow), tostring(self.RosterEnabled)))
end

mercenaries:DevCommand("merc_stow",   "mercenaries:MercStow('by hand')",   "Take the company out of the world, keeping the roster")
mercenaries:DevCommand("merc_unstow", "mercenaries:MercUnstow('by hand')", "Put a stowed company back")
mercenaries:DevCommand("merc_roster_report", "mercenaries:RosterReport()", "Roster count, who is standing, and the switches")
