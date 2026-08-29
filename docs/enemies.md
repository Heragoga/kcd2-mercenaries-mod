# Enemy Groups

Six hostile groups that replace the old single "renegade" test enemy. They exist to fight the player's squad — nothing else. Every group **only attacks the player and the player's mercs, archers and companions** (the `mercenariesFaction`); it ignores (and is ignored by) vanilla NPCs — including the player's *friendly* NPCs — and the groups do not fight each other.

| Group | Console prefix | Souls | Tiers (combat level) | Clothing | Archers |
|---|---|---|---|---|---|
| Looters | `enemy_spawn_looters` | 10 | all weak (0.5) | `enemy_looter_*` — rags or a shabby gambeson | yes |
| Bandits | `enemy_spawn_bandits` | 10 | 5 medium (0.7) + 5 strong (0.9) | `enemy_bandit_*` — rusty mail, open helmets | yes |
| Sigismund's soldiers | `enemy_spawn_sigi` | 10 | 5 weak + 5 medium | `enemy_sigi_*` — Magyar/Uher livery, open helmets | yes |
| Prague regiment | `enemy_spawn_prague` | 10 | 5 medium + 5 strong | `enemy_prague_*` — Prague livery, open helmets | yes |
| Cumans | `enemy_spawn_cumans` | 10 | 4 weak + 3 medium + 3 strong | `enemy_cuman_*` — Cuman kit, wide mix; Cuman faces (`tvez` roma bodies) + Cuman voices | yes |
| Sigismund's knights | `enemy_spawn_knights` | 5 | elite (1.0) + health boost | `enemy_knight_*` — best plate, closed visors, 12 noble houses | no |
| Heinrich (boss) | `enemy_spawn_heinrich` | 1 | elite (1.0) + 2× health | Henry's look + his final plate armour + St. George's sword | no |

## Wardrobes

Each group has 12 clothing presets of its own (`enemy_<group>_NN` in `clothing_preset__mercenaries.xml`), built the same way as the squad wardrobe — see [Squad outfits](outfits.md) for the budget method and the layering rules. What differs is that each group is a distinct **identity**, not a tier:

| Group | Armour budget | Quality / Condition | Silhouette | Shields |
|---|---|---|---|---|
| Looters | 30–121 | 1 / 0.12–0.32 | rags or a shabby open gambeson. No helmet, coif, mail, plate or leg armour | **none** |
| Bandits | ~700 | 1 / 0.22–0.42 | looted mail over a gambeson, scrap plate on the limbs, open helmet. Never a cuirass or brigandine | 1 draw in 6 |
| Sigismund's soldiers | ~1500 | 2 / 0.62–0.82 | good kit, **open helmets only**, Magyar/Uher livery on every man | 3 in 6 |
| Prague regiment | ~1500 | 2 / 0.64–0.84 | same standard, Prague livery, open helmets | 3 in 6 |
| Cumans | ~1100 | 1 / 0.34–0.72 | caftan instead of a gambeson, loose hose, knee boots, open bascinets, no heraldry | 2 in 6 |
| Knights | ~2150 | 3 / 0.88–1.00 | closed-visor bascinet, cuirass or heavy brigandine over mail, full limb harness | 2 in 4 |

Armour budget is the sum of `DefenseStab + DefenseSlash + DefenseSmash` over the whole outfit. Cumans sit deliberately between the bandits and the regular soldiers, with a wide ramp so a line of them reads as a mix.

**Looters** are the one group built from a schedule rather than a rotation: eight in rags or work aprons (30–42) and four in `GambesonShort02` (94–121), the worst-quality gambeson in the game — the shabby open one, not a soldier's arming coat. Their headwear is filtered by Charisma ≤ 16, which drops the frilly, burgher, noble, embroidered, peacock and brooch caps along with the hunter hats; straw hats and apron tunics are kept on purpose. Hoods are limited to the four rattiest — the draped liripipe ones (including the `Hood11` the liveried houses wear) read as capes.

**Wear is carried by `Quality` (1–4) and `Condition` (0–1) on the preset**, not by the item list — those are stock KCD2 preset attributes used by 600+ vanilla presets. Quality 1 with a low Condition is what makes bandit kit read as rusty and pitted; Quality 3 at Condition ~0.95 is what makes a knight look polished. `ConditionVariation` widens the scatter within one preset (0.28 for Cumans, 0.05 for knights).

Each pool is authored **worst-first** along a ramp (±6% for knights, ±30% for looters), which is what `DiffWardrobe` in `mercenaries_difficulty.lua` splits into a ragged and a good half when the difficulty tier biases armour quality.

**Heraldry.** Sigismund was King of Hungary, so his soldiers fly the `_mMagyar`/`_mUher` livery — the only Sigismund-army heraldry the game ships. Prague has a richer set (4 surcoats, a coat, 2 hoods, 2 coifs). Knights get one **noble house each** — Bergov, Nebak, Semin, Ruthart, Pisek, Krizovnik (Order of the Red Star), Teuton, Kuttenberg, Vavak, Cimburk, Papal, Leipa — so a line of them reads as a coalition rather than a regiment. Bandits, looters and Cumans wear no heraldry: they have no lord.

## Weapons and shields

`grp.weapons` lists the `WeaponSets` categories a group may draw from. Categories **2 (sword+shield), 3 (axe+shield) and 5 (mace+shield) bundle a shield**; 4 (longsword), 6 (shortsword), 7 (mace) and 8 (axe) do not. A group whose list contains none of 2/3/5 can therefore never be handed a shield, however it rolls — that is how looters stay shieldless. Repeating a category weights it, which is how bandits get "a few shields, but not many" (one shield entry in six).

This only started working when the backstop below was fixed. `EquipEnemy` re-equips once more after the first draw, to cover the empty-weapon-set bug (`Can't execute explicit DrawAction for selected weapon set which contains no weapons!` — once ~23 of 75 besiegers). That retry used to be a hardcoded `EnemyWeaponFallbacks = { 2 }`, and since the last call wins it **silently overrode `grp.weapons` for every group** — knights included — and put a sword and shield on everyone who spawned. It now draws a second time from the same allowed list, so the group's own rule holds either way, and the shield decision reads the draw that actually stuck.


**Heinrich** is a single, deliberately overpowered boss — essentially a late-game player: Henry's own head/hair/body, his final plate armour (`UC_HenryFinalArmor`), St. George's sword (the best sword, pinned via `weaponPreset`), maxed `combat_level` (1.0) and a 2× health multiplier. On top of that he carries a permanent boss buff (`heinrich_imba_buff`, applied via the perk chain in `buff__`/`perk__`/`perk_buff__`/`soul2perk__mercenaries.xml`) so he can wade into a group and win: +40–45 to every combat stat, ~70% damage resistance (`hlh*0.3`,`slh*0.3`), 4× stamina regeneration with no stamina cooldowns (`srg*4`,`src=0`,`sco=0`) plus +50% max stamina, and 5 HP/s regen in combat. It's modelled on vanilla's `imba_combat_guy` but toned down so he is still beatable by a large group or a skilled player. `enemy_spawn_heinrich` spawns one; `enemy_spawn_heinrich_3` spawns three. He is left out of `SpawnTestBattle`'s enemy line on purpose.

Combat levels mirror the mercenary tiers (weak 0.5 / medium 0.7 / strong 0.9), so an enemy roughly matches the merc tier it's fighting. Knights are **elites**: `combat_level` maxes out at 1.0 in the engine, so their extra strength comes from a **health multiplier** (`healthMult = 1.6`, applied on spawn in `EquipEnemy`) that makes them notably tankier. Their plate is a **mix of surcoated (Sigismund / Kuttenberg waffenrock) and plain plate/mail**, so not every knight wears a tabard.

Each group also carries **2 archer souls**. When you spawn a group, roughly every 4th unit is an archer (so a row of 10 gets ~2 bowmen); knights have none. A single-unit spawn is always melee.

## Test commands

The base command spawns a **row of 10**; `_1` spawns a single unit and `_20` a bigger wave:

```
enemy_spawn_looters      enemy_spawn_looters_1     enemy_spawn_looters_20
enemy_spawn_bandits      enemy_spawn_bandits_1     enemy_spawn_bandits_20
enemy_spawn_sigi         enemy_spawn_sigi_1        enemy_spawn_sigi_20
enemy_spawn_prague       enemy_spawn_prague_1      enemy_spawn_prague_20
enemy_spawn_cumans       enemy_spawn_cumans_1      enemy_spawn_cumans_20
enemy_spawn_knights      enemy_spawn_knights_1     enemy_spawn_knights_20
enemy_spawn_heinrich     enemy_spawn_heinrich_3
```

They spawn behind the player in a row and immediately move to engage. `merc_lua mercenaries:SpawnEnemyGroup('bandit', 8)` works for arbitrary counts.

## How it works

Everything lives under the name `enemiesFaction`, patched into the mod's own `*__mercenaries.xml` tables (one file per table, one mod id), and reuses the merc mod's existing gear tables.

- **Faction** — `FactionTree__mercenaries.xml`. One faction, hostile only to `player` and `mercenariesFaction` (which covers hired mercs, archers and companions) — deliberately **not** `players_friends`, so the player's friendly vanilla NPCs are left out of it. It carries `Labels="publicEnemy"`, which is what makes the bodies free to loot rather than robbed — see [Public enemies and stolen loot](public-enemy.md). Everything else defaults to neutral. `mercenariesFaction` in the same file is hostile back to `enemiesFaction`, so the squad's target selection recognises them.
- **Souls** — `soul__mercenaries.xml`, 65 enemy souls, named `soul_enemy_<group>_<n>` / `soul_enemy_<group>_archer_<n>`. `combat_level` per soul sets the tier; `soul_vip_class_id="0"` and `xp_multiplier="1"` make them fully lootable and worth XP.
- **Appearance** — `enemiesappearance.xml` (a second `<source>` on the appearance task in `storm__mercenaries.xml`). One face per soul, themed per group (rough tan faces for looters/bandits, Sigismund's-camp Roma/tan faces for sigi/cumans, pale Czech soldiers for Prague, mature groomed faces for knights).
- **Brains** — melee souls use the existing `renegade_brain` (`enemy_melee_scheduler.xml`), archer souls `enemy_archer_brain` (`enemy_archer_scheduler.xml`); both are declared in `data/libs/tables/ai/*__mercenaries.xml`. Both schedulers acquire targets through the shared `mercenaries:FindEnemyTarget` and fire the shared AI modules — `combat_melee` for melee, `combat_archer_dynamic` for archers (see [ai-modules.md](ai-modules.md)). The archer scheduler re-fires the module whenever `FindEnemyTarget` switches targets (tracked via `firedTarget`, with `IgnorePriorityOnPreviousInterrupt`), so a bowman promptly re-points when its target dies instead of idling. Side rules are resolved in Lua: enemies never leash to the player — an enemy archer leashes to its own target at 60 m (a player-leash here once made them thrash and stop shooting). Both schedulers also fire `camp_actor` while an enemy holds a camp role and has no target, which is what future bandit camps run on.
- **Gear** — applied from Lua on spawn (`SpawnEnemyGroup` → `EquipEnemy`). Clothing is rolled from the group's `clothing` GUID pool; the weapon goes through the normal `EquipMercenaryWeapon` path, which reads the tier out of the spawn name (`SpawnedEnemy_<group>_<tier>_…`) and routes `_archer_` names to the bow set. No Storm equipment rules are needed.
- **Target selection** — `FindEnemyTarget` (once/sec, 50 m) considers only the player and entities named `SpawnedFriend_*` / `MercenaryCustomCompanion*`. Vanilla NPCs and other spawned enemies are never candidates. Same anti-swarm pool the renegades used (`EnemySwarmCap`, `EnemyTargetOf`/`EnemyTargetLoad`). A target once acquired is **held** for the whole approach, out to `EnemyTargetHoldRange` (60 m) — re-picking mid-approach makes the scheduler re-fire, and a re-fire restarts the charge. See [combat-target-selection.md](combat-target-selection.md) and [foe-ai.md](foe-ai.md).

## Config

Groups are defined in one table in [mercenaries_spawning.lua](../data/Scripts/mods/mercenaries_spawning.lua):

```lua
mercenaries.EnemyGroups = {
    <group> = {
        label    = "...",       -- log/debug label
        clothing = { <guid>, ... },   -- clothing preset GUID pool
        melee    = { { guid = "...", tier = "weak|medium|strong" }, ... },
        archers  = { <guid>, ... },
    },
    ...
}
```

To add a unit, add a soul to `soul__mercenaries.xml` (+ an `enemiesappearance.xml` rule), then add its GUID to the group's `melee`/`archers` list. To retune strength, edit the soul's `combat_level`. To re-skin a group, swap its `clothing` GUID pool.

## Backward compatibility

The old renegade tokens and the debug "spawn renegade" dialog submenu still work: `mercenaries:SpawnRenegade(n, _, tier)` is a shim that maps `weak→looter`, `medium→bandit`, `strong→knight` onto `SpawnEnemyGroup`. `SpawnTestBattle` / `merc_battle` still spawn an enemy line (from a merged pool of all enemy melee souls) under the `SpawnedRenegade_` prefix, which `FindEnemyTarget` also recognises.
