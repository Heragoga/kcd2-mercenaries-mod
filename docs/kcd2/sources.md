---
title: Sources
summary: Catalogue of every local and online source the KCD2 knowledge base draws on, and how to keep it fresh.
tags: [tooling]
kind: reference
status: current
scope: kcd2
---

# Sources

Single index of where every fact in this KB comes from. If you're about to research something,
check here first — there is likely already a local copy or a known-good link. If you're writing a
topic page, cite provenance using one of the tags this catalogue backs: `(vanilla: Scripts/...)`,
`(official wiki KM-A-xx)`, `(retail binary: sub_XXXX / disasm)`, `(community: <url>)`, `(unverified)`.

## TL;DR — where to look for X

| Question type | Best source | Local path / command |
| --- | --- | --- |
| What does Lua function `X` do, what's its signature? | Generated API reference | [`api/README.md`](api/README.md), `api/<Table>.md`, or `python tools/kb.py api <name>` |
| Is `X` actually present/used in retail, or only documented? | API page status line (docs / retail binary / runtime dump / vanilla uses) | same `api/<Table>.md` page |
| What does cvar/command `X` do, what's its default? | Generated cvar data | [`console-variables.md`](console-variables.md), [`data/cvars.tsv`](data/cvars.tsv), or `python tools/kb.py cvar <regex>` |
| What's the official rule for mod structure / manifest / publishing? | Official wiki snapshot | `../../references/kcd2-mod-docs-main/official-wiki/` — KM-A-3, KM-A-57, KM-A-58, KM-A-85 (see [table](#official-wiki-article-table) below) |
| How do STORM selectors/operations work? | Official wiki | KM-A-32, KM-A-33, KM-A-34 |
| How do behaviour trees / XGEN AI work? | Vanilla `AI/` trees + community docs | `references/kcd2-mod-docs-main/Scripts/AI/`, `MODDING_STACK.md`; KCD1 MBT_Trees wiki for the mental model (see [Online sources](#online-sources)) |
| How do Skald quests/dialogue work? | Official wiki walkthroughs | KM-A-18, KM-A-29 through KM-A-34, KM-A-67 through KM-A-76 |
| What native/engine internals exist (`gEnv`, vtables, offsets)? | Retail-binary corpus | `E:\kcd2_disasm`, `python tools/disasm_query.py ...`, `../mercenaries/tech/disassembly.md` |
| What's the general CryEngine-level Lua/scripting model? | CryEngine 5 official docs (online) | see [Online sources → CryEngine reference](#cryengine-reference) |
| What changed between KCD1 and KCD2 Lua APIs? | benjaminfoo/KCD2-Development-Guide | see [Online sources → Community KCD2](#community-kcd2) |
| What live debug web tools exist for RPG/factions/AI/saves? | CryHttp debug web tools | `C:\Program Files\Steam\steamapps\common\KCD2Mod\Data\libs\CryHttp\` (see [§1](#1-official-modding-tools-install)) |
| Has the official wiki changed since our snapshot? | YouTrack REST API drift check | see [Keeping sources fresh](#keeping-sources-fresh) |
| What UI/Scaleform metrics (sizes, colors) does vanilla use? | Measured from vanilla `.gfx` movies | [`ui-scaleform.md`](ui-scaleform.md) (absorbed the measured UI dossier) |
| Mercenaries-mod-specific war stories behind these pages | The mod's own docs | `docs/mercenaries/` in the mod's source repo (not published) |
| How-to guides for adding NPCs/outfits/weapons/quests | Step-by-step guides | [`../xml/add-new-npc.md`](../xml/add-new-npc.md), [`../general/adding-new-outfits.md`](../general/adding-new-outfits.md), [`../skald/add-top-level-quest.md`](../skald/add-top-level-quest.md) |
| How do I pack/package a mod into a `.pak`? | Official wiki + community pak tools | KM-A-3, KM-A-57; [`mod-structure.md`](mod-structure.md); see [Online sources → Tools & libraries](#tools--libraries) |

## Local sources

Paths under `references/` are **local-only** (gitignored — see `.gitignore`); links to them work on
this machine but are dead on GitHub, and `tools/kb.py check` flags them as such (warning, not error).

### 1. Official modding-tools install

`C:\Program Files\Steam\steamapps\common\KCD2Mod` — Steam app id `2429020` ("Kingdom Come:
Deliverance II Modding Tools"), branch/build `release_1_5` (Tools built 2026-03-03, Editor built
2025-09-01). This is the live install, not an extract.

- **script_bind docs** — `Tools/modding/docs/script_bind/script_bind_2025_01_14/`, a Doxygen/Doc-O-Matic
  HTML dump (4963 files, dated 2025-01-14). Identical copy checked into the repo at
  `references/script_bind_2025_01_14/` and used as the primary input to the [generated API
  reference](#5-generated-references-in-this-kb).
- **CryHttp debug web tools** — `Data/libs/CryHttp/`, the dev build's live web debug server
  (served at `http://localhost:1403` when the game is running). No written docs anywhere else;
  their existence and URLs are the finding:
  | Path | What it does |
  | --- | --- |
  | `api/README.txt` | Points to an *internal* Warhorse YouTrack article for a REST API (`KCD2-A-8684`) — not in the public wiki mirror, see [Known gaps](#known-gaps) |
  | `rpg/*.html` (`factions.html`, `locations.html`, `pois.html`, `poi_map.html`) | Live debug views over RPG factions/locations/points-of-interest |
  | `xgen/exprdebug.html`, `xgen/types.html` | Live XGEN AI expression debugger |
  | `saveviewer/`, `savemodifier/` | Browse/edit a loaded savegame live |
  | `factionsdebug/`, `perception/` | Faction and AI-perception debug views |
  | `xzar2/` | Event/location map tool; per-region JSON exports (`export-klaster.json`, ...) |
  | `player/randomEvents/`, `player/tutorials/` | Player-state debug views for random events / tutorial triggers |
  | `Profiling/*` | Engine profiling (entities, materials, shaders, textures, LODs, skeletons) — not modding-specific |
  | `static/apiBrowser.html`, `static/scheduler.html` | Browsable API index and task scheduler UI |
  | `static/tests/*.html` | Combat, minigame, skirmish, weapon-destroy test harnesses |
  | `gameDataViewer/`, `andebugger/` | Game data / animation-network debug views (untested this pass) |
- **Excel Add-in** — `Tools/modding/excelAddin/`. `Modding.dll` + `Npgsql.dll` confirm it talks to a
  Postgres `ConfigDB` (matches KM-A-86 and `DBSkald_Document.pdf`, see [§6](#6-other-local-material)).
  `data/export/text_export.xml` is the only data file; no docs ship with it.
- **Editor** — `Editor/Help/` is a placeholder only (`do_not_delete_this_folder.txt`, no real help
  content shipped). `Editor/DynamicToolbars/*.xml` are toolbar-button definitions, not docs.
  `Editor/Python/Lib/` is a stock CPython 2 stdlib bundle for the Editor's scripting console, not
  KCD2-specific. `Editor/UI/LuaAutocompleteTokens.txt` (1332 flat names) is used as a corroboration
  input by the generated API reference.
- `LICENSE.txt` covers only the third-party .NET libraries used *by the tools app itself* (MIT:
  AvalonEdit, Avalonia, AutoMapper, ...); it says nothing about redistributing extracted game data —
  see [Known gaps](#known-gaps).

### 2. Official wiki offline snapshot

`references/kcd2-mod-docs-main/official-wiki/` — mirror of `https://warhorse.youtrack.cloud/articles/KM`,
snapshot dated **2026-06-23**, **78 articles** (`README.md` per article) + 320 images, bilingual
EN/中文 top-level README. This is the single highest-value local source for official, authoritative
modding facts. Confirmed still current as of 2026-09-26 — see [Keeping sources
fresh](#keeping-sources-fresh).

#### Official wiki article table

| KM id | Title | Topic | Summary |
| --- | --- | --- | --- |
| [KM-A-1](https://warhorse.youtrack.cloud/articles/KM-A-1) | Modding Kingdom Come: Deliverance 2 | tooling (index) | Wiki home page. |
| [KM-A-36](https://warhorse.youtrack.cloud/articles/KM-A-36) | Technical Overview | tooling | Section index: tools, mod layout, publishing. |
| [KM-A-3](https://warhorse.youtrack.cloud/articles/KM-A-3) | Structure of a Mod | tooling | Mod = folder in `mods/`; loads loose (tools) or `.pak`-only (retail). |
| [KM-A-12](https://warhorse.youtrack.cloud/articles/KM-A-12) | Database tables | data | 300+ tables hold items/buffs/perks/NPCs etc.; full list. |
| [KM-A-35](https://warhorse.youtrack.cloud/articles/KM-A-35) | Reserved ModIds | tooling | Some modids collide with existing game filenames — avoid them. |
| [KM-A-57](https://warhorse.youtrack.cloud/articles/KM-A-57) | Mod Manifest | tooling | `mod.manifest` XML required at mod root; documents its fields. |
| [KM-A-55](https://warhorse.youtrack.cloud/articles/KM-A-55) | The Modding Tools | tooling | Separate Steam app; requires activated KCD2 key. |
| [KM-A-58](https://warhorse.youtrack.cloud/articles/KM-A-58) | Publishing a mod | tooling | Extra steps once a mod works in the dev build. |
| [KM-A-85](https://warhorse.youtrack.cloud/articles/KM-A-85) | Publishing to Steam workshop | tooling | Custom uploader tool (no plain Steam client upload). |
| [KM-A-37](https://warhorse.youtrack.cloud/articles/KM-A-37) | Modding - Game Data | data (index) | Tables, levels, quests, scripts index. |
| [KM-A-19](https://warhorse.youtrack.cloud/articles/KM-A-19) | Modifying game data | data (index) | Sub-index, no own content. |
| [KM-A-15](https://warhorse.youtrack.cloud/articles/KM-A-15) | Modifying LUA entities and scripts | lua | The "Lua + XGEN AI + Skald" stack statement — not everything is Lua-modifiable. |
| [KM-A-16](https://warhorse.youtrack.cloud/articles/KM-A-16) | RPG - Character stats and skills | data (index) | Multiple ways RPG is handled; overview. |
| [KM-A-20](https://warhorse.youtrack.cloud/articles/KM-A-20) | RPG Constants/Params | data | Full-width param reference page. |
| [KM-A-21](https://warhorse.youtrack.cloud/articles/KM-A-21) | Stats and skills | data | Use technical names when referencing stats/skills/derivstats. |
| [KM-A-27](https://warhorse.youtrack.cloud/articles/KM-A-27) | Crime | ai | Crime mostly in AI behaviour trees; some basics via DB tables. |
| [KM-A-32](https://warhorse.youtrack.cloud/articles/KM-A-32) | STORM | tooling | Tool auto-assigning RPG/ScriptContext/Inventory/Dialogue/Appearance/UI-name roles. |
| [KM-A-33](https://warhorse.youtrack.cloud/articles/KM-A-33) | Selectors | data | List of STORM selectors. |
| [KM-A-34](https://warhorse.youtrack.cloud/articles/KM-A-34) | Operations | data | List of STORM operations, per task. |
| [KM-A-86](https://warhorse.youtrack.cloud/articles/KM-A-86) | Excel Addin | tooling | `Tools/modding/excelAddin` — bulk table editing via Excel. |
| [KM-A-29](https://warhorse.youtrack.cloud/articles/KM-A-29) | Quest System | skald (index) | Sub-index. |
| [KM-A-30](https://warhorse.youtrack.cloud/articles/KM-A-30) | General | skald | Quest = "concept graph", a node graph scripting quests/dialogue/etc. |
| [KM-A-31](https://warhorse.youtrack.cloud/articles/KM-A-31) | Example: Tourist mode | skald | Worked example: hide streamed gates via buff + quest graph. |
| [KM-A-67](https://warhorse.youtrack.cloud/articles/KM-A-67) | Event system | skald | Exported internal event database. |
| [KM-A-71](https://warhorse.youtrack.cloud/articles/KM-A-71) | Events creation | skald (index) | Sub-index. |
| [KM-A-68](https://warhorse.youtrack.cloud/articles/KM-A-68) | How to create a random event | skald | Uses the CryHttp web debugger to spawn/tweak events live. |
| [KM-A-69](https://warhorse.youtrack.cloud/articles/KM-A-69) | How to create an Event place | skald | Event places are shared — check before making a new one. |
| [KM-A-70](https://warhorse.youtrack.cloud/articles/KM-A-70) | How to create a Generic Random Event | skald | Place a `GenericRandomEvent` concept node. |
| [KM-A-72](https://warhorse.youtrack.cloud/articles/KM-A-72) | Events Tech | skald (index) | Sub-index. |
| [KM-A-73](https://warhorse.youtrack.cloud/articles/KM-A-73) | Event Place Skald node | skald | Node reference (mostly image). |
| [KM-A-74](https://warhorse.youtrack.cloud/articles/KM-A-74) | Random Event Skald node | skald | Node reference (mostly image). |
| [KM-A-75](https://warhorse.youtrack.cloud/articles/KM-A-75) | Random Event Variant node | skald | Node reference (mostly image). |
| [KM-A-76](https://warhorse.youtrack.cloud/articles/KM-A-76) | Static ports | skald | How the Skald event system wires ports. |
| [KM-A-89](https://warhorse.youtrack.cloud/articles/KM-A-89) | Items - Quality | data | Item health (0-1) affects stats; not directly durability. |
| [KM-A-90](https://warhorse.youtrack.cloud/articles/KM-A-90) | Inventory presets | data | Rule-based item sets for NPC/chest/shop inventories. |
| [KM-A-91](https://warhorse.youtrack.cloud/articles/KM-A-91) | Localization | data | All displayed text must be a localized string key. |
| [KM-A-92](https://warhorse.youtrack.cloud/articles/KM-A-92) | Level data | world | Changing levels not fully supported — many export steps gather/save level data. |
| [KM-A-93](https://warhorse.youtrack.cloud/articles/KM-A-93) | Links | world | Entity links resolved at export time, by type. |
| [KM-A-38](https://warhorse.youtrack.cloud/articles/KM-A-38) | Modding - Visuals | assets (index) | Section index. |
| [KM-A-39](https://warhorse.youtrack.cloud/articles/KM-A-39) | Character Art | assets (index) | Character art creation/implementation overview. |
| [KM-A-22](https://warhorse.youtrack.cloud/articles/KM-A-22) | Clothing - technical overview | assets (index) | Sub-index. |
| [KM-A-14](https://warhorse.youtrack.cloud/articles/KM-A-14) | Smid | assets/tooling | Tool for Components/Materials/Body parts/Armor/Weapons/Presets. |
| [KM-A-25](https://warhorse.youtrack.cloud/articles/KM-A-25) | Character Components | assets | Characters are built from components. |
| [KM-A-64](https://warhorse.youtrack.cloud/articles/KM-A-64) | Hiding groups | assets | How to use hiding groups (occlusion by clothing layer). |
| [KM-A-65](https://warhorse.youtrack.cloud/articles/KM-A-65) | Morphs | assets | Deform a component mesh to fit around another. |
| [KM-A-26](https://warhorse.youtrack.cloud/articles/KM-A-26) | Material Atlas | assets | Shared material library for clothing texturing. |
| [KM-A-23](https://warhorse.youtrack.cloud/articles/KM-A-23) | Clothing Layers | assets | Layer system (mostly image). |
| [KM-A-24](https://warhorse.youtrack.cloud/articles/KM-A-24) | Clothing Features | assets | Feature IDs via vertex color or texture. |
| [KM-A-66](https://warhorse.youtrack.cloud/articles/KM-A-66) | Maya setup | assets/tooling | Installing the CryEngine Maya export plugin. |
| [KM-A-77](https://warhorse.youtrack.cloud/articles/KM-A-77) | Example mods | assets (index) | Sub-index. |
| [KM-A-78](https://warhorse.youtrack.cloud/articles/KM-A-78) | Dress recolor | assets | Worked example: recoloring a dress. |
| [KM-A-79](https://warhorse.youtrack.cloud/articles/KM-A-79) | Custom horses | assets | Worked example: reskinning a horse. |
| [KM-A-81](https://warhorse.youtrack.cloud/articles/KM-A-81) | Custom helmet | assets | Worked example: a new helmet. |
| [KM-A-40](https://warhorse.youtrack.cloud/articles/KM-A-40) | Environment Art | assets/world (index) | Section index. |
| [KM-A-41](https://warhorse.youtrack.cloud/articles/KM-A-41) | 3D Max tools | tooling | Tools available after WH 3ds Max workspace setup. |
| [KM-A-42](https://warhorse.youtrack.cloud/articles/KM-A-42) | How to set up your 3ds max | tooling | Workspace setup walkthrough. |
| [KM-A-43](https://warhorse.youtrack.cloud/articles/KM-A-43) | 3D Max template file | tooling | Template scene file, with a known open-file warning. |
| [KM-A-44](https://warhorse.youtrack.cloud/articles/KM-A-44) | Asset creation pipeline | assets (index) | Full pipeline for a model: LODs, collision, etc. |
| [KM-A-45](https://warhorse.youtrack.cloud/articles/KM-A-45) | Asset creation | assets | Models for levels (not other data types). |
| [KM-A-46](https://warhorse.youtrack.cloud/articles/KM-A-46) | LOD's (Level Of Details) | assets | Well-done LODs = smooth switching. |
| [KM-A-47](https://warhorse.youtrack.cloud/articles/KM-A-47) | Occlusion Proxy | assets | Helps engine decide what to render per frame. |
| [KM-A-48](https://warhorse.youtrack.cloud/articles/KM-A-48) | Physical Proxy - Collisions | assets | Why/how physics proxies are built. |
| [KM-A-49](https://warhorse.youtrack.cloud/articles/KM-A-49) | Shadow Proxy | assets | Separate low-cost shadow geometry to save draw calls. |
| [KM-A-50](https://warhorse.youtrack.cloud/articles/KM-A-50) | Important Topics and Guidelines | assets (index) | Sub-index. |
| [KM-A-51](https://warhorse.youtrack.cloud/articles/KM-A-51) | General mesh optimization guidelines | assets | Poly-budget optimization, esp. for consoles. |
| [KM-A-52](https://warhorse.youtrack.cloud/articles/KM-A-52) | Standardized dimension | assets | Why certain dimensions must stay standardized. |
| [KM-A-59](https://warhorse.youtrack.cloud/articles/KM-A-59) | Detail maps - Library chart | assets | Full detail-map library chart w/ names/pictures/greyscale values. |
| [KM-A-53](https://warhorse.youtrack.cloud/articles/KM-A-53) | Details mapping - Detail atlas | assets | How the detail atlas is used. |
| [KM-A-54](https://warhorse.youtrack.cloud/articles/KM-A-54) | Texel Ratio | assets | Model-size-to-texture-size ratio guidance. |
| [KM-A-88](https://warhorse.youtrack.cloud/articles/KM-A-88) | Weapons | assets | LOD0 poly budget guidance for weapons. |
| [KM-A-82](https://warhorse.youtrack.cloud/articles/KM-A-82) | Building shader cache | engine/tooling | Shaders in `Engine/Shaders.pak`; modified shaders force a recompile. |
| [KM-A-83](https://warhorse.youtrack.cloud/articles/KM-A-83) | Walkthroughs | tooling (index) | Section index. |
| [KM-A-17](https://warhorse.youtrack.cloud/articles/KM-A-17) | Adding a new Item | data | Full add-item walkthrough via `Data/libs/Tables`. |
| [KM-A-18](https://warhorse.youtrack.cloud/articles/KM-A-18) | Skald | skald | Skald tool walkthrough: quests, dialogues, localization. |
| [KM-A-8](https://warhorse.youtrack.cloud/articles/KM-A-8) | Simple mod - Modifying cvars | engine | Minimal cvar-mod walkthrough, references KM-A-3 structure. |
| [KM-A-84](https://warhorse.youtrack.cloud/articles/KM-A-84) | Modifying RPG parameters and NPC stats | data | Walkthrough version of KM-A-16's RPG overview. |
| [KM-A-87](https://warhorse.youtrack.cloud/articles/KM-A-87) | Modding rules | tooling | Steam Workshop guidelines. |
| [KM-A-56](https://warhorse.youtrack.cloud/articles/KM-A-56) | Installing mods | tooling | Player-facing: Workshop + manual install, `mod_order.txt`. |

Most valuable for a mod author: KM-A-15 (Lua/XGEN/Skald stack statement), KM-A-3/KM-A-57 (mod
structure/manifest), KM-A-12 (table list), KM-A-32/33/34 (STORM), KM-A-17/KM-A-8/KM-A-18 (concrete
walkthroughs), KM-A-86 (Excel Addin), KM-A-56/KM-A-85 (publishing/install).

### 3. Vanilla extracts

Under `references/kcd2-mod-docs-main/` (a checked-out clone of `muyuanjin/kcd2-mod-docs`, gitignored):

- **`Scripts/`** — extract of retail `Data/Scripts.pak`, build `release_1_5`, pak dated 2026-04-22,
  **26415 files**: `Quests/` 24000+ (Skald graphs/dialogue), `AI/` 1400+ (XGEN/MBT behaviour trees),
  `Scripts/` 400+ (Lua), `Entities/` 140+. See `Scripts/README.md` for the re-extraction one-liner.
- **`Libs/Tables/`** — extract of retail `Data/Tables.pak`, same branch/date, **1738 files**: top
  folders `ai/`, `rpg/`, `item/`, `combat/`, `skald/`, `ui/`, `action/`, `animation/`, `music/`,
  `minigame/`, `Character/`; both `.xml` source and compiled `.tbl` present. See
  `Libs/Tables/README.md`.
- **`lua_dump_state/`** — `luastate.txt` (29582 lines) / `LuaState_Sorted.txt` (28834 lines): a raw
  dump of every global Lua table/function/constant live in a loaded `release_1_5` save, taken via
  the in-game `lua_dump_state` console command. The broadest concrete Lua surface area available
  locally; one input to the [generated API reference](#5-generated-references-in-this-kb).

### 4. Retail-binary corpus (`E:\kcd2_disasm`)

Static-analysis corpus over retail `WHGame.dll`, build **`release_1_5_1308617_856`**. Built and
maintained by `tools/disasm_build.py` in this repo; see `E:\kcd2_disasm\AGENTS.md` for the full
schema. Query it with `python tools/disasm_query.py {info,fn,dis,strings,xrefs,callers,callees,
vtable,rtti,imports,cvar,binds,symbols,name,at,sql} ...` from the repo root — full write-up and
verified anchors (`gEnv`, vtable slots, named symbols) in `../mercenaries/tech/disassembly.md`.

Key caveats worth carrying into any claim sourced from here: static-only (a call edge means
"exists", not "runs"); `sub_` names/RVAs are **not stable across game builds**, only `symbols`
entries survive a rebuild; `binds`/`cvars` are heuristic pattern recovery, not ground truth; Lua is
statically linked (no `lua_*` imports), so Lua-surface discovery must go through `binds`, `strings`
and vtables instead.

### 5. Generated references in this KB

Everything under `docs/kcd2/api/` and `docs/kcd2/data/` is **generated** from §1/§3/§4 above — do
not hand-edit, regenerate instead (see [Keeping sources fresh](#keeping-sources-fresh)).

- [`api/README.md`](api/README.md) — Lua ScriptBind reference: how it cross-checks the official
  script_bind HTML, the retail binary's `binds` table, and the runtime `lua_dump_state` dump; legend
  for the per-function status line; class list.
- [`data/README.md`](data/README.md) — what each generated data file is (currently `cvars.tsv`) and
  how it was built, including the confidence-tier legend.
- [`console-variables.md`](console-variables.md) — the curated, human-readable companion to
  `data/cvars.tsv`: what cvar prefix groups mean, how to set/read a cvar from Lua/console/`.cfg`.

### 6. Other local material

`<workspace>` below is the author's local modding folder (the parent of the mod repos); none of it is in
this repository.

- **`<workspace>\docs\kcd2_modding_context.md`** - the old hand-written AI-context dossier. **Superseded**:
  its general content was merged into this knowledge base, which corrects several errors in it (the
  "player GUID", the `SpawnFriend` prefix rule, the retail `ExecuteConsoleString` node, a nonexistent
  `GetItemCount` node). Kept only for the record.
- **`<workspace>\docs\documentation.pdf`** (103 MB) - a **rendered PDF export of the official KM wiki**;
  same articles as the §2 snapshot. Not new information; treat §2 as authoritative.
- **`<workspace>\docs\DBSkald_Document.pdf`** (6 pages) - setup guide for the Postgres `ConfigDB` behind
  the Excel Add-in / Skald database tools (PostgreSQL 16 + ODBC, `modding.sql`/`public.sql`/`sequences.sql`,
  a hex-edit fix for `Tools/Skald/SQLConnector.dll`). Written for KCD1's install paths - plausibly still
  applicable to KCD2's `excelAddin` (same `Npgsql.dll` architecture) but **unverified for KCD2**.
- **`<workspace>
ew-skalitz\docs\`** - `ui-metrics.md` (type sizes, row heights and exact colours measured
  from vanilla `.gfx` movies) and `icons.md` (icon-asset spec). Absorbed into [`ui-scaleform.md`](ui-scaleform.md).
- **`<workspace>nezkacompanion
eferences\docs\`** - an older copy of this repo's step-by-step guides;
  nothing new.
- **`<workspace>	ools\`** - `kcd-toolkit-master` (Altair/altire-dev: PAK Builder, Mod Generator, Asset
  Finder, Mod Suite), `KCD2-PAK-master` (drag-and-drop C# packer), `KCDUtils-main` (Destuur, Lua utility
  framework: `KCDUtils.RegisterMod()` pattern, depends on `LuaDB`/Nexus 1523 for persistence).
- **`../../references/KCD2 Lipsync Tool/README.txt`** (in this repo, local-only) — standalone tool
  doc: generates facial lip-sync for modded voice lines via Warhorse's own phoneme recognizer
  (ships in the Modding Tools SDK). Writes `Data\Animations\humans\facials\<modid>\...` +
  `Data\<modid>_facials.pak`; the facial index is global and additive per mod, so shipping it is
  mandatory and must be regenerated after game updates add dialogue.

## Online sources

### Official

| Source | Owner | Last update | Quality | Good for |
| --- | --- | --- | --- | --- |
| [Warhorse YouTrack KM wiki](https://warhorse.youtrack.cloud/articles/KM) | Warhorse Studios | Rolling; most recent touch 2026-09-14 (KM-A-58, metadata-only as of our 2026-09-26 check) | High (primary source) | Authoritative modding facts — see the [offline snapshot](#2-official-wiki-offline-snapshot) for the curated local copy |
| [DeepSilver modding announcement](https://www.deepsilver.com/games/kingdom-come-deliverance-ii/news/modding-in-kingdom-come-deliverance-2) | Deep Silver / Warhorse | 2025-03-14 | High but thin | Official Steam Workshop policy, install paths, pak requirement, load-order rule; confirms no documented Lua sandbox |
| [Fextralife KCD2 Patch Notes](https://kingdomcomedeliverance2.wiki.fextralife.com/Patch_Notes) | Community (Fextralife) | Tracks live patches (1.2.2–1.5.3 checked) | Medium | Checking whether a game patch touched mod-loading/pak format/Lua (none have, 1.2–1.5.3) |

### Community KCD2

| Source | Owner | Last update | Quality | Good for |
| --- | --- | --- | --- | --- |
| [souky-byte/kcd2-modding-docs](https://github.com/souky-byte/kcd2-modding-docs) | souky-byte | Newer than the `muyuanjin` mirror we clone locally | Medium-high | Broad, current compilation + a 15-repo code-pattern analysis; verify specific claims before citing (index is JS-rendered, not directly fetchable) |
| [benjaminfoo/KCD2-Development-Guide](https://github.com/benjaminfoo/KCD2-Development-Guide) | benjaminfoo | Lightly maintained (4 commits) | Medium | KCD1→KCD2 Lua API renames (e.g. `vecScale` → `VectorUtils.Scale`, new `EntityCommon` table); workspace setup |
| [KCD2ModLoader](https://github.com/xiaoxiao921/KCD2ModLoader) | xiaoxiao921 | Active | High | Native mod-loader hook taxonomy (XML-parse hook, FMOD hook, `rom.game_data.*` events); documented gotchas: multi-threaded Lua VM disabled, level-XML hot-edit limited to `objects_mission0` |
| [kcd2db / LuaDB](https://github.com/muyuanjin/kcd2db) | muyuanjin | Active | High | SQLite persistence pattern for mods (`LuaDB.*`/`DB.*`); documented limits (~953 MB per JSON object, ASCII-only console output) |
| [violetanvil/kcdx](https://github.com/violetanvil/kcdx) | violetanvil | Stopped (unmaintained, MIT-licensed) | High as reference architecture | SKSE-style native-extender interface taxonomy (messaging/task/trampoline/serialization/console/scripting interfaces, Address Library); do not use its filesystem-takeover branch — currently breaks game boot |
| [Warbox](https://github.com/vawser/Warbox) | vawser | — | Medium | Desktop table/localization editor tool (workflow, not a format reference) |
| [ModForge](https://github.com/Destuur/ModForge) (Nexus 2142) | Destuur | 2026-02-21 (v1.2.3) | Medium | XML data editor for perks/buffs/items/localization → packaged `.pak` (workflow tool) |
| [KCD2 Mod Manager (rewrite)](https://github.com/KCD2ModManager/KCD2-Mod-Manager) | KCD2ModManager | Active | Medium | Mod install/organize tool only, no new API facts |
| [kcd2-cheat](https://github.com/pryans/kcd2-cheat) | pryans | — | Low-medium | Cheat-mod reference implementation |
| KCDUtils (Nexus 2410) | Destuur | — (fetch blocked, not re-verified) | Medium | Lua utility framework; settings-UI integration patterns |

### CryEngine reference

Recommend the **CryEngine 5** doc tree over CryEngine 3 — KCD2 forks CE5, and the CE3 category this
repo's community docs historically cited is stale for KCD2-era APIs.

| Source | Owner | Last update | Quality | Good for |
| --- | --- | --- | --- | --- |
| [CryEngine 5 docs — Script Usage](https://www.cryengine.com/docs/static/engines/cryengine-5/categories/23756813/pages/23306632) | Crytek | Live, rolling | High | General CryEngine Lua scripting model; confirms embedded **Lua 5.1.1-rc4** inside `CryScriptSystem` |
| [CryEngine 5 docs — Lua Scripting category](https://www.cryengine.com/docs/static/engines/cryengine-5/categories/23756813/pages/23306623) | Crytek | Live, rolling | High | ScriptBind_Script/System/Action pages, "Learning the Lua language", the in-engine Lua Debugger |

### KCD1 still applicable

| Source | Owner | Last update | Quality | Good for |
| --- | --- | --- | --- | --- |
| [MBT_Trees (Nexus wiki)](https://wiki.nexusmods.com/index.php/MBT_Trees) | Community | Confirmed live | High | Behaviour-tree mental model (strictly hierarchical, explicit loop nodes, XML under `Libs/AI`) that maps onto KCD2's XGEN AI trees |
| [Unofficial KCD1 Lua/DB docs (fireundubh)](https://forum.kingdomcomerpg.com/t/resource-unofficial-lua-scripting-and-modding-documentation/48887) | fireundubh | 2018, static | Medium | Legacy Lua class reference, RPG params/stats/buffs/perks tables; candidate DevMode cvars (`wh_sys_PreferredDB`, `wh_sys_SQLServer`, `wh_sys_SQLDatabase`) worth checking against `data/cvars.tsv` |
| [Nexus-Mods/kcd-documentation](https://github.com/Nexus-Mods/kcd-documentation) | Nexus Mods (mirror of Warhorse KCD1 docs) | Static | High as cross-reference | Official KCD1 ScriptBind HTML (`C_ScriptBind_Quest`, `C_ScriptBindInventory`, etc.) — useful for telling a deliberate KCD2 removal from an extraction gap |

### Tools & libraries

| Source | Owner | Last update | Quality | Good for |
| --- | --- | --- | --- | --- |
| KCD PAK Builder (Nexus 78) / Auto Packer (Nexus 406) / KCD2 PAK (Nexus 1482) | Community | Varies | Medium | Community pak-packing utilities filling the gap the official guide leaves (no first-party packer); Auto Packer auto-syncs an `.unpacked` folder to its `.pak` |
| [yobson1/kcd2lua](https://github.com/yobson1/kcd2lua) (VS Code Lua Runner) | yobson1 | Active | Medium | In-editor Lua execution via `vscodelua.asi` (requires Ultimate-ASI-Loader); `-console` flag for a separate debug console |

## Keeping sources fresh

- **Detect official-wiki drift**: query
  `https://warhorse.youtrack.cloud/api/articles?fields=idReadable,summary,updated` (works
  unauthenticated; the article pages themselves are JS-rendered and fetch empty). Compare the
  article count and `updated` timestamps against the [article table](#official-wiki-article-table)
  above. A newer `updated` timestamp does not always mean new content — diff the actual body via
  `https://warhorse.youtrack.cloud/api/articles/<ID>?fields=content` before re-snapshotting; as of
  2026-09-26 the three articles with post-2026-06-23 timestamps (KM-A-30, KM-A-58, KM-A-76) were all
  byte-identical to the local snapshot.
- **Regenerate the API reference**: `python tools/gen_api_reference.py` (stdlib-only; rerun after a
  game patch or after re-extracting `references/script_bind_2025_01_14/` or rebuilding
  `E:\kcd2_disasm`). Writes into `docs/kcd2/api/`.
- **Regenerate cvar data**: `python tools/gen_cvar_reference.py` (rerun after `E:\kcd2_disasm` is
  rebuilt for a new patch, or after this mod's or vanilla's Lua changes enough to be worth
  re-scanning). Writes `docs/kcd2/data/cvars.tsv`.
- **Rebuild the disassembly corpus**: `python tools/disasm_build.py` (needed after any game patch —
  `sub_` names and RVAs are not stable across builds; see `E:\kcd2_disasm\AGENTS.md`).
- **Rebuild the search index**: `python tools/kb.py build` (incremental; `--full` to force a full
  rebuild) after any of the above, or after adding/editing docs.

## Known gaps

- **`Data/libs/CryHttp` REST API** is undocumented publicly — the only lead is a link to an
  *internal* Warhorse YouTrack article (`KCD2-A-8684`) not present in the offline wiki mirror. Only
  the existence and URLs of the debug web apps are known, not the actual endpoint schema.
- **Redistribution rights for extracted game data/docs** are unresolved. `LICENSE.txt` in the tools
  install covers only the .NET libraries used by the tools app itself, not whether `Scripts.pak`/
  `Tables.pak` extracts, script_bind HTML, or wiki-snapshot text may be redistributed in a public
  repo. Not settled by KM-A-87 (Steam Workshop content guidelines) either.
- **Full equipped-slot read model** — Lua cannot read the full equipped-slot state; only native
  `C_EquipmentManager`/RTTR can, and the candidate offsets (`C_Inventory+0x8`, `C_Item+0x30`,
  `C_Soul+0x2B8`) are unverified guesses. No local or online source resolves this cleanly.
- **`QuestSystem.*` availability during mod-init** is inconsistent/unreliable per community notes;
  no source gives a definitive rule for when it is or isn't present.
- **Excel Add-in / ConfigDB workflow for KCD2 specifically** — `DBSkald_Document.pdf` targets KCD1's
  installer paths; nobody has verified the same steps (Postgres 16, `SQLConnector.dll` hex patch)
  still apply unmodified to KCD2's `Tools/modding/excelAddin`.
- **CryEngine version identity** — nobody has pinned which upstream CryEngine version/fork KCD2 is
  based on; stock CryEngine reference headers diverge from KCD2's actual vtable offsets (confirmed
  independently in `../mercenaries/tech/disassembly.md`).
- **KCD1's `wh_sys_PreferredDB` cvar family** (`SQL,XML,TBL` backend selector) may still exist as a
  DevMode-only cvar in KCD2's binary — flagged as a candidate to verify against
  [`data/cvars.tsv`](data/cvars.tsv) / `python tools/disasm_query.py cvar` rather than assumed.
