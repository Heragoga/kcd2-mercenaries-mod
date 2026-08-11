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

### Contrast with what the mod does today

The mod uses none of the vanilla machinery — grepping `data/` for any of the formation nodes or the `AI.*Formation*` binds returns nothing.

[mercenaries_formation_handler.lua](../data/Scripts/mods/mercenaries_formation_handler.lua) rebuilds `FormationSlots` from scratch each low-priority tick: filter to living non-camp mercs, split mounted/unmounted, sort by `formationRank` (hero 0 / regular 1 / archer 2) with unmounted regulars tie-broken on descending health, then build a **follow chain** — each merc at index `i` follows the merc `width` places ahead (`width = 3` at 15+ mercs, else 2). The first `width` mercs get no target and fall through to the player. [follow.xml](../data/AI/follow.xml) polls `CalculateFormationTarget` once a second and drives locomotion with `CrimeFollower Target="$followTarget"`, not with any formation node.

| | Vanilla | This mod |
|---|---|---|
| Shape source | authored `<Spot x y radius>` in a global file | emergent from a Lua follow chain |
| Owner | the entity that ran `MakeFormation`; followers resolve via `GetMemberFormation` | nobody — each NPC independently follows one WUID |
| Cohesion | `FormationMode`, engine-side | emergent from `CrimeFollower` + distance bands |
| Player as anchor | impossible | trivial, it's the default |
| Re-targeting | `EndFormation` + `MakeFormation` | rebuild the Lua table; picked up within 1 s |
| Spacing/facing | authored | not controllable |

The chain-follow design is the correct response to the constraint, not ignorance of the alternative — the third-party bodyguards mod reached the same conclusion independently (`references/bodyguards/data/AI/companion_follow.xml` sets `$followTarget = $__player` and uses `CrimeFollower`, zero formation nodes). Its real costs are that spacing and facing are emergent rather than authored, and that the whole chain is rebuilt every tick.

### The elected-leader workaround

If authored spacing is worth the cost, the shape vanilla actually supports is: **one merc leads, and it is the leader that follows the player.**

**This is not speculative — vanilla ships the existence proof.** The [ambient startle pair](#the-ambient-startle-pair-a-formation-with-no-quest-and-no-level-data) is exactly this problem solved with exactly these constraints: no quest, no `EnableBehavior`, no smart object, no level-baked link, two ordinary entities negotiating a formation at runtime. It is the closest thing in the game to what the mod would be doing, and everything it uses (`MakeFormation` on the anchor, `GetMemberFormation` from the anchor's WUID on the follower, globally-named locks templated on the anchor, an `autoInverse` link for exclusivity) is reachable from mod-shipped `data/AI/*.xml` plus WUIDs the mod already tracks in Lua.

The build:

- Elect a leader in Lua (the existing sort already produces a deterministic ordering — take index 1). Or elect it in pure BT: the battle controller's `Semaphore` + `GraphSearch` + `AddLink` latch quoted above is nine generic lines with no battle dependency.
- The leader runs a tree that does `MakeFormation FormationName="'followNPC'"` in `OnInit` — or in `SubtreeDecorator/Init` with `EndFormation` in `Cleanup`, so an interrupt cannot leak the handle — and then the mod's existing `CrimeFollower` on `$__player` as its locomotion. This is exactly the `followNPC_leader` shape: create the formation, then delegate movement.
- Every other merc runs the `so_guardPair` slave shape against the leader's WUID (handed over from Lua rather than `GetBehaviorHolders`), with the `Selector` + `Wait '1s'` retry as the gate, wrapped in the `Loop` + `SuppressFailure` idiom from [walkaround.xml:319-332](../references/AI/profession/bailiff/walkaround.xml) so a transient `FormationFollower` failure retries instead of ending the behaviour. `MoveHistory` for marching.
- If several squads or camps can ever be live at once, key every lock name on the anchor's WUID the way the startle pair does. Global locks are one flat string namespace; a fixed name deadlocks the second squad.

Costs, ranked by how real they are:

- **The formation is one merc behind where you want it.** The shape trails the *leader*, so the whole squad sits one follow-distance further back than today, and the leader's own jitter propagates into every slot. No way around this — it is the headline constraint restated.
- **Leader death needs rebuilding in Lua.** Election exists in vanilla and is copyable; **re-election does not exist anywhere** — the battle controller's `'leader'` link is never removed (`RemoveLink` on that tag has zero hits in the file), and `moveinformation_simple`'s `OnLeaderDeath` is a plain `SoulDeathTrigger` the designer wires by hand. You would detect the death in Lua, `EndFormation`, re-elect, restart every follower's behaviour, and every follower re-acquires from scratch. That is a common event for this mod, so this is the cost that decides it.
- **Slot count is capped by the preset.** `followNPC` holds 8; beyond that you need a bigger preset, which means shipping the file (below). No overflow rule was found in any BT.
- **Combat interaction: partly evidenced, partly unknown.** Fighting *inside* a formation is shipped and needs no battle infrastructure — [battlegroupcontroller.xml:1755-1768](../references/AI/battles/battlegroupcontroller.xml) composes the full melee stack in `Parallel` with `FormationFollower`. What is unknown is teardown and re-entry: the mod's schedulers replace `follow` with a combat module at equal priority, and whether spot assignment survives that cycle cleanly is untested.
- **The mounted branch is a three-line idiom, not a rewrite.** `StanceElement stance="horse"` wrapping `WaitAction` + the follow node ships three times (`prijezdnasuchdol.xml:873`, `moveInFormation_simple.xml:43`, `erik_armyMovement.xml` `cavalry_move`). What you would lose is `follow.xml`'s 10 m/4 m distance-band `Move` logic, since `FormationFollower` owns locomotion entirely.

Given the leader-death cost alone, this is still not obviously an improvement for a squad that takes casualties. It is worth prototyping if authored spacing is a goal in itself — and the startle pair means the prototype is a known-good shape rather than a research project.

### Untested, and worth one experiment each

- **Can the player's own tree run `MakeFormation`?** The player has a brain and always-active subbrains, and a mod can add `brain2subbrain` rows. If a mod tree attached to the vanilla `player` brain can run `MakeFormation` + `Wait '-1'`, the entire hand-rolled slot system collapses into one `FormationFollower` per merc, with no elected leader and no leader-death problem. Nothing in vanilla tries it; the player entity is not an `NHNPC` and has no navmesh agent, so it may simply be rejected. **This is the single highest-value test.**
- **A spawned holder.** Spawn a `SmartObjectHolder` with a mod `guidSmartObjectType` whose subbrain is a clone of `formationholder.xml`, and keep it on the player. Two unknowns: whether a runtime-spawned holder gets its `on_update_tree` ticked at all (every existing spawn in this mod is an SO that NPCs *enter*, never one with its own always-active brain), and whether a per-tick `SetPos` breaks it — [ai-modules.md](ai-modules.md) records that periodic `SetPos` resets an NPC's AI, though a holder that only waits may be immune.
- **There is no Lua route.** The 14 `AI.*Formation*` binds (`CreateFormation`, `CreateGroupFormation`, `AddFormationPoint`, `AddFormationPointFixed`, `ChangeFormation`, `ScaleFormation`, `SetFormationPosition`, `GetFormationPosition`, `GetFormationPointPosition`, `SetFormationLookingPoint`, `GetFormationLookingPoint`, `SetFormationAngleThreshold`, `SetFormationUpdate`, `SetFormationUpdateSight`) are CryEngine-2 legacy on a completely different data model — sight angles, `eSoldierClass`, 3D offsets, scale, none of which exists in `FormationDefinitions.xml`. Nothing in the shipped game calls them. `XGenAIModule`, `soul`, `human` and `entity` have no formation functions at all. Anything formation-shaped must be driven from a behaviour tree.

## This mod's own shapes

[data/AI/FormationDefinitions.xml](../data/AI/FormationDefinitions.xml) is a **whole-file override** of the vanilla catalogue: all 63 vanilla formations copied verbatim, then six of ours appended below a banner. It has to be a full copy — see the section below for why there is no merge. **Drop a vanilla formation from that file and it stops existing game-wide**, breaking every quest that names it.

> **On a game update:** re-copy `references/AI/FormationDefinitions.xml` over ours and re-append the `merc_*` block. The generator that built it is throwaway; the file is the artefact.

Six shapes, each at **four sizes** (6 / 12 / 20 / 30 spots), switched live:

| Command | Formation | Shape | Footprint at 6 → 30 |
|---|---|---|---|
| `merc_formation_column` | `merc_column*` | column of twos | 2.4 m wide, 4 → 28 m deep |
| `merc_formation_line` | `merc_doubleLine*` | two ranks abreast | 4 → 28 m wide, 2 m deep |
| `merc_formation_square` | `merc_square*` | block, square at every size | 4 → 10 m wide |
| `merc_formation_wedge` | `merc_wedge*` | cone, leader at the tip | 7 → 34 m wide |
| `merc_formation_circle` | `merc_circle*` | ring (two rings past 12) | 8 → 14 m across |
| `merc_formation_escort` | `merc_escort*` | two flanking files | 8 m wide, 4 → 28 m deep |
| `merc_formation_auto` | *(vanilla)* | the vanilla size ladder — fallback if the override isn't honoured | |

**Size the formation to the squad.** `PreferredPositions=""` means the engine drops a follower in *any* free spot, so a 30-slot template handed to six mercs scatters them across 30 m and keeps them walking to reach it. `ResolveFormationPreset` picks the smallest size that seats everyone.

### The three numbers that stop the squad milling about

| | Value | Why |
|---|---|---|
| `radius` | 1.2 (1.6 loose) | Arrival tolerance. A follower inside it is "in place" and stops correcting. At vanilla's 0.5 with a big squad **nobody is ever in place**, so everyone re-paths every tick. Vanilla only uses 0.5 for formations of 5–8; its loose and mounted presets run 1–3. |
| pitch | 2.0 m | Neighbour spacing. Must clear an NPC's footprint plus pathing slack or followers shoulder each other out of position. |
| standoff | 3.4 m | Clear gap in front of the first rank. **This is the feedback loop**: the leader is a solid body, the rank behind shoves him, the anchor moves, and every follower chases it. |

Two things worth knowing about these:

- **The ring is centred on the leader, not the player** — nothing can centre on the player, because he is never the anchor. `merc_circle30` is shifted 1.5 m forward so the ring brackets the player rather than trailing behind him, but it is still the leader's ring.
- **They only read as designed shapes under `KeepShape`.** `Relaxed` drifts and `MoveHistory` replays the leader's recorded path, so both blur the geometry. `KeepShape` is the default for exactly this reason.

`auto` exists because the override is the one part of this that is **unverified**: nothing in vanilla or any third-party mod overrides `FormationDefinitions.xml`, and unlike a behaviour tree it is loaded once at AI-system init rather than lazily on resolution, so mod-pak mount timing is untested. If the custom shapes do nothing, `merc_formation_auto` puts the squad back on vanilla presets without a rebuild.

## Moddability: shipping your own presets

**Likely: whole-file replacement only, and it has not been runtime-tested.**

There is no merge mechanism. `FormationDefinitions` is not a database table at all: the official table inventory ([KM-A-12 Database tables/README.md:33-341](../references/kcd2-mod-docs-main/official-wiki/KM-A-1%20Modding%20Kingdom%20Come%20Deliverance%202/KM-A-36%20Technical%20Overview/KM-A-3%20Structure%20of%20a%20Mod/KM-A-12%20Database%20tables/README.md), 307 rows) contains **zero** occurrences of the string "formation" — so it is not merely outside the patchable subset (208 of those 307 support patching), it is not in the list at all. It ships in `Scripts.pak`, not `Tables.pak`, so the `<tablename>__<modid>.xml` convention has no hook for it. The complete set of merge-capable mod files (`scripts/mods/<modid>.lua`, `data/libs/tables/.../<table>__<modid>.xml`, `data/quests/<modid>.xml`, `data/libs/Storm/storm__<modid>.xml`) does not include AI XML. The filename is engine-side: it appears in no vanilla XML, and [`WHGame_release_1_5.dll`](../references/kcd2-mod-docs-main/DLL/WHGame_release_1_5.dll) contains the literal `FormationDefinitions.xml` exactly once (`0x3fe3ac8`), in a bare literal pool with no directory prefix and no format specifier — so nothing in the loader could recognise a part file. (Its neighbours in the pool are `FormationSpinePointPuppet` and `C_CrimeShelver`; adjacency in a string pool is not ownership, so which class consumes it is unknown.)

**The mod-side path is `data/AI/FormationDefinitions.xml`, not `data/Scripts/AI/...`.** `Scripts/` in the mod-docs dump is the *extraction root* of `Scripts.pak`, whose own top level is `Quests/`, `AI/`, `Scripts/`, `Entities/`. `PackageMod.bat` zips `data/` with no containing folder, so `data/AI/follow.xml` becomes pak entry `AI/follow.xml` — which is why `SmartEntity__so_interrupt__mercenaries.xml` addresses it as the bare `FileName="follow.xml"`. That is the same `AI/` root vanilla uses, so a mod file there collides with the vanilla one by design.

Same-path override of an AI XML is empirically honoured — `zdjbcamping_mod` ships full copies of `AI/world/so_fireplace.xml` and `so_smokehouse.xml` (the entire vanilla files plus insertions, exactly the shape whole-file override forces). But **no mod in the reference set has ever overridden `FormationDefinitions.xml` or its sibling `LinkTagDefinitions.xml`**, and both are loaded once at AI-system init rather than lazily on tree resolution, so mod-pak mount timing relative to that init is unverified. One test settles it: add a uniquely-named formation, `MakeFormation` on it, and check a dev-build log for a resolution failure (see [dev logging](ai-modules.md) — the release exe logs nothing).

If it works, the cost is real: you must copy all 63 vanilla formations into your file or you delete the missing ones game-wide, you hard-conflict with any other mod that ships the file, and a game patch that edits it silently reverts you.

**The conflict-free alternative is reusing an existing preset name.** `MakeFormation` takes only a name string, so any preset in the loaded catalogue is available to a mod's own tree with no level data and no file collision. `followNPC` (8 spots, ±0.7 m, ranks every 1.7 m) is close to what `UpdateFormationSlots` already builds by hand; `infantryMen20` and `cavalryRiders6` cover larger bodies; `longLine` and `nextToLeader` cover small escorts.
