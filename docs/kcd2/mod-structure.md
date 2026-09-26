---
title: Mod structure, packaging and load order
summary: What a KCD2 mod folder must contain, which files go in which pak, how mods merge and override each other, how load order works, and how to publish and keep a mod working across game patches.
tags: [data, tooling, assets]
kind: reference
status: current
scope: kcd2
verified: release_1_5
---

# Mod structure, packaging and load order

## TL;DR

- A mod is `Mods/<folder>/` holding `mod.manifest` (required), optional loose `mod.cfg`, `Data/*.pak` and `Localization/*.pak`. **Retail loads nothing loose except `mod.manifest` and `mod.cfg`**; the Modding Tools dev build also reads loose files (official wiki KM-A-58, KM-A-55).
- `modid` (in the manifest, lowercase letters and `_` only) is the key for everything: `mod_order.txt`, `<table>__<modid>.xml`, `Scripts/Mods/<modid>.lua`, `Quests/<modid>.xml`, `Libs/Storm/storm__<modid>.xml`, `*__<modid>.xml` localization (official wiki KM-A-3).
- Two ways to change vanilla data: **merge** (the five `modid`-named conventions above) or **override** (same path, whole file, last-loaded mod wins). Prefer merge; every override conflicts with every other mod touching that path and freezes the file at today's game build.
- Load order: Workshop mods (Steam API order), then `Mods/` alphabetically. A `Mods/mod_order.txt` replaces that, and **any mod not listed is not loaded at all**, Workshop mods included (official wiki KM-A-56).
- A pak is a zip with the `Data/` mirror at the archive root. Store (no compression) is the documented format; see [Building paks](#building-paks) for what is actually tolerated.
- Everything goes wrong silently. `kcd.log` is the only report; the exact `[Mod]` strings are in [Reading kcd.log](#reading-kcdlog).

Step-by-step tutorial for all of this: [Episode 1: mod setup](../tutorials/episode-01-mod-setup.md). Official: [KM-A-3](https://warhorse.youtrack.cloud/articles/KM-A-3), [KM-A-57](https://warhorse.youtrack.cloud/articles/KM-A-57), [KM-A-58](https://warhorse.youtrack.cloud/articles/KM-A-58).

## Folder layout

```
<game>/Mods/                         (the engine also finds mods/ - Windows is case-insensitive)
  mod_order.txt                      optional; one modid per line
  <folder>/                          name it after the modid (they may differ; the engine uses the modid)
    mod.manifest                     required, loose
    mod.cfg                          optional, loose: cvars applied at startup
    Data/
      *.pak                          any number; every *.pak here is opened
    Localization/
      English_xml.pak ...            text, one pak per language
      english.pak                    voice-over (optional)
```

- Workshop mods use the same layout under `steamapps/workshop/content/1771300/<workshop id>/` (tutorial episode 1, verified in game).
- Inside a pak, paths mirror vanilla `Data/`: `Libs/...`, `Scripts/...`, `AI/...`, `Quests/...` (official wiki KM-A-3).
- Keep the whole path short. Windows caps paths at 255 characters and the deepest vanilla quest path is 192 characters from the game root (official wiki KM-A-55). Install the Modding Tools near a drive root for the same reason.

## What goes where

| You are shipping | Path inside the mod | Mechanism |
|---|---|---|
| Manifest | `mod.manifest` (loose) | read by the mod manager |
| Console variables | `mod.cfg` (loose) | [mod.cfg](#modcfg) |
| Table rows (items, buffs, souls, factions, shops, AI registration) | `Data/*.pak` → `Libs/Tables/<dir>/<table>__<modid>.xml` | merge; see [data-tables.md](data-tables.md) |
| Storm rules (NPC appearance, equipment, roles, contexts, abilities) | `Data/*.pak` → `Libs/Storm/storm__<modid>.xml` + your rule files | merge into the Storm root; rules run in load order (official wiki KM-A-84) |
| Lua entry point | `Data/*.pak` → `Scripts/Mods/<modid>.lua` | run once at startup, right after `Scripts/main.lua` (official wiki KM-A-3; log string `Loading lua init script for mod %s ...`, retail binary: sub_20E1330) |
| More Lua | `Scripts/Mods/<modid>_*.lua` | never runs on its own; `Script.LoadScript` it from the entry point |
| New entity class | `Entities/<Class>.ent` (`<Entity Name=".." Script="Scripts/Entities/<Class>.lua"/>`) + that Lua file | picked up by name (mod: `data/Entities/mercenaries_Prop.ent`, verified in game) |
| Behaviour trees | `AI/<name>.xml` | new names are additive; a vanilla name is a whole-file override (MODDING_EXPERIENCE.md) |
| Quest / dialogue graph | `Quests/<modid>.xml` + your files under `Quests/<modid>/` | loaded for both maps alongside vanilla's graph; see [skald-quests-dialog.md](skald-quests-dialog.md) |
| UI movies, icons | `Libs/UI/...` | see [ui-scaleform.md](ui-scaleform.md) |
| Meshes, materials | `Objects/...` | see [assets-pipeline.md](assets-pipeline.md) |
| Lipsync clips + index | separate paks in `Data/` | see [audio-voice-lipsync.md](audio-voice-lipsync.md#lipsync-facial-animation) |
| Subtitles, UI strings | `Localization/<Language>_xml.pak` → `<anything>__<modid>.xml` | [Localization](#localization-text) |
| Voice lines | `Localization/<language>.pak` → `dialog/<namespace>/<voice>_<StringName>.ogg` | see [audio-voice-lipsync.md](audio-voice-lipsync.md#file-format-naming-and-lookup) |

Nothing else merges. AI XML such as `FormationDefinitions.xml` or `LinkTagDefinitions.xml`, level files, and vanilla quest files can only be overridden whole ([formations.md](formations.md#moddability), official wiki KM-A-30, KM-A-92).

## mod.manifest

```xml
<?xml version="1.0" encoding="utf-8"?>
<kcd_mod>
  <info>
    <name>Pack Mule</name>
    <modid>pack_mule</modid>
    <description>Henry carries everything.</description>
    <author>Alex</author>
    <version>1.0</version>
    <created_on>2026-09-23</created_on>
    <modifies_level>false</modifies_level>
  </info>
  <supports>
    <version>1.*</version>
  </supports>
</kcd_mod>
```

| Field | Rule | Source |
|---|---|---|
| `modid` | Required in practice. Lowercase letters and `_` only. Auto-generated from `name` if missing (not recommended). | official wiki KM-A-57 |
| `name`, `version` | Free text, **written into every savegame** so Warhorse can see which mods a bug-report save used. | official wiki KM-A-57 |
| `description`, `author` | Display only. | official wiki KM-A-57 |
| `created_on` | `YYYY-MM-DD`. The game ignores it; some tools require it. The Mercenaries manifest uses a full ISO timestamp and loads fine. | official wiki KM-A-57; mod `mod.manifest` |
| `modifies_level` | `false` unless you ship level data. Parsed by the loader (retail binary: sub_243F278); its exact effect is undocumented (unverified). | official wiki KM-A-3 template |
| `supports/version` | Optional list. If present and no entry matches, the mod is **disabled**. String/wildcard compare against `wh_sys_version`. | official wiki KM-A-57 |

**The `supports` trap.** Major releases ship without a patch number (`wh_sys_version` is `1.2`, not `1.2.0`), so `1.2.*` never matches `1.2`. Write `1.2*`, or `1.*` for any 1.x. Leave `supports` out to mean "any version" (official wiki KM-A-57). Only restrict versions if you override major vanilla files and actually tested them.

**Encoding.** Keep `encoding="utf-8"` in the XML declaration. The official template says `us-ascii` and the game accepts it, but some mod managers fail to parse such manifests (tutorial episode 1; old context doc, community).

**Reserved modids.** A modid equal to one of Warhorse's own table-part names makes your "patch" file collide with a vanilla part: `horse` → `item__horse.xml` replaces vanilla's instead of patching it. The list has ~780 names including `alchemy`, `base`, `clothes`, `combat`, `crime`, `dlc`, `horse`, `perk`, `player`, `quests`, `test`, `tests` and most quest names (official wiki [KM-A-35](https://warhorse.youtrack.cloud/articles/KM-A-35)). Prefix your modid with something unique.

## Load order

Default order (official wiki KM-A-3, KM-A-56):

1. Workshop subscriptions, in Steam API order ("arbitrary").
2. `Mods/`, alphabetically (`[Mod] Loading mods in alphabetical order`).

With `Mods/mod_order.txt`, each line is a **modid** (not a folder name) and mods load in that order. Mods missing from the file are not loaded, including Workshop ones (official wiki KM-A-56).

Load order decides:

- **Overrides:** same path in two mods → the later-loaded mod's file wins (official wiki KM-A-3).
- **Table patches:** applied after all regular table parts, in mod load order, so a later patch of the same row lands on top (official wiki KM-A-12).
- **Global singletons:** anything with exactly one instance, such as the facial-animation index `Animations/FacialAnimations.img`, goes to the last loader (lipsync.md, verified in game).

## Merge vs override

| | Merge (`__modid` conventions) | Override (same path) |
|---|---|---|
| Works for | tables that support patching, Storm root, localization, own quest graph, own Lua entry | any file |
| Conflicts | only when two mods touch the same row | with every mod shipping that path |
| Game patches | vanilla rows you did not touch keep updating | the file is frozen at the build you copied; Warhorse fixes to it are silently reverted for your users (quest-override-battles.md) |

Use an override only when no merge format exists. Real override examples: an empty `Videos/startup/startup_01/startup_01.bk2` skips the intro; replaced `Libs/UI/Textures/Overlays/Helmets/helmet_1..8.dds` removes the visor overlay (tutorial episode 1).

## Building paks

Rules (official wiki KM-A-3, KM-A-58; tutorial episode 1):

- Zip format, extension renamed to `.pak`.
- The archive root holds `Libs/`, `Scripts/`, `AI/`... directly. **No wrapping folder.**
- Store (0 compression) is the documented format.
- You can use one pak or many; the split does not matter.

What is actually tolerated, and the tools that work:

| Tool | Result | Source |
|---|---|---|
| Windows Explorer "Compressed (zipped) folder" (Windows 10), Total Commander | works | official wiki KM-A-58 |
| .NET `ZipFile.CreateFromDirectory(src, pak, CompressionLevel.NoCompression, $false)` | works; this is what the Mercenaries packager uses | mod: `PackageMod.bat` |
| 7-Zip `7z a -tzip -mx0 <pak> <src>\*` | works in practice | tutorial episode 1 (verified in game) |
| 7-Zip, default settings | "doesn't work" per Warhorse | official wiki KM-A-58 |
| Deflate-compressed pak | loads; the mod's 124 MB facial index ships deflated, and vanilla `Facials_english-part0.pak` is deflated too | lipsync.md (verified in game) |

The wiki's 7-Zip warning and the tutorial's working 7-Zip command are not a real conflict: the verified command forces zip format and Store. Precedence rule applied: verified in game over official wiki. Store is still the safe default.

Two more observations. Vanilla voice paks hold exactly 65,535 entries each (`english-part0.pak`), the plain zip32 entry limit, so keep a single pak under that (observed in retail paks; whether zip64 paks load is unverified). Python's `zipfile` refuses some vanilla paks because CryEngine writes backslash paths in local headers; patch `ZipInfo.orig_filename` to read them (camp-inspection.md, retail binary).

## mod.cfg

- Loose file at the mod root, never inside a pak. One cvar per line, `name = value` or `name=value` (official wiki KM-A-8).
- `--` line comments work. The Mercenaries `mod.cfg` is mostly comments and loads fine (mod: `mod.cfg`, verified in game).
- Applied at startup (`Loading config file 'mods/<modid>/mod.cfg'`). It is the supported way to set a cvar persistently, and it survives the `CVarOverride` re-application that undoes in-session `System.SetCVar` changes on context switches (npc-lod.md; mod `mod.cfg` header).
- If a mod has no `mod.cfg` the game logs `[Error] Validator: Config file 'mods/<modid>/mod.cfg' not found!` every launch. It is harmless; ship an empty one to silence it (mod: `mod.cfg` header, verified in game).
- Cvar reference: [console-variables.md](console-variables.md).

## Localization (text)

Every visible string is a **string id** (e.g. an item's `UIName`, a dialogue line's `StringName`) looked up in the active language (official wiki [KM-A-91](https://warhorse.youtrack.cloud/articles/KM-A-91)).

```
Localization/
  English_xml.pak      contains text__<modid>.xml (any name ending __<modid>.xml)
  German_xml.pak       same file name, translated rows
```

```xml
<Table>
  <Row><Cell>pack_mule_hello</Cell><Cell>Hello</Cell><Cell>Henry is now a pack mule.</Cell></Row>
</Table>
```

- Cell 1 = string id, cell 2 = ignored (source language), cell 3 = displayed text (official wiki KM-A-91).
- Text paks are `<Language>_xml.pak`. The 16 names: `Chineses Chineset Czech English French German Italian Japanese Korean Polish Portuguese Russian Spanish Turkish Ukrainian Vietnamese` (tutorial episode 1; retail `Localization/`). Voice paks are `<language>.pak` (official wiki KM-A-91).
- File name inside the pak: `<anything>__<modid>.xml`. Files not following the pattern still load, at the wrong time, and spam `<localization dupe/clash detection> Hash: ..., Key: ...` (official wiki KM-A-91; string in retail binary: sub_71AEC0). Before patch 1.3 only `text__<modid>.xml` loaded reliably. The Mercenaries mod ships `test__mercenaries.xml` (a typo of `text`) and it loads on 1.5 (verified in game), so the prefix really is free. The snapshot of KM-A-91 renders the pattern as `anything_modid.xml` with one underscore; that is most likely lost markdown, the tutorial and the working mod use two.
- The log confirms each file: `[Mod] Loading localization patch '%s'` (retail binary: sub_71AEC0).
- A player whose language your mod lacks gets English (official wiki KM-A-91). A language pak you do ship but that lacks a row shows the **raw key** with no log line; `Game.SendInfoText` keys therefore need a row in every language file you ship (ui-building.md, verified in game).
- Vanilla keeps its text in 11 files per language pak (`text_ui_dialog.xml`, `text_ui_items.xml`, `text_ui_quest.xml`, `text_ui_soul.xml`, ...; retail `English_xml.pak`). Grep them to reuse an existing string id instead of adding one.
- Editing tip: Python `ElementTree.write` drops XML comments. Splice rows in as text if the files carry hand-written comments (ui-building.md).
- Skald has a "Disabled" localization mode that writes translations into the quest XML's `Text` attributes, and a "PAKs" mode that writes `StringName`s plus per-language `<lang>_xml.pak`. Only the PAK route localizes properly (official wiki KM-A-18). Details: [skald-quests-dialog.md](skald-quests-dialog.md#text-stringname-and-localization).

## Dev build vs retail

The Modding Tools (separate Steam app `KCD2Mod`, free with the game) are a second game install with a development build in `Bin/Win64ReleaseSteamLTO_DLL/` (official wiki KM-A-55). Differences that matter for mod structure:

| | Retail | Dev build (`KCD2Mod`) |
|---|---|---|
| Loose files in `Data/` and `mods/` | ignored (only `mod.manifest`, `mod.cfg`) | loaded; priority set by `sys_pakPriority` 0 files>paks (default), 1 paks>files, 2 paks only. Set it in `user.cfg`, it must be set before engine start (official wiki KM-A-58) |
| Workshop subscriptions | loaded | **not loaded**: different Steam app id (official wiki KM-A-55) |
| Skald/quest load errors | silent | named in `KCD2Mod/kcd.log` (npc-lod.md, verified in game) |
| Facial animation data | present | **absent** (`Data/Facials` missing), so nobody's lips move (lipsync.md) |
| Save/load time | ~20 s | ~1 min ([how-to-mod.md](../general/how-to-mod.md), community) |
| Tolerance | strict | more permissive of bad mod code (community, same source) |
| Debug web server | no | `http://localhost:1403`, API browser at `/static/apiBrowser.html` (official wiki KM-A-55) |

Saves are compatible between the two (official wiki KM-A-55). `Data/Developer.pak` exists only in the tools install and Skald needs it; the WorkspaceSetup tool links or copies the retail paks into the tools install (official wiki KM-A-55). Always re-test the packed mod in retail. More in [debugging.md](debugging.md) and [lua-scripting.md](lua-scripting.md#how-mod-lua-gets-loaded).

## Publishing

1. Pack everything under `Data/` and `Localization/` into paks (retail loads nothing loose).
2. Folder to upload = the folder holding `mod.manifest`:
   ```
   mod_folder/  mod.manifest  mod.cfg  data/*.pak  localization/*_xml.pak  localization/<language>.pak
   ```
3. Steam Workshop: only through `Tools/SteamWorkshopUploader/SteamWorkshopUploader.exe` from the Modding Tools; the Steam client cannot upload. Needs an activated KCD2 key (family sharing or a free weekend may fail). Cover image **at most 1 MB** or the upload fails. The Workshop title may differ from the manifest `name`. First upload is **hidden**; change visibility in the Steam client. Accept the Workshop legal agreement once per account. Failures return a Steamworks `EResult` (official wiki [KM-A-85](https://warhorse.youtrack.cloud/articles/KM-A-85)). The uploader and WorkspaceSetup need .NET Desktop Runtime 6; Skald and Smid need .NET Framework 4.8 (official wiki KM-A-55).
4. Workshop rules: mark mature content, upload only your own work or with permission, no malicious code, avoid external dependencies, accurate tags, proper thumbnail, no ads or monetization, follow Steam's rules (official wiki [KM-A-87](https://warhorse.youtrack.cloud/articles/KM-A-87)). Deep Silver's announcement adds: no paywalling without permission, identify the mod as fan content (community: DeepSilver modding page, see [sources.md](sources.md)).
5. Nexus or manual install: the same folder, zipped. Players drop it into `Mods/`. Mods that change files outside `data/` (e.g. shader paks) need manual steps you must document (official wiki KM-A-56).

Installing mods does not disable achievements (official wiki KM-A-56).

## Versions and compatibility

- **Gate with `supports`** when you override vanilla files (see [mod.manifest](#modmanifest)). Log strings tell you what happened: `supports game version '%s' explicitly`, `... by wildcard '%s'`, `is not limited to any game version`, `doesn't support game version '%s', it will be disabled` (retail binary: sub_244172C).
- **What breaks on a game patch:** full-file overrides (frozen copy; re-derive from the new vanilla file); a shipped `FacialAnimations.img` (new vanilla dialogue loses its face until you regenerate it, lipsync.md); native plugins that hard-code offsets (`gEnv` moves on almost every patch, even between builds with the same version string, disassembly.md). Table patches and your own quest graph usually survive.
- **Patch notes 1.2.2 to 1.5.3 changed nothing about mod loading, pak format or scripting**; 1.2.4 fixed saving "when having too many mods installed" (community: Fextralife patch notes, see [sources.md](sources.md)).
- **Removing a mod from a running playthrough.** Spawned entities of mod-defined classes stay in the save and render as untextured placeholders ("white pyramids"); vanilla-class entities stay as they are. Rows your table patches added and your quest graph cannot be cleaned from Lua. A measured "old saves load slowly after uninstall" symptom was not caused by leftover entities; dangling references into removed table rows and quest graphs are the remaining suspect (save-footprint.md, entity part verified in game, table/quest part unverified). Ship an uninstall/cleanup command if your mod spawns things.
- **Mods share one Lua state** and one `Scripts/Mods/` folder: keep all globals in one table named after your modid and prefix extra files with it (tutorial episode 1).
- **Mods share one keybind namespace**: two mods binding the same key with `bind` overwrite each other silently (command-ui.md).

## Reading kcd.log

`<game>/kcd.log` is rewritten every launch (retail logs little; the dev build logs much more). Exact strings from the retail binary:

| String | Meaning |
|---|---|
| `[Mod] Loading mods from %s/%s` / `[Mod] %d mods loaded from %s/` / `[Mod] %d mods enabled` | discovery summary |
| `[Mod] Loading mods in alphabetical order` | no `mod_order.txt` |
| `[Mod] %s not found`, `[Mod] %s has bad format` | manifest missing or malformed (meaning inferred from the caller, unverified) |
| `[Mod] '%s' has no version restrictions in manifest` | no `supports` block |
| `[Mod] '%s' doesn't support game version '%s', it will be disabled` | `supports` excluded this build |
| `[Mod] Opening paks in %s` | the mod's `data/*.pak` were opened |
| `[Mod] Loading localization patch '%s'` | a localization file was picked up |
| `Loading lua init script for mod %s ...` then `Loading and executing script file 'scripts/mods/<modid>.lua'` | Lua entry point ran |
| `Table '%s' is patched by '%s', lines added: %d, modified: %d, equal: %d` | a table patch merged; `modified` > 0 means it overrode existing rows |
| `Loading config file 'mods/<modid>/mod.cfg'` | `mod.cfg` applied |

Sources: retail binary sub_D9DD78, sub_D9DE94, sub_243F278, sub_244172C, sub_1DDCFD0, sub_71AEC0, sub_20E1330, sub_2749940; the `Loading and executing script file` and `Loading config file` lines are quoted from the official wiki KM-A-8 log. The dev build prints `Patched database Item with file 'item__<modid>.xml'` instead of the `Table ... is patched by` line (official wiki KM-A-17).

Silent-failure checklist (tutorial episode 1):

1. Mod never mentioned: wrong folder depth; it must be `Mods/<folder>/mod.manifest`.
2. Mod disabled: `supports`, or a `mod_order.txt` that does not list it.
3. Loaded, nothing changes: paths inside the pak (wrapping folder) or wrong patch filename.
4. Lua never runs: file not named exactly `Scripts/Mods/<modid>.lua`, or a syntax error.
5. Loose files: ignored in retail.

## Gotchas

- **Mod loads but nothing changes:** the pak has a wrapping folder (`src/Libs/...`). Open it and check the top level is `Libs/`/`Scripts/` (tutorial episode 1, verified in game).
- **Every Workshop mod stopped loading** after you added one line to `mod_order.txt`: unlisted mods, Workshop included, are not loaded at all (official wiki KM-A-56).
- **Mod disabled after a game patch** although it "supports 1.2.*": major versions have no patch number; write `1.2*` (official wiki KM-A-57).
- **Your table patch replaced a whole vanilla file** instead of patching it: your modid equals a reserved table-part name such as `horse` or `perk` (official wiki KM-A-35).
- **Works in the Modding Tools, does nothing in retail:** loose files. Pack them (official wiki KM-A-58).
- **Workshop mod not loading in the dev build:** by design; different Steam app (official wiki KM-A-55).
- **Log full of "hash clash" / `dupe/clash detection` lines:** localization file not named `<anything>__<modid>.xml` (official wiki KM-A-91).
- **Raw string key on screen:** the row is missing from a language file you ship (verified in game). The English fallback covers a missing language pak (official wiki KM-A-91), apparently not a missing row (inferred). See [Localization](#localization-text).
- **Mod manager crashes on your mod:** manifest without `encoding="utf-8"` (community, unverified which managers).
- **Vanilla NPCs lost their lipsync** after installing your mod: you shipped a partial `FacialAnimations.img`; it replaces vanilla's whole index (lipsync.md).
- **A Warhorse bugfix never reached your players:** you ship an override of that file (quest XML, AI XML); regenerate it after each patch (quest-override-battles.md).
- **Upload to Workshop fails:** cover image over 1 MB (official wiki KM-A-85).

## See also

- [data-tables.md](data-tables.md): table patch semantics, key tables, GUIDs.
- [skald-quests-dialog.md](skald-quests-dialog.md): the `Quests/<modid>.xml` graph.
- [audio-voice-lipsync.md](audio-voice-lipsync.md): voice paks and lipsync paks.
- [console-variables.md](console-variables.md), [sources.md](sources.md).
- Public guides: [Episode 1](../tutorials/episode-01-mod-setup.md), [how-to-mod.md](../general/how-to-mod.md).
- Mercenaries packagers `PackageMod.bat` / `PackageModDev.bat` (repo root) are a working reference for pak building, 16-language localization paks, voice and lipsync paks.
