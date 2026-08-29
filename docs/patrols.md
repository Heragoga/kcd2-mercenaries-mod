# Patrols (tester)

A sandbox for working out how bandit and soldier patrols should move.
`mercenaries_patrol.lua`, not player-facing yet.

| Command | Use |
| --- | --- |
| `merc_patrol_wp` | drop a barrel waypoint where you are looking; run once per point |
| `merc_patrol_wpclear` | remove the waypoints |
| `merc_patrol_spawn [count] [group]` | leader + men formed up 10 m ahead of you |
| `merc_patrol_go` | leader walks the route, the block follows |
| `merc_patrol_stop` / `merc_patrol_clear` | halt / remove everything |
| `merc_patrol_status` | where they are and what they are doing |

## Roaming patrols (live)

`mercenaries_patrols_live.lua`, one gang per recorded route. Routes are stored **per level**:

| Level | Table | File |
| --- | --- | --- |
| `kutnohorsko` / `kuttenberg` | `PatrolRoutesKuttenberg` | `mercenaries_patrol_routes.lua` (26 routes) |
| `trosecko` / `trosky` | `PatrolRoutesTrosky` | `mercenaries_patrol_routes_trosky.lua` (21 routes) |

**They cannot be merged into one list.** The two maps' coordinates overlap — the Trosky set
spans x 682‥2904, y 953‥3136, comfortably inside Kuttenberg's range — so the set has to be
*chosen*, never filtered by a coordinate box. `PatrolRoutesForLevel` points `PatrolRouteData`
at the winner; adding a map means recording routes, dumping them into their own file, and
adding a row to `PatrolRouteSets`.

### Identifying the level, in three fallbacks

**1. The level name — never works.** Every candidate (`System.GetCurrLevelName`,
`Game.GetLevelName`, `System.GetCurrAsyncLevelName`, and four more) **errors**: measured in
game, the log read `for level 'unknown'` while the engine was loading `trosecko`.
`CurrentLevelIsTrosecko` exists but is a **Skald quest-graph node** (`LevelLocation`), not a
Lua binding, and the engine bindings list no level-name method at all. The ladder is kept only
in case one ever appears.

Falling back from that to "the first set" was a real bug: it handed Trosky the Kuttenberg
routes and nothing spawned.

**2. RPG locations — the authoritative test.** `RPG.GetLocations()` returns a **different list
per level** (measured: 45 entries on Kuttenberg, 33 on Trosky). The `Location` objects expose
no name field, but their `tostring` is `Location[name=location_pritoky]`, so the name is parsed
out. Each route set lists `locations` that exist only on its map — one match identifies the
level outright, and unlike proximity it does not care where the player is standing, which
matters in wilderness far from any recorded road. Cached for `PatrolLocProbeSecs`; the list
only changes on a level load.

Add names as they are confirmed — `merc_level_probe` dumps the full list for the current level
and says which signature matched, or `NONE` if the table needs a new entry.

> `LocationPoint` **entities** look promising (they self-register via `RPG.AddLocationPoint`
> and carry `guidLocationId`) but are a dead end: measured 2 on Trosky with `guid=nil`, and
> **0 on Kuttenberg**. Don't retry them.

**3. Road proximity — the fallback.** The set with recorded road nearest the player wins.
Self-validating for this feature, since patrols only spawn within `PatrolSpawnRange` anyway.
Measured 4 m vs 266 m on Trosky and 52 m vs 1322 m on Kuttenberg, so it is decisive in
practice. Throttled (`PatrolSetProbeSecs`), short-circuits while the live set still has road
within `PatrolSetNearEnough`, and an incumbent only loses to a challenger beating it by
`PatrolSetSwitchMargin` — switching wipes every live patrol, so it must not happen on a tie.

Switching sets **clears `LivePatrols`**: records are keyed `"route:slot"` and a route index
means a different road on each map, so carrying them across a level change would march one
map's gangs along the other's indices.

Long routes carry two gangs, so Kuttenberg has 37 gang slots and Trosky 24.

### Why Trosky feels emptier

Measured from the two route tables: **Kuttenberg 40.5 km of recorded road across a 3.8 x 3.9 km
footprint; Trosky 20.4 km across 2.2 x 2.2 km** - on levels that are both 4096 x 4096 m. A patrol
can only ever be met near a recorded route, so the half of the Trosky map nobody has ridden with
the recorder is a permanent dead zone, and that is the bulk of the difference. It is a content
gap, not a bug: the gangs-per-kilometre-of-road figures are already close (Kuttenberg one gang
per 1.09 km, Trosky one per 0.85 km), and a matched-exposure simulation of the spawn pipeline
puts Trosky slightly ahead. Recording more Trosky road with `merc_route_*` is the remedy; roughly
doubling it would match Kuttenberg's encounter rate.

Two things were genuinely miscalibrated for Trosky, and both are fixed:

* **The two-gang test is now a length in metres** (`PatrolTwoAtMetres`, 1650 m), not a point
  count. `PatrolRouteStep` (10 m) is the recorder's *minimum* marker spacing, not a guarantee -
  ride faster and the markers space out. Measured, Kuttenberg averages **11.1 m** between points
  and Trosky **15.9 m**, so the old `#pts >= 150` bar meant 1665 m on one map and 2385 m on the
  other. 1650 m is the Kuttenberg equivalent, so this changes Kuttenberg not at all (37 slots
  before and after) and gives Trosky 22 -> 24.
* **The ghost steps by index, so it must divide by that route's own spacing.** `PatrolTickOne`
  used a hard-coded `stepM = 10.0`, which scales the notional patrol's real ground speed by
  (actual spacing / 10): Trosky's ghosts drifted at **2.23 m/s instead of `PatrolGhostSpeed`'s
  1.4** - 59% too fast, hence 37% less time inside the 200-250 m spawn band on every approach.
  `PatrolMeasureRoutes` now stamps `len` and `stepM` on every route when a set goes live, and the
  set's road length and slot count are logged with it.

| Command | Use |
| --- | --- |
| `merc_patrols_status` | where every patrol is, its group, size and state |
| `merc_patrols_here` | spawn the nearest patrol on top of you |
| `merc_patrols 0\|1` | turn roaming patrols off or on |
| `merc_patrols_floor <m> [bandFloor] [bandCeil]` | the hard never-nearer-than distance, and the band |
| `merc_patrols_budget <men> [gangs] [perGang]` | the three population caps |

> There is no `merc_patrols_arm` and no `merc_patrols_clear`, whatever older notes said. The
> switch is `merc_patrols 0\|1` (registered in `mercenaries_commands.lua`, not here), and the
> only route to `LivePatrolClear` is `merc_enemy_clear`, which sweeps every spawned enemy.

**Hostility is faction, not code.** `patrolFaction` is hostile to `player`,
`mercenariesFaction` and `enemiesFaction` (the mod's bandits), and **deliberately silent
about everyone else** — civilians and quest NPCs fall through to the default neutral
relation rather than being dragged into a war. Gating combat in Lua was tried for the
tester and does not work; faction is the only thing the engine actually respects. It is
also labelled `publicEnemy`, so a dead patrolman is looted rather than robbed; that label does
*not* make the town watch join in — see [Public enemies and stolen loot](public-enemy.md) for
why bystanders ignore a patrol and what it would take to change that.

**Size** is a multiple of the player's strength — himself plus his living mercs — clamped to
`PatrolMinMen`..`PatrolMaxMen` (3..50) and rolled per patrol. The floor of the multiple is a
flat `PatrolPartyMin` (0.5x); **the ceiling scales with the party** (`PatrolMaxMultFor`),
ramping from `PatrolPartyMaxSolo` (1.2x at a party of one) to `PatrolPartyMax` (2.0x at
`PatrolPartyMaxAt`, 20, and above).

**A player with no mercenaries still meets patrols.** Being alone used to withhold them
entirely, which emptied the roads for exactly the player who is out there on his own. It now
sizes them instead: `PatrolPlayerAlone` clamps the roll to
`PatrolSoloMinMen`..`PatrolSoloMaxMen` (**3‥5**), applied *after* the difficulty tier and any
route escalation so neither can push past it. Three to five men is a fight a lone Henry can
take or run from.

It used to be a flat 0.5x‥3x with a floor of five men, and that is a mugging rather than an
encounter at the sizes players actually ride around at: a lone rider always met exactly five,
and a party of four met up to twelve. A big company can absorb the full multiple; a small one
cannot, and the small one is the common case. Ramped rather than stepped, so there is no
headcount at which hiring one more merc doubles what walks down the road.

| Party | Original | Ramped | With the population caps |
| --- | --- | --- | --- |
| 1 | 5 | 3 | 3 |
| 4 | 5‥12 | 3‥5 | 3‥5 |
| 6 | 5‥18 | 3‥8 | 3‥8 |
| 11 | 6‥33 | 6‥18 | 6‥16 |
| 21 | 11‥50 | 11‥42 | 11‥16 |
| 31+ | 16‥50 | unchanged | 16 |

`merc_patrols_status` prints the party strength, the size range it currently implies, and the
live population against the caps.

## Pacing

The population caps above answer *how many gangs may stand in the world at once*. Until
2.1.1 nothing answered **how often a new one may appear**, and that is a different question
with a much worse failure mode.

A gang's slot frees the instant its last man dies (`rec.spawned = false`). The next 3 s tick
then finds the whole spawn band eligible again and puts the nearest waiting gang on the road.
The recorded networks have junctions where 9 (Kuttenberg) and 12 (Trosky) gang slots sit
inside the band together, and each of those is a route slot that has never spawned and is
therefore not on any respawn cooldown. So:

> Kill one, another walks in. Kill that one, another walks in. Kill *those* two and two more
> arrive. Nothing was being exceeded — the caps held at 3 gangs and 36 men the whole time.

That is the "endless waves of enemies" report, and it is worth being precise about why it
appeared when it did: it is a **consequence of the ghost-creep fix**. Before that fix an
unspawned patrol never actually moved (`rec.creep` did not carry its remainder), so a player
standing still met whatever happened to be near him and then nothing else, forever. Once
gangs genuinely walk their routes, a standing player has gangs drifting *into* his band for
as long as he stands there. The movement is correct. What was missing is that a road has to
be allowed to go quiet.

Three limits, because there are three distinct failures:

| Knob | Default | Answers |
| --- | --- | --- |
| `PatrolQuietSecs` | 180 s | floor on the gap between **any** two gangs |
| `PatrolPostFightSecs` | 480 s | the longer silence a **wipe** buys — winning has to be worth something |
| `PatrolAnchorCap` | 2 | gangs a player who has not travelled may meet at all |
| `PatrolAnchorRadius` | 500 m | ...how far he must go for that count to reset |
| `PatrolCampClearance` | 350 m | no gang ever spawns this close to the camp |

`PatrolMayEncounter` is checked in `LivePatrolBody` **before** the candidate sort, so a quiet
road costs nothing per tick. It is deliberately separate from `PatrolBudgetFor`: that one asks
whether there is *room* for a gang, this one asks whether it is *time* for one.

**The anchor is what covers standing still.** Two clocks alone still hand a stationary player
a gang every quiet period for ever, and standing still for hours is exactly what a camp is.
`PatrolAnchorTouch` keeps a point and a count; travelling `PatrolAnchorRadius` from it re-seats
both. A player moving through the world clears his own count constantly and never notices the
cap exists.

**The camp is not a patrol route.** A camp pitched beside a road had gangs walking into it all
day, dying to the garrison, and being replaced — "endless waves of enemies spawn near the
camp". `PatrolNearCamp` refuses the spawn while `CampActive`; the notional gang still creeps
straight through, it just never becomes men. Uninvited trouble at the camp is what
[raids](walls-and-sieges.md) are for, on their own two-day clock.

**Both clocks are session-only.** They are stamped from `System.GetCurrTime`, which does not
survive the level you just left, so `ClearAnyLeftoverPatrols` drops them on load —
`PatrolLoadGraceSecs` covers the gap. `PatrolQuietLeft` also discards a deadline longer than
any silence that could have been bought, which is the same clock-went-backwards guard
`RaidTick` uses.

Tune it live with `merc_patrols_pace <gapSecs> [postFightSecs] [standingCap]`;
`merc_patrols_status` prints the current state, including how long the roads are quiet for and
how many gangs the current anchor has already spent.

### Frequency is a difficulty setting

`PatrolQuietByTier` multiplies both clocks:

| Tier | × | gap | after a wipe |
| --- | --- | --- | --- |
| easy | 2.0 | 6 min | 16 min |
| medium | 1.0 | 3 min | 8 min |
| difficult | 0.85 | 2.5 min | 6.8 min |
| extreme | 0.7 | 2.1 min | 5.6 min |
| impossible | 0.6 | 1.8 min | 4.8 min |
| horde | 0.35 | 1 min | 2.8 min |

Before this the tier scaled only how *big* a gang was and how well it was dressed. A player
who picks "easy" usually wants to be left alone, and all he got was the same rate of
encounters in worse armour — which is why the endless-wave reports came in from easy as
readily as from anywhere else. See [difficulty.md](difficulty.md).

## Not while he is busy

Pacing and distance stop a patrol landing *in the player's lap*; they do nothing about
landing on him at a moment he cannot react. A patrol raised while he is asleep, waiting out
the clock, mid-conversation or already fighting a quest battle is a fight he never chose and
often never saw start. `LivePatrolBody` now asks `PlayerBusyForSpawns`
([mercenaries_main_quest_handler.lua](../data/Scripts/mods/mercenaries_main_quest_handler.lua))
before any per-record work, alongside the existing `LivePatrolsEnabled`/`EncountersOn` gates,
and returns early if the answer is yes. Standing patrols are untouched — only *new* ones are
held back, so anything already on the road keeps walking.

This is deliberately **not** `_G.MercIdle`. That flag is about what the squad does and is
narrow on purpose; widening it would idle the men every time the player opened a
conversation. This is about what the world is allowed to do *to* the player, which is a
different and more cautious question.

| Probe | State | Confidence |
| --- | --- | --- |
| `player.player:IsLaying()` | sleeping | confirmed — the camp bed watcher already uses it |
| `Calendar.GetWorldTimeRatio() > 20` | waiting, sleeping, jail | confirmed proxy — there is **no** `IsWaiting` binding; the main-quest handler has used this for as long as it has existed |
| `player.human:IsInDialog()` | in a conversation | vanilla uses it (`TriggerBase.lua`); ours is the first call in this mod |
| `player.soul:IsInCombatDanger()` | in a fight | confirmed, used in four other places |
| `mercenaries.RBQ.active` | the siege of Raborsch | ours |
| `Game.QueryBattleStatus() >= 0.5` | a battle in progress | documented (0 quiet … 1 full combat), unproven here — opportunistic, and only trusted when it answers with a number |
| fast-travel detection | a level transition | the main-quest handler's own ghost-movement heuristic |

There is **no** Lua-readable "a main-quest scene is running" flag. The 12 main-quest battles
set `crime_global_battleInProgress` via `SetGameContextPreset`, but that is an XML-authoring
fact (see [quest-override-battles.md](quest-override-battles.md)) with no reader exposed to
mod Lua, and the `Quest.*` scriptbind has no global table in the runtime Lua state at all.
`IsInCombatDanger` is the honest stand-in: it catches the player being in a scripted fight,
which is what actually matters here. Every probe is `pcall`-wrapped and reads as *not busy*
on failure, so a binding that turns out not to exist quietly leaves the old behaviour alone
rather than erroring.

`SpawnGuardClearSecs` (6 s) holds the gate shut past the last busy reading, so nothing walks
out of the bushes on the frame he wakes up. `merc_spawnguard` prints the verdict and what
every individual probe answers — run it while asleep, in dialogue and mid-fight to confirm
coverage rather than assuming it.

---

## Population caps

The ramp above sizes *one* gang. Nothing used to bound how many gangs were live at once, and
that is where the cost was: the recorded networks have positions with 9 (Kuttenberg) and 12
(Trosky) gang slots inside the spawn band simultaneously, and every one of them spawned. At a
20-merc company that measured a median of 78 and a worst case of **234** extra NPCs.

| cap | default | bounds |
| --- | --- | --- |
| `PatrolMaxMen` | 16 | one gang |
| `PatrolMaxLiveMen` | 36 | every gang, added up |
| `PatrolMaxLiveGangs` | 3 | how many gangs at once |
| `PatrolSpawnPerTick` | 1 | how many may appear per 3s tick |
| `PatrolMaxCorpses` | 12 | lingering bodies, all gangs |
| `PatrolCorpseGraceSecs` | 30 s | the pile just made is exempt from the cap for this long |

Worst case is now 36 living patrolmen, whatever the route geometry. Small parties are
unaffected — they never reached the caps.

**`PatrolMaxMen` clips the ramp above a party of about ten.** That is deliberate: the ceiling
in `PatrolMaxMultFor` still describes the *intent* (a big company should be outnumbered), but a
26-man gang met three at a time is a battle, not a patrol, and the aggregate caps are what
actually bound the cost.

**Spawning is staggered and nearest-first.** Candidates are collected each tick, sorted by
distance, and at most `PatrolSpawnPerTick` of them appear. Previously table order decided who
spawned at a junction and all of them landed on one frame. One consequence worth knowing: a
mounted player crossing a busy junction quickly may only trigger one or two gangs where the old
behaviour would have spawned everything in range. Raise `PatrolSpawnPerTick` if roads feel empty
in transit.

Tune any of it live with `merc_patrols_budget <men> [gangs] [perGang]`; `merc_patrols 0`
switches the system off entirely.

**Strength and identity are both in the soul.** There is one soul per **group** per tier —
`soul_patrol_<group>_1..4` at `combat_level` 0.4 / 0.7 / 0.9 / 1.0 — because the soul carries
the `skald_character_name`, which is what the game **calls him on screen**. A single shared
set of guard souls made every patrol read as a *looter* whatever colours `EquipEnemy` dressed
him in. `PatrolRollSoul(group)` therefore picks from that gang's own set, so name and kit
always agree. Adding a group to `PatrolGroupPool` without souls to match would bring the
mismatch straight back.

**Only nearby patrols exist.** Eight routes of 1-2 km would be hundreds of NPCs, so each
patrol keeps a *notional* index that creeps along its route on a timer whether or not it is
spawned (`PatrolGhostSpeed`). The creep **carries its remainder** (`rec.creep`): a 3 s tick at
1.4 m/s covers 4.2 m of the recorder's 10 m spacing, so flooring one tick's travel on its own
is always zero - and since `moveAt` is stamped every pass regardless, the notional patrol never
moved at all and every gang sat on the point it was rolled at for the whole session. Men appear within `PatrolSpawnRange` and are removed beyond
`PatrolDespawnRange`, so a patrol turns up roughly where it should be rather than where you
last left it. While spawned, the notional index tracks the real leader.

### Never in your lap

A gang materialises only inside a **band**, never on top of the player:

| Knob | Value | Meaning |
| --- | --- | --- |
| `PatrolMinPlayerDist` | 150 m | the hard floor — no man of any gang is ever created inside it |
| `PatrolNoSpawnRange` | 200 m | the band: never *eligible* closer than this |
| `PatrolSpawnRange` | 250 m | ...and no further than this |
| `PatrolDespawnRange` | 330 m | remove them out here (hysteresis) |
| `PatrolFreshMinDist` | 450 m | where a newly rolled record starts |

**The band is not the guarantee; `PatrolMinPlayerDist` is.** The band is tested in
`PatrolTickOne`, which runs for every record first and only then sorts and spawns
`PatrolSpawnPerTick` of them — so the test is up to a tick (3 s) old by the time the men
exist, and a galloping player eats most of a 50 m band in that time. It is also tested on the
*notional point*, while the column is laid out **behind** the lead man, which is as often as
not the player's side of it, and `FindValidGround` can walk each man a few metres further.

So the floor is re-tested where it actually matters:

* `PatrolSpawnGang` re-reads the player's position (never the tick's sample) and refuses the
  whole gang if the route point is inside the floor;
* the lead man is tested again after `FindValidGround` has placed him;
* **every** other man is tested on his own final spot, and one inside the floor is simply left
  out. A gang one man short is invisible; a man appearing at your shoulder is the complaint.

...and `PatrolNearCamp` refuses the whole gang on the same pass, so the camp clearance
cannot be crossed by a gang that merely cleared the player floor.

**The floor was raised from 100 m to 150 m.** 100 m of open Bohemian road is inside the
distance at which a man reads "that just appeared", and the floor is what a *rider* meets —
a galloping horse covers ~50 m in the 3 s between the band test and the men being created,
so the floor is the only number standing between a mounted player and a gang in his lap.
That is the "enemies spawned in front of me" report. The band itself is unchanged.

`force` bypasses all of it, and only the console passes it — `merc_patrols_here` and
`merc_patrol_<group>` exist precisely to put a gang on top of you.

The floor is what stops "I load a save and get jumped". In normal play the floor never bites —
a ghost walking toward a standing player crosses 250 m before it reaches 200 m and spawns at
the outer edge — it only bites when a record appears *near* the player, which is exactly the
load case. Raising the range is the other half: 140 m was close enough that a gang could
resolve within sight.

Three things happen on load. Every record is created fresh, and `PatrolMakeRecord` takes the
farthest of `PatrolFreshTries` (8) random start points, stopping early once one clears
`PatrolFreshMinDist` — measured on the point the slot offset actually lands on, not the one
before it. `ClearAnyLeftoverPatrols` sweeps the men themselves. And nothing spawns at all for
`PatrolLoadGraceSecs` (45 s).

**The grace is the distance floor expressed in time.** Loading in is the one moment the player
has no bearings and no squad: the merc cache rebuild is 2 s behind him and the camp restore 4 s,
so a gang met in the first seconds is met alone — which is what "extreme when you just spawn in"
was. It is a *spawn* gate only; the notional indices keep creeping through it, so when it lifts
the gangs are spread along their roads where they belong rather than queued at the player.
`merc_patrols_here` bypasses it (it spawns a gang directly), and `merc_patrols_status` prints
the time left.

**Patrols are not save-persistent, and cannot be.** The men are ordinary spawned NPCs, so the
engine serialises them with the game — but `LivePatrols` is plain Lua state and is gone after a
load. What came back was a hostile gang with no record, no leader and no route: they never
walked, nothing despawned them, and they stood wherever the player saved. `ClearAnyLeftoverPatrols`
(from `OnGameplayStarted`, before `LivePatrolStart`) removes anything matching `PatrolPrefixes`
and empties `LivePatrols`; the tick re-rolls fresh records within a second or two. Corpses go
with them — their record is gone, so `PatrolClearCorpses` could never reach them.

It scans a `PatrolSweepRadius` (600 m) box rather than every NPC in the world: nothing of ours
can be beyond `PatrolDespawnRange`, and the one permitted full-world NPC scan on load already
belongs to the merc cache.

**Back and forth**, not round and round: `PatrolAdvance` reverses `dir` at each end of the
route. The tester still loops; `PatrolStepIndex` is what differs between them.

**Two gangs on a long route.** Any route of at least `PatrolTwoAtPoints` (150 points, ~1.5 km)
carries two, started `PatrolPairSpacing` of the route apart so they are not shadowing each
other. `LivePatrols` is keyed `"route:slot"` rather than by route index, and every per-patrol
table (including the stuck detector) keys off `rec.key`.

**Kuttenberg only — and that is a LEVEL check, not a coordinate box.** Kuttenberg is its own
map, and Trosky's coordinates overlap these, so a bounding box would cheerfully spawn
Kuttenberg's patrols over there. `PatrolLevelAllowed` matches `PatrolLevels`
(`kutnohorsko`, `kuttenberg`) as a substring of the level name; on any other level the tick
returns immediately and anything standing is removed.

No level API is exposed to Lua, so the name is probed best-effort through
`System.GetCurrLevelName` / `Game.GetLevelName` / `System.GetCurrAsyncLevelName` — the same
ladder `mercenaries_ambush.lua` uses. **`unknown` is treated as "allow"**: better a patrol on
the wrong map than none on the right one, and a route still has to be within
`PatrolSpawnRange` to produce anything. `merc_patrols_status` prints the detected name, so
if patrols never appear that line is the first thing to read.

**Wiped patrols come back.** When the last man dies the record is marked and a fresh gang —
new group, new size, new strength — takes the road after `PatrolRespawnDays` (1).

### One tree, two behaviours

The roaming patrols and the tester share `patrol_scheduler.xml`. It has combat arms
(`FindEnemyTarget` + a `combat_melee` fire, lifted from `enemy_melee_scheduler.xml`), gated
on **`$patrolFights`** — set by `PatrolRole`, true only for a man belonging to a live
roaming record.

> This used to say the split was decided "entirely by the soul's faction". **That was
> false.** `FindEnemyTarget` contains no relationship or faction check of any kind and
> returns the player unconditionally, so the tester acquired targets exactly like the
> roaming gangs. Faction only decides how *third parties* react.

**Patrols are their own side in `SideOf`.** They used to fall through to `'friend'`, which
handed them the mercenaries' 20 m leash **to the player** — so a gang fighting anywhere the
player wasn't standing failed its `combat_melee` on the first watchdog tick, sheathed, and
had it re-fired ~1 s later, for ever. That is the whole "start-stop near enemies without
fighting" symptom. They now leash to their **own target** at 60 m (outside `FindEnemyTarget`'s
own 50 m acquisition radius, so a spurious trip self-corrects instead of failing the fight).
Making them `'enemy'` instead is the wrong fix: that removes leashing altogether, they chase
the player across Kuttenberg, `PatrolSyncIndex` rewrites the gang's notional route index to
wherever the chase ended, and `PatrolDespawnRange` deletes them mid-fight on screen.

**The route yields to combat from the inside.** `patrol_walk`/`patrol_follow` are fired at
Priority 200 while `combat_melee` is 160, and whether a 160 fire can evict a running 200 is
genuinely unsettled (`docs/npc-lod.md` measures 200 beating 160; `patrol_walk.xml` used to
claim the opposite). Rather than bet on it, the *behaviour ends itself*: `PatrolWalkTick`
sets `routeDone` and `PatrolFollowRole`/`PatrolChainPoll` drop `stillFollowing` the moment
`PatrolHasTarget` is true, which frees the interrupt slot whichever way the engine resolves
priority. The scheduler re-fires the route once `FindEnemyTarget` drops the target again.
Walking and following also stand down while `$inCombat`, so combat movement never fights the
route `Move`.

**A claim that never becomes a fight is written off.** Holding a claim is what stands a
patrolman down off his route, so a claim that never turns into combat stops him for good — he
neither walks nor swings. That was "the patrol always stops when it gets near me". A claim now
has `PatrolEngageGrace` (5 s) to reach a combat context; past that it is dropped along with the
alert's forced target (or `FindEnemyTarget` would hand the same one straight back) and the
route resumes. `PatrolYieldToCombat` is the single gate all three yield points go through.

**The whole gang joins in, not just the point.** `PatrolDetectRange` (12 m) is deliberately
short — a gang walking a road should have to *come across* you rather than notice you from
across a field. But that range is **per man**, and a fifty-strong gang is strung out along the
road, so only the few at the point were ever inside it: the front rank fought while the tail
walked on past. That is the "long patrol line only partly engages" bug.

Once any man makes contact, `PatrolAlert` marks the record and pushes his target to every
living member through **`ForcedTargetOf`**, which `FindEnemyTarget` honours ahead of its own
scan and **without any distance limit** — so the tail turns round and comes. It lasts
`PatrolAlertSecs` (45 s), refreshed while contact continues, and is cleared when the target
dies or the timer runs out (`PatrolAlertClear`, from the live tick).

Two details that matter:

- **`PatrolCombatLeash` had to go up to 120 m.** The patrol melee leash is measured against the
  man's own target, and an alerted rear-rank man is handed a target far beyond his own detect
  range — at the old 60 m he would disengage on the first watchdog tick instead of closing.
  Still far inside `PatrolDespawnRange` (220 m), so it cannot become a cross-map chase.
- **The alert is throttled.** Contact is reported every tick by every man in range; rewriting
  fifty forced-target entries every second is thousands of pointless writes, so the clock is
  refreshed cheaply and the gang is only re-tagged when the target changes (or every ~3 s, to
  pick up men who have joined since).

**A corpse must not lead.** `PatrolCtx` checks membership against the full roster (so a
downed man is still recognised as one of ours) but builds the leader and the follow chain
from `PatrolLivingMen`. The chain is only re-read when a man's *target* changes, and a dead
man's key never changes — so before this, a fallen leader anchored the whole column where he
died. Deliberately **no `PatrolEpoch` bump** on a death: that counter is global across every
gang and the tester, so bumping it restarts every `CrimeFollower` on the map at once.

**The follow fire must be re-armable.** The scheduler latches `followFired` so it does not
re-issue `patrol_follow` every second — and nothing cleared that latch, so anything which
ended the behaviour (combat replacing it, a failed move, the leader dying) left the man
standing for good while the leader walked on. `PatrolFollowEnd` cannot touch the scheduler's
variables from inside the behaviour's own tree, so it flags the man in `PatrolRefire` and
`PatrolRole` clears `followFired` on its next poll.

The Lua hooks are shared too. `PatrolCtx(ent)` resolves any patrolman to his own leader,
followers, route points and index — the tester's singletons or one of the roaming records —
so a single set of BT hooks drives all nine patrols at once.

## Recording routes

`mercenaries_routes.lua`. Ride the route you want a patrol to walk and it drops a marker
every `PatrolRouteStep` (10 m) — the recorder samples the player position four times a
second and drops a barrel whenever he has moved a full step from the last one.

| Key | Command | Use |
| --- | --- | --- |
| F5 | `merc_route_new` | start a new route (drops a marker where you stand) |
| F6 | `merc_route_save` | keep it; markers stay standing so the shape is visible |
| F7 | `merc_route_cancel` | discard it and remove its markers |
| F8 | `merc_route_dump` | print every saved route as a Lua table |

**F5 is vanilla quicksave and F8 is vanilla quickload.** The binds are re-applied on every
load, so while the recorder is installed those two keys belong to it. Change the four
`System.ExecuteCommand("bind …")` lines in `mercenaries.lua` if that is not the trade you
want, or rebind from the console.

Supporting commands: `merc_route_status`, `merc_route_show [n]` / `merc_route_hide`,
`merc_route_forget`, `merc_route_step <m>`, and `merc_route_walk [n]` — which loads a
recorded route into the patrol tester so `merc_patrol_go` walks it immediately.

Routes are saved to `QMRoutes` as flat text so they survive a reload while you are
collecting them. That is working storage, not the shipping form: `merc_route_dump` prints
them as a `mercenaries.PatrolRouteData` table to be pasted into the mod once the shapes are
right.

## Why they need their own brain

Making the **tester** harmless took several attempts:

1. **Gate our own combat fires** (`wbLocked`, the wall-battle lock). Still attacked — this
   only stops the mod from *choosing* to attack.
2. **Move the souls to a friendly faction** (`testFaction`, friendly to the player and the
   mercs). Still attacked.
3. **Give them their own brain**, so the only reachable combat path is one tree we control.

The tree is now shared with the roaming gangs, which must fight, so the capability cannot
simply be absent — it is gated on `$patrolFights` instead. That looks like attempt 1
repeating itself, and the difference matters: attempt 1 gated *Lua* while the tester souls
still sat on `renegade_brain`, whose own scheduler arms were never gated at all. Since
`patrol_brain` maps only to `patrol_scheduler.xml`, the two arms behind `$patrolFights` are
the only combat path the tester can reach.

The original lesson still generalises: as long as *any reachable* tree can acquire a target
and fire an attack interrupt, something eventually will. Gating is only safe once you know
every tree the soul can run. **If a gated tester is ever seen swinging again, the answer is
structural** — split `patrol_tester_scheduler.xml` off with the acquisition and combat arms
deleted outright (keep `inCombat` and its tracker; the locomotion arms read it) and repoint
the tester's `brain2subbrain` row at it.

The rest is belt and braces: souls stay on `testFaction`, names are `SpawnedPatrol_` rather
than `SpawnedEnemy_` so `IsModEnemyName` does not match (the mercs will not target them and
the raid/wall-battle systems ignore them), and weapons are sheathed on spawn.

Registration follows the static archer's chain — `brain__`, `subbrain__`,
`subbrain_switching__` and `brain2subbrain__mercenaries.xml`, plus the second
`brain2subbrain` row to `4eaa0620-…` that every brain here carries.

Appearance still comes from `EquipEnemy(ent, group, false)` — clothing and weapons only,
nothing to do with faction — so they can be dressed as any enemy group and stay harmless.

A soul's `skald_character_name` must exist in `skald_character__mercenaries.xml`; only
`char_enemy_looter_1` and `_2` are defined, so the four patrol souls cycle those two.

## Marching

Two proven pieces, nothing invented.

**The leader's walk is a BEHAVIOUR** (`patrol_walk.xml`), not a scheduler arm. It ran in the
scheduler while the patrols were a harmless tester, which was fine because nothing competed
for the leader's movement — but once the roaming patrols gained combat, the scheduler's own
`Move` held him and `combat_melee` could never take movement over, so **the leader never
entered a fight**. As a behaviour, combat replaces it cleanly and the scheduler re-fires it
afterwards. Nothing moves in `patrol_scheduler.xml` any more: it only fires `patrol_walk`
and `patrol_follow`.

Both fires are latched (`walkFired`, `followFired`) and both are re-armed the same way: the
behaviour's `OnFail` flags the man in `PatrolRefire`/`PatrolRefireWalk`, and `PatrolRole`
clears the latch on its next poll. Without that, anything ending a behaviour leaves the man
standing for good.

Its mechanism is `testnpc_walk.xml`'s: one continuous `Move` whose
`$wpPos` Lua rewrites in place, with the waypoint advanced at a **switch radius**
(`PatrolSwitchR`, 7 m) rather than on arrival. Because the destination moves on before he
gets there, the `Move` never completes — and a `Move` that completes is restarted from a
standstill by the loop around it, which is the stop every few metres. The first version
drove the leader through `nav_goto`, which ends on arrival and gets re-issued, and stopped
at every waypoint for exactly that reason.

#### The lookahead has to be defended, not just written

The switch radius only helps while the index it advances stays advanced, and two things
fight it. `PatrolSyncIndex` (every live tick, 3 s) parks the record's index on the point
*nearest* the leader — but the walk deliberately runs one or two points ahead of that, so
the sync rewound it and the next tick republished a point he had already walked past.
A destination 11 m **behind** the previous one makes him brake, turn, and pick the road up
again 150 ms later: that is the stop at every waypoint, back again with the lookahead
apparently in place. Measured over one Kuttenberg route it happened 38 times.

Two changes, both needed:

- `PatrolSyncIndex` may only move the index **forward along `rec.dir`** unless a caller
  forces it (`merc_patrols_here` does, since it is re-seating the gang on the player).
- `PatrolWalkTick` advances in a **`while` loop** instead of one step, until the published
  point is beyond the switch radius. One step is only ever enough while nothing else
  touches the index, and something does.

The rule to keep: the destination handed to that `Move` must be monotone along the route
and never nearer than `PatrolSwitchR`. Anything that writes `rec.idx` has to respect it.

**The formation is `follow.xml`'s, verbatim**: the leader owns a `MakeFormation` and the
rest run `FormationFollower` off him, with the same `formationEpoch` / `formationModeCode`
latching. It is identical to the squad's own formation in every respect except the anchor —
the patrol leader instead of the merc who stands in for the player.

`FormationFollower` **is** the followers' locomotion; they have no `Move` of their own, and
the engine does NPC-on-NPC avoidance inside it. That is what a hand-rolled column of
trailing offsets could not do, and why the first attempt looked like a mess.

### Follower nodes must be a BEHAVIOUR, not a scheduler arm

Running the follower nodes as an arm of `patrol_scheduler.xml` fails outright:

```
[FollowerBase]: This node can run only in SchedulerSubbrain
```

`FormationFollower` and `CrimeFollower` share that base, so **both** are rejected when the
tree is the switching subbrain itself — and the man just stands still, with no other
symptom. `follow.xml` gets away with them because it is fired as an interrupt behaviour.
In this mod schedulers *fire*; behaviours *act*.

So the follower half lives in `patrol_follow.xml`, registered in
`SmartEntity__so_interrupt__mercenaries.xml` alongside `nav_goto`, and the scheduler only
fires it — latched on `followFired`, cleared on an epoch change so a respawn re-issues it.

### The double column

The shape is a **CrimeFollower chain**, the one the mod used before (`AssignNpcFormation`):
the first `PatrolWidth` men follow the leader, and everyone after follows the man
`PatrolWidth` places ahead. With a width of 2 —

```
m1 (file 0) follows LEADER      m2 (file 1) follows LEADER
m3 (file 0) follows m1          m4 (file 1) follows m2
```

— two files, i.e. a double column. `PatrolChain` returns the man to follow and the file.

`MakeFormation` was tried and taken out again. The authored `merc_column*` preset *is* a
column of twos and holds a tidier shape, but a formation spot is a rigid offset from the
anchor: it cannot absorb a leader moving faster than his men, and the leader visibly pulls
away from the block. A chain has no fixed geometry to violate, so it degrades gracefully.

`Role` is a node **attribute** and cannot be a variable, so the two files are two
`CrimeFollower` nodes behind a switch — file 0 on `Main`, file 1 on `Assist`. Same reason
`follow.xml` spells out every `FormationMode` combination separately.

### End the follower node on a change, never on a timer

`CrimeFollower` never returns on its own, so something has to end it or the chain could
never be re-read when a man ahead dies. The obvious answer is a time-box — and it is wrong
here: **restarting `CrimeFollower` makes the follower dash to re-acquire his station**, so
a 1.5 s box produced a catch-up sprint every 1.5 seconds, forever. That is the "weird loop".

So the second arm of the `Parallel` is a watcher: it polls `PatrolChainPoll` once a second
and only finishes when the man he follows has actually changed (target or epoch). In steady
state the node runs uninterrupted and he simply walks. `PatrolFollowRole` re-baselines
`PatrolChainOf` when it issues an order, so the watcher never fires on the order it was
just given.

### Keep the two speeds in step

**Everyone walks.** Two places set that and they must agree:

| Who | Where |
| --- | --- |
| leader | `speed` on the `Move` in `patrol_scheduler.xml` |
| followers | `MoveParamsDecorator speed` and `RelativeSpeedLimit` in `patrol_follow.xml` |

**A leader faster than his followers' ceiling simply runs away from them.** That is exactly
what a running leader with `Walk`-capped followers produced, and no follower method fixes
it — it is a speed mismatch, not a following problem.

The cost of capping both at `Walk` is that a man who loses ground on a corner or an
obstacle has no faster gear to recover with. If they straggle, give the followers back
their headroom (`RelativeSpeedLimit="Dash"`) rather than speeding the leader up — that
keeps the patrol walking while letting stragglers close.

`PatrolSlot` lays the men out at spawn in two files, so the block does not have to
reshuffle the moment it starts moving.

### Unreachable waypoints

A waypoint more than ~2 m off the engine navmesh makes every path request fail —

```
[MoveBase] Path finding failed: End point ... is not close enough to nav mesh
```

— and the leader stands there spamming the log. There is no scriptbind for "nearest point
on the navmesh", so `merc_patrol_wp` runs the dropped point through `FindValidGround`, and
`PatrolWalkTick` watches for a waypoint it is making no progress toward
(`PatrolStuckSecs` / `PatrolStuckGain`) and skips it with a log line. Aim at open ground.

### Lua locals bind downward only

`pLog` and `pKey` are declared at the very top of `mercenaries_patrol.lua` on purpose. A
`local function` is only in scope for code written *after* it, so a helper added above them
gets `attempt to call global 'pKey' (a nil value)` at runtime, not at load.

