# mercenaries_nav.asi — walls into the navmesh

A native plugin for Kingdom Come: Deliverance II that exposes the engine's runtime
navigation obstacles to Lua, so the mod's palisades become something the pathfinder routes
around instead of through. The mod works without it (collision backstop + own steering);
with it, NPCs *plan* around the walls like they do around any baked asset.

## What it does

The navmesh ships baked (`Levels/<level>/recast.pak`, Detour tiles — the `DNAV` magic is at
tile offset 0x3c). Nothing spawned at runtime is ever in it. But the engine keeps a runtime
obstacle registry for in-game NPC dialogues — passers-by walk round a conversation because
`C_AIObstacles::AddObstacle(desc)` sets bit 2 on every navmesh polygon under a cylinder, and
`C_PathFindingBlockNavMeshFilter::getCost` multiplies the cost of such polygons by
`wh_ai_FindPathObstaclesMultiplier` (ships 3.0) whenever `wh_ai_FindPathUseObstacles` is on
(ships 1). The dialogue kind of obstacle (`flag=1`) also tells NPCs already walking to replan.

`AddObstacle` has exactly four callers in `WHGame.dll` — two in the dialogue system, the
cutscene `SequenceArea`, and one internal — and none is reachable from Lua, XML, Skald or a
behaviour tree. This plugin is the fifth caller.

## Console command

```
merc_navobst add <x> <y> <z> <radius> <height> [ignoreRadius=-1] [flag=1]
    -> Lua global MercNavObstacleResult = obstacle id (>=0), or -1
merc_navobst remove <id>
merc_navobst clear          removes everything this plugin added
merc_navobst status
```

`data/Scripts/mods/mercenaries_navobst.lua` drives it: `System.ExecuteCommand(...)` runs the
command synchronously, then the Lua reads the global. On load it sets `MercNavPlugin`.

## Installing

1. Put an ASI loader in the game's exe folder
   (`...\KingdomComeDeliverance2\Bin\Win64MasterMasterSteamPGO\`). The community uses
   [Ultimate ASI Loader](https://github.com/ThirteenAG/Ultimate-ASI-Loader) — the same setup
   `kcd2db` documents.
2. Copy `out\mercenaries_nav.asi` next to it (or into its `scripts\`/`plugins\` folder).
3. Check `mercenaries_nav.log` beside the `.asi` after a launch: it should say
   `resolved: ...`, `hooked IGame::CompleteInit`, and `merc_navobst registered`.

For development, `tools\inject_dll.py` loads it into a running game without any loader.

## How it finds the engine

Nothing is hard-coded — `gEnv` moves on every patch (see `docs/disassembly.md`). Three byte
signatures over `WHGame.dll`'s `.text`, each required to be unique:

| Signature | Yields |
| --- | --- |
| the `exec autoexec.cfg` console call (the two shapes from `docs/disassembly.md`) | `gEnv` = `&gEnv->pConsole − 0xA8` |
| the in-game-dialogue `AddObstacle` site: `ignoreRadius=-1; flag=1; accessor(); [+0x160]; [+0xA8]; vtable[9]; AddObstacle(&desc)` | the module accessor and `AddObstacle` |
| the `RemoveObstacle` wrapper that clears its owner's id (`cmp [rcx+0x108],-1 … call remove`) | `RemoveObstacle` (and a cross-check on the accessor) |

Then `IGame::CompleteInit` (vtable slot 4 of `gEnv->pGame`) is hooked so the command is
registered on the game thread after every subsystem exists. If injected after init, the hook
never fires and the plugin registers directly after a 30 s grace period.

Verified on `release_1_5_1308617_856`. After a game patch: run
`python tools/disasm_build.py`, re-check each signature with `python tools/disasm_query.py`,
and adjust. `docs/walls-and-sieges.md` ("Into the navmesh") has the full derivation.

## Building

```
powershell -ExecutionPolicy Bypass -File native\mercnav\build.ps1
```

Needs Visual Studio 2022 with the C++ x64 toolset. Output: `native\mercnav\out\mercenaries_nav.asi`.
