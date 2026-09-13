# Crossing between Trosky and Kuttenberg

Fast travel between the two regions is **a full level change**, and that is what was behind
the reports of the camp, the palisade and the archer towers "disappearing after fast
travelling". Nothing was corrupted and nothing was lost — the mod simply arrived in a world
where none of its own entities existed and reported an empty company.

---

## What the engine actually does

`kutnohorsko` and `trosecko` are separate levels. Travelling between them loads one:

```
[DEBUG] 1: @ui_level_fasttravel_trosecko
[DEBUG] EventSystemListener: actionName[System] eventName[OnQuickLoadingStart]
============================ Loading level trosecko ============================
[DEBUG] EventSystemListener: actionName[System] eventName[OnGameplayStarted]
```

**Every entity the mod spawns belongs to the level it was spawned in.** That is the men, the
camp props, the wall segments, the gates, the towers and the carts — and, decisively, the
hidden `BasicEntity` "saver" entities named `mercenary_mod_state_data_<tag>__<value>` that
carry *every* persisted tag (`mercenaries_saving.lua`). They do not exist in the other level,
so `OnGameplayStarted` there rebuilds the tag map from a world that has none of them and
every `LoadString` answers nil.

Measured, one session, `LogBackups/kcd Build(0) 27 Aug 26 (22 55 21).log`:

| | kutnohorsko | after `Loading level trosecko` |
|---|---|---|
| men | `Active mercs: 50` | `Active mercs: 3` |
| supply | `food=15 drink=15` | `food=0 drink=0 coffer=0`, no upgrades |
| camp | `[Camp] restored saved camp` | nothing |
| defences | `1 wall run/14 corners, 2 carts` + 11 towers | `[Defences] new pitch - previous camp's defences left behind` |

It was never permanent: the other level's entities are still standing, so travelling back
brought everything with it (`mercs 6 -> 0 -> 6` across the round trips in the 07 Jul and
09 May logs). The player was just never told.

**Intra-region fast travel is not this.** A jump on the map inside one region is a plain
teleport — `[FTTrace] PLAYER JUMPED 1784m` with no level load and no `OnGameplayStarted` —
and nothing of the mod's is touched.

## Why the mod could not see it

* There is no level-name API. `System.GetCurrLevelName`, `Game.GetLevelName` and
  `System.GetCurrAsyncLevelName` all come back empty in KCD2 — `merc_bcamp_dump` has been
  printing `level = "unknown"` into site rows for exactly this reason.
* `OnGameplayStarted` calls `SaverForget()` and rescans, so the previous region's values were
  dropped before anything could compare them.

## What does survive: Lua

Lua tables live through a level change. The base game itself relies on it —
`references/Scripts/GameRules/SinglePlayer.lua` stashes a game token in the Lua global
`g_GameTokenPreviousLevel` across `EndLevel` / `OnStartLevel` because *tokens* do not
survive. The mod's own evidence of the same thing is in the log: the scheduler's load
generation comes back as `epoch 2` and the `[MercForm] rebuild #N` counter carries on
counting.

That is the whole mechanism `mercenaries_region.lua` is built on.

## The carry

**The company follows the player. The camp stays where it was built.**

1. `RegionCaptureTags()` runs at the top of `OnGameplayStarted`, **before** `SaverForget()` —
   the last moment `SaverValues` and `ActiveMercs` still describe the level being left. It
   copies the tags and the merc *names* (the entity handles are already dead).
2. `RegionOnLoad()` runs immediately after the forget, ahead of every `LoadString` in
   `OnGameplayStarted`, so the rest of the load reads the carried state naturally.
3. If this region has none of the mod's tags, or its own are staler than the carry
   (`MercStateWhen`, stamped each low-priority pass and rounded to the world hour), the
   carried tags are written here and the men are queued to be brought across.
4. `RegionRestoreDelayed` (3 s in, after the merc cache rebuild at 2 s) sweeps any of our men
   this region holds that the company no longer has, then `RegionSpawnStep` re-spawns the
   roster four at a time — fifty NPCs and their gear in one frame is a hitch, and the equip
   pipeline wants frames between its passes anyway.

A man is rebuilt from **his entity name**: the prefix says foot, archer (`_archer_`) or named
companion (`_hero_`), and the last field is his soul, so he comes back with the same face. He
keeps the same name, which is what stops a later crossing duplicating him.

### Identity check

Loading an unrelated save is the one thing that looks like a crossing from inside the mod, so
the **world clock** decides: a crossing carries it forward by the travel time, and the carry
is refused unless the clock moved forward by no more than `RegionMaxDayGap` (2 days). Loading
an earlier save moves it backwards; loading a much later one overshoots. Between that and the
`MercStateWhen` comparison, a save that is genuinely newer than the carry is never clobbered.

### What is left behind, and why

A camp is pitched on a *spot*, and its walls, gates, towers and carts stand on that spot, so
those tags never travel (`RegionPlaceTags` / `RegionPlacePrefixes`):

`MercCampActive`, `MercCampX/Y/Z/Ang`, `MercCampTiles`, `MercOutParty`, `QMDefX/Y`,
`QMWallPts`, `QMWallClosed`, `QMWallType`, `QMGates`, `QMTowers`, `QMCarts`, `QMRoutes`,
`BCampLayout`, `EditorOwner`, and anything starting `Alx` (Aleksej lodges in Kuttenberg) or
`Torture` (the test rig).

Nothing forces the destination's camp flag either way: a region with no camp of its own gets
none, and travelling back to the one the camp was pitched in puts it up again off its own
anchor. `RestoreCampDelayed` holds off for a second at a time while men are still being
brought across, so the camp is not laid out around half a squad.

Everything else follows: roster flags, outfit and weapon presets, the custom gear pattern,
coffer, food, drink, morale, tiredness, wages, every upgrade, difficulty, orders, contract
progress.

### Console

| Command | |
|---|---|
| `merc_region` | what would follow the player to the other map, and which side's stamp is newer |
| `merc_region_carry 0\|1` | turn the carry off / on |

---

## The other half: a rebuild is not a new pitch

Separately from the region change, `DefRestoreBody` used to `DefForget()` — permanently
erasing the wall, gates, towers and carts from the save — whenever the standing camp's anchor
did not match the one the defences were built at, within `DefAnchorEps` (2 m).

That is right for a camp the player pitched somewhere new. It is wrong for a **rebuild**
(a save load, or buying an upgrade), because `SpawnMercCamp` re-runs its ground search on the
saved anchor and re-saves the result — and that search reads static geometry, which streams.
Rebuild the camp with its surroundings not yet loaded and the winning cell can shift a couple
of metres, past the tolerance, for no reason the player did anything about.

`DefArmRestore(rebuild)` now carries that distinction. On a rebuild the anchor **follows the
camp** — the wall's corners are absolute world points and did not move — and the log says so:

```
[Defences] rebuild moved the camp anchor - defences re-anchored, not abandoned
```

Only a genuine new pitch still leaves a layout behind.
