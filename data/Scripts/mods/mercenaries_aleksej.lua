-- Aleksej of Zaslawye: his lodging, a pre-combat speech test, and the 9-beat runner
-- (docs/aleksej.md). Three parts:
--
-- 1. A PLACEMENT editor for his room. He needs a spawn point, a stool, a bed and a chest, and
--    the chest is the beat 6 reveal, so its position matters as much as his.
--
--      F5  Aleksej's spawn point      F8   chest
--      F6  stool                      F9   dump the four positions
--      F7  bed                        F10  clear what has been placed
--
--    merc_alx_binds takes the F-keys off whatever holds them (the camp builder, the siege
--    builder, the route recorder); merc_bcamp_binds / merc_siege_binds take them back.
--
-- 2. A FORCED-DIALOGUE test, for the marsh speech (beat 9).
--
--    merc_alx_talk spawns the test NPC. His brain is aleksej_brain, which fires forced_dialog
--    from its own scheduler arm (aleksej_scheduler.xml) - the test NPC carries no camp role, so
--    that arm is what starts the speech, not camp_actor. Nothing else: no
--    combat role, not in ActiveMercs, nothing. Walk within ten metres and merc_alx_talk_now (or
--    proximity) calls RequestForceTalk, which queues the "aleksej_marsh" alias for
--    data/AI/forced_dialog.xml to play via Function_speech_dialogInitiator - see part 3 below.
--
--    This replaces two earlier attempts. RequestBark was wrong: a bark is an alias queued for a
--    schedulerMonolog node inside a behaviour the NPC is already running, and it is not a
--    dialogue at any stage - the test NPC just stood there eating. A separate top-level Skald
--    ForcedDialog module (gated by its own bool port, fired by dropping a token when the player
--    closed to range) also proved unnecessary once RequestForceTalk/forced_dialog.xml was
--    working - it never touches the production beat 9 path and has been removed
--    (docs/aleksej.md).
--
-- 3. THE BEAT RUNNER (bottom of the file). Nine beats, replacing mercenaries.KleinkriegContracts.
--    It does NOT touch that table or mercenaries.BCQ - the Kleinkrieg runner (mercenaries_
--    banditcamp_quest.lua) is someone else's file, mid-rewrite concurrently, and its whole
--    engine is wired through that one singleton. Re-pointing it for nine unrelated beats would
--    have meant fighting its per-tick alert/despawn/rebuild logic beat by beat.
--
--    Instead this reuses the pieces that already take explicit arguments and carry no
--    Kleinkrieg-specific state: BanditCampFollowerCount (scaling), BanditCampSiteByName /
--    BanditCampSiteAnchor (the same eight camp/patrol sites), EnemyGroups + SpawnEnemyAt +
--    EquipEnemy (mercenaries_spawning.lua's own words: "the single spawn path for every
--    encounter"), SpawnRaborsch (beat 8, untouched), IsAliveAndWell, and RequestForceTalk +
--    forced_dialog.xml (beat 9, already proven above). Three functions this file does not own
--    are additively WRAPPED, not edited, so every existing caller keeps working exactly as
--    before and only Aleksej's own actors are affected:
--      BanditCampMonitor     - also ticks AlxTick every pass, same cadence as the rest of the mod

local function aLog(s) System.LogAlways("[Aleksej] " .. s) end

mercenaries.AlxPieces = {}     -- { kind =, ents = {id,...}, pos =, yaw = }
mercenaries.AlxCat    = 0
mercenaries.AlxGhost  = "objects/manmade/common_furniture/barrels/barrel_a.cgf"

-- What each key places. `spawn` is a position only - nothing is left in the world for it
-- beyond a marker you can see while laying the room out. `key` is the short field name
-- AlxDump writes into mercenaries.AlxLodging and every consumer (AlxLodgingSpawn,
-- AlxBeat6Start) reads back - it must match on both ends or the baked-in table is silently
-- the wrong shape.
function mercenaries:AlxCatalogue()
    if self._alxCat then return self._alxCat end
    self._alxCat = {
        { name = "Aleksej's spawn", key = "spawn", marker = true,
          ghost = "objects/manmade/structures/defensive/walls/palisade/palisade_wall_single_sharp.cgf" },
        { name = "stool", key = "stool", model = self.CampModels and self.CampModels.Stool, so = self.CampChairSO },
        { name = "bed",   key = "bed",   model = self.CampModels and self.CampModels.Bed,   so = self.CampBedSO },
        { name = "chest", key = "chest", stash = "Objects/characters/assets/chest/chest_rustic_a.cdf" },
    }
    return self._alxCat
end

function mercenaries:AlxSpec()
    local it = self:AlxCatalogue()[self.AlxCat]
    if not it then return nil end
    return {
        parts = { { model = it.ghost or it.model or self.AlxGhost,
                    x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0 } },
        validMaterial = nil, sink = 0,
        isValid = function() return true end,
        atMax   = function() return false end,
        confirm = function(s, pos, angle) s:AlxPlace(pos, angle) end,
        onCancel = function(s) s:AlxUndo() end,
        keepOnCancel = true,
        info = { placing = 'merc_info_tower_placing', already = 'merc_info_tower_already',
                 aim = 'merc_info_tower_aim', blocked = 'merc_info_tower_blocked',
                 limit = 'merc_info_tower_limit', raised = 'merc_info_tower_raised',
                 cancelled = 'merc_info_tower_cancelled' },
    }
end

function mercenaries:AlxPick(i)
    self.AlxCat = i
    local spec = self:AlxSpec()
    if not spec then return end
    if self.ActivePlacement then self:EndPlacement() end
    self:StartPlacement(spec)
    aLog("placing: " .. self:AlxCatalogue()[i].name)
end

function mercenaries:AlxPlace(pos, yaw)
    local it = self:AlxCatalogue()[self.AlxCat]
    if not it then return end
    pos = pos or self.PlacePos or self:TowerLookedAtPos()
    yaw = yaw or self.PlaceAngle or 0
    if not pos then aLog("look at solid ground first"); return end
    -- NO ground snap. PlacePos is already the exact point the camera ray hit, which is where the
    -- ghost is drawn. CampSnapToGround starts its probe 5m ABOVE that point and casts down, so
    -- indoors it finds the roof first and the furniture lands up there. Snapping is for outdoor
    -- terrain placement (the camp rings below); an aimed point needs no correction.

    local ents = {}
    if it.stash then
        pcall(function()
            local e = System.SpawnEntity({
                class = "Stash", name = "AlxChest_" .. tostring(math.random(100000, 999999)),
                position = pos, orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
                properties = { object_Model = it.stash, bSaved_by_game = false },
            })
            if e then
                pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw }) end)
                table.insert(ents, e.id)
            end
        end)
    elseif it.so and it.model then
        self:SpawnCampFurnitureSO(it.model, pos, yaw, "AlxFurn", it.so, nil, ents)
    else
        -- The spawn point: a stake so the spot is visible while the room is laid out. It is
        -- NOT part of the room - the dump gives you a coordinate, not a prop.
        self:SpawnCampPropModel(it.ghost, pos, yaw, "AlxMark", ents)
    end

    table.insert(self.AlxPieces, { kind = it.name, key = it.key, ents = ents, pos = pos, yaw = yaw })
    aLog("placed " .. it.name .. string.format("  (%.2f, %.2f, %.2f)", pos.x, pos.y, pos.z))
end

function mercenaries:AlxUndo()
    local last = table.remove(self.AlxPieces)
    if not last then aLog("nothing to undo"); return end
    for _, id in ipairs(last.ents or {}) do pcall(function() System.RemoveEntity(id) end) end
    aLog("undid " .. tostring(last.kind))
end

function mercenaries:AlxClear()
    for _, p in ipairs(self.AlxPieces) do
        for _, id in ipairs(p.ents or {}) do pcall(function() System.RemoveEntity(id) end) end
    end
    self.AlxPieces = {}
    if self.ActivePlacement then self:EndPlacement() end
    self.AlxCat = 0
    aLog("cleared")
end

-- Absolute, because a room is not replayed anywhere else. Shape matches what every consumer
-- actually reads (AlxLodgingSpawn's L.spawn/L.spawnYaw, AlxBeat6Start's L.chest/L.chestYaw):
-- a position table per key, plus a sibling <key>Yaw - NOT a flat array of {what=,x=,...}. The
-- two must agree or a copy-pasted table silently reads as nil everywhere.
function mercenaries:AlxDump()
    if #self.AlxPieces == 0 then aLog("nothing placed yet"); return end
    local lvl = "unknown"
    for _, get in ipairs({ function() return System.GetCurrLevelName() end,
                           function() return Game.GetLevelName() end }) do
        local ok, v = pcall(get)
        if ok and v and v ~= "" then lvl = tostring(v); break end
    end
    aLog("---- Aleksej's lodging (level " .. lvl .. ") ----")
    aLog("mercenaries.AlxLodging = {")
    for _, p in ipairs(self.AlxPieces) do
        local key = p.key or p.kind
        aLog(string.format('    %s = { x = %.2f, y = %.2f, z = %.2f },', key, p.pos.x, p.pos.y, p.pos.z))
    end
    for _, p in ipairs(self.AlxPieces) do
        local key = p.key or p.kind
        aLog(string.format('    %sYaw = %.4f,', key, p.yaw or 0))
    end
    aLog("}")
end

-- ==== forced-dialogue test ====
-- A REAL forced dialogue, not a bark: RequestForceTalk queues the alias, and
-- data/AI/forced_dialog.xml (fired from the NPC's own scheduler arm) calls
-- Function_speech_dialogInitiator with Initiator="NonPlayer" on the target Decision
-- (carbongo/aleksej_marsh.xml, Alias="aleksej_marsh").
--
-- The previous version asked RequestBark for a monolog alias, which is why the test NPC stood
-- there eating bread: a bark is queued for a schedulerMonolog node inside a behaviour the NPC
-- is already running, and it is not a dialogue at any point.
-- The console wraps a non-empty %line argument in double quotes, so an unstripped arg arrives
-- as ["GOSSIP] and silently matches nothing. mercenaries_ambush.lua documents the same trap.
local function alxArg(v)
    local t = tostring(v or ""):gsub("^%s*(.-)%s*$", "%1")
    t = t:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
    return (t:gsub("^%s*(.-)%s*$", "%1"))
end

-- Aleksej's lodging in Kuttenberg, placed with the F5-F11 editor and dumped with merc_alx_dump.
-- These are exact interior floor points: never pass them through CampSnapToGround.
mercenaries.AlxLodgingLevel = "kutnohorsko"
mercenaries.AlxLodging = {
    spawn = { x = 3215.88, y = 434.23, z = 36.72 },
    stool = { x = 3212.28, y = 434.27, z = 36.55 },
    bed   = { x = 3213.60, y = 449.00, z = 42.99 },   -- beside the chest, which is on good ground
    chest = { x = 3215.04, y = 449.00, z = 42.99 },
    spawnYaw = -0.6379,
    stoolYaw = -2.1840,
    bedYaw   = -1.4091,
    chestYaw = -1.5089,
}

mercenaries.AlxTalkRange = 10.0
-- Spawn close: the player stands on navmesh, 15m ahead might be a rock. A dialogue whose preset
-- positions its participants needs a pathable NPC or the request just times out.
mercenaries.AlxSpawnDist = 6.0
-- Decision alias to play. Defaults to one of the mod's OWN gossip dialogs, because those are
-- proven to play from this exact BT node - so a first run tests the MECHANISM, not new content.
-- Swap for Aleksej's own Decision once it exists.
-- Aleksej's own speech. No metarole is passed at all - the player holds none in any vanilla
-- player dialogue, and passing him one was why the Decision never matched.
mercenaries.AlxTalkAlias = "aleksej_marsh"
-- 1 = fader, 2 = chat, 3 = ingame. preset does NOT have to match the Dialogue's Type - a shipped
-- Type="chat" dialogue is called with both ingame and chat presets.
--
-- What the preset DOES decide is positioning, and that is what timed the request out: ingame and
-- fader move and rotate the participants, so an NPC who cannot path never arrives. chat positions
-- nobody - it is what vanilla's pre-duel taunt uses, the closest shipped thing to this beat - so
-- it is the default until the speech is confirmed playing.
--
-- ...except chat is now RULED OUT for this file: preset=chat against a Type="ingame" dialogue
-- logs "Dialogue chat mode is not consistent with its decisions branch type". ingame is the
-- matching pair and raises no such error, so 3. fader also raises none, and is what the finished
-- beat wants (control taken) - merc_alx_preset 1.
mercenaries.AlxTalkPreset = 1

mercenaries.AlxTokenNear = "679a655e-189d-4519-b437-ccc4b92bea5d"
mercenaries.AlxTokenFar  = "679a655e-189d-4519-b437-ccc4b92bea6d"
mercenaries.AlxTalk = nil

-- HIS OWN soul. The full chain, none of it shared with the quartermaster:
--   soul_aleksej (soul__mercenaries.xml)          - the entity the game spawns
--     -> char_aleksej (skald_character__)         - who he is to the dialogue system
--       -> role_aleksej (role__ + character2role) - what a <Response Role=""> binds to
-- The BRAIN is his own, aleksej_brain: a townsman who talks and does not pick fights, plus his
-- own camp routine and forced-dialogue arms (aleksej_scheduler.xml). That is what Aleksej is for
-- beats 1-5, and the brain decides it, not the soul.
-- Voice pool is "generic" only - he is Ruthenian, so the christian lines are wrong for him.
mercenaries.AlxTestSoul = "a1e50000-1c4b-4e6a-9f01-3b8c5d2e7b01"

local function alxSignal(self, cls)
    pcall(function() player.inventory:CreateItem(cls, 1, 1) end)
end

-- NO AI. He is spawned and left alone: no camp role, no activity, no combat table entry,
-- nothing in ActiveMercs. The only thing he is for is the conversation.
function mercenaries:AlxTalkTest(alias)
    alias = alxArg(alias)
    if alias ~= "" then self.AlxTalkAlias = alias end
    if not player then return end
    local p, a
    pcall(function() p = player:GetWorldPos(); a = player:GetWorldAngles() end)
    if not p then return end
    local yaw = (a and a.z) or 0
    local d = self.AlxSpawnDist
    local pos = self:CampSnapToGround({ x = p.x + math.cos(yaw) * d,
                                        y = p.y + math.sin(yaw) * d, z = p.z })

    self:AlxTalkClear()
    local name = "AleksejTest_" .. tostring(math.random(10000, 99999)) .. "_" .. self.AlxTestSoul
    local ent
    pcall(function()
        System.SpawnEntity({
            class = "NPC", name = name, position = pos,
            orientation = { x = math.cos(yaw + math.pi), y = math.sin(yaw + math.pi), z = 0 },
            properties = { guidSharedSoulId = self.AlxTestSoul },
        })
        ent = System.GetEntityByName(name)
    end)
    if not ent then aLog("could not spawn the test NPC"); return end

    -- A standing activity gives him something to do while he waits. His brain is
    -- aleksej_brain (part 2 above); the speech is delivered by its own scheduler arm polling
    -- ForceTalkWanted, not camp_actor's.
    local wuid = XGenAIModule.GetMyWUID(ent)
    local ws = tostring(wuid or (ent.this and ent.this.id) or ent.id)
    self.BanditCampActors[ws] = true
    self.CampActivities[ws] = { unstance = "eating_standing", mode = 2, pos = pos, facePos = p }

    self.AlxTalk = { id = ent.id, ws = ws, altWs = tostring(ent.this and ent.this.id or ws), fired = false }
    aLog(string.format("test NPC %.0fm ahead (on navmesh, near you). Walk within %.0fm.", self.AlxSpawnDist, self.AlxTalkRange))
    aLog("  a conversation starting = RequestForceTalk/forced_dialog.xml works")
    aLog("  nothing = check the log for [fd] lines (data/AI/forced_dialog.xml)")
    aLog("  merc_alx_talk_now forces it from here; merc_alx_talk_clear removes him")
end

function mercenaries:AlxTalkTick()
    local T = self.AlxTalk
    if not (T and not T.fired and player) then return end
    local e = System.GetEntity(T.id)
    if not e then self.AlxTalk = nil; return end
    local p, q
    pcall(function() p = player:GetWorldPos(); q = e:GetWorldPos() end)
    if not (p and q) then return end
    local dx, dy, dz = q.x - p.x, q.y - p.y, q.z - p.z
    if (dx * dx + dy * dy + dz * dz) <= (self.AlxTalkRange * self.AlxTalkRange) then
        self:AlxTalkFire()
    end
end

-- The BT arm is what starts the conversation: RequestForceTalk queues the Decision alias and
-- camp_actor's first branch plays it AT the player, the same way the gossip arm plays one at
-- another merc. The Skald token gate is kept too - harmless, and it is what a real beat would
-- use to pick which speech plays.
function mercenaries:AlxTalkFire()
    local T = self.AlxTalk
    if not T then aLog("no test NPC - run merc_alx_talk first"); return end
    T.fired = true
    alxSignal(self, self.AlxTokenNear)
    self:RequestForceTalk(T.ws, self.AlxTalkAlias, self.AlxTalkPreset, T.altWs)
    local pn = ({ "fader", "chat", "ingame" })[self.AlxTalkPreset] or "?"
    aLog(("requested alias=[%s] preset=[%s %s] dist=%.1fm"):format(
        tostring(self.AlxTalkAlias), tostring(self.AlxTalkPreset), pn, self:AlxTestDist()))
    aLog("  watch for [fd] lines: scheduler firing / entered / dialogInitiator / returned")
    aLog("  'alias not found' = Skald side (Definition without an instance node, docs/aleksej.md)")
    aLog("  plays but feels wrong = merc_alx_preset 1 (fader) 2 (chat) 3 (ingame)")
end

-- Distance to the test NPC. A dialogue request that times out with one soul is usually just
-- distance, so it belongs in the log next to the alias.
function mercenaries:AlxTestDist()
    local T = self.AlxTalk
    local e = T and System.GetEntity(T.id)
    if not (e and player) then return -1 end
    local a, b = e:GetWorldPos(), player:GetWorldPos()
    if not (a and b) then return -1 end
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function mercenaries:AlxTalkPresetSet(line)
    local n = tonumber(alxArg(line))
    if not n or n < 1 or n > 3 then aLog("merc_alx_preset <1 fader|2 chat|3 ingame>"); return end
    self.AlxTalkPreset = n
    aLog("preset=" .. n .. " [" .. ({ "fader", "chat", "ingame" })[n] .. "] - merc_alx_talk_now to retry")
end

function mercenaries:AlxTalkClear()
    local T = self.AlxTalk
    if T then
        pcall(function() self:ClearBanditCampActor(T.ws) end)
        pcall(function() System.RemoveEntity(T.id) end)
        self.AlxTalk = nil
        aLog("test NPC removed")
    end
    -- Put the gate back down so the test can be run again.
    alxSignal(self, self.AlxTokenFar)
end

-- DISABLED. No editor holds F5-F11 any more: all three binders are commented out so the
-- F-keys stay free for the game. Every merc_alx_* command still works from the console -
-- only the key grab is off.
--
-- TO RESTORE: uncomment the block below and uncomment the AlxBinds call in the load hook in
-- mercenaries.lua.
function mercenaries:AlxBinds(quiet)
    aLog("key binding is OFF for the lodging editor - nothing holds F5-F11.")
    aLog("  every merc_alx_* command still works from the console")
    aLog("  to restore: uncomment AlxBinds in mercenaries_aleksej.lua")
    -- self:EditorOwner("aleksej")
    -- self:EditorsStopExcept("aleksej")
    -- pcall(function()
    --     System.ExecuteCommand("bind f5 merc_alx_spawn")
    --     System.ExecuteCommand("bind f6 merc_alx_stool")
    --     System.ExecuteCommand("bind f7 merc_alx_bed")
    --     System.ExecuteCommand("bind f8 merc_alx_chest")
    --     System.ExecuteCommand("bind f9 merc_alx_dump")
    --     System.ExecuteCommand("bind f10 merc_alx_clear")
    --     System.ExecuteCommand("bind f11 merc_alx_undo")
    -- end)
    -- if not quiet then self:AlxHelp() end
end

function mercenaries:AlxHelp()
    aLog("F5 Aleksej's spawn   F6 stool   F7 bed   F8 chest")
    aLog("F9 dump the positions   F10 clear   F11 undo the last piece")
    aLog("LEFT CLICK places, RIGHT CLICK undoes - both need a weapon drawn (engine input map)")
    aLog("merc_bcamp_binds / merc_siege_binds take the F-keys back")
    aLog("merc_alx_talk [alias] spawns the pre-combat speech test NPC")
    aLog("merc_alx_beat <n>   jump to beat n of the 9-beat runner (testing)")
    aLog("merc_alx_status     what the runner is doing right now")
end

mercenaries:DevCommand("merc_alx_lodging",    "mercenaries:AlxLodgingSpawn()",  "Spawn Aleksej and his room (Kuttenberg)")
mercenaries:DevCommand("merc_alx_lodging_off","mercenaries:AlxLodgingRemove()", "Remove Aleksej and his room")
mercenaries:DevCommand("merc_alx_spawn",      "mercenaries:AlxPick(1)",   "F5 - Aleksej's spawn point")
mercenaries:DevCommand("merc_alx_stool",      "mercenaries:AlxPick(2)",   "F6 - stool")
mercenaries:DevCommand("merc_alx_bed",        "mercenaries:AlxPick(3)",   "F7 - bed")
mercenaries:DevCommand("merc_alx_chest",      "mercenaries:AlxPick(4)",   "F8 - chest")
mercenaries:DevCommand("merc_alx_dump",       "mercenaries:AlxDump()",    "F9 - print the four positions")
mercenaries:DevCommand("merc_alx_clear",      "mercenaries:AlxClear()",   "F10 - remove what has been placed")
mercenaries:DevCommand("merc_alx_undo",       "mercenaries:AlxUndo()",    "F11 - undo the last piece")
mercenaries:DevCommand("merc_alx_place",      "mercenaries:AlxPlace()",   "Place at your aim point (console)")
mercenaries:DevCommand("merc_alx_binds",      "mercenaries:AlxBinds()",   "Take F5-F11 for the lodging editor")
mercenaries:DevCommand("merc_alx_help",       "mercenaries:AlxHelp()",    "Key map")
mercenaries:DevCommand("merc_alx_talk",       "mercenaries:AlxTalkTest('%line')", "Pre-combat speech test: spawn an NPC that speaks when approached")
mercenaries:DevCommand("merc_alx_talk_now",   "mercenaries:AlxTalkFire()",  "Force the test line without walking up")
mercenaries:DevCommand("merc_alx_preset",     "mercenaries:AlxTalkPresetSet('%line')", "Forced-dialogue preset: 1 fader, 2 chat, 3 ingame")
mercenaries:DevCommand("merc_alx_talk_clear", "mercenaries:AlxTalkClear()", "Remove the test NPC")

-- ==== the beat runner ====
-- Nine beats, and SKALD OWNS THE PROGRESSION - which beat is live, when it is finished, what it
-- pays, and the journal (the alx_* half of mercenaries_background_quest.xml). One int, alx_beat,
-- is the whole quest. This file's remaining job is to put a camp in the world when it is asked
-- to, and take it away again when everyone in it is dead.
--
-- The contract is one token per beat, created by the quest graph in the player's inventory and
-- swept by MonitorInventory (mercenaries.lua):
--
--     AlxSpawnToken[N]  ->  AlxSpawnBeat(N)
--
-- The graph issues it when beat N opens, AND again on every level wake while N is still the
-- live, unfinished beat. That second path is the whole reason a camp survives a reload without
-- being save data: nothing here is persisted, everything is dropped on load, and the token puts
-- it back.
--
-- WHAT ENDS A BEAT IS THE LEADER'S DEATH, and Skald watches that itself with a SoulDeathTrigger
-- on his own dedicated soul - every beat has a different one. So there is no kill counting, no
-- completion signalling, no payout and no save blob in this file any more. Clearing the rest of
-- the camp is optional; it only decides when the tents come down.
--
-- One exception: beat 6 has no camp and no leader, so Lua still tells Skald when the lodging
-- chest has been opened. There is nothing in the world there for Skald to watch.

-- Skald -> Lua: "stand beat N's camp up". item__mercenaries.xml, and the exec_alx_spawn_N
-- EventFunctions in the quest graph, carry these same GUIDs.
mercenaries.AlxSpawnToken = {
    [1] = "679a655e-189d-4519-b437-ccc4b92bec2d",
    [2] = "679a655e-189d-4519-b437-ccc4b92bec3d",
    [3] = "679a655e-189d-4519-b437-ccc4b92bec4d",
    [4] = "679a655e-189d-4519-b437-ccc4b92bec5d",
    [5] = "679a655e-189d-4519-b437-ccc4b92bec6d",
    [6] = "679a655e-189d-4519-b437-ccc4b92bec7d",
    [7] = "679a655e-189d-4519-b437-ccc4b92bec8d",
    [8] = "679a655e-189d-4519-b437-ccc4b92bec9d",
    [9] = "679a655e-189d-4519-b437-ccc4b92becad",
}

-- Lua -> Skald, the only one left: beat 6's documents are in hand.
mercenaries.TokenIDAlxB6Done = "679a655e-189d-4519-b437-ccc4b92beb7d"

-- Lua -> Skald: "beat N's leader is down". This is what actually closes a beat.
--
-- It was meant to be a SoulDeathTrigger on each leader's own soul, entirely inside Skald, and it
-- never fired once - while everything else in the same graph worked on the same run. A
-- SoulDeathTrigger does not appear to bind to an NPC spawned at runtime from a shared soul, only
-- to one baked into level data. Lua sees the death anyway, so Lua says so.
mercenaries.AlxDownToken = {
    [1] = "679a655e-189d-4519-b437-ccc4b92beccd",
    [2] = "679a655e-189d-4519-b437-ccc4b92becdd",
    [3] = "679a655e-189d-4519-b437-ccc4b92beced",
    [4] = "679a655e-189d-4519-b437-ccc4b92becfd",
    [5] = "679a655e-189d-4519-b437-ccc4b92bed0d",
    [7] = "679a655e-189d-4519-b437-ccc4b92bed1d",
    [8] = "679a655e-189d-4519-b437-ccc4b92bed2d",
    [9] = "679a655e-189d-4519-b437-ccc4b92bed3d",
}

-- A Lua->Skald token has to come back out of the pack once Skald has seen it, or the player ends
-- the arc carrying a fistful of sacks of nails. One tick's grace: OnAcquire is documented as
-- synchronous, but MonitorInventory and this tick share a pass, so a same-tick delete would be
-- betting on that.
--
-- Swept off a STATIC list rather than a queue of pending signals, the way BanditCampSweepTokens
-- does. A queue only knows about the tokens this session issued, so one that a save caught in
-- flight came back on load with nothing left to remove it - and sat in the pack re-firing its
-- trigger on every load after that.
mercenaries.AlxTokenSeen = {}

function mercenaries:AlxBridgeTokens()
    if self._alxSweepTokens then return self._alxSweepTokens end
    local t = { self.TokenIDAlxB6Done }
    for _, cls in pairs(self.AlxDownToken) do table.insert(t, cls) end
    for _, cls in pairs(self.AlxDocToken)  do table.insert(t, cls) end
    self._alxSweepTokens = t
    return t
end

function mercenaries:AlxSignalToken(cls)
    if not cls then return end
    pcall(function() player.inventory:CreateItem(cls, 1, 1) end)
    self.AlxTokenSeen[cls] = false
end

function mercenaries:AlxSweepTokens()
    if not (player and player.inventory) then return end
    for _, cls in ipairs(self:AlxBridgeTokens()) do
        pcall(function()
            local c = player.inventory:GetCountOfClass(cls)
            if c and c > 0 then
                if self.AlxTokenSeen[cls] then
                    player.inventory:DeleteItemOfClass(cls, c)
                    self.AlxTokenSeen[cls] = nil
                else
                    self.AlxTokenSeen[cls] = true   -- first tick seen: let it live one more
                end
            else
                self.AlxTokenSeen[cls] = nil
            end
        end)
    end
end

-- On load, straight out. A token still in the pack belongs to the session that saved, and Skald
-- restored its own state with that signal already counted; leaving it in fires the trigger a
-- second time and walks the arc on a beat.
function mercenaries:AlxSweepStaleTokens()
    if not (player and player.inventory) then return end
    self.AlxTokenSeen = {}
    local n = 0
    for _, cls in ipairs(self:AlxBridgeTokens()) do
        pcall(function()
            local c = player.inventory:GetCountOfClass(cls)
            if c and c > 0 then player.inventory:DeleteItemOfClass(cls, c); n = n + c end
        end)
    end
    if n > 0 then aLog("load: swept " .. n .. " stale bridge token(s) out of the pack") end
end

-- The seven documents, BY CLASS GUID. They were referenced by Name ("merc_alx_doc1") and every
-- CreateItem call silently did nothing inside its pcall, so no leader ever carried one - the same
-- failure mode as player.inventory:AddMoney. Item NAMES are not item CLASSES; every working
-- CreateItem in this mod passes a GUID (see reference_paying_the_player).
mercenaries.AlxDocs = {
    doc1 = "679a655e-189d-4519-b437-ccc4b92beaad",
    doc2 = "679a655e-189d-4519-b437-ccc4b92beabd",
    doc3 = "679a655e-189d-4519-b437-ccc4b92beacd",
    doc4 = "679a655e-189d-4519-b437-ccc4b92beadd",
    doc5 = "679a655e-189d-4519-b437-ccc4b92beaed",
    doc6 = "679a655e-189d-4519-b437-ccc4b92beafd",
    doc7 = "679a655e-189d-4519-b437-ccc4b92beb0d",
    doc8 = "679a655e-189d-4519-b437-ccc4b92beb1e",
}

-- Put an item in an inventory and CHECK IT LANDED. Three separate bugs in this quest have now been
-- a pcall around a call that quietly did nothing; a give that matters is worth reading back.
function mercenaries:AlxGiveItem(inv, cls, label)
    if not (inv and cls) then return false end
    pcall(function() inv:CreateItem(cls, 1, 1) end)
    local n = 0
    pcall(function() n = inv:GetCountOfClass(cls) or 0 end)
    if n > 0 then return true end
    aLog("FAILED to create " .. tostring(label or cls) .. " - the class GUID is wrong or the " ..
         "inventory was not ready")
    return false
end

-- Lua -> Skald: "the document is off his body". On a beat that carries one, the leader's death
-- raises "search the body" instead of ending the beat; this is what ends it. Without it the
-- player could walk past the one thing the beat exists to find.
mercenaries.AlxDocToken = {
    [2] = "679a655e-189d-4519-b437-ccc4b92bed4d",
    [5] = "679a655e-189d-4519-b437-ccc4b92bed5d",
    [7] = "679a655e-189d-4519-b437-ccc4b92bed6d",
    [8] = "679a655e-189d-4519-b437-ccc4b92bed7d",
}

-- Skald -> Lua: "he has left his lodging for good". Issued once alx_beat reaches 6 and again on
-- every level wake after that, so the empty room survives a reload without Lua persisting a flag.
mercenaries.TokenIDAlxLodgingGone = "679a655e-189d-4519-b437-ccc4b92becbd"

-- Every leader is his OWN soul, and the quest names him: soul_alx_* in soul__mercenaries.xml,
-- one SoulAsset apiece in the quest graph, one SoulDeathTrigger apiece. That is what lets the
-- progression live entirely in Skald - and what stopped every leader being called "Captain".
mercenaries.AlxLeaderSouls = {
    ondra   = "a1e50100-1c4b-4e6a-9f01-3b8c5d2e7c02",
    vavra   = "a1e50100-1c4b-4e6a-9f01-3b8c5d2e7c03",
    hedge   = "a1e50100-1c4b-4e6a-9f01-3b8c5d2e7c04",
    bartos  = "a1e50100-1c4b-4e6a-9f01-3b8c5d2e7c05",
    -- Spare. Beat 5 was a generic "the knight" on this soul until Sir Jezhek took the
    -- role; kept for the next named leader who needs one.
    knight  = "a1e50100-1c4b-4e6a-9f01-3b8c5d2e7c06",
    captain = "a1e50100-1c4b-4e6a-9f01-3b8c5d2e7c01",
    officer = "a1e50100-1c4b-4e6a-9f01-3b8c5d2e7c07",
    -- The marsh Aleksej. A mortal soul that looks like him: the immortal one (soul_aleksej) is
    -- the man in the lodging, and he cannot be the man who dies.
    aleksej = "a1e50000-1c4b-4e6a-9f01-3b8c5d2e7b03",
    -- Sir Jezhek of Holohlavy, cloned onto a soul of the mod's own - never his real one.
    jezek   = "a1e50100-1c4b-4e6a-9f01-3b8c5d2e7c08",
}

-- What a leader is worth carrying off. Cast silver, the first lootable silver in the game
-- (item__mercenaries.xml).
mercenaries.AlxSilver = "679a655e-189d-4519-b437-ccc4b92bed8d"

-- Sir Jezhek's own sword and the Lords of Holohlavy shield, bundled by the mod because vanilla
-- bundles neither (weapon_preset__mercenaries.xml).
mercenaries.AlxJezekWeapons = "a1e50100-1c4b-4e6a-9f01-3b8c5d2e7d02"

-- THE BEST HARNESS IN THE GAME, worn piece by piece. Not his own set: five of those seven pieces
-- carry IsQuestItem="true" and inventory:CreateItem silently refuses them - the log said
-- "NOT CREATED" for exactly those five and worked for the two without the flag. Nothing here
-- carries it, and there is no surcoat, caparison or tabard in the list.
--
-- ORDER MATTERS. equipment_slot.xml declares RequiresFilledSlot, and a plate slot will not accept
-- anything until the padded layer beneath it is filled:
--     head_helmet    <- head_coif_padded          body_plate  <- body_cloth_padded
--     body_chainmail <- body_cloth_padded         sleeves     <- body_cloth_padded
--     leg_armor      <- leg_trousers_padded       spur        <- boot
-- So the arming cap goes on before the bascinet, the gambeson before the cuirass and the arms,
-- the hose before the leg plate, and the boots before the spurs. Reorder this list and he ends up
-- half-dressed with no error anywhere.
mercenaries.AlxKnightHarness = {
    { "1b4b6487-72cc-409e-9296-692b53e0429e", "arming cap" },      -- CoifCap01_m01_C
    { "f55191d9-81e9-4d8c-b456-b12a24d198e3", "mail coif" },       -- CoifMail02_m01_B3
    { "311f5baa-ce48-48e0-98f2-e480b677a05a", "bascinet" },        -- BascinetVisor04_m01_A5, closed visor
    { "34249f9e-e0b2-4bd2-a462-770dacda5833", "gambeson" },        -- GambesonShort03_m10_A4
    { "2c501caf-4279-4bdf-82ea-9ba4bfaa4677", "hauberk" },         -- MailLong01_m03_C5
    { "1b214a97-8aa8-4892-bcd0-461b12b34258", "cuirass" },         -- Cuirass03_m01_A5, best torso plate in the game
    { "11b0fbff-28b9-409c-81ee-c9b5eda50921", "arms" },            -- ArmPlate04_m04_A5
    { "09ae6cbc-77d1-4686-801e-871b49440d7d", "gauntlets" },       -- Gauntlets05_m01_A5
    { "078e439b-1a5b-40ca-b009-d4abf6fcf810", "padded hose" },     -- LegsPadded01_m07_C3
    { "1972ac07-f8e1-41f0-9fb4-cf115b0088ec", "leg plate" },       -- LegsPlate03_m03_A5
    { "569438e6-7cae-483b-a4db-d1d25aa783d0", "boots" },           -- BootsKnee01_m01_C
    { "1113ab25-a055-478e-b0c9-42b5d0cb2c6d", "spurs" },           -- Spurs01_m01_C
}

-- Put one item on an NPC and SAY whether it went on. The pattern is vanilla's own
-- (references/Scripts/Entities/actor/player.lua): CreateItem into the inventory, FindItem for the
-- instance id, EquipInventoryItem on that. inventory:CreateItem is the call this mod has already
-- proven works on an NPC; ItemManager.CreateItem + AddItem is the one that silently does not
-- (reference_giving_items_to_npcs).
function mercenaries:AlxWear(ent, cls, label)
    if not (ent and ent.inventory and ent.actor and cls) then return false end
    local id
    pcall(function() id = ent.inventory:FindItem(cls) end)
    if not id then
        pcall(function() ent.inventory:CreateItem(cls, 1, 1) end)
        pcall(function() id = ent.inventory:FindItem(cls) end)
    end
    if not id then
        aLog("  " .. tostring(label) .. ": NOT CREATED (" .. tostring(cls) .. ")")
        return false
    end
    local ok = pcall(function() ent.actor:EquipInventoryItem(id) end)
    aLog("  " .. tostring(label) .. (ok and ": worn" or ": created but EquipInventoryItem FAILED"))
    return ok
end

-- The slots a livery preset fills that AlxKnightHarness does not, and that render OVER it: the
-- waffenrock/tabard above all, then a hood or a hat sitting on top of a bascinet, then a collar.
-- Ids are from Libs/Tables/item/equipment_slot.xml.
--
-- Taken off AFTER he is dressed, never before. Stripping first does not work: a runtime-spawned
-- NPC that has never worn a preset refuses EquipInventoryItem outright and the whole harness ends
-- up in his pack. The preset goes on, the harness goes on over it, and then only the parts still
-- showing come off. Deliberately NOT in this list: body_cloth (35) and leg_trousers (40) - a
-- shirt and hose belong under a gambeson and are invisible once the plate is on.
mercenaries.AlxOverSlots = {
    7,    -- body_coat  (the Waffenrock)
    23,   -- head_hood
    33,   -- head_cap
    22,   -- collar
}

-- Human.UnequipItemInSlot(slotId) - a real scriptbind taking an int slot id. inventory:
-- RemoveAllItems does NOT do this: it empties the pack, and clothes that are WORN stay worn,
-- which is exactly how Jezhek and Aleksej came out wearing two kits at once.
function mercenaries:AlxStripOverLayers(ent)
    local h = ent.human
    if not h then return end
    for _, slot in ipairs(self.AlxOverSlots) do
        pcall(function() h:UnequipItemInSlot(slot) end)
    end
end

-- A number that says whether the armour actually went on. There is no "what is in this slot"
-- query in the scriptbind, but GetArmor reads the character's armour value, and naked-against-
-- plate is not a subtle difference. Logged either side of the dressing, so one line in kcd.log
-- settles "he is wearing it" against "it is sitting in his pack".
function mercenaries:AlxArmourValue(ent)
    local v
    pcall(function() v = ent.actor:GetArmor() end)
    return v
end

-- Beat shape: { name, site, group, soloGroup, ratio/min OR fixedBase/fixedPerMerc, archerFrac,
-- capBoost, extraHealthMult, leaderSoul, leaderName, leaderClothingGroup, leaderSurcoat, doc,
-- siege, combat }. Counts mirror BanditCampScale's shape (see AlxScale).
mercenaries.AlxBeats = {
    [1] = { name = "woodland camp",     site = "woodland_camp",  group = "looter",
            ratio = 1.0, min = 4, archerFrac = 0.1,
            leaderName = "Ondra", leaderSoul = mercenaries.AlxLeaderSouls.ondra, combat = true },
    [2] = { name = "the mine",          site = "mining_camp",    group = "bandit",
            ratio = 1.1, min = 5, archerFrac = 0.15,
            leaderName = "Vavra", leaderSoul = mercenaries.AlxLeaderSouls.vavra,
            doc = mercenaries.AlxDocs.doc1, combat = true },
    [3] = { name = "the convoy",        site = "patrol_convoy",  group = "bandit", soloGroup = "looter",
            ratio = 1.3, min = 6, archerFrac = 0.15,
            leaderName = "the hedge knight", leaderSoul = mercenaries.AlxLeaderSouls.hedge,
            leaderClothingGroup = "knight",
            -- It is a SILVER convoy. He is carrying some.
            loot = mercenaries.AlxSilver, lootCount = 2, combat = true },
    [4] = { name = "burnt mill camp",   site = "south_camp",     group = "looter",
            ratio = 1.0, min = 5, archerFrac = 0.05,
            -- Aleksej names Kunes in the report line; the man actually in charge is not him -
            -- that mismatch IS the beat (docs/aleksej.md). Keep this name off any Kunes line.
            leaderName = "Bartos", leaderSoul = mercenaries.AlxLeaderSouls.bartos,
            leaderSurcoat = true, combat = true },
    [5] = { name = "Sigismund patrol",  site = "patrol_company", group = "sigi",
            ratio = 2.0, min = 9, archerFrac = 0.2, capBoost = 3, extraHealthMult = 1.3,
            -- THE OUTLIER. A normal step up from beat 3 would give beat 6 no trigger.
            -- A real knight in real plate, not a Sigismund livery pulled out of a pool.
            leaderName = "Sir Jezhek", leaderSoul = mercenaries.AlxLeaderSouls.jezek,
            leaderGear = mercenaries.AlxKnightHarness,
            leaderWeaponPreset = mercenaries.AlxJezekWeapons,
            doc = mercenaries.AlxDocs.doc2, combat = true },
    [6] = { name = "Kuttenberg lodging", combat = false },
    [7] = { name = "the burnt farm rearguard", site = "roman_fort",   group = "knight",
            fixedBase = 3, fixedPerMerc = 0.15, archerFrac = 0.1,
            leaderName = "the captain", leaderSoul = mercenaries.AlxLeaderSouls.captain,
            doc = mercenaries.AlxDocs.doc5, combat = true },
    [8] = { name = "Raborsch",          site = "raborsch",       group = "sigi",
            ratio = 1.2, min = 6, archerFrac = 0.15, siege = true,
            leaderName = "the officer", leaderSoul = mercenaries.AlxLeaderSouls.officer,
            leaderClothingGroup = "knight", doc = mercenaries.AlxDocs.doc6, combat = true },
    -- The marsh. A camp like any other now: he is a mortal man in armour at the head of his
    -- Ruthenians, there is no speech, and killing him ends the quest.
    -- Four archer carts and two towers are authored on the island. Against a small company that
    -- is a killing field before the melee even closes, so the carts are capped and thinned.
    [9] = { name = "the marsh island",  site = "swamp_island",   group = "ruthenian",
            smallCompany = 5, cartsIfSmall = 2, cartArchersIfSmall = 2, towersIfSmall = 0,
            fixedBase = 5, fixedPerMerc = 0.1, archerFrac = 0.1, extraHealthMult = 1.4,
            -- He is the last fight in the quest and he is dressed for it: the same harness Sir
            -- Jezhek wears, on a man who has been paying for armour out of an archbishop's silver
            -- for nine years.
            leaderName = "Aleksej", leaderSoul = mercenaries.AlxLeaderSouls.aleksej,
            leaderGear = mercenaries.AlxKnightHarness,
            -- Spelled out because RemoveAllItems takes the group's weapon off him again: without
            -- a preset of his own he met the player bare-handed. Axe and shield, like his men
            -- (axe_shield_4_02, no livery on it).
            leaderWeaponPreset = "5e37ab6b-d101-47f4-8e18-968288f1f84a",
            doc = mercenaries.AlxDocs.doc7, combat = true },
}

mercenaries.AlxSoul = mercenaries.AlxSoul or mercenaries.AlxTestSoul  -- same GUID; see part 2

mercenaries.AlxLodging = mercenaries.AlxLodging or {}
-- Fill in from merc_alx_dump once the room is placed: AlxLodging.spawn/.stool/.bed/.chest =
-- {x=,y=,z=}, plus a sibling .spawnYaw/.stoolYaw/.bedYaw/.chestYaw in radians for each.

mercenaries.AlxCamp      = nil    -- the one standing camp, or nil. Never saved.
mercenaries.AlxBeat6Done = false
mercenaries.AlxBeat6Live = false

-- HENRY'S OWN THOUGHTS. Beats 1-5 each end with a conversation; from beat 6 on Aleksej is gone
-- and there is nobody left to report to, so those beats end in silence (voicelines/
-- aleksej_script.md: "Beats 6, 7, 8 - no dialogue at all"). These two lines stand in for the
-- report dialogue at the two places the silence actually costs something: walking into the
-- emptied lodging, and reading the muster order off the captain at the burnt farm.
--
-- Game.SendInfoText is the mod's own channel for this (~90 call sites) and takes a localisation
-- key. In practice these read at about 80 characters; longer and the HUD line runs out.
mercenaries.AlxThoughtSecs = 8
mercenaries.AlxThoughts = {
    [7] = "merc_info_alx_raborsch",
}

function mercenaries:AlxThought(key)
    if not key then return end
    pcall(function() Game.SendInfoText(key, false, 0, self.AlxThoughtSecs) end)
    aLog("thought: " .. tostring(key))
end

-- Beat 6's thought fires on ARRIVAL, not on the loot: the reveal is the empty room, and the
-- player should have the line before they open the chest.
--
-- Anchored on the CHEST, and deliberately not on Aleksej's own spot as well. Beat 6 opens the
-- instant the beat-5 report ends, and that conversation happens where he stands - a second anchor
-- there would fire this the moment he vanishes, with the player rooted to the spot and nothing
-- discovered yet. The chest is ~16m off and 6m up from him (see AlxLodging above), well clear of
-- this radius, so the player has to walk to it.
mercenaries.AlxLodgingMsgKey   = "merc_info_alx_lodging"
mercenaries.AlxLodgingMsgRange = 10.0

-- Once EVER, not once per session. The beat-6 spawn token is reissued on every level wake and
-- AlxLodgingResetOnLoad rebuilds the chest on every load, so a plain boolean would replay this
-- line after each reload. SaveString is the mod's own save-persistent store
-- (mercenaries_saving.lua): the flag rides in the name of a hidden entity the game saves.
mercenaries.AlxLodgingMsgTag = "alx_told_lodging"
mercenaries.AlxLodgingMsgShown = nil   -- nil = not read back yet, then true/false

function mercenaries:AlxLodgingMsgDone()
    if self.AlxLodgingMsgShown == nil then
        local v
        pcall(function() v = self:LoadString(self.AlxLodgingMsgTag) end)
        self.AlxLodgingMsgShown = (v == "1")
    end
    return self.AlxLodgingMsgShown
end

-- Has the player reached the chest in the emptied lodging? Squared distance against the baked
-- anchor, the file's own idiom (AlxTalkTick).
function mercenaries:AlxAtLodging()
    if not player then return false end
    local L = self.AlxLodging
    if not L then return false end
    local p
    pcall(function() p = player:GetWorldPos() end)
    if not p then return false end
    local a = L.chest
    if not a then return false end
    local dx, dy, dz = a.x - p.x, a.y - p.y, a.z - p.z
    return (dx * dx + dy * dy + dz * dz) <= (self.AlxLodgingMsgRange * self.AlxLodgingMsgRange)
end

-- Lets the line be seen again - for testing, and so a player who reloads past it is not locked
-- out of it forever.
function mercenaries:AlxLodgingMsgReset()
    self.AlxLodgingMsgShown = false
    pcall(function() self:SaveString(self.AlxLodgingMsgTag, "0") end)
    aLog("the lodging thought will play again")
end

function mercenaries:AlxLodgingThought()
    if self:AlxLodgingMsgDone() then return end
    if not self:AlxLodgingHere() then return end
    if not self:AlxAtLodging() then return end
    self.AlxLodgingMsgShown = true
    pcall(function() self:SaveString(self.AlxLodgingMsgTag, "1") end)
    self:AlxThought(self.AlxLodgingMsgKey)
end

-- How many consecutive 1 Hz polls a body must be un-findable before it counts as gone. The
-- engine drops a handle for a tick without the NPC being dead (docs/npc-lod.md); without this
-- the camp would fold itself up mid-fight.
mercenaries.AlxMissingTicks = 5

-- A cleared camp is not taken down where the player is standing in it. It stays - bodies, tents,
-- fire and all - until they are this far off.
mercenaries.AlxCampDespawnRange = 100.0

-- ---- additive wraps around functions this file does not own ----

local AlxBaseMonitor = mercenaries.BanditCampMonitor
function mercenaries:BanditCampMonitor()
    if AlxBaseMonitor then AlxBaseMonitor(self) end
    local ok, err = pcall(function() self:AlxTick() end)
    if not ok then aLog("AlxTick error: " .. tostring(err)) end
end

-- ---- scaling ----
-- Same shape and the same follower count as BanditCampScale, so "how many men turn up" agrees
-- everywhere in the mod.
function mercenaries:AlxScale(beat)
    local F = self:BanditCampFollowerCount()
    local group = beat.group
    if beat.soloGroup and F == 0 then group = beat.soloGroup end

    local count
    if beat.fixedBase then
        count = beat.fixedBase + math.floor(F * (beat.fixedPerMerc or 0))
    else
        count = math.floor(math.max(1, F) * (beat.ratio or 1.0) + 0.5)
    end
    if count < (beat.min or 3) then count = beat.min or 3 end
    local cap = ((F == 0) and 10 or 20) + (beat.capBoost or 0)
    if count > cap then count = cap end

    local archers = math.floor(count * (beat.archerFrac or 0))
    return count, archers, group
end

-- ---- spawning ----
local function alxRing(origin, i, n, radius)
    local a = (i - 1) * (2 * math.pi / math.max(1, n))
    return { x = origin.x + math.cos(a) * radius, y = origin.y + math.sin(a) * radius, z = origin.z }
end

-- The beat's named leader, on HIS OWN soul. Skald's SoulDeathTrigger names that soul, so this
-- one NPC is the entire progression: kill him and the beat is over, whatever else is standing.
function mercenaries:AlxSpawnLeaderNPC(pos, yaw, beat)
    local ent
    pcall(function()
        local soul = beat.leaderSoul
        local name = "SpawnedEnemy_alxleader_" .. tostring(math.random(10000, 99999)) .. "_" .. soul
        System.SpawnEntity({
            class = "NPC", name = name,
            position = { x = pos.x, y = pos.y, z = pos.z },
            orientation = { x = 0, y = 0, z = yaw or 0 },
            properties = { guidSharedSoulId = soul },
        })
        ent = System.GetEntityByName(name)
    end)
    if not ent then return nil end

    -- THE PRESET GOES ON FIRST, even for a man who is about to be harnessed piece by piece. It is
    -- not decoration: a runtime-spawned NPC that has never had a clothing preset applied accepts
    -- inventory:CreateItem and then quietly refuses actor:EquipInventoryItem, so withholding it
    -- left Sir Jezhek carrying the best harness in the game in his pack with none of it on him.
    -- The second kit is dealt with below, after he is dressed - not by withholding this.
    self:EquipEnemy(ent, beat.group, false)

    if beat.leaderGear then
        -- Whatever else he turned up carrying goes; what he is WEARING stays on him, which is the
        -- point - the harness needs something to replace rather than nothing to sit on.
        pcall(function() ent.inventory:RemoveAllItems() end)
        -- A named man is harnessed piece by piece, in slot order. The pools below are for the
        -- ones who are only a rank.
        local was = self:AlxArmourValue(ent)
        aLog(tostring(beat.leaderName) .. " is dressing:")
        local worn = 0
        for _, g in ipairs(beat.leaderGear) do
            if self:AlxWear(ent, g[1], g[2]) then worn = worn + 1 end
        end
        -- Now the parts of the livery still showing over the plate - the waffenrock, a hat on top
        -- of the bascinet - and nothing else.
        self:AlxStripOverLayers(ent)
        aLog(string.format("%s dressed: %d/%d pieces, armour %s -> %s",
                           tostring(beat.leaderName), worn, #beat.leaderGear,
                           tostring(was), tostring(self:AlxArmourValue(ent))))
        if beat.leaderWeaponPreset then
            pcall(function() ent.actor:EquipWeaponPreset(beat.leaderWeaponPreset) end)
        end
    elseif beat.leaderClothingGroup then
        local grp = self.EnemyGroups[beat.leaderClothingGroup]
        local pool = grp and grp.clothing
        if pool and #pool > 0 then
            pcall(function() ent.actor:EquipClothingPreset(pool[math.random(#pool)]) end)
        end
    elseif beat.leaderSurcoat then
        local guid = self.AlxSurcoatClothingGuid
        if guid then
            pcall(function() ent.actor:EquipClothingPreset(guid) end)
        else
            aLog("TODO: mercenaries.AlxSurcoatClothingGuid not set - beat 4 leader " ..
                 "wears generic Sigismund gear instead of the shared surcoat")
            local pool = self.EnemyGroups.sigi and self.EnemyGroups.sigi.clothing
            if pool and #pool > 0 then
                pcall(function() ent.actor:EquipClothingPreset(pool[math.random(#pool)]) end)
            end
        end
    end
    if beat.extraHealthMult and ent.actor then
        pcall(function()
            local m = ent.actor:GetMaxHealth()
            if m and m > 0 then
                ent.actor:SetMaxHealth(m * beat.extraHealthMult)
                ent.actor:SetHealth(m * beat.extraHealthMult)
            end
        end)
    end
    -- reference_giving_items_to_npcs: inventory:CreateItem only - and read it back, because a
    -- document that never landed makes its beat uncompletable and says nothing while doing it.
    if beat.doc then
        if self:AlxGiveItem(ent.inventory, beat.doc, beat.leaderName .. "'s document") then
            aLog(tostring(beat.leaderName) .. " is carrying " .. tostring(beat.doc))
        end
    end
    if beat.loot then
        local n = beat.lootCount or 1
        pcall(function() ent.inventory:CreateItem(beat.loot, 1, n) end)
        local got = 0
        pcall(function() got = ent.inventory:GetCountOfClass(beat.loot) or 0 end)
        if got > 0 then
            aLog(string.format("%s is carrying %dx %s", tostring(beat.leaderName), got, tostring(beat.loot)))
        else
            aLog("FAILED to put loot on " .. tostring(beat.leaderName) .. " - class " .. tostring(beat.loot))
        end
    end
    return ent
end

-- Is this beat met on a ROAD rather than in a camp? The site row carries a recorded route, and
-- that changes everything about how the band stands: a convoy strung out along the road it is
-- actually travelling, not a ring of men in a field waiting to be walked into.
function mercenaries:AlxOnTheRoad(site)
    return site ~= nil and site.route ~= nil
end

-- `count` ordinary members of `group`, in a ring at a camp or in a column on a road. Never the
-- leader.
function mercenaries:AlxSpawnBand(beat, count, archers, group)
    if count <= 0 then return { ids = {}, wuids = {}, meleeIds = {}, archerIds = {} } end
    local site = self:BanditCampSiteByName(beat.site)
    if not site then
        aLog("beat '" .. tostring(beat.name) .. "': no site '" .. tostring(beat.site) ..
             "' in BanditCampSites")
        return nil
    end
    local origin = self:CampSnapToGround(self:BanditCampSiteAnchor(site))

    -- A COLUMN, about four metres between men measured along the road, so a band of seven takes
    -- up ~25m of it. Every man falls in BEHIND the anchor, never in front: the leader stands on
    -- it, and placing the others forward would put him at the back of his own column and send him
    -- walking through his men the moment he set off. Ported from the Kleinkrieg contract's own
    -- patrol spawner, where all of that was learned the hard way.
    local roadPts = self:AlxOnTheRoad(site) and self:BanditCampRoutePts(site.route) or nil
    local function bandPos(i, n)
        if roadPts then
            local step = (self.BanditCampColumnSpacing or 4.0)
                       / (self.BanditCampRoutePointSpacing or 10.7)
            local at = (site.pt or 1) - math.floor(i * step + 0.5)
            local a = roadPts[math.max(1, math.min(#roadPts, at))]
            if a then
                -- Sidestep off the centreline, perpendicular to the road's own heading.
                local b = roadPts[math.max(1, math.min(#roadPts, at + 1))] or a
                local hx, hy = b.x - a.x, b.y - a.y
                local len = math.sqrt(hx * hx + hy * hy)
                local off = ((i % 2 == 0) and 1.4 or -1.4)
                if len > 0.01 then
                    return { x = a.x - (hy / len) * off, y = a.y + (hx / len) * off, z = a.z }
                end
                return { x = a.x, y = a.y, z = a.z }
            end
        end
        return alxRing(origin, i, n, beat.radius or 6.0)
    end

    local ids, wuids, meleeIds, archerIds = {}, {}, {}, {}
    for i = 1, count do
        local isArcher = i <= archers
        local pos = self:CampSnapToGround(bandPos(i, count))
        local ent = self:SpawnEnemyAt(group, isArcher, pos, site.yaw or 0)
        if ent then
            table.insert(ids, ent.id)
            table.insert(isArcher and archerIds or meleeIds, ent.id)
            local w = XGenAIModule.GetMyWUID(ent)
            local ws = tostring(w or (ent.this and ent.this.id) or ent.id)
            table.insert(wuids, ws)
            local ws2 = ent.this and tostring(ent.this.id) or nil
            if ws2 and ws2 ~= ws then table.insert(wuids, ws2) end

            if beat.extraHealthMult and ent.actor then
                pcall(function()
                    local m = ent.actor:GetMaxHealth()
                    if m and m > 0 then
                        ent.actor:SetMaxHealth(m * beat.extraHealthMult)
                        ent.actor:SetHealth(m * beat.extraHealthMult)
                    end
                end)
            end
        end
    end
    return { ids = ids, wuids = wuids, meleeIds = meleeIds, archerIds = archerIds, origin = origin }
end

-- ---- the camp ----
-- Every camp site in BanditCampSites carries an authored layout in BanditCampLayouts; this
-- replays it through the Kleinkrieg camp's own BanditCampPlaceRow. That reads a couple of BCQ
-- fields as it works (the group its tower/cart archers are dressed as, the chest and seat pools
-- it records), so those are borrowed and put straight back - a Kleinkrieg contract can never be
-- running at the same time as a beat. Road sites have no layout and get no camp, which is right:
-- a column on the march is not a camp.
function mercenaries:AlxSpawnCampProps(C, site)
    local layout = self.BanditCampLayouts[site.layout or ""]
    if not layout then return end

    local S = self.BCQ
    local keep = { group = S.group, placed = S.letterChestPlaced, chest = S.letterChestId,
                   seats = S.seats, beds = S.beds }
    S.group, S.letterChestPlaced, S.letterChestId = C.group or "bandit", false, nil

    local origin = self:CampSnapToGround(self:BanditCampSiteAnchor(site))
    C.propIds, C.seats, C.beds, C.towers, C.carts = {}, {}, {}, {}, {}

    -- A small company gets fewer archer carts, and fewer archers on each of them.
    local beat = self.AlxBeats[C.beat] or {}
    local small = beat.smallCompany and (self:BanditCampFollowerCount() <= beat.smallCompany)
    local cartCap = small and beat.cartsIfSmall or nil
    local towerCap = small and beat.towersIfSmall or nil
    local cartsPlaced, towersPlaced = 0, 0
    if small then
        self.ArcherCartCrew = beat.cartArchersIfSmall
        aLog(string.format("small company: %d cart(s), %s archer(s) each",
             cartCap or -1, tostring(beat.cartArchersIfSmall)))
    end
    -- The station rows (the makeshift inn) push their own stools straight into BCQ.seats, which
    -- is nil unless a Kleinkrieg camp has been built this session. Pointed at our pool for the
    -- duration, so those stools are claimable like any other.
    S.seats, S.beds = C.seats, C.beds

    for _, row in ipairs(layout) do
        if cartCap and row.kind == "cart" then
            cartsPlaced = cartsPlaced + 1
            if cartsPlaced > cartCap then row = nil end
        elseif towerCap and row.kind == "tower" then
            towersPlaced = towersPlaced + 1
            if towersPlaced > towerCap then row = nil end
        end
        local ok, kind, wuid, soPos = true, nil, nil, nil
        if row then
            ok, kind, wuid, soPos = pcall(function()
                return self:BanditCampPlaceRow(row, origin, site.yaw or 0, C.propIds)
            end)
        end
        if not ok then
            aLog("camp row '" .. tostring(row.what) .. "' failed: " .. tostring(kind))
        elseif kind == "seat" then
            table.insert(C.seats, { wuid = wuid, pos = soPos, firePos = origin })
        elseif kind == "bed" then
            table.insert(C.beds, { wuid = wuid, pos = soPos })
        -- A tower/cart row hands back its STATION RECORD, and the caller owns it: it is what the
        -- archer is adopted from, brought down through, and torn down by.
        elseif kind == "tower" then
            table.insert(C.towers, wuid)
        elseif kind == "cart" then
            table.insert(C.carts, wuid)
        end
    end
    C.chestId, C.chestStocked, C.chestTries = S.letterChestId, false, 0
    self.ArcherCartCrew = nil

    S.group, S.letterChestPlaced, S.letterChestId = keep.group, keep.placed, keep.chest
    S.seats, S.beds = keep.seats, keep.beds

    aLog(string.format("camp '%s': %d prop(s), %d seat(s), %d bed(s), %d tower(s), %d cart(s)",
        tostring(site.layout), #C.propIds, #C.seats, #C.beds, #C.towers, #C.carts))
end

-- Sit / eat / sleep / walk the perimeter, so the camp reads as lived in rather than as a ring of
-- men facing outwards. Same borrow: AssignBanditCampRoles is written against the BCQ tables and
-- hands out the WUID-keyed camp roles the enemy schedulers already run (docs/ai-modules.md).
function mercenaries:AlxAssignCampRoles(C, origin)
    local S = self.BCQ
    local keep = { bandits = S.bandits, seats = S.seats, beds = S.beds, spots = S.spots,
                   site = S.site, idx = S.contractIdx }
    -- The LEADER is left out of the roles. He was drawing sit/eat/sleep with everyone else, so
    -- the man the whole beat is about stood eating bread through his own battle.
    local band = {}
    for _, id in ipairs(C.ids or {}) do
        if id ~= C.leaderId then table.insert(band, id) end
    end
    S.bandits, S.seats, S.beds, S.spots, S.site = band, C.seats or {}, C.beds or {}, {}, C.site
    -- AssignBanditCampRoles asks the running Kleinkrieg contract whether this is a camp or a
    -- column, so it is pinned to one of each: contract 1 (woodland) is a camp, contract 4
    -- (company) is a patrol. A road site gets the column - one man walking the recorded route
    -- with the rest following the man ahead - and a camp site gets sit/eat/sleep.
    S.contractIdx = self:AlxOnTheRoad(C.site) and 4 or 1
    pcall(function() self:AssignBanditCampRoles(origin) end)
    C.spots = S.spots
    S.bandits, S.seats, S.beds, S.spots, S.site, S.contractIdx =
        keep.bandits, keep.seats, keep.beds, keep.spots, keep.site, keep.idx
end

-- The camp's takings. A Stash builds its inventory lazily, so this is retried each tick until it
-- takes rather than assumed to work on the first one, and it verifies by reading the count back.
mercenaries.AlxChestTries = 600
mercenaries.AlxChestCoin  = { 60, 220 }

function mercenaries:AlxStockCampChest(C)
    if C.chestStocked or not C.chestId then return end
    C.chestTries = (C.chestTries or 0) + 1

    local done = false
    pcall(function()
        local e = System.GetEntity(C.chestId)
        if not (e and e.inventory) then return end
        local coin = math.random(self.AlxChestCoin[1], self.AlxChestCoin[2])
        e.inventory:CreateItem(self.BanditCampMoneyItem, 1, coin)
        if (e.inventory:GetCountOfClass(self.BanditCampMoneyItem) or 0) <= 0 then return end
        -- One flavour per chest, not the same craft-material grab-bag every beat
        -- (mercenaries.KleinkriegRewardPools, mercenaries_banditcamp_quest.lua).
        self:KleinkriegRollPool(e.inventory)
        done = true
    end)

    if done then
        C.chestStocked = true
    elseif C.chestTries >= self.AlxChestTries then
        C.chestStocked = true
        aLog("gave up stocking the camp chest after " .. tostring(C.chestTries) .. " tries")
    end
end

-- Towers and carts spawn their archers on their own deferred timer, so they cannot be counted at
-- build time. Adopt each the first tick it exists, or the camp would come down while two men
-- were still shooting off a watchtower.
function mercenaries:AlxAdoptStationArchers(C)
    C.adopted, C.station = C.adopted or {}, C.station or {}
    for i, st in ipairs(C.towers or {}) do
        local a = st and st.archer
        if a and not C.adopted["t" .. i] then
            C.adopted["t" .. i] = true
            C.station[a.id] = true
            table.insert(C.ids, a.id)
            local w = XGenAIModule.GetMyWUID(a)
            if w then
                self.BanditCampActors[tostring(w)] = true
                table.insert(C.wuids, tostring(w))
            end
            aLog("tower archer joined the camp")
        end
    end
    for i, st in ipairs(C.carts or {}) do
        local aboard = st and st.archers
        if aboard and #aboard > 0 and not C.adopted["c" .. i] then
            C.adopted["c" .. i] = true
            for _, a in ipairs(aboard) do
                if a.ent then
                    C.station[a.ent.id] = true
                    table.insert(C.ids, a.ent.id)
                    local w = XGenAIModule.GetMyWUID(a.ent)
                    if w then
                        self.BanditCampActors[tostring(w)] = true
                        table.insert(C.wuids, tostring(w))
                    end
                end
            end
            aLog(#aboard .. " cart archer(s) joined the camp")
        end
    end
end

-- Once every man on the GROUND is down, the tower archers stop being snipers and come after the
-- player: there is no way to walk one down a ladder (the deck has no navmesh and
-- static_archer_brain is "stand and shoot", which cannot be swapped at runtime), so each is
-- removed and an identical archer of the same group is put on the ground beneath his tower,
-- keeping his outfit. Mirrors BanditCampBringArchersDown.
function mercenaries:AlxBringArchersDown(C)
    if not (C.towers and #C.towers > 0) then return end
    C.station = C.station or {}

    local groundLeft, manned = 0, 0
    for _, id in ipairs(C.ids or {}) do
        local e = System.GetEntity(id)
        if e and self:IsAliveAndWell(e, false) then
            if C.station[id] then manned = manned + 1 else groundLeft = groundLeft + 1 end
        end
    end
    if groundLeft > 0 or manned == 0 then return end

    for _, st in ipairs(C.towers) do
        local a = st and st.archer
        if a and self:IsAliveAndWell(a, false) then
            local pos = st.placedGround or st.origin
            if pos then
                local oldId = a.id
                local ground = self:CampSnapToGround({ x = pos.x, y = pos.y, z = pos.z })
                -- His outfit has to be read BEFORE he is removed: RemoveStaticArcher clears the
                -- StaticArchers record the replacement is meant to match.
                local aws = tostring(a.this and a.this.id or a.id)
                local rec = self.StaticArchers and self.StaticArchers[aws]
                local outfit = rec and rec.outfit

                local w
                pcall(function() w = XGenAIModule.GetMyWUID(a) end)
                if w then self:ClearBanditCampActor(tostring(w)) end
                pcall(function() self:RemoveStaticArcher(a) end)
                st.archer = nil

                local ent = self:SpawnEnemyAt(C.group or "bandit", true, ground, st.yaw or 0)
                if ent then
                    self:BanditCampDressUp(ent, true, outfit)
                    for i, id in ipairs(C.ids) do
                        if id == oldId then C.ids[i] = ent.id; break end
                    end
                    C.station[oldId] = nil
                    C.station[ent.id] = true
                    if C.missing then C.missing[oldId] = nil end
                    aLog("a tower archer came down to fight")
                else
                    for i, id in ipairs(C.ids) do
                        if id == oldId then table.remove(C.ids, i); break end
                    end
                    C.station[oldId] = nil
                    aLog("tower archer removed but his replacement failed to spawn")
                end
            end
        end
    end
end

-- ---- standing a beat up, and taking it away ----

-- Whatever a previous session left standing at this site. Spawned props and men outlive the Lua
-- that tracked them, so a rebuild would stack a second camp on the first. ClearAnyLeftoverBandit-
-- Camp already does exactly this job; it is written against the BCQ tables, which are idle
-- whenever a beat is running.
function mercenaries:AlxSweepSite(site)
    local S = self.BCQ
    if S.active then return end
    local keepSite = S.site
    S.active, S.site = true, site
    pcall(function() self:ClearAnyLeftoverBanditCamp() end)
    S.active, S.site = false, keepSite
end

-- The one entry point from Skald. Called when beat N opens and again on every level wake while
-- N is still live, so it must be idempotent: a camp already standing for this beat is left alone.
function mercenaries:AlxSpawnBeat(n)
    n = tonumber(n)
    local beat = n and self.AlxBeats[n]
    if not beat then aLog("no such beat: " .. tostring(n)); return end

    if self.AlxCamp and self.AlxCamp.beat == n then
        aLog("beat " .. n .. "'s camp is already standing")
        return
    end
    -- The previous beat's camp is NOT pulled down to make room. It goes to the spent list and
    -- comes away on the same distance rule as always (AlxSpentTick) - otherwise clearing a camp
    -- and picking up the document, which is what opens the next beat, wiped the field you were
    -- still standing on.
    if self.AlxCamp then self:AlxRetireCamp() end

    if n == 6 then
        self.AlxBeat6Done, self.AlxBeat6Live = false, true
        self:AlxLodgingRemove()
    end
    if not beat.combat then
        self:AlxBeat6Start()
        return
    end
    if n == 1 then self:AlxLodgingSpawn() end

    local site = self:BanditCampSiteByName(beat.site)
    if not site then aLog("beat " .. n .. ": no site '" .. tostring(beat.site) .. "'"); return end
    -- Kleinkrieg has first claim on the ground. The quartermaster's repeatable bounty draws its
    -- camp from the same site table and may be standing on this one right now - and AlxSweepSite
    -- is about to delete everything near it, which would take the bounty's band and props with
    -- it and leave that contract counting kills against men who were never killed. So the bounty
    -- is told to move first (BountyYieldSite, mercenaries_bounty.lua).
    pcall(function() self:BountyYieldSite(site.name) end)
    self:AlxSweepSite(site)

    local count, archers, group = self:AlxScale(beat)
    local C = {
        beat = n, group = group, site = site,
        ids = {}, wuids = {}, meleeIds = {}, archerIds = {}, propIds = {},
        seats = {}, beds = {}, towers = {}, carts = {}, missing = {}, station = {}, adopted = {},
    }
    self.AlxCamp = C

    self:AlxSpawnCampProps(C, site)

    -- Raborsch keeps its authored siege on top of the camp; its officer is still the man whose
    -- death ends the beat.
    if beat.siege then pcall(function() self:SpawnRaborsch() end) end

    local origin = self:CampSnapToGround(self:BanditCampSiteAnchor(site))
    local leader = self:AlxSpawnLeaderNPC({ x = origin.x, y = origin.y + 3.2, z = origin.z },
                                          site.yaw or 0, beat)
    if leader then
        C.leaderId = leader.id
        table.insert(C.ids, leader.id)
        table.insert(C.meleeIds, leader.id)
        local w = XGenAIModule.GetMyWUID(leader)
        local ws = tostring(w or (leader.this and leader.this.id) or leader.id)
        table.insert(C.wuids, ws)
        local ws2 = leader.this and tostring(leader.this.id) or nil
        if ws2 and ws2 ~= ws then table.insert(C.wuids, ws2) end
    else
        aLog("beat " .. n .. ": THE LEADER FAILED TO SPAWN - nothing can end this beat")
    end

    local band = self:AlxSpawnBand(beat, math.max(0, count - 1), archers, group)
    if band then
        for _, id in ipairs(band.ids)       do table.insert(C.ids, id) end
        for _, id in ipairs(band.meleeIds)  do table.insert(C.meleeIds, id) end
        for _, id in ipairs(band.archerIds) do table.insert(C.archerIds, id) end
        for _, ws in ipairs(band.wuids)     do table.insert(C.wuids, ws) end
    end

    -- A road site has no seats or beds and still needs its roles: the column IS a role.
    if self:AlxOnTheRoad(site) or #(C.seats or {}) > 0 or #(C.beds or {}) > 0 then
        self:AlxAssignCampRoles(C, origin)
    end

    aLog(string.format("beat %d '%s': camp up at '%s' - %d standing, leader %s (%s)%s",
        n, beat.name, tostring(beat.site), #C.ids, tostring(beat.leaderName),
        tostring(beat.leaderSoul), beat.doc and (" carrying " .. beat.doc) or ""))
end

-- Hand the standing camp over to the spent list instead of removing it. Whatever opened the
-- next beat - a document picked up, a report heard - must not make the last one vanish underfoot.
mercenaries.AlxSpent = {}

function mercenaries:AlxRetireCamp()
    local C = self.AlxCamp
    if not C then return end
    self.AlxCamp = nil
    table.insert(self.AlxSpent, C)
    aLog("beat " .. tostring(C.beat) .. ": camp retired - it stands until the player is " ..
         tostring(self.AlxCampDespawnRange) .. "m off")
end

-- Spent camps come away one at a time, on the same rule a cleared one uses.
function mercenaries:AlxSpentTick()
    if #self.AlxSpent == 0 then return end
    local p = player and player:GetWorldPos()
    if not p then return end
    for i = #self.AlxSpent, 1, -1 do
        local C = self.AlxSpent[i]
        local a = C.site and self:BanditCampSiteAnchor(C.site)
        if a then
            local d = math.sqrt((a.x - p.x) ^ 2 + (a.y - p.y) ^ 2 + (a.z - p.z) ^ 2)
            if d >= self.AlxCampDespawnRange then
                table.remove(self.AlxSpent, i)
                aLog(string.format("beat %s: spent camp cleaned up (player %.0fm off)",
                     tostring(C.beat), d))
                self:AlxTearDown(C)
            end
        else
            table.remove(self.AlxSpent, i)
            self:AlxTearDown(C)
        end
    end
end

-- Take it all away: men, props, towers, carts. The bodies go too - by the time this runs the
-- fight is long over.
function mercenaries:AlxDespawnCamp(onLoad)
    local C = self.AlxCamp
    if not C then return end
    self.AlxCamp = nil
    self:AlxTearDown(C, onLoad)
end

-- onLoad: the world is being reloaded, not cleaned up. NOTHING here may report progress in that
-- case - see the document fallback below.
function mercenaries:AlxTearDown(C, onLoad)
    if not C then return end

    -- The document rides on the leader's body, and the body goes with the camp. Walk away without
    -- looting him and the beat would be uncompletable, so it is handed over instead. Same
    -- safety net BanditCampGrantLetterFallback is for the Kleinkrieg letter.
    --
    -- NEVER on a load. This camp is the one the PREVIOUS session was standing in, and the save
    -- being loaded may be from long before the leader fell - so granting the document and firing
    -- its token here closed the objective the player had just reloaded to replay, and on beats 7
    -- and 8 (where the doc token increments alx_beat) skipped the whole beat. The wake token
    -- rebuilds the camp with its leader and his document a moment later anyway.
    local doc = self.AlxDocToken[C.beat]
    if doc and C.leaderNoted and not C.docNoted and not onLoad then
        local beat = self.AlxBeats[C.beat] or {}
        C.docNoted = true
        self:AlxGiveItem(player.inventory, beat.doc, "the document")
        self:AlxSignalToken(doc)
        -- The same thought as the looted path: this IS the beat closing, it just closed with the
        -- document handed over rather than picked up.
        self:AlxThought(self.AlxThoughts[C.beat])
        aLog("beat " .. tostring(C.beat) .. ": " .. tostring(beat.doc) ..
             " was never looted - granted it rather than losing it with the body")
    end

    for _, id in ipairs(C.ids or {}) do
        pcall(function()
            local e = System.GetEntity(id)
            local w = e and XGenAIModule.GetMyWUID(e)
            if w then self:ClearBanditCampActor(tostring(w)) end
            System.RemoveEntity(id)
        end)
    end
    for _, ws in ipairs(C.wuids or {}) do
        pcall(function() self:ClearBanditCampActor(ws) end)
    end
    for _, st in ipairs(C.towers or {}) do
        pcall(function() self:TowerStationClearOne(st) end)
    end
    for _, st in ipairs(C.carts or {}) do
        pcall(function() self:ArcherCartClearOne(st) end)
    end
    for _, id in ipairs(C.propIds or {}) do
        pcall(function() System.RemoveEntity(id) end)
    end
    if C.beat == 8 then pcall(function() self:DespawnRaborsch() end) end
    aLog("beat " .. tostring(C.beat) .. ": camp taken down")
end

-- How many of the camp are still on their feet. A missing handle is not a death (the engine
-- drops one for a tick), so it is given AlxMissingTicks polls of the benefit of the doubt.
function mercenaries:AlxLivingCount(C)
    C.missing = C.missing or {}
    local n = 0
    for _, id in ipairs(C.ids or {}) do
        local e = System.GetEntity(id)
        if e then
            C.missing[id] = nil
            if self:IsAliveAndWell(e, false) then n = n + 1 end
        else
            local k = (C.missing[id] or 0) + 1
            C.missing[id] = k
            if k < self.AlxMissingTicks then n = n + 1 end
        end
    end
    return n
end

-- Dropped wholesale on load. Nothing about a camp is save data: the quest re-issues the spawn
-- token on the level's own OnWake if its beat is still live, and AlxSpawnBeat sweeps the site
-- before it rebuilds.
--
-- WHERE THE ARC IS IS SKALD'S, AND THE SAVE JUST LOADED IS THE ONLY AUTHORITY ON IT. Nothing in
-- here may signal a beat forward: every table this touches describes the session that saved,
-- which may be several beats ahead of the save being loaded.
function mercenaries:AlxOnLoad()
    self:AlxSweepStaleTokens()
    -- Session flags for beat 6, not save data. Left standing, a tick after loading an earlier
    -- save could read the beat as live and hand its documents in again.
    self.AlxBeat6Live, self.AlxBeat6Done = false, false
    for i = #self.AlxSpent, 1, -1 do
        local sp = self.AlxSpent[i]
        table.remove(self.AlxSpent, i)
        pcall(function() self:AlxTearDown(sp, true) end)
        if sp.site then pcall(function() self:AlxSweepSite(sp.site) end) end
    end
    local C = self.AlxCamp
    if C then
        -- TEAR IT DOWN, do not just forget it. Dropping the reference leaves the men and tents
        -- standing, the shared camp-role tables holding their wuids, and - for beat 8 - RBQ.active
        -- stuck true, which makes SpawnRaborsch refuse for the rest of the session ("already
        -- standing"), so the reissued token rebuilds a siege-less camp forever after.
        local site = C.site
        aLog("load: taking the previous session's camp down")
        self:AlxDespawnCamp(true)
        -- ...and again by name and radius, because every id in that table came from before the
        -- load and may resolve to nothing (or to something else entirely).
        if site then self:AlxSweepSite(site) end
    end
    self:AlxLodgingResetOnLoad()
end

-- The persistent Aleksej the player actually talks to for beats 1-5 (aleksej_dialog.xml is a
-- talk-to menu; it needs a standing NPC to open it on). Spawned at beat 1's start on his own
-- immortal soul. He goes away the instant beat 6 starts ("Aleksej absent" - that absence is the
-- reveal) and never comes back; the marsh Aleksej of beat 9 is a separate, MORTAL spawn on
-- soul_aleksej_double, stood up as an ordinary camp leader like every other beat.
--
-- "He is gone" is Skald's to remember, not this file's: the quest drops AlxLodgingGoneToken once
-- alx_beat has reached 6, and again on every level wake from then on, so a reload cannot walk him
-- back into a room whose emptiness is the point.

-- ==== LODGING ROUTINE ====
-- Sits on his stool all day, sleeps in his bed all night. Nothing else: no wandering, no work.
-- Driven by the camp furniture tables, which camp_actor consumes - so aleksej_scheduler.xml
-- carries a camp_actor arm for him (his brain reaches none of the four schedulers that normally
-- fire it).
mercenaries.AlxWakeHour  = 6
mercenaries.AlxSleepHour = 21

function mercenaries:AlxLodgingHere()
    local lvl
    pcall(function() lvl = System.GetCurrLevelName() end)
    if not lvl or lvl == "" then return true end          -- unknown level: do not block
    return tostring(lvl):lower():find(tostring(self.AlxLodgingLevel):lower(), 1, true) ~= nil
end

-- Spawn the two smart objects he uses. Kept out of AlxPieces: these belong to the world, not to
-- the editor's undo stack.
function mercenaries:AlxLodgingFurniture()
    local L = self.AlxLodging
    if not L or self.AlxFurnSO then return self.AlxFurnSO end
    local so = { ents = {} }
    if L.stool then
        -- (wuid, pos) - the WUID is the FIRST return. Taking the second put a position TABLE
        -- into a _wuid variable: "Var(campFurniture) Incorrect data type from lua. Expected
        -- Pointer, got: Table."
        so.chair = self:SpawnCampFurnitureSO(self.CampModels and self.CampModels.Stool, L.stool,
            L.stoolYaw or 0, "AlxStool", self.CampChairSO, nil, so.ents, true)
    end
    if L.bed then
        so.bed = self:SpawnCampFurnitureSO(self.CampModels and self.CampModels.Bed, L.bed,
            L.bedYaw or 0, "AlxBed", self.CampBedSO, nil, so.ents, true)
    end
    -- His chest stands in the room from the start. It is only STOCKED with the surcoats at
    -- beat 6 (AlxBeat6Start); before that it is just furniture.
    if L.chest then
        pcall(function()
            local yaw = L.chestYaw or 0
            local nm = "AlxLodgeChest_" .. tostring(math.random(100000, 999999))
            System.SpawnEntity({
                class = "Stash", name = nm, position = L.chest,
                orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
                properties = { object_Model = "Objects/characters/assets/chest/chest_rustic_a.cdf",
                               bSaved_by_game = false },
            })
            local e = System.GetEntityByName(nm)
            if e then
                pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw }) end)
                table.insert(so.ents, e.id)
                so.chestId = e.id
            end
        end)
    end
    self.AlxFurnSO = so
    return so
end

function mercenaries:AlxLodgingClearFurniture()
    local so = self.AlxFurnSO
    if not so then return end
    for _, id in ipairs(so.ents or {}) do pcall(function() System.RemoveEntity(id) end) end
    self.AlxFurnSO = nil
end

-- Called every logistics tick. Swaps his assigned furniture as the clock passes wake/sleep.
-- He is a fixture of Kuttenberg, not a one-shot spawn. Entities do not survive a level load and
-- the engine may drop him when the player streams far enough away, so his presence is re-checked
-- rather than assumed: if he should be standing there and is not, he is put back.
--
-- The one thing that keeps him away is beat 6, where his absence IS the story.
mercenaries.AlxKeepEvery = 5.0    -- seconds between presence checks; the check is two lookups

function mercenaries:AlxLodgingEnsure()
    if self.AlxLodgingGone then return end
    local L = self.AlxLodging
    if not (L and L.spawn) then return end
    if not self:AlxLodgingHere() then return end
    if self.AlxLodgingId and System.GetEntity(self.AlxLodgingId) then return end
    self.AlxLodgingId = nil
    self:AlxLodgingSpawn()
end

-- Every name this file leaves in his room. The sweep below matches on the prefix, exactly as
-- the camp's own leftover sweep does.
mercenaries.AlxLodgingNames = { "AleksejLodging_", "AlxStool", "AlxBed", "AlxLodgeChest_",
                                "AlxSurcoatChest_" }

-- What a LOAD invalidates. Two things here were why he simply never came back:
--
--   * AlxLodgingId. Entity ids are recycled, so a stale one very often still resolves to SOME
--     entity after a load - and AlxLodgingEnsure's whole test is "does this id resolve". It read
--     someone else's entity as "he is standing there" and never put him back.
--   * AlxKeepLast. It holds System.GetCurrTime, which RESTARTS on a load. A value cached from
--     later in the previous session left `now - AlxKeepLast` negative for the rest of the
--     session, so the presence check never ran again at all.
--
-- Everything in the room is swept by name and rebuilt by the tick rather than adopted: adopting
-- would mean re-deriving his WUID, his camp role and three smart-object handles from entities
-- that can no longer be proved to be ours.
function mercenaries:AlxLodgingResetOnLoad()
    self.AlxKeepLast, self.AlxLodgingDay = nil, nil
    if self.AlxLodgingWuid then
        self.BanditCampActors[self.AlxLodgingWuid] = nil
        self.CampFurniture[self.AlxLodgingWuid] = nil
        self.CampActivities[self.AlxLodgingWuid] = nil
    end
    self.AlxLodgingId, self.AlxLodgingWuid, self.AlxFurnSO = nil, nil, nil
    self.AlxBeat6ChestId = nil          -- swept below with the rest of the room

    local swept = 0
    for _, cls in ipairs({ "NPC", "Stash", "StanceSmartObject", "BasicEntity" }) do
        pcall(function()
            for _, e in pairs(System.GetEntitiesByClass(cls) or {}) do
                local n = e and e:GetName() or ""
                for _, pre in ipairs(self.AlxLodgingNames) do
                    if string.find(n, pre, 1, true) == 1 then
                        System.RemoveEntity(e.id)
                        swept = swept + 1
                        break
                    end
                end
            end
        end)
    end
    aLog("lodging: reset after load" ..
         (swept > 0 and (" (" .. swept .. " leftover(s) swept)") or "") ..
         " - the tick puts him back within " .. tostring(self.AlxKeepEvery) .. "s")
end

function mercenaries:AlxLodgingTick()
    -- Presence first: the routine below is meaningless if he is not there at all.
    local now = 0
    pcall(function() now = System.GetCurrTime() or 0 end)
    -- A load restarts this clock, so `now` can be BEHIND the cached mark. Treat that as due
    -- rather than waiting out the difference - which, from late in a long session, is forever.
    if now < (self.AlxKeepLast or 0) then self.AlxKeepLast = nil end
    if now - (self.AlxKeepLast or -999) >= self.AlxKeepEvery then
        self.AlxKeepLast = now
        pcall(function() self:AlxLodgingEnsure() end)
    end

    local ws = self.AlxLodgingWuid
    if not ws then return end
    local L, so = self.AlxLodging, self.AlxFurnSO
    if not (L and so) then return end
    local h
    local ok = pcall(function() h = Calendar.GetWorldHourOfDay() end)
    if not (ok and h) then return end
    local day = (h >= self.AlxWakeHour and h < self.AlxSleepHour)
    if day == self.AlxLodgingDay then return end
    self.AlxLodgingDay = day
    self.BanditCampActors[ws] = true
    if day and so.chair then
        self.CampFurniture[ws] = { wuid = so.chair, kind = "chair", pos = L.stool }
    elseif (not day) and so.bed then
        self.CampFurniture[ws] = { wuid = so.bed, kind = "bed", pos = L.bed }
    end
    aLog(day and "Aleksej: day, to the stool" or "Aleksej: night, to bed")
end

function mercenaries:AlxLodgingSpawn()
    if self.AlxLodgingId and System.GetEntity(self.AlxLodgingId) then
        aLog("lodging: already standing (id " .. tostring(self.AlxLodgingId) .. ")")
        return
    end
    if not self:AlxLodgingHere() then
        local lvl; pcall(function() lvl = System.GetCurrLevelName() end)
        aLog("lodging: wrong level - his room is on " .. tostring(self.AlxLodgingLevel) ..
             ", you are on " .. tostring(lvl))
        return
    end
    local L = self.AlxLodging
    local spawnPos = L and L.spawn
    if not spawnPos then
        aLog("beat 1: mercenaries.AlxLodging.spawn is not set - place the room with the F5-F11 " ..
             "editor and merc_alx_dump, then bake the printed position in here. Aleksej will not " ..
             "be standing anywhere yet, so his talk-to menu (aleksej_dialog.xml) has nobody to " ..
             "open it on until this is done.")
        return
    end
    local pos = spawnPos   -- baked from the editor: already the exact floor point, do not re-snap
    local yaw = L.spawnYaw or 0
    local soul = self.AlxSoul or self.AlxTestSoul
    local ent
    pcall(function()
        local name = "AleksejLodging_" .. tostring(math.random(10000, 99999))
        System.SpawnEntity({
            class = "NPC", name = name,
            position = pos, orientation = { x = 0, y = 0, z = yaw },
            properties = { guidSharedSoulId = soul },
        })
        ent = System.GetEntityByName(name)
    end)
    if not ent then
        aLog("lodging: SpawnEntity failed. soul=" .. tostring(soul) ..
             string.format("  pos=(%.2f, %.2f, %.2f)", pos.x or -1, pos.y or -1, pos.z or -1))
        return
    end
    self.AlxLodgingId = ent.id
    -- A standing activity, same idiom as AlxTalkTest - camp_actor's forced-dialogue arm and a
    -- plausible idle both want an IsCampActor entry to run in.
    local ws = tostring(XGenAIModule.GetMyWUID(ent) or (ent.this and ent.this.id) or ent.id)
    self.BanditCampActors[ws] = true
    -- NO standing activity. camp_actor runs an activity in preference to furniture, so an
    -- activity here is exactly why he stood at his spawn point instead of using the stool or the
    -- bed. AlxLodgingTick owns him now: CampFurniture, swapped on the clock.
    self.CampActivities[ws] = nil
    aLog(string.format("lodging: Aleksej up at (%.2f, %.2f, %.2f) - talk to him for aleksej_dialog",
        pos.x, pos.y, pos.z))
    -- Routine: stool by day, bed by night. AlxLodgingTick does the swapping.
    if ent then
        local w = XGenAIModule.GetMyWUID(ent) or (ent.this and ent.this.id) or ent.id
        self.AlxLodgingWuid = tostring(w)
        local so = self:AlxLodgingFurniture()
        aLog("lodging: furniture - stool=" .. tostring(so and so.chair ~= nil) ..
             " bed=" .. tostring(so and so.bed ~= nil) ..
             " chest=" .. tostring(so and so.chestId ~= nil) ..
             "   (models: Stool=" .. tostring(self.CampModels and self.CampModels.Stool ~= nil) ..
             " Bed=" .. tostring(self.CampModels and self.CampModels.Bed ~= nil) .. ")")
        self.AlxLodgingDay = nil
        self:AlxLodgingTick()
    end
end

function mercenaries:AlxLodgingRemove()
    if not self.AlxLodgingId then return end
    local id = self.AlxLodgingId
    self.AlxLodgingId = nil
    pcall(function()
        local e = System.GetEntity(id)
        if e then
            local ws = tostring(XGenAIModule.GetMyWUID(e) or (e.this and e.this.id) or e.id)
            self:ClearBanditCampActor(ws)
        end
        System.RemoveEntity(id)
    end)
    aLog("beat 6: Aleksej is gone from his lodging")
    -- He is gone for good from beat 6: that absence is the reveal, so the keeper below must not
    -- put him back.
    self.AlxLodgingGone = true
    self:AlxLodgingClearFurniture()
    if self.AlxLodgingWuid then
        self.BanditCampActors[self.AlxLodgingWuid] = nil
        self.CampFurniture[self.AlxLodgingWuid] = nil
        self.AlxLodgingWuid = nil
    end
end

-- No combat: a chest to stock, not a spawner. Kept independent of BanditCampChestInsert (that
-- one is BCQ-bound) - the pattern is the same three lines, CreateItem then verify.
-- Also the fallback when the chest itself never gets placed/spawned (below) - so it grants the
-- same coin and flavour roll the chest would have held, straight to the player, on top of the
-- two required documents.
function mercenaries:AlxGrantBeat6Items()
    -- The beat-6 token is reissued on every level wake while the beat is live, and on this path
    -- there is no chest standing to check, so the pack is the guard: without it a reload is free
    -- coin and a second copy of both documents.
    local has3, has4 = 0, 0
    pcall(function() has3 = player.inventory:GetCountOfClass(self.AlxDocs.doc3) or 0 end)
    pcall(function() has4 = player.inventory:GetCountOfClass(self.AlxDocs.doc4) or 0 end)
    if has3 > 0 and has4 > 0 then
        aLog("beat 6: both documents are already in the pack - granted nothing")
        return
    end
    self:AlxGiveItem(player.inventory, self.AlxDocs.doc3, "doc3")
    self:AlxGiveItem(player.inventory, self.AlxDocs.doc4, "doc4")
    self:GiveMoney(math.random(self.AlxChestCoin[1], self.AlxChestCoin[2]))
    self:KleinkriegRollPool(player.inventory)
end

function mercenaries:AlxBeat6Start()
    -- Idempotent, like every other spawn here: the beat-6 token is reissued on every level wake
    -- while the beat is live, and without this each one stood up another chest holding another
    -- two documents.
    if self.AlxBeat6ChestId and System.GetEntity(self.AlxBeat6ChestId) then
        aLog("beat 6: the chest is already standing")
        return
    end
    local L = self.AlxLodging
    local chestPos = L and L.chest
    if not chestPos then
        aLog("beat 6: mercenaries.AlxLodging.chest is not set - place the room with the F5-F11 " ..
             "editor and merc_alx_dump, then bake the printed position in here. Granting the " ..
             "beat's items to the player directly so the quest is not blocked meanwhile.")
        self:AlxGrantBeat6Items()
        return
    end

    local pos = chestPos   -- baked from the editor: already the exact floor point, do not re-snap
    local yaw = L.chestYaw or 0
    local e
    pcall(function()
        e = System.SpawnEntity({
            class = "Stash", name = "AlxSurcoatChest_" .. tostring(math.random(100000, 999999)),
            position = pos, orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
            properties = { object_Model = "Objects/characters/assets/chest/chest_rustic_a.cdf",
                           bSaved_by_game = false },
        })
    end)
    if not e then
        aLog("beat 6: chest failed to spawn - granting the items directly")
        self:AlxGrantBeat6Items()
        return
    end
    pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw }) end)

    local surcoat = self.AlxSurcoatItemClass
    if surcoat then
        pcall(function() e.inventory:CreateItem(surcoat, 1, 4) end)
    else
        aLog("TODO: mercenaries.AlxSurcoatItemClass not set - beat 6 chest has no surcoats yet")
    end
    self:AlxGiveItem(e.inventory, self.AlxDocs.doc3, "doc3")
    self:AlxGiveItem(e.inventory, self.AlxDocs.doc4, "doc4")
    -- Every other Kleinkrieg chest carries coin and a rolled flavour on top of what it must
    -- carry; this one only had the two documents (and the still-unauthored surcoat).
    pcall(function() e.inventory:CreateItem(self.BanditCampMoneyItem, 1, math.random(self.AlxChestCoin[1], self.AlxChestCoin[2])) end)
    self:KleinkriegRollPool(e.inventory)
    self.AlxBeat6ChestId = e.id
    aLog("beat 6: the chest is stocked (docs 3 and 4" .. (surcoat and " and the surcoats" or "") .. ")")
end

-- ---- the tick (driven off the wrapped BanditCampMonitor, see above) ----

function mercenaries:AlxTick()
    self:AlxSweepTokens()
    self:AlxSpentTick()
    -- Beat 6 has nothing in the world for Skald to watch die, so this is the one place Lua still
    -- reports progress: both documents out of the chest is that beat's hand-off.
    if self.AlxBeat6Live and not self.AlxBeat6Done then
        self:AlxLodgingThought()
        local has3, has4 = 0, 0
        pcall(function() has3 = player.inventory:GetCountOfClass(self.AlxDocs.doc3) or 0 end)
        pcall(function() has4 = player.inventory:GetCountOfClass(self.AlxDocs.doc4) or 0 end)
        if has3 > 0 and has4 > 0 then
            self.AlxBeat6Done, self.AlxBeat6Live = true, false
            self:AlxSignalToken(self.TokenIDAlxB6Done)
            aLog("beat 6: both documents in hand - told Skald")
        end
    end

    local C = self.AlxCamp
    if not C then return end

    -- THE ONE PIECE OF PROGRESS LUA STILL REPORTS: the leader is down. A missing body is not
    -- proof (the engine drops a handle for a tick), so it gets the same grace as everyone else.
    if C.leaderId and not C.leaderNoted then
        local down = false
        local le = System.GetEntity(C.leaderId)
        if le then
            C.leaderMissing = 0
            down = not self:IsAliveAndWell(le, true)
        else
            C.leaderMissing = (C.leaderMissing or 0) + 1
            down = C.leaderMissing >= self.AlxMissingTicks
        end
        if down then
            C.leaderNoted = true
            self:AlxSignalToken(self.AlxDownToken[C.beat])
            aLog("beat " .. tostring(C.beat) .. ": the leader is down - told Skald")
        end
    end

    -- ...and on a document beat, again when the document is actually in hand. Polled, because the
    -- player loots it off a body and Lua never sees that directly.
    local doc = self.AlxDocToken[C.beat]
    if C.leaderNoted and doc and not C.docNoted then
        local beat = self.AlxBeats[C.beat]
        local have = 0
        pcall(function() have = player.inventory:GetCountOfClass(beat.doc) or 0 end)
        if have > 0 then
            C.docNoted = true
            self:AlxSignalToken(doc)
            self:AlxThought(self.AlxThoughts[C.beat])
            aLog("beat " .. tostring(C.beat) .. ": " .. tostring(beat.doc) .. " is in the pack - told Skald")
        end
    end

    self:AlxStockCampChest(C)
    self:AlxAdoptStationArchers(C)
    -- Before the count: a replacement swapped in on the ground must already be on the roster, or
    -- this tick would see an empty slot and fold the camp up early.
    self:AlxBringArchersDown(C)

    -- The camp comes away when the last man in it is down AND the player has walked off. THE
    -- QUEST DOES NOT WAIT FOR EITHER - Skald closed the beat the moment the leader fell; this
    -- only decides when the tents go, and taking them down under the player's feet looked awful.
    if self:AlxLivingCount(C) == 0 then
        if not C.cleared then
            C.cleared = true
            aLog("beat " .. tostring(C.beat) .. ": every man down - the camp stands until the player is " ..
                 tostring(self.AlxCampDespawnRange) .. "m off")
        end
        local p = player and player:GetWorldPos()
        local a = C.site and self:BanditCampSiteAnchor(C.site)
        if p and a then
            local d = math.sqrt((a.x - p.x) ^ 2 + (a.y - p.y) ^ 2 + (a.z - p.z) ^ 2)
            if d >= self.AlxCampDespawnRange then
                aLog(string.format("beat %s: player %.0fm off - camp cleaned up", tostring(C.beat), d))
                self:AlxDespawnCamp()
            end
        end
    end
end

-- ---- console ----

function mercenaries:AlxStatus()
    aLog("followers counted for scaling: " .. tostring(self:BanditCampFollowerCount()))
    aLog("  (which beat is live is Skald's, not this file's - read the journal)")
    local C = self.AlxCamp
    if not C then aLog("  no camp standing"); return end
    local beat = self.AlxBeats[C.beat] or {}
    aLog(string.format("  beat %d '%s': %d tracked, %d still up, %d prop(s), %d tower(s)",
        C.beat, tostring(beat.name), #(C.ids or {}), self:AlxLivingCount(C),
        #(C.propIds or {}), #(C.towers or {})))
    local le = C.leaderId and System.GetEntity(C.leaderId)
    aLog(string.format("  leader %s (%s): %s", tostring(beat.leaderName), tostring(beat.leaderSoul),
        le and (self:IsAliveAndWell(le, true) and "alive" or "DOWN - the beat is over")
           or "not in world"))
    local site = C.site
    if site then
        local a = self:BanditCampSiteAnchor(site)
        local p = player and player:GetWorldPos()
        local d = p and math.sqrt((a.x - p.x) ^ 2 + (a.y - p.y) ^ 2 + (a.z - p.z) ^ 2)
        aLog(string.format("  site '%s' at %.1f, %.1f, %.1f - %s from player",
            tostring(site.name), a.x, a.y, a.z, d and string.format("%.0fm", d) or "?"))
    end
end

-- TESTING AID ONLY. A beat's site can be 4+ km from the lodging; this drops the player on it.
function mercenaries:AlxGoto()
    local C = self.AlxCamp
    local site = C and C.site
    if not site then aLog("merc_alx_goto: no camp standing"); return end
    local pos = self:CampSnapToGround(self:BanditCampSiteAnchor(site))
    local ok = pcall(function() player:SetPos(pos) end)
    aLog(string.format("merc_alx_goto: %.1f, %.1f, %.1f (%s)", pos.x, pos.y, pos.z,
        ok and "moved" or "SetPos failed"))
end

-- NOT merc_alx_spawn / merc_alx_clear: those are already the lodging editor's F5 and F10
-- (AlxPick(1) / AlxClear), bound by AlxBinds on every load. Registering the same names twice
-- silently broke one feature or the other depending on which registration won.
mercenaries:DevCommand("merc_alx_beat",   "mercenaries:AlxSpawnBeat('%line')", "TEST: stand beat N's camp up (Skald normally asks)")
mercenaries:DevCommand("merc_alx_beat_clear", "mercenaries:AlxDespawnCamp()",  "TEST: take the standing camp down")
mercenaries:DevCommand("merc_alx_status", "mercenaries:AlxStatus()",           "What Aleksej's camp is doing")
mercenaries:DevCommand("merc_alx_goto",   "mercenaries:AlxGoto()",             "TEST: teleport to the standing camp")
-- Baked one per line: AddCCommand does not substitute %1 (reference_ccommand_arg_substitution).
mercenaries:DevCommand("merc_alx_msg_lodging",
                   "mercenaries:AlxThought(mercenaries.AlxLodgingMsgKey)",
                   "TEST: Henry's thought on the emptied lodging")
mercenaries:DevCommand("merc_alx_msg_raborsch",
                   "mercenaries:AlxThought(mercenaries.AlxThoughts[7])",
                   "TEST: Henry's thought on the siege of Raborsch")
mercenaries:DevCommand("merc_alx_msg_reset",
                   "mercenaries:AlxLodgingMsgReset()",
                   "TEST: let the lodging thought play again")
