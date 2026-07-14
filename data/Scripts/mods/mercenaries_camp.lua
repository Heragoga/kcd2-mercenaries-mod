-- Procedural mercenary camp: spawns tents/fire/chairs/beds near the player,
-- moves the squad in, and idles them (guards patrol, the rest sit/sleep). Camp
-- props are plain BasicEntity + object_Model spawns; the whole feature is
-- session-only (never restored across save/load - ClearAnyLeftoverCamp sweeps
-- leftovers by name). See docs/camp.md for the full design and postmortems.

mercenaries.CampModels = {
    -- Small/standard tent, kept for potential reuse.
    TentSmall = "objects/manmade/structures/living/tents/tent_small_shabby_a.cgf",
    -- Fallback single tent model - the real camp layout instead picks
    -- randomly from CampTentVariants for visual variety, see SpawnMercCamp.
    TentLarge = "objects/manmade/structures/living/tents/tent_small_forest_a.cgf",
    -- The only bed model
    -- that reads as an actual bed rather than a rag/skins/blob in tall
    -- grass - both tiers use it now (no more separate "nicer" tent-tier bed).
    Bed       = "objects/manmade/common_furniture/beds/low/bed_shabby_a.cgf",
    BedStraw  = "objects/manmade/common_furniture/beds/low/bed_shabby_a.cgf",
    Chair     = "objects/manmade/common_furniture/chairs/low/chair_rustic_d.cgf",
    Stool     = "objects/manmade/common_furniture/chairs/low/chair_trunk_c.cgf",
    -- The single seating ring around each campfire uses these small vertical
    -- log stumps (chair_trunk_c - the same seat the sit activities used during
    -- testing, which read well) rather than a horizontal log bench.
    Log       = "objects/manmade/common_furniture/chairs/low/chair_trunk_c.cgf",
    Sack      = "objects/manmade/common_furniture/sacks/sack_b.cgf",
    -- Chest is no longer spawned in camp (see SpawnMercCamp) but kept
    -- defined in case it's wanted again later.
    Chest     = "objects/manmade/common_furniture/chests/chest-small-a.cgf",
    -- Reads in-game as an actual stack of weapons - used for one seat per
    -- fire cluster, see SpawnMercCamp.
    WeaponStack = "objects/manmade/common_decorations/weapons/polearm_pile_a.cgf",
}

-- Campfires spawn via Game.SpawnPrefab against an invisible anchor entity
-- (spawn an anchor, Hide it, then Game.SpawnPrefab(anchor.id, prefabId, 0)) -
-- the technique references/zdjbcamping_mod's DJB_Camping:SpawnCampfirePrefab
-- uses. A pre-authored prefab already has its wood/particle/light pieces
-- correctly aligned, so this avoids per-model Z-offset/rotation guessing and
-- the invisible-prop problems that hand-picked .cgf paths ran into.
-- CampFirePrefabId is fireplace_on_camp.xml's own Prefab Id - the vanilla
-- "reference lit campfire" (fireplace_wood_c.cgf + a nosmoke fire particle +
-- a Light, all pre-aligned).
mercenaries.CampFirePrefabId = "84b335ee-22f2-411e-b3da-97f13575370c"

-- The old campfire model, overlaid on the fireplace_on_camp ash-heap prefab
-- for a fuller wood-pile look (see SpawnCampFirePrefab).
mercenaries.CampFireOverlayModel = "objects/manmade/task_specific_props/food_processing/cooking/camp_cooking_c_old.cgf"

-- Vanilla one-NPC sleeper tents (same footprint/facing) - one picked at random
-- per tent for variety.
mercenaries.CampTentVariants = {
    "objects/manmade/structures/living/tents/tent_small_forest_a.cgf",
    "objects/manmade/structures/living/tents/tent_small_forest_b.cgf",
    "objects/manmade/structures/living/tents/tent_small_forest_d.cgf",
    "objects/manmade/structures/living/tents/tent_small_shabby_a.cgf",
    "objects/manmade/structures/living/tents/tent_small_rustic_a.cgf",
}

-- Random sack/crate spawned beside each merc tent.
mercenaries.CampTentClutterVariants = {
    "objects/manmade/common_furniture/sacks/sack_b.cgf",
    "objects/manmade/common_furniture/sacks/sack_pig_feed.cgf",
    "objects/manmade/common_furniture/sacks/sack_charcoal.cgf",
    "objects/manmade/common_furniture/crates/crate_low_b.cgf",
    "objects/manmade/common_furniture/crates/crate_small.cgf",
}

-- Where the tent-side clutter prop sits relative to its own tent - right/
-- forward are in the tent's own local space (same convention as
-- CampBedOffset). Toggling `forward` (tried both +0.9 and -0.9) never
-- actually moved the prop toward/away from the fire - the wrong axis: the
-- tent's own frame here already has CampTentFacingFix's extra 90-degree
-- rotation baked into it (see SpawnMercCamp - `angle` is tentFaceAngle +
-- math.pi + CampTentFacingFix, not just tentFaceAngle + math.pi), so
-- `right`, not `forward`, ends up aligned with the tent<->fire axis -
-- negative `right` is toward the fire/inside the ring, positive is away/
-- outside. Swapped per feedback ("try the other axis") - `right` now
-- carries the toward-fire offset, `forward` the side offset. Scaled down to
-- a small ~0.2m nudge per follow-up feedback (was right=-0.9/forward=2.1) -
-- just enough to keep it off the tent/bed centerline. Still a guess, not
-- yet checked in-game.
mercenaries.CampTentClutterOffset = { right = 0.8, forward = -1, z = 0 }

-- Where mercs stand relative to their own bed, so they're not planted right
-- on top of it: right/forward are in the bed's own local space (relative to
-- its facing angle, which already includes CampBedOffset's rotationDeg).
-- forward = 1.3 (bed) + 0.5 (further from the tent, per feedback) = 1.8.
mercenaries.CampMercStandOffset = { right = 0.8, forward = -1.3, z = 0 }

-- Player tent: one central tent + a real, player-usable bed, spawned once per
-- camp. SpawnPlayerCampTent spawns the bed (a BasicEntity carrying the vanilla
-- bed smart-object properties) plus a separate vanilla BedTrigger next to it,
-- empty-name-linked to the bed - that trigger, not an OnUsed handler, drives the
-- "E - Sleep" prompt and lying stance. See docs/camp.md "The player tent".
mercenaries.CampPlayerTentModel = "objects/manmade/structures/living/tents/tent_big_round_a.cgf"
mercenaries.CampPlayerBedModel = mercenaries.CampModels.Bed
-- White/round tents face opposite the small ones - CampTentFacingFix plus
-- another half turn. Computed inside SpawnPlayerCampTent (not here) because
-- CampTentFacingFix is defined further down this file, so referencing it now
-- would evaluate to nil and error the script load.
mercenaries.CampPlayerBedOffset = { right = 0, forward = 1, z = 0, rotationDeg = 180 }
-- BedTrigger placement relative to the bed's centre/facing and its
-- interaction-volume scale. Tunable if the "E - Sleep" prompt is awkward.
mercenaries.CampPlayerBedTriggerOffset = { right = 0, forward = 0, z = 0.4 }
mercenaries.CampPlayerBedTriggerScale = { 0.7, 0.7, 0.7 }

-- Spawns the player's own tent + usable bed once, at `centerPos` - the
-- camp grid's own center (see SpawnMercCamp; the whole cluster grid is laid
-- out around this same point now, with the tile directly in front of it
-- reserved as empty space, so the player tent no longer needs a dedicated
-- grid slot of its own). `facingAngle` is the world-space direction the
-- tent's entrance should open toward (SpawnMercCamp passes the "front" the
-- rest of the grid is built around, so the reserved empty tile lines up
-- with the tent's own entrance) - CampTentFacingFix corrects for the
-- model's own facing convention on top of that, same as every other tent.
-- Not part of any merc's cluster. See the big comment above for why the bed
-- is a BasicEntity + SO properties + a linked vanilla BedTrigger (for the
-- "E - Sleep" interaction) rather than a new custom entity class.
function mercenaries:SpawnPlayerCampTent(centerPos, facingAngle)
    local ok, err = pcall(function()
        local tentPos = self:CampSnapToGround(centerPos)
        -- +45 degrees on top of the grid-derived facing per feedback, then
        -- +30 more (75 total) per follow-up feedback.
        local tentAngle = (facingAngle or 0) +  math.rad(130)

        self:SpawnCampPropModel(self.CampPlayerTentModel, tentPos, tentAngle, "MercCampProp_PlayerTent")

        local bedPos, bedAngle = self:CampRelativeOffset(tentPos, tentAngle, self.CampPlayerBedOffset)
        bedPos = self:CampSnapToGround(bedPos)

        -- The bed itself - a smart-object bed. Properties copied from
        -- references/zdjbcamping_mod's DJB_BedEntity (including the Bed and
        -- Script sub-tables) so it registers as the exact same vanilla bed
        -- smart object; the BedTrigger below is what makes it interactable.
        local bedEnt = System.SpawnEntity({
            class = "BasicEntity",
            name = "MercCampProp_PlayerBed_" .. tostring(math.random(100000, 999999)),
            position = bedPos,
            properties = {
                object_Model = self.CampPlayerBedModel,
                bMissionCritical = false,
                guidSmartObjectType = "425d4fdf-8dcd-4a2b-fdc5-cbb1b5d25b89",
                soclass_SmartObjectHelpers = "Bed_1Place_Low",
                sWH_AI_EntityCategory = "Bed",
                sSittingTagGlobal = "sittingNoTable",
                fUsabilityDistance = 1.25,
                bInteractiveCollisionClass = true,
                Script = {
                    esBedTypes = "GroundBed",
                },
                Bed = {
                    esSleepQuality = "low",
                    esReadingQuality = "bed_ground",
                },
            }
        })

        if bedEnt then
            pcall(function() bedEnt:SetAngles({ x = 0, y = 0, z = bedAngle }) end)
            pcall(function() bedEnt:SetViewDistUnlimited() end)
            pcall(function() bedEnt:RenderShadow(true) end)
            table.insert(self.CampEntities, bedEnt.id)

            self:SpawnCampBedTrigger(bedEnt, bedPos, bedAngle)
        end
    end)
    if not ok then
        System.LogAlways('[Mercenaries] SpawnPlayerCampTent error: ' .. tostring(err))
    end
end

-- Spawns a vanilla BedTrigger next to `bedEnt` and links it, giving the bed
-- the "E - Sleep" interaction. This is the same thing
-- references/zdjbcamping_mod does in DJB_Camping:SpawnBedTrigger +
-- LinkBedEntities: a BedTrigger (an ActionTrigger subclass) with a Click
-- block whose action lies the player down, linked to the bed by an
-- EMPTY-NAMED link (ActionTrigger:GetLinkedSmartObject returns the first link
-- whose name == "", and uses that entity's smart object as the thing to lie
-- on). The reverse "mTrigger" link mirrors what the camping mod sets up.
function mercenaries:SpawnCampBedTrigger(bedEnt, bedPos, bedAngle)
    local ok, err = pcall(function()
        local triggerPos = self:CampRelativeOffset(bedPos, bedAngle, self.CampPlayerBedTriggerOffset)

        local trigger = System.SpawnEntity({
            class = "BedTrigger",
            name = "MercCampProp_BedTrigger_" .. tostring(math.random(100000, 999999)),
            position = triggerPos,
            scale = self.CampPlayerBedTriggerScale,
            properties = {
                InteractorPriorityOverride = 1,
                Click = {
                    bIsActive = true,
                    bedEntity = bedEnt,
                    UseMessage = "@ui_hud_sleep",
                    bAllowNoOwner = 0,
                    bCheckOwner = 0,
                    esActionType = "Stance",
                    sAction = "lying",
                },
            }
        })

        if trigger then
            table.insert(self.CampEntities, trigger.id)
            -- Empty-named link trigger -> bed is the one GetLinkedSmartObject
            -- finds; the "mTrigger" back-link mirrors the camping mod.
            pcall(function() trigger:CreateLink("", bedEnt.id) end)
            pcall(function() bedEnt:CreateLink("mTrigger", trigger.id) end)
        end
    end)
    if not ok then
        System.LogAlways('[Mercenaries] SpawnCampBedTrigger error: ' .. tostring(err))
    end
end

-- Property sets for the StanceSmartObject entities that let a merc actually
-- sit/lie down (see SpawnCampFurnitureSO below, the sit/sleep assignment in
-- SpawnMercCamp, and the incamp-sitter/sleeper cases in mercenary_follow.xml).
--
-- IMPORTANT - the first attempt at this put these properties directly on the
-- bed/stool BasicEntity prop, and mercs just stood around. That's not how the
-- game does it. Every vanilla sit/sleep spot is a PREFAB containing two
-- separate objects: the visual brush (the bed/bench model) and a dedicated
-- `StanceSmartObject` entity holding the smart object. See
-- references/Prefabs/Bed/bed_low.xml (which uses our exact bed_shabby_a.cgf
-- model) and references/Prefabs/Bench/bench_1place_low.xml - in both, a
-- BedTrigger/ActionTrigger and a SchedulerHub *link* to the StanceSmartObject,
-- they never carry the SO properties themselves. StanceSmartObject
-- (references/Scripts/Entities/WH/Bed/StanceSmartObject.lua) is a vanilla
-- class whose own doc comment reads "Smart object representing a place where
-- stance can be played. Intended for sitting and lying stance both for NPCs
-- and player" - exactly what we need, and spawnable by name the same way the
-- vanilla BedTrigger already is. Values below are copied verbatim from those
-- two prefabs. The `stance` field is what mercenary_follow.xml's StanceElement
-- passes; it is NOT an entity property (stripped before spawning).
mercenaries.CampBedSO = {
    stance = "lying",
    guidSmartObjectType = "425d4fdf-8dcd-4a2b-fdc5-cbb1b5d25b89",
    soclass_SmartObjectHelpers = "Bed_1Place_Low",
    sWH_AI_EntityCategory = "Bed",
    Script = { esBedTypes = "GroundBed" },
    Bed = { esSleepQuality = "low", esReadingQuality = "bed_ground" },
}
mercenaries.CampChairSO = {
    stance = "sitting",
    guidSmartObjectType = "57cbebae-c19a-443b-8945-999d8ee87955",
    soclass_SmartObjectHelpers = "Sit_1Place_Bench_Low",
    sWH_AI_EntityCategory = "Seat",
    Script = { esBedTypes = "Chair" },
    Bed = { esReadingQuality = "bench_notable" },
}

-- Sitter tuning, per feedback ("a bit off center", "should always be rotated
-- towards the campfire"). The Sit_1Place_Bench_Low helper places the seated
-- pose relative to the smart object, and it's authored for a bench rather
-- than our small trunk stool, so the merc lands slightly off the stool's
-- middle. CampSitSOOffset shifts the SMART OBJECT (not the visible stool)
-- in the seat's own local frame to re-centre the pose; CampSitFacingFixDeg
-- is added to the "face the campfire" angle if the pose comes out rotated.
mercenaries.CampSitSOOffset = { right = 0.2, forward = 0, z = 0 }
-- Degrees added to the seat's "face the fire" angle. Left at 0: reliably turning
-- a seated merc to the fire turned out not to be controllable from the seat's
-- rotation (the sit pose ignores it), so this is a no-op knob for now - the seat
-- orients toward the fire but the merc's own facing is left to the engine.
mercenaries.CampSitFacingFixDeg = 0

-- (The per-merc activity spot radius moved outside the tent circle - see
-- CampActivityOutsideGap in the schedule section below.)

-- Camp activities: named NPC animations played via the UnstanceAction BT node.
-- Modes recorded per entry: 1 = sit on a seat smart object then play; 2 = stand,
-- no anchor; 3 = stand aligned to an anchor entity (needs `prop`); 4 = stand duo
-- leader (partner plays `partner`). `prop`/`prop2` = decorative models at the
-- spot. Which names actually look right was found with merc_camp_activity_test;
-- the per-name verdicts and the underlying rules are in docs/camp.md.
mercenaries.CampActivityCatalogue = {
    -- ---- CONFIRMED WORKING ----
    { name = "sword_training", unstance = "noob_sword_training",        mode = 2, note = "WORKS - sparring drill, mimes without a weapon; needs open space" },
    { name = "eat_standing",   unstance = "eating_standing",            mode = 2, note = "WORKS - eats, spawns its own bun" },
    { name = "snooze",         unstance = "camper_snooze",              mode = 1, note = "WORKS - dozing off, seated" },
    { name = "pick_herbs",     unstance = "PickingHerbsNPC",            mode = 2, note = "WORKS VERY WELL - foraging/gathering from the ground" },
    { name = "loot",           unstance = "Loot",                       mode = 2, note = "WORKS - rummaging through something on the ground" },
    { name = "cook_fire",      unstance = "woman_cookingCampfire_loop", mode = 2, prop = "objects/manmade/task_specific_props/food_processing/cooking/camp_cooking_c_old.cgf", prop2 = "objects/manmade/task_specific_props/household/cooking_eating/kettles/kettle_a.cgf", note = "WORKS - stirs a pot; now spawns fire + kettle so there is one" },
    { name = "stretch",        unstance = "Stretching",                 mode = 2, note = "works - plain emote" },
    { name = "arms_crossed",   unstance = "waiting_armsCrossed",        mode = 2, note = "works - plain emote" },
    { name = "look_around",    unstance = "waiting_nervous_lookingAround_noObject", mode = 2, note = "works - plain emote" },

    -- ---- SEATED, round-2 verdict: none worked even with the locationObject
    -- fix. The likely cause is what round-2 feedback guessed - they need a
    -- HELD ITEM (book/dice/flute/spindle/cup) or a TABLE smart object that the
    -- fragment doesn't bring, the seated equivalent of the sword drill miming
    -- with empty hands. Giving a merc a specific item means real inventory/
    -- equip work, so these stay test-only and out of the schedule for now.
    -- The two "noTable" body-language ones need no item and are the best bets
    -- if any seated variety is wanted later.
    { name = "sit_nervous",    unstance = "specialSittingActivity_male_noTable_nervous", mode = 1, note = "no-item seated fidget - best re-try candidate" },
    { name = "sit_sad",        unstance = "specialSittingActivity_male_noTable_sad",     mode = 1, note = "no-item seated brooding - best re-try candidate" },
    { name = "x_sit_read",     unstance = "readingSittingNoTable",       mode = 1, note = "needs a book in hand" },
    { name = "x_sit_drink",    unstance = "specialSittingActivity_male_noTable_drinking_01", mode = 1, note = "needs a cup in hand" },
    { name = "x_sit_dice",     unstance = "diceSitting",                 mode = 1, note = "needs dice" },
    { name = "x_sit_flute",    unstance = "flutist_sitting",             mode = 1, note = "needs a flute" },
    { name = "x_sit_spindle",  unstance = "housekeeper_spindle",         mode = 1, note = "needs a spindle" },
    { name = "x_sit_chat_teller",   unstance = "SittingTableChatTeller",  mode = 1, note = "name says Table - needs a table SO, not a stool" },
    { name = "x_sit_chat_listener", unstance = "SittingTableChatListener", mode = 1, note = "needs a table SO" },

    -- ---- mode 5/6: two-merc conversation (REWORKED after round 2) ----
    -- The bodyguards-mod GOSSIP polylog did nothing here - our custom souls
    -- have no GOSSIP polylog content. Now built from proven pieces: both turn
    -- to face each other and the speaker plays one of the mod's own
    -- a614a_story* monolog lines (the same aliases the idle barks use, which
    -- audibly work), looking at the listener. Lua rotates the alias randomly.
    { name = "converse",       mode = 5, note = "GOSSIP polylog between two mercs (bodyguards technique); this is also automatic in camp via CampChatTick" },

    -- ---- KNOWN BROKEN, kept so we don't retry them ----
    { name = "x_chop_wood",    unstance = "lumberjack_woodChopping", mode = 3, note = "BROKEN - needs axe + authored align points" },
    { name = "x_saw_wood",     unstance = "sawingWood",              mode = 3, note = "BROKEN - needs saw + align points" },
    { name = "x_sweep",        unstance = "sweeping",                mode = 2, note = "BROKEN (round 2)" },
    { name = "x_stoke_fire",   unstance = "butcherSmokeHouseStoke",  mode = 2, note = "BROKEN (round 2)" },
    { name = "x_smokehouse",   unstance = "butcherSmokeHouseFill",   mode = 2, note = "BROKEN (round 2)" },
    { name = "x_alchemy",      unstance = "alchemy",                 mode = 2, note = "plays but mimes at an invisible bench (round 2)" },
    { name = "x_soldier_bored", unstance = "ratbor2_SoldierBored",   mode = 2, note = "BROKEN (round 2)" },
    { name = "x_guard_attention", unstance = "halberdierGuard_atAttention", mode = 2, note = "BROKEN (round 2)" },
    { name = "x_point",        unstance = "Pointing_withoutScope",   mode = 2, note = "just points at the player (round 2)" },
    { name = "x_cheer",        unstance = "mildCheering",            mode = 2, note = "BROKEN (round 2)" },
    { name = "x_show_off",     unstance = "sermiri_showOff",         mode = 2, note = "draws + resheathes, nothing interesting (round 2)" },
    { name = "x_sharpen",      unstance = "camper_knifeSharpening",  mode = 1, note = "BROKEN - needs a knife in hand" },
    { name = "x_repair_gear",  unstance = "camper_repairGear",       mode = 1, note = "BROKEN - needs kit in hand" },
    { name = "x_eat_sitting",  unstance = "eating",                  mode = 1, note = "sits, then stands to eat; retest w/ locationObject fix or use eat_standing" },
    { name = "x_dig",          unstance = "digging",                 mode = 2, note = "BROKEN" },
}

-- How long a merc holds an activity before it loops again.
mercenaries.CampActivityHoldSeconds = 25

-- [mercWuidStr] = { unstance=, mode=, locWuid=, pos={x,y,z}, slaveWuid= }
mercenaries.CampActivities = {}

-- Camp daily schedule: each non-guard tent merc owns a set of spots (bed, stool,
-- stand, training slot) and cycles through CampRoleCycle (trainers use
-- CampTrainerCycle), staggered per merc. RotateCampRoles (MonitorCamp's 5s tick)
-- advances everyone a step; mercs then walk to the next spot themselves, which
-- reads as camp life. sit/snooze/sleep pull from shared pools and pick a spot
-- further from the merc to create movement. See docs/camp.md.
mercenaries.CampRoleCycle = { "sleep", "sit", "eat", "herbs", "snooze" }
mercenaries.CampTrainerCycle = { "train", "sit", "train", "eat", "train", "sleep" }
-- At night (CampIsNight, 9pm-6am) each role rotation has this chance to be
-- overridden to "sleep" instead of the cycle step, so most of the camp beds
-- down after dark (per feedback that too few slept at night).
mercenaries.CampNightSleepChance = 0.75
-- How long a merc holds each role, in SECONDS (a random span). Sleeps and sits
-- run long (2-5 min per feedback); the rest are shorter so the camp keeps
-- shuffling. Training is deliberately short - the drill animation is long, so a
-- short hold keeps it from running on (and overrunning a break-camp).
mercenaries.CampRoleSeconds = {
    sleep  = { 120, 300 },
    sit    = { 120, 300 },
    snooze = { 120, 300 },
    eat    = { 40, 80 },
    herbs  = { 40, 90 },
    train  = { 25, 45 },
}
mercenaries.CampMercSpots = {}   -- [mercWuidStr] = { actPos=, firePos=, trainPos=, trainFacePos=, isTrainer=, lastPos= }
mercenaries.CampRoleIdx = {}     -- [mercWuidStr] = current index into that merc's cycle
mercenaries.CampNextRotate = {}  -- [mercWuidStr] = absolute CampTicks at which this merc next rotates
mercenaries.CampTicks = 0
mercenaries.CampSeats = {}       -- shared log seats: { { wuid=, pos=, angle=, occupant= }, ... }
mercenaries.CampBeds = {}        -- shared tent beds: { { wuid=, pos=, occupant= }, ... }

-- Radius of the single log seating ring around each campfire (per feedback).
mercenaries.CampFireSeatRadius = 1.7

-- eat/herbs "gather" spot sits OUTSIDE the tent circle per earlier feedback, at
-- CampTentRingRadius + this gap, staggered half a slot so it lands between
-- tents (a clear sightline to the fire) rather than behind their own tent.
mercenaries.CampActivityOutsideGap = 1.6

-- TRAINING YARD (per feedback: right in front of the player tent, a little
-- space in between; up to five straw dummies, one per five mercs). Placed
-- CampTrainingYardDistance metres BEHIND the player tent (along -forward), in
-- the (0, -1) tile CampGridOffsets reserves for it (the empty tile is (0, 1),
-- in front). Dummies are laid out in a row across the yard
-- (target_straw/target_stand from the vanilla combat prop set); trainees stand
-- on the camp side facing them.
mercenaries.CampTrainingYardDistance = 8.0
mercenaries.CampTrainingDummyModels = {
    "objects/manmade/task_specific_props/combat/archery/target_straw.cgf",
    "objects/manmade/task_specific_props/combat/archery/target_stand.cgf",
}
mercenaries.CampTrainingDummySpacing = 1.6   -- between dummies, along the row
mercenaries.CampTrainingTraineeSetback = 2.2 -- how far in front of the dummies trainees stand
mercenaries.CampTrainingTraineeSpacing = 1.5 -- between trainees, along the row

-- Camp conversations (bodyguards technique). CONCURRENT: CampChatTick pairs up
-- ALL eligible nearby mercs each tick, not just one pair, and publishes them in
-- _G.MercCampChats[wuidStr] = { partner=wuid, role=1|2, alias=..., age=ticks }.
-- Each merc's follow BT reads its own entry and the pair runs the aliased gossip
-- polylog (no greeting). The initiator ends its pair the moment its sequence
-- finishes (EndCampChat); the per-pair `age` below is only a stuck-pair safety
-- net (e.g. a participant despawned before EndCampChat ran), kept just above the
-- BT's own 5m safety Timeout so it never cuts a real conversation short.
--
-- Cadence: NO global gap (conversations overlap freely). Instead every merc has
-- a PER-MERC cooldown so it chats roughly once every CampChatMercCooldownTicks
-- (5 min). The cooldowns are staggered on camp start (each merc seeded with a
-- random 0..max) so conversations spread out over the window rather than all
-- firing at once, then re-applied when each conversation ends.
mercenaries.CampChatHoldTicks = 72   -- 5s ticks: stuck-pair safety only (~6 min)
mercenaries.CampChatMercCooldownTicks = 60  -- per-merc: ~5 min between a merc's conversations
mercenaries.CampChatRadius = 4.0     -- max metres between two mercs to pair them
mercenaries.CampMaxConcurrentChats = 2   -- most conversations running at once, camp-wide
mercenaries.CampChatMercCooldown = {}    -- wuidStr -> remaining ticks of per-merc cooldown
mercenaries.CampChatStaggered = false    -- one-time per-camp cooldown seeding done?

-- Our own two-NPC camp gossips (Decision Alias of each gossip_merc_*.xml, played
-- by the follow BT's polylog step exactly like the mod's monolog stories are
-- played by their alias). CampChatTick tags each new pair with a random one; the
-- BT tries it first and falls back to the vanilla GOSSIP pool if it can't play.
mercenaries.CampGossipAliases = {
    "merc_gossip_2", "merc_gossip_3", "merc_gossip_4", "merc_gossip_5",
    "merc_gossip_6", "merc_gossip_7", "merc_gossip_8", "merc_gossip_9", "merc_gossip_10",
    "merc_gossip_11", "merc_gossip_12", "merc_gossip_13", "merc_gossip_14", "merc_gossip_15",
    "merc_gossip_16", "merc_gossip_17", "merc_gossip_18", "merc_gossip_19", "merc_gossip_20",
    "merc_gossip_21", "merc_gossip_22", "merc_gossip_23", "merc_gossip_24", "merc_gossip_25",
    "merc_gossip_26", "merc_gossip_27", "merc_gossip_28", "merc_gossip_29", "merc_gossip_30",
    "merc_gossip_31", "merc_gossip_32", "merc_gossip_33", "merc_gossip_34", "merc_gossip_35",
    "merc_gossip_36", "merc_gossip_37", "merc_gossip_38", "merc_gossip_39", "merc_gossip_40",
}

-- Caps keep large squads from spawning an absurd number of props (and keep
-- the layout from ballooning past a sane footprint).
mercenaries.CampMaxTents      = 100
-- Hard cap on camping tiles (6 tents each), per spec ("at most ten camping
-- tiles"). A squad whose non-guards need more than this many tiles spills the
-- excess onto the straw-bed outer ring rather than tiling endlessly.
mercenaries.CampMaxCampingTiles = 10
-- Camp is built from repeating "cells": one campfire, up to CampClusterSize
-- seats around it, and up to CampClusterSize tents (each with a bed) around
-- that ("6 tents around a camp fire" per feedback). Squads bigger than one
-- cell tile additional cells in a grid (see SpawnMercCamp) instead of piling
-- everyone around a single fire.
mercenaries.CampClusterSize   = 6
-- Tents around each cluster's fire are placed on a ring sized for this many
-- slots (see SpawnMercCamp's tent-ring placement) even though at most
-- CampClusterSize tents actually get spawned into it - "calculate with there
-- being seven tents, but leave one spot empty" per feedback, so a full
-- 6-tent cluster always leaves exactly one ring slot open as a gap mercs (and
-- the player) can walk through, rather than a fully closed circle of tents.
mercenaries.CampClusterTentRingSlots = 7
-- Radius of each cluster's tent ring around its fire: 6.0, halved to 3.0 per
-- earlier feedback, then bumped 30% to 3.9 (tents a bit further apart). Named
-- so the patrol ring can size itself relative to the outermost tents (see the
-- guard-assignment loop in SpawnMercCamp).
mercenaries.CampTentRingRadius = 3.9
-- Distance the patrol navnode ring sits beyond the outermost tent, per
-- feedback ("navnodes placed at a distance of about 3m from the nearest
-- tent"). Patrol radius = (farthest cluster from centre) + CampTentRingRadius
-- + this clearance, so the ring encircles the whole camp ~3m outside the
-- tents rather than cutting through them.
mercenaries.CampPatrolTentClearance = 3.0
-- Guard density cap: at most one patroller per this many metres of patrol-ring
-- route length (see the guard-count route cap in SpawnMercCamp). Parties up to
-- ~15 keep the half-the-squad split; bigger ones get thinned so the perimeter
-- isn't crowded. 12 = midpoint of the "1 per 10-15 m" spec.
mercenaries.CampPatrolSpacing = 12.0
-- Was 18.0, then a third of that (6.0) per earlier feedback, then +1m
-- (7.0), then +50% on top of that (10.5) per follow-up feedback - grid
-- tiles (player tent / fire clusters) kept growing further apart each
-- round.
mercenaries.CampClusterSpacing = 10.5
-- No longer a hard cap - guard count is now half the squad (originally a
-- third, per "a third of mercs should be going around the camp at all
-- times", bumped to half per follow-up feedback), picked at random,
-- computed directly in SpawnMercCamp. Kept defined so anything external
-- still referencing it doesn't break.
mercenaries.CampMaxPatrollers = 3

-- Ground-validation tuning (CampValidateSpot / SpawnMercCamp): decides whether a
-- cluster cell is buildable ground vs a roof/hillside/tree/step. See docs/camp.md
-- "Ground validation" for the reasoning behind these thresholds.
mercenaries.CampClusterFootprint = 3.0                 -- half-width (m) of the probe-ray square around a cell
mercenaries.CampProbeStartHeight = 50.0                -- rays start this high so a tree/roof top registers on the way down
mercenaries.CampProbeDepth       = 30.0
mercenaries.CampMaxSlopeCos = math.cos(math.rad(28))   -- reject ground steeper than ~28deg
mercenaries.CampMaxStep = 1.2                          -- max height spread (m) across a cell, and per-probe spike threshold
mercenaries.CampMaxRise = 2.0                          -- higher than this above player level = roof/ledge/tree top
mercenaries.CampMaxDrop = 4.0                          -- lower than this below = pit / floor under a building
mercenaries.CampMaxProbeCells = 60                     -- cells SpawnMercCamp probes before giving up (bounds raycast cost)

-- Fine heightmap classifier (CampSampleHeightmap / CampClassifyHeightmap): a dense
-- 0.5m grid sorted into valid/obstacle/building/void by connectivity, so slopes
-- stay valid and only sharp steps cut off. See docs/camp.md.
mercenaries.CampSampleStep = 0.5      -- sample resolution (m)
mercenaries.CampConnectStep = 0.5     -- height delta between adjacent samples that counts as an edge, not the same surface
mercenaries.CampSmallClumpMax = 5     -- obstacle clumps this size or smaller = tree/rock (tolerable); bigger = building

-- Tile layout tuning (CampBuildMap / the tile loop in SpawnMercCamp): the camp is
-- chosen on a coarse grid of square tiles judged from the fine classification
-- above. See docs/camp.md for the full scheme.
mercenaries.CampTileHalf = 5.25                        -- half-size (m) of one layout tile (a campfire unit's footprint)
mercenaries.CampTileMaxInvalidFrac = 0.5               -- a camping tile may be at most this fraction invalid
mercenaries.CampTileClearFrac = 0.8                    -- player-tent/training tiles need this fraction valid and no building clump
-- Prop footprints (half-width x half-depth, m); a footprint passes if <= CampFootprintSlack cells are invalid.
mercenaries.CampTentFootHalf   = { w = 1.0, h = 2.25 }
mercenaries.CampFireFootHalf    = { w = 1.25, h = 1.25 }
mercenaries.CampPlayerTentFootHalf = { w = 2.25, h = 2.25 }
mercenaries.CampFootprintSlack  = 2
mercenaries.CampMercFootprint   = 0.6                  -- footprint FindValidGround checks per single spawn/teleport spot
mercenaries.CampNudgeStep = 0.5                        -- prop nudge step/limit to dodge an obstacle before placing least-bad
mercenaries.CampNudgeMax  = 3
mercenaries.CampMapMaxRadius = 22.0                    -- caps the one-time raycast burst; tiles beyond fall back to CampValidateSpot
mercenaries.CampCenterSearch     = 2.0                 -- player-tent placement search grid (most-valid-ground wins), kept small
mercenaries.CampCenterSearchStep = 1.0
-- A column whose high ray hits this far above the player's feet counts as under a
-- roof; such columns are marked unbuildable so the camp forms on open ground.
mercenaries.CampRoofDetectHeight = 3.0

-- Bed placement relative to its own tent: right/forward in tent-local space, z a
-- world vertical offset, rotationDeg relative to the tent's facing.
mercenaries.CampBedOffset = { right = 0, forward = 0, z = 0, rotationDeg = 90 }

-- Tents were coming out of SpawnCampProp facing 90 degrees off from where
-- they should - this is added on top of the computed facing angle whenever
-- a tent is spawned in the real camp layout (not in the tent-comparison
-- row, which shows raw/unrotated orientations on purpose). Flip the sign if
-- it turns out to be the wrong direction.
mercenaries.CampTentFacingFix = math.pi / 2

mercenaries.CampActive    = false
mercenaries.CampEntities  = {}   -- list of spawned entity ids, for teardown
mercenaries.CampSlots     = {}   -- [wuidStr] = {x,y,z} idle position per merc
mercenaries.CampCenter    = nil  -- {x,y,z}, kept for reference/patrol waypoints
mercenaries.CampPatrollers = {}  -- [mercWuidStr] = { waypoints={ {x,y,z}, ... }, index= } - perimeter positions, see SpawnMercCamp's guard-assignment loop
mercenaries.CampFurniture  = {}  -- [mercWuidStr] = { wuid=furnitureSOWuid, kind="bed"/"chair" } - a non-guard merc's assigned sit/sleep smart object, see SpawnMercCamp + GetCampFurniture
mercenaries.CampCommunalChairs = {} -- unused - kept declared for back-compat

-- Ground-snap a position via the same terrain raycast GetSafeSpawnPosition uses.
function mercenaries:CampSnapToGround(pos)
    local ok, result = pcall(function()
        local hitTable = {}
        local start = { x = pos.x, y = pos.y, z = pos.z + 5.0 }
        local dir = { x = 0, y = 0, z = -100 }
        local hits = Physics.RayWorldIntersection(start, dir, 2, ent_terrain + ent_static, 0, nil, hitTable)
        if hits > 0 and hitTable[1] and hitTable[1].pos then
            return { x = pos.x, y = pos.y, z = hitTable[1].pos.z }
        end
        return pos
    end)
    if ok and result then return result end
    return pos
end

-- Validate whether a tent/cluster can sit on the ground at `pos`, by firing a
-- cluster of downward probe rays over a CampClusterFootprint square: the centre
-- probe rejects steep normals and ground that sits too far above/below the
-- player's level (a roof/ledge/pit), and eight edge probes reject steps and tree
-- trunks. Leaf canopies pass through (camping under one is fine). Returns valid,
-- groundZ, reason. See docs/camp.md "Ground validation" for the full rationale.
function mercenaries:CampValidateSpot(pos, refZ, footprint)
    footprint = footprint or self.CampClusterFootprint
    refZ = refZ or pos.z

    local function probe(px, py)
        local hitTable = {}
        local start = { x = px, y = py, z = refZ + self.CampProbeStartHeight }
        local dir   = { x = 0, y = 0, z = -(self.CampProbeStartHeight + self.CampProbeDepth) }
        local ok, hz, hn = pcall(function()
            local hits = Physics.RayWorldIntersection(start, dir, 2, ent_terrain + ent_static, 0, nil, hitTable)
            if hits > 0 and hitTable[1] and hitTable[1].pos then
                return hitTable[1].pos.z, hitTable[1].normal
            end
            return nil, nil
        end)
        if ok then return hz, hn end
        return nil, nil
    end

    local cz, cnormal = probe(pos.x, pos.y)
    if not cz then return false, pos.z, "no_ground" end          -- over a hole/void

    if cnormal and cnormal.z and cnormal.z < self.CampMaxSlopeCos then
        return false, cz, "too_steep"                            -- hillside
    end
    if cz - refZ > self.CampMaxRise then return false, cz, "too_high" end  -- roof/tree/ledge
    if refZ - cz > self.CampMaxDrop then return false, cz, "too_low" end   -- pit/cliff

    local offs = {
        { footprint, 0 }, { -footprint, 0 }, { 0, footprint }, { 0, -footprint },
        { footprint, footprint }, { footprint, -footprint }, { -footprint, footprint }, { -footprint, -footprint },
    }
    local minZ, maxZ = cz, cz
    for _, o in ipairs(offs) do
        local hz = probe(pos.x + o[1], pos.y + o[2])
        if hz then
            if hz - cz > self.CampMaxStep then return false, cz, "obstacle" end  -- trunk/rock/wall in footprint
            if hz < minZ then minZ = hz end
            if hz > maxZ then maxZ = hz end
        end
    end
    if (maxZ - minZ) > self.CampMaxStep then return false, cz, "uneven" end       -- step/cliff edge

    return true, cz, "ok"
end

-- Heightmap sampler: one downward ray per cell of a (2*radius+1)^2 grid at
-- `spacing` m around `origin`, returning z[i][j] ground heights (nil = void).
-- Raw input to CampClassifyHeightmap. See docs/camp.md.
function mercenaries:CampSampleHeightmap(origin, radius, spacing, underRoof)
    spacing = spacing or self.CampSampleStep
    local refZ = origin.z
    local highStart = refZ + self.CampProbeStartHeight
    local bottomZ = refZ - self.CampProbeDepth
    local roofThresh = self.CampRoofDetectHeight

    -- One downward ray from absolute height `fromZ`; returns hit z or nil.
    local function probe(wx, wy, fromZ)
        local hitTable = {}
        local ok, hz = pcall(function()
            local hits = Physics.RayWorldIntersection({ x = wx, y = wy, z = fromZ },
                { x = 0, y = 0, z = -(fromZ - bottomZ) }, 2, ent_terrain + ent_static, 0, nil, hitTable)
            if hits > 0 and hitTable[1] and hitTable[1].pos then return hitTable[1].pos.z end
            return nil
        end)
        return ok and hz or nil
    end

    local z = {}
    local roof = {}
    for i = 0, 2 * radius do
        z[i] = {}
        roof[i] = {}
        for j = 0, 2 * radius do
            local wx = origin.x + (i - radius) * spacing
            local wy = origin.y + (j - radius) * spacing
            local hi = probe(wx, wy, highStart)
            z[i][j] = hi
            -- Per-cell roof test: in under-roof mode, a column whose high ray
            -- hits well ABOVE the player is under a roof. The engine snaps a
            -- spawned prop onto that roof regardless of the z we ask for, so
            -- such a column is UNBUILDABLE - flag it invalid. A column whose
            -- high ray reaches ~ground level has stepped OUT from under the
            -- roof (outside the walls) and stays normal ground. So an indoor
            -- camp marks the whole building footprint invalid and everything
            -- past the walls valid - "once it reaches out-of-building tiles
            -- those are good to go".
            if underRoof and hi and (hi - refZ) >= roofThresh then
                roof[i][j] = true
            end
        end
    end
    return { r = radius, spacing = spacing, origin = origin, refZ = refZ, z = z, roof = roof }
end

-- Heightmap classifier: flood the walkable surface out from a seed cell (the
-- player's feet), stepping to a neighbour only when |dz| <= CampConnectStep, so
-- slopes stay connected but steps don't. Reached cells are "valid"; unreached
-- clumps are "small" (tree/rock) or "building" by size; no-ground is "void".
-- Returns cls[i][j] and a counts table. See docs/camp.md.
function mercenaries:CampClassifyHeightmap(hm, seedI, seedJ)
    local r, z, roofg = hm.r, hm.z, hm.roof
    local step = self.CampConnectStep
    local cls = {}
    for i = 0, 2 * r do cls[i] = {} end

    local function inb(i, j) return i >= 0 and i <= 2 * r and j >= 0 and j <= 2 * r end
    local function isRoof(i, j) return roofg and roofg[i] and roofg[i][j] end
    -- A cell is buildable ground only if it has a hit AND isn't a roof column
    -- (under a roof = the engine would spawn the prop on the roof, so it's a
    -- hard no-build).
    local function hasZ(i, j) return z[i] and z[i][j] ~= nil and not isRoof(i, j) end
    local NB = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }

    -- Seed defaults to the centre; if that column is a void OR a roof (the
    -- player is standing inside a building), spiral out to the nearest buildable
    -- cell so the flood starts on real open ground - the camp then forms outside
    -- the walls rather than on the roof.
    seedI = seedI or r
    seedJ = seedJ or r
    if not hasZ(seedI, seedJ) then
        local found = false
        for rad = 1, r do
            for di = -rad, rad do
                for dj = -rad, rad do
                    local i, j = seedI + di, seedJ + dj
                    if not found and inb(i, j) and hasZ(i, j) then
                        seedI, seedJ, found = i, j, true
                    end
                end
            end
            if found then break end
        end
    end

    -- 1. Flood the walkable surface from the seed.
    local ground = {}
    if hasZ(seedI, seedJ) then
        local stack = { { seedI, seedJ } }
        ground[seedI .. "," .. seedJ] = true
        while #stack > 0 do
            local c = table.remove(stack)
            local cz = z[c[1]][c[2]]
            for _, d in ipairs(NB) do
                local ni, nj = c[1] + d[1], c[2] + d[2]
                local nk = ni .. "," .. nj
                if inb(ni, nj) and not ground[nk] and hasZ(ni, nj) and math.abs(z[ni][nj] - cz) <= step then
                    ground[nk] = true
                    table.insert(stack, { ni, nj })
                end
            end
        end
    end

    -- 2. Label every cell; size the leftover obstacle clumps.
    local seen = {}
    local counts = { valid = 0, small = 0, building = 0, void = 0 }
    for i = 0, 2 * r do
        for j = 0, 2 * r do
            local key = i .. "," .. j
            if isRoof(i, j) then
                -- under a roof: unbuildable (a prop would land on the roof)
                cls[i][j] = "building"; counts.building = counts.building + 1
            elseif not hasZ(i, j) then
                cls[i][j] = "void"; counts.void = counts.void + 1
            elseif ground[key] then
                cls[i][j] = "valid"; counts.valid = counts.valid + 1
            elseif not seen[key] then
                -- Flood this obstacle clump (joined by small internal steps).
                local comp = {}
                local stack = { { i, j } }
                seen[key] = true
                while #stack > 0 do
                    local c = table.remove(stack)
                    table.insert(comp, c)
                    local cz = z[c[1]][c[2]]
                    for _, d in ipairs(NB) do
                        local ni, nj = c[1] + d[1], c[2] + d[2]
                        local nk = ni .. "," .. nj
                        if inb(ni, nj) and not seen[nk] and not ground[nk] and hasZ(ni, nj)
                            and math.abs(z[ni][nj] - cz) <= step then
                            seen[nk] = true
                            table.insert(stack, { ni, nj })
                        end
                    end
                end
                local kind = (#comp <= self.CampSmallClumpMax) and "small" or "building"
                for _, c in ipairs(comp) do
                    cls[c[1]][c[2]] = kind
                    counts[kind] = counts[kind] + 1
                end
            end
        end
    end

    return cls, counts
end

-- Under-roof detection: sample the player's own column from high up; a hit
-- CampRoofDetectHeight+ above their feet means a roof overhead (a tree canopy
-- passes through, no false positive). Gates the per-cell roof sampling.
-- Returns underRoof(bool), ceilingZ(or nil).
function mercenaries:CampDetectRoof(playerPos)
    local refZ = playerPos.z
    local hitTable = {}
    local ok, roofZ = pcall(function()
        local hits = Physics.RayWorldIntersection(
            { x = playerPos.x, y = playerPos.y, z = refZ + self.CampProbeStartHeight },
            { x = 0, y = 0, z = -(self.CampProbeStartHeight + self.CampProbeDepth) },
            2, ent_terrain + ent_static, 0, nil, hitTable)
        if hits > 0 and hitTable[1] and hitTable[1].pos then return hitTable[1].pos.z end
        return nil
    end)
    if ok and roofZ and (roofZ - refZ) >= self.CampRoofDetectHeight then
        return true, roofZ
    end
    return false, nil
end

-- Camp map: a classified heightmap (sampler + classifier) built once per camp,
-- remembering its geometry so a world (x,y) maps back to a cell class.
function mercenaries:CampBuildMap(center, radius, underRoof)
    local hm = self:CampSampleHeightmap(center, radius, self.CampSampleStep, underRoof)
    local cls = self:CampClassifyHeightmap(hm, radius, radius)
    return { hm = hm, cls = cls, center = center, r = radius, spacing = self.CampSampleStep }
end

-- Class ("valid"/"small"/"building"/"void") at a world (x,y), or nil if the
-- point falls outside the sampled map.
function mercenaries:CampMapClassAt(map, wx, wy)
    if not map then return nil end
    local i = math.floor((wx - map.center.x) / map.spacing + 0.5) + map.r
    local j = math.floor((wy - map.center.y) / map.spacing + 0.5) + map.r
    if i < 0 or i > 2 * map.r or j < 0 or j > 2 * map.r then return nil end
    return map.cls[i] and map.cls[i][j]
end

-- World {x, y} of the nearest "valid" cell to (wx, wy) in the map, searched in
-- growing rings, or nil if the map has no valid ground. Used to move the whole
-- camp out of a building: if the player's own spot is under a roof (invalid),
-- the camp origin jumps to the closest open ground - the doorway / nearest
-- exterior tile.
function mercenaries:CampNearestValidCell(map, wx, wy)
    if not map then return nil end
    local ci = math.max(0, math.min(2 * map.r, math.floor((wx - map.center.x) / map.spacing + 0.5) + map.r))
    local cj = math.max(0, math.min(2 * map.r, math.floor((wy - map.center.y) / map.spacing + 0.5) + map.r))
    for rad = 0, 2 * map.r do
        for di = -rad, rad do
            for dj = -rad, rad do
                if math.max(math.abs(di), math.abs(dj)) == rad then
                    local i, j = ci + di, cj + dj
                    if i >= 0 and i <= 2 * map.r and j >= 0 and j <= 2 * map.r
                        and map.cls[i] and map.cls[i][j] == "valid" then
                        return { x = map.center.x + (i - map.r) * map.spacing,
                                 y = map.center.y + (j - map.r) * map.spacing }
                    end
                end
            end
        end
    end
    return nil
end

-- Counts cells inside a rectangular footprint centred at `wpos`, oriented by
-- `angle` (its local +forward), half-width `halfW` (right axis) x half-depth
-- `halfH` (forward axis), stepping at the map resolution. Returns
-- valid, total, hasBuilding. Cells outside the map count as invalid (not
-- valid) but don't set hasBuilding.
function mercenaries:CampFootprintStats(map, wpos, angle, halfW, halfH)
    local fwd = { x = math.cos(angle), y = math.sin(angle) }
    local rgt = { x = -fwd.y, y = fwd.x }
    local step = map.spacing
    local valid, total, hasBuilding = 0, 0, false
    local a = -halfW
    while a <= halfW + 1e-6 do
        local b = -halfH
        while b <= halfH + 1e-6 do
            local wx = wpos.x + rgt.x * a + fwd.x * b
            local wy = wpos.y + rgt.y * a + fwd.y * b
            local c = self:CampMapClassAt(map, wx, wy)
            total = total + 1
            if c == "valid" then
                valid = valid + 1
            elseif c == "building" then
                hasBuilding = true
            end
            b = b + step
        end
        a = a + step
    end
    return valid, total, hasBuilding
end

-- True if a prop footprint at (wpos, angle) sits on mostly-valid ground -
-- at most CampFootprintSlack invalid cells. Used to accept, or to score
-- nudges for, tents/fires/the player tent.
function mercenaries:CampFootprintOk(map, wpos, angle, half)
    if not map then return true end   -- no map (fallback) -> don't block placement
    local valid, total = self:CampFootprintStats(map, wpos, angle, half.w, half.h)
    return (total - valid) <= self.CampFootprintSlack, valid, total
end

-- Nudges `basePos` (in its local right/forward frame) over a small search to
-- find the spot whose footprint has the fewest invalid cells; returns the best
-- position found. Tents/beds are never skipped - the least-bad spot is used -
-- so every non-guard keeps a tent and the furniture pools stay intact.
function mercenaries:CampNudgeToValid(map, basePos, angle, half)
    if not map then return basePos end
    local ok, bestValid = self:CampFootprintOk(map, basePos, angle, half)
    if ok then return basePos end
    local best = basePos   -- bestValid = valid-cell count of basePos, from CampFootprintOk above
    for ring = 1, self.CampNudgeMax do
        local d = ring * self.CampNudgeStep
        for _, off in ipairs({ { d, 0 }, { -d, 0 }, { 0, d }, { 0, -d }, { d, d }, { -d, d }, { d, -d }, { -d, -d } }) do
            local cand = self:CampRelativeOffset(basePos, angle, { right = off[1], forward = off[2] })
            local v, t = self:CampFootprintStats(map, cand, angle, half.w, half.h)
            if (t - v) <= self.CampFootprintSlack then
                return cand    -- first clean spot wins
            end
            if v > bestValid then best, bestValid = cand, v end
        end
    end
    return best
end

-- Spawns one decorative camp prop given a raw model path. Tracked in
-- CampEntities for teardown. Used directly where a prop needs to pick from
-- several possible models (e.g. random tent variants - see SpawnMercCamp);
-- SpawnCampProp (below) is the usual modelKey-based entry point.
-- (Used to also merge smart-object properties from CampFurnitureSO onto the
-- entity here so mercs could sit/lie in it - disabled, see file header.)
-- `trackList` (optional) is the table the spawned entity id is recorded in for
-- teardown; defaults to CampEntities. The activity-test commands pass their own
-- list so clearing them can't disturb a live camp.
function mercenaries:SpawnCampPropModel(model, pos, angleZ, namePrefix, trackList)
    if not model or model == "" then return nil end

    local groundPos = self:CampSnapToGround(pos)
    local name = (namePrefix or "MercCampProp") .. "_" .. tostring(math.random(100000, 999999))

    local ent = System.SpawnEntity({
        class = "BasicEntity",
        name = name,
        position = groundPos,
        properties = {
            object_Model = model,
            bMissionCritical = false,
        }
    })

    if ent then
        pcall(function() ent:SetAngles({ x = 0, y = 0, z = angleZ or 0 }) end)
        pcall(function() ent:SetViewDistUnlimited() end)
        pcall(function() ent:RenderShadow(true) end)
        table.insert(trackList or self.CampEntities, ent.id)
    end

    return ent
end

-- Spawns one decorative camp prop by CampModels key. Tracked in
-- CampEntities for teardown.
function mercenaries:SpawnCampProp(modelKey, pos, angleZ)
    local model = self.CampModels[modelKey]
    if not model then return nil end
    return self:SpawnCampPropModel(model, pos, angleZ, "MercCampProp_" .. modelKey)
end

-- Spawns a bed/stool a merc can actually sit/lie in, the way the vanilla
-- prefabs do it (see the CampBedSO/CampChairSO comment): TWO entities - the
-- visual prop (a plain BasicEntity with the model, no smart-object properties)
-- and, at the same spot and facing, a dedicated `StanceSmartObject` entity
-- carrying the smart-object properties from `soProps`. Only the
-- StanceSmartObject is a real smart object; that's what a StanceElement has to
-- target, and that's what the earlier version got wrong by putting the SO
-- properties on the prop itself.
--
-- Returns the StanceSmartObject's AI WUID (XGenAIModule.GetMyWUID - a spawned
-- entity's plain .id is not a valid smart-object handle) and the ground
-- position, both of which mercenary_follow.xml needs: it Moves the merc to the
-- position first (StanceElement does not appear to navigate on its own - the
-- vanilla scheduler walks the NPC to the spot before running the smart
-- object's `use` behaviour), then runs the StanceElement against the WUID.
-- Both entities are tracked in CampEntities for teardown.
function mercenaries:SpawnCampFurnitureSO(model, pos, angleZ, namePrefix, soProps, soPosOverride, trackList)
    if not model or model == "" then return nil, nil end

    local groundPos = self:CampSnapToGround(pos)
    angleZ = angleZ or 0

    -- 1. The visual prop - purely decorative, no SO properties.
    self:SpawnCampPropModel(model, groundPos, angleZ, namePrefix, trackList)

    -- 2. The smart object itself. Normally co-located with the prop, but
    -- callers can nudge it (soPosOverride) when the SO helper's authored pose
    -- doesn't land centred on our particular prop - see the sitter stool.
    local soGroundPos = soPosOverride and self:CampSnapToGround(soPosOverride) or groundPos
    local wuid = nil
    local ok, err = pcall(function()
        -- Orientation MUST be set at spawn time (orientation = euler radians,
        -- the format every SpawnEntity call in this mod uses). A StanceSmartObject
        -- caches its sit/lie helper transform when it is created; SetAngles AFTER
        -- spawn moves the visible entity but NOT that cached helper, so a merc
        -- sitting on it would face the default world direction (why every seated
        -- merc used to face the same way regardless of the fire). SetAngles is
        -- kept too, to keep the entity's own transform consistent.
        local soEnt = System.SpawnEntity({
            class = "StanceSmartObject",
            name = (namePrefix or "MercCampProp") .. "_SO_" .. tostring(math.random(100000, 999999)),
            position = soGroundPos,
            orientation = { x = 0, y = 0, z = angleZ },
            properties = {
                guidSmartObjectType = soProps.guidSmartObjectType,
                soclass_SmartObjectHelpers = soProps.soclass_SmartObjectHelpers,
                sWH_AI_EntityCategory = soProps.sWH_AI_EntityCategory,
                Script = soProps.Script,
                Bed = soProps.Bed,
            }
        })

        if soEnt then
            pcall(function() soEnt:SetAngles({ x = 0, y = 0, z = angleZ }) end)
            table.insert(trackList or self.CampEntities, soEnt.id)
            wuid = XGenAIModule.GetMyWUID(soEnt)
        end
    end)
    if not ok then
        System.LogAlways('[Mercenaries] SpawnCampFurnitureSO error: ' .. tostring(err))
    end

    if not wuid then
        System.LogAlways('[Mercenaries] SpawnCampFurnitureSO: no WUID for StanceSmartObject (' .. tostring(soProps.soclass_SmartObjectHelpers) .. ') - merc will not sit/sleep here')
    end

    -- Return the SMART OBJECT's position (not the prop's) - that's the spot
    -- mercenary_follow.xml Moves the merc to before the StanceElement.
    return wuid, { x = soGroundPos.x, y = soGroundPos.y, z = soGroundPos.z }
end


-- Spawns a campfire via Game.SpawnPrefab against an invisible anchor entity.
-- The anchor is the only piece tracked in CampEntities / swept by name prefix
-- for teardown; the prefab's own spawned pieces (wood/particle/light) keep the
-- names authored into the prefab, so removing the anchor (BreakMercCamp
-- iterates CampEntities) is relied on to take them with it.
--
-- The prefab alone renders as a small smouldering ash heap, so
-- CampFireOverlayModel is layered on top at the same position/facing for a
-- fuller "wood pile" look on top of the embers.
function mercenaries:SpawnCampFirePrefab(pos, angleZ, prefabId)
    local ok, err = pcall(function()
        local groundPos = self:CampSnapToGround(pos)
        local anchorEnt = System.SpawnEntity({
            class = "BasicEntity",
            name = "MercCampProp_FireAnchor_" .. tostring(math.random(100000, 999999)),
            position = groundPos,
            properties = { object_Model = "", bMissionCritical = false }
        })
        if anchorEnt then
            pcall(function() anchorEnt:SetAngles({ x = 0, y = 0, z = angleZ or 0 }) end)
            table.insert(self.CampEntities, anchorEnt.id)
            Game.SpawnPrefab(anchorEnt.id, prefabId or self.CampFirePrefabId, 0)
        end

        self:SpawnCampPropModel(self.CampFireOverlayModel, groundPos, angleZ or 0, "MercCampProp_FireOverlay")
    end)
    if not ok then
        System.LogAlways('[Mercenaries] SpawnCampFirePrefab error: ' .. tostring(err))
    end
end

-- (Patrol waypoints used to be spawned as invisible BasicEntity markers here
-- - SpawnCampWaypoint - and Moved to as entities. That didn't work: a plain
-- BasicEntity isn't registered with the AI system as a navigable target, so
-- pathfinding couldn't resolve it. Patrol now Moves to raw {x,y,z} positions
-- instead, so no marker entities are spawned at all - see the guard-
-- assignment loop in SpawnMercCamp.)

-- A merc is a camp "guard" if SpawnMercCamp gave them a patroller record
-- (a set of perimeter waypoints). Guards patrol; everyone else in camp just
-- stands. This is the "asks if he's a guard" check the schedulers/follow BT
-- run per merc while in camp - see the incamp handling in
-- mercenary_scheduler.xml / archer_scheduler.xml (routes guards into the
-- follow BT instead of the stand-still idle branch) and mercenary_follow.xml
-- (the actual patrol Move loop).
-- Camp deployment: the quartermaster can send a fraction of the squad (best-
-- equipped first) out of camp to follow the player while the rest keep camping.
-- Deployed mercs are tracked in CampOutParty; the camp accessors return nothing
-- for them (so the follow BT follows the player), but IsCampActor stays true so
-- the scheduler routes them to the follow branch, not idle-stand.
mercenaries.CampOutParty = {}   -- [wuidStr] = true : mercs deployed out of camp

function mercenaries:IsCampOut(mercWuid)
    return self.CampOutParty[tostring(mercWuid)] == true
end

-- "In a sortie" = out following the player (no camp at all, or a camp is up but
-- this merc was deployed); sortie mercs respect the wait order and teleport to
-- keep up, while in-camp mercs ignore it and follow their role. Keys off
-- _G.MercInCamp (mercs actually camping), not CampActive (structure exists), so
-- after RecallMercs (tents still standing) everyone counts as a sortie.
function mercenaries:IsMercInSortie(mercWuid)
    if not _G.MercInCamp then return true end
    return self:IsCampOut(mercWuid)
end

function mercenaries:IsMercInCampProper(mercWuid)
    return (_G.MercInCamp == true) and not self:IsCampOut(mercWuid)
end

function mercenaries:IsCampGuard(mercWuid)
    if not _G.MercInCamp or _G.MercenariesDismissed then return false end
    if self:IsCampOut(mercWuid) then return false end
    local rec = self.CampPatrollers and self.CampPatrollers[tostring(mercWuid)]
    return (rec and rec.waypoints and #rec.waypoints > 0) == true
end

-- Returns a non-guard camp merc's assigned furniture record { wuid=, kind= }
-- ("bed" -> sleep/lie, "chair" -> sit), or nil. Set by SpawnMercCamp for the
-- non-patrolling mercs (half sit, half sleep). mercenary_follow.xml reads this
-- and drives a StanceElement against the furniture's smart object.
function mercenaries:GetCampFurniture(mercWuid)
    if not _G.MercInCamp or _G.MercenariesDismissed then return nil end
    if self:IsCampOut(mercWuid) then return nil end
    return self.CampFurniture and self.CampFurniture[tostring(mercWuid)]
end

-- Returns a merc's assigned camp ACTIVITY record, or nil:
--   { unstance = "<NPCStateUnstanceDatabase name>", mode = 1..4,
--     pos = {x,y,z}, locWuid = <anchor/seat WUID or nil>, slaveWuid = <partner or nil> }
-- Deliberately NOT gated on _G.MercInCamp, so merc_camp_activity_test can play
-- an activity outside of camp; the activity case in mercenary_follow.xml is
-- first in the ContinuousSwitch, so it preempts patrol/sit/sleep/follow.
function mercenaries:GetCampActivity(mercWuid)
    if _G.MercenariesDismissed then return nil end
    if self:IsCampOut(mercWuid) then return nil end
    return self.CampActivities and self.CampActivities[tostring(mercWuid)]
end

-- True if this merc has ANY camp role (guard, assigned sit/sleep furniture, or
-- a camp activity) - i.e. should be routed into mercenary_follow's camp handling
-- rather than the schedulers' stand-still idle branch.
--
-- A deployed (sortie) merc is deliberately NOT a camp actor: it has no camp role,
-- so it drops into the `isIdle & ~isCampActor` idle branch when the player has
-- given a wait order, and into the follow branch otherwise - i.e. sortie mercs
-- respect global idle. (Camp no longer forces global idle on, so the in-camp
-- mercs are held in place by their roles, not by the idle flag.)
function mercenaries:IsCampActor(mercWuid)
    if self:GetCampActivity(mercWuid) ~= nil then return true end
    if self:IsCampGuard(mercWuid) then return true end
    return self:GetCampFurniture(mercWuid) ~= nil
end

-- Releases whatever spot `wuidStr` holds in a shared pool (CampSeats/CampBeds).
function mercenaries:ReleaseSpot(pool, wuidStr)
    for _, sp in ipairs(pool) do
        if sp.occupant == wuidStr then sp.occupant = nil end
    end
end

-- Claims a spot from a shared pool for `wuidStr`, preferring one a bit FURTHER
-- from `fromPos` (per feedback, to create walking): frees the merc's current
-- spot, then picks at random among the farther half of the free spots. Returns
-- the spot, or nil if the pool is full.
function mercenaries:ClaimSpot(pool, wuidStr, fromPos)
    self:ReleaseSpot(pool, wuidStr)
    local free = {}
    for _, sp in ipairs(pool) do
        if not sp.occupant then table.insert(free, sp) end
    end
    if #free == 0 then return nil end
    if fromPos then
        table.sort(free, function(a, b)
            local da = (a.pos.x - fromPos.x) ^ 2 + (a.pos.y - fromPos.y) ^ 2
            local db = (b.pos.x - fromPos.x) ^ 2 + (b.pos.y - fromPos.y) ^ 2
            return da > db
        end)
    end
    local topN = math.max(1, math.ceil(#free / 2))
    local pick = free[math.random(topN)]
    pick.occupant = wuidStr
    return pick
end

-- Points a non-guard camp merc at one occupation, using their spot record
-- (CampMercSpots) and the shared seat/bed pools. sit/snooze/sleep claim a spot
-- a bit further off to make them walk; eat/herbs use the merc's own outer spot;
-- train uses their training-yard slot. Exactly one of CampFurniture /
-- CampActivities holds the assignment afterward - the follow BT walks them there.
function mercenaries:ApplyCampRole(wuidStr, role)
    local s = self.CampMercSpots and self.CampMercSpots[wuidStr]
    if not s then return end

    self.CampFurniture[wuidStr] = nil
    self.CampActivities[wuidStr] = nil
    -- Give up any pooled seat/bed unless we're re-claiming the same kind below.
    if role ~= "sit" and role ~= "snooze" then self:ReleaseSpot(self.CampSeats, wuidStr) end
    if role ~= "sleep" then self:ReleaseSpot(self.CampBeds, wuidStr) end

    local from = s.lastPos or s.actPos

    if role == "sleep" then
        local bed = self:ClaimSpot(self.CampBeds, wuidStr, from)
        if bed then
            self.CampFurniture[wuidStr] = { wuid = bed.wuid, kind = "bed", pos = bed.pos }
            s.lastPos = bed.pos
        end
    elseif role == "sit" then
        local seat = self:ClaimSpot(self.CampSeats, wuidStr, from)
        if seat then
            self.CampFurniture[wuidStr] = { wuid = seat.wuid, kind = "chair", pos = seat.pos, facePos = seat.firePos }
            s.lastPos = seat.pos
        end
    elseif role == "snooze" then
        local seat = self:ClaimSpot(self.CampSeats, wuidStr, from)
        if seat then
            self.CampActivities[wuidStr] = { unstance = "camper_snooze", mode = 1, pos = seat.pos, locWuid = seat.wuid, facePos = seat.firePos }
            s.lastPos = seat.pos
        end
    elseif role == "eat" then
        self.CampActivities[wuidStr] = { unstance = "eating_standing", mode = 2, pos = s.actPos, facePos = s.firePos }
        s.lastPos = s.actPos
    elseif role == "herbs" then
        self.CampActivities[wuidStr] = { unstance = "PickingHerbsNPC", mode = 2, pos = s.actPos, facePos = s.firePos }
        s.lastPos = s.actPos
    elseif role == "train" then
        self.CampActivities[wuidStr] = { unstance = "noob_sword_training", mode = 2, pos = s.trainPos or s.actPos, facePos = s.trainFacePos }
        s.lastPos = s.trainPos or s.actPos
    end
end

-- The cycle a given merc follows (trainers get a training-heavy one).
function mercenaries:CampCycleFor(wuidStr)
    local s = self.CampMercSpots and self.CampMercSpots[wuidStr]
    if s and s.isTrainer then return self.CampTrainerCycle end
    return self.CampRoleCycle
end

-- Camp night window (9pm-6am): most mercs should be asleep then.
function mercenaries:CampIsNight()
    local ok, h = pcall(function() return Calendar.GetWorldHourOfDay() end)
    if not ok or type(h) ~= "number" then return false end
    return h >= 21 or h < 6
end

-- The role a merc should take this rotation: its normal cycle step, except at
-- night most mercs bed down (overrides even trainers, so nobody drills in the
-- dark). Returns the possibly-overridden role.
function mercenaries:CampRoleWithNightBias(role)
    if role ~= "sleep" and self:CampIsNight() and math.random() < self.CampNightSleepChance then
        return "sleep"
    end
    return role
end

-- Advances any camp merc whose per-role timer has elapsed to the next step of
-- their cycle, and schedules their next rotation from CampRoleSeconds. Called
-- from MonitorCamp each 5s tick. Per-merc timing (not a global rotation) is
-- what lets sleeps/sits run 2-5 min while shorter roles turn over quickly.
function mercenaries:RotateCampRoles()
    if not self.CampActive then return end
    local ok, err = pcall(function()
        for wuidStr in pairs(self.CampMercSpots or {}) do
            -- The camp blacksmith is pinned to the forge and opts out of the
            -- normal role rotation (see mercenaries_forge.lua).
            if wuidStr ~= self.CampForgeSmithWuid and not self:IsCampOut(wuidStr) and self.CampTicks >= (self.CampNextRotate[wuidStr] or 0) then
                local cycle = self:CampCycleFor(wuidStr)
                local idx = ((self.CampRoleIdx[wuidStr] or 0) % #cycle) + 1
                self.CampRoleIdx[wuidStr] = idx
                local role = self:CampRoleWithNightBias(cycle[idx])
                self:ApplyCampRole(wuidStr, role)
                local span = self.CampRoleSeconds[role] or { 60, 90 }
                local secs = math.random(span[1], span[2])
                -- ticks are 5s apart
                self.CampNextRotate[wuidStr] = self.CampTicks + math.max(1, math.floor(secs / 5))
            end
        end
    end)
    if not ok then
        System.LogAlways('[Mercenaries] RotateCampRoles error: ' .. tostring(err))
    end
end

-- Deploy the best-equipped `fraction` (0..1) of the living squad out of camp to
-- follow the player; the rest keep camping. "Best equipped" = highest tier (all
-- mercs share one outfit/weapon preset, so tier is the only per-merc gear
-- signal). Absolute: each call sets the out-party to exactly this fraction, so
-- "take a quarter" after "take half" leaves a quarter deployed.
function mercenaries:CampTakeParty(fraction)
    if not self.CampActive then
        Game.SendInfoText('merc_info_camp_not_active', false, 0, 3)
        return
    end
    fraction = fraction or 0.5
    local function tierRank(t) if t == "strong" then return 0 elseif t == "medium" then return 1 else return 2 end end

    local list = {}
    for name, ent in pairs(self.ActiveMercs) do
        if ent and self:IsAliveAndWell(ent, false) then
            local wuid = XGenAIModule.GetMyWUID(ent)
            local ws = wuid and tostring(wuid)
            -- Keep the pinned camp smith working at his forge.
            if ws and ws ~= self.CampForgeSmithWuid then
                table.insert(list, { ws = ws, tier = self:GetTierFromName(name) or "weak" })
            end
        end
    end
    local total = #list
    if total == 0 then return end
    local takeN = math.floor(total * fraction + 0.5)
    if takeN < 1 then takeN = 1 end
    if takeN > total then takeN = total end
    table.sort(list, function(a, b) return tierRank(a.tier) < tierRank(b.tier) end)

    -- Rebuild the out-party as exactly the top takeN. Clear the deployed mercs'
    -- camp assignment so they drop the activity and follow; anyone no longer in
    -- the party rejoins camp life on the next role rotation.
    self.CampOutParty = {}
    for i = 1, takeN do
        local ws = list[i].ws
        self.CampOutParty[ws] = true
        if self.CampActivities then self.CampActivities[ws] = nil end
        if self.CampFurniture then self.CampFurniture[ws] = nil end
        pcall(function() self:ReleaseSpot(self.CampSeats, ws) end)
        pcall(function() self:ReleaseSpot(self.CampBeds, ws) end)
    end
    Game.SendInfoText('merc_info_camp_deployed', false, 0, 4)
    System.LogAlways(string.format('[CampDeploy] deployed %d/%d mercs (best tier first)', takeN, total))
end

-- Teleport a merc entity back into the camp (near the centre, jittered so a
-- returning group doesn't stack) and queue an immediate camp-role reassignment.
-- SetPos from this Lua context (not the merc's own BT) sticks - see the camp
-- teleport rules. Silently no-ops if there's no camp/entity.
function mercenaries:CampTeleportToCamp(ent, ws)
    if not (ent and self.CampCenter) then return end
    pcall(function()
        local c = self.CampCenter
        local tp = self:CampSnapToGround({ x = c.x + (math.random() - 0.5) * 5.0,
                                           y = c.y + (math.random() - 0.5) * 5.0, z = c.z })
        ent:SetPos(tp)
    end)
    if ws and self.CampNextRotate then self.CampNextRotate[ws] = 0 end
end

-- Return the WHOLE sortie to camp. Each merc barks "on my way" and keeps
-- following (running) for a moment, THEN teleports into camp - so you see them
-- jog off and call out before they pop back, rather than blinking away instantly.
-- The delayed teleport + finalise happens in ProcessReturnPending (1s cadence).
-- (Used by the look-at "Back to camp" action and the console command.)
function mercenaries:CampReturnAll()
    if not self.CampActive then self.CampOutParty = {}; return end
    _G.MercReturnPending = _G.MercReturnPending or {}
    local any = false
    for name, ent in pairs(self.ActiveMercs) do
        local wuid = ent and XGenAIModule.GetMyWUID(ent)
        local ws = wuid and tostring(wuid)
        if ws and self.CampOutParty[ws] and not _G.MercReturnPending[ws] then
            self:RequestBark(wuid, "merc_bark_moveout")
            -- Stay out-party (following/running) during the countdown; ProcessReturnPending
            -- teleports and finalises when it hits 0. ~2 ticks = ~2s at the 1s cadence.
            _G.MercReturnPending[ws] = { ticks = 2, ent = ent }
            any = true
        end
    end
    if any then Game.SendInfoText('merc_info_camp_returned', false, 0, 4) end
end

-- Count down each pending return; when it hits zero teleport the merc into camp
-- and finalise (clear out-party so it rejoins camp life). Called every second
-- from MonitorLoop.
function mercenaries:ProcessReturnPending()
    local pend = _G.MercReturnPending
    if not pend then return end
    for ws, rec in pairs(pend) do
        rec.ticks = (rec.ticks or 0) - 1
        if rec.ticks <= 0 then
            self.CampOutParty[ws] = nil
            self:CampTeleportToCamp(rec.ent, ws)
            pend[ws] = nil
        end
    end
end

-- Camp practice yard (Practice Yard upgrade): its own structure (like the forge)
-- so it can be raised on camp make or the moment it's bought mid-camp. Spawns
-- straw dummies + a weapon pile on the reserved training tile; drilling mercs
-- come from the trainer role (CampTrainerCycle). Props track in CampEntities.
mercenaries.CampPracticeYard = nil   -- { numDummies=, trainCenter= } while up

function mercenaries:SpawnCampPracticeYard(center)
    if self.CampPracticeYard then return true end
    center = center or self.CampCenter
    if not center then return false end
    local fwdAng = self.CampForwardAngle or 0
    local trainCenter = self.CampTrainCenter or self:CampSnapToGround({
        x = center.x - math.cos(fwdAng) * self.CampTrainingYardDistance,
        y = center.y - math.sin(fwdAng) * self.CampTrainingYardDistance, z = center.z })
    local dummyFacing = fwdAng
    local traineeFacing = fwdAng + math.pi

    local n = 0
    for _, ent in pairs(self.ActiveMercs) do
        if ent and self:IsAliveAndWell(ent, false) then n = n + 1 end
    end
    local numDummies = math.max(1, math.min(5, math.ceil(math.max(n, 1) / 5)))

    for d = 1, numDummies do
        local off = (d - (numDummies + 1) / 2) * self.CampTrainingDummySpacing
        local dPos = self:CampRelativeOffset(trainCenter, traineeFacing, { right = off, forward = 0 })
        local model = self.CampTrainingDummyModels[((d - 1) % #self.CampTrainingDummyModels) + 1]
        self:SpawnCampPropModel(model, dPos, dummyFacing, "MercCampProp_Training")
    end
    -- A weapon pile off to one side dresses the yard.
    self:SpawnCampPropModel("objects/manmade/common_decorations/weapons/polearm_pile_a.cgf",
        self:CampRelativeOffset(trainCenter, traineeFacing, { right = numDummies * self.CampTrainingDummySpacing * 0.5 + 1.0, forward = -0.5 }),
        dummyFacing, "MercCampProp_Training")

    self.CampPracticeYard = { numDummies = numDummies, trainCenter = trainCenter }
    return true
end

-- Flag up to `n` in-camp mercs as trainers and start them drilling (used when the
-- yard is bought mid-camp; camp build does its own inline assignment). RotateCampRoles
-- then keeps them on the training-heavy CampTrainerCycle.
function mercenaries:AssignCampTrainers(n)
    local yard = self.CampPracticeYard
    if not yard then return end
    n = n or yard.numDummies or 1
    local assigned, idx = 0, 0
    for wuidStr, spots in pairs(self.CampMercSpots or {}) do
        if assigned >= n then break end
        if wuidStr ~= self.CampForgeSmithWuid and not self:IsCampOut(wuidStr) and not spots.isTrainer then
            spots.isTrainer = true
            local rowOff = (idx - (n - 1) / 2) * self.CampTrainingTraineeSpacing
            spots.trainPos = self:CampSnapToGround(self:CampRelativeOffset(yard.trainCenter, self.CampForwardAngle or 0, { right = rowOff, forward = self.CampTrainingTraineeSetback }))
            spots.trainFacePos = { x = yard.trainCenter.x, y = yard.trainCenter.y, z = yard.trainCenter.z }
            self.CampNextRotate[wuidStr] = 0
            idx = idx + 1
            assigned = assigned + 1
        end
    end
end

-- Return one deployed merc to camp (teleports them back). Kept for console use;
-- the look-at button returns the whole sortie via CampReturnAll.
function mercenaries:CampReturnMerc(mercWuid)
    local ws = tostring(mercWuid)
    if not self.CampOutParty[ws] then return end
    self.CampOutParty[ws] = nil
    local target
    for name, ent in pairs(self.ActiveMercs) do
        local wuid = ent and XGenAIModule.GetMyWUID(ent)
        if wuid and tostring(wuid) == ws then target = ent break end
    end
    self:CampTeleportToCamp(target, ws)
    Game.SendInfoText('merc_info_camp_returned', false, 0, 3)
end

-- Ends a conversation and applies the per-merc cooldown to both participants.
-- Given any merc in a pair, clears both its and its partner's entry from
-- _G.MercCampChats. Called by EndCampChat (initiator BT) and the stuck-pair
-- safety in CampChatTick.
function mercenaries:ClearCampChatPair(mercWuid)
    local chats = _G.MercCampChats
    if not chats then return end
    local w = tostring(mercWuid)
    local c = chats[w]
    if not c then return end
    chats[w] = nil
    self.CampChatMercCooldown[w] = self.CampChatMercCooldownTicks
    if c.partner then
        local pw = tostring(c.partner)
        chats[pw] = nil
        self.CampChatMercCooldown[pw] = self.CampChatMercCooldownTicks
    end
end

-- Ends the conversation `mercWuid` is in (called by the initiator BT when its
-- polylog sequence finishes).
function mercenaries:EndCampChat(mercWuid)
    self:ClearCampChatPair(mercWuid)
end

-- Pairs up ALL eligible nearby mercs each 5s tick (concurrent conversations),
-- seeds staggered per-merc cooldowns once per camp, and ages out stuck pairs.
function mercenaries:CampChatTick()
    if not self.CampActive then _G.MercCampChats = {} return end
    _G.MercCampChats = _G.MercCampChats or {}
    local chats = _G.MercCampChats
    local ok, err = pcall(function()
        -- Tick down per-merc cooldowns.
        for w, t in pairs(self.CampChatMercCooldown) do
            if t <= 1 then self.CampChatMercCooldown[w] = nil
            else self.CampChatMercCooldown[w] = t - 1 end
        end

        -- One-time stagger: seed every current merc with a random slice of the
        -- per-merc cooldown so their first conversations spread over the window
        -- rather than all firing on the same tick.
        if not self.CampChatStaggered then
            for _, ent in pairs(self.ActiveMercs) do
                if ent and self:IsAliveAndWell(ent, false) then
                    local w = tostring(ent.this and ent.this.id or ent.id)
                    self.CampChatMercCooldown[w] = math.random(0, self.CampChatMercCooldownTicks)
                end
            end
            self.CampChatStaggered = true
        end

        -- Age active pairs; force-clear any that overran the stuck-pair safety.
        -- Only role-1 entries carry the age, so each pair is counted once.
        local expired = {}
        for w, c in pairs(chats) do
            if c.role == 1 then
                c.age = (c.age or 0) + 1
                if c.age >= self.CampChatHoldTicks then table.insert(expired, w) end
            end
        end
        for _, w in ipairs(expired) do self:ClearCampChatPair(w) end

        -- Collect eligible mercs: alive, not already chatting, not on cooldown,
        -- not fighting, not mid-drill, with a position.
        local list = {}
        for _, ent in pairs(self.ActiveMercs) do
            if ent and self:IsAliveAndWell(ent, false) then
                local wuid = ent.this and ent.this.id or ent.id
                local wuidStr = tostring(wuid)
                -- Deployed (sortie) mercs are following the player, not sitting in
                -- camp - they must never be pulled into a full-stop conversation
                -- (only monologs/barks for them). Skip them here.
                if not chats[wuidStr] and not self.CampChatMercCooldown[wuidStr] and not self:IsCampOut(wuidStr) then
                    local p = nil
                    pcall(function() p = ent:GetWorldPos() end)
                    local hasTarget = false
                    pcall(function() hasTarget = self.MercTargetOf and self.MercTargetOf[wuidStr] ~= nil end)
                    local act = self.CampActivities[wuidStr]
                    local isTraining = act and act.unstance == "noob_sword_training"
                    if wuid and p and not hasTarget and not isTraining then
                        table.insert(list, { wuid = wuid, p = p })
                    end
                end
            end
        end

        -- Count conversations already running (one role-1 entry per pair) so we
        -- never exceed CampMaxConcurrentChats camp-wide.
        local activePairs = 0
        for _, c in pairs(chats) do if c.role == 1 then activePairs = activePairs + 1 end end

        -- Shuffle so pairings aren't biased by iteration order, then greedily
        -- pair eligible mercs within radius - up to the concurrent-conversation cap.
        for i = #list, 2, -1 do
            local j = math.random(i)
            list[i], list[j] = list[j], list[i]
        end
        local r2 = self.CampChatRadius * self.CampChatRadius
        local used = {}
        for i = 1, #list do
            if activePairs >= self.CampMaxConcurrentChats then break end
            if not used[i] then
                for j = i + 1, #list do
                    if not used[j] then
                        local dx, dy = list[i].p.x - list[j].p.x, list[i].p.y - list[j].p.y
                        if (dx * dx + dy * dy) <= r2 then
                            local a, b = list[i].wuid, list[j].wuid
                            local alias = self.CampGossipAliases[math.random(#self.CampGossipAliases)]
                            chats[tostring(a)] = { partner = b, role = 1, alias = alias, age = 0 }
                            chats[tostring(b)] = { partner = a, role = 2, alias = alias }
                            used[i] = true; used[j] = true
                            activePairs = activePairs + 1
                            break
                        end
                    end
                end
            end
        end
    end)
    if not ok then
        System.LogAlways('[Mercenaries] CampChatTick error: ' .. tostring(err))
    end
end

-- Returns the {x,y,z} POSITION of a guard's current target waypoint, or nil
-- if this merc isn't a guard (or has no waypoints). Called from
-- mercenary_follow.xml each patrol step to pick the next Move destination
-- (which is a vec3, not an entity - see the guard-assignment loop in
-- SpawnMercCamp for why).
function mercenaries:GetPatrolWaypoint(mercWuid)
    if self:IsCampOut(mercWuid) then return nil end
    local rec = self.CampPatrollers and self.CampPatrollers[tostring(mercWuid)]
    if not rec or not rec.waypoints or #rec.waypoints == 0 then return nil end
    return rec.waypoints[rec.index]
end

-- Advances a guard to the next waypoint in their loop. Called from
-- mercenary_follow.xml once a Move to the current waypoint completes.
function mercenaries:AdvancePatrolWaypoint(mercWuid)
    local rec = self.CampPatrollers and self.CampPatrollers[tostring(mercWuid)]
    if not rec or not rec.waypoints or #rec.waypoints == 0 then return end
    rec.index = (rec.index % #rec.waypoints) + 1
end

-- Returns a position on a ring of the given radius around center, plus the
-- angle used (so callers can face props toward the ring center).
function mercenaries:CampRingPos(center, radius, index, count, angleOffset)
    local n = math.max(count, 1)
    local angle = (angleOffset or 0) + (index - 1) * (2 * math.pi / n)
    local pos = {
        x = center.x + math.cos(angle) * radius,
        y = center.y + math.sin(angle) * radius,
        z = center.z
    }
    return pos, angle
end

-- Returns a position/angle offset from (basePos, baseAngle) by `offset`
-- ({right, forward, z, rotationDeg}), where right/forward are in the local
-- space defined by baseAngle (e.g. a tent's own facing) rather than world
-- axes. Used to place a bed relative to its tent - see CampBedOffset, and
-- the merc_camp_bed_test console command for finding good offset values.
function mercenaries:CampRelativeOffset(basePos, baseAngle, offset)
    local forward = { x = math.cos(baseAngle), y = math.sin(baseAngle) }
    local right = { x = -forward.y, y = forward.x }
    local pos = {
        x = basePos.x + right.x * (offset.right or 0) + forward.x * (offset.forward or 0),
        y = basePos.y + right.y * (offset.right or 0) + forward.y * (offset.forward or 0),
        z = basePos.z + (offset.z or 0),
    }
    return pos, baseAngle + math.rad(offset.rotationDeg or 0)
end

-- Returns the first `count` grid cell offsets (as {dx, dy} integer pairs,
-- dx = right/left of the player tent, dy = forward(+)/behind(-) of it) that
-- fire clusters should fill, per feedback: "first behind, left, right, then
-- the corners - notice one grid is left empty in front of the player tent",
-- "then more and more if there are more mercenaries". (0, 0) is the player
-- tent itself and is never returned; (0, 1) - directly in front of the
-- player tent - is never returned either, so there's always open ground to
-- walk out into. The immediate ring around the player tent (Chebyshev
-- distance 1) has exactly 7 other cells once (0, 1) is excluded, matching
-- the order asked for; further rings (for squads needing more than 7
-- clusters) are walked in a similar spirit - starting directly behind and
-- sweeping around the perimeter - without a fully bespoke ordering, since
-- realistic squad sizes shouldn't need them.
function mercenaries:CampGridOffsets(count)
    local offsets = {}
    local ring = 1
    while #offsets < count do
        local ringCells = {}
        if ring == 1 then
            ringCells = { { 0, -1 }, { -1, 0 }, { 1, 0 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }
        else
            local r = ring
            table.insert(ringCells, { 0, -r })
            for x = -1, -r, -1 do table.insert(ringCells, { x, -r }) end
            for y = -r + 1, r do table.insert(ringCells, { -r, y }) end
            for x = -r + 1, r do table.insert(ringCells, { x, r }) end
            for y = r - 1, -r, -1 do table.insert(ringCells, { r, y }) end
            for x = r - 1, 1, -1 do table.insert(ringCells, { x, -r }) end
        end
        for _, cell in ipairs(ringCells) do
            -- (0, 1) directly in front of the player tent is the reserved EMPTY
            -- tile (open ground to walk out through); (0, -1) directly behind is
            -- the TRAINING tile - neither is ever a camping cluster.
            if not ((cell[1] == 0 and cell[2] == 1) or (cell[1] == 0 and cell[2] == -1)) then
                table.insert(offsets, cell)
            end
        end
        ring = ring + 1
    end
    return offsets
end

-- Build the physical camp layout and teleport the squad in. Tent recipients (up
-- to CampMaxTents) are grouped into cells of CampClusterSize, each with its own
-- fire/seats/tents, tiled in a grid; mercs beyond the cap get an outer-ring bed.
-- See docs/camp.md for the full layout scheme.
function mercenaries:SpawnMercCamp()
    if self.CampActive then
        Game.SendInfoText('merc_info_camp_already_active', false, 0, 3)
        return
    end
    if _G.MercenariesDismissed then
        Game.SendInfoText('merc_info_camp_no_squad', false, 0, 3)
        return
    end

    self:Recount()
    if not _G.MercCount or _G.MercCount <= 0 then
        Game.SendInfoText('merc_info_camp_no_squad', false, 0, 3)
        return
    end

    local ok, err = pcall(function()
        local center, _ = self:GetSafeSpawnPosition(player, 7)
        if not center then
            Game.SendInfoText('merc_info_camp_no_spot', false, 0, 3)
            return
        end
        center = self:CampSnapToGround(center)

        -- Sort mercs strong -> medium -> weak so tent slots go to the
        -- higher tiers first.
        local function tierRank(t)
            if t == "strong" then return 0 end
            if t == "medium" then return 1 end
            return 2
        end

        local mercList = {}
        for name, ent in pairs(self.ActiveMercs) do
            if ent and self:IsAliveAndWell(ent, false) then
                table.insert(mercList, { name = name, ent = ent, tier = self:GetTierFromName(name) })
            end
        end
        table.sort(mercList, function(a, b) return tierRank(a.tier) < tierRank(b.tier) end)

        local mercCount = #mercList
        if mercCount == 0 then
            Game.SendInfoText('merc_info_camp_no_squad', false, 0, 3)
            return
        end

        -- Helper: pull the WUID out of a spawned entity the same way the
        -- rest of this file already does for mercs.
        local function entWuid(e)
            if not e then return nil end
            return e.this and e.this.id or e.id
        end

        -- === Camp role assignment (guard / sit / sleep) ===
        -- Half the squad patrol; the rest split half sit / half sleep, per
        -- feedback. Roles are picked at random (Fisher-Yates shuffle of
        -- mercList indices) so selection doesn't favour any tier. campRole[i]
        -- is keyed by index into the tier-sorted mercList - the per-merc loop
        -- below reads it to spawn the right smart-object furniture and record
        -- CampFurniture, and the guard-waypoint loop further down reads it to
        -- pick patrollers.
        -- Guards are picked at random (Fisher-Yates over indices, so tier isn't
        -- favoured). Per the tile spec - "one camping tile = 6 tents for 12
        -- mercs, as half the mercs patrol either way" - only the NON-guards get
        -- tents. So mercList is re-sorted NON-GUARDS FIRST (each group keeps its
        -- strong->weak tier order), tentRecipients is the non-guard count, and
        -- the tent/cluster loop below (which keys tents off the low indices)
        -- hands tents only to non-guards; guards fall past tentRecipients and
        -- get no tent, just a patrol ring (see the guard branch further down).
        local guardCount = math.max(1, math.floor(mercCount / 2 + 0.5))
        guardCount = math.min(guardCount, mercCount)
        -- Patrol-density cap: half the squad is fine for small parties, but a big
        -- one crowds the perimeter. The guards patrol a ring; estimate its length
        -- (2*pi*radius, radius grown from how many camping tiles the non-guards
        -- need) and allow only ~1 guard per CampPatrolSpacing metres of route.
        -- So parties up to ~15 keep the half split; larger ones are thinned out.
        do
            local estNonGuard = mercCount - guardCount
            local estClusters = math.max(1, math.min(self.CampMaxCampingTiles,
                math.ceil(estNonGuard / self.CampClusterSize)))
            local maxTile = 0
            for _, off in ipairs(self:CampGridOffsets(estClusters)) do
                maxTile = math.max(maxTile, math.sqrt(off[1] * off[1] + off[2] * off[2]))
            end
            local estRadius = maxTile * self.CampClusterSpacing
                + self.CampTentRingRadius + self.CampPatrolTentClearance
            local routeCap = math.max(1, math.floor((2 * math.pi * estRadius) / self.CampPatrolSpacing))
            guardCount = math.max(1, math.min(guardCount, routeCap))
        end
        local isGuard = {}
        do
            local idxs = {}
            for i = 1, mercCount do idxs[i] = i end
            for i = mercCount, 2, -1 do
                local j = math.random(i)
                idxs[i], idxs[j] = idxs[j], idxs[i]
            end
            for p = 1, guardCount do isGuard[idxs[p]] = true end
        end
        do
            local reordered = {}
            for i, m in ipairs(mercList) do if not isGuard[i] then table.insert(reordered, m) end end
            for i, m in ipairs(mercList) do if isGuard[i] then table.insert(reordered, m) end end
            mercList = reordered
        end
        local nonGuardCount = mercCount - guardCount

        -- campRole / campSeed key off the re-sorted mercList: 1..nonGuardCount
        -- are the tented, scheduled mercs (each on the rotating CampRoleCycle
        -- with a staggered starting seed, so the camp shows a mix of
        -- occupations); the rest are guards, fixed for the camp's lifetime.
        local campRole = {}
        local campSeed = {}
        for i = 1, nonGuardCount do
            local seed = ((i - 1) % #self.CampRoleCycle) + 1
            campRole[i] = self.CampRoleCycle[seed]
            campSeed[i] = seed
        end
        for i = nonGuardCount + 1, mercCount do campRole[i] = "guard" end

        self.CampFurniture = {}
        self.CampActivities = {}
        self.CampMercSpots = {}
        self.CampRoleIdx = {}
        self.CampNextRotate = {}
        self.CampSeats = {}
        self.CampBeds = {}
        self.CampTicks = 0

        -- Only non-guards get tents; guards patrol and get none. Tents are
        -- grouped CampClusterSize (6) per camping tile, so one tile covers ~12
        -- mercs once its ~6 guards are counted. Camping tiles are capped at
        -- CampMaxCampingTiles (10, per spec), so a giant squad's excess
        -- non-guards spill onto the straw-bed outer ring instead of tiling
        -- endlessly ("lets an overpopulated camp exist").
        local ClusterSize = self.CampClusterSize
        local numClusters = math.max(1, math.min(self.CampMaxCampingTiles,
            math.ceil(math.max(nonGuardCount, 1) / ClusterSize)))
        local tentRecipients = math.min(self.CampMaxTents, nonGuardCount, numClusters * ClusterSize)

        -- Grid axes: "forward" is the direction the player was facing when
        -- camp was made - the whole grid (and the player tent's own facing)
        -- is built around that, so the single reserved-empty tile always
        -- lines up with the tent's entrance. "right" is perpendicular to it.
        local playerDir = player:GetDirectionVector()
        local dirLen = math.sqrt(playerDir.x * playerDir.x + playerDir.y * playerDir.y)
        local forward = dirLen > 0.0001 and { x = playerDir.x / dirLen, y = playerDir.y / dirLen } or { x = 0, y = 1 }
        local right = { x = -forward.y, y = forward.x }
        local spacing = self.CampClusterSpacing

        local worldForwardAngle = math.atan2(forward.y, forward.x)

        -- === GROUND MAP (phase 2) ===
        -- Detect whether the player is under a roof (so rays are restarted
        -- under the ceiling and map the FLOOR, not the roof), then sample +
        -- classify ONE fine heightmap covering the whole camp footprint
        -- (CampBuildMap). Tile selection and every prop placement below query
        -- this map by world position instead of re-raycasting. If the map can't
        -- be built for any reason, campMap stays nil and the code falls back to
        -- the older per-cluster CampValidateSpot probe, so camp creation never
        -- fails. Map radius is sized to the rings the clusters span, capped at
        -- CampMapMaxRadius so a huge squad can't trigger a giant raycast burst.
        local underRoof = self:CampDetectRoof(center)
        -- Size the map to the farthest tile the clusters actually reach (plus a
        -- tile half-extent, the centre search, and a margin), capped so a giant
        -- squad can't trigger a huge raycast burst.
        local maxCellDist = 1
        for _, off in ipairs(self:CampGridOffsets(numClusters)) do
            local e = math.sqrt(off[1] * off[1] + off[2] * off[2])
            if e > maxCellDist then maxCellDist = e end
        end
        local mapRadiusM = math.min(self.CampMapMaxRadius,
            maxCellDist * spacing + self.CampTileHalf + self.CampCenterSearch + 1.0)
        local mapCells = math.max(8, math.floor(mapRadiusM / self.CampSampleStep + 0.5))
        local campMap = nil
        pcall(function() campMap = self:CampBuildMap(center, mapCells, underRoof) end)

        -- If the player's own spot is unbuildable (inside a building - under a
        -- roof - or otherwise invalid), jump the whole camp origin to the
        -- nearest open ground so nothing spawns on a roof. When that jump is
        -- more than the fine search can cover, rebuild the map around the new
        -- origin so the tiles are still on sampled ground.
        if campMap and self:CampMapClassAt(campMap, center.x, center.y) ~= "valid" then
            local nv = self:CampNearestValidCell(campMap, center.x, center.y)
            if nv then
                local moved = math.abs(nv.x - center.x) + math.abs(nv.y - center.y)
                center = self:CampSnapToGround({ x = nv.x, y = nv.y, z = center.z })
                if moved > self.CampCenterSearch then
                    pcall(function() campMap = self:CampBuildMap(center, mapCells, underRoof) end)
                end
            end
        end

        -- Player-tent placement: nudge the whole camp origin over a small grid
        -- of candidate spots and keep the one whose 9x9 footprint sits on the
        -- most valid ground ("find a position with the most valid tiles around
        -- it"). A small clump in/near the tent is tolerated, just avoided.
        if campMap then
            local bestC, bestScore = center, -1
            local s, st = self.CampCenterSearch, self.CampCenterSearchStep
            local a = -s
            while a <= s + 1e-6 do
                local b = -s
                while b <= s + 1e-6 do
                    local cand = {
                        x = center.x + right.x * a + forward.x * b,
                        y = center.y + right.y * a + forward.y * b,
                        z = center.z,
                    }
                    local v = select(1, self:CampFootprintStats(campMap, cand, worldForwardAngle,
                        self.CampPlayerTentFootHalf.w, self.CampPlayerTentFootHalf.h))
                    local score = v - 0.001 * (math.abs(a) + math.abs(b))  -- tie-break toward the asked spot
                    if score > bestScore then bestScore, bestC = score, cand end
                    b = b + st
                end
                a = a + st
            end
            center = self:CampSnapToGround(bestC)
        end

        -- Cell (0, 0) is the player tent itself; (dx, dy) offsets are in
        -- grid tiles, dx = right/left, dy = forward(+)/behind(-).
        local function gridCellPos(dx, dy)
            return self:CampSnapToGround({
                x = center.x + right.x * dx * spacing + forward.x * dy * spacing,
                y = center.y + right.y * dx * spacing + forward.y * dy * spacing,
                z = center.z,
            })
        end

        self:SpawnPlayerCampTent(center, worldForwardAngle)

        -- The quartermaster: an immortal talking-interface NPC that stands by
        -- the player tent for the camp's lifetime (see mercenaries_quartermaster.lua).
        self:SpawnQuartermaster(center, worldForwardAngle)

        -- Fire clusters fill grid cells in the order CampGridOffsets lays out -
        -- behind the player tent first, then left/right, then the corners, then
        -- further rings for bigger squads - always skipping (0, 0) (the player
        -- tent) and (0, 1) (the reserved empty tile in front of it).
        --
        -- TILE VALIDATION: each candidate cell is a camping tile, accepted only
        -- if at most CampTileMaxInvalidFrac (50%) of its ground reads invalid in
        -- the map; the fire itself is then nudged onto valid ground inside the
        -- tile. We walk outward until we have numClusters good tiles or run out,
        -- then fill any shortfall with the closest raw cells so the camp still
        -- fully forms (an imperfect/overpopulated camp beats no camp). Without a
        -- map, this falls back to the per-cluster CampValidateSpot probe.
        local candidateOffsets = self:CampGridOffsets(math.max(self.CampMaxProbeCells, numClusters))
        local clusterCenters = {}
        local usedCell = {}
        for _, off in ipairs(candidateOffsets) do
            if #clusterCenters >= numClusters then break end
            local raw = gridCellPos(off[1], off[2])
            local accept = false
            if campMap then
                local v, t = self:CampFootprintStats(campMap, raw, worldForwardAngle, self.CampTileHalf, self.CampTileHalf)
                accept = t > 0 and ((t - v) / t) <= self.CampTileMaxInvalidFrac
                if accept then
                    raw = self:CampSnapToGround(self:CampNudgeToValid(campMap, raw, worldForwardAngle, self.CampFireFootHalf))
                end
            else
                local valid, gz = self:CampValidateSpot(raw, center.z, self.CampClusterFootprint)
                accept = valid
                if accept then raw = { x = raw.x, y = raw.y, z = gz } end
            end
            if accept then
                usedCell[off[1] .. "," .. off[2]] = true
                table.insert(clusterCenters, { x = raw.x, y = raw.y, z = raw.z or center.z })
            end
        end
        -- Shortfall fallback: fill remaining clusters with the closest cells we
        -- haven't already used, validated or not.
        if #clusterCenters < numClusters then
            for _, off in ipairs(candidateOffsets) do
                if #clusterCenters >= numClusters then break end
                local key = off[1] .. "," .. off[2]
                if not usedCell[key] then
                    usedCell[key] = true
                    table.insert(clusterCenters, gridCellPos(off[1], off[2]))
                end
            end
        end
        for _, cPos in ipairs(clusterCenters) do
            self:SpawnCampFirePrefab(cPos, 0)
        end

        -- TRAINING YARD - the reserved tile BEHIND the player tent (per spec:
        -- "training area is behind the player tent, one tile in front is
        -- empty"). Placed CampTrainingYardDistance metres along -forward, in the
        -- (0, -1) tile CampGridOffsets reserves. Straw dummies (up to five, one
        -- per five mercs) are laid out in a row across the yard; trainees stand
        -- on the camp side facing them. Nudged onto valid ground if the map
        -- found a clump behind the tent.
        local trainCenter = self:CampSnapToGround({
            x = center.x - forward.x * self.CampTrainingYardDistance,
            y = center.y - forward.y * self.CampTrainingYardDistance,
            z = center.z,
        })
        if campMap then
            trainCenter = self:CampSnapToGround(self:CampNudgeToValid(campMap, trainCenter, worldForwardAngle, self.CampFireFootHalf))
        end
        -- Yard is behind camp, so "toward camp" is +forward and "away" is
        -- -forward: dummies face the camp (+forward), trainees face away toward
        -- the dummies (-forward). (Flipped from the old in-front yard.)
        -- The practice yard is its own structure now (like the forge/alchemy
        -- bench): remember the geometry it needs, then raise it if the Practice
        -- Yard upgrade is owned. numDummies stays 0 without it, so no merc is
        -- flagged a trainer below and nobody drills. Buying it mid-camp raises it
        -- immediately via LogiBuyPractice -> SpawnCampPracticeYard.
        self.CampForwardAngle = worldForwardAngle
        self.CampTrainCenter = trainCenter
        local numDummies = 0
        pcall(function()
            if self.LogiState and self:LogiState().hasPracticeYard then
                self:SpawnCampPracticeYard(center)
                numDummies = (self.CampPracticeYard and self.CampPracticeYard.numDummies) or 0
            end
        end)

        self.CampSlots = {}
        self.CampPatrollers = {}

        -- THE single seating ring around each campfire (per feedback: "only
        -- one, around the campfire itself, use logs"). Each log is a real
        -- sit smart object turned to FACE the fire, added to the shared
        -- CampSeats pool that mercs claim from (see ClaimSpot). One log per
        -- cluster merc; a weapon pile dresses the first slot instead of a log.
        for c, cPos in ipairs(clusterCenters) do
            local clusterFirst = (c - 1) * ClusterSize + 1
            local clusterLast = math.min(c * ClusterSize, tentRecipients)
            local clusterMercCount = clusterLast - clusterFirst + 1
            for j = 1, clusterMercCount do
                local seatPos = self:CampSnapToGround(select(1, self:CampRingPos(cPos, self.CampFireSeatRadius, j, clusterMercCount, math.pi / clusterMercCount)))
                if j == 1 then
                    self:SpawnCampProp("WeaponStack", seatPos, math.atan2(cPos.y - seatPos.y, cPos.x - seatPos.x))
                else
                    -- Face the fire so a seated merc faces it.
                    local faceFire = math.atan2(cPos.y - seatPos.y, cPos.x - seatPos.x) + math.rad(self.CampSitFacingFixDeg)
                    local soPos = self:CampRelativeOffset(seatPos, faceFire, self.CampSitSOOffset)
                    local logWuid, logSoPos = self:SpawnCampFurnitureSO(self.CampModels.Log, seatPos, faceFire, "MercCampProp_LogSO", self.CampChairSO, soPos)
                    if logWuid then
                        -- Keep the fire this seat rings so a merc who claims it can
                        -- Turn to face it after sitting (the seated pose doesn't
                        -- inherit the smart object's rotation - see mercenary_follow).
                        table.insert(self.CampSeats, { wuid = logWuid, pos = logSoPos, firePos = { x = cPos.x, y = cPos.y, z = cPos.z }, occupant = nil })
                    end
                end
            end
        end

        -- Patrol/straw-bed rings need to clear the whole cluster grid, not
        -- just a single fire - scale their radius with how far the
        -- farthest actual cluster ended up from `center`, plus that
        -- cluster's own footprint radius. For a single cluster this stays
        -- small; it grows as more clusters get tiled outward.
        local maxClusterOffset = 0
        for _, cPos in ipairs(clusterCenters) do
            local ddx, ddy = cPos.x - center.x, cPos.y - center.y
            maxClusterOffset = math.max(maxClusterOffset, math.sqrt(ddx * ddx + ddy * ddy))
        end
        local outerRadius = math.max(7.0, maxClusterOffset + 8.0)

        local strawCount = mercCount - tentRecipients
        -- Counts scheduled (non-guard) mercs as the loop below meets them -
        -- used to hand out unique training-ground ring slots.
        local schedCount = 0

        for i, m in ipairs(mercList) do
            local hasTent = i <= tentRecipients
            local mercWuid = entWuid(m.ent)
            local pos, angle
            -- The fire this merc's cluster is built around; stools are turned
            -- to face it (see the stool spawn below). nil for the straw-bed
            -- overflow mercs, who belong to no cluster.
            local clusterFirePos = nil
            -- This merc's angular slot / member count in its cluster tent ring,
            -- reused to place their activity spot at the same bearing but pulled
            -- inward (clear of every tent).
            local ringSlot, ringCount = nil, nil

            if hasTent then
                local clusterIndex = math.ceil(i / ClusterSize)
                local clusterFirst = (clusterIndex - 1) * ClusterSize + 1
                local clusterLast = math.min(clusterIndex * ClusterSize, tentRecipients)
                local clusterMercCount = clusterLast - clusterFirst + 1
                local memberIndex = i - clusterFirst + 1
                local cPos = clusterCenters[clusterIndex]
                clusterFirePos = cPos
                ringSlot = memberIndex
                ringCount = self.CampClusterTentRingSlots

                -- Tent on the outer ring of its cluster, facing back toward
                -- the fire (plus CampTentFacingFix - see its definition).
                -- Ring is sized for CampClusterTentRingSlots (7) regardless
                -- of how many tents this cluster actually has - a full
                -- 6-tent cluster then always leaves one ring slot open as a
                -- gap, per feedback ("calculate with seven tents, but leave
                -- one tent spot empty, to allow movement"). Radius is
                -- CampTentRingRadius (see its definition for history).
                local tentPos, tentFaceAngle = self:CampRingPos(cPos, self.CampTentRingRadius, memberIndex, self.CampClusterTentRingSlots, 0)
                tentPos = self:CampSnapToGround(tentPos)
                angle = tentFaceAngle + math.pi + self.CampTentFacingFix
                -- Nudge the whole tent unit onto valid ground if its footprint
                -- caught an obstacle clump - the bed and clutter are placed
                -- relative to tentPos, so they move with it. Never skipped (the
                -- least-bad spot is used) so every non-guard keeps a bed and the
                -- shared CampBeds pool stays intact.
                if campMap then
                    tentPos = self:CampSnapToGround(self:CampNudgeToValid(campMap, tentPos, angle, self.CampTentFootHalf))
                end
                -- Random tent variant per merc, for visual variety - every
                -- CampTentVariants entry shares the same footprint/facing.
                local tentModel = self.CampTentVariants[math.random(#self.CampTentVariants)]
                self:SpawnCampPropModel(tentModel, tentPos, angle, "MercCampProp_Tent")
                local tentFacing = angle

                -- Bed placed relative to the tent itself (CampBedOffset) -
                -- see merc_camp_bed_test to tune this. IMPORTANT: capture
                -- BOTH return values - CampRelativeOffset's rotated angle
                -- was previously being discarded here, so CampBedOffset's
                -- rotationDeg was silently never actually applied to the
                -- real camp (only in the merc_camp_bed_test debug tool,
                -- which does capture both values) - that's the bug behind
                -- "beds still not oriented correctly".
                local bedAngle
                pos, bedAngle = self:CampRelativeOffset(tentPos, angle, self.CampBedOffset)
                pos = self:CampSnapToGround(pos)
                -- Non-guard tents get a smart-object bed added to the SHARED
                -- CampBeds pool - the schedule lets any scheduled merc sleep in
                -- any free bed, preferring one further off to make them walk
                -- (per feedback). Guards never sleep; theirs stays decorative.
                if campRole[i] ~= "guard" then
                    self.CampMercSpots[tostring(mercWuid)] = {}
                    local bedWuid, bedSoPos = self:SpawnCampFurnitureSO(self.CampModels.Bed, pos, bedAngle, "MercCampProp_BedSO", self.CampBedSO)
                    if bedWuid then
                        table.insert(self.CampBeds, { wuid = bedWuid, pos = bedSoPos, occupant = nil })
                    end
                else
                    self:SpawnCampProp("Bed", pos, bedAngle)
                end
                -- CampMercStandOffset below is relative to the bed's own
                -- (now correctly rotated) facing, not the tent's - update
                -- `angle` so that holds true regardless of CampBedOffset's
                -- rotationDeg (this is also the "wrong axis" fix: before,
                -- the merc-stand offset was silently using the tent's
                -- facing instead of the bed's).
                angle = bedAngle
                -- (No chest/personal-effects prop anymore - removed per feedback.)

                -- A random sack/open-container prop beside the tent (not on
                -- top of the bed or the merc's standing spot), per feedback.
                local clutterModel = self.CampTentClutterVariants[math.random(#self.CampTentClutterVariants)]
                local clutterPos = self:CampRelativeOffset(tentPos, tentFacing, self.CampTentClutterOffset)
                self:SpawnCampPropModel(clutterModel, clutterPos, tentFacing, "MercCampProp_TentClutter")
            else
                -- Guards get no tent/bed (they patrol) - just a spot on the
                -- outer ring to start from. Non-guard overflow (squads past the
                -- tent cap) still get a plain straw bed there.
                local ringIndex = i - tentRecipients
                local radius = math.max(3.2, outerRadius - 3.0) + (ringIndex % 3) * 0.5
                pos, angle = self:CampRingPos(center, radius, ringIndex, math.max(strawCount, 1), 0)
                pos = self:CampSnapToGround(pos)
                if campRole[i] ~= "guard" then
                    self:SpawnCampProp("BedStraw", pos, angle)
                end
            end

            -- Stand a bit in front of the bed (CampMercStandOffset) rather
            -- than right on top of it.
            local standPos = self:CampRelativeOffset(pos, angle, self.CampMercStandOffset)
            standPos = self:CampSnapToGround(standPos)
            local slotPos = { x = standPos.x + (math.random() - 0.5) * 0.4, y = standPos.y + (math.random() - 0.5) * 0.4, z = standPos.z }
            self.CampSlots[tostring(mercWuid)] = slotPos

            -- No per-merc stool any more (that was the second seating ring the
            -- logs around the fire replaced). Each scheduled merc just gets an
            -- OUTSIDE-the-tent-circle spot for eat/forage, a training-yard slot,
            -- and a trainer flag; sit/sleep come from the shared pools.
            local role = campRole[i]
            local spots = self.CampMercSpots[tostring(mercWuid)]

            if role ~= "guard" and spots and clusterFirePos then
                schedCount = schedCount + 1

                -- eat/forage spot: OUTSIDE the tent circle per earlier feedback,
                -- staggered half a slot so it lands between two tents with a
                -- clear line to the fire rather than directly behind their own.
                local activityRadius = self.CampTentRingRadius + self.CampActivityOutsideGap
                local actPos = self:CampSnapToGround(select(1, self:CampRingPos(clusterFirePos, activityRadius, ringSlot, ringCount, math.pi / ringCount)))

                -- Only about one merc per five trains (cap 5, = the dummy count):
                -- the first `numDummies` scheduled mercs are the trainers and get
                -- the training-heavy cycle; the rest never practise.
                local isTrainer = (schedCount <= numDummies)
                local nTrain = math.max(numDummies, 1)
                local rowIdx = ((schedCount - 1) % nTrain)
                local rowOff = (rowIdx - (nTrain - 1) / 2) * self.CampTrainingTraineeSpacing

                spots.actPos = actPos
                spots.firePos = { x = clusterFirePos.x, y = clusterFirePos.y, z = clusterFirePos.z }
                -- Yard is behind camp: trainees stand on the camp side of the
                -- dummies, i.e. +setback along forward (toward the tent).
                spots.trainPos = self:CampSnapToGround(self:CampRelativeOffset(trainCenter, worldForwardAngle, { right = rowOff, forward = self.CampTrainingTraineeSetback }))
                spots.trainFacePos = { x = trainCenter.x, y = trainCenter.y, z = trainCenter.z }
                spots.isTrainer = isTrainer
                spots.lastPos = actPos

                -- Put them on a staggered first step of their cycle and start
                -- their per-role timer; RotateCampRoles advances from here.
                local cycle = self:CampCycleFor(tostring(mercWuid))
                local idx = ((campSeed[i] or 1) - 1) % #cycle + 1
                self.CampRoleIdx[tostring(mercWuid)] = idx
                local role0 = self:CampRoleWithNightBias(cycle[idx])
                self:ApplyCampRole(tostring(mercWuid), role0)
                local span = self.CampRoleSeconds[role0] or { 60, 90 }
                self.CampNextRotate[tostring(mercWuid)] = self.CampTicks + math.max(1, math.floor(math.random(span[1], span[2]) / 5))
            end

            -- Start each merc at wherever their first occupation happens -
            -- they walk between spots themselves from now on. If that spot
            -- landed on an obstacle (map says not valid), jump it to the nearest
            -- valid cell so nobody is teleported onto a tree/roof.
            local act = self.CampActivities[tostring(mercWuid)]
            local fur = self.CampFurniture[tostring(mercWuid)]
            local startPos = (act and act.pos) or (fur and fur.pos) or slotPos
            if campMap and self:CampMapClassAt(campMap, startPos.x, startPos.y) ~= "valid" then
                local nv = self:CampNearestValidCell(campMap, startPos.x, startPos.y)
                if nv then startPos = self:CampSnapToGround({ x = nv.x, y = nv.y, z = startPos.z }) end
            end
            pcall(function() m.ent:SetPos(startPos) end)
        end

        -- Half the squad (per feedback) become "guards" and patrol the camp
        -- perimeter for real, continuously - picked at random (a Fisher-Yates
        -- shuffle of mercList indices, so selection doesn't favor any tier;
        -- the per-merc loop above still walked mercList in its original sorted
        -- order for tent/bed assignment, only the guard flag is random). Each
        -- guard gets a ring of waypoint POSITIONS encircling the whole camp;
        -- the follow BT walks them point-to-point with periodic pauses (see
        -- IsCampGuard / GetPatrolWaypoint / AdvancePatrolWaypoint above, and
        -- the incamp-guard handling in mercenary_scheduler.xml /
        -- archer_scheduler.xml / mercenary_follow.xml). Guards are staggered
        -- by a per-guard angular offset so they spread around the perimeter
        -- rather than clumping.
        --
        -- Patrol ring radius sits ~CampPatrolTentClearance (3m) beyond the
        -- outermost tent, per feedback: the farthest cluster's distance from
        -- centre, plus the tent ring radius (which is how far a tent can sit
        -- from its cluster fire), plus the clearance. This puts the navnodes
        -- roughly 3m outside the tents so the route goes AROUND the camp
        -- instead of cutting through it.
        --
        -- Waypoints are stored as plain {x,y,z} POSITIONS, not entities: the
        -- follow BT Moves to a vec3 destination directly (the same way
        -- references/AI/world/so_ladder.xml Moves to its vec3 $t_entryPos).
        -- The earlier version spawned invisible BasicEntity markers and Moved
        -- to those, which flat-out didn't work - a plain BasicEntity is not
        -- registered with the AI system as a navigable/targetable entity
        -- (references/Scripts/Entities/Physics/BasicEntity.lua leaves
        -- EntityCommon.MakeTargetableByAI commented out), so pathfinding
        -- couldn't resolve the marker and the guards never moved. A raw
        -- position has no such requirement.
        -- Guards were already chosen up front (campRole == "guard"); collect
        -- them and give each a perimeter waypoint ring, staggered by a
        -- per-guard angular offset.
        local NUM_WAYPOINTS = 8
        local patrolRadius = maxClusterOffset + self.CampTentRingRadius + self.CampPatrolTentClearance
        local guardIndices = {}
        for i = 1, mercCount do
            if campRole[i] == "guard" then table.insert(guardIndices, i) end
        end
        for p, idx in ipairs(guardIndices) do
            local m = mercList[idx]
            if m then
                local wuid = entWuid(m.ent)
                local baseAngle = (p - 1) * (2 * math.pi / math.max(#guardIndices, 1))
                local waypoints = {}
                for w = 1, NUM_WAYPOINTS do
                    local wp = self:CampRingPos(center, patrolRadius, w, NUM_WAYPOINTS, baseAngle)
                    wp = self:CampSnapToGround(wp)
                    table.insert(waypoints, { x = wp.x, y = wp.y, z = wp.z })
                end
                if wuid and #waypoints > 0 then
                    self.CampPatrollers[tostring(wuid)] = { waypoints = waypoints, index = 1 }
                end
            end
        end

        self.CampCenter = center
        self.CampActive = true
        self.CampOutParty = {}   -- fresh camp: everyone starts in it
        _G.MercCampMode = true
        -- "A camp exists" flag. The schedulers/follow BT and the formation &
        -- teleport monitors read it (via IsMercInCampProper) to leave the mercs
        -- who stay in camp alone. NOTE: camp deliberately no longer forces the
        -- global idle flag - in-camp mercs are held in place by their camp roles
        -- (IsCampActor), while global idle is reserved for the player's own
        -- wait order, which only affects sortie mercs.
        _G.MercInCamp = true

        -- Camp forge: with the Portable Smithy upgrade, build a usable forge on
        -- the flattest patch near camp (needs a village Smithery loaded nearby
        -- to borrow; silently skips if there's none).
        pcall(function()
            if self.LogiState and self:LogiState().hasSmithy then self:SpawnCampForge(center) end
        end)
        -- Same for the alchemy bench (borrows a village AlchemyTable).
        pcall(function()
            if self.LogiState and self:LogiState().hasAlchemy then self:SpawnCampAlchemy(center) end
        end)
        -- Hunting station: dressed camp props (no borrow) once a Hunter is hired.
        pcall(function()
            if self.LogiState and (self:LogiState().hunterSpots or 0) > 0 then self:SpawnCampHunt(center) end
        end)

        Game.SendInfoText('merc_info_camp_made', false, 0, 4)
    end)

    if not ok then
        System.LogAlways('[Mercenaries] SpawnMercCamp error: ' .. tostring(err))
    end
end

-- Despawn every tracked camp prop and resume normal squad state. silent = true
-- skips the info text (when a follow/dismiss order breaks camp as a side effect).
function mercenaries:BreakMercCamp(silent)
    if not self.CampActive then
        if not silent then
            Game.SendInfoText('merc_info_camp_not_active', false, 0, 3)
        end
        return
    end

    local ok, err = pcall(function()
        for _, entId in ipairs(self.CampEntities) do
            pcall(function() System.RemoveEntity(entId) end)
        end
    end)
    if not ok then
        System.LogAlways('[Mercenaries] BreakMercCamp error: ' .. tostring(err))
    end

    -- The quartermaster is an NPC, not a tracked BasicEntity prop, so he's
    -- torn down separately.
    self:DespawnQuartermaster()

    -- Tear down the camp forge (restores the borrowed village Smithery).
    pcall(function() self:DespawnCampForge() end)
    pcall(function() self:DespawnCampAlchemy() end)
    pcall(function() self:DespawnCampHunt() end)

    self.CampEntities = {}
    self.CampSlots = {}
    self.CampPatrollers = {}
    self.CampFurniture = {}
    self.CampActivities = {}
    self.CampMercSpots = {}
    self.CampRoleIdx = {}
    self.CampNextRotate = {}
    self.CampSeats = {}
    self.CampBeds = {}
    self.CampTicks = 0
    self.CampCommunalChairs = {}
    self.CampOutParty = {}
    self.CampPracticeYard = nil
    self.CampTrainCenter = nil
    self.CampForwardAngle = nil
    self.CampCenter = nil
    self.CampActive = false
    _G.MercCampMode = false
    _G.MercInCamp = false
    _G.MercCampChats = {}
    _G.MercReturnPending = {}
    self.CampChatMercCooldown = {}
    self.CampChatStaggered = false
    -- Clear any idle order so the squad follows again after camp comes down.
    -- (This is what was missing before: camp used to force the global idle flag
    -- on, and breaking camp left it on, so the whole squad stood around until an
    -- explicit "follow me" order. Camp no longer sets it, and we clear it here.)
    _G.MercIdle = false
    _G.MercPersistentIdleFlag = false
    self:SaveString("MercIdlePersistent", "0")

    if not silent then
        Game.SendInfoText('merc_info_camp_broken', false, 0, 3)
    end
end

-- Called from LowPriorityMonitorLoop (5s cadence) while camp is active.
-- Camp itself does NOT auto-despawn based on player distance anymore - it
-- stays up until explicitly broken. This drives the camp "daily schedule":
-- every CampRotateTicks ticks (~3 min), every scheduled merc advances one
-- step through CampRoleCycle and walks to their next occupation - see
-- RotateCampRoles / ApplyCampRole.
function mercenaries:MonitorCamp()
    if not self.CampActive then return end
    self.CampTicks = (self.CampTicks or 0) + 1
    -- Per-merc role timers (see RotateCampRoles) - checked every tick.
    self:RotateCampRoles()
    -- Conversations run on their own cadence (see CampChatTick).
    self:CampChatTick()
end

-- Bring the whole squad to the player and resume following, from anywhere,
-- without touching the camp structure (tents stay until explicitly broken).
-- Bound to a key in OnGameplayStarted. See docs/camp.md.
function mercenaries:RecallMercs()
    if _G.MercenariesDismissed then
        Game.SendInfoText('merc_info_camp_no_squad', false, 0, 3)
        return
    end
    if not player then return end

    local ok, err = pcall(function()
        local center, _ = self:GetSafeSpawnPosition(player, 3)
        if not center then center = player:GetWorldPos() end

        local i = 0
        for name, ent in pairs(self.ActiveMercs) do
            if ent and self:IsAliveAndWell(ent, false) then
                i = i + 1
                local pos = self:CampRingPos(center, 2.0 + (i % 4), i, 12, 0)
                pos = self:FindValidGround(pos, center.z)
                pcall(function() ent:SetPos(pos) end)
            end
        end
    end)
    if not ok then
        System.LogAlways('[Mercenaries] RecallMercs error: ' .. tostring(err))
    end

    self.CampPatrollers = {}
    -- Recall pulls everyone (guards included) back to the player and resumes
    -- normal following - clear the incamp state AND the schedule assignments
    -- (GetCampActivity is deliberately not gated on MercInCamp for the test
    -- commands, so activities must be cleared explicitly or recalled mercs
    -- would walk straight back to their camp occupation).
    self.CampFurniture = {}
    self.CampActivities = {}
    self.CampMercSpots = {}
    self.CampRoleIdx = {}
    self.CampNextRotate = {}
    self.CampSeats = {}
    self.CampBeds = {}
    _G.MercInCamp = false
    _G.MercCampChats = {}
    self.CampChatMercCooldown = {}
    self.CampChatStaggered = false
    _G.MercIdle = false
    _G.MercPersistentIdleFlag = false
    self:SaveString("MercIdlePersistent", "0")

    Game.SendInfoText('merc_info_recalled', false, 0, 3)
end

-- Called once from OnGameplayStarted. Camp never persists across a save/load
-- (see file header) - this sweeps away any leftover props from a camp that was
-- active when the game was saved, since our Lua-side CampEntities list is gone
-- after a fresh script load either way. Covers BasicEntity and ParticleEffect
-- props, plus the BedTrigger and smart-object classes handled further down.
function mercenaries:ClearAnyLeftoverCamp()
    local ok, err = pcall(function()
        for _, cls in ipairs({ "BasicEntity", "ParticleEffect" }) do
            local ents = System.GetEntitiesByClass(cls)
            if ents then
                for _, e in pairs(ents) do
                    local name = e and e:GetName() or ""
                    if string.find(name, "MercCampProp_", 1, true) or string.find(name, "MercActTest_", 1, true) then
                        System.RemoveEntity(e.id)
                    end
                end
            end
        end

        -- The player-bed sleep trigger is a BedTrigger, not a BasicEntity, so
        -- the class sweep above can't catch it - sweep it by name here too.
        local triggers = System.GetEntitiesByClass("BedTrigger")
        if triggers then
            for _, e in pairs(triggers) do
                local name = e and e:GetName() or ""
                if string.find(name, "MercCampProp_BedTrigger_", 1, true) then
                    System.RemoveEntity(e.id)
                end
            end
        end

        -- Same for the merc sit/sleep smart objects and the activity-test
        -- anchors - both are their own entity classes, so the BasicEntity
        -- sweep above can't catch them.
        for _, cls in ipairs({ "StanceSmartObject", "SmartObjectHolder" }) do
            local smartObjects = System.GetEntitiesByClass(cls)
            if smartObjects then
                for _, e in pairs(smartObjects) do
                    local name = e and e:GetName() or ""
                    if string.find(name, "MercCampProp_", 1, true) or string.find(name, "MercActTest_", 1, true) then
                        System.RemoveEntity(e.id)
                    end
                end
            end
        end
    end)
    if not ok then
        System.LogAlways('[Mercenaries] ClearAnyLeftoverCamp error: ' .. tostring(err))
    end

    -- Sweep away a leftover quartermaster (an NPC, swept by name prefix).
    self:DespawnQuartermaster()

    -- Tear down the camp forge (restores the borrowed village Smithery).
    pcall(function() self:DespawnCampForge() end)
    pcall(function() self:DespawnCampAlchemy() end)
    pcall(function() self:DespawnCampHunt() end)

    self.CampActive = false
    self.CampEntities = {}
    self.CampSlots = {}
    self.CampPatrollers = {}
    self.CampFurniture = {}
    self.CampActivities = {}
    self.CampMercSpots = {}
    self.CampRoleIdx = {}
    self.CampNextRotate = {}
    self.CampSeats = {}
    self.CampBeds = {}
    self.CampTicks = 0
    self.CampCommunalChairs = {}
    self.CampOutParty = {}
    self.CampCenter = nil
    self.ActivityTestEntities = {}
    self.CampChatMercCooldown = {}
    self.CampChatStaggered = false
    _G.MercCampMode = false
    _G.MercInCamp = false
    _G.MercCampChats = {}
end

System.AddCCommand("merc_camp_make", "mercenaries:SpawnMercCamp()", "Spawn a procedural camp and idle the squad in it")
System.AddCCommand("merc_camp_break", "mercenaries:BreakMercCamp()", "Break camp and resume normal squad behaviour")
System.AddCCommand("merc_camp_recall", "mercenaries:RecallMercs()", "Recall the whole squad to your position (does not break camp)")
System.AddCCommand("merc_camp_take_half",    "mercenaries:CampTakeParty(0.5)",       "Deploy the best-equipped half of the squad out of camp to follow you")
System.AddCCommand("merc_camp_take_third",   "mercenaries:CampTakeParty(0.3333)",    "Deploy the best-equipped third of the squad out of camp to follow you")
System.AddCCommand("merc_camp_take_quarter", "mercenaries:CampTakeParty(0.25)",      "Deploy the best-equipped quarter of the squad out of camp to follow you")
System.AddCCommand("merc_camp_return_all",   "mercenaries:CampReturnAll()",          "Return every deployed merc to camp")
