# Behaviour Trees: Basic Structure

This is the part of KCD2 modding with the smallest amount of documentation. That being none. Everything I have learned is from reverse engineering vanilla behaviour trees. My knowledge may be incomplete and inaccurate, and my only credential is the mercenaries mod, which does what it is supposed to.

---

## What is a Behaviour Tree?

It is the brain of every NPC in KCD2. It handles NPCs walking around the open world, talking with each other, and reacting to the player. It also handles a large amount of quest-related behaviour — the soldiers climbing the walls at Neuhof? Behaviour trees. The sheep Ignaz following you if you have a carrot in your inventory? Behaviour trees. Guiding an NPC through a tunnel? Behaviour trees.

Behaviour tree nodes fall into a few broad categories:

- **Logic** — conditionals, loops, switches, and other flow control
- **Functions** — calling other behaviour trees, calling C++ functionality directly, or invoking other game systems
- **Lua execution** — the `ExecuteLua` node, which lets you run arbitrary Lua code directly inside the tree
- **Concurrency** — `Parallel`, `AtomicDecorator`, and friends, for doing multiple things at once

---

## Basic Structure

If your NPC brain is referencing your behaviour tree correctly, the top-level file should look like this:

```xml
<?xml version="1.0" encoding="us-ascii"?>
<BehaviorTrees>
    <BehaviorTree name="onUpdate" is_function="0">
        <Variables>
            <Variable name="testvar" type="_int" values="" isPersistent="0" form="single" />
        </Variables>
        <Root OneTimeOnly="false" FailState="Recoverable" saveVersion="2">
            <Behavior canSkip="1">
                <!-- your logic goes here -->
            </Behavior>
        </Root>
        <ForestContainer />
    </BehaviorTree>
</BehaviorTrees>
```

Key attributes:

- **`name`** on `BehaviorTree` — this is the exact string referenced by `tree_name` in your `subbrain_switching` and `mailbox_group` definitions. It must match exactly.
- **`is_function`** — set to `1` if this tree is meant to be called as a node (`<Function_yourtree />`) from another tree. Set to `0` for a root tree that runs on its own.
- **`Variables`** — declares every variable your tree uses. See the Variables section below.
- **`Root`** — the entry point. `OneTimeOnly="false"` means the root re-evaluates continuously. `FailState="Recoverable"` means a failure won't permanently break the tree.
- **`<Behavior canSkip="1">`** — contains all your actual logic, executed top to bottom.
- Everything below `</Root>` (`ForestContainer`, editor metadata) is fluff and can be ignored.

You can have multiple `<BehaviorTree>` nodes inside one `<BehaviorTrees>` file.

---

## Variables

Variables are declared in the `<Variables>` block and typed. The most common types are:

| Type | Description |
|------|-------------|
| `_int` | Integer |
| `_float` | Float |
| `_bool` | Boolean |
| `_wuid` | World-unique entity ID (used for targeting entities) |
| `additionalMoveParams` | Movement parameter bundle |
| `pathFindingParams` | Pathfinding parameter bundle |

```xml
<Variables>
    <Variable name="distanceToPlayer" type="_float" values="0"     isPersistent="0" form="single" />
    <Variable name="inCombat"         type="_bool"  values="false" isPersistent="0" form="single" />
    <Variable name="enemiesArray"     type="_wuid"  values=""      isPersistent="0" form="array"  />
</Variables>
```

- `form="single"` for a single value, `form="array"` for a list
- `isPersistent="1"` saves the variable to disk across sessions; `0` resets on load
- `values` sets the default value

There are two ways to read and write variables at runtime:

```xml
<ExecuteLua code="data.testvar = 67" />
```

```xml
<Expression expressions="$testvar = 67" />
```

Prefer `Expression` over `ExecuteLua` for simple assignments. `ExecuteLua` requires the code to be compiled each time and has more overhead. Use it when you need actual Lua logic.

### Parameters

If your tree has `is_function="1"` and needs to receive arguments when called, declare them under a `<Parameters>` block immediately after `</Variables>`:

```xml
<Parameters>
    <Variable name="attackData" type="switch:interruptData:attack" values="" isPersistent="0" form="single" requirementType="In" />
</Parameters>
```

This is only necessary when calling the tree as a function from another tree and passing data in.

---

## Logic

### Sequence

Chains nodes together sequentially. Stops and fails as soon as any child node fails, unless wrapped in `SuppressFailure`.

```xml
<Sequence>
    <NodeA />
    <NodeB />
    <NodeC />
</Sequence>
```

### Loop

Repeats its child node. `-1` means infinite repetitions.

```xml
<Loop count="-1">
    <Sequence>
        <!-- ... -->
        <Wait duration="'500ms'" timeType="GameTime" doFail="false" variation="" />
    </Sequence>
</Loop>
```

Every loop must contain at least one `Wait` node with a non-zero duration. See the Concurrency section for why.

### SuppressFailure

Forces the tree to continue even if the wrapped node fails. Without this, a failing node can cause the entire tree to exit.

```xml
<SuppressFailure>
    <SomeNodeThatMightFail />
</SuppressFailure>
```

### IfCondition

Executes its child only if the condition is true.

```xml
<IfCondition failOnCondition="false" condition="~$inCombat">
    <!-- executed when NOT in combat -->
</IfCondition>
```

- `failOnCondition="true"` — the entire tree fails if the condition is not met
- `failOnCondition="false"` — if the condition is not met, execution simply skips this node and continues

Condition syntax:

| Operator | Meaning | XML encoding |
|----------|---------|--------------|
| `~` | NOT | — |
| `==` | equals | — |
| `~=` | not equals | — |
| `== $__null` | null check | — |
| `&gt;` | greater than | `>` would break XML |
| `&lt;` | less than | `<` would break XML |
| `\|` | OR | — |
| `&amp;` | AND | `&` would break XML |

You cannot write `<`, `>`, or `&` directly in a condition string — the XML parser will treat them as markup. Use the encoded forms.

### IfElseCondition

```xml
<IfElseCondition failOnCondition="false" condition="$playerTarget ~= $__null &amp; ~$isFriendly" saveVersion="2">
    <Then canSkip="1">
        <!-- condition is true -->
    </Then>
    <Else canSkip="1">
        <!-- condition is false -->
    </Else>
</IfElseCondition>
```

### For

Iterates over an array variable.

```xml
<For startIndex="0" endIndex="-1" step="1" array="$enemiesArray" iterator="" value="$candidate" break="$foundTarget">
    <!-- $candidate holds the current element each iteration -->
    <!-- sets $foundTarget = true to break early -->
</For>
```

- `endIndex="-1"` iterates to the end of the array
- `break` — the loop exits early if this variable becomes `true`
- `value` — the variable that receives the current element each iteration

---

## Functions: Calling Another Behaviour Tree (Interrupts)

The most common reason to call another behaviour tree is to trigger a combat interrupt. First, register the target tree as a `SmartBehaviorTemplate` in your `SmartEntity__so_interrupt__yourmodid.xml` as described in [make-npc-brain.md](make-npc-brain.md). Then use this sequence to fire it:

```xml
<Sequence>
    <SuppressFailure>
        <Function_crime_getMrkev mrkev="$mrkev" nodeLabel="1234" />
        <CreateInformationWrapper Label="'assault'" PerceivedWuid="$this.id" PositionType="positionWuid" PositionVec3="" PositionWuid="$__player" Information="$crimeInformation" />
        <LockDynamicInformationValues Information="$crimeInformation">
            <SetDynamicInformationValue Information="$crimeInformation" Tag="'stimulusKind'" Variable="$enum:crime_stimulusKind.combat" Type="" Value="" />
        </LockDynamicInformationValues>
        <Function_crime_limits_reserveReactionLink ffCrimeIcon="false" information="$crimeInformation" priority="160" reactionKind="$enum:crime_reactionKind.attack" nodeLabel="898990" />
    </SuppressFailure>
    <Expression expressions="$attackData.target = $__player &#10; $attackData.information = $crimeInformation &#10; $attackData.stimulusKind = $enum:crime_stimulusKind.combat &#10; $attackData.previousReaction = $enum:crime_reactionKind.unknown &#10; $attackData.initiatedBy = $enum:switch_interruptInitiator.switch &#10; $attackData.defenceMode = false &#10; $attackData.relationOverride = true &#10; $attackData.source = $enum:crime_source.direct &#10; $attackData.freshlyAttributedCrime = false &#10; $attackData.criminalFreshness = $enum:crime_criminalFreshness.unknown &#10; $attackData.escalatedFromFailedSurrender = false" />
    <AddInterrupt_attack attackData="$attackData" Target="$this.id" Host="$mrkev" Behavior="'YOUR_BEHAVIOUR_NAME'" Priority="160" IgnorePriorityOnPreviousInterrupt="true" urgency="Fast" Aliveness="Alive" Privileged="false" FastForward="false" />
</Sequence>
```

`YOUR_BEHAVIOUR_NAME` must match the `Name` attribute on the `SmartBehaviorTemplate` in your SmartEntity file. The variables `attackData`, `mrkev`, and `crimeInformation` must be declared in your `<Variables>` block. Use the mercenaries mod as a reference for exact type declarations.

This looks hacky. It is. It also works flawlessly, and it's a copy-and-paste operation.

---

## Executing Lua Code

`ExecuteLua` is the most powerful node in the tree. Put any Lua in there and it will run.

```xml
<ExecuteLua code="data.inCombat = true" />
```

A few important rules:

- `data.varname` — reads and writes a variable declared in `<Variables>` from inside Lua. Use this instead of `$varname` syntax, which only works in `Expression` and condition strings.
- `_G.YOURVARNAME` — sets a global variable that persists for the current session. Define it without a `local` keyword: `_G.MercenariesDismissed = true`. Functions defined in your mod's Lua scripts can be called normally.
- Characters like `<` and `>` must be XML-encoded as `&lt;` and `&gt;` inside the `code` attribute, or the XML parser will error.
- **Never use `--` Lua comments inside a `code=""` attribute.** The behaviour tree parser sees `--` and treats everything after it as a comment at the parser level, before Lua even runs. This produces uncompilable code that will spam your log at whatever rate the node ticks. Use XML `<!-- -->` comments outside the `ExecuteLua` node instead.
- Wrap non-trivial code in `pcall` to prevent a Lua error from killing the entire behaviour tree tick.

```xml
<ExecuteLua code="
    local ok, err = pcall(function()
        local dist = data.distanceToPlayer
        if dist &lt; 5.0 then
            data.tooClose = true
        end
    end)
    if not ok then System.LogAlways('[MyMod] error: ' .. tostring(err)) end
" />
```

---

## Concurrency

The `Parallel` node runs all of its children simultaneously:

```xml
<Parallel successMode="Any" failureMode="Any">
    <Loop count="-1">
        <!-- branch A -->
        <Wait duration="'150ms'" timeType="GameTime" doFail="false" variation="" />
    </Loop>
    <Loop count="-1">
        <!-- branch B -->
        <Wait duration="'100ms'" timeType="GameTime" doFail="false" variation="" />
    </Loop>
</Parallel>
```

- `successMode="Any"` — the `Parallel` succeeds as soon as any one child succeeds
- `failureMode="Any"` — the `Parallel` fails as soon as any one child fails

### Wait

```xml
<Wait duration="'500ms'" timeType="GameTime" doFail="false" variation="'100ms'" />
```

Every loop must contain at least one `Wait` with a non-zero duration. Without it the loop executes infinitely fast, which will freeze or crash the game. Always add a small `variation` value if you have many instances of the same behaviour tree running simultaneously — otherwise all instances tick at exactly the same moment and cause a lag spike.

### AtomicDecorator

Forces its contents to execute as a single uninterruptible unit. Other branches in a `Parallel` cannot interleave with it while it is running. It **must not** contain `Wait` nodes — doing so will deadlock the tree.

```xml
<AtomicDecorator>
    <Sequence>
        <ExecuteLua code="data.foundTarget = false" />
        <Expression expressions="$playerWUID = $__player" />
    </Sequence>
</AtomicDecorator>
```

Use `AtomicDecorator` any time you need to read and then immediately write a variable without another branch being able to read it in between.

---

## Special Variables

The engine exposes a few built-in WUID variables you can use in expressions and conditions without declaring them:

| Variable | Meaning |
|----------|---------|
| `$__player` | The player entity's WUID |
| `$__null` | Null / empty WUID |
| `$this.id` | The current NPC's own WUID |

---

## Where to Learn More

Look at vanilla behaviour trees. They are a goldmine of information and will tell you everything you need to know to implement whatever feature you want. They live in `Libs/AI/BehaviorTrees/` inside the game's data paks. Unpack them with a PAK extractor and read through them — every mechanic in the game is in there somewhere.
