---
title: Debugging and testing
summary: Where KCD2 reports errors, how to get real Lua errors out of it, dev mode and the console, inspecting live state, profiling, automated test harnesses, and the common crash causes.
tags: [testing, tooling, lua]
kind: reference
status: current
scope: kcd2
verified: release_1_5
---

# Debugging and testing

## TL;DR

- **Read `kcd.log`** in the game root. It is rewritten every launch, and older runs are kept in
  `logbackups\`. The game shows almost nothing on screen.
- **Retail swallows two things silently:** Lua errors in console-command bodies, and Skald nodes it
  rejects. The **dev build** (modding tools, `PackageModDev.bat`) logs both, naming the node. It is
  an older, slower game version, so find errors there and measure performance in retail.
- **Launch with `-lua_storedebug 1`.** Without it, every Lua error message is replaced by
  `<file>:0: [Error] Lua error. Please run with -lua_storedebug 1 to enable lua debug info.`, which
  gives neither the text nor the line.
- **`-devmode`** makes `System.IsDevModeEnable()` return true and is how you gate test tooling. The
  `~` console works in retail without it.
- **`lua_dump_state`** (console, run after loading a save) dumps every live Lua global. It is the
  ground truth for "does this function exist".
- For automation, have the mod **poll a `.cfg` file** that a host script writes, instead of sending
  keystrokes. Reload by relaunch + Continue, because `Game.QuickLoad()` is a no-op.

## Logs

| File | What |
|---|---|
| `<game>\kcd.log` | Current run. The header has `Build info` → `description: release_1_5_...` and the full `Cmdline:`. Check both before trusting a run |
| `<game>\logbackups\kcd Build(0) <dd Mon yy> (<hh mm ss>).log` | Every earlier run. Grep across these to see whether a message is new |
| `<KCD2Mod>\kcd.log` | Dev build's own log, completely separate from retail's. `PackageModDev.bat` deletes it before each launch so a stale file cannot mislead |
| `<game>\permanent.log` | Savegame deletion history (observed) |
| `<KCD2Mod>\game_levelloadtime.log` | Per-level load times (dev build) |
| `<plugin>.log` beside an `.asi` | Native plugins log themselves ([engine-internals.md](engine-internals.md#native-plugins)) |
| `<game>\BugSplatAttachments\`, `<game>\AftermathDumps\` | Crash reporter attachments; GPU crash dumps (by the name; unverified) |

### Log lines worth searching for

| Search | Tells you |
|---|---|
| `[Mod]` | Every mod found, enabled or disabled, and why ([episode 1 §12](../tutorials/episode-01-mod-setup.md#12-debugging)) |
| `doesn't support game version` | The `supports` list in `mod.manifest` excluded this build |
| `Loading lua init script for mod <modid>` | Your init script ran |
| `Mods used while saving (N)` | The mod set of the save being loaded. A save made with other mods invalidates any with/without comparison (performance.md) |
| `Loading level <name>` | A save load or a Trosky ↔ Kuttenberg crossing |
| `eventName[OnGameplayStarted]` | The listener event fired (`[DEBUG]` line) |
| `[Error] Lua error. Please run with -lua_storedebug 1` | A Lua error whose text was discarded. Relaunch with the flag |
| `[Lua Error]` | Script execution failure. In the dev build this also covers console-command bodies: `[string ""]:1: ...` (ui.md) |
| `[ExecuteLua]: Can't run uncompilable lua code` | A BT `ExecuteLua` body does not compile, usually a `--` comment ([behavior-trees.md](behavior-trees.md)) |
| `[AddInterrupt]:Specified behavior doesn't exist on any smart entity` | A BT interrupt names a behaviour with no `SmartBehaviorTemplate` row (aleksej.md) |
| `Object factory was not able to create new` | A Skald node type that cannot be instantiated. It takes the whole quest graph down (npc-lod.md) |
| `[Error][LoadGame] Class:'X' not found` | A save references an entity class that no longer exists, and the load will fail ([lua-scripting.md](lua-scripting.md#persistence-and-saving)) |
| `Loading config file Config/CVarOverrides/<name>.cfg` | A `CVarOverride.xml` game context (e.g. `Battle`) switched cvar profiles (malesov-test.md) |
| `[CVARS][IGNORED CHANGE]` | A protected cvar write was refused. Never seen on 1.5 (combat-movement.md) |
| `invalid configuration line` | A `.cfg` line the parser rejects. Observed for `bind ...` lines in `user.cfg` |
| `[Localization] Facial pak can't be opened` | Dev-build noise (the dev build ships no facial data); ignore it (lipsync.md) |

Log with [`System.LogAlways`](api/System.md#logalways) and a `[YourMod]` prefix.
[`System.Log`](api/System.md#log) respects `log_Verbosity`, and `LogAlways` ignores it.

## Console and dev mode

- **Console.** `~` opens it in retail; players use it without dev mode (verified in game). Type
  `name value` to set a cvar. [`System.AddCCommand`](api/System.md#addccommand)`(name, body, help)`
  registers a command whose `body` is a Lua string, evaluated when the command is typed.
- **`-devmode`.** The retail binary parses `devmode`/`nodevmode` in `CSystem`.
  [`System.IsDevModeEnable`](api/System.md#isdevmodeenable) reports it (retail binary). Put it in
  Steam's launch options, or launch with `steam://rungameid/1771300` / `-applaunch 1771300`. The mod
  keeps ~350 authoring commands unregistered unless `-devmode` is set (console.md).
- **Cheat-flagged cvars are writable anyway.** On `release_1_5_1308617_856` the `VF_CHEAT` gate
  never fires on `System.SetCVar` (combat-movement.md). Whether `-devmode`
  changes console or cvar access in other ways is unverified
  ([console-variables.md](console-variables.md#how-cvars-work-in-kcd2)).
- **Command arguments.** `%line` (the text after the command name) is the only placeholder that is
  substituted, and it arrives **already wrapped in quotes**. `%1`/`%2` stay literal text (verified
  in game, console.md, retest-round4.md). A body written
  `"mymod.Cmd('%line')"` receives `"yes"` including the quote characters. `tonumber` of that is `nil`,
  and `nil ~= 0` is true, so boolean switches could only ever turn on. Strip the surrounding quotes
  once, in one helper. Community `CONSOLE.md` says `%%` and `%1`… are substituted too; the in-game
  result takes precedence.
- **Running arbitrary Lua.** Register an escape-hatch command such as `mymod_lua <code>` that
  `loadstring`s its argument; the mod's `merc_lua` works this way. CryEngine's `#<lua>` console
  prefix is documented upstream but unverified in KCD2 retail.
- **Keys.** Game-owned F-keys shadow mod binds silently. The `bind` command keeps no history and
  cannot be read back. A key bound to a command that is not registered yet does nothing, forever,
  with no error (command-ui.md, torture-test.md).
  For anything automated, **type** the command instead of binding it.
- **No player god mode.** `god` is unknown and `GameRules.SetInvulnerability` errors. Test rigs
  refill a huge max health every tick instead (torture-test.md).

## Reading Lua errors

1. **Get the text back.** Launch with `-lua_storedebug 1`. Otherwise every caught error reads
   `...:0: [Error] Lua error. Please run with -lua_storedebug 1...` (retail binary string; hundreds
   of such lines in the mod's log backups).
2. **Get the stack.** `pcall` tells you *that* a call failed, not *where*. Use
   `xpcall(fn, function(e) return debug.traceback(tostring(e), 2) end)`. `debug.traceback` exists
   in KCD2 (vanilla `DebugUtils.lua`; mod `mercenaries.TracedCall`).
3. **Know what the chunk names mean.** `[string ""]:1:` is a console-command body.
   `[string "ExecuteLua"]` is a behaviour-tree node. A file name with `:0` is the chunk that armed
   the call, not necessarily the one that threw.
4. **A module that is simply missing** (its functions are nil) did not compile. Check for a UTF-8
   BOM, which gives a generic `[Error] Lua error` with no file. `tools/check_lua.py` reads bytes and
   rejects a BOM.
5. **Syntax checks miss misspelled names.** `mathit_sin` passed luacheck. Flag any called name that
   appears exactly once and is never defined (performance.md).
6. **"Nothing happens, nothing logged" in retail** means a console-body Lua error or a rejected
   Skald node. Reproduce in the dev build (ui.md,
   npc-lod.md).

## Inspecting live state

| Tool | What it gives | Notes |
|---|---|---|
| `lua_dump_state` console command | Every Lua global, table and function into `LuaState.txt` | Run after loading a save, not at the menu. Registered in the retail binary. A sorted snapshot is in `references/kcd2-mod-docs-main/lua_dump_state/` (community README) |
| [`Script.DumpLoadedScripts`](api/Script.md#dumploadedscripts) | Every loaded script path | Confirms a `LoadScript` happened |
| Engine debug-draw cvars (e.g. `wh_rpg_SkirmishDebugDraw`, `wh_cs_DebugDrawLods`) | The engine's own view of one subsystem | Ground truth. Guessing state from Lua binds (`IsHidden`, heartbeats) misled the mod for 30+ runs (npc-lod.md). Find more with `python tools/kb.py cvar "DebugDraw"` |
| `r_DisplayInfo`, `r_Stats`, `profile`, `sys_enable_budgetmonitoring` | Frame breakdown, renderer stats, engine profiler, budget overruns | All present in retail (performance.md) |
| CryHttp web tools | `static/apiBrowser.html`, `xgen/exprdebug.html` (live XGEN expression debugger), `saveviewer/`, `savemodifier/`, `rpg/` (factions, locations, POIs), `perception/`, `factionsdebug/`, `Profiling/*` | Files ship in the dev build's `Data/libs/CryHttp/`. Served at `http://localhost:1403` (community `MODDING_EXPERIENCE.md`). The official wiki uses it for random events (KM-A-68). Retail contains the server code (`CSimpleHttpServerListener`); whether it listens in retail is unverified |
| kcd2lua | Run Lua from VS Code in the live game (`vscodelua.asi`, needs Ultimate ASI Loader) | community ([sources.md](sources.md#tools--libraries)) |
| Save forensics | `.whs` files are zlib blocks `[compLen u32][rawLen u32][78 5e ...]`. Decompress and grep for class names and serialised timer records | how the save-borne timer flood was found (performance.md) |

## Profiling

- **Measure in retail.** The dev build is non-PGO and an older game version, and it lags with no
  mods at all (performance.md).
- **Lua is rarely the cost.** A 50-NPC mod measured its Lua at 0.19–0.5% of wall time. The cost is
  what the Lua makes the engine do: NPC count, raycasts, rendered entities, raised cvars
  (performance.md).
- **Lua timing.** `os.clock()` is the only sub-frame clock (~1 ms). `System.GetCurrTime()` is
  cached per frame. The timer floor is ~100 ms. Check the clock resolution before trusting any
  profiler: a profiler reading 0.000 ms is quantised.
- **A Lua profiler can lie.** The mod's first profiler reported "stall is outside this mod" for
  every stall (performance.md, round 4).
  Cross-check it with an engine profiler.
- **CryEngine collapses consecutive identical log lines.** Nine `patrols armed` events showed as one
  line. Put a varying field (a counter, a slot number) into any line you count
  (performance.md).
- **Rule out the environment first.** Check for corrupted game files (verify integrity through
  Steam), a Windows power plan that parks cores (session-to-session variance on many-core CPUs), and
  a save made with a different mod set (performance.md,
  performance.md).
- The dev build ships `OptickCore.dll` and writes `KCD2*.trace` files. Optick use and the trace
  format are unverified.

## Test harness patterns

These have been used unattended for 25–40 minute campaigns
(torture-test.md, camp-inspection.md,
ui.md).

- **Drive the game through a file, not the keyboard.** Keystrokes sent to the console with
  `SendInput` arrive as gameplay input (`m` opens the map), and non-US layouts remap punctuation.
  Instead, the mod arms a 1 s poll that runs `exec <game>\my_ctl.cfg`, and the host script only
  writes that file. Every command in it must be **idempotent**, because the file runs again every
  second. Arm the poll from `OnGameplayStarted`.
- **Launching.** Go through Steam (`steam://rungameid/1771300`) with `-devmode` in the launch
  options. A direct `KingdomCome.exe` launch quits during init with `Steam Service Quit - not started
  through Steam` unless `steam_appid.txt` containing `1771300` is beside the exe. One rig instead
  logged `License not verified - No SteamApps` on a direct launch
  (torture-test.md, camp-inspection.md).
- **Back up the saves before any Steam launch.** Direct launches bypass Steam Cloud, so local saves
  drift from the cloud copy. The next Steam launch can reconcile by emptying the local save folder,
  and Steam uploads on exit (camp-inspection.md).
- **Saving.** Use [`Game.SaveGameViaResting()`](api/Game.md#savegameviaresting) with
  [`Game.QuickSave()`](api/Game.md#quicksave) as the fallback; `QuickSave` writes an **autosave**
  slot. An **airborne** player cannot be saved: `QuickSave` silently wrote nothing five times while
  the player hovered. After each save, check that a save file newer than the run start exists on
  disk (torture-test.md).
- **Reloading.** [`Game.QuickLoad()`](api/Game.md#quickload) silently does nothing. Kill the game,
  relaunch, and press **Continue**, which loads the newest save. Keystroke navigation of the load menu
  once landed in the *save* list and overwrote saves.
- **Proof of load.** `Loading saved game <file>` is printed as soon as an entry is *selected*. Only
  your own `OnGameplayStarted` log line proves a load completed.
- **Self-validating phases.** Stamp a stage marker into the save (Recipe 1 in
  [lua-scripting.md](lua-scripting.md#persistence-and-saving)). Phase B then only runs against the
  right save, so resuming the wrong one times out instead of passing falsely.
- **Never auto-arm test campaigns** from `OnGameplayStarted` or from default key binds. Players will
  trigger them, and some campaigns quit the game when done. Gate them behind `-devmode` plus an
  explicit command.
- **Screenshots.** Each install has its own screenshot folder, so discover it rather than assume it.
  The game writes a ~5 MB JPEG progressively, so wait until the file size stops changing before you
  copy it (`tools/Screenshot-Game.ps1`, `tools/campshot.ps1`, `tools/uicycle.sh`).

## Gotchas

### Crashes and freezes

- **The game freezes or deadlocks in a behaviour tree.** Either a `Loop` has no non-zero `Wait`, or
  a latent node (`Wait`, `Move`, `Turn`) sits inside an `AtomicDecorator`
  ([behavior-trees.md](behavior-trees.md), [basic-structure.md](../behaviour-trees/basic-structure.md#concurrency)).
- **A native crash with a 0-byte minidump.** A mount was `RemoveEntity`d in the same frame its rider
  was dismounted. Remove a horse only once it is confirmed unmounted, several polls later (verified
  in game, travel-detection.md).
- **The game crashes when the map opens.** Map POI markers with low ids (1, 2) collide with vanilla
  clip depths. Use ids ≥ 9001 (map-marker.md, [ui-scaleform.md](ui-scaleform.md)).
- **A crash on `LoadCharacter`.** KCD2 ships no `.cdf`/`.chr` files, so vanilla-style character paths
  do not exist (npc-lod.md).
- **A switching behaviour tree crashes on `Move`.** `changeNPCState="true"` is not allowed in a
  Switching-type tree ([movement.md](../behaviour-trees/movement.md)).
- **A save will not load after the mod is removed ("Load of game has failed").** An entity of a
  mod-defined class is in the save ([lua-scripting.md](lua-scripting.md#persistence-and-saving)).
- **The game quits during init with nothing useful in the log.** It was launched directly without
  `steam_appid.txt`.

### Silent failures

- **A console command does nothing and logs nothing (retail).** Its body threw a Lua error.
  Reproduce in the dev build, where it logs `[Lua Error] ... [string ""]:1:`.
- **A command always uses its default argument.** The `%line` quoting: `tonumber('"5"')` is `nil`.
- **A quest silently stops working (retail).** A Skald node was rejected. Only the dev build's
  `kcd.log` names it, and one bad node can take down the mod's entire quest graph.
- **Stutter that grows across save-scumming, then bursts after fast travel.** Duplicate timer chains
  were restored from the save ([lua-scripting.md](lua-scripting.md#timers-and-saves)).
- **A mod-bound F-key logs "bound" and then does nothing.** The game owns that key.
- **The UI draws nothing, with no error.** Most Scaleform mistakes produce no log line at all. Check
  statically before launching (ui-building.md, [ui-scaleform.md](ui-scaleform.md)).

### Traps in the debugging process itself

- **Conclusions drawn from an old run.** The log was stale: the dev build's copy of the mod was weeks
  old and nobody checked the file's modified time. Several research runs were invalidated
  (npc-lod.md).
- **An event you know fired N times shows up once.** Identical consecutive log lines are collapsed.
- **Performance numbers from the dev build are wildly worse than players report.** It is the wrong
  build to measure.
- **An A/B test "proves" two different culprits on two days.** The fault was intermittent (corrupted
  game files). Single-run A/B tests on a coin-flip fault prove nothing.
- **A "with/without mod" comparison is meaningless.** The save carries entities or state from mods
  that are no longer installed (`Mods used while saving`).
- **A fixture broke its own test.** A helper named "force render" set the ratio to 254 and then 0 on
  the next line, and a whole approach was abandoned on that evidence. Sanity-check the instrument
  first (npc-lod.md).
- **A guessed asset path "proves" the asset does not exist.** Wrong guesses fail silently and look
  exactly like a missing asset. Grep the extracted data for real names
  (siege-builder.md).
