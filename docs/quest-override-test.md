# Quest-override experiment: putting a merc soul in utokNaMalesov

An experiment, not a shipped feature. It tests the oldest hypothesis in the invisible-merc
investigation: **main quests list the souls they care about, and the game renders those souls
while everything else drops to MonsterLOD.** If SoulAsset membership is what earns an NPC its
render slot during a scripted battle, a merc soul present in *every* SoulAsset of the Malesov
battle should render like a quest soldier.

Background on the bug and the 35 runs behind it: [npc-lod.md](npc-lod.md).

## What it does

`tools/OverrideMalesovQuest.py` copies the vanilla quest out of `references/` into `data/` at
the **same path**, so the mod pak's copy wins over the vanilla one:

```
data/Quests/Final/Barbora/kutnohorsko/utokNaMalesov.xml
data/Quests/Final/Barbora/kutnohorsko/utokNaMalesov/**      (339 xml files total)
```

While copying, it appends one merc soul GUID to every `SharedSoulGuids` attribute it finds —
**137 lists across 31 files**. Nothing else in the quest is altered; the remaining 308 files are
byte-identical copies. Every file was verified to still parse as XML.

The soul is `e1f2a3b4-1234-4efa-c890-123456789012` — `mercenaries.TestSoulGuid` in
[mercenaries_spawning.lua](../data/Scripts/mods/mercenaries_spawning.lua). One fixed soul is the
whole point: the normal `Hire` path cycles `SoulIndex` across the tier list, so a hired merc
could be any of ~80 souls and we would have to inject all of them.

`merc_testmerc` spawns exactly one merc bound to that soul — free, no cap check, no
dismissal/idle state changes, and named with the usual `SpawnedFriend_` prefix so the cache,
follow, targeting and every LOD probe treat it as a normal merc.

## Running it

```
python tools/OverrideMalesovQuest.py      # write the override
PackageMod.bat                            # repack and launch
```

In game, before or during the battle:

```
merc_testmerc
```

Then fight and watch whether that one merc renders.

To undo — do this before shipping anything, and any time you want vanilla behaviour back:

```
python tools/OverrideMalesovQuest.py --revert
```

The script is idempotent: it re-copies from `references/` every run, so it can never
double-append.

## RESULT: it worked

The test merc **rendered** in the Malesov battle. Quest SoulAsset membership is the render gate —
the theory that opened this whole investigation, after 35 runs of cvar bisecting said otherwise.

It also **attacked the player**, for a simple reason: the first pass injected into *all* 137
SoulAssets, which includes both armies. The merc was simultaneously in `zizkaband`,
`brabantSoldiers`, `villageReinforcements` (Zizka's side, the player's) **and** in
`innerCourtyardDefender_1..7`, `towerDefenders`, `outerCourtyardDefenders`, `malesovTowerShooters`
(the Malesov garrison). The quest's own relation and behaviour nodes then treated it as a
defender. Fixed by `--group ally` (now the default): 67 lists in 17 files, every enemy asset left
untouched.

## Which node actually grants the render (open, one session from an answer)

Membership alone cannot be the whole story: `mercenaries_background_quest.xml` **already** has a
`mercs` SoulAsset listing all ~80 merc souls, and mercs still vanish. So something in Malesov
*acts on* the souls in its assets. Structural diff of the two quests:

| node type | utokNaMalesov | background quest |
| --- | ---: | ---: |
| `EnableBehavior` | 77 | **0** |
| `SetEntityContext` | 42 | 2 |
| `SchedulerLinkActivation` | 20 | 0 |
| `ProfileAsset` | 21 | 0 |
| `Layer` | 15 | 0 |
| `MakeArray` | 137 | 4 |

`EnableBehavior` is the prime suspect. Its 77 uses target smart objects (`qSo`, group
controllers) and, crucially, the **named companions** — `zizka` (10), `sam` (9), `hans` (7),
`komar` (6), `ptacek` (5), `cert` (4) — all of which the merc was injected into.

Mechanism hypothesis: a quest-enabled behaviour forces a **MonsterLOD wake-up**. The engine has
`WH_AI_LOD_MaxCountLODUnstealableByMLWakeUp` and warns *"Too many MonsterLOD wakeups! Script
logic issue"*, and run 35 measured `32 Forced from ML` against `666 Forced to ML` — 32 being
roughly the quest roster. Note the enabled behaviours (`fight`, `defendTower`, `shooter_move`,
`runAndHide`) do **not** carry `PreventsMonsterLod`, so this is a wake, not a constraint.

Discounted: `zizkaband` receives only `SetEntityContext` (combat contexts:
`combat_suppressFriendlyFire`, `combat_neverSurrenderOrFlee`, …) and `BuffEffect` — nothing
render-related.

**Next test, one session:**

```
python tools/OverrideMalesovQuest.py --assets "^(zizka|sam|hans|komar|ptacek|cert)$"
```

Six SoulAssets, all `EnableBehavior` targets. If the merc still renders, `EnableBehavior` on a
soul is the render mechanism, and the general fix becomes: **our background quest enables one of
our own smart behaviours on the `mercs` SoulAsset, permanently.** If it does *not* render, the
mechanism is one of the bulk assets and the next cut is `--assets "Reinforcement"`.

## How to read the result

* **The merc renders** — SoulAsset membership is the render gate. That is the answer to the
  whole investigation, and the shippable version becomes a much smaller question: which
  SoulAssets actually matter, and can the mod inject into them at runtime instead of shipping a
  339-file quest override (which it should not).
* **The merc stays invisible** — soul membership is *not* the gate, and the remaining suspect is
  `ProfileAsset` (see below). Either way the hypothesis is settled, which three sessions of cvar
  bisecting did not manage.

## Honest caveats

* **`ProfileAsset` is the more likely gate, and this experiment cannot reach it.** Vanilla
  battle NPCs are also referenced by 27 `ProfileAsset` nodes pointing at level layer names
  (`utoknamalesov_innercourtyard_basiccrew`). Those layers are baked into the level, and a
  runtime-spawned entity cannot join one. If rendering is driven by profile/layer streaming
  rather than soul membership, this override will change nothing — and that is a real
  possibility, not a remote one.
* **Unverified: whether a mod pak overrides a vanilla *quest* file at all.** The mod's existing
  quests are new files, not overrides. Path-based override is the normal KCD2 behaviour, but it
  has not been proven for `Quests/`. Check `kcd.log` after loading for quest-load errors or
  duplicate-definition complaints before trusting a negative result.
* Path casing is *not* a concern: Windows folded the copy into the pre-existing lowercase
  `data/quests/`, so the pak records `quests/Final/…` against vanilla's `Quests/Final/…`. CryPak
  matches case-insensitively — this mod's own `data/libs/tables/` and `data/quests/` already load
  against vanilla `Libs/Tables/` and `Quests/`, and reference mods mix `Data/Libs` and
  `data/libs` freely.
* **This must not ship.** It pins 339 files of a main quest to one game version; the next patch
  makes them stale and would silently revert Warhorse's own fixes to that quest.
* Quest GUIDs and structure are untouched, so a save mid-Malesov should still load — but take a
  backup save before testing anyway.
