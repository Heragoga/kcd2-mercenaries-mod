-- The quartermaster's bandit-camp contract.
--
-- The Skald side (data/Quests/mercenaries/kutnohorsko/bandit_camp_quest.xml) only owns the
-- journal entry and the map marker. Everything real happens here: the camp is built from a
-- layout table, populated with a scaled enemy band, watched until the last one drops, paid
-- out, and torn down once the player is out of sight of it.
--
-- Three tokens carry the conversation with Skald, all defined in item__mercenaries.xml:
--   be81d  dialog -> Lua   "I'll take the job"
--   be83d  Lua -> Skald    "the camp is standing"  (opens the journal entry)
--   be82d  Lua -> Skald    "the camp is cleared"   (closes it)
--
-- See docs/bandit-camp-quest.md.

local function qLog(s) System.LogAlways("[BanditCampQuest] " .. s) end

-- Same ladder as mercenaries_ambush.lua: there is no single reliable level-name binding,
-- and `Level.GetName` (the obvious guess) does not exist - it returns nothing.
local function levelName()
    for _, get in ipairs({
        function() return System.GetCurrLevelName() end,
        function() return Game.GetLevelName() end,
        function() return System.GetCurrAsyncLevelName() end,
    }) do
        local ok, v = pcall(get)
        if ok and v and v ~= "" then return tostring(v) end
    end
    return "unknown"
end

mercenaries.TokenIDBanditCamp        = "679a655e-189d-4519-b437-ccc4b92be81d"
mercenaries.TokenIDBanditCampCleared = "679a655e-189d-4519-b437-ccc4b92be82d"
mercenaries.TokenIDBanditCampUp      = "679a655e-189d-4519-b437-ccc4b92be83d"
-- The letter itself is a real readable Document, not a token: the player loots it, can read
-- it, and hands it back. be85d is the dialog asking to hand it over; be86d closes the quest.
mercenaries.TokenIDBanditCampLetter  = "679a655e-189d-4519-b437-ccc4b92be84d"
mercenaries.TokenIDBanditCampHandIn  = "679a655e-189d-4519-b437-ccc4b92be85d"
mercenaries.TokenIDBanditCampPaid    = "679a655e-189d-4519-b437-ccc4b92be86d"

mercenaries.TokenIDBanditCampTaken   = "679a655e-189d-4519-b437-ccc4b92be87d"

-- The Kleinkrieg letters, one Document per story beat (item__mercenaries.xml). Letter 6 is
-- Raborsch's and waits for that contract. None carry IsQuestItem - see the letter gotcha.
mercenaries.TokenIDKKLetter1 = "679a655e-189d-4519-b437-ccc4b92be88d"
mercenaries.TokenIDKKLetter2 = "679a655e-189d-4519-b437-ccc4b92be89d"
mercenaries.TokenIDKKLetter3 = "679a655e-189d-4519-b437-ccc4b92be8ad"
mercenaries.TokenIDKKLetter4 = "679a655e-189d-4519-b437-ccc4b92be8bd"
mercenaries.TokenIDKKLetter5 = "679a655e-189d-4519-b437-ccc4b92be8cd"
mercenaries.TokenIDKKLetter7 = "679a655e-189d-4519-b437-ccc4b92be8dd"

-- Closes the journal entry, and only when the LAST contract is paid: the quest stays open
-- across the whole arc, so this is the one thing that ends it.
mercenaries.TokenIDKKArcDone = "679a655e-189d-4519-b437-ccc4b92be8ed"

-- Phase markers. Dropping token N latches a bool in the background quest that the
-- quartermaster's dialog gates on, so he offers contract N's own lines instead of one
-- generic "any work?" every time. Latched and saved on the Skald side, so the token is
-- swept straight back out of the pack (BanditCampSweepTokens).
mercenaries.TokenIDKKPhase = {
    "679a655e-189d-4519-b437-ccc4b92be90d", "679a655e-189d-4519-b437-ccc4b92be91d",
    "679a655e-189d-4519-b437-ccc4b92be92d", "679a655e-189d-4519-b437-ccc4b92be93d",
    "679a655e-189d-4519-b437-ccc4b92be94d", "679a655e-189d-4519-b437-ccc4b92be95d",
    "679a655e-189d-4519-b437-ccc4b92be96d", "679a655e-189d-4519-b437-ccc4b92be97d",
    "679a655e-189d-4519-b437-ccc4b92be98d", "679a655e-189d-4519-b437-ccc4b92be99d",
    "679a655e-189d-4519-b437-ccc4b92be9ad", "679a655e-189d-4519-b437-ccc4b92be9bd",
    "679a655e-189d-4519-b437-ccc4b92bea3d",   -- 13th: Raborsch
}
-- "the looter column was dispersed, not killed" - picks his alternate report line.
mercenaries.TokenIDKKPhaseAlt = "679a655e-189d-4519-b437-ccc4b92be9cd"

-- Which way the quest goes after the last kill. A contract that carries a letter raises the
-- "search his body" objective; one that does not sends the player straight home. Splitting
-- these is what stops a letterless contract flashing an objective that completes itself in
-- the same instant it appears.
mercenaries.TokenIDKKSearch = "679a655e-189d-4519-b437-ccc4b92be9dd"
mercenaries.TokenIDKKReport = "679a655e-189d-4519-b437-ccc4b92be9ed"

-- The two gates the quartermaster's dialog reads: is a contract running, and is it ready to
-- hand in. Each has its own set and clear token so LUA owns them outright.
--
-- They used to piggyback on the flow tokens (accept / letter-taken / paid), which broke the
-- hand-in option: a contract with no letter never creates the letter-taken token at all, so
-- "ready" was never set and the report line could not be selected - the job could be finished
-- but never turned in. Riding on tokens whose lifetime belongs to something else also left
-- the gates stale across a reload.
mercenaries.TokenIDKKOpen    = "679a655e-189d-4519-b437-ccc4b92be9fd"
mercenaries.TokenIDKKShut    = "679a655e-189d-4519-b437-ccc4b92bea0d"
mercenaries.TokenIDKKReady   = "679a655e-189d-4519-b437-ccc4b92bea1d"
mercenaries.TokenIDKKUnready = "679a655e-189d-4519-b437-ccc4b92bea2d"

-- Push the gates whenever they change. _kkOpen/_kkReady start nil, so the first tick after a
-- load always re-asserts both and the dialog cannot come back out of step with the contract.
function mercenaries:KleinkriegSyncGates()
    -- The ARC's slot by name. This runs outside the monitor's per-slot bind (and again
    -- straight out of the hand-in dialog), so the pointer is not to be trusted here.
    local S = self.BCQ_KK
    local open  = (S.active == true and S.paid ~= true)
    local ready = (S.active == true and S.cleared == true and S.paid ~= true
                   and self:BanditCampHasLetter() == true)
    if self._kkOpen ~= open then
        self:BanditCampSignal(open and self.TokenIDKKOpen or self.TokenIDKKShut)
        self._kkOpen = open
    end
    if self._kkReady ~= ready then
        self:BanditCampSignal(ready and self.TokenIDKKReady or self.TokenIDKKUnready)
        self._kkReady = ready
        qLog("hand-in " .. (ready and "available" or "not available"))
    end
end

-- Latch every phase up to the contract the run has reached. Cheap and idempotent: the Skald
-- states only ever go true, so re-latching after a reload costs nothing, and catching up
-- from 1 means a save made before this existed still lands on the right lines.
function mercenaries:KleinkriegSyncPhase()
    local want = self:BanditCampCleared() + 1
    if want > #self.TokenIDKKPhase then want = #self.TokenIDKKPhase end
    if self._kkPhaseDone == nil then
        local v
        pcall(function() v = self:LoadString("KKPhase") end)
        self._kkPhaseDone = tonumber(v) or 0
    end
    if self._kkPhaseDone >= want then return end
    for i = self._kkPhaseDone + 1, want do
        self:BanditCampSignal(self.TokenIDKKPhase[i])
    end
    self._kkPhaseDone = want
    pcall(function() self:SaveString("KKPhase", tostring(want)) end)
    qLog("quartermaster now speaks for contract " .. want)
end

-- (The chest's InventoryPreset is gone: it carried the letter, which now rides on the leader.
--  InventoryPreset__mercenaries.xml still defines it, unused, so nothing else breaks.)

-- Vanilla money (item__system.xml), divisible and worth 1 groschen a unit, so the amount is
-- just the count. The camp's takings sit in the chest with the letter.
mercenaries.BanditCampMoneyItem  = "5ef63059-322e-4e1b-abe8-926e100c770e"
mercenaries.BanditCampChestShare = 0.75   -- of the contract fee again, as loose coin

-- The band's stolen stock. Smithing materials mostly, because a camp with a borrowed anvil in
-- it should have something to feed it, plus a couple of tools. Each row is rolled
-- independently: { class, minimum, maximum, chance }. All vanilla classes (item.xml).
mercenaries.BanditCampChestLoot = {
    { "3c1c0ae2-731e-40c1-a917-024fb3f000da", 2, 5, 0.9 },   -- bsmt_steelNormal
    { "4a4da84c-f12a-4bc8-94dc-a7d8d76788ea", 1, 3, 0.5 },   -- bsmt_steelGood
    { "54f297f8-62c0-41b5-9ab4-892c7475fc6a", 2, 6, 0.8 },   -- bsmt_steelBad
    { "4a6269c1-5c01-473d-ad69-e0a0c41643e7", 1, 4, 0.7 },   -- bsmt_hardware
    { "1c933935-d4b3-4884-8228-a4cde0c3a96d", 1, 2, 0.35 },  -- bsmt_guardStrong
    { "1fe0e850-e07d-45f0-ade0-26f030a63da4", 1, 2, 0.35 },  -- bsmt_pommelCoin
    { "55be7c8b-7ef1-4e45-820d-d04a2497f016", 2, 5, 0.8 },   -- special_charcoalImproved
    { "0502824d-a654-4471-9978-c1624860dde1", 1, 1, 0.3 },   -- blacksmith_hammer
    { "43fd458b-8e49-4ad1-8e9a-1d7e44f2ab41", 1, 2, 0.5 },   -- whetstone
    { "009a655e-189d-4519-b437-ccc4b92be48d", 1, 2, 0.4 },   -- loot_sackOfNails
}

-- One flavour rolled per Kleinkrieg chest (KK contract chest, every Aleksej beat's camp chest,
-- and the beat-6 lodging chest), on TOP of the coin and whatever the quest itself requires -
-- those two are never part of this table and are granted unconditionally at each call site.
-- Same row shape as BanditCampChestLoot: { class, minimum, maximum, chance }, rolled
-- independently once a pool is picked. craft reuses BanditCampChestLoot itself rather than
-- duplicating its rows. Extend any pool here without touching a single stocking function.
--
-- healing and gear are vanilla GUIDs (item.xml / item__alchemy.xml) never exercised by this
-- mod's own CreateItem before - verified by grepping references/Libs/Tables/item/ directly for
-- each Id= (no IsQuestItem on any of them), but smoke-test with merc_banditcamp_chest_probe or
-- the AlxGiveItem read-back once before shipping. Gear reuses four of AlxKnightHarness's own
-- pieces (mercenaries_aleksej.lua) - those ARE proven to CreateItem in this mod already - plus
-- two vanilla arm pieces found the same way as the healing rows.
mercenaries.KleinkriegRewardPools = {
    craft = mercenaries.BanditCampChestLoot,
    healing = {
        { "9fa3000e-3807-48a8-bed8-81427f0bda55", 1, 3, 0.6 },   -- bandage_classic
        { "b38c34b7-6016-4f64-9ba2-65e1ce31d4a1", 1, 2, 0.5 },   -- potion_marigold
        { "761f9e84-e07b-4b4b-9425-7681898abccd", 1, 2, 0.35 },  -- potion_marigold_medium
        { "b4e0af8c-3ed7-40ed-8537-7772489832c8", 1, 1, 0.2 },   -- potion_marigold_high
        { "928463d9-e21a-4f7c-b5d3-8378ed375cd1", 1, 2, 0.3 },   -- potion_saviourSchnapps
        { "3d4a8904-98f1-464a-9b3e-d3926b835804", 1, 1, 0.15 },  -- potion_saviourSchnapps_high
    },
    gear = {
        { "1b4b6487-72cc-409e-9296-692b53e0429e", 1, 1, 0.5 },   -- arming cap, CoifCap01_m01_C
        { "09ae6cbc-77d1-4686-801e-871b49440d7d", 1, 1, 0.35 },  -- gauntlets, Gauntlets05_m01_A5
        { "078e439b-1a5b-40ca-b009-d4abf6fcf810", 1, 1, 0.4 },   -- padded hose, LegsPadded01_m07_C3
        { "569438e6-7cae-483b-a4db-d1d25aa783d0", 1, 1, 0.4 },   -- boots, BootsKnee01_m01_C
        { "a3c3146a-84a7-4c98-a7a9-eb27d547e547", 1, 1, 0.3 },   -- ArmPlate01_m03_C2
        { "a42c2f51-88e5-45ce-b672-aa4e4e42a4ee", 1, 1, 0.12 },  -- BrigandineArm03_m05_C2, rare
    },
}
mercenaries.KleinkriegRewardPoolNames = { "craft", "healing", "gear" }

-- Pick one flavour and roll its rows into an inventory (player, NPC, or Stash - all take the
-- same CreateItem call). Same "attempt every row, no per-row verify" idiom as the craft loop
-- this replaces; the coin already stocked is what's verified, per chest.
function mercenaries:KleinkriegRollPool(inv)
    if not inv then return 0 end
    local names = self.KleinkriegRewardPoolNames
    local pool = self.KleinkriegRewardPools[names[math.random(#names)]]
    local rolled = 0
    for _, L in ipairs(pool or {}) do
        if math.random() < (L[4] or 1) then
            pcall(function() inv:CreateItem(L[1], 1, math.random(L[2] or 1, L[3] or 1)) end)
            rolled = rolled + 1
        end
    end
    return rolled
end

mercenaries.BanditCampLeaderSoul = "7a1c9e40-5d2b-4f83-9c16-8e5a3b7d0f21"

-- Props are despawned when the player is this far from the camp centre, and the whole
-- camp is unloaded (survivors remembered) once they wander this far off mid-contract.
mercenaries.BanditCampDespawnRange = 50
mercenaries.BanditCampForgetRange  = 300

-- How many consecutive 1 Hz polls a bandit must be un-findable before he counts as dead.
-- The engine can drop an entity handle for a tick without the NPC being gone.
mercenaries.BanditCampMissingTicks = 5

-- WUIDs of everyone in the bandit camp. The camp-role accessors in mercenaries_camp.lua
-- consult this so a bandit can hold a camp role without the PLAYER's camp being up.
mercenaries.BanditCampActors = {}

-- ==== layouts ====
-- Paste `merc_bcamp_dump` output here. Coordinates are RELATIVE to the first piece placed,
-- so one layout can be dropped at any site. `yaw` is radians.
mercenaries.BanditCampLayouts = {}

-- Five tents in a horseshoe round a fire, a bed in each, logs to sit on, and the spoils
-- piled up west of it. Authored in-game with merc_bcamp_dump; the origin is the first tent.
-- The 5 beds and 4 logs are what the sleep/sit roles claim, so this camp seats about nine
-- convincingly - past that the extras eat, gather herbs and walk the perimeter instead.
mercenaries.BanditCampLayouts.default = {
    { kind = "prop", what = "tent 1", x = 0.00, y = 0.00, z = 0.00, yaw = -4.4630 },
    { kind = "prop", what = "tent 2", x = 0.69, y = 2.67, z = 0.00, yaw = 1.0305 },
    { kind = "prop", what = "tent 4", x = 3.02, y = 4.49, z = 0.00, yaw = 0.1642 },
    { kind = "prop", what = "tent 1", x = 5.60, y = 3.85, z = 0.00, yaw = -0.5943 },
    { kind = "prop", what = "tent 4", x = 6.59, y = 1.33, z = 0.00, yaw = -1.4346 },
    { kind = "prop", what = "bed", x = 6.68, y = 1.26, z = 0.00, yaw = 0.1086 },
    { kind = "prop", what = "bed", x = 5.73, y = 4.14, z = 0.00, yaw = 0.9895 },
    { kind = "prop", what = "bed", x = 3.12, y = 4.48, z = 0.00, yaw = 1.7097 },
    { kind = "prop", what = "bed", x = 0.66, y = 3.06, z = 0.00, yaw = 2.5132 },
    { kind = "prop", what = "bed", x = 0.03, y = -0.10, z = 0.00, yaw = -2.8646 },
    { kind = "prop", what = "campfire (light)", x = 3.43, y = 1.31, z = 0.00, yaw = 2.0194 },
    { kind = "prop", what = "log seat", x = 2.17, y = 0.38, z = 0.00, yaw = 2.6165 },
    { kind = "prop", what = "log seat", x = 2.14, y = 1.91, z = 0.00, yaw = 2.2607 },
    { kind = "prop", what = "log seat", x = 3.71, y = 2.74, z = 0.00, yaw = 1.7880 },
    { kind = "prop", what = "log seat", x = 5.14, y = 1.32, z = 0.00, yaw = 1.3160 },
    { kind = "prop", what = "big chest (lootable)", x = 0.84, y = -2.24, z = 0.00, yaw = 1.8664 },
    { kind = "prop", what = "beer barrel", x = 1.01, y = -3.29, z = 0.00, yaw = -2.8211 },
    { kind = "prop", what = "arrow barrel", x = -0.12, y = -2.11, z = 0.00, yaw = 2.8917 },
    { kind = "prop", what = "crate_low_b", x = 0.02, y = -2.85, z = 0.00, yaw = -2.8782 },
    { kind = "prop", what = "sack_b", x = -0.03, y = -3.12, z = 0.00, yaw = -2.7418 },
    { kind = "prop", what = "sack_pig_feed", x = -0.17, y = -2.69, z = 0.00, yaw = -2.9894 },
    { kind = "prop", what = "sack_charcoal", x = 0.20, y = -3.72, z = 0.00, yaw = -2.4091 },

    -- Watchtowers. Their archers are dressed as the camp's own group and run in "hostile"
    -- mode, so they shoot the player and the mercs. Each one joins the kill count as soon as
    -- it spawns (the archer arrives on a delay), so the contract is not payable while a
    -- tower is still manned. They do consume the player's tower allowance - see
    -- TowerMaxCount in docs/bandit-camp-quest.md.
    { kind = "tower", what = "archer tower (spawns an archer)", x = 1.58, y = -11.35, z = 0.00, yaw = -1.5172 },
    { kind = "tower", what = "archer tower (spawns an archer)", x = 11.10, y = -4.08, z = 0.01, yaw = -0.3342 },

    -- The drinking spot. Built by SpawnBanditCampTavern from the same InnStationLayout the
    -- player's inn upgrade uses, but into the camp's own entity and seat lists - its eight
    -- stools are claimable, so bandits actually sit and drink at it.
    { kind = "upgrade", what = "makeshift inn", x = 5.00, y = -1.51, z = 0.00, yaw = -2.6231 },
}

-- A bigger, two-hearth camp: a tent ring round one fire, and a second cluster downhill with
-- the player tent, the spoils and a mess table. 11 beds, 6 logs and 6 chairs, so it seats a
-- full 20-man band without anyone queueing for furniture.
mercenaries.BanditCampLayouts.hillside = {
    { kind = "prop", what = "tent 1", x = 0.00, y = 0.00, z = 0.00, yaw = -2.1701 },
    { kind = "prop", what = "tent 3", x = 0.04, y = 3.51, z = 0.25, yaw = -1.2029 },
    { kind = "prop", what = "tent 4", x = -2.10, y = 5.21, z = 0.27, yaw = -0.2729 },
    { kind = "prop", what = "tent 1", x = -5.02, y = 4.86, z = 0.25, yaw = 0.7074 },
    { kind = "prop", what = "tent 3", x = -8.08, y = 3.16, z = -0.41, yaw = 0.2112 },
    { kind = "prop", what = "player tent", x = -15.52, y = -5.78, z = -2.09, yaw = 0.1845 },
    { kind = "prop", what = "tent 4", x = -18.17, y = -3.42, z = -1.95, yaw = -3.9952 },
    { kind = "prop", what = "tent 5", x = -19.25, y = -0.47, z = -1.65, yaw = 1.2689 },
    { kind = "prop", what = "tent 1", x = -17.18, y = 1.52, z = -1.20, yaw = 0.3864 },
    { kind = "prop", what = "tent 4", x = -14.66, y = 1.25, z = -1.06, yaw = -0.4432 },
    { kind = "prop", what = "bed", x = -14.51, y = -5.23, z = -1.96, yaw = 0.4560 },
    { kind = "prop", what = "bed", x = -16.51, y = -6.51, z = -2.21, yaw = -2.4130 },
    { kind = "prop", what = "bed", x = -18.31, y = -3.47, z = -1.96, yaw = -2.2964 },
    { kind = "prop", what = "bed", x = -19.59, y = -0.17, z = -1.64, yaw = -3.1212 },
    { kind = "prop", what = "bed", x = -17.12, y = 1.76, z = -1.15, yaw = 2.0264 },
    { kind = "prop", what = "bed", x = -14.64, y = 1.38, z = -1.04, yaw = 1.1073 },
    { kind = "prop", what = "bed", x = -7.92, y = 3.91, z = -0.30, yaw = 1.9858 },
    { kind = "prop", what = "bed", x = -5.24, y = 4.93, z = 0.25, yaw = 2.2238 },
    { kind = "prop", what = "bed", x = -2.08, y = 5.52, z = 0.31, yaw = 1.3681 },
    { kind = "prop", what = "bed", x = 0.69, y = 3.29, z = 0.27, yaw = 0.4665 },
    { kind = "prop", what = "bed", x = 0.23, y = -0.06, z = 0.00, yaw = -0.5720 },
    { kind = "prop", what = "big chest (lootable)", x = -14.90, y = -6.85, z = -2.12, yaw = -2.7507 },
    { kind = "prop", what = "small chest", x = -13.96, y = -6.41, z = -2.03, yaw = -1.8383 },
    { kind = "prop", what = "table small", x = -16.73, y = -5.10, z = -2.09, yaw = 3.0103 },
    { kind = "prop", what = "chair", x = -17.04, y = -5.71, z = -2.17, yaw = 2.8475 },
    { kind = "prop", what = "chair", x = -15.83, y = -5.03, z = -2.04, yaw = 3.0736 },
    { kind = "prop", what = "campfire (light)", x = -3.39, y = 1.82, z = 0.10, yaw = 1.2142 },
    { kind = "prop", what = "log seat", x = -5.02, y = 1.76, z = 0.16, yaw = 2.1205 },
    { kind = "prop", what = "log seat", x = -4.28, y = 3.12, z = 0.18, yaw = 1.6592 },
    { kind = "prop", what = "log seat", x = -2.39, y = 3.56, z = 0.10, yaw = 1.1286 },
    { kind = "prop", what = "log seat", x = -1.31, y = 2.08, z = -0.00, yaw = 0.6244 },
    { kind = "prop", what = "log seat", x = -2.54, y = 0.17, z = 0.07, yaw = 0.0282 },
    { kind = "prop", what = "log seat", x = -4.27, y = -0.06, z = 0.11, yaw = 0.7300 },
    { kind = "prop", what = "campfire (light)", x = -16.28, y = -0.89, z = -1.47, yaw = 3.0237 },
    { kind = "prop", what = "table big", x = -14.02, y = -1.35, z = -1.42, yaw = 2.1231 },
    { kind = "prop", what = "chair", x = -14.59, y = -2.10, z = -1.56, yaw = 2.2847 },
    { kind = "prop", what = "chair", x = -15.03, y = -1.59, z = -1.50, yaw = 1.2051 },
    { kind = "prop", what = "chair", x = -12.71, y = -1.09, z = -1.31, yaw = 2.0719 },
    { kind = "prop", what = "chair", x = -13.28, y = -0.19, z = -1.21, yaw = -3.1030 },
    { kind = "upgrade", what = "food cart", x = -7.00, y = -3.40, z = -0.38, yaw = -1.0608 },
    { kind = "prop", what = "sack_pig_feed", x = -6.81, y = -1.21, z = -0.11, yaw = -1.0965 },
    { kind = "prop", what = "crate_low_b", x = -4.96, y = -2.03, z = -0.08, yaw = -2.6343 },
    { kind = "prop", what = "sack_pig_feed", x = -4.89, y = -2.27, z = -0.11, yaw = -2.4082 },
    { kind = "prop", what = "sack_charcoal", x = -5.12, y = -1.80, z = -0.04, yaw = -2.9040 },
    { kind = "prop", what = "sack_charcoal", x = -3.51, y = 5.52, z = 0.25, yaw = 1.4929 },
    { kind = "prop", what = "weapon pile", x = -14.03, y = -3.38, z = -1.72, yaw = -0.6500 },
    { kind = "prop", what = "weapon pile", x = -13.12, y = -4.42, z = -1.74, yaw = -0.6693 },
    { kind = "upgrade", what = "hunter's spot", x = -17.81, y = -11.01, z = -2.40, yaw = -3.1324 },
}

-- A hillfort camp on broken ground: two tent clusters up the slope, a mess table and stores
-- below, torches strung along the approach, and THREE watchtowers covering it. The biggest of
-- the three - bring the company.
mercenaries.BanditCampLayouts.hillfort = {
    { kind = "prop", what = "tent 2", x = -8.49, y = 9.15, z = 3.55, yaw = -1.6325 },
    { kind = "prop", what = "tent 3", x = -9.83, y = 6.44, z = 3.74, yaw = -2.4127 },
    { kind = "prop", what = "tent 4", x = -10.52, y = 11.05, z = 4.22, yaw = -0.3477 },
    { kind = "prop", what = "bed", x = -10.55, y = 11.31, z = 4.24, yaw = 1.2100 },
    { kind = "prop", what = "bed", x = -8.12, y = 8.84, z = 3.42, yaw = -0.1428 },
    { kind = "prop", what = "bed", x = -9.78, y = 5.72, z = 3.65, yaw = -1.1131 },
    { kind = "prop", what = "campfire (light)", x = -10.65, y = 8.87, z = 4.11, yaw = -0.5325 },
    { kind = "prop", what = "stool", x = -11.19, y = 10.08, z = 4.33, yaw = 0.2030 },
    { kind = "prop", what = "stool", x = -9.72, y = 9.62, z = 3.90, yaw = -0.0871 },
    { kind = "prop", what = "stool", x = -10.46, y = 7.21, z = 3.95, yaw = -0.9597 },
    { kind = "prop", what = "tent 5", x = -8.96, y = 16.32, z = 4.47, yaw = -0.8082 },
    { kind = "prop", what = "tent 4", x = -12.08, y = 15.90, z = 5.00, yaw = 0.6850 },
    { kind = "prop", what = "tent 4", x = -8.68, y = 13.08, z = 4.02, yaw = -2.1016 },
    { kind = "prop", what = "straw bed", x = -8.25, y = 12.89, z = 3.93, yaw = -0.5112 },
    { kind = "prop", what = "straw bed", x = -9.33, y = 16.79, z = 4.57, yaw = 2.3474 },
    { kind = "prop", what = "straw bed", x = -12.13, y = 15.86, z = 5.01, yaw = 2.3640 },
    { kind = "prop", what = "big chest (lootable)", x = -8.31, y = 15.89, z = 4.35, yaw = -0.9363 },
    { kind = "prop", what = "campfire (light)", x = -10.31, y = 14.11, z = 4.44, yaw = 0.9023 },
    { kind = "prop", what = "torch / lamp (light)", x = -5.76, y = -2.35, z = -0.43, yaw = 2.8685 },
    { kind = "prop", what = "torch / lamp (light)", x = -5.49, y = 1.90, z = 1.13, yaw = 2.0352 },
    { kind = "prop", what = "torch / lamp (light)", x = 1.03, y = -0.36, z = 0.19, yaw = 0.2906 },
    { kind = "prop", what = "torch / lamp (light)", x = 1.87, y = -1.51, z = 0.40, yaw = 0.9379 },
    { kind = "prop", what = "torch / lamp (light)", x = 3.32, y = -4.35, z = -0.09, yaw = 0.0944 },
    { kind = "prop", what = "torch / lamp (light)", x = -7.72, y = 10.99, z = 4.89, yaw = -1.1241 },
    { kind = "prop", what = "torch / lamp (light)", x = -6.66, y = 18.79, z = 6.13, yaw = 1.7682 },
    { kind = "prop", what = "torch / lamp (light)", x = 0.78, y = 11.93, z = 4.14, yaw = -0.9579 },
    { kind = "prop", what = "torch / lamp (light)", x = 7.47, y = 10.62, z = 5.23, yaw = -0.1569 },
    { kind = "prop", what = "torch / lamp (light)", x = 8.22, y = -1.13, z = 3.75, yaw = -0.9923 },
    { kind = "prop", what = "table big", x = -13.47, y = 14.00, z = 5.22, yaw = -0.5555 },
    { kind = "prop", what = "chair", x = -13.56, y = 12.51, z = 5.08, yaw = -1.1235 },
    { kind = "prop", what = "chair", x = -14.48, y = 13.34, z = 5.47, yaw = -1.4772 },
    { kind = "prop", what = "chair", x = -12.58, y = 14.28, z = 5.01, yaw = -0.2091 },
    { kind = "prop", what = "chair", x = -14.81, y = 14.67, z = 5.54, yaw = -0.3800 },
    { kind = "prop", what = "weapon pile", x = -13.56, y = 11.79, z = 4.98, yaw = -0.7295 },
    { kind = "prop", what = "barrel", x = -14.34, y = 11.50, z = 5.08, yaw = -1.0659 },
    { kind = "prop", what = "barrel", x = -15.01, y = 11.00, z = 5.11, yaw = -1.3994 },
    { kind = "prop", what = "beer barrel", x = -14.31, y = 12.28, z = 5.20, yaw = -0.8121 },
    { kind = "prop", what = "arrow barrel", x = -14.90, y = 12.09, z = 5.26, yaw = -1.1983 },
    { kind = "prop", what = "arrow barrel", x = -15.23, y = 11.81, z = 5.26, yaw = -1.4461 },
    { kind = "prop", what = "sack_b", x = -15.08, y = 12.71, z = 5.38, yaw = -1.1378 },
    { kind = "prop", what = "sack_pig_feed", x = -15.45, y = 12.42, z = 5.39, yaw = -1.5885 },
    { kind = "prop", what = "sack_charcoal", x = -15.54, y = 11.36, z = 5.24, yaw = 0.3154 },
    { kind = "prop", what = "tent 5", x = -15.02, y = 11.74, z = 5.22, yaw = -3.9112 },
    { kind = "tower", what = "archer tower (spawns an archer)", x = 7.42, y = 4.22, z = 2.77, yaw = 0.2708 },
    { kind = "tower", what = "archer tower (spawns an archer)", x = -13.59, y = 1.96, z = 3.97, yaw = 1.8532 },
    { kind = "tower", what = "archer tower (spawns an archer)", x = 6.09, y = -5.64, z = 1.37, yaw = 1.2491 },
    { kind = "prop", what = "crate_low_b", x = -4.95, y = 21.52, z = 5.05, yaw = -0.3917 },
    { kind = "prop", what = "weapon pile", x = -4.28, y = 22.30, z = 5.06, yaw = 0.1760 },
    { kind = "prop", what = "arrow barrel", x = -6.06, y = 18.92, z = 4.78, yaw = -1.3461 },
    { kind = "prop", what = "sack_b", x = -4.73, y = 21.80, z = 5.06, yaw = 0.4774 },
    { kind = "prop", what = "sack_charcoal", x = -4.84, y = 21.39, z = 5.04, yaw = 0.2967 },

    -- The smithy BORROWS a Smithery from the world - see SpawnBanditCampForge. It searches
    -- loaded entities rather than nearby ones, so the camp's distance from a village does not
    -- matter; the label's "(needs a Smithery nearby)" is the builder's wording, not a real
    -- constraint. The camp hands it back when it comes down.
    { kind = "upgrade", what = "smithy (needs a Smithery nearby)", x = -8.43, y = 22.22, z = 5.16, yaw = 2.6810 },

    -- One of the two coincident torches at (-6.6, 18.8) dropped: they were 15cm apart and
    -- stacked Light entities blow each other out.
}

-- A ring of nine tents round a single fire, with a drinking bench in the middle, an alchemy
-- bench off to one side and an archer cart covering the western approach. Torch-lit.
mercenaries.BanditCampLayouts.ringcamp = {
    { kind = "prop", what = "tent 3", x = 0.00, y = 0.00, z = 0.00, yaw = -1.4489 },
    { kind = "prop", what = "tent 4", x = -1.60, y = 1.70, z = -0.32, yaw = -0.3805 },
    { kind = "prop", what = "tent 1", x = 3.79, y = -5.25, z = 0.90, yaw = -1.3007 },
    { kind = "prop", what = "tent 2", x = 3.86, y = -7.64, z = 1.14, yaw = -2.2854 },
    { kind = "prop", what = "tent 3", x = 1.52, y = -9.46, z = 1.16, yaw = -3.2033 },
    { kind = "prop", what = "tent 4", x = -2.22, y = -8.72, z = 0.84, yaw = -3.3850 },
    { kind = "prop", what = "tent 5", x = -4.85, y = -7.09, z = 0.55, yaw = -4.3548 },
    { kind = "prop", what = "tent 1", x = -6.05, y = -4.02, z = 0.15, yaw = -4.3879 },
    { kind = "prop", what = "tent 2", x = -7.07, y = -1.56, z = -0.21, yaw = 1.2678 },
    { kind = "prop", what = "bed", x = -1.51, y = 1.77, z = -0.32, yaw = 1.2920 },
    { kind = "prop", what = "bed", x = 0.74, y = -0.22, z = 0.07, yaw = 0.2513 },
    { kind = "prop", what = "bed", x = 3.83, y = -5.34, z = 0.95, yaw = 0.2129 },
    { kind = "prop", what = "bed", x = 3.83, y = -8.03, z = 1.18, yaw = -0.7983 },
    { kind = "prop", what = "bed", x = 1.16, y = -10.25, z = 1.17, yaw = -1.4955 },
    { kind = "prop", what = "bed", x = -2.34, y = -8.86, z = 0.85, yaw = -1.7824 },
    { kind = "prop", what = "bed", x = -4.79, y = -7.47, z = 0.59, yaw = -1.1747 },
    { kind = "prop", what = "bed", x = -6.14, y = -4.13, z = 0.16, yaw = -2.7596 },
    { kind = "prop", what = "bed", x = -7.36, y = -1.15, z = -0.27, yaw = 2.8439 },
    { kind = "prop", what = "campfire (light)", x = -1.76, y = -2.71, z = 0.30, yaw = 0.3973 },
    { kind = "upgrade", what = "makeshift inn", x = -0.60, y = -4.47, z = 0.55, yaw = -2.6954 },
    { kind = "prop", what = "barrel", x = 0.51, y = -6.80, z = 0.84, yaw = -1.7102 },
    { kind = "prop", what = "beer barrel", x = 0.45, y = -5.92, z = 0.75, yaw = -0.3411 },
    { kind = "prop", what = "sack_pig_feed", x = -1.51, y = -7.52, z = 0.77, yaw = -1.2908 },
    { kind = "prop", what = "sack_pig_feed", x = -0.16, y = -5.75, z = 0.70, yaw = 0.2978 },
    { kind = "prop", what = "sack_charcoal", x = 0.23, y = -7.60, z = 0.91, yaw = -0.0935 },
    { kind = "prop", what = "crate_low_b", x = -2.00, y = -6.91, z = 0.69, yaw = 2.6480 },
    { kind = "upgrade", what = "alchemy bench (needs an AlchemyTable nearby)", x = 2.33, y = -18.13, z = 1.69, yaw = -2.7009 },
    { kind = "cart", what = "archer cart (spawns 3 archers)", x = -13.99, y = 5.15, z = -1.47, yaw = 1.5134 },
    { kind = "prop", what = "torch / lamp (light)", x = -15.53, y = 4.40, z = -1.44, yaw = 0.4314 },
    { kind = "prop", what = "torch / lamp (light)", x = -12.27, y = 4.17, z = -1.24, yaw = 0.9214 },
    { kind = "prop", what = "torch / lamp (light)", x = -9.91, y = 3.45, z = 0.38, yaw = 0.5529 },
    { kind = "prop", what = "torch / lamp (light)", x = -7.87, y = 1.68, z = 0.73, yaw = -0.3110 },
    { kind = "prop", what = "torch / lamp (light)", x = -0.66, y = 1.33, z = -0.19, yaw = -0.0709 },
    { kind = "prop", what = "torch / lamp (light)", x = 0.65, y = -1.24, z = 0.22, yaw = -0.4020 },
    { kind = "prop", what = "torch / lamp (light)", x = 2.82, y = -3.04, z = 0.58, yaw = 0.0783 },
    { kind = "prop", what = "torch / lamp (light)", x = 3.97, y = -4.15, z = 0.79, yaw = -0.1002 },
    { kind = "prop", what = "torch / lamp (light)", x = 3.01, y = -8.91, z = 1.19, yaw = -0.9543 },
    { kind = "prop", what = "torch / lamp (light)", x = -0.07, y = -10.17, z = 1.10, yaw = -1.8535 },
    { kind = "prop", what = "torch / lamp (light)", x = -1.29, y = -9.17, z = 0.94, yaw = -1.5646 },
    { kind = "prop", what = "torch / lamp (light)", x = -4.14, y = -7.97, z = 0.67, yaw = -2.5088 },
    { kind = "prop", what = "big chest (lootable)", x = -5.40, y = -6.16, z = 0.43, yaw = 2.0080 },
    { kind = "prop", what = "small chest", x = -5.10, y = -8.35, z = 0.61, yaw = -2.6555 },
    { kind = "prop", what = "chair", x = -1.60, y = -0.94, z = 0.06, yaw = -0.4949 },
    { kind = "prop", what = "chair", x = -0.82, y = -2.02, z = 0.24, yaw = -0.6474 },
    { kind = "prop", what = "chair", x = -0.86, y = -3.22, z = 0.39, yaw = -0.8604 },
    { kind = "prop", what = "chair", x = -2.15, y = -4.07, z = 0.40, yaw = -1.1935 },
    { kind = "prop", what = "chair", x = -3.72, y = -3.28, z = 0.22, yaw = -1.5260 },
    { kind = "prop", what = "chair", x = -3.91, y = -1.61, z = -0.00, yaw = -1.5848 },
    { kind = "prop", what = "chair", x = -11.17, y = 3.01, z = -1.03, yaw = 1.5860 },
}

-- Built around the player HOUSE as the leader's quarters: two tent rows and a fire either
-- side of it, a supply dump 20m east, a mess table, a hunter's spot and two watchtowers.
-- The hut is what makes this one read as a settled band rather than a camp.
mercenaries.BanditCampLayouts.hideout = {
    { kind = "upgrade", what = "player HOUSE", x = 0.00, y = 0.00, z = 0.00, yaw = 0.6721 },
    { kind = "prop", what = "tent 1", x = -0.79, y = 5.35, z = -0.28, yaw = 1.2731 },
    { kind = "prop", what = "tent 2", x = 0.30, y = 8.92, z = 0.11, yaw = 1.4671 },
    { kind = "prop", what = "tent 3", x = 0.80, y = 12.39, z = 0.17, yaw = 0.9935 },
    { kind = "prop", what = "tent 4", x = 4.53, y = 7.61, z = 0.09, yaw = -1.7444 },
    { kind = "prop", what = "tent 2", x = 5.16, y = 11.17, z = 0.28, yaw = -1.7963 },
    { kind = "prop", what = "tent 3", x = 6.47, y = 14.60, z = -0.03, yaw = -1.8801 },
    { kind = "prop", what = "tent 4", x = 8.65, y = 13.33, z = -0.22, yaw = 1.0944 },
    { kind = "prop", what = "tent 5", x = 7.84, y = 9.31, z = 0.04, yaw = 1.4981 },
    { kind = "prop", what = "bed", x = 7.42, y = 9.40, z = 0.11, yaw = -3.1193 },
    { kind = "prop", what = "bed", x = 8.45, y = 13.42, z = -0.20, yaw = 2.6455 },
    { kind = "prop", what = "bed", x = 6.75, y = 14.13, z = -0.04, yaw = -0.2444 },
    { kind = "prop", what = "bed", x = 5.23, y = 10.85, z = 0.30, yaw = -0.2160 },
    { kind = "prop", what = "bed", x = 4.70, y = 7.61, z = 0.09, yaw = -0.1547 },
    { kind = "prop", what = "bed", x = -0.15, y = 9.12, z = 0.08, yaw = 2.8910 },
    { kind = "prop", what = "bed", x = -0.57, y = 5.22, z = -0.31, yaw = 2.8251 },
    { kind = "prop", what = "bed", x = 0.56, y = 12.89, z = 0.20, yaw = 2.7910 },
    { kind = "prop", what = "campfire (light)", x = 2.78, y = 9.19, z = 0.11, yaw = 1.7457 },
    { kind = "prop", what = "stool", x = 0.21, y = 7.26, z = 0.01, yaw = 2.9558 },
    { kind = "prop", what = "stool", x = 3.84, y = 10.86, z = 0.21, yaw = 1.4576 },
    { kind = "prop", what = "stool", x = 2.13, y = 11.30, z = 0.14, yaw = 2.0017 },
    { kind = "prop", what = "stool", x = 1.40, y = 10.10, z = 0.16, yaw = 2.3291 },
    { kind = "prop", what = "stool", x = 1.88, y = 7.48, z = 0.08, yaw = 3.1160 },
    { kind = "prop", what = "stool", x = 3.62, y = 7.38, z = 0.11, yaw = 1.5316 },
    { kind = "prop", what = "tent 1", x = 1.66, y = 15.91, z = 0.12, yaw = 1.2892 },
    { kind = "prop", what = "bed", x = 1.71, y = 15.91, z = 0.12, yaw = 2.8560 },
    { kind = "prop", what = "campfire (light)", x = 4.03, y = 14.62, z = 0.07, yaw = 0.6944 },
    { kind = "prop", what = "chair", x = 5.71, y = 14.52, z = 0.01, yaw = 0.4993 },
    { kind = "prop", what = "chair", x = 4.89, y = 12.79, z = 0.10, yaw = -0.0948 },
    { kind = "prop", what = "chair", x = 2.37, y = 13.93, z = 0.14, yaw = 2.0302 },
    { kind = "prop", what = "chair", x = 3.48, y = 16.43, z = 0.02, yaw = 1.3769 },
    { kind = "prop", what = "chair", x = 5.10, y = 16.15, z = 0.01, yaw = 0.3212 },
    { kind = "prop", what = "stool", x = 17.32, y = 11.67, z = -1.30, yaw = -0.1390 },
    { kind = "prop", what = "stool", x = 15.49, y = 12.64, z = -1.26, yaw = 0.1912 },
    { kind = "prop", what = "stool", x = 13.42, y = 12.25, z = -1.20, yaw = 0.1884 },
    { kind = "prop", what = "torch / lamp (light)", x = 15.10, y = 12.70, z = -1.25, yaw = 0.2260 },
    { kind = "prop", what = "torch / lamp (light)", x = 17.19, y = 11.93, z = -1.28, yaw = -0.0031 },
    { kind = "prop", what = "torch / lamp (light)", x = 13.13, y = 12.29, z = -1.17, yaw = 0.2528 },
    { kind = "prop", what = "crate_small", x = 16.36, y = 12.63, z = -1.24, yaw = -0.4778 },
    { kind = "prop", what = "beer barrel", x = 14.19, y = 13.62, z = -1.14, yaw = 1.6823 },
    { kind = "prop", what = "arrow barrel", x = 21.00, y = 12.79, z = -1.23, yaw = -0.0393 },
    { kind = "prop", what = "arrow barrel", x = 21.47, y = 12.22, z = -1.24, yaw = -0.1962 },
    { kind = "prop", what = "sack_b", x = 21.14, y = 11.67, z = -1.22, yaw = -0.3773 },
    { kind = "prop", what = "sack_b", x = 21.18, y = 11.17, z = -1.21, yaw = -0.5049 },
    { kind = "prop", what = "sack_pig_feed", x = 20.69, y = 11.46, z = -1.22, yaw = -0.4973 },
    { kind = "prop", what = "sack_pig_feed", x = 20.45, y = 13.18, z = -1.26, yaw = 0.1123 },
    { kind = "prop", what = "sack_charcoal", x = 19.82, y = 13.00, z = -1.24, yaw = 0.0496 },
    { kind = "prop", what = "sack_charcoal", x = 19.21, y = 12.91, z = -1.23, yaw = 0.0027 },
    { kind = "prop", what = "weapon pile", x = 20.46, y = 12.18, z = -1.23, yaw = -0.2889 },
    { kind = "prop", what = "weapon pile", x = 19.69, y = 12.38, z = -1.23, yaw = -0.3043 },
    { kind = "prop", what = "small chest", x = 7.34, y = 8.26, z = -0.00, yaw = -3.0583 },
    { kind = "prop", what = "torch / lamp (light)", x = 7.54, y = 10.69, z = 0.08, yaw = 2.5305 },
    { kind = "prop", what = "torch / lamp (light)", x = 9.04, y = 14.53, z = -0.28, yaw = 2.0219 },
    { kind = "prop", what = "torch / lamp (light)", x = 1.29, y = 15.08, z = 0.18, yaw = -2.9891 },
    { kind = "prop", what = "torch / lamp (light)", x = 1.01, y = 14.00, z = 0.20, yaw = 2.4839 },
    { kind = "prop", what = "torch / lamp (light)", x = 0.25, y = 10.33, z = 0.16, yaw = 2.5968 },
    { kind = "prop", what = "torch / lamp (light)", x = 4.45, y = 6.58, z = 0.08, yaw = -0.5167 },
    { kind = "prop", what = "torch / lamp (light)", x = 5.04, y = 9.78, z = 0.23, yaw = -0.0358 },
    { kind = "prop", what = "torch / lamp (light)", x = 6.58, y = 13.05, z = 0.02, yaw = -0.4013 },
    { kind = "prop", what = "tent 1", x = 19.81, y = 8.03, z = -1.20, yaw = -1.6201 },
    { kind = "prop", what = "tent 2", x = 18.97, y = 5.57, z = -0.86, yaw = -2.0667 },
    { kind = "prop", what = "bed", x = 19.07, y = 5.46, z = -0.82, yaw = -0.5201 },
    { kind = "prop", what = "bed", x = 19.83, y = 7.83, z = -1.16, yaw = -0.0642 },
    { kind = "prop", what = "table big", x = 11.39, y = 14.89, z = -0.68, yaw = -3.0042 },
    { kind = "prop", what = "chair", x = 10.82, y = 13.87, z = -0.69, yaw = -2.6901 },
    { kind = "prop", what = "chair", x = 11.61, y = 14.04, z = -0.83, yaw = -2.6037 },
    { kind = "prop", what = "chair", x = 10.92, y = 16.26, z = -0.50, yaw = 2.7568 },
    { kind = "prop", what = "chair", x = 11.71, y = 16.15, z = -0.64, yaw = 2.6607 },
    { kind = "upgrade", what = "hunter's spot", x = 16.27, y = -2.77, z = -0.59, yaw = -0.0200 },
    { kind = "tower", what = "archer tower (spawns an archer)", x = 8.92, y = 2.11, z = -0.01, yaw = 2.4998 },
    { kind = "tower", what = "archer tower (spawns an archer)", x = 20.25, y = 0.50, z = -0.42, yaw = -0.2740 },
    { kind = "prop", what = "big chest (lootable)", x = 5.23, y = 4.68, z = 0.11, yaw = -1.5495 },
    { kind = "prop", what = "beer barrel", x = 5.84, y = 5.78, z = 0.09, yaw = -0.0551 },
    { kind = "prop", what = "arrow barrel", x = 5.26, y = 5.65, z = 0.07, yaw = -0.1299 },
    { kind = "prop", what = "sack_b", x = 4.72, y = 5.74, z = 0.06, yaw = -0.1193 },
}

-- The SECOND camp from the same dump, rebased onto its own origin. It was built ~150m south
-- of the hideout in the same builder session, so the dump came out as one 170m-long
-- "layout" - far too big to be one camp: the spawn ring, the 50m despawn radius, the alert
-- range and the leftover sweep all key off a single centre.
mercenaries.BanditCampLayouts.southcamp = {
    { kind = "prop", what = "tent 4", x = 0.00, y = 0.00, z = 0.00, yaw = 1.3194 },
    { kind = "prop", what = "tent 5", x = 2.03, y = 2.12, z = -0.07, yaw = 0.1685 },
    { kind = "prop", what = "player tent", x = 7.28, y = 1.96, z = -0.15, yaw = -3.7361 },
    { kind = "prop", what = "tent 4", x = 6.88, y = -1.52, z = 0.13, yaw = -1.7256 },
    { kind = "prop", what = "tent 5", x = 4.66, y = -3.23, z = 0.26, yaw = -3.0256 },
    { kind = "prop", what = "bed", x = -0.05, y = 0.02, z = 0.00, yaw = 2.8187 },
    { kind = "prop", what = "bed", x = 2.02, y = 2.24, z = -0.07, yaw = 1.8493 },
    { kind = "prop", what = "bed", x = 8.18, y = 1.15, z = -0.17, yaw = -0.7129 },
    { kind = "prop", what = "bed", x = 6.48, y = 2.71, z = -0.12, yaw = 2.4151 },
    { kind = "prop", what = "big chest (lootable)", x = 8.06, y = 3.00, z = -0.28, yaw = -0.7304 },
    { kind = "prop", what = "small chest", x = 8.99, y = 2.10, z = -0.32, yaw = -0.5917 },
    { kind = "prop", what = "sack_b", x = 7.66, y = 0.11, z = -0.02, yaw = -1.5281 },
    { kind = "prop", what = "torch / lamp (light)", x = 9.25, y = 2.19, z = -0.34, yaw = -0.4734 },
    { kind = "prop", what = "torch / lamp (light)", x = 5.55, y = 2.10, z = -0.05, yaw = -2.6822 },
    { kind = "prop", what = "bed", x = 7.04, y = -1.57, z = 0.13, yaw = -0.0877 },
    { kind = "prop", what = "bed", x = 4.63, y = -3.37, z = 0.26, yaw = -1.3673 },
    { kind = "prop", what = "table big", x = 4.92, y = -1.09, z = 0.10, yaw = -0.5227 },
    { kind = "prop", what = "chair", x = 5.69, y = -0.57, z = 0.08, yaw = -0.1617 },
    { kind = "prop", what = "chair", x = 5.10, y = -0.15, z = 0.06, yaw = 0.0294 },
    { kind = "prop", what = "chair", x = 4.62, y = -2.18, z = 0.16, yaw = -1.0109 },
    { kind = "prop", what = "chair", x = 3.79, y = -1.68, z = 0.13, yaw = -1.2916 },
    { kind = "prop", what = "campfire (light)", x = 2.46, y = -0.42, z = 0.02, yaw = 1.0199 },
    { kind = "prop", what = "tent 5", x = -4.09, y = 6.05, z = 0.14, yaw = -1.2438 },
    { kind = "prop", what = "player tent", x = -11.72, y = 5.53, z = 0.36, yaw = -1.0625 },
    { kind = "prop", what = "tent 4", x = -6.54, y = 9.12, z = 0.26, yaw = -0.7757 },
    { kind = "prop", what = "tent 4", x = -4.69, y = 2.89, z = 0.20, yaw = -2.0818 },
    { kind = "prop", what = "tent 5", x = -9.53, y = 8.92, z = 0.31, yaw = 0.5005 },
    { kind = "prop", what = "bed", x = -9.78, y = 9.13, z = 0.31, yaw = 2.0869 },
    { kind = "prop", what = "bed", x = -6.44, y = 9.06, z = 0.26, yaw = 1.0282 },
    { kind = "prop", what = "bed", x = -3.82, y = 6.09, z = 0.12, yaw = 0.3580 },
    { kind = "prop", what = "bed", x = -4.66, y = 2.76, z = 0.20, yaw = -0.4391 },
    { kind = "prop", what = "bed", x = -12.18, y = 6.43, z = 0.36, yaw = 2.0986 },
    { kind = "prop", what = "bed", x = -12.63, y = 4.58, z = 0.36, yaw = -2.7581 },
    { kind = "prop", what = "bed", x = -10.93, y = 4.77, z = 0.36, yaw = -1.0919 },
    { kind = "prop", what = "chair", x = -11.59, y = 5.46, z = 0.36, yaw = -1.9829 },
    { kind = "prop", what = "torch / lamp (light)", x = -10.40, y = 5.06, z = 0.35, yaw = -1.1973 },
    { kind = "prop", what = "torch / lamp (light)", x = -12.39, y = 4.45, z = 0.36, yaw = -2.1089 },
    { kind = "prop", what = "torch / lamp (light)", x = -12.55, y = 6.40, z = 0.36, yaw = -2.9409 },
    { kind = "prop", what = "beer barrel", x = -5.55, y = 7.68, z = 0.23, yaw = 0.7224 },
    { kind = "prop", what = "sack_b", x = -4.07, y = 4.24, z = 0.15, yaw = -0.3867 },
    { kind = "prop", what = "campfire (light)", x = -7.36, y = 5.97, z = 0.27, yaw = 1.2458 },
    { kind = "prop", what = "weapon pile", x = -6.05, y = 2.51, z = 0.26, yaw = -0.4080 },
    { kind = "upgrade", what = "food cart", x = 3.31, y = -13.17, z = 0.80, yaw = -0.8584 },
    { kind = "prop", what = "table big", x = 5.13, y = -10.81, z = 0.62, yaw = -1.0801 },
    { kind = "prop", what = "chair", x = 5.80, y = -10.13, z = 0.60, yaw = -0.8537 },
    { kind = "prop", what = "chair", x = 6.57, y = -11.26, z = 0.57, yaw = -0.8183 },
    { kind = "prop", what = "chair", x = 4.60, y = -9.65, z = 0.57, yaw = -0.8353 },
    { kind = "prop", what = "sack_b", x = 3.12, y = -11.36, z = 0.64, yaw = -1.7952 },
    { kind = "prop", what = "sack_b", x = 4.44, y = -11.55, z = 0.68, yaw = -1.3278 },
    { kind = "prop", what = "sack_pig_feed", x = 5.08, y = -12.33, z = 0.70, yaw = -1.2161 },
    { kind = "prop", what = "sack_pig_feed", x = 0.80, y = -14.30, z = 0.91, yaw = -1.1456 },
    { kind = "prop", what = "sack_pig_feed", x = 1.03, y = -13.75, z = 0.86, yaw = -0.8278 },
    { kind = "prop", what = "sack_pig_feed", x = 1.40, y = -13.16, z = 0.80, yaw = -0.3163 },
    { kind = "prop", what = "sack_charcoal", x = 1.47, y = -14.53, z = 0.93, yaw = -0.9166 },
    { kind = "prop", what = "sack_charcoal", x = 2.37, y = -12.59, z = 0.74, yaw = 0.0639 },
    { kind = "prop", what = "weapon pile", x = 1.32, y = -15.24, z = 0.98, yaw = -1.1164 },
    { kind = "prop", what = "barrel", x = 2.46, y = -12.49, z = 0.73, yaw = 0.0995 },
    { kind = "prop", what = "barrel", x = 1.51, y = -12.46, z = 0.73, yaw = 0.1898 },
    { kind = "upgrade", what = "makeshift inn", x = 6.01, y = 11.50, z = -0.47, yaw = 1.9029 },
    { kind = "prop", what = "campfire (light)", x = 7.28, y = 13.14, z = -0.49, yaw = 1.6609 },
    { kind = "tower", what = "archer tower (spawns an archer)", x = -5.07, y = -17.38, z = 5.02, yaw = -2.3801 },
    { kind = "tower", what = "archer tower (spawns an archer)", x = -2.44, y = -19.29, z = 4.61, yaw = 2.2547 },
}

-- The ROMAN FORT: thirteen tents walled round two hearths, two drinking benches, a smithy,
-- and FOUR watchtowers on the corners. The last camp before Raborsch, and it should read as
-- the one that needs the whole company.
--
-- The practice yard that appeared in the dump was a misplacement and is left out.
mercenaries.BanditCampLayouts.romanfort = {
    { kind = "prop", what = "tent 2", x = 0.00, y = 0.00, z = 0.00, yaw = -2.6744 },
    { kind = "prop", what = "tent 4", x = -3.40, y = -1.19, z = 0.21, yaw = -2.6990 },
    { kind = "prop", what = "tent 1", x = -6.17, y = -2.22, z = 0.36, yaw = -2.7315 },
    { kind = "prop", what = "tent 2", x = -8.64, y = -2.70, z = 0.55, yaw = -2.6481 },
    { kind = "prop", what = "tent 4", x = -11.69, y = -4.00, z = 0.79, yaw = -2.6297 },
    { kind = "prop", what = "tent 1", x = -13.84, y = -3.31, z = 0.90, yaw = -4.3248 },
    { kind = "prop", what = "tent 2", x = -14.26, y = -0.74, z = 1.11, yaw = -4.3401 },
    { kind = "prop", what = "tent 2", x = -15.44, y = 2.16, z = 1.02, yaw = -4.3586 },
    { kind = "prop", what = "tent 4", x = -16.24, y = 5.33, z = 0.98, yaw = -4.4302 },
    { kind = "prop", what = "tent 5", x = -15.37, y = 8.43, z = 0.84, yaw = 0.3407 },
    { kind = "prop", what = "tent 1", x = -11.97, y = 9.81, z = 0.48, yaw = 0.3421 },
    { kind = "prop", what = "tent 4", x = -9.13, y = 10.07, z = 0.21, yaw = 0.3434 },
    { kind = "prop", what = "tent 1", x = -6.40, y = 11.16, z = -0.07, yaw = 0.4911 },
    { kind = "prop", what = "bed", x = 0.11, y = -0.28, z = 0.00, yaw = -1.0849 },
    { kind = "prop", what = "bed", x = -3.35, y = -1.41, z = 0.23, yaw = -1.1988 },
    { kind = "prop", what = "bed", x = -6.09, y = -2.41, z = 0.37, yaw = -1.1568 },
    { kind = "prop", what = "bed", x = -8.67, y = -3.06, z = 0.56, yaw = -1.1515 },
    { kind = "prop", what = "bed", x = -11.64, y = -4.19, z = 0.78, yaw = -1.0620 },
    { kind = "prop", what = "bed", x = -14.11, y = -3.30, z = 0.90, yaw = -2.8108 },
    { kind = "prop", what = "bed", x = -14.66, y = -0.70, z = 1.09, yaw = -2.8769 },
    { kind = "prop", what = "bed", x = -15.92, y = 2.00, z = 0.98, yaw = -2.8080 },
    { kind = "prop", what = "bed", x = -16.45, y = 5.18, z = 0.99, yaw = -2.8393 },
    { kind = "prop", what = "bed", x = -15.36, y = 8.56, z = 0.84, yaw = 1.9591 },
    { kind = "prop", what = "bed", x = -11.98, y = 9.62, z = 0.46, yaw = 1.9223 },
    { kind = "prop", what = "bed", x = -9.21, y = 10.05, z = 0.22, yaw = 1.8875 },
    { kind = "prop", what = "bed", x = -6.57, y = 11.12, z = -0.05, yaw = 2.1096 },
    { kind = "prop", what = "campfire (light)", x = -7.03, y = 1.22, z = 0.64, yaw = -1.9154 },
    { kind = "prop", what = "campfire (light)", x = -10.74, y = 6.84, z = 0.21, yaw = 1.9015 },
    { kind = "upgrade", what = "makeshift inn", x = -11.20, y = 1.64, z = 0.65, yaw = -2.8397 },
    { kind = "prop", what = "table big", x = -11.77, y = 3.59, z = 0.37, yaw = -1.3086 },
    { kind = "prop", what = "table big", x = -14.33, y = 3.10, z = 0.81, yaw = -1.3072 },
    { kind = "prop", what = "stool", x = -12.78, y = 3.10, z = 0.53, yaw = -0.7922 },
    { kind = "prop", what = "stool", x = -12.78, y = 3.71, z = 0.47, yaw = -0.5939 },
    { kind = "prop", what = "stool", x = -13.75, y = 3.08, z = 0.70, yaw = -1.1486 },
    { kind = "prop", what = "stool", x = -13.81, y = 3.58, z = 0.66, yaw = -1.0558 },
    { kind = "prop", what = "stool", x = -15.06, y = 2.66, z = 0.93, yaw = -1.4816 },
    { kind = "prop", what = "stool", x = -15.13, y = 3.15, z = 0.89, yaw = -1.5023 },
    { kind = "prop", what = "stool", x = -10.89, y = 3.54, z = 0.36, yaw = -1.6717 },
    { kind = "prop", what = "stool", x = -11.13, y = 4.31, z = 0.27, yaw = -1.8959 },
    { kind = "upgrade", what = "makeshift inn", x = -8.06, y = 3.53, z = 0.43, yaw = -2.0893 },
    { kind = "upgrade", what = "smithy (needs a Smithery nearby)", x = -5.76, y = 4.55, z = 0.17, yaw = -1.9024 },
    { kind = "tower", what = "archer tower (spawns an archer)", x = 4.59, y = -2.64, z = -0.13, yaw = 2.4373 },
    { kind = "tower", what = "archer tower (spawns an archer)", x = -4.54, y = 14.78, z = -0.15, yaw = 2.6589 },
    { kind = "tower", what = "archer tower (spawns an archer)", x = -18.98, y = 9.21, z = 1.05, yaw = -2.0830 },
    { kind = "tower", what = "archer tower (spawns an archer)", x = -14.62, y = -7.00, z = 0.98, yaw = -0.6069 },
    { kind = "prop", what = "weapon pile", x = -6.27, y = 8.43, z = 0.01, yaw = 1.9587 },
    { kind = "prop", what = "weapon pile", x = -5.46, y = 8.80, z = -0.06, yaw = 1.6945 },
    { kind = "prop", what = "weapon pile", x = -7.40, y = -1.64, z = 0.48, yaw = -2.0572 },
    { kind = "prop", what = "big chest (lootable)", x = -8.40, y = 7.27, z = 0.14, yaw = 0.3660 },
    { kind = "prop", what = "barrel", x = -6.86, y = 9.14, z = 0.04, yaw = 1.6256 },
    { kind = "prop", what = "barrel", x = -4.62, y = 10.02, z = -0.17, yaw = 1.1997 },
    { kind = "prop", what = "beer barrel", x = -14.71, y = 4.29, z = 0.79, yaw = -2.9192 },
    { kind = "prop", what = "arrow barrel", x = -6.19, y = 9.38, z = -0.02, yaw = 1.8556 },
    { kind = "prop", what = "arrow barrel", x = -4.59, y = 9.25, z = -0.17, yaw = 1.1957 },
    { kind = "prop", what = "arrow barrel", x = -3.80, y = 10.25, z = -0.23, yaw = 1.0997 },
    { kind = "prop", what = "sack_b", x = -5.98, y = 10.03, z = -0.07, yaw = 1.7621 },
    { kind = "prop", what = "sack_b", x = -5.38, y = 10.46, z = -0.13, yaw = 1.5372 },
    { kind = "prop", what = "sack_pig_feed", x = -5.13, y = 9.76, z = -0.14, yaw = 1.4192 },
    { kind = "prop", what = "sack_pig_feed", x = -7.68, y = 8.95, z = 0.11, yaw = 2.2646 },
    { kind = "prop", what = "sack_charcoal", x = -5.07, y = 7.85, z = -0.10, yaw = 0.5076 },
    { kind = "prop", what = "torch / lamp (light)", x = -3.20, y = 8.17, z = -0.20, yaw = 0.4459 },
    { kind = "prop", what = "torch / lamp (light)", x = -1.10, y = -0.62, z = 0.08, yaw = -1.6160 },
    { kind = "prop", what = "torch / lamp (light)", x = -4.33, y = -1.69, z = 0.25, yaw = -2.1367 },
    { kind = "prop", what = "torch / lamp (light)", x = -5.02, y = -2.05, z = 0.30, yaw = -0.9662 },
    { kind = "prop", what = "torch / lamp (light)", x = -9.67, y = -3.48, z = 0.66, yaw = -1.6932 },
    { kind = "prop", what = "torch / lamp (light)", x = -12.57, y = -4.76, z = 0.80, yaw = -1.9987 },
    { kind = "prop", what = "torch / lamp (light)", x = -14.31, y = -2.32, z = 0.98, yaw = 2.9613 },
    { kind = "prop", what = "torch / lamp (light)", x = -15.11, y = 0.41, z = 1.09, yaw = 2.4720 },
    { kind = "prop", what = "torch / lamp (light)", x = -16.54, y = 3.33, z = 0.92, yaw = 2.8260 },
    { kind = "prop", what = "torch / lamp (light)", x = -16.67, y = 6.27, z = 1.05, yaw = 2.8227 },
    { kind = "prop", what = "torch / lamp (light)", x = -16.32, y = 7.74, z = 1.02, yaw = 2.5297 },
    { kind = "prop", what = "torch / lamp (light)", x = -12.13, y = 9.74, z = 0.49, yaw = 1.3103 },
    { kind = "prop", what = "torch / lamp (light)", x = -9.02, y = 10.30, z = 0.21, yaw = 1.5558 },
    { kind = "prop", what = "torch / lamp (light)", x = -6.48, y = 11.16, z = -0.06, yaw = 0.8609 },
}

-- The MINING CAMP: nine tents in two arcs round a single fire, a long mess of two tables and
-- nine chairs, and a stores corner. No towers and no borrowed upgrades - a working camp
-- rather than a fortified one, and the most compact of the set at roughly 11 x 11m.
mercenaries.BanditCampLayouts.mining = {
    { kind = "prop", what = "tent 1", x = 0.00, y = 0.00, z = 0.00, yaw = -4.0108 },
    { kind = "prop", what = "tent 2", x = -1.79, y = 2.41, z = -0.32, yaw = 1.4766 },
    { kind = "prop", what = "tent 3", x = -0.42, y = 4.92, z = -0.54, yaw = 0.7665 },
    { kind = "prop", what = "tent 4", x = 1.79, y = 6.59, z = -0.02, yaw = 0.1284 },
    { kind = "prop", what = "tent 1", x = 9.05, y = 5.67, z = -0.08, yaw = -1.6761 },
    { kind = "prop", what = "tent 2", x = 7.89, y = 8.51, z = -0.10, yaw = -0.8656 },
    { kind = "prop", what = "tent 3", x = 4.91, y = 9.49, z = 0.00, yaw = 0.0417 },
    { kind = "prop", what = "tent 4", x = 6.62, y = 4.06, z = -0.06, yaw = -2.7617 },
    { kind = "prop", what = "tent 5", x = 2.04, y = 9.06, z = 0.10, yaw = 1.0136 },
    { kind = "prop", what = "barrel", x = 1.10, y = 8.60, z = -0.00, yaw = 2.8356 },
    { kind = "prop", what = "barrel", x = 1.82, y = 10.35, z = 0.00, yaw = 2.3324 },
    { kind = "prop", what = "beer barrel", x = 1.18, y = 9.39, z = -0.01, yaw = 2.6295 },
    { kind = "prop", what = "arrow barrel", x = 1.17, y = 7.82, z = -0.02, yaw = 3.0541 },
    { kind = "prop", what = "arrow barrel", x = 1.46, y = 9.83, z = 0.01, yaw = 2.4943 },
    { kind = "prop", what = "sack_b", x = 2.36, y = 10.40, z = 0.01, yaw = 2.2133 },
    { kind = "prop", what = "sack_b", x = 1.46, y = 8.72, z = 0.05, yaw = 2.7674 },
    { kind = "prop", what = "sack_b", x = 1.70, y = 7.85, z = 0.08, yaw = 3.0260 },
    { kind = "prop", what = "sack_pig_feed", x = 1.97, y = 8.38, z = 0.10, yaw = 2.8155 },
    { kind = "prop", what = "sack_pig_feed", x = 2.01, y = 9.35, z = 0.09, yaw = 2.5106 },
    { kind = "prop", what = "big chest (lootable)", x = 2.65, y = 8.26, z = 0.16, yaw = 0.9725 },
    { kind = "prop", what = "bed", x = 0.03, y = -0.24, z = -0.01, yaw = -2.5626 },
    { kind = "prop", what = "bed", x = -2.08, y = 2.56, z = -0.33, yaw = 2.9834 },
    { kind = "prop", what = "bed", x = -0.47, y = 5.37, z = -0.53, yaw = 2.2785 },
    { kind = "prop", what = "bed", x = 2.03, y = 6.66, z = 0.04, yaw = 1.8675 },
    { kind = "prop", what = "bed", x = 5.40, y = 9.83, z = -0.08, yaw = 1.5228 },
    { kind = "prop", what = "bed", x = 8.31, y = 8.39, z = -0.08, yaw = 0.7898 },
    { kind = "prop", what = "bed", x = 8.90, y = 5.71, z = -0.07, yaw = -0.2343 },
    { kind = "prop", what = "bed", x = 6.86, y = 3.93, z = -0.07, yaw = -1.1576 },
    { kind = "prop", what = "small chest", x = 9.09, y = 7.51, z = -0.04, yaw = 0.7581 },
    { kind = "prop", what = "sack_b", x = 7.40, y = 9.39, z = -0.17, yaw = 1.5521 },
    { kind = "prop", what = "torch / lamp (light)", x = 5.24, y = 9.71, z = -0.05, yaw = 1.8442 },
    { kind = "prop", what = "torch / lamp (light)", x = 1.96, y = 6.61, z = 0.02, yaw = 2.3381 },
    { kind = "prop", what = "torch / lamp (light)", x = -0.14, y = 5.87, z = -0.49, yaw = 2.7956 },
    { kind = "prop", what = "torch / lamp (light)", x = -2.13, y = 3.21, z = -0.48, yaw = -3.0131 },
    { kind = "prop", what = "torch / lamp (light)", x = -0.42, y = -0.61, z = -0.00, yaw = -2.1926 },
    { kind = "prop", what = "torch / lamp (light)", x = 5.70, y = 3.76, z = -0.07, yaw = -0.6604 },
    { kind = "prop", what = "torch / lamp (light)", x = 8.30, y = 4.74, z = -0.09, yaw = -0.1780 },
    { kind = "prop", what = "torch / lamp (light)", x = 7.39, y = 9.24, z = -0.16, yaw = 1.2413 },
    { kind = "prop", what = "weapon pile", x = -1.31, y = 0.96, z = -0.09, yaw = -2.4972 },
    { kind = "prop", what = "weapon pile", x = 7.39, y = 4.89, z = -0.05, yaw = 0.0553 },
    { kind = "prop", what = "campfire (light)", x = 2.63, y = 3.36, z = 0.04, yaw = -2.4168 },
    { kind = "prop", what = "stool", x = 1.38, y = 4.49, z = -0.20, yaw = -3.0150 },
    { kind = "prop", what = "stool", x = 0.55, y = 2.83, z = -0.18, yaw = -2.6477 },
    { kind = "prop", what = "stool", x = 1.26, y = 1.05, z = -0.06, yaw = -2.2475 },
    { kind = "prop", what = "stool", x = 4.06, y = 1.93, z = -0.16, yaw = -1.6581 },
    { kind = "prop", what = "stool", x = 4.01, y = 4.81, z = 0.07, yaw = -2.9305 },
    { kind = "prop", what = "table big", x = 4.83, y = 6.82, z = 0.11, yaw = 2.4335 },
    { kind = "prop", what = "table big", x = 5.99, y = 5.90, z = -0.00, yaw = 2.4639 },
    { kind = "prop", what = "chair", x = 4.32, y = 6.29, z = 0.13, yaw = 1.8603 },
    { kind = "prop", what = "chair", x = 4.95, y = 5.85, z = 0.07, yaw = 1.5696 },
    { kind = "prop", what = "chair", x = 5.45, y = 5.38, z = 0.02, yaw = 1.1707 },
    { kind = "prop", what = "chair", x = 6.05, y = 4.61, z = -0.03, yaw = 0.3730 },
    { kind = "prop", what = "chair", x = 6.12, y = 7.13, z = -0.01, yaw = 2.5888 },
    { kind = "prop", what = "chair", x = 6.86, y = 6.51, z = -0.07, yaw = 2.7436 },
    { kind = "prop", what = "chair", x = 5.24, y = 7.52, z = 0.07, yaw = -2.6389 },
    { kind = "prop", what = "chair", x = 4.77, y = 8.49, z = 0.09, yaw = 2.8397 },
    { kind = "prop", what = "chair", x = 3.79, y = 7.85, z = 0.19, yaw = -2.9444 },
}

-- The SWAMP ISLAND: the run's coda. Two tent clusters on a marsh island, ringed by four
-- archer carts and two towers covering every approach - the last professional company,
-- sitting on the last of the silver. The practice yard from the dump is left out (the
-- player-camp trainer has no bandit-side variant); its spot is kept below.
-- { kind = "upgrade", what = "practice yard", x = 8.10, y = -12.85, z = -0.18, yaw = -1.4661 },
mercenaries.BanditCampLayouts.swampisland = {
    { kind = "prop", what = "tent 5", x = 0.00, y = 0.00, z = 0.00, yaw = 1.1242 },
    { kind = "prop", what = "tent 1", x = 0.60, y = -3.14, z = -0.58, yaw = -4.2145 },
    { kind = "prop", what = "tent 2", x = 3.04, y = -4.76, z = -0.20, yaw = -3.2774 },
    { kind = "prop", what = "tent 2", x = 3.25, y = 1.44, z = -0.34, yaw = 0.0262 },
    { kind = "prop", what = "tent 3", x = 5.98, y = 0.10, z = 0.02, yaw = -0.7902 },
    { kind = "prop", what = "tent 4", x = 5.51, y = -4.33, z = 0.20, yaw = -2.5044 },
    { kind = "prop", what = "bed", x = 5.53, y = -4.62, z = 0.21, yaw = -0.9963 },
    { kind = "prop", what = "bed", x = 2.95, y = -4.95, z = -0.24, yaw = -1.7324 },
    { kind = "prop", what = "bed", x = 0.51, y = -3.30, z = -0.69, yaw = -2.6041 },
    { kind = "prop", what = "bed", x = -0.42, y = 0.22, z = 0.01, yaw = 2.6069 },
    { kind = "prop", what = "bed", x = 3.27, y = 1.69, z = -0.38, yaw = 1.5302 },
    { kind = "prop", what = "bed", x = 6.71, y = 0.17, z = 0.05, yaw = 0.6997 },
    { kind = "prop", what = "campfire (light)", x = 3.90, y = -1.78, z = 0.14, yaw = -3.0035 },
    { kind = "prop", what = "stool", x = 3.37, y = -3.12, z = 0.02, yaw = -2.5790 },
    { kind = "prop", what = "stool", x = 1.74, y = -1.79, z = -0.11, yaw = -3.0732 },
    { kind = "prop", what = "stool", x = 2.37, y = 0.24, z = -0.11, yaw = 2.6866 },
    { kind = "prop", what = "stool", x = 5.09, y = -0.37, z = 0.09, yaw = 2.2920 },
    { kind = "prop", what = "stool", x = 5.72, y = -2.54, z = 0.24, yaw = 3.0111 },
    { kind = "prop", what = "big chest (lootable)", x = -0.49, y = -0.99, z = -0.10, yaw = 2.6274 },
    { kind = "prop", what = "barrel", x = 1.75, y = 2.25, z = -0.34, yaw = 1.5390 },
    { kind = "prop", what = "beer barrel", x = 4.63, y = 1.25, z = -0.31, yaw = 1.4019 },
    { kind = "prop", what = "sack_b", x = 6.62, y = -3.10, z = 0.30, yaw = -0.7844 },
    { kind = "prop", what = "torch / lamp (light)", x = 4.69, y = -5.34, z = 0.12, yaw = -1.4767 },
    { kind = "prop", what = "torch / lamp (light)", x = 3.48, y = -5.51, z = -0.14, yaw = -2.1095 },
    { kind = "prop", what = "torch / lamp (light)", x = 0.68, y = -3.92, z = -0.81, yaw = -2.8088 },
    { kind = "prop", what = "torch / lamp (light)", x = 0.25, y = 1.74, z = -0.15, yaw = 1.7976 },
    { kind = "prop", what = "torch / lamp (light)", x = 4.37, y = 1.39, z = -0.33, yaw = 0.4336 },
    { kind = "prop", what = "torch / lamp (light)", x = 6.97, y = -0.59, z = 0.25, yaw = -0.0987 },
    { kind = "prop", what = "player tent", x = 10.56, y = -2.58, z = 0.50, yaw = -2.0525 },
    { kind = "prop", what = "tent 1", x = 14.03, y = -1.21, z = -0.06, yaw = -0.1717 },
    { kind = "prop", what = "tent 2", x = 16.22, y = -3.05, z = -0.15, yaw = -1.0794 },
    { kind = "prop", what = "tent 3", x = 16.84, y = -6.14, z = -0.23, yaw = -2.0138 },
    { kind = "prop", what = "tent 4", x = 14.46, y = -8.19, z = -0.11, yaw = -2.8736 },
    { kind = "prop", what = "tent 1", x = 11.98, y = -8.01, z = 0.04, yaw = -3.5441 },
    { kind = "prop", what = "bed", x = 13.90, y = -1.43, z = -0.01, yaw = 1.4301 },
    { kind = "prop", what = "straw bed", x = 16.33, y = -3.26, z = -0.15, yaw = 0.4172 },
    { kind = "prop", what = "straw bed", x = 17.35, y = -6.61, z = -0.27, yaw = -0.4007 },
    { kind = "prop", what = "straw bed", x = 14.48, y = -8.20, z = -0.11, yaw = -1.2599 },
    { kind = "prop", what = "straw bed", x = 12.08, y = -8.16, z = 0.06, yaw = -1.9305 },
    { kind = "prop", what = "straw bed", x = 10.23, y = -3.59, z = 0.49, yaw = -2.2388 },
    { kind = "prop", what = "straw bed", x = 11.36, y = -1.77, z = 0.35, yaw = 0.9554 },
    { kind = "prop", what = "chair", x = 9.19, y = -2.24, z = 0.53, yaw = 2.9413 },
    { kind = "prop", what = "chair", x = 9.89, y = -1.35, z = 0.43, yaw = 2.2164 },
    { kind = "prop", what = "campfire (light)", x = 14.02, y = -5.20, z = 0.07, yaw = 0.2234 },
    { kind = "prop", what = "log seat", x = 13.72, y = -3.71, z = 0.09, yaw = 0.7807 },
    { kind = "prop", what = "log seat", x = 15.38, y = -4.36, z = 0.02, yaw = 0.3571 },
    { kind = "prop", what = "log seat", x = 15.21, y = -6.08, z = -0.07, yaw = -0.0932 },
    { kind = "prop", what = "log seat", x = 13.34, y = -7.14, z = -0.13, yaw = -0.6896 },
    { kind = "prop", what = "weapon pile", x = 14.86, y = -6.87, z = -0.09, yaw = -0.3385 },
    { kind = "prop", what = "beer barrel", x = 13.17, y = -7.74, z = -0.08, yaw = -0.9220 },
    { kind = "prop", what = "arrow barrel", x = 13.19, y = -2.58, z = 0.14, yaw = 1.1209 },
    { kind = "prop", what = "sack_b", x = 11.21, y = -4.58, z = 0.36, yaw = 1.9411 },
    { kind = "prop", what = "torch / lamp (light)", x = 14.98, y = -1.45, z = -0.16, yaw = 0.9136 },
    { kind = "prop", what = "torch / lamp (light)", x = 16.17, y = -2.90, z = -0.14, yaw = 0.3224 },
    { kind = "prop", what = "torch / lamp (light)", x = 17.47, y = -7.12, z = -0.30, yaw = -0.6251 },
    { kind = "prop", what = "torch / lamp (light)", x = 13.70, y = -8.50, z = -0.07, yaw = -1.4319 },
    { kind = "prop", what = "torch / lamp (light)", x = 11.18, y = -7.97, z = 0.05, yaw = -2.0070 },
    { kind = "upgrade", what = "food cart", x = 11.80, y = -11.88, z = -0.22, yaw = -0.6923 },
    { kind = "cart", what = "archer cart (spawns 3 archers)", x = 3.68, y = -11.48, z = -0.93, yaw = -2.7623 },
    { kind = "cart", what = "archer cart (spawns 3 archers)", x = 16.63, y = -15.81, z = -1.04, yaw = -0.7265 },
    { kind = "cart", what = "archer cart (spawns 3 archers)", x = 21.75, y = -2.37, z = -0.79, yaw = 0.6513 },
    { kind = "cart", what = "archer cart (spawns 3 archers)", x = -0.33, y = 5.42, z = -0.72, yaw = 1.9387 },
    { kind = "tower", what = "archer tower (spawns an archer)", x = -4.39, y = -0.95, z = -0.70, yaw = -2.9212 },
    { kind = "tower", what = "archer tower (spawns an archer)", x = 8.68, y = -8.38, z = 0.25, yaw = 2.9109 },
}

-- ==== sites ====
-- Where a camp can stand. `merc_bcamp_site_here` prints one of these rows for wherever
-- you are standing.
mercenaries.BanditCampSites = {
    -- Origin is the layout's first tent, straight from merc_bcamp_dump, so the camp lands
    -- exactly where it was built.
    --
    -- `level` was dumped as "unknown": none of the three level-name bindings answered. It is
    -- pinned to kutnohorsko rather than left blank because a blank matches ANY map, and a
    -- camp is spawned at fixed coordinates - matching the wrong map would drop it into
    -- whatever happens to be at 564,3746 over there. Correct it if this camp is on Trosky.
    { name = "woodland_camp", level = "kutnohorsko", x = 564.17, y = 3746.97, z = 132.10, yaw = 0, layout = "default" },
    -- Also dumped with level "unknown" and pinned to kutnohorsko for the same reason.
    { name = "hillside_camp", level = "kutnohorsko", x = 442.17, y = 2180.63, z = 209.27, yaw = 0, layout = "hillside" },
    { name = "hillfort_camp", level = "kutnohorsko", x = 1413.22, y = 3651.50, z = 96.13, yaw = 0, layout = "hillfort" },
    { name = "ring_camp",     level = "kutnohorsko", x = 2335.58, y = 3508.67, z = 83.23, yaw = 0, layout = "ringcamp" },    { name = "hideout_camp",  level = "kutnohorsko", x = 2092.32, y = 2465.87, z = 181.54, yaw = 0, layout = "hideout" },
    -- Same dump as hideout_camp; this half stood ~150m south, so it gets its own origin.
    { name = "south_camp",    level = "kutnohorsko", x = 2077.27, y = 2314.26, z = 180.54, yaw = 0, layout = "southcamp" },
    { name = "mining_camp",   level = "kutnohorsko", x = 3588.54, y = 1979.04, z = 105.70, yaw = 0, layout = "mining" },
    { name = "roman_fort",    level = "kutnohorsko", x = 1050.21, y = 306.10,  z = 109.04, yaw = 0, layout = "romanfort" },
    { name = "swamp_island",  level = "kutnohorsko", x = 3410.07, y = 256.28,  z = 27.48,  yaw = 0, layout = "swampisland" },
    -- The siege. No layout of its own here: mercenaries_raborsch.lua owns it, and this row
    -- exists only so the contract has a position for the marker and the distance checks.
    { name = "raborsch",      level = "kutnohorsko", x = 1425.57, y = 3871.55, z = 118.13, yaw = 0, layout = "patrol" },
    -- Patrol grounds. These sit on the REAL recorded roads (mercenaries_patrol_routes.lua,
    -- captured in game with the F5-F8 recorder), so a column is met walking a road that
    -- actually goes somewhere instead of pacing a field. `route`+`pt` are the truth;
    -- x/y/z are the resolved point, kept only so the site reads and sorts like any other
    -- and still works if the routes are ever re-recorded shorter. See BanditCampSiteAnchor.
    --
    -- company: mid-map and far from every camp - soldiers where no soldiers should be.
    { name = "patrol_company", level = "kutnohorsko", route = "route3",  pt = 80,
      x = 2293.74, y = 1384.14, z = 107.80, yaw = 0, layout = "patrol" },
    -- convoy: the ore road, ~770m out from the mine the player has just taken.
    { name = "patrol_convoy",  level = "kutnohorsko", route = "route21", pt = 50,
      x = 3108.83, y = 2577.79, z = 101.59, yaw = 0, layout = "patrol" },
    -- looters: west of the southern camp, walking away from it - the unpaid half going home.
    { name = "patrol_looters", level = "kutnohorsko", route = "route2",  pt = 150,
      x = 1315.02, y = 2629.84, z = 174.79, yaw = 0, layout = "patrol" },
}

-- ==== scaling ====

-- How many men will ACTUALLY turn up to the fight. Not _G.MercCount, which is the whole
-- payroll: with a camp standing, most of that roster is asleep in it and the player may walk
-- out with four. Sizing the camp off the payroll then hands those four a twenty-strong band.
-- Same predicate the formation uses, so "who is in the shape behind me" and "who counts" agree.
function mercenaries:BanditCampFollowerCount()
    local n = 0
    for _, ent in pairs(self.ActiveMercs or {}) do
        local wuid = ent and (ent.this and ent.this.id or ent.id)
        if wuid and self:IsAliveAndWell(ent, false) and not self:IsMercInCampProper(wuid)
           and not self:IsCampActor(wuid) then
            n = n + 1
        end
    end
    return n
end

-- ==== Kleinkrieg: the contract run ====
-- One story told almost entirely in numbers (docs/bandit-camp-quest.md): twelve contracts in
-- a fixed order, alternating camps and patrols. Counts scale off the men ACTUALLY following
-- the player via a per-contract ratio, so the company is sometimes the bigger side and
-- sometimes not - the spikes and the dips are the storytelling. A lone player still gets
-- every contract, floored at `min` and capped at 10 on the field instead of 20.
--
-- `accept` / `turnin` are the quartermaster's two lines per contract, shown as info text on
-- taking the job and on payment. `letter` names the Document found on the band's leader;
-- contracts without one close their search objective on the last kill. Raborsch (the story's
-- own climax) slots in between the fort and the swamp when it is built.
mercenaries.KleinkriegContracts = {
    { name = "woodland",   site = "woodland_camp",  group = "looter", ratio = 0.5, min = 3,
      accept = "merc_kk_acc_1",  turnin = "merc_kk_turn_1" },
    { name = "hillside",   site = "hillside_camp",  group = "looter", ratio = 0.7, min = 4,
      leaderClothing = "sigi",
      accept = "merc_kk_acc_2",  turnin = "merc_kk_turn_2" },
    { name = "hillfort",   site = "hillfort_camp",  group = "looter", fixedBase = 3,
      wounded = 0.35, payMult = 0.6,
      accept = "merc_kk_acc_3",  turnin = "merc_kk_turn_3" },
    { name = "company",    site = "patrol_company", group = "sigi",   ratio = 1.1, min = 5,
      archerFrac = 0.15, patrol = true, letter = "TokenIDKKLetter1", payMult = 1.2,
      leaderClothing = "knight", leaderHealthMult = 1.2,
      accept = "merc_kk_acc_4",  turnin = "merc_kk_turn_4" },
    { name = "mine",       site = "mining_camp",    group = "bandit", ratio = 1.2, min = 6,
      archerFrac = 0.15, letter = "TokenIDKKLetter2",
      accept = "merc_kk_acc_5",  turnin = "merc_kk_turn_5" },
    { name = "waystation", site = "ring_camp",      group = "bandit", ratio = 0.9, min = 5,
      archerFrac = 0.2,
      accept = "merc_kk_acc_6",  turnin = "merc_kk_turn_6" },
    { name = "convoy",     site = "patrol_convoy",  group = "sigi",   ratio = 1.4, min = 7,
      archerFrac = 0.15, patrol = true, letter = "TokenIDKKLetter3", payMult = 2.0,
      leaderClothing = "knight", leaderHealthMult = 1.4,
      accept = "merc_kk_acc_7",  turnin = "merc_kk_turn_7" },
    { name = "ambush",     site = "hideout_camp",   group = "sigi",   ratio = 1.3, min = 6,
      archerFrac = 0.25, payMult = 1.3,
      accept = "merc_kk_acc_8",  turnin = "merc_kk_turn_8" },
    { name = "south",      site = "south_camp",     group = "bandit", ratio = 1.6, min = 8,
      archerFrac = 0.1, letter = "TokenIDKKLetter4", payMult = 1.2,
      accept = "merc_kk_acc_9",  turnin = "merc_kk_turn_9" },
    { name = "looters",    site = "patrol_looters", group = "looter", ratio = 0.8, min = 5,
      patrol = true, disperse = true, payMult = 0.8,
      accept = "merc_kk_acc_10", turnin = "merc_kk_turn_10", turninAlt = "merc_kk_turn_10b" },
    { name = "romanfort",  site = "roman_fort",     group = "knight", fixedBase = 4,
      fixedPerMerc = 0.15, archerFrac = 0.2, letter = "TokenIDKKLetter5", payMult = 1.5,
      leaderHealthMult = 1.3,
      accept = "merc_kk_acc_11", turnin = "merc_kk_turn_11" },
    -- THE SIEGE. Not a camp: this one hands off to mercenaries_raborsch.lua, which replays an
    -- authored layout and generates the besiegers from the player's own company. It carries no
    -- letter - what is found here is the place itself.
    { name = "raborsch",   site = "raborsch",       group = "sigi",   ratio = 1.5, min = 10,
      siege = true, payMult = 3.0,
      accept = "merc_kk_acc_13", turnin = "merc_kk_turn_13" },
    { name = "swamp",      site = "swamp_island",   group = "sigi",   ratio = 1.0, min = 6,
      archerFrac = 0.2, letter = "TokenIDKKLetter7", payMult = 1.5,
      leaderClothing = "knight", leaderHealthMult = 1.6,
      accept = "merc_kk_acc_12", turnin = "merc_kk_turn_12" },
}

mercenaries.KleinkriegPerHead = { looter = 55, bandit = 90, sigi = 110, prague = 100,
                                  cuman = 120, knight = 160 }

-- The contract the player is on (during one) or up for (between them).
--
-- A bounty is not part of the arc, so while the bounty slot is bound the "contract in hand"
-- is the descriptor that job built for itself. Everything downstream - BanditCampScale, the
-- letter lookup, the patrol/siege/disperse tests - then reads the right thing without
-- knowing which kind of job it is servicing. An explicit `idx` always means the arc.
function mercenaries:KleinkriegContract(idx)
    if idx == nil and self.BCQ and self.BCQ.kind == "bounty" then
        return self.BCQ.contract or self.BountyContractStub, 0
    end
    local list = self.KleinkriegContracts
    local i = idx or self.BCQ.contractIdx or (self:BanditCampCleared() + 1)
    if i > #list then i = #list end
    if i < 1 then i = 1 end
    return list[i], i
end

function mercenaries:KleinkriegLetterClass()
    local c = self:KleinkriegContract()
    return (c and c.letter and self[c.letter]) or nil
end

function mercenaries:BanditCampScale()
    local c = self:KleinkriegContract()
    local F = self:BanditCampFollowerCount()

    local count
    if c.fixedBase then
        -- The few-but-terrible contracts: a fixed core plus a sliver of scaling.
        count = c.fixedBase + math.floor(F * (c.fixedPerMerc or 0))
    else
        count = math.floor(math.max(1, F) * (c.ratio or 1.0) + 0.5)
    end
    if count < (c.min or 3) then count = c.min or 3 end
    -- Contract sizing is the one the player chose a difficulty for; F (the men who
    -- actually walked out) is the right strength to cap against, not the payroll.
    pcall(function() count = self:DifficultyCount(count, math.max(1, F), c.min or 3) end)
    local cap = (F == 0) and 10 or 20
    pcall(function() cap = self:DifficultyCeil(cap) end)
    if count > cap then count = cap end

    local archers = math.floor(count * (c.archerFrac or 0))
    local reward  = math.floor(count * (self.KleinkriegPerHead[c.group] or 90) * (c.payMult or 1.0))

    return c.group, count, archers, reward
end

-- The recorded points of a named road. Prefers whatever set the level picked, so a patrol
-- contract on a re-recorded map follows the new road; falls back to the Kuttenberg table the
-- sites were authored against. Deliberately does NOT call PatrolRoutesForLevel - that has
-- side effects (it clears LivePatrols on a set switch) and these sites are Kuttenberg-only.
function mercenaries:BanditCampRoutePts(routeName)
    if not routeName then return nil end
    for _, set in ipairs({ self.PatrolRouteData, self.PatrolRoutesKuttenberg }) do
        for _, r in ipairs(set or {}) do
            if r.name == routeName and r.pts and #r.pts > 0 then return r.pts end
        end
    end
    return nil
end

-- Where a site actually is. For a road site the recorded point wins over the cached x/y/z,
-- so re-recording the routes moves the contract with them; the cached values only stand in
-- if the road is gone or has been recorded shorter than the stored index.
function mercenaries:BanditCampSiteAnchor(site)
    if site and site.route then
        local pts = self:BanditCampRoutePts(site.route)
        local pt = pts and pts[site.pt or 1]
        if pt then return { x = pt.x, y = pt.y, z = pt.z } end
        qLog("route '" .. tostring(site.route) .. "' pt " .. tostring(site.pt) ..
             " missing - falling back to the site's stored position")
    end
    return { x = site.x, y = site.y, z = site.z }
end

-- A there-and-back stretch of road for one man: `span` points either side of `at`, then the
-- same points reversed. The patroller cycles its waypoint list, so without the return leg he
-- would march to the far end and then walk the whole way back through every point again.
function mercenaries:BanditCampRoadWalk(routeName, at, span)
    local pts = self:BanditCampRoutePts(routeName)
    if not pts then return nil end
    local lo = math.max(1, at - span)
    local hi = math.min(#pts, at + span)
    if hi - lo < 2 then return nil end
    at = math.max(lo, math.min(hi, at))

    -- The cycle must START where he is standing and head FORWARD. Building it from `lo` sent
    -- the lead man off to the point furthest BEHIND the column first, so he turned round and
    -- walked back through his own men, wrapping them around him.
    -- Every Nth point, not every one. A waypoint is a stop - the Move node ends, the guard
    -- sequence waits, and he sets off again - so taking all of them made the lead man halt
    -- every ten metres. Sampling every third gives him ~30m legs and a steady march.
    local stride = math.max(1, self.BanditCampLeadStride or 3)
    local function P(i) return { x = pts[i].x, y = pts[i].y, z = pts[i].z } end
    local walk = {}
    for i = at, hi, stride do table.insert(walk, P(i)) end
    for i = hi, lo, -stride do table.insert(walk, P(i)) end
    for i = lo, at - 1, stride do table.insert(walk, P(i)) end
    if #walk < 2 then return nil end
    return walk
end

function mercenaries:BanditCampSiteByName(name)
    for _, st in ipairs(self.BanditCampSites) do
        if st.name == name then return st end
    end
    return nil
end

-- ==== the letter in the chest ====
-- Database.sInventoryPreset is how the LEVEL EDITOR fills a Stash, and it did nothing for one
-- spawned from Lua - the chest came up empty. The editor-side helper the vanilla Stash script
-- uses for this (EditorUtil.AssignInventoryToStash) does not exist at runtime either: there is
-- no EditorUtil table in the game's Lua state at all.
--
-- So the letter is pushed straight into the container's own inventory with the same call the
-- mod uses to arm NPCs (see reference_giving_items_to_npcs: inventory:CreateItem, never
-- ItemManager.CreateItem + AddItem, which silently no-ops). A Stash builds its inventory
-- lazily, so this is retried for a few seconds after the chest is placed rather than assumed
-- to work on the first tick, and it VERIFIES by reading the count back.
-- Keep trying for the whole time the camp stands rather than for a fixed few seconds: a
-- container's inventory may not exist until well after SpawnEntity returns, and possibly not
-- until the chest has been streamed in near the player. Cheap - it stops on the first success.
mercenaries.BanditCampStockTries = 600

-- Every route that might work, tried in order, each guarded. Returns how many letters the
-- chest reports holding afterwards, and the name of whatever route reported success.
-- The camp's spoils: coin plus whatever the band had stolen. The chest is verified by
-- reading the money back, because that is the one line guaranteed to be there.
function mercenaries:BanditCampChestInsert(e)
    if not e.inventory then return 0, nil end
    local S = self.BCQ

    local function count(cls)
        local n = 0
        pcall(function() n = e.inventory:GetCountOfClass(cls) or 0 end)
        return n
    end

    local coin = math.max(1, math.floor((S.reward or 0) * self.BanditCampChestShare))
    if count(self.BanditCampMoneyItem) > 0 then return 1, "already stocked" end

    pcall(function() e.inventory:CreateItem(self.BanditCampMoneyItem, 1, coin) end)
    if count(self.BanditCampMoneyItem) <= 0 then return 0, nil end   -- inventory not ready yet

    -- One flavour per chest - craft materials, healing, or gear - so two camps never hold quite
    -- the same haul (mercenaries.KleinkriegRewardPools).
    local rolled = self:KleinkriegRollPool(e.inventory)
    qLog(string.format("chest: %d groschen and %d kind(s) of stock", coin, rolled))
    return 1, "entity.inventory"
end

function mercenaries:BanditCampStockChest()
    local S = self.BCQ
    if S.chestStocked or not S.letterChestId then return end
    S.stockTries = (S.stockTries or 0) + 1

    local n, how = 0, nil
    pcall(function()
        local e = System.GetEntity(S.letterChestId)
        if not e then return end
        n, how = self:BanditCampChestInsert(e)
    end)

    if n > 0 then
        S.chestStocked = true
        qLog("chest stocked (via " .. tostring(how) .. ") after " ..
             tostring(S.stockTries) .. " tr" .. (S.stockTries == 1 and "y" or "ies"))
    elseif S.stockTries >= self.BanditCampStockTries then
        S.chestStocked = true    -- stop retrying
        qLog("gave up stocking the chest after " .. tostring(S.stockTries) ..
             " tries - merc_banditcamp_chest_probe shows what the chest exposes")
    end
end

-- Diagnostics. Prints what the live chest entity actually offers, because the game's Lua
-- state dump only covers global tables and says nothing about an entity instance's members -
-- there is no way to answer this by reading, only by asking the running game.
function mercenaries:BanditCampChestProbe()
    local S = self.BCQ
    if not S.letterChestId then qLog("probe: no chest recorded (is the camp up?)"); return end
    local e = System.GetEntity(S.letterChestId)
    if not e then qLog("probe: chest entity id " .. tostring(S.letterChestId) .. " is gone"); return end

    -- Every read is guarded: this runs against an engine-backed entity whose shape is exactly
    -- what we are trying to discover, and a diagnostic that crashes tells us nothing.
    local function say(label, fn)
        local ok, v = pcall(fn)
        qLog(string.format("  %-26s %s", label, ok and tostring(v) or "<error>"))
    end

    say("name", function() return e:GetName() end)
    for _, k in ipairs({ "inventory", "stash", "actor", "soul", "item", "Properties" }) do
        say("." .. k, function() return type(e[k]) end)
    end
    for _, m in ipairs({ "CreateItem", "GetCountOfClass", "AddItem", "DeleteItemOfClass" }) do
        say(".inventory:" .. m, function() return type(e.inventory[m]) end)
    end
    say("letters in chest", function() return e.inventory:GetCountOfClass(self.TokenIDBanditCampLetter) end)
    say(".stash members", function()
        local keys = {}
        for k, v in pairs(e.stash) do keys[#keys + 1] = k .. "(" .. type(v) .. ")" end
        return #keys > 0 and table.concat(keys, " ") or "<none enumerable>"
    end)
    qLog("  tries so far: " .. tostring(S.stockTries or 0) .. ", stocked=" .. tostring(S.chestStocked))
end

-- Safety net, decided at the moment the camp is cleared. Keyed on whether the chest ACTUALLY
-- holds the letter, not on how many insert attempts have been spent: the retry now runs for
-- as long as the camp stands, so a camp cleared quickly would otherwise finish with the
-- letter neither in the chest nor on the player, and an uncompletable contract.
function mercenaries:BanditCampGrantLetterFallback()
    local S = self.BCQ
    if S.letterGranted then return end
    if self:BanditCampHasLetter() then S.letterGranted = true; return end
    if S.letterOnLeader then return end    -- it is on his body; let them loot it themselves

    S.letterGranted = true
    pcall(function()
        local cls = self:KleinkriegLetterClass() or self.TokenIDBanditCampLetter
        player.inventory:CreateItem(cls, 1, 1)
    end)
    Game.SendInfoText('merc_info_banditcamp_letterbody', false, 0, 5)
    qLog("chest never took the letter - granted it from the leader's body instead")
end

-- ==== alertness ====
-- A camp does not start a fight the moment it can see you. Until it is ALERTED its bandits
-- take no targets at all, and IsValidEnemy (mercenaries_target_selection.lua) checks this
-- same suppression flag before letting a merc claim one of them - it used to rely on the
-- weapon-drawn check for that instead, which UpdateEnemyCache deliberately bypasses when
-- building the merc squad's target cache, so a merc could lock onto a still-docile bandit
-- from outside BanditCampAlertRange and stand there flapping his weapon at a target that
-- would never fight back or alert.
--
-- It wakes up on any of:
--   * a bandit ending up within BanditCampAlertRange of the player or a merc,
--   * any bandit losing health (the player attacked, from any distance),
--   * a bandit dying,
--   * any bandit TAKING one of ours as his target, at any range.
--
-- That last one is the authoritative one and the others are early warnings. A man who has
-- picked the player or a merc to fight has started the battle by definition, and until it
-- existed the camp could be mid-brawl and still read as asleep - which suppresses every
-- one of its members out of the squad's target cache, so the mercs stand and watch.
-- Once alerted it stays alerted for the life of the camp; walking away and coming back
-- rebuilds it, and a rebuilt camp is calm again.
mercenaries.BanditCampAlertRange = 10.0

-- Column geometry. Recorded routes step roughly 10.7m between points, so spacing is converted
-- into point-indices rather than guessed at.
mercenaries.BanditCampColumnSpacing = 4.0
mercenaries.BanditCampRoutePointSpacing = 10.7
-- Route points the column lead skips between stops. 3 x 10.7m gives him ~30m legs.
mercenaries.BanditCampLeadStride = 3

function mercenaries:BanditCampAlertRangeNow()
    return self.BanditCampAlertRange
end

-- Asked by FindEnemyTarget (mercenaries_spawning.lua) and FindStaticArcherTarget before any
-- bandit picks a target. Returns false for everything that is not part of THIS camp, so the
-- mod's other encounters (ambushes, raids, patrols, wall battles) and the player's own tower
-- archers are untouched.
-- Asked from outside the monitor's pass, so it walks every slot rather than trusting the
-- pointer: a bandit of the bounty camp is suppressed by the BOUNTY camp's alert flag.
-- Cheap precondition for the hot path. IsValidEnemy asks about suppression for EVERY nearby
-- NPC on every 300ms combat scan, so in a crowd this runs dozens of times a tick - and the
-- answer is "no camp is suppressing anything" in almost every session. Two table lookups,
-- no allocation, no string. See docs/performance.md "Costs that scale with NPC density".
function mercenaries:BanditCampAnyUnalerted()
    local S = self.BCQ_KK
    if S and S.active and S.spawned and not S.alerted then return true end
    S = self.BCQ_BO
    if S and S.active and S.spawned and not S.alerted then return true end
    return false
end

function mercenaries:BanditCampSuppressed(wuidStr)
    -- Slots walked directly rather than through BanditCampSlots(): that builds a fresh
    -- two-element table on every call, and this is a per-NPC-per-tick path.
    if self:BanditCampSlotSuppresses(self.BCQ_KK, wuidStr) then return true end
    if self:BanditCampSlotSuppresses(self.BCQ_BO, wuidStr) then return true end
    return false
end

function mercenaries:BanditCampSlotSuppresses(S, wuidStr)
    if not (S and S.active and S.spawned) or S.alerted then return false end
    -- BanditCampActors is the mod-wide "belongs to a foreign camp" set, shared with Aleksej's
    -- camps and the siege, so it cannot say WHICH camp. Each slot keeps its own copy, and that
    -- is the one the alert gate has to read.
    if (S.actorSet or {})[wuidStr] then return true end

    -- Towers are checked directly rather than relying on the roster. Their archers arrive on
    -- their own deferred timer and are only registered by the next camp tick, which leaves a
    -- window where a 90m watchtower would already be picking targets. Two towers, so the
    -- scan is trivial.
    for _, st in ipairs(S.towers or {}) do
        local a = st and st.archer
        if a then
            local aid = tostring(a.this and a.this.id or a.id)
            if aid == wuidStr then return true end
        end
    end
    -- Cart archers arrive on their own deferred timer too, so they get the same treatment.
    for _, st in ipairs(S.carts or {}) do
        for _, a in ipairs((st and st.archers) or {}) do
            if a.ent then
                local aid = tostring(a.ent.this and a.ent.this.id or a.ent.id)
                if aid == wuidStr then return true end
            end
        end
    end
    return false
end

-- Wake whichever camp owns this man, from outside the monitor's per-slot pass.
-- BanditCampAlert reads self.BCQ, so the slot has to be bound round it - the pointer is
-- whatever the last bind left behind, and it is usually the wrong camp for a call coming
-- in off the target selector. Returns true if a camp was actually woken.
--
-- BanditCampSlotSuppresses already answers false for a slot that is alerted, inactive or
-- unspawned, so this is a no-op in every case except the one it is for.
function mercenaries:BanditCampAlertFor(wuidStr, why)
    local woke = false
    pcall(function()
        for _, S in ipairs(self:BanditCampSlots()) do
            if self:BanditCampSlotSuppresses(S, wuidStr) then
                self:BanditCampWith(S, function() self:BanditCampAlert(why) end)
                woke = true
            end
        end
    end)
    return woke
end

function mercenaries:BanditCampAlert(why)
    local S = self.BCQ
    if S.alerted then return end
    S.alerted = true
    qLog("camp alerted (" .. tostring(why) .. ")")
end

-- Watches for the three wake-up conditions. Health is sampled per bandit so a hit from any
-- range counts - shooting a sleeping man from a hilltop has to start the fight, or the camp
-- would stand there being picked off.
function mercenaries:BanditCampAlertTick()
    local S = self.BCQ
    if S.alerted or not S.spawned then return end

    S.health, S.missing = S.health or {}, S.missing or {}
    local range = self:BanditCampAlertRangeNow()
    local r2 = range * range

    -- The one band that does not want a fight: the looter column's proximity alarm only arms
    -- when steel is out. A sheathed approach is the disperse path (see BanditCampMonitor).
    local proximityArms = true
    do
        local c = self:KleinkriegContract()
        if c and c.disperse then
            local drawn = false
            pcall(function() drawn = player.human:IsWeaponDrawn() end)
            proximityArms = drawn
        end
    end

    -- Everyone who could be noticed: the player plus the living squad.
    local watchers = {}
    if player then
        local pp; pcall(function() pp = player:GetWorldPos() end)
        if pp then table.insert(watchers, pp) end
    end
    for _, ent in pairs(self.ActiveMercs or {}) do
        if ent and self:IsAliveAndWell(ent, false) then
            local mp; pcall(function() mp = ent:GetWorldPos() end)
            if mp then table.insert(watchers, mp) end
        end
    end

    for _, entId in ipairs(S.bandits or {}) do
        local e = System.GetEntity(entId)
        if e then
            -- soul:GetState('health'), the same reading IsAliveAndWell takes. There is no
            -- actor:GetHealth() in this engine - the actor only exposes GetMaxHealth and
            -- GetHealthRatio - and a wrong name inside a pcall fails silently, which would
            -- have left the whole "shot from range" wake-up dead.
            local hp
            pcall(function() hp = e.soul and e.soul:GetState('health') end)
            if hp then
                local was = S.health[entId]
                if was and hp < was then self:BanditCampAlert("a bandit was hurt"); return end
                S.health[entId] = hp
            end

            -- In a fight. Not gated on proximityArms: the disperse path is about not
            -- STARTING one, and this only fires once one has started.
            --
            -- Two sources, both proven. IsRecentAttacker is the authoritative one - the
            -- behaviour tree's own GetTarget node confirmed this man has taken one of
            -- ours as his target (see NoteAttacker). IsInCombatDanger is vanilla's own
            -- "this soul is in a fight" and catches him a beat earlier. What is NOT used
            -- is soul:GetTarget(), which is not a Lua scriptbind and silently answers no.
            local w = e.this and e.this.id or e.id
            if w and self.IsRecentAttacker and self:IsRecentAttacker(w) then
                self:BanditCampAlert("a bandit took one of ours as his target"); return
            end
            local fighting = false
            pcall(function() fighting = e.soul and e.soul:IsInCombatDanger() or false end)
            if fighting then
                self:BanditCampAlert("a bandit is in a fight"); return
            end

            local bp; pcall(function() bp = e:GetWorldPos() end)
            if bp and proximityArms then
                for _, w in ipairs(watchers) do
                    local dx, dy, dz = bp.x - w.x, bp.y - w.y, bp.z - w.z
                    if (dx * dx + dy * dy + dz * dz) <= r2 then
                        self:BanditCampAlert(string.format("someone came within %.0fm", range))
                        return
                    end
                end
            end
        elseif S.health[entId] and (S.missing[entId] or 0) >= self.BanditCampMissingTicks then
            -- Tracked, and un-findable for long enough to be a real death rather than the
            -- engine briefly dropping the handle - see BanditCampCountDead.
            self:BanditCampAlert("a bandit was killed")
            return
        end
    end
end

-- ==== conversations ====
-- Bandits hold the same real conversations the camp mercs do: camp_actor.xml reads
-- _G.MercCampChats, and they are paired with an alias from the mod's own CampGossipAliases
-- (gossip_merc_*.xml) rather than being left to the vanilla GOSSIP fallback.
--
-- That works because those dialogs are built from HARVESTED VANILLA lines - vanilla roles
-- (GOSSIP_OBECNY_MUZ_1/2) over the 660 oggs in voice/gossip - and because the bandit skald
-- characters already carry the same three voice ids as the mercs (106 / 132 / 239), so the
-- audio resolves for them identically.
mercenaries.BanditCampChatRadius = 4.0
mercenaries.BanditCampMaxChats = 3
mercenaries.BanditCampChatCooldown = 12      -- ticks (this runs on the 1 Hz monitor)
-- Stuck-pair safety, in 1 Hz ticks. NOT CampChatHoldTicks: that one is 72 on a 5s tick
-- (~6 min), and reusing it here would cut a conversation off after 72 seconds - inside the
-- BT's own 5-minute dialog Timeout, so it would kill gossip that was still playing.
mercenaries.BanditCampChatHoldTicks = 360    -- ~6 min, matching the merc camp in real time

function mercenaries:BanditCampChatTick()
    local S = self.BCQ
    if not (S.spawned and S.active) or S.alerted then return end   -- nobody chats mid-fight
    -- A patrol is a column on the march, not a camp: no standing about talking.
    local kc = self:KleinkriegContract()
    if kc and kc.patrol then return end
    _G.MercCampChats = _G.MercCampChats or {}
    local chats = _G.MercCampChats

    S.chatCooldown = S.chatCooldown or {}
    for w, t in pairs(S.chatCooldown) do
        if t <= 1 then S.chatCooldown[w] = nil else S.chatCooldown[w] = t - 1 end
    end

    -- Age out our own pairs. Only role 1 carries the age, so each pair counts once.
    local expired = {}
    for w, c in pairs(chats) do
        if c.foreign and c.role == 1 and c.slot == S.key then
            c.age = (c.age or 0) + 1
            if c.age >= self.BanditCampChatHoldTicks then table.insert(expired, w) end
        end
    end
    for _, w in ipairs(expired) do
        local c = chats[w]
        if c and c.partner then chats[tostring(c.partner)] = nil end
        chats[w] = nil
        S.chatCooldown[w] = self.BanditCampChatCooldown
    end

    local list, active = {}, 0
    for _, c in pairs(chats) do if c.foreign and c.role == 1 then active = active + 1 end end

    for _, entId in ipairs(S.bandits or {}) do
        local e = System.GetEntity(entId)
        if e and self:IsAliveAndWell(e, false) then
            local wuid = e.this and e.this.id or e.id
            local ws = tostring(wuid)
            local busy = self.MercTargetOf and self.MercTargetOf[ws]
            if not chats[ws] and not S.chatCooldown[ws] and not busy then
                local p; pcall(function() p = e:GetWorldPos() end)
                if p then table.insert(list, { wuid = wuid, p = p }) end
            end
        end
    end

    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end

    local r2 = self.BanditCampChatRadius * self.BanditCampChatRadius
    local used = {}
    for i = 1, #list do
        if active >= self.BanditCampMaxChats then break end
        if not used[i] then
            for j = i + 1, #list do
                if not used[j] then
                    local dx, dy = list[i].p.x - list[j].p.x, list[i].p.y - list[j].p.y
                    if (dx * dx + dy * dy) <= r2 then
                        local a, b = list[i].wuid, list[j].wuid
                        -- The mod's own gossip dialogs, same pool the mercs draw from.
                        -- `foreign` marks the pair as ours so the player camp's CampChatTick
                        -- leaves it out of its age-out and its concurrency cap.
                        local aliases = self.CampGossipAliases or {}
                        local alias = (#aliases > 0) and aliases[math.random(#aliases)] or ""
                        chats[tostring(a)] = { partner = b, role = 1, alias = alias, age = 0,
                                               foreign = true, slot = S.key }
                        chats[tostring(b)] = { partner = a, role = 2, alias = alias,
                                               foreign = true, slot = S.key }
                        used[i], used[j] = true, true
                        active = active + 1
                        break
                    end
                end
            end
        end
    end
end

-- Drops this camp's conversations only: with two camps standing, wiping every foreign pair
-- would silence the other one every time this camp unloaded.
function mercenaries:ClearBanditCampChats()
    local chats = _G.MercCampChats
    if not chats then return end
    local key = self.BCQ and self.BCQ.key
    for w, c in pairs(chats) do
        if c and c.foreign and (key == nil or c.slot == nil or c.slot == key) then chats[w] = nil end
    end
end

-- ==== gear ====
-- A camp of twelve drawing on one group's ten outfits reads as a uniform, and half of them
-- are wearing the same thing. These are the pools the mod already ships (docs/enemies.md) -
-- looters and bandits are both ragged outlaws, and Sigismund's men are plausible as gear
-- stripped off bodies - so the camp dresses from all three instead of one.
mercenaries.BanditCampClothingGroups = { "bandit", "looter", "sigi" }

-- What this band wears. The contract's OWN group, so looters look like looters: merging
-- bandit+looter+sigi into one pool was meant to stop the camps looking uniform, but it put a
-- third of every ragged band in Sigismund's and Kuttenberg's colours - which also spoiled the
-- one place that livery is supposed to mean something, on the hillside leader.
-- Each group carries 9-12 presets of its own, which is variety enough.
function mercenaries:BanditCampClothingPool(group)
    group = group or self.BCQ.group
    local grp = group and self.EnemyGroups[group]
    if grp and grp.clothing and #grp.clothing > 0 then return grp.clothing end

    -- Only if a group somehow has no wardrobe of its own.
    if self._bcampClothes then return self._bcampClothes end
    local pool = {}
    for _, key in ipairs(self.BanditCampClothingGroups) do
        local g = self.EnemyGroups[key]
        for _, guid in ipairs((g and g.clothing) or {}) do table.insert(pool, guid) end
    end
    self._bcampClothes = pool
    return pool
end

-- Re-dress one bandit from the wide pool, and give him his own melee loadout. EquipEnemy
-- has already run inside SpawnEnemyAt; this only widens what it drew from.
-- `outfitGuid` pins the clothing instead of rolling for it - used by the tower descent, where
-- the replacement has to be wearing what the archer on the platform was wearing.
function mercenaries:BanditCampDressUp(ent, isArcher, outfitGuid)
    if not (ent and ent.actor) then return end
    local guid = outfitGuid
    if not guid then
        local pool = self:BanditCampClothingPool()
        if #pool > 0 then guid = pool[math.random(1, #pool)] end
    end
    if guid then
        pcall(function() ent.actor:EquipClothingPreset(guid) end)
    end
    -- Archers keep the bow: EquipMercenaryWeapon routes '_archer_' names to the bow set and
    -- would only re-roll the same thing. Preset 1 is the "random category" path, so each
    -- footman gets a fresh sword/axe/mace/polearm pick rather than the group default.
    if not isArcher then
        pcall(function() self:EquipMercenaryWeapon(ent, 1, nil) end)
    end
end

-- ==== the camp ====

-- Resolve a dumped label back to the builder's catalogue entry, so a layout stays in sync
-- with the editor that produced it instead of duplicating its model paths.
function mercenaries:BanditCampItemFor(label)
    for _, cat in ipairs(self:BCampCatalogue() or {}) do
        for _, it in ipairs(cat.items or {}) do
            if it.label == label then return it end
        end
    end
    return nil
end

-- Place one layout row. Returns "seat" / "bed" for the pieces an NPC can use, so the
-- caller can pool them.
function mercenaries:BanditCampPlaceRow(row, origin, yawBase, ents)
    local it = self:BanditCampItemFor(row.what)
    if not it then qLog("unknown piece '" .. tostring(row.what) .. "' - skipped"); return nil end

    -- Rotate the layout about its origin so a camp can face any direction.
    local c, s = math.cos(yawBase), math.sin(yawBase)
    local pos = {
        x = origin.x + (row.x * c - row.y * s),
        y = origin.y + (row.x * s + row.y * c),
        z = origin.z + (row.z or 0),
    }
    local yaw = (row.yaw or 0) + yawBase

    if it.fire then
        -- Own name and own tracking list: "MercCamp*" is swept globally by name whenever the
        -- player's camp is rebuilt, which would take this camp's fire with it.
        pcall(function() self:SpawnCampFirePrefab(pos, 0, nil, "BCampQFire_", ents) end)
        return nil

    elseif it.stash then
        -- A real lootable container, not a prop - the bandits' spoils. Mirrors BCampPlace.
        -- It holds coin and stock only (BanditCampChestInsert). It used to be filled from an
        -- InventoryPreset carrying the letter as well; the letter moved onto the leader's
        -- body, and the preset went on quietly adding a second contract-less copy to every
        -- camp. The first chest is still TRACKED, because the test commands poke at it.
        local S = self.BCQ
        local withLetter = not S.letterChestPlaced
        pcall(function()
            local props = { object_Model = it.stash, bSaved_by_game = false }
            local e = System.SpawnEntity({
                class = "Stash",
                name = "BCampQChest_" .. tostring(math.random(100000, 999999)),
                position = self:CampSnapToGround(pos),
                orientation = { x = math.cos(yaw), y = math.sin(yaw), z = 0 },
                properties = props,
            })
            if e then
                pcall(function() e:SetAngles({ x = 0, y = 0, z = yaw }) end)
                table.insert(ents, e.id)
                if withLetter then
                    S.letterChestPlaced = true
                    S.letterChestId = e.id
                    qLog("letter chest placed")
                end
            end
        end)
        return nil

    elseif it.so then
        local wuid, soPos = self:SpawnCampFurnitureSO(it.model, pos, yaw, "BCampQFurn", it.so, nil, ents)
        if wuid then
            return (it.so == self.CampBedSO) and "bed" or "seat", wuid, soPos
        end
        return nil

    elseif it.model then
        self:SpawnCampPropModel(it.model, pos, yaw, "BCampQProp", ents)
        -- A mesh emits nothing by itself: the "(light)" variants carry a Light entity too,
        -- and without this the camp's lamps are dark props.
        if it.light then
            pcall(function()
                local e = System.SpawnEntity({
                    class = "Light",
                    name = "BCampQLight_" .. tostring(math.random(100000, 999999)),
                    position = { x = pos.x, y = pos.y, z = pos.z + (it.lightZ or 1.0) },
                    properties = it.light,
                })
                if e then table.insert(ents, e.id) end
            end)
        end
        return nil

    elseif string.find(row.what, "HOUSE", 1, true) then
        -- The hut: shell, foundation, invisible collider walls and a bed. It spawns its own
        -- props (no borrowing), so it only needs its own NAME and its own tracking list -
        -- "MercCamp*" is swept globally by name and CampEntities is what BreakMercCamp
        -- empties, so the player rebuilding their camp would otherwise level this one.
        -- Deliberately skipped. The hut is the PLAYER's upgrade; standing one in a bandit
        -- camp read as the player's own house misplaced in the woods. The layout row is kept
        -- so the site still reads the same if it is ever wanted back.
        return nil

    elseif string.find(row.what, "smithy", 1, true) then
        self:SpawnBanditCampBorrowed("smithy", pos, yaw)
        return nil

    elseif string.find(row.what, "alchemy", 1, true) then
        self:SpawnBanditCampBorrowed("alchemy", pos, yaw)
        return nil

    elseif it.station == "cart" then
        -- A bandit archer cart: three enemy archers on a wagon, same "hostile" mode and
        -- enemy souls as the watchtowers.
        local st = self:SpawnArcherCart(pos, yaw, { mode = "hostile", group = self.BCQ.group or "bandit" })
        if st then return "cart", st end
        qLog("archer cart refused (cap reached - ArcherCartMax)")
        return nil

    elseif self.BanditCampStations[row.what] then
        -- Matched by label, not by a catalogue flag: the builder's entries for these point at
        -- the player-camp spawners, which own singleton state. The bandit camp replays their
        -- layouts into its own lists instead - see BanditCampStations.
        self:SpawnBanditCampStation(row.what, pos, yaw, ents)
        return nil

    elseif it.station == "tower" then
        -- A bandit watchtower: same structure as the player's, but its archer is dressed as
        -- one of the camp's own and runs in "hostile" mode, so he shoots the player and the
        -- mercs. Returned so the caller can track the station for teardown.
        local st = self:SpawnTowerStation(pos, yaw, { mode = "hostile", group = self.BCQ.group or "bandit" })
        if st then return "tower", st end
        qLog("tower refused (cap reached - TowerMaxCount) at " .. string.format("%.1f,%.1f", pos.x, pos.y))
        return nil
    end

    -- Upgrades and archer carts are player-camp structures with singleton state; see the
    -- commented-out rows in BanditCampLayouts.default for why they are not replayed.
    qLog("piece '" .. tostring(row.what) .. "' is a camp structure, not a prop - skipped")
    return nil
end

-- Camp UPGRADES, replayed for a camp that is not the player's.
--
-- The upgrade spawners themselves cannot be reused: each sets a singleton (self.CampInn,
-- self.CampFoodCart, self.CampHunt), needs self.CampCenter, and pushes anything sittable into
-- the PLAYER's CampSeats pool - so a bandit camp built through them fights the player's own
-- upgrades. What IS reusable is their LAYOUT TABLES, which all share one shape:
-- { n = name, m = model, fwd, lat, up, rx, ry, rz }. So the layout is replayed here into the
-- bandit camp's own entity and seat lists, and nothing else is touched.
mercenaries.BanditCampStations = {
    ["makeshift inn"]  = { layout = "InnStationLayout",     seat = "^stool", so = "InnChairSO" },
    ["food cart"]      = { layout = "CampFoodCartLayout" },
    ["hunter's spot"]  = { layout = "HuntStationLayout",    seat = "^chair", so = "CampChairSO" },
}

-- Upgrades that BORROW a real object from the world rather than spawning props: the smithy
-- takes a village Smithery, the alchemy bench an AlchemyTable, and each is MOVED to the camp.
-- Both search loaded entities, not nearby ones, so the camp's distance from a settlement does
-- not matter - the "(needs X nearby)" in the builder's labels is its wording, not a rule.
--
-- Two things have to be handled or they misbehave: the authored spot is pinned by seeding the
-- station tile first (called cold they scan for their own flattest patch and wander metres
-- off), and the record is then taken off the player-camp singleton into this camp's state, so
-- the two camps do not share one slot and neither teardown restores the other's loan.
mercenaries.BanditCampBorrowed = {
    smithy  = { tile = "forge",   spawn = "SpawnCampForge",   despawn = "DespawnCampForge",
                slot = "CampForge",   what = "Smithery" },
    alchemy = { tile = "alchemy", spawn = "SpawnCampAlchemy", despawn = "DespawnCampAlchemy",
                slot = "CampAlchemy", what = "AlchemyTable" },
}

function mercenaries:SpawnBanditCampBorrowed(key, pos, yaw)
    local spec = self.BanditCampBorrowed[key]
    if not spec then return false end
    local S = self.BCQ
    S.borrowed = S.borrowed or {}
    if S.borrowed[key] then return true end

    if self[spec.slot] then
        qLog(key .. " skipped: the player's own camp is already borrowing the world's " .. spec.what)
        return false
    end

    self.CampStationTiles = self.CampStationTiles or {}
    local had = self.CampStationTiles[spec.tile] ~= nil
    local restore = self.CampStationTiles[spec.tile]
    self.CampStationTiles[spec.tile] = { x = pos.x, y = pos.y, z = pos.z, ang = yaw }

    local built = false
    pcall(function() built = self[spec.spawn](self, pos) end)

    if had then self.CampStationTiles[spec.tile] = restore
    else self.CampStationTiles[spec.tile] = nil end

    if built and self[spec.slot] then
        S.borrowed[key] = self[spec.slot]
        self[spec.slot] = nil          -- release the slot; the player can still build theirs
        qLog(key .. " built - a village " .. spec.what .. " is on loan to the camp")
        return true
    end
    qLog(key .. " not built - no loaded " .. spec.what .. " to borrow")
    return false
end

-- Gives every borrowed object back. This MUST run whenever the camp comes down: they are real
-- world objects that were moved, not props we spawned, and deleting them instead would strand
-- a village's anvil or alchemy table at a dead bandit camp.
function mercenaries:DespawnBanditCampBorrowed()
    local S = self.BCQ
    for key, rec in pairs(S.borrowed or {}) do
        local spec = self.BanditCampBorrowed[key]
        if spec and rec then
            local saved = self[spec.slot]
            self[spec.slot] = rec
            pcall(function() self[spec.despawn](self) end)
            self[spec.slot] = saved
        end
    end
    S.borrowed = {}
end

function mercenaries:SpawnBanditCampStation(label, spot, ang, ents)
    local spec = self.BanditCampStations[label]
    if not spec then return false end
    local layout = self[spec.layout]
    if not layout then qLog("no layout '" .. tostring(spec.layout) .. "' for " .. label); return false end
    return self:BanditCampReplayStation(layout, spot, ang, ents, spec.seat, spec.so and self[spec.so], label)
end

function mercenaries:BanditCampReplayStation(layout, spot, ang, ents, seatPat, seatSO, label)
    local S = self.BCQ
    local F   = { x = math.cos(ang), y = math.sin(ang) }
    local Lft = { x = -F.y, y = F.x }
    local function wp(L)
        return { x = spot.x + F.x * L.fwd + Lft.x * L.lat,
                 y = spot.y + F.y * L.fwd + Lft.y * L.lat,
                 z = spot.z + (L.up or 0) }
    end

    -- Seats face squarely across their table rather than at its centre, and only the ones
    -- whose table is behind them get flipped - the same rule the real tavern uses, and the
    -- reason its stools do not all skew inward by different amounts.
    local tables = {}
    for _, L in ipairs(layout) do
        if tostring(L.n):match("table") then table.insert(tables, wp(L)) end
    end
    local function nearestTable(w)
        local best, bd
        for _, t in ipairs(tables) do
            local d = (t.x - w.x) ^ 2 + (t.y - w.y) ^ 2
            if not bd or d < bd then best, bd = t, d end
        end
        return best or spot
    end

    local seats = 0
    for _, L in ipairs(layout) do
        local w = wp(L)
        if seatPat and seatSO and tostring(L.n):match(seatPat) then
            local tgt = nearestTable(w)
            local toward = (tgt.x - w.x) * F.x + (tgt.y - w.y) * F.y
            local soAng = ang + math.rad(self.InnSeatYawFixDeg or 0)
            if toward < 0 then soAng = soAng + math.pi end
            local wuid, soPos = self:SpawnCampFurnitureSO(L.m, w, soAng, "BCampQStationSeat", seatSO, nil, ents)
            if wuid then
                table.insert(S.seats, { wuid = wuid, pos = soPos, firePos = spot, tavern = true })
                seats = seats + 1
            end
        else
            local e
            pcall(function()
                e = System.SpawnEntity({ class = "BasicEntity",
                    name = "BCampQStation_" .. tostring(math.random(100000, 999999)),
                    position = w,
                    properties = { object_Model = L.m, bMissionCritical = false,
                                   bSaved_by_game = false, bSerialize = false } })
            end)
            if e then
                pcall(function() e:SetAngles({ x = math.rad(L.rx or 0), y = math.rad(L.ry or 0),
                                               z = ang + math.rad(L.rz or 0) }) end)
                table.insert(ents, e.id)
            end
        end
    end
    qLog(string.format("station '%s' built (%d piece(s), %d seat(s))", tostring(label), #layout, seats))
    return true
end

function mercenaries:SpawnBanditCampLayout(site)
    local layout = self.BanditCampLayouts[site.layout or "default"]
    if not layout then qLog("no layout '" .. tostring(site.layout) .. "'"); return end

    local S = self.BCQ
    S.entities = S.entities or {}
    S.seats = {}
    S.beds  = {}

    S.towers, S.carts = {}, {}
    local origin = self:CampSnapToGround(self:BanditCampSiteAnchor(site))
    for _, row in ipairs(layout) do
        local kind, wuid, soPos = self:BanditCampPlaceRow(row, origin, site.yaw or 0, S.entities)
        if kind == "seat" then
            table.insert(S.seats, { wuid = wuid, pos = soPos, firePos = origin })
        elseif kind == "bed" then
            table.insert(S.beds, { wuid = wuid, pos = soPos })
        elseif kind == "tower" then
            table.insert(S.towers, wuid)   -- the station record
        elseif kind == "cart" then
            table.insert(S.carts, wuid)
        end
    end
    qLog(string.format("layout '%s': %d entities, %d seats, %d beds, %d towers",
         tostring(site.layout or "default"), #S.entities, #S.seats, #S.beds, #S.towers))
end

-- Ring of standing spots around the fire, used for the walk-about activities.
local function ringPos(origin, i, n, radius)
    local a = (i - 1) * (2 * math.pi / math.max(1, n))
    return { x = origin.x + math.cos(a) * radius, y = origin.y + math.sin(a) * radius, z = origin.z }
end

-- The leader is the quest's MAP MARKER ANCHOR, and a marker bound to a soul with no live
-- NPC points at nothing - so he is spawned the moment the contract is taken and kept alive
-- for its whole life, even while the rest of the camp is unloaded. Spawning him with the
-- band instead meant the marker only appeared once the player was already at the camp,
-- which is the one moment they no longer need it.
--
-- He is not respawned once he has been killed (S.leaderDead), and the death count only runs
-- while the camp is loaded, so a streamed-out leader is never mistaken for a dead one.
function mercenaries:BanditCampEnsureLeader()
    local S = self.BCQ
    if not (S.active and S.site) or S.cleared or S.leaderDead then return end

    if S.leaderId then
        local e = System.GetEntity(S.leaderId)
        if e then return end     -- still standing
    end

    local origin = self:CampSnapToGround(self:BanditCampSiteAnchor(S.site))
    -- Each camp gets its OWN leader soul. A SoulAsset marker resolves to whichever NPC
    -- carries the guid, so two leaders sharing one soul would leave both quests' markers
    -- pointing at an arbitrary one of them.
    local soul = S.leaderSoul or self.BanditCampLeaderSoul
    local name = "SpawnedEnemy_banditcampleader_strong_" ..
                 tostring(math.random(10000, 99999)) .. "_" .. soul
    local leader
    pcall(function()
        System.SpawnEntity({
            class = "NPC",
            name = name,
            position = { x = origin.x, y = origin.y + 3.2, z = origin.z },
            orientation = { x = 0, y = 0, z = S.site.yaw or 0 },
            properties = { guidSharedSoulId = soul },
        })
        leader = System.GetEntityByName(name)
        if leader then
            self:EquipEnemy(leader, S.group or "bandit", false)
            local c = self:KleinkriegContract()
            if c and c.leaderClothing then
                -- Story gear: the hillside leader in Sigismund's scraps, the captain in
                -- knight's kit. Clothing only - the soul underneath stays the leader.
                local grp = self.EnemyGroups[c.leaderClothing]
                local pool = (grp and grp.clothing) or {}
                if #pool > 0 then
                    local g = pool[math.random(#pool)]
                    pcall(function() leader.actor:EquipClothingPreset(g) end)
                end
            else
                self:BanditCampDressUp(leader, false)
            end
            if c and c.leaderHealthMult and leader.actor then
                pcall(function()
                    local m = leader.actor:GetMaxHealth()
                    if m and m > 0 then
                        leader.actor:SetMaxHealth(m * c.leaderHealthMult)
                        leader.actor:SetHealth(m * c.leaderHealthMult)
                    end
                end)
            end
        end
    end)

    if leader then
        S.leaderId = leader.id
        -- The contract's letter rides on the man himself - when it carries one at all.
        local cls = self:KleinkriegLetterClass()
        if cls then
            pcall(function() leader.inventory:CreateItem(cls, 1, 1) end)
            local n = 0
            pcall(function() n = leader.inventory:GetCountOfClass(cls) or 0 end)
            S.letterOnLeader = (n > 0)
            qLog("letter on the leader: " .. tostring(S.letterOnLeader))
        else
            S.letterOnLeader = false
        end
        -- Only counts as one of the band once the camp is actually up; while the player is
        -- far away he is just the marker's anchor. Membership is checked because this runs
        -- before the death count each tick, so a leader replaced mid-camp would otherwise be
        -- listed twice and inflate the living headcount.
        if S.spawned then
            local listed = false
            for _, id in ipairs(S.bandits or {}) do if id == leader.id then listed = true; break end end
            if not listed then table.insert(S.bandits, leader.id) end
        end
        qLog("camp leader up - the map marker has its anchor")
    else
        qLog("leader failed to spawn - there will be no map marker")
    end
end

-- `count` is the TOTAL that should be standing, leader included - it has to match what
-- BanditCampCountDead measures against S.target, or the contract closes a body early.
function mercenaries:SpawnBanditCampBand(site, group, count, archers, withLeader)
    local S = self.BCQ
    S.bandits = S.bandits or {}
    if count <= 0 then return end
    local origin = self:CampSnapToGround(self:BanditCampSiteAnchor(site))

    -- A patrol contract meets a column on the march: string the band out along the recorded
    -- road, a couple of points apart and alternating sides of the centreline, instead of
    -- bunching them into the ring a camp uses.
    local kcSpawn = self:KleinkriegContract()
    local roadPts = (kcSpawn and kcSpawn.patrol) and self:BanditCampRoutePts(site.route) or nil
    local function bandPos(i, n)
        if roadPts then
            -- A COLUMN: about four metres between men, measured along the road, so a band of
            -- seven takes up ~25m of it and the lead man is at the anchor. Spreading them
            -- across a fixed 85m window (what this did) scattered them so far apart they read
            -- as separate groups, and the back was still walking up while the front died.
            -- MINUS: the leader stands on the anchor and everyone else falls in BEHIND him.
            -- Placing them forward of it put him at the back of his own column, so the moment
            -- he set off he walked straight through his men - which is what "wrong direction,
            -- wrapping the column around him" actually was.
            local step = (self.BanditCampColumnSpacing or 4.0)
                       / (self.BanditCampRoutePointSpacing or 10.7)
            local at = (site.pt or 1) - math.floor((i - 1) * step + 0.5)
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
        return ringPos(origin, i, n, 3.2)
    end

    local spawned = 0

    -- The leader already exists (BanditCampEnsureLeader put him there when the contract was
    -- taken); he just joins the roster now that the camp is up.
    if withLeader and S.leaderId and System.GetEntity(S.leaderId) then
        table.insert(S.bandits, S.leaderId)
        spawned = 1
    end

    -- Archers are counted among the NON-leader spawns: the leader is always melee
    -- (EquipEnemy above passes isArcher=false), so testing the raw loop index would give
    -- one archer fewer on every build that includes him - and zero when archers == 1.
    local made = 0
    for i = spawned + 1, count do
        made = made + 1
        local isArcher = (made <= archers)
        local ent = self:SpawnEnemyAt(group, isArcher, bandPos(i, count), site.yaw or 0)
        if ent then
            self:BanditCampDressUp(ent, isArcher)
            local kc = self:KleinkriegContract()
            if kc and kc.wounded and ent.actor then
                -- Survivors of something: they start the fight already hurt.
                pcall(function()
                    local m = ent.actor:GetMaxHealth()
                    if m and m > 0 then ent.actor:SetHealth(m * kc.wounded) end
                end)
            end
            table.insert(S.bandits, ent.id)
        end
    end

    self:AssignBanditCampRoles(origin)
    qLog(string.format("%d %s standing (%d archers, leader=%s)",
         #S.bandits, tostring(group), archers, tostring(withLeader)))
end

-- Hand every bandit a camp role. This is the same WUID-keyed contract the merc camp uses
-- (docs/ai-modules.md): the enemy schedulers already fire `camp_actor` for anyone holding
-- one, and drop it for combat the moment they acquire a target.
function mercenaries:AssignBanditCampRoles(origin)
    local S = self.BCQ
    S.roleIdx, S.nextRotate = {}, {}

    local kc   = self:KleinkriegContract()
    local site = S.site or {}
    local prevWuid = nil

    local i = 0
    for _, entId in ipairs(S.bandits) do
        local ent = System.GetEntity(entId)
        local wuid = ent and XGenAIModule.GetMyWUID(ent)
        if wuid then
            local ws = tostring(wuid)
            i = i + 1
            self.BanditCampActors[ws] = true
            S.actorSet[ws] = true
            S.spots = S.spots or {}
            S.spots[ws] = { actPos = ringPos(origin, i, #S.bandits, 4.5), firePos = origin }

            -- A couple of them walk the perimeter instead of loafing by the fire. The
            -- waypoints are kept on the spot record too, because the shared camp tables get
            -- REPLACED wholesale whenever the player's own camp is broken or rebuilt - see
            -- BanditCampRepairRoles.
            if kc and kc.patrol then
                -- A COLUMN, not a scattered picket. One man walks the recorded road and the
                -- rest fall in behind him, each following the man ahead, so they travel and
                -- arrive as a unit. Handing every man his own slice of road (what this did
                -- before) let them drift apart and trickle into the fight one at a time.
                if prevWuid == nil then
                    local wps = site.route and self:BanditCampRoadWalk(site.route, site.pt or 1, 14) or nil
                    if not wps then
                        wps = {}
                        for k = 1, 8 do table.insert(wps, ringPos(origin, k, 8, 14.0)) end
                    end
                    S.spots[ws].patrol = wps
                    self:BanditCampSetPatrol(ws, wps)
                    -- He is marching, not standing a post: no sentry pause at each waypoint.
                    if self.CampPatrollers[ws] then self.CampPatrollers[ws].noPause = true end
                    S.spots[ws].noPause = true
                    S.columnLead = ws
                else
                    self.BanditCampColumn[ws] = prevWuid
                    S.spots[ws].column = tostring(prevWuid)
                end
                prevWuid = wuid
            elseif i % 5 == 0 then
                local wps = {}
                for k = 1, 6 do table.insert(wps, ringPos(origin, k, 6, 9.0)) end
                S.spots[ws].patrol = wps
                self:BanditCampSetPatrol(ws, wps)
            else
                self:ApplyBanditCampRole(ws, self.BanditCampRoleCycle[(i % #self.BanditCampRoleCycle) + 1])
            end
        end
    end
end

mercenaries.BanditCampRoleCycle = { "sit", "eat", "sleep", "snooze", "herbs" }

-- Bandit-camp equivalent of ApplyCampRole. Deliberately separate: the merc version reads
-- CampMercSpots and the player camp's shared seat/bed pools, both of which belong to a
-- camp that may not even be standing.
function mercenaries:ApplyBanditCampRole(ws, role)
    local S = self.BCQ
    local s = S.spots and S.spots[ws]
    if not s then return end

    self.CampFurniture[ws]  = nil
    self.CampActivities[ws] = nil
    if role ~= "sit" and role ~= "snooze" then self:ReleaseSpot(S.seats or {}, ws) end
    if role ~= "sleep" then self:ReleaseSpot(S.beds or {}, ws) end

    local from = s.lastPos or s.actPos

    if role == "sleep" then
        local bed = self:ClaimSpot(S.beds or {}, ws, from)
        if bed then
            self.CampFurniture[ws] = { wuid = bed.wuid, kind = "bed", pos = bed.pos }
            s.lastPos = bed.pos
        end
    elseif role == "sit" then
        local seat = self:ClaimSpot(S.seats or {}, ws, from)
        if seat then
            self.CampFurniture[ws] = { wuid = seat.wuid, kind = "chair", pos = seat.pos, facePos = seat.firePos }
            s.lastPos = seat.pos
        end
    elseif role == "snooze" then
        local seat = self:ClaimSpot(S.seats or {}, ws, from, true)
        if seat then
            self.CampActivities[ws] = { unstance = "camper_snooze", mode = 1, pos = seat.pos, locWuid = seat.wuid, facePos = seat.firePos }
            s.lastPos = seat.pos
        end
    elseif role == "eat" then
        self.CampActivities[ws] = { unstance = "eating_standing", mode = 2, pos = s.actPos, facePos = s.firePos }
        s.lastPos = s.actPos
    elseif role == "herbs" then
        self.CampActivities[ws] = { unstance = "PickingHerbsNPC", mode = 2, pos = s.actPos, facePos = s.firePos }
        s.lastPos = s.actPos
    end
end

-- `index`, not `idx`: GetPatrolWaypoint reads rec.waypoints[rec.index] and
-- AdvancePatrolWaypoint steps rec.index. `foreign` is what keeps the wall navmesh
-- (NavRefreshPatrolRings) from re-pointing these at the PLAYER camp's gate posts.
-- Read by camp_actor's column arm every cycle. Sets followTarget to the man ahead and clears
-- it the moment the column is gone, which is what ends the CrimeFollower node.
function mercenaries:ColumnFollowRole(data, entity)
    -- NEVER assign nil to data.followTarget. It is a declared _wuid BT variable, and writing
    -- nil into one fails the ExecuteLua node - which fails the enclosing Sequence, which kills
    -- the whole role-refresh loop for EVERY camp actor, merc and bandit alike. They all just
    -- stand there. Clear the bool and return, exactly as PatrolFollowRole does.
    data.stillFollowing = false
    data.inColumn = false

    local w = entity and entity.this and entity.this.id
    if not w then return end
    local t = self:GetColumnFollowTarget(w)
    if not t then return end

    -- The man ahead may already be dead; walk up the chain to the first one still standing so
    -- the column closes up instead of trailing along behind a corpse.
    local hops = 0
    while hops < 12 do
        local alive = false
        pcall(function()
            local e = XGenAIModule.GetEntityByWUID(t)
            alive = (e ~= nil) and self:IsAliveAndWell(e, true)
        end)
        if alive then break end
        local nxt = self:GetColumnFollowTarget(t)
        if not nxt or nxt == t then return end
        t, hops = nxt, hops + 1
    end
    if hops >= 12 then return end

    data.followTarget   = t
    data.columnTarget   = t
    data.stillFollowing = true
    data.inColumn       = true
end

function mercenaries:BanditCampSetPatrol(ws, wps)
    self.CampPatrollers[ws] = { waypoints = wps, index = 1, foreign = true }
end

-- CampFurniture / CampActivities / CampPatrollers are shared with the player's camp, and
-- breaking, rebuilding or recalling that camp REPLACES all three tables outright (a dozen
-- sites in mercenaries_camp.lua). That silently strips every bandit of its camp role and
-- drops the whole camp out of camp_actor into a standing idle, with nothing to put it back.
-- Cheap insurance: notice the role is missing and re-assert it.
function mercenaries:BanditCampRepairRoles()
    local S = self.BCQ
    for ws, s in pairs(S.spots or {}) do
        -- Column followers need no repair: BanditCampColumn is the mod's own table and is
        -- never one of the shared camp tables the player's camp replaces wholesale.
        if s.column then           -- nothing to do
        elseif s.patrol then
            if not self.CampPatrollers[ws] then
                self:BanditCampSetPatrol(ws, s.patrol)
                if s.noPause and self.CampPatrollers[ws] then
                    self.CampPatrollers[ws].noPause = true
                end
            end
        elseif not (self.CampFurniture[ws] or self.CampActivities[ws]) then
            -- Force this one to rotate on the next pass rather than guessing its old role.
            S.nextRotate[ws] = 0
        end
    end
end

function mercenaries:RotateBanditCampRoles()
    local S = self.BCQ
    if not (S.active and S.spawned) then return end
    S.ticks = (S.ticks or 0) + 1
    S.nextRotate = S.nextRotate or {}
    self:BanditCampRepairRoles()
    for ws in pairs(S.spots or {}) do
        -- Perimeter walkers keep walking; only the loafers rotate.
        if not self.CampPatrollers[ws] and S.ticks >= (S.nextRotate[ws] or 0) then
            local cycle = self.BanditCampRoleCycle
            local idx = ((S.roleIdx[ws] or 0) % #cycle) + 1
            S.roleIdx[ws] = idx
            self:ApplyBanditCampRole(ws, cycle[idx])
            S.nextRotate[ws] = S.ticks + math.random(12, 40)
        end
    end
end

-- ==== lifecycle ====

-- Two contracts can be live at the same time: the Kleinkrieg arc and the quartermaster's
-- repeatable bounty (mercenaries_bounty.lua). Rather than thread a state table through the
-- two dozen functions in this file that all open with `local S = self.BCQ`, self.BCQ is a
-- SLOT POINTER: BanditCampWith binds it to one camp for the length of that camp's work and
-- puts it back afterwards, so everything below keeps reading self.BCQ and is unchanged.
--
-- Anything reached from OUTSIDE that pass - BanditCampSuppressed off the target selector,
-- the accept and hand-in tokens, the console commands - must not trust whatever the last
-- bind left behind. Those either pin their own slot or walk BanditCampSlots().
local function newCampState(key)
    return {
        key = key,           -- slot name, and the suffix on its save tag
        kind = key,          -- "kk" (the arc) or "bounty"
        active = false,      -- contract taken and not yet paid out
        spawned = false,     -- camp is physically standing
        site = nil,
        killed = 0,
        target = 0,
        group = nil,
        reward = 0,
        entities = {},
        bandits = {},
        actorSet = {},       -- this camp's own members, keyed by wuid string
    }
end

mercenaries.BCQ_KK = mercenaries.BCQ_KK or newCampState("kk")
mercenaries.BCQ_BO = mercenaries.BCQ_BO or newCampState("bounty")
-- The bound slot. Rests on the arc, which is what every caller that does not say otherwise
-- means by "the contract".
mercenaries.BCQ = mercenaries.BCQ_KK

function mercenaries:BanditCampSlots()
    return { self.BCQ_KK, self.BCQ_BO }
end

-- Bind S for the length of fn, and put the pointer back whatever happens inside: a slot left
-- bound after an error would hand the next caller the wrong camp.
function mercenaries:BanditCampWith(S, fn)
    local prev = self.BCQ
    self.BCQ = S
    local ok, err = pcall(fn)
    self.BCQ = prev
    if not ok then qLog("slot '" .. tostring(S and S.key) .. "': " .. tostring(err)) end
    return ok
end

-- How many contracts have been finished. Persisted separately from the contract itself,
-- because it has to outlive each one - it is what makes the camps a PROGRESSION.
function mercenaries:BanditCampCleared()
    -- Cached: this is read every monitor tick, and LoadString logs a line each time - the run
    -- was re-reading the save twice a second for the whole session. We are the only writer,
    -- so one read per load is enough. BanditCampResync clears it.
    if self._bcampCleared == nil then
        local v
        pcall(function() v = self:LoadString("BCampDone") end)
        self._bcampCleared = tonumber(v) or 0
    end
    return self._bcampCleared
end

function mercenaries:BanditCampAdvance()
    local n = self:BanditCampCleared() + 1
    self._bcampCleared = n
    pcall(function() self:SaveString("BCampDone", tostring(n)) end)
    qLog("camps cleared: " .. n .. "/" .. #self.BanditCampSites)
end

-- The camps are an ORDERED run, not a random draw: BanditCampSites is in the order they are
-- meant to be fought, ending at the roman fort, which is the last one before Raborsch. So the
-- contract hands out the next one the player has not done rather than picking at random.
function mercenaries:BanditCampPickSite()
    local level = levelName()
    local function onThisMap(s)
        -- Wildcards on either side. The level bindings are unreliable enough that
        -- merc_bcamp_dump can print "unknown" into a site row, and a site that could never
        -- match anything would just report "no camp in these parts" forever.
        local sl = s.level
        return sl == nil or sl == "" or sl == "unknown" or level == "unknown" or sl == level
    end

    local order = {}
    for _, s in ipairs(self.BanditCampSites) do
        if onThisMap(s) then table.insert(order, s) end
    end
    if #order == 0 then return nil end

    -- Next in the run. Past the end everything has been cleared, so it stays on the last one
    -- rather than refusing the contract - the quest is repeatable and the fort can be re-run.
    local idx = self:BanditCampCleared() + 1
    if idx > #order then idx = #order end
    local site = order[idx]

    -- Except: never pitch a camp on top of the player. If the next one in the run is too
    -- close to be travelled to, fall through to the furthest one that is.
    local p = player and player:GetWorldPos()
    if p then
        local a = self:BanditCampSiteAnchor(site)
        local d = math.sqrt((a.x - p.x) ^ 2 + (a.y - p.y) ^ 2)
        if d <= self.BanditCampForgetRange then
            local best, bestD = site, d
            for _, s in ipairs(order) do
                local sa = self:BanditCampSiteAnchor(s)
                local sd = math.sqrt((sa.x - p.x) ^ 2 + (sa.y - p.y) ^ 2)
                if sd > bestD then best, bestD = s, sd end
            end
            qLog("next camp in the run is underfoot - taking " .. tostring(best.name) .. " instead")
            return best
        end
    end
    qLog(string.format("camp %d/%d in the run: %s", idx, #order, tostring(site.name)))
    return site
end

-- Token be81d: the player accepted the job.
function mercenaries:BanditCampAccept()
    -- Reached from the dialog token and the console, both outside the monitor's bind.
    self.BCQ = self.BCQ_KK
    if self.BCQ.active then
        Game.SendInfoText('merc_info_banditcamp_already', false, 0, 4)
        return
    end

    local c, idx = self:KleinkriegContract(self:BanditCampCleared() + 1)
    local site = self:BanditCampSiteByName(c.site)
    if not site then
        Game.SendInfoText('merc_info_banditcamp_nosite', false, 0, 5)
        qLog("contract '" .. c.name .. "' names site '" .. tostring(c.site) ..
             "', which is not in BanditCampSites")
        return
    end

    -- Kleinkrieg has first claim on the ground. If the repeatable bounty is standing on the
    -- site this contract needs, the bounty is the one that moves (mercenaries_bounty.lua).
    pcall(function() self:BountyYieldSite(site.name) end)

    -- BEFORE the scale call: BanditCampScale resolves the contract through KleinkriegContract,
    -- which reads S.contractIdx - left stale from the previous contract, it sized contract 4
    -- with contract 3's group, headcount and reward. Only the very first contract escaped.
    self.BCQ.contractIdx = idx

    local group, count, archers, reward = self:BanditCampScale()
    qLog(string.format("contract sized to %d follower(s): %d %s, %d archer(s), %d groschen",
         self:BanditCampFollowerCount(), count, tostring(group), archers, reward))

    local S = self.BCQ
    S.active, S.site, S.group = true, site, group
    S.contractIdx, S.dispersed, S.disperseTicks = idx, false, 0
    -- The roaming gangs stand down for the duration. A contract already puts a band on a
    -- road, and having wandering patrols walk into it turned every job into a three-way.
    pcall(function()
        if self.LivePatrolsEnabled then
            S.patrolsWereOn = true
            self:LivePatrolSetEnabled(0)
        end
    end)
    -- Every per-contract flag, reset EXPLICITLY. S.paid was the arc-breaker: with one write
    -- and no reset, contract 2 inherited contract 1's paid=true and the monitor closed it
    -- unpaid the moment the player walked off after clearing - every contract after the
    -- first, deterministically. The letter flags carried the same class of staleness.
    S.paid, S.letterTaken, S.letterGranted = false, false, false
    S.letterOnLeader, S.warnedLetter = false, false
    S.target, S.killed, S.reward, S.archers = count, 0, reward, archers
    S.cleared, S.spawned, S.leaderDead = false, false, false
    S.entities, S.bandits, S.spots, S.actorSet = {}, {}, {}, {}

    -- Deliberately NOT spawned here: the camp is somewhere else, and the monitor builds it
    -- when the player gets within BanditCampForgetRange. Spawning now would put twenty NPCs
    -- on the far side of the map for the next tick to unload again.
    self:BanditCampSave()

    -- Tell Skald to open the journal entry and drop the marker.
    self:BanditCampSignal(self.TokenIDBanditCampUp)
    -- His accept line is SPOKEN now (quartermaster_dialog.xml gates one per contract), so
    -- this only confirms the job was taken.
    Game.SendInfoText('merc_info_banditcamp_taken', false, 0, 5)
end

function mercenaries:SpawnBanditCamp()
    local S = self.BCQ
    if S.spawned or not S.site then return end
    local kc = self:KleinkriegContract()

    -- Raborsch runs its own module: an authored siege, not a generated camp.
    if kc and kc.siege then
        S.spawned = true
        pcall(function() self:SpawnRaborsch() end)
        qLog("the siege of Raborsch stands")
        return
    end

    if not (kc and kc.patrol) then
        self:SpawnBanditCampLayout(S.site)
    end
    -- On a rebuild after wandering off, only the survivors come back - and the leader only
    -- if he was still standing when the camp unloaded.
    local remaining = math.max(0, (S.target or 0) - (S.killed or 0))
    self:SpawnBanditCampBand(S.site, S.group or "bandit", remaining, S.archers or 0, not S.leaderDead)
    S.spawned = true
end

function mercenaries:DespawnBanditCamp(keepContract)
    local S = self.BCQ

    for _, entId in ipairs(S.bandits or {}) do
        -- The leader survives an unload: he is the map marker's anchor and has to outlive
        -- the camp for as long as the contract does. A full despawn takes him too.
        if not (keepContract and entId == S.leaderId) then
            pcall(function()
                local e = System.GetEntity(entId)
                if e then
                    local w = XGenAIModule.GetMyWUID(e)
                    if w then self:ClearBanditCampActor(tostring(w)) end
                end
                System.RemoveEntity(entId)
            end)
        end
    end
    for _, id in ipairs(S.entities or {}) do
        pcall(function() System.RemoveEntity(id) end)
    end
    -- Towers own their parts, colliders and archer, so let the tower system take them down
    -- rather than deleting entities out from under it.
    for _, st in ipairs(S.towers or {}) do
        pcall(function() self:TowerStationClearOne(st) end)
    end
    for _, st in ipairs(S.carts or {}) do
        pcall(function() self:ArcherCartClearOne(st) end)
    end
    -- Before anything else is removed: hand back the borrowed Smithery. Its pieces are real
    -- world objects that were moved here, not props of ours.
    self:DespawnBanditCampBorrowed()

    self:ClearBanditCampChats()

    S.bandits, S.entities, S.spots, S.seats, S.beds = {}, {}, {}, {}, {}
    S.actorSet = {}
    S.towers, S.carts, S.adoptedTowers, S.adoptedCarts, S.towerArcherIds = {}, {}, {}, {}, {}
    -- The chest went with the props, so a rebuilt camp gets a fresh one carrying the letter.
    -- A CLEARED camp never reaches a rebuild (the monitor returns first), so this cannot
    -- hand out a second letter.
    S.letterChestPlaced, S.letterChestId = false, nil
    S.chestStocked, S.stockTries = false, 0
    -- A camp that gets rebuilt after the player wandered off is calm again: the men who saw
    -- them are the ones that were just unloaded.
    S.alerted, S.health, S.missing, S.chatCooldown = false, {}, {}, {}
    S.spawned = false
    -- Keep the leader handle across an unload; only a finished contract lets him go.
    if not keepContract then S.leaderId = nil end

    if not keepContract then
        S.active, S.site, S.killed, S.target = false, nil, 0, 0
        S.cleared, S.leaderDead = false, false
        self:BanditCampSave()
    end
end

function mercenaries:ClearBanditCampActor(ws)
    self.BanditCampActors[ws] = nil
    for _, S in ipairs(self:BanditCampSlots()) do
        if S.actorSet then S.actorSet[ws] = nil end
    end
    self.CampFurniture[ws]    = nil
    self.CampActivities[ws]   = nil
    self.CampPatrollers[ws]   = nil
    if self.BanditCampColumn then self.BanditCampColumn[ws] = nil end
end

-- The two Lua->Skald signal tokens have to come back out of the inventory once Skald has
-- seen them: leaving one lying around would instantly re-fire on the NEXT contract, and
-- this quest is Repeatable.
--
-- They are given a one-tick grace rather than being deleted on sight. Skald triggers are
-- documented as synchronous, so OnAcquire should already have fired inside CreateItem - but
-- MonitorInventory and this monitor run in the same 1 Hz pass, so a same-tick delete would
-- depend on that being true. Surviving one full tick costs nothing and does not.
function mercenaries:BanditCampSignal(tokenId)
    pcall(function() player.inventory:CreateItem(tokenId, 1, 1) end)
    self.BanditCampTokenSeen = self.BanditCampTokenSeen or {}
    self.BanditCampTokenSeen[tokenId] = false
end

-- TokenIDKKPhase and BountySweepTokens are assigned once at load and never
-- reassigned, so the combined list is built once and reused.
function mercenaries:BanditCampSweepTokens()
    if not (player and player.inventory) then return end
    self.BanditCampTokenSeen = self.BanditCampTokenSeen or {}
    if not self._bcSweepTokens then
        local sweep = { self.TokenIDBanditCampCleared, self.TokenIDBanditCampUp,
                        self.TokenIDKKArcDone, self.TokenIDKKPhaseAlt,
                        self.TokenIDKKSearch, self.TokenIDKKReport,
                        self.TokenIDKKOpen, self.TokenIDKKShut,
                        self.TokenIDKKReady, self.TokenIDKKUnready }
        for _, id in ipairs(self.TokenIDKKPhase) do table.insert(sweep, id) end
        -- The bounty's Lua->Skald signals, registered by mercenaries_bounty.lua.
        for _, id in ipairs(self.BountySweepTokens or {}) do table.insert(sweep, id) end
        self._bcSweepTokens = sweep
    end
    for _, id in ipairs(self._bcSweepTokens) do
        pcall(function()
            local c = player.inventory:GetCountOfClass(id)
            if c and c > 0 then
                if self.BanditCampTokenSeen[id] then
                    player.inventory:DeleteItemOfClass(id, c)
                    self.BanditCampTokenSeen[id] = nil
                else
                    -- First tick this token has been seen: let it live one more.
                    self.BanditCampTokenSeen[id] = true
                end
            else
                self.BanditCampTokenSeen[id] = nil
            end
        end)
    end
end

-- ==== the tick ====
-- One pass per LIVE camp. The token sweep and the dialog gates are mod-wide and run once;
-- everything after that is serviced with the slot bound, so BanditCampService and everything
-- it calls sees exactly one camp through self.BCQ.
function mercenaries:BanditCampMonitor()
    self:BanditCampSweepTokens()
    self:KleinkriegSyncPhase()
    self:KleinkriegSyncGates()
    pcall(function() self:BountySyncGates() end)

    for _, S in ipairs(self:BanditCampSlots()) do
        if S.active then
            self:BanditCampWith(S, function() self:BanditCampService() end)
        end
    end
    -- Back on the arc, so anything reading self.BCQ without asking gets what it always did.
    self.BCQ = self.BCQ_KK
end

function mercenaries:BanditCampService()
    local S = self.BCQ
    if not S.active then return end

    local p = player and player:GetWorldPos()
    if not (p and S.site) then return end
    local sa = self:BanditCampSiteAnchor(S.site)
    local dist = math.sqrt((sa.x - p.x) ^ 2 + (sa.y - p.y) ^ 2 + (sa.z - p.z) ^ 2)

    -- Before anything else: the marker's anchor. Spawned NPCs do not survive a save, so this
    -- is also what puts the marker back after a reload.
    self:BanditCampEnsureLeader()

    -- The moment the letter is actually in hand, tell Skald: that closes "find the letter" and
    -- moves the tracker off the camp and onto the quartermaster. Polled rather than hooked
    -- because the player picks it up out of a container, which Lua never sees directly.
    if S.kind ~= "bounty" and S.cleared and not S.letterTaken and self:BanditCampHasLetter() then
        S.letterTaken = true
        self:BanditCampSignal(self.TokenIDBanditCampTaken)
        self:BanditCampSave()
        qLog("letter picked up - tracker moves to the quartermaster")
    end

    -- Cleared. The props come down once the player has walked off, but NEVER while the letter
    -- is still in the chest - tearing the camp down then would make the contract
    -- uncompletable. Someone who leaves without looting comes back to a standing, lifeless
    -- camp. A cleared camp also never goes through the unload/rebuild cycle below, because
    -- this branch returns.
    if S.cleared then
        if S.spawned and dist >= self.BanditCampDespawnRange then
            if S.paid then
                self:DespawnBanditCamp(false)          -- contract over, drop everything
                qLog("camp cleaned up")
            elseif self:BanditCampHasLetter() then
                self:DespawnBanditCamp(true)           -- letter is on the player; keep the
                qLog("camp cleaned up - deliver the letter")   -- contract alive for hand-in
            elseif not S.warnedLetter then
                S.warnedLetter = true
                qLog("camp kept standing: the letter is still in its chest")
            end
        elseif S.paid and not S.spawned and S.active then
            -- Handed in after the camp was already gone: close the contract out.
            self:DespawnBanditCamp(false)
        end
        return
    end

    -- Wandered off mid-contract: unload the camp but remember the body count, so
    -- coming back does not hand the player a full camp again.
    if S.spawned and dist > self.BanditCampForgetRange then
        self:BanditCampCountDead()
        self:DespawnBanditCamp(true)
        self:BanditCampSave()
        qLog("player left the area - camp unloaded, " .. tostring(S.killed) .. " already dead")
        return
    end
    if (not S.spawned) and dist <= self.BanditCampForgetRange then
        self:SpawnBanditCamp()
        qLog("player returned - camp rebuilt with the survivors")
        return
    end

    if not S.spawned then return end

    -- The siege counts its own dead: its men are in RBQ, not S.bandits.
    local kcS = self:KleinkriegContract()
    if kcS and kcS.siege then
        local left = 0
        pcall(function()
            for _, id in ipairs(self.RBQ.foot or {}) do
                local e = System.GetEntity(id)
                if e and self:IsAliveAndWell(e, true) then left = left + 1 end
            end
            for _, id in ipairs(self.RBQ.archers or {}) do
                local e = System.GetEntity(id)
                if e and self:IsAliveAndWell(e, true) then left = left + 1 end
            end
        end)
        S.target = math.max(S.target or 0, left)
        S.killed = (S.target or 0) - left
        if left == 0 and not S.cleared then
            self:BanditCampComplete()
        end
        return
    end

    -- The looter column can be DISPERSED: walk into them with steel sheathed and hold for a
    -- few seconds, and they scatter instead of dying. One boolean, remembered for Raborsch
    -- (its first wave shrinks if these men were spared).
    local kc = self:KleinkriegContract()
    if kc and kc.disperse and not S.alerted and not S.cleared then
        local drawn = true
        pcall(function() drawn = player.human:IsWeaponDrawn() end)
        local near = false
        for _, entId in ipairs(S.bandits or {}) do
            local e = System.GetEntity(entId)
            local bp
            if e then pcall(function() bp = e:GetWorldPos() end) end
            if bp then
                local dx, dy, dz = bp.x - p.x, bp.y - p.y, bp.z - p.z
                if (dx * dx + dy * dy + dz * dz) <= 64.0 then near = true; break end
            end
        end
        if near and not drawn then
            S.disperseTicks = (S.disperseTicks or 0) + 1
            if S.disperseTicks == 1 then
                Game.SendInfoText('merc_info_kk_disperse_hint', false, 0, 5)
            elseif S.disperseTicks >= 4 then
                S.dispersed = true
                pcall(function() self:SaveString("KKDispersed", "1") end)
                self:BanditCampSignal(self.TokenIDKKPhaseAlt)
                for _, entId in ipairs(S.bandits or {}) do
                    pcall(function()
                        local e = System.GetEntity(entId)
                        if e then
                            local w = XGenAIModule.GetMyWUID(e)
                            if w then self:ClearBanditCampActor(tostring(w)) end
                        end
                        System.RemoveEntity(entId)
                    end)
                end
                S.bandits = {}
                S.killed = S.target
                S.leaderDead = true
                Game.SendInfoText('merc_info_kk_dispersed', false, 0, 6)
                qLog("the column dispersed without a fight")
                self:BanditCampComplete()
                return
            end
        else
            S.disperseTicks = 0
        end
    end

    self:BanditCampStockChest()
    self:RotateBanditCampRoles()
    self:BanditCampAdoptTowerArchers()
    self:BanditCampAlertTick()
    self:BanditCampChatTick()
    -- Before the count: a swapped-in replacement must already be on the roster, or that tick
    -- would see the slot empty and bank a kill that never happened.
    self:BanditCampBringArchersDown()
    self:BanditCampCountDead()

    if S.killed >= S.target then
        self:BanditCampComplete()
    end
end

-- Tower archers arrive on a delay (TowerArcherSpawnQueue), so they cannot be counted at
-- build time. Adopt each one the first tick it exists and raise the target with it -
-- otherwise the contract would pay out while two archers were still shooting from towers.
function mercenaries:BanditCampAdoptTowerArchers()
    local S = self.BCQ
    S.adoptedTowers = S.adoptedTowers or {}
    for i, st in ipairs(S.towers or {}) do
        if st and st.archer and not S.adoptedTowers[i] then
            S.adoptedTowers[i] = true
            table.insert(S.bandits, st.archer.id)
            S.towerArcherIds = S.towerArcherIds or {}
            S.towerArcherIds[st.archer.id] = true
            S.target = (S.target or 0) + 1
            -- Registered as a camp member so the alert gate suppresses his fire too. He
            -- holds no camp ROLE, so the role accessors still hand back nil for him.
            local w = XGenAIModule.GetMyWUID(st.archer)
            if w then
                self.BanditCampActors[tostring(w)] = true
                S.actorSet[tostring(w)] = true
            end
            qLog("tower archer joined the count - target now " .. tostring(S.target))
        end
    end

    -- Cart archers the same way: three per cart, also on their own deferred spawn, and also
    -- part of the band the contract counts. They are NOT marked as tower archers, so the
    -- ground-cleared descent leaves them where they are - a cart is at ground level already.
    S.adoptedCarts = S.adoptedCarts or {}
    for i, st in ipairs(S.carts or {}) do
        local aboard = st and st.archers
        if aboard and #aboard > 0 and not S.adoptedCarts[i] then
            S.adoptedCarts[i] = true
            for _, a in ipairs(aboard) do
                if a.ent then
                    table.insert(S.bandits, a.ent.id)
                    S.target = (S.target or 0) + 1
                    local w = XGenAIModule.GetMyWUID(a.ent)
                    if w then
                        self.BanditCampActors[tostring(w)] = true
                        S.actorSet[tostring(w)] = true
                    end
                end
            end
            qLog(#aboard .. " cart archer(s) joined the count - target now " .. tostring(S.target))
        end
    end
end

-- Once the last man on the ground is down, the tower archers stop being snipers and come
-- after the player. There is no way to walk one down a ladder - the deck has no navmesh and
-- his whole brain (static_archer_brain) is "stand and shoot", which cannot be swapped at
-- runtime - so he is SWAPPED: the static archer is removed and an ordinary bandit archer of
-- the same group takes his place at the foot of his tower, keeping the roster slot. The
-- replacement runs the normal enemy archer AI, so he closes, kites and fights properly.
--
-- It reads as him having climbed down while you were busy, which is the point; watch it
-- happen in the open and it is a pop.
function mercenaries:BanditCampBringArchersDown()
    local S = self.BCQ
    if not (S.alerted and S.spawned) or not S.towers or #S.towers == 0 then return end
    S.towerArcherIds = S.towerArcherIds or {}

    -- Anyone still standing who is NOT up a tower.
    local groundLeft, manned = 0, 0
    for _, entId in ipairs(S.bandits or {}) do
        local e = System.GetEntity(entId)
        if e and self:IsAliveAndWell(e, true) then
            if S.towerArcherIds[entId] then manned = manned + 1 else groundLeft = groundLeft + 1 end
        end
    end
    if groundLeft > 0 or manned == 0 then return end

    for _, st in ipairs(S.towers) do
        local a = st and st.archer
        if a and self:IsAliveAndWell(a, true) then
            local oldId = a.id
            local pos = st.placedGround or st.origin
            local yaw = st.yaw or 0
            if pos then
                local ground = self:CampSnapToGround({ x = pos.x, y = pos.y, z = pos.z })
                -- Read his outfit off the StaticArchers record BEFORE removing him -
                -- RemoveStaticArcher clears that entry, and the replacement has to match.
                local aws = tostring(a.this and a.this.id or a.id)
                local rec = self.StaticArchers and self.StaticArchers[aws]
                local outfit = rec and rec.outfit

                local w
                pcall(function() w = XGenAIModule.GetMyWUID(a) end)
                if w then self:ClearBanditCampActor(tostring(w)) end
                pcall(function() self:RemoveStaticArcher(a) end)
                st.archer = nil

                local ent = self:SpawnEnemyAt(S.group or "bandit", true, ground, yaw)
                if ent then
                    self:BanditCampDressUp(ent, true, outfit)
                    for i, id in ipairs(S.bandits) do
                        if id == oldId then S.bandits[i] = ent.id; break end
                    end
                    S.towerArcherIds[oldId] = nil
                    S.towerArcherIds[ent.id] = true
                    qLog("a tower archer came down to fight")
                else
                    -- The swap failed, so the slot is now empty: drop it from the roster and
                    -- the target, or the contract could never be completed.
                    for i, id in ipairs(S.bandits) do
                        if id == oldId then table.remove(S.bandits, i); break end
                    end
                    S.towerArcherIds[oldId] = nil
                    S.target = math.max(0, (S.target or 1) - 1)
                    qLog("tower archer removed but his replacement failed to spawn")
                end
            end
        end
    end
end

-- Counts the fallen and releases their camp roles. Conscious-strict would be wrong here:
-- a knocked-out bandit is out of the fight but not dead, and the contract says dead.
function mercenaries:BanditCampCountDead()
    local S = self.BCQ
    -- A MISSING entity is not proof of death. The engine streams and despawns NPCs on its
    -- own (docs/npc-lod.md - the mod already had to fight this for its own mercs), and
    -- S.killed only ever ratchets upward, so treating one nil lookup as a kill would let a
    -- streaming blip inflate the count permanently and eventually pay the contract out with
    -- bandits still standing. A body only counts once it has been missing for
    -- BanditCampMissingTicks consecutive polls, or is present and verifiably dead.
    S.missing = S.missing or {}
    local alive = 0
    for _, entId in ipairs(S.bandits or {}) do
        local ent = System.GetEntity(entId)
        if ent then
            S.missing[entId] = nil
            if self:IsAliveAndWell(ent, true) then
                alive = alive + 1
            else
                if entId == S.leaderId then S.leaderDead = true end
                local w = XGenAIModule.GetMyWUID(ent)
                if w then self:ClearBanditCampActor(tostring(w)) end
            end
        else
            local n = (S.missing[entId] or 0) + 1
            S.missing[entId] = n
            if n < self.BanditCampMissingTicks then
                alive = alive + 1          -- give him the benefit of the doubt for now
            elseif entId == S.leaderId then
                S.leaderDead = true
            end
        end
    end
    local killed = math.max(S.killed or 0, (S.target or 0) - alive)
    -- Persist as soon as the count moves. The player can quicksave mid-fight, and the save
    -- captures whatever SaveString last wrote - so leaving this until the camp unloads
    -- would reload with a stale count and put the dead back on their feet.
    if killed ~= S.killed then
        S.killed = killed
        self:BanditCampSave()
    end
end

-- Every bandit is down. That closes the FIRST objective and opens the second: the leader kept
-- a letter in the camp's chest, and the quartermaster wants it. No money changes hands here.
function mercenaries:BanditCampComplete()
    local S = self.BCQ
    if S.cleared then return end
    S.cleared = true

    -- The bounty is its own quest with its own two objectives and nothing to find on the
    -- body, so it never touches the arc's tokens.
    if S.kind == "bounty" then
        S.letterTaken = true
        self:BanditCampSignal(self.TokenIDBountyCleared)
        Game.SendInfoText('merc_info_bounty_done', false, 0, 6)
        qLog("bounty camp cleared - report to the quartermaster")
        self:BanditCampSave()
        return
    end

    self:BanditCampSignal(self.TokenIDBanditCampCleared)
    -- Only fires if the leader refused the letter; normally the player loots it themselves.
    self:BanditCampGrantLetterFallback()
    if self:KleinkriegLetterClass() then
        self:BanditCampSignal(self.TokenIDKKSearch)
        Game.SendInfoText('merc_info_banditcamp_done', false, 0, 6)
    else
        -- Nothing to find: skip the search leg entirely rather than raising it and closing
        -- it in the same breath, and point the tracker straight home.
        S.letterTaken = true
        self:BanditCampSignal(self.TokenIDKKReport)
        Game.SendInfoText('merc_info_kk_report', false, 0, 6)
    end
    qLog("cleared - letter " .. (S.letterOnLeader and "on the leader's body" or "none this contract"))
    self:BanditCampSave()
end

-- "Nothing outstanding": true when the current contract's letter is in the pack, or when the
-- contract carries no letter at all (then there is nothing to hold the despawn or the pay).
function mercenaries:BanditCampHasLetter()
    local cls = self:KleinkriegLetterClass()
    if not cls then return true end
    local n = 0
    pcall(function() n = player.inventory:GetCountOfClass(cls) or 0 end)
    return n > 0
end

-- The quartermaster dialog's hand-in option (token be85d). This is where the contract is
-- actually paid: turning up without the letter is refused rather than half-completing.
function mercenaries:BanditCampDeliverLetter()
    self.BCQ = self.BCQ_KK
    local S = self.BCQ
    if not (S.active and S.cleared) then
        Game.SendInfoText('merc_info_banditcamp_noletter', false, 0, 4)
        return
    end
    if not self:BanditCampHasLetter() then
        Game.SendInfoText('merc_info_banditcamp_noletter', false, 0, 4)
        qLog("hand-in refused: the player does not have the letter")
        return
    end

    local cls = self:KleinkriegLetterClass()
    if cls then pcall(function() player.inventory:DeleteItemOfClass(cls, 1) end) end
    self:GiveMoney(S.reward or 0)
    self:BanditCampSignal(self.TokenIDBanditCampPaid)

    S.paid = true
    -- Advance the run only on PAYMENT, not on the last kill: a camp you cleared but never
    -- collected on is not finished, and should still be the next one offered.
    self:BanditCampClearSiege()
    self:BanditCampAdvance()
    -- ALWAYS closes the journal entry now, not just on the twelfth contract. The
    -- quartermaster no longer offers this run at all - Aleksej's nine beats are the
    -- Kleinkrieg quest (docs/aleksej.md) - so a hand-in is the last thing that can happen
    -- to it, and leaving the entry open waiting for a next contract that can never be
    -- taken would strand it in the journal forever.
    self:BanditCampSignal(self.TokenIDKKArcDone)
    S.arcFinished = true
    qLog("Kleinkrieg contract closed out - the quartermaster no longer issues these")
    -- Straight away, not on the next monitor tick: the player is still standing in the dialog.
    self:KleinkriegSyncGates()
    self:KleinkriegSyncPhase()

    -- The chain is gone with the offer. Reporting used to take the next job straight away,
    -- which is precisely the quartermaster issuing another Kleinkrieg contract - so it would
    -- have put the run back on the moment anyone handed one in. The roads come back instead.
    self:BanditCampRestorePatrols()

    -- His report line is spoken in the hand-in dialog; this is just the receipt.
    local c = self:KleinkriegContract()
    Game.SendInfoText('merc_info_banditcamp_paid', false, 0, 6)
    qLog("contract '" .. tostring(c and c.name) .. "' paid " .. tostring(S.reward) .. " groschen")
    self:BanditCampSave()
end

-- ==== persistence ====
-- Spawned entities are not saved by the engine, so what survives a reload is the CONTRACT,
-- not the camp: site, group, how many there were and how many are down. The camp itself is
-- rebuilt from that on the next tick the player is near enough.
function mercenaries:BanditCampSaveTag(S)
    return (S.kind == "bounty") and "BOQuest" or "BCQuest"
end

function mercenaries:BanditCampSave()
    local S = self.BCQ
    local tag = self:BanditCampSaveTag(S)
    if not S.active then
        pcall(function() self:SaveString(tag, "none") end)
        return
    end
    local blob = string.format("%s|%s|%d|%d|%d|%d|%.2f|%.2f|%.2f|%.4f|%s|%s|%s|%s|%s|%s|%s",
        S.site.name or "?", S.group or "bandit", S.target or 0, S.killed or 0,
        S.reward or 0, S.archers or 0,
        S.site.x, S.site.y, S.site.z, S.site.yaw or 0,
        S.cleared and "1" or "0", S.leaderDead and "1" or "0",
        -- Alertness rides along: reloading beside a camp you have already woken must not
        -- hand it back its calm, or a quicksave is a free way to un-alert a camp.
        S.alerted and "1" or "0", S.paid and "1" or "0",
        tostring(S.contractIdx or 0), S.dispersed and "1" or "0",
        S.letterTaken and "1" or "0")
    pcall(function() self:SaveString(tag, blob) end)
end

-- How far around the site a reload sweeps for the previous camp's leavings.
mercenaries.BanditCampSweepRadius = 60.0

-- Spawned entities SURVIVE a save/load - the Lua tables that tracked them do not. That is why
-- the player's own camp has ClearAnyLeftoverCamp, whose comment says a rebuild "would
-- otherwise stack on top of them"; this camp needs exactly the same treatment and did not have
-- it, so reloading with a contract running built a second camp on top of the first. The
-- survivors held no camp roles (BanditCampActors is rebuilt empty) and were not on the new
-- roster, so they could never be killed off the contract either.
--
-- The sweep is by RADIUS around the site as well as by name, because parts of this camp are
-- spawned through the shared camp helpers and come out named MercCampProp_FireAnchor_* and
-- MercTowerPart_* - indistinguishable by name from the player's own.
function mercenaries:ClearAnyLeftoverBanditCamp()
    local S = self.BCQ
    if not (S.active and S.site) then return end

    local c = S.site
    local r2 = self.BanditCampSweepRadius * self.BanditCampSweepRadius

    -- Never sweep across the player's own camp, which uses some of the same name prefixes.
    -- This reads the SAVED anchor, not self.CampCenter: at load time the camp has not been
    -- rebuilt yet (RestoreCampDelayed runs seconds later), so CampCenter is still nil and a
    -- guard on it would never once fire.
    local pc = self.CampCenter
    if not pc then pcall(function() pc = self:LoadCampOrigin() end) end
    if pc and pc.x and pc.y then
        local dx, dy = pc.x - c.x, pc.y - c.y
        if (dx * dx + dy * dy) < r2 then
            qLog("leftover sweep skipped: the player's camp is inside the sweep radius")
            return
        end
    end

    local function near(e)
        local p
        pcall(function() p = e:GetWorldPos() end)
        if not p then return false end
        local dx, dy = p.x - c.x, p.y - c.y
        return (dx * dx + dy * dy) <= r2
    end

    local swept = 0
    local classes = { "Stash" }
    for _, cls in ipairs(self.CampPropClasses or {}) do table.insert(classes, cls) end
    for _, cls in ipairs(classes) do
        pcall(function()
            for _, e in pairs(System.GetEntitiesByClass(cls) or {}) do
                local n = e and e:GetName() or ""
                if (string.find(n, "BCampQ", 1, true) == 1 or string.find(n, "MercCamp", 1, true) == 1
                    or string.find(n, "MercTower", 1, true) == 1 or string.find(n, "MercInn", 1, true) == 1)
                   and near(e) then
                    System.RemoveEntity(e.id); swept = swept + 1
                end
            end
        end)
    end

    -- And the men. The leader is unmistakable (his own soul guid is in his name); the rest are
    -- ordinary SpawnedEnemy_ NPCs, so they are taken only inside the radius - an ambush or a
    -- patrol elsewhere on the map is untouched.
    pcall(function()
        for _, e in pairs(System.GetEntitiesByClass("NPC") or {}) do
            local n = e and e:GetName() or ""
            -- SpawnedTower_archer_ is a MERC tower archer. One has no business at a bandit
            -- camp; if the defence restore ever puts one here again, it goes with the rest.
            if (string.find(n, S.leaderSoul or self.BanditCampLeaderSoul, 1, true)
                or ((string.find(n, "SpawnedEnemy_", 1, true) == 1
                     or string.find(n, "SpawnedTower_archer_", 1, true) == 1) and near(e))) then
                System.RemoveEntity(e.id); swept = swept + 1
            end
        end
    end)

    if swept > 0 then qLog("swept " .. swept .. " leftover(s) from the previous camp") end
end

-- Both slots, each from its own blob. Bound while it restores, because everything the
-- restore calls (the leftover sweep, the site lookup) reads self.BCQ.
function mercenaries:BanditCampRestore()
    for _, S in ipairs(self:BanditCampSlots()) do
        self:BanditCampWith(S, function() self:BanditCampRestoreSlot() end)
    end
    self.BCQ = self.BCQ_KK
end

function mercenaries:BanditCampRestoreSlot()
    local S0 = self.BCQ
    local blob
    pcall(function() blob = self:LoadString(self:BanditCampSaveTag(S0)) end)
    -- No contract in the save. CLEAR the slot rather than returning: this session may have one
    -- running, and the loaded save is the only authority on that - leaving it would keep the
    -- hand-in offered and rebuild a camp for a contract nobody in this save ever took. The table
    -- itself is kept, because self.BCQ points at it.
    if not blob or blob == "none" then
        if not S0.active then return end
        -- Its camp goes first, while the site is still known: by name and radius, because every
        -- entity id in the slot came from before the load.
        self:ClearAnyLeftoverBanditCamp()
        local fresh = newCampState(S0.key)
        fresh.kind = S0.kind
        for k in pairs(S0) do S0[k] = nil end
        for k, v in pairs(fresh) do S0[k] = v end
        qLog("no contract in this save - the previous session's was dropped")
        return
    end

    local f = {}
    for part in string.gmatch(blob, "([^|]+)") do table.insert(f, part) end
    -- 12 fields is the pre-alertness format; those saves restore as a calm camp.
    if #f < 12 then qLog("saved contract unreadable: " .. tostring(blob)); return end

    local S = self.BCQ
    S.active     = true
    S.spawned    = false
    S.group      = f[2]
    S.target     = tonumber(f[3]) or 0
    S.killed     = tonumber(f[4]) or 0
    S.reward     = tonumber(f[5]) or 0
    S.archers    = tonumber(f[6]) or 0
    S.cleared    = (f[11] == "1")
    S.leaderDead = (f[12] == "1")
    S.alerted    = (f[13] == "1")
    S.paid       = (f[14] == "1")
    S.contractIdx = tonumber(f[15])
    if S.contractIdx == 0 then S.contractIdx = nil end
    S.dispersed   = (f[16] == "1")
    -- A bounty's "contract" is generated, not one of the arc's rows, so it is rebuilt here
    -- from what the blob carries. Everything on it that matters after accept is the group.
    if S.kind == "bounty" then S.contract = self:BountyContractFor(S.group) end
    -- Without this, reloading after the letter was taken refired the taken signal each load.
    S.letterTaken = (f[17] == "1")
    S.health, S.missing, S.chatCooldown = {}, {}, {}
    S.letterChestPlaced, S.warnedLetter = false, false
    S.site    = { name = f[1], x = tonumber(f[7]), y = tonumber(f[8]), z = tonumber(f[9]),
                  yaw = tonumber(f[10]), layout = "default" }
    S.entities, S.bandits, S.spots, S.actorSet = {}, {}, {}, {}

    -- Match the site back to a defined one so it keeps its layout - and, for a road site,
    -- its route. Without route/pt a reloaded patrol contract silently degrades: the band
    -- respawns in a ring and paces a 14m loop instead of walking the road it was met on.
    for _, s in ipairs(self.BanditCampSites) do
        if s.name == f[1] then
            S.site.layout = s.layout or "default"
            S.site.route, S.site.pt = s.route, s.pt
        end
    end
    -- The leader is respawned by the monitor, and the camp rebuilt, so anything the old
    -- session left standing has to go first or the two sets stack.
    S.leaderId = nil
    self:ClearAnyLeftoverBanditCamp()

    qLog(string.format("contract restored: %s, %d/%d down", tostring(f[1]), S.killed, S.target))
end

-- ==== console ====
function mercenaries:BanditCampStatus()
    pcall(function() self:BountyStatus() end)
    self.BCQ = self.BCQ_KK
    local S = self.BCQ
    if not S.active then qLog("no Kleinkrieg contract"); return end
    qLog(string.format("site=%s group=%s %d/%d killed reward=%d spawned=%s cleared=%s alerted=%s",
        tostring(S.site and S.site.name), tostring(S.group), S.killed or 0, S.target or 0,
        S.reward or 0, tostring(S.spawned), tostring(S.cleared), tostring(S.alerted)))
    local chats = 0
    for _, c in pairs(_G.MercCampChats or {}) do if c and c.foreign and c.role == 1 then chats = chats + 1 end end
    qLog(string.format("alert range now %.0fm (%d conversation(s) running)",
        self:BanditCampAlertRangeNow(), chats))
    local kc, ki = self:KleinkriegContract()
    qLog(string.format("Kleinkrieg: %d/%d contracts paid; current/next = %d '%s'%s",
        self:BanditCampCleared(), #self.KleinkriegContracts, ki, tostring(kc and kc.name),
        S.dispersed and " (dispersed)" or ""))
    qLog(string.format("letter: chest=%s onLeader=%s inPack=%s paid=%s",
        tostring(S.letterChestId ~= nil), tostring(S.letterOnLeader),
        tostring(self:BanditCampHasLetter()), tostring(S.paid)))
end

-- Prints a BanditCampSites row for wherever the player stands.
function mercenaries:BanditCampSiteHere()
    local p = player and player:GetWorldPos()
    if not p then return end
    qLog(string.format('{ name = "RENAME_ME", level = "%s", x = %.2f, y = %.2f, z = %.2f, yaw = 0, layout = "default" },',
        levelName(), p.x, p.y, p.z))
    qLog("NOTE: a layout replays around its FIRST placed piece. If you have already built a")
    qLog("camp, use the site row that merc_bcamp_dump prints instead - it uses that piece's")
    qLog("real position, so the camp lands exactly where you built it.")
end

-- ==== item diagnostics ====
-- The chest probe showed .inventory:CreateItem is a real function and the count still never
-- moves, so the question is whether the LETTER ITEM CLASS is valid at all. These separate the
-- two: a known-good class (one of the mod's own token MiscItems, which the dialog system
-- creates thousands of) is tried alongside the letter, into the same inventory.
mercenaries.BanditCampKnownGoodItem = "679a655e-189d-4519-b437-ccc4b92be41d"  -- hire-w1 token
-- A VANILLA Document (letter_huntsmanRenes, Type 5) - the control that separates "my Document
-- is malformed" from "inventory:CreateItem cannot instantiate a Document at all".
mercenaries.BanditCampVanillaDoc = "08a31823-a5c6-43f9-9b4b-27b8230a352f"

-- CreateItem RETURNS whether it actually made the item - the `cheat` mod in references/ uses
-- exactly that to probe which items the engine refuses ("some items are block by
-- inventory:CreateItem"). The first version of this harness threw the return value away and
-- only reported whether the CALL threw, which is why a refusal looked like a mystery no-op.
local function tryInto(inv, cls, label, log)
    local before, after, made = -1, -1, nil
    pcall(function() before = inv:GetCountOfClass(cls) or -1 end)
    local ok = pcall(function() made = inv:CreateItem(cls, 1, 1) end)
    pcall(function() after = inv:GetCountOfClass(cls) or -1 end)
    log(string.format("  %-14s call=%s made=%s  count %s -> %s  %s",
        label, tostring(ok), tostring(made), tostring(before), tostring(after),
        (after > before and after > 0) and "OK" or "FAILED"))
    return (after > before and after > 0)
end

-- Into the PLAYER's own inventory. If the letter fails here too, the item class is broken and
-- the chest was never the problem.
function mercenaries:BanditCampItemTest()
    if not (player and player.inventory) then qLog("no player inventory"); return end
    qLog("item test -> player inventory")
    local good   = tryInto(player.inventory, self.BanditCampKnownGoodItem, "known-good", qLog)
    local vanilla = tryInto(player.inventory, self.BanditCampVanillaDoc,   "vanilla doc", qLog)
    local ours   = tryInto(player.inventory, self.TokenIDBanditCampLetter, "letter", qLog)
    -- Only say something when there is something to say; printing every branch every time is
    -- how the last run read as a failure when all three had actually passed.
    if ours then
        qLog("all good - the letter can be created")
    elseif vanilla then
        qLog("vanilla doc works, ours does not -> our Document definition is at fault")
    elseif good then
        qLog("no Document can be created -> CreateItem refuses the whole type here")
    else
        qLog("even the known-good token failed - the inventory itself is not accepting items")
    end
end

-- Same two items, into the camp chest.
function mercenaries:BanditCampChestTest()
    local S = self.BCQ
    if not S.letterChestId then qLog("no chest recorded (is the camp up?)"); return end
    local e = System.GetEntity(S.letterChestId)
    if not (e and e.inventory) then qLog("chest has no inventory"); return end
    qLog("item test -> chest " .. tostring(e:GetName()))
    tryInto(e.inventory, self.BanditCampKnownGoodItem, "known-good", qLog)
    tryInto(e.inventory, self.TokenIDBanditCampLetter, "letter", qLog)
end

-- Straight grant, so the hand-in half of the quest can be tested without the chest at all.
function mercenaries:BanditCampGiveLetter()
    pcall(function()
        local cls = self:KleinkriegLetterClass() or self.TokenIDBanditCampLetter
        player.inventory:CreateItem(cls, 1, 1)
    end)
    qLog("letter granted; in pack = " .. tostring(self:BanditCampHasLetter()))
end

-- Deferred a beat so the hand-in has finished settling (and the dialog has closed) before the
-- next contract is written over the same BCQ table.
-- Kept only so a timer left over from a save taken before the offer was removed lands on
-- something harmless. It no longer takes the next contract: the quartermaster does not issue
-- this run any more, and re-issuing it here would be the same thing by another route.
function mercenaries.BanditCampChainNext()
    local self = mercenaries
    self.BCQ = self.BCQ_KK
    self:BanditCampRestorePatrols()
end

-- Everything that is cached in memory rather than saved has to be dropped and re-derived when
-- a save is loaded, or the session carries the previous one's answers. Called from the restore
-- path AND unconditionally on load, because a save taken with no contract running still has to
-- clear a stale contract out of memory.
-- Hand the roads back once nothing is running.
function mercenaries:BanditCampRestorePatrols()
    local S = self.BCQ
    if not S.patrolsWereOn then return end
    S.patrolsWereOn = nil
    pcall(function() self:LivePatrolSetEnabled(1) end)
end

function mercenaries:BanditCampResync()
    self.BCQ = self.BCQ_KK
    -- Re-read from the save rather than trusting this session.
    self._bcampCleared, self._kkPhaseDone = nil, nil
    -- Force the dialog gates to re-assert on the next tick: nil means "unknown", so both are
    -- pushed again whatever they turn out to be. Same for the bounty's pair.
    self._kkOpen, self._kkReady = nil, nil
    self._boOpen, self._boReady = nil, nil
    -- The column is rebuilt from scratch by AssignBanditCampRoles when the camp respawns; a
    -- chain of WUIDs from the previous session refers to entities that no longer exist.
    self.BanditCampColumn = {}
    -- Same for the per-contract cached contract index.
    local S = self.BCQ
    if not (S and S.active) then
        S.contractIdx, S.dispersed = nil, false
    end
    self:KleinkriegSyncPhase()
    self:KleinkriegSyncGates()
    qLog(string.format("resynced after load: %d contract(s) paid, contract %d is current",
        self:BanditCampCleared(), select(2, self:KleinkriegContract())))
end

-- A siege contract owns a whole standing battlefield; dropping the contract has to take it
-- down as well, or 170 pieces and a hundred men stay in the world with nothing tracking them.
function mercenaries:BanditCampClearSiege()
    pcall(function()
        if self.RBQ and self.RBQ.active and self.DespawnRaborsch then self:DespawnRaborsch() end
    end)
end

function mercenaries:BanditCampAbandon()
    self.BCQ = self.BCQ_KK
    self:BanditCampClearSiege()
    self:DespawnBanditCamp(false)
    self.BCQ.cleared = false
    qLog("contract abandoned and camp removed")
end

-- The quartermaster no longer offers this run (Aleksej's nine beats are the Kleinkrieg quest),
-- so this is the only way left to start one. Kept for testing the contract machinery itself.
mercenaries:DevCommand("merc_banditcamp_start",   "mercenaries:BanditCampAccept()",  "Take a Kleinkrieg contract (debug: nobody issues these in game any more)")
mercenaries:DevCommand("merc_banditcamp_status",  "mercenaries:BanditCampStatus()",  "Contract state: site, group, kills, reward")
mercenaries:DevCommand("merc_banditcamp_abandon", "mercenaries:BanditCampAbandon()", "Drop the contract and remove the camp")
mercenaries:DevCommand("merc_banditcamp_clear",   "mercenaries:BanditCampComplete()","Force-complete the contract (debug)")
mercenaries:DevCommand("merc_banditcamp_alert",   "mercenaries:BanditCampAlert('console')", "Wake the camp up now (debug)")
mercenaries:DevCommand("merc_banditcamp_resync", "mercenaries:BanditCampResync()", "Re-derive the arc state after a load (debug)")
mercenaries:DevCommand("merc_banditcamp_reset",   "mercenaries:SaveString('BCampDone','0')", "Restart the camp run from the first site (debug)")
mercenaries:DevCommand("merc_banditcamp_chest_probe", "mercenaries:BanditCampChestProbe()", "Report what the camp chest entity exposes (letter diagnostics)")
mercenaries:DevCommand("merc_banditcamp_item_test",  "mercenaries:BanditCampItemTest()",  "Try a known-good item AND the letter into the player's inventory")
mercenaries:DevCommand("merc_banditcamp_chest_test", "mercenaries:BanditCampChestTest()", "Try a known-good item AND the letter into the camp chest")
mercenaries:DevCommand("merc_banditcamp_give_letter","mercenaries:BanditCampGiveLetter()","Put the letter straight in the player's pack (test the hand-in)")
mercenaries:DevCommand("merc_bcamp_site_here",    "mercenaries:BanditCampSiteHere()","Print a BanditCampSites row for where you stand")
