-- Procedural mercenary camp: spawns tents/fire/chairs/beds near the player,
-- moves the squad in, and idles them (guards patrol, the rest sit/sleep). Camp
-- props are plain BasicEntity + object_Model spawns, so they don't survive a save
-- - the camp is made persistent by saving only where it was pitched
-- (CampBuildOrigin) and rebuilding it there on load (RestoreCampDelayed), with
-- ClearAnyLeftoverCamp sweeping any leftovers by name first.
-- See docs/camp.md for the full design and postmortems.

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

-- WHERE THE DOORWAY IS, MEASURED - not the eyeballed rotation this replaced (a
-- stack of "+45, then +30 more" feedback that had settled on +130 and put the
-- entrance round the back). Read straight out of the mesh, two independent ways
-- that agree: the baked collision hull is eleven wall boxes round a twelve-slot
-- circle and the missing slot spans +75..+97 deg; the visible canvas has exactly
-- one empty arc in the whole 360, +75..+95 deg, flanked by the densest vertex
-- bins in the file (the door frame). So the opening faces +85 deg in MESH space.
--
-- A prop is spawned as a plain yaw, so mesh +X lies along the spawn angle: the
-- door then points along yaw + 85. Wanting it to open onto the reserved empty
-- tile - which is at the camp's own forward - makes the spawn yaw
-- forward - 85, which is CampPlayerTentYaw below. Re-measure with
-- tools/cgf_proxies.py if the model is ever swapped.
mercenaries.CampPlayerTentDoorDeg = 85
mercenaries.CampPlayerBedOffset = { right = 0, forward = 1, z = 0, rotationDeg = 180 }
-- BedTrigger placement relative to the bed's centre/facing and its
-- interaction-volume scale. Tunable if the "E - Sleep" prompt is awkward.
mercenaries.CampPlayerBedTriggerOffset = { right = 0, forward = 0, z = 0.4 }
mercenaries.CampPlayerBedTriggerScale = { 0.7, 0.7, 0.7 }

-- The camp bed is the player's own, so it sleeps AND saves. Bed ownership (what
-- the engine's own sleep-and-save keys off) can only be granted by a quest, never
-- from Lua, so the save is made here instead - see CampBedSleepWatch and
-- docs/camp.md "The player tent".
mercenaries.CampBedSleepRadius     = 3.5   -- metres from the bed to count as sleeping in it
mercenaries.CampBedSleepMinSeconds = 600   -- in-game seconds that must pass to count as a sleep

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
-- The yaw the player tent is spawned at, so its measured doorway
-- (CampPlayerTentDoorDeg) opens along `facingAngle` - the camp's own forward,
-- which is the tile the grid deliberately leaves empty. Everything that wants
-- "where the entrance is" should use `facingAngle` itself, not this: the whole
-- point of deriving the yaw is that the entrance no longer needs its own
-- correction term (the quartermaster and the camp amenities both used to carry
-- a copy of the old +130).
function mercenaries:CampPlayerTentYaw(facingAngle)
    return (facingAngle or 0) - math.rad(self.CampPlayerTentDoorDeg or 0)
end

function mercenaries:SpawnPlayerCampTent(centerPos, facingAngle)
    -- Player House upgrade: a real hut (with its own bed) stands here instead of
    -- the tent. See mercenaries_house.lua.
    local house = false
    pcall(function() house = self.LogiState and self:LogiState().hasHouse end)
    if house then
        self:SpawnCampHouse(centerPos, facingAngle)
        return
    end

    local ok, err = pcall(function()
        local tentPos = self:CampSnapToGround(centerPos)
        local tentAngle = self:CampPlayerTentYaw(facingAngle)

        self:SpawnCampPropModel(self.CampPlayerTentModel, tentPos, tentAngle, "MercCampProp_PlayerTent")
        if self.NavAddObstacle then
            self:NavAddObstacle(tentPos, tentAngle,
                self:CampPropFootHalf(self.CampPlayerTentModel, 0), "tent")
        end

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
                bSaved_by_game = false,
                bSerialize = false,
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
                bSaved_by_game = false,
                bSerialize = false,
                Click = {
                    bIsActive = true,
                    bedEntity = bedEnt,
                    UseMessage = "@ui_hud_sleep_and_save",
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

            -- Remember the bed so CampBedSleepWatch can spot the player sleeping
            -- in it. engineSaves is normally false (a spawned bed has no owner),
            -- and is only checked so we never double up on an engine autosave.
            local engineSaves = false
            pcall(function() engineSaves = EntityModule.WillSleepingOnThisBedSave(bedEnt.id) and true or false end)
            self.CampPlayerBed = { id = bedEnt.id, pos = bedPos, engineSaves = engineSaves }
            self.CampBedSleepState = nil

            -- The player's own chest, beside the bed. Here rather than in the two
            -- callers because this is the point where "that bed is the player's"
            -- is decided - tent and house both come through it.
            if self.SpawnCampChest then self:SpawnCampChest(bedPos, bedAngle) end
        end
    end)
    if not ok then
        System.LogAlways('[Mercenaries] SpawnCampBedTrigger error: ' .. tostring(err))
    end
end

-- Creates the "slept in your own bed" save. Game.SaveGameViaResting is the
-- engine's own resting autosave; QuickSave is the fallback if it ever goes away.
function mercenaries:CampBedSave()
    local bed = self.CampPlayerBed
    if bed and bed.engineSaves then return end   -- the engine already saves on this bed

    local ok = pcall(function() Game.SaveGameViaResting() end)
    if not ok then
        ok = pcall(function() Game.QuickSave() end)
    end
    System.LogAlways("[Camp] sleep-and-save: " .. (ok and "save created" or "FAILED - no save binding"))
end

function mercenaries.CampBedSaveDelayed()
    mercenaries:CampBedSave()
end

-- Watches the player lying in the camp bed and saves once they get up, provided
-- game time actually moved (so lying down and standing straight back up doesn't
-- save). Called each second from MonitorLoop.
function mercenaries:CampBedSleepWatch()
    local bed = self.CampPlayerBed
    if not bed or not player then return end

    local w = self.CampBedSleepState
    if not w then w = { laying = false, armed = false }; self.CampBedSleepState = w end

    local laying = false
    pcall(function() laying = player.player:IsLaying() and true or false end)

    if laying and not w.laying then
        -- Just lay down: arm only if it's our bed they're on.
        local p = player:GetWorldPos()
        local dx, dy, dz = p.x - bed.pos.x, p.y - bed.pos.y, p.z - bed.pos.z
        w.armed = (dx * dx + dy * dy + dz * dz) <= (self.CampBedSleepRadius * self.CampBedSleepRadius)
        w.startTime = self:LogiNow()
    elseif w.laying and not laying then
        if w.armed and (self:LogiNow() - (w.startTime or 0)) >= self.CampBedSleepMinSeconds then
            -- Let the wake-up animation finish before the game freezes to save.
            Script.SetTimerForFunction(2000, "mercenaries.CampBedSaveDelayed")
        end
        w.armed = false
    end
    w.laying = laying
end

-- Property sets for the StanceSmartObject entities that let a merc actually
-- sit/lie down (see SpawnCampFurnitureSO below, the sit/sleep assignment in
-- SpawnMercCamp, and the incamp-sitter/sleeper cases in camp_actor.xml).
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
-- two prefabs. The `stance` field is what camp_actor.xml's StanceElement
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
-- Degrees added to the seat's "face the fire" angle. A merc sits facing OPPOSITE
-- the SO's spawn direction vector, so 180 cancels it (see SpawnCampFurnitureSO;
-- value settled in play on the tavern seats). The log seats still use the
-- omnidirectional Bench_Low helper, so facing may resolve to either side - but the
-- correct side is now one of the two, where before it was arbitrary.
mercenaries.CampSitFacingFixDeg = 180

-- Degrees added to a BED smart object's facing, and to it alone, so the sleeper lies
-- along the bed rather than across it - see SpawnCampFurnitureSO for why the mesh and
-- the smart object need different numbers. 90 undoes the quarter turn the direction
-- vector introduces; +/-90 both lay him along the frame and differ only in which end
-- his head is at, so merc_camp_bed_yaw re-pitches the camp with a new value to check.
mercenaries.CampBedSOYawFixDeg = 90

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
-- When a tavern (inn upgrade) is up, non-trainer mercs use this sit-heavy cycle
-- instead: no herb-picking, mostly sitting - and sit/snooze prefer the tavern
-- seats (see ClaimSpot), so the camp gravitates to the tables rather than moping
-- around the fire.
mercenaries.CampTavernCycle = { "sit", "eat", "sit", "snooze", "sit" }
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
-- 2.0, from 1.7: the cooking tripod's legs reach 0.97 m from the fire and a seat's inner
-- edge sat at 1.34 - a judged survey found a stool between the tripod's legs. Sigismund's
-- men sit about two metres from theirs.
mercenaries.CampFireSeatRadius = 2.0

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
-- A raid ends for the whole squad within the same tick or two, so every survivor's
-- MercTargetOf clears at once - without a cooldown here they'd all become chat-eligible
-- on that same tick and pair up in a simultaneous wall of conversations. Randomized per
-- merc so the squad settles back into idle chatter staggered, the way CampChatStaggered
-- spreads out the very first conversations on camp start.
mercenaries.CampChatPostCombatCooldownMin = 30   -- 5s ticks: ~2.5 min minimum before a merc chats again after a fight
mercenaries.CampChatPostCombatCooldownMax = 90   -- 5s ticks: ~7.5 min maximum
mercenaries.MercCampCombatFlag = {}      -- wuidStr -> true while a merc has a live combat target (falling edge triggers the cooldown above)
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

-- The radius the tent ring actually needs, never smaller than CampTentRingRadius.
--
-- WHICH WAY ROUND A TENT SITS ON THE RING is the thing to get right here, and it is not what
-- it looks like. A tent is placed at `tentFaceAngle + pi + CampTentFacingFix`, and
-- CampRingPos's second return is the RADIAL direction, so the tent's forward ends up at
-- radial + 3pi/2 - a quarter turn off. Forward is TANGENTIAL. Since forward is the mesh's X
-- (see CampPropFootHalf), the mesh's LONG axis lies along the ring and its short axis points
-- at the fire. Sizing the ring by the short axis, as the first version of this did, lets the
-- widest variant lap its neighbour by over a metre.
--
-- Two constraints, both off the CLAIM box so the ring and the overlap test can never
-- disagree:
--   tangential  each of `slots` tents needs 2 * claim.h of arc
--   radial      the tent's inner edge has to clear the fire's seating ring, which is spawned
--               at CampFireSeatRadius and is as wide as the weapon pile that dresses it
function mercenaries:CampTentRingRadiusFor(models, slots)
    local tang, rad = 0, 0
    for _, model in ipairs(models or {}) do
        local c = self:CampPropClaimHalf(model)
        if c.h > tang then tang = c.h end
        if c.w > rad then rad = c.w end
    end
    if tang == 0 then
        tang = self.CampPropFootDefault.h + self.CampPropClaimPad
        rad  = self.CampPropFootDefault.w + self.CampPropClaimPad
    end
    slots = math.max(1, slots or self.CampClusterTentRingSlots)

    local byArc = (slots * 2 * tang) / (2 * math.pi)
    local seatOuter = self.CampFireSeatRadius
        + self:CampPropClaimHalf(self.CampModels.WeaponStack).w
    local bySeats = seatOuter + rad

    return math.max(self.CampTentRingRadius, byArc, bySeats), byArc, bySeats
end

-- The radius THIS camp's tent rings were built at. Settled once per pitch, because
-- everything that has to stay clear of the tents - the activity spots, the night lamps, the
-- guards' patrol ring - is measured outward from it and would otherwise sit among them.
mercenaries.CampTentRingR = nil

function mercenaries:CampTentRing()
    return self.CampTentRingR or self.CampTentRingRadius
end
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
-- ...and at least this much open ground between two tent rings, whatever the meshes force
-- the ring radius to. See the spacing bump in SpawnMercCamp.
mercenaries.CampClusterGap = 1.5
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
-- How level the ground under one anchor has to actually BE. CampMaxStep above is a
-- cliff test; this is the flatness test. Tunable live with merc_camp_spread, because it
-- trades picture quality against how often a camp can be pitched at all.
mercenaries.CampMaxSpread = 0.55
mercenaries.CampMaxRise = 2.0                          -- higher than this above player level = roof/ledge/tree top
mercenaries.CampMaxDrop = 4.0                          -- lower than this below = pit / floor under a building
mercenaries.CampMaxProbeCells = 60                     -- cells SpawnMercCamp probes before giving up (bounds raycast cost)

-- Fine heightmap classifier (CampSampleHeightmap / CampClassifyHeightmap): a dense
-- 0.5m grid sorted into valid/obstacle/building/void by connectivity, so slopes
-- stay valid and only sharp steps cut off. See docs/camp.md.
mercenaries.CampSampleStep = 0.5      -- sample resolution (m)
-- The terrain sub-grid the surface test runs on, coarser because terrain layers are large
-- patches. One ray per cell of THIS grid, not of the 0.5m one - see CampSampleHeightmap.
mercenaries.CampTerrainSampleStep = 2.0
mercenaries.CampConnectStep = 0.5     -- height delta between adjacent samples that counts as an edge, not the same surface
mercenaries.CampSmallClumpMax = 5     -- obstacle clumps this size or smaller = tree/rock (tolerable); bigger = building

-- Tile layout tuning (CampBuildMap / the tile loop in SpawnMercCamp): the camp is
-- chosen on a coarse grid of square tiles judged from the fine classification
-- above. See docs/camp.md for the full scheme.
mercenaries.CampTileHalf = 5.25                        -- half-size (m) of one layout tile (a campfire unit's footprint)
mercenaries.CampTileMaxInvalidFrac = 0.5               -- a camping tile may be at most this fraction invalid
mercenaries.CampTileClearFrac = 0.8                    -- player-tent/training tiles need this fraction valid and no building clump
-- The campfire's footprint. It is a PREFAB, not a single mesh, so there is nothing in the
-- paks to measure it from and it stays a hand-set box - unlike the tents below, which are
-- measured (CampPropFootHalf).
mercenaries.CampFireFootHalf = { w = 1.25, h = 1.25 }

-- Footprints for ROUTING (mercenaries_navmesh.lua), not for placement. A routing box is the
-- mesh's own extent and nothing more: padding one steers men round a wider obstacle than is
-- there, and round a fire circle that walls the men out of their own camp. Tents pass
-- CampPropFootHalf(model, 0) for the same reason; the fire has no mesh to measure.
mercenaries.NavFireFootHalf = { w = 1.00, h = 1.00 }
mercenaries.CampFootprintSlack  = 2
-- ...or this share of the box, whichever is larger. The slack used to be a flat cell count
-- against a flat box; now that a footprint is the mesh's own size, a big tent covers twice
-- the cells of a small one and two bad cells out of a hundred would be a far harsher test
-- than two out of fifty. 0.04 is what the old pair of numbers works out to on the box they
-- were tuned against, so a small tent behaves exactly as it did.
mercenaries.CampFootprintSlackFrac = 0.04

-- How many invalid cells a footprint of `total` cells may have.
function mercenaries:CampFootprintAllowance(total)
    return math.max(self.CampFootprintSlack,
                    math.floor((total or 0) * self.CampFootprintSlackFrac))
end

-- MEASURED FOOTPRINTS. The fallback boxes above are one size for every model, on the stated
-- grounds that the tent variants "share the same footprint". Measured out of the paks
-- (tools/measure_camp_props.py, table in mercenaries_camp_footprints.lua) they do not: the
-- five span 1.46 to 2.33 half-length, so tent_small_rustic_a is 60% longer than the box that
-- approved its spot. Three of them are not centred on their own origin either -
-- tent_small_forest_d sits 0.69m off along Y.
--
-- Getting a mesh measurement into the placement frame needs no convention-guessing, because
-- the spawn is a plain YAW: SpawnCampPropModel sets angles {0, 0, angleZ}, so the mesh's own
-- +X axis ends up along (cos angleZ, sin angleZ) - which is exactly the `forward` that
-- CampFootprintStats and CampRelativeOffset project along. So:
--
--     forward (depth)  = the mesh's X        right (width) = the mesh's Y
--
-- and the mesh's centre offset (ox, oy) is a `forward`/`right` offset of the same numbers.
-- That falls out of the rotation rather than being tuned, and it agrees with the hand-tuned
-- routing box this replaced: 1.05 x 1.45 against a mesh measuring y 1.19, x 1.46.
--
-- The offset is applied, not absorbed into a bigger box. An earlier version grew the box to
-- reach an off-centre mesh (half = |offset| + extent) to avoid needing the sign; that is
-- safe for a ground test and wrong for everything else, because it inflates the box in the
-- direction the mesh ISN'T, and a tent inflated 0.69m toward its own campfire collides with
-- it.
mercenaries.CampPropFootSlack = 0.35   -- clear ground wanted beyond the mesh itself
mercenaries.CampPropFootDefault = { w = 1.0, h = 1.5 }   -- a model with no measurement

-- The footprint of one model: { w, h, right, forward } in the prop's own frame, where
-- right/forward locate the box CENTRE relative to the spawn position. `slack` defaults to
-- CampPropFootSlack; pass 0 for the mesh's own extent, which is what a nav obstacle wants -
-- a padded obstacle round a tent closes the gaps the men walk through between them.
function mercenaries:CampPropFootHalf(model, slack)
    local m = model and self.CampPropFoot and self.CampPropFoot[model]
    if not m then
        local d = self.CampPropFootDefault
        return { w = d.w, h = d.h, right = 0, forward = 0 }
    end
    slack = slack or self.CampPropFootSlack
    return { w = m.y + slack, h = m.x + slack, right = m.oy, forward = m.ox }
end

-- Where a footprint's box actually sits, given where its prop is being put.
function mercenaries:CampFootCentre(pos, angle, half)
    if not (pos and half) then return pos end
    if (half.right or 0) == 0 and (half.forward or 0) == 0 then return pos end
    return (self:CampRelativeOffset(pos, angle or 0,
        { right = half.right or 0, forward = half.forward or 0 }))
end

-- The mesh's own extent in the placement frame, WITHOUT the off-centre growth. This is the
-- one to space neighbours by: two tents on the same ring share a local frame, so a mesh that
-- sits to one side of its origin shifts them both equally and never brings them closer.
function mercenaries:CampPropSpanHalf(model)
    local m = model and self.CampPropFoot and self.CampPropFoot[model]
    if not m then
        local d = self.CampPropFootDefault
        return { w = d.w, h = d.h, right = 0, forward = 0 }
    end
    return { w = m.y, h = m.x, right = 0, forward = 0 }
end

-- What a prop OCCUPIES, as against what it would like clear: the mesh plus a gap to walk
-- through, and nothing else. This is what neighbours are tested against - padding a claim
-- with the ground slack as well would have two tents 0.6m apart declared overlapping, which
-- they visibly are not.
mercenaries.CampPropClaimPad = 0.25

function mercenaries:CampPropClaimHalf(model)
    local f = self:CampPropSpanHalf(model)
    local m = model and self.CampPropFoot and self.CampPropFoot[model]
    return { w = f.w + self.CampPropClaimPad, h = f.h + self.CampPropClaimPad,
             right = m and m.oy or 0, forward = m and m.ox or 0 }
end

mercenaries.CampMercFootprint   = 0.6                  -- footprint FindValidGround checks per single spawn/teleport spot
mercenaries.CampNudgeStep = 0.5                        -- prop nudge step/limit to dodge an obstacle before placing least-bad
-- Five rings, 2.5 m. At three (1.5 m) a ring tent whose slot fell across the smokehouse had
-- nowhere clean to go, and CampNudgeToValid keeps the base spot when nothing clean is found -
-- so it was built INTO the smokehouse. A judged survey: "branch shelter wrapped around the
-- smokehouse's left half", in seven frames.
mercenaries.CampNudgeMax  = 5
mercenaries.CampMapMaxRadius = 22.0                    -- caps the one-time raycast burst; tiles beyond fall back to CampValidateSpot
-- The camp centre is searched over this square (half-width, m) at this step. It was 2.0 /
-- 1.0 while only the player tent's footprint was scored; the search now scores the tent
-- rings' cells too, and a ring needs more than two metres of shift to clear a stream bank
-- or a stand of elder. See the search in SpawnMercCamp.
mercenaries.CampCenterSearch     = 6.0
mercenaries.CampCenterSearchStep = 1.5
-- A column whose high ray hits this far above the player's feet counts as under a
-- roof; such columns are marked unbuildable so the camp forms on open ground.
mercenaries.CampRoofDetectHeight = 3.0

-- Bed placement relative to its own tent: right/forward in tent-local space, z a
-- world vertical offset, rotationDeg relative to the tent's facing.
-- right/forward are added to the TENT'S FOOTPRINT CENTRE, not to its origin - see
-- SpawnMercCamp, which now offsets by CampPropFootHalf before applying this. Three of the
-- five tent meshes are not centred on their own origin (tent_small_forest_d by 0.69 m along
-- Y), so a bed placed at the origin sits off-centre inside the tent and pokes out through
-- the canvas. Measured 2026-09-19 from an in-game capture; see docs/camp-inspection.md.
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
-- A marching column: [followerWuidStr] = WUID of the man he walks behind. Bandit-only and
-- deliberately NOT one of the shared camp tables - those get replaced wholesale whenever the
-- player's own camp is broken or rebuilt, which is exactly how the bandit patrol records were
-- trampled before (see BanditCampRepairRoles).
mercenaries.BanditCampColumn = {}

function mercenaries:IsColumnFollower(wuid)
    return self.BanditCampColumn ~= nil and self.BanditCampColumn[tostring(wuid)] ~= nil
end

function mercenaries:GetColumnFollowTarget(wuid)
    return self.BanditCampColumn and self.BanditCampColumn[tostring(wuid)]
end

mercenaries.CampPatrollers = {}  -- [mercWuidStr] = { waypoints={ {x,y,z}, ... }, index= } - perimeter positions, see SpawnMercCamp's guard-assignment loop
mercenaries.CampFurniture  = {}  -- [mercWuidStr] = { wuid=furnitureSOWuid, kind="bed"/"chair" } - a non-guard merc's assigned sit/sleep smart object, see SpawnMercCamp + GetCampFurniture
mercenaries.CampCommunalChairs = {} -- unused - kept declared for back-compat

-- Ground-snap a position. The old version took the first surface a ray met 5m above the
-- point, which over a house is the roof and over a cart is the cart - that is how props and
-- men ended up standing on things. It asks mercenaries_ground.lua instead, which looks at
-- the whole column and picks the surface that is actually the world's ground.
--
-- Returns pos, clear, kind. `clear` is false when the ground here has something standing on
-- it (the snap still lands at ground level, not on the object's roof) - callers that can
-- move the thing somewhere else should; the rest are no worse off than before.
-- `verify` pays a few extra rays to also run the edge test, which is what catches a log or a
-- crate. Worth it wherever something solid is being put down; not for the thousands of snaps
-- a camp pitch does while working out its layout.
function mercenaries:CampSnapToGround(pos, verify)
    if not pos then return pos end
    local ok, p, clear, kind = pcall(self.GroundSnap, self, pos, verify)
    if ok and p then return p, clear, kind end
    return pos, false, nil
end

-- Validate whether a tent/cluster can sit on the ground at `pos`, by firing a
-- cluster of downward probe rays over a CampClusterFootprint square: the centre
-- probe rejects steep normals, anything that isn't the world's own ground, and
-- ground that sits too far above/below the player's level (a roof/ledge/pit); eight
-- edge probes reject steps and tree trunks. Leaf canopies pass through (camping
-- under one is fine). Returns valid, groundZ, reason. See docs/camp.md "Ground
-- validation" and docs/ground-guard.md.
-- `skipEdge` leaves out the one test that costs rays of its own. FindValidGround passes it
-- because it calls this up to 40 times to spiral for a spot and then runs the edge test once,
-- on the winner - 4 rays per search instead of 4 per candidate. Nothing else should.
function mercenaries:CampValidateSpot(pos, refZ, footprint, skipEdge)
    footprint = footprint or self.CampClusterFootprint
    refZ = refZ or pos.z

    -- Returns the topmost surface at a column: its height, its normal, and the raw hit, so
    -- the caller can ask mercenaries_ground.lua about it without firing a second ray.
    local function probe(px, py)
        local hitTable = {}
        local start = { x = px, y = py, z = refZ + self.CampProbeStartHeight }
        local dir   = { x = 0, y = 0, z = -(self.CampProbeStartHeight + self.CampProbeDepth) }
        local ok, hz, hn, hit = pcall(function()
            -- GroundMask, not ent_terrain + ent_static: that mask cannot see a rigid body, so
            -- a cart, a log or a woodpile was invisible to every check below it.
            local hits = Physics.RayWorldIntersection(start, dir, 2,
                self.GroundMask and self:GroundMask() or (ent_terrain + ent_static),
                nil, nil, hitTable)
            if hits > 0 and hitTable[1] and hitTable[1].pos then
                return hitTable[1].pos.z, hitTable[1].normal, hitTable[1]
            end
            return nil, nil, nil
        end)
        if ok then return hz, hn, hit end
        return nil, nil, nil
    end

    local cz, cnormal, chit = probe(pos.x, pos.y)
    if not cz then return false, pos.z, "no_ground" end          -- over a hole/void

    -- Is this surface the ground, or the top of something standing on it? The only check
    -- here that does not care where the caller THINKS the floor is: refZ is whatever the
    -- caller had in hand, and when the caller is a man already stranded on a roof, every
    -- relative test below agrees the roof is fine.
    --
    -- The free half first: the heightmap comparison costs no ray, and catches the things
    -- with tops too big to find the edge of - a roof, a bridge, a wall walk.
    if self.GroundTerrainAt then
        local tz, tSurf = self:GroundTerrainAt(pos.x, pos.y, refZ)
        local isObj, why = self:GroundSurfaceLooksLikeObject(cz, chit and chit.surface, tz, tSurf)
        if isObj then
            self:GroundNote(string.format('rejected (%.1f, %.1f) z=%.2f - %s',
                pos.x, pos.y, cz, tostring(why)))
            return false, cz, "on_object"
        end
    end

    if cnormal and cnormal.z and cnormal.z < self.CampMaxSlopeCos then
        return false, cz, "too_steep"                            -- hillside
    end

    -- What the ground is MADE of, not just how steep it is. Brambles, forest floor, bog and
    -- streambed are all perfectly flat and perfectly wrong to stand a tent on; a camp judged
    -- on two rounds of screenshots lost most of its remaining marks to exactly this. See
    -- CampBadSurfaces in mercenaries_campfit.lua for the measurements behind the list.
    if self.CampSurfaceOK then
        local sOK, sName = self:CampSurfaceOK(pos.x, pos.y, refZ)
        if not sOK then
            self:GroundNote(string.format('rejected (%.1f, %.1f) - ground is %s',
                pos.x, pos.y, tostring(sName)))
            return false, cz, "bad_surface"
        end
    end
    -- ...and what GROWS on it, which no ray here can see. The baked vegetation
    -- (mercenaries_campveg.lua) is the only witness to a bush.
    if self.VegSpotBlocked then
        local plant = self:VegSpotBlocked(pos.x, pos.y, footprint)
        if plant then
            self:GroundNote(string.format('rejected (%.1f, %.1f) - %s',
                pos.x, pos.y, self:VegDescribe(plant)))
            return false, cz, "vegetation"
        end
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

    -- ONE LEVEL, not merely "no cliff". CampMaxStep is 1.2 m across a 6 m cell, which is a
    -- test for a cliff and lets a prop straddle a half-metre terrace lip quite happily. That
    -- is what the fourth judged survey kept finding: a smokehouse tipped against the barn's
    -- raised earth pad, a drying rack with its lower shelves overhanging a terrace, a
    -- grindstone canted on a bank, a barrel pitched over the stream-bank break. Every one of
    -- them was on ground that was flat enough by the old rule and plainly a step to the eye.
    --
    -- "the prop is sitting on or across a discontinuity in the ground rather than on a flat
    -- patch ... Sampling height across the footprint and refusing the anchor when the spread
    -- exceeds a threshold would clear five of the six defects in one change."
    -- ...and nothing BUILT on it. The heightmap under a barn is as flat as a meadow.
    if self.CampSpotStructureFree and not skipEdge then
        local free, by = self:CampSpotStructureFree(pos.x, pos.y, refZ + 8, footprint)
        if not free then
            self:GroundNote(string.format('rejected (%.1f, %.1f) - a structure stands %.2f m proud here',
                pos.x, pos.y, by or 0))
            return false, cz, "structure"
        end
    end

    if self.CampMaxSpread and (maxZ - minZ) > self.CampMaxSpread then
        self:GroundNote(string.format('rejected (%.1f, %.1f) - ground steps %.2f m across the footprint',
            pos.x, pos.y, maxZ - minZ))
        return false, cz, "stepped"
    end

    -- Last, because it is the only check that costs rays of its own and by here almost
    -- everything has already been rejected: is this surface the TOP of something? The ring
    -- above cannot answer that - its radius is the caller's footprint, 0.6m for one man and
    -- 3.0m for a tent cluster, and the question needs a known distance. Four probes at a
    -- fixed 1.25m, all of which must drop: on a slope one of them is always above you, so
    -- hillsides (where camping is fine) never trip it, while a log, a crate, a plank walkway
    -- or a low wall - everything too short for the step tests above to notice - does.
    if self.GroundEdgeCheck and not skipEdge then
        local isTop, drops, samples = self:GroundEdgeCheck(pos.x, pos.y, cz,
                                                           self.GroundEdgeFast, self.GroundEdgeFast)
        if isTop then
            self:GroundNote(string.format(
                'rejected (%.1f, %.1f) z=%.2f - stands above its surroundings on %d of %d sides',
                pos.x, pos.y, cz, drops, samples))
            return false, cz, "on_object"
        end
    end

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

    -- One downward ray from absolute height `fromZ`; returns hit z and the surface type it
    -- landed on, or nil.
    local function probe(wx, wy, fromZ)
        local hitTable = {}
        local ok, hz, surf = pcall(function()
            local hits = Physics.RayWorldIntersection({ x = wx, y = wy, z = fromZ },
                { x = 0, y = 0, z = -(fromZ - bottomZ) }, 2,
                self.GroundMask and self:GroundMask() or (ent_terrain + ent_static),
                nil, nil, hitTable)
            if hits > 0 and hitTable[1] and hitTable[1].pos then
                return hitTable[1].pos.z, hitTable[1].surface
            end
            return nil, nil
        end)
        if not ok then return nil, nil end
        return hz, surf
    end

    -- THE TERRAIN SUB-GRID.
    --
    -- Telling the ground from a thing lying on it means knowing what the ground at that spot
    -- is made of, which is a second ray (ent_terrain only - see mercenaries_ground.lua). One
    -- per cell would double a map that is already ~8000 rays, and a single burst that size is
    -- the shape of the camp-lag postmortem, so the terrain is sampled on its own COARSER
    -- grid: terrain layers are large patches and their material does not change every half
    -- metre. At 2m against the map's 0.5m that is a sixteenth of the rays - a few hundred.
    --
    -- A fine cell is compared against the FOUR terrain samples around it and counts as ground
    -- if it matches ANY of them. That is what makes the coarse grid safe: on a grass/dirt
    -- boundary the nearest single sample would often be the wrong layer and punch holes in
    -- the map, while "matches one of the materials hereabouts" does not care which side of
    -- the boundary the sample fell.
    local tstep = self.CampTerrainSampleStep
    local tr = math.max(1, math.ceil((radius * spacing) / tstep))
    local tsurf = {}
    -- Skipped entirely with the guard off, which costs nothing and leaves the map exactly as
    -- it was before any of this: no sub-grid, no cell ever marked as an object.
    local guarded = (self.GroundGuard and self.GroundTerrainAt) and true or false
    if guarded then
        for ti = 0, 2 * tr do
            tsurf[ti] = {}
            for tj = 0, 2 * tr do
                local _, sid = self:GroundTerrainAt(origin.x + (ti - tr) * tstep,
                                                    origin.y + (tj - tr) * tstep, refZ)
                tsurf[ti][tj] = sid
            end
        end
    end

    -- Does this cell's surface match the ground anywhere around it? nil terrain samples mean
    -- there is no heightmap here to compare against (a bridge, a cut-away interior), and then
    -- nothing is ruled out - the edge test in CampValidateSpot covers that case.
    local function surfaceIsGroundHere(wx, wy, sid)
        if not guarded or sid == nil then return true end
        local fi = (wx - origin.x) / tstep + tr
        local fj = (wy - origin.y) / tstep + tr
        local i0, j0 = math.floor(fi), math.floor(fj)
        local sawTerrain = false
        for di = 0, 1 do
            for dj = 0, 1 do
                local ti, tj = i0 + di, j0 + dj
                local t = tsurf[ti] and tsurf[ti][tj]
                if t ~= nil then
                    sawTerrain = true
                    if t == sid then return true end
                end
            end
        end
        return not sawTerrain
    end

    -- Which of those terrain samples are water, streambed or bog. The surface rule refused a
    -- tent whose ORIGIN stood in the stream and nothing else: a shelter with three legs on
    -- the bank and one in the creek passed it. Marked on the map instead, every cell within
    -- a sample of bad ground is unbuildable, and the two-metre sub-grid gives the water a
    -- metre of bank for free.
    local tbad = {}
    local wet = {}
    if guarded and self.CampBadSurfaces then
        for ti = 0, 2 * tr do
            tbad[ti] = {}
            for tj = 0, 2 * tr do
                local sid = tsurf[ti] and tsurf[ti][tj]
                if sid ~= nil then
                    local name
                    pcall(function() name = System.GetSurfaceTypeNameById(sid) end)
                    if name and self.CampBadSurfaces[name] then tbad[ti][tj] = true end
                end
            end
        end
    end
    local function nearBadGround(wx, wy)
        local fi = (wx - origin.x) / tstep + tr
        local fj = (wy - origin.y) / tstep + tr
        local i0, j0 = math.floor(fi), math.floor(fj)
        for di = 0, 1 do
            for dj = 0, 1 do
                local row = tbad[i0 + di]
                if row and row[j0 + dj] then return true end
            end
        end
        return false
    end

    local z = {}
    local roof = {}
    local obj = {}
    local nWet = 0
    for i = 0, 2 * radius do
        z[i] = {}
        roof[i] = {}
        obj[i] = {}
        wet[i] = {}
        for j = 0, 2 * radius do
            local wx = origin.x + (i - radius) * spacing
            local wy = origin.y + (j - radius) * spacing
            local hi, hsurf = probe(wx, wy, highStart)
            z[i][j] = hi
            if hi and nearBadGround(wx, wy) then
                wet[i][j] = true
                nWet = nWet + 1
            end
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
            -- Made of something the ground here is not: a mat, a plank, a woodpile, a cart, a
            -- roof. The classifier already refused anything TALL, because its flood cannot
            -- climb a big step - what it could not see is a thing lying FLAT on the ground,
            -- which joined the walkable surface and had tents pitched on it.
            if hi and not surfaceIsGroundHere(wx, wy, hsurf) then
                obj[i][j] = true
            end
        end
    end
    if nWet > 0 then
        System.LogAlways(string.format('[Mercenaries] camp map: %d cells on or beside water, bog or scrub', nWet))
    end
    return { r = radius, spacing = spacing, origin = origin, refZ = refZ,
             z = z, roof = roof, obj = obj, wet = wet }
end

-- Heightmap classifier: flood the walkable surface out from a seed cell (the
-- player's feet), stepping to a neighbour only when |dz| <= CampConnectStep, so
-- slopes stay connected but steps don't. Reached cells are "valid"; unreached
-- clumps are "small" (tree/rock) or "building" by size; no-ground is "void".
-- Returns cls[i][j] and a counts table. See docs/camp.md.
function mercenaries:CampClassifyHeightmap(hm, seedI, seedJ)
    local r, z, roofg, objg = hm.r, hm.z, hm.roof, hm.obj
    local step = self.CampConnectStep
    local cls = {}
    for i = 0, 2 * r do cls[i] = {} end

    local function inb(i, j) return i >= 0 and i <= 2 * r and j >= 0 and j <= 2 * r end
    local function isRoof(i, j) return roofg and roofg[i] and roofg[i][j] end
    -- A cell is buildable ground only if it has a hit AND isn't a roof column
    -- (under a roof = the engine would spawn the prop on the roof, so it's a
    -- hard no-build).
    local function hasZ(i, j) return z[i] and z[i][j] ~= nil and not isRoof(i, j) end
    -- ...and nothing stands on a cell made of something the ground here is not. Kept OUT of
    -- hasZ on purpose, so these cells still go through the clump sizing below: a straw mat
    -- comes out "small" (tolerable, props step round it) where a woodpile or a cart comes out
    -- "building". Folding it into hasZ would make every one of them a hard barrier.
    local function isObj(i, j) return objg and objg[i] and objg[i][j] end
    -- ...and nothing GROWS on it. The bake (mercenaries_campveg.lua) marks the cells a tree
    -- trunk, a bush or a stump stands on; no ray ever sees those, and this is the one place
    -- every tile, tent and prop reads from, so marking them here is what keeps the camp out
    -- of the scrub. A hard barrier, unlike isObj: a prop cannot step round a bush it is in.
    local vegg, wetg = hm.veg, hm.wet
    local function isVeg(i, j)
        return (vegg and vegg[i] and vegg[i][j]) or (wetg and wetg[i] and wetg[i][j])
    end
    local function walkable(i, j) return hasZ(i, j) and not isObj(i, j) and not isVeg(i, j) end
    local NB = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }

    -- Seed defaults to the centre; if that column is a void, a roof (the player
    -- is standing inside a building) or an object (he is standing on a cart),
    -- spiral out to the nearest buildable cell so the flood starts on real open
    -- ground - the camp then forms outside the walls rather than on the roof.
    seedI = seedI or r
    seedJ = seedJ or r
    if not walkable(seedI, seedJ) then
        local found = false
        for rad = 1, r do
            for di = -rad, rad do
                for dj = -rad, rad do
                    local i, j = seedI + di, seedJ + dj
                    if not found and inb(i, j) and walkable(i, j) then
                        seedI, seedJ, found = i, j, true
                    end
                end
            end
            if found then break end
        end
    end

    -- 1. Flood the walkable surface from the seed.
    local ground = {}
    if walkable(seedI, seedJ) then
        local stack = { { seedI, seedJ } }
        ground[seedI .. "," .. seedJ] = true
        while #stack > 0 do
            local c = table.remove(stack)
            local cz = z[c[1]][c[2]]
            for _, d in ipairs(NB) do
                local ni, nj = c[1] + d[1], c[2] + d[2]
                local nk = ni .. "," .. nj
                if inb(ni, nj) and not ground[nk] and walkable(ni, nj) and math.abs(z[ni][nj] - cz) <= step then
                    ground[nk] = true
                    table.insert(stack, { ni, nj })
                end
            end
        end
    end

    -- 2. Label every cell; size the leftover obstacle clumps.
    local seen = {}
    local counts = { valid = 0, small = 0, building = 0, void = 0, veg = 0 }
    for i = 0, 2 * r do
        for j = 0, 2 * r do
            local key = i .. "," .. j
            if isRoof(i, j) then
                -- under a roof: unbuildable (a prop would land on the roof)
                cls[i][j] = "building"; counts.building = counts.building + 1
            elseif isVeg(i, j) then
                -- a plant stands here, or it is water: unbuildable, whatever the height says
                cls[i][j] = "veg"; counts.veg = counts.veg + 1
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
            -- Static geometry only, deliberately NOT GroundMask: this asks whether there is
            -- SHELTER overhead, and a parked cart or a stack of crates is not a roof.
            2, ent_terrain + ent_static, nil, nil, hitTable)
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
    -- What grows on it, from the bake - the rays above cannot see a bush at all.
    if self.VegMarkMap then pcall(function() self:VegMarkMap(hm) end) end
    local cls, counts = self:CampClassifyHeightmap(hm, radius, radius)

    -- Safety net for the ground guard. The map is guarded now: a cell whose surface is not
    -- what the ground there is made of is unwalkable. Somewhere that rule does not hold - a
    -- region paved in meshes, a terrain layer the sub-grid never samples - it would leave the
    -- camp with nowhere to stand and no clue why. A map with not one buildable cell might be
    -- that, so ask again with the guard off: if the answer changes, the guard was the reason,
    -- and it is turned off and said so rather than quietly breaking camps.
    if counts and counts.valid == 0 and self.GroundGuard then
        local ok = pcall(function()
            self.GroundGuard = false
            local hm2 = self:CampSampleHeightmap(center, radius, self.CampSampleStep, underRoof)
            if self.VegMarkMap then pcall(function() self:VegMarkMap(hm2) end) end
            local cls2, counts2 = self:CampClassifyHeightmap(hm2, radius, radius)
            if counts2 and counts2.valid > 0 then
                hm, cls, counts = hm2, cls2, counts2
                System.LogAlways('[Mercenaries] the ground guard rules out every column here but ' ..
                    'the plain heightmap does not, so the guard is now OFF. Run merc_groundprobe on ' ..
                    'this spot and merc_groundguard 1 to put it back.')
            else
                self.GroundGuard = true    -- not the guard's doing; this site is genuinely unusable
            end
        end)
        if not ok then self.GroundGuard = true end
    end

    -- One line per camp pitch. A camp that comes out in an odd shape is almost always a map
    -- that saw the ground differently than the player did, and this is the cheapest way to
    -- know that without running merc_camp_scan after the fact.
    if counts then
        System.LogAlways(string.format(
            '[Mercenaries] camp map %.0fm: %d buildable, %d tree/rock, %d building, %d void, ' ..
            '%d under plants or water (ground guard %s)',
            radius * self.CampSampleStep, counts.valid, counts.small, counts.building,
            counts.void, counts.veg or 0, self.GroundGuard and 'on' or 'OFF'))
    end

    return { hm = hm, cls = cls, center = center, r = radius, spacing = self.CampSampleStep, counts = counts }
end

-- Fewer buildable cells than this on the settled map and the camp is not pitched: the hut
-- and one ring need about 250 m2 of ground, and a map with less has nothing to offer the
-- shortfall fallback but cliffs and trees.
mercenaries.CampMinBuildable = 800

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
    local vegN = 0
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
            elseif c == "veg" then
                vegN = vegN + 1
            end
            b = b + step
        end
        a = a + step
    end
    return valid, total, hasBuilding, vegN
end

-- Mean step between neighbouring samples under a footprint, as a fraction of the cell
-- spacing (0.1 = 6 deg, 0.25 = 14 deg, 0.5 = 27 deg). The classifier joins any slope a man
-- can walk, so "valid" says nothing about how steep the ground is - a tent ring passed the
-- tile test on a 25 degree stream bank, and every bed in it was buried half a metre at the
-- uphill edge. This is the number that test was missing.
function mercenaries:CampFootprintRough(map, wpos, angle, halfW, halfH)
    if not (map and map.hm and map.hm.z) then return 0 end
    local fwd = { x = math.cos(angle), y = math.sin(angle) }
    local rgt = { x = -fwd.y, y = fwd.x }
    local step, z, r = map.spacing, map.hm.z, map.r
    local sum, n = 0, 0
    local a = -halfW
    while a <= halfW + 1e-6 do
        local b = -halfH
        while b <= halfH + 1e-6 do
            local wx = wpos.x + rgt.x * a + fwd.x * b
            local wy = wpos.y + rgt.y * a + fwd.y * b
            local i = math.floor((wx - map.center.x) / step + 0.5) + r
            local j = math.floor((wy - map.center.y) / step + 0.5) + r
            local z0 = z[i] and z[i][j]
            if z0 then
                local zx = z[i + 1] and z[i + 1][j]
                local zy = z[i][j + 1]
                if zx then sum = sum + math.abs(zx - z0); n = n + 1 end
                if zy then sum = sum + math.abs(zy - z0); n = n + 1 end
            end
            b = b + step
        end
        a = a + step
    end
    if n == 0 then return 0 end
    return (sum / n) / step
end

-- The flattest spot for a footprint within a small search of `pos`: the candidate with the
-- least rise between neighbouring samples under it that is still valid ground and unclaimed.
-- Returns `pos` itself when nothing within reach is flatter by a useful margin.
function mercenaries:CampNudgeToFlattest(map, pos, angle, half)
    if not map then return pos end
    local best, bestR = pos, self:CampFootprintRough(map, pos, angle, half.w, half.h)
    for _, d in ipairs({ 0.5, 1.0, 1.5, 2.0 }) do
        for k = 0, 7 do
            local a = k * (math.pi / 4)
            local cand = { x = pos.x + math.cos(a) * d, y = pos.y + math.sin(a) * d, z = pos.z }
            local r = self:CampFootprintRough(map, cand, angle, half.w, half.h)
            if r < bestR - 0.02 and self:CampFootprintOk(map, cand, angle, half)
               and not self:CampFootClaimed(cand, angle, half) then
                best, bestR = cand, r
            end
        end
    end
    return best
end

-- How bad a grid cell is for a ring of tents: the share of its ground that is unbuildable
-- (bush, building, void) plus a slope term. 0 is a level meadow.
function mercenaries:CampTileBadness(map, raw, angle)
    local v, t = self:CampFootprintStats(map, raw, angle, self.CampTileHalf, self.CampTileHalf)
    local inv = (t > 0) and ((t - v) / t) or 1
    local rough = self:CampFootprintRough(map, raw, angle, self.CampTileHalf, self.CampTileHalf)
    -- ...and a ploughed field under it, as a soft preference for the meadow cell next door.
    local field = 0
    if self.VegFieldAt then
        local n = 0
        for _, o in ipairs({ { 0, 0 }, { 3, 3 }, { 3, -3 }, { -3, 3 }, { -3, -3 } }) do
            if self:VegFieldAt(raw.x + o[1], raw.y + o[2]) then n = n + 1 end
        end
        field = n / 5
    end
    -- A cell too steep for a ring outranks any field cell: the field is a look, the bank
    -- is beds buried to the rail. At 0.35 the field weighed as much as a 25 degree slope
    -- and a ring went back onto the stream bank.
    local steep = (rough > (self.CampTileMaxRough or 0.22)) and 1.0 or 0
    return inv + 2 * rough + 0.15 * field + steep, inv, rough
end
-- A tile steeper than this on average is refused even when its ground is all "valid".
mercenaries.CampTileMaxRough = 0.22

-- ==== what the camp has already claimed ====
--
-- The ground map answers "is there decent ground here" and nothing else. It does not know
-- what the camp itself has already put down, so two tents on the same ring could each be
-- nudged up to CampNudgeMax * CampNudgeStep (1.5m) TOWARD each other and both come out
-- "valid" - 3m of closing on a 0.4m gap. That is why tents still overlapped after the
-- footprints were measured: the footprints were right and nothing was comparing them.
--
-- Each claim is the oriented box a prop occupies. Cleared with the camp.
mercenaries.CampPlacedFoot = {}

function mercenaries:CampClearClaims()
    self.CampPlacedFoot = {}
end

function mercenaries:CampClaimFoot(pos, angle, half, what)
    if not (pos and half) then return end
    local c = self:CampFootCentre(pos, angle, half)
    table.insert(self.CampPlacedFoot, { x = c.x, y = c.y, a = angle or 0,
                                        w = half.w, h = half.h, what = what })
end

-- Do two oriented boxes overlap? Separating-axis test on the four box axes: they are clear
-- exactly when some axis has a gap between their projections.
local function obbOverlap(ax, ay, aa, aw, ah, bx, by, ba, bw, bh)
    local dx, dy = bx - ax, by - ay
    local axes = {
        { math.cos(aa), math.sin(aa) }, { -math.sin(aa), math.cos(aa) },
        { math.cos(ba), math.sin(ba) }, { -math.sin(ba), math.cos(ba) },
    }
    -- Box local axes: forward = (cos a, sin a) carries the DEPTH, right carries the WIDTH -
    -- the same convention CampFootprintStats projects with.
    local afx, afy = math.cos(aa), math.sin(aa)
    local arx, ary = -afy, afx
    local bfx, bfy = math.cos(ba), math.sin(ba)
    local brx, bry = -bfy, bfx
    for _, ax2 in ipairs(axes) do
        local ux, uy = ax2[1], ax2[2]
        local ra = math.abs((arx * ux + ary * uy) * aw) + math.abs((afx * ux + afy * uy) * ah)
        local rb = math.abs((brx * ux + bry * uy) * bw) + math.abs((bfx * ux + bfy * uy) * bh)
        if math.abs(dx * ux + dy * uy) > (ra + rb) then return false end
    end
    return true
end

-- Would a prop of this footprint, here, sit on top of something the camp has already placed?
-- `upto` limits the test to the first `upto` claims: a station placing its own furniture
-- tests against what stood before it, not against the table it just put down.
function mercenaries:CampFootClaimed(pos, angle, half, upto)
    if not (pos and half) then return false end
    local p = self:CampFootCentre(pos, angle, half)
    local claims = self.CampPlacedFoot or {}
    local n = math.min(#claims, upto or #claims)
    for i = 1, n do
        local c = claims[i]
        if obbOverlap(p.x, p.y, angle or 0, half.w, half.h,
                      c.x, c.y, c.a, c.w, c.h) then
            return true, c.what
        end
    end
    return false
end

-- ==== thin geometry the map cannot see ====
--
-- The map samples straight down every half metre, which a FENCE walks straight through: its
-- rails are a hand wide, so a run at an angle registers on some cells and not others, the
-- flood fill leaks through the gaps, both sides of it read as one connected surface, and a
-- tent gets pitched across it. Posts, thin walls, cart shafts and railings all do this.
--
-- A fence crossing a footprint has to cross its PERIMETER, so the perimeter is what gets
-- cast - four rays round the edges plus the two diagonals for anything standing alone in the
-- middle. Horizontal rays at the heights a rail lives at, which is the one thing a downward
-- grid can never see however fine it is sampled.
--
-- A SAFETY MARGIN, not a detection improvement. A cart's two thin handles are the case that
-- makes the point: they are a couple of centimetres across, they stick out well past the
-- body, and no sampling catches every one of them. So the box that gets swept is the
-- footprint GROWN by CampClearMargin - anything within a hand's breadth of where a tent is
-- going counts as in the way, and a near miss becomes a miss.
--
-- The heights matter as much as the margin. Two of them (0.45 and 1.05) left a hole at 0.7m,
-- which is exactly where a resting cart shaft sits; the band is sampled at 0.35m now, from
-- below a fence's bottom rail to above its top one. Anything lower than the first height is
-- the ground tests' business.
--
-- Run on a spot everything cheaper has already approved.
mercenaries.CampClearHeights = { 0.25, 0.60, 0.95, 1.30 }   -- above the ground under the spot
mercenaries.CampClearMargin  = 0.10                         -- keep this clear all round

function mercenaries:CampFootprintUnobstructed(pos, angle, half, groundZ)
    if not (pos and half) then return true end
    local centre = self:CampFootCentre(pos, angle, half)
    local fwd = { x = math.cos(angle or 0), y = math.sin(angle or 0) }
    local rgt = { x = -fwd.y, y = fwd.x }
    local w = half.w + self.CampClearMargin
    local h = half.h + self.CampClearMargin

    local function corner(sw, sh)
        return { x = centre.x + rgt.x * (sw * w) + fwd.x * (sh * h),
                 y = centre.y + rgt.y * (sw * w) + fwd.y * (sh * h) }
    end
    -- Four edges and the two diagonals. A ray that STARTS inside solid geometry may report
    -- nothing, which sounds like a hole in the perimeter and is not: an object covering a
    -- corner has to cross both edges meeting at it, and the other of those two is cast from
    -- its far end, outside the object. The only thing that escapes is something swallowing
    -- the whole box, which the ground map has already refused. The diagonals are for a post
    -- standing alone in the middle, crossing no edge at all.
    local c = { corner(-1, -1), corner(1, -1), corner(1, 1), corner(-1, 1) }
    local lines = { { c[1], c[2] }, { c[2], c[3] }, { c[3], c[4] }, { c[4], c[1] },
                    { c[1], c[3] }, { c[2], c[4] } }

    local base = groundZ or pos.z
    local mask = self.GroundObstacleMask and self:GroundObstacleMask()
                 or (ent_static + ent_sleeping_rigid + ent_rigid)
    for _, hgt in ipairs(self.CampClearHeights) do
        for _, ln in ipairs(lines) do
            local a, b = ln[1], ln[2]
            local dx, dy = b.x - a.x, b.y - a.y
            local hit = false
            pcall(function()
                local hitTable = {}
                local n = Physics.RayWorldIntersection(
                    { x = a.x, y = a.y, z = base + hgt }, { x = dx, y = dy, z = 0 },
                    1, mask, nil, nil, hitTable)
                hit = (tonumber(n) or 0) > 0
            end)
            if hit then return false end
        end
    end
    return true
end

-- True if a prop footprint at (wpos, angle) sits on mostly-valid ground -
-- at most CampFootprintSlack invalid cells. Used to accept, or to score
-- nudges for, tents/fires/the player tent.
function mercenaries:CampFootprintOk(map, wpos, angle, half)
    if not map then return true end   -- no map (fallback) -> don't block placement
    local c = self:CampFootCentre(wpos, angle, half)
    local valid, total = self:CampFootprintStats(map, c, angle, half.w, half.h)
    return (total - valid) <= self:CampFootprintAllowance(total), valid, total
end

-- Nudges `basePos` (in its local right/forward frame) over a small search to
-- find the spot whose footprint has the fewest invalid cells; returns the best
-- position found. Tents/beds are never skipped - the least-bad spot is used -
-- so every non-guard keeps a tent and the furniture pools stay intact.
-- A candidate has to clear three things, cheapest first: the GROUND under its footprint
-- (the map, free), what the CAMP has already claimed there (bookkeeping, free), and anything
-- THIN standing in it (a perimeter sweep, six rays - only ever on a spot the other two have
-- already passed).
-- `claim` is the box tested against what the camp has already put down, and defaults to
-- `half`. They differ wherever the ground slack would make a prop look bigger than it is.
function mercenaries:CampNudgeToValid(map, basePos, angle, half, groundZ, claim)
    if not map then return basePos end
    claim = claim or half

    local function acceptable(p)
        local v, t, _, vegN = self:CampFootprintStats(map, self:CampFootCentre(p, angle, half),
                                                      angle, half.w, half.h)
        if (t - v) > self:CampFootprintAllowance(t) then return false, v end
        -- The allowance is for a rough cell or two, not for a bush: a tent whose far corner
        -- covered two cells of elder was accepted under it, and backed into the bush.
        if (vegN or 0) > 0 then return false, v end
        if self:CampFootClaimed(p, angle, claim) then return false, v end
        if not self:CampFootprintUnobstructed(p, angle, half, groundZ or p.z) then
            return false, v
        end
        return true, v
    end

    local okBase, bestValid = acceptable(basePos)
    if okBase then return basePos end
    local best = basePos
    for ring = 1, self.CampNudgeMax do
        local d = ring * self.CampNudgeStep
        for _, off in ipairs({ { d, 0 }, { -d, 0 }, { 0, d }, { 0, -d }, { d, d }, { -d, d }, { d, -d }, { -d, -d } }) do
            local cand = self:CampRelativeOffset(basePos, angle, { right = off[1], forward = off[2] })
            local ok, v = acceptable(cand)
            if ok then return cand end    -- first clean spot wins
            if v > bestValid then best, bestValid = cand, v end
        end
    end
    -- Nothing clean within the rings above. Before settling for rough ground, look further
    -- and finer: sixteen bearings out to twice the range. A ring slot that fell on the
    -- smokehouse had every near candidate claimed too, and the base was kept - which is a
    -- tent built THROUGH the smokehouse, the single worst thing in a judged survey.
    for ring = self.CampNudgeMax + 1, self.CampNudgeMax * 2 do
        local d = ring * self.CampNudgeStep
        for k = 0, 15 do
            local a = k * (math.pi / 8)
            local cand = self:CampRelativeOffset(basePos, angle, { right = math.cos(a) * d, forward = math.sin(a) * d })
            local ok, v = acceptable(cand)
            if ok then
                self:GroundNote(string.format('a prop moved %.1f m to the nearest clear ground', d))
                return cand
            end
            if v > bestValid and not self:CampFootClaimed(cand, angle, claim) then best, bestValid = cand, v end
        end
    end
    -- Still nothing clean. The least-bad ground still beats the original spot, but a spot
    -- that would sit ON something already placed is worse than a rough one that does not,
    -- so those are refused outright and the base is kept - and said, because it is a defect.
    if self:CampFootClaimed(best, angle, claim) then
        local _, what = self:CampFootClaimed(basePos, angle, claim)
        if what then
            self:GroundNote(string.format('a prop is being built on the %s at (%.1f, %.1f): no clear ground within %.1f m',
                tostring(what), basePos.x, basePos.y, self.CampNudgeMax * 2 * self.CampNudgeStep))
        end
        return basePos
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
-- OFF. Spawning camp dressing STATIC looked like a free physics win - BasicEntity's default is
-- a live pushable rigid body and a big camp has ~250 of them. But ac_disableLivingVsRigidCollisions
-- ships at 1, which exempts living entities from RIGID bodies only: as rigid props, chairs and
-- beds were invisible to an NPC's character controller, and making them static handed that
-- collision back. Mercs then sat a metre up, standing on the seat's collision box instead of in
-- it. Correctness beats an unmeasured frame or two; set true again only with a seat/bed exemption.
mercenaries.CampPropsStatic = false

-- `ghost` spawns the prop with NO collision at all. BasicEntity's class default is
-- bPhysicalize = true / bRigidBody = true, and a spawn that OMITS the Physics table inherits
-- that default rather than getting no physics - so "no Physics property" never made a
-- walk-through prop, it made a pushable rigid body. Only an explicit bPhysicalize = false
-- skips BasicEntity:PhysicalizeThis (references/Scripts/Entities/Physics/BasicEntity.lua).
function mercenaries:SpawnCampPropModel(model, pos, angleZ, namePrefix, trackList, ghost)
    if not model or model == "" then return nil end

    -- Snapping now answers with the ground rather than the top of whatever is standing on
    -- it, so a prop over a cart or a shed lands at its foot instead of on its roof. Where it
    -- lands under something, say so: the layout chose this spot and the layout is what wants
    -- fixing, but the prop is at least on the floor.
    local groundPos, clear = self:CampSnapToGround(pos, true)
    if clear == false and self.GroundNote then
        self:GroundNote(string.format('%s placed at (%.1f, %.1f) with something over it',
            tostring(namePrefix or 'camp prop'), groundPos.x, groundPos.y))
    end
    -- Loose dressing that would stand in a bush is not built. A sack beside a tent is placed
    -- at a fixed offset from the tent with no test of its own, and the bake is the only thing
    -- that can tell it is in the scrub; a camp with one sack fewer beats a sack in a bramble.
    if namePrefix == "MercCampProp_TentClutter" and self.VegFootprintHit and self.CampPropFootHalf then
        local plant = self:VegFootprintHit(groundPos, angleZ or 0, self:CampPropFootHalf(model, 0.1))
        if plant then
            if self.GroundNote then
                self:GroundNote(string.format('%s dropped: %s', tostring(namePrefix), self:VegDescribe(plant)))
            end
            return nil
        end
    end
    -- Lay it ON its ground rather than on the single point under its origin: one height
    -- and no tilt is only correct on flat ground, and a tent is up to 4.66 m long. Decoration
    -- only - the smart-object path (SpawnCampFurnitureSO) is deliberately left alone, because
    -- sit and sleep animations are authored against a level surface. See
    -- mercenaries_campfit.lua. A nil back means the fit had no better answer than the snap.
    local fitX, fitY, fitted = 0, 0, false
    if self.CampFitProp then
        local fz, ax, ay = self:CampFitProp(model, groundPos, angleZ, ghost)
        if fz then
            -- A FRESH table: groundPos can be the caller's own `pos`, and writing z into it
            -- would move whatever else is still holding that reference.
            groundPos = { x = groundPos.x, y = groundPos.y, z = fz }
            fitX, fitY = ax or 0, ay or 0
            fitted = (fitX ~= 0 or fitY ~= 0)
        end
    end

    local name = (namePrefix or "MercCampProp") .. "_" .. tostring(math.random(100000, 999999))

    local ent = System.SpawnEntity({
        class = "BasicEntity",
        name = name,
        position = groundPos,
        -- Orientation at SPAWN as a forward DIRECTION VECTOR (SpawnEntity's
        -- `orientation` is a vec3 direction, not Euler - see SpawnCampFurnitureSO).
        -- Anything caching this entity's transform (e.g. an SO attached via the
        -- "attachable" link) reads this; the SetAngles below covers the render.
        orientation = { x = math.cos(angleZ or 0), y = math.sin(angleZ or 0), z = 0 },
        properties = {
            object_Model = model,
            bMissionCritical = false,
            -- Never serialise camp props: the camp is rebuilt from scratch on load
            -- (see docs/camp.md), and saved ones come back as broken placeholders.
            bSaved_by_game = false,
            bSerialize = false,
            -- STATIC. BasicEntity's shipped default is bRigidBody = true and
            -- bPushableByPlayers = true, so without this every tent, table, rack and wood pile
            -- in the camp is a live, pushable rigid body - about 250 of them inside 50 m in a
            -- fully-upgraded camp, all paying broadphase for ever. Every structural spawn path
            -- in this mod already forces static; the decor path never did. Camp dressing should
            -- not drift when somebody walks into it either.
            -- No Physics property at all is the mod's recipe for a walk-through prop (see
            -- GhostBuild and AmbushMarkerSpawn); an explicit bPhysicalize = false gave the
            -- wrong mesh. mercenaries.CollisionMode decides - camp dressing is the bulk of
            -- the physicalised entities in a camp and none of it needs to stop anybody.
            -- A missing helper means the old behaviour, never a silent loss of collision:
            -- mercenaries_solid.lua is loaded after this file.
            -- A TILTED PROP MUST BE STATIC, or the tilt does not survive its first frame.
            -- With CampPropsStatic false the branch below yields NO Physics table, and this
            -- file's own header explains what that means: BasicEntity's class default is
            -- bPhysicalize = true AND bRigidBody = true, so the prop is a live dynamic body.
            -- Physics then settles it upright on whatever is under it and throws away the
            -- orientation we authored - which is why every sign convention for the ground
            -- tilt appeared to make things worse, across three separate calibration sweeps
            -- (2026-09-19). A static body keeps its transform and still collides.
            --
            -- Only props the ground fit actually tilted are forced static, so the blast
            -- radius is exactly the props this fix is for. Everything else keeps whatever
            -- it had before.
            -- A PROP THAT IS TO BE TILTED IS SPAWNED UNPHYSICALIZED, and physicalized a few
            -- lines below once its angles are on. Measured 2026-09-19: SetAngles moves the up
            -- axis of an entity with no physics exactly as asked, and does NOTHING AT ALL to a
            -- physicalized one - `merc_camp_retilt` reported "68 props wanted a tilt, 68
            -- reached, 0 changed their up axis". The physics proxy owns the transform once it
            -- exists, so the orientation has to be set before it does.
            Physics = (fitted and not ghost) and {
                bPhysicalize = false,
                bRigidBody = false,
            } or (not ghost and mercenaries.CampPropsStatic ~= false
                       and (not mercenaries.PropSolid
                            or mercenaries:PropSolid("decor"))) and {
                bPhysicalize = true,
                bRigidBody = false,
                bPushableByPlayers = false,
                Mass = -1,
                Density = -1,
            } or (ghost and { bPhysicalize = false, bRigidBody = false } or nil),
        }
    })

    if ent then
        pcall(function() ent:SetAngles({ x = fitX, y = fitY, z = angleZ or 0 }) end)
        -- Now that the orientation is on, give it its collision back - static, at the
        -- transform it is already standing in. BasicEntity:PhysicalizeThis reads
        -- self.Properties.Physics, so those are set first.
        if fitted and not ghost then
            pcall(function()
                local ph = ent.Properties and ent.Properties.Physics
                if ph then
                    ph.bPhysicalize = true
                    ph.bRigidBody = false
                    ph.bPushableByPlayers = false
                    ph.Mass = -1
                    ph.Density = -1
                end
                if ent.PhysicalizeThis then ent:PhysicalizeThis() end
            end)
        end
        pcall(function() ent:SetViewDistUnlimited() end)
        pcall(function() ent:RenderShadow(true) end)
        -- Belt and braces, the way mercenaries_store.lua does it: the property above should
        -- mean PhysicalizeThis is never called, but this whole bug was an assumption about
        -- physics nobody checked.
        if ghost then pcall(function() ent:DestroyPhysics() end) end
        table.insert(trackList or self.CampEntities, ent.id)
        -- Placement record, for the ground/alignment audit (mercenaries_campshot.lua).
        -- An entity can be asked for its position afterwards but NOT for the model it was
        -- given nor for the position the layout originally wanted, and those two are the
        -- whole question when a table ends up inside a hillside: `want` is what the layout
        -- chose, `got` is what the ground snap did with it. Bounded by the camp - cleared
        -- with CampEntities on both teardown paths - and written nowhere else.
        self.CampPropLog = self.CampPropLog or {}
        if #self.CampPropLog < 800 then
            table.insert(self.CampPropLog, {
                id = ent.id, model = model, angle = angleZ or 0, prefix = namePrefix or "",
                angX = fitX, angY = fitY,
                want = { x = pos.x, y = pos.y, z = pos.z },
                got  = { x = groundPos.x, y = groundPos.y, z = groundPos.z },
            })
        end
    end

    return ent
end

-- Is this spot clear of everything the camp has already put down? The grid's own
-- anti-overlap is the usedCell bookkeeping inside SpawnMercCamp, which off-grid
-- placements (the stations' flat-patch fallback, ForgeFindFlattest) never see - they
-- used to check only a 7m gap against OTHER STATIONS, so a forge or a food cart could
-- land on a tent, a fire ring or the practice yard. This checks against the real
-- world instead: the centre cell (player tent + quartermaster), every tracked camp
-- entity, every claimed station tile, and the tower/cart footprints. It runs only
-- when a station is being placed, so walking CampEntities is fine.
function mercenaries:CampSpotClearOfProps(pos, pad)
    if not pos then return false end
    pad = pad or 3.0
    local pad2 = pad * pad
    local c = self.CampCenter or self.CampBuildOrigin
    if c then
        local dx, dy = pos.x - c.x, pos.y - c.y
        if (dx * dx + dy * dy) < 36.0 then return false end   -- 6m: tent + quartermaster
    end
    for _, id in ipairs(self.CampEntities or {}) do
        local p
        pcall(function()
            local e = System.GetEntity(id)
            if e and e.GetWorldPos then p = e:GetWorldPos() end
        end)
        if p then
            local dx, dy = pos.x - p.x, pos.y - p.y
            if (dx * dx + dy * dy) < pad2 then return false end
        end
    end
    for _, t in pairs(self.CampStationTiles or {}) do
        if t and t.x then
            local dx, dy = pos.x - t.x, pos.y - t.y
            if (dx * dx + dy * dy) < 49.0 then return false end   -- 7m: a tile is busy ground
        end
    end
    if self.IsSpotNearTower and self:IsSpotNearTower(pos) then return false end
    if self.IsSpotNearCart and self:IsSpotNearCart(pos) then return false end
    if self.IsSpotNearWall and self:IsSpotNearWall(pos) then return false end
    return true
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
-- position, both of which camp_actor.xml needs: it Moves the merc to the
-- position first (StanceElement does not appear to navigate on its own - the
-- vanilla scheduler walks the NPC to the spot before running the smart
-- object's `use` behaviour), then runs the StanceElement against the WUID.
-- Both entities are tracked in CampEntities for teardown.
-- noSnap: use pos exactly as given. Indoors CampSnapToGround probes from 5m ABOVE the point and
-- casts down, so it finds the roof and the furniture lands up there. Aimed/baked interior
-- coordinates are already exact floor points and must not be corrected.
function mercenaries:SpawnCampFurnitureSO(model, pos, angleZ, namePrefix, soProps, soPosOverride, trackList, noSnap)
    if not model or model == "" then return nil, nil end

    local groundPos = noSnap and { x = pos.x, y = pos.y, z = pos.z } or self:CampSnapToGround(pos)

    -- HEIGHT ONLY, and from the TERRAIN. CampSnapToGround above takes the first surface the
    -- ray meets, whatever it is, so a seat placed beside the cooking tripod snapped onto the
    -- TRIPOD and ended up hanging a metre in the air at the middle of the camp - the worst
    -- defect of one judged survey, visible from four of eight fire angles.
    --
    -- The ground fit's terrain-only plane cannot do that: it ignores props entirely. Only its
    -- height is taken. Tilt is still withheld from smart-object furniture on purpose - sit
    -- and sleep animations are authored against a level surface, and this codebase has had
    -- mercs sitting a metre above a seat before from a change that looked harmless.
    if not noSnap and self.CampFitProp then
        local fz = self:CampFitProp(model, groundPos, angleZ, false)
        if fz then groundPos = { x = groundPos.x, y = groundPos.y, z = fz } end
    end
    angleZ = angleZ or 0

    -- 1. The visual prop - purely decorative, no SO properties, and NO COLLISION.
    -- A seat is the one prop a man has to stand at: the smart object sits inside the stump's
    -- own footprint, so a solid stump is a 0.47m step he climbs on the way in and then sits
    -- on top of, which is the "merc floats above his log" report. Measured with
    -- merc_seat_probe: the floaters' z was the stump's top face, to the centimetre.
    -- See docs/camp.md, "The sitter floated above his log".
    local propEnt = self:SpawnCampPropModel(model, groundPos, angleZ, namePrefix, trackList, true)

    -- The prop ground-snaps once more on its way in, so take the height it ACTUALLY landed
    -- at. The smart object has to sit on the seat, not on the height the seat was asked for.
    -- Not under noSnap: there the caller has an exact aimed floor point (an interior, where
    -- snapping is what goes wrong) and the prop's own snap is the thing not to copy.
    if propEnt and not noSnap then
        local pp
        pcall(function() pp = propEnt:GetWorldPos() end)
        if pp and pp.z then groundPos = { x = groundPos.x, y = groundPos.y, z = pp.z } end
    end

    -- 2. The smart object itself. Normally co-located with the prop, but
    -- callers can nudge it (soPosOverride) when the SO helper's authored pose
    -- doesn't land centred on our particular prop - see the sitter stool.
    -- The nudge is horizontal and lands INSIDE the prop's own footprint, so it takes the
    -- prop's height rather than a ground ray of its own: that ray fires with the prop
    -- already physicalised and hits the prop's own top face. See docs/camp.md,
    -- "The sitter floated above his log".
    local soGroundPos = groundPos
    if soPosOverride then
        soGroundPos = {
            x = soPosOverride.x,
            y = soPosOverride.y,
            z = groundPos.z + ((soPosOverride.z or pos.z) - pos.z),
        }
    end

    -- BEDS ONLY: the sleeper lies across the bed instead of along it, because the two
    -- halves of this function do not share a facing convention. The prop is turned with
    -- SetAngles (a yaw), the smart object with SpawnEntity's `orientation` (a forward
    -- DIRECTION VECTOR, whose zero is the entity's own forward axis, a quarter turn off
    -- the yaw zero) - so an SO handed the same number as its mesh ends up a quarter turn
    -- from it. Nothing caught it before the bed because every seat this function spawns is
    -- a round stool or a log: symmetric meshes, on which a rotated smart object is
    -- invisible, and whose facing (CampSitFacingFixDeg, InnSeatYawFixDeg) was tuned by eye
    -- against the SO alone. The bed is the first asymmetric mesh here, so it is the first
    -- place the mismatch shows. Correcting it inside the seat path would move every seat
    -- that was tuned around it, so the fix is scoped to the bed SOs - which are the ones
    -- with a mesh to disagree with.
    local soAngleZ = angleZ
    local isBedSO = soProps and (soProps.sWH_AI_EntityCategory == "Bed"
                                 or soProps.soclass_SmartObjectHelpers == "Bed_1Place_Low")
    if isBedSO then soAngleZ = angleZ + math.rad(self.CampBedSOYawFixDeg or 0) end

    local wuid = nil
    local ok, err = pcall(function()
        -- Orientation MUST be set at spawn time and MUST be a forward DIRECTION
        -- VECTOR - SpawnEntity's `orientation` is a vec3 direction, NOT Euler
        -- angles. Euler {0,0,yaw} reads as a garbage up-vector, leaving every SO
        -- helper at world-default: that is why seated mercs all faced one
        -- direction for so long. A StanceSmartObject also caches its sit/lie
        -- helper transform at creation, so rotating it AFTER spawn (SetAngles /
        -- SetWorldAngles) moves the entity but not the helper. The SetAngles below
        -- is kept only to keep the entity's own transform consistent.
        local soEnt = System.SpawnEntity({
            class = "StanceSmartObject",
            name = (namePrefix or "MercCampProp") .. "_SO_" .. tostring(math.random(100000, 999999)),
            position = soGroundPos,
            orientation = { x = math.cos(soAngleZ), y = math.sin(soAngleZ), z = 0 },
            properties = {
                guidSmartObjectType = soProps.guidSmartObjectType,
                soclass_SmartObjectHelpers = soProps.soclass_SmartObjectHelpers,
                sWH_AI_EntityCategory = soProps.sWH_AI_EntityCategory,
                Script = soProps.Script,
                Bed = soProps.Bed,
                bSaved_by_game = false,
                bSerialize = false,
            }
        })

        if soEnt then
            pcall(function() soEnt:SetAngles({ x = 0, y = 0, z = soAngleZ }) end)
            -- Attach the SO to the visual mesh the way the vanilla furniture
            -- prefabs do (EntityLinks Name="attachable" -> the prop entity, see
            -- references chairattable layer) - the sit helper then follows the
            -- mesh instead of free-floating.
            if propEnt then pcall(function() soEnt:SetLinkTarget("attachable", propEnt.id) end) end
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
    -- camp_actor.xml Moves the merc to before the StanceElement.
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
-- `namePrefix` and `trackList` let a camp that is NOT the player's own borrow this. The name
-- matters: ClearAnyLeftoverCamp and the upgrade rebuild sweep "MercCamp*" GLOBALLY by name,
-- so a bandit camp's fire named that way is destroyed the moment the player rebuilds theirs.
function mercenaries:SpawnCampFirePrefab(pos, angleZ, prefabId, namePrefix, trackList)
    local ok, err = pcall(function()
        local groundPos = self:CampSnapToGround(pos)
        local anchorEnt = System.SpawnEntity({
            class = "BasicEntity",
            name = (namePrefix or "MercCampProp_FireAnchor_") .. tostring(math.random(100000, 999999)),
            position = groundPos,
            properties = mercenaries:NoSaveProps({ object_Model = "", bMissionCritical = false })
        })
        if anchorEnt then
            pcall(function() anchorEnt:SetAngles({ x = 0, y = 0, z = angleZ or 0 }) end)
            table.insert(trackList or self.CampEntities, anchorEnt.id)
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
-- follow BT instead of the stand-still idle branch) and camp_actor.xml
-- (the actual patrol Move loop).
-- Camp deployment: the quartermaster can send a fraction of the squad (best-
-- equipped first) out of camp to follow the player while the rest keep camping.
-- Deployed mercs are tracked in CampOutParty; the camp accessors return nothing
-- for them (so the follow BT follows the player), but IsCampActor stays true so
-- the scheduler routes them to the follow branch, not idle-stand.
mercenaries.CampOutParty = {}   -- [wuidStr] = true : mercs deployed out of camp

-- Deploying a party has to survive a save. CampOutParty is keyed by WUID, and a WUID is not
-- stable across a load - but the entity NAME is, which is exactly why RebuildMercCache
-- re-finds the squad by scanning for names. So the out-party is persisted as a list of names
-- and mapped back to WUIDs once that cache exists.
--
-- Restore must run AFTER the camp is rebuilt: SpawnMercCamp resets CampOutParty to empty
-- ("fresh camp: everyone starts in it") and hands every merc a camp role, so restoring before
-- it would simply be overwritten.
--
-- Stored as "anchorX,anchorY|name;name;...", the same shape (and the same anchor epsilon)
-- CampPackStationTiles uses for the upgrade tiles, because the list belongs to a PITCH and
-- not to the company. Without the anchor the tag simply outlives the table it mirrors:
-- SpawnMercCamp empties CampOutParty in memory and never rewrote the tag, so the last party
-- anyone deployed was still sitting in the save and LoadCampOutParty handed the whole squad
-- back to the player on the next load - "everybody starts following after I reload". An
-- unstamped blob is from before this and is discarded, which heals a save already carrying one.
function mercenaries:SaveCampOutParty()
    local names = {}
    for name, ent in pairs(self.ActiveMercs or {}) do
        local ka, kb = self:CampMercKeys(ent)
        if (ka and self.CampOutParty[ka]) or (kb and self.CampOutParty[kb]) then
            names[#names + 1] = name
        end
    end
    table.sort(names)   -- stable string, so SaveString can skip an unchanged rewrite
    local o = self.CampBuildOrigin
    pcall(function()
        if not o then
            -- No pitch to key the list to (camp struck, or never made): there is no sortie.
            self:SaveString("MercOutParty", "none")
        else
            self:SaveString("MercOutParty",
                            string.format("%.2f,%.2f|%s", o.x, o.y, table.concat(names, ";")))
        end
    end)
end

function mercenaries:LoadCampOutParty(origin)
    local blob
    pcall(function() blob = self:LoadString("MercOutParty") end)
    if not blob or blob == "none" then return end

    -- Only a list written for the camp being pitched right now counts. Both callers run
    -- immediately after SpawnMercCamp, so CampBuildOrigin is this pitch's anchor.
    local o = origin or self.CampBuildOrigin
    local head, body = string.match(blob, "^([^|]*)|(.*)$")
    local ax, ay
    if head then ax, ay = string.match(head, "([^,]+),([^,]+)") end
    ax, ay = tonumber(ax), tonumber(ay)
    local mine = false
    if body and o and ax and ay then
        local dx, dy = o.x - ax, o.y - ay
        mine = (dx * dx + dy * dy) <= (self.CampTileAnchorEps * self.CampTileAnchorEps)
    end
    if not mine then
        System.LogAlways("[Camp] out-party list belongs to another pitch - everyone stays in camp")
        return
    end

    local restored = 0
    for name in string.gmatch(body, "([^;]+)") do
        local ent = self.ActiveMercs and self.ActiveMercs[name]
        local ka, kb = self:CampMercKeys(ent)
        if ka then
            for _, ws in ipairs({ ka, kb }) do
                if ws then
                    self.CampOutParty[ws] = true
                    self.CampRoster[ws] = nil
                    -- A deployed merc holds no camp role; the camp rebuild just gave him one.
                    if self.CampFurniture then self.CampFurniture[ws] = nil end
                    if self.CampActivities then self.CampActivities[ws] = nil end
                    if self.CampPatrollers then self.CampPatrollers[ws] = nil end
                    self:ReleaseSpot(self.CampSeats or {}, ws)
                    self:ReleaseSpot(self.CampBeds or {}, ws)
                end
            end
            restored = restored + 1
        end
    end
    if restored > 0 then
        -- These men were camp actors a moment ago (SpawnMercCamp put every merc in the camp
        -- and teleported them there) and are now followers, so the shape has to be rebuilt.
        if self.CampActorInvalidateAll then self:CampActorInvalidateAll() end
        System.LogAlways("[Camp] restored " .. restored .. " merc(s) to the deployed party")
        self:CampFormationDirty("restore")
    end
end

-- Reachable ONLY with a camp standing (IsMercInCampProper short-circuits otherwise),
-- which is why a save with a camp threw on every formation tick and a save without one
-- was fine. The throw is tostring() on the WUID: these are engine userdata, and a handle
-- belonging to an entity the roster rebuild has replaced errors when converted. Nothing
-- here is worth an exception - a WUID that cannot be read is simply not in the out-party.
function mercenaries:IsCampOut(mercWuid)
    if mercWuid == nil then return false end
    local t = self.CampOutParty
    if type(t) ~= "table" then return false end
    local k
    if not pcall(function() k = tostring(mercWuid) end) or k == nil then return false end
    return t[k] == true
end

-- ===== Camp membership =====
-- CampOutParty says who LEFT; CampRoster says who is holding the camp, and it is rebuilt
-- from ActiveMercs every camp tick. Camp ROLES are handed out once, when the camp is laid
-- out, so anyone who joined the squad afterwards (a new hire, a man back from a sortie, a
-- squad restored on load) had no role - which made him no camp actor, which dropped him
-- into the follow branch. He trailed the player while nominally "in camp", could not be
-- sent back (he was never in the out-party) and was left out of the formation
-- (IsMercInCampProper). See docs/camp.md, "Joining a camp that is already up".
mercenaries.CampRoster = {}

-- How close to the camp centre a merc has to be hired for him to join camp life rather
-- than the party you are currently leading.
mercenaries.CampJoinRadius = 25.0

-- Both WUID spaces for one merc: this file writes with GetMyWUID, every BT consumer reads
-- entity.this.id. They coincide for these NPCs today; keying under both costs two table
-- writes and removes the whole class of bug if they ever stop (the same hedge
-- RequestForceTalk makes). Second return is nil when the two ids are the same.
function mercenaries:CampMercKeys(ent)
    if not ent then return nil, nil end
    local a = ent.this and ent.this.id or ent.id
    local b
    pcall(function() b = XGenAIModule.GetMyWUID(ent) end)
    local ka = a and tostring(a) or nil
    local kb = b and tostring(b) or nil
    if kb == ka then kb = nil end
    return ka, kb
end

function mercenaries:CampActorDirty(...)
    if not self.CampActorInvalidate then return end
    for i = 1, select('#', ...) do
        local k = select(i, ...)
        if k then self:CampActorInvalidate(k) end
    end
end

-- The roster the formation is built from just changed. UpdateFormationLeader only rebuilds
-- on a size or leader change it notices of its own accord, so a deploy or a return leaves
-- the shape stale until something forces it: bump the epoch and drop the leader so the next
-- tick re-elects one and re-slots everybody.
function mercenaries:CampFormationDirty(why)
    self.FormationLeader = nil
    self.FormationCap    = 0
    self.FormationEpoch  = (self.FormationEpoch or 0) + 1
    pcall(function() self:UpdateFormationLeader() end)
    System.LogAlways('[Camp] formation rebuild #' .. tostring(self.FormationEpoch) ..
                     ' (' .. tostring(why or 'party') .. ')')
end

-- Move one merc in or out of the sortie, under both keys.
function mercenaries:CampSetOut(ent, out)
    local ka, kb = self:CampMercKeys(ent)
    if ka then self.CampOutParty[ka] = out or nil end
    if kb then self.CampOutParty[kb] = out or nil end
    self:CampActorDirty(ka, kb)
    return ka, kb
end

function mercenaries:CampIsMember(wuidStr)
    if _G.MercenariesDismissed or not _G.MercInCamp then return false end
    if self:IsForeignCampActor(wuidStr) then return false end
    if self.CampOutParty[wuidStr] then return false end
    return self.CampRoster[wuidStr] == true
end

-- A spot record for a merc the camp build never placed. Without one ApplyCampRole returns
-- immediately and the man never gets an occupation. Geometry mirrors the activity ring the
-- build loop uses: outside the tents, on a bearing with a clear line to a fire.
function mercenaries:CampEnsureSpot(wuidStr)
    if not (self.CampActive and self.CampCenter) then return nil end
    local s = self.CampMercSpots[wuidStr]
    if s and s.actPos then return s end
    s = s or {}
    local fires = self.CampClusterCenters or {}
    local fire = (#fires > 0) and fires[math.random(#fires)] or self.CampCenter
    local slots = self.CampClusterTentRingSlots or 7
    s.actPos  = self:CampSnapToGround(select(1, self:CampRingPos(fire,
        self:CampTentRing() + self.CampActivityOutsideGap,
        math.random(slots), slots, math.pi / slots)))
    s.lastPos = s.actPos
    s.firePos = { x = fire.x, y = fire.y, z = fire.z }
    if self.CampTrainCenter then
        local off = (math.random() - 0.5) * (self.CampTrainingTraineeSpacing or 2.0) * 2
        s.trainPos = self:CampSnapToGround(self:CampRelativeOffset(self.CampTrainCenter,
            self.CampForwardAngle or 0, { right = off, forward = self.CampTrainingTraineeSetback }))
        s.trainFacePos = { x = self.CampTrainCenter.x, y = self.CampTrainCenter.y, z = self.CampTrainCenter.z }
    end
    self.CampMercSpots[wuidStr] = s
    return s
end

-- Advance one merc to the next step of his cycle and schedule the step after it.
function mercenaries:CampRotateRole(wuidStr)
    local cycle = self:CampCycleFor(wuidStr)
    local idx = ((self.CampRoleIdx[wuidStr] or 0) % #cycle) + 1
    self.CampRoleIdx[wuidStr] = idx
    local role = self:ApplyCampRole(wuidStr, self:CampRoleWithInjuryBias(self:CampRoleWithNightBias(cycle[idx]), wuidStr))
    local span = self.CampRoleSeconds[role] or { 60, 90 }
    -- ticks are 5s apart
    self.CampNextRotate[wuidStr] = self.CampTicks + math.max(1, math.floor(math.random(span[1], span[2]) / 5))
end

-- Put a merc into camp life NOW: out of the sortie, holding a spot, and on a role this
-- instant rather than at the next 5s rotation - a role-less merc is not a camp actor, and
-- would spend that gap walking back to the player.
function mercenaries:CampAdmitToCamp(ent, wuidStr)
    if not self.CampActive then return end
    local ka, kb = self:CampMercKeys(ent)
    local ws = ka or wuidStr
    if not ws then return end
    for _, k in pairs({ ka = ka, kb = kb, ws = wuidStr }) do
        self.CampOutParty[k] = nil
        self.CampRoster[k] = true
    end
    -- Guards already have an occupation (their patrol ring) and want no spot.
    if not (self.CampPatrollers and self.CampPatrollers[ws]) then
        if self:CampEnsureSpot(ws) then self:CampRotateRole(ws) end
    end
    self:CampActorDirty(ka, kb, wuidStr)
end

-- Every camp tick. Anyone in the squad who is not out on the sortie is a camp member, and
-- any member with no occupation at all is given a spot and rotated onto one. This is what
-- admits a late joiner without rebuilding the whole camp.
function mercenaries:CampSyncRoster()
    if not (self.CampActive and _G.MercInCamp) or _G.MercenariesDismissed then
        if next(self.CampRoster) then
            self.CampRoster = {}
            if self.CampActorInvalidateAll then self:CampActorInvalidateAll() end
        end
        return
    end
    local roster = {}
    for _, ent in pairs(self.ActiveMercs or {}) do
        if ent and self:IsAliveAndWell(ent, false) then
            local ka, kb = self:CampMercKeys(ent)
            local out = (ka and self.CampOutParty[ka]) or (kb and self.CampOutParty[kb])
            if ka and not out then
                if not self.CampRoster[ka] then self:CampActorDirty(ka, kb) end
                roster[ka] = true
                if kb then roster[kb] = true end
                if not self:IsCampGuard(ka)
                   and not (self.CampActivities and self.CampActivities[ka])
                   and not (self.CampFurniture and self.CampFurniture[ka]) then
                    if self:CampEnsureSpot(ka) then self:CampRotateRole(ka) end
                end
            end
        end
    end
    for ws in pairs(self.CampMercSpots or {}) do
        if not roster[ws] and not self.CampOutParty[ws] then
            self:ReleaseSpot(self.CampSeats or {}, ws)
            self:ReleaseSpot(self.CampBeds or {}, ws)
            if self.CampFurniture then self.CampFurniture[ws] = nil end
            if self.CampActivities then self.CampActivities[ws] = nil end
            self.CampMercSpots[ws] = nil
        end
    end
    self.CampRoster = roster
end

-- Hired (or otherwise added to the squad) while the camp stands. Nothing else decides which
-- half of the squad a new man belongs to, and the default - absent from the out-party - reads
-- as "in camp" to the formation while he holds no camp role at all. Hired at camp he joins
-- camp life; hired anywhere else he joins the party you are leading, so he marches in the
-- formation and can be sent back with the rest.
function mercenaries:CampOnMercJoined(ent)
    if not (ent and self.CampActive and _G.MercInCamp) then return end
    local ka = self:CampMercKeys(ent)
    if not ka then return end
    local atCamp = false
    pcall(function()
        local c = self.CampCenter
        local pp = player and player:GetWorldPos()
        if c and pp then
            local dx, dy = pp.x - c.x, pp.y - c.y
            atCamp = (dx * dx + dy * dy) <= (self.CampJoinRadius * self.CampJoinRadius)
        end
    end)
    if atCamp then
        self:CampAdmitToCamp(ent, ka)
    else
        self:CampSetOut(ent, true)
        self.CampRoster[ka] = nil
        self:CampFormationDirty("hire")
    end
    pcall(function() self:SaveCampOutParty() end)
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

-- Defensive, and it reports WHY. This threw on every formation tick (2026-09-19) and no
-- capture method could say what the error was: KCD2 replaces the Lua error text with a
-- generic "[Error] Lua error. Please run with -lua_storedebug 1" unless the game is
-- started with that switch, so pcall, xpcall and debug.traceback all return the same
-- useless string. The only way left to find out is to check the preconditions by hand
-- and name the one that is wrong - and while we are here, repair it, because the caller
-- is an exclusion predicate on a 0.22s loop and a throw there costs the squad its
-- formation for the whole session.
function mercenaries:IsMercInCampProper(mercWuid)
    if _G.MercInCamp ~= true then return false end
    if type(self.CampOutParty) ~= "table" then
        if not self._campOutPartyWarned then
            self._campOutPartyWarned = true
            System.LogAlways("[Camp] CampOutParty was " .. type(self.CampOutParty) ..
                             ", not a table - recreated. Something nil'd it after load.")
        end
        self.CampOutParty = {}
    end
    if type(self.IsCampOut) ~= "function" then
        if not self._isCampOutWarned then
            self._isCampOutWarned = true
            System.LogAlways("[Camp] IsCampOut is " .. type(self.IsCampOut) ..
                             ", not a function - mercenaries_camp.lua did not finish loading.")
        end
        return false
    end
    if mercWuid == nil then return false end
    return not self:IsCampOut(mercWuid)
end

-- True when this WUID belongs to a camp that is not the player's - a bandit camp from
-- the quartermaster's contract. Those actors hold camp roles on their own terms: their
-- camp exists whether or not the squad has pitched one, and they are never "camp out".
function mercenaries:IsForeignCampActor(wuidStr)
    return (self.BanditCampActors and self.BanditCampActors[wuidStr]) == true
end

function mercenaries:IsCampGuard(mercWuid)
    local ws = tostring(mercWuid)
    if not self:IsForeignCampActor(ws) then
        if not _G.MercInCamp or _G.MercenariesDismissed then return false end
        if self:IsCampOut(mercWuid) then return false end
    end
    local rec = self.CampPatrollers and self.CampPatrollers[ws]
    return (rec and rec.waypoints and #rec.waypoints > 0) == true
end

-- Returns a non-guard camp merc's assigned furniture record { wuid=, kind= }
-- ("bed" -> sleep/lie, "chair" -> sit), or nil. Set by SpawnMercCamp for the
-- non-patrolling mercs (half sit, half sleep). camp_actor.xml reads this
-- and drives a StanceElement against the furniture's smart object.
function mercenaries:GetCampFurniture(mercWuid)
    local ws = tostring(mercWuid)
    if not self:IsForeignCampActor(ws) then
        if not _G.MercInCamp or _G.MercenariesDismissed then return nil end
        if self:IsCampOut(mercWuid) then return nil end
    end
    return self.CampFurniture and self.CampFurniture[ws]
end

-- Returns a merc's assigned camp ACTIVITY record, or nil:
--   { unstance = "<NPCStateUnstanceDatabase name>", mode = 1..4,
--     pos = {x,y,z}, locWuid = <anchor/seat WUID or nil>, slaveWuid = <partner or nil> }
-- Deliberately NOT gated on _G.MercInCamp, so merc_camp_activity_test can play
-- an activity outside of camp; the activity case in camp_actor.xml is
-- first in the ContinuousSwitch, so it preempts patrol/sit/sleep/follow.
function mercenaries:GetCampActivity(mercWuid)
    -- Dismissing the squad ends MERC camp life; it says nothing about a bandit camp.
    if _G.MercenariesDismissed and not self:IsForeignCampActor(tostring(mercWuid)) then return nil end
    -- A post-battle loot task outranks camp life and ignores the camp-out gate:
    -- the bodies are wherever the fight was, and the mercs working them are
    -- usually the sortie party. See mercenaries_lootsweep.lua.
    local loot = self.LootActivities and self.LootActivities[tostring(mercWuid)]
    if loot then return loot end
    if not self:IsForeignCampActor(tostring(mercWuid)) and self:IsCampOut(mercWuid) then return nil end
    return self.CampActivities and self.CampActivities[tostring(mercWuid)]
end

-- True if this merc has ANY camp role (guard, assigned sit/sleep furniture, or
-- a camp activity) - i.e. should be routed into camp_actor's camp handling
-- rather than the schedulers' stand-still idle branch.
--
-- A deployed (sortie) merc is deliberately NOT a camp actor: it has no camp role,
-- so it drops into the `isIdle & ~isCampActor` idle branch when the player has
-- given a wait order, and into the follow branch otherwise - i.e. sortie mercs
-- respect global idle. (Camp no longer forces global idle on, so the in-camp
-- mercs are held in place by their roles, not by the idle flag.)
-- THE reason a camp actor stands in a battle being hit.
--
-- camp_actor is an infinite Loop with no way out: once it has the interrupt slot it keeps it
-- for good. The patrol trees do not have this problem because PatrolYieldToCombat makes their
-- walk node FAIL the moment the man has a target, which ends the behaviour and lets combat
-- take the slot (mercenaries_patrol.lua). Camp actors had no equivalent, so clearing their
-- camp role only stopped camp_actor being fired AGAIN - the instance already running carried
-- on looping regardless.
--
-- Called every cycle from camp_actor.xml. True = drop out of the camp behaviour now.
-- ==== Standing up before fighting ====
-- A camp merc who was sitting or lying when a fight started kept the pose and then moved
-- around still in it. The cause is a race between two trees that never talked to each other:
--
--   camp_actor holds its pose INSIDE a StanceElement and polls $campYield every ~500ms;
--   when the poll fails, the element unwinds and the engine plays the stand-up fragment.
--   That is the only clean way out of a stance - there is no "force standing" node in the
--   engine or in vanilla (the sleeping halberdier guard leaves his pose the same way).
--
--   The scheduler, meanwhile, polls for targets every ~600ms and fires combat_melee in the
--   SAME pass it claims one, with IgnorePriorityOnPreviousInterrupt - which REPLACES the
--   running camp_actor outright. Win that race, and the StanceElement never gets to unwind:
--   the pose is torn off rather than ended, and he fights in it.
--
-- So the scheduler now waits for him to stand. CampActorYield stamps CampPoseAt while he is
-- mid-pose; CampPoseHold reports that to the scheduler, which withholds the combat interrupt
-- (and its optimistic $inCombat, so the branch simply retries) until the stamp clears. He
-- already has a target by then, so $campYield is true and camp_actor is unwinding on its own
-- - the wait is only as long as the stand-up takes.
--
-- Bounded on both sides, because a merc who cannot fight is worse than one who fights
-- seated: the stamp expires by itself if camp_actor stops running (CampPoseFreshSecs), and
-- CampPoseMaxHoldSecs caps the whole wait however fresh the stamps are.
mercenaries.CampPoseAt          = {}     -- [wuidStr] = when he was last seen inside a pose
mercenaries.CampPoseHoldFrom    = {}     -- [wuidStr] = when we started making combat wait
mercenaries.CampPoseFreshSecs   = 2.5    -- a stamp older than this means the tree is gone
mercenaries.CampPoseMaxHoldSecs = 4.0    -- never hold combat off longer than this, whatever

local function campNow()
    local t = 0
    pcall(function() t = System.GetCurrTime() or 0 end)
    return t
end

-- ==== The pose outlives the tree ====
-- A StanceElement binds the merc to its smart object: while it is up, the ENGINE owns his
-- position, and a Lua SetPos is undone on the next animation update. Tear camp_actor off
-- mid-pose (which is exactly what a deploy's FollowStalled does) and the element is orphaned
-- rather than ended - so the man is still pinned to the bed with no tree left to unwind him.
-- Anything that hauls him then plays out as teleport, snap back, teleport, snap back, once a
-- second, until the orphan finally lets go. That is the sleeping-merc deploy report.
--
-- CampPoseAt is cleared the moment he leaves a pose, so it cannot answer "is he still
-- unwinding one". CampPoseLastAt is the same heartbeat kept: it is never cleared, so the
-- grace below runs from the last tick camp_actor reported him posed - whether the tree ended
-- cleanly or was destroyed.
mercenaries.CampPoseLastAt      = {}     -- [wuidStr] = last tick he was seen inside a pose
mercenaries.CampPoseUnwindSecs  = 3.5    -- how long camp_actor's yield gate needs to stand him up
mercenaries.CampPoseGraceSecs   = 6.0    -- ...and how long nothing may teleport him afterwards

-- Age of a pose stamp, or nil if there is none to read. A NEGATIVE age means the engine
-- clock restarted under us (a save load), which would otherwise read as "stamped in the
-- future" and exempt the man from every haul for good - so the stamp is dropped instead.
local function campPoseAge(pool, ws)
    local at = pool[ws]
    if not at then return nil end
    local age = campNow() - at
    if age < 0 then pool[ws] = nil; return nil end
    return age
end

-- True while he is demonstrably inside a Stance/Unstance element RIGHT NOW.
function mercenaries:InCampPose(wuid)
    local age = campPoseAge(self.CampPoseAt, tostring(wuid))
    return (age ~= nil) and age <= self.CampPoseFreshSecs
end

-- ==== Ask the ENGINE, not the camp tables ====
-- Everything above is inference: it reads what the mod believes about a merc's camp role,
-- and a torn-off pose is precisely the case where that belief is wrong - the tables are
-- already cleared while the engine still has him pinned to a bed. `GetStance` is the engine's
-- own answer and cannot be wrong about it, so both schedulers poll it once a second and
-- publish the result here. It keeps reporting after the tree that owned the pose is gone,
-- which is exactly when it is needed.
--
-- No grace window and no bound: this is a LIVE read, refreshed every second, so "he is still
-- lying down" stays true for as long as it is true and becomes false the tick he stands. The
-- only bound it needs is staleness - a merc whose scheduler has stopped reporting is not
-- described by an old sample. (Same shape as the GHOST LATCH sweep's FollowSchedAt test.)
mercenaries.StanceAt          = {}      -- [wuidStr] = when the stance was last read
mercenaries.StanceDown        = {}      -- [wuidStr] = engine says lying or sitting
mercenaries.StanceFreshSecs   = 4.0     -- a read older than this describes nothing

-- How many times we have asked this man to get up without the engine agreeing that he did.
mercenaries.StandUpTries = {}
mercenaries.StandUpLogEvery = 10        -- attempts between log lines, after the first

-- ==== Pose rescue: own the pose again, then let it go ====
-- Playing a standing action at a pinned merc does NOT free him - measured, 30+ attempts, the
-- engine still reporting him lying. A StanceElement binds him to its smart object and only
-- ENDING the element releases him, so the cure has to be to re-enter it and leave: the exit
-- plays the Out fragment and stands him up. camp_actor's rescue arm does exactly that.
--
-- This is the automatic form of the workaround found by hand - sending a stuck man back to
-- camp cures him, because a camp role is what makes camp_actor fire and take the pose back.
-- Here he is handed to camp_actor for a couple of seconds WITHOUT a camp role, and given back
-- the moment he is on his feet.
-- 2, not 4: the rescue is what actually works, so the seconds spent playing an action at him
-- first are mostly just a man lying in a bed for longer than he needs to be.
mercenaries.PoseRescueAfter    = 2      -- failed stand-ups before handing him to camp_actor
mercenaries.PoseRescueMax      = 4      -- rescues attempted before giving up on him
mercenaries.PoseRescuePending  = {}     -- [wuidStr] = true while camp_actor should run the arm
mercenaries.PoseRescueCount    = {}     -- [wuidStr] = rescues attempted
mercenaries.PoseRescueDoneAt   = {}     -- [wuidStr] = when his last rescue finished

-- A MAN GETTING UP STILL READS AS LYING. The stand-up is not instant, and for as long as it
-- plays the engine reports the old stance - so judging him the moment the rescue ends counts a
-- success as a failure, asks for another, and that one re-enters the StanceElement on top of
-- the stand-up already running. Measured before this window existed: eight men rescued, five
-- needing a second go, four a third, one a fourth, each fired on the very next poll. camp_actor
-- holds him through most of the transition; this covers the rest.
mercenaries.PoseRescueSettleSecs = 4.0

function mercenaries:PoseRescueSettling(ws)
    local age = campPoseAge(self.PoseRescueDoneAt, ws)
    return (age ~= nil) and age <= self.PoseRescueSettleSecs
end

-- Read by camp_actor (the arm) and by IsCampActor (so the scheduler fires camp_actor at all).
function mercenaries:PoseRescueWanted(wuid)
    return self.PoseRescuePending[tostring(wuid)] == true
end

function mercenaries:PoseRescueDone(wuid)
    local ws = tostring(wuid)
    self.PoseRescuePending[ws] = nil
    self.PoseRescueDoneAt[ws]  = campNow()
    -- The stance poll decides whether it worked; clearing the try count here would restart
    -- the ladder and rescue him forever.
    self:CampActorDirty(ws)
end

-- Give up loudly rather than silently: a man this cannot free is a real, unhandled state and
-- the log should say so once, by name, instead of counting to infinity.
function mercenaries:PoseRescueAsk(ws)
    if self.PoseRescuePending[ws] then return end
    local n = (self.PoseRescueCount[ws] or 0) + 1
    if n > self.PoseRescueMax then
        if n == self.PoseRescueMax + 1 then
            self.PoseRescueCount[ws] = n
            System.LogAlways("[Camp] " .. ws .. " could not be freed from his pose in " ..
                             tostring(self.PoseRescueMax) .. " attempts - leaving him. " ..
                             "Nothing will teleport him while he is down.")
        end
        return
    end
    self.PoseRescueCount[ws] = n
    self.PoseRescuePending[ws] = true
    self:CampActorDirty(ws)
    System.LogAlways("[Camp] " .. ws .. " will not stand - handing him to camp_actor to unwind the pose (" ..
                     tostring(n) .. " of " .. tostring(self.PoseRescueMax) .. ")")
end

function mercenaries:NoteStance(bt_data, myWuid)
    local ws   = tostring(myWuid)
    local down = (bt_data.stanceGrounded == true)
    self.StanceAt[ws]   = campNow()
    self.StanceDown[ws] = down
    bt_data.standUpWanted = false

    -- On his feet: nothing to do, and both ladders are only meaningful unbroken. The rescue
    -- budget resets too, so a man pinned again an hour later gets a fresh one rather than
    -- inheriting a count from the last time.
    if not down then
        self.StandUpTries[ws]     = nil
        self.PoseRescueCount[ws]  = nil
        self.PoseRescueDoneAt[ws] = nil
        return
    end

    -- He is off his feet. That is only WRONG if he holds no camp role - a man asleep in his
    -- own camp bed is doing exactly what he was told to. Both tests, because they answer
    -- different questions: IsCampActor is "has a role", IsMercInCampProper is "is quartered
    -- here at all", and the paths that take a squad out of camp do not all clear both.
    -- A rescue is running, or one has just finished and he is still climbing out of the pose.
    -- Either way camp_actor has him in hand: leave BOTH the action and the try count alone -
    -- resetting the count would send him back to the bottom of the ladder every time, and
    -- counting a failure mid-stand-up is what made one rescue turn into four.
    if self:PoseRescueWanted(myWuid) or self:PoseRescueSettling(ws) then return end

    if _G.MercenariesDismissed then return end
    if self:IsCampActor(myWuid) or self:IsMercInCampProper(myWuid) then
        self.StandUpTries[ws] = nil
        return
    end

    local n = (self.StandUpTries[ws] or 0) + 1
    self.StandUpTries[ws] = n

    -- The cheap cure first: play a standing action at him. It does work for some poses, and
    -- it costs one node. When it plainly is not working, escalate to the rescue - and stop
    -- playing the action, so the two are never fighting over him at once.
    if n < self.PoseRescueAfter then
        bt_data.standUpWanted = true
        if n == 1 then
            System.LogAlways("[Camp] " .. ws .. " is off his feet with no camp role - standing him up")
        end
        return
    end
    self:PoseRescueAsk(ws)
end

-- One line per merc saying whether he is on his feet and what every guard makes of it. The
-- teleport loop is invisible in a log otherwise: "he snaps back to the bed" and "he is
-- following normally" look identical from the camp tables alone.
function mercenaries:StanceDump()
    local n, down = 0, 0
    for name, ent in pairs(self.ActiveMercs or {}) do
        local w = ent and (ent.this and ent.this.id or ent.id)
        if w then
            n = n + 1
            local grounded = self:IsGroundedStance(w)
            if grounded then down = down + 1 end
            local age = self.StanceAt[tostring(w)]
            System.LogAlways(string.format(
                '[MercStance] %-58s %-4s read=%s campOut=%-5s campActor=%-5s pose=%-5s standUps=%d',
                tostring(name), grounded and "DOWN" or "up",
                age and string.format('%.1fs ago', campNow() - age) or 'never',
                tostring(self:IsCampOut(w)), tostring(self:IsCampActor(w)),
                tostring(self:LeavingCampPose(w)), self.StandUpTries[tostring(w)] or 0))
        end
    end
    System.LogAlways('[MercStance] ' .. tostring(down) .. ' of ' .. tostring(n) ..
                     ' merc(s) are off their feet. read=never means the scheduler is not polling him.')
end

-- True when the engine currently has him off his feet (lying or sitting).
function mercenaries:IsGroundedStance(wuid)
    local ws = tostring(wuid)
    if not self.StanceDown[ws] then return false end
    local age = campPoseAge(self.StanceAt, ws)
    return (age ~= nil) and age <= self.StanceFreshSecs
end

-- THE test every teleporter asks before moving a merc. Three ways to be off your feet, most
-- authoritative first:
--   * the engine says lying/sitting - true even for a pose nothing owns any more;
--   * camp_actor says it is inside a Stance/Unstance element right now;
--   * it said so within CampPoseGraceSecs - the stand-up fragment is still playing.
-- A StanceElement pins the actor to its smart object, so SetPos on any of these is undone on
-- the next animation update: the merc blinks to the player and snaps straight back. The last
-- two are bounded because they are stamps; the first needs no bound because it is a live read.
function mercenaries:LeavingCampPose(wuid)
    if self:IsGroundedStance(wuid) then return true end
    local age = campPoseAge(self.CampPoseLastAt, tostring(wuid))
    return (age ~= nil) and age <= self.CampPoseGraceSecs
end

-- Does this merc have a fight on? Shared by CampActorYield (should he leave his pose)
-- and CampPoseHold (is combat actually waiting on him).
function mercenaries:CampHasFightTarget(ws)
    local has = false
    pcall(function()
        has = (self.EnemyTargetOf and self.EnemyTargetOf[ws] ~= nil)
           or (self.ForcedTargetOf and self.ForcedTargetOf[ws] ~= nil)
           or (self.MercTargetOf  and self.MercTargetOf[ws]  ~= nil)
    end)
    return has
end

-- Called from both schedulers' acquisition pass. Sets bt_data.campPoseHold.
--
-- The STAMP is kept up for as long as he is in a pose (so there is no window where a
-- target is claimed before camp_actor has reported in), but the HOLD CLOCK only runs
-- while combat is actually waiting on him. The first version started the clock for every
-- man sitting peacefully in camp: it expired 4s later, logged, restarted, and did that
-- forever - 341 "would not leave his pose" lines in one session - and, far worse, meant
-- the cap had usually already blown by the time a fight really started, so the gate was
-- spent exactly when it was needed.
function mercenaries:CampPoseHold(bt_data, myWuid)
    bt_data.campPoseHold = false
    local ok = pcall(function()
        local ws = tostring(myWuid)
        local at = self.CampPoseAt[ws]
        if not at then
            self.CampPoseHoldFrom[ws] = nil
            return
        end
        -- Nobody is waiting on him: he is just sitting there. Leave the clock unstarted.
        if not self:CampHasFightTarget(ws) then
            self.CampPoseHoldFrom[ws] = nil
            return
        end
        local now = 0
        pcall(function() now = System.GetCurrTime() or 0 end)
        if (now - at) > self.CampPoseFreshSecs then
            -- camp_actor stopped reporting: either it ended or it is gone. Either way
            -- there is nothing left to wait for.
            self.CampPoseAt[ws] = nil
            self.CampPoseHoldFrom[ws] = nil
            return
        end
        local from = self.CampPoseHoldFrom[ws]
        if not from then
            self.CampPoseHoldFrom[ws] = now
            from = now
        end
        if (now - from) >= self.CampPoseMaxHoldSecs then
            System.LogAlways("[Camp] " .. ws .. " would not leave his pose in " ..
                             tostring(self.CampPoseMaxHoldSecs) .. "s - letting him fight anyway")
            self.CampPoseAt[ws] = nil
            self.CampPoseHoldFrom[ws] = nil
            return
        end
        bt_data.campPoseHold = true
    end)
    if not ok then bt_data.campPoseHold = false end
end

function mercenaries:CampActorYield(data, entity)
    data.campYield = false
    local w = entity and entity.this and entity.this.id
    if not w then return end
    local ws = tostring(w)

    -- HEARTBEAT: is he inside a Stance/Unstance element right now? camp_actor raises
    -- $inCampAnim around every pose, and this is the only place Lua gets to read it, so
    -- the scheduler learns "do not tear him out yet" from here. A STAMP rather than a
    -- flag, because a flag set on entry would never be cleared if the tree were torn
    -- down - which is the very failure being prevented. See CampPoseHold.
    --
    -- `== true`, not truthiness: a BT bool read back through `data` is not necessarily a
    -- Lua boolean, and 0 is TRUE in Lua. UpdateFormationRole compares `inFormation == true`
    -- for the same reason.
    if data.inCampAnim == true then
        local now = 0
        pcall(function() now = System.GetCurrTime() or 0 end)
        self.CampPoseAt[ws] = now
        -- Never cleared: this is what tells the teleporters he is still shedding a pose
        -- after the tree that owned it is gone. See CampPoseLastAt.
        self.CampPoseLastAt[ws] = now
    else
        self.CampPoseAt[ws] = nil
    end

    -- No longer a camp actor at all (his role was stripped, or a siege has started).
    if not self:IsCampActor(ws) then data.campYield = true; return end

    -- Or he has a fight on: a target of his own, one handed to him, or one he is claiming.
    if self:CampHasFightTarget(ws) then data.campYield = true end
end

-- Forced dialogue AT THE PLAYER, run from camp_actor exactly the way the two-NPC gossip is.
--
-- The gossip arm proves the shape: Function_speech_schedulerPolylog_initiator with a Decision
-- ALIAS, a participants array and a matching metarole. Aim that at the player instead of at
-- another merc and it is a forced conversation - the Skald graph describes a dialogue but the
-- BT is what starts one, which is the thing five earlier attempts all missed.
--
-- _G.MercForceTalk[wuidStr] = { alias, meta, partnerMeta }, set from Lua; consumed once.
-- NB: this must NOT clear alxForce. It used to, and that alone would have killed the arm even
-- with everything else right: the guard sits in a ContinuousSwitch, so clearing the flag on the
-- next poll turned the condition false again and tore the dialogue down before a line played.
-- Raised here, lowered only by ForceTalkDone once the speech has finished.
function mercenaries:ForceTalkRole(data, entity)
    local w = entity and entity.this and entity.this.id
    if not w then return end
    local req = _G.MercForceTalk and _G.MercForceTalk[tostring(w)]
    if not req then return end
    data.alxAlias = req.alias
    data.alxForce = true
end

-- Scheduler side: peek without consuming - the interrupt must fire before the behaviour that
-- consumes the request can run at all.
--
-- Each request carries a seq. A seq the tree has not seen yet re-arms fdFired, so a NEW request
-- always fires even if the PREVIOUS dialogue failed. Without that, one failed dialogue wedged
-- the whole system forever: a failing RequestDialog skips ForceTalkDone, the stale request keeps
-- fdWant true, and the scheduler's "reset once nothing is wanted" arm never runs.
function mercenaries:ForceTalkWanted(data, entity)
    local w = entity and entity.this and entity.this.id
    local req = w and _G.MercForceTalk and _G.MercForceTalk[tostring(w)]
    data.fdWant = req ~= nil
    if req and req.seq ~= data.fdSeen then
        data.fdSeen = req.seq
        data.fdFired = false
    end
end

-- Consumed at FIRE time, not at finish time, so a dialogue that fails cannot leave the request
-- behind and block every later one.
function mercenaries:ForceTalkPull(data, entity)
    local w = entity and entity.this and entity.this.id
    local req = w and _G.MercForceTalk and _G.MercForceTalk[tostring(w)]
    if not req then data.alxAlias = ""; return end
    data.alxAlias = req.alias or ""
    data.alxPreset = req.preset or 1
    _G.MercForceTalk[tostring(w)] = nil
    if req.altKey then _G.MercForceTalk[req.altKey] = nil end
end

function mercenaries:ForceTalkDone(data, entity)
    local w = entity and entity.this and entity.this.id
    if w and _G.MercForceTalk then _G.MercForceTalk[tostring(w)] = nil end
    data.alxForce = false
    data.fdWant = false
end

-- Key under BOTH wuid spaces: writers use GetMyWUID, every BT consumer reads entity.this.id.
-- They coincide for these NPCs today; mercenaries_raborsch.lua already hedges the same way.
function mercenaries:RequestForceTalk(wuid, alias, preset, altWuid)
    if not (wuid and alias) then return end
    _G.MercForceTalk = _G.MercForceTalk or {}
    _G.MercForceTalkSeq = (_G.MercForceTalkSeq or 0) + 1
    local k, ak = tostring(wuid), altWuid and tostring(altWuid) or nil
    local req = { alias = alias, preset = preset or 1, seq = _G.MercForceTalkSeq,
                  altKey = (ak ~= k) and ak or nil }
    _G.MercForceTalk[k] = req
    if req.altKey then _G.MercForceTalk[req.altKey] = req end
end

function mercenaries:IsCampActor(mercWuid)
    -- A besieger in a live, alerted siege is NEVER a camp actor, whatever the camp tables
    -- still say. Clearing all four of them left every man reading campActor=true, so one of
    -- the checks below draws on something this override does not need to identify: once the
    -- battle is on, camp_actor must not hold the interrupt slot, full stop.
    if self.RaborschIsFighting and self:RaborschIsFighting(mercWuid) then return false end

    -- A man being freed from a stuck pose IS a camp actor for the moment it takes, whatever
    -- else is true of him: camp_actor owns the rescue arm, and the scheduler only fires
    -- camp_actor at men this answers true for. Checked before everything else because it has
    -- to outrank "he holds no camp role" - that is precisely the state he is being rescued
    -- from. See PoseRescueAsk.
    if self:PoseRescueWanted(mercWuid) then return true end

    if self:GetCampActivity(mercWuid) ~= nil then return true end
    if self:IsCampGuard(mercWuid) then return true end
    -- Men marching in a column count too: camp_actor is the behaviour that carries the follow
    -- arm, and it only ever fires for those this returns true for.
    if self:IsColumnFollower(mercWuid) then return true end
    if self:GetCampFurniture(mercWuid) ~= nil then return true end
    -- Anyone holding the camp counts even between occupations. A member with no role at all
    -- used to fall through to the follow branch and walk out of camp after the player - that
    -- is what "the men I left behind trail after me" was. camp_actor's last arm just stands,
    -- and CampActorYield still drops him out the moment he has a fight.
    return self:CampIsMember(tostring(mercWuid))
end

-- Mercs who were mid-activity (sitting, eating, drilling at the dummies) when camp came down.
-- camp_actor only tests CampActorYield between activities, so the drill animation runs on for
-- a while after the tables are cleared - and a man in that state must not anchor the formation,
-- because everyone else follows him and the whole squad stands. Guards are excluded on purpose:
-- they are already on their feet and walking, so the leader comes from them.
-- See docs/camp.md, "Leaving camp: who leads".
mercenaries.CampBusyUntil       = {}     -- [wuidStr] = time he is trusted to march again
mercenaries.CampBusyRecoverSecs = 45.0

-- Snapshot the unfit. Must run BEFORE the camp role tables are cleared.
function mercenaries:MarkCampBusyMercs()
    local until_ = campNow() + self.CampBusyRecoverSecs
    for _, ent in pairs(self.ActiveMercs or {}) do
        local w  = ent and (ent.this and ent.this.id or ent.id)
        local ws = w and tostring(w)
        if ws and not self:IsCampGuard(w)
           and ((self.CampActivities and self.CampActivities[ws])
             or (self.CampFurniture and self.CampFurniture[ws])) then
            self.CampBusyUntil[ws] = until_
        end
    end
end

function mercenaries:IsCampBusy(wuid)
    local ws = tostring(wuid)
    local t  = self.CampBusyUntil[ws]
    if not t then return false end
    if campNow() >= t then self.CampBusyUntil[ws] = nil; return false end
    return true
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
-- the spot, or nil if the pool is full. `excludeTavern` skips tavern chairs
-- (snooze plays a stool-authored anim that looks wrong on a backed chair).
function mercenaries:ClaimSpot(pool, wuidStr, fromPos, excludeTavern)
    self:ReleaseSpot(pool, wuidStr)
    local free = {}
    for _, sp in ipairs(pool) do
        if not sp.occupant and not (excludeTavern and sp.tavern) then table.insert(free, sp) end
    end
    if #free == 0 then return nil end
    if fromPos or self.CampInn then
        table.sort(free, function(a, b)
            -- With a tavern up, its seats (flagged tavern) rank first so sit/snooze
            -- fill the tables before the campfire logs.
            if self.CampInn then
                local at, bt = a.tavern and 1 or 0, b.tavern and 1 or 0
                if at ~= bt then return at > bt end
            end
            if not fromPos then return false end
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
    -- The camp-actor answer this merc feeds the formation just changed.
    if self.CampActorInvalidate then self:CampActorInvalidate(wuidStr) end
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
        -- Tavern chairs excluded: camper_snooze is stool-authored and fights the
        -- backed chair's helper. Snoozers doze on the campfire logs instead.
        local seat = self:ClaimSpot(self.CampSeats, wuidStr, from, true)
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

    -- The seat and bed pools are shared and finite: a whole sortie coming back at once can
    -- find every log and bed taken, and a man left with neither furniture nor activity is no
    -- camp actor at all - he walks back out to the player. Give him something at his own spot,
    -- and report the role he actually got so the hold is timed by that one instead (a failed
    -- sleep claim must not park him on a 2-5 minute span doing nothing).
    if not self.CampFurniture[wuidStr] and not self.CampActivities[wuidStr] and s.actPos then
        self.CampActivities[wuidStr] = { unstance = "eating_standing", mode = 2, pos = s.actPos, facePos = s.firePos }
        s.lastPos = s.actPos
        return "eat"
    end
    return role
end

-- The cycle a given merc follows (trainers get a training-heavy one).
function mercenaries:CampCycleFor(wuidStr)
    local s = self.CampMercSpots and self.CampMercSpots[wuidStr]
    if s and s.isTrainer then return self.CampTrainerCycle end
    if self.CampInn then return self.CampTavernCycle end   -- tavern up: sit-heavy, no herbs
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

-- Bed-rest bias: an injured merc strongly prefers "sleep" over any other cycle
-- step, but this is a BIAS not a lock - ClaimSpot pulls a bed from the same
-- shared CampBeds pool as everyone else (see ApplyCampRole), so an injured
-- merc who rolls "sleep" and finds the pool full just falls through to
-- whatever ApplyCampRole gives him instead, and an uninjured merc can still
-- claim a bed whenever the injured one isn't already sitting on one.
-- mercenaries:LogiIsInjured is owned by mercenaries_logistics.lua and may not
-- exist yet on an old save - called defensively.
mercenaries.CampInjuredSleepChance = 0.85

function mercenaries:CampRoleWithInjuryBias(role, wuidStr)
    if role == "sleep" or not wuidStr then return role end
    local hurt = false
    pcall(function() hurt = mercenaries.LogiIsInjured and mercenaries:LogiIsInjured(wuidStr) or false end)
    if hurt and math.random() < self.CampInjuredSleepChance then return "sleep" end
    return role
end

-- Night-watch lamps around the guard perimeter: mesh + a real Light entity
-- (a bare mesh has no light source of its own - same two-piece technique the
-- bandit-camp builder's own "torch / lamp" catalogue entry uses, see
-- mercenaries_banditcamp.lua), spawned once at camp build (CampSpawnNightLights)
-- and shown/hidden with CampIsNight via DrawSlot(0,0)/(0,1) - the invisible-
-- collider trick from mercenaries_gate.lua - rather than respawned every dusk.
mercenaries.CampNightLightModel = "objects/manmade/common_illumination/lamp_table_rustic_a.cgf"
mercenaries.CampNightLightProps = {
    Radius = 4.0, fAttenuationBulbSize = 0.4,
    Color = { clrDiffuse = { x = 0.85, y = 0.42, z = 0.15 }, fDiffuseMultiplier = 0.08 },
    Options = { fVerticalClipDistanceDownward = 3, fVerticalClipDistanceUpward = 11 },
    Shadows = { nCastShadows = 2 },
}
mercenaries.CampNightLightZ = 1.2
mercenaries.CampNightLightCount = 6      -- lamps spread around the perimeter, not one per guard
mercenaries.CampNightLights = {}         -- { { meshId=, lightId= }, ... } - built once per camp
mercenaries.CampNightLightsOn = nil      -- last-applied state, so the toggle only runs on a real change

-- Builds the lamp ring at camp build time, reusing the perimeter positions
-- the guards themselves already patrol (self.CampPatrollers' own waypoints,
-- populated just above this call in SpawnMercCamp) rather than recomputing
-- geometry. Falls back to a plain ring around `center` for a squad too small
-- to have any guards at all.
function mercenaries:CampSpawnNightLights(center)
    self.CampNightLights = {}
    self.CampNightLightsOn = nil

    local ok, err = pcall(function()
        local ring = {}
        for _, rec in pairs(self.CampPatrollers or {}) do
            for _, wp in ipairs(rec.waypoints or {}) do table.insert(ring, wp) end
        end
        if #ring == 0 then
            for w = 1, self.CampNightLightCount do
                -- select(1, ...): the snap answers with a validity flag too, and a bare
                -- call in the last argument slot would hand every one of them to insert.
                table.insert(ring, (self:CampSnapToGround(select(1, self:CampRingPos(center,
                    self:CampTentRing() + self.CampPatrolTentClearance, w, self.CampNightLightCount, 0)))))
            end
        end

        local step = math.max(1, math.floor(#ring / self.CampNightLightCount))
        local placed = 0
        for i = 1, #ring, step do
            if placed >= self.CampNightLightCount then break end
            local pos = ring[i]
            local mesh = self:SpawnCampPropModel(self.CampNightLightModel, pos, math.random() * 2 * math.pi, "MercCampProp_NightLamp")
            local lightEnt
            pcall(function()
                lightEnt = System.SpawnEntity({
                    class = "Light",
                    name = "MercCampProp_NightLampLight_" .. tostring(math.random(100000, 999999)),
                    position = { x = pos.x, y = pos.y, z = pos.z + self.CampNightLightZ },
                    properties = mercenaries:NoSaveProps(self.CampNightLightProps),
                })
                if lightEnt then table.insert(self.CampEntities, lightEnt.id) end
            end)
            if mesh then
                table.insert(self.CampNightLights, { meshId = mesh.id, lightId = lightEnt and lightEnt.id or nil })
                placed = placed + 1
            end
        end

        self:CampApplyNightLightState(self:CampIsNight())
    end)
    if not ok then
        System.LogAlways('[Mercenaries] CampSpawnNightLights error: ' .. tostring(err))
    end
end

-- Shared by CampSpawnNightLights (initial state) and CampNightWatchTick
-- (nightly toggle): DrawSlot(0,0) hides the render slot on both the lamp mesh
-- and its Light entity, DrawSlot(0,1) restores it - no respawn either way.
function mercenaries:CampApplyNightLightState(night)
    for _, rec in ipairs(self.CampNightLights or {}) do
        if rec.meshId then
            local e = System.GetEntity(rec.meshId)
            if e then pcall(function() e:DrawSlot(0, night and 1 or 0) end) end
        end
        if rec.lightId then
            local e = System.GetEntity(rec.lightId)
            if e then pcall(function() e:DrawSlot(0, night and 1 or 0) end) end
        end
    end
    self.CampNightLightsOn = night
end

-- Guard torches: CreateItem+EquipItem into the dedicated Torch weapon slot at
-- night (the same conjuring trick the camp forge smith uses on his sword -
-- see mercenaries_forge.lua / docs/camp-forge.md), stripped again at dawn.
-- torch_weapon is a real vanilla MeleeWeapon on its own equip_slot="Torch"
-- (weapon_class.xml id 11, distinct from a guard's own drawn weapon slot) -
-- GUID confirmed in item.xml. UNVERIFIED IN THIS MOD: whether it reads right
-- held by a WALKING/patrolling NPC - the one proven held-item precedent
-- (camper_knifeSharpening) is seated, not walking. CampNightTorchEnabled is a
-- one-line revert if it doesn't. There is no proven weapon UnEquipItem path
-- in this codebase either, so dawn strips it by deleting the conjured
-- instance outright (inventory:RemoveItem) rather than trying to un-equip it.
mercenaries.CampNightTorchEnabled = true
mercenaries.CampTorchItemGUID = "4cea28a0-0814-405a-bf24-4fd711f7eb63"  -- torch_weapon (item.xml)
mercenaries.CampGuardTorch = {}   -- [wuidStr] = true while that guard holds the conjured torch
-- How many may burn at once. Every lit torch is a MOVING, SHADOW-CASTING dynamic light with
-- a fire emitter - on the author's 5080 that is invisible, on a mid-range card a fistful of
-- them in a town at night is milliseconds of GPU per frame, scaling 1:1 with squad size. The
-- verified user report ("4-5 mercs cost 40-50fps in dense areas", weaker hardware hit
-- hardest) is consistent with exactly this shape. Two torches light a marching column enough
-- to read as "the company carries light" without turning the squad into a chandelier; camp
-- guards get priority for them. merc_torches N to taste, 0 = none (and strips).
mercenaries.CampTorchMax = 2

-- EVERY living merc, not just the camp guards, and with or without a camp standing:
-- a company on a road after dark should be carrying light too, which is what the
-- lamps at the guard posts cannot do. Driven from the main monitor tick rather than
-- the camp one for exactly that reason; `night` is worked out here when the caller
-- does not pass it.
function mercenaries:CampNightTorchTick(night)
    if not self.CampNightTorchEnabled or (self.CampTorchMax or 0) <= 0 then return end
    if _G.MercenariesDismissed then return end
    if night == nil then night = self:CampIsNight() end
    local ok, err = pcall(function()
        -- Count what already burns, and strip anything past the cap (the cap can be
        -- lowered mid-night by merc_torches).
        local burning = 0
        for _ in pairs(self.CampGuardTorch) do burning = burning + 1 end

        -- Two passes so camp guards get the lit torches first: a guard on a dark
        -- perimeter is the man the feature exists for; the marching column shares
        -- whatever the cap has left.
        local passes = { true, false }
        for _, guardsOnly in ipairs(passes) do
        for _, ent in pairs(self.ActiveMercs or {}) do
            if ent and self:IsAliveAndWell(ent, false) then
                local ka = self:CampMercKeys(ent)
                if ka then
                    local isGuard = false
                    pcall(function() isGuard = self:IsCampGuard(ka) and true or false end)
                    local has = self.CampGuardTorch[ka]
                    if night and not has and burning < self.CampTorchMax
                       and (isGuard == guardsOnly) and ent.inventory and ent.actor then
                        local id
                        pcall(function() id = ent.inventory:FindItem(self.CampTorchItemGUID) end)
                        if not id then
                            pcall(function() ent.inventory:CreateItem(self.CampTorchItemGUID, 1, 1) end)
                            pcall(function() id = ent.inventory:FindItem(self.CampTorchItemGUID) end)
                        end
                        if id then
                            local eq = pcall(function() ent.actor:EquipInventoryItem(id) end)
                            if eq then self.CampGuardTorch[ka] = true; burning = burning + 1 end
                        end
                    elseif has and ((not night) or burning > self.CampTorchMax) and ent.inventory then
                        local id
                        pcall(function() id = ent.inventory:FindItem(self.CampTorchItemGUID) end)
                        if id then pcall(function() ent.inventory:RemoveItem(id, -1) end) end
                        self.CampGuardTorch[ka] = nil
                        burning = burning - 1
                    end
                end
            end
        end
        end
    end)
    if not ok then
        System.LogAlways('[Mercenaries] CampNightTorchTick error: ' .. tostring(err))
    end
end

function mercenaries:CampTorchMaxSet(v)
    local n = tonumber(tostring(v or ''):match('%d+'))
    if not n then
        System.LogAlways('[Mercenaries] merc_torches <n> - lit torches at night, 0 = none (now: '
                         .. tostring(self.CampTorchMax) .. ')')
        return
    end
    self.CampTorchMax = n
    if n == 0 then pcall(function() self:CampStripAllTorches(true) end) end
    System.LogAlways('[Mercenaries] night torches capped at ' .. n)
end

-- Called from MonitorCamp every 5s tick: lamps toggle only on an actual
-- day/night change, torches are re-checked every tick (cheap - a handful of
-- guards) so a merc admitted to guard duty mid-night, or one who lost his
-- torch some other way, picks one up on the next pass rather than never.
function mercenaries:CampNightWatchTick()
    if not self.CampActive then return end
    local night = self:CampIsNight()
    if night ~= self.CampNightLightsOn then
        pcall(function() self:CampApplyNightLightState(night) end)
    end
    -- Torches are driven from the main monitor tick instead (they are not a camp
    -- feature); only the lamps are gated on a camp standing.
end

-- Strips every conjured guard torch and forgets who was holding one - called
-- wherever guard duty ends outright (camp broken, squad recalled) so a torch
-- never rides along into a sortie. inventory:RemoveItem deletes the conjured
-- instance, taking it out of the guard's hand along with it (see the note on
-- CampNightTorchTick above - there is no proven weapon un-equip call here).
-- `force` ignores the latch and asks the INVENTORY instead. The latch is plain Lua and does
-- not survive a load, while the torch does - it is a real item, equipped, saved with the merc.
-- So a squad that was lit at night and is reloaded in daylight has torches in hand and an
-- empty latch, and neither branch of CampNightTorchTick fires: `night and not has` is false
-- because it is day, `(not night) and has` is false because the latch is empty. The torches
-- then burn in daylight for the rest of the save. Eight moving, shadow-casting fire lights
-- that nothing will ever take away is a standing GPU cost with no gameplay behind it.
function mercenaries:CampStripAllTorches(force)
    if not force and not next(self.CampGuardTorch or {}) then return end
    local ok, err = pcall(function()
        for _, ent in pairs(self.ActiveMercs or {}) do
            if ent and ent.inventory then
                local ka, kb = self:CampMercKeys(ent)
                if force or (ka and self.CampGuardTorch[ka]) or (kb and self.CampGuardTorch[kb]) then
                    local id
                    pcall(function() id = ent.inventory:FindItem(self.CampTorchItemGUID) end)
                    if id then pcall(function() ent.inventory:RemoveItem(id, -1) end) end
                end
            end
        end
    end)
    if not ok then
        System.LogAlways('[Mercenaries] CampStripAllTorches error: ' .. tostring(err))
    end
    self.CampGuardTorch = {}
end

-- Called once per load, after the merc cache is rebuilt. Reconciles the latch with reality by
-- taking every torch off: the tick puts them straight back the same night, and the cost of
-- being wrong in this direction is one dark evening rather than a permanent daylight bonfire.
function mercenaries:CampTorchOnLoad()
    self.CampGuardTorch = {}
    pcall(function() self:CampStripAllTorches(true) end)
end

-- All-hands alarm: UpdateEnemyCache's own sweep is centred on the PLAYER
-- (EnemyScanRadius/EnemyAlertRadius around player:GetPos(), see
-- mercenaries_target_selection.lua), so a camp under attack while the player
-- is elsewhere is never seen - CachedEnemies simply never contains anyone
-- near the camp, so no camp merc (guards included) ever acquires a target.
-- Runs off MonitorCamp's own 5s tick, gated hard: only when a camp exists and
-- only once the player is further out than the squad's own alert reach (i.e.
-- the player's own scan could not already be covering the camp). Feeds
-- validated (IsValidEnemy - same hostility rules as everywhere else)
-- candidates straight into the shared CachedEnemies pool in the exact shape
-- UpdateEnemyCache itself uses, so the ALREADY-WORKING per-merc acquisition
-- loop (ScanForEnemies -> EvaluateCombatTarget/PickCombatTarget ->
-- TryClaimTarget, mercenary_scheduler.xml's always-on Loop) picks them up on
-- its own next tick and sets MercTargetOf itself - which is what
-- CampActorYield already watches to pull a camp merc out of camp_actor and
-- into combat_melee. Deliberately does NOT write MercTargetOf/ForcedTargetOf
-- directly: TryClaimTarget sets MercTargetOf and $playerTarget together, in
-- the same BT tick, and setting MercTargetOf without that BT-side companion
-- would leave a camp merc's own $playerTarget stuck null forever - camp_actor
-- would yield on the stale claim every re-entry and never get anything else,
-- a permanent soft-lock instead of a fight.
mercenaries.CampAlarmRadius = 35.0

function mercenaries:CampWatchForAttack()
    if not (self.CampActive and self.CampCenter and player) then return end
    local ok, err = pcall(function()
        local c = self.CampCenter
        local pp = player:GetWorldPos()
        if not pp then return end
        local farAt = self.EnemyAlertRadius or 60.0
        local dx, dy = pp.x - c.x, pp.y - c.y
        if (dx * dx + dy * dy) <= (farAt * farAt) then return end   -- the player's own scan already reaches the camp

        local playerWuid = player.this and player.this.id or player.id
        local ents = System.GetPhysicalEntitiesInBoxByClass(c, self.CampAlarmRadius, "NPC")
        if not ents then return end

        self.CachedEnemies = self.CachedEnemies or {}
        for _, ent in pairs(ents) do
            if ent and type(ent) == "table" and ent.soul and self:IsValidEnemy(ent, nil, playerWuid) then
                local entWuid = ent.this and ent.this.id or ent.id
                local armed = (ent.human == nil) or ent.human:IsWeaponDrawn()
                local p = ent:GetPos()
                table.insert(self.CachedEnemies, { entity = ent, wuid = entWuid, armed = armed,
                    pos = p and { x = p.x, y = p.y, z = p.z } or nil })
            end
        end
    end)
    if not ok then
        System.LogAlways('[Mercenaries] CampWatchForAttack error: ' .. tostring(err))
    end
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
                self:CampRotateRole(wuidStr)
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
--
-- fraction 1.0 is "everybody you can spare": the camp keeps standing (and keeps its
-- pinned smith), it just empties. Both halves of the split are written here rather than
-- left to the next camp tick, so the shape behind you is right immediately.
function mercenaries:CampTakeParty(fraction)
    if not self.CampActive then
        Game.SendInfoText('merc_info_camp_not_active', false, 0, 3)
        return
    end
    fraction = fraction or 0.5

    -- Note who is mid camp-animation BEFORE their roles are torn down below - this reads
    -- CampActivities/CampFurniture, and the split loop clears them. BreakMercCamp and
    -- RecallMercs have always done this; deploying did not, and it is the one path where
    -- it matters most. A man pulled out of the practice yard or off a bench keeps playing
    -- his fragment for tens of seconds and cannot walk, and UpdateFormationLeader elects
    -- the merc NEAREST THE PLAYER - who, since the player is standing in his own camp when
    -- he deploys, is very often exactly that man. Anchor the formation on someone who
    -- cannot move and the whole out-party is stood up behind him. See docs/camp.md,
    -- "Leaving camp: who leads".
    pcall(function() self:MarkCampBusyMercs() end)

    local list = {}
    for name, ent in pairs(self.ActiveMercs) do
        if ent and self:IsAliveAndWell(ent, false) then
            local ka, kb = self:CampMercKeys(ent)
            -- Keep the pinned camp smith working at his forge: he is the one man
            -- "everybody you can spare" still spares.
            local isSmith = (ka and ka == self.CampForgeSmithWuid) or (kb and kb == self.CampForgeSmithWuid)
            if ka and not isSmith then
                table.insert(list, { ka = ka, kb = kb, ent = ent, name = name,
                                     tier = self:GetTierFromName(name) or "weak",
                                     archer = self:IsArcherName(name) or false })
            end
        end
    end
    local total = #list
    if total == 0 then return end
    local takeN = math.floor(total * fraction + 0.5)
    if takeN < 1 then takeN = 1 end
    if takeN > total then takeN = total end
    list = self:CampPickParty(list, takeN)

    -- Rebuild BOTH sides from scratch: the top takeN are the sortie, the rest hold the camp.
    -- The deployed men drop their camp assignment so they stop the activity and follow;
    -- the ones staying are re-rostered here so CampSyncRoster has nothing to repair.
    self.CampOutParty = {}
    self.CampRoster   = {}
    for i, m in ipairs(list) do
        for _, k in ipairs({ m.ka, m.kb }) do
            if k then
                if i <= takeN then
                    self.CampOutParty[k] = true
                    if self.CampActivities then self.CampActivities[k] = nil end
                    if self.CampFurniture then self.CampFurniture[k] = nil end
                    pcall(function() self:ReleaseSpot(self.CampSeats, k) end)
                    pcall(function() self:ReleaseSpot(self.CampBeds, k) end)
                else
                    self.CampRoster[k] = true
                end
            end
        end
        -- Coming back in off an earlier sortie: his role was stripped when he left, so give
        -- him one now rather than leaving him a follower until the next camp tick.
        if i > takeN and not self:IsCampGuard(m.ka)
           and not (self.CampActivities and self.CampActivities[m.ka])
           and not (self.CampFurniture and self.CampFurniture[m.ka]) then
            if self:CampEnsureSpot(m.ka) then self:CampRotateRole(m.ka) end
        end
    end
    if self.CampForgeSmithWuid then self.CampRoster[self.CampForgeSmithWuid] = true end
    if self.CampActorInvalidateAll then self:CampActorInvalidateAll() end
    self:SaveCampOutParty()

    -- THE DEPLOYED MEN ARE NOT CAMP-BUSY. MarkCampBusyMercs ran before the split, when
    -- they still held their roles, so it stamped them along with everyone else - and in a
    -- standing camp CampSyncRoster has given every non-guard an occupation, so that is the
    -- whole out-party. Leaving the stamp on is what stood the sortie up: the men left
    -- behind (the guards among them) are camp members and therefore not formation-eligible,
    -- so with the out-party marked busy too UpdateFormationLeader has no fit anchor at all
    -- and falls through to the busy tier. Whole-company deploys escape it because the
    -- guards come along, and guards are never stamped. The stayers keep their stamp.
    --
    -- ...with one exception, and it is the man lying in a bed. "Cannot walk yet" is a guess
    -- for most of the stamp's subjects and a fact for him: he is inside a StanceElement, and
    -- until it unwinds the engine owns where he stands. Clear his stamp and he can be elected
    -- the formation anchor from a bed - the whole sortie then forms up on a man who is asleep.
    for k in pairs(self.CampOutParty) do
        if self.CampBusyUntil and not self:InCampPose(k) then self.CampBusyUntil[k] = nil end
    end

    -- A standing order outranks the formation squad-wide (see UpdateFormationRole's `off`
    -- chain), and "I want to take some men with me" means following. BreakMercCamp and
    -- RecallMercs both clear all five; this path cleared none, so an order given before
    -- camping - or restored from the save - survived the deploy and switched the formation
    -- off for the party that had just been handed to the player.
    pcall(function() self:HoldEnd(true) end)
    pcall(function() self:EscortEnd(true) end)
    _G.MercIdle = false
    _G.MercPersistentIdleFlag = false
    self:SaveString("MercIdlePersistent", "0")

    -- Force each deployed man off his camp behaviour. camp_actor is an infinite loop that
    -- owns the interrupt slot once it has it, and a merc still unwinding a camp pose
    -- swallows the follow interrupt the scheduler fires at him - while the scheduler
    -- latches him "following" anyway, and its re-fire test is edge-triggered on the camp
    -- role, so it never tries again. That is the same transition the loot sweep has to
    -- force, and this is its cure: evict, stagger, verify (LootReleaseFinished).
    --
    -- A man mid-POSE is the one who must NOT be evicted on this tick. His camp role was
    -- cleared a few lines up, so CampActorYield already reads campYield for him and
    -- camp_actor is unwinding his StanceElement on its own; evicting him now tears that off
    -- instead, and an orphaned element keeps him pinned to the furniture with no tree left
    -- to end it. Hold his eviction for the length of the yield gate and he stands up first.
    local kicked, deferred = 0, 0
    for i, m in ipairs(list) do
        if i <= takeN and m.ent then
            local posed = self:InCampPose(m.ka)
            if posed then deferred = deferred + 1 end
            local wait = posed and self.CampPoseUnwindSecs or nil
            if pcall(function() self:FollowStalled(m.ent, wait) end) then kicked = kicked + 1 end
        end
    end
    if deferred > 0 then
        System.LogAlways(string.format(
            '[CampDeploy] %d deployed merc(s) were mid-pose - eviction held %.1fs so they stand up first',
            deferred, self.CampPoseUnwindSecs))
    end
    pcall(function() self:FollowStaggerSquad() end)
    -- Safe for the men staying behind: DismountVerify skips anyone IsCampActor answers for.
    pcall(function() self:BeginFollowVerify("camp deploy") end)

    self:CampFormationDirty("deploy")
    Game.SendInfoText('merc_info_camp_deployed', false, 0, 4)
    -- SquadSize/leader are printed straight after CampFormationDirty's re-election, so the
    -- log says whether the FORMATION actually saw the party that was just deployed. A
    -- deploy of six that lands on squad=0 is the whole "they revert to the follow chain"
    -- report in one line; merc_formation_status then breaks down which gate it was.
    System.LogAlways(string.format(
        '[CampDeploy] deployed %d/%d mercs (best tier first), %d left in camp, %d evicted from camp duty - formation squad=%d leader=%s',
        takeN, total, total - takeN, kicked, self.SquadSize or 0, tostring(self.FormationLeader)))
end

-- ==== What the party is made of ====
-- The deploy menu used to sort the whole company strong -> weak and take the top slice,
-- which meant a player could never take an archer out with him: archers are a separate
-- hire and never rank above a strong foot soldier, so any fraction short of "everyone"
-- left every one of them in camp. The quartermaster now takes two standing orders - how
-- much of the party should be archers, and whether the foot should be the best men or the
-- greenest - and CampPickParty fills the slots to match.
--
-- Both settings live in LogiState so they persist, and both apply to every fraction.
mercenaries.CampArcherShare = {   -- deployArchers -> share of the party, nil = same mix as the company
    same = nil, none = 0.0, quarter = 0.25, half = 0.5, all = 1.0,
}

-- One token, one handler: the AMOUNT the dialog grants is the option index.
mercenaries.CampCompositionOptions = {
    { field = "deployArchers", value = "same",    text = 'merc_info_comp_arch_same' },
    { field = "deployArchers", value = "none",    text = 'merc_info_comp_arch_none' },
    { field = "deployArchers", value = "quarter", text = 'merc_info_comp_arch_quarter' },
    { field = "deployArchers", value = "half",    text = 'merc_info_comp_arch_half' },
    { field = "deployArchers", value = "all",     text = 'merc_info_comp_arch_all' },
    { field = "deployPick",    value = "best",    text = 'merc_info_comp_foot_best' },
    { field = "deployPick",    value = "mixed",   text = 'merc_info_comp_foot_mixed' },
    { field = "deployPick",    value = "green",   text = 'merc_info_comp_foot_green' },
}

function mercenaries:CampSetComposition(which)
    local opt = self.CampCompositionOptions[tonumber(which) or 0]
    if not opt then
        System.LogAlways("[CampDeploy] composition: no option at index " .. tostring(which))
        return
    end
    local L = self:LogiState()
    L[opt.field] = opt.value
    self:LogiSave()
    Game.SendInfoText(opt.text, false, 0, 4)
    System.LogAlways("[CampDeploy] composition: " .. opt.field .. " = " .. opt.value)
end

-- Reorder `list` so its first `takeN` entries are the party the player asked for. The
-- return is the whole list, still complete - CampTakeParty needs the tail to re-roster
-- the men who stay - just resorted so the cut lands in the right place.
function mercenaries:CampPickParty(list, takeN)
    local L = self:LogiState()
    local pick  = L.deployPick or "best"
    local share = L.deployArchers or "same"

    local function tierRank(t) if t == "strong" then return 0 elseif t == "medium" then return 1 else return 2 end end
    -- "mixed" wants a spread of tiers rather than a block of one, so it is ordered by a
    -- shuffle instead of by tier; "green" is "best" read backwards (keep the veterans in
    -- camp and blood the new men).
    local order
    if pick == "green" then
        order = function(a, b) return tierRank(a.tier) > tierRank(b.tier) end
    elseif pick == "mixed" then
        order = nil
    else
        order = function(a, b) return tierRank(a.tier) < tierRank(b.tier) end
    end

    local archers, foot = {}, {}
    for _, m in ipairs(list) do
        table.insert(m.archer and archers or foot, m)
    end
    local function arrange(t)
        if order then table.sort(t, order)
        else
            for i = #t, 2, -1 do
                local j = math.random(i); t[i], t[j] = t[j], t[i]
            end
        end
        return t
    end
    arrange(archers); arrange(foot)

    -- How many of the slots go to archers. "same" keeps the company's own ratio, which is
    -- the least surprising default and on its own fixes "I can never take an archer".
    local wantArchers
    local frac = self.CampArcherShare[share]
    if share == "same" or frac == nil then
        wantArchers = math.floor(takeN * (#archers / math.max(1, #list)) + 0.5)
    else
        wantArchers = math.floor(takeN * frac + 0.5)
    end
    wantArchers = math.max(0, math.min(wantArchers, #archers, takeN))
    -- Whatever the archers cannot fill, the foot does, and the other way round.
    local wantFoot = math.min(takeN - wantArchers, #foot)
    wantArchers = math.min(#archers, takeN - wantFoot)

    local out = {}
    for i = 1, wantArchers do table.insert(out, archers[i]) end
    for i = 1, wantFoot do table.insert(out, foot[i]) end
    for i = wantArchers + 1, #archers do table.insert(out, archers[i]) end
    for i = wantFoot + 1, #foot do table.insert(out, foot[i]) end
    System.LogAlways(string.format(
        "[CampDeploy] composition: archers=%s foot=%s -> %d archer(s) + %d foot of %d",
        share, pick, wantArchers, wantFoot, takeN))
    return out
end

-- ==== Picking your party man by man ====
-- The Deploy menu only ever takes a FRACTION, best tier first, so a player who wanted
-- one particular man - an archer, say, who is never "best" by tier - had no way to ask
-- for him. These two are that way: walk up to a man and tell him, and only him, to come
-- along or to stay. Neither touches the camp, so the tents keep standing either way.
--
-- The deploy half does by hand what CampTakeParty does in bulk for the men it takes:
-- drop the camp role, release the shared seat/bed spot, clear the busy stamp, and EVICT
-- the camp behaviour rather than asking it to stop (camp_actor owns the interrupt slot -
-- see docs/camp.md, "The partial deploy needed three more things").
function mercenaries:CampDeployOne(ent)
    if not self.CampActive then
        Game.SendInfoText('merc_info_camp_not_active', false, 0, 3)
        return false
    end
    local ka, kb = self:CampMercKeys(ent)
    if not ka then return false end
    if self:IsCampOut(ka) then return false end

    -- Read BEFORE the role tables are torn down, the same ordering MarkCampBusyMercs needs.
    local posed = self:InCampPose(ka)

    for _, k in ipairs({ ka, kb }) do
        if k then
            self.CampOutParty[k] = true
            if self.CampRoster then self.CampRoster[k] = nil end
            if self.CampActivities then self.CampActivities[k] = nil end
            if self.CampFurniture then self.CampFurniture[k] = nil end
            -- A man inside a StanceElement genuinely cannot walk yet, and an anchor that
            -- cannot walk stands the squad. This path never ran MarkCampBusyMercs, so the
            -- stamp has to be laid rather than kept - and only for as long as standing up
            -- takes, not the 45s a broken camp allows. See CampTakeParty.
            if self.CampBusyUntil then
                self.CampBusyUntil[k] = posed and (campNow() + self.CampPoseUnwindSecs) or nil
            end
            if self.CampPatrollers then self.CampPatrollers[k] = nil end
            pcall(function() self:ReleaseSpot(self.CampSeats, k) end)
            pcall(function() self:ReleaseSpot(self.CampBeds, k) end)
        end
    end

    -- A standing hold/wait order switches the formation off squad-wide, and asking a man
    -- to come with you means following - the same clear CampTakeParty does.
    pcall(function() self:HoldEnd(true) end)
    pcall(function() self:EscortEnd(true) end)
    _G.MercIdle = false
    _G.MercPersistentIdleFlag = false
    self:SaveString("MercIdlePersistent", "0")

    if self.CampActorInvalidateAll then self:CampActorInvalidateAll() end
    -- Mid-pose men are deferred, not evicted - see the same call in CampTakeParty.
    pcall(function() self:FollowStalled(ent, posed and self.CampPoseUnwindSecs or nil) end)
    pcall(function() self:FollowStaggerSquad() end)
    pcall(function() self:BeginFollowVerify("camp deploy one") end)
    self:SaveCampOutParty()
    -- NO CampFormationDirty here. It nulls the leader and forces a re-election, and one
    -- session of picking men out one at a time did that seven times - every rebuild drops
    -- the squad onto the chain until everyone re-slots, which then reads as a squad full of
    -- stalled mercs. UpdateFormationLeader grows the preset the moment `followers > cap`,
    -- so a single man joining is picked up on the next pass for free.
    System.LogAlways("[CampDeploy] " .. tostring(ent and ent.GetName and ent:GetName()) .. " joined the party")
    return true
end

-- The reverse: this man alone goes back to camp life. Teleported in only if he is
-- actually away from it - told to stay while standing in the middle of the camp, he just
-- picks up a camp role where he is, with no blink.
function mercenaries:CampStayOne(ent)
    if not self.CampActive then return false end
    local ka, kb = self:CampMercKeys(ent)
    if not ka then return false end
    if not self:IsCampOut(ka) then return false end

    for _, k in ipairs({ ka, kb }) do
        if k then self.CampOutParty[k] = nil end
    end
    self:CampAdmitToCamp(ent, ka)

    local far = true
    pcall(function()
        local c, ep = self.CampCenter, ent:GetWorldPos()
        if c and ep then
            local dx, dy = ep.x - c.x, ep.y - c.y
            far = (dx * dx + dy * dy) > (self.CampJoinRadius * self.CampJoinRadius)
        end
    end)
    if far then self:CampTeleportToCamp(ent, ka) end

    if self.CampActorInvalidateAll then self:CampActorInvalidateAll() end
    self:SaveCampOutParty()
    -- Same as CampDeployOne: the shrink is noticed on its own, no rebuild needed.
    System.LogAlways("[CampDeploy] " .. tostring(ent and ent.GetName and ent:GetName()) .. " stayed in camp")
    return true
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
    if not self.CampActive then
        self.CampOutParty = {}
        pcall(function() self:SaveCampOutParty() end)
        return
    end
    _G.MercReturnPending = _G.MercReturnPending or {}
    local any = false
    for name, ent in pairs(self.ActiveMercs) do
        -- Keyed by the ENTITY id (what the bark lookup and every BT consumer read), and the
        -- out-party is checked under both ids so nobody can be stranded out by a key mismatch.
        local ka, kb = self:CampMercKeys(ent)
        local out = (ka and self.CampOutParty[ka]) or (kb and self.CampOutParty[kb])
        if ka and out and not _G.MercReturnPending[ka] then
            self:RequestBark(ka, "merc_bark_moveout")
            -- Stay out-party (following/running) during the countdown; ProcessReturnPending
            -- teleports and finalises when it hits 0. ~2 ticks = ~2s at the 1s cadence.
            _G.MercReturnPending[ka] = { ticks = 2, ent = ent }
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
    local returned = false
    for ws, rec in pairs(pend) do
        rec.ticks = (rec.ticks or 0) - 1
        if rec.ticks <= 0 then
            -- Admit, don't just un-deploy: clearing the out-party flag alone leaves a man who
            -- never had a camp role (a late hire, or anyone past the tent caps) with nothing to
            -- do, and he walks straight back out to the player. That was "sending them back
            -- doesn't work".
            self:CampAdmitToCamp(rec.ent, ws)
            self:CampTeleportToCamp(rec.ent, ws)
            pend[ws] = nil
            returned = true
        end
    end
    if returned then
        self:SaveCampOutParty()
        self:CampFormationDirty("return")
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
    local target
    for name, ent in pairs(self.ActiveMercs) do
        local ka, kb = self:CampMercKeys(ent)
        if ka == ws or kb == ws then target = ent break end
    end
    self:CampAdmitToCamp(target, ws)
    self:CampTeleportToCamp(target, ws)
    self:SaveCampOutParty()
    self:CampFormationDirty("return")
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

-- Drops the MERCS' conversations and nothing else. _G.MercCampChats is shared with the
-- bandit-camp contract, whose entries carry `foreign` and belong to a camp that has nothing
-- to do with the squad breaking or rebuilding theirs.
function mercenaries:ClearMercCampChats()
    local chats = _G.MercCampChats or {}
    for w, c in pairs(chats) do
        if not (c and c.foreign) then chats[w] = nil end
    end
    _G.MercCampChats = chats
end

-- Pairs up ALL eligible nearby mercs each 5s tick (concurrent conversations),
-- seeds staggered per-merc cooldowns once per camp, and ages out stuck pairs.
function mercenaries:CampChatTick()
    -- No merc camp: drop the MERCS' conversations, but leave anything flagged `foreign`.
    -- The bandit-camp contract publishes into this same table (its own pairing tick), and
    -- its camp stands whether or not the squad has pitched one - a blanket wipe here would
    -- have silenced it every tick.
    if not self.CampActive then
        local chats = _G.MercCampChats or {}
        for w, c in pairs(chats) do
            if not (c and c.foreign) then chats[w] = nil end
        end
        _G.MercCampChats = chats
        return
    end
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
        -- `foreign` entries belong to a bandit camp and are aged by its own tick, which runs
        -- at a different rate; ageing them here too would expire them early and at the wrong
        -- cadence.
        local expired = {}
        for w, c in pairs(chats) do
            if c.role == 1 and not c.foreign then
                c.age = (c.age or 0) + 1
                if c.age >= self.CampChatHoldTicks then table.insert(expired, w) end
            end
        end
        for _, w in ipairs(expired) do self:ClearCampChatPair(w) end

        -- Collect eligible mercs: alive, not already chatting, not on cooldown,
        -- not fighting, not mid-drill, with a position.
        -- A merc counts as "at the tavern" if its claimed seat / snooze anchor is
        -- one of the tavern seats - those get paired first (see below).
        local innSeats = self.CampInn and self.CampInn.seatWuidSet or nil
        local function atTavern(wuidStr)
            if not innSeats then return false end
            local f = self.CampFurniture and self.CampFurniture[wuidStr]
            if f and f.wuid and innSeats[tostring(f.wuid)] then return true end
            local a = self.CampActivities and self.CampActivities[wuidStr]
            if a and a.locWuid and innSeats[tostring(a.locWuid)] then return true end
            return false
        end
        local list = {}
        for _, ent in pairs(self.ActiveMercs) do
            -- Named companions do everything else a merc does in camp - they sit, they
            -- eat, they take a bed - but they are never paired into a conversation. The
            -- gossip pool is written for anonymous sellswords and plays on the soul's
            -- own voice. See IsHeroName.
            -- ...and the women, for the same reason: the gossip pool is a man's voice.
            -- They still sit, eat and take a bed like everyone else.
            if ent and self:IsAliveAndWell(ent, false)
               and not self:IsHero(ent) and not self:IsFemale(ent) then
                local wuid = ent.this and ent.this.id or ent.id
                local wuidStr = tostring(wuid)
                -- Deployed (sortie) mercs are following the player, not sitting in
                -- camp - they must never be pulled into a full-stop conversation
                -- (only monologs/barks for them). Skip them here.
                if not self:IsCampOut(wuidStr) then
                    local hasTarget = false
                    pcall(function() hasTarget = self.MercTargetOf and self.MercTargetOf[wuidStr] ~= nil end)
                    -- Track the combat flag for every eligible merc (even one already
                    -- chatting or on cooldown) so the falling edge is never missed, then
                    -- catch it the tick a target clears and seed the stagger cooldown.
                    if hasTarget then
                        self.MercCampCombatFlag[wuidStr] = true
                    elseif self.MercCampCombatFlag[wuidStr] then
                        self.MercCampCombatFlag[wuidStr] = nil
                        self.CampChatMercCooldown[wuidStr] = math.random(self.CampChatPostCombatCooldownMin, self.CampChatPostCombatCooldownMax)
                    end
                    if not chats[wuidStr] and not self.CampChatMercCooldown[wuidStr] then
                        local p = nil
                        pcall(function() p = ent:GetWorldPos() end)
                        local act = self.CampActivities[wuidStr]
                        local isTraining = act and act.unstance == "noob_sword_training"
                        if wuid and p and not hasTarget and not isTraining then
                            table.insert(list, { wuid = wuid, p = p, tav = atTavern(wuidStr) })
                        end
                    end
                end
            end
        end

        -- Count conversations already running (one role-1 entry per pair) so we
        -- never exceed CampMaxConcurrentChats camp-wide. A bandit camp's pairs live in this
        -- same table but must not eat the squad's budget - they have their own cap.
        local activePairs = 0
        for _, c in pairs(chats) do
            if c.role == 1 and not c.foreign then activePairs = activePairs + 1 end
        end

        -- Shuffle so pairings aren't biased by iteration order, then bring the
        -- tavern-seated mercs to the front so they pair first (conversations are
        -- more likely at the tables). A tavern also raises the concurrent cap.
        for i = #list, 2, -1 do
            local j = math.random(i)
            list[i], list[j] = list[j], list[i]
        end
        table.sort(list, function(a, b) return (a.tav and 1 or 0) > (b.tav and 1 or 0) end)
        local cap = self.CampMaxConcurrentChats + (self.CampInn and 2 or 0)
        local r2 = self.CampChatRadius * self.CampChatRadius
        local used = {}
        for i = 1, #list do
            if activePairs >= cap then break end
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
-- camp_actor.xml each patrol step to pick the next Move destination
-- (which is a vec3, not an entity - see the guard-assignment loop in
-- SpawnMercCamp for why).
-- Returns where the guard should walk NEXT, which is not always the waypoint itself:
-- when a camp wall stands between him and it, this hands back the next corner of a
-- route around instead, and AdvancePatrolWaypoint holds the ring index until the real
-- waypoint is reached. A waypoint that is walled off with no route at all is skipped,
-- so a wall drawn across the patrol ring cannot park a guard forever.
-- True for a man who should walk his route without the sentry pause between waypoints -
-- the lead of a marching column. A sentry pacing a beat pauses; a column does not.
function mercenaries:IsPatrolNoPause(mercWuid)
    local rec = self.CampPatrollers and self.CampPatrollers[tostring(mercWuid)]
    return (rec ~= nil) and (rec.noPause == true)
end

function mercenaries:GetPatrolWaypoint(mercWuid)
    if self:IsCampOut(mercWuid) then return nil end
    local rec = self.CampPatrollers and self.CampPatrollers[tostring(mercWuid)]
    if not rec or not rec.waypoints or #rec.waypoints == 0 then return nil end

    local wp = rec.waypoints[rec.index]
    rec.onDetour = false
    if not (wp and self.NavSteerPoint and (self:WallHasAny() or self:NavHasObstacles())) then return wp end

    local ent, me
    pcall(function() ent = XGenAIModule.GetEntityByWUID(mercWuid) end)
    if ent then pcall(function() me = ent:GetWorldPos() end) end
    if not me then return wp end

    if not self:NavPathBlocked(me, wp) then
        rec.nav = nil
        return wp
    end

    rec.nav = rec.nav or {}
    local p = self:NavSteerPoint(rec.nav, me, wp)
    if p and (p.x ~= wp.x or p.y ~= wp.y) then
        rec.onDetour = true
        return p
    end

    -- Nothing came back. Only a WALL with no route round it is worth dropping a
    -- waypoint for: a tent he could not round this tick is not, or he would shed points
    -- off his ring for a prop he will be clear of in a second.
    if not self:NavIsBlocked(me, wp) then return wp end
    rec.index = (rec.index % #rec.waypoints) + 1
    rec.nav = nil
    return rec.waypoints[rec.index]
end

-- Is this guard being walked round a wall right now? GetPatrolWaypoint sets rec.onDetour
-- when it hands back a NavSteerPoint corner instead of the waypoint itself. Read by
-- mercenaries_solid.lua, which otherwise asks only IsNavGotoActive and concludes that nothing
-- is routing a sentry the mod is in fact routing.
function mercenaries:IsPatrolDetouring(mercWuid)
    local rec = self.CampPatrollers and self.CampPatrollers[tostring(mercWuid)]
    return (rec ~= nil) and (rec.onDetour == true)
end

-- Drop the waypoint this guard cannot reach and move him on. For a camp actor this replaces
-- being handed through the wall: his reroute can never be granted (the scheduler's detour arm
-- is gated ~$isCampActor), so the alternative was a phase-through on a fixed timer.
function mercenaries:PatrolSkipWaypoint(mercWuid)
    local rec = self.CampPatrollers and self.CampPatrollers[tostring(mercWuid)]
    if not rec or not rec.waypoints or #rec.waypoints < 2 then return false end
    rec.index = (rec.index % #rec.waypoints) + 1
    rec.nav, rec.onDetour = nil, false
    return true
end

-- Advances a guard to the next waypoint in their loop. Called from
-- camp_actor.xml once a Move to the current waypoint completes.
function mercenaries:AdvancePatrolWaypoint(mercWuid)
    local rec = self.CampPatrollers and self.CampPatrollers[tostring(mercWuid)]
    if not rec or not rec.waypoints or #rec.waypoints == 0 then return end
    -- Mid-detour the guard has only finished a LEG, not the waypoint - advancing here
    -- would walk him one corner round the wall and then skip the point entirely.
    if rec.onDetour then return end
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

-- The camp upgrades that want a grid tile of their own this camp, in placement
-- order. Each is treated exactly like a campfire cluster: its own tile, same
-- spacing, same footprint validation - which is what stops them overlapping each
-- other and the tents. The practice yard has the reserved (0,-1) tile and the
-- house replaces the (0,0) player tent, so neither is listed here.
-- Camp upgrades are bought through the quartermaster, which rebuilds the whole
-- camp (see the LogiBuy* functions) so this list is re-read and the grid re-tiled.
mercenaries.CampStationTiles = {}   -- [name] = { x, y, z, ang } while camped

function mercenaries:CampActiveStations()
    local list = {}
    local L
    pcall(function() L = self.LogiState and self:LogiState() end)
    if not L then return list end
    if L.hasSmithy then table.insert(list, "forge") end
    if L.hasAlchemy then table.insert(list, "alchemy") end
    if (L.hunterSpots or 0) > 0 then table.insert(list, "hunt") end
    if L.innActive then table.insert(list, "inn") end
    if (L.foodCartDays or 0) > 0 then table.insert(list, "cart") end
    if L.hasTrader then table.insert(list, "trader") end
    return list
end

-- The tile reserved for `name` this camp: a position + the outward facing (away
-- from the camp centre). nil if the station has no tile, in which case its own
-- spawn falls back to scanning for a flat patch.
-- Where the player PUT a station, as opposed to where the camp would have put it. Keyed by
-- the same station names as CampStationTiles and read in preference to them, so one entry
-- here overrides the automatic layout for that one improvement and leaves the rest alone.
--
-- Tied to the camp anchor exactly as the automatic tiles are: a spot chosen around one camp
-- means nothing around a camp pitched somewhere else, so moving camp drops them and the
-- automatic layout takes over again.
mercenaries.CampPlacedSpots = mercenaries.CampPlacedSpots or {}

-- Tent rings the player moved, by ring number. Same anchor rule as the station spots.
mercenaries.CampCirclePlaced = mercenaries.CampCirclePlaced or {}

-- Where the player put the training ground, if anywhere.
mercenaries.CampTrainPlaced = mercenaries.CampTrainPlaced or nil

function mercenaries:CampSaveCircles()
    local t = {}
    for i, p in pairs(self.CampCirclePlaced or {}) do t["c" .. i] = p end
    if self.CampTrainPlaced then t["train"] = self.CampTrainPlaced end
    local packed = self:CampPackSpots(t)
    if packed then pcall(function() self:SaveString("MercCampCircles", packed) end) end
end

function mercenaries:CampLoadCircles(origin)
    local raw = self:LoadString("MercCampCircles")
    if not (raw and origin) then return {} end
    local head, body = string.match(raw, "^([^|]*)|(.*)$")
    if not head then return {} end
    local ax, ay = string.match(head, "([^,]+),([^,]+)")
    ax, ay = tonumber(ax), tonumber(ay)
    if not (ax and ay) then return {} end
    local dx, dy = origin.x - ax, origin.y - ay
    if (dx * dx + dy * dy) > (self.CampTileAnchorEps * self.CampTileAnchorEps) then return {} end
    local out = {}
    self.CampTrainPlaced = nil
    for chunk in string.gmatch(body or "", "[^;]+") do
        local name, rest = string.match(chunk, "^([^:]+):(.*)$")
        local x, y, z = string.match(rest or "", "([^,]+),([^,]+),([^,]+)")
        if name and x then
            local pos = { x = tonumber(x), y = tonumber(y), z = tonumber(z) }
            if name == "train" then
                self.CampTrainPlaced = pos
            else
                local i = tonumber(string.match(name, "^c(%d+)$") or "")
                if i then out[i] = pos end
            end
        end
    end
    return out
end

function mercenaries:CampStationSpot(name)
    local p = self.CampPlacedSpots and self.CampPlacedSpots[name]
    if p then return { x = p.x, y = p.y, z = p.z }, p.ang end
    local t = self.CampStationTiles and self.CampStationTiles[name]
    if not t then return nil end
    return { x = t.x, y = t.y, z = t.z }, t.ang
end

-- Both tables serialise the same way; the tag is the only difference.
function mercenaries:CampPackSpots(tbl)
    local o = self.CampBuildOrigin
    if not o then return nil end
    local out = {}
    for name, t in pairs(tbl or {}) do
        table.insert(out, string.format("%s:%.2f,%.2f,%.2f,%.4f", name, t.x, t.y, t.z or o.z, t.ang or 0))
    end
    table.sort(out)
    return string.format("%.2f,%.2f|%s", o.x, o.y, table.concat(out, ";"))
end

function mercenaries:CampSavePlacedSpots()
    local packed = self:CampPackSpots(self.CampPlacedSpots)
    if packed then pcall(function() self:SaveString("MercCampPlaced", packed) end) end
end

function mercenaries:CampLoadPlacedSpots(origin)
    local raw = self:LoadString("MercCampPlaced")
    if not (raw and origin) then return {} end
    local head, body = string.match(raw, "^([^|]*)|(.*)$")
    if not head then return {} end
    local ax, ay = string.match(head, "([^,]+),([^,]+)")
    ax, ay = tonumber(ax), tonumber(ay)
    if not (ax and ay) then return {} end
    local dx, dy = origin.x - ax, origin.y - ay
    if (dx * dx + dy * dy) > (self.CampTileAnchorEps * self.CampTileAnchorEps) then return {} end
    local out = {}
    for chunk in string.gmatch(body or "", "[^;]+") do
        local name, rest = string.match(chunk, "^([^:]+):(.*)$")
        if name then
            local x, y, z, a = string.match(rest, "([^,]+),([^,]+),([^,]+),([^,]+)")
            if x and y and z then
                out[name] = { x = tonumber(x), y = tonumber(y), z = tonumber(z),
                              ang = tonumber(a) or 0 }
            end
        end
    end
    return out
end

-- ==== Camp persistence ====
-- Where the player pitched camp: { x, y, z, ang }, saved with the game. The camp
-- itself is rebuilt rather than serialised (its props are runtime-spawned and
-- don't survive a save), so this anchor is all that's needed: on load - and on an
-- upgrade rebuild - SpawnMercCamp is handed this instead of the player's current
-- position, and the camp goes back exactly where it stood.
mercenaries.CampBuildOrigin = nil

-- Upgrade tiles are saved as well as the anchor, because they are NOT reproducible
-- from it. A tile is handed out from the grid cells the tent clusters did not take,
-- so it depends on the cluster count - which depends on how many men were alive and
-- cached at the moment the camp was laid out. Rebuild with one man fewer (or a merc
-- cache that is still filling four seconds after a load) and every station moves to
-- a different cell. That is the "upgrades shuffle around after a reload" report.
--
-- Stored as "anchorX,anchorY|name:x,y,z,ang;...". The anchor rides along so tiles
-- from the last pitch are discarded rather than dragged to a camp somewhere new,
-- the same rule mercenaries_defences.lua applies to walls and towers.
mercenaries.CampTileAnchorEps = 2.0

function mercenaries:CampPackStationTiles()
    local o = self.CampBuildOrigin
    if not o then return nil end
    local out = {}
    for name, t in pairs(self.CampStationTiles or {}) do
        table.insert(out, string.format("%s:%.2f,%.2f,%.2f,%.4f", name, t.x, t.y, t.z or o.z, t.ang or 0))
    end
    table.sort(out)   -- stable string, so SaveString can skip an unchanged rewrite
    return string.format("%.2f,%.2f|%s", o.x, o.y, table.concat(out, ";"))
end

-- The saved tiles, but only if they belong to the camp being pitched now.
function mercenaries:CampLoadStationTiles(origin)
    local raw = self:LoadString("MercCampTiles")
    if not (raw and origin) then return {} end
    local head, body = string.match(raw, "^([^|]*)|(.*)$")
    if not head then return {} end
    local ax, ay = string.match(head, "([^,]+),([^,]+)")
    ax, ay = tonumber(ax), tonumber(ay)
    if not (ax and ay) then return {} end
    local dx, dy = origin.x - ax, origin.y - ay
    if (dx * dx + dy * dy) > (self.CampTileAnchorEps * self.CampTileAnchorEps) then return {} end
    local out = {}
    for chunk in string.gmatch(body or "", "[^;]+") do
        local name, rest = string.match(chunk, "^([^:]+):(.*)$")
        if name then
            local x, y, z, a = string.match(rest, "([^,]+),([^,]+),([^,]+),([^,]+)")
            if x then
                out[name] = { x = tonumber(x), y = tonumber(y), z = tonumber(z), ang = tonumber(a) }
            end
        end
    end
    return out
end

function mercenaries:SaveCampState()
    local o = self.CampBuildOrigin
    if self.CampActive and o then
        self:SaveString("MercCampActive", "1")
        self:SaveString("MercCampX", tostring(o.x))
        self:SaveString("MercCampY", tostring(o.y))
        self:SaveString("MercCampZ", tostring(o.z))
        self:SaveString("MercCampAng", tostring(o.ang))
        local tiles = self:CampPackStationTiles()
        if tiles then self:SaveString("MercCampTiles", tiles) end
    else
        self:SaveString("MercCampActive", "0")
    end
end

-- The saved anchor, or nil if no camp was standing when the game was saved.
function mercenaries:LoadCampOrigin()
    if self:LoadString("MercCampActive") ~= "1" then return nil end
    local function num(tag) local s = self:LoadString(tag); return s and tonumber(s) end
    local x, y, z, a = num("MercCampX"), num("MercCampY"), num("MercCampZ"), num("MercCampAng")
    if not (x and y and z and a) then return nil end
    return { x = x, y = y, z = z, ang = a }
end

-- Put a saved camp back up after a load. Deferred until the merc cache exists
-- (SpawnMercCamp needs ActiveMercs to hand out tents) - see the load sequence in
-- mercenaries.lua.
--
-- RETRIES. This was a one-shot: if the merc cache was still empty at t+4s (the cache
-- rebuild is a name scan of LOADED NPCs, and streaming can be slower than 2s on the
-- machines that need this most), SpawnMercCamp bailed and nothing ever tried again -
-- the camp with every upgrade on it simply did not come back that session, while
-- MercCampActive stayed "1" so a LATER load restored it fine. That is the "upgrades
-- disappear after reloading, and sometimes reappear again" report. The try counter is
-- reset from OnGameplayStarted (it is plain Lua and would otherwise survive the load).
mercenaries.CampRestoreRetryMs  = 5000
mercenaries.CampRestoreRetryMax = 12

function mercenaries.RestoreCampDelayed()
    local self = mercenaries
    -- A region crossing is still walking the company back into the world (docs/regions.md).
    -- Pitching now would lay the camp out around whoever happens to be standing already and
    -- leave the rest of them outside it.
    if next(self.RegionSpawnQueue or {}) then
        Script.SetTimerForFunction(1000, "mercenaries.RestoreCampDelayed")
        return
    end
    local o = self:LoadCampOrigin()
    if not o or self.CampActive or _G.MercenariesDismissed then return end
    pcall(function() self:Recount() end)
    if not _G.MercCount or _G.MercCount <= 0 then
        self._campRestoreTries = (self._campRestoreTries or 0) + 1
        if self._campRestoreTries <= (self.CampRestoreRetryMax or 12) then
            System.LogAlways(string.format(
                "[Camp] restore waiting for the merc cache (try %d/%d)",
                self._campRestoreTries, self.CampRestoreRetryMax or 12))
            Script.SetTimerForFunction(self.CampRestoreRetryMs or 5000,
                                       "mercenaries.RestoreCampDelayed")
        else
            System.LogAlways("[Camp] restore gave up - no mercs ever registered this session"
                             .. " (the camp stays saved and restores on a later load)")
        end
        return
    end
    self.CampBuildOrigin = o
    local ok, err = pcall(function() self:SpawnMercCamp(o, true) end)
    if ok then System.LogAlways("[Camp] restored saved camp")
    else System.LogAlways("[Camp] restore failed: " .. tostring(err)) end
    -- Strictly after the rebuild: SpawnMercCamp empties CampOutParty and gives everyone a
    -- camp role, so the deployed party has to be put back on top of that, not before it.
    pcall(function() self:LoadCampOutParty() end)
end

-- ==== Where the camp gets pitched ====
-- The tent used to land wherever GetSafeSpawnPosition put it - about 7m BEHIND the
-- player, out of sight, so the camp was near enough impossible to aim. It is pitched
-- on the conversation partner instead: whoever the player just told to make camp is
-- standing exactly where the player wants the camp, and he walks into his own tent
-- rather than being teleported out of it.
--
-- The look-at prompt has the entity in hand and calls CampSetAnchorEnt; the Skald
-- dialog path has no such handle (a token arrives, the partner is not named), so the
-- partner is resolved by geometry: the nearest living squad member in front of the
-- player. Both are best-effort - no partner means the old behaviour.
mercenaries.CampPartnerMaxDist  = 7.0    -- a conversation partner is no further than this
mercenaries.CampPartnerMinDot   = 0.0    -- ... and no further round than 90 degrees off the player's facing
mercenaries.CampAnchorHoldSecs  = 20.0   -- how long an explicitly-set anchor entity stays valid

-- Remember the merc a camp order was given to. Called by the look-at prompt, which
-- knows exactly who was asked; the timestamp keeps a stale press from anchoring a
-- camp made minutes later from the console.
function mercenaries:CampSetAnchorEnt(ent)
    self.CampAnchorEnt = ent
    self.CampAnchorAt  = nil
    pcall(function() self.CampAnchorAt = System.GetCurrTime() end)
end

-- The spot the player's conversation partner is standing on, or nil.
function mercenaries:CampTalkPartnerPos()
    if not player then return nil end
    local pp, pdir
    pcall(function() pp = player:GetWorldPos() end)
    pcall(function() pdir = player:GetDirectionVector() end)
    if not pp then return nil end

    -- 1. The merc the order was actually given to (look-at prompt).
    local e = self.CampAnchorEnt
    if e then
        local now; pcall(function() now = System.GetCurrTime() end)
        local fresh = (not now) or (not self.CampAnchorAt)
                      or ((now - self.CampAnchorAt) <= self.CampAnchorHoldSecs)
        self.CampAnchorEnt, self.CampAnchorAt = nil, nil
        if fresh and self:IsAliveAndWell(e, true) then
            local ep; pcall(function() ep = e:GetWorldPos() end)
            if ep then return { x = ep.x, y = ep.y, z = ep.z } end
        end
    end

    -- 2. Dialog path: the nearest living squad member the player is facing. A
    -- conversation partner stands close and roughly ahead, so that is the whole test.
    local dl = pdir and math.sqrt(pdir.x * pdir.x + pdir.y * pdir.y) or 0
    local fx, fy = 0, 0
    if dl > 0.0001 then fx, fy = pdir.x / dl, pdir.y / dl end
    local maxD, best, bestScore = self.CampPartnerMaxDist, nil, nil
    for _, ent in pairs(self.ActiveMercs or {}) do
        if ent and self:IsAliveAndWell(ent, true) then
            local ep; pcall(function() ep = ent:GetWorldPos() end)
            if ep then
                local dx, dy = ep.x - pp.x, ep.y - pp.y
                local d = math.sqrt(dx * dx + dy * dy)
                if d > 0.05 and d <= maxD then
                    local dot = (dl > 0.0001) and ((dx / d) * fx + (dy / d) * fy) or 1.0
                    if dot >= self.CampPartnerMinDot then
                        -- Nearest wins, with a small bonus for being dead ahead so a man
                        -- squarely in front beats one a step closer off to the side.
                        local score = d - dot
                        if not bestScore or score < bestScore then bestScore, best = score, ep end
                    end
                end
            end
        end
    end
    if best then return { x = best.x, y = best.y, z = best.z } end
    return nil
end

-- Build the physical camp layout and teleport the squad in. Tent recipients (up
-- to CampMaxTents) are grouped into cells of CampClusterSize, each with its own
-- fire/seats/tents, tiled in a grid; mercs beyond the cap get an outer-ring bed.
-- `atOrigin` ({x,y,z,ang}) pitches the camp there instead of in front of the
-- player - used by the upgrade rebuild and the save restore, so neither drags the
-- camp to wherever the player happens to be standing. `silent` skips the
-- "camp made" text for those non-player-initiated builds.
-- See docs/camp.md for the full layout scheme.
function mercenaries:SpawnMercCamp(atOrigin, silent, allowSolo)
    if self.CampActorInvalidateAll then self:CampActorInvalidateAll() end
    if self.CampActive then
        Game.SendInfoText('merc_info_camp_already_active', false, 0, 3)
        return
    end
    if _G.MercenariesDismissed then
        Game.SendInfoText('merc_info_camp_no_squad', false, 0, 3)
        return
    end

    self:Recount()
    if not allowSolo and (not _G.MercCount or _G.MercCount <= 0) then
        Game.SendInfoText('merc_info_camp_no_squad', false, 0, 3)
        return
    end

    local ok, err = pcall(function()
        local center
        if atOrigin then
            center = { x = atOrigin.x, y = atOrigin.y, z = atOrigin.z }
        else
            -- "Make camp here" is said TO somebody, and that somebody is standing on
            -- the spot the player picked out - so the player tent goes exactly where
            -- he stands. GetSafeSpawnPosition (7m BEHIND the player) is only the
            -- fallback for the console command, where nobody was asked.
            center = self:CampTalkPartnerPos()
            if not center then center = self:GetSafeSpawnPosition(player, 7) end
            if not center then
                Game.SendInfoText('merc_info_camp_no_spot', false, 0, 3)
                return
            end
        end
        center = self:CampSnapToGround(center)
        -- A FRESH pitch first asks whether a camp fits here at all, and walks to the nearest
        -- ground it does fit on - or says there is none. A rebuild trusts its origin.
        if not atOrigin and self.CampFindSite then
            local site = self:CampFindSite(center)
            if not site then
                Game.SendInfoText('merc_info_camp_no_spot', false, 0, 3)
                return
            end
            center = self:CampSnapToGround(site)
        end
        -- Footprints an NPC has to walk around are registered as the props go down and
        -- rebuilt with the camp; they are never saved. See mercenaries_navmesh.lua.
        if self.NavClearObstacles then self:NavClearObstacles() end

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
        if mercCount == 0 and not allowSolo then
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
                + self:CampTentRing() + self.CampPatrolTentClearance
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

        -- Settle the tent ring for this camp before anything measures outward from it. The
        -- widest tent variant decides, not the constant: the tents sit with their LONG axis
        -- along the ring (see CampTentRingRadiusFor), so seven of tent_small_rustic_a at the
        -- nominal 3.9m lap each other by over a metre.
        self:CampClearClaims()
        local ringR, byArc, bySeats = self:CampTentRingRadiusFor(self.CampTentVariants,
                                                                 self.CampClusterTentRingSlots)
        self.CampTentRingR = ringR
        if ringR > self.CampTentRingRadius + 0.01 then
            System.LogAlways(string.format(
                '[Mercenaries] tent ring %.2fm (nominal %.2f): %.2f to give %d tents their arc, ' ..
                '%.2f to clear the fire seats',
                ringR, self.CampTentRingRadius, byArc, self.CampClusterTentRingSlots, bySeats))
        end

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
        -- A rebuild/restore reuses the saved angle so the layout comes back
        -- identical rather than swinging to wherever the player is now looking.
        -- Measured from the anchor TOWARD the player rather than from the player's
        -- look direction: both give the same axis back when the camp is pitched
        -- behind the player (the old behaviour), but only this one still points the
        -- tent's entrance at the player when the anchor is the man he is talking to,
        -- who stands in FRONT of him. The camp then grows away past that man instead
        -- of swallowing the player.
        local forward
        if atOrigin then
            -- An origin without a facing is legitimate (the camp screen hands over the
            -- player's position); nil here used to kill the whole pitch inside its pcall.
            local a0 = atOrigin.ang or 0
            forward = { x = math.cos(a0), y = math.sin(a0) }
        else
            local pp = player:GetWorldPos()
            local dx, dy = pp.x - center.x, pp.y - center.y
            local dl = math.sqrt(dx * dx + dy * dy)
            if dl > 0.5 then
                forward = { x = dx / dl, y = dy / dl }
            else
                local playerDir = player:GetDirectionVector()
                local dirLen = math.sqrt(playerDir.x * playerDir.x + playerDir.y * playerDir.y)
                forward = dirLen > 0.0001 and { x = playerDir.x / dirLen, y = playerDir.y / dirLen } or { x = 0, y = 1 }
            end
        end
        local right = { x = -forward.y, y = forward.x }
        local spacing = self.CampClusterSpacing
        -- A wider tent ring needs wider spacing between the clusters, or neighbouring rings
        -- grow into each other and it is the same overlap one tile further out.
        do
            local needSpacing = 2 * self:CampTentRing() + self.CampClusterGap
            if needSpacing > spacing then
                System.LogAlways(string.format(
                    '[Mercenaries] cluster spacing %.2fm -> %.2fm so the tent rings do not meet',
                    spacing, needSpacing))
                spacing = needSpacing
            end
        end

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
        -- Upgrades take a tile each on top of the clusters, so the map has to
        -- reach far enough to validate those cells too.
        local stationNames = self:CampActiveStations()
        local maxCellDist = 1
        for _, off in ipairs(self:CampGridOffsets(numClusters + #stationNames)) do
            local e = math.sqrt(off[1] * off[1] + off[2] * off[2])
            if e > maxCellDist then maxCellDist = e end
        end
        local mapRadiusM = math.min(self.CampMapMaxRadius,
            maxCellDist * spacing + self.CampTileHalf + self.CampCenterSearch + 1.0)
        local mapCells = math.max(8, math.floor(mapRadiusM / self.CampSampleStep + 0.5))
        local campMap = nil
        pcall(function() campMap = self:CampBuildMap(center, mapCells, underRoof) end)

        -- BOTH searches below run only on a FRESH pitch. On a rebuild at a given origin
        -- (a save restore, an upgrade rebuild) the anchor was settled by these same
        -- searches when the camp was first pitched, and re-running them re-derives the
        -- winner from a FRESH raycast map - which streaming differences flip, moving the
        -- centre up to ~2.8m per rebuild. Every consumer of the anchor compares with a
        -- 2.0m epsilon (CampTileAnchorEps, DefAnchorEps), so one drifted rebuild threw
        -- the pinned station tiles away and DefForget-ed the walls/towers/carts: that is
        -- BOTH halves of the "upgrades vanish after a reload / tents overlap the camp"
        -- report. A given origin is trusted verbatim.
        if not atOrigin then
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
        -- ...and not only the tent. The search used to score the player tent's own footprint
        -- and nothing else, over a two-metre square, so a camp asked for beside a stream
        -- bank put its tent on the one good patch and its tent RINGS wherever the grid fell:
        -- on the bank, in the scrub. Now every candidate centre is scored on the tent plus
        -- the cells the clusters and upgrades will need, over a wider square, and the whole
        -- camp shifts to where it fits. A camp is a place; the man who asked for it is a few
        -- metres from where it stands either way.
        if campMap then
            local bestC, bestScore, bestMoved = center, nil, 0
            local s, st = self.CampCenterSearch, self.CampCenterSearchStep
            local pf = self:CampPropFootHalf(self.CampPlayerTentModel)
            local need = math.min(4, numClusters + #stationNames)
            local cellOffs = {}
            for _, off in ipairs(self:CampGridOffsets(need + 2)) do
                if #cellOffs < need and not (off[1] == 0 and off[2] == 0) and not (off[1] == 0 and off[2] == 1) then
                    table.insert(cellOffs, off)
                end
            end
            local a = -s
            while a <= s + 1e-6 do
                local b = -s
                while b <= s + 1e-6 do
                    local cand = {
                        x = center.x + right.x * a + forward.x * b,
                        y = center.y + right.y * a + forward.y * b,
                        z = center.z,
                    }
                    local tc = self:CampFootCentre(cand, worldForwardAngle, pf)
                    local v, t = self:CampFootprintStats(campMap, tc, worldForwardAngle, pf.w, pf.h)
                    local rough = self:CampFootprintRough(campMap, tc, worldForwardAngle, pf.w, pf.h)
                    -- The tent's own ground weighs double: it is the one thing the player
                    -- walks up to, and it has to be level.
                    local score = 2 * ((t > 0) and (v / t) or 0) - 4 * rough
                    for _, off in ipairs(cellOffs) do
                        local cell = {
                            x = cand.x + right.x * off[1] * spacing + forward.x * off[2] * spacing,
                            y = cand.y + right.y * off[1] * spacing + forward.y * off[2] * spacing,
                        }
                        local bad = self:CampTileBadness(campMap, cell, worldForwardAngle)
                        score = score + (1 - math.min(bad, 1))
                    end
                    local moved = math.abs(a) + math.abs(b)
                    score = score - 0.01 * moved  -- tie-break toward the asked spot
                    if not bestScore or score > bestScore then bestScore, bestC, bestMoved = score, cand, moved end
                    b = b + st
                end
                a = a + st
            end
            center = self:CampSnapToGround(bestC)
            if bestMoved > 0.5 then
                System.LogAlways(string.format(
                    '[Mercenaries] camp shifted %.1f m to where its rings fit (score %.2f)', bestMoved, bestScore))
            end
            -- Far enough that the grid's outer cells have left the sampled ground: map again
            -- round the settled centre, so the tiles are still chosen off real samples.
            if bestMoved > 2.5 then
                pcall(function() campMap = self:CampBuildMap(center, mapCells, underRoof) end)
            end
        end
        end

        -- The settled map, for the stations' furniture tests (CampSatelliteSpot).
        self.CampLastMap = campMap

        -- No ground at all is a refusal, not a camp in the trees.
        if not atOrigin and campMap and campMap.counts
           and campMap.counts.valid < (self.CampMinBuildable or 0) then
            System.LogAlways(string.format(
                '[Mercenaries] camp refused: only %d buildable cells on the settled map', campMap.counts.valid))
            Game.SendInfoText('merc_info_camp_no_spot', false, 0, 3)
            return
        end

        -- The camp's anchor is settled now (on a fresh pitch the searches above may
        -- have moved it; on a rebuild it is the given origin verbatim). Remember +
        -- persist it, so an upgrade rebuild or a save/load puts the camp back on this
        -- exact spot and facing - the searches are skipped on that path precisely so
        -- the anchor cannot drift past the 2.0m epsilons its consumers compare with.
        self.CampBuildOrigin = { x = center.x, y = center.y, z = center.z, ang = worldForwardAngle }

        -- Cell (0, 0) is the player tent itself; (dx, dy) offsets are in
        -- grid tiles, dx = right/left, dy = forward(+)/behind(-).
        local function gridCellPos(dx, dy)
            local p = self:CampSnapToGround({
                x = center.x + right.x * dx * spacing + forward.x * dy * spacing,
                y = center.y + right.y * dx * spacing + forward.y * dy * spacing,
                z = center.z,
            })
            return p
        end

        self:SpawnPlayerCampTent(center, worldForwardAngle)
        local hasHouse = false
        pcall(function() hasHouse = (self.LogiState and self:LogiState().hasHouse) and true or false end)
        if hasHouse and self.HouseLocalToWorld and self.CampHouseWalls then
            -- The HUT, not the tent. The tent's box centred on the origin covered the hut's
            -- front half only: the hut's origin is its door gable and it runs 4.7 m behind
            -- it, so its rear half was unclaimed ground, and a judged survey found a lean-to
            -- built into the thatch and a shelter against the rear wall. Claim the walls'
            -- box at the hut's own yaw, with the eave's overhang.
            local lx0, ly0, lx1, ly1 = math.huge, math.huge, -math.huge, -math.huge
            for _, w in ipairs(self.CampHouseWalls) do
                for _, p in ipairs({ { w.ax, w.ay }, { w.bx, w.by } }) do
                    if p[1] < lx0 then lx0 = p[1] end
                    if p[2] < ly0 then ly0 = p[2] end
                    if p[1] > lx1 then lx1 = p[1] end
                    if p[2] > ly1 then ly1 = p[2] end
                end
            end
            local hAng = worldForwardAngle + (self.CampHouseFacingFix or math.pi)
            local hc = self:HouseLocalToWorld(center, hAng, (lx0 + lx1) / 2, (ly0 + ly1) / 2, 0)
            -- The collider lines are the LOG walls; the thatch is a roof-to-ground slope that
            -- meets the dirt well outside them, and the dirt apron runs further still. With a
            -- metre of margin two judged surveys found a shelter's foliage in the straw and a
            -- smokehouse under the gable eave; the margins are the thatch's, not the walls'.
            -- Measured off the mesh (tools/cgf_mesh.py, 2026-09-22): above knee height the
            -- thatch spans local x -1.24..6.04 and y -3.13..4.45 against walls at x -0.06..4.71
            -- and y -1.72..3.09 - 1.2 to 1.4 m past the wall line on every side. The dirt
            -- apron under it runs a further 2-3 m, and that is left for the props.
            local eave = self.CampHouseEave or 1.8
            local gable = self.CampHouseGableClear or 1.8
            local hw, hh = (ly1 - ly0) / 2 + eave, (lx1 - lx0) / 2 + gable
            self:CampClaimFoot(hc, hAng, { w = hw, h = hh }, "player house")
            System.LogAlways(string.format('[Camp] hut claimed: %.1f x %.1f m box at (%.1f, %.1f), yaw %.0f',
                2 * hw, 2 * hh, hc.x, hc.y, math.deg(hAng)))
        else
            -- Claimed so the ring tents cannot be nudged onto it. The box is claimed at the
            -- tent's OWN yaw, not the grid's - CampPlayerTentYaw is what it was spawned at.
            self:CampClaimFoot(center, self:CampPlayerTentYaw(worldForwardAngle),
                               self:CampPropClaimHalf(self.CampPlayerTentModel), "player tent")
        end

        -- (The drying rack and the smokehouse go down AFTER the tent rings now - see below.
        -- They used to come first "so their tiles are claimed and routed around", but a ring
        -- tent whose slot fell on the smokehouse had nowhere clean to be nudged to and was
        -- built through it. The stations can spiral to clear ground; a ring tent cannot.)

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

        -- Tiles this camp handed out the last time it stood, reserved BEFORE anything else
        -- claims a cell. An upgrade's tile is drawn from the cells the tent clusters did
        -- not take, so where it lands depends on the cluster count - which depends on how
        -- many men were alive and cached when the camp was laid out. Rebuild four seconds
        -- after a load, off a merc cache that is still filling, and every station moved:
        -- that is the "upgrades shuffle around after a reload" report. Restoring them first
        -- pins them, and the clusters below route around them instead of over them.
        self.CampStationTiles = {}
        local reusedStations = 0
        do
            local savedTiles = {}
            pcall(function() savedTiles = self:CampLoadStationTiles(center) or {} end)
            pcall(function() self.CampPlacedSpots = self:CampLoadPlacedSpots(center) or {} end)
            pcall(function() self.CampCirclePlaced = self:CampLoadCircles(center) or {} end)
            for _, name in ipairs(stationNames) do
                local t = savedTiles[name]
                -- A tile the player has since run a palisade through is not worth keeping:
                -- the rule that a standing upgrade never moves exists so a purchase does
                -- not reshuffle the camp, not so an upgrade can stay inside a wall. Drop it
                -- and let the claim below deal it a fresh cell.
                if t and t.x and t.y and self.IsSpotNearWall and self:IsSpotNearWall(t) then
                    System.LogAlways("[Camp] upgrade tile '" .. name .. "' now sits on the wall - re-dealing it")
                    t = nil
                end
                if t and t.x and t.y then
                    self.CampStationTiles[name] = { x = t.x, y = t.y, z = t.z or center.z, ang = t.ang or 0 }
                    reusedStations = reusedStations + 1
                    -- Which grid cell it sits in. Compared on the RAW cell centre, not
                    -- gridCellPos - that ground-snaps, and a raycast per candidate cell per
                    -- station is a burst of them for an answer only x/y is needed for.
                    local bestKey, bestD
                    for _, off in ipairs(candidateOffsets) do
                        local cx = center.x + right.x * off[1] * spacing + forward.x * off[2] * spacing
                        local cy = center.y + right.y * off[1] * spacing + forward.y * off[2] * spacing
                        local d = (cx - t.x) ^ 2 + (cy - t.y) ^ 2
                        if not bestD or d < bestD then bestD, bestKey = d, off[1] .. "," .. off[2] end
                    end
                    if bestKey and bestD and bestD <= (spacing * spacing) then usedCell[bestKey] = true end
                end
            end
        end
        for _, off in ipairs(candidateOffsets) do
            if #clusterCenters >= numClusters then break end
            local raw = gridCellPos(off[1], off[2])
            local accept = false
            if campMap then
                local _, inv, rough = self:CampTileBadness(campMap, raw, worldForwardAngle)
                accept = inv <= self.CampTileMaxInvalidFrac and rough <= self.CampTileMaxRough
                if accept then
                    raw = self:CampSnapToGround(self:CampNudgeToValid(campMap, raw, worldForwardAngle, self.CampFireFootHalf, raw.z))
                    -- ...then onto the LEVELLEST ground within reach. A fire, its tripod and
                    -- the seats round it stand plumb, and plumb on a 10 degree slope is a
                    -- buried uphill leg and a floating downhill one whatever the seating rule
                    -- does. The tile is accepted at up to 12 degrees on average; the fire
                    -- itself goes where the tile is flattest.
                    raw = self:CampSnapToGround(self:CampNudgeToFlattest(campMap, raw, worldForwardAngle, self.CampFireFootHalf))
                    self:CampClaimFoot(raw, worldForwardAngle, self.CampFireFootHalf, "fire")
                end
            else
                local valid, gz = self:CampValidateSpot(raw, center.z, self.CampClusterFootprint)
                accept = valid
                if accept then raw = { x = raw.x, y = raw.y, z = gz } end
            end
            -- never drop a fire cluster on an archer tower or a cart (both check their
            -- SAVED layout too, so the load window before DefRestore is covered)
            if accept and self.IsSpotNearTower and self:IsSpotNearTower(raw) then accept = false end
            if accept and self.IsSpotNearCart and self:IsSpotNearCart(raw) then accept = false end
            if accept then
                usedCell[off[1] .. "," .. off[2]] = true
                table.insert(clusterCenters, { x = raw.x, y = raw.y, z = raw.z or center.z })
            end
        end
        -- Shortfall fallback: fill remaining clusters with the closest cells we
        -- haven't already used, validated or not - but never one a tower or cart
        -- occupies: "validated or not" is about GROUND quality, not about dropping a
        -- tent ring inside a standing structure.
        -- The LEAST BAD of them, not the nearest. "Closest cells, validated or not" took the
        -- first free cell in grid order, and with the scrub round a stream ruling out the near
        -- cells that was a 25 degree bank: a whole ring of beds buried to the uphill rail
        -- while a merely bushy cell two places further on would have done. Ranked by how much
        -- of each cell is unbuildable and how steep it is, nearest first among equals.
        if #clusterCenters < numClusters then
            local pool = {}
            for idx, off in ipairs(candidateOffsets) do
                local key = off[1] .. "," .. off[2]
                if not usedCell[key] then
                    local raw = gridCellPos(off[1], off[2])
                    local blocked = (self.IsSpotNearTower and self:IsSpotNearTower(raw))
                                 or (self.IsSpotNearCart and self:IsSpotNearCart(raw))
                    if not blocked then
                        local bad = campMap and self:CampTileBadness(campMap, raw, worldForwardAngle) or 0
                        table.insert(pool, { key = key, raw = raw, bad = bad, idx = idx })
                    end
                end
            end
            table.sort(pool, function(p, q)
                if math.abs(p.bad - q.bad) > 0.05 then return p.bad < q.bad end
                return p.idx < q.idx
            end)
            for _, p in ipairs(pool) do
                if #clusterCenters >= numClusters then break end
                usedCell[p.key] = true
                table.insert(clusterCenters, p.raw)
                System.LogAlways(string.format(
                    '[Mercenaries] no validated cell left for a tent ring - took the least bad (%.0f%% bad) at (%.1f, %.1f)',
                    p.bad * 100, p.raw.x, p.raw.y))
            end
        end

        -- A tent ring the player moved by hand wins over the cell the grid chose for it.
        -- This has to happen BEFORE anything reads clusterCenters: the campfire, the seats,
        -- the tents and the beds are all placed off these positions further down, so an
        -- override applied after that moved nothing at all - the ring stayed where the grid
        -- put it and only the remembered position changed.
        for i, cp in pairs(self.CampCirclePlaced or {}) do
            if clusterCenters[i] then
                clusterCenters[i] = self:CampSnapToGround({ x = cp.x, y = cp.y, z = cp.z })
            end
        end

        -- STATION TILES: each camp upgrade claims its own grid tile out of the
        -- cells the clusters didn't take - same spacing and same footprint
        -- validation as a campfire cluster, so an upgrade is given exactly as much
        -- room as a tent ring and can't land on top of one (or on another upgrade).
        -- Each faces outward from the camp centre. Anything that can't get a
        -- validated tile takes the next free cell raw, then falls back to its own
        -- flat-patch scan if it got nothing at all.
        -- Anything the last pitch already placed kept its tile above; only a station with
        -- no saved tile - a newly bought one - draws a fresh cell here.
        --
        -- avoidWall keeps the tile off a standing palisade. It is a separate pass rather
        -- than part of requireValid because a tight ring can leave no cell at all clear of
        -- the wall, and an upgrade placed badly still beats one that is never built.
        local placedStations = reusedStations
        local function claimStationTile(name, requireValid, avoidWall)
            for _, off in ipairs(candidateOffsets) do
                local key = off[1] .. "," .. off[2]
                if not usedCell[key] then
                    local raw = gridCellPos(off[1], off[2])
                    local accept = true
                    if requireValid and campMap then
                        local _, inv, rough = self:CampTileBadness(campMap, raw, worldForwardAngle)
                        accept = inv <= self.CampTileMaxInvalidFrac and rough <= self.CampTileMaxRough
                        if accept then
                            raw = self:CampSnapToGround(self:CampNudgeToValid(campMap, raw, worldForwardAngle, self.CampFireFootHalf, raw.z))
                    self:CampClaimFoot(raw, worldForwardAngle, self.CampFireFootHalf, "fire")
                        end
                    end
                    -- and don't hand an upgrade a tile that a tower, a cart or the palisade
                    -- stands on
                    if accept and self.IsSpotNearTower and self:IsSpotNearTower(raw) then accept = false end
                    if accept and self.IsSpotNearCart and self:IsSpotNearCart(raw) then accept = false end
                    if accept and avoidWall and self.IsSpotNearWall and self:IsSpotNearWall(raw) then accept = false end
                    if accept then
                        usedCell[key] = true
                        self.CampStationTiles[name] = { x = raw.x, y = raw.y, z = raw.z or center.z,
                            ang = math.atan2(raw.y - center.y, raw.x - center.x) }
                        return true
                    end
                end
            end
            return false
        end
        for _, name in ipairs(stationNames) do
            if not self.CampStationTiles[name] then
                if claimStationTile(name, true, true) or claimStationTile(name, false, true)
                   or claimStationTile(name, false, false) then
                    placedStations = placedStations + 1
                end
            end
        end
        if #stationNames > 0 then
            System.LogAlways(string.format("[Camp] %d/%d upgrade tiles reserved (%d kept from the last pitch)",
                placedStations, #stationNames, reusedStations))
        end

        for _, cPos in ipairs(clusterCenters) do
            self:SpawnCampFirePrefab(cPos, 0)
            if self.NavAddObstacle then self:NavAddObstacle(cPos, 0, self.NavFireFootHalf, "fire") end
        end

        -- TRAINING YARD - the reserved tile BEHIND the player tent (per spec:
        -- "training area is behind the player tent, one tile in front is
        -- empty"). Placed CampTrainingYardDistance metres along -forward, in the
        -- (0, -1) tile CampGridOffsets reserves. Straw dummies (up to five, one
        -- per five mercs) are laid out in a row across the yard; trainees stand
        -- on the camp side facing them. Nudged onto valid ground if the map
        -- found a clump behind the tent.
        -- The hut runs 4.7 m behind the origin where the round tent runs 2.3, so the same
        -- yard distance put the pells a stride from the hut's rear gable and the men
        -- drilling against its wall. A hut gets the difference added.
        local yardDist = self.CampTrainingYardDistance + (hasHouse and 3.5 or 0)
        local trainCenter = self:CampSnapToGround({
            x = center.x - forward.x * yardDist,
            y = center.y - forward.y * yardDist,
            z = center.z,
        })
        if campMap then
            trainCenter = self:CampSnapToGround(self:CampNudgeToValid(campMap, trainCenter, worldForwardAngle, self.CampFireFootHalf, trainCenter.z))
            self:CampClaimFoot(trainCenter, worldForwardAngle, self.CampFireFootHalf, "training")
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
        -- A training ground the player moved wins over the computed one. Without this the
        -- rebuild recomputed it from the camp's forward angle and overwrote the chosen spot
        -- before the yard was spawned, so it could never be moved.
        if self.CampTrainPlaced then
            self.CampTrainCenter = self:CampSnapToGround({
                x = self.CampTrainPlaced.x, y = self.CampTrainPlaced.y,
                z = self.CampTrainPlaced.z })
        else
            self.CampTrainCenter = trainCenter
        end
        -- Kept so a merc who joins the camp later can be given a spot on one of the same
        -- rings the build loop used (CampEnsureSpot) instead of no spot at all.
        self.CampClusterCenters = clusterCenters
        local numDummies = 0
        pcall(function()
            if self.LogiState and self:LogiState().hasPracticeYard then
                self:SpawnCampPracticeYard(center)
                numDummies = (self.CampPracticeYard and self.CampPracticeYard.numDummies) or 0
                -- The whole ROW is claimed, dummies and the men drilling in front of them:
                -- the yard's claim was a fire-sized box at its centre, and a judged survey
                -- found the food cart's side board through a dummy and a tripod at the
                -- anvil's elbow. Stations placed after this route round it.
                if numDummies > 0 and self.CampClaimFoot then
                    local rowHalf = numDummies * (self.CampTrainingDummySpacing or 1.6) * 0.5 + 1.0
                    local rowC = self:CampRelativeOffset(self.CampTrainCenter or trainCenter, worldForwardAngle,
                        { right = 0, forward = (self.CampTrainingTraineeSetback or 2.2) * 0.5 })
                    self:CampClaimFoot(rowC, worldForwardAngle,
                        { w = rowHalf, h = (self.CampTrainingTraineeSetback or 2.2) * 0.5 + 1.2 }, "practice yard")
                end
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
            -- The weapon pile stands OUTSIDE the seat ring, in the gap the tent ring leaves
            -- open (its seventh slot is never given a tent), halfway between the seats and
            -- the tents. It used to take the first seat's slot, which put a rack of polearms
            -- a metre from the fire, inside the ring of men - "the weapon stack sits inside
            -- the seating ring" in three frames of a judged survey.
            do
                -- A stride outside the seats, on the open slot's own bearing. Halfway to
                -- the tents put it in the depth band the tents' nudges wander through, and
                -- one was found standing on a bed inside a shelter.
                local wsR = self.CampFireSeatRadius + 0.9
                local wsPos = self:CampSnapToGround(select(1, self:CampRingPos(cPos, wsR,
                    self.CampClusterTentRingSlots, self.CampClusterTentRingSlots, 0)))
                -- Satellite props were dropped straight onto an offset from their
                -- parent with no test at all, which is why the polearm stacks kept
                -- turning up standing in the stream, in bank scrub, and inside the
                -- vanilla barn's thatch while everything else placed cleanly.
                if self.CampNudgeClearOfStructures then
                    wsPos = self:CampNudgeClearOfStructures(wsPos, 1.2, 5.0,
                                self.CampModels.WeaponStack, 0)
                end
                local wsAng = math.atan2(cPos.y - wsPos.y, cPos.x - wsPos.x)
                self:SpawnCampProp("WeaponStack", wsPos, wsAng)
                -- ...and claimed, so the tents placed after it route round it.
                if self.CampClaimFoot and self.CampPropFootHalf then
                    self:CampClaimFoot(wsPos, wsAng, self:CampPropFootHalf(self.CampModels.WeaponStack, 0.3), "weapon stack")
                end
            end
            for j = 1, clusterMercCount do
                local seatPos = self:CampSnapToGround(select(1, self:CampRingPos(cPos, self.CampFireSeatRadius, j, clusterMercCount, math.pi / clusterMercCount)))
                do
                    -- Face the fire so a seated merc faces it.
                    local faceFire = math.atan2(cPos.y - seatPos.y, cPos.x - seatPos.x) + math.rad(self.CampSitFacingFixDeg)
                    local soPos = self:CampRelativeOffset(seatPos, faceFire, self.CampSitSOOffset)
                    local logWuid, logSoPos = self:SpawnCampFurnitureSO(self.CampModels.Log, seatPos, faceFire, "MercCampProp_LogSO", self.CampChairSO, soPos)
                    if logWuid then
                        -- Keep the fire this seat rings so a merc who claims it can
                        -- Turn to face it after sitting (the seated pose doesn't
                        -- inherit the smart object's rotation - see camp_actor).
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
                local tentPos, tentFaceAngle = self:CampRingPos(cPos, self:CampTentRing(), memberIndex, self.CampClusterTentRingSlots, 0)
                tentPos = self:CampSnapToGround(tentPos)
                angle = tentFaceAngle + math.pi + self.CampTentFacingFix
                -- Nudge the whole tent unit onto valid ground if its footprint
                -- caught an obstacle clump - the bed and clutter are placed
                -- relative to tentPos, so they move with it. Never skipped (the
                -- least-bad spot is used) so every non-guard keeps a bed and the
                -- shared CampBeds pool stays intact.
                -- Random tent variant per merc, for visual variety. Chosen BEFORE the
                -- nudge, not after: the variants are not the same size (see
                -- CampPropFootHalf), so validating the spot against a fixed box and then
                -- rolling for the model meant the ground was checked for a tent other than
                -- the one that got built there.
                local tentModel = self.CampTentVariants[math.random(#self.CampTentVariants)]
                local tentFoot = self:CampPropFootHalf(tentModel)
                local tentClaim = self:CampPropClaimHalf(tentModel)
                if campMap then
                    tentPos = self:CampSnapToGround(self:CampNudgeToValid(
                        campMap, tentPos, angle, tentFoot, tentPos.z, tentClaim))
                end
                self:CampClaimFoot(tentPos, angle, tentClaim, "tent")
                self:SpawnCampPropModel(tentModel, tentPos, angle, "MercCampProp_Tent")
                -- The obstacle gets the mesh's own extent, no slack: padding a tent closes
                -- the gaps the men walk through between them.
                if self.NavAddObstacle then
                    self:NavAddObstacle(tentPos, angle, self:CampPropFootHalf(tentModel, 0), "tent")
                end
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
                -- From the tent's FOOTPRINT CENTRE, not its origin. tent_small_forest_d's
                -- mesh sits 0.69 m off its own origin along Y, so a bed placed at the
                -- origin lies off-centre in the tent and pushes out through the canvas.
                pos, bedAngle = self:CampRelativeOffset(
                    self:CampFootCentre(tentPos, angle, self:CampPropFootHalf(tentModel, 0)),
                    angle, self.CampBedOffset)
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
                local activityRadius = self:CampTentRing() + self.CampActivityOutsideGap
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
                local role0 = self:CampRoleWithInjuryBias(self:CampRoleWithNightBias(cycle[idx]), tostring(mercWuid))
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

        -- The drying rack and the smokehouse, beside the hut - after the rings, so they take
        -- the clear ground the tents left rather than the other way round. Each is nudged
        -- clear of buildings, plants and every claim above (CampNudgeClearOfStructures).
        if self.SpawnCampAmenities then self:SpawnCampAmenities(center, worldForwardAngle) end

        -- Half the squad (per feedback) become "guards" and patrol the camp
        -- perimeter for real, continuously - picked at random (a Fisher-Yates
        -- shuffle of mercList indices, so selection doesn't favor any tier;
        -- the per-merc loop above still walked mercList in its original sorted
        -- order for tent/bed assignment, only the guard flag is random). Each
        -- guard gets a ring of waypoint POSITIONS encircling the whole camp;
        -- the follow BT walks them point-to-point with periodic pauses (see
        -- IsCampGuard / GetPatrolWaypoint / AdvancePatrolWaypoint above, and
        -- the incamp-guard handling in mercenary_scheduler.xml /
        -- archer_scheduler.xml / camp_actor.xml). Guards are staggered
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
        local patrolRadius = maxClusterOffset + self:CampTentRing() + self.CampPatrolTentClearance
        local guardIndices = {}
        for i = 1, mercCount do
            if campRole[i] == "guard" then table.insert(guardIndices, i) end
        end
        -- The ring is a circle drawn on the map, so it runs through whatever happens to be
        -- standing around the camp. A waypoint that lands on a house is not merely
        -- unreachable - the guard's Move resolves to it and he ends up on the roof, which
        -- is the "patrolling mercs get teleported onto buildings" report. Every point is
        -- pulled onto open ground near where the circle wanted it and dropped when there is
        -- none, so the route goes round the obstacle instead of over it. A ring that loses
        -- most of its points is drawn again closer in, where a cramped site has more room.
        -- One ring is validated for the whole camp, not one per guard: the circle is the
        -- same for everybody and only the starting point differs, so validating it per man
        -- multiplied the raycast burst by the guard count for no new information.
        local RING_POINTS = NUM_WAYPOINTS * 3
        local function ringWaypoints(radius)
            local pts = {}
            for w = 1, RING_POINTS do
                local wp = self:CampRingPos(center, radius, w, RING_POINTS, 0)
                local g = self:FindValidGround({ x = wp.x, y = wp.y, z = center.z }, center.z,
                                               3.0, 0.5, 16)
                if g and self:CampValidateSpot(g, center.z, self.CampMercFootprint) then
                    table.insert(pts, { x = g.x, y = g.y, z = g.z })
                end
            end
            return pts
        end

        local ring = ringWaypoints(patrolRadius)
        if #ring < 4 then
            local tighter = ringWaypoints(patrolRadius * 0.6)
            if #tighter > #ring then ring = tighter end
        end

        if #ring < 2 then
            System.LogAlways(
                '[Mercenaries] camp guards: no open ground anywhere on the patrol ring - they stay put')
        end
        for p, idx in ipairs(guardIndices) do
            local m = mercList[idx]
            local wuid = m and entWuid(m.ent)
            if wuid and #ring > 1 then
                -- Each guard walks the same loop from his own place on it, which is what the
                -- per-guard angular offset did before, taking NUM_WAYPOINTS points spread
                -- evenly through whatever survived so the legs stay the length the sentry
                -- pause was tuned around however many candidates the obstacles took out.
                local start = math.floor(((p - 1) / math.max(#guardIndices, 1)) * #ring)
                local taken = math.min(NUM_WAYPOINTS, #ring)
                local waypoints = {}
                for w = 0, taken - 1 do
                    table.insert(waypoints, ring[((start + math.floor(w * #ring / taken)) % #ring) + 1])
                end
                self.CampPatrollers[tostring(wuid)] = { waypoints = waypoints, index = 1 }
            end
        end

        self.CampCenter = center
        self.CampActive = true
        -- A camp is the biggest burst of entities the mod ever creates, and the periodic
        -- sweep may be 30s away. Flag them out of the save now, or a save taken in that
        -- window carries the whole camp - which is what "white pyramids where the camp
        -- was" is once the mod is gone.
        pcall(function() if self.NoSaveSweep then self:NoSaveSweep(true) end end)
        -- Nobody raids a camp that went up an hour ago (mercenaries_raids.lua). `fresh` is
        -- a NEW pitch; an origin without it is the saved anchor coming back after a load or
        -- an upgrade, which is the same camp and keeps its age. Same test as DefArmRestore
        -- below.
        local freshPitch = (atOrigin == nil or atOrigin.fresh == true)
        if self.RaidNoteCampPitched then
            pcall(function() self:RaidNoteCampPitched(freshPitch) end)
        end
        self.CampStationRetries = 0
        self.CampOutParty = {}   -- fresh camp: everyone starts in it
        -- Persist that emptying, or the last sortie's list outlives the camp it was written
        -- for - pitch again on the same spot and the next load deploys those men again.
        -- Only on a fresh pitch: a restore and an upgrade rebuild both come through here with
        -- the saved anchor and then read the tag back (RestoreCampDelayed /
        -- LogiRebuildCampForUpgrade), so writing here would wipe the party they mean to keep.
        if freshPitch then pcall(function() self:SaveCampOutParty() end) end
        _G.MercCampMode = true
        -- "A camp exists" flag. The schedulers/follow BT and the formation &
        -- teleport monitors read it (via IsMercInCampProper) to leave the mercs
        -- who stay in camp alone. NOTE: camp deliberately no longer forces the
        -- global idle flag - in-camp mercs are held in place by their camp roles
        -- (IsCampActor), while global idle is reserved for the player's own
        -- wait order, which only affects sortie mercs.
        _G.MercInCamp = true
        self:CampSyncRoster()

        -- Starting stores on the very first camp (no-op afterwards).
        pcall(function() self:LogiGrantStartingSupplies() end)

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
        -- Makeshift inn/tavern: sittable tables + barrels once the inn is bought.
        pcall(function()
            if self.LogiState and self:LogiState().innActive then self:SpawnCampInn(center) end
        end)
        -- Food cart: a loaded supply wagon while the Food Cart upgrade has days left.
        pcall(function()
            if self.LogiState and (self:LogiState().foodCartDays or 0) > 0 then self:SpawnCampFoodCart(center) end
        end)
        -- Trader: the stall, the sutler, and his counter (which keeps its stock across
        -- a break and a reload - see mercenaries_trader.lua).
        pcall(function()
            if self.LogiState and self:LogiState().hasTrader then self:SpawnCampTrader(center) end
        end)
        -- Night-watch lamps around the guard perimeter (see CampSpawnNightLights).
        pcall(function() self:CampSpawnNightLights(center) end)

        -- Persist the camp (anchor + "a camp is standing") so it survives a save.
        pcall(function() self:SaveCampState() end)

        -- Defences (wall/towers/carts) belong to a PITCH, not to the company: put them
        -- back if this is the same spot they were built at, otherwise leave them behind
        -- and start bare. Deferred so the camp props are all down first.
        pcall(function()
            -- "A rebuild" means the camp went back up on a SAVED anchor, which is what
            -- an explicit origin used to imply. It no longer does: the camp screen pitches
            -- a NEW camp at the player's position and passes an origin to do it, and
            -- calling that a rebuild had the defence restore re-anchor the previous camp's
            -- walls onto the new one. An origin marked `fresh` says which it is.
            if self.DefArmRestore then
                self:DefArmRestore(atOrigin ~= nil and not atOrigin.fresh)
            end
        end)

        if not silent then Game.SendInfoText('merc_info_camp_made', false, 0, 4) end
    end)

    if not ok then
        System.LogAlways('[Mercenaries] SpawnMercCamp error: ' .. tostring(err))
    end
end

-- Despawn every tracked camp prop and resume normal squad state. silent = true
-- skips the info text (when a follow/dismiss order breaks camp as a side effect).
function mercenaries:BreakMercCamp(silent)
    -- Everything standing goes into storage first, whichever way camp is being broken: the
    -- camp screen's own Break did this, the look-at-and-hold-E route did not, and the two
    -- must not disagree about whether you keep what you paid for.
    if self.CUStowStanding and self.CampActive then
        pcall(function() self:CUStowStanding() end)
    end
    if self.CampActorInvalidateAll then self:CampActorInvalidateAll() end
    if not self.CampActive then
        if not silent then
            Game.SendInfoText('merc_info_camp_not_active', false, 0, 3)
        end
        return
    end

    -- Before anything is cleared: note who is still winding down an activity, so the
    -- formation is anchored on a guard rather than on a man mid sword-drill.
    pcall(function() self:MarkCampBusyMercs() end)
    -- A conjured guard torch must not survive the camp it was conjured for.
    pcall(function() self:CampStripAllTorches() end)

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
    pcall(function() self:DespawnCampInn() end)
    pcall(function() self:DespawnCampFoodCart() end)
    pcall(function() self:DespawnCampTrader() end)
    -- House props go with CampEntities; this just restores the grass CVar.
    pcall(function() self:ClearCampHouse() end)
    -- The wall's invisible obstacle blockers go with it. Without this they are left
    -- standing, solid and unseen, where the camp used to be.
    pcall(function() if self.NavObstBlockerClear then self:NavObstBlockerClear() end end)

    if self.NavClearObstacles then self:NavClearObstacles() end
    self.CampEntities = {}
    self.CampPropLog = {}
    self.CampFitStats = { fitted = 0, tiltSum = 0, tiltMax = 0, moveSum = 0, moveMax = 0 }
    self.CampSlots = {}
    self.CampPatrollers = {}
    self.CampFurniture = {}
    self.CampActivities = {}
    self.CampMercSpots = {}
    self.CampNightLights = {}
    self.CampNightLightsOn = nil
    self.CampGuardTorch = {}
    self.CampRoleIdx = {}
    self.CampNextRotate = {}
    self.CampSeats = {}
    self.CampBeds = {}
    self.CampPlayerBed = nil
    self.CampBedSleepState = nil
    self.CampTicks = 0
    self.CampCommunalChairs = {}
    self.CampOutParty = {}
    self.CampRoster = {}
    self.CampPracticeYard = nil
    self.CampStationTiles = {}
    self.CampTrainCenter = nil
    self.CampForwardAngle = nil
    self.CampClusterCenters = nil
    self.CampCenter = nil
    self.CampActive = false
    -- Forget the pitch: a struck camp must not come back on the next load. (The
    -- upgrade rebuild grabs CampBuildOrigin before it calls this - see
    -- LogiRebuildCampForUpgrade.)
    self.CampBuildOrigin = nil
    pcall(function() self:SaveCampState() end)
    -- Take the defences down with the camp, but do NOT forget them: pitching again on
    -- the same spot puts them back, pitching elsewhere is what discards them
    -- (DefRestore checks the anchor). The upgrade rebuild passes through here too, so
    -- they come straight back up with the new layout.
    pcall(function() if self.DefClearWorld then self:DefClearWorld() end end)
    _G.MercCampMode = false
    _G.MercInCamp = false
    mercenaries:ClearMercCampChats()
    _G.MercReturnPending = {}
    self.CampChatMercCooldown = {}
    self.MercCampCombatFlag = {}
    self.CampChatStaggered = false
    -- Clear any idle order so the squad follows again after camp comes down.
    -- (This is what was missing before: camp used to force the global idle flag
    -- on, and breaking camp left it on, so the whole squad stood around until an
    -- explicit "follow me" order. Camp no longer sets it, and we clear it here.)
    --
    -- The two globals alone are NOT enough any more: a hold order deliberately
    -- leaves both false, so clearing them is a no-op and the sortie would stay
    -- planted on its line after the camp came down - exactly the standing-around
    -- this block exists to prevent.
    pcall(function() self:HoldEnd(true) end)
    pcall(function() self:EscortEnd(true) end)
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
-- A station can fail to build and say nothing. The forge and the alchemy bench each
-- BORROW a vanilla Smithery/AlchemyTable out of the nearest settlement, and right after
-- a save load - RestoreCampDelayed rebuilds the camp four seconds in - the level around
-- the camp may not have streamed those in yet, so the borrow finds nothing and the
-- upgrade the player paid for simply is not there. That is the other half of "upgrades
-- come back invisible": not misplaced, never built.
--
-- So every camp tick for the first minute, anything the player owns but that is not
-- standing gets another go. Each spawner already no-ops when its station exists, and the
-- tile it was reserved is still held, so a late build lands exactly where it belonged.
mercenaries.CampStationRetryMax = 12     -- 5s ticks: a minute of streaming grace
mercenaries.CampStationRetries  = 0

function mercenaries:CampStationRetryTick()
    if not (self.CampActive and self.CampCenter) then return end
    if (self.CampStationRetries or 0) >= self.CampStationRetryMax then return end
    local L
    pcall(function() L = self:LogiState() end)
    if not L then return end

    local missing = {}
    local function want(owned, built, name, fn)
        if owned and not built and fn then
            table.insert(missing, name)
            pcall(fn, self, self.CampCenter)
        end
    end
    want(L.hasSmithy, self.CampForge, "forge", self.SpawnCampForge)
    want(L.hasAlchemy, self.CampAlchemy, "alchemy", self.SpawnCampAlchemy)
    want((L.hunterSpots or 0) > 0, self.CampHunt, "hunt", self.SpawnCampHunt)
    want(L.innActive, self.CampInn, "inn", self.SpawnCampInn)
    want((L.foodCartDays or 0) > 0, self.CampFoodCart, "cart", self.SpawnCampFoodCart)
    want(L.hasTrader, self.CampTrader, "trader", self.SpawnCampTrader)

    if #missing == 0 then
        -- everything owned is standing: stop asking
        self.CampStationRetries = self.CampStationRetryMax
        return
    end
    self.CampStationRetries = (self.CampStationRetries or 0) + 1
    if self.CampStationRetries >= self.CampStationRetryMax then
        System.LogAlways("[Camp] gave up rebuilding: " .. table.concat(missing, ", ")
            .. " (no settlement near enough to borrow from?)")
    end
end

function mercenaries:MonitorCamp()
    if not self.CampActive then return end
    self.CampTicks = (self.CampTicks or 0) + 1
    -- Retry any upgrade that failed to build (see above); self-limiting.
    self:CampStationRetryTick()
    -- Who is in camp, and does everyone in it have something to do (see CampSyncRoster).
    self:CampSyncRoster()
    -- Per-merc role timers (see RotateCampRoles) - checked every tick.
    self:RotateCampRoles()
    -- Conversations run on their own cadence (see CampChatTick).
    self:CampChatTick()
    -- Camp-centred hostile scan - closes the "player is away" gap (see comment above).
    self:CampWatchForAttack()
    -- Night-watch lamps + guard torches (see comment above).
    self:CampNightWatchTick()
end

-- Bring the whole squad to the player and resume following, from anywhere,
-- without touching the camp structure (tents stay until explicitly broken).
-- Bound to a key in OnGameplayStarted. See docs/camp.md.
function mercenaries:RecallMercs()
    if self.CampActorInvalidateAll then self:CampActorInvalidateAll() end
    if _G.MercenariesDismissed then
        Game.SendInfoText('merc_info_camp_no_squad', false, 0, 3)
        return
    end
    if not player then return end

    -- Same as BreakMercCamp: note the mid-activity men before their roles are torn down.
    pcall(function() self:MarkCampBusyMercs() end)

    local ok, err = pcall(function()
        -- Indoors, take the player's own position verbatim and do NOT re-snap. Every
        -- ground probe in this file fires from above, so under a roof both
        -- GetSafeSpawnPosition and FindValidGround resolve to the ROOF and the recall
        -- puts the squad on top of the building instead of in the room - the same
        -- defect that made hiring at an innkeeper's look like nothing spawned (see
        -- docs/spawning-npcs.md). "Come to me" means his floor by definition, and he
        -- is standing on it, so his z needs no validating.
        local indoors = self:CampDetectRoof(player:GetWorldPos()) and true or false
        local center = nil
        if not indoors then center = select(1, self:GetSafeSpawnPosition(player, 3)) end
        if not center then center = player:GetWorldPos() end

        local i = 0
        for name, ent in pairs(self.ActiveMercs) do
            if ent and self:IsAliveAndWell(ent, false) then
                i = i + 1
                local pos = self:CampRingPos(center, 2.0 + (i % 4), i, 12, 0)
                if not indoors then pos = self:FindValidGround(pos, center.z) end
                pcall(function() ent:SetPos(pos) end)
            end
        end
    end)
    if not ok then
        System.LogAlways('[Mercenaries] RecallMercs error: ' .. tostring(err))
    end

    -- Guards stop being guards; a conjured torch must not ride along as a follower.
    pcall(function() self:CampStripAllTorches() end)
    self.CampPatrollers = {}
    -- Recall pulls everyone (guards included) back to the player and resumes
    -- normal following - clear the incamp state AND the schedule assignments
    -- (GetCampActivity is deliberately not gated on MercInCamp for the test
    -- commands, so activities must be cleared explicitly or recalled mercs
    -- would walk straight back to their camp occupation).
    self.CampFurniture = {}
    self.CampActivities = {}
    self.CampMercSpots = {}
    self.CampRoster = {}
    self.CampRoleIdx = {}
    self.CampNextRotate = {}
    self.CampSeats = {}
    self.CampBeds = {}
    -- The sortie is over too: everyone is with the player, so there is no out-party to hold
    -- apart from the camp. Leaving the old one behind (in the table and in the save) is what
    -- let a finished deploy come back as a follow order on the next load.
    self.CampOutParty = {}
    pcall(function() self:SaveCampOutParty() end)
    _G.MercInCamp = false
    mercenaries:ClearMercCampChats()
    self.CampChatMercCooldown = {}
    self.MercCampCombatFlag = {}
    self.CampChatStaggered = false
    -- A recall that leaves a hold order standing UNDOES ITSELF: the men are teleported
    -- to a ring around the player just above, and the next hold poll sees each of them
    -- off his mark and walks him straight back to it. Clearing the two legacy globals
    -- cannot help - a hold order never sets them.
    pcall(function() self:HoldEnd(true) end)
    pcall(function() self:EscortEnd(true) end)
    _G.MercIdle = false
    _G.MercPersistentIdleFlag = false
    self:SaveString("MercIdlePersistent", "0")

    Game.SendInfoText('merc_info_recalled', false, 0, 3)
end

-- Every entity class we spawn camp/upgrade props as, and the name prefixes we
-- give them. ClearAnyLeftoverCamp sweeps the cross product. Both lists must grow
-- whenever a new prop class or prefix is introduced, or its props will be left
-- behind on load and the rebuild will stack on top of them.
-- Prefixes are matched from the START of the name and are deliberately more
-- specific than a bare "Merc" - that would also match vanilla entities like a
-- "Merchant..." stall.
-- (Smithery/ItemSlot/TagPoint are the upgrade-preview rig's. Sweeping the class
-- is safe because the prefixes only match OUR spawns - a village's own Smithery
-- is never named "MercSmith...", and the camp forge only BORROWS one.)
mercenaries.CampPropClasses = {
    "BasicEntity", "ParticleEffect", "BedTrigger", "StanceSmartObject",
    "SmartObjectHolder", "mercenaries_Prop", "Bed", "GeomEntity", "Light",
    "Smithery", "ItemSlot", "TagPoint",
    -- The player tent's amenities: the personal chest and the two food stations
    -- (mercenaries_amenities.lua).
    "Stash", "FoodProcessingTrigger", "ActionTrigger",
}
mercenaries.CampPropPrefixes = {
    "MercCamp",       -- props, player tent/bed, forge, alchemy, hunt, inn, cart, house
    "MercActTest_",   -- activity-test scaffolding
    "MercHunt",       -- hunting console tester
    "MercInn",        -- inn console tester + tavern stools
    "MercTower",      -- archer-tower console tester
    "MercForge",      -- forge rig / smith bench
    "MercSmith",      -- borrowed-smithery scaffolding
    "MercAnvil",
    "MercPart_",      -- upgrade preview
    "MercUpg",
    -- Invisible navigation blockers (mercenaries_navobst.lua). They are RESTING RIGID
    -- bodies, so one left behind is collision standing in an empty field, unseen.
    "MercNavBlocker_",
}

local function isCampPropName(name)
    for _, p in ipairs(mercenaries.CampPropPrefixes) do
        if string.sub(name, 1, #p) == p then return true end
    end
    return false
end

-- Called once from OnGameplayStarted, before RestoreCampDelayed rebuilds a saved
-- camp: sweeps away any leftover props from the camp that was standing when the
-- game was saved, since our Lua-side CampEntities list is gone after a fresh
-- script load either way (and the rebuild would otherwise stack on top of them).
-- Props are spawned bSaved_by_game = false so they shouldn't survive at all; this
-- is the backstop for any that do (a serialised one comes back as a broken white
-- placeholder mesh, which is exactly what this prevents).
function mercenaries:ClearAnyLeftoverCamp()
    System.LogAlways("[Camp] ClearAnyLeftoverCamp: entered")
    -- Same story as IsMercInCampProper: this throws and the engine will not say where.
    -- Name every precondition it depends on, once, so the next log says which is wrong.
    if not self._clearCampChecked then
        self._clearCampChecked = true
        local missing = {}
        for _, n in ipairs({ "CampPropClasses", "CampPropPrefixes", "CampOutParty", "CampRoster" }) do
            if type(self[n]) ~= "table" then missing[#missing + 1] = n .. "=" .. type(self[n]) end
        end
        for _, n in ipairs({ "DespawnQuartermaster", "ClearMercCampChats", "LoadStep",
                             "DespawnCampForge", "DespawnCampTrader", "ReleaseSpot" }) do
            if type(self[n]) ~= "function" then missing[#missing + 1] = n .. "=" .. type(self[n]) end
        end
        if #missing > 0 then
            System.LogAlways("[Camp] ClearAnyLeftoverCamp preconditions MISSING: " ..
                             table.concat(missing, ", "))
        end
    end
    local ok, err = pcall(function()
        local swept = 0
        for _, cls in ipairs(self.CampPropClasses) do
            local ents = System.GetEntitiesByClass(cls)
            if ents then
                for _, e in pairs(ents) do
                    local name = e and e:GetName() or ""
                    if isCampPropName(name) then
                        System.RemoveEntity(e.id)
                        swept = swept + 1
                    end
                end
            end
        end
        if swept > 0 then
            System.LogAlways("[Camp] swept " .. swept .. " leftover camp props")
        end
    end)
    if not ok then
        System.LogAlways('[Mercenaries] ClearAnyLeftoverCamp error: ' .. tostring(err))
    end

    -- Sweep away a leftover quartermaster (an NPC, swept by name prefix).
    -- EVERY call in the rest of this function is guarded. It is a teardown: the table
    -- resets at the bottom are what the camp system depends on afterwards, and a throw
    -- in any sweep above them used to skip the lot - while also costing the merc cache
    -- rebuild and the camp restore, since the whole function is one OnGameplayStarted
    -- step. Nothing here is worth that.
    self:LoadStep("DespawnQuartermaster", function() self:DespawnQuartermaster() end)

    -- Tear down the camp forge (restores the borrowed village Smithery).
    pcall(function() self:DespawnCampForge() end)
    pcall(function() self:DespawnCampAlchemy() end)
    pcall(function() self:DespawnCampHunt() end)
    pcall(function() self:DespawnCampInn() end)
    pcall(function() self:DespawnCampFoodCart() end)
    pcall(function() self:DespawnCampTrader() end)
    -- House props go with CampEntities; this just restores the grass CVar.
    pcall(function() self:ClearCampHouse() end)
    -- The wall's invisible obstacle blockers go with it. Without this they are left
    -- standing, solid and unseen, where the camp used to be.
    pcall(function() if self.NavObstBlockerClear then self:NavObstBlockerClear() end end)

    self.CampActive = false
    self:LoadStep("NavClearObstacles", function()
        if self.NavClearObstacles then self:NavClearObstacles() end
    end)
    self.CampEntities = {}
    self.CampPropLog = {}
    self.CampFitStats = { fitted = 0, tiltSum = 0, tiltMax = 0, moveSum = 0, moveMax = 0 }
    self.CampSlots = {}
    self.CampPatrollers = {}
    self.CampFurniture = {}
    self.CampActivities = {}
    self.CampMercSpots = {}
    self.CampNightLights = {}
    self.CampNightLightsOn = nil
    self.CampGuardTorch = {}
    self.CampRoleIdx = {}
    self.CampNextRotate = {}
    self.CampSeats = {}
    self.CampBeds = {}
    self.CampPlayerBed = nil
    self.CampBedSleepState = nil
    -- The player's master chest is LEVEL data and there is one per level, so the
    -- cached handle cannot be carried across a load into the other region.
    self.CampMasterChest = nil
    self.CampTicks = 0
    self.CampCommunalChairs = {}
    self.CampOutParty = {}
    self.CampRoster = {}
    self.CampCenter = nil
    self.ActivityTestEntities = {}
    self.CampChatMercCooldown = {}
    self.MercCampCombatFlag = {}
    self.CampChatStaggered = false
    _G.MercCampMode = false
    _G.MercInCamp = false
    self:LoadStep("ClearMercCampChats", function() mercenaries:ClearMercCampChats() end)
    System.LogAlways("[Camp] ClearAnyLeftoverCamp: completed")
end

-- ==== camp tuning / diagnostics ====

-- Re-pitch the standing camp on the same anchor with a new bed smart-object yaw, so the
-- sleeping pose can be checked without a rebuild-by-hand. +/-90 both lie the merc along
-- the bed; the sign decides which end his head is at.
function mercenaries:CampBedYawSet(line)
    local a = self:CmdArgs(line)
    local v = tonumber(a[1])
    if v == nil then
        System.LogAlways("[Camp] bed SO yaw fix is " .. tostring(self.CampBedSOYawFixDeg) .. " deg; usage: merc_camp_bed_yaw <degrees>")
        return
    end
    self.CampBedSOYawFixDeg = v
    System.LogAlways("[Camp] bed SO yaw fix -> " .. tostring(v) .. " deg")
    if self.CampActive then
        pcall(function() self:LogiRebuildCampForUpgrade() end)
    end
end

-- Print where a camp would go, and which upgrade tiles it would reuse. The whole of
-- issues "the tent lands behind me" and "the upgrades move after a reload" is readable
-- from this without pitching anything.
function mercenaries:CampAnchorReport()
    local p = self:CampTalkPartnerPos()
    if p then
        System.LogAlways(string.format("[Camp] conversation partner at %.2f, %.2f, %.2f - the tent would go there", p.x, p.y, p.z))
    else
        System.LogAlways("[Camp] no conversation partner in range - the tent would fall back behind the player")
    end
    local o = self.CampBuildOrigin or self:LoadCampOrigin()
    if o then
        System.LogAlways(string.format("[Camp] saved anchor %.2f, %.2f ang %.3f", o.x, o.y, o.ang or 0))
        local t = self:CampLoadStationTiles(o)
        local n = 0
        for name, v in pairs(t) do
            n = n + 1
            System.LogAlways(string.format("[Camp]   tile %-8s %.2f, %.2f", name, v.x, v.y))
        end
        if n == 0 then System.LogAlways("[Camp]   no saved upgrade tiles for this anchor") end
        -- Same question as the tiles, and the one behind "everyone follows me after a load":
        -- does the saved out-party belong to THIS pitch, or to one that is long gone?
        local blob = self:LoadString("MercOutParty")
        if not blob or blob == "none" then
            System.LogAlways("[Camp]   no saved out-party - everyone stays in camp")
        else
            local head, body = string.match(blob, "^([^|]*)|(.*)$")
            local cnt = 0
            for _ in string.gmatch(body or "", "[^;]+") do cnt = cnt + 1 end
            System.LogAlways(string.format("[Camp]   out-party %d man/men, anchor %s",
                cnt, head or "UNSTAMPED (will be discarded)"))
        end
    else
        System.LogAlways("[Camp] no saved camp anchor")
    end
    for _, name in ipairs(self:CampActiveStations()) do
        local s = self.CampStationTiles and self.CampStationTiles[name]
        System.LogAlways(string.format("[Camp]   live %-8s %s", name,
            s and string.format("%.2f, %.2f", s.x, s.y) or "NO TILE"))
    end
end

mercenaries:DevCommand("merc_camp_bed_yaw", "mercenaries:CampBedYawSet('%line')",
                   "Set the bed smart-object yaw fix in degrees and re-pitch the camp")
mercenaries:DevCommand("merc_camp_anchor", "mercenaries:CampAnchorReport()",
                   "Report the camp anchor, the conversation partner and the saved upgrade tiles")

-- Console front ends for the two quartermaster menus that are driven by an option index
-- (see LogiRemoveUpgrade / CampSetComposition). With no argument they print the list, so
-- the numbers never have to be remembered.
function mercenaries:CmdRemoveUpgrade(line)
    local n = tonumber((self:CmdArgs(line))[1])
    if not n then
        System.LogAlways("[MercCmd] merc_camp_remove <n>:")
        for i, u in ipairs(self.UpgRemovable or {}) do
            System.LogAlways(string.format("  %2d  %s", i, u.label))
        end
        return
    end
    self:LogiRemoveUpgrade(n)
end

function mercenaries:CmdComposition(line)
    local n = tonumber((self:CmdArgs(line))[1])
    if not n then
        local L = self:LogiState()
        System.LogAlways(string.format("[MercCmd] party is now: archers=%s, foot=%s",
            tostring(L.deployArchers), tostring(L.deployPick)))
        for i, o in ipairs(self.CampCompositionOptions or {}) do
            System.LogAlways(string.format("  %2d  %s = %s", i, o.field, o.value))
        end
        return
    end
    self:CampSetComposition(n)
end

-- Pull the nearest man out of camp / send him back, the console twin of the look-at
-- prompt (which needs the player to be looking at somebody).
function mercenaries:CmdCampJoinNearest(stay)
    if not player then return end
    local pp = player:GetWorldPos()
    local best, bd
    for _, ent in pairs(self.ActiveMercs or {}) do
        if ent and self:IsAliveAndWell(ent, true) then
            local ep; pcall(function() ep = ent:GetWorldPos() end)
            if ep then
                local d = (ep.x - pp.x) ^ 2 + (ep.y - pp.y) ^ 2
                if not bd or d < bd then bd, best = d, ent end
            end
        end
    end
    if not best then System.LogAlways("[CampDeploy] nobody nearby"); return end
    if stay then self:CampStayOne(best) else self:CampDeployOne(best) end
end

mercenaries:DevCommand("merc_camp_join_nearest", "mercenaries:CmdCampJoinNearest(false)",
                   "Take the nearest man out of camp with you")
mercenaries:DevCommand("merc_camp_stay_nearest", "mercenaries:CmdCampJoinNearest(true)",
                   "Send the nearest man back to camp")

System.LogAlways("[CampLoad] mercenaries_camp.lua FINISHED loading (5645 lines)")