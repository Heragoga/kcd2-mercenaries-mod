# The town watch

Butcher enough people inside a village and the place fights back. A body of guards in
Kuttenberg livery musters out of sight and comes for the company.

[mercenaries_townwatch.lua](../data/Scripts/mods/mercenaries_townwatch.lua) decides when to
answer and what to send. All the watching is [crime-watch.md](crime-watch.md)'s job — this
file never scans anything itself, it reads what the watchdog published.

> **This feature is OFF by default and is not finished.** Nothing in it runs — the
> scheduler gates both halves on their enable flags, so a dormant install pays no scans
> at all. To switch it on for a session:
>
> ```
> merc_dev
> merc_townwatch_enable
> ```
>
> `merc_townwatch_disable` puts it back, clearing any wave standing at the time.
> `merc_townwatch` reports which way it is set. The switch is **session-scoped and
> deliberately not saved** — "temporarily disabled" has to mean the next launch is quiet
> again, whatever was switched on in this one. It does survive a level change within a
> session, which is all testing needs.
>
> One switch drives **both** halves — the crime watchdog and the waves it feeds — because
> a half-enabled feature (tallying kills that nothing ever answers) is a worse state than
> either end of the switch. `merc_crime_on` / `merc_watch_on` remain as finer controls.
>
> Still open before it can come out from behind the switch: the muster still guesses at
> town terrain, and seventy guards in a street has never been measured on a real machine.

| Command (`merc_dev` first) | What it does |
|---|---|
| `merc_watch_status` | every gate, the company's account per village, cooldowns, and what it would send |
| `merc_watch_force [n]` | turn out a wave here and now, ignoring every gate (`merc_watch_force 3`) |
| `merc_watch_stand_down` | send the current watch away |
| `merc_watch_on` / `merc_watch_off` | enable/disable |
| `merc_watch_reset` | clear every village's 3-day timer |

`merc_watch_status` prints the live wave, seconds until the next one, and the full three-wave
table sized against your current company and difficulty.

---

## When it fires

Four gates, all of which must hold. `merc_watch_status` prints them.

1. **More than three living mercs** (`TWMinMercs`). Fewer and the town has no reason to
   muster rather than simply arrest him — and a four-man squad jumped by a dozen guards is
   not a fight, it is an execution.
2. **The company's account is due**: 3 civilians *or* 1 guard killed in this settlement
   (`TWCivilianKills` / `TWGuardKills`). Counted per village, and settled when the watch
   answers it.
3. **A fight is on.** Without it a dozen guards drop into a quiet street. Four sources
   (`CrimeFightOn`), plus a kill in the last 20 s — because the massacre *is* the combat:
   `IsInCombatDanger` on the player, `crime_interruptAttack` on the player, **any merc
   holding a combat target**, or the BT-fed attacker register.

   The first version used only the first and last of those, and it read **false through an
   eight-merc massacre in Kutná Hora** — which is why nothing ever triggered naturally.
   Neither source fires when *we* are the aggressors and the victims are unarmed: nothing
   locks on to us, and butchering a fleeing baker is not "danger". A merc holding a target
   is the reading that actually fires.
4. **The player is in a village or town**, by the faction test in
   [crime-watch.md](crime-watch.md#am-i-in-a-village-or-a-town) — never in open country.

### Stealth kills don't count

A kill only counts if **either** the victim knew something was happening **or** a fight was
already on. Both halves are needed, and the first version had neither right.

**Awareness** is latched per NPC: every census pass samples `soul:IsInCombatDanger()`,
weapon-drawn, and the crime-reaction contexts (`crime_interruptAttack`,
`crime_interruptFlee`, `crime_indifferentFlee`, `combat_flee`, `combat_surrender`). The
first two alone were measured wrong — a massacre in a Kutná Hora street logged four
civilian kills at 1.3–1.5 m from an armed player and marked **every one** `STEALTH`.
Townsfolk carry no weapons and do not "fight"; they run. **Fleeing is the awareness the
test was looking for.**

**A fight being on** (`CrimeFightOn`) covers the sampling gap: the census runs once a
second, and a civilian cut down inside a single tick would otherwise score as an
assassination. Nobody dies unaware in the middle of a brawl.

Kills are still tallied and logged when they don't count, with `STEALTH` on the line.

## What turns out

Ten `townguard` souls in [mercenaries_spawning.lua](../data/Scripts/mods/mercenaries_spawning.lua)'s
`EnemyGroups`, five at combat level 0.7 and five at 0.9. No weak tier — a town does not put
its worst men on the gate when the alarm goes up. **No archers**: a watch that opens fire
into a crowded street is neither what they did nor something the spawn points could place
safely.

Kit is a municipal watch, not a field army — kettle hats throughout (the town-watch helm)
over a mail coif, short mail and a gambeson, with **Kuttenberg livery** on every man
(`Waffenrock02/09_mKuttenberg`, one `Coat04`) and `shieldKite_kuttenberg_A`/`_B`. The senior
half add brigandine arms. Budget lands ~1050–1250, deliberately between the bandits (~700)
and Sigismund's soldiers (~1500). All ten presets, souls, faces and the skald character are
generated by [tools/gen_townguards.py](../tools/gen_townguards.py), which is idempotent —
edit the pools and re-run.

**They are `enemiesFaction`, like every other force the mod fields, and that is the whole
design.** Using the game's real guards was the obvious idea and does not work: no vanilla
faction declares any relation to `mercenariesFaction`, so vanilla guards would fight the
player and ignore the squad entirely — one-sided combat, and the squad stops rendering. See
[npc-lod.md](npc-lod.md).

## Three waves

The town does not send one force, it sends three, and **it only gives up after the third**.
The shape is an escalation the player is meant to feel.

| Wave | Size | Arrives from | When |
|---|---|---|---|
| 1 — *the watch* | **fewer** than the company (0.65×, and hard-capped at `mercs − 1`) | ≥5 points | on the trigger |
| 2 — *the muster* | **slightly more** (1.25×, at least `mercs + 1`) | ≥1 point | 2 min after wave 1 is destroyed |
| 3 — *the town in arms* | **significantly more** (2.0×, at least `mercs + 4`) | ≥1 point | 5 min after wave **2 arrives** |

`points` is a **minimum**, not a count — see [Spread](#spread) below.

Wave one is a scramble — whoever was nearby, from every direction, and beatable by any real
company. The two after it want to read as a **formed body coming from one place**, and do
while they are small enough for that to mean anything. A single point that turns out to be
unusable would cost the whole wave, so a failed single-point muster widens to the full ring
rather than sending nobody.

Wave three is timed from wave two **arriving**, not from its destruction — the town does not
wait to see how the muster gets on before calling everybody else out. So wave two may still
be standing when wave three shows up. In that case the survivors are **folded into** wave
three rather than added on top of it: the wave tops up to its size, and holdovers count
towards it. What the table promises is how many men the player faces, not how many were
created that minute.

The quiet gaps are the point. The street goes silent, and then it does not stay silent.

### Sizing

```
mercs × share  →  floor  →  DifficultyCount  →  the `over` promise  →  ceilings
```

`DifficultyCount` is passed **the wave's own intended size as its `base`**, not the merc
count. It caps `want` at `base × countMult`, so passing the merc count would clamp wave
three (2× the company) back to 1.2× on Medium and flatten the whole escalation.

The `over` minimum is applied **after** difficulty, because it is the promise the design
makes: wave two outnumbers the company and wave three badly outnumbers it, on Easy as well
as on Horde.

Two ceilings. `TWMaxCount` (48) is the design knob and gets multiplied by the tier;
`TWHardCap` (70) is absolute and applied last. **`TWMaxCount` is the one that actually
binds on the default tier** — `DifficultyCeil` returns it unchanged at Medium and below, so
raising only the hard cap would leave a 40-man company still drawing 24 guards.

At 70 the town can genuinely come down on a large company. What makes that affordable is
not the count but the spread.

### Spread

**A big wave landing on one spot is a single mass brawl in the player's face, which is the
most expensive thing this mod can produce.** The same men split across the village fight in
pockets — most of them far enough away to cost a fraction of that — and drift in as they
win or lose.

So `points` is a floor, not a count: no muster point holds more than `TWMenPerPoint` (8)
men, and the wave takes as many points as that needs, up to `TWMaxPoints` (10). A muster of
forty arrives as five columns from five streets rather than one heap in one. Big waves also
form up **further out** — `TWSpreadPerMan` (0.9 m per man) pushes the ideal anchor ring
from 32 m out toward the 66 m limit of the crowd scan.

| Tier | Mercs | Waves | Points | Ring |
|---|---|---|---|---|
| Medium | 8 | 6 / 12 / 19 | 5 / 2 / 3 | 37–49 m |
| Medium | 40 | 31 / 48 / 48 | 5 / 6 / 6 | 54–66 m |
| Horde | 25 | 24 / 70 / 70 | 5 / 9 / 9 | 54–66 m |

### Everyone is handed a target

Spreading out **requires** this and is broken without it. `FindEnemyTarget` scans 50 m
*centred on the man*; guards mustered across the far side of a village see nobody at all
and simply carry on standing — which is exactly the "only half of them engaged" that
`ForcedTargetOf` was added to Raborsch to fix.

So every guard gets the player as a forced target on spawn (`TownWatchAimAt`, written under
both wuid keys, plus a view-distance pin), and the entries are released when the wave stands
down. One *shared* target for the whole force, as `PatrolAlert` does: round-robin across
marks makes everyone path at a different moving man and nobody converges. They re-target
normally once they are in among the squad.

## Muster points: stand where the locals stand

A town is the worst terrain the mod places NPCs in — walls, interiors, and the roof trap
(`GetSafeSpawnPosition`'s ground snap probes from above, so indoors it finds the *roof*).
The first version raycast a ring of five points; all five validated, seven men reported
spawned, and **three were never seen**. Raycasting a town is guesswork.

A living townsman is not guesswork. The engine is already holding him upright, outdoors, on
navmesh, inside the village, at a height that is genuinely the ground. **His feet are a
proven spawn.** So the ring is now built from the crowd: one sphere scan, keep the living
vanilla locals between 16 m and 70 m, bucket them by bearing into five arcs so the watch
still comes from all round rather than out of one doorway, and take from each bucket
whoever stands nearest the ideal radius. Guards spawn 1.6 m beside him, keeping **his** z.

The raycast ring survives as the fallback that makes up the numbers when there aren't
enough locals — an emptied-out village at night, or a street the player has already
cleared.

Placement is then defended at four depths, because nothing can promise a town spot is
escapable *before* the fact:

1. **The anchor must be outdoors.** A townsman standing in a kitchen has perfectly good feet,
   but a wave forms a *block around him* — and a block around a man indoors is a wave inside
   somebody's house: alive, with a target, and no way out. Anchors now fail `CampDetectRoof`.
2. **Every man's own slot is validated**, not just the anchor (`CampDetectRoof` +
   `CampValidateSpot`). At five points and two men each this barely mattered; at 24 men to a
   *single* point it is the difference between a wave and a wall.
3. **Where the engine actually put him.** A spawn is snapped to navmesh and can be moved a
   long way; more than `TWSpawnSlipMax` (12 m) from his slot and he is deleted rather than
   left wherever he went.
4. **`TownWatchInertCheck` — the safety net.** If the wave's centroid has not moved
   `TWInertDist` (4 m) after `TWInertSecs` (25 s), the muster was bad whatever the reason,
   and the living men are **picked up and put down** at fresh points. Re-placed, not
   despawned: the wave is owed to the player either way. Bounded by `TWInertRetries` (2) per
   wave, so a village with nowhere good cannot loop.

Waves at a single point also form **around** the anchor — rows alternating in front of and
behind it — rather than trailing 8 m in one direction into whatever happens to be there.

The log names the source of every point (`beside kkut_man_88 at 34m`, `raycast ring`) and
reports discards and refusals, so a thin or inert turnout says *why*.

## Standing down

- **The player leaves.** More than 140 m from where they mustered, held for 12 s so
  crossing the line at a run does not flicker them away and back. They defend their own
  village; they were never a pursuit force.
- **All three waves are destroyed.** *Only then* is the village marked spent, with **no
  answer for 3 days** (`TWRegenDays`, measured in `LogiUpkeepDay`). Killing wave one or two
  costs the town nothing but the men. This is the one piece of state that is saved — a fight
  in progress does not survive a level change with anything useful left of it, but "this
  town has nothing left to send" has to outlive both the save and the road to the next town.

Leaving mid-sequence ends it **without** costing the town anything: they never got to
finish, so they are not spent. A level change is treated the same way — the escalation
resets to wave zero rather than the town being marked for a sequence that never ended.

The **dead are left where they fall**. Bodies the player earned are his to loot, and the
loot sweep is already watching for them (they are named `SpawnedEnemy_townguard_*`, so
`IsModEnemyName` picks them up). Only the living are withdrawn.

A message fires once on muster: `merc_info_townwatch_out`, added to all 16 localisations
with English text.

## Known limits

- The leash is distance from the **muster anchor**, not a real village boundary. It is a
  good proxy and needs no authored geometry, but a large town means the player can be
  "outside the village" while still standing in it, and vice versa.
- If the fight ends with the player still inside the leash, the watch stands about until he
  leaves. There is no "they won, now disperse" state yet.
- Muster points depend on there being locals about. A village the player has already
  emptied falls back to the raycast ring, which is the less reliable half.
- Kit is generic Kuttenberg watch everywhere, including Trosky villages.

## Related

- [crime-watch.md](crime-watch.md) — the detection half: classification, the settlement
  test, and the awareness flag this trigger depends on
- [enemies.md](enemies.md) — the enemy-group system, wardrobe budgets and `enemiesFaction`
- [difficulty.md](difficulty.md) — `DifficultyCount` / `DifficultyCeil`
