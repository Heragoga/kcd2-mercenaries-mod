---
title: Engine internals
summary: What KCD2's engine is under the hood (CryEngine fork, WHGame.dll, gEnv, vtables), how native ASI plugins reach it, and how to query the disassembly corpus.
tags: [engine, tooling]
kind: reference
status: current
scope: kcd2
verified: release_1_5_1308617_856
---

# Engine internals

## TL;DR

- KCD2 runs on **Warhorse's in-house fork of CryEngine**. Nobody has pinned the upstream version,
  and offsets differ from the public CryEngine headers. Stock CryEngine is at best a guide.
- **Retail builds everything into one `WHGame.dll`** (≈89 MB, PGO), loaded by
  `KingdomCome.exe` from `Bin\Win64MasterMasterSteamPGO\`. The modding-tools dev build uses a
  different, split set of DLLs and runs a different game version.
- Every engine subsystem hangs off **`gEnv`**. Find it through the `exec autoexec.cfg` call site.
  **Never hardcode its RVA**: it moves on nearly every patch, sometimes between builds with the same
  version name.
- Native code reaches the game as an **ASI plugin**. The proven pattern is: signature-scan for
  `gEnv`, hook `IGame::CompleteInit`, register a console command, and pass results to Lua through a
  global (see `native/mercnav`).
- Engine questions get answered from the **disassembly corpus**: `python tools/disasm_query.py ...`
  against `E:\kcd2_disasm`. It is static analysis only, and RVAs are per-build.
- The war story is in disassembly.md. This page is the reference.

## Engine identity

| Layer | What it is in KCD2 | Evidence |
|---|---|---|
| Core | CryEngine: `CrySystem`, `CryAction`, `CryEntitySystem`, `CryScriptSystem`, `CryPhysics`, `Cry3DEngine`, `CryAnimation` (+ Mannequin), `CryAISystem`, `CryMovie` (TrackView), `CryInput`, `CryFont`, `CryNetwork` | source paths `...\Code\CryEngine\CrySystem\*.cpp` embedded in the retail binary; dev-build DLL names |
| Scripting | Lua 5.1, statically linked (no `lua_*` imports) | retail binary string `Lua 5.1`; `E:\kcd2_disasm\AGENTS.md` |
| Files | CryPak: `.pak` = uncompressed zip; paths inside matched **case-insensitively** | verified in game (quest-override-test.md); [mod-structure.md](mod-structure.md) |
| Rendering | `CryRenderD3D12` | dev-build DLL name |
| UI | Scaleform (Flash SWF8/AS2) through `CFlashUI` | retail binary; [ui-scaleform.md](ui-scaleform.md) |
| Audio | FMOD (`CryAudioImplFmod`) | dev-build DLL name |
| Navigation | CryAI MNM on **Recast/Detour tiles baked offline** per level (`recast.pak`, `DNAV` magic) | retail binary; walls-and-sieges.md |
| Debug web server | CryHttp (`Server: CryHttp/0.0.1`, content in `Libs/CryHttp`) | retail binary strings; dev-build `Data/libs/CryHttp/` ([debugging.md](debugging.md#inspecting-live-state)) |
| Warhorse game code | `wh::<name>module` classes on a module framework (`wh::framework::C_BaseModule`): `xgenaimodule` (XGEN AI / behaviour trees), `conceptmodule` (Skald quest graphs), `rpgmodule`, `entitymodule`, `combatmodule`, `dialogmodule`, `guimodule`, `questmodule`, `animationmodule`, `databasemodule`, `playermodule`, `shopmodule`, `soundmodule`, `musicmodule`, `environmentmodule`, `utilsmodule`, `xbehaviormodule` | RTTI in the retail binary (`disasm_query.py rtti "wh::"`); matching dev-build DLLs (`XGenAIModule.dll`, ...) |
| Reflection | RTTR is present (`wh::tests::TestRttrEnum` in the binary), and native equipment state lives in RTTR-reflected `wh::entitymodule` types. The old context doc claims an undefined RTTR type referenced from a quest file breaks the mod's load (unverified) | retail binary strings; community `MODDING_EXPERIENCE.md`; `skald-quests-dialog.md` |
| Crash reporting | BugSplat (`BugSplat64.dll`, `BugSplatAttachments\`); `AftermathDumps\` (by the name, NVIDIA Aftermath GPU dumps; unverified) | install folder listing |

Three layers are moddable without native code: **Lua**, **XGEN AI** (behaviour trees, smart objects) and
**Skald** (quests, dialogue). The official wiki says not everything is reachable from Lua alone
(official KM-A-15). See [lua-scripting.md](lua-scripting.md), [behavior-trees.md](behavior-trees.md)
and `skald-quests-dialog.md`.

### Retail vs dev build

| | Retail (Steam app 1771300) | Modding-tools dev build (app 2429020) |
|---|---|---|
| Binaries | `Bin\Win64MasterMasterSteamPGO\KingdomCome.exe` + monolithic `WHGame.dll` (also `WHGameArm.dll`, purpose unverified) | `Bin\Win64ReleaseSteamLTO_DLL\`: ~40 split DLLs (`CrySystem.dll`, `CryScriptSystem.dll`, `XGenAIModule.dll`, `QuestModule.dll`, ...) + `Editor.exe`, `OptickCore.dll` |
| Game version | current patch | lags behind (e.g. 1.5.5 vs 1.5.6 when measured) (performance.md) |
| Optimisation | PGO | non-PGO LTO. Laggy even without mods, so never measure performance here |
| Mod files | `.pak` only (plus loose `mod.manifest`, `mod.cfg`) | loose files too; does not load Workshop mods |
| Error reporting | swallows rejected Skald nodes and console-Lua errors | logs `[Error]`/`[Warning]` naming the node; see [debugging.md](debugging.md) |
| Facial animation data | present | **absent** (`Data/Facials` missing, so lipsync tests there are meaningless) (lipsync.md) |

Anything you learn about addresses or behaviour from the dev DLLs is **not** evidence about retail
(disassembly.md).

## gEnv and interfaces

`gEnv` (`SSystemGlobalEnvironment*`) is the root of the engine. To find it in any build:

1. Find the only `.rdata` string `exec autoexec.cfg`.
2. Find the only instruction that references it, a RIP-relative `lea`.
3. The `mov rcx, [rip+X]` a few instructions above it loads `gEnv->pConsole`. `X` is the storage
   address of that member.
4. `gEnv = X - 0xA8` (`pConsole` is the 22nd pointer member).

`python tools/disassemble_whgame.py genv` does this, `validate` re-checks the vtable table below,
and `builds <dll...>` tabulates several builds (disassembly.md).

| `gEnv` member | Offset | Evidence (release_1_5_1308617_856) |
|---|---|---|
| `pScriptSystem` | `+0x28` | 756 refs |
| `pGame` | `+0x90` | 434 refs |
| `pConsole` | `+0xA8` | 2472 refs |
| `pAISystem` | `+0xD8` | corpus `symbols` |
| `pFlashUI` | `+0x138` | corpus `symbols` (UIAction resolve helper) |

| Interface method | vtable slot (offset) | Status |
|---|---|---|
| `IConsole::ExecuteString` | 35 (`0x118`) | confirmed; stable 1.1.1 → 1.5 |
| `IConsole::AddCommand` (CXConsole) | 33 (`0x108`) | used by the shipped mercnav plugin (verified in game) |
| `IScriptSystem::ExecuteFile` | 5 (`0x28`) | confirmed from its body |
| `IScriptSystem::ExecuteBuffer` | 6 (`0x30`) | confirmed from its body: `lua_load` over a buffer + `pcall`; verified in game by mercnav |
| `IScriptSystem::UnloadScript` | 7 (`0x38`) | confirmed from its body |
| `IScriptSystem::CreateTable` | 13 (`0x68`) | confirmed |
| `IScriptTable::SetValueAny` | 7 (`0x38`) | corpus `symbols` |
| `IScriptTable::AddFunction` | 22 (`0xB0`) | confirmed (`"%s.%s(%s)"`) |
| `IGame::CompleteInit` | 4 (`0x20`) | confirmed; called once |
| `IGame::GetLongName` / `GetName` | 12 / 13 (`0x60` / `0x68`) | return `"Kingdom Come: Deliverance II"` / `"KCD2"` |
| `IGame::GetIGameFramework` | 16 (`0x80`) | busiest slot, 379 calls |
| `IGameFramework::RegisterListener` | 100 (`0x320`, CCryAction) | in bounds, not independently confirmed |

`IGame` has **no RTTI** (there is no `.?AVCGame@@`). Find its vtable from the `lea rax,[rip+"KCD2"]; ret`
stub for `GetName`. On the current build it is at RVA `0x04095688`, 41 slots. The `CScriptSystem`,
`CScriptTable`, `CXConsole` and `CCryAction` vftables come from RTTI. Their RVAs are listed in
disassembly.md. Re-derive them
after a patch rather than copying them into code.

### Build drift

- `gEnv` RVA moved in every one of 7 builds from 1.1.1 to 1.5. Two builds both tagged `release_1_5`
  differ by 8 KB (disassembly.md).
- The community byte signature for the `gEnv` site (`48 8B 0D ?? ?? ?? ?? 48 8D 15 ...`) matches
  **nothing from 1.4 onward**. 1.4/1.5 need
  `48 8B 0D ?? ?? ?? ?? 45 33 C9 45 33 C0 48 8B 11 4C 8B 92 ?? ?? ?? ?? 48 8D 15 ?? ?? ?? ?? 41 FF D2 48 85 FF`.
  Scan for both (disassembly.md).
- The community guide's `0x38` for `ExecuteBuffer` is an **offset error**: it rightly calls
  `ExecuteBuffer` the 7th virtual function (0-based slot 6) and then multiplies 7 x 8 instead of 6 x 8.
  The real offset is `0x30`; `0x38` is `UnloadScript`, and one catalog summary repeats the error. A plugin built on that reading silently unloaded a nonexistent script on every Lua
  write. A slot counts as confirmed only when its callee's body identifies it; being next to a known
  slot proves nothing (disassembly.md).

## Native plugins

### Loading

| Route | How | Use |
|---|---|---|
| Ultimate ASI Loader | a proxy DLL in the exe folder (`Bin\Win64MasterMasterSteamPGO\`) loads `*.asi` beside it or from `scripts\`/`plugins\`. Which proxy name works best for KCD2 is not recorded here (unverified); KCD2ModLoader proxies `d3d12.dll` | players (community; mercnav README) |
| `tools/inject_dll.py <dll>` | `LoadLibraryA` through `CreateRemoteThread` into the running game | development only |
| Launcher injectors | e.g. kcdx (`kcdx.exe` injects `kcdx.dll`), now unmaintained | reference architecture only ([sources.md](sources.md#tools--libraries)) |

### The pattern that works (mercnav, kcd2db)

1. **Resolve everything by byte signature, never by address.** Require every signature to be
   unique in `.text`. Derive `gEnv` from the console call site and internal functions from their
   shipping call sites.
2. **Register on the game thread after init.** Hook `IGame::CompleteInit` (vtable slot 4 of
   `gEnv->pGame`). If the plugin was injected after init, that hook never fires, so fall back to
   registering after a grace period (mercnav uses 30 s).
3. **Expose it to Lua through the console.** Register a command with `IConsole::AddCommand`
   (slot 33). The command writes its result into a Lua global with `IScriptSystem::ExecuteBuffer`
   (slot 6). Lua calls `System.ExecuteCommand("cmd args")`, which runs synchronously, and then reads
   the global. Alternatively, add real Lua functions with `IScriptTable::AddFunction`, as kcd2db does.
4. **Write a plugin log beside the `.asi`** (`resolved: ...`, `hooked IGame::CompleteInit`,
   `<cmd> registered`). The game log will not tell you the plugin loaded.
5. **Re-check every signature after each patch**: `python tools/disasm_build.py`, then
   `disasm_query.py` against each target.

Worked example: `native/mercnav/README.md` makes
`C_AIObstacles::AddObstacle` reachable from Lua. It has four shipping callers, none reachable from
Lua, XML, Skald or a BT. Derivation:
walls-and-sieges.md.

### What native code still cannot do (or should not)

- **Create a new UI element.** Every `UIAction` bind resolves names against the existing element
  container, and there is no add/register entry point. The XML file is the only way in
  (ui.md).
- **Read Lua proxy fields from native `IScriptTable` in the live game.** This is crash-prone
  (community `MODDING_EXPERIENCE.md`).
- **Touch the Lua VM from other threads.** KCD2ModLoader disabled multi-threaded Lua for crashes
  (community).
- **Survive a patch unchanged.** Everything built on reverse-engineered internals can break silently.
  kcd2db advises disabling it on a crash after an update (community).

Native offsets noted by the community, all per build and unverified here: `C_Inventory+0x8`
(inventory vector), `C_Item+0x30` (WUID), `C_Soul+0x2B8` (EquipmentManager candidate)
(`MODDING_EXPERIENCE.md`).

## The disassembly corpus

A fact database over retail `WHGame.dll`, kept outside the repo at `E:\kcd2_disasm\`
(`KCD2_DISASM_DIR` overrides the location). Current build `release_1_5_1308617_856`: 291,812
functions, 2.0 M xrefs, 815 k direct calls, 136 k strings, RTTI-named vtable slots, ~1,400
recovered Lua binds, 5,321 cvar-shaped strings, and a writable `symbols` table.
Read `E:\kcd2_disasm\AGENTS.md` before pointing an agent at it.

```bash
python tools/disasm_build.py        # ~30 s, rebuild after a game patch
python tools/disasm_listing.py      # ~30 s, full annotated listing to E:\kcd2_disasm\listing\ (59 shards + INDEX.tsv)
python tools/disasm_query.py info   # build, sha256, counts
```

| Question | Command |
|---|---|
| Is Lua function `X` real, and where is its C++? | `disasm_query.py binds "^X$"` → `dis <fn>` |
| Who reads or registers cvar `Y`? | `disasm_query.py cvar Y` (or `python tools/kb.py cvar Y` for the generated table) |
| Where is this log or error string used? | `disasm_query.py strings "<regex>"` → `xrefs` / `callers` |
| What does this function do? | `disasm_query.py dis <addr\|name> [-n N]` |
| What is a class's vtable? | `disasm_query.py rtti "<regex>"` → `vtable <class>` |
| Named anchors (`gEnv`, verified slots, AI globals) | `disasm_query.py symbols "."` |
| Record a finding for the next agent | `disasm_query.py name <addr> <name> --note "..."` |
| Grep the whole binary for an instruction pattern | grep `E:\kcd2_disasm\listing\`; use `INDEX.tsv` to jump |

Addresses can be given as a VA, an RVA, a `sub_` name, `Class::vfN`, or a symbol.

**Limits:**

- The corpus is static: a call edge means code *exists*, not that it *runs*.
- Virtual calls are missing from `calls`. They only show up as `xrefs` on the vtable.
- `sub_` names and RVAs change with every build. Only `symbols` entries survive a rebuild of the same
  binary.
- `binds` and `cvars` are heuristic pattern recovery. Cross-check them with the runtime dump or
  vanilla usage (the [`api/`](api/README.md) and [`data/`](data/README.md) generators already do).
- Some cvar defaults sit in uninitialised `.data` and read 0 statically. Read live values with
  `System.GetCVar` (combat-movement.md).

Case studies that settled real questions: disassembly.md (gEnv),
walls-and-sieges.md (navmesh),
ui.md (custom UI elements, `wh_gfx_useSWF`),
collision-ghosting.md (collision classes),
ground-guard.md (raycast hit fields).

## Gotchas

- **A native plugin reads a random pointer and crashes after a patch.** The `gEnv` RVA was hardcoded
  or gated on the version string. Resolve it by signature on every launch.
- **A runtime signature scan finds nothing on 1.4+.** It uses the pre-1.4 byte pattern. Scan for
  both patterns.
- **Every Lua write from a native plugin "succeeds" and nothing happens.** The plugin called vtable
  slot 7 (`UnloadScript`) believing it was `ExecuteBuffer`. Use slot 6, and confirm slots from the
  function body.
- **The `CompleteInit` hook never fires.** The DLL was injected after init. Register directly after a
  grace period.
- **Behaviour or timings measured in the dev build do not match retail.** It is a different DLL
  layout, a non-PGO build and an older game version.
- **A cvar default reads 0 in the disassembly.** It sits in uninitialised `.data` and is assigned at
  runtime. Read it live.
- **A "call" found in the corpus is dead code, or a function has no callers.** The corpus is static,
  and virtual calls are not in `calls`. Check `xrefs` on the vtable, and prove behaviour in game.
