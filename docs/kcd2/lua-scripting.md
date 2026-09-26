---
title: Lua scripting
summary: How mod Lua is loaded and run in KCD2, what survives a save or a level change, how timers really behave, and what Lua cannot do.
tags: [lua, engine]
kind: reference
status: current
scope: kcd2
verified: release_1_5
---

# Lua scripting

## TL;DR

- **Lua 5.1**, statically linked into `WHGame.dll`, one Lua state shared by the game and every
  mod. `_VERSION=Lua 5.1` in the runtime dump; the string `Lua 5.1` is in the retail binary.
- **Exactly one file per mod runs by itself:** `Scripts/Mods/<modid>.lua`, right after
  `Scripts/main.lua`, before any level or player exists. Everything else is
  `Script.LoadScript`ed from it. Put gameplay setup in an `OnGameplayStarted` listener, which
  fires on **every** save load and every Trosky/Kuttenberg level load.
- **What survives a load:** Lua globals do, and they keep their values from before the load, so
  they can be stale. Entities, behaviour-tree state and running timer chains belong to the level.
  Pending `Script.SetTimerForFunction` timers are **written into the save** and re-armed when it
  loads.
- **Persist data** in a script-table field of one *vanilla-class* entity that the engine already
  serialises. Never leave an entity of a mod-defined class in a save: if the mod is removed, that
  save will not load.
- **Retail hides errors.** Wrap everything in `pcall`/`xpcall`. Line numbers need
  `-lua_storedebug 1`. See [debugging.md](debugging.md).
- API lookup: [`api/README.md`](api/README.md) or `python tools/kb.py api <name>`.

## The Lua environment

| What | Status | Source |
|---|---|---|
| Version | Lua 5.1: no `goto`, no `//`, no integer subtype, no `bit32` | runtime dump `_VERSION`; retail binary string |
| Bit ops | globals `band`, `bor`, `bxor`, `bnot`, `lshift`, `rshift`, `arshift` (CryEngine's, not a library table) | runtime dump |
| `string`, `table`, `math`, `coroutine` | present | runtime dump |
| `os` | `os.clock()` and `os.time()` **only**. `os.clock()` is the only sub-frame timer | runtime dump; performance.md |
| `debug` | present, and `debug.traceback` works (vanilla `Scripts/Debug/DebugUtils.lua` uses it) | vanilla; mod `mercenaries.TracedCall` |
| `io` | not in the runtime dump, so assume there is no file I/O. `System.LoadTextFile` reads | runtime dump (unverified that `io` is fully absent) |
| `loadstring`, `dofile`, `require`, `setfenv` | present | runtime dump |
| `json` | global `json.encode` / `json.decode` (`_version=0.1.1`) | runtime dump |
| Randomness | `math.random`, plus a global `random()`. The old context doc says `math.random` repeats the same sequence each launch unless seeded (unverified); seed it yourself or use a rotating index where variety matters | runtime dump |
| Engine constants | `ent_*` ray masks, `g_PhysicsCollisionClass`, `ENTITY_FLAG_NO_SAVE=32768`, `g_localActorId`, `g_Vectors`, `g_Pi`/`g_Deg2Rad`, ~300 `enum_*` tables (e.g. `enum_actorState`) | runtime dump |
| Vanilla helpers | `VectorUtils`, `ItemUtils`, `EntityUtils`, `TableUtils`, `StringUtils`, `MathUtils`, `EntityCommon`, ... loaded from `Scripts/Utils` at startup | vanilla `Scripts/main.lua`, `Scripts/common.lua` |

The full live symbol list is `references/kcd2-mod-docs-main/lua_dump_state/LuaState_Sorted.txt`.
To make a fresh one, see [debugging.md](debugging.md#inspecting-live-state).

## How mod Lua gets loaded

In engine order:

1. **Vanilla boot.** `Scripts/main.lua` `OnInit()` calls `LoadAllScripts()`, which
   `ScriptLoader.LoadFolder`s `Scripts/Utils`, `Systems`, `Quests` and `Debug` (vanilla).
2. **Mod init scripts.** For each enabled mod the engine runs `Scripts/Mods/<modid>.lua`. The log
   says `Loading lua init script for mod <modid>...`, then
   `Loading and executing script file 'scripts/mods/<modid>.lua'`
   (verified in game; official wiki KM-A-15; [episode 1 §10](../tutorials/episode-01-mod-setup.md#10-lua)).
   Top-level code here runs at the main menu. There is no player, no level and no save yet.
3. **Your other files.** Load them from the init script with `Script.LoadScript(path)`.
   [`Script.LoadScript`](api/Script.md#loadscript) runs a file once and remembers it in the
   loaded-script set. [`Script.ReloadScript`](api/Script.md#reloadscript) runs it again.
   `ExecuteFile` normalises and lower-cases the path first, so paths are case-insensitive
   (retail binary: `IScriptSystem::ExecuteFile`, see [engine-internals.md](engine-internals.md#genv-and-interfaces)).
4. **Entity scripts.** `Scripts/Entities/**/<Class>.lua` define entity classes. A class also needs
   `Entities/<Class>.ent`, or `System.SpawnEntity` throws
   (ui.md, verified in game).
5. **Overriding a vanilla script.** Ship the file at the same path in your pak, for example
   `Scripts/Entities/Doors/AnimDoor.lua` (official KM-A-15). This replaces the whole file, and it
   stays at this game version: later patches to that file never reach your users.
6. **Other entry points.** `<ExecuteLua code="...">` in behaviour trees is compiled per tick
   ([behavior-trees.md](behavior-trees.md)). Console command bodies are evaluated when the command
   is typed ([debugging.md](debugging.md#console-and-dev-mode)). Skald's
   `wh::conceptmodule::ExecuteConsoleString` does not work in retail; use the inventory-token bridge
   (`skald-quests-dialog.md`, [lua-skald-communication.md](../general/lua-skald-communication.md)).

Retail reads Lua only from `.pak` files. Loose files are read by the modding-tools dev build only
([mod-structure.md](mod-structure.md)).

### Minimal init script

```lua
mymod = mymod or {}                       -- one global table; `or` keeps state across a re-run
Script.LoadScript("Scripts/Mods/mymod_util.lua")   -- prefix every extra file with your modid

function mymod:OnGameplayStarted(actionName, eventName, argTable)
    mymod.LoadGen = (mymod.LoadGen or 0) + 1       -- generation for this load (see Timers)
    local ok, err = pcall(function() mymod:Start() end)
    if not ok then System.LogAlways("[mymod] start failed: " .. tostring(err)) end
end

UIAction.RegisterEventSystemListener(mymod, "", "OnGameplayStarted", "OnGameplayStarted")
```

## Namespace and module rules

- **All mods share one global namespace.** Keep everything in one table named after your modid.
  Prefix every file name with the modid too, because `Scripts/Mods/` is one folder for every mod
  (verified in game; [episode 1 §10](../tutorials/episode-01-mod-setup.md#10-lua)).
- **A file that fails to compile takes the whole module with it.** Everything it would have defined
  is `nil`. The error shows up later, somewhere else, as "attempt to call a nil value". The classic
  cause is a UTF-8 BOM, which Lua 5.1 does not skip (verified in game, `tools/check_lua.py`).
- **Timer and command targets are resolved by name at fire time.** `Script.SetTimerForFunction`
  takes a dotted global path string such as `"mymod.Tick"`. A console command body is a Lua string.
  The target must therefore be a plain field reachable from `_G`, and it is called without `self`:
  write `function mymod.Tick()`, not `function mymod:Tick()`. It may be defined in a file that loads
  later.
- **Entity handles are not identities.** `tostring(ent.id)` is not stable across ticks, so compare
  entities by `ent:GetName()` (verified in game; ai-modules.md).

## Lifecycle events

| Event | When | Notes |
|---|---|---|
| Init-script top level | Once per game launch, at the main menu | No player or level. Register listeners and commands here |
| `OnGameplayStarted` | After **every** save load, and after every inter-region level load | Registered with [`UIAction.RegisterEventSystemListener`](api/UIAction.md#registereventsystemlistener)`(tbl, "", "OnGameplayStarted", "Method")`. The log shows `EventSystemListener: actionName[System] eventName[OnGameplayStarted]` (verified in game, regions.md) |
| `OnQuickLoadingStart` | Before a level load | Seen in the same log. Not used by the mod; that it can be registered the same way is unverified |
| Entity `OnSpawn` / `OnInit` / `OnReset` / `OnPropertyChange` | Per entity, from its class script | vanilla entity scripts |
| Entity `OnSave(tbl)` / `OnLoad(tbl)` | Save write / save load, per entity | Looked up on the **class** when the script is parsed. Assigning `ent.OnSave` on one instance later is never called (verified in game, `mercenaries_store.lua`) |
| Entity `Client:OnUpdate(dt)` / `Server:OnUpdate(dt)` | Every frame once `ent:Activate(1)` | Must be in the `Client` or `Server` sub-table. A top-level `OnUpdate` is never called (verified in game, ui.md) |

There is **no pre-save hook** (save-footprint.md).
There is **no level-name API**: `System.GetCurrLevelName`, `Game.GetLevelName` and
`System.GetCurrAsyncLevelName` return nothing usable. regions.md says "empty"; the mod's log backups
show `System.GetCurrLevelName` and `Game.GetLevelName` failing with a Lua error, which suggests they
are not bound at all. None of the three is in [`api/`](api/README.md)
(regions.md).

## Timers and update loops

| Call | Callback | Use |
|---|---|---|
| [`Script.SetTimer`](api/Script.md#settimer)`(ms, fn)` | a function value or closure | Returns an id for [`Script.KillTimer`](api/Script.md#killtimer). What vanilla uses (`EntityCommon.lua`) |
| [`Script.SetTimerForFunction`](api/Script.md#settimerforfunction)`(ms, "tbl.Func")` | a **global path string** | What most mods use. One-shot |

- **Every timer is one-shot.** To loop, re-arm at the end of the callback. Returning a number does
  not re-arm (old context doc; matches every shipped loop).
- **Do not pass a third argument to `SetTimerForFunction`.** The script_bind docs describe a
  `userData` argument. In game it never reaches the callback, and passing it can stop the chain
  re-firing (verified in game, performance.md).
  This contradicts the official docs; the in-game result takes precedence.
- **Floor ≈ 100 ms.** Shorter delays are rounded up
  (performance.md). After a hitch, the engine fires queued timers
  back to back, so a guard of the form "skip if the last tick was under N ms ago" can kill your only
  chain (performance.md, round 7).
- **Timers run on engine time.** During sleep, wait or fast travel the engine clock runs faster
  than real time (×29.4 measured). Timers and `System.GetCurrTime` follow it, so per-tick load
  multiplies exactly then (verified in game,
  travel-detection.md).
  If you need a real-world duration, measure it with `os.clock()`. BT `timeType="GameTime"` waits
  follow the world clock instead, and burst the same way during skips
  ([behavior-trees.md](behavior-trees.md)).
- **Clocks.** [`System.GetCurrTime`](api/System.md#getcurrtime) is cached once per frame, so every
  call within one frame returns the same value. `os.clock()` is wall time at about 1 ms resolution.
  [`Calendar.GetWorldTimeRatio`](api/Calendar.md#getworldtimeratio) reads **15.0** in normal play,
  not 1.0 (verified in game, travel-detection.md).

### Timers and saves

Measured facts (verified in game unless noted):

- A timer chain that is **running** when a load starts does not carry into the loaded game. A latch
  such as `Running = true` in your Lua table survives the load, and it will then block re-arming for
  the rest of the session (verified in game, performance.md).
- Timers that were **pending when the save was written** are serialised into the `.whs` file and
  re-armed on load. They skip every arm-once guard in your code. One long save carried **5,899**
  duplicate timers (save forensics, performance.md).
  Older notes in the same doc say that chains "die with the level" and never enter the save; the save
  forensics supersede that.
- A restored timer is only a **name**. If that name points at a closure created at run time
  (`mymod._restore = function() ... end`, then `SetTimerForFunction(ms, "mymod._restore")`), the
  timer re-arms after a fresh launch and fires into nothing, because the closure existed only in the
  session that made it. Anything that must happen after a load cannot live in such a timer: persist
  the intent (a saved string) and redo it in `OnGameplayStarted`
  (command-ui.md, `_blChargeRestore`).
- [`System.GetCurrTime`](api/System.md#getcurrtime) **restarts on a load**, while Lua tables keep the
  marks cached from the previous session, so `now - mark` goes negative and a cooldown never expires
  for the rest of the session. Clear time marks in `OnGameplayStarted`
  (aleksej.md, observed in game).
- **Entity ids are recycled.** An id cached in a Lua table before a load usually resolves to
  *something* afterwards - often a different entity - so "does this id still resolve" is not a presence
  test. Drop cached ids on load and re-find entities by name (same source).

The pattern that works:

1. At the **top** of `OnGameplayStarted`, before anything arms a timer, clear every latch and bump
   a load generation.
2. Put the generation in the **function name** (`"mymod.TickG3"`). The live chain re-arms under the
   current name. A callback that fires under an old name only counts itself and stops. A timer
   restored from the save therefore drains in one firing.
3. Prefer one master tick that dispatches to slots over many self-arming chains. A private
   self-arming chain cannot count its own duplicates
   (performance.md).

## Entities: script classes vs ScriptBind tables

Lua reaches the engine through two different kinds of table:

| Kind | Examples | Call style | Where documented |
|---|---|---|---|
| **Static ScriptBind tables**: C++ singletons exposed as globals | `System`, `Game`, `Script`, `XGenAIModule`, `ItemManager`, `Calendar`, `UIAction`, `Physics`, `RPG`, `EntityModule`, `Variables` | `System.GetEntityByName("x")` | [`api/<Table>.md`](api/README.md) |
| **Entity script tables**: one per entity, built from a Lua class in `Scripts/Entities` | `player`, anything returned by `System.GetEntity*` | `ent:GetWorldPos()`; engine methods are in [`api/Entity.md`](api/Entity.md) | vanilla class file + `Entity` |
| **Per-entity proxies** on an entity table (each carries `__this`) | `ent.soul`, `ent.actor`, `ent.human`, `ent.inventory` | `ent.soul:GetState("health")` | [`Soul`](api/Soul.md), [`Actor`](api/Actor.md), [`Human`](api/Human.md), [`Inventory`](api/Inventory.md) |

- `player` is the player's entity table (class `Player`). `g_localActorId` is its id (runtime dump).
  Inside a BT `ExecuteLua`, `entity` is the NPC running the tree and `data.<var>` reads and writes
  the tree's variables ([behavior-trees.md](behavior-trees.md),
  [basic-structure.md](../behaviour-trees/basic-structure.md#executing-lua-code)).
- The API pages for `AnimDoor`, `Dog`, `Horse`, `Player`, `InteractionTrigger` and a few others
  mix a handful of real C++ binds with the Lua callbacks of the vanilla entity class of the same
  name (`OnReset`, `OnUsed`, ...). Those callbacks are class code you can override, not engine API
  (api-report).
- "retail: unconfirmed" on an API page means no evidence was found, not that the function was
  removed. About 44% of documented functions show it, which is mostly a coverage gap
  ([api/README.md](api/README.md#status-line-legend)).

### Finding and making entities

- **Lookup.** [`System.GetEntity`](api/System.md#getentity)`(id)`,
  [`System.GetEntityByName`](api/System.md#getentitybyname) (a linear scan, so cache the result on
  hot paths, performance.md),
  [`System.GetEntitiesByClass`](api/System.md#getentitiesbyclass),
  [`System.GetEntitiesInSphere`](api/System.md#getentitiesinsphere), and
  [`XGenAIModule.GetEntityByWUID`](api/XGenAIModule.md#getentitybywuid) (the BT `$wuid` form).
- **Spawning.** [`System.SpawnEntity`](api/System.md#spawnentity)`{class=, name=, position=, orientation=, properties={...}}`
  **throws** when the class has no `.ent`, so wrap it in `pcall`. A plain prop is `class="BasicEntity"`
  plus `properties.object_Model`, with no custom class needed (camp.md). Placement,
  physics and raycasts are covered in [world-and-physics.md](world-and-physics.md).
- **Removing.** [`System.RemoveEntity`](api/System.md#removeentity)`(id)`. The old context doc
  claimed `ent:DeleteThis()` "often fails" (unverified).
- **Flags.** [`Entity.SetFlags`](api/Entity.md#setflags)`(flags, mode)`: **mode 0 = add,
  1 = AND-mask (keep only these), 2 = clear.** This is not the order CryEngine documents. Passing 1
  to "add" wipes every other flag (retail binary `sub_70FC3C`, from `mercenaries_roster.lua`). Read
  back with [`Entity.HasFlags`](api/Entity.md#hasflags).
- **Transient nils.** `System.GetEntity` can return `nil` for a live entity for a tick or more while
  it streams. Require several consecutive misses before you decide it is gone (verified in game,
  bandit-camp-quest.md).

## Persistence and saving

### What survives what

| State | Save → load (same level) | Region crossing (level load) | Quit and relaunch |
|---|---|---|---|
| Lua globals and tables | **Kept, but stale.** They hold whatever the session had before the load; nothing is restored from the save | Kept. This is the only channel that carries state across levels (verified in game; vanilla `SinglePlayer.lua` stores `g_GameTokenPreviousLevel` in a Lua global for this) | Gone |
| Entities you spawned | Written into the save unless flagged out | Belong to their level. They are absent in the other level and return when you go back (regions.md) | From the save |
| Fields an entity class writes in `OnSave` | Restored | Per level, with the entity | From the save |
| Pending `SetTimerForFunction` timers | Serialised and re-armed | Running chains are dropped with the old level | From the save |
| Running timer chains, BT runtime state | Dropped | Dropped | n/a |
| Game tokens | Saved (unverified) | **Not** kept across a level change (vanilla `SinglePlayer.lua`) | From the save |
| Buffs with `is_persistent="false"` | Never written (save-footprint.md) | n/a | n/a |

Because Lua tables survive a load that entities do not, a table that still gates a scan radius or a
cvar will charge a fight's cost after a load with no fight on. Reset derived state in
`OnGameplayStarted` (performance.md).

### Recipe 1: one vanilla entity as the save carrier (verified in game)

Spawn one `BasicEntity` with a unique name (e.g. `MyModStore`) and put a Lua table in its
**`health`** field. Vanilla `BasicEntity:OnSave` writes `table.health = self.health` and `OnLoad`
restores it (vanilla `Scripts/Entities/Physics/BasicEntity.lua`, lines 96-102). Nested tables
survive; one save restored 61 keys intact. Find the entity again by name (`BasicEntity` is a busy
class), and read it after `OnGameplayStarted`. Two rules:

- It must be a **vanilla** class. A save containing an entity of a mod-defined class fails to load
  once the mod is removed: `[Error][LoadGame] Class:'X' not found`, then
  `Load of game has failed (CryEngine data)` (verified in game, modding-tools build).
- Do not try an instance-level `OnSave` override; it is never called (see Lifecycle events above).

Full mechanism and history: `data/Scripts/mods/mercenaries_store.lua`,
save-footprint.md.

### Recipe 2: keep entities out of the save and rebuild from data

- Set `ent:SetFlags(ENTITY_FLAG_NO_SAVE, 0)` **and** spawn with
  `properties.bSaved_by_game=false, bSerialize=false`. Then check with `HasFlags` that the flag stuck.
  The properties only work if the class script reads them. `BasicEntity` does. `mercenaries_roster.lua`
  says `NPC` does not, although save-footprint.md
  logged NPCs being left out with the property alone. The sources disagree, so use both.
- Store a compact description (e.g. tier and health per NPC) with Recipe 1, and spawn the shortfall
  in `OnGameplayStarted`. Rebuilt NPCs appear around the player, not where they stood.
- Every entity of a **mod-defined class** must be flagged no-save, whatever else you do.

### Recipe 3: across a region crossing

Only Lua globals carry over. The saver entity from Recipe 1 is in the other level. Copy what you
need into a global before the crossing and reconcile afterwards (regions.md).

### Other approaches, with status

- **External storage.** kcd2db / `LuaDB` (native ASI, SQLite, per-save and cross-save keys)
  (community; [engine-internals.md](engine-internals.md#native-plugins)). Plain files break save
  causality: reloading an older save does not roll the file back (old context doc; follows from how
  saves work).
- **`Variables.SetGlobal`.** The old context doc claims names are truncated (so similar long names
  collide) and that unregistered names with string values crash with a type mismatch (unverified).
  `Variables.SetGlobal` is documented and present in the runtime dump, but not found in the binary
  bind table.
- **BT `isPersistent="1"` variables and `brain_variable is_persistent`.** These persist at the
  tree/brain level ([behavior-trees.md](behavior-trees.md), `ai-brains-and-npcs.md`).
- **"Hibernation cell"** (old context doc, unverified). Instead of deleting NPCs, teleport them to
  `z + 1500` above the player, freeze them with `actor:SetMovementRestriction(true, true)`, and call
  `actor:PostPhysicalize()` when bringing them back. Both calls are documented but not confirmed in
  the binary or runtime dump. The mercenaries mod shipped Recipe 2 instead.

## API recipes

| Task | Call | Notes |
|---|---|---|
| Log | [`System.LogAlways`](api/System.md#logalways) | Ignores verbosity. [`System.Log`](api/System.md#log) respects it |
| Run a console line | [`System.ExecuteCommand`](api/System.md#executecommand) | Synchronous: the command has finished when the call returns (mercnav README) |
| Register a command | [`System.AddCCommand`](api/System.md#addccommand) | Argument quoting trap: [debugging.md](debugging.md#console-and-dev-mode) |
| cvars | [`System.GetCVar`](api/System.md#getcvar) / [`System.SetCVar`](api/System.md#setcvar) | [console-variables.md](console-variables.md) |
| Position / facing | [`Entity.GetWorldPos`](api/Entity.md#getworldpos), [`GetWorldAngles`](api/Entity.md#getworldangles) (yaw = `.z`) | When spawning facing the player, copy yaw only (`{x=0,y=0,z=yaw}`), or NPCs spawn tilted (old context doc) |
| Soul values | [`Soul.GetState`](api/Soul.md#getstate)`("health")` | Wrap in `pcall`: it throws for entities in transitional states such as during fast travel (old context doc) |
| Relationship | [`Soul.GetRelationship`](api/Soul.md#getrelationship) | Relations are one-directional (`ai-brains-and-npcs.md`) |
| Script / entity context | [`Soul.HasScriptContext`](api/Soul.md#hasscriptcontext) | Read-only. Setting a context needs a Skald `SetEntityContext` (enemy-morale.md) |
| Talk to a BT | [`XGenAIModule.SetBrainVariable`](api/XGenAIModule.md#setbrainvariable) / [`GetBrainVariable`](api/XGenAIModule.md#getbrainvariable) / [`SendMessageToEntity`](api/XGenAIModule.md#sendmessagetoentity) | community `MODDING_EXPERIENCE.md` |
| Inventory | [`Inventory.GetInventoryTable`](api/Inventory.md#getinventorytable) + [`ItemManager.GetItem`](api/ItemManager.md#getitem) | `it.class`, `it.amount`, `it.health` read fine with plain indexing (shipped mod code). The old context doc's "proxy table, must use `pairs()`" claim is contradicted by that code |
| Count / remove items | [`Inventory.GetCountOfClass`](api/Inventory.md#getcountofclass), [`DeleteItemOfClass`](api/Inventory.md#deleteitemofclass); vanilla `ItemUtils.RemoveInvItem` | The old context doc claims `inventory:RemoveMoney` can empty the whole purse (unverified). Money is item class `5ef63059-322e-4e1b-abe8-926e100c770e` |
| On-screen text | [`Game.SendInfoText`](api/Game.md#sendinfotext) | A string key with no localization row prints the raw key (ui-building.md) |
| Save | [`Game.SaveGameViaResting`](api/Game.md#savegameviaresting), fallback [`Game.QuickSave`](api/Game.md#quicksave) | `QuickSave` writes an autosave slot. `Game.QuickLoad` does nothing ([debugging.md](debugging.md#test-harness-patterns)) |
| Dev-mode check | [`System.IsDevModeEnable`](api/System.md#isdevmodeenable) | `true` only in a `-devmode` launch |
| UI | [`UIAction`](api/UIAction.md) | [ui-scaleform.md](ui-scaleform.md) |
| Raycasts, ground, spawning position | [`Physics.RayWorldIntersection`](api/Physics.md#rayworldintersection) | [world-and-physics.md](world-and-physics.md) |

## KCD1 → KCD2 differences

- KCD1's `vecScale`-style vector globals are now `VectorUtils.*`, e.g. `VectorUtils.Scale(a, b)`
  (community: benjaminfoo/KCD2-Development-Guide; confirmed in vanilla
  `Scripts/Utils/VectorUtils.lua:100`).
- Entity mix-ins are on `EntityCommon`, e.g. `EntityCommon.MakeUsable(entity)`
  (vanilla `Scripts/Entities/EntityCommon.lua:368`). It **overwrites** a class's own
  `OnUsed`/`IsUsable` if called after them (gates.md).
- `QuestSystem.*` is documented, but it is not reliably available as a global from
  `Scripts/Mods/*.lua` (community `MODDING_EXPERIENCE.md`).
- Much KCD1 knowledge does not carry over. Cross-check against the KCD1 ScriptBind mirror
  (`Nexus-Mods/kcd-documentation`) and the KCD2 [`api/`](api/README.md) before relying on a KCD1
  recipe ([sources.md](sources.md#kcd1-still-applicable)).

## What is NOT possible from Lua

| Want | Status | Source |
|---|---|---|
| Read an NPC's current target | `soul:GetTarget()` is not a bind. It fails inside `pcall` and looks like "no target". Use the BT `GetTarget` node | verified in game, combat-target-selection.md |
| Read full equipped-slot state / an item's slot | Not exposed. `actor:GetArmor()` can read 0 on an armoured NPC | community `MODDING_EXPERIENCE.md`; custom-gear.md |
| Set an entity/script context | Only Skald `SetEntityContext` | enemy-morale.md |
| Know that a save is about to be written | No hook | save-footprint.md |
| Know the level name, or "am I fast travelling" | No getter works. `enum_actorState` exists but nothing returns it | regions.md, travel-detection.md |
| Change the navmesh or add path obstacles | Baked, no Lua route. Possible only through a native plugin | walls-and-sieges.md, [engine-internals.md](engine-internals.md#native-plugins) |
| Enable an input action filter | `EnableActionFilter` was removed from the bind; only whole action maps can be switched | command-ui.md |
| Inspect or cancel collision damage | No hit callback | collision-ghosting.md |
| Cancel an NPC action already in flight; `SetPos` on an NPC from inside its own BT | Neither sticks. Do it from a timer or console context | verified in game, camp-forge.md |
| Give the player god mode | No `god` command. `GameRules.SetInvulnerability` errors | verified in game, torture-test.md |
| Terrain height via `System.GetTerrainElevation`; indoors via `System.IsPointIndoors` | Returns `nil` / dead on this build | [world-and-physics.md](world-and-physics.md) |

## Gotchas

- **A command, timer or BT hook "does nothing" in retail.** A Lua error inside it was swallowed.
  Wrap bodies in `xpcall` with `debug.traceback`, and reproduce in the dev build
  ([debugging.md](debugging.md#reading-lua-errors)).
- **A whole module's functions are `nil`.** The file failed to compile (a BOM, a stray `end`), or it
  was never `Script.LoadScript`ed. Lua 5.1 does not skip a UTF-8 BOM.
- **Gameplay setup at the top level of the init script finds `player == nil`.** That code runs at
  the main menu. Move it into `OnGameplayStarted`.
- **A loop runs 2×, 3×, N× too often after several loads, or a long save stutters.** Pending
  `SetTimerForFunction` timers were restored from the save and bypassed your arm-once guard. Put the
  load generation in the timer function name.
- **A loop never starts again after the second load in one session.** A `Running=true` latch
  survived the load, but the chain it guarded did not. Clear latches at the top of
  `OnGameplayStarted`.
- **A timer chain silently stops re-firing.** A third argument was passed to
  `Script.SetTimerForFunction`.
- **A "restore" timer taken across a save never restores after a relaunch.** It named a run-time
  closure that no longer exists; persist the state and redo it on load.
- **A cooldown never expires again after loading a save.** A `System.GetCurrTime` mark from the
  previous session survived in a Lua table; the clock restarted. Clear marks on load.
- **A cached entity is "still there" after a load, but it is someone else.** Entity ids are recycled;
  re-resolve by name.
- **A `self`-using callback errors on "attempt to index nil".** Timer and command targets are
  called by name without `self`.
- **Cooldowns expire instantly during sleep or fast travel.** Timers and `GetCurrTime` run on the
  accelerated engine clock. Use `os.clock()` for real-world durations.
- **Timing inside one frame reads 0 ms.** `System.GetCurrTime()` is frame-cached. Use `os.clock()`.
- **Every `LoadString` returns nil after crossing Trosky ↔ Kuttenberg.** The saver entity lives in
  the other level. Carry state in a Lua global.
- **Removing the mod makes a save refuse to load ("Load of game has failed").** An entity of a
  mod-defined class is in that save. Flag such entities `ENTITY_FLAG_NO_SAVE`.
- **An instance `OnSave`/`OnLoad` override never fires.** They are cached on the class. Use a
  field the vanilla class already serialises.
- **`SetFlags(x, 1)` wipes an entity's flags.** Mode 1 is AND-mask; add is mode 0.
- **A custom entity's `OnUpdate` never runs.** It must be `Client:OnUpdate` or `Server:OnUpdate`,
  with `ent:Activate(1)`.
- **`System.SpawnEntity` kills the calling command with no log line.** The class has no `.ent`
  file. The call throws, so wrap it in `pcall` and log the failure.
- **A GUID lookup with `string.find` fails or matches the wrong thing.** `-` is a pattern magic
  character. Use `string.find(s, guid, 1, true)`, or better, a hash set keyed by GUID.
- **`MakeUsable` silently replaces your `OnUsed`.** Call `EntityCommon.MakeUsable` before defining
  the class's own handlers.
