---
title: Behaviour trees (XGEN / MBT) reference
summary: File structure, variables, expression syntax, node catalogue, Lua nodes, functions, interrupts and timing rules of KCD2 behaviour trees, verified against vanilla.
tags: [ai, bt, lua]
kind: reference
status: current
scope: kcd2
verified: release_1_5
---

# Behaviour trees (XGEN / MBT) reference

KCD2 NPC logic runs in Warhorse's XGEN AI behaviour trees ("MBT" in KCD1 terms): XML files that
a brain's subbrain or a SmartEntity template points at. This page is the reference; the public
step-by-step guides are [basic structure](../behaviour-trees/basic-structure.md),
[combat](../behaviour-trees/combat.md), [movement](../behaviour-trees/movement.md) and
[talking](../behaviour-trees/talking.md). How trees attach to NPCs is in
[AI brains and NPCs](ai-brains-and-npcs.md); the combat decorator stack is in
[combat and perception](combat-and-perception.md).

> **TL;DR**
> - Only `<Root>` executes. `<ForestContainer>` and `<EditorData>` are editor scratch, so a raw grep over vanilla overcounts live nodes (vanilla: `Scripts/AI`, 1,457 files, 4,517 trees).
> - Conditions and `Expression` use `$var`; Lua nodes use `data.var`. Built-ins: `$__player`, `$__null`, `$this.id`.
> - Every `Loop` needs a latent node (usually `Wait`) or the game freezes; never put a latent node inside `AtomicDecorator` (vanilla does it 0 times in 376 uses).
> - `timeType="GameTime"` waits collapse during sleep/wait time skips; the only other value is `WorldTime`.
> - Fire other trees with `AddInterrupt_*`, and only after registering them as a `SmartBehaviorTemplate`. The loader and the release build fail silently, so test with the dev build.

Vanilla paths below are relative to `references/kcd2-mod-docs-main/` (the extracted `Scripts.pak`
and `Tables.pak`). Counts are **live** (inside `<Root>`) unless stated otherwise.

## Where trees live and how they are reached

| Reached from | Reference | Notes |
| --- | --- | --- |
| A brain's subbrain | `subbrain_switching` row: `file_name` + `tree_name` | Paths are relative to the `AI/` root: vanilla `npc/basic/switch/switch.xml`, tree `root` (vanilla: `Libs/Tables/ai/subbrain_switching.xml`). A mod ships its trees under `data/AI/`. |
| A mailbox group | `mailbox_group_file_name` + `mailbox_group_tree_name` | See [brains](ai-brains-and-npcs.md#brains-and-subbrains). |
| An interrupt | `SmartBehaviorTemplate` → `<TreeLocation FileName TreeName>` | Fired by name through `AddInterrupt_*`. See [interrupts](#interrupts-and-schedulers). |
| Another tree, inline | `Function_<treeName>` | Target tree has `is_function="1"`; its parameters become attributes. |
| Another tree, by file | `<IncludeTree File="'animal/animals.xml'" Name="'hitReactions'"/>` | 174 uses. |

`BehaviorTree name` must match the `tree_name` that references it exactly. One file can hold
many trees.

## File structure

```xml
<BehaviorTrees>
  <BehaviorTree name="my_tree" is_function="0">
    <Variables> <Variable name="x" type="_int" values="0" isPersistent="0" form="single" /> </Variables>
    <Parameters> <!-- only when is_function="1" --> </Parameters>
    <Root OneTimeOnly="false" FailState="Recoverable" saveVersion="2">
      <OnInit canSkip="1"> <!-- optional: runs once before Behavior --> </OnInit>
      <Behavior canSkip="1"> <!-- the logic --> </Behavior>
    </Root>
    <ForestContainer />   <!-- editor canvas; never executed -->
    <EditorData> ... </EditorData>
  </BehaviorTree>
</BehaviorTrees>
```

| Attribute | Values seen in vanilla | Meaning |
| --- | --- | --- |
| `is_function` | `0` (3,694), `1` (794) | `1` = callable as `Function_<name>` |
| `Root OneTimeOnly` | `false` (4,516), `true` (1) | `false` re-enters `Behavior` when it finishes |
| `Root FailState` | `Recoverable` (4,501), `Error` (10), `Expected` (4) | Use `Recoverable` (unverified what the others change) |
| `Root saveVersion` | `2` always | Copy as is |
| `canSkip` on `Behavior`/`Then`/`Else`/`Child`... | `1` | Copy as is |

(vanilla: census of `Scripts/AI`)

## Variables

```xml
<Variable name="target" type="_wuid" values="" isPersistent="0" form="single" />
```

| Type | Live vanilla declarations | Notes |
| --- | ---: | --- |
| `_wuid` | 5,807 | Entity/soul handle. Null is `$__null`. |
| `_bool` / `_int` / `_float` / `_string` / `_int64` | 2,628 / 719 / 512 / 1,651 / 162 | |
| `vec3` | 399 | Lua fills it component-wise |
| `enum:<name>` | many | e.g. `enum:movementSpeed`, `enum:crime_stimulusKind`; defined in `Libs/Tables/ai/ai_enums.xml` (202 enums) |
| struct types | many | e.g. `switch:interruptData:attack`, `crime:assaultData`, `followFormationParams`, `information`, `hitReaction`, `perceptionInfo`; defined in `Libs/Tables/ai/ai_types.xml` (488 types) |
| `additionalMoveParams` | 105 | `values="destChangedThreshold('200ms'),continueWhenHalting(true)"`; also `stuckThreshold(5)` (1 use, `profession/farmer/so_field.xml`) |
| `pathFindingParams` | 138 | `values="usePaths(false),useSmartObjects(false),useGeneratedNSO(true)"` |

- **`form`**: `single`, `array`, `associative` (142), `custom_associative` (34).
- **`isPersistent`**: `0` in 15,087 declarations, `1` in 220. The public guide says `1` saves the value
  with the game; the old context doc says it survives the behaviour being interrupted and restarted.
  Neither is verified; treat the exact semantics as `(unverified)`.
- **Parameters** (`is_function="1"` trees) add `requirementType`: `In` (3,621), `ConstReference`
  (421; the caller can rewrite it while the tree runs, see [formations](formations.md#changeformation-re-shaping-without-invalidating-handles)),
  `Out` (264), `Reference` (136), `ForwardDeclaration` (98; a variable the calling tree must declare).

### Built-in variables

| Variable | Live uses | Meaning |
| --- | ---: | --- |
| `$__player` | 3,175 | Player WUID |
| `$this.id` / `$this.name` | 5,318 / 88 | This NPC's WUID / entity name. Read-only |
| `$__object.id` | 2,517 | The smart object / SmartEntity the behaviour runs on |
| `$__null` | 1,216 | Null WUID. Compare against it; Lua `nil` does not clear a `_wuid` (see [gotchas](#gotchas)) |
| `$__resource.id` | 329 | The behaviour's resource object (inferred from its use as a `Move` destination) |
| `$__value`, `$__key` | 111, 10 | Current element inside array conditions (`FindInArray`, `EraseFromArray`) |
| `$__playerDog` | 56 | Player's dog |
| `$__bodyInfo.isMonsterLod` | 4 | True when the NPC is in MonsterLOD (vanilla: `Scripts/AI/world/so_fireplace.xml`) |
| `$data:script_param['name'].value` | 431 | A `Libs/Tables/ai/ScriptParams.xml` value, e.g. `combat_moraleForCombat` |

## Expression and condition syntax

```xml
<Expression expressions="$a = 1 &#10;$b = $a + 1 &#10;$count += 1" />
<IfCondition failOnCondition="false" condition="$target ~= $__null &amp; #enemies &gt; 0 | ~$busy" />
```

| Syntax | Meaning | Vanilla example |
| --- | --- | --- |
| `&#10;` (or `,&#10;`) | Separates statements; also lets a condition span lines | everywhere |
| `~` / `==` / `~=` | NOT / equal / not equal | |
| `&amp;` / `\|` | AND / OR. Raw `&`, `<`, `>` break the XML | |
| `&lt;` `&gt;` `&lt;=` `&gt;=` | comparisons | `#searchPoints &lt; 3` |
| `+=` | compound assignment | `$priority += $priorityBoost` |
| `#arr` | array length | `#areas &gt; 0` |
| `$arr[$i]` | array element | `$controllers[$index]` |
| `$s.field` | struct member | `$attackData.target` |
| `$enum:type.value` | enum literal | `$enum:crime_stimulusKind.combat` |
| `'text'` | string literal; `$var` inside it **is interpolated** | `Pattern="'followNPC_leader_$this.id'"` |
| `'500ms'`, `'2s'`, `'-1'` | durations; `'-1'` = forever | `Wait duration="'-1'"` (1,763 uses) |
| `//` comment | allowed inside multi-line conditions | `crime/*.xml` |

## Node catalogue

The most used and most useful live vanilla nodes, grouped. Count = live uses in vanilla.
Attribute lists are the ones vanilla actually writes. Nodes not listed here: grep
`Scripts/AI` for real usage before trusting a guessed attribute, because
**misspelled or unknown attributes are silently ignored** (see [gotchas](#gotchas)).

### Flow control

| Node | Uses | Key attributes | Semantics / traps |
| --- | ---: | --- | --- |
| `Sequence` | 9,824 | | Stops at the first failing child |
| `Selector` | 636 | | Stops at the first succeeding child. Pair with `Wait` as a retry gate |
| `Parallel` | 1,376 | `successMode`, `failureMode` = `Any` / `All` | Runs children together. `Any`/`Any` is the watchdog shape: a sibling that `Fail`s ends the whole thing |
| `Loop` | 1,104 | `count` (`-1` = forever) | Must contain a latent node |
| `LoopUntil` | 124 | `until`, `attemptCount` | |
| `While` | 530 | `condition`, `doFail`, `propagateChildFail` | |
| `For` / `ForEach` | 76 / 335 | `startIndex`, `endIndex` (`-1` = end), `step`, `array`, `value`, `iterator`, `break` | `break` var set true exits early |
| `IfCondition` | 4,489 | `condition`, `failOnCondition` | `failOnCondition="true"` fails when false; `false` just skips |
| `IfElseCondition` | 1,463 | `condition`, `failOnCondition` + `<Then>`/`<Else>` | |
| `Switch` | 594 | children: `IfCondition`s + `<DefaultBranch>` | First matching case wins |
| `ContinuousSwitch` | 193 | children: conditions | Re-evaluates every tick and switches immediately; case order matters |
| `SuppressFailure` | 1,004 | | Child failure becomes success |
| `Invertor` | 16 | | Flips result |
| `Success` / `Fail` / `ErrorNode` | 1,709 / 175 / 253 | `ErrorNode Message` | |
| `FuseBox` | 632 | `StatusPropagation` (`Child`/`Success`/`CleanUp`), `OneCleanup` + `<Child>`, `<OnSuccess>`, `<OnFail>` | Cleanup runs on success or failure of the child only |
| `SubtreeDecorator` | 56 | `<Init>`, `<Subtree>`, `<Cleanup>` | `Cleanup` runs on **any** exit including an external interrupt; prefer it for resources |
| `AtomicDecorator` | 376 | | Children run as one step. Never put a latent node inside |
| `RandomGate` | 120 | `opensWithChance` + `Then`/`Else` | |

### Waiting and gating (latent)

| Node | Uses | Key attributes | Notes |
| --- | ---: | --- | --- |
| `Wait` | 4,059 | `duration`, `timeType`, `doFail`, `variation`, `skipInLOD` | Add `variation` when many NPCs run the same tree, or they all tick together |
| `WaitAction` | 1,003 | | Waits for the running action/animation (e.g. inside `StanceElement`) |
| `Timeout` | 28 | `duration`, `timeType`, `doFail` | |
| `IfGate` | 490 | `condition`, `atomic`, `RunLogic` | `RunLogic="Halt"` blocks until true; `"KeepRunning"` runs child while true |
| `EntityContextBarrier` | 152 | `context`, `target`, `Negation`, `RunLogic` | Gate on an active context |
| `DistanceGate` / `DistanceCondition` | 328 / 278 | `Origin`, `ReferencePt`, `Low`, `High`, `Negation` | |
| `IsInsideAreaWithLabelBarrier` | 47 | `Who`, `Label="'interior'"`, `Negation` | Area labels, see [world and physics](world-and-physics.md) |
| `DetailBehaviorBarrier` | 5 | `RunLogic` | Runs only while the NPC is in AI Detail tier; it reads the tier, never raises it |
| `ExternalLock` / `SetExternalLock` | 131 / 287 | `LockManagerType` (`Local`/`Global`/`Intellect`), `LockName`/`SemaphoreName` | Opener and closer must use the same `LockManagerType` or it fails open |
| `Semaphore` / `Synchronize` | 135 / 262 | `SemaphoreCount`, `SemaphoreName`, `LockManagerType` | 1-count semaphore = leader election |

### Data

| Node | Uses | Key attributes |
| --- | ---: | --- |
| `Expression` | 5,520 | `expressions` |
| `ReinitVariable` | 144 | `variable` (reset to declared default) |
| `PushToArray` / `EraseFromArray` / `FindInArray` | 119 / 53 / 67 | `array`, `value`, `direction`; `condition="$__value == $x"`; `keyOut` |
| `GetTime` | 172 | `TimeType`, `OutVar`, `Delta` |
| `MeasureDistance` | 86 | `position1`, `position2`, `mode` (`ThreeDimensions`/`TwoDimensions`), `result` |
| `GenerateRandomInteger` / `RandomItem` | 32 / 53 | `lowerBoundary`, `upperBoundary`, `result` / `Array`, `Result` |
| `Concatenation` | 106 | `Pattern`, `OutString` |
| `GetRandomPos` | 33 | `StartPos`, `MaxRange`, `navAgentType`, `pathFindingParams` |

### Lua

| Node | Uses | Notes |
| --- | ---: | --- |
| `ExecuteLua code="..."` | 350 | See [Lua in trees](#lua-in-trees) |
| `LuaGate code="return ..."` | 56 | Condition from a Lua boolean, e.g. `return entity:IsMountLegal()` |
| `LuaWrapper onEnter="..." onExit="..."` | 39 | Lua on entering and leaving its child |

### Calls, messages, contexts

| Node | Uses | Notes |
| --- | ---: | --- |
| `Function_<tree>` | many | Attributes = the callee's `Parameters` plus `nodeLabel` (any unique number) |
| `IncludeTree` | 174 | `File`, `Name` |
| `CallDecorator_<tree>` | ~150 | Function call whose children fill named callback slots (e.g. `<Attack>`, `<LookAround>`). Semantics `(unverified)` |
| `CallBehavior` | 105 | `Target`, `BehaviorName` |
| `AddInterrupt` / `AddInterrupt_attack` / `_arrest` / `_report` ... | 21 / 3 / 3 / 3 | See [interrupts](#interrupts-and-schedulers) |
| `ProcessMessage` | 383 | `inbox="'hitReaction'"`, `variable`, `timeout`, `condition`. Inboxes: `hitReaction` (60), `perceptionInfo` (43), `dialogMailbox` (7), ... |
| `InstantSendMessageToNPC` / `SendMessageToNPC` | 253 / 11 | `target`, `type`, `variable` |
| `ClearInbox` | 55 | `inbox` |
| `EntityContext` / `EntityContextElement` | 746 / 362 | `context`, `target`: context is active while the child runs |
| `EntityContextCheck` | 1,208 | `context`, `target` + `Then`/`Else` |
| `EntityContextPreset` / `AnyDecorator preset` | 125 / 345 | Apply a `ScriptContextPreset.xml` bundle |
| `RelationContext` / `GameContext` / `GameContextCheck` | 21 / 56 / 98 | Relation- and game-class contexts |
| `LogToConsole` | 71 | `LogLevel`, `Message` (not `text`) |

### Movement and animation

| Node | Uses | Key attributes / notes |
| --- | ---: | --- |
| `Move` | 811 | `destinationSpecification` (WUID; `2`/`3` for flee distance), `speed`, `stopWithinDistance`, `stopDistanceVariation`, `changeNPCState`, `additionalParams`, `pathFindingParams`. Ends on arrival |
| `ExactMove` | 626 | adds `directionType` (`AlignWithEntity`/`FromVariable`), `precise` |
| `Turn` / `ForceLook` | 367 / 322 | `target`, `align` / `LookTarget` |
| `MoveParamsDecorator` | 181 | `speed`, `pathFindingParams`. Not around combat, see [combat](combat-and-perception.md#the-combat-stack) |
| `UrgencyDecorator` | 232 | `Urgency` (`Instant`/`Fast`/`Slow`) |
| `CrimeFollower` | 83 | `Target`, `Role` (`Main`/`Assist`), `RelativeSpeedLimit`, `DisableGhosting`, `BlockWay`. Vanilla `RelativeSpeedLimit` values are only `Dash` 56, `Walk` 18, `AlertedWalk` 6, `Run` 2 (+1 variable). Never returns on its own; reported to run only inside a fired interrupt behaviour (bandit-camp-quest, claimed) |
| `StopMovement` / `TeleportAction` | 30 / 96 | `waitUntilStopped` / `Position` |
| `StanceElement` | 486 | `smartObject`, `stance`, `allowAny`; holds a sit/lie stance while its child runs |
| `UnstanceAction` / `UnstanceElement` | 995 / 144 | `unstance`, `locationObject`; use `Element` to hold a pose |
| `AnimationAction` | 534 | `fragment`, `tags`, `alignObject` |
| `DisableCollisionAvoidance` | 25 | Turns avoidance off; there is no node to turn extra avoidance on |

`speed` takes `enum:movementSpeed`: `RelaxedWalk`=0, `Walk`, `AlertedWalk`, `Run`, `FastRun`,
`SlowSprint`, `ModerateSprint`, `Sprint`, `SlowestDash`, `SlowDash`, `ModerateDash`, `Dash`=11
(vanilla: `lua_dump_state/LuaState_Sorted.txt`). Live use: `Walk` 1,033, `Run` 245, `AlertedWalk` 96,
`Sprint` 65, `RelaxedWalk` 43, `FastRun` 33, `Dash` 20. There is no gait above `Dash`; faster needs a
speed buff (see [companions](ai-brains-and-npcs.md#companions-and-followers)). Ordinal order is not speed order
proof: whether `Sprint` or `Dash` is faster in game is `(unverified)`.

`changeNPCState="true"` is what vanilla uses for every move to a fixed point: 809 of 854 raw `Move` nodes; the 45
`false`s continuously follow a moving actor (vanilla census, camp).

### Links and graph search

`GraphSearch` (2,477) walks entity links with filter children (`LinkTagFilter` 2,154,
`WUIDFilter`, `SoulIsAliveFilter`, `EntityClassFilter`, `ItemParamFilter`...) and collects results
with `Nodalyzer`/`Datalyzer`. `AddLink`/`RemoveLink` (`From`, `To`, `Tag`, `LinkOpHandleMode`)
edit links at runtime. A mod may use its own link tag without declaring it anywhere
([formations](formations.md#link-tags-need-no-declaration)).

Combat, formation and perception nodes are catalogued in
[combat and perception](combat-and-perception.md).

## Lua in trees

```xml
<ExecuteLua code="local ok, err = pcall(function() &#10;  -- safe: this comment ends at the encoded newline &#10;  data.tooClose = data.dist &lt; 5 &#10;end) &#10;if not ok then System.LogAlways('[MyMod] ' .. tostring(err)) end" />
```

- `data.<var>` reads and writes declared tree variables; `data.this.id` is this NPC's WUID
  (vanilla: `ExecuteLua` census). `entity` is the NPC's script table.
- `$var` syntax does not work inside Lua; `data.var` does not work inside `Expression`.
- **Line breaks.** A raw newline inside an XML attribute is normalised to a space by the XML parser,
  so a `--` comment then swallows everything after it and the node logs
  `[ExecuteLua]: Can't run uncompilable lua code` every tick. Encode newlines as `&#10;` (vanilla
  does, with `--` comments, in 12 live nodes, e.g. `Scripts/AI/crime/calculatePunishment.xml`) or
  use `--[[ ]]`. The public guide's "the parser treats `--` specially" and the old context doc's
  "attribute normalisation" describe the same symptom; the vanilla files support the
  normalisation explanation.
- Escape `<` `>` `&` as `&lt;` `&gt;` `&amp;` inside `code`.
- Wrap anything non-trivial in `pcall`; an error kills that tick of the tree (community guide).
- `ExecuteLua` is reported to recompile its code on every run, so prefer `Expression` for plain
  assignments (community guide, `(unverified)`).
- The global `player` is not reliably set inside tree Lua; pass `$__player` into a variable
  (old context doc, `(unverified)`).
- `entity:SetPos` called from the NPC's **own** `ExecuteLua` does not stick; from a Lua timer it does
  (verified in game: camp-forge).
- From outside, talk to a tree through its inbox:
  [`XGenAIModule.SendMessageToEntity`](api/XGenAIModule.md#sendmessagetoentity) /
  [`SendMessageToEntityData`](api/XGenAIModule.md#sendmessagetoentitydata) (vanilla:
  `Scripts/Scripts/Entities/Doors/AnimDoor.lua`), or through Lua tables the tree polls. General Lua
  environment: [Lua scripting](lua-scripting.md).

## Functions and subtrees

A tree with `is_function="1"` and a `<Parameters>` block is called as `Function_<name>`:

```xml
<Function_crime_getMrkev mrkev="$mrkev" nodeLabel="123" />
```

Callee `crime_getMrkev` is `Scripts/AI/crime/getMrkev.xml`. `nodeLabel` just has to be a number.
`Out`/`Reference` parameters write back into the caller's variables.

## Interrupts and schedulers

An **interrupt** suspends the NPC's switch tree and runs a named behaviour. The name must exist
as a `SmartBehaviorTemplate` (see [SmartEntity](ai-brains-and-npcs.md#smartentity-and-smartbehaviortemplate)),
or the engine logs `[AddInterrupt]:Specified behavior doesn't exist on any smart entity` and the
NPC stands still (vanilla + verified in game: aleksej).

```xml
<AddInterrupt_attack attackData="$attackData" Target="$this.id" Host="$mrkev"
    Behavior="'combat_melee'" Priority="160" IgnorePriorityOnPreviousInterrupt="true"
    urgency="Fast" Aliveness="Alive" Privileged="false" FastForward="false" />
```

The full attack-interrupt boilerplate (`Function_crime_getMrkev`, `CreateInformationWrapper`,
`attackData` fields) is in [combat and perception](combat-and-perception.md#starting-a-fight).
Plain `AddInterrupt` (21 live uses, `Scripts/AI/autotest/scheduler.xml`) takes the same attributes
without `attackData`.

Facts that decide scheduler design (all verified in game in the mod):

- `IgnorePriorityOnPreviousInterrupt="true"` makes a re-fire **replace** the running behaviour and
  run its `OnFail`. Re-firing is not free: it restarts the approach and replays any draw animation
  (ai-modules, foe-ai).
- An interrupt is applied on a **later** engine update, not when queued. Two scheduler arms on
  independent timers can race: an eviction queued by one lands after the other started the
  behaviour (formations).
  The race grows with NPC count.
- A behaviour that wraps itself in `EntityContext context="crime_interruptAttack"` can be read as
  "in combat" by any scheduler (`EntityContextCheck`) or Lua (`soul:HasScriptContext`).
- There is no failure signal when an interrupt is refused. A self-healing pattern: the behaviour
  calls a Lua heartbeat every ~700 ms; a Lua tick re-fires when the heartbeat is stale
  (foe-ai).
- A proven scheduler shape: `Parallel` of three loops (sense, pick, and a `ContinuousSwitch` that
  fires) (quartermaster).

## Entity contexts

Script contexts are named flags with a class (`Entity`, `Relation`, `Game`) and an optional
C++ `SideEffect`, all declared in `Libs/Tables/ai/ScriptContext.xml`; presets (bundles) are in
`ScriptContextPreset.xml`.

| Want to | Use |
| --- | --- |
| Set while a subtree runs | `EntityContext` / `EntityContextElement` / `RelationContext` / `GameContext` |
| Branch on it | `EntityContextCheck`, `EntityContextBarrier`, `RelationContextCheck`, `GameContextCheck` |
| Read from Lua | [`soul:HasScriptContext(name)`](api/Soul.md#hasscriptcontext): read-only, no Lua setter |
| Set from a quest | Skald `SetEntityContext` / `SetGameContextPreset` ([skald](skald-quests-dialog.md)) |

The combat and crime contexts are listed in
[combat and perception](combat-and-perception.md#script-contexts).

## Time

- `timeType`/`TimeType`/`TimerType` take `GameTime` (4,794 + 154 + 660 uses) or `WorldTime`
  (22 + 36 + 2). The binary registers no other name for this enum (retail binary: strings
  `GameTime`/`WorldTime` referenced from `sub_252750`). A `RealTime` value, suggested in
  interior-detection, does not
  exist in vanilla or the binary; treat it as wrong.
- A long `GameTime` wait **expires almost instantly during sleep/wait time skips**, and a loop
  gated by it free-runs (measured: 61 bark calls in one sleep) (verified in game:
  squad-orders). Gate such loops with
  a Lua real-time floor too.
- The map / fast-travel screen freezes all tree execution; watchdogs that see "every NPC stale at
  once" must stand down (verified in game: formations).

## Debugging trees

- Only the modding-tools **dev build** logs rejected nodes and Skald failures to `KCD2Mod\kcd.log`;
  the release build is silent. See [debugging](debugging.md).
- `LogToConsole Message="'...'"` from the tree; `System.LogAlways` from `ExecuteLua`.
- Read vanilla: every mechanic is in `Scripts/AI`. Before copying, check the node is under
  `<Root>`, not `<ForestContainer>`.

## Gotchas

- **Game freezes or hangs** when a `Loop` contains no latent node (`Wait`, `Move`, a gate...). 77 of
  1,104 vanilla loops have none because they rely on a latent child elsewhere; do not copy that
  without understanding it (public guide + vanilla census).
- **Tree deadlocks / engine freezes** when `Wait`, `Move`, `Turn` or another latent node sits inside
  `AtomicDecorator`. Vanilla never does it (0 of 376) (public guide, old context doc).
- **Lua node spams "Can't run uncompilable lua code"** when a `--` comment sits on a raw line break
  in `code`. Use `&#10;` or `--[[ ]]`.
- **A typo'd attribute does nothing** and loads without error; vanilla itself passes undeclared
  attributes to `Function_` calls (verified in game: aleksej). `LogToConsole` takes
  `Message`, not `text`.
- **A `_wuid` never reads back as nil in Lua** once set, and `data.x = nil` does not clear it. Clear
  with `Expression "$x = $__null"` and test nulls tree-side; publish a separate bool from Lua when
  Lua owns validity (verified in game: quartermaster,
  formations).
- **NPC stands still after `AddInterrupt_attack`** when the `Behavior` name has no
  `SmartBehaviorTemplate`; if the tree's "already fired" flag is set regardless, it retries forever
  silently.
- **Behaviour dies right after starting** when another arm queues an interrupt in the same window
  (interrupts land a tick later). Scope re-kicks to NPCs that need them, and stagger them.
- **Loop free-runs during sleep** when paced by a long `GameTime` wait.
- **A stopped NPC freezes at a point** with `Move changeNPCState="false"`; that value is for
  continuously following a moving actor. `changeNPCState="true"` inside a Switching tree reportedly
  crashes it (community guide, `(unverified)`).
- **A pose keeps playing after the tree is torn down** when held with `UnstanceAction` (it returns
  immediately). Use `UnstanceElement` or `StanceElement` around the hold.
- **Multi-waypoint walker halts at every point** when a `Loop` re-issues `Move` at the point it just
  reached; aim ahead instead. Shrinking the arrival radius makes `Move` fail, and inside a
  `Parallel failureMode="Any"` takes the whole tree down (verified in game:
  walls-and-sieges).
- **`Move` to a spawned `BasicEntity` does nothing**: `BasicEntity` is not AI-targetable. Move to a
  `vec3` instead (verified in game: camp).
- **Many NPCs lag-spike together** when they share a tree with an un-varied `Wait`.
- **A scheduler stops re-firing a behaviour after some fights but not others**: a latch (`$isIdleActive`-style bool) is
  cleared by only one of the paths into the state it guards. Clear it wherever the state is entered, e.g. in the
  combat-detection loop as well as in the arm that starts a fight (verified in game:
  quartermaster).
- **A follower dashes to re-acquire its station over and over**: a time-boxed `CrimeFollower` is being restarted; it never
  returns on its own, so end it on a change of state, not a timer (bandit-camp-quest).

## See also

- Public guides: [basic structure](../behaviour-trees/basic-structure.md), [combat](../behaviour-trees/combat.md),
  [movement](../behaviour-trees/movement.md), [talking](../behaviour-trees/talking.md).
- Mod war stories: ai-modules, foe-ai,
  formations, squad-orders, camp.
- Community: KCD1 MBT overview, still a valid mental model (community: https://wiki.nexusmods.com/index.php/MBT_Trees).
