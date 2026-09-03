# Mercenaries

A companion mod for **Kingdom Come: Deliverance II**. Hire a mercenary company, equip it,
order it about, camp with it, and take it to war. Up to **50 men** under your command.

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

Open the console with `~`. `merc_help` lists everything; the full reference is
[docs/console.md](docs/console.md). A taste:

```bash
merc_hire_army_big
```

```bash
merc_battle 20 knight 6 45
```

```bash
merc_raid_sigismund
```

Authoring and diagnostic commands (wall builder, siege builder, profiler, prop galleries)
are hidden until you type `merc_dev`.

## Compatibility

The mod ships exactly **one** file that overrides a base-game file: `AI/FormationDefinitions.xml`.
Our copy keeps all 63 vanilla formations untouched and appends the mod's own, so vanilla
battles behave normally — but any other mod that replaces that file will conflict with this one.
Everything else the mod adds is under its own names.

## For modders

The `docs/` folder is a small KCD2 modding wiki written while building this mod — behaviour
trees, Skald, spawning NPCs, lipsync, formations, and postmortems of what does not work.
Start at [docs/index.md](docs/index.md).

## Building

- `PackageMod.bat` builds the mod into the game's `Mods` folder.
- `PackageModDev.bat` does the same but deploys to the dev build and launches its exe,
  which writes `kcd.log` with the `[Error]`/`[Warning]` lines the retail build swallows.
- `PackageRelease.bat` produces the release archives, `release/mercenaries.zip` and
  `release/UNLIMITED mercenaries.zip`. Run `PackageMod.bat` first.

**Nothing here has the game's path baked in.** Every script (and both test harnesses)
calls `tools/Find-KCD2.ps1`, which checks `KCD2_DIR`, then `tools/local.paths.txt`, then
every Steam library on the machine — including ones on other drives — so a fresh clone on
a new PC normally just works. When it cannot find the game (a non-Steam copy, an unusual
folder), tell it once:

```bash
set KCD2_DIR=D:\path\to\KingdomComeDeliverance2
```

or copy `tools/local.paths.txt.example` to `tools/local.paths.txt` and fill it in — that
file is gitignored, so each machine keeps its own. The **dev build is never guessed**: set
`KCD2_DEV_DIR` (or the `dev=` line) if you want `PackageModDev.bat`, because deploying a
dev pak into the game you actually play would be worse than failing.

To check what it finds on this machine:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File tools\Find-KCD2.ps1
```

Both archives are the same build with voicelines; only the companion limit differs. The
supported limit is 50 and lives in the source, not the packager: `mercenaries.MaxCompanions`
in `data/Scripts/mods/mercenaries.lua`. Changing it means regenerating the formation ladder in
`data/AI/FormationDefinitions.xml` to match — `mercenaries.FormationSizes` must top out at
the new limit, or squads above the largest template share too few engine spots.

The UNLIMITED archive is that same build with `MaxCompanions` rewritten to 999 inside the
packed `mercenaries.pak`, so the source stays at the tested limit. Its formation ladder still
tops out at 50: past that the squad reuses the 50-slot template and the extra mercs share
spots. Raise or lower it with `UNLIMITED_MAX` at the top of `PackageRelease.bat`.

## Layout

| Path | What |
|---|---|
| `data/Scripts/mods/` | The Lua: one module per system, plus `mercenaries_commands.lua` for every console command |
| `data/AI/` | Behaviour trees and the formation catalogue |
| `data/libs/tables/` | Souls, items, outfits, weapon presets, buffs |
| `data/quests/` | Skald quest graphs and dialogue |
| `localization/` | 16 languages |
| `docs/` | The modding wiki |
| `tools/` | Generators and voice-processing scripts |

## Credits

- **carbongo** — voicelines
- **takuspore0729** — Japanese translation
- **OzelHarekaTR** — Turkish translation
- **小邮票** — Chinese version
- **Walker aka Walker** — Skalitz equipment presets
- **Heragoga** — everything else
