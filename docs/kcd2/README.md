---
title: KCD2 modding knowledge base
summary: Index of the game knowledge base - what is true for any KCD2 mod, where each topic lives, how to search it and how to keep it current.
tags: [lua, ai, skald, ui, data, engine, tooling]
kind: index
status: current
scope: kcd2
verified: release_1_5
---

# KCD2 modding knowledge base

Everything here is true for **any** Kingdom Come: Deliverance 2 mod, not just Mercenaries. It merges
the official modding wiki, the official ScriptBind docs, what the retail `WHGame.dll` shows, vanilla
game files, public community docs and a year of hands-on findings from building this mod. The
war stories behind the findings stay in the Mercenaries mod's own docs (`docs/mercenaries/`, in the
mod's source repo); the pages here point to them.

## How to find things

| You want | Do this |
|---|---|
| Anything, by keyword or symptom | `python tools/kb.py search "timer survives save"` (add `--scope kcd2`, `--source api,wiki`) |
| A Lua function's signature, whether it exists in retail, who uses it | `python tools/kb.py api Entity.GetWorldPos` · browse [api/](api/README.md) |
| A console variable | `python tools/kb.py cvar "^ai_Compat"` · [console-variables.md](console-variables.md) |
| One section, without opening the page | `python tools/kb.py show docs/kcd2/lua-scripting.md#gotchas` |
| A browsable, searchable site | `python tools/kb.py serve` then open http://127.0.0.1:8765/ |
| The trap you just walked into | [gotchas.md](gotchas.md) - every known trap, symptom first |
| A term that means three things | [glossary.md](glossary.md) |
| Where a fact came from, or a source to read | [sources.md](sources.md) |

The search index also covers the offline copy of the official wiki; `python tools/kb.py build
--with-vanilla` adds the vanilla scripts and tables (local only, ~40 s).

## Reading a page

Every page opens with a **TL;DR**, ends with **Gotchas**, and tags each non-obvious claim with where
it comes from. When sources disagree the pages say so, and rank them:

`verified in game` > `retail binary` (disassembly) > `vanilla` (game files) > `official wiki` /
`script_bind docs` > `community` > `(unverified)`

`verified: release_1_5` in the frontmatter is the game build the page was checked against.

## Pages

<!-- BEGIN GENERATED: pages (tools/gen_kb_index.py) -->

### Start here

| Page | What it answers |
|---|---|
| [Mod structure, packaging and load order](mod-structure.md) | What a KCD2 mod folder must contain, which files go in which pak, how mods merge and override each other, how load order works, and how to publish and keep a mod working across game patches. |
| [Lua scripting](lua-scripting.md) | How mod Lua is loaded and run in KCD2, what survives a save or a level change, how timers really behave, and what Lua cannot do. |
| [Debugging and testing](debugging.md) | Where KCD2 reports errors, how to get real Lua errors out of it, dev mode and the console, inspecting live state, profiling, automated test harnesses, and the common crash causes. |

### AI and NPCs

| Page | What it answers |
|---|---|
| [Behaviour trees (XGEN / MBT) reference](behavior-trees.md) | File structure, variables, expression syntax, node catalogue, Lua nodes, functions, interrupts and timing rules of KCD2 behaviour trees, verified against vanilla. |
| [AI brains, souls and NPCs](ai-brains-and-npcs.md) | How a KCD2 NPC is assembled (soul, brain, subbrains, SmartEntity, factions, Storm), how to spawn one, and the traps in factions, smart objects, followers, equipment, appearance and female NPCs. |
| [Combat, crime and perception](combat-and-perception.md) | How NPC combat is layered, how to start and end a fight from a behaviour tree, what drives positioning, target choice, morale, the crime system, perception, formations and NPC-vs-NPC collision. |
| [Formations (engine system)](formations.md) | How does vanilla KCD2's behaviour-tree formation system work - presets, the five live nodes, modes, slot selection, leader/follower rendezvous, fighting in formation - and what can a mod reuse, replace or never reach? |
| [NPC rendering, LOD and invisible NPCs](npc-rendering-and-lod.md) | Why KCD2 NPCs pop in and out or go invisible while still fighting (AI LOD tiers, renderer view distance, clothing assembly, quest and battle mechanics, content errors), how to diagnose each, and what a mod can do. |

### Quests, data and audio

| Page | What it answers |
|---|---|
| [Skald quests and dialogue](skald-quests-dialog.md) | How KCD2's Skald concept graph works for a mod - file layout, quests, objectives and map markers, assets, every dialogue flavour (fader, forced, chat menus, monologs), the Lua-Skald bridge, and the node-level traps that silently kill a mod's whole quest graph. |
| [Data tables (the game database)](data-tables.md) | How KCD2's XML table database is laid out, how a mod patches it with __modid files, what the key tables (items, presets, buffs, RPG params, souls, factions, shops, Skald characters) look like, GUID conventions, and how to find things in vanilla data. |
| [Audio, voice lines and lipsync](audio-voice-lipsync.md) | How KCD2 finds and plays a dialogue voice line (format, naming, paks, voice ids, fallbacks), how facial lipsync binds to it and how a mod bakes its own, how barks work, and where sound and music hooks live. |

### UI, assets and the world

| Page | What it answers |
|---|---|
| [Scaleform UI](ui-scaleform.md) | How to put anything on screen in KCD2 - the UIAction Lua bridge, vanilla elements you can drive, shipping your own .swf, map/compass markers, immediate-mode drawing, fonts and metrics, and input for custom screens. |
| [Assets pipeline](assets-pipeline.md) | How to get your own static meshes, materials and textures into KCD2 (Blender -> FBX -> rc.exe -> .cgf), how to read and enumerate the game's own assets, and how to spawn static geometry without a custom entity class. |
| [World and physics](world-and-physics.md) | Levels and region crossings, time and fast-travel detection, raycasts and what counts as the ground, interior area labels, collision classes and NPC-vs-prop collision, the baked navmesh and what can still steer NPCs around runtime geometry. |

### Engine and lookup tables

| Page | What it answers |
|---|---|
| [Engine internals](engine-internals.md) | What KCD2's engine is under the hood (CryEngine fork, WHGame.dll, gEnv, vtables), how native ASI plugins reach it, and how to query the disassembly corpus. |
| [Console variables](console-variables.md) | How KCD2 cvars work, what the prefix groups are, and which ones this mod or vanilla scripts actually touch. |
| [KCD2 Lua ScriptBind API reference](api/README.md) | Generated reference of every Lua ScriptBind function, cross-checked against the retail binary and the runtime Lua state dump. |
| [Generated data files](data/README.md) | What each file under docs/kcd2/data/ is, how it was built, and how to regenerate it. |

### Cross-cutting

| Page | What it answers |
|---|---|
| [Gotchas (all pages)](gotchas.md) | Every known KCD2 modding trap from the knowledge base in one list, symptom first - search this page for the symptom you are seeing. |
| [Glossary](glossary.md) | Disambiguation for KCD2 modding terms that mean several unrelated things, plus one-line definitions for the vocabulary a modder or agent meets across this knowledge base. |
| [Sources](sources.md) | Catalogue of every local and online source the KCD2 knowledge base draws on, and how to keep it fresh. |

<!-- END GENERATED: pages -->

## Keeping it current

- **Found something new?** Put it on the topic page it belongs to, with its provenance. If it's a
  trap, add it to that page's `## Gotchas`, then run `python tools/gen_kb_index.py` to rebuild
  [gotchas.md](gotchas.md) and the table above. If it corrects an API page, add a row to
  `tools/api_annotations.tsv` rather than editing the generated page.
- **After a game patch:** `python tools/disasm_build.py`, `python tools/gen_api_reference.py`,
  `python tools/gen_cvar_reference.py`, then re-check pages marked `verified: <old build>`.
- **Before committing docs:** `python tools/kb.py check` (links, anchors, frontmatter) and
  `python tools/gen_kb_index.py --check`.
