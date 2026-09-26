# Mercenaries

A companion mod for **Kingdom Come: Deliverance II**. Hire a mercenary company, equip it,
order it about, camp with it, and take it to war. Up to **50 men** under your command.

**Download:** [GitHub Releases](https://github.com/Heragoga/kcd2-mercenaries-mod/releases) (`mercenaries.zip`, or
`UNLIMITED mercenaries.zip` without the 50-man cap), [Nexus Mods](https://www.nexusmods.com/kingdomcomedeliverance2/mods/3051) or the
Steam Workshop. The Nexus page also carries the **unlimited** build (no 50-man cap) and a muted
build without the custom voicelines.
**Help and bug reports:** [Discord](https://discord.com/invite/R7xKaGqdRU)

This repository holds the mod's source and a set of general KCD2 modding tutorials.

---

## Install

1. Extract the archive into `KingdomComeDeliverance2\Mods\`, so you end up with
   `Mods\mercenaries\mod.manifest`.
2. Start the game. No launcher argument and no load-order entry are needed.

To uninstall, open the console and run `merc_uninstall yes` - it removes every mercenary,
horse, patrol, camp structure and hidden state the mod put into your world. Then **save the
game**, exit, and delete the folder. Skipping this step leaves mod entities baked into your
saves, which makes them load very slowly (up to a minute) once the mod is gone.

## Getting started

- Talk to any **innkeeper** to hire your first mercenaries, or use the console: `merc_hire 5`.
- **Look at a mercenary** to open the silent order wheel: follow, wait, orders, equipment.
- Once you have a company, `merc_camp_make` (or the dialogue) pitches a camp. The
  **quartermaster** in camp is the interface for everything else: wages, food, drink,
  upgrades, contracts and difficulty.
- `merc_help` in the console lists every command.

## What's in it

**The company.** Hire foot in three tiers and archers alongside them, up to 50 men. Six
uniform styles across a 180-preset wardrobe, nine weapon loadouts, or build your own uniform
by dropping gear in a chest and dressing the whole company in a copy of it. 44 named
companions cloned from vanilla characters can be recruited individually.

**Command.** Seven marching formations, four engagement stances, hold-this-ground, escort,
and a called target the whole company converges on. Archers get their own stances: skirmish,
close to melee, or stand and shoot.

**Camp.** A procedural camp your men live in — they sit, eat, sleep, drink, spar and gossip.
Upgrades bought from the quartermaster: smithy, alchemy bench, hunting station, tavern,
practice yard, player house, palisade walls, gates, watchtowers and archer carts. Wages,
food, drink, tiredness and morale all run while you are away, with the company's state
mirrored on your own HUD.

**War.** Bandit camps raid your palisade and are fought off at the gaps in your wall. Roaming
patrols and ambushes populate the roads. The quartermaster issues a repeatable bounty and the
**Kleinkrieg** contract chain, both voiced. The **siege of Raborsch** is a full set-piece:
towers, carts, barricades, an archery duel across the walls and an assault that scales to the
company you brought.

**Difficulty.** Six tiers, from *easy* to *horde*, scaling how many enemies every encounter
fields and how well armoured they are.

Sixteen languages, and custom voice acting for the mercenaries and for Aleksej.

## Console

Open the console with `~`. `merc_help` lists everything. A taste:

```bash
merc_hire_army_big
```

```bash
merc_battle 20 knight 6 45
```

```bash
merc_raid_sigismund
```

## Compatibility

The mod ships exactly **one** file that overrides a base-game file: `AI/FormationDefinitions.xml`.
Our copy keeps all 63 vanilla formations untouched and appends the mod's own, so vanilla
battles behave normally — but any other mod that replaces that file will conflict with this one.
Everything else the mod adds is under its own names.

## Modding tutorials

The `docs/` folder is a small set of general KCD2 modding guides written while building this
mod: mod setup and the game's file structure, Skald quests and dialogue, adding NPCs and their
brains, behaviour trees, and talking between Lua and Skald. Start at
[docs/README.md](docs/README.md).

## Building from source

`PackageMod.bat` packs `data/` and `localization/` into `Mods\mercenaries` in your game folder
(Windows only). It finds the game through `tools/Find-KCD2.ps1`, which checks `KCD2_DIR`, then
`tools/local.paths.txt`, then every Steam library on the machine. If it cannot find yours:

```bash
set KCD2_DIR=D:\path\to\KingdomComeDeliverance2
```

or copy `tools/local.paths.txt.example` to `tools/local.paths.txt` and fill it in.

The voice recordings and baked lipsync are not part of this repository, so a build from source
has the mod's text but not its custom voice acting. For the voiced build, download a release.

The companion limit lives in the source: `mercenaries.MaxCompanions` in
`data/Scripts/mods/mercenaries.lua`. Raising it means regenerating the formation ladder in
`data/AI/FormationDefinitions.xml` to match — `mercenaries.FormationSizes` must top out at the
new limit, or squads above the largest template share too few engine spots.

## Layout

| Path | What |
|---|---|
| `data/Scripts/mods/` | The Lua: one module per system, plus `mercenaries_commands.lua` for every console command |
| `data/AI/` | Behaviour trees and the formation catalogue |
| `data/libs/tables/` | Souls, items, outfits, weapon presets, buffs |
| `data/quests/` | Skald quest graphs and dialogue |
| `localization/` | 16 languages |
| `docs/` | General KCD2 modding tutorials |

## Credits

- **carbongo** — voicelines
- **takuspore0729** — Japanese translation
- **OzelHarekaTR** — Turkish translation
- **小邮票** — Chinese version
- **Walker aka Walker** — Skalitz equipment presets
- **KCD2 Lipsync Generation Tool** (Nexus 3648) — Aleksej's lipsync was generated with it
- **Heragoga** — everything else
