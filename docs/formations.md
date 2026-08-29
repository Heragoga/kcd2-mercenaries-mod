# Vanilla formations

How Warhorse's own formation system works, and why this mod does not use it. The short version, up front: **a formation is anchored on the entity whose behaviour tree ran `MakeFormation`, and the player never runs one** — so "the squad forms up around the player" is not expressible with vanilla formations. Everything below is read out of the extracted vanilla files; inferences are labelled.

## What a formation is

A named 2-D shape, defined once in [FormationDefinitions.xml](../references/AI/FormationDefinitions.xml) (606 lines, 63 `<Formation>` entries, 395 live `<Spot>`s). The whole schema is three elements and four attributes:

```xml
<FormationDefinitions version="1">
    <Formation name="dogCompanion_followHeel">
        <Spot name="leftHeel" radius="1" x="-1.2" y="0.2" />
    </Formation>
```
([FormationDefinitions.xml:2, :4-5](../references/AI/FormationDefinitions.xml)) — `<Formation>` has only `name`; `<Spot>` has only `name`, `radius`, `x`, `y`. **There is no `z`**, no orientation, no per-spot unit class, and no `.xsd` anywhere in the extraction. Attribute order varies between presets (`name radius x y` and `name x y radius` both ship), so it is not significant.

### Coordinate convention

Not documented in any file; this is read off consistent sign/name correlation across all 63 presets.

| | Meaning | Evidence |
|---|---|---|
| `+x` | leader's right | `nextToLeader`: `left x="-1.2"` / `right x="1.2"` (`:20-23`) |
| `+y` | **behind** the leader | `followNPC` is four trailing ranks at y = 1.7/3.5/5.2/6.9 (`:58-67`); `mucirna_..._rideToSemin` labels ranks `row1`…`row7` at monotonically increasing y (`:157-172`) |
| `-y` | in front of the leader | `returnStartledHorse` is one spot at `y="-3.0"` (`:602-604`), and the NPC who takes it walks out ahead of the horse to intercept it |
| units | metres | inferred from magnitudes: 1.2–1.5 m infantry rank spacing, 2.5–3.5 m for riders |

**The leader sits at the origin and never gets a `<Spot>`.** Inferred, but from two independent signals: only one spot in the entire file is at (0,0), and presets whose name encodes a headcount list N−1 spots (`cavalryRiders6` → 5, `infantryMen20` → 19, `block6wide` → 5). The rule is a convention, not enforced — `rutinaAVypad_halberdPatrol_16` lists 16.

`radius` is never explained in any file read. Inferred as the arrival/jitter tolerance around the ideal point; correlational support only (loose mounted presets use 1–3, tight indoor queues 0.3). Its only nearby engine surface is `FormationInSpotsGate PercentageThreshold`, and even there the semantics are unstated.

### Spot names are labels, not geometry

`<Spot name>` is free-form and **deliberately non-unique** — `followNPC` has four spots called `left` and four called `right`, `infantryMen20` names all 19 `front`. A name is therefore a *class* of slot that `PreferredPositions` selects into, and the engine picks a free member of the class.

Names also lie routinely: `bailiffAndScribe_walkAround`'s spot is named `left` but sits at `x="1"` (`:53-55`), and `rutinaAVypad_trackview_mountedPatrol` names four spots `front`/`backright`/`backleft`/`2backright` while all four have `x="1"` (`:325-329`). Do not infer layout from names.

The useful counter-pattern: name spots after the NPCs that will fill them. `prepadeni_ptaceksGroup` (`:238-244`) names its spots `prepadeni_horseKonrad`, `prepadeni_horseMikulas`, …; `mucirna_vypaleniSemina_rideToSemin` does the same for its lead rider, `<Spot name="ptacek" …>` at `:158` before falling back to `row1`…`row7`.

There is a BT that turns that into automatic per-NPC slots — [prepadeni.xml:54](../references/AI/quests/prepadeni/prepadeni.xml), tree `npc_formationFollower`:

```xml
<Expression expressions="$t_followFormationParams.formation.leader = $leader &#10;$t_followFormationParams.formation.preferedPosition = $this.name" />
```

but do not read it as the shipped system, for three reasons. The tree declares an In parameter `preferedPosition` (`:49`) and then never reads it — line 54 overwrites the concept. It is registered `InitialState="Disabled"` ([SmartEntity__prepadeni.xml:9-10](../references/Libs/Tables/ai/smartEntity/SmartEntity__prepadeni.xml)) and no shipped quest markup enables it. And the actual consumer of `prepadeni_ptaceksGroup` is `moveinformation_simple` with explicit `preferedpositions` string constants (`formace.xml:34, :52, :70, :88`, path below). So `preferedPosition = $this.name` is a real and cheap idea, but an **unexercised code path** — treat it as untested.

### Notable presets

| Name | Line | Spots | Shape |
|---|---|---|---|
| `followNPC` | 58 | 8 | Two files ±0.7 m, ranks every 1.7 m. The BT-side fallback when `formation.type` is empty. |
| `block6wide` | 12 | 5 | 1.2 m box. Default value of the Skald `formationname` port ([moveinformation_simple.xml:27](../references/Quests/Final/Barbora/utils/move/moveinformation_simple.xml)) — designer default only, **not** an engine-wide default, and the one shipped caller overrides it. |
| `nextToLeader` | 20 | 2 | One either side, level with the leader. |
| `longLine` | 46 | 4 | Single file, radius 1.5. Gaps are 0.9 / 1 / 1 — the first spot sits at `y="0.1"`, not 0 (`:47-48`). |
| `guard_pairs` | 475 | 1 | `x=1.5 y=1.2`. Used by `so_guardPair`. |
| `followCart` | 591 | 8 | `followNPC` shifted 2.7 m back, with 8 **uniquely named** spots (`leftClosest`…`rightFurthest`) — the preset designed for `PreferredPositions` targeting. |
| `dogCompanion_followHeel` / `_horse` | 4 / 8 | 1 | Heel at the left hip; the mounted variant is pushed 3 m back with `radius="3"`, the largest in the file. |
| `battleFormation_basic25` | 413 | 24 | Regular 5×5 grid at 1.5 m pitch, front two ranks `front`, rest `back`. |
| `cavalryRiders6` | 558 | 5 | See below. |
| `infantryMen20` | 566 | 19 | See below. |
| `prototypeFollowPlayer` | 69 | 8 | **Dead data.** Four positions duplicated verbatim; referenced by nothing in `AI/`, `Quests/` or `Scripts/`. |

The two military presets, verbatim:

```xml
    <!-- army movement in cutscene -->
    <Formation name="cavalryRiders6">
        <Spot name="front" radius="0.5" x="2.5" y="0.0" />
        <Spot name="front" radius="0.5" x="-2" y="0.0" />
        <Spot name="front" radius="0.5" x="0.5" y="2.5" />
        <Spot name="front" radius="0.5" x="2.5" y="2.5" />
        <Spot name="front" radius="0.5" x="-3.5" y="3" />
    </Formation>
```
([FormationDefinitions.xml:557-564](../references/AI/FormationDefinitions.xml)). Note every spot keeps `radius="0.5"` — half a metre of tolerance for a horse, with two spots only 2 m apart in x at the same y. Compare `dogCompanion_followHeel_horse`, which widens to 3 for exactly this reason.

```xml
    <Formation name="infantryMen20">
        <Spot name="front" radius="0.5" x="-3" y="0.5" />
        <Spot name="front" radius="0.5" x="-1.5" y="0.5" />
        <Spot name="front" radius="0.5" x="1.5" y="0.0" />
        <Spot name="front" radius="0.5" x="3" y="0.5" />

        <Spot name="front" radius="0.5" x="-3" y="2" />
        <Spot name="front" radius="0.5" x="-1.5" y="1.5" />
        <Spot name="front" radius="0.5" x="0.5" y="1.5" />
        <Spot name="front" radius="0.5" x="1" y="2" />
        <Spot name="front" radius="0.5" x="2.5" y="2" />

        <Spot name="front" radius="0.5" x="-3.5" y="4" />
        <Spot name="front" radius="0.5" x="-1.5" y="3" />
        <Spot name="front" radius="0.5" x="0.5" y="3" />
        <Spot name="front" radius="0.5" x="1" y="3.5" />
        <Spot name="front" radius="0.5" x="3" y="3.5" />

        <Spot name="front" radius="0.5" x="-3" y="6" />
        <Spot name="front" radius="0.5" x="-1.5" y="5" />
        <Spot name="front" radius="0.5" x="0.5" y="5" />
        <Spot name="front" radius="0.5" x="1" y="5" />
        <Spot name="front" radius="0.5" x="3.5" y="5.5" />
    </Formation>
```
([FormationDefinitions.xml:566-589](../references/AI/FormationDefinitions.xml)) — four ranks of 4–5, deliberately jittered so it reads as a body of men rather than a grid. The blank lines are the author's rank separators.

## The node contract

Six formation nodes **appear** in shipped vanilla XML; only five of them ever execute. (The engine registers more than six. [`WHGame_release_1_5.dll`](../references/kcd2-mod-docs-main/DLL/WHGame_release_1_5.dll) carries MSVC RTTI type descriptors for `C_AnchorFormation`, `C_TeleportFormationToSpots`, `C_GetFormationLeader`, `C_GetFormationParticipants` and `C_FormationSize`, none of which appears in any XML. Each appears four times — as `C_NodeFactoryImpl<…>`, `C_NodeFactoryImplBase<…>`, `C_NodeWrapper<…>` and the class itself, which is the standard BT-node registration quartet — so they are fully registered nodes, not vestigial symbols. Absence from the data is not absence from the build.)

### Live nodes vs editor scratch

Every `<BehaviorTree>` has three sibling blocks: `<Root>` (executed), `<ForestContainer>` (the editor's *disconnected* canvas nodes) and `<EditorData>` (a per-node metadata mirror). **A formation node inside `<ForestContainer>` never runs**, and vanilla contains six of them — so raw grep counts overstate the live system. Every count elsewhere in this doc is a **live** count unless it says otherwise:

| Node | Occurrences under `references/AI` | Live |
|---|---|---|
| `MakeFormation` | 32 | 31 |
| `FormationFollower` | 26 | 25 |
| `GetMemberFormation` | 20 | 19 |
| `EndFormation` | 28 | 27 |
| `ChangeFormation` | 3 | 2 |
| `FormationInSpotsGate` | 1 | **0** |

The dead six: [battlegroupcontroller.xml:675-676](../references/AI/battles/battlegroupcontroller.xml) (the `FormationInSpotsGate` *and* the `EndFormation` nested inside it — it is the only non-leaf formation node, and its child dies with it), [menhart.xml:429](../references/AI/quests/sermiri/menhart.xml) (`ChangeFormation`), and [utokNaNebakov.xml:4120-4121, :4396](../references/AI/quests/utokNaNebakov/utokNaNebakov.xml). `utokNaNebakov` is worth naming because it is the *only* place `PreferredPositions="$data"` appears and it is triply dead: it sits after `</Root>`, `$data` is not a declared variable or parameter of the enclosing tree (its params are `string` and `wuid`, `:4043-4044`), and the formation its leader half would build, `utokNaNebakov_aroundZizka`, does not exist in `FormationDefinitions.xml`. Do not cite it as a pattern.

All four core nodes are leaves and their attribute sets are invariant across every instance under `references/AI`:

```xml
<MakeFormation       FormationName="'guard_pairs'" HandleVariable="$formationWUID" />
<GetMemberFormation  MemberWUID="$leader" FormationHandleOut="$formation" />
<FormationFollower   FormationHandle="$formation" PreferredPositions="" FormationMode="MoveHistory" AllowRelocation="false" />
<EndFormation        FormationHandle="$formationWUID" />
```
(single quotes shown unescaped; in the files they are `&apos;`)

| Node | Attributes | Notes |
|---|---|---|
| `MakeFormation` | `FormationName`, `HandleVariable` | **No anchor/position/target argument exists.** The anchor is whichever entity's tree executed the node. |
| `GetMemberFormation` | `MemberWUID`, `FormationHandleOut` | Pure lookup: any *member* WUID → the handle. The creator is itself a member, so `GetMemberFormation(leader)` is the standard handoff. |
| `FormationFollower` | `FormationHandle`, `PreferredPositions`, `FormationMode`, `AllowRelocation` | Long-running: **this node is the locomotion**. Followers need no `Move` node at all. |
| `EndFormation` | `FormationHandle` | Only ever called by the creator, always from a cleanup branch. There is no `LeaveFormation` — a follower leaves by exiting `FormationFollower`. |
| `ChangeFormation` | `NewName`, `Formation` | Re-shapes a live handle. Note the attribute is `Formation`, not `FormationHandle`. 2 live uses; see below. |
| `FormationInSpotsGate` | `Formation`, `PercentageThreshold`, `WaitingTimeout`, `FailOnTimeout`, `RunLogic` | The only non-leaf, and **never used live** — its single occurrence is editor scratch. |

That every attribute is *mandatory* is inference — no vanilla author omitted one across ~106 hand-authored nodes, but nothing establishes parser behaviour.

**One documented exception to "the handle is always a declared `_wuid` local".** 31 of 32 `MakeFormation` sites (and 27 of 28 `EndFormation`) write a declared local — `$formationWUID` ×15, `$formation` ×15, `$formationHandle` ×1. The odd one out is [interrupt_animal_returnFromStartle.xml:24](../references/AI/animal/basic/switch/interrupt_animal_returnFromStartle.xml), which writes `HandleVariable="$this.id"` and reads it back at `:35` as `EndFormation FormationHandle="$this.id"`. `$this.id` is a read-only engine builtin (it is not declared in that file's `<Variables>`, and across all of `references/AI` it appears only ever as an *input* — never once on the left of an assignment). Read it as a designer bug, not an idiom: the same tree also declares two variables it never uses. It is benign only because `EndFormation` there is on the abort path and formations die with their creating behaviour anyway. **Always declare a `_wuid` local.**

### ChangeFormation: re-shaping without invalidating handles

`EndFormation` + `MakeFormation` mints a new handle and every follower's `FormationHandle` goes stale. `ChangeFormation` is the only way to change shape in place. Both live uses are byte-identical poll-and-diff watchers ([tour_movementinformation.xml:56-63](../references/AI/speech/tour_movementinformation.xml), same at [moveinformation_tagpointroute.xml:83-90](../references/AI/move/moveinformation_tagpointroute.xml)):

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

Three requirements, all structural: `$formationName` is a `requirementType="ConstReference"` parameter (`:21`) so the quest can rewrite it mid-run; `$currentFormation` is a local snapshot seeded in `Init` right after `MakeFormation` (`:47`); and the `While` must be a `Parallel` **sibling** of the leader's movement with `RunLogic="KeepRunning"`, or the followers get torn down on each change.

### FormationMode

Four values, with engine ordinals read straight out of the Lua state dump:

```
 enum_formationMode = {          enum_formationType = {
	 KeepDistance=1                  KeepDistance=1
	 KeepShape=3                     KeepShape=3
	 MoveHistory=2                   MoveHistory=2
	 Relaxed=0                       Relaxed=0
 }                               }
```
([LuaState_Sorted.txt:27055-27066](../references/kcd2-mod-docs-main/lua_dump_state/LuaState_Sorted.txt))

| Value | Ordinal | Where vanilla uses it |
|---|---|---|
| `Relaxed` | 0 | 2× — the `formationData` default; loose escort |
| `KeepDistance` | 1 | 1× — carts ([carts.xml:2487](../references/AI/carts/carts.xml)). A second literal exists at `utokNaNebakov.xml:4121` but is one of the dead six. |
| `MoveHistory` | 2 | 14× — the dominant mode. Followers replay the leader's recorded path, which is what keeps a column on a road. All marching/mounted escorts use it. |
| `KeepShape` | 3 | 6× — rigid geometry: guard pairs, parade blocks, battle lines |

What each actually does at runtime is **not documented anywhere**; the table above is usage-derived.

**Two syntaxes, both accepted.** 22 live literal call sites write the bare token (`FormationMode="MoveHistory"`); one writes the fully-qualified form, [vezniNaTroskach.xml:677](../references/AI/quests/vezniNaTroskach/vezniNaTroskach.xml) `FormationMode="$enum:formationMode.MoveHistory"`. Both forms appear in that same file for the same value (`:677` vs `:2283`, `:2393`), so the attribute takes either. Struct-driven sites pass `$…formation.policy`, whose declared type *is* `enum:formationMode`.

The designer-facing mirror enum is a genuinely separate registration:

```xml
<Enum name="formationType" ExportToConcept="true">
    <Value Name="Relaxed" />
    <Value Name="KeepDistance" />
    <Value Name="MoveHistory" />
    <Value Name="KeepShape" />
</Enum>
```
([ai_enums.xml:1269-1274](../references/Libs/Tables/ai/ai_enums.xml)). `formationMode` is not in any table — it is engine-side; `formationType` is what Skald ports expose. Every vanilla caller bridges them with a copy-pasted `Switch` (canonical copy at [moveInFormation_simple.xml:26-39](../references/AI/move/moveInFormation_simple.xml), repeated verbatim in `zoufalaObranaZaBohutuBattlePart.xml:2367-2380`, `zbranepanasemina.xml:2366-2377`, `so_test_dialog.xml:2961-2972`).

Since the ordinals are identical, that `Switch` is an **identity re-mapping** — its only real effect is its fallback, and the fallback is a trap. It is three `<IfCondition>` branches (`KeepDistance`, `MoveHistory`, `KeepShape`) plus a `<DefaultBranch>` at `:36-38`:

```xml
<DefaultBranch>
  <Expression expressions="$followFormationParams.formation.policy = $enum:formationMode.Relaxed" />
</DefaultBranch>
```

`Relaxed` is never tested for explicitly, so **any unrecognised `formationType` — including a typo in a Skald `ConstantPort Value` — silently becomes `Relaxed`**, with no failure and no log.

(Naming trap: [`AI/move/moveInFormation_simple.xml`](../references/AI/move/moveInFormation_simple.xml) is the behaviour tree; [`Quests/Final/Barbora/utils/move/moveinformation_simple.xml`](../references/Quests/Final/Barbora/utils/move/moveinformation_simple.xml) is the Skald module that calls it. Different files, near-identical names.)

**Trap:** `AllowRelocation` is a plain bool and has nothing to do with the engine's separate `enum_relocationPolicy`, which also contains a `KeepDistance` token at a different ordinal. What it enables is undocumented, and it is `false` at 22 of the 24 literal call sites (raw total, including the dead one). The two `true`s are as far apart as they could be — an idle "wait for orders" standing formation with no `PreferredPositions` ([mucirna_vypaleniSemina.xml:2657](../references/AI/quests/mucirna_vypaleniSemina/mucirna_vypaleniSemina.xml)) and an actively fighting line ([battlegroupcontroller.xml:1767](../references/AI/battles/battlegroupcontroller.xml)) — but both are `KeepShape`. Best reading, inference: it lets a follower give up its slot and take another when the shape shifts under it.

### The params struct

```xml
<Type Name="formationData">
    <Member Name="leader" Type="wuid" />
    <Member Name="type" Type="string" />
    <Member Name="preferedPosition" Type="string" />
    <Member Name="policy" Type="enum:formationMode" InitialValue="$enum:formationMode.Relaxed" />
    <Member Name="speedLimit" Type="enum:movementSpeed" InitialValue="$enum:movementSpeed.dash" />
    <Member Name="allowRelocation" Type="bool" InitialValue="false" />
</Type>

<Type Name="followFormationParams">
    <Member Name="formation" Type="formationData" />
</Type>
```
([ai_types.xml:2372-2384](../references/Libs/Tables/ai/ai_types.xml)). Both misspellings are load-bearing: the struct member is `preferedPosition` (one `r`, singular), the node attribute is `PreferredPositions` (two `r`s, plural). `speedLimit` is consumed **only** as the leader's `Move speed` — `FormationFollower` has no speed attribute, and follower pace is engine-driven.

`PreferredPositions` is plural but no vanilla call site ever passes more than one name. Whether a list is accepted is unverified.

#### Where `PreferredPositions` gets its value

Histogram over all live `FormationFollower` in `references/AI`: `""` ×14, `$position` ×3, `$formationPreferredPosition` ×3, `$followFormationParams.formation.preferedPosition` ×1, `$t_followFormationParams.…` ×1, `'npc'` ×1, `'leftClosest'` ×1, `'firstLine'` ×1.

| Source | Mechanism | Example |
|---|---|---|
| none | `""` — engine picks any free spot. The majority. | [so_guardPair.xml:71](../references/AI/profession/guard/so_guardPair.xml), [walkaround.xml:324](../references/AI/profession/bailiff/walkaround.xml), [enablebehavior.xml:340](../references/AI/test/_lukas/enablebehavior.xml) |
| literal | inline string naming a `<Spot>` | `'npc'` [interrupt_returnStartledAnimal.xml:315](../references/AI/npc/basic/switch/interrupt_returnStartledAnimal.xml), `'leftClosest'` [prijezdnasuchdol.xml:876](../references/AI/quests/prijezdNaSuchdol/prijezdnasuchdol.xml), `'firstLine'` [battlegroupcontroller.xml:1767](../references/AI/battles/battlegroupcontroller.xml) |
| BT parameter | quest writes a `_string` In param per NPC | `$formationPreferredPosition` at [vezniNaTroskach.xml:595, :677](../references/AI/quests/vezniNaTroskach/vezniNaTroskach.xml), fed one constant per NPC from Skald — `Value="npc2"` at [utek_chodbou_a_chovani_v_usti.xml:64](../references/Quests/Final/Barbora/trosecko/vezniNaTroskach/hibernable/tajna_chodba/utek_chodbou_a_chovani_v_usti.xml), `Value="npc1"` at `:74` |
| struct field | `followFormationParams.formation.preferedPosition` | [moveUtils.xml:2115](../references/AI/move/moveUtils.xml), [questUtils.xml:809](../references/AI/quests/questUtils.xml) |
| NPC's own name | `preferedPosition = $this.name` | [prepadeni.xml:54](../references/AI/quests/prepadeni/prepadeni.xml) — **unexercised**, see above |
| **array indexed by rank** | `FindInArray` the NPC's index in the participant list, then `$preferredPositions[$index]` | [moveinformation_tagpointroute.xml:104-106](../references/AI/move/moveinformation_tagpointroute.xml), [utokNaMalesov.xml:2967](../references/AI/quests/utokNaMalesov/utokNaMalesov.xml) |
| link `Data` payload | `<LinkTagFilter tag="'test_string'" … Data="$position" />` on the NPC | [battlegroupcontroller.xml:3781-3782, :4229](../references/AI/battles/battlegroupcontroller.xml), [zoufalaObranaZaBohutuBattlePart.xml:2363-2366](../references/AI/quests/zoufalaObranaZaBohutu/zoufalaObranaZaBohutuBattlePart.xml) — **needs level data, unusable for this mod** |
| per-soul override | `IfCondition "$followableSoul == $this.id & $followableSoulPreferredPosition ~= 'none'"` inside a shared tour tree; `'none'` is the unset sentinel | [tour_movementinformation.xml:77-78](../references/AI/speech/tour_movementinformation.xml) |

The array-indexed row is the only vanilla mechanism that scales to N followers without level data or per-NPC quest constants, which makes it the one directly applicable to a squad:

```xml
<FindInArray array="$movingNPCs" keyOut="$index" condition="$__value == $this.id" />
<IfCondition failOnCondition="false" condition="$index &lt; #preferredPositions">
  <Expression expressions="$followFormationParams.formation.preferedPosition = $preferredPositions[$index]" />
</IfCondition>
```

Unverified: what happens on a name miss. [battlegroupcontroller.xml:1767](../references/AI/battles/battlegroupcontroller.xml) asks for `'firstLine'` against `battleFormation_basic25`, whose spots are only `front`/`back` — and it ships. Whether the engine silently falls back to any free spot or the node fails is not stated anywhere; that it ships unnoticed is weak evidence for the silent fallback.

## The canonical recipe

The smallest complete working pair in the game is [so_guardPair.xml](../references/AI/profession/guard/so_guardPair.xml) — two trees, no quest dependencies, no lock.

Leader:
```xml
<Root OneTimeOnly="false" FailState="Recoverable" saveVersion="2">
  <OnInit canSkip="1">
    <MakeFormation FormationName="&apos;guard_pairs&apos;" HandleVariable="$formationWUID" />
  </OnInit>
  <Behavior canSkip="1">
    <FuseBox StatusPropagation="Child" OneCleanup="true" saveVersion="2">
      <Child canSkip="1">
        <Move ... destinationSpecification="$__resource.id" speed="Walk" ... />
      </Child>
      <OnFail canSkip="1">
        <EndFormation FormationHandle="$formationWUID" />
      </OnFail>
    </FuseBox>
  </Behavior>
</Root>
```

Follower:
```xml
<OnInit canSkip="1">
  <GetBehaviorHolders area="$__object.id" behaviors="&apos;master&apos;" targetVar="$behaviorHolders" />
</OnInit>
<Behavior canSkip="1">
  <Sequence>
    <IfCondition failOnCondition="false" condition="#behaviorHolders &gt; 0">
      <GetMemberFormation MemberWUID="$behaviorHolders[0]" FormationHandleOut="$formationWUID" />
    </IfCondition>
    <Selector>
      <IfCondition failOnCondition="true" condition="$formationWUID ~= $__null">
        <FormationFollower FormationHandle="$formationWUID" PreferredPositions="" FormationMode="KeepShape" AllowRelocation="false" />
      </IfCondition>
      <Wait duration="&apos;1s&apos;" timeType="GameTime" doFail="false" variation="" skipInLOD="false" />
    </Selector>
  </Sequence>
</Behavior>
```
([so_guardPair.xml:7-20, 61-76](../references/AI/profession/guard/so_guardPair.xml))

Three things to copy verbatim:

- **`MakeFormation` in `OnInit`, `EndFormation` in a guaranteed-cleanup slot.** Vanilla never places `EndFormation` as a bare sibling — it is always `FuseBox/OnFail`, `FuseBox/OnSuccess`, or `SubtreeDecorator/Cleanup`.
- **The `Selector` + `Wait '1s'` retry.** This is the synchronisation gate in its cheapest form: if the leader hasn't created the formation yet, `$formationWUID` is null, the guard fails, the follower naps a second and the `Behavior` re-enters. Self-healing, no shared state.
- **`GetBehaviorHolders`** to discover the leader — "who on this smart object is running behaviour `master`" — instead of wiring a leader WUID in.

Two cheaper shapes worth knowing:

- The **absolute minimum follower** is three nodes, no lock and no gate at all — [enablebehavior.xml:336-341](../references/AI/test/_lukas/enablebehavior.xml): `WaitAction` → `GetMemberFormation MemberWUID="$bures"` → `FormationFollower`. Its leaders (`bures` `:187`, `buresAdvance` `:429`) hand it between "follow" and "do the job" purely by distance, with a `ContinuousSwitch` of two mirrored `DistanceCondition`s toggling `SetBehaviorState behaviors="'gorillaFollow'" state="Enabled"/"Disabled"` (`:210-226`).
- The **cheapest role split** is one shared tree with a single `_wuid` In parameter and `IfElseCondition condition="$this.id == $data"` ([mucirna_vypaleniSemina.xml:2633](../references/AI/quests/mucirna_vypaleniSemina/mucirna_vypaleniSemina.xml)) — no `AddLink`, no `LinkGate`, no `Concatenation`, no per-leader lock name. Its cost is that its lock is the bare literal `'formationCreated'` (`:2642`, `:2654`), global across all instances, so two concurrent mucirna formations would share one gate.

### Lifecycle: `SubtreeDecorator` beats `FuseBox`

`FuseBox/OnSuccess` releases the handle only on success; `FuseBox/OnFail` only on failure. `SubtreeDecorator` `Init`/`Subtree`/`Cleanup` releases on **any** exit, including interrupt — which is what you want when a scheduler can yank the behaviour at any moment. Canonical copy, [vezniNaTroskach.xml:639-655](../references/AI/quests/vezniNaTroskach/vezniNaTroskach.xml):

```xml
<SubtreeDecorator saveVersion="2">
  <Init canSkip="1">
    <MakeFormation FormationName="&apos;vezniNaTroskach_fleeThroughPassage&apos;" HandleVariable="$formationWUID" />
  </Init>
  <Subtree canSkip="1">
    <Sequence>
      <SetExternalLock LockManagerType="Local" Locked="false" LockName="&apos;$formationLock&apos;" />
      <Move ... destinationSpecification="$predefinedPath" speed="Walk" ... />
    </Sequence>
  </Subtree>
  <Cleanup canSkip="1">
    <Sequence>
      <EndFormation FormationHandle="$formationWUID" />
      <SetExternalLock LockManagerType="Global" Locked="true" LockName="&apos;$formationLock&apos;" />
    </Sequence>
  </Cleanup>
</SubtreeDecorator>
```

**Do not copy the lock lines — that block ships a bug.** The leader opens `LockManagerType="Local"` (`:645`) but `Cleanup` closes `LockManagerType="Global"` (`:652`), while the follower waits on `Local` (`:673`). The `Local` lock is opened once and never re-armed, and a `Global` lock of that name was never opened in the first place. Same defect a second time in the same file at `:2131` (`Local`/open) vs `:2139` (`Global`/close) against followers at `:2279` and `:2389`. It fails *open* — a re-run of the behaviour simply skips the "wait for the leader" phase — which is why it shipped. The correct pairing is in the same file at `:1090` / `:1105` (`Global`/`Global`), matching what [moveUtils.xml:2111](../references/AI/move/moveUtils.xml) waits on (`ExternalLock … LockManagerType="Global" SemaphoreName="'$formationLock'" RunLogic="KeepRunning"`).

Also non-obvious and load-bearing here: `LockName="'$formationLock'"` is **not** a literal dollar-sign string. Single-quoted string literals interpolate variables — that is the whole basis of the `followNPC_leader_<wuid>` naming convention ([vezniNaTroskach.xml:1089](../references/AI/quests/vezniNaTroskach/vezniNaTroskach.xml) `Concatenation … Pattern="'followNPC_leader_$this.id'"`).

### The synchronisation gate, heavier variants

The race is always the same: a follower must not call `GetMemberFormation` before the leader ran `MakeFormation`. Vanilla solves it six ways, all interchangeable.

| Mechanism | Shape | Example |
|---|---|---|
| Retry loop | `Selector` + `Wait '1s'`, or `While` + null check | `so_guardPair`, [carts.xml:2480-2492](../references/AI/carts/carts.xml) |
| Named lock | leader `SetExternalLock Locked="false"` right after `MakeFormation`; follower wraps its lookup in `ExternalLock` on the same name | `erik_armyMovement` (`Local`, `'formationReadyToJoin'`), `followNPC_slave` (`Global`) |
| **Per-instance named lock** | root lock name templated on the anchor's WUID by the *initiator*, shipped to the other half in a message; derived sub-locks by string suffix | the startle pair, below |
| Message push | leader `InstantMultiSendMessageToNPC ... variable="$formation"`; follower `ReadMessage ... inbox="'battle_formationSetup'"` | `battlegroupcontroller`, `finale`, `menhart` |
| `Synchronize` | N-count semaphore so everyone starts the same tick | `finale`, `menhart` |
| **Everyone-present link gate** | each member `AddLink` to the leader; leader waits on `LinkGate … amount="All" presence="Present"` before proceeding | [vezniNaTroskach.xml:635, :658](../references/AI/quests/vezniNaTroskach/vezniNaTroskach.xml) |

The link gate is a rendezvous rather than a handle race — the leader has already made the formation and is waiting for the *bodies*. The tighter of its two forms self-keys, so leader identity and gate key cannot drift ([vezniNaTroskach.xml:2123, :2145](../references/AI/quests/vezniNaTroskach/vezniNaTroskach.xml)): `AddLink From="$this.id" To="$this.id" Tag="$formationName"` and `LinkGate from="$npcs" to="$this.id" tag="$formationName" amount="All" presence="Present"` — the formation *name* doubles as the link tag. The looser form at `:635`/`:658` links `To="$formationLeader"` but gates on `to="$npcs[0]"`, which only agrees if the quest happens to pass `formationLeader == npcs[0]`.

The lock variant is worth quoting because it is what the shipped generic follower expects:

```xml
<OnInit canSkip="1">
  <Concatenation OutString="$formationLock" Pattern="&apos;followNPC_leader_$t_followFormationParams.formation.leader&apos;" />
</OnInit>
<Behavior canSkip="1">
  <ExternalLock atomic="false" OutsideQueuePosVariable="" InsidePosVariable="" TimerType="GameTime" OutsideTimerValue="&apos;10m&apos;" LockManagerType="Global" SemaphoreName="&apos;$formationLock&apos;" RunLogic="KeepRunning">
    <Sequence>
      <GetMemberFormation MemberWUID="$t_followFormationParams.formation.leader" FormationHandleOut="$formationWUID" />
      <IfCondition failOnCondition="true" condition="$formationWUID~=$__null">
        <FormationFollower FormationHandle="$formationWUID" PreferredPositions="$t_followFormationParams.formation.preferedPosition" FormationMode="$t_followFormationParams.formation.policy" AllowRelocation="$t_followFormationParams.formation.allowRelocation" />
      </IfCondition>
    </Sequence>
  </ExternalLock>
</Behavior>
```
([questUtils.xml:801-813](../references/AI/quests/questUtils.xml))

The lock name `'followNPC_leader_<leaderWuid>'` is hard-coded in **both** shipped slave implementations ([questUtils.xml:802](../references/AI/quests/questUtils.xml), [moveUtils.xml:2108](../references/AI/move/moveUtils.xml)) — the two systems share one lock namespace. If you reuse `Function_moveInFormation_slave` rather than writing your own follower, your leader tree must create and release exactly that name.

Note that the null guard is a convention, not a requirement: [erik_armyMovement.xml:60-61](../references/AI/quests/erik/erik_armyMovement.xml) and [moveUtils.xml:370-371](../references/AI/move/moveUtils.xml) both feed the handle straight into `FormationFollower` with no `$__null` test.

### The ambient startle pair: a formation with no quest and no level data

Every other formation in the game is created by a quest tree, a battle controller, a cart, a smart-object profession pair or a `moveUtils` helper called from one of those. **One is not.** A horse gets startled, a passing NPC notices, and the two negotiate a formation entirely at runtime through messages, globally-named locks and graph links — no quest, no `EnableBehavior`, no smart object, no level-baked link. That is structurally the mod's problem, so it gets treated in full.

The leader half is the animal, [interrupt_animal_returnFromStartle.xml:23-30](../references/AI/animal/basic/switch/interrupt_animal_returnFromStartle.xml), and it is the entire recipe in five nodes:

```xml
<Sequence>
	<MakeFormation FormationName="&apos;returnStartledHorse&apos;" HandleVariable="$this.id" />
	<SetExternalLock LockManagerType="Global" Locked="false" LockName="&apos;$returnFromStartleData.formationLock&apos;" />
	<Concatenation OutString="$sweetSpotLock" Pattern="&apos;$returnFromStartleData.formationLock;_sweetSpot&apos;" />
	<ExternalLock atomic="false" ... TimerType="GameTime" OutsideTimerValue="&apos;10s&apos;" LockManagerType="Global" SemaphoreName="&apos;$sweetSpotLock&apos;" RunLogic="KeepRunning">
		<Move ... destinationSpecification="$returnFromStartleData.positionToReturnTo" speed="Walk" ... />
	</ExternalLock>
</Sequence>
```

Read it as a two-way handshake:

1. `MakeFormation`. (`HandleVariable="$this.id"` is the bug documented above — ignore it.)
2. `SetExternalLock … Locked="false"` **opens** a gate the NPC pre-closed before it sent its request. That unlock *is* the "formation exists now" signal; there is no formation-ready event.
3. `Concatenation` derives a second lock name from the first by suffix. `$x;_suffix` — the semicolon terminates variable interpolation inside a `Pattern`. The NPC computes the identical string independently at [interrupt_returnStartledAnimal.xml:302](../references/AI/npc/basic/switch/interrupt_returnStartledAnimal.xml); the two halves agree by **naming convention**, not shared state.
4. The animal then blocks on that second lock, so **the horse does not start walking until the follower reports it is in position**.
5. The `Move` is inside the lock. It is the formation's only locomotion — nobody issues the follower a `Move`.

The follower half, [interrupt_returnStartledAnimal.xml:311-326](../references/AI/npc/basic/switch/interrupt_returnStartledAnimal.xml), looks the handle up **from the leader's WUID** (never receives it directly) and pairs `FormationFollower` with a watcher that opens the sweet-spot lock:

```xml
<GetMemberFormation MemberWUID="$returnStartledAnimalData.animal" FormationHandleOut="$horseFormation" />
<Parallel successMode="Any" failureMode="Any">
	<EntityContextElement context="crime_inHorseReturningFormation" enabled="true">
		<FormationFollower FormationHandle="$horseFormation" PreferredPositions="&apos;npc&apos;" FormationMode="MoveHistory" AllowRelocation="false" />
	</EntityContextElement>
	<EntityContextBarrier context="crime_inHorseReturningFormation" target="" Negation="false" RunLogic="KeepRunning">
		<IsInSweetSpotRange WaitForFollowStart="false" RunLogic="KeepRunning">
			<Sequence>
				<SetExternalLock LockManagerType="Global" Locked="false" LockName="&apos;$sweetSpotLock&apos;" />
				<Wait duration="&apos;-1&apos;" timeType="GameTime" doFail="false" variation="" />
			</Sequence>
		</IsInSweetSpotRange>
	</EntityContextBarrier>
</Parallel>
```

`PreferredPositions="'npc'"` names the sole `<Spot>` of `returnStartledHorse` ([FormationDefinitions.xml:602-604](../references/AI/FormationDefinitions.xml)) at `y="-3.0"` — 3 m *in front*, because this NPC leads the horse home rather than driving it. (The formation branch is the minority path: `:249-263` sends anyone else to ride the horse instead; only NPCs with an oversized weapon, or women, walk it.)

**Two layers you should copy, and they are independent.**

*Instance scoping is done by lock naming.* Every lock here is `LockManagerType="Global"`, i.e. one flat string namespace — two startled horses on a fixed name would deadlock each other. The initiator invents one root name templated on the **anchor's** WUID, ships it in the request, and every derived lock is a pure function of it ([interrupt_returnStartledAnimal.xml:300-307](../references/AI/npc/basic/switch/interrupt_returnStartledAnimal.xml)):

```xml
<Concatenation OutString="$formationLock" Pattern="&apos;returnHorse_$returnStartledAnimalData.animal&apos;" />
<Concatenation OutString="$sweetSpotLock" Pattern="&apos;$formationLock;_sweetSpot&apos;" />
<SetExternalLock LockManagerType="Global" Locked="true" LockName="&apos;$formationLock&apos;" />
<SetExternalLock LockManagerType="Global" Locked="true" LockName="&apos;$sweetSpotLock&apos;" />
<Expression expressions="$return_request.requester = $this.id &#10;$return_request.position = $returnPosition &#10;$return_request.formationLock = $formationLock" />
<InstantSendMessageToNPC target="$returnStartledAnimalData.animal" variable="$return_request" />
```

Any number of encounters run concurrently with no registry, no ids and no Lua. The same encounter reuses the trick three more times (`startleState_running_<animal>`, `startleState_onSpot_<animal>` at `:46-47`, `horseWaitLock_<animal>` at `:125`), and the keying entity is **always the shared subject** — the animal — never the reacting NPC, because several NPCs could react to one horse. Note also that `InstantSendMessageToNPC` carries no inbox attribute: routing is by struct type name (`crime:animal_returnFromStartleRequest` → inbox `'crime_animal_returnFromStartleRequest'`, colon becomes underscore). Inference, but strongly supported by both ends.

*Exclusivity is done separately, with an auto-inversed graph link.* Lock naming stops collisions; it does not stop two NPCs both responding. That is [`crime_returnStartledAnimalReserved`](../references/AI/LinkTagDefinitions.xml) (`:8-9`, declared with `autoInverse` + `removeOnRevive`), claimed before dispatch and released on abort:

```xml
<Selector>
	<GraphSearch Origin="$animal" depth="1" SubGraph="&apos;crime_returnStartledAnimalReserved_reverse&apos;" failOnEmpty="true">
		<LinkTagFilter tag="&apos;crime_returnStartledAnimalReserved_reverse&apos;" prune="true" ... />
	</GraphSearch>
	<Expression expressions="$freeReservation = true" />
</Selector>
```
([callInterrupt_returnStartledAnimal.xml:31-42](../references/AI/npc/basic/switch/callInterrupt_returnStartledAnimal.xml)) — the `Selector` sets the flag only when the search **fails**, then `AddLink` claims the anchor.

One more general rule falls out of this pair: **`EndFormation` is optional.** The animal calls it only on the `FuseBox` `OnFail` path (`:32-37`); the success path just ends. [formationholder.xml:8-12](../references/AI/battles/formationholder.xml) never calls it at all, and [moveUtils.xml:328-330](../references/AI/move/moveUtils.xml) puts it behind an infinite `Wait` where it is unreachable. A formation is owned by the behaviour that created it and dies with it; `EndFormation` is an abort-path nicety. (Inference, but from three independent shipped trees.)

## Quest case studies: cavalry vs infantry

[erik_armyMovement.xml](../references/AI/quests/erik/erik_armyMovement.xml) is the cleanest working army-march system, and its two trees differ only by the horse.

**`cavalry_move`** resolves the rider's horse, mounts, and only then branches:

```xml
<GraphSearch Origin="" ... failOnEmpty="true" ...>
  <LinkTagFilter tag="&apos;horse&apos;" prune="true" negprune="unknown" Parent="" Child="$horse" Data="" />
</GraphSearch>
<StanceElement smartObject="$horse" stance="horse" allowAny="false">
  <Sequence>
    <WaitAction />
```
The whole leader/follower `Selector` lives *inside* `StanceElement`, so the formation only exists while the NPC is mounted. `WaitAction` as the first child inside a stance is the universal idiom — inferred to yield until the mount animation completes, so the `Move` below is issued by an already-mounted rider.

Leader branch, in an order that matters:

```xml
<MakeFormation FormationName="&apos;cavalryRiders6&apos;" HandleVariable="$formation" />
<SetExternalLock LockManagerType="Local" Locked="false" LockName="&apos;formationReadyToJoin&apos;" />
<Move ... destinationSpecification="$moveTarget" ... speed="AlertedWalk" ... />
<InstantCallback_empty EventName="&apos;OnFinished&apos;" />
```
Follower branch:
```xml
<ExternalLock atomic="false" ... OutsideTimerValue="&apos;-1&apos;" LockManagerType="Local" SemaphoreName="&apos;formationReadyToJoin&apos;" RunLogic="KeepRunning">
  <Sequence>
    <GraphSearch Origin="$__object.id" ...><LinkTagFilter tag="&apos;leader&apos;" ... Child="$leader" ... /></GraphSearch>
    <GetMemberFormation MemberWUID="$leader" FormationHandleOut="$formation" />
    <FormationFollower FormationHandle="$formation" PreferredPositions="" FormationMode="MoveHistory" AllowRelocation="false" />
  </Sequence>
</ExternalLock>
```
([erik_armyMovement.xml:50-63](../references/AI/quests/erik/erik_armyMovement.xml))

**`infantry_move`** (`:162-183`) is byte-identical with the horse `GraphSearch` and `StanceElement` removed and `FormationName="'infantryMen20'"`.

**Leader election is a level link, not a parameter.** Every member runs the same tree; the leader branch opens with two `GraphSearch`es, and the second (`tag='endMovement'` on *self*, `failOnEmpty="true"`) succeeds only for the one NPC that owns that link. Everyone else fails and the `Selector` drops them into the follower branch. `LockManagerType="Local"` scopes the semaphore to the smart object, which is why five simultaneous army groups do not cross-signal.

Two scoping rules you must get right, both used deliberately in the same tree: `Origin="$__object.id"` is the group's smart-object holder, `Origin=""` is the executing NPC (the `horse` link only ever exists on NPCs, never on the holder).

What erik *omits*, and you probably want: there is no `EndFormation`, no `FuseBox`, no death handling and no leader re-election in that file (nor in any other — see the battle layer below). Followers never finish on their own — `FormationFollower` runs until the quest disables the behaviour. A follower's death just frees its spot; a leader's death leaves everyone holding a handle whose owner is gone.

### The common idiom

Every on-foot quest formation reduces to the same four parts:

1. A preset with at least as many spots as followers.
2. One `MakeFormation` on the leader entity, held for the whole scene, `EndFormation` in a guaranteed-cleanup slot.
3. A role split **inside one shared behaviour**, using one of exactly four tests: `$followFormationParams.formation.leader == $this.id` (param-driven), `$this.id == $data` (the `wuidData` signature, `mucirna_vypaleniSemina`), `$formationLeader == $this.id` (a declared `_wuid` In param, [vezniNaTroskach.xml:636](../references/AI/quests/vezniNaTroskach/vezniNaTroskach.xml)), or a level-link existence check (erik, finale).
4. One of the six rendezvous primitives above.

Only the **leader** is ever route-driven — followers are always follow-driven, and observed leader destinations are a tagpoint swapped by a Skald state machine, a `PredefinedPathAsset`, a `'next'`-linked tagpoint chain walked in the BT, a live entity (`$__player` in `setkanivratbori2`), or nothing at all (`kralovskeStribro`, where the leader only uses smart objects and the bodyguard trails his movement history).

Files not called out elsewhere that use the same idiom and add nothing new: `zbranepanasemina.xml` (`semin_goingIntoTheRocks`), `zoufalaObranaZaBohutuBattlePart.xml` (`withdrawWeaponRideHorse`), `setkanivratbori2.xml`, `kralovskeStribro.xml`, `finale.xml`, `so_test_dialog.xml` (the dev-test tree `xxxtest_formation`), `utokNaMalesov.xml`, and [walkaround.xml](../references/AI/profession/bailiff/walkaround.xml) — the second quest-free profession pair, notable only for two things: the formation exists **only while the follower has no destination** (`LinkGate … tag="'scribeSpot'" amount="AtLeastOne" presence="NotThere"` wrapping the `MakeFormation`, `:85-96`), and both halves build a per-instance `Synchronize` semaphore name from `$__object.name` at `OnInit` (`:28`, `:295`) instead of using `Concatenation`.

Three files write `followFormationParams` and contain **no formation node at all** — they configure and delegate: [moveInFormation_simple.xml](../references/AI/move/moveInFormation_simple.xml) → `Function_moveInFormation_inFormation`, [tour_formationHorseDesicion.xml](../references/AI/speech/tour_formationHorseDesicion.xml) → `Function_speech_tour_movementInFormation` (3 call sites, `:51`, `:66`, `:71`), [tour_advanced.xml](../references/AI/speech/tour_advanced.xml) → the `speech_tour_*` chain. Plus `prepadeni.xml`, `utokNaMalesov.xml`, `zachranaptacka.xml` and two `test_of_everything` trees. If you grep for formation nodes to find "who does formations", you will miss all of these.

## The battle-system layer

[battlegroupcontroller.xml](../references/AI/battles/battlegroupcontroller.xml) adds five capabilities on top of the three core nodes: runtime leader election (one-shot, see below), push-broadcast of the handle, a tag-agnostic dynamic roster, per-member slot names read from link data, and **fighting inside a formation**.

**Leader election** (tree `move_formation`, [battlegroupcontroller.xml:566-574](../references/AI/battles/battlegroupcontroller.xml)) is a 1-count `Semaphore` wrapping a `Selector`: search self for an existing `'leader'` link, and if that search fails, `AddLink` yourself as leader. First NPC through the semaphore wins.

```xml
<Semaphore SemaphoreCount="1" ... LockManagerType="Local" SemaphoreName="&apos;leaderAssignment&apos;">
	<Selector>
		<GraphSearch Origin="$__object.id" depth="1" ... failOnEmpty="true" ...>
			<LinkTagFilter tag="&apos;leader&apos;" prune="true" negprune="unknown" Parent="" Child="$leader" Data="" />
		</GraphSearch>
		<AddLink From="$__object.id" To="$this.id" Tag="&apos;leader&apos;" Data="" LinkOpHandleMode="Success" />
	</Selector>
</Semaphore>
```

Those eight lines are **copyable verbatim with zero battle dependency** — every node in them is generic, `LockManagerType="Local"` scopes the semaphore to the tree instance rather than to any battle manager, and the only external contracts are `$__object.id` and the string tag `'leader'`. The enclosing tree is battle-coupled and should not be copied wholesale (`:543` `AnyDecorator preset="crime_keepItems"`, a sibling `GameContext context="Battle"` branch at `:551`, and consumers at `:580`/`:611`/`:636`).

But it is a **one-shot latch, not a re-election**: `RemoveLink` for tag `'leader'` has zero hits in the file, so the link is never torn down and a dead leader is never replaced. Whether the `Root OneTimeOnly="false"` (`:541`) restarting the `Behavior` would re-run the election is inference, not readable from the markup.

**Membership**, in the same tree (`:586-593`), is `GraphSearch depth=1` + `SoulIsAliveFilter` with **no** tag filter, collected by `<Nodalyzer Quantifiers="ForAll" … Child="$formationParticipants" />` — so the roster is every living linked entity, recounted each pass. Note that the roster is *not* an argument to `MakeFormation` (`:590` is the usual two-attribute `FormationName="$string" HandleVariable="$formation"`); the controller creates the formation, waits 2s, then pushes the handle to the roster with `<InstantMultiSendMessageToNPC targets="$formationParticipants" … variable="$formation" />` (`:593`). Members join by *receiving* a handle, which is the same contract as `GetMemberFormation` — just push instead of pull.

**Per-member slot names** are a different pair of trees: `move_formation_exactPoint_ladder` (`:3753`) and `move_formation_exactPoint` (`:4207`) read a `test_string` link's `Data` payload with `<LinkTagFilter tag="'test_string'" ... Data="$position" />` at `:3782` and `:4229`. Neither is in `move_formation`, and both need level-baked links.

The one directly stealable piece — formation-following and fighting are not mutually exclusive:

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
  <FormationFollower FormationHandle="$formation" PreferredPositions="&apos;firstLine&apos;" FormationMode="KeepShape" AllowRelocation="true" />
</Parallel>
```
([battlegroupcontroller.xml:1755-1768](../references/AI/battles/battlegroupcontroller.xml)) — `KeepShape` + `AllowRelocation="true"` composed in `Parallel` with the full melee stack is "hold the line while fighting", and it needs no battle infrastructure at all.

### Reachability: CONFIRMED DEAD END for the controller, unnecessary anyway

The battle-group layer as vanilla drives it is **not reachable from a script mod**. Of the 37 `SmartBehaviorTemplate`s in `Libs/Tables/ai/smartEntity/SmartEntity__battleGroupController.xml`, 32 are `InitialState="Disabled"` — including `move_formation`, the one that matters — and the only thing that turns one on is a Skald `EnableBehavior` node. (The 5 that ship Enabled are `wait`, `npc_pushLadder`, `stealthShootingTest`, `interrupt_openVisor`, `interrupt_weaponSetup`; none touches formations.) There is no Lua binding for it, and its `SmartEntity` argument resolves through a level-baked `asset['alias']` link. Same wall as [cutscenes.md](cutscenes.md).

The `formationHolder` half is worse — it was **built and never shipped**:

- Zero `formationHolder` entities exist anywhere in either shipped level's data (checked across the whole level-data trees, not just `objects_mission0.xml`).
- That consumer asks for `PreferredPositions='firstLine'` against the only shape the holder can build (`battleFormation_basic25`, spots `front`/`back` only), which has no such spot.
- The `fightformation` Skald module appears in the quest corpus only as `InstanceType="Static"` namespace declarations (e.g. `Quests/Final/Barbora/utils/battle.xml:36`, plus four under `Quests/Testing/`) — never as a gameplay instance.
- The sole prose reference in the whole game is a designer's Czech TODO — "posilat formationHolder a tagpoint pres skald" — at `Quests/Final/Barbora/kutnohorsko/oblehaniSuchdole/hibernables/prohlidka_hradu/hrac_poznava_svoje_muze/rozkazy/verbovani_muzu.xml:239`.

Do not budget time trying to turn it on. None of this matters, though, because **the three core nodes have no dependency on any of it** — `so_guardPair`, `moveUtils`, `carts`, `erik_armyMovement` and the ambient startle pair all use them outside any battle setup.

One thing *not* to conclude from the above: that an undeclared link tag means "never shipped". [LinkTagDefinitions.xml](../references/AI/LinkTagDefinitions.xml) is not the authoritative registry. `formationHolder`, `formationPosition` and even `'leader'` (the battle election tag) all have **zero hits** in it, yet all three drive shipped behaviour; `formationPosition` is instead declared in `references/level data/waitinglinks.xml:137249` and as a `<Type>` in [ai_types.xml:2361](../references/Libs/Tables/ai/ai_types.xml), and it is used live on a level entity (`objects_mission0.xml:226305`) and read by a BT ([mucirna_vypaleniSemina.xml:2639](../references/AI/quests/mucirna_vypaleniSemina/mucirna_vypaleniSemina.xml)). There are at least three independent link-tag registries. Practical consequence for the mod: **a mod may invent a link tag without declaring it anywhere** — the battle election's `'leader'` proves it works.

## followNpc_inFormation

Two trees differ only in capitalisation and one of them is empty.

- `followNpc_inFormation` (lower-case `p`), [moveUtils.xml:1242](../references/AI/move/moveUtils.xml) — **empty stub**, self-closing `<Root/>`, no `<Behavior>`. Its siblings `followNpc_leader` and `followNpc_slave` are hollowed out the same way, and all three are still uselessly registered in `SmartEntity__test_so_moveUtils.xml`.
- `followNPC_inFormation` (upper-case `NPC`), [questUtils.xml:629](../references/AI/quests/questUtils.xml) — the real implementation.

The live one is a one-line dispatcher (`IfElseCondition` on `formation.leader == $this.id` → `followNPC_leader` / `followNPC_slave`) taking its params from a **forward-declared** thread variable named exactly `t_followFormationParams`, which the calling tree must declare and fill.

The leader is unusual and worth understanding: it **does not move**. It creates the formation, opens the global lock, then delegates all locomotion to a caller-supplied callback (`leaderCallback.host` + `.behavior`, or `.file` + `.tree`). The formation is a pure shape provider. It also picks the fallback preset:

```xml
<IfElseCondition failOnCondition="false" condition="$t_followFormationParams.formation.type==&apos;&apos;" saveVersion="2">
  <Then canSkip="1"><MakeFormation FormationName="&apos;followNPC&apos;" HandleVariable="$formationWUID" /></Then>
  <Else canSkip="1"><MakeFormation FormationName="$t_followFormationParams.formation.type" HandleVariable="$formationWUID" /></Else>
</IfElseCondition>
```
([questUtils.xml:682-688](../references/AI/quests/questUtils.xml)) — this, not `block6wide`, is the actual BT-side default, and it is what the `<!-- default for followNpc_inFormation bahavior-->` comment on `followNPC` refers to (typo theirs).

Caveat before copying: `leaderCallback` is read by the leader tree and written by [prepadeni.xml:13](../references/AI/quests/prepadeni/prepadeni.xml), but `followFormationParams` in `ai_types.xml` declares only a `formation` member. Where the type gains `leaderCallback` could not be located. Resolve that before porting the leader half.

The modern equivalent is `moveInFormation_leader` / `_slave` ([moveUtils.xml:1967, :2098](../references/AI/move/moveUtils.xml)) — same logic as real `is_function="1"` functions with proper `<Parameters>`, and a leader that *does* move.

## Applicability to this mod

### Headline: vanilla formations cannot anchor to the player

`MakeFormation` has no anchor argument, so the anchor is whichever entity's tree executed it. The player never executes it. Two independent checks:

- No formation node **in `references/AI`** takes `$__player` as an attribute value. (Scope that to `AI/` deliberately: the Skald layer *does* route the player into formation trees by asset alias — `formace.xml:86` passes `<Asset Name="npcs" Alias="player" />` into the `moveinformation_simple` wrapper, which reaches `FormationFollower`. It is never `MakeFormation`.)
- The behaviours vanilla enables on the player via `<Asset Name="NPC" Alias="player" />` do not intersect the trees that contain `MakeFormation`. The 31 live `MakeFormation` nodes sit in 30 distinct `<BehaviorTree>`s across 21 files (`questUtils.xml`'s `followNPC_leader` holds two, `:684` and `:687`), entirely under `AI/battles`, `AI/move`, `AI/carts`, `AI/profession`, `AI/quests/*`, `AI/speech`, `AI/test` and the one animal switch tree. The enumeration is the evidence; treat the player-side count as approximate.

Worse, the dispatcher pattern makes a player leader silently do nothing rather than fail loudly. Every member runs the same tree and asks `formation.leader == $this.id`; with the player as leader **no** NPC takes the leader branch, `MakeFormation` never runs, and every follower's `GetMemberFormation` yields null — which the null guard then swallows.

Three corrections to assumptions that are easy to make here:

- **A live NPC is not required — a BT-executing *entity* is.** Vanilla anchors formations on a cart smart object ([carts.xml:73](../references/AI/carts/carts.xml)), a `SmartObjectHolder` ([formationholder.xml:10](../references/AI/battles/formationholder.xml)) and a horse. What they share is a brain running a tree.
- **There is no tagpoint/route/path anchor.** Not expressible — the node takes no anchor. A tagpoint or `PredefinedPath` can only ever be the *leader's* `Move` destination.
- **The player IS a first-class formation follower in shipped vanilla, twice — but only on horseback.** [prijezdnasuchdol.xml:871-879](../references/AI/quests/prijezdNaSuchdol/prijezdnasuchdol.xml) runs `GetMemberFormation` + `FormationFollower(PreferredPositions='leftClosest', Relaxed)` on the player against the cart, and [formace.xml:84-101](../references/Quests/Final/Barbora/trosecko/prepadeni/hibernovana_cast/jizda_s_ptackem/po_ceste/formace.xml) puts the player through the general-purpose `moveinformation_simple` wrapper with `preferedpositions="prepadeni_horseJindrich"` (a real spot, [FormationDefinitions.xml:243](../references/AI/FormationDefinitions.xml), 19 m behind the leader). The player has a real brain (`brain_name="player"`) with a Switching and a Scheduler subbrain, so it runs behaviour trees. **The premise "the player has no behaviour tree" is false** — the true blocker is that both reach the player via a level-baked scheduler link on `playerProxy` plus a quest `EnableBehavior`, neither of which a mod can add.

  The mechanism is worth writing down because it is the whole reason any tree runs on the player: quest `EnableBehavior` ([cart_logic.xml:57-62](../references/Quests/Final/Barbora/kutnohorsko/prijezdNaSuchdol/prijezd/cin_m3110k_prijezdnasuchdol__arrival_suchdol/cart_logic.xml)) + a level-baked link on the `playerProxy` tagpoint whose *name* encodes the schedule — `<Link TargetId="98061" … Name="_60,!Fast,prijezdNaSuchdol_PlayerFollowsWagon" />` (`references/kuttenberg level data/objects_mission0.xml:31920`), grammar `_<priority>,!<urgency>,<behaviorName>` — plus a matching scheduler row (`.../tables/ai/scheduler.xml:575322`). `playerProxy` carries 94 such links in one level and 108 in the other.

**Hard constraint: both shipped cases are a MOUNTED player.** Each `FormationFollower` sits inside `StanceElement stance="horse"` — `prijezdnasuchdol.xml:873` (`smartObject=""`, `allowAny="true"`) and `moveInFormation_simple.xml:43` (`smartObject="$horse"`, `allowAny="false"`). There is **no evidence anywhere that a dismounted player can hold a formation slot.**

What *is* true is that the engine path is not horse-gated. [moveInFormation_simple.xml:41-53](../references/AI/move/moveInFormation_simple.xml) is an `IfElseCondition condition="$horse ~= $__null"` whose `<Else>` calls the same follow function with no `StanceElement` at all, and the `GraphSearch` that fills `$horse` is `failOnEmpty="false"` — so with `usehorseincontext = "None"` the dismounted branch would execute. Shipped data never takes it (`formace.xml`'s caller sets `context = "prepadeni"`, [formation_setup.xml:15](../references/Quests/Final/Barbora/trosecko/prepadeni/prepadeni/formation_setup.xml)). Treat "dismounted player as `FormationFollower`" as **unverified — would need a runtime test**, not as supported.

So: the player can be a *passenger* in someone else's formation, on a horse, and vanilla has no pattern at all for "NPCs form up on the player".

### What shipped

The elected-leader build below is what the mod runs now, on foot and mounted. Lua lives in
[mercenaries_formation.lua](../data/Scripts/mods/mercenaries_formation.lua); the tree half is three blocks in
[follow.xml](../data/AI/follow.xml).

**The formation owner is a branch with no locomotion.** `MakeFormation` in `SubtreeDecorator/Init`,
`EndFormation` in `Cleanup`, and a `Subtree` that does nothing but watch for the rebuild signal. This is
vanilla's own shape — `moveUtils` `formation_lead` and the bailiff `walkaround` are both `MakeFormation` +
`Wait` with the walking in a sibling branch. It matters for a concrete reason: while `MakeFormation` lived
inside the leader's *locomotion* branch, mounting preempted that branch, ran `Cleanup`, and destroyed the
formation — which is why mounted could never hold one.

**Everything is latched.** The leader is kept while he stays eligible; the preset grows immediately but
shrinks only with hysteresis. Every earlier version churned — re-electing each tick, re-resolving the preset
from a live headcount, or gating on a heartbeat — and a rebuild makes every follower re-join into a newly
assigned spot, which reads as the whole squad milling about on the spot. `FormationEpoch` is the one rebuild
signal and nothing bumps it without a reason it prints:

```
[MercForm] rebuild #4 (mounted) preset=merc_mounted14 leader=<wuid>
```

**The follow chain survives as the fallback**, in `mercenaries_formation_handler.lua`. Anything that leaves a
merc without a handle — leader in combat, mid-handoff, startup race, a walled camp where the formation cannot
be steered around the wall — drops him onto `CrimeFollower` instead of leaving him standing.

Three bugs from building this are worth not repeating:

- **`CrimeFollower` never returns.** Running one bare as the follower's fallback meant the `Selector` never
  re-evaluated and nobody ever retried `GetMemberFormation` — one epoch bump stranded the whole squad in
  chain-follow permanently. Every `CrimeFollower` in `follow.xml` is now time-boxed inside a
  `Parallel successMode="Any"` with a `Wait`, except the leader's, whose watchdog is a sibling.
- **Never hardcode a preset name.** The size ladder changed several times; a name carrying a size that is no
  longer generated resolves to nothing, `MakeFormation` returns a null handle, and the squad silently drops to
  the chain — which looks exactly like a column and is indistinguishable from the system being broken.
  `FormationPresetName` derives every name from the live ladder.
- **Never leave `FormationName` nil for a tick.** The per-merc updater runs on its own loop; if it sees nil
  and the leader's branch re-enters in that window, `MakeFormation` gets the fallback rather than the shape
  just chosen. That is why only the first shape command used to work.

| | Vanilla | This mod |
|---|---|---|
| Shape source | authored `<Spot x y radius>` | same, generated by `tools/gen_formations.py` |
| Owner | the entity that ran `MakeFormation` | an elected merc, in a locomotion-free branch |
| Player as anchor | impossible | still impossible — the leader stands in for him |
| Re-targeting | `EndFormation` + `MakeFormation` | epoch bump, logged with a reason |
| Spacing/facing | authored | authored |

### Diagnosing "they don't hold a formation, they just follow me in a blob"

Every path that leaves a merc without a formation slot drops him onto `CrimeFollower`, and a squad on
the chain trailing the player is exactly what "a blob" looks like. Nothing on screen tells the two
apart, so the answer has to come out of the log. Three instruments, in the order you should read them:

**1. `merc_formation_status`** prints `makeFormation=` and `inFormation=n/m`.

`inFormation` is the honest number: it is written from a flag `follow.xml`'s locomotion arms set, so it
counts men who are genuinely *inside* `FormationFollower`, not men we merely asked to be. `n=0` with a
healthy `makeFormation=OK` means the handle resolves but nobody gets a slot — i.e. the formation exists
and is **empty**, which is what an unloaded preset catalogue would produce if `MakeFormation` hands
back a handle for any name. `merc_follow_stats 1` prints the same pair every 2 s alongside the spread.

**2. `[MercForm] formation OFF (<reason>)`** names which squad-wide gate stood the formation down —
`hold order`, `escort order`, `idle`, `dismissed`, `no leader`, `squad under 2` — logged
once per change.

`walled camp` is **no longer one of them**, and that was a real bug rather than a missing log line.
`NavSuppressFormation` decided from the *player's* position against a 60 m radius (75 m to come
back), and switched the **whole squad** together. A camp is nowhere near 60 m across, so sallying out
of a walled camp meant the entire squad marched the first 75 m on the CrimeFollower chain, and a hire
made anywhere in that ring came out on the chain too — the "they revert to crime follower when
sallying out" report. What the suppression is actually for is narrow: a merc who must route *around*
the camp wall cannot be steered there by an engine formation, so he drops to slot following and the
custom navmesh takes him. That is a fact about where **that man** is standing, not where the player
is. `NavSuppressFormationFor(wuid)` now decides it per merc, with per-merc hysteresis (the original
comment's warning about boundary churn is real) off the 50 ms `PerfPos` cache, and it is checked
*after* the squad-wide reasons and outside the `off` chain — it can be true for the man inside the
walls and false for his mate already marching away, so it can never be one shared reason string. A hold order that was never cleared is the single easiest way to be permanently on the
chain: `UpdateFormationRole` returns early on `HoldActive`, and every path that resumes following has
to call `HoldEnd`. `SetState('follow')`, `SetState('dismiss')`, `SetSortieWait(false)`, `BreakMercCamp`,
`RecallMercs` and the load-time reset all do; anything new that resumes following must too.

**3. `[MercForm] MakeFormation <preset> -> OK | NULL HANDLE`.**

**This line used to lie.** It was derived in Lua as `bt_data.formationWUID ~= nil`, and a `_wuid`
never reads back as `nil` across the Lua bridge — the same reason `data.x = nil` cannot clear one — so
it answered `OK` even for a null handle. The verdict now comes from `$formationOk`, computed in
`follow.xml` with a BT comparison against `$__null`, which is the only thing that can see it. Any
older log showing `OK` proves nothing.

On a genuine null the squad is no longer just told about it: after `FormationFallbackMisses`
consecutive nulls it switches itself to `vanilla` and re-makes the formation on a stock preset
(`followNPC` / `infantryMen20`), which is in the catalogue whatever happened to ours. A real formation
in the wrong shape beats no formation at all. Any manual `merc_formation_*` command re-arms our shapes.

**The control test.** `merc_formation_control` runs `MakeFormation` on `merc_control_no_such_formation`
— a name in no catalogue, ours or the game's. If that still logs `OK`, the engine returns a handle for
any name, a null handle is not a usable signal, and the automatic fallback above can never fire; fall
back to eyeballing `merc_formation_vanilla` (if the squad suddenly holds a shape, our whole-file
override of `FormationDefinitions.xml` is not being loaded). If it logs `NULL HANDLE` while the real
preset logs `OK`, the override *is* loaded and the blob is somewhere else — start at instrument 2.

**One membership rule.** `IsFormationEligible` gates the engine formation; `UpdateFormationSlots`
builds the chain that catches everyone it rejects. They must use the *same* test. They did not — the
chain checked only `IsMercInCampProper` while eligibility also excluded camp actors — and a merc who
falls through the gap gets no `FormationSlots` entry at all, so `CalculateFormationTarget` defaults him
to `followTarget = the player` and he walks straight at him. Enough of them and the squad piles onto
the player even with a perfectly healthy formation running.

## This mod's own shapes

[data/AI/FormationDefinitions.xml](../data/AI/FormationDefinitions.xml) is **generated** — do not hand-edit it:

```bash
python tools/gen_formations.py
```

It emits the vanilla catalogue copied verbatim plus 56 `merc_*` presets, and asserts that no vanilla formation
was dropped. **Re-run it after every game update** so it re-copies the current vanilla file.

Seven shapes × eight sizes (6/10/14/18/24/30/40/50). Lua picks the smallest that seats the squad — handing a
50-slot template to six mercs lets the engine drop them in any six of fifty spots and strings them out over
the whole thing.

| Command | Shape | At 14 mercs |
|---|---|---|
| `merc_formation_column` | column of twos | 2.4 m wide, 12.6 m deep |
| `merc_formation_line` | ranks abreast | 14 m wide, 2 m deep |
| `merc_formation_square` | square block | 8 × 6 m |
| `merc_formation_wedge` | filled arrowhead | 9 × 7 m |
| `merc_formation_circle` | ring | nearest merc 1.6 m |
| `merc_formation_escort` | flanking files, middle open | 8 m wide |
| *(automatic)* | `mounted` — triple column at horse spacing | 7 m wide, files 3.5 m, ranks 4 m |

`merc_formation_vanilla` falls back to a stock preset, and doubles as the A/B test for whether the whole-file
override is being loaded at all.

**Nothing is ever placed ahead of the anchor** — the generator asserts it. The player walks at the head with
the leader just behind him, so a spot forward of the leader ends up level with or past the *player*, which
reads as him being swallowed by his own squad. Ranked shapes fold the leader into the front rank; `circle` and
`escort` keep him off-lattice in the gap and slide the shape `LEAD_GAP` behind him. The consequence is that
`circle` is a horseshoe trailing behind rather than a true surround — "player always at front" and "ring
around the player" cannot both hold when the anchor is a merc who follows him.

**Mounted is its own shape and its own mode.** `_G.PlayerMounted` swaps the preset to `merc_mounted*`
(defeating the grow-only latch, since it is a real state change), and the mounted `FormationFollower` uses
`MoveHistory`, not `KeepShape`. No vanilla mounted formation uses `KeepShape`, and rigid geometry is not
something a horse can hold — it corners wide and cannot sidestep. Getting that wrong produced riders who sat
completely still, because `FormationFollower` is their only locomotion.

### The three numbers that stop the squad milling about

| | Value | Why |
|---|---|---|
| `radius` | 0.9 (1.3 loose) | Arrival tolerance. A follower inside it is "in place" and stops correcting. Must stay **strictly under half the pitch** or two neighbours' discs overlap and ranks interleave. Vanilla uses 0.5 only for formations of 5–8. |
| pitch | 2.0 m | Neighbour spacing; must clear an NPC footprint plus pathing slack. |
| standoff | 3.4 m | Gap in front of the first rank before the leader is folded in. Without it the rank behind shoves him, the anchor moves, and every follower chases it. |

One more that is not geometry: the scheduler's stuck-follower self-heal (`mercenary_scheduler.xml`) restarts
any merc more than **35 m** from the player, and that restart drops him out of `FormationFollower`. At 15 m it
fired on eight of nineteen followers in a deep column, each restart leaving them without locomotion so they
drifted further back and re-tripped it — the whole "fine at 10 mercs, bad at 20" cliff. Keep the deepest spot
of any preset well inside that threshold.

### Who anchors it: never an injured man

The anchor is the one merc the whole formation hangs off *and* the one who walks nearest the player,
so he is simultaneously the most visible man in the squad and the one whose death costs the most —
he re-elects, which rebuilds the formation and makes every follower re-join. `UpdateFormationLeader`
therefore elects in **three tiers**, nearest-to-player within each:

1. fit and free;
2. **hurt** (below `InjuredHealthPct`, the same floor as the HUD's injured buff and the camp
   bed-rest bias, so "injured" means one thing across the mod);
3. camp-busy — last, because he physically cannot walk yet, and an anchor that cannot walk stands
   the entire squad.

A **busy incumbent keeps the job** on the same terms as a hurt one. He used not to, and that was
a live bug rather than a nicety: without `leaderStillOk` the "leader no longer eligible" branch
fires every 150 ms tick, and since the busy fallback is *nearest busy man to the player* it picks
a different man as the player moves. Every pick bumps the epoch, and every epoch bump rebuilds the
formation. A squad in that state never settles into slots at all.

A sitting leader who crosses the floor is **demoted, not evicted**: he keeps the job until there is
a fit man to hand it to, and the handover is bounded by the same `FormationLeaderSwapCooldown` as a
displacement swap. That bound is the point — health only falls during a fight, so without it a hard
scrap would demote leader after leader as each one crosses the floor, and every demotion rebuilds
the formation. The immediate, cooldown-free path above it stays reserved for a leader who is *dead
or gone*, which is an emergency rather than a preference.

**The wall rule is sized by the wall, not by a blanket radius.** `NavSuppressFormationFor`
exists for one narrow case: a man who has to route *around* the palisade cannot be steered
there by an engine formation, so he drops to slot following and the custom navmesh takes him.
It was measuring that against `NavActiveRadius` (60 m, release at 75 m) when a palisade of 51
segments encloses a circle of about 22 m — so a party deployed from a walled camp, standing
inside it with the leader and the player who ordered them out, was suppressed to a man and
stayed suppressed for its first 75 m. The whole sortie marched on the follow chain with no
formation at all, which reads exactly like the formation system being broken.

It now measures against `NavWallRadius()` — the furthest wall corner from the camp centre,
cached against the wall tables — plus `NavWallPadding`, and it **exempts anyone on the same
side of the wall as the anchor**, which is the real statement of the rule: there is nothing to
route around when you and the shape you are joining are both inside the same palisade.

**The anchor is never suppressed by the wall rule.** `NavSuppressFormationFor` takes any merc
within `NavActiveRadius` (60 m) of a *walled* camp centre out of the formation until he is 75 m
clear, so the engine formation does not drag him through the palisade. Applied to the leader that
is fatal rather than cautious: `MakeFormation` runs only inside `follow.xml` behind
`$isFormationLeader`, so suppressing the anchor means no formation object exists for **anyone** —
every follower's `GetMemberFormation` comes back null and the whole squad drops to the follow
chain. It bit exactly one case, and bit it every time: a party deployed from a walled camp, where
the leader is elected nearest the player and the player is standing in his own camp when he gives
the order. Followers are still suppressed while they are inside the walls and pick up slots as
they clear them.

The injury test reads `soul:GetState('health')` straight off the entity the loop already holds.
`LogiIsInjured` answers the same question but scans `ActiveMercs` for the key, which at 150 ms over
fifty men is O(squad²) a tick.

### The follow-verification net must not fight a deep formation

`DismountVerify` re-fires follow on a merc who has not moved 1 m since his anchor and is
either behind the player's own drift (5 m) or simply `DismountVerifyFar` (22 m) away and
stationary. That far test is shorter than the formations themselves:

| Preset | Depth | Spots past 22 m |
| --- | --- | --- |
| `merc_column10` | 9.0 m | 0 |
| `merc_column24` | 21.6 m | 0 |
| `merc_column30` | 27.0 m | 5 |
| `merc_column40` | 36.0 m | 15–17 |
| `merc_column50` | 45.0 m | 25–27 |

So the rear half of a *correctly formed* long column is beyond it, and whenever the player
pauses those men are stationary because they are standing exactly where they were told to.
Every 2 s for the whole 25 s window each of them was evicted and re-fired — which costs a man
his slot and makes him re-acquire — so the squad churned instead of settling. Deploying 38 men
into `merc_column40` made it unmissable: the log shows the "not following" count *diverging*,
2 → 5 → 10 → 13 → 16 → **17**, matching the 17 spots at or past the 22 m line.

The far test is now waived for a man holding a formation slot, and only for him: `FormationSlotAt`
is stamped from `follow.xml` on every pass, so a claim newer than `FormationSlotFreshSecs`
(2.5 s) is proof his tree is *running*. A genuinely stalled merc stops stamping, his claim
expires, and the far test catches him again — the flag on its own would have been a blind spot.
The player-drift half is never waived: if the player moves and a man does not, he is stuck
whatever he believes about his slot.

### When re-firing does not work: the escalation

The eviction-and-re-fire above cures a merc whose follow tree **died**. It cannot cure one
whose tree is alive and running an arm that produces no movement — a re-fire restarts that
same tree into that same state. The symptom is unmistakable once you know it: the log fills
with `N merc(s) were not following` for the same man every few seconds and he never takes a
step. Repeating a cure that is not working is not a cure.

So a *streak* of failed re-fires escalates instead. The streak resets the instant he is seen
to move, so a merc who recovers at the first re-fire never reaches tier 2 and normal play
never touches any of this.

| Stalls | What changes |
| --- | --- |
| 1–2 | evict + re-fire (unchanged) |
| 3 | **drop him out of the engine formation** for `FollowFormationOffSecs` (30 s) |
| 5 | **teleport him to the player**, then judge him afresh |

**Only a man with no fresh slot claim is ever escalated, and never the leader.** The first
version escalated on the same signal that triggers the cheap re-fire, and a session's log
showed why that is wrong: of five stall reports, four read `inFormation=true slotFresh=true`
— positive proof their trees were running — and one of the four was the man who had just
been elected to anchor the formation. Suppressing him took the shape down for everybody
(`rebuild #5 … leader=nil`, `formation OFF (no leader)`, then six shrink rebuilds in a row).
A re-fire is cheap and harmless, so everyone judged stuck still gets one; the escalation
costs a man his place in the formation, so it now demands the stronger evidence — a stale
`FormationSlotAt` stamp, meaning his tree has stopped reporting at all. `FollowFormationSuppressed`
additionally releases anyone who is the current leader, in case he is elected while suppressed.

The player-drift test on its own is not that evidence: it flags the front ranks of a deep
column every time the player pauses or turns, which is exactly what those four were.

Tier 2 is the interesting one. `follow.xml` dispatches on `$useFormation`, so taking a man
out of the formation sends his *next* re-fire down a completely different arm — the plain
`CrimeFollower` chain instead of `FormationFollower`. If the stall has anything to do with
the formation (a stale handle, a slot he cannot path to, a chain parked behind another
stalled man) that is the cure; if it does not, he still follows, just out of shape for half
a minute. It runs through `IsFormationEligible`, so one flag removes him from both the slot
chain and his own `$useFormation` in the same pass. It deliberately does **not** call
`CampFormationDirty` — that nulls the leader and re-elects, dropping the whole squad onto the
chain to fix one man; `UpdateFormationSlots` rebuilds from scratch every pass anyway, so he
leaves on his own next tick and the chain re-packs itself.

Tier 3 exists because `MonitorDistanceAndTeleport` only hauls a man in past its distance
gate, and a merc stalled **at the player's heel** is never far enough for it to see. That is
precisely why this bug slipped through every other net in the mod.

`FollowStallReport` prints the full dispatch state — `inSlotChain`, `isLeader`, `leader`,
`inFormation`, `slotFresh`, `slot`, `chainTarget`, `campActor`, `campOut`, `navGoto`,
`target`, `mounted`, `playerMounted`, `hold`, `escort` — on the first escalation, because
the state is gone by the time anyone goes looking. `merc_follow_why` prints the same line for
the whole squad on demand plus each man's streak and suppression; `merc_follow_reset` clears
them.

### Named companions ride at the front

`FormationFollower` takes a `PreferredPositions` string naming a `<Spot>` in the preset, and our
generated shapes name their spots by rank. Without it the engine drops each follower in any free
spot, so the one man the player actually hired for himself was as likely to be at the back of forty
as at the front. Heroes ask for the front-most band; everyone else passes `""` and fills in around
them.

Two things are derived rather than hardcoded, and both matter:

- **The spot name is per shape** — `front` for column/line/square/wedge, `inner` for circle,
  `rank1` mounted, and *nothing* for escort (two files flanking the subject; it has no front to be
  at) or for the stock vanilla presets, whose spot names are not ours to guess. A name that does not
  exist in the current formation is at best a silent fallback and at worst a failed node.
- **The band's size is the minimum across the whole size ladder** (`FormationFrontSpots`: column 3,
  wedge 4, square 5, line 6, circle 6, mounted 2), so the request can never exceed what the smallest
  preset of that shape actually has. Ask for more front spots than exist and the overflow men fail
  the node, drop to the time-boxed `CrimeFollower` fallback, and retry every 1.5 s for ever — which
  is visible churn. Regenerate these alongside `tools/gen_formations.py` if the shapes change.

Heroes are sorted by name and the first `slots` of them get the band, so the same men keep the same
standing — re-ranking each pass would re-issue a different `PreferredPositions` every tick and make
them swap places on the march. The **leader is skipped**: he is already the front-most man in the
shape and holds no spot of his own, so he never consumes one.

`UpdateFormationFront` runs once a second rather than on every 150 ms leader tick (`IsHero` costs a
`GetName` per merc and nothing here changes fast), but recomputes at once when the epoch or the
leader changes — the epoch is what carries a shape change, and the spot names are shape-specific.

`merc_formation_status` prints `front=N/slots spot=<name>` so the assignment is checkable without a
logging channel.


## Moddability: shipping your own presets

**Likely: whole-file replacement only, and it has not been runtime-tested.**

There is no merge mechanism. `FormationDefinitions` is not a database table at all: the official table inventory ([KM-A-12 Database tables/README.md:33-341](../references/kcd2-mod-docs-main/official-wiki/KM-A-1%20Modding%20Kingdom%20Come%20Deliverance%202/KM-A-36%20Technical%20Overview/KM-A-3%20Structure%20of%20a%20Mod/KM-A-12%20Database%20tables/README.md), 307 rows) contains **zero** occurrences of the string "formation" — so it is not merely outside the patchable subset (208 of those 307 support patching), it is not in the list at all. It ships in `Scripts.pak`, not `Tables.pak`, so the `<tablename>__<modid>.xml` convention has no hook for it. The complete set of merge-capable mod files (`scripts/mods/<modid>.lua`, `data/libs/tables/.../<table>__<modid>.xml`, `data/quests/<modid>.xml`, `data/libs/Storm/storm__<modid>.xml`) does not include AI XML. The filename is engine-side: it appears in no vanilla XML, and [`WHGame_release_1_5.dll`](../references/kcd2-mod-docs-main/DLL/WHGame_release_1_5.dll) contains the literal `FormationDefinitions.xml` exactly once (`0x3fe3ac8`), in a bare literal pool with no directory prefix and no format specifier — so nothing in the loader could recognise a part file. (Its neighbours in the pool are `FormationSpinePointPuppet` and `C_CrimeShelver`; adjacency in a string pool is not ownership, so which class consumes it is unknown.)

**The mod-side path is `data/AI/FormationDefinitions.xml`, not `data/Scripts/AI/...`.** `Scripts/` in the mod-docs dump is the *extraction root* of `Scripts.pak`, whose own top level is `Quests/`, `AI/`, `Scripts/`, `Entities/`. `PackageMod.bat` zips `data/` with no containing folder, so `data/AI/follow.xml` becomes pak entry `AI/follow.xml` — which is why `SmartEntity__so_interrupt__mercenaries.xml` addresses it as the bare `FileName="follow.xml"`. That is the same `AI/` root vanilla uses, so a mod file there collides with the vanilla one by design.

Same-path override of an AI XML is empirically honoured — `zdjbcamping_mod` ships full copies of `AI/world/so_fireplace.xml` and `so_smokehouse.xml` (the entire vanilla files plus insertions, exactly the shape whole-file override forces). But **no mod in the reference set has ever overridden `FormationDefinitions.xml` or its sibling `LinkTagDefinitions.xml`**, and both are loaded once at AI-system init rather than lazily on tree resolution, so mod-pak mount timing relative to that init is unverified. One test settles it: add a uniquely-named formation, `MakeFormation` on it, and check a dev-build log for a resolution failure (see [dev logging](ai-modules.md) — the release exe logs nothing).

If it works, the cost is real: you must copy all 63 vanilla formations into your file or you delete the missing ones game-wide, you hard-conflict with any other mod that ships the file, and a game patch that edits it silently reverts you.

**The conflict-free alternative is reusing an existing preset name.** `MakeFormation` takes only a name string, so any preset in the loaded catalogue is available to a mod's own tree with no level data and no file collision. `followNPC` (8 spots, ±0.7 m, ranks every 1.7 m) is close to what `UpdateFormationSlots` already builds by hand; `infantryMen20` and `cavalryRiders6` cover larger bodies; `longLine` and `nextToLeader` cover small escorts.


## Turning horses off entirely (`merc_horses 0`)

The company can be told to march on foot whatever the player is riding — from the console or
from the quartermaster's **Mod settings**. The setting is saved (`MercHorses`).

**The lever is `_G.PlayerMounted`, not the horse spawn.** That global is what the whole mod
reads as "the squad is operating mounted", and it independently drives:

| Reader | What it does while true |
| --- | --- |
| `FormationPresetName` | selects `merc_mounted<N>` — files 3.5 m, ranks 4 m, ~64 m deep at fifty men |
| `FormationLeaderSwapMargin*` | widens the leader-swap margin from 8 m to 30 m |
| `UpdateFormationLeader` | force-rebuilds the formation on a mounted/dismounted edge |
| `FormationFrontSpot` | switches to the mounted band |
| `MonitorDistanceAndTeleport` | **disables** the fall-behind teleport entirely |
| the schedulers | skip the stuck-follower self-heal |
| the loot sweep | cancels when the player mounts |

So blocking only the spawn — or only `bt_data.playerIsMounted` — produces men on foot, in a
64 m cavalry column, with catch-up teleport *and* the stuck-follower self-heal switched off,
chasing a galloping player. That is a worse squad than the one that already exists.

Both halves of the mount poll therefore moved out of `follow.xml`'s `code` attributes into
`MercPlayerMountSeen` / `MercPlayerMountLost` (mercenaries_target_selection.lua), and the
"seen" half holds the global false while the setting is off. Everything downstream follows:
`MercMountState` yields `want = false`, so no horse is ever spawned; the formation picks a
foot preset; and the orphan sweep's `elseif not _G.PlayerMounted` arm despawns any horse
already standing, which is what makes the setting take effect mid-game instead of at the next
dismount. Turning it off explicitly drops the global as well, so it does not wait for a poll.

Two consequences worth knowing: catch-up teleport is now *armed* while the player rides, which
is the only thing that lets men on foot keep up with a horse; and the loot sweep no longer
auto-cancels when the player mounts (its distance check still ends it).

## Mounted mercs engaging late

**First, a correction that cost real time: that 10 s `Wait` is not a ride block.** It is the
**mount-acquisition deadline**. The merc is still *on foot* inside it — `StanceElement` is
what walks him to a horse spawned 5 m away and plays the mount transition — and when it
expires the `StanceCheck` below it **destroys the horse** and latches `mountAbandoned`. A
merc who mounts successfully falls through into an *untimed* `Loop count="-1"` and never
returns to this node at all.

So shortening it does nothing whatsoever for engagement lag, and at 2 s it produced a
different bug outright: the horse was deleted out from under a merc who was still walking to
it. That reads as **"horses spawn but despawn before they can mount up"**. It is back to 10 s.

**A third arm that fails on threat does NOT work — it was tried and reverted.** Adding a
watcher `Loop` to that `Parallel` which `Fail`s when a threat is near stopped mounted mercs
following at all. The `Parallel` is `failureMode="Any"`, so that arm ends the whole block —
and with roaming patrols about, `MercSquadThreat` is true often enough that it ended more or
less continuously. Anything added to that `Parallel` must be incapable of failing while the
merc is meant to keep riding.

`_G.MercSquadThreat` is maintained by `UpdateSquadThreat` (once per `CombatScanLoop` pass, a
live hostile within `SquadThreatRange` of the player) and `MercShouldDismount` exposes it to
a tree. **It is still unused by any tree**, and until recently it was also broken: the loop
iterated `CachedEnemies` as if the entries were entities, when they are
`{entity=, wuid=, armed=}` wrappers, so the flag could never go true at all. That is fixed;
the signal is sound, it is the consumer that has never been written.

## Mounted mercs not following

Every mounted node — the distance gate, the mount `CrimeFollower`, and both mounted `Move`s —
reads `$followTarget`. The on-foot leader arm does not: it hardcodes `$playerWUID`. That
difference hid a real bug, because `CalculateFormationTarget` builds `followTarget` from the
follow **chain**, whose ordering (mounted-first / rank / hp / name) has nothing to do with who
**leads** (nearest to the player). The leader's own slot is usually past the formation width,
so his chain target was one of his own followers: mounted, the formation anchor rode at a
squadmate three metres away, his `Move` succeeded the moment it was issued, and the entire
`MoveHistory` column parked with him. `CalculateFormationTarget` now returns the player as the
leader's `followTarget` unconditionally.

Second, both mounted `GetMemberFormation` calls re-bound `$formationWUID` without nulling it
first (the on-foot follower branch does null it). A stale non-null handle therefore survived a
formation rebuild for good, instead of the rider dropping to the `Move` arms until a valid
handle came back. Both sites now clear it first.

### Leader churn is what makes mounted following slow

Every leader change runs `EndFormation` + `MakeFormation` and forces **every** follower to
re-acquire a slot, so a swap is expensive and must be rare. `UpdateFormationLeader` runs every
150 ms and elects whoever is nearest the player, and a plain 8 m distance margin was nowhere near
enough: in one short ride, **6 of 11 rebuilds were `leader displaced`**, with leadership bouncing
between the same few mercs. The squad never stayed still long enough to form up — that is what
"mounted mercs take ages to start following" actually was, rather than anything in the mount path.

Hysteresis is therefore in three parts:

| Part | Setting | Why |
| --- | --- | --- |
| margin | `FormationLeaderSwapMargin` 8 m on foot, `…Mounted` 30 m | the mounted preset is ~64 m deep, so being 20 m ahead of the leader is normal, not exceptional |
| duration | `FormationLeaderSwapSecs` 3 s | the challenger must *hold* the lead, so one overtake on a corner is not a handover |
| cooldown | `FormationLeaderSwapCooldown` 6 s | a rebuild always gets time to settle before another can start |

A leader who is dead or no longer eligible is replaced **immediately** — none of the three apply
to that, because it is not churn.

### `destinationSpecification2`/`3` are the FLEE band — leave them empty to chase

This one cost two wrong diagnoses, so it is worth stating precisely.

The mounted formation **leader** measured *exactly* 0.00 m of movement for as long as he was
mounted, drifting 10 m → 25 m behind the player and recovering the instant he dismounted. He is
the only NPC who shows it because he **is** the formation anchor: every other rider uses
`FormationFollower` (which works mounted), and he is the one who falls through to the `Move` arms.

The cause is not that `Move` cannot drive a rider — `moveOnHorse`, `menhart`, `cavalry_move` and
`hunter_rideHome` all put a bare `Move` directly under a horse `StanceElement`. The cause is that
**wherever `destinationSpecification2`/`3` are populated in shipped data they are the flee band**:
"stay outside these two distances from the target". The only live-WUID examples anywhere are
`companionmerchant.xml` and this mod's own `$goFlee` branch in `mercenary_scheduler.xml`, both
`$distanceToFlee` / `$keepMinimalDistance`. Filling them with stand-off distances turned the
leader's `Move` into a **flee node aimed at the player** — and a leader already 10–25 m away
satisfies the band, hence exactly zero movement rather than merely sluggish movement.

> Two earlier readings of this were wrong and are recorded so they are not repeated. It is **not**
> "the literals should have been variables" — making them variables just produces a correctly
> configured flee node, which is why that change fixed nothing visible. It is **not** "`Move`
> doesn't work while mounted" either.

Empty `spec2`/`spec3` against a live WUID is the chase idiom (`references/AI/_vachek/zakladni_chovani.xml`),
and `changeNPCState="true"` matches every vanilla chase/travel `Move`; `false` is flee-specific.
The distance bands now gate **speed only** (Dash beyond 10 m, Walk inside), never the destination
parameters.

### The mounted leader matches the player's speed

He is the one rider who cannot use `FormationFollower` (he *is* the anchor), so he drives himself
with a `Move` — and `speed` is an enum **attribute**, not a variable, so each gait has to be its
own node behind a switch, the same reason this file spells out every `FormationMode`.

He used to pick between exactly two: Dash beyond 10 m, Walk inside, sampled once a second. That
cannot help but surge — dash until inside 10 m, drop to a walk, fall behind, dash again — and
because every follower replays his path through `MoveHistory`, the whole column concertinas
behind him.

Now `UpdatePlayerSpeed` measures the player's actual speed (smoothed; a raw per-tick delta
jitters enough to flip a gait band on its own) and `MountedLeaderGait` picks the matching gait at
300 ms. **Distance is only a trim** — one gait up if he has dropped back past
`MountStandoff + MountTrimBack`, one down if he has closed inside `MountStandoff - MountTrimNear`.
Matching the speed rather than chasing the gap is what makes it constant: at a true match the gap
simply holds and the trim does almost nothing. Gait `-1` holds station when the player has stopped
and the leader is already at standoff, so he does not creep the last few metres onto him.

Tuning lives in `MountGaitBands` (the m/s cuts between Walk/Run/Dash/Sprint) and `MountStandoff`.

The hook runs for **every** merc, not just the leader: a mounted follower whose formation handle
is momentarily null falls through to these same gait arms, and leaving him on a default Walk
would drop him out of the column.

**Rejected alternative:** anchoring the formation on the player so the leader could use
`FormationFollower` too. `MakeFormation` takes only `FormationName` and `HandleVariable` in every
shipped occurrence — there is no owner/WUID parameter that would let the player be an anchor, and
`GetMemberFormation` only retrieves a handle for an entity some other `MakeFormation` already
made a member. That would be an unproven architectural change for a bug with a mundane cause.

### Keeping up with a sprinting player

**There is no faster gear to give them.** `Dash` is the highest `RelativeSpeedLimit` that
exists — vanilla uses only `Walk`, `AlertedWalk`, `Run`, `Dash` — so the followers are already
flat out and "make them run faster" via the tree is not available.

The fix is therefore to make the *NPC* faster, not the node: **`merc_keepup_buff`**
(`rms*1.3, mst*1.5`), applied to every merc and refreshed on the slow tick. `rms` is the
movement multiplier the mod's own buffs already use; the stamina half matters because a long
run otherwise leaves them winded and slowing.

> **Do NOT switch `FormationMode` automatically to give them "slack".** This was tried —
> `KeepShape` while walking, `MoveHistory` while sprinting — and it is a trap in a deep
> formation. `merc_column50` is **45 m** from front spot to back. `KeepShape` places the back
> spot as a rigid offset behind the leader's *facing*; `MoveHistory` places it 45 m back along
> the path he actually *walked*. After any turn those are two different points tens of metres
> apart, so every switch teleported each follower's **target** and the man ran off to it: the
> "everyone except the leader runs 20 m away and then comes back" bug. It fired exactly when
> the player's speed crossed the threshold, i.e. whenever he got a little ahead. Make the
> followers faster; do not move the goalposts.

**Mounted is the same fix, on the other entity.** `enum:movementSpeed` (confirmed against every
vanilla BT file, including Warhorse's own `getSpeedFromDistance` gait ladder in
`AI/move/moveUtils.xml`, which hard-clamps its index to `sprint`) tops out at `Sprint` for
everyone — there is no `Gallop` tier hiding in the engine for horses. So a mounted merc who is
already at `mountGait == 3` (see [above](#the-mounted-leader-matches-the-players-speed)) has
nothing left in the node either, and `merc_keepup_buff` on the *rider's* soul does nothing while
mounted: the horse carries him, so the horse's own speed is what has to move. `follow.xml`'s
horse-lifecycle Lua now calls `mercenaries:ApplyKeepUpBuff(horseEnt, mercenaries.HorseKeepUpBuff)`
on the merc's horse soul (both when an existing horse is found and right after a fresh one is
spawned) — the same generic per-entity function the on-foot case uses, just pointed at
`horseEnt`/`existingHorse` and a second, **horse-specific** buff (`merc_horse_keepup_buff`,
`rms*1.6, mst*2.0`) instead of `merc_keepup_buff`. It is its own buff rather than a reuse of the
on-foot one because 1.3x (the on-foot value) still left mounted mercs falling behind in testing —
mounted and on-foot keep-up are tuned separately on purpose so raising one never silently changes
the other. This is vanilla-consistent: `item_horse_shoe` and `item_bridle` apply the exact same
`rms`/`mst` codes to a horse's own soul, confirming those stats are horse-readable, not
human-only. If mercs still fall behind at a hard sprint, raise `rms` on `merc_horse_keepup_buff`
in `buff__mercenaries.xml` further rather than touching `merc_keepup_buff`.

### The circle presets are offset forward on purpose

Every formation is anchored on the **leader**, not the player — `MakeFormation` takes only a
name and a handle, with no owner parameter, so there is no way to make the player the anchor
(see the rejected alternative above). A circle drawn around the origin therefore rings the
*leader*, who stands behind the player, and the ring ends up sitting behind him rather than
around him.

So the `merc_circle*` spots are shifted forward: each preset's centre is moved to
`y = -3.0`, i.e. roughly where the player stands relative to a leader following him. `+y` is
behind the leader (the columns run 0 → 45), so negative y is toward the player. `merc_circle6`
now runs y −6.5 → +0.5 around a centre at −3.0, instead of +1.6 → +8.6 around +5.1.

The leader himself is not one of the ring spots — he is the anchor — so he ends up just behind
the ring, which is where a man following the player should be anyway.

**If the ring reads as off-centre again, the number to change is that 3.0 offset**, which is the
assumed leader-to-player standoff; the spot geometry itself is fine. Only `merc_circle*` presets
were touched — column, line, square, wedge and escort are unchanged.

### Teleport leashes: two different numbers

Stragglers are dragged back at `TeleportDistBase + 1.4 m per merc` (capped at 130 m). It **must**
scale: a fifty-man line is enormous and the outer files are legitimately far from the player, and
a flat 50 m gate had them teleporting continuously — and every teleport is a hard `SetPos` that
resets the merc mid-path, so continuous teleporting is continuous churn.

The **leader** is on a short, flat `TeleportLeaderDist` (20 m) instead. He is the anchor: the
whole shape hangs off him, so a leader who has dropped back takes the squad with him, and the
followers' generous gate only makes sense *because* it is measured from a leader who is near the
player. He follows the player directly and normally sits a few metres away, so this fires only
when something is genuinely wrong.

Two things deliberately do **not** apply to him:

- `TeleportKeepBehindLeader` (which keeps a teleported straggler from landing in front of the
  leader and physically blocking the one NPC everything hangs off) — pushing him behind himself
  is meaningless. It is also skipped in **circle** formation, where "behind the leader" has no
  meaning at all.
- The repeat-teleport stall counter. His follow tree is the one that owns `MakeFormation`, so
  restarting it destroys the formation and drops every follower onto the chain. His short leash
  means he teleports more often than the rest by design, so flagging him would churn the squad.

#### The in-combat exemption is not a free pass

Nobody is teleported mid-swing, but "in combat" only means *holding a target* — it says nothing
about the fight being anywhere near the player. Two limits on that exemption:

- Past `TeleportCombatOverride` (2×) his own gate, a fighting merc is dragged back anyway.
- **Archers are exempt from the exemption entirely.** An archer has no swing to interrupt — he
  stands and shoots — and unlike a melee merc he never closes on his target, so nothing brings
  him forward on his own. His module breaks off at the player leash, the scheduler immediately
  re-acquires the same man (targets are cached out to `EnemyAlertRadius` once the squad is
  alerted), and he is "in combat" again. That made archers *permanently* exempt and permanently
  left behind — the "archers never emergency-teleport" report.

`merc_follow_stats 1` logs player speed and the squad's distance spread (nearest / median /
worst, plus how many are past the teleport gate) **alongside the formation epoch, mode and
preset** — those three are the things that can move a follower's target rather than the
follower, so a spread that jumps on the same tick as an epoch or mode change means the squad is
chasing a moved goalpost, not failing to keep up.

### A merc that freezes where he stands

`follow.xml`'s top-level `Parallel` is `failureMode="Any"`, so **any one arm failing ends the
whole follow behaviour** — and the tree had no failure containment at all, so the scheduler's
`$isFollowingActive` stayed latched true with nothing running. The distance self-heal cannot
rescue that: it is gated on `$distanceToPlayer > 35`, so a merc who stops *next to the player*
is never touched. He stands there for ever.

The arm that actually did it was the `MeasureDistance` loop feeding `$mountedDistToTarget`,
which had no `SuppressFailure`. `$followTarget` is a squadmate for most of the squad, and a
dismount churns the whole chain at once (shape flips mounted→foot, epoch bumps, `FormationSlots`
rebuilds) — so a target that is momentarily unresolvable takes the tree down. That is why it hit
**one or two** mercs and not all of them, and why it showed up on dismount specifically. It is
now wrapped; treat any unprotected node in one of those arms as a squad-wide single point of
failure.

**The failure mode is not a tree that dies — it is a tree that is still running and going
nowhere.** The tell is that toggling squad idle on and off fixes the merc by hand. One signal,
`FollowStuck`, handles it: clear `$isFollowingActive` **and** fire `teleport` to evict the
stalled tree, after which the normal arm starts `follow` fresh. The eviction is the essential
part — re-firing `follow` over an already-running `follow` does not reliably displace it, and
toggling idle works by hand precisely because the idle arm fires the **`teleport`** behaviour
first, a *different* behaviour, which definitely evicts it.

> **Never re-arm this from a `FuseBox`/`OnFail` on `follow.xml`.** It was tried and it feeds
> back. The tree is "ended" every time it is *deliberately* replaced — by combat, or by the
> scheduler's own re-fire — so the `OnFail` re-arms the very re-fire that ended it, and `follow`
> restarts once a second for ever. Every restart re-runs `GetMemberFormation`, so the whole
> formation churns visibly. An `OnFail` there cannot distinguish "died unexpectedly" from "we
> replaced it on purpose", which is why `FollowStuck` is raised only by **external** triggers
> (the teleporter, the dismount watch) and consumed before it acts, so it can fire at most once
> per raise.

**Dismount is watched, not blanket-reset.** While the mounted-leader bug was unknown, a dismount
reset the whole squad unconditionally. That is gone: it cost exactly what it was meant to save,
because forcing a `teleport` and a follow restart on mercs who were already following fine is
itself a stall of a second or two, every single time. Now `DismountWatch` merely **opens a
verification window**, and `DismountVerify` resets only a merc who demonstrably covers no ground
**while the player clearly does**. In the normal case nothing happens at all.

**Each merc carries an anchor**, not a previous-sample position: where he was when last seen to
move, and where the player was at that moment. That matters — the first version compared against
the previous sample and demanded the player cover 5 m *inside one 3 s sample*, so walking slowly,
or **stopping to look at the merc who is not following**, meant it could never judge anyone. It
logged zero hits in a session with a visibly stuck merc.

A merc who has covered no ground since his anchor is judged stuck by either of two independent
rules:

- the **player** has covered ground since that anchor — he is being left behind; or
- he is simply **far away and stationary** (`DismountVerifyFar`), which is wrong regardless of
  what the player does. This is the case the player-movement rule structurally cannot see, and
  it is the most likely one to be observed, because noticing a stranded merc usually means
  standing still and looking at him.

Still not the general movement/velocity stuck detector that was removed for causing twitching and
horse churn, and it must not be widened into one: it only runs inside a post-dismount window, a
merc who moves at all re-anchors and is never judged, it skips mercs in combat or on camp duty
and the formation leader, one stall produces exactly one reset (he re-anchors either way), and it
cannot spawn horses because it only runs while the player is on foot. Keep those bounds.

**Dismount reaction time** is set by the `_G.PlayerMounted` debounce, not by anything downstream:
the poll and the debounce are a pair (~500 ms poll, 1.2 s of disagreement = two consecutive
failed reads). That absorbs a blip — one missed `StanceCheck` would otherwise dismount the whole
squad and start every horse's despawn countdown — while still reacting to a real dismount in
about a second. It was 3 s at a 1 s poll with a 2 s debounce. The horse has its own, much longer
guard (`despawnCountdown`), so this value only has to cover the dismount decision.

> **Never idle the squad to fix following.** Driving this through `_G.MercIdle` — the cure
> players do by hand — looks obvious and is wrong. `UpdateFormationRole` returns early on
> `_G.MercIdle`, so `useFormation` goes false for *everyone*, the leader's `SubtreeDecorator`
> runs its `EndFormation` cleanup, and the whole squad drops to the `CrimeFollower` chain until
> the formation is rebuilt from scratch. The per-merc path (clear the latch, fire `teleport`)
> is the part of the idle cure that actually does the work, and it leaves `useFormation` alone.
> If you ever *do* set `_G.MercIdle` transiently, never write `MercIdlePersistent` with it, or
> a save landing inside the window reloads the squad permanently idled.

**The formation leader is skipped** by the dismount reset. His tree is the one that owns
`MakeFormation`, so restarting him destroys the handle and forces every follower onto the chain
— the same regression by another route. Followers restart against a formation that is still
standing and re-join it directly. Skipping him is safe because a stalled *leader* would anchor
the formation and stop the entire squad, which is not the observed symptom (one merc).

**Why the 35 m self-heal could never catch this on its own:** `MonitorDistanceAndTeleport` drags
any merc past 50 m back to the player once a second. A stalled merc was therefore teleported back
*before* he could stay beyond 35 m long enough to be noticed — the teleporter was **hiding** him,
which is exactly why he reads as "standing around next to you as if idle" rather than as a
straggler falling behind. Needing a teleport at all is itself the stuck signal, so that is where
the flag is raised. It cannot cause the two regressions the old velocity-based stuck detector did:
it fires only on a real >50 m teleport (not while everyone stands still), and the teleporter
returns early when the player is mounted, so it can never churn horses.

Two further details matter:

- the poll is **read-only** and the flag is consumed only when the scheduler actually acts, so a
  flag raised during a fight survives until the fight ends instead of being thrown away;
- it never reports true while `IsNavGotoActive`, because walled-battle staging replaces `follow`
  deliberately and re-arming there would fight the staging move.

**Do not "fix" mounted problems by re-firing the follow interrupt.** Restarting the follow
module while mounted throws the merc off his horse — the old "random dismount" — which is why
the stuck-follower self-heal skips mounted mercs entirely.

**Do not raise the mounted `Move` stop distances to the reference mod's values.** There the
rider is a lone companion permanently following the player; here the same rider is the
formation *anchor*, and nothing may sit ahead of him. Widening his standoff slides the whole
authored column back — `merc_mounted50`'s deepest rank is already 64 m — and pushes more of it
past the 35 m de-target in `mercenary_scheduler.xml`.

### When a merc stops following

`FollowStalled` → `PollFollowRefire` → fire `teleport` to evict, then let arm 4 start `follow`
fresh, is the working cure. The problem was never the cure; it was **noticing**.

Two things could notice, and between them they left a hole big enough to be the most-reported
bug in the mod:

* the scheduler's own self-heal (`mercenary_scheduler.xml`, arm 6) needs
  `$distanceToPlayer > 35.0`. It cannot see a man who halts *beside* the player, and 35 m is
  not negotiable — see "The follow-verification net must not fight a deep formation" above;
* `DismountVerify` can see exactly that man, but it only ran inside a **25 s window** opened
  by `BeginFollowVerify`, and only four things open one: a dismount, a battle ending, a hold
  released, an escort ordered.

So a merc who stalled at any other moment — and he can stall at any moment, from any cause —
was watched by nothing at all, for the rest of the session. The player's only cure was to
toggle idle by hand, which is precisely what the eviction does, done manually.

`FollowWatchEvery` (4 s, 0 disables) runs the same sampler continuously when no window is
open. Same per-merc anchors, same exemptions, slower cadence — a stall nobody has noticed yet
is not urgent. Cost is one `GetWorldPos` per merc per sample.

Two gates moved into `DismountVerify` itself, because the continuous path has no
`BeginFollowVerify` to check them for it:

* `_G.MercIdle` / `_G.MercenariesDismissed` — a squad that is *meant* to be standing;
* a merc holding a claim in `MercTargetOf`, added to the existing `busy` test. He is committed
  to an enemy, and the approach across open ground to one is legitimately slow. This could not
  come up before: all four window triggers fire when no fight is on.

`DismountWatch` returns early while the player is mounted, so the continuous watch inherits
the mounted exemption for free — re-firing follow at a rider throws him off his horse.

### The eviction race — a third of the squad freezing after "follow me"

The symptom: with a big squad, "wait here" works, and on "follow me" everyone starts walking and
then roughly a third stop again after a couple of seconds and never move again. It scales with
squad size and is not reproducible at ten men.

Evicting a stalled follow tree is **two steps in two independent scheduler arms**:

| arm | what it does |
| --- | --- |
| re-fire arm (`$followStuck`) | consume the flag, clear `$isFollowingActive`, `AddInterrupt_teleport` to evict whatever is running |
| follow arm (arm 4's `ContinuousSwitch`) | whenever `$isFollowingActive` is false, `AddInterrupt_attack` → `follow`, then latch it true |

An interrupt is **not applied where it is queued** — the engine applies it on its own update.
The two arms have independent, randomised timers, so the follow arm's tick can land inside that
gap, and the order becomes:

```
queue teleport  ->  fire follow, latch = true  ->  teleport lands, evicts the follow we just fired
```

The latch now says "following" with nothing running, and the follow arm only ever retries on a
**false** latch. He stands there for good. The 35 m self-heal cannot see him, because he stopped
next to the player.

The gap widens with squad size (more interrupts per engine update), which is why it only bites at
forty or fifty men. Which mercs lose the race depends on the phase of their own randomised waits,
which is why it is "about a third" rather than all or none.

**Releasing a hold order was the mass trigger.** `HoldReleaseAll` used to raise `FollowStalled`
on the **whole squad**, and that flag is exactly what drives the re-fire arm. But a man stood on
his station is *idle*, so the scheduler's idle arm has already evicted his follow tree and
cleared the latch — the moment the order drops he re-fires on his own, with no help. Flagging him
too queued a **second** eviction about a second later, one that lands *after* he has started
walking. Fifty of those in a two-second window is the bug.

Three changes, in the order they matter:

1. **`HoldReleaseAll` flags only the men who were actually under a nav order** (`mode == "hold"`
   or `"escort"`). Those are the ones whose follow tree was evicted by the `nav_goto` interrupt
   while the latch still said "following", so they genuinely cannot recover on their own.
   Everyone else recovers through the ordinary idle→following transition. In stand-fast mode that
   is usually the whole squad, so the flag count drops from fifty to nearly zero.
2. **`refireBlock` closes the race itself.** Anything that queues an eviction stamps
   `NoteFollowEviction`, and the follow arm will not fire `follow` while the stamp is live
   (`~$isFollowingActive & ~$refireBlock`). The re-fire arm and the idle arm also set
   `$refireBlock = true` inline in the same BT tick as the teleport, so the follow arm cannot see
   a stale `false` in the 300 ms before `FollowGate` republishes it.

   The stamp is **time-based and self-expiring in Lua**, and `FollowGate` clears the BT variable
   *first* so any error leaves the gate open. Both of those are deliberate: a BT latch held
   across a `Wait`, or a gate that can fail shut, is a merc who never follows again — the same
   class of bug one level down.
3. **Re-fires are staggered.** `FollowStalled` is now a queue: each raise takes the next
   `FollowRefireStagger` slot, so a burst spreads out instead of landing in two frames.
   `FollowStaggerSquad` does the same for the whole squad on an order release, capped at
   `FollowStaggerTotal` so a small squad still moves off at once and a fifty-man company ripples
   into motion over about a second and a half.

**The verification window is the safety net**, and it is no longer dismount-only:
`BeginFollowVerify` is opened by a dismount, by releasing hold/escort, by an explicit "follow me",
by the end of a battle, by the end of a loot sweep, and by a **hire** — every moment where a batch
of men must all pick up `follow` at once. Its bounds are unchanged (see above) plus two more — it
stands down if a hold or escort order is re-issued inside the window, and it skips anyone on an
active `nav_goto`.

> **`archer_scheduler.xml` is a parallel copy of `mercenary_scheduler.xml` and needs every fix made
> there.** The guard landed in the melee scheduler first and the archer one was left on the old,
> unguarded evict-then-refire — so archers kept losing the race after everyone else had stopped.
> It showed as "hire ten archers and they spawn but never follow": a hire fires ten `follow`
> interrupts at once *and* grows the formation, which is exactly the burst that widens the gap.
> Both files now carry `refireBlock`, `FollowGate`, and `NoteFollowEviction` on both eviction
> sites. They are the only two schedulers with the `$isFollowingActive` latch — grep for it before
> assuming a fix is complete.
