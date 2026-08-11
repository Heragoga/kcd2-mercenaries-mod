# Overriding every main-quest battle so mercenaries render

This is the mod's answer to the invisible-mercenaries problem. It is a deliberate, committed
choice — not an experiment. The full investigation that led here is
[npc-lod.md](npc-lod.md); the single-quest prototype is
[quest-override-test.md](quest-override-test.md).

## Why this and not something cleaner

Mercs went invisible in every scripted battle while still dealing damage. Across ~44 test
sessions the following were each measured and ruled out: AI LOD tiers and budgets, the combat LOD
system, skirmish passive bands, battle groups and lite souls, the soul combat simulator, the
animation LOD system, the clothing pipeline, entity flags, deterrent areas, dialogue twins, quest
type, permanent battle contexts, and faction membership.

Exactly one thing ever made a merc render in a scripted battle: **listing its soul in the
quest's own `SoulAsset` nodes.** So that is what ships.

## What the tool does

`tools/OverrideMainQuestBattles.py` finds every **main quest** — a `<Quest>` node with **no
`Type` attribute**, which is what distinguishes a main story quest from `Activity`/`Side`/`Micro`
— whose file or folder contains battle machinery (`crime_global_battleInProgress`,
`battleGroupController`, `RequestBattleNPC`, `BattleDirector`, ladder/waking controllers).

It copies each quest into `data/Quests/` at the identical path so the mod pak overrides vanilla,
and appends all 83 merc soul GUIDs to the `SharedSoulGuids` list of every qualifying `SoulAsset`.

```
python tools/OverrideMainQuestBattles.py --list           # preview, writes nothing
python tools/OverrideMainQuestBattles.py --scope noHostile
python tools/OverrideMainQuestBattles.py --scope all
python tools/OverrideMainQuestBattles.py --revert
```

Idempotent: it re-copies from `references/` on every run, so it can never double-append.

## The 12 battles

| quest | files | SoulAssets |
| --- | ---: | ---: |
| utokNaNebakov | 332 | 157 |
| utokNaMalesov | 339 | 137 |
| nebakovObrana | 215 | 130 |
| prepadeniVlasskehoDvora | 368 | 108 |
| pogrom | 207 | 99 |
| hladAZmar | 262 | 95 |
| zoufalaObranaZaBohutu | 146 | 91 |
| setkaniVRatbori2 | 139 | 90 |
| finale | 124 | 83 |
| oblehaniSuchdole | 203 | 67 |
| rutinaAVypad | 191 | 65 |
| posledniPomazani | 13 | 6 |

Cross-check: this is exactly the set of quests that call `SetGameContextPreset` with
`crime_global_battleInProgress`, derived independently. Two different signals, same 12 quests.

## Scopes, and the hostility problem

The first prototype injected into **all** SoulAssets of Malesov. The merc rendered — and fought
for the garrison, attacking the player. Later bisects showed ally-side assets alone (64) and the
six named companions alone both rendered **nothing**. So the render comes from the enemy/roster
side, which is also where the hostility comes from.

| scope | behaviour |
| --- | --- |
| `all` | every SoulAsset. Proven to render; expect hostility. |
| `noHostile` *(shipped)* | every SoulAsset **except** those consumed by `EnableBehavior` or `SetRelationContext` — the nodes that force quest behaviour and forced targets onto a soul, i.e. the hostility mechanism. Keeps the bulk roster assets. |

Faction is per-soul and quests do not change it, so roster membership alone should not flip a
merc hostile once the behaviour-forcing assets are excluded.

**Current build:** `noHostile` — 2,539 files, **827 SoulAssets injected**, 68,641 GUID entries
added, **674 assets skipped**, all files validated as well-formed XML.

Reading the result:

* renders and stays loyal → done, in all 12 battles at once
* renders but hostile → widen the exclusion; the skipped list names the candidates
* still invisible → the render needs the behaviour nodes; switch to `--scope all` and correct
  merc targeting from our own Lua, which we control

## Maintenance

* **Version-pinned.** 2,539 files frozen at the current game build. Any patch to those 12 quests
  is silently reverted for users. Re-run the tool after a game patch — `references/` must be
  refreshed from the patched game data first.
* **Mod conflicts.** Any other mod touching these quests will conflict. Judged acceptable: few
  mods edit main-quest Skald graphs.
* **Saves.** These replace live main quests. Keep a backup save before testing; a save made
  inside a battle whose graph failed may not recover.
* **Never hand-edit** the files under `data/Quests/Final/`. They are generated. Change the tool.

## The case-collision trap (read before editing the tool)

On Windows **`data/Quests` and `data/quests` are the same directory**, and
`data/quests/mercenaries*` holds this mod's own quests — the hire, dismissal and quartermaster
dialogs, the gossips, barks and monologs, 155 files. An early version of this tool did
`shutil.rmtree(DST_ROOT)` where `DST_ROOT = data/Quests`, and **deleted all of them**. They were
recoverable only because they were committed to git (`git checkout HEAD -- data/quests/`).

The tool now:

* only ever removes **`data/Quests/Final/`** (`MANAGED`), the subtree it generates;
* runs `assert_not_ours()` before any delete, which hard-exits on a path containing
  `mercenaries`;
* removes `data/Quests` itself only when genuinely empty, never forced.

`tools/OverrideMalesovQuest.py` was audited and is safe — its delete target is a deep per-quest
path, and its parent cleanup only removes empty directories and stops at `data/`.

Anything that writes under `data/quests/` must assume the mod's own quests are siblings.
