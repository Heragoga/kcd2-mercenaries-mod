# Foe AI

A rewritten hostile NPC, built from scratch and sharing **nothing** with the enemy
groups (`renegade_brain` / `enemy_melee_scheduler` / `combat_melee` /
`FindEnemyTarget`). Own brain, own souls, own faction, own trees, own Lua file. The
two systems can run side by side; deleting either leaves the other untouched.

It exists to fix two things about the old enemies: they took ten seconds or more to
start fighting, and a few of them never started at all.

## The two states

| State | Behaviour | When |
|---|---|---|
| `idle` | `foe_idle.xml` — sheathe, stand around, play a standing emote every 8–12 s | not alerted, or alerted with nothing in range |
| `combat` | `foe_combat.xml` — melee automation charging `$attackData.target`, no leash | alerted and holding a target |

`foe_idle` is the only piece meant to be swapped per foe type. Whatever a band is
doing before the fight — camp life, a march, a patrol — replaces that tree and
nothing else changes. For the test it just stands there.

## The alert

This is the point of the system.

1. A foe notices a target only inside **`FoeDetectRange`** (20 m, line of sight
   required — terrain and static geometry block it, other NPCs do not).
2. The moment one does, he is alerted, **shouts**, and charges.
3. Every foe within **`FoeAlertRange`** (70 m) of the shout is alerted too, *whether
   or not he can see anything himself*, and is handed a target in the same tick.

So a scout at the edge of a camp pulls the whole camp in at once, instead of each man
waking up separately when the fight reaches him.

Three things raise an alarm, all with the same 70 m reach:

| Trigger | Shouts | Why it exists |
|---|---|---|
| a foe spots a target | yes | the main case |
| a foe is hit | yes | an arrow out of the trees has already answered "did he notice you" |
| a foe dies | no (he's dead) | otherwise a band picked off at range by archers never reacts at all |

Propagation is **single hop**: a man woken by a shout does not shout on. Set
`mercenaries.FoeAlertChains = true` to let it chain, but one alarm then ripples
across every foe on the map that is within a chain of 70 m hops.

The shout itself is the vanilla `NPC_VIDI_NEPRITELE_A_BUDE_UTOCIT` bark
("sees an enemy and will attack"), played by **metarole** rather than by alias — the
engine casts it out of the base game's own pool onto the foe's voice, so there is no
mod Skald dialog and no shipped VO. That is also the only reason the foe souls need
`skald_character` rows: a soul with no voice cannot be cast, and the shout is silent.

## Why it engages fast, and always

Engagement is decided in **Lua**, not in the tree.

`FoeTick` (250 ms) does detection, alerting and targeting for the whole roster in one
pass. `foe_scheduler.xml` polls it at the same 250 ms and fires whatever Lua asked
for. Worst case from "a foe sees you" to "the interrupt is issued" is two ticks —
half a second.

The reliability half is the **heartbeat**. A running behaviour calls
`mercenaries:FoeBeat(id, kind)` every 700 ms. Lua re-fires whenever:

* there is no heartbeat within `FoeBeatTimeout` (2.5 s), or
* the heartbeat says `idle` when the foe should be fighting, or
* an encounter explicitly asked for a re-point (`r.repoint`; nothing sets it today),

throttled to one attempt per `FoeRefireDelay` (1 s). A fire that silently failed is
therefore retried a second later, forever. **That is the structural fix for the
enemies who never engaged**: in the old system a failed `AddInterrupt` was invisible
and nothing ever looked again.

Three specific silent failures the old system could hit, and what this one does:

| Failure | Old behaviour | Here |
|---|---|---|
| `Function_crime_getMrkev` yields no interrupt host | wrapped in `SuppressFailure`, `AddInterrupt` fired at nothing, man stands still | `hasHost` is checked, `FoeOnFired(..., false)` logs it, retried next second |
| `AddInterrupt` refused (priority, timing) | nothing noticed | no heartbeat follows, so it is re-fired |
| fire loop and "am I in combat" tracker race, re-firing and so restarting a fight that had just begun | left ~1 in 10 disarmed and idle | there is no tracker: the tree reports, Lua decides |

`foe_status` prints, per foe, how long it took him to engage after being alerted.
That number is the thing to watch.

### A re-fire is not free — it restarts the charge

`AddInterrupt_attack` carries `IgnorePriorityOnPreviousInterrupt`, so a re-fire
**replaces** the running combat: its `OnFail` runs, and the approach starts again from
the top. One re-fire a second reads in game as *step, wait, step, wait* all the way
across the field. Three things exist to keep that from happening:

* **Targets are held, not re-picked.** Once acquired, a foe keeps his man until he is
  dead, despawned or past `FoeEngageRange` — never because someone else drifted
  nearer. The first version re-picked every tick unless the target was within 6 m,
  i.e. for the whole of every charge.
* **A running fight is never interrupted to re-point.** See below — this was the
  stutter.
* **An alerted foe is never sent back to idle.** If he is alerted with nothing in
  range he simply holds. `foe_idle` sheathes his weapon; one bad tick mid-charge would
  otherwise have him put his sword away and draw it again.

Every re-fire logs `[Foe] '<name>' re-fired combat (<reason>)` with which of the three
`FoePoll` conditions asked for it — no heartbeat, wrong behaviour running, or a forced
re-point. Repeated lines for one foe during an approach mean the stutter is back, and
the reason says where to look. **This log is what identified it**; it should be silent
while a foe crosses the field.

The same class of bug lives in the combat tree's `Parallel successMode="Any"`: an arm
that merely **succeeds** ends the fight exactly as an arm that fails does. The shout
arm therefore ends in a `Loop count="-1"` around a finite `Wait`, not a bare
`Wait '-1'`, so it cannot return however the engine treats that duration.

### The approach stutter, and what it actually was

Foes closed on the player in **baby steps — step, pause, step, pause** — the whole way
across the field. It took four attempts, so the reasoning is worth keeping.

**The tell: foes with an empty weapon set ran in perfectly straight.** Only the armed
ones shuffled.

The confirmed cause was **re-fire churn**, and the tell is what connects the two: every
re-fire replaces the running behaviour, so `foe_combat` is entered again from the top
and replays its explicit `DrawAction` — a full animation that stops the man where he
stands. A foe with an empty weapon set has his `DrawAction` fail instantly, so he never
stops. One re-fire a second, one pause a second.

What kept re-firing was the `target changed` condition, comparing an identity key that
was not stable:

* **The key is now the entity NAME.** Neither `tostring(ent.id)` nor
  `tostring(ent.this.id)` is safe for this — those are handles, and one read fresh each
  tick does not necessarily stringify to the same text twice. So "is he still fighting
  the right man?" answered *no* on every tick, forever. Names are plain strings and
  unique per entity.
* **A running fight is no longer interrupted to re-point at all.** There is no need
  for it: when the man he is actually fighting goes down, the watchdog ends the
  behaviour, the heartbeat stops, and the next poll fires him at whoever the record
  holds by then. `r.repoint` is the explicit override for an encounter that genuinely
  must move someone mid-fight; nothing sets it today.
* **The entry `DrawAction` is now conditional** on the weapon not already being out, so
  even a legitimate re-fire costs no animation.

`foe_status` shows `wants=` and `fighting=` per foe. Those two differing is normal —
a live fight is never interrupted to re-point. Both differing *and* no heartbeat is a
problem.

### The combat stack, matched to vanilla

Fixed along the way while hunting the above, and correct regardless: the combat arm is
now node for node vanilla's own NPC-vs-NPC melee,
`references/AI/crime/friendlyFight.xml`:

```
CombatMoveDecorator
 > MeleeOffenseAutomationDecorator
   > MeleeDefenseAutomationDecorator
     > MeleeGuardAutomationDecorator (automate)
       > WeaponAutomationDecorator (melee)
         > CombatFollowerDecorator (sweet spot + arc driver)
           > CombatAction
```

* **`CombatMoveDecorator`** is what puts an NPC into combat locomotion. The mod had it
  nowhere. It replaces the `MoveParamsDecorator` that used to wrap this stack — vanilla
  never puts one outside `CombatFollowerDecorator` and mostly has none at all.
* **`CombatAction` takes no loop, in any position.** It is not a one-shot: under the
  offense/weapon automation it closes, swings and keeps swinging until the target is
  down. The watchdog sibling in the `Parallel successMode="Any"` is what keeps the
  fight alive, exactly as `combat_archer_static` does it.

> `combat_melee.xml` — the old enemies, mercs, quartermaster and archers in melee — has
> no `CombatMoveDecorator`, and does have both the outer `MoveParamsDecorator` and the
> outer re-issue `Loop`. Left alone because it is shared with the entire merc side.

### Bisecting a movement problem in-game

Because that took three rebuilds to find, each automation decorator is now switchable
from Lua at combat entry (`mercenaries.FoeAutomation`, read by `FoeCombatEnter`):

```
foe_auto                      list the current flags
foe_auto guard 0              turn one off
foe_calm                      then
foe_alert                     re-fire everyone with the new flags
```

`weapon` is the interesting one for anything that only affects armed foes; `movement`
disables `CombatFollowerDecorator`, i.e. the approach itself.

## Files

| File | What |
|---|---|
| `data/Scripts/mods/mercenaries_foe.lua` | the whole system: roster, detection, alert, targeting, fire decisions, spawn and debug commands |
| `data/AI/foe_scheduler.xml` | the switch. A dispatcher — it makes no decisions |
| `data/AI/foe_combat.xml` | melee combat + the alert shout |
| `data/AI/foe_idle.xml` | the pre-combat state |

Table rows, all in the mod's existing `__mercenaries` patch files: `foe_brain`
(`f0e10000-…-0001`) → `foe_scheduler` (`…-0002`), mailbox group `…-0003`,
`foe_combat` / `foe_idle` as `SmartBehaviorTemplate`s, six `soul_foe_*`
(`f0e15001-…`), three `char_foe_*` skald characters, a `foeFaction`, and
`foeappearance.xml` on the storm appearance task.

`foeFaction` is hostile to `player` and `mercenariesFaction` and **silent about
everything else**, so civilians and quest NPCs fall through to neutral.
`mercenariesFaction` carries the matching `-1` back, because the mercs' own target
selection gates on `GetRelationship(player) == -1` — without that line the squad
never sees a foe as a valid enemy.

## Console

```
foe_spawn            8 unalerted foes 45m ahead
foe_spawn_1          one, 25m ahead
foe_spawn_20         20, 55m ahead, spread 40m
foe_spawn_scout      the alert demo: a scout at 30m, a band of 8 at 75m behind him
foe_clear            remove every foe
foe_status           per-foe state, what alerted him, and his engage delay
foe_alert / foe_calm force every foe into / out of the alerted state
foe_ranges <d> <s>   set detection and shout ranges live
foe_auto <name> <0|1>  switch a combat automation decorator off to bisect movement bugs
```

`foe_spawn_scout` is the one to run: walk to the scout, and the band 45 m behind him —
which cannot see you at all — should come in with him.

## Tuning

All in `mercenaries_foe.lua`:

| Name | Default | |
|---|---|---|
| `FoeTickMs` | 250 | master tick and detection resolution. Also the scheduler's `Wait` — keep the two the same |
| `FoeDetectRange` | 20 | own eyes |
| `FoeAlertRange` | 70 | how far an alarm carries |
| `FoeEngageRange` | 120 | an alerted foe acquires targets out to here, and holds one out to here |
| `FoeSwarmCap` | 4 | foes on one target before the rest spill onto someone else — applied at acquisition only |
| `FoeRequireLos` | true | detection needs line of sight; the alarm never does |
| `FoeAlertChains` | false | let a shout-woken foe shout on |
| `FoeBeatTimeout` | 2.5 | no heartbeat for this long = not running |
| `FoeRefireDelay` | 1.0 | minimum gap between fire attempts |

## Rules carried over from the old system

These were paid for once already (see [ai-modules.md](ai-modules.md)) and are kept:

* `WeaponChange="melee"` plus an explicit `DrawAction`, or a foe that engages the
  instant he is told to charges in with his fists.
* The explicit draw is inside `SuppressFailure`: a foe whose weapon set came out empty
  must still reach the fight rather than die at that node. `FoeEquip` applies weapon
  category 2 after the random one for the same reason.
* `CombatAction` is continuous and takes **no loop of any kind**, and the melee stack
  must sit inside `CombatMoveDecorator` — see below; this pair cost three rebuilds.
* The combat watchdog confirms a dead target with a second read 300 ms later —
  `FoeCombatTick` defaults `isTargetAlive` to false and only raises it after a
  successful WUID lookup, so a single hiccup would otherwise read as a death.
* `foe_combat` judges liveness on `attackData.target`, the man it was actually fired
  at — not the record's current target, which can be one tick ahead of it.
* The `OnFail` `Wait` sits inside `crime_interruptAttack`, which is dead time before
  anything else can run. It is 200 ms.
* `foe_idle` deliberately does **not** open `crime_interruptAttack`, so combat can
  replace it.
* No `DrawWeapon(false)` on combat exit: an alerted foe stays alerted and keeps his
  weapon out between targets, instead of sheathing and re-drawing each time someone
  in front of him goes down.

## Not done yet

* Archers. Melee only — the ranged module would be a second behaviour fired by the
  same scheduler off the same target.
* Fleeing, surrender, morale.
* Anything but `stand around` for the pre-combat state.
* Persistence: foes are not saved.
