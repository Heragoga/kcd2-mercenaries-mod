# What the mod leaves in a save, and why an uninstalled game can load slowly

The report: *"if you hired a mercenary once and then uninstall the mod, the game takes
significantly longer to load save files — from ~5 seconds to nearly a minute. The only way
to solve it is to install the mod back."*

That is consistent with unresolvable references baked into the save, but **which** ones has
not been measured. This page is the measurement procedure and the tooling for it.

## The roster: the company as data, not as fifty NPCs (2026-09-03)

The staged purge below measures the residue. The roster removes it.

A hired merc is spawned as an `NPC` entity, and the engine writes every NPC into the save -
fifty men means fifty NPCs, their souls, inventories and AI state, in every save. That is the
footprint, and it is why a save made with the mod loads slowly once the mod is gone: the
entities are still in the save with nothing left to explain them. The hand test on
2026-09-03 measured a camp save loading in 2:30 against 1:00 for a save the mod never
touched, with white pyramids where the camp stood and generic townsmen where the men were.

`mercenaries_roster.lua` keeps the company as a LIST - tier and health per man - in one saver
string, and puts the men back into the world from it:

* **On load** (`RosterOnLoad`, straight after the merc cache is rebuilt) the men standing are
  counted and only the SHORTFALL is spawned. That is safe whether the engine restored every
  merc, some, or none - nothing is ever spawned twice.
* **While travelling** (`TravelTick`, 1 Hz) the company is taken out of the world for a fast
  travel or a sleep and put back on arrival. A man who is not in the world cannot be lost by
  a crossing, which is what happened on 2026-09-03: a fast travel arrived with one of five
  men left, and he had stopped following.
* **`merc_stow` / `merc_unstow`** do it by hand, which is how to watch the rebuild work.

**The switch that actually shrinks the save is `merc_roster_nosave`, and it is OFF by
default.** On, mercs are spawned with `bSaved_by_game = false` and the engine never writes one
into a save at all. Two things to know before flipping it: every load then depends on the
roster rebuild, and the men come back around the player rather than where they stood, so a
camp full of men would re-form on the player and have to walk home. Prove the rebuild first.

There is no Lua hook the engine calls before it writes a save, so "despawn everything when the
player saves" cannot be done by watching for a save. Keeping the men out of the save in the
first place is the same result by the other door.

## The three suspects

| | What | Why it might cost | Removed by |
|---|---|---|---|
| **A** | **NPCs, horses, serialising props.** Every merc, patrolman, archer, enemy and quartermaster is a full `NPC` entity carrying `guidSharedSoulId` | Each one's soul, brain, faction, skald character and behaviour tree live in this mod's XML. Without the mod, every lookup fails, per entity. Saves have been measured holding 50 mercs + 27 patrolmen against a live roster of 8 ([performance.md](performance.md)) | `merc_purge_world yes` |
| **B** | **Saver entities.** ~60 hidden `BasicEntity` objects whose *names* carry the mod's state ([mercenaries_saving.lua](../data/Scripts/mods/mercenaries_saving.lua)) | `BasicEntity` is a **vanilla** class, so these should resolve fine without the mod. The cheap suspect, and the one most likely to be innocent | `merc_purge_savers yes` |
| **C** | **Inventory item classes.** 176 classes — dialogue tokens, quest documents, the mod's armour | All defined in `item__mercenaries.xml`. Small in number, but trivial to rule out | `merc_purge_world yes` |

A is the prime suspect. B is the cheap one. The point of splitting the commands is that
**nobody has to guess** — one measurement each settles it.

## Procedure

Establish the two baselines first:

1. **Mod installed.** Load your test save, time it. This is the "normal" number.
2. **Mod removed, nothing scrubbed.** Delete the mod folder, load the *same* save, time it.
   This should reproduce the slow load. Put the mod back afterwards.

Then, for each stage below: load the **original** save with the mod installed, run the
command, **save into a new slot**, quit, remove the mod folder, load that new slot, time
it, and reinstall the mod.

| Run | Command before saving | Interpretation if this load is fast |
|---|---|---|
| 3 | `merc_purge_world yes` | **A and/or C** were the cost |
| 4 | `merc_purge_savers yes` | **B** was the cost |
| 5 | `merc_uninstall yes` | everything is gone; this is the floor |

If run 3 is fast and run 4 is slow, it is the entities (A) — which also means a player who
merely dismisses the company is *not* safe, because dismissal leaves the saver tags and the
already-serialised bodies behind. If run 4 is fast too, the savers are implicated and the
`spawnTag` model/physics defaults deserve another look. If neither is fast on its own but
run 5 is, the cost is spread and only the full scrub helps.

Record the numbers in this file when they exist. **Until then nothing here should be quoted
as the cause** — the mechanism above is a hypothesis with good circumstantial evidence, not
a measurement.

## Reading the world without changing it

```
merc_save_audit
```

Counts all three categories and breaks A down by name prefix, so it is worth running
*before* each stage to know what that run is actually removing. It changes nothing.

```
merc_items
```

Just category C, itemised: count, class GUID, and a friendly label resolved from the mod's
own Lua constants (`TokenIDWeak`, `AlxDocs.doc6`, …) rather than the item table's rows,
which are all called `loot_sackOfNails`. Also prints the total inventory size for context.

## The item list is generated

`mercenaries.ModItemIds` in
[mercenaries_item_ids.lua](../data/Scripts/mods/mercenaries_item_ids.lua) is generated from
`data/libs/tables/item/item__mercenaries.xml`:

```
python tools/gen_item_ids.py
```

**Re-run it after adding or removing item rows**, or the new classes are invisible to both
the audit and the purge. Do not hand-edit the generated file.

It is deliberately an explicit list rather than a GUID-prefix test: this mod also references
**vanilla** items by GUID (groschen, torches, the smithing hammer and tongs), and a prefix
rule that caught one of those would delete a player's money.

## What each stage deliberately does not do

`merc_purge_world` keeps the saver entities, so the mod still knows where the camp was and
which upgrades were bought. A player who runs it and keeps playing gets their camp back on
the next load; only the standing bodies are gone.

`merc_purge_savers` latches persistence **off** for the rest of the session
(`mercenaries.UninstallScrubbed`, checked in `SaveString`/`SaveStrings`), so no tick can
quietly write a tag back between the purge and the player's save. That is why it is not
reversible without a reload.

Neither stage touches the mod's Skald quest graphs or the buffs on souls other than the
player's — a merc that is already gone takes its own buffs with it.

---

# Round 3: what is actually in the save (2026-09-03)

Three things were settled by measurement this round, and one gap was found by reading.

## 1. `bSaved_by_game = false` is honoured for spawned NPCs

This was the open question the whole switch rested on. The load log answers it:

```
[Roster] load: the engine restored 0 merc(s); the roster says 10 (no-save is true)
[Roster] load: 0 man/men were in the world, roster says 10 - put 10 back
```

Ten men in the company, **zero** restored by the engine, all ten put back from the roster.
The flag works. Mercenaries are no longer written to saves when `merc_roster_nosave` is on.

## 2. So the mercenaries were never the load-time cost

An uninstalled load of a save made with the switch **on** was still slow. Since the engine
demonstrably stored no mercenaries in it, whatever is expensive is something else.

## 3. Buffs cannot be it, by construction

All 22 rows in `buff__mercenaries.xml` carry `is_persistent="false"`. A non-persistent buff
is not written to a save at all. `merc_purge_buffs` exists for completeness and because the
audit should be able to say the category is empty, but no test needs to be spent on it.

## 4. The gap: the purge only scanned four entity classes

`merc_purge_world` scanned `NPC`, `Horse`, `BasicEntity` and `Stash`. The mod spawns into
**sixteen** classes. Everything in the other twelve was left in the world and in the save:

| Class | What it is | Spawn sites |
|---|---|---|
| `mercenaries_Prop` | walls, gate columns, tower parts, archer carts, hold slabs | 11 |
| `mercenaries_Gate` | the gate leaf itself | 1 |
| `Light` | camp lamps, forge light, bandit-camp and siege lights | 6 |
| `SmartObjectHolder`, `StanceSmartObject`, `TagPoint` | anvil and forge alignment helpers | 8 |
| `ParticleEffect`, `GeomEntity`, `ItemSlot` | the forge rig | 8 |
| `Smithery`, `Ladder`, `BedTrigger` | the smithy, tower ladders, camp beds | 5 |

**`mercenaries_Prop` and `mercenaries_Gate` are classes only this mod defines.** Every
instance of one that reaches a save is an entity the engine cannot resolve once the mod is
gone — which is exactly the *white pyramids where the camp was* in the round-1 report. They
were never purged because nothing looked at that class.

### The fix

One classifier and one sweep, shared by the audit and every purge, so the two can no longer
disagree:

* `mercenaries.UninstallOwnClasses` — classes only we define. Every instance is ours, no
  name test wanted.
* `mercenaries.UninstallScanClasses` — the fourteen vanilla classes we spawn into. Here the
  **name** decides, because deleting a vanilla `Light` or `Stash` would damage the save.
* `mercenaries.UninstallPrefixes` (29 entries) plus the pattern `^Merc%u` — "Merc" followed
  by a capital, which covers some forty spawn sites without a list that goes stale, and is
  written as a pattern precisely so it cannot swallow the game's own `Merchant...` NPCs.

Checked against every name the mod can generate: **70 of 70 matched, with `Merchant`,
`Merchant_Kuttenberg_1`, `Mercy` and `mercenary_camp_vanilla` correctly rejected.**

## The measurement to run now

`merc_save_audit` is the instrument. **Run it right after loading a save**: what it counts
then is what the save actually stored, which is the number that matters. Running it after an
hour of play tells you what the mod has built since, which is not the same thing.

It now prints per **class**, and flags our own two:

```
A. world entities : 0 NPC(s), 0 horse(s), 47 prop(s)
     BasicEntity            18
     Light                   6
     mercenaries_Prop       21   <- OUR class: white pyramid without the mod
```

Then bisect with one stage at a time — purge, save to a **new** slot, quit, uninstall, time
that load:

| Stage | Command | Hypothesis it tests |
|---|---|---|
| 1 | `merc_purge_props yes` | The camp structures are the cost. **Start here** — this is the category the old purge missed entirely |
| 2 | `merc_purge_npcs yes` | Any people left over (patrolmen, quartermaster) are the cost |
| 3 | `merc_purge_savers yes` | The hidden state entities are the cost |
| 4 | `merc_purge_items yes` | Inventory items are the cost |

If none of the four changes the time, the cost is not entity residue at all and the next
suspect is the mod's Skald quest graphs, which no purge can reach from Lua.
