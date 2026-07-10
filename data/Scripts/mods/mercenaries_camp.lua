-- =======================================================================
-- MERCENARY CAMP
-- Spawns a procedural camp (tents, campfire, chairs, bedrolls) near the
-- player, moves the squad into it, and idles them there. The camp stays up
-- until explicitly broken via dialog/console - it does NOT auto-despawn
-- just because the player wanders off. Press the recall key (F4 by
-- default, see OnGameplayStarted) to bring the whole squad to you from
-- anywhere without touching the camp itself.
--
-- Camp props are plain "BasicEntity" spawns with an object_Model property -
-- confirmed against the vanilla BasicEntity.lua (references/Scripts/Entities/
-- Physics/BasicEntity.lua): OnSpawn -> SetFromProperties -> SetupModel ->
-- LoadObject(0, object_Model) + PhysicalizeThis, no custom entity class or
-- .ent registration needed. Model paths and terrain-alignment technique are
-- taken from references/zdjbcamping_mod (a working reference camping mod).
--
-- Camp is a SESSION-ONLY feature: it is never restored across a save/load.
-- ClearAnyLeftoverCamp (called from OnGameplayStarted) sweeps for and
-- deletes any leftover camp props by name prefix, since our Lua-side
-- bookkeeping (CampEntities/CampActive/CampSlots) doesn't survive a reload
-- even if the physical entities do.
--
-- Smart-object sit/sleep integration (so_sitPlace/so_bed) is DISABLED for
-- now - mercs weren't actually using the chairs/beds in practice. The SO
-- property registration (CampFurnitureSO) and the occupancy-assignment code
-- in SpawnMercCamp are commented out rather than removed, in case this gets
-- revisited later. Chairs/beds still spawn as plain decoration (chests
-- don't - removed per feedback, see SpawnMercCamp).
--
-- Half the squad, picked at random, become "guards" and patrol instead: they
-- get a ring of {x,y,z} perimeter positions (the incamp state, _G.MercInCamp,
-- plus a per-merc IsCampGuard check), and mercenary_follow.xml walks each
-- guard point-to-point (Move to a vec3 destination) with periodic pauses. See
-- IsCampGuard / GetPatrolWaypoint / AdvancePatrolWaypoint below, and the
-- incamp-guard routing in mercenary_scheduler.xml / archer_scheduler.xml.
-- =======================================================================

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

-- =======================================================================
-- PLAYER TENT - one central tent + a real, player-usable bed, spawned once
-- per camp (not assigned to any merc). Round white tent (tent_big_round_a,
-- which has a vanilla single-sleeper precedent in tent_knights.xml) and the
-- same low straw bed the mercs use (CampModels.Bed); the low bed's height
-- matches its Bed_1Place_Low / GroundBed smart-object helper, so the player
-- lies and wakes at ground level.
--
-- Making the bed interactable ("E - Sleep") follows the mechanism
-- references/zdjbcamping_mod uses: NOT an OnUsed handler on the bed (MakeUsable
-- overwrites OnUsed with a generic broadcast handler, so the bed's own OnUsed
-- never fires), but a SEPARATE vanilla `BedTrigger` entity spawned next to the
-- bed and linked to it. The trigger (an ActionTrigger subclass) provides the
-- "@ui_hud_sleep" prompt and drives the lying stance against the bed's smart
-- object on use.
--
-- So SpawnPlayerCampTent spawns TWO things:
--   1. the bed - a plain BasicEntity carrying the vanilla bed smart-object
--      properties (guidSmartObjectType/soclass_SmartObjectHelpers/Bed/
--      Script.esBedTypes). The SO registration is property-driven, so no
--      custom .ent class is needed.
--   2. a vanilla `BedTrigger` next to it (esActionType="Stance",
--      sAction="lying", UseMessage="@ui_hud_sleep"), linked to the bed via an
--      EMPTY-NAMED link - what ActionTrigger:GetLinkedSmartObject looks for.
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
mercenaries.CampSitFacingFixDeg = 0

-- (The per-merc activity spot radius moved outside the tent circle - see
-- CampActivityOutsideGap in the schedule section below.)

-- =======================================================================
-- CAMP ACTIVITIES - "make the camp feel alive"
--
-- The engine plays named NPC activity animations through the `UnstanceAction`
-- behaviour-tree node. Every playable name is catalogued in
-- references/Libs/Tables/ai/NPCStateUnstanceDatabase.xml as an <UnstanceData>
-- entry (In / Loop / Out animation fragments). The simplest real example is
-- references/AI/profession/camper/so_camperFemaleEating.xml, whose whole `use`
-- tree is a sitting StanceElement wrapping
--   <UnstanceAction unstance="eating" locationObject="..." />
-- followed by a Wait. Standing actions don't even need the StanceElement -
-- references/AI/situation/dogbarkingpasserby/situation_dogbarking.xml just
-- calls <UnstanceAction unstance="dogBarking" locationObject="" /> directly.
-- And `unstance` accepts a variable (e.g. unstance="$unstance" in
-- references/AI/special/smallTalkingWatchers/...), so ONE behaviour-tree case
-- can play any activity in this table by name.
--
-- Each UnstanceData carries two attributes that decide what a merc needs:
--   UseLocationObject="false" -> no prop/anchor required, plays anywhere
--   IsAligned="false"         -> the merc isn't snapped to an anchor's transform
-- Entries below record which mode each activity needs:
--   mode 1 = sit on a seat smart object, then play the action
--   mode 2 = stand, no anchor at all
--   mode 3 = stand, aligned to an anchor entity (needs `prop`/anchor)
--   mode 4 = stand, duo leader - plays `unstance`, partner plays `partner`
-- `prop` is an optional decorative model spawned at the spot.
--
-- Names verified to exist in NPCStateUnstanceDatabase.xml. Which ones actually
-- look right in-game is exactly what merc_camp_activity_test is for.
-- IN-GAME TEST RESULTS (rounds 1 + 2). Round 1's rule held with one refinement
-- from round 2:
--   * an action works if its UnstanceData has UseLocationObject="false" AND it
--     needs nothing in the merc's hands...
--   * ...but SEATED actions additionally need the seat passed as the
--     UnstanceAction's locationObject. Round 2's "all sit don't work - they
--     just stand on the log" was exactly that: mode 1 passed an empty
--     locationObject. Vanilla always passes the seat (so_camperFemaleEating:
--     $__resource.id for `eating`; so_sitPlace: $__object.id for
--     camper_snooze) - camper_snooze is ALSO called with an empty one in one
--     vanilla spot, which is why snooze alone tolerated our old call. Fixed in
--     mercenary_follow.xml's mode-1 case; the sit_* entries are worth a retest.
--   * everything defaulting to UseLocationObject="true" (wood chopping, sawing,
--     camper_cooking, wagon pushing, and round 2 additions sweep/stoke/
--     smokehouse) plays nothing - the merc stands at the anchor. Those want
--     the full authored rig (align points + a tool item) that
--     so_choppingWood.xml builds via GraphSearch. Not worth rebuilding.
--   * DrawAction before an unstance is USELESS: the unstance's In fragment
--     re-sheathes the weapon first (round 2, sword_training/show_off: "pull
--     out their sword, sheathe it, then start"). drawWeapon removed.
--   * round 2 confirmations: pick_herbs and loot work very well (the "good
--     labour animation"); cook_fire's stirring works and now gets a kettle;
--     eating_standing/camper_snooze still the staples.
-- `prop`/`prop2` = decorative models spawned at the spot (looks only).
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

-- =======================================================================
-- CAMP DAILY SCHEDULE - the "make it feel alive" layer. Guards (half the
-- squad) patrol permanently; every other tent merc owns a full set of spots
-- (their bed's smart object, their fire-facing stool's smart object, a
-- standing spot, and a slot at the training ground) recorded in
-- CampMercSpots at camp build. Their current occupation comes from
-- CampRoleCycle, staggered per merc so the camp shows a mix at any moment,
-- and RotateCampRoles (driven by MonitorCamp's 5s tick) advances everyone
-- one step every CampRotateTicks ticks - mercs then WALK to their next
-- occupation on their own (the follow BT Moves them), which itself reads as
-- camp life. Only activities CONFIRMED working in-game are in the cycle.
-- Non-trainer mercs cycle through these; trainers (see below) cycle through
-- CampTrainerCycle instead. sit/snooze/sleep pull from SHARED pools (logs
-- around the fire, beds in tents) and pick a spot a bit FURTHER from where the
-- merc currently is, to create walking (per feedback). eat/herbs happen at the
-- merc's own outer spot.
mercenaries.CampRoleCycle = { "sleep", "sit", "eat", "herbs", "snooze" }
mercenaries.CampTrainerCycle = { "train", "sit", "train", "eat", "train", "sleep" }
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
-- CampTrainingYardDistance metres in front of the player tent (along the same
-- "forward" the empty grid tile uses), NOT a grid cell. Dummies are laid out
-- in a row across the yard (target_straw/target_stand from the vanilla combat
-- prop set); trainees stand on the camp side facing them.
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

-- Bed placement relative to its own tent: right/forward are in the tent's
-- local space (relative to the tent's own facing angle), z is a world-space
-- vertical offset, rotationDeg is relative to the tent's facing.
-- rotationDeg was stuck at 90 and never actually reaching the real camp (see
-- the bug note in SpawnMercCamp - CampRelativeOffset's rotated angle was
-- being discarded, so the live camp always showed rotationDeg=0 regardless
-- of this value, even though merc_camp_bed_test correctly showed 90 looking
-- right in isolation). Now that the bug's fixed, bumped by another 90 per
-- feedback - re-check in-game and adjust again if this overshoots.
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

-- =======================================================================
-- Ground-snap a position via the same terrain raycast technique
-- GetSafeSpawnPosition already uses (mercenaries_util.lua).
-- =======================================================================
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
        local soEnt = System.SpawnEntity({
            class = "StanceSmartObject",
            name = (namePrefix or "MercCampProp") .. "_SO_" .. tostring(math.random(100000, 999999)),
            position = soGroundPos,
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
function mercenaries:IsCampGuard(mercWuid)
    if not _G.MercInCamp or _G.MercenariesDismissed then return false end
    local rec = self.CampPatrollers and self.CampPatrollers[tostring(mercWuid)]
    return (rec and rec.waypoints and #rec.waypoints > 0) == true
end

-- Returns a non-guard camp merc's assigned furniture record { wuid=, kind= }
-- ("bed" -> sleep/lie, "chair" -> sit), or nil. Set by SpawnMercCamp for the
-- non-patrolling mercs (half sit, half sleep). mercenary_follow.xml reads this
-- and drives a StanceElement against the furniture's smart object.
function mercenaries:GetCampFurniture(mercWuid)
    if not _G.MercInCamp or _G.MercenariesDismissed then return nil end
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
    return self.CampActivities and self.CampActivities[tostring(mercWuid)]
end

-- True if this merc has ANY camp role (guard, assigned sit/sleep furniture, or
-- a camp activity) - i.e. should be routed into mercenary_follow rather than
-- the schedulers' stand-still idle branch.
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
            self.CampFurniture[wuidStr] = { wuid = seat.wuid, kind = "chair", pos = seat.pos }
            s.lastPos = seat.pos
        end
    elseif role == "snooze" then
        local seat = self:ClaimSpot(self.CampSeats, wuidStr, from)
        if seat then
            self.CampActivities[wuidStr] = { unstance = "camper_snooze", mode = 1, pos = seat.pos, locWuid = seat.wuid }
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

-- Advances any camp merc whose per-role timer has elapsed to the next step of
-- their cycle, and schedules their next rotation from CampRoleSeconds. Called
-- from MonitorCamp each 5s tick. Per-merc timing (not a global rotation) is
-- what lets sleeps/sits run 2-5 min while shorter roles turn over quickly.
function mercenaries:RotateCampRoles()
    if not self.CampActive then return end
    local ok, err = pcall(function()
        for wuidStr in pairs(self.CampMercSpots or {}) do
            if self.CampTicks >= (self.CampNextRotate[wuidStr] or 0) then
                local cycle = self:CampCycleFor(wuidStr)
                local idx = ((self.CampRoleIdx[wuidStr] or 0) % #cycle) + 1
                self.CampRoleIdx[wuidStr] = idx
                local role = cycle[idx]
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
                if not chats[wuidStr] and not self.CampChatMercCooldown[wuidStr] then
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

        -- Shuffle so pairings aren't biased by iteration order, then greedily
        -- pair eligible mercs within radius - as many concurrent pairs as fit.
        for i = #list, 2, -1 do
            local j = math.random(i)
            list[i], list[j] = list[j], list[i]
        end
        local r2 = self.CampChatRadius * self.CampChatRadius
        local used = {}
        for i = 1, #list do
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
            if not (cell[1] == 0 and cell[2] == 1) then
                table.insert(offsets, cell)
            end
        end
        ring = ring + 1
    end
    return offsets
end

-- =======================================================================
-- SPAWN CAMP - builds the physical layout and teleports the squad into it.
-- Tent recipients (everyone, up to CampMaxTents) are grouped into "cells" of
-- CampClusterSize mercs, each cell getting its own campfire + seats + tents,
-- tiled in a grid for larger squads. Mercs beyond the cap get a plain straw
-- bed on an outer ring instead.
-- =======================================================================
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
        local guardCount = math.max(1, math.floor(mercCount / 2 + 0.5))
        guardCount = math.min(guardCount, mercCount)
        local shuffledIdx = {}
        for i = 1, mercCount do table.insert(shuffledIdx, i) end
        for i = mercCount, 2, -1 do
            local j = math.random(i)
            shuffledIdx[i], shuffledIdx[j] = shuffledIdx[j], shuffledIdx[i]
        end
        -- Guards are fixed for the camp's lifetime ("a good portion should
        -- always patrol"); everyone else enters the rotating daily schedule
        -- (CampRoleCycle) with a staggered starting index, so the camp shows
        -- a mix of occupations at any moment. The stagger is what the
        -- per-merc loop below records into CampRoleIdx; RotateCampRoles then
        -- advances everyone every few minutes.
        local campRole = {}
        local campSeed = {}
        for p = 1, guardCount do campRole[shuffledIdx[p]] = "guard" end
        local nonGuardRank = 0
        for p = guardCount + 1, mercCount do
            nonGuardRank = nonGuardRank + 1
            local seed = ((nonGuardRank - 1) % #self.CampRoleCycle) + 1
            campRole[shuffledIdx[p]] = self.CampRoleCycle[seed]
            campSeed[shuffledIdx[p]] = seed
        end
        self.CampFurniture = {}
        self.CampActivities = {}
        self.CampMercSpots = {}
        self.CampRoleIdx = {}
        self.CampNextRotate = {}
        self.CampSeats = {}
        self.CampBeds = {}
        self.CampTicks = 0

        -- Everyone gets a tent, up to the cap - excess mercs beyond that
        -- fall back to a plain straw bed (see the "else" branch below).
        local tentRecipients = math.min(self.CampMaxTents, mercCount)
        local ClusterSize = self.CampClusterSize
        local numClusters = math.max(1, math.ceil(tentRecipients / ClusterSize))

        -- Grid axes: "forward" is the direction the player was facing when
        -- camp was made - the whole grid (and the player tent's own facing)
        -- is built around that, so the single reserved-empty tile always
        -- lines up with the tent's entrance. "right" is perpendicular to it.
        local playerDir = player:GetDirectionVector()
        local dirLen = math.sqrt(playerDir.x * playerDir.x + playerDir.y * playerDir.y)
        local forward = dirLen > 0.0001 and { x = playerDir.x / dirLen, y = playerDir.y / dirLen } or { x = 0, y = 1 }
        local right = { x = -forward.y, y = forward.x }
        local spacing = self.CampClusterSpacing

        -- Cell (0, 0) is the player tent itself; (dx, dy) offsets are in
        -- grid tiles, dx = right/left, dy = forward(+)/behind(-).
        local function gridCellPos(dx, dy)
            return self:CampSnapToGround({
                x = center.x + right.x * dx * spacing + forward.x * dy * spacing,
                y = center.y + right.y * dx * spacing + forward.y * dy * spacing,
                z = center.z,
            })
        end

        local worldForwardAngle = math.atan2(forward.y, forward.x)
        self:SpawnPlayerCampTent(center, worldForwardAngle)

        -- Fire clusters fill grid cells in the order CampGridOffsets lays
        -- out - behind the player tent first, then left/right, then the
        -- corners, then further rings for bigger squads - always skipping
        -- (0, 0) (the player tent) and (0, 1) (the reserved empty tile
        -- directly in front of it).
        local clusterOffsets = self:CampGridOffsets(numClusters)
        local clusterCenters = {}
        for c = 1, numClusters do
            local off = clusterOffsets[c]
            local cPos = gridCellPos(off[1], off[2])
            table.insert(clusterCenters, cPos)
            self:SpawnCampFirePrefab(cPos, 0)
        end

        -- TRAINING YARD (per feedback: right in front of the player tent, a
        -- little space in between). Placed CampTrainingYardDistance metres
        -- along "forward" (the same axis the reserved-empty grid tile uses),
        -- so it sits just past the open tile directly ahead of the tent.
        -- Straw dummies (up to five, one per five mercs) are laid out in a row
        -- across the yard; trainees stand on the camp side facing them.
        local trainCenter = self:CampSnapToGround({
            x = center.x + forward.x * self.CampTrainingYardDistance,
            y = center.y + forward.y * self.CampTrainingYardDistance,
            z = center.z,
        })
        -- Dummies face back toward camp; trainees face away from camp (toward
        -- the dummies), i.e. worldForwardAngle.
        local dummyFacing = worldForwardAngle + math.pi
        local traineeFacing = worldForwardAngle
        local numDummies = math.max(1, math.min(5, math.ceil(mercCount / 5)))
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
                        table.insert(self.CampSeats, { wuid = logWuid, pos = logSoPos, occupant = nil })
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
                local strawIndex = i - tentRecipients
                local radius = math.max(3.2, outerRadius - 3.0) + (strawIndex % 3) * 0.5
                pos, angle = self:CampRingPos(center, radius, strawIndex, math.max(strawCount, 1), 0)
                pos = self:CampSnapToGround(pos)
                self:SpawnCampProp("BedStraw", pos, angle)
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
                spots.trainPos = self:CampSnapToGround(self:CampRelativeOffset(trainCenter, worldForwardAngle, { right = rowOff, forward = -self.CampTrainingTraineeSetback }))
                spots.trainFacePos = { x = trainCenter.x, y = trainCenter.y, z = trainCenter.z }
                spots.isTrainer = isTrainer
                spots.lastPos = actPos

                -- Put them on a staggered first step of their cycle and start
                -- their per-role timer; RotateCampRoles advances from here.
                local cycle = self:CampCycleFor(tostring(mercWuid))
                local idx = ((campSeed[i] or 1) - 1) % #cycle + 1
                self.CampRoleIdx[tostring(mercWuid)] = idx
                self:ApplyCampRole(tostring(mercWuid), cycle[idx])
                local span = self.CampRoleSeconds[cycle[idx]] or { 60, 90 }
                self.CampNextRotate[tostring(mercWuid)] = self.CampTicks + math.max(1, math.floor(math.random(span[1], span[2]) / 5))
            end

            -- Start each merc at wherever their first occupation happens -
            -- they walk between spots themselves from now on.
            local act = self.CampActivities[tostring(mercWuid)]
            local fur = self.CampFurniture[tostring(mercWuid)]
            local startPos = (act and act.pos) or (fur and fur.pos) or slotPos
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
        _G.MercCampMode = true
        -- The new "incamp" state (distinct from idle/following): the
        -- schedulers and the follow BT read this to route guards into patrol
        -- and everyone else into stand-still. Set alongside MercIdle below so
        -- all the existing idle-suppression side effects (no teleport-to-
        -- player, formation monitor leaves them be, etc.) still apply in camp.
        _G.MercInCamp = true

        -- Reuse the existing "wait" idle state - mercs already know how to
        -- stand still under it, and it's the same state formation/teleport
        -- monitors already treat as "leave them be". Guards are carved out of
        -- the idle branch in the schedulers (see IsCampGuard) so they patrol
        -- instead of standing, but MercIdle staying true keeps every other
        -- idle side effect in force for the whole camp.
        _G.MercIdle = true
        _G.MercPersistentIdleFlag = true
        self:SaveString("MercIdlePersistent", "1")

        Game.SendInfoText('merc_info_camp_made', false, 0, 4)
    end)

    if not ok then
        System.LogAlways('[Mercenaries] SpawnMercCamp error: ' .. tostring(err))
    end
end

-- =======================================================================
-- BREAK CAMP - despawns every tracked prop and resumes normal squad state.
-- silent = true skips the "camp broken" info text (used when an explicit
-- follow/dismiss order tears the camp down as a side effect).
-- =======================================================================
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
    self.CampCenter = nil
    self.CampActive = false
    _G.MercCampMode = false
    _G.MercInCamp = false
    _G.MercCampChats = {}
    self.CampChatMercCooldown = {}
    self.CampChatStaggered = false

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

-- =======================================================================
-- RECALL - brings the whole squad to the player's current position
-- immediately, from anywhere, and resumes following. Does NOT touch the
-- camp structure (tents etc. stay standing until explicitly broken) - only
-- the mercs' positions/state change. Bound to a key in OnGameplayStarted
-- (see mercenaries.lua), same "bind <key> <command>" pattern the bodyguards
-- reference mod uses for its own hotkeys.
-- =======================================================================
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
                pos = self:CampSnapToGround(pos)
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
