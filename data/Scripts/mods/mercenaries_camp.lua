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
    -- Fallback single tent model (used by SpawnBedTest and anywhere a single
    -- definite tent is needed) - the real camp layout instead picks
    -- randomly from CampTentVariants for visual variety, see SpawnMercCamp.
    TentLarge = "objects/manmade/structures/living/tents/tent_small_forest_a.cgf",
    -- Confirmed in-game (merc_camp_bed_row_test) to be the only bed model
    -- that reads as an actual bed rather than a rag/skins/blob in tall
    -- grass - both tiers use it now (no more separate "nicer" tent-tier bed).
    Bed       = "objects/manmade/common_furniture/beds/low/bed_shabby_a.cgf",
    BedStraw  = "objects/manmade/common_furniture/beds/low/bed_shabby_a.cgf",
    Chair     = "objects/manmade/common_furniture/chairs/low/chair_rustic_d.cgf",
    Stool     = "objects/manmade/common_furniture/chairs/low/chair_trunk_c.cgf",
    Sack      = "objects/manmade/common_furniture/sacks/sack_b.cgf",
    -- Chest is no longer spawned in camp (see SpawnMercCamp) but kept
    -- defined in case it's wanted again later.
    Chest     = "objects/manmade/common_furniture/chests/chest-small-a.cgf",
    -- Confirmed in-game (merc_camp_clutter_test, candidate #10) to read as
    -- an actual stack of weapons - swapped in for one seat per fire cluster,
    -- see SpawnMercCamp.
    WeaponStack = "objects/manmade/common_decorations/weapons/polearm_pile_a.cgf",
}

-- Campfire spawning switched to Game.SpawnPrefab against an invisible
-- anchor entity - the SAME technique references/zdjbcamping_mod's own
-- DJB_Camping:SpawnCampfirePrefab uses (spawn an anchor, Hide it, then
-- Game.SpawnPrefab(anchor.id, prefabId, 0)), confirmed working by grepping
-- that mod's own Lua for every Game.SpawnPrefab call site. Switched to this
-- FROM manually assembling a wood model + ParticleEffect (SpawnCampFire,
-- below, kept for reference/tinkering but no longer called by the live
-- camp) because that approach mostly produced invisible props in-game -
-- camp_cooking_a/b rendered (but too large), everything else
-- (fireplace_wood_a/b/c, grid_fireplace/_b, camp_cooking_c_old/d_old) came
-- back invisible despite using the exact same BasicEntity+object_Model
-- spawn path that works fine for every other camp prop. Most likely
-- explanation: those specific .cgf paths, hand-picked from a static
-- reference dump, don't all resolve to assets that actually exist in the
-- shipped game the same way - guessing individual file paths has real
-- limits. A prefab GUID is a more load-bearing identifier than an internal
-- file path, and a whole pre-authored prefab already has its wood/particle/
-- light pieces correctly positioned/rotated relative to each other, so this
-- sidesteps the per-model Z-offset/rotation guessing entirely too.
-- CampFirePrefabId is fireplace_on_camp.xml's own Prefab Id - the vanilla
-- "reference lit campfire" identified earlier (fireplace_wood_c.cgf +
-- WH_Particels.fires.fireplace_nosmoke_low + a Light, all pre-aligned).
mercenaries.CampFirePrefabId = "84b335ee-22f2-411e-b3da-97f13575370c"

-- Old manual assembly - kept for SpawnCampFireTestRow's legacy candidates
-- and in case Game.SpawnPrefab turns out not to work either. Not used by
-- the live camp anymore (see above).
mercenaries.CampFireModel = "objects/manmade/task_specific_props/food_processing/cooking/camp_cooking_a.cgf"
mercenaries.CampFireParticleEffect = "WH_Particels.fires.exterior_fireplace"

-- The very first campfire model this mod ever used (originally paired with
-- a particle, back when campfires were built via manual assembly - see
-- CampFireCandidates' "camp_cooking_c_old" entry). Per feedback, now layered
-- as a plain static overlay directly on top of the fireplace_on_camp prefab's
-- ash heap (SpawnCampFirePrefab below) instead of being spawned alone.
mercenaries.CampFireOverlayModel = "objects/manmade/task_specific_props/food_processing/cooking/camp_cooking_c_old.cgf"

-- Confirmed in-game (merc_camp_tent_test) to share roughly the same
-- footprint and all face the same way, so the real camp picks one of these
-- at random per tent instead of using a single fixed model - see
-- SpawnMercCamp. All are vanilla one-NPC "sleeper" tents (tent_small_forest_a
-- is the one used by references/Prefabs/Tent/tent_1.xml; the rest are
-- references/zdjbcamping_mod's per-tier equivalents).
mercenaries.CampTentVariants = {
    "objects/manmade/structures/living/tents/tent_small_forest_a.cgf",
    "objects/manmade/structures/living/tents/tent_small_forest_b.cgf",
    "objects/manmade/structures/living/tents/tent_small_forest_d.cgf",
    "objects/manmade/structures/living/tents/tent_small_shabby_a.cgf",
    "objects/manmade/structures/living/tents/tent_small_rustic_a.cgf",
}

-- Candidate tent models for side-by-side comparison in-game - see
-- SpawnTentTestRow / the merc_camp_tent_test console command below. Sourced
-- from actual base-game prefabs (references/Prefabs/Tent/*.xml,
-- references/Prefabs/Barber/barber_tent.xml) and references/zdjbcamping_mod's
-- per-tier tent choices, favoring models vanilla actually uses for a SINGLE
-- NPC's sleeping spot over multi-prop camp centerpieces. The first five
-- (confirmed same footprint/facing) are CampTentVariants above; the rest
-- were rejected (too big, wrong facing, or the old oversized default).
mercenaries.CampTentCandidates = {
    { name = "small_forest_a (vanilla 1-sleeper soldier tent, tent_1.xml) - IN USE", model = "objects/manmade/structures/living/tents/tent_small_forest_a.cgf" },
    { name = "small_forest_b (zdjb basic bed tent) - IN USE", model = "objects/manmade/structures/living/tents/tent_small_forest_b.cgf" },
    { name = "small_forest_d (zdjb poacher tent) - IN USE", model = "objects/manmade/structures/living/tents/tent_small_forest_d.cgf" },
    { name = "small_shabby_a (zdjb refugee tent) - IN USE", model = "objects/manmade/structures/living/tents/tent_small_shabby_a.cgf" },
    { name = "small_rustic_a (zdjb wayfarer tent) - IN USE", model = "objects/manmade/structures/living/tents/tent_small_rustic_a.cgf" },
    { name = "big_round_a (vanilla 1-sleeper knight tent, tent_knights.xml) - rejected, faces the other way", model = "objects/manmade/structures/living/tents/tent_big_round_a.cgf" },
    { name = "big_round_b (barber's private tent) - rejected, faces the other way", model = "objects/manmade/structures/living/tents/tent_big_round_b.cgf" },
    { name = "gypsycamp_tent_b (unique gypsy camp tent) - rejected, open both ways", model = "objects/manmade/structures/living/tents/gypsycamp_tent_b.cgf" },
    { name = "big_square_b_hungarien_green (OLD default) - rejected, gigantic", model = "objects/manmade/structures/living/tents/tent_big_square_b_hungarien_green.cgf" },
}

-- Candidate bed models for side-by-side comparison in-game - see
-- SpawnBedRowTest / merc_camp_bed_row_test below. Every bed prefab found
-- under references/Prefabs/Bed/*.xml, references/zdjbcamping_mod, and the
-- generic vanilla "Bed" entity's own default model
-- (references/Scripts/Entities/WH/Bed/Bed.lua).
mercenaries.CampBedCandidates = {
    { name = "bed_makeshift_a - rejected, just a rag", model = "objects/manmade/common_furniture/beds/low/bed_makeshift_a.cgf" },
    { name = "bed_makeshift_c - rejected, a bunch of skins", model = "objects/manmade/common_furniture/beds/low/bed_makeshift_c.cgf" },
    { name = "bed_shabby_a - IN USE (actual straw bed w/ log frame, only one visible in tall grass)", model = "objects/manmade/common_furniture/beds/low/bed_shabby_a.cgf" },
    { name = "bed_shabby_b - rejected", model = "objects/manmade/common_furniture/beds/low/bed_shabby_b.cgf" },
    { name = "bed_fancy_a - rejected", model = "objects/manmade/common_furniture/beds/high/bed_fancy_a.cgf" },
    { name = "bed_double_fancy_a - rejected, wide/two-person", model = "objects/manmade/common_furniture/beds/high/bed_double_fancy_a.cgf" },
    { name = "bed_cottage_01 - rejected, renders as a blank white shape here", model = "objects/props/furniture/beds/bed_cottage_01.cgf" },
}

-- Candidate campfires for side-by-side comparison in-game - see
-- SpawnCampFireTestRow / merc_camp_fire_test below. A candidate is either
-- `prefabId` (spawned via Game.SpawnPrefab against an anchor - see
-- CampFirePrefabId above) or `model`+`particle` (the old manual assembly -
-- confirmed mostly broken, see above; camp_cooking_a/b are the only ones
-- that render at all, and even those are too large). Prefab candidates:
-- fireplace_on_camp's own prefab (the new default), plus three of
-- references/zdjbcamping_mod's own campfire prefab GUIDs (from
-- DetermineEquipmentVariation's firePrefabId field) per "try the ones from
-- the camping mod" - note these are gneiss-rock cooking setups from that
-- mod's own tier system, not confirmed to include an active flame (may be
-- the "prepared but unlit" state, same distinction as camp_cooking_*_old).
mercenaries.CampFireCandidates = {
    { name = "fireplace_on_camp prefab - NEW DEFAULT (vanilla self-contained lit campfire: fireplace_wood_c + fireplace_nosmoke_low + a Light, all pre-aligned)", prefabId = "84b335ee-22f2-411e-b3da-97f13575370c" },
    { name = "zdjbcamping_mod Refugee-tier fire prefab (gneiss rocks + pan/cleaver/meat - may be unlit/decorative only)", prefabId = "3954e691-1817-4d63-acce-769699468f83" },
    { name = "zdjbcamping_mod Cuman-tier fire prefab (sausage maker + grill over gneiss rock - may be unlit/decorative only)", prefabId = "064b9851-443f-4f2a-b2e3-752fea5c1523" },
    { name = "zdjbcamping_mod Basic-tier fire prefab (gneiss rocks + stick - may be unlit/decorative only)", prefabId = "547633e0-629f-4af7-8d02-335290d9ce06" },
    { name = "camp_cooking_a + exterior_fireplace - renders but TOO LARGE, rejected", model = "objects/manmade/task_specific_props/food_processing/cooking/camp_cooking_a.cgf", particle = "WH_Particels.fires.exterior_fireplace" },
    { name = "camp_cooking_b + exterior_fireplace - renders but TOO LARGE, rejected", model = "objects/manmade/task_specific_props/food_processing/cooking/camp_cooking_b.cgf", particle = "WH_Particels.fires.exterior_fireplace" },
    { name = "fireplace_wood_a + exterior_fireplace - INVISIBLE in-game, rejected", model = "objects/manmade/task_specific_props/food_processing/cooking/fireplace_wood_a.cgf", particle = "WH_Particels.fires.exterior_fireplace" },
    { name = "fireplace_wood_b + house_fireplace - INVISIBLE in-game, rejected", model = "objects/manmade/task_specific_props/food_processing/cooking/fireplace_wood_b.cgf", particle = "WH_Particels.fires.house_fireplace" },
    { name = "fireplace_wood_c + fireplace_nosmoke_low - INVISIBLE via manual assembly, yet this exact model is what the fireplace_on_camp PREFAB candidate above uses successfully - a spawning-technique problem, not a bad model", model = "objects/manmade/task_specific_props/food_processing/cooking/fireplace_wood_c.cgf", particle = "WH_Particels.fires.fireplace_nosmoke_low" },
    { name = "grid_fireplace + exterior_fireplace - INVISIBLE in-game, rejected", model = "objects/manmade/common_fixtures/fireplaces/grid_fireplace.cgf", particle = "WH_Particels.fires.exterior_fireplace" },
    { name = "grid_fireplace_b + exterior_fireplace - INVISIBLE in-game, rejected", model = "objects/manmade/common_fixtures/fireplaces/grid_fireplace_b.cgf", particle = "WH_Particels.fires.exterior_fireplace" },
    { name = "camp_cooking_c_old - OLD original default, now also reported INVISIBLE, rejected", model = "objects/manmade/task_specific_props/food_processing/cooking/camp_cooking_c_old.cgf", particle = "WH_Particels.fires.exterior_fireplace" },
    { name = "camp_cooking_d_old - previously \"acceptable\", now also reported INVISIBLE, rejected", model = "objects/manmade/task_specific_props/food_processing/cooking/camp_cooking_d_old.cgf", particle = "WH_Particels.fires.exterior_fireplace" },
}

-- Candidate decorative clutter for side-by-side comparison in-game - see
-- SpawnClutterTestRow / merc_camp_clutter_test below. Sacks and crates
-- sourced from references/zdjbcamping_mod's own prop list; sack_charcoal is
-- the vanilla "charcoal sack" model (from the charcoal-wagon/furnace
-- prefabs) standing in for "piles of charcoal"; the two charcoal_piece_*
-- models (loose chunk piles from the blacksmith/collier prefabs) are an
-- alternative, un-sacked take on the same idea. polearm_pile_a is a
-- standalone "stack of weapons" model (pulled out of
-- references/Prefabs/interiorDecoration/weaponGroups/polearms_in_barrel.xml,
-- where it's shown resting tilted atop an open barrel - it may not sit flat
-- if spawned straight on the ground, unverified); the polearms_in_barrel
-- prefab entry spawns that whole authored scene (barrel + weapon pile + hay)
-- via Game.SpawnPrefab instead, the same reliable technique as the campfire.
-- Numbered per the merc_camp_clutter_test row (1-indexed, matching feedback
-- verbatim): #1/#3/#4 are good sacks, #5/#6 are open containers (usable),
-- #9 is a very large container (rejected - too big to sit beside a tent),
-- #10 is the weapon stack (confirmed good, now CampModels.WeaponStack).
-- #2/#7/#8/#11/#12/#13 weren't called out either way - kept defined for the
-- comparison row but not used by the live camp (see CampTentClutterVariants
-- below for what actually got picked).
mercenaries.CampClutterCandidates = {
    { name = "#1 sack_b (plain sack, same model as CampModels.Sack) - GOOD, IN USE", model = "objects/manmade/common_furniture/sacks/sack_b.cgf" },
    { name = "#2 sack_empty_a (deflated/empty sack)", model = "objects/manmade/common_furniture/sacks/sack_empty_a.cgf" },
    { name = "#3 sack_pig_feed (feed sack) - GOOD, IN USE", model = "objects/manmade/common_furniture/sacks/sack_pig_feed.cgf" },
    { name = "#4 sack_charcoal (charcoal sack) - GOOD, IN USE", model = "objects/manmade/common_furniture/sacks/sack_charcoal.cgf" },
    { name = "#5 crate_low_b (low crate) - open container, IN USE", model = "objects/manmade/common_furniture/crates/crate_low_b.cgf" },
    { name = "#6 crate_small (small crate) - open container, IN USE", model = "objects/manmade/common_furniture/crates/crate_small.cgf" },
    { name = "#7 crate_short_for_silver (short crate)", model = "objects/manmade/common_furniture/crates/crate_short_for_silver.cgf" },
    { name = "#8 crate_fabric (cloth-draped crate, from swords_in_crate.xml)", model = "objects/manmade/common_furniture/crates/crate_fabric.cgf" },
    { name = "#9 crate_box_c (plain box crate, from swords_in_crate.xml) - rejected, too large", model = "objects/manmade/common_furniture/crates/crate_box_c.cgf" },
    { name = "#10 polearm_pile_a (standalone stack-of-weapons model) - GOOD, now CampModels.WeaponStack", model = "objects/manmade/common_decorations/weapons/polearm_pile_a.cgf" },
    { name = "#11 polearms_in_barrel prefab (barrel + weapon pile + hay, self-contained scene)", prefabId = "309bfbd5-3f0f-49bf-b397-6574d5f3b1ba" },
    { name = "#12 charcoal_piece_b (loose charcoal chunk pile)", model = "objects/manmade/structures/industrial/kilns/charcoal_piece_b.cgf" },
    { name = "#13 charcoal_piece_d (loose charcoal chunk pile, larger)", model = "objects/manmade/structures/industrial/kilns/charcoal_piece_d.cgf" },
}

-- Random prop spawned beside every merc tent (see SpawnMercCamp) - the
-- confirmed-good sacks (#1/#3/#4) and open containers (#5/#6) from
-- CampClutterCandidates above. #9 (crate_box_c) deliberately excluded per
-- feedback - too large to sit beside a tent.
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
-- per camp (not assigned to any merc). "White" round tent, per feedback -
-- tent_big_round_a.cgf (one of the two rejected-for-mercs "large white
-- circular" candidates from CampTentCandidates; picked over the barber's
-- tent_big_round_b since it's the one with an actual vanilla single-sleeper
-- precedent, tent_knights.xml). Bed uses the same low straw model the mercs
-- use (CampModels.Bed / bed_shabby_a.cgf); it started as the taller
-- bed_double_fancy_a but that left the player sinking on waking (its lying
-- position sat high off the ground), so it was swapped to the ground bed
-- whose height matches the Bed_1Place_Low / GroundBed smart-object helper.
--
-- Making the bed interactable ("E - Sleep"): the mechanism is the SAME one
-- references/zdjbcamping_mod uses, now that its actual workings have been
-- traced. That mod's bed interaction does NOT come from an OnUsed handler -
-- an earlier version of this code assumed it did and set OnUsed on the bed,
-- which never fired. Reading DJB_BedEntity.lua closely: it defines OnUsed,
-- then calls EntityCommon.MakeUsable(DJB_BedEntity) AFTER, and MakeUsable
-- unconditionally overwrites OnUsed with a generic broadcast-only handler
-- (references/Scripts/Entities/EntityCommon.lua) - so DJB_BedEntity's own
-- OnUsed is dead code. The real sleep interaction comes from a SEPARATE
-- vanilla `BedTrigger` entity (references/Scripts/Entities/WH/Triggers/
-- BedTrigger.lua, an ActionTrigger subclass) that the camping mod spawns
-- next to the bed and links to it (DJB_Camping:SpawnBedTrigger /
-- LinkBedEntities). The trigger provides the "@ui_hud_sleep" prompt and,
-- on use, drives the lying/sleep stance against the bed's smart object.
--
-- So SpawnPlayerCampTent below spawns TWO things:
--   1. the bed itself - a plain BasicEntity with the vanilla bed smart-
--      object properties (guidSmartObjectType/soclass_SmartObjectHelpers/
--      Bed/Script.esBedTypes, copied from DJB_BedEntity). No custom .ent
--      class needed: the SO registration is entirely property-driven, so a
--      BasicEntity with the same properties registers the same smart object
--      DJB_BedEntity does.
--   2. a vanilla `BedTrigger` next to it, with a Click block
--      (esActionType="Stance", sAction="lying", UseMessage="@ui_hud_sleep"),
--      linked to the bed via an EMPTY-NAMED link - which is exactly what
--      ActionTrigger:GetLinkedSmartObject looks for (the first link whose
--      name == "") to find the smart object to lie on.
-- BedTrigger geometry (CampPlayerBedTrigger* below) is a starting guess and
-- may need tuning in-game, same as the other camp offsets.
mercenaries.CampPlayerTentModel = "objects/manmade/structures/living/tents/tent_big_round_a.cgf"
-- Same low straw bed the mercs use (CampModels.Bed) rather than the tall
-- bed_double_fancy_a - the fancy bed's lying position sat high off the
-- ground, so the player sank on waking. The low ground bed matches its
-- "Bed_1Place_Low" / GroundBed smart-object helper, keeping the lie/wake
-- height at ground level.
mercenaries.CampPlayerBedModel = mercenaries.CampModels.Bed
-- White/round tents face the opposite way from the small ones (see
-- CampTentCandidates) - CampTentFacingFix plus another half turn. Computed
-- inside SpawnPlayerCampTent (not here) since CampTentFacingFix itself is
-- defined further down this file - referencing it at this point, before
-- it exists yet, would evaluate to nil and error out the whole script load.
-- Starting guess only - tent_big_round_a's footprint is nothing like the
-- small tents CampBedOffset was tuned against, so this hasn't been tuned at
-- all yet. merc_camp_bed_test always targets CampModels.TentLarge/BedStraw,
-- not this pairing directly - temporarily point those at
-- CampPlayerTentModel/CampPlayerBedModel to reuse that tool, or just
-- eyeball and edit this directly. Tried right=1 (a meter toward the tent's
-- right side) per feedback - moved it the wrong way, so switched to the
-- forward axis instead (forward=1) per follow-up feedback.
mercenaries.CampPlayerBedOffset = { right = 0, forward = 1, z = 0, rotationDeg = 180 }
-- BedTrigger placement relative to the bed's own centre/facing (right/forward
-- in the bed's local frame, z world-up) and its interaction-volume scale. The
-- camping mod uses a small offset + 0.29 scale for a low ground bed; ours is a
-- big double bed, so the trigger sits at the bed centre lifted a little, with
-- a roomier volume so the prompt is easy to catch. Tunable if the "E - Sleep"
-- prompt is awkward to trigger in-game.
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

--[[ Smart-object properties that used to be merged onto specific props at
spawn time (see SpawnCampProp) so mercs could sit/lie in them via
StanceElement. DISABLED - mercs weren't actually using the furniture in
practice, so the whole sit/sleep interaction is commented out for now (see
SpawnMercCamp and mercenary_scheduler.xml/archer_scheduler.xml). Left here
for reference in case this gets revisited - GUIDs and soclass names were
lifted from references/zdjbcamping_mod's DJB_ChairEntity.ent/DJB_BedEntity.ent,
cross-checked against references/Libs/Tables/ai/smartEntity/
SmartEntity__so_sitPlace.xml (DatabaseId 57cbebae-...) and
SmartEntity__so_bed.xml (DatabaseId 425d4fdf-...).

mercenaries.CampFurnitureSO = {
    Bed = {
        kind = "bed",
        guidSmartObjectType = "425d4fdf-8dcd-4a2b-fdc5-cbb1b5d25b89",
        soclass_SmartObjectHelpers = "Bed_1Place_Low",
        sWH_AI_EntityCategory = "Bed",
        sSittingTagGlobal = "sittingNoTable",
        fUsabilityDistance = 1.25,
    },
    BedStraw = {
        kind = "bed",
        guidSmartObjectType = "425d4fdf-8dcd-4a2b-fdc5-cbb1b5d25b89",
        soclass_SmartObjectHelpers = "Bed_1Place_Low",
        sWH_AI_EntityCategory = "Bed",
        sSittingTagGlobal = "sittingNoTable",
        fUsabilityDistance = 1.25,
    },
    Chair = {
        kind = "chair",
        guidSmartObjectType = "57cbebae-c19a-443b-8945-999d8ee87955",
        soclass_SmartObjectHelpers = "Sit_1Place_Bench_Low",
        sWH_AI_EntityCategory = "Seat",
        sSittingTagGlobal = "sittingNoTable",
        fUsabilityDistance = 1.75,
    },
    Stool = {
        kind = "chair",
        guidSmartObjectType = "57cbebae-c19a-443b-8945-999d8ee87955",
        soclass_SmartObjectHelpers = "Sit_1Place_Bench_Low",
        sWH_AI_EntityCategory = "Seat",
        sSittingTagGlobal = "sittingNoTable",
        fUsabilityDistance = 1.75,
    },
}
]]

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
mercenaries.CampFurniture  = {}  -- unused while sit/sleep is disabled - see CampFurnitureSO above
mercenaries.CampCommunalChairs = {} -- unused while sit/sleep is disabled - see CampFurnitureSO above

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
function mercenaries:SpawnCampPropModel(model, pos, angleZ, namePrefix)
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
        table.insert(self.CampEntities, ent.id)
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

-- Height above ground and rotation applied to every spawned fire
-- ParticleEffect entity. The rotation is the actual fix for "campfires
-- mostly not showing up": EVERY single ParticleEffect placement found
-- across the whole reference dump (campfires, chandeliers, torches, dozens
-- of unrelated prefabs) carries the same ~90-degree-about-X rotation
-- (quaternion "0.7071068,0.7071068,0,0") - the effects' local emission axis
-- assumes it, and ours were left at identity (pointing sideways/downward
-- instead of up), which is almost certainly why most looked wrong or
-- invisible. Height bumped from 0.3 (too low, buried in some wood piles) to
-- 0.5 - vanilla references range ~0.25-0.8 depending on composition, so
-- this may still need tuning per model.
mercenaries.CampFireParticleHeight = 0.5
mercenaries.CampFireParticleAngles = { x = math.pi / 2, y = 0, z = 0 }

-- Spawns a campfire: the static wood-prop model plus a fire ParticleEffect
-- entity layered on top (see CampFireModel/CampFireParticleEffect above -
-- no static model alone has a visible flame in this engine). Both are
-- tracked in CampEntities for teardown.
function mercenaries:SpawnCampFire(pos, angleZ)
    local fireEnt = self:SpawnCampPropModel(self.CampFireModel, pos, angleZ, "MercCampProp_Fire")

    local ok, err = pcall(function()
        local groundPos = self:CampSnapToGround(pos)
        local particleEnt = System.SpawnEntity({
            class = "ParticleEffect",
            name = "MercCampProp_FireFlame_" .. tostring(math.random(100000, 999999)),
            position = { x = groundPos.x, y = groundPos.y, z = groundPos.z + self.CampFireParticleHeight },
            properties = { ParticleEffect = self.CampFireParticleEffect }
        })
        if particleEnt then
            pcall(function() particleEnt:SetAngles(self.CampFireParticleAngles) end)
            table.insert(self.CampEntities, particleEnt.id)
        end
    end)
    if not ok then
        System.LogAlways('[Mercenaries] SpawnCampFire particle error: ' .. tostring(err))
    end

    return fireEnt
end

-- Spawns a campfire via Game.SpawnPrefab against an invisible anchor entity
-- - see CampFirePrefabId above for why this replaced SpawnCampFire as the
-- live camp's technique. The anchor is the only piece tracked in
-- CampEntities / swept by name prefix for teardown; the prefab's own
-- spawned pieces (wood/particle/light) keep whatever names were authored
-- into that prefab, so they are NOT independently name-swept by
-- ClearAnyLeftoverCamp - only removing the anchor (BreakMercCamp iterates
-- CampEntities) is relied on to take them with it. Not verified.
--
-- The prefab alone renders as a small smouldering ash heap (confirmed good)
-- - CampFireOverlayModel (the very first campfire model this mod used) is
-- layered on top of it at the same position/facing, per feedback, for a
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

        -- Seats around each cluster's fire, one per merc assigned to that
        -- cluster (replaces the old separate personal-stool + capped
        -- communal-chair setup - fewer, more purposeful seats overall).
        -- Per feedback, the first seat slot in each cluster becomes a
        -- weapon stack instead of a chair, rather than a plain stool.
        for c, cPos in ipairs(clusterCenters) do
            local clusterFirst = (c - 1) * ClusterSize + 1
            local clusterLast = math.min(c * ClusterSize, tentRecipients)
            local clusterMercCount = clusterLast - clusterFirst + 1
            for j = 1, clusterMercCount do
                -- Halved from 1.8 to 0.9 per feedback (props sitting closer
                -- to the fire), then +0.5m per follow-up feedback.
                local seatPos, seatAngle = self:CampRingPos(cPos, 1.4, j, clusterMercCount, math.pi / clusterMercCount)
                if j == 1 then
                    self:SpawnCampProp("WeaponStack", seatPos, seatAngle + math.pi)
                else
                    self:SpawnCampProp("Chair", seatPos, seatAngle + math.pi)
                end
            end
        end

        self.CampSlots = {}
        self.CampPatrollers = {}

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

        for i, m in ipairs(mercList) do
            local hasTent = i <= tentRecipients
            local mercWuid = entWuid(m.ent)
            local pos, angle

            if hasTent then
                local clusterIndex = math.ceil(i / ClusterSize)
                local clusterFirst = (clusterIndex - 1) * ClusterSize + 1
                local clusterLast = math.min(clusterIndex * ClusterSize, tentRecipients)
                local clusterMercCount = clusterLast - clusterFirst + 1
                local memberIndex = i - clusterFirst + 1
                local cPos = clusterCenters[clusterIndex]

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
                -- Random tent variant per merc, for visual variety - the
                -- first five CampTentCandidates share the same footprint/
                -- facing (confirmed in-game), so any of them drops in here.
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
                self:SpawnCampProp("Bed", pos, bedAngle)
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
            pcall(function() m.ent:SetPos(slotPos) end)
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
        local NUM_WAYPOINTS = 8
        local patrolRadius = maxClusterOffset + self.CampTentRingRadius + self.CampPatrolTentClearance
        local patrolCount = math.max(1, math.floor(mercCount / 2 + 0.5))
        patrolCount = math.min(patrolCount, mercCount)
        local patrolIndices = {}
        for i = 1, mercCount do table.insert(patrolIndices, i) end
        for i = mercCount, 2, -1 do
            local j = math.random(i)
            patrolIndices[i], patrolIndices[j] = patrolIndices[j], patrolIndices[i]
        end
        for p = 1, patrolCount do
            local m = mercList[patrolIndices[p]]
            if m then
                local wuid = entWuid(m.ent)
                local baseAngle = (p - 1) * (2 * math.pi / math.max(patrolCount, 1))
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
    self.CampCommunalChairs = {}
    self.CampCenter = nil
    self.CampActive = false
    _G.MercCampMode = false
    _G.MercInCamp = false

    if not silent then
        Game.SendInfoText('merc_info_camp_broken', false, 0, 3)
    end
end

-- Called from LowPriorityMonitorLoop (5s cadence) while camp is active.
-- Camp itself does NOT auto-despawn based on player distance anymore - it
-- stays up until explicitly broken. Patrol advancement used to be a SetPos
-- hop driven from here; it's now real Move-based walking driven from
-- mercenary_follow.xml's incamp-guard branch instead (see IsCampGuard/
-- GetPatrolWaypoint/AdvancePatrolWaypoint), so this is currently a no-op -
-- kept as a hook for any future camp-wide periodic checks.
function mercenaries:MonitorCamp()
    if not self.CampActive then return end
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
    -- normal following - clear the incamp state so guards stop patrolling,
    -- even though the camp structure itself stays standing until broken.
    _G.MercInCamp = false
    _G.MercIdle = false
    _G.MercPersistentIdleFlag = false
    self:SaveString("MercIdlePersistent", "0")

    Game.SendInfoText('merc_info_recalled', false, 0, 3)
end

-- Called once from OnGameplayStarted. Camp never persists across a save/
-- load (see file header) - this sweeps away any leftover props from a
-- camp that was active when the game was saved, since our Lua-side
-- CampEntities list is gone after a fresh script load either way. Also
-- sweeps any leftover tent/bed/fire-comparison-row/placement-test props
-- (see SpawnTentTestRow/SpawnBedTest/SpawnBedRowTest/SpawnCampFireTestRow) -
-- including the ParticleEffect-class fire flames, which BasicEntity's own
-- class sweep below can't catch.
function mercenaries:ClearAnyLeftoverCamp()
    local ok, err = pcall(function()
        local ents = System.GetEntitiesByClass("BasicEntity")
        if ents then
            for _, e in pairs(ents) do
                local name = e and e:GetName() or ""
                if string.find(name, "MercCampProp_", 1, true) or string.find(name, "MercTentTest_", 1, true) or string.find(name, "MercBedTest_", 1, true) or string.find(name, "MercBedRowTest_", 1, true) or string.find(name, "MercFireRowTest_", 1, true) or string.find(name, "MercClutterRowTest_", 1, true) then
                    System.RemoveEntity(e.id)
                end
            end
        end

        local particles = System.GetEntitiesByClass("ParticleEffect")
        if particles then
            for _, e in pairs(particles) do
                local name = e and e:GetName() or ""
                if string.find(name, "MercCampProp_FireFlame_", 1, true) or string.find(name, "MercFireRowTest_Flame_", 1, true) then
                    System.RemoveEntity(e.id)
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
    end)
    if not ok then
        System.LogAlways('[Mercenaries] ClearAnyLeftoverCamp error: ' .. tostring(err))
    end

    self.CampActive = false
    self.CampEntities = {}
    self.CampSlots = {}
    self.CampPatrollers = {}
    self.CampFurniture = {}
    self.CampCommunalChairs = {}
    self.CampCenter = nil
    self.TentTestEntities = {}
    self.BedTestEntities = {}
    self.BedRowTestEntities = {}
    self.FireRowTestEntities = {}
    self.ClutterRowTestEntities = {}
    _G.MercCampMode = false
    _G.MercInCamp = false
end

-- =======================================================================
-- TENT COMPARISON ROW - debug helper. Spawns every model in
-- CampTentCandidates in a row in front of the player (and logs the
-- name -> model mapping) so they can be eyeballed side by side to decide
-- which one CampModels.TentLarge/TentSmall should actually use.
-- Console: merc_camp_tent_test / merc_camp_tent_test_clear
-- =======================================================================
mercenaries.TentTestEntities = {}

function mercenaries:SpawnTentTestRow()
    if not player then return end

    local ok, err = pcall(function()
        self:ClearTentTestRow()

        local origin = player:GetWorldPos()
        local dir = player:GetDirectionVector()
        local right = { x = -dir.y, y = dir.x, z = 0 }
        local spacing = 6.0
        local forward = 4.0

        System.LogAlways('[Mercenaries] Spawning tent comparison row (' .. tostring(#self.CampTentCandidates) .. ' tents):')
        for i, candidate in ipairs(self.CampTentCandidates) do
            local pos = {
                x = origin.x + dir.x * forward + right.x * spacing * (i - 1),
                y = origin.y + dir.y * forward + right.y * spacing * (i - 1),
                z = origin.z,
            }
            pos = self:CampSnapToGround(pos)

            local ent = System.SpawnEntity({
                class = "BasicEntity",
                name = "MercTentTest_" .. tostring(i),
                position = pos,
                properties = {
                    object_Model = candidate.model,
                    bMissionCritical = false,
                }
            })
            if ent then
                pcall(function() ent:SetViewDistUnlimited() end)
                pcall(function() ent:RenderShadow(true) end)
                table.insert(self.TentTestEntities, ent.id)
            end

            System.LogAlways('[Mercenaries]   #' .. tostring(i) .. ': ' .. candidate.name .. ' -> ' .. candidate.model)
        end
    end)

    if not ok then
        System.LogAlways('[Mercenaries] SpawnTentTestRow error: ' .. tostring(err))
    end
end

function mercenaries:ClearTentTestRow()
    local ok, err = pcall(function()
        for _, entId in ipairs(self.TentTestEntities) do
            pcall(function() System.RemoveEntity(entId) end)
        end
    end)
    if not ok then
        System.LogAlways('[Mercenaries] ClearTentTestRow error: ' .. tostring(err))
    end
    self.TentTestEntities = {}
end

-- =======================================================================
-- BED COMPARISON ROW - debug helper. Spawns every model in
-- CampBedCandidates in a row in front of the player (and logs the
-- name -> model mapping) so they can be eyeballed side by side to decide
-- which one CampModels.Bed/BedStraw should actually use.
-- Console: merc_camp_bed_row_test / merc_camp_bed_row_test_clear
-- =======================================================================
mercenaries.BedRowTestEntities = {}

function mercenaries:SpawnBedRowTest()
    if not player then return end

    local ok, err = pcall(function()
        self:ClearBedRowTest()

        local origin = player:GetWorldPos()
        local dir = player:GetDirectionVector()
        local right = { x = -dir.y, y = dir.x, z = 0 }
        local spacing = 3.0
        local forward = 4.0

        System.LogAlways('[Mercenaries] Spawning bed comparison row (' .. tostring(#self.CampBedCandidates) .. ' beds):')
        for i, candidate in ipairs(self.CampBedCandidates) do
            local pos = {
                x = origin.x + dir.x * forward + right.x * spacing * (i - 1),
                y = origin.y + dir.y * forward + right.y * spacing * (i - 1),
                z = origin.z,
            }
            pos = self:CampSnapToGround(pos)

            local ent = System.SpawnEntity({
                class = "BasicEntity",
                name = "MercBedRowTest_" .. tostring(i),
                position = pos,
                properties = {
                    object_Model = candidate.model,
                    bMissionCritical = false,
                }
            })
            if ent then
                pcall(function() ent:SetViewDistUnlimited() end)
                pcall(function() ent:RenderShadow(true) end)
                table.insert(self.BedRowTestEntities, ent.id)
            end

            System.LogAlways('[Mercenaries]   #' .. tostring(i) .. ': ' .. candidate.name .. ' -> ' .. candidate.model)
        end
    end)

    if not ok then
        System.LogAlways('[Mercenaries] SpawnBedRowTest error: ' .. tostring(err))
    end
end

function mercenaries:ClearBedRowTest()
    local ok, err = pcall(function()
        for _, entId in ipairs(self.BedRowTestEntities) do
            pcall(function() System.RemoveEntity(entId) end)
        end
    end)
    if not ok then
        System.LogAlways('[Mercenaries] ClearBedRowTest error: ' .. tostring(err))
    end
    self.BedRowTestEntities = {}
end

-- =======================================================================
-- CAMPFIRE COMPARISON ROW - debug helper. Spawns every candidate in
-- CampFireCandidates in a row in front of the player - either via
-- Game.SpawnPrefab (candidate.prefabId) or the old manual wood+particle
-- assembly (candidate.model/.particle) - logs what was spawned and how so
-- you can decide what CampFirePrefabId should actually use.
-- Console: merc_camp_fire_test / merc_camp_fire_test_clear
-- =======================================================================
mercenaries.FireRowTestEntities = {}

function mercenaries:SpawnCampFireTestRow()
    if not player then return end

    local ok, err = pcall(function()
        self:ClearCampFireTestRow()

        local origin = player:GetWorldPos()
        local dir = player:GetDirectionVector()
        local right = { x = -dir.y, y = dir.x, z = 0 }
        local spacing = 6.0
        local forward = 4.0

        System.LogAlways('[Mercenaries] Spawning campfire comparison row (' .. tostring(#self.CampFireCandidates) .. ' fires):')
        for i, candidate in ipairs(self.CampFireCandidates) do
            local pos = {
                x = origin.x + dir.x * forward + right.x * spacing * (i - 1),
                y = origin.y + dir.y * forward + right.y * spacing * (i - 1),
                z = origin.z,
            }
            pos = self:CampSnapToGround(pos)

            if candidate.prefabId then
                -- Prefab candidates: only the anchor is tracked/removable
                -- by name - the prefab's own spawned pieces keep whatever
                -- names were authored into it (see SpawnCampFirePrefab).
                local anchorEnt = System.SpawnEntity({
                    class = "BasicEntity",
                    name = "MercFireRowTest_Anchor_" .. tostring(i),
                    position = pos,
                    properties = { object_Model = "", bMissionCritical = false }
                })
                if anchorEnt then
                    table.insert(self.FireRowTestEntities, anchorEnt.id)
                    Game.SpawnPrefab(anchorEnt.id, candidate.prefabId, 0)
                end
                System.LogAlways('[Mercenaries]   #' .. tostring(i) .. ': ' .. candidate.name .. ' -> prefab ' .. candidate.prefabId)
            else
                local ent = System.SpawnEntity({
                    class = "BasicEntity",
                    name = "MercFireRowTest_" .. tostring(i),
                    position = pos,
                    properties = {
                        object_Model = candidate.model,
                        bMissionCritical = false,
                    }
                })
                if ent then
                    pcall(function() ent:SetViewDistUnlimited() end)
                    pcall(function() ent:RenderShadow(true) end)
                    table.insert(self.FireRowTestEntities, ent.id)
                end

                local particleEnt = System.SpawnEntity({
                    class = "ParticleEffect",
                    name = "MercFireRowTest_Flame_" .. tostring(i),
                    position = { x = pos.x, y = pos.y, z = pos.z + self.CampFireParticleHeight },
                    properties = { ParticleEffect = candidate.particle or self.CampFireParticleEffect }
                })
                if particleEnt then
                    pcall(function() particleEnt:SetAngles(self.CampFireParticleAngles) end)
                    table.insert(self.FireRowTestEntities, particleEnt.id)
                end

                System.LogAlways('[Mercenaries]   #' .. tostring(i) .. ': ' .. candidate.name .. ' -> ' .. candidate.model .. ' + ' .. tostring(candidate.particle or self.CampFireParticleEffect))
            end
        end
    end)

    if not ok then
        System.LogAlways('[Mercenaries] SpawnCampFireTestRow error: ' .. tostring(err))
    end
end

function mercenaries:ClearCampFireTestRow()
    local ok, err = pcall(function()
        for _, entId in ipairs(self.FireRowTestEntities) do
            pcall(function() System.RemoveEntity(entId) end)
        end
    end)
    if not ok then
        System.LogAlways('[Mercenaries] ClearCampFireTestRow error: ' .. tostring(err))
    end
    self.FireRowTestEntities = {}
end

-- =======================================================================
-- BED PLACEMENT TEST - debug helper. Spawns one tent (CampModels.TentLarge)
-- in front of the player, plus a bed offset from it by (right, forward, z)
-- in the TENT'S OWN local space (not world axes) and rotated by rotationDeg
-- relative to the tent's facing - so you can iterate on where the bed
-- should sit under/beside the tent without me guessing blind. Once you've
-- found values that look right, tell me and they get hardcoded into
-- CampBedOffset above (this command doesn't persist across a script reload).
-- Console: merc_camp_bed_test <right> <forward> <z> <rotationDeg>
--          merc_camp_bed_test_clear
-- =======================================================================
mercenaries.BedTestEntities = {}

function mercenaries:SpawnBedTest(right, forward, z, rotationDeg)
    if not player then return end

    right = tonumber(right) or 0
    forward = tonumber(forward) or 0
    z = tonumber(z) or 0
    rotationDeg = tonumber(rotationDeg) or 0

    local ok, err = pcall(function()
        self:ClearBedTest()

        local playerPos = player:GetWorldPos()
        local playerDir = player:GetDirectionVector()
        local tentPos = self:CampSnapToGround({
            x = playerPos.x + playerDir.x * 4.0,
            y = playerPos.y + playerDir.y * 4.0,
            z = playerPos.z,
        })
        local tentAngle = math.atan2(playerDir.y, playerDir.x)

        local tentEnt = System.SpawnEntity({
            class = "BasicEntity",
            name = "MercBedTest_Tent",
            position = tentPos,
            properties = { object_Model = self.CampModels.TentLarge, bMissionCritical = false }
        })
        if tentEnt then
            pcall(function() tentEnt:SetAngles({ x = 0, y = 0, z = tentAngle }) end)
            table.insert(self.BedTestEntities, tentEnt.id)
        end

        local bedPos, bedAngle = self:CampRelativeOffset(tentPos, tentAngle, { right = right, forward = forward, z = z, rotationDeg = rotationDeg })
        bedPos = self:CampSnapToGround(bedPos)

        local bedEnt = System.SpawnEntity({
            class = "BasicEntity",
            name = "MercBedTest_Bed",
            position = bedPos,
            properties = { object_Model = self.CampModels.BedStraw, bMissionCritical = false }
        })
        if bedEnt then
            pcall(function() bedEnt:SetAngles({ x = 0, y = 0, z = bedAngle }) end)
            table.insert(self.BedTestEntities, bedEnt.id)
        end

        System.LogAlways(string.format(
            '[Mercenaries] Bed test: tent facing %.1f deg, bed offset right=%.2f forward=%.2f z=%.2f, bed rotation %.1f deg relative to tent',
            math.deg(tentAngle), right, forward, z, rotationDeg
        ))
    end)

    if not ok then
        System.LogAlways('[Mercenaries] SpawnBedTest error: ' .. tostring(err))
    end
end

function mercenaries:ClearBedTest()
    local ok, err = pcall(function()
        for _, entId in ipairs(self.BedTestEntities) do
            pcall(function() System.RemoveEntity(entId) end)
        end
    end)
    if not ok then
        System.LogAlways('[Mercenaries] ClearBedTest error: ' .. tostring(err))
    end
    self.BedTestEntities = {}
end

-- =======================================================================
-- CLUTTER COMPARISON ROW - debug helper. Spawns every candidate in
-- CampClutterCandidates in a row in front of the player - either via
-- Game.SpawnPrefab (candidate.prefabId) or a plain static model
-- (candidate.model) - logs what was spawned and how, same pattern as
-- SpawnCampFireTestRow.
-- Console: merc_camp_clutter_test / merc_camp_clutter_test_clear
-- =======================================================================
mercenaries.ClutterRowTestEntities = {}

function mercenaries:SpawnClutterTestRow()
    if not player then return end

    local ok, err = pcall(function()
        self:ClearClutterTestRow()

        local origin = player:GetWorldPos()
        local dir = player:GetDirectionVector()
        local right = { x = -dir.y, y = dir.x, z = 0 }
        local spacing = 3.0
        local forward = 4.0

        System.LogAlways('[Mercenaries] Spawning clutter comparison row (' .. tostring(#self.CampClutterCandidates) .. ' props):')
        for i, candidate in ipairs(self.CampClutterCandidates) do
            local pos = {
                x = origin.x + dir.x * forward + right.x * spacing * (i - 1),
                y = origin.y + dir.y * forward + right.y * spacing * (i - 1),
                z = origin.z,
            }
            pos = self:CampSnapToGround(pos)

            if candidate.prefabId then
                local anchorEnt = System.SpawnEntity({
                    class = "BasicEntity",
                    name = "MercClutterRowTest_Anchor_" .. tostring(i),
                    position = pos,
                    properties = { object_Model = "", bMissionCritical = false }
                })
                if anchorEnt then
                    table.insert(self.ClutterRowTestEntities, anchorEnt.id)
                    Game.SpawnPrefab(anchorEnt.id, candidate.prefabId, 0)
                end
                System.LogAlways('[Mercenaries]   #' .. tostring(i) .. ': ' .. candidate.name .. ' -> prefab ' .. candidate.prefabId)
            else
                local ent = System.SpawnEntity({
                    class = "BasicEntity",
                    name = "MercClutterRowTest_" .. tostring(i),
                    position = pos,
                    properties = {
                        object_Model = candidate.model,
                        bMissionCritical = false,
                    }
                })
                if ent then
                    pcall(function() ent:SetViewDistUnlimited() end)
                    pcall(function() ent:RenderShadow(true) end)
                    table.insert(self.ClutterRowTestEntities, ent.id)
                end

                System.LogAlways('[Mercenaries]   #' .. tostring(i) .. ': ' .. candidate.name .. ' -> ' .. candidate.model)
            end
        end
    end)

    if not ok then
        System.LogAlways('[Mercenaries] SpawnClutterTestRow error: ' .. tostring(err))
    end
end

function mercenaries:ClearClutterTestRow()
    local ok, err = pcall(function()
        for _, entId in ipairs(self.ClutterRowTestEntities) do
            pcall(function() System.RemoveEntity(entId) end)
        end
    end)
    if not ok then
        System.LogAlways('[Mercenaries] ClearClutterTestRow error: ' .. tostring(err))
    end
    self.ClutterRowTestEntities = {}
end

System.AddCCommand("merc_camp_make", "mercenaries:SpawnMercCamp()", "Spawn a procedural camp and idle the squad in it")
System.AddCCommand("merc_camp_break", "mercenaries:BreakMercCamp()", "Break camp and resume normal squad behaviour")
System.AddCCommand("merc_camp_recall", "mercenaries:RecallMercs()", "Recall the whole squad to your position (does not break camp)")
System.AddCCommand("merc_camp_tent_test", "mercenaries:SpawnTentTestRow()", "Spawn every candidate tent model in a row in front of you, for comparison")
System.AddCCommand("merc_camp_tent_test_clear", "mercenaries:ClearTentTestRow()", "Remove the tent comparison row")
System.AddCCommand("merc_camp_bed_row_test", "mercenaries:SpawnBedRowTest()", "Spawn every candidate bed model in a row in front of you, for comparison")
System.AddCCommand("merc_camp_bed_row_test_clear", "mercenaries:ClearBedRowTest()", "Remove the bed comparison row")
System.AddCCommand("merc_camp_bed_test", "mercenaries:SpawnBedTest(%1, %2, %3, %4)", "Spawn a test tent + bed at relative offset to try bed placements. Usage: merc_camp_bed_test <right> <forward> <z> <rotationDeg>")
System.AddCCommand("merc_camp_bed_test_clear", "mercenaries:ClearBedTest()", "Remove the tent/bed placement test")
System.AddCCommand("merc_camp_fire_test", "mercenaries:SpawnCampFireTestRow()", "Spawn every candidate campfire wood model (each with the fire particle effect on top) in a row in front of you, for comparison")
System.AddCCommand("merc_camp_fire_test_clear", "mercenaries:ClearCampFireTestRow()", "Remove the campfire comparison row")
System.AddCCommand("merc_camp_clutter_test", "mercenaries:SpawnClutterTestRow()", "Spawn every candidate clutter prop (sacks, crates, weapon piles, charcoal) in a row in front of you, for comparison")
System.AddCCommand("merc_camp_clutter_test_clear", "mercenaries:ClearClutterTestRow()", "Remove the clutter comparison row")
