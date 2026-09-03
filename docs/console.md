# Console commands

Everything a player can type lives in one file: `data/Scripts/mods/mercenaries_commands.lua`.
It is loaded first, before any other module, because every module registers its authoring and
diagnostic commands through `mercenaries:DevCommand` as it loads. The collector itself sits at
the top of `mercenaries.lua`, which registers a command of its own before it gets that far.

Open the console with `~`. Type `merc_help` for the same list in-game.

**Two sets.** The ~100 commands below are registered at load. The ~350 authoring and
diagnostic commands (wall builder, siege builder, route recorder, prop galleries, profiler,
LOD probes, weapon audit, test NPCs) are collected but NOT registered until you type
`merc_dev`. That keeps the console's tab-completion readable for a player and leaves the
tools one keystroke away for whoever is building content.

**Arguments.** `%line` - the whole argument line - is the only substitution the engine
performs. `%1`, `%2` are left as literal text, which is why every command that takes
arguments passes `%line` and splits it itself (`mercenaries:CmdArgs`). Arguments in
`[brackets]` below are optional.

## Squad

| Command | What it does |
|---|---|
| `merc_help` | List the commands |
| `merc_status` | Count, health, orders, archer stance |
| `merc_heal` | Heal and wash the whole company for a flat fee |
| `merc_follow` | Everyone falls in behind you |
| `merc_wait` | Everyone holds where they are |
| `merc_dismiss` | Pay off the whole company |
| `merc_loot` | Send the men to strip the bodies around you |
| `merc_loot_stop` | Call off the loot sweep |

## Hiring

Hiring from the console is free and ignores the quartermaster; the companion cap
(`mercenaries.MaxCompanions`, 50) still applies to everything.

| Command | What it does |
|---|---|
| `merc_hire [n]` | Seasoned foot, default 5 |
| `merc_hire_weak [n]` | Raw foot |
| `merc_hire_strong [n]` | Veterans |
| `merc_hire_archers [n]` | Archers |
| `merc_hire_army_small` | 10 archers and 20 foot |
| `merc_hire_army_big` | 15 archers and 35 foot - a full company at the cap |

## Orders

| Command | What it does |
|---|---|
| `merc_hold` / `merc_hold_end` | Hold this ground and stop chasing / release |
| `merc_escort` / `merc_escort_end` | Escort whoever you are looking at / stop |
| `merc_focus` / `merc_focus_clear` | Call a target for the whole company / drop it |
| `merc_stance_attack` | Attack anything hostile on sight |
| `merc_stance_default` | Fight whoever fights you or the player |
| `merc_stance_defend` | Never start a fight; defend themselves |
| `merc_stance_holdfire` | Hold fire even under attack |

See docs/squad-orders.md for what each stance changes.

## Formation

`merc_form_column`, `merc_form_line`, `merc_form_square`, `merc_form_wedge`,
`merc_form_circle`, `merc_form_escort`, `merc_form_vanilla`.

Mode: `merc_form_keepshape` (rigid, default), `merc_form_relaxed` (loose escort),
`merc_form_movehistory` (follow in your footsteps). See docs/formations.md.

## Gear

`merc_outfit <1-17>` - 1 Generic, 2 Bandit, 3 Cuman, 4 Leipa, 5 Kuttenberg, 6 Skalitz,
8 Prague, 9 Sigismund, 10 Order of the Red Star, 11 Bergov, 12 Nebakov, 13 Semine,
14 Pisek, 15 Teutonic Order, 16 Ruthard, 17 Papal Legate. Type it with no argument for
the list. 7 is the custom uniform — set that with `merc_gear_apply`, not here.

Loadouts: `merc_weapon_random`, `_swordshield`, `_axeshield`, `_longsword`, `_maceshield`,
`_shortsword`, `_mace`, `_axe`, `_polearm`.

Custom uniform (docs/custom-gear.md): `merc_gear_open` puts the wardrobe chest down,
`merc_gear_apply` dresses the company in what you put in it, `merc_gear_close` takes the
chest away, `merc_gear_clear` forgets the uniform.

## Archers

Stance: `merc_archer_skirmish` (shoot and fall back), `merc_archer_melee` (close and fight),
`merc_archer_hold` (stand and shoot).

Weapon: `merc_archer_bow`, `merc_archer_crossbow`, `merc_archer_handcannon`.

## Camp

| Command | What it does |
|---|---|
| `merc_camp_make` / `merc_camp_break` | Pitch the camp here / strike it and march |
| `merc_camp_recall` | Call every man to you without breaking camp |
| `merc_camp_deploy_all` / `merc_camp_deploy_half` | Take the company (or its best half) out with you |
| `merc_camp_return_all` | Send every deployed man back |
| `merc_camp_remove [1-11]` | Take ONE camp improvement down; no argument lists them |
| `merc_camp_party [1-8]` | Set what a deployed party is made of (archer share, which foot); no argument lists them and prints what is set |
| `merc_gate_open` / `merc_gate_close` | Work the camp gates |

## Enemies

Seven groups, three commands each. Substitute the group word: **bandit, looter, sigismund,
knight, prague, cuman, ruthenian**.

| Command | What it does |
|---|---|
| `merc_spawn_<group> [n]` | A row of them in front of you, hostile, default 10 |
| `merc_raid_<group> [n]` | They form up at distance and come for you, default 12. With a camp standing this is the wall battle's own raid: they march on a gate |
| `merc_patrol_<group>` | A gang of them walking a real road route nearby. Falls back to a formed-up group where the level has no recorded routes |
| `merc_spawn_heinrich` | One overpowered champion - best armour, St. George's sword, maxed skill |
| `merc_clear_enemies` | Remove every spawned enemy, raid and patrol nearby |

Raids without a camp hand every man the player as a forced target, so the whole block
commits instead of the front rank noticing you and the rest standing about.

## Set-piece fights

`merc_battle [foot] [group] [archers] [metres]` - two armies drawn up facing each other with
their archers behind, you standing between them. Defaults: 12 foot and 4 archers a side,
bandits, 34 m apart. The merc side are real hires who join your company, so the survivors
follow you home; the count is trimmed to fit the companion cap.

```
merc_battle 20 knight 6 45
```

`merc_raborsch` raises the siege of Raborsch around you; `merc_raborsch_clear` strikes it.
See docs/walls-and-sieges.md.

`merc_raid_now` launches the next scheduled camp raid immediately.

## Options

| Command | Values |
|---|---|
| `merc_difficulty <tier>` | easy, medium, difficult, extreme, impossible, horde |
| `merc_upkeep <mode>` | off, lenient, standard, harsh |
| `merc_encounters <0/1>` | Random raids, patrols and ambushes |
| `merc_patrols <0/1>` | Roaming road patrols |
| `merc_patrols_perday [n]` | Roaming gangs per world day at most (default 2); 0 lifts the cap; no argument reports today's count. Saved. See docs/patrols.md, "The day cap" |
| `merc_patrols_pace <gap> [postFight] [standingCap]` | **dev** — how often a roaming gang may appear at all, in seconds. No argument reports. See docs/patrols.md, "Pacing" |
| `merc_status_icons <0/1>` | Squad status icons on the player HUD |
| `merc_autodismount <0/1>` | Mercs get off their horses to fight |
| `merc_horses <0/1>` | Let the company use horses at all. Off = they march on foot whatever you ride. Saved; also in the quartermaster's Mod settings |
| `merc_horses_max [n]` | Men out with you above which nobody rides, 0 = no limit (default - a hard cap was tried and made mounting worse than the problem it fixed, see docs/formations.md); no argument reports. Saved |
| `merc_lod_quality <preset>` | crisp, balanced (default), performance - how much mesh detail is cut in a big battle. Saved. See docs/npc-lod.md |
| `merc_mqstash <0/1>` | Send the company out of a recognised main-quest battle and bring them back after (default on) - they cannot be rendered inside one, see docs/quest-override-battles.md. Saved |
| `merc_travel_stow <0/1>` | Take the company out of the world while you fast travel or sleep, and put it back on arrival (default on). See docs/save-footprint.md, "The roster" |
| `merc_horsestats` | Every horse reading the travel detector can see - its own speed and velocity, stamina, health, and the player's speed and stamina. `merc_travelstamina` is the older name. See docs/travel-detection.md |
| `merc_roster <0/1>` | Rebuild the company from the saved roster on load (default on) |
| `merc_roster_nosave <0/1>` | Keep hired mercs out of the save entirely - the save-footprint fix (default **off** until the rebuild is proven). Applies to men hired after it is set |
| `merc_hide_others` | Toggle: hide every NPC that is not yours. For clean screenshots and footage - **restore it before saving** |

## Uninstalling, and the save footprint

| Command | What it does |
|---|---|
| `merc_uninstall yes` | Take the whole mod out of this save, then save and delete the folder |
| `merc_save_audit` | Count everything the mod would leave in a save. Changes nothing |
| `merc_items` | List the mod's items in Henry's inventory. Changes nothing |
| `merc_purge_world yes` | Blunt stage: remove NPCs/horses/props/items, **keep** the savers |
| `merc_purge_savers yes` | Remove **only** the hidden saver entities |

### Surgical stages

One category each, so a load-time hunt can remove exactly one thing and measure it.

| Command | What it removes |
|---|---|
| `merc_purge_npcs yes` | Only the **people**: mercenaries, quartermaster, patrolmen, spawned enemies, tower archers, Aleksej's camp |
| `merc_purge_horses yes` | Only the mod's mounts (`MercenaryHorse_*`). Henry's own horse is untouched |
| `merc_purge_props yes` | Only the **structures**: camp walls, gates, towers, forge and rig, carts, beds, chests, lights, markers. This is the white-pyramid category |
| `merc_purge_items yes` | Only the mod's items in Henry's inventory |
| `merc_purge_buffs yes` | Only the mod's buffs on Henry (all 22, not just the five tracked by name) |
| `merc_purge_savers yes` | Only the hidden saver entities |

The purge commands exist to answer *which* residue makes an uninstalled game load slowly —
see [save-footprint.md](save-footprint.md) for the measurement procedure. The audits are
read-only and are what to paste into a bug report about load times.

**`merc_save_audit` is the one to run first, and to run again right after loading a save.**
What it counts on a fresh load is what the save actually stored — which is a different and
much more useful number than what the mod has put in the world since.



## Advanced

`merc_dev` registers the authoring and diagnostic set; `merc_dev_list` prints it.
`merc_dev` only works in a `-devmode` launch: the dev set includes the automated bench and
torture campaigns, several of which quit the game when they finish.
`merc_lua <code>` runs a line of Lua - the escape hatch if a command is missing, e.g.

```
merc_lua mercenaries:SpawnEnemyGroup('cuman', 30)
```

## Adding a command

Player-facing: add one `cmd(name, body, desc)` line in `mercenaries_commands.lua` and list
the name in `CmdHelpSections` so `merc_help` shows it.

Authoring or diagnostic: call `mercenaries:DevCommand(name, body, desc)` from the module
that owns the feature, exactly where `System.AddCCommand` used to go. Nothing else is
needed - the gate collects it.

Do not call `System.AddCCommand` directly anywhere but `mercenaries_commands.lua`.
