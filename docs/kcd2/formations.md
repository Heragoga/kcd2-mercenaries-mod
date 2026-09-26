---
title: Formations (engine system)
summary: How does vanilla KCD2's behaviour-tree formation system work - presets, the five live nodes, modes, slot selection, leader/follower rendezvous, fighting in formation - and what can a mod reuse, replace or never reach?
tags: [ai, bt]
kind: reference
status: current
scope: kcd2
verified: release_1_5
---

# Formations (engine system)

## TL;DR

- A formation is a named 2-D shape in `AI/FormationDefinitions.xml` (63 presets). A tree creates one with
  `MakeFormation`; the **anchor is whichever entity ran that node** - there is no anchor argument, so the
  player can never be the anchor.
- Followers look the handle up from any member with `GetMemberFormation` and run `FormationFollower`,
  which **is** the locomotion (no `Move`). `FormationMode`: `Relaxed`=0, `KeepDistance`=1,
  `MoveHistory`=2 (the common one), `KeepShape`=3.
- The only hard problem is the race "follower looks up before the leader created it". Vanilla solves it
  six ways; the cheapest is a `Selector` + `Wait '1s'` retry.
- `EndFormation` is optional (a formation dies with the behaviour that made it); `ChangeFormation`
  re-shapes without invalidating handles.
- `FormationDefinitions.xml` is not a database table: a mod can only replace the **whole file**. Reusing a
  vanilla preset name costs nothing.
- The battle-group formation controller is unreachable from a mod, but the three core nodes need none of
  it; "hold the line while fighting" is a copyable `Parallel`.

Everything here is read out of the vanilla files unless marked. Paths are pak-relative: `AI/...` is in
`Scripts.pak`, `Libs/Tables/...` in `Tables.pak` (local extracts: `references/AI/`,
`references/kcd2-mod-docs-main/Scripts/AI/`). Counts are **live** counts (see
[Live nodes vs editor scratch](#live-nodes-vs-editor-scratch)). The full evidence, with line numbers and
the mod's own use, is in formations.md; node syntax in general is in
[behaviour trees](behavior-trees.md).

## Presets: `FormationDefinitions.xml`

```xml
<FormationDefinitions version="1">
    <Formation name="dogCompanion_followHeel">
        <Spot name="leftHeel" radius="1" x="-1.2" y="0.2" />
    </Formation>
```

- The whole schema: `<Formation name>` and `<Spot name radius x y>`. **No `z`**, no orientation, no
  per-spot unit class, no `.xsd`. Attribute order varies and is not significant (vanilla:
  `AI/FormationDefinitions.xml`, 63 formations, ~395 live spots).
- `radius` is undocumented; usage suggests an arrival tolerance (loose mounted presets 1-3, tight indoor
  queues 0.3) (inference).

### Coordinate convention

Not documented anywhere; read off consistent name/sign correlation across all 63 presets (inference, strong):

| Axis | Meaning | Evidence |
| --- | --- | --- |
| `+x` | leader's right | `nextToLeader`: `left x="-1.2"` / `right x="1.2"` |
| `+y` | **behind** the leader | `followNPC` ranks trail at y = 1.7 / 3.5 / 5.2 / 6.9; `row1`..`row7` presets increase in y |
| `-y` | ahead of the leader | `returnStartledHorse` has one spot at `y="-3.0"`, and the NPC who takes it walks ahead of the horse |
| units | metres | 1.2-1.5 m infantry spacing, 2.5-3.5 m for riders |

**The leader sits at the origin and gets no `<Spot>`**: only one spot in the file is at (0,0), and presets
whose name encodes a headcount list N-1 spots (`cavalryRiders6` -> 5, `infantryMen20` -> 19). A convention,
not enforced (`rutinaAVypad_halberdPatrol_16` lists 16).

### Spot names are classes, not geometry

`<Spot name>` is free-form and **deliberately non-unique**: `followNPC` has four `left` and four `right`,
`infantryMen20` calls all 19 spots `front`. A name is a *class* of slot that `PreferredPositions` selects
into; the engine picks a free member. Names also lie (`bailiffAndScribe_walkAround`'s `left` sits at
`x="1"`), so never infer layout from a name. `followCart` is the one preset built for targeting: 8
uniquely named spots (`leftClosest`...`rightFurthest`).

### Notable presets

| Name | Spots | Shape / use |
| --- | ---: | --- |
| `followNPC` | 8 | two files +-0.7 m, ranks every 1.7 m. The BT-side default when `formationData.type` is empty (`AI/quests/questUtils.xml`) |
| `block6wide` | 5 | 1.2 m box; default of the Skald `formationname` port only, not an engine default |
| `nextToLeader` | 2 | one either side, level with the leader |
| `longLine` | 4 | single file, radius 1.5 |
| `guard_pairs` | 1 | `x=1.5 y=1.2`; used by `so_guardPair` |
| `followCart` | 8 | `followNPC` shifted 2.7 m back, uniquely named spots |
| `dogCompanion_followHeel` / `_horse` | 1 | heel at the left hip; the mounted one 3 m back, radius 3 |
| `battleFormation_basic25` | 24 | 5x5 grid at 1.5 m, spots `front`/`back` |
| `cavalryRiders6` | 5 | cutscene army riders, all radius 0.5 |
| `infantryMen20` | 19 | four jittered ranks of 4-5, all `front` |
| `prototypeFollowPlayer` | 8 | dead data: duplicated positions, referenced by nothing |

## The node contract

```xml
<MakeFormation       FormationName="'guard_pairs'" HandleVariable="$formationWUID" />
<GetMemberFormation  MemberWUID="$leader" FormationHandleOut="$formation" />
<FormationFollower   FormationHandle="$formation" PreferredPositions="" FormationMode="MoveHistory" AllowRelocation="false" />
<EndFormation        FormationHandle="$formationWUID" />
<ChangeFormation     NewName="$formationName" Formation="$formationWUID" />
```

(Single quotes shown unescaped; in files they are `&apos;`.)

| Node | Live | Notes |
| --- | ---: | --- |
| `MakeFormation` | 31 | `FormationName`, `HandleVariable`. **No anchor, position or roster argument.** |
| `GetMemberFormation` | 19 | any member WUID -> handle. The creator is a member, so `GetMemberFormation(leader)` is the standard handoff |
| `FormationFollower` | 25 | long-running; **is** the follower's locomotion. No speed attribute: follower pace is engine-driven |
| `EndFormation` | 27 | only ever called by the creator, from a cleanup branch. There is no `LeaveFormation`: a follower leaves by exiting `FormationFollower` |
| `ChangeFormation` | 2 | re-shapes a live handle; note the attribute is `Formation`, not `FormationHandle` |
| `FormationInSpotsGate` | **0** | the only non-leaf (`Formation`, `PercentageThreshold`, `WaitingTimeout`, `FailOnTimeout`, `RunLogic`); its single occurrence is editor scratch |

- Attribute sets are invariant across ~106 vanilla nodes; that every attribute is mandatory is inference.
- Always write the handle into a declared `_wuid` local. The one vanilla site that writes
  `HandleVariable="$this.id"` (`AI/animal/basic/switch/interrupt_animal_returnFromStartle.xml`) is a
  designer bug that only works because `EndFormation` there is on the abort path.
- The engine registers **more** formation nodes than the data uses: `C_AnchorFormation`,
  `C_TeleportFormationToSpots`, `C_GetFormationLeader`, `C_GetFormationParticipants`, `C_FormationSize`
  each have the full BT-node factory/wrapper RTTI quartet but appear in no XML. Their XML names and
  attributes are unknown (retail binary: RTTI in `WHGame.dll` release_1_5).
- The `AI` Lua table still carries CryEngine's legacy formation binds (`AI.CreateFormation`,
  `AddFormationPoint`, `ChangeFormation`, `GetFormationPosition`, ... 15 in all, retail-confirmed, 0
  vanilla uses). Nothing connects them to the XGEN nodes above; treat them as unrelated
  ([api/AI.md](api/AI.md), `(unverified)` whether they do anything).

### Live nodes vs editor scratch

Every `<BehaviorTree>` has `<Root>` (executed), `<ForestContainer>` (the editor's disconnected canvas) and
`<EditorData>`. **A node under `<ForestContainer>` never runs.** Six formation nodes in vanilla are scratch
(`AI/battles/battlegroupcontroller.xml` - the `FormationInSpotsGate` and its child `EndFormation`;
`AI/quests/sermiri/menhart.xml`; three in `AI/quests/utokNaNebakov/utokNaNebakov.xml`), so raw grep counts
overstate the live system. `utokNaNebakov`'s `PreferredPositions="$data"` is triply dead (after
`</Root>`, undeclared variable, preset that does not exist) - do not cite it as a pattern.

### `ChangeFormation`: re-shaping without invalidating handles

`EndFormation` + `MakeFormation` mints a new handle and every follower's handle goes stale.
`ChangeFormation` changes the shape in place. Both live uses are the same poll-and-diff watcher
(vanilla: `AI/speech/tour_movementinformation.xml`, `AI/move/moveinformation_tagpointroute.xml`):

```xml
<While doFail="false" propagateChildFail="false" condition="true">
  <IfGate atomic="false" condition="$currentFormation ~= $formationName" RunLogic="KeepRunning">
    <Sequence>
      <ChangeFormation NewName="$formationName" Formation="$formationWUID" />
      <Expression expressions="$currentFormation = $formationName" />
    </Sequence>
  </IfGate>
</While>
```

Three structural requirements: `$formationName` is a `requirementType="ConstReference"` parameter (so the
caller can rewrite it mid-run); `$currentFormation` is a local seeded right after `MakeFormation`; and the
`While` is a `Parallel` **sibling** of the leader's movement with `RunLogic="KeepRunning"`, or the
followers are torn down on each change.

## `FormationMode` and the params struct

| Value | Ordinal | Vanilla use |
| --- | ---: | --- |
| `Relaxed` | 0 | 2x - the struct default; loose escort |
| `KeepDistance` | 1 | 1x - carts (`AI/carts/carts.xml`) |
| `MoveHistory` | 2 | 14x - followers replay the leader's recorded path; every marching/mounted column |
| `KeepShape` | 3 | 6x - rigid geometry: guard pairs, parade blocks, battle lines |

Ordinals from `enum_formationMode` in `lua_dump_state/LuaState_Sorted.txt`. What each mode does at runtime
is undocumented; the table is usage-derived. The attribute accepts the bare token or
`$enum:formationMode.MoveHistory` (both forms in `AI/quests/vezniNaTroskach/vezniNaTroskach.xml`).

**Two enums, one bridge, one trap.** `formationMode` is engine-side; the designer-facing mirror is
`<Enum name="formationType" ExportToConcept="true">` in `Libs/Tables/ai/ai_enums.xml`, with the same four
values and ordinals - it is what Skald ports expose. Every vanilla caller bridges them with a copy-pasted
`Switch` (canonical: `AI/move/moveInFormation_simple.xml`) that tests `KeepDistance`, `MoveHistory`,
`KeepShape` and puts `Relaxed` in the `DefaultBranch`. The mapping is an identity, so its only real effect
is the fallback: **any unrecognised `formationType` - including a typo in a Skald `ConstantPort` - silently
becomes `Relaxed`**, no error, no log.

(Naming trap: `AI/move/moveInFormation_simple.xml` is the tree; `Quests/.../utils/move/moveinformation_simple.xml`
is the Skald module that calls it.)

`AllowRelocation` is a plain bool, unrelated to the engine's `enum_relocationPolicy` (which has its own
`KeepDistance` at a different ordinal). It is `false` at 22 of 24 sites; both `true`s are `KeepShape`,
one of them a line that fights. Best reading: it lets a follower swap slots when the shape shifts
(inference).

```xml
<Type Name="formationData">
    <Member Name="leader" Type="wuid" />
    <Member Name="type" Type="string" />
    <Member Name="preferedPosition" Type="string" />
    <Member Name="policy" Type="enum:formationMode" InitialValue="$enum:formationMode.Relaxed" />
    <Member Name="speedLimit" Type="enum:movementSpeed" InitialValue="$enum:movementSpeed.dash" />
    <Member Name="allowRelocation" Type="bool" InitialValue="false" />
</Type>
<Type Name="followFormationParams"><Member Name="formation" Type="formationData" /></Type>
```

(vanilla: `Libs/Tables/ai/ai_types.xml`). **Both misspellings are load-bearing**: the struct member is
`preferedPosition` (one `r`, singular), the node attribute is `PreferredPositions` (two `r`s, plural).
`speedLimit` only ever feeds the leader's `Move speed`.

### Choosing a spot: `PreferredPositions`

Live histogram: `""` x14, a BT parameter x6, a struct field x2, literals `'npc'`, `'leftClosest'`,
`'firstLine'` x1 each. No site passes more than one name; whether a list is accepted is unverified.

| Source | Mechanism | Example (vanilla) |
| --- | --- | --- |
| none | `""`: engine picks any free spot. The majority | `AI/profession/guard/so_guardPair.xml` |
| literal | a `<Spot>` name inline | `'npc'` in `AI/npc/basic/switch/interrupt_returnStartledAnimal.xml` |
| BT parameter | the quest passes one `_string` per NPC from Skald | `$formationPreferredPosition`, `vezniNaTroskach.xml` |
| struct field | `followFormationParams.formation.preferedPosition` | `AI/move/moveUtils.xml`, `AI/quests/questUtils.xml` |
| the NPC's own name | `preferedPosition = $this.name` against spots named after NPCs | `AI/quests/prepadeni/prepadeni.xml` - registered `Disabled` and never enabled: **unexercised** |
| **array indexed by rank** | `FindInArray` the NPC in the participant list, then `$preferredPositions[$index]` | `AI/move/moveinformation_tagpointroute.xml`, `utokNaMalesov.xml` |
| link `Data` payload | `LinkTagFilter tag="'test_string'" Data="$position"` | `battlegroupcontroller.xml` - needs level-baked links |
| per-soul override | `IfCondition` on `$followableSoul == $this.id`, `'none'` as the unset sentinel | `tour_movementinformation.xml` |

The array-by-rank row is the **only** vanilla pattern that scales to N followers without level data or
per-NPC quest constants:

```xml
<FindInArray array="$movingNPCs" keyOut="$index" condition="$__value == $this.id" />
<IfCondition failOnCondition="false" condition="$index &lt; #preferredPositions">
  <Expression expressions="$followFormationParams.formation.preferedPosition = $preferredPositions[$index]" />
</IfCondition>
```

A name that matches no spot: `battlegroupcontroller.xml` asks for `'firstLine'` against
`battleFormation_basic25` (spots `front`/`back` only) and ships, which weakly suggests a silent fallback to
any free spot `(unverified)`.

## The canonical recipe

The smallest complete pair is `AI/profession/guard/so_guardPair.xml` - two trees, no quest, no lock:

```xml
<!-- leader -->
<OnInit><MakeFormation FormationName="'guard_pairs'" HandleVariable="$formationWUID" /></OnInit>
<Behavior>
  <FuseBox StatusPropagation="Child" OneCleanup="true">
    <Child><Move destinationSpecification="$__resource.id" speed="Walk" ... /></Child>
    <OnFail><EndFormation FormationHandle="$formationWUID" /></OnFail>
  </FuseBox>
</Behavior>

<!-- follower -->
<OnInit><GetBehaviorHolders area="$__object.id" behaviors="'master'" targetVar="$behaviorHolders" /></OnInit>
<Behavior>
  <Sequence>
    <IfCondition failOnCondition="false" condition="#behaviorHolders &gt; 0">
      <GetMemberFormation MemberWUID="$behaviorHolders[0]" FormationHandleOut="$formationWUID" />
    </IfCondition>
    <Selector>
      <IfCondition failOnCondition="true" condition="$formationWUID ~= $__null">
        <FormationFollower FormationHandle="$formationWUID" PreferredPositions="" FormationMode="KeepShape" AllowRelocation="false" />
      </IfCondition>
      <Wait duration="'1s'" timeType="GameTime" doFail="false" variation="" />
    </Selector>
  </Sequence>
</Behavior>
```

- `MakeFormation` in `OnInit` (or `SubtreeDecorator/Init`); `EndFormation`, if used, only in a guaranteed
  cleanup slot (`FuseBox/OnFail`, `FuseBox/OnSuccess`, `SubtreeDecorator/Cleanup`), never a bare sibling.
- The `Selector` + `Wait '1s'` is the cheapest synchronisation gate: null handle -> nap -> re-enter.
- `GetBehaviorHolders` finds the leader ("who on this smart object runs `master`") instead of wiring a WUID.
- Minimum follower: `WaitAction` -> `GetMemberFormation` -> `FormationFollower`, no gate at all
  (`AI/test/_lukas/enablebehavior.xml`). Cheapest role split: one shared tree with
  `IfElseCondition condition="$this.id == $data"` (`mucirna_vypaleniSemina.xml`).
- The null guard is a convention: `erik_armyMovement.xml` and `moveUtils.xml` feed the handle straight in.

**Lifecycle: `SubtreeDecorator` beats `FuseBox`.** `FuseBox/OnSuccess` releases only on success, `OnFail`
only on failure; `SubtreeDecorator` `Init`/`Subtree`/`Cleanup` releases on **any** exit, including an
interrupt - what you want when a scheduler can yank the behaviour.

**`EndFormation` is optional.** The startle animal calls it only on its abort path, `AI/battles/formationholder.xml`
never calls it, and `moveUtils.xml` puts it behind an infinite `Wait`. A formation is owned by the
behaviour that created it and dies with it (inference from three shipped trees).

What vanilla never does: re-elect a leader. A follower's death frees its spot; a leader's death leaves
everyone holding a handle whose owner is gone (no death handling in any formation tree).

### The common idiom

Every on-foot quest formation reduces to four parts:

1. A preset with at least as many spots as followers.
2. One `MakeFormation` on the leader, held for the scene; `EndFormation` in a cleanup slot if at all.
3. A role split **inside one shared behaviour**, by one of four tests: `formation.leader == $this.id`,
   `$this.id == $data`, a `_wuid` In param `== $this.id`, or a level-link existence check.
4. One of the six rendezvous primitives below.

Only the **leader** is route-driven (tagpoint swapped by Skald, `PredefinedPathAsset`, a `'next'`-linked
tagpoint chain, a live entity, or nothing); followers are always follow-driven. Leader election by level
link: every member runs `erik_armyMovement.xml`; only the NPC owning an `endMovement` link passes the
leader branch's `GraphSearch`, everyone else falls into the follower branch. `cavalry_move` wraps the
whole split in `StanceElement stance="horse"` with `WaitAction` first, so the formation exists only while
mounted; `infantry_move` is identical minus the horse and uses `infantryMen20`.

Some trees configure `followFormationParams` and delegate without containing any formation node
(`moveInFormation_simple.xml`, `tour_formationHorseDesicion.xml`, `tour_advanced.xml`); grepping for the
nodes misses them.

## Rendezvous: follower must not look up before the leader creates

| Mechanism | Shape | Vanilla example |
| --- | --- | --- |
| Retry loop | `Selector` + `Wait '1s'`, or `While` + null check | `so_guardPair`, `carts.xml` |
| Named lock | leader `SetExternalLock Locked="false"` right after `MakeFormation`; follower wraps its lookup in `ExternalLock` on the same name | `erik_armyMovement` (`Local`, `'formationReadyToJoin'`), `followNPC_slave` (`Global`) |
| Per-instance named lock | root lock name templated on the anchor's WUID, shipped in a message; derived sub-locks by suffix | the startle pair, below |
| Message push | leader `InstantMultiSendMessageToNPC variable="$formation"`; follower `ReadMessage inbox="'battle_formationSetup'"` | `battlegroupcontroller`, `finale`, `menhart` |
| `Synchronize` | N-count semaphore, everyone starts on one tick | `finale`, `menhart`, `walkaround.xml` |
| Everyone-present link gate | each member `AddLink` to the leader; leader waits on `LinkGate amount="All" presence="Present"` | `vezniNaTroskach.xml` |

Tightest link-gate form self-keys: `AddLink From="$this.id" To="$this.id" Tag="$formationName"` and
`LinkGate from="$npcs" to="$this.id" tag="$formationName" amount="All" presence="Present"` - the formation
name doubles as the link tag.

**Lock names interpolate.** `LockName="'$formationLock'"` is not a literal dollar string: single-quoted
string literals interpolate variables. That is the basis of the shared `followNPC_leader_<wuid>` lock,
built with `Concatenation Pattern="'followNPC_leader_$t_followFormationParams.formation.leader'"` in both
shipped slave implementations (`questUtils.xml`, `moveUtils.xml`) - reuse `Function_moveInFormation_slave`
and your leader must open and release exactly that name. Inside a `Pattern`, **`;` terminates the
variable name**: `'$formationLock;_sweetSpot'` appends `_sweetSpot` to the value.

**Do not copy the lock lines from `vezniNaTroskach.xml`'s `SubtreeDecorator`.** The leader opens
`LockManagerType="Local"` but `Cleanup` closes `LockManagerType="Global"`, while the follower waits on
`Local`; the same mismatch recurs later in the file. It fails *open* (a re-run skips the wait), which is why
it shipped. The correct pairing is `Global`/`Global` elsewhere in that file, matching what `moveUtils.xml`
waits on.

### The ambient startle pair: a runtime formation with no quest or level data

The one vanilla formation not created by a quest, battle controller, cart, profession pair or helper: a
horse is startled, a passing NPC notices, and the two negotiate a formation at runtime through messages,
global locks and graph links. Structurally it is what a mod needs.

Leader (the animal, `AI/animal/basic/switch/interrupt_animal_returnFromStartle.xml`):

```xml
<Sequence>
  <MakeFormation FormationName="'returnStartledHorse'" HandleVariable="$this.id" />
  <SetExternalLock LockManagerType="Global" Locked="false" LockName="'$returnFromStartleData.formationLock'" />
  <Concatenation OutString="$sweetSpotLock" Pattern="'$returnFromStartleData.formationLock;_sweetSpot'" />
  <ExternalLock ... TimerType="GameTime" OutsideTimerValue="'10s'" LockManagerType="Global" SemaphoreName="'$sweetSpotLock'" RunLogic="KeepRunning">
    <Move ... destinationSpecification="$returnFromStartleData.positionToReturnTo" speed="Walk" ... />
  </ExternalLock>
</Sequence>
```

1. The unlock of a lock the NPC pre-closed **is** the "formation exists" signal; there is no event.
2. The second lock name is derived by suffix; the NPC computes the same string independently. The halves
   agree by naming convention, not shared state.
3. The horse does not walk until the follower opens the sweet-spot lock (in position). The `Move` is the
   formation's only locomotion.

Follower (`AI/npc/basic/switch/interrupt_returnStartledAnimal.xml`): `GetMemberFormation` from the
animal's WUID, then a `Parallel` of `FormationFollower PreferredPositions="'npc'" FormationMode="MoveHistory"`
and an `IsInSweetSpotRange` watcher that opens `$sweetSpotLock`. Its request side:

```xml
<Concatenation OutString="$formationLock" Pattern="'returnHorse_$returnStartledAnimalData.animal'" />
<Concatenation OutString="$sweetSpotLock" Pattern="'$formationLock;_sweetSpot'" />
<SetExternalLock LockManagerType="Global" Locked="true" LockName="'$formationLock'" />
<SetExternalLock LockManagerType="Global" Locked="true" LockName="'$sweetSpotLock'" />
<InstantSendMessageToNPC target="$returnStartledAnimalData.animal" variable="$return_request" />
```

Two independent layers worth copying:

- **Instance scoping by lock naming.** `Global` locks share one flat namespace; key every name on the
  **shared subject's** WUID (the animal, never the reacting NPC) and any number of encounters run
  concurrently with no registry and no Lua.
- **Exclusivity by an auto-inverse link.** `crime_returnStartledAnimalReserved` (declared with `autoInverse`
  + `removeOnRevive` in `AI/LinkTagDefinitions.xml`) is claimed with `AddLink` only when a `GraphSearch` for
  the `_reverse` tag fails, and released on abort (`callInterrupt_returnStartledAnimal.xml`).
- `InstantSendMessageToNPC` has no inbox attribute; routing is by struct type name
  (`crime:animal_returnFromStartleRequest` -> inbox `'crime_animal_returnFromStartleRequest'`) (inference).

### `followNPC_inFormation`: two trees, one empty

`followNpc_inFormation` (lower-case `p`, `AI/move/moveUtils.xml`) is an empty `<Root/>` stub, as are its
`followNpc_leader`/`_slave` siblings. `followNPC_inFormation` (`AI/quests/questUtils.xml`) is real: a
dispatcher on `formation.leader == $this.id`, reading a forward-declared thread variable
`t_followFormationParams`. Its leader **does not move** - it makes the formation (falling back to
`followNPC` when `type` is empty), opens the global lock and hands locomotion to a caller-supplied
`leaderCallback`, a member `followFormationParams` does not declare (unresolved). The modern equivalent
with proper parameters and a moving leader is `moveInFormation_leader` / `_slave` in `moveUtils.xml`.

## The battle-system layer

`AI/battles/battlegroupcontroller.xml` adds runtime leader election, push-broadcast of the handle, a
dynamic roster, per-member slot names from link data, and fighting in formation.

**Leader election** (tree `move_formation`) is copyable with zero battle dependency - a 1-count semaphore
around "find an existing `'leader'` link, else claim it":

```xml
<Semaphore SemaphoreCount="1" ... LockManagerType="Local" SemaphoreName="'leaderAssignment'">
  <Selector>
    <GraphSearch Origin="$__object.id" depth="1" ... failOnEmpty="true" ...>
      <LinkTagFilter tag="'leader'" prune="true" negprune="unknown" Parent="" Child="$leader" Data="" />
    </GraphSearch>
    <AddLink From="$__object.id" To="$this.id" Tag="'leader'" Data="" LinkOpHandleMode="Success" />
  </Selector>
</Semaphore>
```

It is a **one-shot latch**: nothing ever removes the `'leader'` link, so a dead leader is never replaced.

- **Roster:** `GraphSearch depth=1` + `SoulIsAliveFilter` with no tag filter into a `Nodalyzer`: every living
  linked entity, recounted each pass. The controller makes the formation, waits 2 s, then pushes the handle
  with `InstantMultiSendMessageToNPC targets="$formationParticipants"` - members join by receiving it.
- **Fighting in formation** needs no battle infrastructure:

```xml
<Parallel successMode="Any" failureMode="Any">
  <MeleeOffenseAutomationDecorator active="true">
    <MeleeDefenseAutomationDecorator active="true">
      <MeleeGuardAutomationDecorator GuardMode="automate" active="true">
        <WeaponAutomationDecorator WeaponChange="none" active="true">
          <CombatFollowerDecorator ProbablisticDrivenSweetSpot="true" RPGSweetSpotArcDriver="true" active="true">
            <CombatAction TargetNPC="$enemySoldier" RelationOverride="None" />
          </CombatFollowerDecorator>
        </WeaponAutomationDecorator>
      </MeleeGuardAutomationDecorator>
    </MeleeDefenseAutomationDecorator>
  </MeleeOffenseAutomationDecorator>
  <FormationFollower FormationHandle="$formation" PreferredPositions="'firstLine'" FormationMode="KeepShape" AllowRelocation="true" />
</Parallel>
```

`KeepShape` + `AllowRelocation="true"` beside the full melee stack is "hold the line while fighting"
(combat stack: [combat and perception](combat-and-perception.md#the-combat-stack)).

### Reachability of the controller

**Dead end for a mod.** 32 of the 37 `SmartBehaviorTemplate`s in
`Libs/Tables/ai/smartEntity/SmartEntity__battleGroupController.xml` are `InitialState="Disabled"`,
including `move_formation`; only a Skald `EnableBehavior` on a level-baked asset turns one on, and there is
no Lua binding. The `formationHolder` half was built and never shipped (zero `formationHolder` entities in
either level; the `fightformation` Skald module appears only as static namespace declarations). None of it
matters: the three core nodes have no dependency on it.

### Link tags need no declaration

`AI/LinkTagDefinitions.xml` is not the authoritative registry: `formationHolder`, `formationPosition` and
the battle election's `'leader'` all have zero hits in it yet drive shipped behaviour (`formationPosition`
is declared in level data and as a `<Type>` in `ai_types.xml` instead). **A mod may invent a link tag
without declaring it anywhere** - the `'leader'` election proves it works.

## The player and formations

- **The player cannot anchor a formation.** No formation node in `AI/` takes `$__player`, and the
  behaviours vanilla enables on the player never contain `MakeFormation`. With the dispatcher pattern a
  player "leader" fails silently: no NPC takes the leader branch, `MakeFormation` never runs, every
  follower's lookup is null and the null guard swallows it.
- **A live NPC is not required - a BT-executing entity is.** Vanilla anchors on a cart smart object, a
  `SmartObjectHolder` and a horse. There is no tagpoint/path anchor; those can only be the leader's `Move`
  destination.
- **The player follows a formation only when mounted, and only via `playerProxy` links.** Two shipped cases
  (`AI/quests/prijezdNaSuchdol/prijezdnasuchdol.xml` against a cart, and the `prepadeni` ride through
  `moveInFormation_simple`) run `FormationFollower` on the player, both inside `StanceElement stance="horse"`.
  The player has a real brain (`brain_name="player"`, Switching + Scheduler subbrains), but trees reach it only
  through a quest `EnableBehavior` plus a level-baked link on the `playerProxy` tagpoint whose name encodes the
  schedule (`_<priority>,!<urgency>,<behaviorName>`, e.g. `_60,!Fast,prijezdNaSuchdol_PlayerFollowsWagon`)
  and a matching scheduler row - neither of which a mod can add (vanilla level data).
  `moveInFormation_simple.xml` has a dismounted `Else` branch that shipped data never takes; a dismounted
  player in a slot is `(unverified)`.

So vanilla has no pattern for "NPCs form up on the player"; a mod needs an NPC leader it elects itself
(formations.md is one working design).

## Moddability

- **`FormationDefinitions.xml` is a whole-file override only.** It is not a database table (zero
  occurrences in the official table inventory, official wiki KM-A-12), ships in `Scripts.pak` not
  `Tables.pak`, and the loader holds one bare `FormationDefinitions.xml` literal with no part-file pattern
  (retail binary). A mod's copy goes at `data/AI/FormationDefinitions.xml` (pak entry
  `AI/FormationDefinitions.xml`, the same root vanilla uses) ([mod structure](mod-structure.md)).
- Same-path override of AI XML is honoured (community: `zdjbcamping_mod` ships whole `AI/world/*.xml`).
  The file is read once at AI-system init; that a mod pak's copy is mounted in time has only
  circumstantial in-game evidence (the Mercenaries mod ships one and its presets appear to resolve; the
  decisive control test has no recorded result).
- Cost of overriding: copy all 63 vanilla formations or delete them game-wide, conflict with any other mod
  shipping the file, and silently revert on a game patch - regenerate after every patch.
- **Conflict-free alternative:** reuse a vanilla preset name. `MakeFormation` takes only a string, so
  `followNPC`, `longLine`, `nextToLeader`, `infantryMen20`, `cavalryRiders6` are available to any mod tree.

## Gotchas

- **Followers stand still or trail as a blob with no error:** the "leader" is the player or an entity whose
  tree never ran `MakeFormation`; `GetMemberFormation` returns null and the null guard swallows it.
- **A formation type from Skald is silently loose:** an unrecognised `formationType` (typo, wrong case)
  falls into the bridge `Switch`'s `DefaultBranch` and becomes `Relaxed`.
- **`PreferredPositions` from a struct does nothing:** the struct member is `preferedPosition` (one `r`,
  singular); the node attribute is `PreferredPositions`.
- **Followers are stranded after a shape change:** `EndFormation` + `MakeFormation` minted a new handle;
  use `ChangeFormation`, run as a `Parallel` sibling of the leader's movement.
- **A copied formation node never runs:** it came from `<ForestContainer>` (editor scratch), not `<Root>`.
- **Second encounter deadlocks the first:** a `Global` lock with a fixed name; template it on the shared
  subject's WUID.
- **Lock name reads as `$x_suffix` literally or as the wrong variable:** single-quoted strings interpolate;
  terminate the variable with `;` before a suffix (`'$lock;_sweetSpot'`).
- **Re-running a behaviour skips the "wait for leader" phase:** `Local` open vs `Global` close lock
  mismatch (vanilla `vezniNaTroskach.xml` ships this); pair the manager types.
- **A dead leader leaves the whole formation frozen:** vanilla never re-elects (the battle election is a
  one-shot latch); re-elect yourself.
- **Vanilla formations vanish game-wide after installing a mod:** its `FormationDefinitions.xml` override
  dropped presets, or is from an older game build.

## See also

- formations.md - the full evidence with line numbers, and the
  Mercenaries squad formation built on an elected NPC leader.
- [behaviour trees](behavior-trees.md) (node syntax, locks, links), [combat and perception](combat-and-perception.md)
  (combat stack, collision), [AI brains and NPCs](ai-brains-and-npcs.md) (the player's brain, SmartEntity),
  [skald quests and dialogue](skald-quests-dialog.md) (`EnableBehavior`), [mod structure](mod-structure.md)
  (whole-file overrides).
