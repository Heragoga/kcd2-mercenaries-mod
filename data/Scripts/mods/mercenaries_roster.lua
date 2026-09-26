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
-- merc_travel_stow 0|1 (saved). No longer a stow: the men who are WITH you are teleported
-- to you at the far end of a crossing (mercenaries_travelwatch.lua). Camp residents and men
-- holding ground are never moved.
mercenaries.TravelStow    = true

-- THE SAVE-FOOTPRINT SWITCH, and the whole point of the roster - but OFF until the rebuild
-- above has been watched working, because it is the half that cannot be undone by a reload.
--
-- On, mercs are spawned with bSaved_by_game = false and the engine never writes one into a
-- save: the footprint drops from fifty NPCs to one string, and a save made with the mod
-- loads clean once the mod is gone. The cost is that EVERY load then depends on
-- RosterOnLoad putting the company back, and the men come back around the player rather
-- than where they stood - a camp full of men would re-form on the player and have to walk
-- home. Prove the rebuild first (merc_stow / merc_unstow, and a fast travel), then flip it.
-- ON. It was switched off on 2026-09-19 along with a 118-site spawn conversion, on the
-- theory that the conversion had broken hiring, the load sequence and the formation. It
-- had not: the real cause was a UTF-8 BOM accidentally written onto mercenaries_camp.lua,
-- which stopped that whole file compiling (see tools/check_lua.py). The conversion stays
-- reverted - it was never needed - because NoSaveSweep flags entities by NAME, and that
-- works whether the mod spawned them this session or the engine restored them from a save.
-- This switch is what keeps the mod's things out of the save at all, so it is on.
mercenaries.RosterNoSave  = true     -- merc_roster_nosave 0|1 (saved)

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

-- The properties above only work if the entity's CLASS SCRIPT reads them - BasicEntity
-- and its derivatives do, NPC does not, which is why stamped mercs still turned up in
-- saves. This is the engine-level equivalent and needs no cooperation from the class:
-- ENTITY_FLAG_NO_SAVE (0x8000) is registered as a Lua global by CScriptBind_Entity
-- (WHGame.dll release_1_5, sub_144DCB4 @ 0x1451ACE) and the entity system skips a flagged
-- entity when it writes the save.
--
-- SetFlags' modes are NOT the CryEngine documentation's order - read off sub_70FC3C:
--   mode 0 (or any other value) -> or  edx, ebx   ADD
--   mode 1                      -> and edx, ebx   AND-mask, i.e. keep only these
--   mode 2                      -> not/and        CLEAR
-- Passing 1 to "add" a flag would wipe every other flag the entity has.
mercenaries.EntityFlagNoSave = ENTITY_FLAG_NO_SAVE or 0x8000

-- Sets the flag AND checks it stuck. Entity.HasFlags is bound next to SetFlags, so there
-- is no excuse for assuming: the whole "the mod leaves nothing in a save" claim rests on
-- this one call, and a pcall around it would hide a total failure as a silent success.
-- `always` is for the entities whose CLASS this mod defines. Those are not an
-- optimisation: an entity of a missing class aborts the whole LoadGame (see
-- NoSaveSweepFatal), so they are kept out of saves whatever merc_roster_nosave says.
function mercenaries:NoSaveEntity(ent, always)
    if not ent then return ent end
    if not (always or self.RosterNoSave) then return ent end
    local stuck = false
    pcall(function()
        ent:SetFlags(self.EntityFlagNoSave, 0)
        stuck = (ent:HasFlags(self.EntityFlagNoSave) and true) or false
    end)
    if stuck then
        self.NoSaveFlagOk = (self.NoSaveFlagOk or 0) + 1
    else
        self.NoSaveFlagFail = (self.NoSaveFlagFail or 0) + 1
        if not self._noSaveWarned then
            self._noSaveWarned = true
            System.LogAlways("[Roster] ENTITY_FLAG_NO_SAVE did NOT stick on " ..
                tostring((ent.GetName and ent:GetName()) or "?") ..
                " - the mod's things will keep being written into saves. merc_save_footprint lists them.")
        end
    end
    return ent
end

-- What would this save actually carry? Walks the same classification and reports, per
-- class, how many of the mod's entities are flagged out and how many are not. This is
-- the in-game version of decoding the .whs afterwards.
function mercenaries:SaveFootprintAudit()
    local flagged, unflagged, byClass = 0, 0, {}
    local function visit(cls, e, forced)
        local name = (e and e.GetName and e:GetName()) or ""
        -- Same exclusion as NoSaveSweep, for the same reason: by name, not by class.
        if name == mercenaries.StoreEntityName or cls == "mercenaries_Store" then return end
        local pfx = self.SaverPrefix
        if pfx and string.sub(name, 1, string.len(pfx)) == pfx then return end
        if not (forced or self:IsOurEntityName(name)) then return end
        local has = false
        pcall(function() has = (e:HasFlags(self.EntityFlagNoSave) and true) or false end)
        if has then flagged = flagged + 1 else
            unflagged = unflagged + 1
            byClass[cls] = (byClass[cls] or 0) + 1
        end
    end
    for _, cls in ipairs(self.UninstallOwnClasses or {}) do
        if cls ~= "mercenaries_Store" then
            pcall(function()
                for _, e in pairs(System.GetEntitiesByClass(cls) or {}) do visit(cls, e, true) end
            end)
        end
    end
    for _, cls in ipairs(self.UninstallScanClasses or {}) do
        pcall(function()
            for _, e in pairs(System.GetEntitiesByClass(cls) or {}) do visit(cls, e) end
        end)
    end
    System.LogAlways(string.format(
        "[Roster] save footprint: %d entit(ies) kept OUT of the save, %d would still be WRITTEN",
        flagged, unflagged))
    for cls, n in pairs(byClass) do
        System.LogAlways(string.format("[Roster]    %-24s %d would be written", cls, n))
    end
    System.LogAlways("[Roster] plus the store entity itself, which is meant to be there.")
    return flagged, unflagged
end

-- Stamping at SPAWN is not enough, and playline3/exit.whs is the proof: after the store
-- landed it still carried 20 SpawnedFriend NPCs, merc_bl_flag_3 and seven camp-smoke
-- ParticleEffects - all of them with the SAME entity names as the save before it. They
-- were not spawned by this session at all; the engine RESTORED them out of the previous
-- save, so no spawn-time code ever touched them, and they re-saved themselves forever.
--
-- So the flag has to be applied to what is already standing in the world, not only to
-- what we create. This runs on load, over the same classification the uninstall sweep
-- uses, and it is what actually empties a save of everything but the store.
-- THE ONE THAT MATTERS, and it is always on.
--
-- A save containing a single entity whose class the mod defines makes the game refuse
-- to load that save once the mod is gone - not slowly, not partially: CryAction aborts
-- with "Load of game has failed (CryEngine data)" and drops to the main menu. Proved in
-- the modding-tools build on 2026-09-14; the offender was one leftover merc_bl_flag_3.
--
-- Only mercenaries_Prop and mercenaries_Gate can do this, so this sweep is two
-- GetEntitiesByClass calls and runs on every low-priority tick. It is independent of
-- merc_roster_nosave, which is only ever about save SIZE.
function mercenaries:NoSaveSweepFatal()
    local n = 0
    for _, cls in ipairs(self.UninstallOwnClasses or {}) do
        if cls ~= "mercenaries_Store" then
            pcall(function()
                for _, e in pairs(System.GetEntitiesByClass(cls) or {}) do
                    if e then self:NoSaveEntity(e, true); n = n + 1 end
                end
            end)
        end
    end
    if n > 0 and not self._fatalSweepSaid then
        self._fatalSweepSaid = true
        System.LogAlways(string.format(
            "[Roster] fatal-class sweep: %d mod-class entit(ies) kept out of saves " ..
            "(they would abort a mod-less load outright)", n))
    end
    return n
end

-- The broad version: everything else the mod spawns, vanilla classes included. Purely a
-- save-size measure, so it stays behind merc_roster_nosave.
function mercenaries:NoSaveSweep(quiet)
    self:NoSaveSweepFatal()
    if not self.RosterNoSave then return 0 end
    local n = 0
    local function visit(cls, e, forced)
        local name = (e and e.GetName and e:GetName()) or ""
        -- The store is the ONE thing that must keep being written, and it is excluded by
        -- NAME, not by class. It used to be class mercenaries_Store; it is a vanilla
        -- BasicEntity called MercStore now, and "MercStore" matches IsOurEntityName's
        -- "^Merc%u" - so for one build this sweep stamped NO_SAVE on the mod's own save
        -- carrier every 60 seconds and nothing the mod owned ever persisted again.
        if name == mercenaries.StoreEntityName or cls == "mercenaries_Store" then return end
        -- Legacy per-tag savers are migrated and deleted by MigrateLegacy; flagging them
        -- would only keep them alive in the world for this session.
        local pfx = self.SaverPrefix
        if pfx and string.sub(name, 1, string.len(pfx)) == pfx then return end
        if not (forced or self:IsOurEntityName(name)) then return end
        self:NoSaveEntity(e)
        n = n + 1
    end
    for _, cls in ipairs(self.UninstallOwnClasses or {}) do
        if cls ~= "mercenaries_Store" then
            pcall(function()
                for _, e in pairs(System.GetEntitiesByClass(cls) or {}) do visit(cls, e, true) end
            end)
        end
    end
    for _, cls in ipairs(self.UninstallScanClasses or {}) do
        pcall(function()
            for _, e in pairs(System.GetEntitiesByClass(cls) or {}) do visit(cls, e) end
        end)
    end
    if not quiet then
        -- Not rLog: that is a `local` declared further down this file, so it is nil here.
        System.LogAlways(string.format(
            "[Roster] no-save sweep: %d entit(ies) flagged out of the next save", n))
    end
    return n
end

-- Timer entry point: Script.SetTimerForFunction takes a NAME, so it has to be a plain
-- field on the table, not a method. Armed from OnGameplayStarted.
--
-- One sweep is not enough and playline3/exit.whs shows why: it ran 2s after the load and
-- the CAMP had not been rebuilt yet, so eight MercCampFoodsmokehouseSmoke particle
-- effects were still unflagged when the next save was written. Anything the mod builds
-- later - camp, walls, towers, patrols, a merc hired an hour in - has the same problem.
-- So it repeats, slowly: there is no save event to hang it off, and the only cost of
-- being early is doing it again.
-- It deliberately does NOT arm a timer of its own to repeat: a pending
-- Script.SetTimerForFunction is itself serialised into the save (13 of them are in
-- playline3/exit.whs), so a sweep that re-armed itself would add the very kind of trace
-- it exists to remove. It rides LowPriorityMonitorLoop instead - see NoSaveSweepMaybe.
function mercenaries.NoSaveSweepTick()
    pcall(function() mercenaries:NoSaveSweep() end)
end

-- Called from the 5s low-priority loop; sweeps about once a minute. The scan is over a
-- dozen entity classes, so it is not something to do every tick.
mercenaries.NoSaveSweepEveryTicks = 6

function mercenaries:NoSaveSweepMaybe()
    -- Cheap and always: two class lookups, and it is the only thing standing between a
    -- player and a save that will not load once the mod is uninstalled.
    pcall(function() self:NoSaveSweepFatal() end)
    if not self.RosterNoSave then return end
    self._noSaveTicks = (self._noSaveTicks or 0) + 1
    if self._noSaveTicks < (self.NoSaveSweepEveryTicks or 6) then return end
    self._noSaveTicks = 0
    pcall(function() self:NoSaveSweep(true) end)
end

-- The one way the mod should put anything in the world. Stamps the spawn properties
-- AND the engine flag, so a class that ignores bSaved_by_game is still kept out of the
-- save. Pass keepInSave = true for the handful of things that genuinely must persist -
-- the store entity, and anything whose absence a reload would read as quest progress
-- (a dead enemy coming back to life is worse than a stale prop).
function mercenaries:SpawnTransient(params, keepInSave)
    if type(params) ~= "table" then return nil end
    local p = params
    if not keepInSave then
        p = {}
        for k, v in pairs(params) do p[k] = v end
        p.properties = self:NoSaveProps(params.properties)
    end
    local ent, err = nil, nil
    local ok = pcall(function() ent = System.SpawnEntity(p) end)
    -- SpawnEntity THROWS when a class has no .ent file, and the old call sites let that
    -- kill the calling command outright with nothing in the log. Catching it here would
    -- turn that into a silent nil, so say so instead.
    if not ok or not ent then
        System.LogAlways(string.format("[Roster] SpawnTransient FAILED: class=%s name=%s",
            tostring(p.class), tostring(p.name)))
        return nil
    end
    if not keepInSave then self:NoSaveEntity(ent) end
    return ent
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
    -- Before the tier match, like the archers': a woman's name carries "_medium_" too, and
    -- rebuilt as a medium man she would come back male, helmeted and in the squad's livery.
    if self.IsFemaleName and self:IsFemaleName(name) then return "female" end
    local tier = string.match(name, "^SpawnedFriend_([a-z]+)_")
    if tier == "archer" then return "archer" end
    return tier or "medium"
end

function mercenaries:RosterCapture()
    -- Men still queued to spawn are not in the world yet; a capture now would drop them from
    -- the roster, and an autosave in that second would lose them for good.
    if self.RosterSpawnQueue and #self.RosterSpawnQueue > 0 then
        local n = 0
        for _ in pairs(self.ActiveMercs or {}) do n = n + 1 end
        return n + #self.RosterSpawnQueue, nil
    end
    local out = {}
    for name, ent in pairs(self.ActiveMercs or {}) do
        local hp = 0
        pcall(function() hp = math.floor(ent.actor:GetHealth() or 0) end)
        -- The NAME goes in too. Without it a man is only "tier,hp", so a custom companion
        -- or an archer came back from a stow as a generic merc - reported against 2.3.
        -- Names carry no comma or semicolon, so the blob stays parseable.
        out[#out + 1] = self:RosterTierOf(name) .. "," .. tostring(hp) .. "," .. tostring(name)
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
        local tier, hp, nm = string.match(entry, "^([a-z_]+),(%-?%d+),(.+)$")
        if not tier then tier, hp = string.match(entry, "^([a-z_]+),(%-?%d+)$") end
        if tier then
            list[#list + 1] = { tier = tier, hp = tonumber(hp) or 0, name = nm }
        end
    end
    return list
end

-- Put `n` men of a tier into the world around the player. Returns how many stood up.
-- Rebuild ONE man exactly as he was, from the soul guid his own entity name carries.
--
-- Every merc this mod spawns is named "<prefix>_<tier>_<rand>_<soulGuid>", and the soul is
-- what makes him that man: a named companion, an archer, a particular face. Respawning him
-- from his tier alone is what turned companions into generic mercs after a stow (reported
-- against 2.3). Modelled on SpawnMercAt, which is still the path for a man with no name on
-- record - an older save's roster blob has none.
function mercenaries:RosterRespawnNamed(name, pos, yaw)
    name = tostring(name or "")
    -- The trailing 36-character guid, if the name carries one.
    local soulGuid = string.match(name, "([0-9a-fA-F][0-9a-fA-F-]+)$")
    if not soulGuid or string.len(soulGuid) < 36 then return nil end
    -- A fresh suffix: the old entity is gone, and two entities may not share a name.
    -- The guid is located with a PLAIN find, never a pattern: it is full of hyphens, and a
    -- hyphen in a Lua pattern is the lazy quantifier, so an embedded guid matches nonsense.
    local gi = string.find(name, soulGuid, 1, true)
    if not gi or gi < 3 then return nil end
    local head = string.sub(name, 1, gi - 2)              -- drops the "_" before the guid
    local stem = string.match(head, "^(.+)_%d+$") or head -- ...and the random suffix
    if not stem or stem == "" then return nil end
    local newName = stem .. "_" .. tostring(math.random(10000, 99999)) .. "_" .. soulGuid

    local ent
    local ok, err = pcall(function()
        -- Plain SpawnEntity again: the mod-wide SpawnTransient conversion was reverted
        -- on 2026-09-19 (see NoSaveSweep). RosterSpawnProps still stamps the properties,
        -- and NoSaveEntity below adds the engine flag when merc_roster_nosave is on.
        System.SpawnEntity({
            class = "NPC", name = newName, position = pos,
            orientation = { x = 0, y = 0, z = yaw or 0 },
            properties = self:RosterSpawnProps(soulGuid),
        })
        ent = System.GetEntityByName(newName)
        self:NoSaveEntity(ent)
        if not ent then return end
        self.ActiveMercs[newName] = ent
        pcall(function()
            self:EnsureMercIsAlwaysRendered(ent)
            self:EquipMercenary(ent, _G.MercCurrentOutfit or 1)
            self:EquipMercenaryWeapon(ent, _G.MercCurrentWeapon or 1, _G.MercCurrentOutfit or 1)
            self:InjectInteraction(ent)
            self:CampOnMercJoined(ent)
        end)
    end)
    if not ok then rLog("named respawn failed for " .. newName .. ": " .. tostring(err)) end
    return ent
end

-- One man, where the roster says he stood. Returns the entity or nil.
function mercenaries:RosterSpawnOne(m, pp, yaw, outfit, weapon)
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
    -- A named companion is rebuilt as himself, from the soul his name carries, rather
    -- than as an anonymous man of his tier.
    if m.name and self.RosterRespawnNamed then
        pcall(function() ent = self:RosterRespawnNamed(m.name, spot, yaw) end)
    end
    if not ent then
        if m.tier == "archer" then
            pcall(function() ent = self:SpawnArcherAt(spot, yaw, outfit) end)
        elseif m.tier == "female" then
            pcall(function() ent = self:SpawnFemaleAt(spot, yaw, weapon) end)
        else
            pcall(function() ent = self:SpawnMercAt(m.tier, spot, yaw, outfit, weapon) end)
        end
    end
    if ent and m.hp and m.hp > 0 then pcall(function() ent.actor:SetHealth(m.hp) end) end
    return ent
end

-- Put the men on the list into the world - a few now, the rest a few at a time. Fifty men
-- spawned in one frame at the far end of a fast travel is the one moment this mod has ever
-- crashed the game for people ("my game keeps crashing any time I fast travel with mercs",
-- three reports on one page), so past the first batch they come in on a timer.
mercenaries.RosterSpawnBatch   = 6
mercenaries.RosterSpawnEveryMs = 250
mercenaries.RosterSpawnQueue   = nil

function mercenaries:RosterSpawn(list)
    local pp
    pcall(function() pp = player:GetWorldPos() end)
    if not pp then return 0 end
    local yaw = 0
    pcall(function() local a = player:GetWorldAngles(); yaw = a and a.z or 0 end)
    local outfit = _G.MercCurrentOutfit or 1
    local weapon = _G.MercCurrentWeapon or 1
    local made = 0
    local batch = self.RosterSpawnBatch or 6
    for i, m in ipairs(list) do
        if i > batch then
            self.RosterSpawnQueue = self.RosterSpawnQueue or {}
            table.insert(self.RosterSpawnQueue, m)
        elseif self:RosterSpawnOne(m, pp, yaw, outfit, weapon) then
            made = made + 1
        end
    end
    if self.RosterSpawnQueue and #self.RosterSpawnQueue > 0 and not self._rosterQueueArmed then
        self._rosterQueueArmed = true
        rLog(string.format("%d man/men now, %d more queued at %d every %d ms",
            made, #self.RosterSpawnQueue, batch, self.RosterSpawnEveryMs or 250))
        Script.SetTimerForFunction(self.RosterSpawnEveryMs or 250, "mercenaries.RosterSpawnTick")
    end
    return made
end

mercenaries.RosterSpawnTick = function()
    local self = mercenaries
    local q = self.RosterSpawnQueue
    if not q or #q == 0 then
        self._rosterQueueArmed = false
        self.RosterSpawnQueue = nil
        rLog("the queued men are all in the world")
        pcall(function() self:RosterCapture() end)
        pcall(function() self:BeginFollowVerify("roster queue") end)
        return
    end
    local pp
    pcall(function() pp = player:GetWorldPos() end)
    if pp then
        local yaw = 0
        pcall(function() local a = player:GetWorldAngles(); yaw = a and a.z or 0 end)
        local outfit = _G.MercCurrentOutfit or 1
        local weapon = _G.MercCurrentWeapon or 1
        for _ = 1, (self.RosterSpawnBatch or 6) do
            local m = table.remove(q, 1)
            if not m then break end
            pcall(function() self:RosterSpawnOne(m, pp, yaw, outfit, weapon) end)
        end
    end
    Script.SetTimerForFunction(self.RosterSpawnEveryMs or 250, "mercenaries.RosterSpawnTick")
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
    -- WHICH men are missing, by name - not how many. The shortfall used to be "the last N
    -- entries of the roster", on the assumption that the engine restores the first ones. It
    -- does not: it restores whichever it kept, so when a load dropped a companion and kept two
    -- soldiers, the roster spawned a THIRD soldier and Hans Capon was gone for good ("each
    -- time I reloaded a save Hans was replaced by a regular soldier" - a streamer, 2026-09-21).
    -- An entry with no name (an older save's blob) still falls back to the count.
    local liveNames = {}
    for name in pairs(self.ActiveMercs or {}) do liveNames[tostring(name)] = true end
    local want, unnamedLive = {}, live
    for _, m in ipairs(list) do
        if m.name and m.name ~= "" then
            if not liveNames[m.name] then want[#want + 1] = m end
        elseif unnamedLive > 0 then
            unnamedLive = unnamedLive - 1
        else
            want[#want + 1] = m
        end
    end
    if #want == 0 then
        if live > #list then
            rLog(string.format("%d men standing against a roster of %d - the roster is stale, rewriting it", live, #list))
            self:RosterCapture()
        end
        self.RosterStowed = false
        pcall(function() self:SaveString("MercRosterStowed", "0") end)
        return
    end
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
