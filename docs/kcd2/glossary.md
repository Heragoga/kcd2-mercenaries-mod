---
title: Glossary
summary: Disambiguation for KCD2 modding terms that mean several unrelated things, plus one-line definitions for the vocabulary a modder or agent meets across this knowledge base.
tags: [engine, ai, skald, data]
kind: reference
status: current
scope: kcd2
verified: release_1_5
---

# Glossary

Two kinds of entry. [Overloaded terms](#overloaded-terms) disambiguates words that mean several
**unrelated** things in KCD2 modding — read the table before trusting a claim that uses one of
these words without saying which system it means. [Terms A–Z](#terms-az) is a flat dictionary of
the vocabulary the rest of the knowledge base uses, one term per heading so search and `kb.py show
docs/kcd2/glossary.md#<term>` both work.

## Overloaded terms

### Hibernation

"Hibernation"/"hibernate" names three unrelated things. They never interact; which one a claim
means is decided by where it appears.

| Meaning | Where it lives | How you touch it | Page link |
| --- | --- | --- | --- |
| Skald quest-graph dormancy | a `Quest`'s `HibernateMode` (`Script`/`EventPlace`/`DLC`/`ActivityType`/`Auto`) | set on the quest definition in the concept graph; not reachable from Lua | [npc-rendering-and-lod.md#quest-and-dialogue-hides](npc-rendering-and-lod.md#quest-and-dialogue-hides) |
| NPC AI-simulation sleep | `SmartBehaviorTemplate` flags `HibernateInMonsterLod`, `SkipMLODMove`, `PostponeByPlayerInMonsterLod` | set per behaviour template in a `SmartEntity__*.xml`; the "additive NPC" background-crowd machinery | [ai-brains-and-npcs.md#smartentity-and-smartbehaviortemplate](ai-brains-and-npcs.md#smartentity-and-smartbehaviortemplate), [npc-rendering-and-lod.md#ai-lod-tiers](npc-rendering-and-lod.md#ai-lod-tiers) |
| Vanilla quest-file naming convention (`hibernovana_cast` / `nehibernovana_cast`) | quest/node file names only | not an engine feature at all — an author's naming habit, easy to mistake for either row above | npc-lod.md (research log) |

### LOD

"LOD" names at least five independent systems. Fixing one says nothing about the others — raising
the AI Detail budget, for example, changes nothing the renderer draws.

| Meaning | Where it lives | How you touch it | Page link |
| --- | --- | --- | --- |
| AI simulation detail tier (Detail / LOD / MonsterLOD) | `wh_ai_LOD_*` / `WH_AI_LOD_*` cvars, `$__bodyInfo.isMonsterLod`, `DetailBehaviorBarrier` | budgets and distances via cvars (counts, not just distances); read the tier from a tree | [npc-rendering-and-lod.md#ai-lod-tiers](npc-rendering-and-lod.md#ai-lod-tiers) |
| Character mesh/clothing swap ("uberlod") | `Entity.SetLodRatio`, `wh_cc_LodForUberlod`, `wh_cc_UberlodLoadDistRatio` | set once on a character; a high ratio forces the merged low-poly outfit early ("clay puppets") | [npc-rendering-and-lod.md#renderer-view-distance-and-mesh-lod](npc-rendering-and-lod.md#renderer-view-distance-and-mesh-lod) |
| Combat system's own LOD tier | `wh_cs_ForceLod`, `wh_cs_Lod*Distance` cvars, game context `ForceCombatSystemAmbientLOD` | forced globally by the 12 scripted main-quest battles via `SetGameContextPreset` | [npc-rendering-and-lod.md#combat-system-lod-and-scripted-battles](npc-rendering-and-lod.md#combat-system-lod-and-scripted-battles) |
| Animation-controller LOD | `wh_am_LOD_*` cvars (`wh_am_LOD_Debug`, `wh_am_LOD_ForceEmitAllAnimEvents`, ...) | diagnostics and per-entity animation LOD, separate from AI or combat LOD | [npc-rendering-and-lod.md#diagnostics](npc-rendering-and-lod.md#diagnostics), [console-variables.md](console-variables.md) |
| Renderer view distance / static mesh LOD | `Entity.SetViewDistRatio`, `e_ViewDistRatio`, `$lod1_<name>`/`$lod2_<name>` mesh nodes | draw distance and static-prop mesh switching; unrelated to AI simulation | [npc-rendering-and-lod.md#renderer-view-distance-and-mesh-lod](npc-rendering-and-lod.md#renderer-view-distance-and-mesh-lod), [assets-pipeline.md#what-a-mesh-must-carry](assets-pipeline.md#what-a-mesh-must-carry) |

### Context

Three context **classes** share one registry and one set of BT/Skald verbs, and "context" alone
does not say which class or which named flag is meant.

| Meaning | Where it lives | How you touch it | Page link |
| --- | --- | --- | --- |
| Entity context | `EntityContext`/`EntityContextElement`/`EntityContextCheck`/`EntityContextBarrier` BT nodes | set while a subtree runs; read with `soul:HasScriptContext` (no Lua setter) | [behavior-trees.md#entity-contexts](behavior-trees.md#entity-contexts) |
| Relation context | `RelationContext`/`RelationContextCheck` BT nodes, Skald `SetRelationContext` | forces one soul to target another, e.g. `combat_forcedTarget` | [combat-and-perception.md#script-contexts](combat-and-perception.md#script-contexts) |
| Game context | `GameContext`/`GameContextCheck` BT nodes, Skald `SetGameContext`/`SetGameContextPreset` | global switches such as `Battle` (suppresses all dialogue) or `ForceCombatSystemAmbientLOD`; also selects a `CVarOverride.xml` cvar profile | [combat-and-perception.md#script-contexts](combat-and-perception.md#script-contexts), [npc-rendering-and-lod.md#combat-system-lod-and-scripted-battles](npc-rendering-and-lod.md#combat-system-lod-and-scripted-battles) |
| The shared registry itself | `Libs/Tables/ai/ScriptContext.xml` (named flag + class + optional C++ side effect), `ScriptContextPreset.xml` (bundles) | source of every named context above; not directly patchable data for new gameplay | [behavior-trees.md#entity-contexts](behavior-trees.md#entity-contexts) |

### Module

"Module" spans a Skald authoring concept, a family of native C++ classes, and this KB's own
shorthand for a Lua file — three different granularities of "a unit of code".

| Meaning | Where it lives | How you touch it | Page link |
| --- | --- | --- | --- |
| Skald "module" (a quest/definition's dormancy scope) | a `Quest`'s `HibernateMode` | see [Hibernation](#hibernation) above | [npc-rendering-and-lod.md#quest-and-dialogue-hides](npc-rendering-and-lod.md#quest-and-dialogue-hides) |
| C++ `wh::<name>module` classes | `xgenaimodule`, `conceptmodule`, `combatmodule`, `rpgmodule`, `entitymodule`, `dialogmodule`, `questmodule`, ... on `wh::framework::C_BaseModule` | native engine subsystems, not moddable directly; some are exposed to Lua via a same-named ScriptBind table | [engine-internals.md#engine-identity](engine-internals.md#engine-identity) |
| A mod's own Lua "module" (this KB's usage) | one file, `Script.LoadScript`ed from the mod's entry point | keep one global table per mod and prefix every extra file with the modid | [lua-scripting.md#namespace-and-module-rules](lua-scripting.md#namespace-and-module-rules) |

### State

"State" spans a saved quest-graph value, an unreachable engine enum, a physical NPC pose, and the
AI LOD tier — four things with no relation to each other.

| Meaning | Where it lives | How you touch it | Page link |
| --- | --- | --- | --- |
| Skald `State` node | `<State Name=".." TypeT="bool"><Constant .../></State>` | a persistent (saved) value in the concept graph | [skald-quests-dialog.md#concepts](skald-quests-dialog.md#concepts) |
| `enum_actorState` | a Lua runtime-dump constant (`skipTime=32`, `fastTravel=33`, `cutscene=34`, ...) | exists in the state dump, but **no Lua getter returns it** — nine candidate reads were all tried and failed | [world-and-physics.md#time-fast-travel-and-time-skips](world-and-physics.md#time-fast-travel-and-time-skips) |
| NPC stance/pose state | `GetStance Npc Stance StanceObject`, `stanceCategory` enum (`standing`, `sitting`, `kneel`, ...) | read from a tree; held with `StanceElement`/`UnstanceElement`, never a bare `UnstanceAction` | [ai-brains-and-npcs.md#smart-objects-sitting-sleeping-working](ai-brains-and-npcs.md#smart-objects-sitting-sleeping-working) |
| AI LOD "state" (Detail/LOD/MonsterLOD) | see [LOD](#lod) above | | [npc-rendering-and-lod.md#ai-lod-tiers](npc-rendering-and-lod.md#ai-lod-tiers) |

### GUID vs WUID

Not one overloaded word, but two easily-confused ones. Mixing them up is a common, silent failure
mode (see [data-tables.md gotchas](data-tables.md#gotchas)).

| Meaning | Where it lives | How you touch it | Page link |
| --- | --- | --- | --- |
| GUID | a table primary key: bare lowercase `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` | identifies a **data row** (soul, item, buff, brain, ...) that exists whether or not anything has spawned; never changes at runtime | [data-tables.md#guid-conventions](data-tables.md#guid-conventions) |
| WUID | a runtime entity handle: BT `_wuid` variable type, `$this.id`, resolved with `XGenAIModule.GetEntityByWUID` | identifies a **live spawned entity**; null is `$__null`; does not exist until something is spawned, and `tostring()` of one is not stable across ticks | [behavior-trees.md#variables](behavior-trees.md#variables) |

A soul's GUID (`guidSharedSoulId`) is what you pass to `System.SpawnEntity`; the WUID is what you
get back. GUIDs are bare everywhere **except** vanilla's `CombatDebug.SpawnFriend`/`SpawnEnemy`
console helper, which wants an `s`-prefixed (soul) / `a`-prefixed (armour preset) / `w`-prefixed
(weapon preset) 37-character form ([data-tables.md#guid-conventions](data-tables.md#guid-conventions)).

## Terms A–Z

### Area label / interior

A `TriggerArea` entity property (`Label`, semicolon-separated) that tags level geometry —
`interior`, `castle`, `stealthArea_crouch`, `private`, and roughly 40 `music_*` labels among ~112
distinct ones. Read from a tree (`IsInsideAreaWithLabel(Barrier)`), from Skald
(`AreaLabelTrigger`), or from Lua (`XGenAIModule.IsPointInAreaWithLabelWUID`, poll only).

See: [world-and-physics.md#interiors-and-area-labels](world-and-physics.md#interiors-and-area-labels)

### ASI plugin

A native DLL renamed `.asi` and loaded by a proxy such as the Ultimate ASI Loader — the only way
to reach engine internals KCD2 does not expose to Lua (navmesh writes, raw `gEnv`/vtable access).
The working pattern resolves everything by byte signature and hooks `IGame::CompleteInit`.

See: [engine-internals.md#native-plugins](engine-internals.md#native-plugins)

### Brain

The AI identity an NPC's soul points to (`brain_id`). A brain is just a GUID and a name; its
subbrains (Switching, Scheduler, SmartObject, ...) do the actual work — see [Subbrain](#subbrain).

See: [ai-brains-and-npcs.md#brains-and-subbrains](ai-brains-and-npcs.md#brains-and-subbrains)

### Brambora

The name mod files use for the Skald quest database; the engine's own internal name for the same
database is `barbora`. Both refer to the one concept graph a mod's `Quests/<modid>.xml` roots into.

See: [skald-quests-dialog.md](skald-quests-dialog.md)

### Buff

A stat modifier applied to a soul (`rpg/buff.xml`), with a `buff_class_id` (System, Perk, Injury,
Script System for mod buffs, ...), a C++ `implementation` (`Cpp:Constant`, `Cpp:Unconscious`, ...)
and a `buff_params` list like `rms*1.15` or `imm=1`. Applied with `soul:AddBuff(guid)` or the BT
`AddBuff` node.

See: [data-tables.md#buffs](data-tables.md#buffs)

### Chat menu

A compact `Dialogue Type="chat"` option list where the player keeps control — used for order
wheels and follower commands. Only four slots per level (`ChatPosition`), and only one chat can be
open on a given NPC at a time.

See: [skald-quests-dialog.md#chat-menus-typechat](skald-quests-dialog.md#chat-menus-typechat)

### Collision class

A bitmask (`PHYSICPARAM_COLLISION_CLASS`) on an entity's physics that decides which other classes
it ignores; the test is symmetric, so setting one side is enough. Bits 28+ are free for a mod's own
tag, and masks do not survive re-physicalisation (spawn, save/load, level change).

See: [world-and-physics.md#collision-classes](world-and-physics.md#collision-classes)

### Concept graph

Warhorse's own name for the Skald quest/dialogue system: a node graph of Definitions, States,
Effects and triggers. See [Skald](#skald).

See: [skald-quests-dialog.md](skald-quests-dialog.md)

### cvar

A named, typed engine setting: `System.SetCVar`/`GetCVar` from Lua, `name value` at the console, or
a `.cfg` line. 5,321 names have been recovered from the retail binary; the prefix (`wh_`, `r_`,
`ai_`, ...) hints at the owning subsystem but is not an authoritative map.

See: [console-variables.md](console-variables.md)

### Entity context

A named boolean flag class (`ScriptContext.xml`) set on one entity while a BT subtree runs
(`EntityContext`/`EntityContextElement`), read with `soul:HasScriptContext` (there is no Lua
setter). One of three context classes — see [Context](#context) above for the other two.

See: [behavior-trees.md#entity-contexts](behavior-trees.md#entity-contexts)

### FaderDialog

A dialogue module that takes control away from the player (camera fades in, participants walk into
position) — as opposed to `Dialog` (a plain E-prompt conversation) or `ForcedDialog`
(NPC-initiated). All three wrap one `<Dialogue>`.

See: [skald-quests-dialog.md#dialogue](skald-quests-dialog.md#dialogue)

### Faction / relation

`FactionTree.xml` rows carrying `<Relation target=".." reputation="-1|0|1"/>` children. Relations
are **one-directional**: your faction declaring `-1` toward a vanilla faction does not make that
vanilla faction hostile back.

See: [ai-brains-and-npcs.md#factions-and-relations](ai-brains-and-npcs.md#factions-and-relations)

### gEnv

The root pointer of the CryEngine/WHGame engine (`SSystemGlobalEnvironment*`); every subsystem
(`pScriptSystem`, `pConsole`, `pGame`, ...) hangs off it. Its address moves on nearly every game
patch, so a plugin must resolve it by signature at runtime and never hardcode the RVA.

See: [engine-internals.md#genv-and-interfaces](engine-internals.md#genv-and-interfaces)

### GUID

A table primary key — see [GUID vs WUID](#guid-vs-wuid) above.

See: [data-tables.md#guid-conventions](data-tables.md#guid-conventions)

### Level (Trosky / Kuttenberg)

KCD2 ships two separate levels, `trosecko` (Trosky) and `kutnohorsko` (Kuttenberg). Crossing
between them is a full level load: every spawned entity belongs to the level it was spawned in, and
only Lua globals carry state across the crossing. Both levels share one coordinate space.

See: [world-and-physics.md#levels-and-regions](world-and-physics.md#levels-and-regions)

### Mailbox

A named inbox a behaviour tree polls with `ProcessMessage` (`hitReaction`, `perceptionInfo`,
`dialogMailbox`, ...). Lua sends to one with `XGenAIModule.SendMessageToEntity`/
`SendMessageToEntityData`.

See: [ai-brains-and-npcs.md#mailboxes-and-messages](ai-brains-and-npcs.md#mailboxes-and-messages)

### MBT / behaviour tree

KCD1's name ("MBT trees") for what KCD2 calls XGEN AI behaviour trees: XML files under `AI/` that a
brain's subbrain or a SmartEntity template points at. Only `<Root>` executes; `<ForestContainer>`
and `<EditorData>` are editor scratch that a raw grep will overcount.

See: [behavior-trees.md](behavior-trees.md)

### mod.manifest

The one required loose file at a mod's root (`Mods/<folder>/mod.manifest`). Declares the `modid`,
`name`, `version` and an optional `supports` version gate; its `name`/`version` are written into
every savegame.

See: [mod-structure.md#modmanifest](mod-structure.md#modmanifest)

### modid

The lowercase-and-underscore key that ties a mod's files together: `mod_order.txt` entries,
`<table>__<modid>.xml` patches, `Scripts/Mods/<modid>.lua`, `Quests/<modid>.xml`, and localization
file names. Colliding with a reserved vanilla table-part name (`horse`, `perk`, `player`, ...)
silently turns a patch into a whole-file override.

See: [mod-structure.md#modmanifest](mod-structure.md#modmanifest)

### `__modid` patch

A file named `<table>__<modid>.xml` placed at the vanilla table's own path, e.g.
`Libs/Tables/rpg/rpg_param__mercenaries.xml`. Merges into the vanilla table instead of replacing
it; what the patch row must contain depends on whether the table is "old" or "new" generation.

See: [data-tables.md#patching](data-tables.md#patching)

### MonsterLOD

The coarsest AI simulation tier: virtual, hidden via an aspect-profile swap, skeleton not
evaluated, position "estimated" by periodic teleports. Distinct from the renderer's view-distance
culling and from the combat system's own LOD tier — see [LOD](#lod) above, and
[Hibernation](#hibernation) for its `HibernateInMonsterLod`-style flags.

See: [npc-rendering-and-lod.md#ai-lod-tiers](npc-rendering-and-lod.md#ai-lod-tiers)

### Navmesh

The Recast/Detour walkable-surface data KCD2 bakes offline per level (`recast.pak`). Nothing
spawned at runtime ever enters it and the "rebuild" cvars (`wh_ai_RebuildNavmesh` and friends) are
stubs; runtime obstacle avoidance and the `AI.*` steering binds are the only mod-reachable levers.

See: [world-and-physics.md#navmesh](world-and-physics.md#navmesh)

### Objective

The smallest quest unit shown in the journal: a Skald `State` plus a visualising node inside the
`Quest` definition. Its map marker binds to whichever NPC carries the target soul at the moment the
objective's `Started` log fires, and does not re-bind if that soul is later respawned.

See: [skald-quests-dialog.md#quests-objectives-and-map-markers](skald-quests-dialog.md#quests-objectives-and-map-markers)

### Pak

A KCD2 data archive: an ordinary zip (Store/no-compression is the documented format) renamed
`.pak`, with the `Data/` mirror (`Libs/`, `Scripts/`, `AI/`, ...) at the archive root and no
wrapping folder. Retail loads only `.pak`s (plus loose `mod.manifest`/`mod.cfg`); the Modding Tools
dev build also reads loose files.

See: [mod-structure.md#building-paks](mod-structure.md#building-paks)

### Perk

A `rpg/perk.xml` row a soul can hold (via `soul2perk`), which can override RPG constants through
`perk_rpg_param_override`. An "old"-generation table: a patch row must repeat every field, not just
the ones that changed.

See: [data-tables.md#key-tables](data-tables.md#key-tables)

### Preset

A named, reusable bundle: a `clothing_preset` (an outfit), a `weapon_preset` (a loadout equipped as
one atomic set — there is no separate shield slot), or an `InventoryPreset` (a rule-based inventory
built from weighted sources and a selection `Mode`). Not the same as a `ScriptContextPreset` (a
context bundle) or a `CVarOverride` profile.

See: [data-tables.md#inventory-presets](data-tables.md#inventory-presets)

### publicEnemy label

A `Labels="publicEnemy"` tag on a `FactionTree` faction, read by `RPG.IsPublicEnemy`. Decides
Loot-vs-Rob on corpses and chests and whether the crime AI treats a kill as a crime at all —
independent of combat relations, so a faction can be fully hostile without this label and its
victims will still read as robbed, not looted.

See: [ai-brains-and-npcs.md#faction-labels](ai-brains-and-npcs.md#faction-labels)

### RPG param

A `rpg/rpg_param.xml` key/value global constant (`rpg_param_key`/`rpg_param_value`), readable and
writable at runtime as `RPG.<Key>`. Some constants (the `CombatAuto*` attack-cadence block) are
recomputed every tick after load, so a table edit to those has no effect.

See: [data-tables.md#rpg-parameters](data-tables.md#rpg-parameters)

### Saver entity

A spawned entity (conventionally a vanilla `BasicEntity`) used to smuggle a mod's Lua table through
the engine's own save/load, by writing it into a field the vanilla class already serialises (its
`health` field). Like any spawned entity it exists only in the level it was spawned in.

See: [lua-scripting.md#recipe-1-one-vanilla-entity-as-the-save-carrier-verified-in-game](lua-scripting.md#recipe-1-one-vanilla-entity-as-the-save-carrier-verified-in-game)

### Scaleform / GFx

CryEngine's Flash-based UI middleware (SWF v8, ActionScript 2, no AS3 anywhere). Every screen is a
`.gfx` movie (a zlib-wrapped SWF tag stream) plus a `Libs/UI/UIElements/<Name>.xml` contract; a mod
can ship a plain `.swf` instead once `wh_gfx_useSWF=1` is set before launch.

See: [ui-scaleform.md#the-stack](ui-scaleform.md#the-stack)

### Scheduler / firing

The Scheduler subbrain (type 9) drives an NPC's daily routine and is required for MonsterLOD
switching — an NPC without one is never demoted. Separately, "firing" an interrupt
(`AddInterrupt_*`) suspends the switch tree for a named behaviour, but the interrupt lands on a
**later** engine update than the one that queued it, which is the usual cause of scheduler races.

See: [ai-brains-and-npcs.md#brains-and-subbrains](ai-brains-and-npcs.md#brains-and-subbrains), [behavior-trees.md#interrupts-and-schedulers](behavior-trees.md#interrupts-and-schedulers)

### ScriptBind

The C++-to-Lua binding layer. Static tables such as `System`, `Game` and `XGenAIModule` are each
one `CScriptBind_*` singleton exposed as a global; per-entity proxies (`ent.soul`, `ent.actor`,
`ent.human`) carry a `__this` pointer into the same machinery. The generated
[api/](api/README.md) reference documents every recovered function.

See: [lua-scripting.md#entities-script-classes-vs-scriptbind-tables](lua-scripting.md#entities-script-classes-vs-scriptbind-tables)

### Skald

The quest and dialogue authoring tool, and the concept-graph system it edits (a.k.a. "the concept
graph"; database name `barbora`, called `brambora` in mod files — see [Brambora](#brambora)).
Scripts quests, dialogue and reactions as a node graph; one bad node can silently disable a mod's
entire graph.

See: [skald-quests-dialog.md](skald-quests-dialog.md)

### Smart object

An entity — often a separate `StanceSmartObject`, distinct from its visual prop — carrying
`guidSmartObjectType`/helpers that a behaviour tree's `StanceElement`/`UnstanceAction` targets to
sit, sleep or work at. Not the same thing as a [SmartEntity](#smartentity).

See: [ai-brains-and-npcs.md#smart-objects-sitting-sleeping-working](ai-brains-and-npcs.md#smart-objects-sitting-sleeping-working)

### SmartEntity

A named registry of behaviour templates (`SmartBehaviorTemplate`) that `AddInterrupt_*`,
`CallBehavior` and Skald `EnableBehavior` refer to by name — the mechanism vanilla's `so_interrupt`
entity uses for combat and other interrupts. Registry-keyed: a second file that reuses an existing
template `Name` does not merge with the first.

See: [ai-brains-and-npcs.md#smartentity-and-smartbehaviortemplate](ai-brains-and-npcs.md#smartentity-and-smartbehaviortemplate)

### Soul

A `rpg/soul.xml` row: an NPC's persistent identity (GUID, `brain_id`, `factionName`, archetype,
social class, ...). An NPC in the world is a soul plus a spawned entity linked to it by
`properties.guidSharedSoulId`.

See: [ai-brains-and-npcs.md#souls](ai-brains-and-npcs.md#souls)

### Storm / appearance

The rule system (official wiki KM-A-32) that selects souls by name pattern (`hasName`, wildcards
supported) and applies appearance/equipment/role/ability operations (`setBody`, `setHead`,
`addRole`, `setAttribute`, ...) in load order. Merged in with `Libs/Storm/storm__<modid>.xml`.

See: [ai-brains-and-npcs.md#equipment-and-appearance](ai-brains-and-npcs.md#equipment-and-appearance)

### Subbrain

One functional unit of a brain: type 1 BehaviorTree, 3 SmartArea, 4 SmartObject, 5 Situation, 6
Switching (the NPC's always-on tree), 7 Dialog, 8 DogCompanion, 9 Scheduler (required for
MonsterLOD switching — see [Scheduler / firing](#scheduler--firing)).

See: [ai-brains-and-npcs.md#brains-and-subbrains](ai-brains-and-npcs.md#brains-and-subbrains)

### Token

An inventory item used as the one working Lua-Skald bridge: Skald grants it
(`CreatePlayerReward`) and Lua polls and deletes it, or Lua grants it and Skald watches with
`ItemDescriptorTrigger`. It needs its own row in `item__<modid>.xml`, or the grant silently does
nothing.

See: [skald-quests-dialog.md#lua-skald-bridge](skald-quests-dialog.md#lua-skald-bridge)

### UIAction

The Lua ScriptBind table (`CScriptBind_UIAction`) that drives every Scaleform screen:
`ShowElement`/`HideElement`, `CallFunction`, `SetVariable`/`SetArray`, clip transforms
(`SetPos`/`SetScale`/`SetAlpha`), and listener registration.

See: [ui-scaleform.md#uiaction---the-lua-bridge](ui-scaleform.md#uiaction---the-lua-bridge)

### WHGame.dll

The single ~89 MB DLL retail builds the entire engine and game code into, loaded by
`KingdomCome.exe`. The disassembly corpus and every `sub_XXXX` reference in this knowledge base are
addresses inside this one binary, valid only for the game build they were recovered from.

See: [engine-internals.md#engine-identity](engine-internals.md#engine-identity)

### WUID

A runtime entity handle — see [GUID vs WUID](#guid-vs-wuid) above.

See: [behavior-trees.md#variables](behavior-trees.md#variables)

### XGEN

Warhorse's AI behaviour-tree engine (`wh::xgenaimodule`, `XGenAIModule.dll` in the dev build) — the
"XGEN" in the page title "Behaviour trees (XGEN / MBT)". `XGenAIModule` is also the Lua ScriptBind
table for talking to it (`SendMessageToEntity`, `GetBrainVariable`, ...).

See: [behavior-trees.md](behavior-trees.md), [engine-internals.md#engine-identity](engine-internals.md#engine-identity)
