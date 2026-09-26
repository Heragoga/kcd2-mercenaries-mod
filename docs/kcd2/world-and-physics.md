---
title: World and physics
summary: Levels and region crossings, time and fast-travel detection, raycasts and what counts as the ground, interior area labels, collision classes and NPC-vs-prop collision, the baked navmesh and what can still steer NPCs around runtime geometry.
tags: [world, engine, lua, ai, testing]
kind: reference
status: current
scope: kcd2
verified: release_1_5
---

# World and physics

## TL;DR

- **Trosky (`trosecko`) and Kuttenberg (`kutnohorsko`) are separate levels.** Crossing is a full level load; every
  spawned entity - including hidden "saver" entities - exists only in the level it was spawned in. Lua globals survive
  the load. There is no working level-name API (verified in game).
- **`System.GetTerrainElevation` returns nil** on this build. Ground = a `Physics.RayWorldIntersection` restricted to
  `ent_terrain`; tell objects from ground by the hit's **`surface`** id, not by height (verified in game).
- **NPCs walk through runtime-spawned props** because `ac_disableLivingVsRigidCollisions` ships ON; the flag is
  read per character at physicalisation. No obstacle-side setting can fix it (retail binary + verified in game).
- **The navmesh is baked** (`Levels/<level>/recast.pak`); nothing spawned at runtime ever enters it, and the rebuild
  commands are stubs. Runtime levers are steering/avoidance only (retail binary + tested).
- **`Calendar.GetWorldTimeRatio()` is a constant 15** in normal play and during fast travel; detect travel by how fast
  `Calendar.GetWorldTime()` actually advances, or by position moving while the entity's own speed is 0 (verified in game).
- "Indoors" = the **`interior` area label** on prefab `TriggerArea`s; `System.IsPointIndoors` is dead (no VisAreas in
  either level) (retail binary + level data).

## Levels and regions

| Fact | Source |
| --- | --- |
| Fast travel between regions logs `Loading level trosecko` with `OnQuickLoadingStart` then `OnGameplayStarted`, like a save load | verified in game (regions.md) |
| Intra-region fast travel is a plain teleport: no level load, no `OnGameplayStarted` | verified in game |
| Entities (NPCs, props, `BasicEntity` saver/tag entities) belong to the level they were spawned in; in the other level every lookup returns nil, not an error; travelling back finds them again | verified in game |
| Lua tables/globals persist across a level change; vanilla `SinglePlayer.lua` stashes `g_GameTokenPreviousLevel` across `EndLevel`/`OnStartLevel` for exactly this reason | vanilla + verified |
| `System.GetCurrLevelName`, `Game.GetLevelName`, `System.GetCurrAsyncLevelName` come back empty (none is in the generated API index) | verified in game |
| Both levels share one coordinate space - a saved position without its level is ambiguous | verified in game |
| Level geometry streams: a raycast-based search re-run on load can land metres from its original result because static geometry is not loaded yet | verified in game |
| [`RPG.GetLocations()`](api/RPG.md#getlocations) returns a **different list per level** (45 on Kuttenberg, 33 on Trosky). `Location` objects have no name field, but `tostring` gives `Location[name=location_pritoky]`; one level-unique name identifies the level wherever the player stands | verified in game (patrols.md) |
| `LocationPoint` entities (self-register via `RPG.AddLocationPoint`, carry `guidLocationId`) are a dead end: 2 on Trosky with `guid=nil`, 0 on Kuttenberg | verified in game (patrols.md) |
| A **moved level entity** (e.g. a village smithy the mod relocated) is restored by the engine **where it was moved to** after a load, so "its current position" is no longer its home. Save the true home yourself | verified in game (camp-forge.md) |

Patterns that follow:

- **Carry state across a crossing in a Lua global**, captured at the top of `OnGameplayStarted` before you reset your
  own caches (regions.md).
- **Tell a crossing from an unrelated save load by the world clock**: a crossing moves `Calendar.GetWorldTime()` forward by
  roughly the travel time; an older save moves it backwards, a much newer one overshoots.
- **Store the level (or a level-specific marker) with any saved position**, and treat "anchor moved on reload" as
  streaming noise, not player intent, when re-deriving placements.
- `Calendar`/quest state is global; entity state is per level.

Level data in general (official wiki KM-A-92): entities and brushes live in editor layers; layers in the `game` export
profile are merged into e.g. `objects_mission0.xml` and always present; layers in additive **streaming profiles** exist
only while a Skald `EnableProfile` node has them on. Exported level data cannot be merged between mods - see
[assets-pipeline.md](assets-pipeline.md#shipping-level-data).

## Time, fast travel and time skips

| Signal | Behaviour on this build | Source |
| --- | --- | --- |
| [`Calendar.GetWorldTimeRatio()`](api/Calendar.md#getworldtimeratio) | **15.0 on every sample**, including fast travel and sleep (2,343 samples) | verified in game |
| rate of [`Calendar.GetWorldTime()`](api/Calendar.md#getworldtime) per real second / 15 | ~1 in play; **4.8x** during a crossing; noisy per tick (a mid-crossing sample read 1.1) | verified in game |
| [`System.GetCurrTime()`](api/System.md#getcurrtime) | engine clock; runs ~x29 through a time skip - a 3 s hold expired in ~0.1 s real time | verified in game |
| `os.clock()` | wall clock; use for real-world holds/debounces during warps | verified in game |
| [`Calendar.IsWorldTimePaused()`](api/Calendar.md#isworldtimepaused) | **false** while the map screen is open | verified in game |
| `enum_actorState` (`skipTime=32, fastTravel=33, cutscene=34`) | in the Lua state dump, but no getter returns it (nine candidates tried: `soul:GetState('actorState')`, `actor:GetState()`, ...) | verified in game |
| [`entity:GetSpeed()`](api/Entity.md#getspeed) / [`GetVelocity()`](api/Entity.md#getvelocity) | the entity's **own** locomotion; 0 while its position is set externally (fast travel, carried) | verified in game |
| [`human:GetHorse()`](api/Human.md#gethorse) | whether the player **owns** a horse, not whether he rides it (true on 100% of samples on foot) | verified in game |
| [`System.GetEntity`](api/System.md#getentity) with a WUID | nil - resolve WUIDs with [`XGenAIModule.GetEntityByWUID`](api/XGenAIModule.md#getentitybywuid) | verified in game |
| horse `soul:GetState('stamina')` | frozen during a crossing, but also flat while walking/cantering (drain starts ~gallop) - not a discriminator | verified in game |
| [`actor:TrackViewControlled(0)`](api/Actor.md#trackviewcontrolled) | claimed cutscene detector; retail-unconfirmed in the API index | (unverified) |

**Conflict**: the old combined context doc says the ratio "spikes to 400+ during time skips, `> 100` catches all";
in-game probes on `release_1_5` never saw it leave 15.0. The measured behaviour wins - use the clock *rate*.

Detector that works (travel-detection.md): sample at ~100 ms; **position moved while the mover's own
`GetSpeed()` is 0** (player on foot; the **horse** when mounted - the rider always reads 0 in the saddle), plus the
world-clock rate as confirmation; skip rate tests on samples whose `dt > 0.5 s` (a freeze: load, pause, map).
Known blind window: side effects that run while the player chooses a destination on the map happen **before** any
travel is detectable - gate risky actions on "the player has physically moved recently" instead.

Other time facts:

- A BT `<Wait timeType="GameTime">` expires **instantly** during sleep/wait skips; loops gated on it free-run. There is
  no `RealTime` value (only `GameTime`/`WorldTime`, see [behaviour trees](behavior-trees.md#time)); gate the loop with a
  Lua real-time floor instead (verified in game: interior-detection.md).
- **Slow motion**: `t_GameScale` scales game time only (`t_Scale` also slows UI). Not cheat-gated (flags `0x84` vs cheat
  mask `0x3000002`), unused by vanilla, but the engine **restores it ~10 s after a write** - re-assert every second, and
  reset it on every `OnGameplayStarted` (retail binary + verified in game).
- `Game.SaveGameViaResting()` is the engine's resting autosave; whether sleeping in a bed saves depends on bed
  ownership (`EntityModule.WillSleepingOnThisBedSave`), settable only from Skald (retail binary: camp.md).

## Raycasts and the ground

[`Physics.RayWorldIntersection(vPos, vDir, nMaxHits, iEntTypes [, skipEnt ...])`](api/Physics.md#rayworldintersection)
per-hit fields (retail binary: `sub_39AA4B0`): always `pos`, `normal`, `dist`, `surface`; then `entity` if the collider
has entity foreign data, else `renderNode` for static/foliage. In practice **`renderNode` is also set on terrain hits**,
so only `surface` discriminates. It returns **one hit** however many you ask for (no piercing). The skip-entity argument (5th) must be an entity
**id** (`ent.id`, as vanilla `Scripts/Entities/Physics/PressurizedObject.lua` passes `self.id`); passing the entity
table logs a parameter-type warning per ray **and ignores the skip**, so the ray can hit its own caster (mod:
`mercenaries_util.lua`, spawning-npcs.md).
[`System.RayWorldIntersection`](api/System.md#rayworldintersection) is a thinner bind (`normal`, `dist`, `surface` only).

Entity-type mask (live Lua state dump):

| Constant | Value | Notes |
| --- | --- | --- |
| `ent_static` | 1 | brushes, `PE_STATIC` props |
| `ent_sleeping_rigid` | 2 | resting rigid bodies |
| `ent_rigid` | 4 | carts, barrels, corpses |
| `ent_living` | 8 | actors - leave out of ground checks |
| `ent_independent` | 16 | |
| `ent_terrain` | 256 | heightmap only |
| `ent_all` | 287 | |

- `257` (terrain + static), the mask most snippets use, **cannot see rigid bodies**; `263` adds rigid + sleeping rigid.
- **Ground rule**: cast once with `ent_terrain` (true ground height and material at that column) and once with the full
  mask; if the top hit's `surface` differs from the terrain's, it is an object at any height (terrain `1` vs woodpile
  `138` measured). Height thresholds cannot work - a straw mat is 2 cm, kerbs are taller. Keep a height backstop only
  for same-material objects (0.8 m used). Surface names: [`System.GetSurfaceTypeNameById`](api/System.md#getsurfacetypenamebyid).
- Columns with no terrain (bridges, cut-away interiors): ring the point with probes; if **every** side drops (> 0.25 m at
  1.25 m), it is the top of an object - a hillside drops on at most half the ring.
- **Roof test**: a vertical ray from ~50 m above; a hit 3 m+ above the feet means shelter. Spawns snap to the topmost
  surface over (x, y), roofs included.
- **Safe spawn near the player**: sweep rays in an arc behind the player for the longest clear direction, then ray down
  from ~z+2 to snap; use the player's **yaw only** (`{x=0, y=0, z=rot.z}`) - pitch/roll tilt spawned NPCs into the
  ground (claimed, old context doc; the ground rule above supersedes its `ent_terrain + ent_static` mask).
- `System.GetEntitiesInSphere` catches objects by registration rather than geometry. **Conflict:** it returned the
  level's area entities on one call and **zero** on four later calls at the same and nearby points
  (camp-inspection.md); do not rely on it without a fallback.
- **Vegetation is invisible at runtime**: no ray mask (`ent_static` ... `ent_all`) hits a bush or tree, the terrain
  material under it reads plain soil, and `AI.CanMoveStraightToPoint` does not notice it. Plants are HLOD render
  instances with no physics proxy; the only source is the level files, baked offline (verified in game:
  camp-inspection.md).
- **Living townsfolk's feet are proven spawn points** in a town: the engine already holds them upright, outdoors (check
  the roof), on navmesh, on real ground. A spawn is still snapped to navmesh and can slip far from its slot - re-check
  the distance after spawning (town-watch.md).

Details and the diagnostic probe: ground-guard.md.

## Interiors and area labels

Levels carry `TriggerArea` entities with a semicolon-separated `Label` property (Kuttenberg: 6,055 areas, 2,444 labelled,
112 distinct labels; 384 `interior`; Trosky 179 `interior`). `interior` comes with every placed building **prefab**
(houses, sheds, barns, stables, bathhouses; 241 distinct prefab sources in Kuttenberg) plus hand-placed quest interiors
(level data: `objects_mission0.xml`).
The engine relies on it: `Cpp:InteriorCrouch`/`ExteriorCrouch`/`InteriorDrunk` buffs test it (stealth visibility), as do
horse-call and dog-follow suppression (retail binary: `C_InteriorCrouchBuff::vf32`). The stealth side is tuned by
`VisibilityDecrementDaytimeInterior` / `...Nighttime...` and `InteriorCrouchHysteresis` (vanilla:
`Libs/Tables/rpg/rpg_param.xml`).

| Surface | How | Notes |
| --- | --- | --- |
| BT | `IsInsideAreaWithLabel`, `IsInsideAreaWithLabelBarrier` (`Who="$__player"`, `Label="'interior'"` - a quoted string) | 60 vanilla trees; template `AI/animal/basic/switch/animal_continuouslyCheckTrespass.xml` |
| Skald | `AreaLabelTrigger` (ports `IsActive`, `Souls`, `Label`; `OnEnter/OnLeave/OnAllEnter/OnAllLeave`), `AreaLabelCheck`, `AreaLabel` (adds/removes labels at runtime) | primitives, safe in mod quests |
| Lua | [`XGenAIModule.IsPointInAreaWithLabelWUID(wuid, label)`](api/XGenAIModule.md#ispointinareawithlabelwuid) -> bool | takes a **WUID**, uses that entity's live position; poll only |

Other labels read the same way: ownership (`private`, `personal`, `semipublic`, `household`, `prohibited`, ...), space
(`kitchen`, `cellar`, `attic`, `castle`, `closedCastleArea`, ...), stealth (`stealthArea_crouch`/`_stand`), suppressors
(`suppressHorseCall`, `dogForbidden`, `horseSpeedLimiter`, ...), ~40 `music_*`.

Coverage: **not** castles/churches (they use `castle`/`closedCastleArea`/`music_*_indoor`), not porches/arcades/gate
passages/bridges, and **never anything a mod spawns** - the player is "outdoors" inside a mod-built structure.
[`System.IsPointIndoors`](api/System.md#ispointindoors) is CryEngine's VisArea test and both levels contain zero
VisAreas/Portals: it is always false. Details: interior-detection.md.

## Physics and collision

### Collision classes

[`Entity.SetPhysicParams(PHYSICPARAM_COLLISION_CLASS, t)`](api/Entity.md#setphysicparams) (`PHYSICPARAM_COLLISION_CLASS = 21`)
is live. Two entities skip each other when either one's type bits intersect the other's ignore bits - symmetric, so
setting one side is enough. Keys: `collisionClass` / `collisionClassIgnore` OR bits in; `collisionClassUNSET` /
`collisionClassIgnoreUNSET` clear them (vanilla `GeomEntity.lua`) - additive and reversible.
Global table `g_PhysicsCollisionClass` (retail binary, pinned by `gcc_player_all = 0xC00` and vanilla
`gcc_interactive = 262144`):

| Class | Bit | Class | Bit |
| --- | --- | --- | --- |
| `collision_class_terrain` | `0x1` | `gcc_horse` | `0x10000` |
| `collision_class_wheeled` | `0x2` | `gcc_ai` | `0x20000` |
| `collision_class_living` | `0x4` | `gcc_interactive` | `0x40000` |
| `collision_class_articulated` | `0x8` | `gcc_npc_reported_type` | `0x80000` |
| `collision_class_soft` | `0x10` | `gcc_player_type` | `0x100000` |
| `collision_class_particle` | `0x40` | `gcc_npc_ignored_type` | `0x200000` |
| `gcc_player_capsule` | `0x400` | `gcc_ledge` | `0x400000` |
| `gcc_player_body` | `0x800` | `gcc_animal` | `0x800000` |
| `gcc_vehicle` | `0x1000` | `gcc_horse_bridle` | `0x1000000` |
| `gcc_ignore_z_correction` | `0x2000` | `gcc_player_ghostable_type` | `0x2000000` |
| `gcc_ragdoll` | `0x4000` | `gcc_decoy_projectile` | `0x4000000` |
| `gcc_rigid` | `0x8000` | `gcc_item` | `0x8000000` |

Composites: `gcc_player_all = 0xC00`, `gcc_npc_avoiding_types = 0x280000`, `gcc_all_engine = 0x3FF`,
`gcc_all_game = 0xFFFFFC00`. The game's table stops at bit 27; bits **28+** are free for a mod's own tag (e.g. tag your
NPCs with `0x10000000` and put that bit on one specific entity's ignore mask). Deriving the table from disassembly
naively is off by one (names are stored at the index of the *previous* value).

- Masks **do not survive re-physicalisation** (spawn, save/load, level change): re-apply at spawn and on a sweep.
- `gcc_player_type` is an AI-avoidance marker, not the player's body. Tagging `gcc_horse` on an ignore mask did **not**
  stop mount-vs-player-mount contact (verified in game) - measure what a ridden horse actually carries.
- Collision classes are physics only; none of them affects pathfinding.
- Dead ends: `foreignCollisionDamageMult`, `vehicleCollisionDamageMult`, `collisionDamageThreshold` in `player.lua` /
  `NPC.lua` are Crysis leftovers absent from `WHGame.dll`; actors have no `Client.OnHit`/collision callback;
  `SinglePlayer:CreateHit` only calls into C++. Collision damage cannot be filtered from Lua after the fact - prevent
  the contact instead (collision-ghosting.md). The only cvars nearby,
  `g_debugCollisionDamage` (logging) and the `wh_HitReaction_*` family (`CollisionsEnabled`, `PhysicalHitCoef`,
  `EnvironmentCollisionScale`), are global and govern hit reactions and impulses, not who collides. The class table is
  built in `sub_1690428` with names assigned in `sub_1750264` (retail binary).

### NPCs vs runtime props: `ac_disableLivingVsRigidCollisions`

A runtime-spawned `PE_STATIC` or `PE_RIGID` prop stops the **player** but not an NPC's body. Cause: cvar
`ac_disableLivingVsRigidCollisions` ("Disable collisions between living and rigid entities. Must reload level (or update
collider mode otherwise) to work.") ships **on**; its single consumer is `CAnimatedCharacter`'s ColliderMode resolver
(`sub_83C630`), which never looks at the obstacle. Eleven obstacle-side and mode-side alternatives (`ac_ColliderModeAI`
2/3/4, `SetColliderMode` on walker or wall, `ac_movementControlMethodHor`, `ac_enableExtraSolidCollider`, collision
classes, 5-tonne rigid bodies) all failed; setting the cvar to `0` stopped the walker 2/2 (retail binary + verified in
game: walls-and-sieges.md).

- The flag is latched per character when it physicalises or when its collider mode **changes**. Pulse
  [`SetColliderMode`](api/Entity.md#setcollidermode) 3 -> 0 on an existing character to re-apply (re-requesting the
  current mode can be dropped).
- Safe scoping: arm the cvar while the player is near your geometry (everything spawning is born solid), hand
  characters far from it back by pulse, restore the shipping value elsewhere.
- Making a body solid tells the pathfinder nothing: an NPC now presses against the wall instead of passing it. Pair it
  with your own routing and a stuck-release.
- In the palisade test the mesh's `$physics_proxy` node had 0 vertices, as do vanilla level palisades - proxies were not
  the differentiator.

### Rigid vs static, and other physics facts

- `BasicEntity` spawns as a pushable rigid body unless `Physics` says otherwise (see
  [assets-pipeline.md](assets-pipeline.md#spawning-static-geometry-without-a-custom-entity-class)).
  `EntityCommon.PhysicalizeRigid` picks `PE_RIGID` only for `Properties.Physics.bRigidBody == true`; `bResting` is
  tested `== 0`; `bRigidBodyActive` is an entity field, not a property (retail binary). A resting rigid body reads
  `GetMass()` > 0 and holds position; a static one reads 0.
- **A physicalized entity ignores `SetAngles`**: the physics proxy owns the transform, and the call silently does
  nothing. To tilt a prop, spawn it with `bPhysicalize = false`, set its angles, then call
  `BasicEntity:PhysicalizeThis()`. The x/y angle components act in the **prop's own frame**, not world axes (measured
  by a two-yaw probe) (verified in game: camp-inspection.md).
- **Never destroy an entity that has something attached**: force-dismounting riders and `RemoveEntity`-ing their horses
  in the same frame crashed natively with no callstack. Vanilla/mod code always defers horse removal several polls after
  dismount. To teleport a mounted NPC, **move the horse**; the rider comes along (verified in game:
  travel-detection.md).

## Navmesh

- Baked offline in Sandbox inside hand-placed `NavigationArea`s, exported by a separate RC job to
  `Levels/<level>/recast.pak`: one `rdnavmesh_<source>_1.nav` Detour tile set per navigation source (`DNAV` magic) plus
  `groupcombinations_*.xml`. "The world changed" is handled by **pre-baked alternative layers** switched by quest flags
  at fixed spots (e.g. a whole variant for one closed crypt wall) (retail files; Warhorse dev on the modding Discord; official wiki KM-A-92).
- `wh_ai_RebuildNavmesh` / `wh_ai_RebuildNavmeshFromCache` are registered but point at the shared `ret 0` stub.
  The generator code is present, gated by `wh_ai_AutomaticMNMRebuild` (ships 0); forcing it (and
  `wh_ai_CryNavigationSystemEnabled`) to 1 and spawning obstacles produced **no generation at all** in 150 s
  (retail binary + tested).
- The only runtime navmesh write is `C_AIObstacles::AddObstacle({x,y,z,radius,height,ignoreRadius,flag})`: it flags
  Detour polygons and the path filter multiplies their cost by `wh_ai_FindPathObstaclesMultiplier` (3.0) when
  `wh_ai_FindPathUseObstacles` (1). **Cost, not a block.** Reachable from data only through in-game dialogues
  (`wh_dlg_CreateObstacle`, default 1 - why passers-by walk round a conversation), and transient. No Lua, BT or Skald
  entry point. **Conflict**: an earlier section of walls-and-sieges.md says none of its callers is data-reachable;
  the later full audit found the dialogue path and supersedes it.
- A navmesh-regenerating FlowGraph node (`AI:RegenerateMNM`) could live in a `Libs/FlowgraphModules/*.xml` module, but
  nothing a mod controls can start a module (untested idea: splice into an always-running vanilla module such as
  `IsDay.xml`) (retail binary).
- Off-mesh links (`OffMeshNavigationManager`) add connections, never blocks.
- BT has read-only `IsPointOnNavMesh` / `GetLastNavmeshPosition`.
- `stuckThreshold(N)` on the `additionalMoveParams` BT variable (vanilla `AI/profession/farmer/so_field.xml`) drives the
  path follower's give-up timer; comma-compose with `destChangedThreshold`, `continueWhenHalting`. Lowering it shortens
  how long any NPC shoves an obstacle (vanilla files). The same fields can be set from an `<Expression>`
  (`$additionalMoveParams.destChangedThreshold = '1s'`). Engine side: stuck detection is `CNavPath::m_stuckTime`
  against `stuckDetectionThreshold`; related live cvars `wh_ai_StuckDetectionAllowAnyMovement` (1),
  `wh_ai_MovementTeleportWhenStuck` (2), `WH_Move_OffMeshStuckDetectionMultiplier` (2) (retail binary:
  walls-and-sieges.md).
- Surface types can mark geometry unwalkable at bake time (`wood_unwalk`) - only relevant if you ship level data.

### The `AI` Lua table

`CScriptBind_AI` (constructed by `CAISystem::vf1`) fills the `AI` table: **265** functions in the live runtime dump,
which is what [api/AI.md](api/AI.md) marks retail-confirmed; 261 of them are found in the disassembly `binds` table
(4 more are in the dump only); the script_bind docs list 305, of which 51 are absent in retail. An older "281" count
is not reproducible. Vanilla scripts call about twenty. Relevant ones (verified in game):

| Bind | Reality |
| --- | --- |
| [`AI.CanMoveStraightToPoint(id, pt)`](api/AI.md#canmovestraighttopoint) | flipped to false exactly where a runtime wall stood - **but** also answered true for a point 40 m underground. Useful hint, not a walkability oracle (conflicting measurements, both in walls-and-sieges.md) |
| [`AI.SetPFBlockerRadius(id, type, r)`](api/AI.md#setpfblockerradius) | per-agent radius against the fixed `PFB_*` enum; acts on an AI object, which a prop does not have |
| [`AI.CreateTempGenericShapeBox`](api/AI.md#createtempgenericshapebox) | creates a query volume, not a pathfinding primitive |
| [`AI.IntersectsForbidden`](api/AI.md#intersectsforbidden) | gutted - tests nothing |
| [`AI.SetCollisionAvoidanceRadiusIncrement(id, r)`](api/AI.md#setcollisionavoidanceradiusincrement), [`AI.SetAdjustPath`](api/AI.md#setadjustpath), [`AI.SetForcedNavigation`](api/AI.md#setforcednavigation) | per-agent steering levers that do work |
| [`AI.RegisterDamageRegion(id, r)`](api/AI.md#registerdamageregion) | documented as a region pathfinding avoids; untested here (unverified) |

## Local avoidance (steering)

- `Properties.AI.bUsedAsDynamicObstacle` (only nav property in the shipped scripts, on `RigidBodyEx`) adds an entity to
  nearby agents' avoidance sets - but the candidate query uses flags `0x50006` (`ent_rigid | ent_sleeping_rigid`, **no
  `ent_static`**), so it does **nothing on a `PE_STATIC` entity**. Make the obstacle a (resting) rigid body. **Conflict**:
  an earlier section of walls-and-sieges.md says the flag defaults on and walls were already in the set; the later
  disassembly supersedes it (retail binary: `sub_2F52A5C`).
- The per-agent avoidance pass (`sub_300CB98`: entities within 15 m of each NPC, every tick) also gates on height: the
  obstacle AABB's max.z / min.z against the found floor, with 0.5 m / 2.0 m thresholds. A tall wall sunk metres into the
  ground still passes (retail binary: walls-and-sieges.md).
- Obstacles are per entity (all physics parts merged into one footprint), and all go into **one global ring of 32 slots**.
  Register one merged invisible collider per straight run, not one per mesh piece.
- Live values that make avoidance "barely work" (read in game):

| Cvar | Ships | Effect |
| --- | --- | --- |
| `ai_CollisionAvoidanceTargetCutoffRange` | 3.0 | stops avoiding within 3 m of its target |
| `ai_CollisionAvoidancePathEndCutoffRange` | 1.3 | same for the destination |
| `ai_CollisionAvoidanceRange` / `...ObstacleTimeHorizon` | 5.0 / 1.5 | short look-ahead |
| `ai_MovementSystemPathReplanningEnabled` | 0 | existing paths never replan |
| `ai_ExtraAvoidanceRadius` | 0 | no margin |
| `wh_ai_ObstaclesAddToCollisionAvoidance` | 1 | already on; writing it can only lower it, so leave it alone |
| `ai_AdjustPathsAroundDynamicObstacles` / `ai_CollisionAvoidanceEnableRadiusIncrement` | 1 / 1 | already on |
| `ai_CollisionAvoidanceClampVelocitiesWithNavigationMesh` | 2 | agents off the navmesh get no avoidance |
| `wh_ai_DisableORCAInBattle` | 1 | avoidance off in the scripted `battle` game context; **event-latched** (re-read only on a context transition) |

  These are global - arm them only near your geometry and restore elsewhere. `battle` is a Skald-set game context
  (`SetGameContext`/`GameContextTrigger`), not "any fight".
- **Combat locomotion** (`CombatMoveDecorator -> CombatFollowerDecorator -> CombatAction`) never uses the path follower;
  its own obstacle terms (`WH_AI_CombatMove_ObstacleWeight`, ...) are baked tunables, not cvars. Fighting NPCs run at
  walls in vanilla too; the only mod lever is collision (retail binary + verified in game). Combat movement detail:
  combat-movement.md.
- A `Move` node **ends on arrival** and a surrounding `Loop` restarts it from a standstill (halt at every waypoint); aim
  ahead along the route instead of tightening `stopWithinDistance` (an unreachable radius fails the `Move`, and a
  `Parallel failureMode="Any"` takes the whole tree down).
- Local rounding of a box obstacle: try the **far** corner first, **latch** the side per obstacle, walk straight out if
  already inside, and give up after ~9 s without progress - "round it, else clip it, never circle it"
  (walls-and-sieges.md).

## Gotchas

- Everything the mod built "vanished" after fast travel -> the player crossed into the other level; entities are per level.
- Saved state reads nil after a region crossing -> saver entities stayed in the other level; carry state in Lua globals.
- `GetCurrLevelName` returns "" -> no level-name API works on this build; identify the level from `RPG.GetLocations()` names.
- A reloaded structure moved a few metres -> geometry was still streaming when the ground search re-ran.
- A marker/structure appears in the wrong place on the other map -> both levels share one coordinate space.
- Ground check passes everything -> `System.GetTerrainElevation` returns nil; use an `ent_terrain` ray.
- Props land on woodpiles/tents/roofs -> first-hit-wins raycast; compare `surface` with the terrain ray's.
- Ray can't see carts, barrels, corpses -> mask 257 excludes rigid bodies; use 263.
- Multi-hit ray returns one hit -> it does not pierce; cast separately masked rays.
- `renderNode`/`entity` fields misclassify terrain -> `renderNode` is set on terrain too; only `surface` discriminates.
- Player reads "outdoors" inside a castle or your own tent -> `interior` covers prefab buildings only.
- `System.IsPointIndoors` always false -> no VisAreas in KCD2 levels.
- Fast-travel detector never fires -> `GetWorldTimeRatio` is always 15; the `realTimeDelta` guard never passes at 1 Hz;
  `GetHorse()` is ownership; measure the clock rate and the mover's own speed.
- Riding triggers the "carried" detector -> the rider's speed is 0 in the saddle; test the horse's own `GetSpeed()`.
- Mounted detection always says "on foot" -> `System.GetEntity(wuid)` returns nil; use `XGenAIModule.GetEntityByWUID`.
- A 3 s cooldown expires instantly during travel -> `System.GetCurrTime` is warped; use `os.clock()` for real-time holds.
- Something spawned while the player was on the map screen -> no detector can see a trip before it starts; gate on player movement.
- BT watcher loop runs wild after sleeping -> `Wait timeType="GameTime"` expires instantly during time skips.
- Slow motion wears off after ~10 s -> the engine restores `t_GameScale`; re-assert it every second.
- NPCs walk through your walls while the player cannot -> `ac_disableLivingVsRigidCollisions` is on; pulse collider mode with it off.
- NPCs press against your wall and stay -> the navmesh never contains runtime geometry; route them yourself.
- `wh_ai_RebuildNavmesh` does nothing -> it is a stub; the navmesh is baked.
- `bUsedAsDynamicObstacle` has no effect -> the entity is `PE_STATIC`; the obstacle query only sees rigid bodies.
- Only some of a long wall is avoided -> the global obstacle pool has 32 slots; merge runs into one obstacle each.
- Collision mask stops working after a save/load -> masks don't survive re-physicalisation; re-apply on a sweep.
- Tagging `gcc_horse` didn't stop mount collisions -> measure what class the ridden horse carries.
- Native crash with no callstack while moving a mounted company -> a horse was removed in the same frame its rider was
  dismounted; move the horse instead, defer any removal.
- Teleported rider is back where he was a moment later -> another system re-mounted him on the horse left behind; move the horse.
- `wh_ai_DisableORCAInBattle` change has no effect -> it is latched on game-context transitions only.
- Ray ignores your skip entity and hits the caster, with a warning per ray -> you passed the entity table; pass `ent.id`.
- Placement probe never sees the bush growing through your prop -> vegetation has no physics proxy; bake it offline.
- `GetEntitiesInSphere` finds nothing where it found something before -> it is unreliable on repeat calls; keep a fallback.
- A prop's tilt never applies -> it was physicalized first; set angles before `PhysicalizeThis()`.
- A borrowed level entity's "home" is wrong after a load -> the engine restored it where you moved it; save the home.

## See also

- War stories: regions.md, travel-detection.md, ground-guard.md, interior-detection.md,
  collision-ghosting.md, walls-and-sieges.md, gates.md, camp.md, formations.md,
  disassembly.md (how the binary facts were read).
- [assets-pipeline.md](assets-pipeline.md) (spawning props, proxies, level data), [ui-scaleform.md](ui-scaleform.md)
  (map markers and levels), [console-variables.md](console-variables.md) (every cvar named here), [api/](api/README.md).
