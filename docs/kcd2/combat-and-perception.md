---
title: Combat, crime and perception
summary: How NPC combat is layered, how to start and end a fight from a behaviour tree, what drives positioning, target choice, morale, the crime system, perception, formations and NPC-vs-NPC collision.
tags: [ai, bt, combat]
kind: reference
status: current
scope: kcd2
verified: release_1_5
---

# Combat, crime and perception

What a mod can and cannot control about how KCD2 NPCs fight. Tree syntax is in
[behaviour trees](behavior-trees.md); souls, factions and brains are in
[AI brains and NPCs](ai-brains-and-npcs.md); why fighters vanish in scripted battles is in
[NPC rendering and LOD](npc-rendering-and-lod.md).

> **TL;DR**
> - The tree only decides *that* an NPC fights and *whom*. Swings, blocks, footwork and weapon draw are C++ "automation" under a fixed decorator stack; copy vanilla's `Scripts/AI/crime/friendlyFight.xml`.
> - `CombatAction` is continuous: no re-issue loop. End a fight with a watchdog sibling in `Parallel successMode="Any"` that `Fail`s.
> - Faction relations are one-directional, and only `-1` means hostile. `Labels="publicEnemy"` on the faction marks outlaws (loot vs rob, crime AI).
> - Vanilla NPCs break when morale falls below `combat_moraleForCombat` = 0.2, and morale is driven by headcount.
> - Guards react to the `assault` information that vanilla's `interrupt_attack` behaviour emits, not to the fight itself.
> - ~20 footwork cvars and RPG constants are writable and read, and changing them made no visible difference to how combat feels (verified in game).

Vanilla paths are relative to `references/kcd2-mod-docs-main/`.

## The five layers

| Layer | Owner | Decides | Moddable by |
| --- | --- | --- | --- |
| Behaviour tree | `CombatMoveDecorator`, `CombatFollowerDecorator`, `CombatAction` | that the NPC fights, and whom | XML |
| Combat automation | `wh::combatmodule::C_CombatAutomation*` (Guard/Attack/Defense/ZoneChange/Weapons) | when to swing, guard, change zone; caps speed | `wh_cs_*` cvars, `rpg_param` |
| Combat movement | `wh::xgenaimodule::C_CombatMove` | the "sweet spot" on an arc around the target, circling, repulsion | `WH_AI_CombatMove_*` cvars |
| Follower / path | target/formation follower, MNM pathfinding | walking there | BT, `ai_*` cvars |
| Locomotion | Mannequin `CombatMovement` fragments | animation for the velocity | data tables |

(retail binary: combat-movement)

## The combat stack

Vanilla's own NPC-vs-NPC melee, node for node (vanilla: `Scripts/AI/crime/friendlyFight.xml`;
verified in game: ai-modules):

```xml
<CombatMoveDecorator>
  <MeleeOffenseAutomationDecorator active="true">
    <MeleeDefenseAutomationDecorator active="true">
      <MeleeGuardAutomationDecorator GuardMode="automate" active="true">
        <WeaponAutomationDecorator WeaponChange="melee" active="true">
          <CombatFollowerDecorator ProbablisticDrivenSweetSpot="true" RPGSweetSpotArcDriver="true" active="true">
            <CombatAction TargetNPC="$attackData.target" RelationOverride="Hostile" />
          </CombatFollowerDecorator>
        </WeaponAutomationDecorator>
      </MeleeGuardAutomationDecorator>
    </MeleeDefenseAutomationDecorator>
  </MeleeOffenseAutomationDecorator>
</CombatMoveDecorator>
```

| Node | Live uses | Attribute values (vanilla) | Notes |
| --- | ---: | --- | --- |
| `CombatMoveDecorator` | 12 | none | Puts the NPC into combat locomotion. Without it a moving fighter steps and pauses. Do **not** wrap the stack in `MoveParamsDecorator` |
| `MeleeOffenseAutomationDecorator` | 76 | `active` | Engine swings |
| `MeleeDefenseAutomationDecorator` | 29 | `active` | Engine blocks/parries |
| `MeleeGuardAutomationDecorator` | 79 | `GuardMode` = `automate` (36), `forceEnable` (26), `freeBlock` (20), `forceDisable` (6) | Enum `combatAutomationGuardMode` 0..3 (vanilla: `lua_dump_state`). `forceDisable` is live in `Scripts/AI/battles/battlegroupcontroller.xml` and `battleGateController.xml` (also `battleLadderController.xml`, `hladAZmar.xml`), so combat-movement's "no forceDisable in shipped data" is wrong |
| `WeaponAutomationDecorator` | 68 | `WeaponChange` = `missile` (30), `none` (26), `melee` (15), `unarmed` (2); enum also has `oversized` | `none` relies on a passive draw that a freshly spawned, instantly hostile NPC loses: fists for ~5 s. Force `melee`/`missile` |
| `CombatFollowerDecorator` | 34 | `ProbablisticDrivenSweetSpot="true" RPGSweetSpotArcDriver="true"` always | Closes distance. Omit it and an archer stands and fires |
| `CombatAction` | 70 | `TargetNPC`, `RelationOverride` = `Hostile`/`None` | One continuous action for the whole fight |

- **Archers:** `MeleeOffenseAutomationDecorator > WeaponAutomationDecorator WeaponChange="missile" > CombatAction`,
  no follower (vanilla: `Scripts/AI/battles/battlegroupcontroller.xml` trees `standFire`/`crouchFire`;
  archers).
- **Hold a line while fighting:** a `Parallel` of the full stack plus
  `FormationFollower FormationMode="KeepShape" AllowRelocation="true"` (vanilla:
  `battlegroupcontroller.xml`, [formations](formations.md#the-battle-system-layer)).
- **Ending a fight:** put the stack in `Parallel successMode="Any" failureMode="Any"` next to a
  watchdog `Loop` that waits, re-reads target/leash/ammo state and `Fail`s. Wrapping
  `CombatAction` itself in a `Loop` makes fighters approach in visible steps and archers flicker
  (verified in game: ai-modules).
- **Cleanup:** in `FuseBox/OnFail`, sheathe with
  [`Human.DrawWeapon`](api/Human.md#drawweapon)`(false)`; otherwise NPCs stand with weapons out after
  the fight. Do not sheathe NPCs that are about to be re-fired into another fight, or every re-fire
  costs a sheathe and a redraw. The public guide also calls `soul:SetTarget(nil)`, but `SetTarget`
  is not a Soul bind in the retail binary or the runtime dump, so inside its `pcall` it does nothing
  ([API index](api/Soul.md)).
- **After a kill** the engine re-acquires nearby enemies by itself ("viking behaviour"), so a
  tree pointed at one target keeps fighting (community guide: [combat](../behaviour-trees/combat.md)).
- An **empty weapon set** kills the fight at the draw:
  `[DrawAction]: Can't execute explicit DrawAction for selected weapon set which contains no weapons!`.
  The NPC then stands in the open being hit (verified in game: npc-lod).

## Starting a fight

Combat cannot start from a plain Switching tree. It runs as an interrupt behaviour
([behaviour trees](behavior-trees.md#interrupts-and-schedulers)). The attack boilerplate, as
copied between mods (community guide: [basic structure](../behaviour-trees/basic-structure.md#functions-calling-another-behaviour-tree-interrupts)):

```xml
<SuppressFailure>
  <Function_crime_getMrkev mrkev="$mrkev" nodeLabel="1" />
  <CreateInformationWrapper Label="'assault'" PerceivedWuid="$this.id" PositionType="positionWuid"
      PositionVec3="" PositionWuid="$target" Information="$crimeInformation" />
  <LockDynamicInformationValues Information="$crimeInformation">
    <SetDynamicInformationValue Information="$crimeInformation" Tag="'stimulusKind'"
        Variable="$enum:crime_stimulusKind.combat" Type="" Value="" />
  </LockDynamicInformationValues>
  <Function_crime_limits_reserveReactionLink ffCrimeIcon="false" information="$crimeInformation"
      priority="160" reactionKind="$enum:crime_reactionKind.attack" nodeLabel="2" />
</SuppressFailure>
<Expression expressions="$attackData.target = $target &#10;$attackData.information = $crimeInformation &#10;$attackData.stimulusKind = $enum:crime_stimulusKind.combat &#10;$attackData.previousReaction = $enum:crime_reactionKind.unknown &#10;$attackData.initiatedBy = $enum:switch_interruptInitiator.switch &#10;$attackData.defenceMode = false &#10;$attackData.relationOverride = true &#10;$attackData.source = $enum:crime_source.direct &#10;$attackData.freshlyAttributedCrime = false &#10;$attackData.criminalFreshness = $enum:crime_criminalFreshness.unknown &#10;$attackData.escalatedFromFailedSurrender = false" />
<AddInterrupt_attack attackData="$attackData" Target="$this.id" Host="$mrkev" Behavior="'my_attack'"
    Priority="160" IgnorePriorityOnPreviousInterrupt="true" urgency="Fast" Aliveness="Alive"
    Privileged="false" FastForward="false" />
```

`$attackData` is `switch:interruptData:attack`; `$crimeInformation` is `information`.
Vanilla starts fights through `Function_callInterrupt_attack` (42 live uses), which fires the
vanilla `interrupt_attack` behaviour (vanilla: `Scripts/AI/npc/basic/switch/callInterrupt_attack.xml`).

- **Information labels:** use vanilla labels (`assault`, `murder`...) from
  `Libs/Tables/rpg/crime.xml`. A custom label reportedly breaks the tree silently (old context doc,
  `(unverified)`).
- **Self-defence:** `ProcessMessage inbox="'hitReaction'" variable="$hitReaction"` delivers
  `$hitReaction.attacker` (vanilla: 60 uses). Filter out bleeding and the player. The engine also
  reports physical bumps as hits (see [bumps](#npc-vs-npc-collision-and-bumping)).
- **Guards and bystanders** react to the `assault` information that vanilla's `interrupt_attack`
  tree emits with `Function_crime_emitInformation` (vanilla: `Scripts/AI/npc/basic/switch/interrupt_attack.xml`).
  A custom behaviour fired straight through `AddInterrupt_attack` never emits it, even if you
  build the same wrapper. Run `Function_crime_emitInformation emitCrimeInformation="true"
  reactionKind="$enum:crime_reactionKind.attack"` as a parallel arm for the length of the fight
  (verified in game for the missing broadcast; the fix is untested: public-enemy).
- **Leashing:** vanilla leashes to a fixed point (`$myPosRubber`). Companion trees measure distance
  to `$__player` in a parallel loop and `Fail` past a threshold. When a floor and a clamp both
  apply to a leash, clamp first and floor second (combat-target-selection).
- **Surrender loop:** vanilla attack trees spend much of their logic on crime, trespass and
  surrender checks (`DetermineTrespassReaction`, `IsPublicEnemy`, `attackState`). A follower that
  reuses them turns on the player after crimes. A custom tree drops that logic.
  `enum:crime_interruptAttackState`: `attacking`, `fightIsDone`, `fightIsPaused`,
  `playerIsSurrendering`, `playerSurrendered`, `playerInUnconscious` (old context doc).

## Positioning: sweet spot and "polite" melee

Each attacker walks to its own **sweet spot** on an arc (`MinArcRange`..`MaxArcRange`, 35..50
degrees) beside the target. It does not queue. `ForeignTargetRepulsion` spreads attackers, and past
`TacticalSurround` (5) attackers the ring grows. Melee looks polite because of four data mechanisms
(retail binary: combat-movement):

1. `CombatAutoAttackDelayIncreasePerAttacker` / `CombatAutoMoveActivityDecreasePerAttacker` (RPG
   constants) slow every attacker as more pile on one target.
2. Movement activity below `CirclingLowestMovementActivity` (0.25) means no lateral movement at
   all. A "wait" roll holds the NPC still for 1.2 to 5.0 s.
3. Guard caps speed at `wh_cs_AutomationAction_GuardMaxSpeed` = 2.9 m/s (300 ms to engage,
   1,000 ms to release).
4. `ForeignTargetRepulsion` = 0.6 and `DestinationRepulsionThreshold` = 2.0 keep extra attackers off.

| Cvar | Stock | Effect |
| --- | --- | --- |
| `WH_AI_CombatMove_CirclingWaitingDurationMin` / `Max` | 1.2 / 5.0 | stand-still length (s) |
| `WH_AI_CombatMove_TacticalSurround` | 5 | attackers before the ring grows |
| `WH_AI_CombatMove_ApproachOffset` | 6.0 | approach becomes engage (m) |
| `wh_cs_AutomationAction_AttackImmediateDistance` | 0.8 | attack immediately inside (m) |
| `wh_cs_AutomationAction_MaxDistanceForTarget` | 60.0 | target dropped beyond (m) |
| `wh_cs_AutomationAction_HuntAttackDist` | 10.0 | running attack trigger (m) |
| `wh_cs_EnableCombatGroups` | 0 | shipped off, unexplored |

Full table and caveats (a dozen `SweetSpotArea_*` defaults read 0 in the image; a
`*Factor*`/`ObstacleWeight` family is probably dead) in
combat-movement. All are settable with
[`System.SetCVar`](api/System.md#setcvar) despite `VF_CHEAT`: the gate in `ICVar::Set` does not fire on this
build, so no `[CVARS]: [IGNORED CHANGE]` lines appear (retail binary + verified in game). The
`WH_AI_*` family *is* registered in `WHGame.dll` (`sub_14DF3B8`, alongside the lowercase `wh_ai_*`
cvars) -- the disasm corpus's own `cvars` table just misses every uppercase-starting name;
[data/cvars.tsv](data/README.md) now recovers these separately (`source` = `harvested (...)`).

**The negative result.** All the above, plus the crowd-throttle constants via
`rpg_param__<modid>.xml`, was applied at the most aggressive values and made **no perceptible
difference** (verified in game). Attack **cadence** (`CombatAutoMaxAttackDelay` etc. at Constants
offsets `0xC8C`..`0xC94`) is recomputed by a runtime blend (`0x50D658`) that likely overwrites
table values. That is inferred from the write pattern and not traced (retail binary). Not
reachable without native code: army tactics, the five-zone duel model, agent shoving.

**Combat locomotion ignores pathfinding and avoidance.** `CombatMoveDecorator` →
`CombatFollowerDecorator` → `CombatAction` never enters MovementSystem or ORCA avoidance. Vanilla
fighters also walk straight at walls and are stopped only by collision. `wh_ai_DisableORCAInBattle`
(1) is latched on game-context transitions, so toggling it mid-session does nothing (retail binary:
walls-and-sieges). For walls and navmesh see
[world and physics](world-and-physics.md).

## Target selection

| Need | Use | Notes |
| --- | --- | --- |
| Who is X targeting? | BT `GetTarget ReferenceNPC="$x" TargetVarOut="$t"` (16 live) | There is **no** `soul:GetTarget()` Lua bind. In a `pcall` it fails silently and reads as "nobody targets anyone" (verified in game: combat-target-selection) |
| Is X fighting? | [`soul:IsInCombatDanger()`](api/Soul.md#isincombatdanger) or context `crime_interruptAttack` | vanilla-proven, but `IsInCombatDanger` alone is unreliable: it read **false** for the whole side through an eight-man massacre of unarmed townsfolk (aggressors facing no threat), and the mod's patrol code treats it as untrustworthy on NPCs. Combine it with `human:IsWeaponDrawn()` and the `crime_interruptAttack`/`combat_flee`/`combat_surrender` contexts (mod: `mercenaries_townwatch.lua`, `mercenaries_patrols_live.lua`; other mod code relies on it for hostile NPCs, so the NPC case is disputed) |
| Everyone in this fight | `GetSkirmishParticipants ReferenceNPC Active Passive Targets HumanOnly ParticipantsOutVar` | "skirmish" = the engine's multi-party fight |
| Hostile to X? | [`soul:GetRelationship(otherWuid[, "Original"/"Current"/"Perceived"])`](api/Soul.md#getrelationship) | -1..1. Treat only `-1` as hostile; `0` and `0.5` are authored neutral values |
| Outlaw? | [`RPG.IsPublicEnemy(wuid)`](api/RPG.md#ispublicenemy) / BT `IsPublicEnemy Soul=` | Reads the faction's `Labels="publicEnemy"` |
| Guard or civilian? | contexts `crime_isAuthority`, `crime_isAuthorityOnDuty`, `crime_isSecurity`, `crime_isCivilian`; else [`soul:GetFactionID()`](api/Soul.md#getfactionid) | `GetFactionID` returns the faction **name** (`<region>_settlements_<place>_<estate>_...`). `crime_isCivilian` fires on almost nobody (verified in game: crime-watch) |

- `GetTarget` on `$__player` returns whatever the player is **looking at**, hostile or not. Require
  a drawn weapon too.
- A wanted player sits at `-1` with the town watch too, so relationship alone cannot tell a robber
  from a guard doing his job. Add a faction/label test.
- Build enemy caches **without** the weapon-drawn check, so a hostile is engaged the moment he
  draws, not after the animation.
- Compare entity identity across ticks by **name**. `tostring(ent.id)` is a handle and does not
  stringify stably (verified in game: foe-ai).
- Real-time windows (e.g. "held the same target for 2 s") need `os.clock()`. Sources disagree
  about `System.GetCurrTime`: combat-target-selection
  measured it running ~29x fast through sleep, squad-orders
  treats it as real seconds, and performance found it frame-cached. See
  [Lua scripting](lua-scripting.md).
- Spreading hostiles over a wide area leaves some with nobody in their local scan radius; give
  every spawned attacker an explicit target (town-watch).

## Morale: why enemies run

Every vanilla NPC's `interrupt_attack` loops `Function_crime_surrenderDecision`, which breaks on
`($moraleLow | $hpLow) & ($isGuarding | $isIdling)`. `$hpLow` is never assigned, so **morale is the
only trigger** (vanilla: `Scripts/AI/crime/surrenderDecision.xml`,
enemy-morale).

- `moraleLow` comes from a `MoraleGate` against `combat_moraleForCombat` = 0.2 (vanilla:
  `Libs/Tables/ai/ScriptParams.xml`). Below it, the NPC surrenders if isolated within 3 m of the
  player, otherwise it flees with `combat_flee` for `crime_flee_stayFledDuration` (420,000, i.e.
  420 s game time). The same value decides flee-vs-attack before combat (`DecideSkirmishReactionCrime`).
- **Inputs:** a continuous side-ratio term weighted by `SkirmishPredominanceWeight` (RPG constant,
  not authored in vanilla `rpg_param.xml`), plus fading deltas from `Libs/Tables/rpg/morale_change.xml`:
  `combat_outnumbered_small/medium/large_negative` -0.05/-0.1/-0.2, `combat_ally_dies` -0.2,
  `combat_ally_flees` -0.1. The last one is why bands rout together.
- **Levers:** `SkirmishPredominanceWeight=0` via `rpg_param__<modid>.xml` (a pure insert; verified
  in game that the table patch merges); override `morale_change` rows (unverified merge case);
  lower `combat_moraleForCombat` (unverified merge); context `combat_neverSurrenderOrFlee` (Skald
  only, no Lua setter).
- **Reading it:** morale has no Lua getter (`GetMorale` exists only as a Skald concept-graph function).
  [`soul:ModifyMoraleDebug(id)`](api/Soul.md#modifymoraledebug) only writes. Observe `combat_flee` /
  `combat_surrender` contexts instead.
- **The morale constants** (`wh::rpgmodule::Constants`, retail binary offsets; enemy-morale):

  | Constant | Offset | Meaning |
  | --- | --- | --- |
  | `SoulCourageMoraleWeight` | `0xbbc` | weight of soul courage (authored 6) |
  | `ClassCourageMoraleWeight` | `0xbc0` | weight of social-class courage |
  | `BadassnessMoraleWeight` | `0xbc4` | weight of badassness |
  | `SkirmishPredominanceWeight` | `0xbc8` | the side-ratio (headcount) term; no runtime writes to it, so a table value sticks |
  | `MinMorale` / `MaxMorale` | | the clamp |
  | `MoraleContextFadingSpeed` | | how fast accumulated deltas decay back |
  | `MoraleDecisionReliability` | | noise in the check |

## Crime system

Crime is mostly behaviour-tree logic parameterised by tables (official wiki KM-A-27):

- `Libs/Tables/rpg/crime.xml`: one row per label (`assault`, ...) with `fine` in decigroschen,
  `jail`, `importance`. The wiki calls the params table `script_params.xml`; the shipped file is
  `Libs/Tables/ai/ScriptParams.xml` (vanilla wins).
- **Player crime rating ("angriness")** has no Lua getter. It is write-only via
  [`soul:ModifyPlayerReputation`](api/Soul.md#modifyplayerreputation) and readable only in a tree with
  `CheckAngrinessInterval type="Violence" Faction= Flag=` (vanilla: `Scripts/AI/crime/so_crime_extraGuards.xml`).
  Bands (`Libs/Tables/rpg/angriness_flag.xml`): low (0..0.3), mid [0.3..0.6), high [0.6..0.9), alerted [0.9..).
  Extra guards spawn at 0.8, and one witnessed killing sets 0.8 (crime-watch).
- **Settlement test:** a faction name containing `_settlements_<place>` is a settlement. `_enemies_`
  disqualifies it. Only Kutná Hora carries `Labels="city"`. Require a quorum of 2 NPCs.
- **Deaths:** Skald `SoulDeathTrigger` is reported not to fire for vanilla NPCs a mod did not spawn
  (crime-watch), and play-testing found it does not fire for
  Lua-spawned shared-soul NPCs either (aleksej). Every vanilla use watches a
  level-baked NPC. Treat it as unusable from a mod and detect deaths by census polling.
- Civilians flee rather than fight, so "was this kill witnessed" must also check the flee contexts
  (town-watch).

## Script contexts

Verified in `Libs/Tables/ai/ScriptContext.xml`. Set in trees with `EntityContext`, read with
[`soul:HasScriptContext`](api/Soul.md#hasscriptcontext) (no Lua setter), set from quests with Skald
`SetEntityContext`.

| Context | Class | Effect / use |
| --- | --- | --- |
| `crime_interruptAttack` | Entity | NPC is inside an attack interrupt; the de facto "in combat" flag |
| `crime_interrupt` | Entity | any crime interrupt |
| `crime_interruptFlee` / `crime_indifferentFlee` | Entity | fleeing a crime / frightened civilian |
| `combat_flee` / `combat_surrender` | Entity | morale break outcomes |
| `combat_neverSurrenderOrFlee` | Entity | halts the surrender/flee decision |
| `combat_immortalityProtection` | Entity | a quest keeps him alive |
| `combat_defenceMode` | Entity | passive defence, no offence |
| `combat_forceArmed` / `combat_forceMelee` | Entity | weapon choice |
| `combat_disableCombatMovement` | Entity | no combat footwork |
| `combat_suppressFriendlyFire` | Entity | |
| `combat_leavePlayerUnconsciousAfterFight` | Entity | no game over on KO |
| `combat_invisible` | Entity | ignored **as a target** by the combat system; unrelated to rendering |
| `combat_forcedTarget` | Relation | forces A to target B (Skald `SetRelationContext`) |
| `crime_isAuthority` / `crime_isAuthorityOnDuty` / `crime_isSecurity` / `crime_isCivilian` | Entity | role flags |
| `crime_suppressBehavioralReaction` | Entity | ignore ambient crimes while active |
| `crime_preventDespawn` | Entity | no despawn while active |
| `crime_playerUnderArrestByAuthority` | Entity | on the player |
| `deterrenceImmunity` | Entity | |
| `PerceptionPriorityBoost` | Relation | perception stimulus priority |
| `Battle` | Game | battle mode; loads `Battle.cfg`, **suppresses dialogue globally** |
| `ForceCombatSystemAmbientLOD` | Game | forces combat LOD to ambient (see [LOD](npc-rendering-and-lod.md#combat-system-lod-and-scripted-battles)) |
| `NoDog` | Game | |

## Perception

Mostly tree-side, and sparsely documented:

| Mechanism | Where | Notes |
| --- | --- | --- |
| `perceptionInfo` inbox | `ProcessMessage inbox="'perceptionInfo'"` (43 live) | perception reports arrive as messages |
| `HasSeenPlayer NPC FullyAwareOnly` | 71 live | |
| `HasPerceivableState` / `AddPerceivableState PerceivableLabel` | 73 / 51 live | tag what others perceive about this NPC |
| `IgnorePerception` node / [`XGenAIModule.IgnorePerception`](api/XGenAIModule.md#ignoreperception) | 56 live / Lua | make a perceptor ignore a perceptible for a time (vanilla: `AnimDoor.lua`) |
| `CheckRelationshipInterval_SoulToSoul` | 77 live | relationship bands in trees |
| Area labels | `IsInsideAreaWithLabel(Barrier)`, [`XGenAIModule.IsPointInAreaWithLabelWUID`](api/XGenAIModule.md#ispointinareawithlabelwuid) | `interior` drives stealth crouch/visibility buffs (`Cpp:InteriorCrouch`); see [world and physics](world-and-physics.md) |

Exact perception ranges and the stealth model are `(unverified)`; start from the `crime/*` and
`npc/basic/switch/handleStimulus*.xml` trees.

## Formations (engine system)

Full reference: [formations](formations.md). In short: `MakeFormation` anchors on whichever entity's tree
ran it (never the player), `FormationFollower` is the followers' locomotion, `FormationMode`
`MoveHistory` is the common mode and an unknown `formationType` silently becomes `Relaxed`, and
`FormationDefinitions.xml` is a whole-file override only (vanilla: `AI/FormationDefinitions.xml`, 63 shapes).

- "Hold the line while fighting" is a `Parallel` of the combat stack and a `KeepShape` follower
  ([formations](formations.md#the-battle-system-layer)).
- The engine picks which follower gets which spot. For "this man on that spot", walk each NPC to
  his own point (squad-orders).
- Adding NPCs one at a time across formation size boundaries re-deals every slot and can strand
  followers (retest-round3).
- Measured: an engine formation was **cheaper** than N independent followers
  (performance).

## NPC-vs-NPC collision and bumping

- Crowding is handled by local avoidance (ORCA) and repulsion. There is no push-through-crowd
  system (retail binary).
- **Ghosting:** an NPC that is walked into for a while becomes passable. `CrimeFollower DisableGhosting`
  controls it for followers ([movement](../behaviour-trees/movement.md)).
- Many NPCs `Move`-ing to one static point treat each other as obstacles and scatter. Use
  `CrimeFollower` (`Role="Main"`/`"Assist"`) or a formation ([movement](../behaviour-trees/movement.md)).
- **Bumps register as hits.** A shoulder in a crowd or a horse clip can briefly create an attacker
  relationship. Confirm aggression with weapon drawn, a real combat state, and the same victim held
  for ~2 s real time (combat-target-selection).
- To stop specific pairs colliding, OR a class bit into
  [`Entity.SetPhysicParams`](api/Entity.md#setphysicparams)`(PHYSICPARAM_COLLISION_CLASS, ...)`. The test is
  symmetric, and the mask must be re-applied after any re-physicalisation
  (collision-ghosting, bit table in [world and physics](world-and-physics.md)).
  `ac_disableLivingVsLivingCollisions` exists but needs a level reload (cvar help text).
- Converging groups shove each other sideways hard enough to push an NPC through a wall. Move
  groups as a leader-and-trailers column (walls-and-sieges).

## Knockouts, death and corpses

- [`Actor.CanDoMercyKill`](api/Actor.md#candomercykill) is player-only: an NPC is refused at 1.4 m
  while the player is allowed at 7.7 m. [`Actor.Revive`](api/Actor.md#revive) on a corpse does
  nothing, and [`Actor.RequestKnockOut`](api/Actor.md#requestknockout) has no effect (verified in
  game: loot-sweep).
- Knock out a live NPC with [`soul:AddBuff`](api/Soul.md#addbuff)`("c75aa0db-65ca-44d7-9001-e4b6d38c6875")`
  (`unconscious_permanent`, `Cpp:Unconscious`) or the 60 s variant `f8d60fe4-e2c1-420a-946a-213e1cd09264`
  (vanilla: `Libs/Tables/rpg/buff.xml`).
- [`soul:DealDamage`](api/Soul.md#dealdamage) on stamina never knocks out; the overflow goes to health.
- Corpse despawn timers (`CorpseDisappearanceTime*`) are in **game-time** seconds, and nothing
  despawns within 30 m of the player. `wh_rpg_CorpseDisappearAddedDelay` is only a retry delay
  (loot-sweep). `CorpseDisappearanceTimeUndiscovered` is authored 3600
  (vanilla: `Libs/Tables/rpg/rpg_param.xml`); `...Discovered` is not in the table and keeps its compiled default
  of 300 (official wiki). Both are table-patchable `rpg_param` rows. At KCD2's day length a game second is worth
  roughly 1/12 of a real one by loot-sweep's estimate (the calendar ratio reads 15,
  see [world and physics](world-and-physics.md#time-fast-travel-and-time-skips)), so vanilla bodies vanish within minutes.
- No animation substitutes for a mercy kill: the vanilla kill fragments in `anim_fragment.xml` are **two-actor**,
  `aligned="true"` quest scenes with a `...Slave` counterpart and baked root motion; the standalone ones need specific
  weapon tags. A T-pose means a fragment whose work is all in its `Loop` failed its tag match
  (loot-sweep, verified in game).
- [`Actor.AcceptStealthActionByVictim`](api/Actor.md#acceptstealthactionbyvictim) ("called by victim to accept stealth
  action") is docs-only in the API index and has no callers in vanilla Lua: the victim half of stealth takedowns is
  engine-driven, so a mod cannot complete that handshake by hand (loot-sweep).
- `System.GetEntitiesByClass('NPC')` returns ragdoll corpses. Freeze settled ragdolls to save CPU
  (performance).

## Gotchas

- **NPC stands still when told to attack**: the `Behavior` has no `SmartBehaviorTemplate`, or the
  target was re-fired every tick (each re-fire replays entry and draw).
- **Fresh enemies swing with fists for seconds**: `WeaponChange="none"`. Use `melee`/`missile`.
- **30% of a battle stands idle but visible**: empty weapon set. Grep the log for `explicit DrawAction`.
- **Fighters approach in step-pause-step**: `CombatAction` inside a `Loop`, a missing
  `CombatMoveDecorator`, or target churn re-firing the interrupt.
- **Custom squad turns on guards**: a relationship test that treats anything below 1 as hostile, or
  one that does not separate "wanted player" from "outlaw". Only `-1` plus a label or faction test.
- **Squad charges villagers**: `GetTarget` on the player without a weapon-drawn check.
- **Town watch ignores a fight between mod NPCs**: no reverse faction relation exists, and nobody
  emits `crime_emitInformation`.
- **Enemies flee before contact against a big squad**: vanilla morale headcount term. See
  [morale](#morale-why-enemies-run).
- **Everyone reads as "not targeted"**: code relies on `soul:GetTarget()`, which does not exist.
- **Combat-feel cvars "don't work"**: they do take effect, and still change nothing visible. Do not
  rebuild that experiment.
- **Mercy kill never offered to NPC logic**: player-only engine rule.
- **Permanent `Battle` context kills all dialogue** (npc-lod).

## See also

combat-movement, combat-target-selection,
enemy-morale, crime-watch, public-enemy,
[formations](formations.md) (squad formations), ai-modules, foe-ai,
archers, collision-ghosting, public guide
[combat](../behaviour-trees/combat.md).
