# Mercenary Camp

A dialog option that spawns a procedural camp (tents, campfire, chairs, bedrolls) near the player, teleports the squad into it, and idles them there. The camp stays standing until explicitly broken — it does not despawn just because the player wanders off. A recall hotkey brings the whole squad to the player from anywhere without touching the camp itself.

This was built as an experimental feature, not a fully-realized one — see [Known limitations](#known-limitations) before relying on it for anything serious.

---

## How it works

**Trigger**: any merc's dialog → "Company management." → "Camp." → "Make camp here." / "Break camp." This lives in its own management/logistics hub, separate from the day-to-day squad orders (Wait/Follow/Dismiss). Console: `merc_camp_make` / `merc_camp_break`.

**Recall**: press **F4** to bring the whole squad to your current position immediately, from anywhere, and resume following — this does **not** break camp; the tents and fire stay standing, just empty, until you explicitly break camp. Console: `merc_camp_recall`. Rebind any time with `bind <key> merc_camp_recall`. The bind is (re-)applied every load via `System.ExecuteCommand("bind f4 merc_camp_recall")` in `OnGameplayStarted`, the same pattern the bodyguards reference mod uses for its own hotkeys (`references/bodyguards/data/Scripts/mods/kcdcompanion.lua`).

**Spawning the physical camp** ([mercenaries_camp.lua](../data/Scripts/mods/mercenaries_camp.lua)): every camp prop is a plain `class = "BasicEntity"` spawn with an `object_Model` property — confirmed against the vanilla `BasicEntity.lua` (`references/Scripts/Entities/Physics/BasicEntity.lua`): `OnSpawn` → `SetFromProperties` → `SetupModel` → `LoadObject(0, object_Model)` + `PhysicalizeThis()`. No custom entity class or `.ent` registration needed — this is the same trick `mercenaries_saving.lua` already uses for its data-holder entities, just with a real model attached. Model paths and the terrain-raycast-snap technique are lifted from `references/zdjbcamping_mod`, a working reference camping mod bundled for this purpose.

**Layout, built from fire "cells" around the player tent**: the player's own tent sits at the grid's origin, and fire cells (campfire + seats + tents, one cell per `CampClusterSize`, now 6, mercs) tile outward from it on a grid, rather than the player tent taking a slot in an otherwise-anonymous grid. The grid's axes are the direction the player was facing when camp was made (`forward`) and its perpendicular (`right`) — so "in front of the player tent" always means the direction the player was actually looking, not some fixed world axis. Two tiles are reserved: the one directly in **front** of the player tent is always left **empty** (open ground to walk in/out through), and the one directly **behind** is the **training** yard (see phase 2). So camping cells fill the remaining immediate neighbours — left, right, then the four corners (6 cells in the first ring, not 7) — and bigger squads spiral further outward ring by ring (`CampGridOffsets`), always still skipping the front and behind tiles. Grid tiles are `CampClusterSpacing` (10.5m) apart — 18m → 6m (a third) → 7m (+1m) → 10.5m (+50%) across three rounds of feedback. The seat ring (1.4m — 1.8m halved to 0.9m, then +0.5m) and tent ring (3.9m, was 6.0m, then halved to 3.0m, then bumped 30% back up to 3.9m) around each fire were separately tuned, so props within a cell sit closer to their own fire while tents themselves now have a bit more room between them.

- **Tent recipients**: the **non-guards only** (per the "6 tents for 12 mercs" change — guards patrol and get no tent), up to `CampMaxTents`. Each gets a tent and a bed, plus a random sack/crate beside the tent (see below); the seat by the cell's fire (one per merc in that cell) replaces the old separate personal stool, and there's no personal chest anymore (removed per feedback — see below). Confirmed in-game: `tent_small_forest_a/_b/_d`, `tent_small_shabby_a`, and `tent_small_rustic_a` (`CampTentVariants`) all share roughly the same footprint and face the same way, so each tent in camp picks one of the five at random for visual variety instead of using one fixed model. All five are vanilla one-NPC "sleeper" tents (`tent_small_forest_a` is the one `references/Prefabs/Tent/tent_1.xml` uses for a single soldier's sleeping tent). This replaced an earlier choice, `tent_big_square_b_hungarien_green.cgf` — the canvas body of the "big square" tent used in `references/zdjbcamping_mod`'s Cuman/Poacher/Wayfarer tent prefabs as one piece of a ~20-prop camp centerpiece assembly — which was far too large for a single merc's personal tent. (An even earlier version used a *different*, similarly-named model from that same prefab, `..._hanger_b.cgf`, which turned out to be just the interior rope for hanging a lantern, not a tent at all — that's the "floating wire in the air" bug that got reported and fixed before the sizing issue.) Spawned tents get an extra 90° rotation (`CampTentFacingFix`) on top of the computed facing, confirmed correct in-game. See [Comparing tents](#comparing-tents) below for the rejected candidates (two face the wrong way, one's open both ways, one's the old oversized default).
- **Tent ring has a built-in gap.** Per feedback ("calculate with there being seven tents, but leave one tent spot empty, to allow movement"), each cell's tent ring is spaced for `CampClusterTentRingSlots` (7) positions even though at most `CampClusterSize` (6) tents actually get placed into it — a full cluster leaves exactly one ring slot open, so the ring of tents around a fire is never a fully closed circle.
- **One weapon stack per fire, instead of a stool.** Per feedback, the first seat slot in every cell's seat ring spawns `CampModels.WeaponStack` (`polearm_pile_a.cgf`) instead of a chair — the rest of that cell's seats are still plain chairs.
- **Beyond the cap**: excess mercs (squads bigger than `CampMaxTents`) get the same bed (see below) on an outer ring instead, no tent, no fire cell.
- **No more personal chest.** Removed entirely per feedback — `CampModels.Chest` is still defined (in case it's wanted again) but `SpawnMercCamp` no longer spawns one.
- **A separate, central player tent.** One `tent_big_round_a.cgf` (one of the "large white circular" tents, rejected for mercs since it faces the other way — see [Comparing tents](#comparing-tents)) spawns once per camp, at the grid's own origin, with its own bed (`bed_double_fancy_a.cgf`, the "wide/large" bed rejected for mercs) inside. Its facing is now tied to the same `forward` direction the whole grid is built around, so its entrance opens toward the one reserved empty tile rather than a fixed world angle. See [The player tent](#the-player-tent) below, the least-proven part of this whole feature.

**Beds**: both tiers use the same model now, `bed_shabby_a.cgf` — confirmed in-game to be the only candidate that actually reads as a bed in tall grass rather than a rag, a pile of skins, or (for one candidate) an invisible/broken placeholder. See [Comparing beds](#comparing-beds) below for the full rejected list.

**Campfires switched to a whole different spawning technique.** Two earlier rounds fixed a particle-pairing bug and a missing-rotation bug, but the fundamental problem turned out to be the approach itself: manually assembling a wood-prop model + a `ParticleEffect` entity mostly produced **invisible** props in-game — `camp_cooking_a`/`_b` rendered (just too large), but every other hand-picked `.cgf` path (`fireplace_wood_a/b/c`, `grid_fireplace`/`_b`, even the original `camp_cooking_c_old`/`_d_old`) came back invisible despite using the exact same spawn mechanism that works fine for every other camp prop. Most likely explanation: those specific paths, hand-picked from a static reference dump, don't all resolve to assets that actually exist in the shipped game the same way — there's a real limit to guessing individual file paths blind.

So campfires now spawn via `Game.SpawnPrefab` against an invisible anchor entity instead (`SpawnCampFirePrefab`, `mercenaries_camp.lua`) — the exact same technique `references/zdjbcamping_mod`'s own `DJB_Camping:SpawnCampfirePrefab` uses (confirmed by grepping every `Game.SpawnPrefab` call in that mod's Lua). A prefab GUID is a more load-bearing identifier than an internal file path, and the whole pre-authored prefab already has its wood/particle/light pieces correctly positioned relative to each other, sidestepping the per-model Z-offset/rotation guessing entirely. New default: `fireplace_on_camp.xml`'s own prefab (`CampFirePrefabId`) — the vanilla "reference lit campfire" identified two rounds ago (`fireplace_wood_c.cgf` + `fireplace_nosmoke_low` + a Light). See [Comparing campfires](#comparing-campfires) below.

**Non-guards sit or sleep (half/half).** Every non-patrolling merc in camp either sits on a stool or lies in a bed, split roughly evenly (assigned in the same random shuffle that picks guards — see below).

**How the game actually does sit/sleep spots.** Two failed attempts got this wrong before the answer turned up in the level prefabs. Every vanilla sit/sleep spot is a *prefab containing two separate objects*: the visual brush (the bed/bench model) **and a dedicated `StanceSmartObject` entity** that holds the smart object. See `references/Prefabs/Bed/bed_low.xml` — which uses our exact `bed_shabby_a.cgf` model — and `references/Prefabs/Bench/bench_1place_low.xml`. In both, the `BedTrigger`/`ActionTrigger` (player interaction) and the `SchedulerHub` (NPC scheduling) merely *link* to the `StanceSmartObject`; they never carry the SO properties themselves. `StanceSmartObject` (`references/Scripts/Entities/WH/Bed/StanceSmartObject.lua`) is a **vanilla class** whose own doc comment reads *"Smart object representing a place where stance can be played. Intended for sitting and lying stance both for NPCs and player"* — and it's spawnable by name, exactly like the vanilla `BedTrigger` we already spawn.

The earlier versions hung the SO properties (`guidSmartObjectType`, `soclass_SmartObjectHelpers`, …) directly on the bed/stool `BasicEntity` prop. That's enough for the *player's* `BedTrigger` to resolve a smart object, which is why the player bed works — but it never gave NPCs a usable stance spot, so the mercs just stood around.

**What it does now.** `SpawnCampFurnitureSO` spawns **two** entities: the decorative prop (plain `BasicEntity` + model, no SO properties) and, co-located and identically rotated, a `StanceSmartObject` carrying the property set copied verbatim from those prefabs (`CampBedSO` / `CampChairSO`). It returns the `StanceSmartObject`'s AI WUID (`XGenAIModule.GetMyWUID` — a spawned entity's plain `.id` is not a valid smart-object handle) plus its position, both stored in `CampFurniture[mercWuid]`.

`camp_actor.xml` then runs a **two-step** sit/sleep case: first `Move` the merc to the smart object's `vec3` position (`changeNPCState="true"` — the same proven move-to-a-point setup the guard patrol uses), then `StanceElement` against its WUID with `stance="lying"` / `"sitting"`. The `Move` is there because `StanceElement` does **not** navigate on its own: `references/AI/world/so_bed.xml`'s `use` tree is just a `StanceElement` on `$__object.id`, and vanilla relies on the scheduler having already walked the NPC to the spot.

**`StanceElement` needs a `<WaitAction/>` inside it.** With the smart objects spawning correctly and the `Move` working, mercs would walk to their bed/stool and then simply *stand on it*. The reason: `StanceElement` only declares the stance requirement — **`WaitAction` is what actually executes and awaits the enter (sit/lie) animation.** A bare `<Wait>` timer as the child is not enough. Every vanilla example is the same shape:

```xml
<StanceElement smartObject="..." stance="sitting" allowAny="false">
  <Sequence>
    <WaitAction />                 <!-- plays/awaits the sit-down animation -->
    <Wait duration="'5s'" ... />   <!-- how long to hold the pose -->
  </Sequence>
</StanceElement>
```

See the minimal `references/AI/test/SAL_showcase/test_sit.xml` and `test_sleep.xml`, and the `use` trees of `so_bed.xml` / `so_sitPlace.xml`. Our cases now match this exactly; the trailing `Wait` (40s ±20s) is just the hold time before they stand and re-enter.

Run `merc_camp_furniture_debug` in console to dump the pipeline state (SOs spawned → per-merc assignments → guard count); the first line that reads `0` is where it broke.

**Moving the squad in**: each merc is teleported directly (`ent:SetPos(...)`) to a slot near their housing, then the squad is put into the existing `_G.MercIdle` "wait" state — the same state the regular Wait order already uses. Mercs now stand a bit in front of their own bed (`CampMercStandOffset`, computed the same relative-offset way as `CampBedOffset`) instead of right on top of it — `forward = 1.8` (bumped by another 0.5m per feedback). This also had a bug: the stand-offset was silently computed relative to the *tent's* facing instead of the bed's (because the bed's own rotation was being discarded — see below), which is very likely the "wrong axis" — now fixed alongside the bed-rotation bug, so it's relative to the bed's actual facing as originally intended.

**Camp roles: half patrol, the rest sit/sleep — a distinct `incamp` state.** Making camp introduces a third merc state alongside idle and following: **`incamp`** (`_G.MercInCamp`). Every merc gets a camp *role*, assigned up front in a single Fisher-Yates shuffle of merc indices (random, not tier-based): half the squad (`math.floor(mercCount / 2 + 0.5)`) become **guards** (patrol); the remaining non-guards are split evenly into **sitters** and **sleepers**. The shuffle only picks roles; `mercList` keeps its strong→medium→weak sort order for tent/bed layout. A merc's role is queried per-cycle via `mercenaries:IsCampGuard` (has a patrol-waypoint record) and `mercenaries:GetCampFurniture` (has an assigned sit/sleep smart object); `mercenaries:IsCampActor` is true if either — i.e. the merc has any camp activity.

How the state routes through the behavior trees:
- **Camp actors** (guards, sitters, sleepers — `$isCampActor`) are deliberately *excluded* from the schedulers' idle stand-still branch (`$isIdle & ~$isCampActor`), so they fall through to the normal follow branch, which fires the `camp_actor` behavior. That's the "the incamp state is so the follow script does the move nodes" part: rather than adding a second mover, every camp activity reuses the proven follow-BT machinery.
- **Plain idle mercs** (a Wait order, not in camp) stay in the idle branch and stand.
- Inside `camp_actor.xml`, the main `ContinuousSwitch` gets three new cases ahead of the player-follow/horse cases (first-match wins), each refreshed each second from Lua: **guard** → patrol (`Move` to the current waypoint via `GetPatrolWaypoint`, advance, pause); **sleeper** → `StanceElement stance="lying"` on the assigned bed WUID; **sitter** → `StanceElement stance="sitting"` on the assigned stool WUID. Horse-spawning is suppressed while `_G.MercInCamp` so nobody mounts up mid-camp.

Each guard patrols an 8-point ring encircling the whole camp, staggered by a per-guard angular offset so they spread around the perimeter rather than clumping. The ring radius (`patrolRadius`) is sized to sit ~3m outside the outermost tent per feedback: `maxClusterOffset + CampTentRingRadius + CampPatrolTentClearance` (farthest cluster from centre + how far a tent sits from its fire + 3m clearance), so the route goes *around* the camp rather than cutting through the tents.

**Waypoints are positions, not entities — and that was the bug.** The first attempt spawned invisible `BasicEntity` markers and `Move`d to them as entities; the guards **flat-out refused to move**. Root cause, found in `references/Scripts/Entities/Physics/BasicEntity.lua`: that class leaves `EntityCommon.MakeTargetableByAI` **commented out**, so a plain `BasicEntity` is never registered with the AI system as a navigable target — pathfinding couldn't resolve the marker, and the `Move` silently did nothing. (A second contributing bug: the `Move` used `changeNPCState="false"`, which is only correct for *continuously following a moving actor*; every base-game move-to-a-fixed-point uses `changeNPCState="true"`, and `"false"` leaves a standing NPC frozen.) The fix: don't use entities at all. Each waypoint is a plain `{x,y,z}` position, and the follow BT `Move`s to a **`vec3` destination** directly — exactly how `references/AI/world/so_ladder.xml` moves an NPC to its `vec3 $t_entryPos`. Lua fills the BT's `vec3` variable component-wise (`data.patrolWaypoint.x = …`), the same pattern `references/AI/quests/questbehaviors.xml` uses, and the `Move` runs with `changeNPCState="true"`. No marker entities are spawned anymore.

"Standing around" between waypoints is just not issuing a `Move` — the engine's own idle animation set takes over once movement stops. Breaking camp or recalling clears `_G.MercInCamp`, so guards drop out of the patrol case on their next follow-BT cycle and resume normal player-following seamlessly.

**Camp persistence**: the camp does not auto-despawn based on player distance. It stays up until "Break camp" is chosen explicitly (dialog or `merc_camp_break`). An explicit Follow or Dismiss order also breaks camp first (silently, since that order's own info text covers it) — otherwise the props would sit there abandoned with no mercs nearby. Recall does *not* break camp (see above).

**Save/load**: camp survives a save. The props themselves are not serialised (they are runtime `System.SpawnEntity` spawns) — instead the camp is *rebuilt* from the one thing that is saved: **where it was pitched**. `SpawnMercCamp` records `CampBuildOrigin = {x, y, z, ang}` once the centre is settled, and `SaveCampState()` persists it plus a "camp is standing" flag (`MercCampActive`); `BreakMercCamp` clears both, so a struck camp stays struck.

On load, `mercenaries:ClearAnyLeftoverCamp()` (from `OnGameplayStarted`) first sweeps any leftover props by name prefix, then `RestoreCampDelayed` (4s, after the 2s merc-cache rebuild — it needs `ActiveMercs` to hand out tents) calls `SpawnMercCamp(savedOrigin, silent)`.

`SpawnMercCamp(atOrigin, silent)` takes that anchor instead of using the player's position/facing, which is what makes the camp come back *in the same place with the same layout* rather than in front of wherever the player now stands. The same path is used by `LogiRebuildCampForUpgrade` (see below). Re-running the origin through the centre searches is stable: they tie-break toward the asked spot, so a saved centre wins again and the camp doesn't drift across reloads.

**Camp upgrades are tiles**: every upgrade (forge, alchemy bench, hunting station, tavern, food cart) claims its own **grid tile** out of the cells the campfire clusters didn't take — same `CampClusterSpacing`, same `CampTileHalf` footprint validation, same `usedCell` bookkeeping (`CampActiveStations` → `CampStationTiles`, read back via `CampStationSpot`). That is what gives each upgrade the same room as a tent ring and makes overlap structurally impossible. The practice yard owns the reserved `(0,-1)` tile and the player house replaces the `(0,0)` tent, so neither needs one. Since a tile can only be reserved while the grid is being laid out, buying an upgrade mid-camp rebuilds the whole camp (`LogiRebuildCampForUpgrade`, at the saved origin) rather than squeezing the new structure into a gap.

---

## Look-at prompts on a merc

Looking at a merc shows up to two mod prompts alongside the vanilla ones (`InjectInteraction`, [mercenaries_lookatinteraction.lua](../data/Scripts/mods/mercenaries_lookatinteraction.lua)). The standard vanilla actions (Talk, Pickpocket, …) are preserved by calling through to `BasicAIActions.GetActions`; prompts only draw when the merc is conscious and alive. The looked-at merc barks an acknowledgment on each action.

**1. Camp option** (always shown) — decided live at press time from `CampActive` and whether *this* merc is currently deployed out of camp (`IsCampOut`):

| State | Prompt | Action |
|---|---|---|
| No camp | Make camp | `SpawnMercCamp` |
| Camp up, merc in camp | Break camp | `BreakMercCamp` |
| Camp up, merc deployed | Back to camp | `CampReturnAll` (returns the whole sortie) |

**2. Wait / Follow toggle** — only for a merc "in a sortie" (deployed out of camp, or the whole squad when there's no camp; `IsMercInSortie`). It flips the global sortie wait order (`SetSortieWait` / `_G.MercPersistentIdleFlag`); mercs left in camp ignore it. Hidden for a camped merc. It uses the `use_other` hold action (the way `references/CompanionMerchant` drives its second prompt — `alch_use` rendered a blank entry).

Bark requests key off the entity id (`self.this.id`), which is what the follow-BT bark lookup expects — not the AI WUID.

---

## Known limitations

- **Merc sit/sleep took three passes; the last fix isn't playtested yet.** History, since each failure looked identical (mercs standing around) but had a different cause: (1) SO properties hung on the prop `BasicEntity` — no real smart object existed; (2) real `StanceSmartObject` entities + `Move`, but the `StanceElement` child was a bare `<Wait>`, so the stance was *declared* but the sit/lie animation never executed — mercs walked to the furniture and stood on it; (3) added the required `<WaitAction/>`. Confirmed working up to stage (2) via `merc_camp_furniture_debug` (5 SOs spawned, 5 assignments with WUIDs, correct walk-to positions), so only the animation step is unverified. If they still don't pose, the remaining unknown is whether `StanceElement` needs the SO's `use` resource reserved — vanilla routes NPCs through a `SchedulerHub` link, which we bypass by calling `StanceElement` directly. Note the old disabled `StanceElement` comment blocks still sit in both scheduler XMLs' idle branches — inert, superseded by the follow-BT version.
- **Campfires switched to `Game.SpawnPrefab`, not re-checked in-game yet.** Manual wood+particle assembly turned out to mostly spawn invisible props (see above and [Comparing campfires](#comparing-campfires)) - switched to spawning a whole pre-authored prefab by GUID instead, the same technique `references/zdjbcamping_mod` itself uses for its own campfires/beds/chairs. This is a different-enough mechanism (an anchor entity + `Game.SpawnPrefab`, vs. the plain `BasicEntity` spawns used everywhere else) that it needs its own in-game check, and there's an open question about teardown: the prefab's own spawned pieces keep whatever names were authored into them, so `ClearAnyLeftoverCamp`'s name-prefix sweep can't independently catch orphaned ones from a camp that was active during a save (only removing the tracked anchor entity, in the normal `Break camp` path, is relied on to take them with it).
- **The player bed's "E — Sleep" interaction now uses a vanilla `BedTrigger`, matching the camping mod (unverified in-game, but built on the mechanism that mod actually uses).** The earlier attempt bolted an `OnUsed` handler onto the bed; that never fired (see [The player tent](#the-player-tent)). The bed is still a smart-object `BasicEntity`, but the interaction comes from a separate `BedTrigger` entity spawned next to it and linked by an empty-named link — exactly how `zdjbcamping_mod` does it. Trigger geometry (`CampPlayerBedTriggerOffset`/`Scale`) is a first guess and may need tuning if the prompt is awkward to catch.
- **No leaning animation.** A vanilla leaning smart object does exist (`SO_LeaningRail`/`SO_CheeringSpot_Leaning` in `references/Scripts/Entities/WH/Special/`, registered under `references/Libs/Tables/ai/smartEntity/SmartEntity__so_leaningRail.xml`) — but unlike `so_sitPlace`/`so_bed`, both are derived from `SmartObjectHolder`, a proper custom entity class that needs real `.ent` registration, not the zero-`.ent` `BasicEntity` + `properties` trick every other camp prop (and this whole mod) relies on. There's also no fence/railing prop in the current camp layout that a "leaning" spot would make sense on. Investigated and deliberately left out rather than bolting on the mod's first custom `.ent` class for a cosmetic extra.
- **Guard patrol: the "refuse to move" bug is fixed, but the fix isn't playtested yet.** The freeze was traced to `Move`-ing to non-AI-navigable `BasicEntity` markers (plus `changeNPCState="false"`); patrol now `Move`s to raw `vec3` positions with `changeNPCState="true"` — see [How it works](#how-it-works). That's the highest-confidence fix (both halves have direct base-game precedent — `so_ladder.xml` for the vec3 `Move`, every point-move for `changeNPCState="true"`), but it still needs an in-game confirm. If guards *still* don't move, the next suspects are: the follow BT not firing for guards at all (add a log in the `$isCampGuard` case), `IsCampGuard` returning false (check `_G.MercInCamp` is set and the `CampPatrollers` key matches `entity.this.id`), or the Lua→`vec3` component assignment not taking. If they move but jankily: pause timing, or pathing on broken terrain. Key points: `IsCampGuard`/`GetPatrolWaypoint` in `mercenaries_camp.lua`, the `$isCampGuard` case in `camp_actor.xml`, and `$isIdle & ~$isCampGuard` in both schedulers.
- **The fire-cell grid layout is new and unverified.** `CampClusterSpacing` (7m) and the seat/tent ring radii (0.9m/3.0m) are best-guess numbers tightened per feedback, not measured against the actual tent footprint in-game — expect to need to retune again once you've seen a multi-cell camp (12+ mercs), especially since tighter spacing raises the odds of clipping. Tent facing (`CampTentFacingFix`) and bed placement (`CampBedOffset`) are both confirmed correct now (see below).
- **The player-tent-centered grid, the tent-ring gap, and the tent-side clutter offset are all brand new and none have been checked in-game.** The grid now orients itself off `player:GetDirectionVector()` at the moment camp is made rather than a fixed axis, `CampGridOffsets` has only been reasoned through (not run against a real multi-cluster camp), and `CampTentClutterOffset` is a first guess at where a sack/crate can sit beside a tent without overlapping the bed or the merc's own stand spot. Expect to need another tuning pass on all three once you've seen a camp go up.
- **Cluster cells are now ground-validated, but individual props inside a cell aren't.** Camp cluster positions are probed and rejected if they land on a roof, a hillside, a tree, or a step (see [Ground validation](#ground-validation) below), so the whole camp no longer lands on a building. But *within* an accepted cell each prop is still only ground-snapped, not obstacle-routed — on broken terrain expect the odd clipped or floating prop inside an otherwise-valid cell. The player tent at the grid origin is placed where the player stood and is **not** itself validated (only the clusters around it are). Patrol waypoints are snapped but the path between them isn't guaranteed clear. Unverified in-game — use `merc_camp_scan` to eyeball what the validator accepts before trusting it.
- **Combat while camped inherits the existing Wait-state limitation**: non-guard mercs idling under `_G.MercIdle` don't fight back today regardless of cause (this isn't new to camp — the same applies if you just tell them to Wait). Recall or break camp if trouble shows up. Guards are different: because they run the `camp_actor` behavior, the schedulers' normal combat path (firing `combat_melee`) preempts their patrol the same way it preempts following, so a guard that picks up a target fights and then resumes patrol afterward — but the non-guard camp mercs standing by still won't.
- Large squads (more than `CampMaxTents`, 10) won't get everyone a tent — see the caps above; excess mercs beyond the sort order just get the bed-on-an-outer-ring treatment, no tent/fire cell.

---

## Comparing tents

**Resolved.** Confirmed in-game: the first five candidates (`tent_small_forest_a/_b/_d`, `tent_small_shabby_a`, `tent_small_rustic_a`) are all small, sized to fit a bed under them, and face the same way — used interchangeably at random now (`CampTentVariants`). The next two (`tent_big_round_a`/`_b`) are large white circular tents facing the *other* way — rejected. `gypsycamp_tent_b` is small but open on both ends — rejected. The old default (`tent_big_square_b_hungarien_green`) is gigantic — rejected.

*(The `merc_camp_tent_test` comparison-row command and its `CampTentCandidates` table were removed in the code cleanup once the choice was settled; the findings above are the record.)*

---

## Comparing beds

**Resolved.** Confirmed in-game: `bed_shabby_a` is an actual straw bed with a log frame, and the only one of the seven that stays visible in tall grass — that's what `CampModels.Bed`/`BedStraw` both use now. Everything else was rejected: `bed_makeshift_a` is just a rag, `bed_makeshift_c` is a pile of skins, `bed_shabby_b` didn't stand out, `bed_fancy_a` and `bed_double_fancy_a` (the two "high"-tier vanilla home beds, the latter a wide two-person one) were both passed over, and `bed_cottage_01` (the generic vanilla `Bed` entity's own default model) rendered as a blank white shape — likely an invalid/wrong-cased path rather than an actual bed asset.

*(The `merc_camp_bed_row_test` comparison-row command and its `CampBedCandidates` table were removed in the code cleanup once the choice was settled.)*

---

## Comparing campfires

**Round 1**: all 6 candidates forced through `WH_Particels.fires.exterior_fireplace` — none looked good, `camp_cooking_d_old` (an explicitly "abandoned fireplace" model elsewhere in vanilla) was the only one called acceptable.

**Round 2**: expanded to 9 candidates, each paired with the effect its *own* vanilla prefab actually uses (round 1 forced `fireplace_wood_c` through the wrong effect).

**Round 3 result**: "all currently attempted prefabs are invisible except the first two, which are too large" — i.e. of the 9 manually-assembled candidates, only `camp_cooking_a`/`camp_cooking_b` render at all (and they're oversized), everything else is invisible. This means the manual wood+particle assembly approach itself is the problem, not any individual model/effect pairing — see [How it works](#how-it-works) above for why.

The winning approach spawns a whole pre-authored prefab by GUID instead:
- `fireplace_on_camp` prefab — **default**, the vanilla self-contained lit campfire (`fireplace_wood_c` + `fireplace_nosmoke_low` + a Light, all pre-aligned)

**Round 4 — confirmed working.** `fireplace_on_camp` renders in-game as a small heap of smouldering ash. Per feedback, `SpawnCampFirePrefab` now also layers `camp_cooking_c_old.cgf` (`CampFireOverlayModel`) as a plain static overlay on top of the ash heap, at the same position/facing, for a fuller wood-pile-over-embers look.

*(The `merc_camp_fire_test` comparison-row command and its `CampFireCandidates` table were removed in the code cleanup once the prefab approach was settled.)*

---

## Camp activities (making the camp feel alive)

**How NPC activity animations work.** The engine plays named NPC actions through the `UnstanceAction` behavior-tree node. Every playable name is catalogued in `references/Libs/Tables/ai/NPCStateUnstanceDatabase.xml` as an `<UnstanceData Name="...">` entry with `In` / `Loop` / `Out` animation fragments. The whole mechanism is visible in `references/AI/profession/camper/so_camperFemaleEating.xml`, whose entire `use` tree is:

```xml
<StanceElement smartObject="..." stance="sitting">
  <Sequence>
    <UnstanceAction unstance="eating" locationObject="..." />
    <Wait duration="'15s'" />
  </Sequence>
</StanceElement>
```

Three facts make a generic system possible:

1. **Standing actions need no `StanceElement` at all** — `references/AI/situation/dogbarkingpasserby/situation_dogbarking.xml` just calls `<UnstanceAction unstance="dogBarking" locationObject="" />` directly.
2. **`unstance` accepts a variable** (vanilla uses `unstance="$unstance"` in the `smallTalkingWatchers` trees), so *one* BT node can play *any* action by name.
3. Each `UnstanceData` declares `UseLocationObject` and `IsAligned`. Actions with `UseLocationObject="false"` need **no prop or anchor whatsoever**.

**The modes.** `CampActivityCatalogue` in `mercenaries_camp.lua` tags each activity with what it needs, and `camp_actor.xml` has one `ContinuousSwitch` case per mode (placed first, so an activity preempts patrol/sit/sleep/follow):

| Mode | Meaning | Examples |
|---|---|---|
| 1 | Sit on a seat smart object, then play the action | `camper_snooze`, `readingSittingNoTable` |
| 2 | Stand, no anchor, no prop | `noob_sword_training`, `eating_standing`, `woman_cookingCampfire_loop` |
| 3 | Stand, aligned to an anchor entity | `lumberjack_woodChopping`, `sawingWood` |
| 4 | Duo animation pair — leader passes partner as `slaveObject` | *(confirmed broken, unused)* |
| 5 / 6 | **Real conversation** — polylog initiator / receiver | *(see below)* |

**The rule that decides whether an action works.** Two rounds of in-game testing produced a clean law:

> An action plays iff its `UnstanceData` has **`UseLocationObject="false"`** *and* it needs **nothing in the merc's hands** — and, for **seated** actions, the seat smart object must be passed as the `UnstanceAction`'s **`locationObject`**.

The `locationObject` clause was round 2's discovery (mode 1 was passing an empty one). But round 3 showed that fixing it *still* didn't make the `sit_*` actions play — so the real blocker is the same one the sword drill has: they need a **held item** the fragment doesn't bring (a book for `readingSittingNoTable`, dice for `diceSitting`, a flute for `flutist_sitting`, a spindle, a cup) or, for the `SittingTable*` ones, an actual **table** smart object rather than a stool. Giving a merc a specific item is real inventory/equip work, so all of these are now `x_`-prefixed and kept out of the schedule; only `camper_snooze` (which needs nothing) is used seated. The two item-less body-language poses (`sit_nervous`, `sit_sad`) are the best candidates if seated variety is wanted later.

- ✅ Confirmed working: `noob_sword_training`, `eating_standing` (spawns its own bun!), `camper_snooze`, `PickingHerbsNPC` ("works very well"), `Loot`, `woman_cookingCampfire_loop` (now spawns fire **+ kettle** so there's a pot to stir), plus the plain standing emotes.
- ❌ Everything defaulting to `UseLocationObject="true"` — chopping, sawing, `camper_cooking`, wagon pushing, and round-2 additions `sweeping`/`butcherSmokeHouse*`. The merc stands at the anchor. These want the full authored rig (align points + a tool item) that `so_choppingWood.xml` builds via `GraphSearch`. Not worth rebuilding — `PickingHerbsNPC`/`Loot` are the working labour loops instead.
- ❌ `DrawAction` before an unstance is **useless**: the unstance's `In` fragment re-sheathes the weapon first (round 2: "pull out their sword, sheathe it, then start"). The `drawWeapon` flag is gone; the sword drill mimes bare-handed, which reads fine at a straw dummy.
- Round-2 rejects (`x_` prefixed so they don't get retried): `sweeping`, `butcherSmokeHouseStoke/Fill`, `ratbor2_SoldierBored`, `halberdierGuard_atAttention`, `mildCheering`, `sermiri_showOff`, `Pointing_withoutScope` (memorably: just points at the player), `alchemy` (mimes at an invisible bench).

**Conversation — the bodyguards-mod technique, done properly.** The earlier one-shot attempt (assign one merc "speaker", the other "listener") never worked because the two were never in their respective polylog branches *at the same time*. The bodyguards mod's actual trick is a **shared global**: `kcdcompanion.ChatTick` publishes a pair in `_G.CompanionChat = {a, b}`, and every companion's follow BT reads its `chatRole` (1 = initiator, 2 = receiver) off that global *each cycle* — so both drop into `Function_speech_schedulerPolylog_initiator`/`_receiver` on the same tick, and the engine syncs them into real ambient voice lines. Replicated: `mercenaries:CampChatTick` (driven by `MonitorCamp`) picks two mercs within `CampChatRadius` and sets `_G.MercCampChat`; the follow BT's `chatRole` sensing + two polylog cases (placed **first** in the `ContinuousSwitch`, so a chatting merc turns to talk regardless of what they were doing) mirror `companion_follow.xml`.

**Structure: straight into the gossip, no greeting.** Each talk is just the gossip topic followed by a farewell (`SITUACE_ROZLOUCENI`) — the greeting (`SITUACE_POZDRAVY`) was removed per feedback, on both the initiator and receiver side. The termination is **dialogue-driven**: the whole exchange sits inside a `Timeout duration="'5m'"` safety net (not a length limit — each line blocks and plays in full), and the initiator calls `mercenaries:EndCampChat` the moment its sequence finishes, which clears the pair from `_G.MercCampChats`, drops both mercs' `chatRole` to 0, and applies their per-merc cooldowns. The only timed cutoffs (`CampChatHoldTicks` ~6 min; the BT's 5 m `Timeout`) exist purely so a hung line or a despawned participant can't trap a merc forever.

**Custom two-NPC gossips, fully voiced, reusing vanilla voicelines (32 and counting).** On top of the generic vanilla gossip pool, the mercs have a growing set of their own campfire conversations (`gossip_merc_2..33.xml`, added in batches). Each is a Skald `Dialog` built exactly like a vanilla gossip (`gossip_obecny__muz__muz_kutnohorsko_outskirts.xml`): roles `GOSSIP_OBECNY_MUZ_1`/`GOSSIP_OBECNY_MUZ_2`, `Autoselect="true"`, `VoiceoverFallbackLevel`, and a `Decision Alias` (`merc_gossip_N`) wrapping one `Sequence` of `Response` lines referencing existing vanilla string ids (drawn from many source dialogs — `goss_gossip_*`, `jurk_*`, `band_event_cri_*`, `voja_stajmistr_*`, etc.). Registered in the **kutnohorsko** quest only (identical `Decision Alias` in both region quests would collide). Every conversation is all-male — feminine-grammar lines (e.g. `goss_gossip_na_slysela_*`, "*slyšela*") were only recorded by female voices and are avoided.

**Voiceover.** VO audio is loaded from `.ogg` files named `<voice>_<StringName>.ogg`, keyed by the **cast soul's** voice (the `SelectedSoul Voice` attribute is only an editor reference; a `VoiceoverFallbackLevel` single-copy approach was tested and does **not** work). `PackageMod.bat` flattens everything under `voice/` into `localization/english.pak` at internal path `dialog/mercenaries_background_quest/`, which is where the game looks for VO of any dialog in this quest — so the dialogs need no relocation. Because camp pairs are random and the mercs only ever use voices jcom/phos2/sbar, each line's recording is shipped under **all three** merc-voice prefixes (`voice/gossip/{jcom,phos2,sbar}_<string>.ogg`). Each conversation was sourced so both speakers' lines come from an actor pair that actually recorded them together (within a bark block different lines are voiced by different, non-overlapping actors); speaker A's lines carry actor A's recording under every merc prefix and speaker B's carry actor B's, so the exchange always sounds like the intended two-voice pair no matter which mercs are cast. Subtitles come free from vanilla localization in every language.

They're played by **alias**: `CampChatTick` tags each pair with a random `merc_gossip_N` in `_G.MercCampChats[wuid].alias`, the follow BT reads it into `$chatAlias`/`$hasChatAlias`, and the gossip step is a `Selector` that plays that specific dialog (`Function_speech_schedulerPolylog_initiator alias="$chatAlias" metarole="'GOSSIP'"` / `_receiver aliasOrMetarole="$chatAlias"`; initiator casts into MUZ_1, receiver into MUZ_2) and **falls back to the generic vanilla `GOSSIP`/`FALLBACK_GOSSIP` pool** if no alias was assigned.

**How often conversations happen (concurrent, capped, staggered).** Conversations run **concurrently** — each 5 s `CampChatTick` greedily pairs up eligible mercs within **`CampChatRadius` (4 m)**, up to **`CampMaxConcurrentChats` (2)** running at once camp-wide (published per-merc in `_G.MercCampChats[wuid]`, not a single global pair). There's **no global gap** beyond that cap. Cadence is governed entirely by a **per-merc cooldown** (`CampChatMercCooldownTicks`, ~5 min): after a merc's conversation ends, both participants wait 5 minutes before they're eligible again, so each merc chats roughly once every 5 minutes. To avoid every merc becoming eligible on the same tick, the cooldowns are **staggered** — on camp start (`CampChatStaggered`, one-time) each merc is seeded with a random `0..max` slice, spreading first conversations across the window. `CampChatTick` also ages each live pair and force-clears any that overruns `CampChatHoldTicks` (~6 min, stuck-pair safety), and skips fighters and mercs mid-drill.

**The daily schedule.** Guards take half the squad, permanently ("a good portion should always patrol"). The rest are split into **trainers** (`numDummies` of them — `ceil(mercCount / 5)`, cap 5, per "about 1 per five mercs practising") and everyone else. Trainers run a training-heavy cycle (`CampTrainerCycle`); the rest never practise and run `CampRoleCycle` (`sleep → sit → eat → herbs → snooze`). Each merc rotates on its **own** per-role timer (`CampRoleSeconds`): sleeps and sits run **2–5 minutes** (per feedback), eat/forage/train are shorter so the camp keeps shuffling. `MonitorCamp` checks the timers each 5s tick and, when one elapses, advances that merc and it **walks** to the next spot.

**Seating is one ring of log stumps around the campfire** (per feedback — the earlier design had *two* rings, per-merc stools plus decorative chairs). The seat is the small vertical trunk stump (`chair_trunk_c`, the one the sit activities used in testing), and each is a real sit smart object turned to face the fire, and they're a **shared pool** (`CampSeats`): when a merc rotates to `sit`/`snooze` it claims a **free log a bit further from where it is** (`ClaimSpot` picks among the farther half of free seats), so the merc walks across camp to sit — same for **beds** (`CampBeds`, one per non-guard tent). eat/forage happen at the merc's own spot just outside the tent circle. Standing activities `Turn` to face the campfire (or, for trainers, the dummies) after arriving, since `Move` otherwise leaves them facing whichever way they walked in.

**The training yard** is placed **behind the player tent** (`CampTrainingYardDistance` m along `-forward`), in the `(0, -1)` tile `CampGridOffsets` reserves for it — the reserved *empty* tile is `(0, 1)`, in front. (This moved from in-front to behind in phase 2, per the tile spec; dummy/trainee facings were flipped to match and need in-game confirmation.) It gets **up to five straw dummies** (`ceil(mercCount / 5)`, cap 5 — `target_straw.cgf` / `target_stand.cgf`) in a row; trainers line up on the camp side facing the dummies. Trainers are excluded from conversation pairing (`CampChatTick` skips any merc whose live activity is the drill), and the drill's per-loop hold was shortened so it can't run on past a break-camp.

**Testing more.** The catalogue is still a test surface for everything not yet promoted:

- `merc_camp_activity_list` — print the catalogue with indices and modes
- `merc_camp_activity_test <index|name>` — spawn whatever the activity needs (seat smart object, anchor, decorative prop) and hand it to a live merc (two for conversation)
- `merc_camp_activity_test_clear` — stop it and remove the props

Assignment is deliberately *not* gated on `_G.MercInCamp`, so this works without making camp. Note the merc holds each pose for ~15 s, so `_clear` can take that long to visibly stop the animation (the props vanish immediately).

---

## Comparing clutter

The clutter candidates were compared in-game as a numbered row (#1–#13):

- **Sacks**: #1 `sack_b`, #2 `sack_empty_a`, #3 `sack_pig_feed`, #4 `sack_charcoal` (the dedicated "charcoal sack" model, from the charcoal-wagon/furnace prefabs)
- **Crates**: #5 `crate_low_b`, #6 `crate_small`, #7 `crate_short_for_silver`, #8 `crate_fabric`, #9 `crate_box_c` (the last two pulled straight out of `references/Prefabs/interiorDecoration/weaponGroups/swords_in_crate.xml`, a vanilla decorative scene)
- **Weapons**: #10 `polearm_pile_a`, a standalone "stack of weapons" model pulled out of `references/Prefabs/interiorDecoration/weaponGroups/polearms_in_barrel.xml`; #11 that same prefab's *whole* authored scene (barrel + weapon pile + hay)
- **Charcoal (loose)**: #12 `charcoal_piece_b`, #13 `charcoal_piece_d`, loose chunk-pile models from the blacksmith/collier kiln prefabs

**Feedback**: #1/#3/#4 (the three sacks) are good; #5/#6 (two of the crates) are usable "open containers"; #9 (`crate_box_c`) is a very large container — rejected; #10 (`polearm_pile_a`) reads as an actual stack of weapons — confirmed good. #2/#7/#8/#11/#12/#13 weren't called out either way.

This is now wired into the live camp, not just a comparison row:
- **Beside every merc tent** (`CampTentClutterVariants`): a random pick from the five confirmed-good props (#1, #3, #4, #5, #6) spawns at `CampTentClutterOffset` relative to the tent (to its side, clear of the bed and the merc's own standing spot). First moved further out (`right`/`forward` from 1.4/-0.6 to 2.1/-0.9), then flipping `forward` between +0.9/-0.9 per feedback ("clutter should be on the inside of a tent circle") didn't move it toward/away from the fire at all — the wrong axis. The tent's own local frame has `CampTentFacingFix`'s extra 90° rotation baked in (see `SpawnMercCamp`'s `angle = tentFaceAngle + math.pi + CampTentFacingFix`), so `right`, not `forward`, is actually aligned with the tent↔fire axis (negative `right` = toward the fire/inside the ring). Swapped per follow-up feedback ("try the other axis") to `right = -0.9` (toward the fire), `forward = 2.1` (the side offset), then scaled both down to a small `right = -0.2`/`forward = 0.2` nudge (~0.2m) per further feedback — just enough to keep it off the tent/bed centerline. Still not checked in-game.
- **One per fire cell** (`CampModels.WeaponStack` = #10, `polearm_pile_a`): swapped in for the first chair in each cell's seat ring, instead of a stool, per feedback.

*(The `merc_camp_clutter_test` comparison-row command and its `CampClutterCandidates` table were removed in the code cleanup once the picks were settled.)*

---

## Ground validation

**The problem.** `CampSnapToGround` raycasts straight down against `ent_terrain + ent_static` and takes the first hit's Z. `ent_static` *is* the building geometry, so a cluster cell over a house snaps its whole fire-cell onto the roof — that's the "camp spawns on buildings" bug. Two non-fixes ruled out first: dropping `ent_static` snaps *through* the roof to the terrain floor inside the house (camp clips into walls), and buildings are brushes/render-nodes rather than entities, so `hitTable[1].entity` is `nil` for both terrain and buildings and can't tell them apart. The only robust signal is **geometry**.

This is being built in two phases. **Phase 1 (done): the detector** — a dense heightmap classifier plus a debug visualiser, so the ground-reading can be verified in-game before anything depends on it. **Phase 2 (planned): the placement** — driving camp tile selection and prop placement off that classifier. Recorded below.

### Phase 1 — the detector

**A dense 0.5 m heightmap, classified by connectivity, not absolute height.** `CampSampleHeightmap` (`mercenaries_camp.lua`) fires one downward ray per cell of a grid centred on the player and records the ground height (or `nil` for a void). `CampClassifyHeightmap` then sorts every cell into one of four classes by flood-filling *from the player's own cell*:

- **valid** — the cell is on the walkable surface reachable from where the player stands, stepping cell-to-cell only where the height difference is ≤ `CampConnectStep` (0.5 m). Because a gentle slope has a tiny per-step delta, the whole hillside stays one connected valid surface — **slopes are fine**, exactly as asked; only a *sharp* step stops the flood.
- **small** — an obstacle clump the flood couldn't cross (a ≥0.5 m step cuts it off), of `CampSmallClumpMax` (5) cells or fewer: a tree trunk, a rock, a bush. Tolerable — props just avoid it.
- **building** — a larger cut-off clump (> 5 cells): a wall or building. A hard barrier.
- **void** — no ground under the column at all.

This is the breadth-first "no sharp edge from where I stand" test from the spec, and it fixes the earlier absolute-to-player bound's weakness (which wrongly rejected far cells on gentle slopes): connectivity at 0.5 m resolution means a slope stays valid however far it runs, while a 0.5 m+ step — trunk, kerb, wall — always registers.

**Trees ("very high, thin objects"), handled deliberately.** Rays start `CampProbeStartHeight` (50 m) up, above any tree, like the camping mod's `+50`. A leaf **canopy** has no collision, so the ray passes through it and hits the ground — camping under a canopy is fine. A **trunk** has a physics proxy, so its cells read as a sharp spike above the surrounding ground → cut off by the flood → an obstacle clump. A thin trunk is a *small* clump (tree); a building's roof is a big flat clump joined by small internal steps → *building*. The one blind spot is a trunk thinner than the 0.5 m sample step threading between cells; tighter sampling closes it.

**Debug: see the classification.** `merc_camp_scan [radius] [spacing]` (`mercenaries_camp_debug.lua`) samples + classifies a grid centred on you and drops a colour-coded marker per cell: a **flag** (`flag_temporary.cgf`) on valid ground, a **barrel** (`barrel_a.cgf`) on a small tree/rock clump, a **big crate** (`crate_box_c.cgf`) on a building clump, and nothing on a void (counted only). Valid flags sit at their sampled ground height so you can read the slope; obstacle markers sit at the player's level so a wall or tree reads as a line at eye height. Defaults to a 25×25 grid at 0.5 m (`ScanGridRadius`/`ScanGridSpacing`); the spec numbers were worked out at `merc_camp_scan 21 0.5` (a ~21 m field). `merc_camp_scan_clear` removes the markers. The scan uses the **same** classifier the live camp now runs (phase 2, below), and reports `(indoors)` when it detects an under-roof spot.

**Confirmed working in-game** (the scan reads terrain, trees, and buildings correctly), which is what phase 2 builds on.

### Phase 2 — the tile algorithm (implemented)

`SpawnMercCamp` now builds **one** classified map (`CampBuildMap`) covering the whole camp footprint and drives placement off it. If the map can't be built for any reason it falls back to the phase-1 per-cluster `CampValidateSpot` probe, so camp creation can never fail.

1. **Tiles.** The camp is a square grid of tiles (`CampClusterSpacing` apart, `CampTileHalf` half-extent). Fixed tiles: the **player-tent** tile at the origin, the **empty** tile in front (`(0, 1)`, reserved), and the **training** tile behind (`(0, -1)`, reserved). **Camping** tiles fill the remaining cells outward — and, per the "6 tents for 12 mercs" change, only **non-guards get tents**, so a camping tile of `CampClusterSize` (6) tents covers ~12 mercs once its ~6 guards are counted. This halved the number of camping tiles versus before (guards used to get decorative tents too).
2. **Player-tent placement is optimised.** The camp origin is nudged over a ±`CampCenterSearch` grid and the spot whose 9×9 footprint (`CampPlayerTentFootHalf`) has the most valid ground wins — "find a position with the most valid tiles around it".
3. **Camping tiles are validated.** Each candidate cell is accepted only if at most `CampTileMaxInvalidFrac` (50 %) of its tile square reads invalid in the map; then the fire is nudged onto valid ground inside the tile (`CampNudgeToValid`). We walk outward to `CampMaxProbeCells` and fall back to raw cells on a shortfall (imperfect/overpopulated camp beats no camp).
4. **Props stay on the tuned ring, nudged not repacked.** Each tent unit (tent + its bed + clutter move together) is nudged onto valid ground if its `CampTentFootHalf` footprint caught a clump; the training yard is nudged the same way. Tents/beds are **never skipped** — the least-bad spot is used — so every non-guard keeps a bed and the shared `CampBeds` pool stays intact. Footprint/tile thresholds: `CampFootprintSlack`, `CampTentFootHalf`, `CampFireFootHalf`, `CampPlayerTentFootHalf`, `CampNudgeStep`/`CampNudgeMax`.

**Under-roof mode (in-building = invalid).** The engine snaps a spawned prop onto whatever is directly above a point — a roof included — *regardless of the z we ask for*, so a prop placed on an interior floor lands on the roof. Mapping the interior floor is therefore pointless; instead, when the player is under a roof the whole building footprint is marked **unbuildable** and the camp forms on the open ground past the walls. `CampDetectRoof` samples the player's own column from 50 m up; if the hit is `CampRoofDetectHeight` (3 m)+ above their feet there's a roof overhead, and `CampSampleHeightmap` then runs a **per-cell** test: any column whose high ray hits a roof (≥ 3 m above the player) is flagged invalid (`roof` → `building` class), while a column whose high ray reaches ~ground level has stepped **out** from under the roof (outside the walls) and stays valid ground. So the building reads as one invalid block and everything past the walls is good to go — "once it reaches out-of-building tiles those are good to go". If the player's own spot is invalid, `CampNearestValidCell` jumps the whole camp origin (player tent included) to the closest open ground and rebuilds the map there, so nothing spawns on the roof. The scan does the same classification and prints `(indoors)`, drawing the building footprint as crates — point it at a doorway to see the wall between invalid-inside and valid-outside.

**Performance.** The map is sampled at `CampSampleStep` (0.5 m) over a radius sized to the tiles, capped at `CampMapMaxRadius` (22 m). Worst case (a full-corner camp) is ~7.9 k one-time rays at camp creation — no entity spawns, so cheaper than a `merc_camp_scan` of the same size; typical small/medium camps are well under that. Tiles beyond the cap fall back to the cheap per-cluster probe.

**Per-merc position validation (`FindValidGround`, `mercenaries_util.lua`).** Any single spot a merc is placed on — teleported to (straggler catch-up in `mercenaries_teleport.lua`, recall), or spawned on (hire, custom companion, renegades, archers) — is now validated with `CampValidateSpot` (a small "one tile per merc" footprint) against the squad's reference level, and if it's blocked (a tree/rock/roof top) it spirals outward in 0.5 m rings to the nearest clear ground before the `SetPos`/spawn. This stops the "merc standing on a tree" cases that a plain ground-snap (first-hit-wins) produced. Inside a live camp the move-in spot is instead checked against the camp map (`CampNearestValidCell`), so it also respects the under-roof invalidation.

**Still to verify in-game:** the whole phase-2 spawn path (map build, tile selection, player-tent optimisation, per-prop nudge, 12/6 tenting, and the training yard's move to *behind* the player tent with flipped dummy/trainee facings) is new and unplaytested — expect a tuning pass, especially on the training-yard facings and the footprint sizes.

---

## Positioning the bed under a tent

`CampBedOffset` is currently `{ right = 0, forward = 0, z = 0, rotationDeg = 180 }`, against `tent_small_forest_a.cgf` (and by extension its four same-footprint siblings, `CampTentVariants`).

**A real bug was found here and got fixed**: `rotationDeg` was validated at 90 in isolation and looked right *there* — but the real camp spawn code (`SpawnMercCamp`) was discarding the rotated angle `CampRelativeOffset` returns and spawning the bed at the tent's raw, un-rotated facing regardless of `rotationDeg`'s value. So every camp so far had shown the bed at an *effective* `rotationDeg` of 0, not 90 — meaning "still not oriented correctly, rotate another 90" was reacting to that 0-rotation bug, not to 90 being insufficient. Both are addressed now: the bug's fixed (the bed actually rotates), and the value's bumped to 180 per the explicit ask. Since the bug means 90 was never really seen live, there's a real chance 180 overshoots what would otherwise have looked right — check in-game and say so if it needs to come back down.

`right`/`forward` are in the *tent's own local space* (not world axes — "forward" is the direction the tent faces), `z` is a world-space vertical offset, and `rotationDeg` is relative to the tent's own facing. Tell me new values and they get hardcoded into `CampBedOffset`.

---

## The player tent

A separate, central tent + bed spawns once per camp, not assigned to any merc — `tent_big_round_a.cgf` (one of the two "large white circular" tents from [Comparing tents](#comparing-tents), picked over the barber's `tent_big_round_b` since it's the one with an actual vanilla single-sleeper precedent) with the bed inside. The bed uses the same low straw model the mercs use (`CampModels.Bed` / `bed_shabby_a.cgf`). It started as the taller `bed_double_fancy_a`, but that left the player sinking on waking — the fancy bed's lying position sat high off the ground, mismatched with its `Bed_1Place_Low` / `GroundBed` smart-object helper — so it was swapped to the ground bed, whose height matches.

**Making it interactable ("E — Sleep").** The first attempt got the mechanism wrong. It reasoned like this: `zdjbcamping_mod` spawns its beds as a custom `DJB_BedEntity` class (which needs a `.ent` file this mod deliberately avoids), and that class *defines* an `OnUsed` sleep handler — so we replicated the `OnUsed` on a plain `BasicEntity`. But that never fired, and tracing `DJB_BedEntity.lua` line-by-line shows why: it defines `OnUsed`, then calls `EntityCommon.MakeUsable(DJB_BedEntity)` **after**, and `MakeUsable` unconditionally overwrites `OnUsed` with a generic broadcast-only handler (unless the override is renamed `Base_OnUsed`, which it isn't). So DJB_BedEntity's own `OnUsed` is **dead code** — the sleep interaction was never coming from there.

Where it *actually* comes from: a separate vanilla **`BedTrigger`** entity (`references/Scripts/Entities/WH/Triggers/BedTrigger.lua`, a subclass of `ActionTrigger`). The camping mod spawns one next to each bed (`DJB_Camping:SpawnBedTrigger`) and links it to the bed (`LinkBedEntities`). The trigger carries a `Click` block — `esActionType="Stance"`, `sAction="lying"`, `UseMessage="@ui_hud_sleep"` — which is what shows the "E — Sleep" prompt and drives the lying/sleep stance. It finds *which* bed to lie on via `ActionTrigger:GetLinkedSmartObject`, which returns the first link whose name is `""` (empty) — so the trigger→bed link **must be created with an empty name**.

So `SpawnPlayerCampTent` (in `mercenaries_camp.lua`) now spawns two things, exactly matching the camping mod: (1) the bed as a smart-object `BasicEntity` carrying the vanilla bed properties copied verbatim from `DJB_BedEntity` (`guidSmartObjectType`, `soclass_SmartObjectHelpers = "Bed_1Place_Low"`, plus the `Bed` and `Script.esBedTypes` sub-tables) — no custom `.ent` class needed, since smart-object registration is entirely property-driven; and (2) a `BedTrigger` (`SpawnCampBedTrigger`) with the `Click` block above, linked to the bed by an empty-named link (plus the mirror `"mTrigger"` back-link the camping mod also makes). Trigger position/scale are `CampPlayerBedTriggerOffset`/`CampPlayerBedTriggerScale` — starting guesses, tunable if the prompt is awkward to catch. Not yet verified in-game, but it's now built on the mechanism the camping mod actually uses rather than a dead `OnUsed`.

**Sleep *and save*.** The camp bed is the player's own, so it behaves like a bed you own in town: the prompt reads "@ui_hud_sleep_and_save" and a save is made when you get up.

Vanilla decides this per bed with `EntityModule.WillSleepingOnThisBedSave(id)` (see `references/Scripts/Entities/WH/Bed/Bed.lua`, which uses it to pick between `@ui_hud_sleep` and `@ui_hud_sleep_and_save`), and that is pure **bed ownership** — the room-renting quest grants it with a Skald **`SetOwner`** node (`Who = player`, `What =` the bed, in `references/Quests/.../roomrenting/roomrentonenight.xml`). There is **no Lua binding that sets ownership**: `XGenAIModule.GetOwner` reads it, nothing writes it, and quest asset ports can't bind a runtime-spawned entity anyway. So a bed we spawn is ownerless and the engine will never save on it.

The save is therefore made from Lua. `Game.SaveGameViaResting()` is the engine's own resting autosave (creates an `Auto` save; `Game.QuickSave()` is the fallback if the binding ever disappears). `CampBedSleepWatch`, called each second from `MonitorLoop`, is a two-state watcher on `player.player:IsLaying()`: on the transition into lying it arms only if the player is within `CampBedSleepRadius` (3.5 m) of the bed recorded by `SpawnCampBedTrigger` (`CampPlayerBed`), and on the transition back out it saves — but only if world time moved at least `CampBedSleepMinSeconds` (600 in-game seconds), so lying down and standing straight back up, or a sleep interrupted after a moment, doesn't save. The save is deferred 2 s so the wake-up animation finishes first. `CampPlayerBed.engineSaves` is queried once at spawn and suppresses our save if the engine ever does start saving on this bed by itself. The house upgrade's bed goes through the same `SpawnCampBedTrigger`, so it gets sleep-and-save too.

**Placement fixed, twice.** First fix: it was clipping into merc tents (fixed `center + 12m` offset regardless of grid size) — given a reserved slot in the merc fire-cell grid instead. Second pass, per feedback: rather than being just another grid slot, the player tent is now the grid's own origin — every fire cell is placed relative to it, and the tile directly in front of it (along the direction the player was facing when camp was made) is always left empty. See [How it works](#how-it-works) above.

**Facing**: the tent's angle is `worldForwardAngle + CampTentFacingFix + 75°`, where `worldForwardAngle` is the direction the player was facing when camp was made (the same "front" the empty grid tile is built around). The extra rotation is a direct ask from feedback - +45°, then +30° more (75° total) per follow-up feedback - on top of the usual `CampTentFacingFix` correction every tent gets. Not yet re-checked in-game against the empty tile.

**Bed offset**: `CampPlayerBedOffset` is `{ right = 0, forward = 1, z = 0, rotationDeg = 180 }`. First tried `right = 1` (moved a meter over) per feedback — that moved it the wrong way, so it's now `forward = 1` instead (a meter along the tent's facing axis rather than sideways). Like `CampBedOffset`, this is a from-scratch guess against a tent (`tent_big_round_a.cgf`) with a completely different footprint than the small tents it was never actually tuned against — expect to need another pass once you've seen it in-game.

---

## Files touched

| Piece | File |
|---|---|
| Camp spawn/despawn/recall logic, fire-cell grid layout, ground validation of cluster cells (`CampValidateSpot` + the probe-and-explore loop in `SpawnMercCamp`), `incamp` state (`_G.MercInCamp`), camp-role assignment (guard/sit/sleep) + `IsCampGuard`/`GetCampFurniture`/`IsCampActor`, smart-object furniture (`SpawnCampFurnitureSO`, `CampBedSO`/`CampChairSO`), daily schedule + conversation pairing (`MonitorCamp`/`CampChatTick`/`EndCampChat`) | `data/Scripts/mods/mercenaries_camp.lua` |
| Console-only debug helpers: activity catalogue test (`merc_camp_activity_*`), sit/sleep pipeline dump (`merc_camp_furniture_debug`), and the ground-validator visualiser (`merc_camp_scan` / `merc_camp_scan_clear`) — split out of the main file in the cleanup | `data/Scripts/mods/mercenaries_camp_debug.lua` |
| Camp activity cases in the main `ContinuousSwitch`: guard-patrol `Move` loop, sleeper/sitter `StanceElement`; role sensing; horse-suppression while `_G.MercInCamp` | `data/AI/camp_actor.xml` |
| Route incamp actors into the follow branch (`$isIdle & ~$isCampActor` idle condition; `data.isCampActor` sensing); inert old sit/sleep `StanceElement` comment blocks | `data/AI/mercenary_scheduler.xml`, `data/AI/archer_scheduler.xml` |
| Shared tier-from-name helper (`GetTierFromName`) | `data/Scripts/mods/mercenaries_util.lua` |
| Script registration, tokens, `SetState` hook, recall keybind, `LowPriorityMonitorLoop`/`OnGameplayStarted` hooks | `data/Scripts/mods/mercenaries.lua` |
| Camp tokens | `data/libs/tables/item/item__mercenaries.xml`, ids `...be65d` (make) / `...be66d` (break) |
| Dialog entries (management hub → camp sub-hub) | `data/quests/mercenaries/kutnohorsko/mercenaries_background_quest/dismissal_dialog.xml` |
| Quest token wiring | `data/quests/mercenaries/kutnohorsko/mercenaries_background_quest.xml` |
| Localization (16 languages) | `localization/*.xml` |
