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

Long routes carry two gangs, so Kuttenberg alone has 37 patrols.

| Command | Use |
| --- | --- |
| `merc_patrols_status` | where every patrol is, its group, size and state |
| `merc_patrols_here` | spawn the nearest patrol on top of you |
| `merc_patrols_arm 0\|1` | turn roaming patrols off or on |
| `merc_patrols_clear` | remove them all and re-roll |

**Hostility is faction, not code.** `patrolFaction` is hostile to `player`,
`mercenariesFaction` and `enemiesFaction` (the mod's bandits), and **deliberately silent
about everyone else** — civilians and quest NPCs fall through to the default neutral
relation rather than being dragged into a war. Gating combat in Lua was tried for the
tester and does not work; faction is the only thing the engine actually respects.

**Size** is `PatrolPartyMin`..`PatrolPartyMax` (0.5x-3x) of the player's strength — himself
plus his living mercs — clamped to `PatrolMinMen`..`PatrolMaxMen` (5..50), rolled per patrol.

**Strength and identity are both in the soul.** There is one soul per **group** per tier —
`soul_patrol_<group>_1..4` at `combat_level` 0.4 / 0.7 / 0.9 / 1.0 — because the soul carries
the `skald_character_name`, which is what the game **calls him on screen**. A single shared
set of guard souls made every patrol read as a *looter* whatever colours `EquipEnemy` dressed
him in. `PatrolRollSoul(group)` therefore picks from that gang's own set, so name and kit
always agree. Adding a group to `PatrolGroupPool` without souls to match would bring the
mismatch straight back.

**Only nearby patrols exist.** Eight routes of 1-2 km would be hundreds of NPCs, so each
patrol keeps a *notional* index that creeps along its route on a timer whether or not it is
spawned (`PatrolGhostSpeed`). Men appear within `PatrolSpawnRange` and are removed beyond
`PatrolDespawnRange`, so a patrol turns up roughly where it should be rather than where you
last left it. While spawned, the notional index tracks the real leader.

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

