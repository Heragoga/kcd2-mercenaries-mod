# Detecting fast travel, sleep and teleports

## What the history actually says

The detector was never lost. `mercenaries_main_quest_handler.lua` is **byte-identical in
every commit in this repository**, from the first one to today, and it still holds exactly
the code the early versions ran:

```lua
local isGhostMovement  = (not isOnHorse) and (distanceMoved > 0.5 and playerSpeed < 0.1 and realTimeDelta < 0.4)
local isInstantTeleport = (distanceMoved > 25.0)
```

The idea is right and worth keeping: **the player's position moves while the engine reports
Henry's own speed as zero.** Walking, running and riding all report a speed, so distance
without speed means the player is being carried by something rather than moving himself.

The bug is `realTimeDelta < 0.4`. That test lived inside `MonitorMainQuestLoop`, and that
loop has run at **1 Hz since the first commit** - it was `SetTimerForFunction(1000, ...)`
then and it is a 1000 ms scheduler slot now. `realTimeDelta` is therefore about 1.0 on every
tick, the guard is false every time, and the ghost branch has **never fired once, in any
version of this mod**. It reads like a working detector and is dead code.

That leaves two live branches, and the 2026-09-03 logs show neither firing on this build:

* `isInstantTeleport` needs 25 m inside one sample. Fast travel in KCD2 is not a teleport -
  Henry is walked along the road on the map screen - so a 1 Hz sampler either sees ordinary
  road distances or spans a frozen map screen where the elapsed time is meaningless.
* The world time ratio never came back above 20 in any log, on a fast travel or a sleep. The
  patrol spawn guard uses the same probe and its "waiting" reason has never once appeared,
  while its dialogue and combat reasons appear constantly.

## What the probe measured (2026-09-03, 2343 samples)

`merc_travelprobe 1`, then fast travels on foot and on horseback. The movement heuristics
cannot see a fast travel on this build, and no retuning of their thresholds will change it:

| Reading | What the samples show |
|---|---|
| position | never jumped. Fastest single sample 24.5 m/s, sustained max ~15 m/s - a galloping horse. No level load either. |
| `GetHorse()` | answered "mounted" on **all 2343 samples, on foot included**. It reports that Henry owns a horse, not that he is riding one. |
| `GetWorldTimeRatio()` | exactly **15.0 on every sample**. 15 is the normal rate in this game, so the original `> 20` test was never close to firing for a crossing. |

Two of those are outright bugs in the old detector. The mounted guard the ghost test depends
on was permanently true, so the test was permanently off - a second reason that branch could
never fire, independent of the 1 Hz cadence. And the clock threshold was written as though 1
were the normal ratio.

## What replaced it

**The engine's own actor state, first.** `LuaState_Sorted.txt` carries

```
enum_actorState = { ... skipTime=32, fastTravel=33, cutscene=34, ... }
```

so the engine knows exactly what this module wants to know. What is undocumented is which
bind returns it - so rather than guess one name and ship another detector that silently never
fires, `TravelActorState` tries nine plausible getters once, keeps the first that answers with
a number, and logs which one won. `merc_travelstate` prints what all nine answer. When the
state is available it is the **only** signal used: a gallop and a crossing are identical to
every heuristic, and the state tells them apart. It also covers cutscenes and time skips.

**The movement heuristics, as a backstop** if no getter answers. `mercenaries_travelwatch.lua`
runs them on a **100 ms scheduler slot** (`travelwatch`), the cadence the original test was
written for, with the mounted test fixed - the horse's own position now decides whether Henry
is riding it, rather than whether he owns one. Three ways in:

| Signal | Test |
|---|---|
| **Ghost** | distance > 0.5 m with Henry's own speed < 0.1, sustained 0.5 s, not mounted |
| **Teleport** | more than 25 m inside one 100 ms sample |
| **Clock** | world time ratio above 20 |

A sample whose `dt` exceeds 0.5 s spans a freeze - a load, the pause menu, the map screen -
so its distance is real but its elapsed time is not. Ghost is a rate and is skipped for those;
teleport still applies, since a frozen span is usually exactly what a teleport looks like.

On detection `TravelBegin` stows the company (mercenaries_roster.lua) and takes down standing
patrol gangs; three seconds after the last detection `TravelEnd` puts the company back.

## The actor state is not reachable (2026-09-03)

`merc_travelstate` answered on the retail build:

```
soul:GetState('actorState')        nil
soul:GetState('state')             nil
soul:GetState('actor_state')       nil
actor:GetState()                   unavailable
actor:GetActorState()              unavailable
player:GetState()                  unavailable
human:GetActorState()              unavailable
human:GetState()                   unavailable
this:GetState()                    unavailable
```

`soul:GetState` exists and accepts a name, but it is for soul stats (health, stamina) and
answers nil for the actor state; nothing else exposes a getter at all. The enum is in the Lua
state dump because the engine uses it internally, not because a mod can read it. So the
heuristics are all there is, and the module logs
`no actor-state getter answered - falling back to the movement heuristics` to say so.

## The world clock is the discriminator

The first heuristic run after that fired on **horseback**: `carried 1.8m at 0.00 m/s of his
own`, three times. Riding and being carried are the same thing to a movement test - the horse
moves the player and Henry's own speed is zero - so movement alone can never separate them.
Two changes:

* The mounted test now resolves the horse WUID with `XGenAIModule.GetEntityByWUID`, the bind
  the rest of the mod uses. `System.GetEntity` takes an entity id and returns nil for a WUID,
  which is why the first version of this test reported "on foot" while riding.
  `_G.PlayerMounted` is consulted as a second opinion.
* **Ghost movement now requires the clock to agree.** The nominal ratio is a useless constant
  15, but how fast the world clock ACTUALLY advances is not: `TravelClockRate` measures
  `GetWorldTime()` per real second against that nominal, so a crossing, a sleep and a wait all
  read several times normal while a gallop reads 1.

## Confirmed working (2026-09-03, 1587 samples)

Two fast travels, one on foot and one mounted, both caught, with no false fire in between:

```
[Travel] the player is being carried (the world clock is running 4.8x its normal rate)
[Roster] 5 man/men stowed - the company is a list until it is put back
[Roster] 5 of 5 man/men put back (the crossing is over)
[Patrol] holding spawns - player is fast travel

[Travel] the player is being carried (28m in one sample)
[Roster] 5 man/men stowed
[Roster] 5 of 5 man/men put back (the crossing is over)
```

What the samples show, and what each test contributed:

| | on foot | mounted |
|---|---|---|
| position jump | **none** - 1.3 m in the sample that fired | 27.7 m in one sample |
| world clock rate | **4.8x** | 4.8x |
| caught by | ghost + clock | teleport + clock |

**The world clock is the only signal that catches both.** An on-foot crossing produces no
position jump at all, so a movement-only detector could never have seen it - which is what
every earlier attempt, including the original, was trying to do.

The mounted test also works now: 677 of 1587 samples read mounted, against 2343 of 2343
before the fix. One mounted sample reached rate 2.1 and correctly did **not** fire, the
threshold being 3.

Turn the probe off for normal play (`merc_travelprobe 0`); it writes a line every 100 ms.

## Riding versus mounted fast travel: stamina (2026-09-03)

The world-clock-rate discriminator that separated a mounted crossing from a gallop worked,
but not fast enough to be useful: "the fast travelling detection only fired when the fast
travelling was done." The user's own sample data shows why - the per-tick rate calculation is
noisy against a coarse underlying clock, so a sample taken mid-crossing can read a completely
normal rate:

```
[Travel] at=2509,3238 wt=6794247 rate=1.1 dt=0.50 dist=1.84 speed=0.00 mounted=false ratio=15.0 ... ghost=true tp=false clock=false
```

That is a real fast-travel sample reading `rate=1.1` - below the 3.0 threshold - despite the
crossing being underway. The signal is real on average but not on any single tick, so gating
detection on it meant waiting for a lucky sample.

The user proposed the fix: **stamina**. `Soul::GetState` is documented generically -
"returns state value for a given name (health, stamina,...)" - and is confirmed in the base
game's own feature tests (`references/base_game/Scripts/FeatureTests/saveLoad.xml`):
`player.soul:GetState('stamina')`. A horse's stamina is a live simulated stat: it drains
under exertion and regenerates otherwise, so it is ticking, however slightly, for as long as
the horse is actually being ridden, at ANY pace from a walk to a gallop. Fast travel does not
run that simulation at all, so during a mounted crossing the value does not merely change
slowly - it does not change AT ALL, bit for bit, for the whole crossing.

**The decision tree, exactly as specified:**

1. No distance moved -> standing still. Nothing fires.
2. Distance moved and Henry's own speed is non-zero -> walking (or running, sprinting). Real
   movement, on foot or driving a mounted merc's own animation - never the player, who
   reads 0 in the saddle either way.
3. Distance moved, Henry's own speed reads zero:
   - **Not mounted** - no other explanation exists in ordinary play (walking, running and
     sprinting on foot all report a speed), so this fires on a short grace with no further
     test - being carried on foot.
   - **Mounted** - riding and mounted fast travel are the SAME thing to a movement test, so
     the horse's stamina is checked: if it has not moved at all for `TravelStaminaFreezeSecs`
     (1.0 s default) while ground is being covered, that is not a horse under a rider.

`TravelHorseStamina()` resolves the horse the same way the mounted test does
(`XGenAIModule.GetEntityByWUID`) and calls `.soul:GetState("stamina")` on it - the same bind
already used throughout the mod on merc NPCs (`ent.soul:GetState('health')` in half a dozen
files). If a build's horse entity has no readable stamina, `TravelPlayerStamina()` (the
player's own, same bind) is the fallback; if neither answers, the old clock-rate test is a
last resort, now with its own short grace rather than firing on the first noisy spike.

**The re-baseline bug caught before shipping.** The freeze clock cannot simply be "how long
since the value last changed" measured from whenever that was - a horse standing at a stable
with capped stamina for ten minutes would already read a ten-minute freeze the INSTANT the
player mounts up and starts riding, firing "fast travel" immediately on a perfectly normal
ride. `TravelStaminaFrozenFor` is armed only while the ambiguous state itself holds (mounted
+ covering ground + zero Henry-speed) and re-baselines to zero the instant that state begins,
so the clock only ever measures how long the stamina has been frozen DURING the suspect span,
never before it.

**Known limitation, not yet observed in play**: if a horse's stamina is capped at its
maximum and a gentle walk neither drains nor regenerates it for a stretch, that plateau could
read the same as a crossing. `merc_travelstamina` prints live horse/player stamina on demand -
tap it a few times over a couple of seconds while actually riding to confirm it is ticking. If
a false "fast travel" trigger is ever seen while genuinely riding, raise
`TravelStaminaFreezeSecs` first.

## Not every pace drains stamina (2026-09-03)

Raised immediately after the stamina discriminator shipped: at some paces a horse does not
consume stamina at all, so a genuine slow ride would sit exactly as flat as a crossing does.
The state dump's AI movement table confirms it -
`Horse.AIMovementAbility.AIMovementSpeeds.Relaxed`:

```
Walk:   1.2 - 2.0 m/s
Run:    2.0 - 2.6 m/s
Sprint: 6.5 - 7.1 m/s
```

Nothing says Walk or Run costs stamina - only Sprint plausibly does - and a horse standing
still at a stable is not exerting itself either, for the identical reason a crossing isn't.
Flat stamina alone was never enough; it only means anything once the horse is going fast
enough that flat stamina would be surprising.

**The fix is a speed gate in front of the stamina test, not instead of it.** The test is only
trusted once the SUSTAINED speed since the ambiguous span began is above
`TravelStaminaMinSpeed` (3.0 m/s default - above the table's Run ceiling, below its Sprint
floor). "Sustained" is a running average over the whole span (total distance covered since
mounted-and-ghosting began, divided by the time since then), not one 100 ms sample, for the
same noise reasons the old clock-rate signal was unreliable per-tick.

Below that speed, the tick does nothing at all - not even the world-clock fallback, which
exists only for a build where stamina cannot be read at all, not as a second opinion once a
reading is available. A real walk or trot, however long it lasts, never fires. The accepted
gap: a fast travel that happens to render at walking pace goes undetected. That trip covers
almost no ground compared to what fast travel is for, so the company is barely at any more
risk than if the player had just walked there - a smaller cost than wrongly stowing the
company mid-ride, which is the failure this gate exists to prevent.

`TravelStaminaMinSpeed` is a guess anchored to the generic AI table, not a measurement of a
real, possibly upgraded or perked, player horse - `merc_travelprobe 1` prints `spanSpd` and
`gate` on every sample, so the actual speed at which a specific horse's stamina starts
ticking can be read directly and the threshold set just below it.

## Stamina cannot do it either: the horse's own motion (2026-09-03)

The speed gate lasted one test:

```
[Travel] the player is being carried (mounted, the horse's stamina has not moved in 1.0s at 5.3 m/s)
[Travel] the player is being carried (mounted, the horse's stamina has not moved in 1.0s at 6.0 m/s)
```

Both were a real ride at a canter, and neither drained stamina - the drain threshold sits at
or above a full gallop, not at the AI table's Run ceiling. And crossings had already been
measured rendering at 3.1-3.6 m/s. The two ranges overlap, so no speed gate can separate
"canter with flat stamina" from "crossing with flat stamina". Stamina is not the answer for
a mounted crossing; it only ever appeared to be because the first test happened to be a
gallop.

**The answer is the mounted mirror of the on-foot rule.** On foot, the detector rests on one
fact: Henry's position moves while `player:GetSpeed()` says he is not moving himself. In the
saddle that reading is 0 either way - but the horse has the same bind.
`CScriptBind_Entity::GetSpeed` and `GetVelocity` are entity-level ("Get the speed of the
entity", "Get the velocity of the entity"), so the horse resolved by `GetEntityByWUID` answers
them too. A horse under a rider reports its own motion at any pace, walk to gallop. A horse
being carried along a crossing has its position set for it and reports none.

`TravelHorseMotion()` reads the horse's `GetSpeed()`, falling back to `|GetVelocity()|`. While
mounted and covering ground with zero Henry-speed: the horse reporting motion above
`TravelHorseMoveSpeed` (0.3 m/s) is riding; the horse reporting none for
`TravelMountedGraceSecs` (0.5 s) is the crossing. No stamina, no speed gate, no pace
assumption of any kind - the same shape as the on-foot rule, which has not produced a false
detection yet.

The stamina path is kept only for a build where neither horse-motion bind answers, and the
comment on it now says plainly that its speed gate is a poor substitute. `merc_horsestats`
prints every reading the detector can see - the horse's speed, velocity, stamina and health,
and the player's speed and stamina - so the horse's own speed can be watched at a walk, a
canter and a gallop, and then during a crossing, in one session.

## The window no travel detector can close (2026-09-03)

A gang still spawned during a crossing after all of the above worked. The log shows why, in
order:

```
CryGFxFileOpener::OpenFile(), 'Libs/UI//ApseMap.gfx'      <- the map screen opens
[Patrols] route 13: 7 prague spawned at point 74/144      <- the 3s patrol tick comes round
[Patrols] route 13: despawned (player left the area)
[Travel] the player is being carried (the world clock is running 4.8x its normal rate)
[Roster] 5 man/men stowed
[Mercenary] Fast Travel/Teleport detected! Temp idling mercs.
```

The gang was put on the road **while the player was choosing a destination on the map** -
before the crossing had started, and therefore before any detector could possibly see one.
The clock only spikes once the map closes. No amount of detector work closes that window,
because there is nothing to detect yet.

`Calendar.IsWorldTimePaused()` was tried for this and **answers false while the map is
open** - the map does not pause world time, or does not report it. The probe never fired once
and the gang came through again.

What is certainly true while any menu is open is that **Henry does not move**, so that is what
the patrol tick asks now: `PatrolPlayerMoving` requires 4 m of ground covered within the last
5 s before a gang may be put on the road. A walk covers ~6 m per 3 s tick, so anyone actually
going somewhere clears it, and the gate shuts within two ticks of him stopping - before a
destination is chosen. It also covers standing in an inventory, reading, sitting in a tavern
and simply standing about, all of which are moments a gang appearing nearby reads as an
ambush. A gang the crossing does take down refunds the day's allowance, since the player never
got to meet it.

## If it still misses

```
merc_travelstate
```

That prints what each of the nine candidate getters answers right now. Run it while standing
still and the answer is the idle state; if every line says `unavailable`, no bind exposes the
enum and the heuristics are all there is. Then:

```
merc_travelprobe 1
```

Then fast travel once and send `kcd.log`. Every 100 ms sample prints its raw numbers:

```
[Travel] at=3218,2184 wt=918273 rate=1.0 dt=0.10 dist=0.42 speed=4.10 mounted=false ratio=15.0 frozen=false state=nil | ghost=false tp=false clock=false
```

`at` is the absolute position and `wt` the world clock, so a crossing shows up as a jump in
one or both even if every derived test misses it - which is the question that is left. If
neither moves across a fast travel, then nothing in Lua observes one on this build, and the
answer is to handle the consequence (gather the company after any large displacement) rather
than the cause. Every threshold above is a field on `mercenaries`
and can be retuned from that data without guessing.
