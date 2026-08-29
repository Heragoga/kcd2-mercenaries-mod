# Performance

What this mod costs, what controls it, and how to measure it. The investigation that produced this
is in the appendix — including what turned out to be wrong, so nobody re-chases it.

## The short version

The long-standing "world is struggling" problem was **roaming patrols**: on by default, spawning
with no mercs hired, with nothing bounding how many gangs could be live at once. At a 20-merc
company that measured a median of 78 and a worst case of **234** extra full NPCs. Capped, it is 36.

The mod's **Lua is not a meaningful cost** — every scheduler slot, behaviour-tree hook and
persistence write together measured **0.19% of wall time** (116ms in a 60,300ms window, release
build). Cost lives in what the mod makes the **engine** do: NPCs it spawns, entities it keeps
rendered, raycasts it fires, cvars it raises.

## Tunables that control cost

| tunable | file | default | what it costs |
|---|---|---|---|
| `LivePatrolsEnabled` | `mercenaries_patrols_live.lua` | true | the whole patrol system; `merc_patrols 0` |
| `PatrolMaxLiveMen` | same | 36 | living patrolmen, all gangs |
| `PatrolMaxLiveGangs` | same | 3 | concurrent gangs |
| `PatrolMaxMen` | same | 16 | one gang |
| `PatrolSpawnPerTick` | same | 1 | gangs appearing per 3s tick |
| `PatrolMaxCorpses` / `PatrolCorpseSecs` | same | 12 / 180s | lingering ragdolls |
| `RenderPin` | `mercenaries_util.lua` | true | every merc never distance-culled or LOD-reduced; `merc_render_pin 0` |
| `LodBoostMinCrowd` + `LodBoostRequireFoes` | `mercenaries_lodboost.lua` | 70, true | raises the engine AI-LOD budget globally while a real fight is on — and **only** then; density alone must never arm it |
| `PatrolQuietSecs` / `PatrolPostFightSecs` | `mercenaries_patrols_live.lua` | 180 s / 480 s | how often a roaming gang may appear at all — see [patrols.md](patrols.md), "Pacing" |
| `PatrolCampClearance` | `mercenaries_patrols_live.lua` | 350 m | no roaming gang spawns this close to the camp |
| `FollowWatchEvery` | `mercenaries_formation_handler.lua` | 4 s | continuous stall watch; one `GetWorldPos` per merc per sample |
| `TowerMaxCount` | `mercenaries_tower.lua` | 999 | ~8 always-rendered meshes per tower — effectively uncapped |
| `RaidEnabled` | `mercenaries_raids.lua` | true | a camp raid every ~2 in-game days |
| `SchedEnabled` | `mercenaries_scheduler.lua` | true | `merc_sched 0` falls back to the legacy timers |
| `ProfEnabled` | `mercenaries_profiler.lua` | **false** | profiling wraps ~74 functions; opt-in only |

## Measuring

**Use the release build.** `PackageModDev.bat` launches `KCD2Mod`, a non-PGO DLL config **and an
older game version** (1.5.5 vs 1.5.6), which is laggy with no mods at all. Its timings are
meaningless. It is still the only build that prints engine `[Error]` lines, so it is the right tool
for finding errors and the wrong one for finding cost.

| command | what it does |
|---|---|
| `merc_prof 1` | enable profiling (off by default) and instrument in one step |
| `merc_prof_timer` | **run first** — if the smallest delta reads 0.000ms the clock is quantised and nothing below is trustworthy |
| `merc_prof_report` / `merc_prof_total` | dump by worst spike / by total time |
| `merc_prof_hitch <ms>` | lower the threshold if nothing trips |
| `merc_gc 0` / `1` | stop/restart Lua GC — the A/B for a GC-driven stutter |
| `merc_perf_verify` | proves the own-soul hash set answers the same as the old 65-entry scan |
| `merc_sched_status` | scheduler slots, rates, per-slot errors |
| `merc_patrols_status` | live patrol men / gangs / corpses against the caps |

Reading the output:

- **`STALL … Ran on the previous tick:`** — if it names slots, the mod is implicated; if it says
  *"NOTHING - the stall is outside this mod"*, it is engine-side and no Lua tuning will help. Slots
  whose period is a single tick are excluded, because they fire every tick regardless of cause.
- **`HITCH <name> … (Nms since last of THIS, Mms since any)`** — the first figure is the real period
  for that source. Periods are per-name; one shared timestamp is noise when sources interleave.
- **`~bt hooks per window`** — aggregate ms across all per-NPC behaviour-tree hooks per 250ms. Many
  individually-cheap calls landing in one frame are invisible to any per-call threshold.
- **`~mastertick gap` / `~heartbeat gap`** — gauges, not durations; their normal value is their own
  schedule. `Script.SetTimerForFunction` will not go below roughly **100ms**.
- Rows marked `(nest)` ran inside another timed function; their time is already in the caller's.

**Check the save's mod set.** `kcd.log` prints `Mods used while saving (N)` before the level load. A
save made with 35 mods, loaded against 1, carries state referencing 34 absent ones and invalidates
any with/without comparison run on it.

## The 2026-08 lag hunt: it was corrupted game files

**Root cause: verifying the game files through Steam fixed it completely.** Nothing in this
mod, and no code change, was involved. Recorded in full because the hunt cost days and the
same trap is easy to fall into again.

What made it so expensive to find:

- **The fault was intermittent per launch.** The same build was laggy on one run and smooth
  on the next. Every single-run A/B was therefore a coin flip, and two "confirmed culprits"
  were produced that way and acted on: a bisect fingering roaming patrols, and a
  `GetActions` A/B fingering `mercenaries_lookatinteraction.lua`. Both were noise.
- **It survived removing the mod entirely**, which should have ended the investigation far
  sooner than it did.
- **It was location-correlated, not content-correlated.** A clean vanilla save with no mods
  lagged around Kuttenberg and was fine in open countryside — which reads as "the mod is
  heavy in cities" and is really "the install is damaged".

**The rules that would have found it in an hour:**

1. If the symptom persists with the mod uninstalled, stop debugging the mod.
2. Never accept a single-launch A/B for an intermittent fault. Five runs per side minimum.
3. Verify game file integrity before a deep performance hunt. It is two minutes.
4. Check `kcd.log`'s `Extended build info:` line. Two installs exist on the dev machine:
   release `1.5.6` (`Win64MasterMasterSteamPGO`, `PackageMod.bat`) and the `KCD2Mod` dev
   install `1.5.5` **DEBUG PURE CLIENT** (`PackageModDev.bat`), which is laggy with no mods
   at all. Mixing launchers alone produces "sometimes laggy, sometimes not".

Genuine per-session variables to rule out before suspecting mod code: the launcher above;
`road_encounter` (77 `RandomEventVariant` nodes, 32 on fast travel); a save written with far
more mods than are installed (the `.whs` header is plain XML and lists them); and cold shader
cache (kcd.log showed 16,268 PSOs precached in ~1.5s on a load).

The one lasting good from the hunt is the density work below — found by measurement, kept on
its own merits, not because it fixed this.

## Costs that scale with NPC DENSITY, not squad size

A separate axis from everything else in this file. **This did not cause the 2026-08 lag** —
that was corrupted game files, see above — but it is a real cost found while looking, and it
is kept on its own merits.

The axis: a mod cost proportional to *how many vanilla NPCs are near the player* is silent in
a field and expensive in a market square, however few mercs are hired. Worth knowing about
because it is the one profile that never shows up in a squad-size test.

`UpdateEnemyCache` runs every 300ms (600ms when idle) and passes **every** NPC the box query
returns — not just hostiles — through `IsValidEnemy`. So per nearby NPC, three times a
second, the mod paid:

| was | now |
|---|---|
| `if self.BanditCampSuppressed then` — a **method reference**, always truthy, so the block ran for every candidate in every session even with no bandit camp anywhere | gated on `BanditCampAnyUnalerted()`: two table lookups, no allocation |
| `BanditCampSlots()` built a fresh 2-element table per candidate | slots walked directly in `BanditCampSuppressed` |
| `pcall(function() ... end)` in `IsValidEnemy` (x2) and in `IsAliveAndWell` — a fresh closure per candidate | `pcall(method, obj, arg)` — no closure |
| shared scan radius **latched** to `StaticArcherRange` (90m) forever after the first tower archer, via `PerfWantRadius`, cleared only by `PerfReset` on load | `PerfScanNpcs` recomputes it per pass; 90m only while static archers exist |

That last one is the big multiplier: a 90m circle is ~25x the area of the default 18m, so one
tower archer placed once turned every later crowd into a hundreds-of-NPC sweep — with the
player nowhere near the tower, and after the archer was gone.

Why allocations matter here specifically: Lua's collector runs **on the main thread**. A
per-NPC-per-tick garbage stream is invisible with three NPCs around and becomes a periodic
main-thread pause in a crowd — which reads exactly like "laggy about once a second".

**Still known, not yet changed:** `IsValidEnemy` re-fetches both `ent:GetPos()` and
`distanceRefEnt:GetPos()` per candidate although `UpdateEnemyCache` already holds both
(`playerPos`, and `e.pos` from the shared scan). Two scriptbind crossings per NPC per tick.
Fixing it means a signature change across every caller, so it is left deliberately.

Also unconsolidated: static archers in `hostile`/`mod_enemies` mode and the quartermaster each
run their **own** box query (~90m and 30m) once a second, bypassing the shared scan and
repeating the same per-NPC validation.

## Fast travel: the follow watch against a frozen world

A fast travel spends its whole duration on the map screen, and there the behaviour trees stop
running. The follow watch reads "nobody moved and nobody stamped a slot claim" as a squad-wide
stall and re-fires, escalates and rebuilds against it, on every sample, for the whole journey.
One session measured 3,163 follow re-fires, 527 escalations and 59 `MakeFormation` rebuilds,
with 131 of the 133 sampling passes inside the map screen and 2 outside it. Each escalation is
a 10-ray safe-position sweep plus a `SetPos`, so this is engine time on the main thread while
the game is streaming a route across the map.

Fixed by two stand-downs in `DismountVerify`, keyed on a behaviour-tree liveness heartbeat and
on the share of the squad indicted in one pass. Full account in
[formations.md](formations.md), "The watch must never run against a frozen world".

| tunable | file | default |
|---|---|---|
| `FollowWatchBtStaleSecs` | `mercenaries_formation_handler.lua` | 2.5 s with no `MercIsIdle` call = trees frozen |
| `FollowWatchSystemicFrac` / `FollowWatchSystemicMin` | same | 0.5 of the squad / 5 men flagged at once = the world, not the men |

## State that outlives the level

A separate failure mode from anything above, and the one that made the lag reports look
undebuggable: **the mod's plain Lua tables survive a save load; the things they describe do
not.** Behaviour trees, spawned entities and sieges all die with the level. The tables that
remember them are untouched. Where such a table gates a *radius* or a *cvar*, a fresh load
then pays a battle's costs with no battle on — for the rest of the session, cured only by
restarting the game.

That profile explains every property of the reports at once: intermittent, unreproducible,
worse after save-scumming, immune to bisecting the mod by file (it is cross-module state, not
one module), and location-correlated (a wide sweep is free in a field and expensive in
Kuttenberg).

Four were found and fixed. Each releases on load and re-establishes itself within a tick if it
is genuinely still warranted, so the reset can be unconditional:

| state | held by | what it cost | released by |
|---|---|---|---|
| `StaticArchers` non-empty | nothing prunes it, ever | shared NPC scan pinned at 90 m — ~25× the area of the 18 m default — anywhere, for ever, after one tower was placed once | `StaticArcherWidenRadius` asks the archers themselves and drops records whose entity is gone |
| `MercTargetOf` orphan | `combat_melee`'s OnFail never ran (tree evicted, or the save was loaded mid-fight) | one entry holds `EnemyAlerted` true, pinning the sweep at 60 m | `TargetingOnLoad`; plus `PruneCombatClaims` evicts a claim older than `MercClaimGraceSecs` whose holder is not in combat |
| `EnemyAlertRadius` = 160, `SiegePeace` | the Raborsch siege, restored only on the strike path | the widest sweep in the mod, running in a city | `RaborschOnLoad` |
| `LodBoostPinned` | same siege, same single release path | ~22 global cvars re-pushed every 300 ms, `e_ViewDistRatio` 50 → 200 | `LodBoostOnLoad`, plus `LodBoostTick` unpinning a siege pin with no siege standing |

**The scan radius is the number to look at.** `merc_dev` then `merc_perf_status` prints it live
along with how many NPCs came back: `npcScan=N npc(s) r=R`. In town with the squad out, `r`
should read 18. Anything else is one of the rows above.

**Why `e_ViewDistRatio` matters more in Kuttenberg than anywhere else.** `LodBoostReassert`
exists to defeat `CVarOverride.xml`, and the file it is defeating is
`performanceDemandingArea.cfg` — which clamps exactly these cvars, for exactly these places.
Holding that clamp open is defensible for the duration of a siege and indefensible the rest of
the time, which is what the pin check now enforces.

## The 2026-08-27 profile: measured, and not the Lua

First release-build profile of the stutter. `window=32.9s`, squad of 8, Kuttenberg.

```
~mastertick gap      198 calls   avg 104.818ms   max 183.00   (scheduled 100ms)
~heartbeat gap        77 calls   avg 267.286ms   max 340.01   (scheduled 250ms)
mastertick gaps over 1.3x schedule: 26 of 198
```

**The stutter is in the data.** 198 gaps covering 20.75s of ticking carry 954ms of excess over
schedule, and 26 of them are more than 30% late. That is ~1.25 late ticks per second at ~37ms
of lost main thread each, worst case 83ms — "light stutters every second or so", quantified.
The independent 250ms heartbeat sees the same lateness, so it is the main thread, not the
scheduler.

**None of it is this mod's Lua.** The largest single row is `slot:monitor` at 3.01ms max.
`~bt hooks per window` peaks at 4ms. **Zero hitches** at a 6ms threshold, across every row.
Total mod time is ~1.2% of the window. GC is not it either: the heap is flat (129,014KB →
129,108KB across two reports) while 7.4MB was allocated and reclaimed.

Two things that look alarming in that log and are not: the 9,383ms / 9,545ms `STALL` lines in
the second report are the pause menu and the console being open — `Script.SetTimerForFunction`
does not fire while the game is paused, so both gauges record the whole pause as one gap. The
stall detector cannot currently tell a pause from a freeze.

### The one anomaly, and how it was visible

| chain | firings in the window | due | verdict |
|---|---|---|---|
| `timer.LootSweepTick` | 20 | 20 | exact |
| `timer.LivePatrolTick` | 63 | ~7 | **~9 chains** |

A controlled comparison inside a single log: the session had exactly one load, one
`roaming patrols armed` line and no watchdog re-arm, and `LootSweepTick` — the one chain that
had just been given a slot identity — was dead on schedule in the same window while the patrol
tick fired nine times too often.

So **duplicate timer chains are real, and an arming latch does not prevent them.** That
settles the assumption in `mercenaries_scheduler.lua` the other way from how it was written.

Why it matters more than its 8ms of Lua suggests: an extra chain does not make the tick
slower, it makes it *more frequent* — another pass over the route set, and another chance per
period to spawn a gang. A gang spawn is NPC creation, ground raycasts and character assembly:
engine time, on the main thread, that a Lua profiler cannot see. That is the shape of a cost
that reports as "the stall is outside this mod".

`LivePatrolTick` now uses the same two-slot device as `LootSweepArm`, and the profile report
prints observed period against armed period for every standalone chain, naming a duplicate
outright — so this class of fault is visible in one line from now on instead of by arithmetic.

## The mod is not the stutter — measured, 2026-08-27

Four release-build sessions, ~15 profile windows. The metric is
`mastertick gaps over 1.3x schedule`: a 100ms timer arriving more than 130ms late, i.e. a
frame that lost 30ms or more. It tracks the reported "light stutter about once a second".

| condition | ratio |
|---|---|
| 8 mercs, patrols on, 5 duplicate patrol chains | 15.5 – 18.7% |
| **0 mercs** (slots gated off — no `slot:mercpos` row at all), patrols on | **16.4 – 17.6%** |
| duplicate chains fixed, 8 mercs | 16.9% |
| **patrols OFF** | **20.4 – 25.8%** |

Three independent negatives:

- **Squad size does nothing.** Eight men and none give the same ratio, and the average tick
  gap is flat at ~106ms against 100ms armed either way. The whole per-merc axis — enemy
  scans, BT polls, render pinning, formation, target claims — is not it.
- **Fixing the duplicate patrol/raid chains did nothing** to the ratio (17.7% → 16.9%),
  though it did cut the NPC population, which was a real win on its own merits.
- **Disabling patrols made it WORSE** (20–26% against 15–19%). Turning off the mod's largest
  subsystem cannot make the mod's cost go up. The metric is dominated by something that
  varies between sessions and is not this mod.

In every one of those windows the mod's Lua measured **~0.5% of wall time** with, at most,
two or three hitches over 6ms in a two-minute session.

This is the same conclusion the 2026-08 hunt reached and it should not be re-litigated a
third time. The rules at the top of that section stand, and one is worth restating: **the
symptom persists with the mod uninstalled** — which the users who fixed theirs by verifying
files, updating drivers and re-saving without mods independently confirm.

### If it is chased again, use an engine profiler

A Lua profiler cannot see engine frame time, which is where every measurement above says the
cost is. These cvars exist in `WHGame.dll` (release build, 1.5.6) and are the right instrument:

| cvar | use |
|---|---|
| `r_DisplayInfo` | on-screen frame breakdown |
| `r_Stats` | renderer statistics |
| `profile` | engine profiler |
| `sys_enable_budgetmonitoring` | budget overruns |

### A note on the duplicate-chain heuristic

It now needs 8 samples before flagging a row. A 20s chain in a 30s window fires once or
twice, so a single warm-up firing read as "2.0x TOO OFTEN" for `RaidTick` while the same
chain measured a clean 20101ms over a long window. The check is for standing rates.

## Why a subsystem may not own its own timer

Second profile, 111.3s window, with the observed-vs-armed column added:

```
timer.LivePatrolBeat  181 calls   every 615ms, armed at 3000   <-- 4.9x TOO OFTEN
timer.RaidTick         17 calls   every 6545ms, armed at 20000 <-- 3.1x TOO OFTEN
timer.LootSweepTick   109 calls   (exact)
~mastertick gap      1028 calls   avg 108.168ms, armed at 100  (exact)
mastertick gaps over 1.3x schedule: 182 of 1028
```

Per chain the interval is right; there are simply five patrol chains and three raid chains.
The slot device did its job - the log shows nine `roaming patrols armed` lines alternating
slot 0/1, so four chains on the dead slot retired and five on the live one survived, which is
the 4.9x exactly - but it cannot help when `LivePatrolStart` is called **nine times inside the
first two seconds of a single load**, because each call flips the slot.

Two lessons, one of them about the log rather than the code:

- **CryEngine collapses consecutive identical log lines.** The previous session showed *one*
  `roaming patrols armed` line for what must have been nine arms. Putting the slot number in
  the message made the lines distinct and the burst appeared. A repeated event that logs an
  unchanging string is invisible here; give any such line a varying field.
- **A private self-arming chain has no way to count itself.** Both call sites of
  `LivePatrolStart` can each run once per load, the watchdog logs when it re-arms and did not,
  and `OnGameplayStarted` ran once (one `master tick armed`, epoch 1) - yet there were nine
  arms. Rather than keep hunting the caller, the cadence moved to something that cannot be
  duplicated without duplicating the master tick, which is measured correct and already has a
  watchdog.

`patrols` and `raids` are now scheduler slots. The private chains survive only for
`merc_sched 0`, and the watchdog's strike-3 fallback hands them back explicitly.

This is worth far more than the 29ms of patrol Lua it removes. Five chains is five times the
chances per period to spawn a **gang**, and a gang spawn is NPC creation, ground raycasts and
character assembly. It also multiplies the standing NPC population, and per another KCD2
combat modder *"one of the biggest lag spikes is changing targets"* - which scales with how
many hostiles are alive near the player. All of that is main-thread engine time that reports,
correctly, as "the stall is outside this mod".

### What the same profile still says about the Lua

Unchanged and now on a longer window: mod Lua is ~0.5% of 111.3s, and the whole session
produced **three** hitches over 6ms - `mon.MonitorInventory` at 36.01ms once,
`bt.WBCombatPoll` at 8.00ms, `bt.PickCombatTarget` at 6.01ms. GC is healthy (36 collections,
26.2MB freed against 20.1MB allocated, heap shrinking). Meanwhile 182 of 1028 master ticks
were more than 30% late. The stutter is real and it is not in this mod's script.

## Chains that cannot be counted

`Script.SetTimerForFunction` chains are *believed* to die with the level. That belief was never
measured, and its only stated evidence was circular — `LootSweepLoop` re-armed itself with no
guard at either end, so "it does not double" was an observation nobody was in a position to
make. A time-based duplicate guard is not the answer either: one was tried on the master tick
and retired the only chain there was, because after a hitch the engine fires queued timers back
to back.

The device that does work is to carry the generation in the **function name**. Consecutive
loads alternate between two entry points (`LootSweepLoop0` / `LootSweepLoop1`,
`GearKeepTick0` / `GearKeepTick1`) and each retires the moment it is not the current slot, so a
chain from the previous load stops on its next firing whether or not the engine kept it. Any
new self-arming chain should do the same rather than inherit the assumption.

## Two costs that were not state

- **The custom-uniform keep pass** re-equipped the whole armour pattern on four mercs **every
  second, for ever**, because there is no "is he wearing it" query and it re-equips blind.
  `EquipInventoryItem` on a KCD2 character is attachment work. Now 5 s, which still fully
  re-asserts a twenty-man company about every 25 seconds.
- **A patrol gang is spawned entirely within one tick**, and each of the men behind the lead ran
  an unbudgeted `FindValidGround` — up to 40 candidates at up to 9 rays each. A 16-man gang
  could therefore ask for thousands of synchronous raycasts before the frame ended. That is the
  hitch behind "enemies appeared right in front of me while I was riding at full speed".
  `PatrolGroundTries` bounds the followers at 6; the lead man keeps the full search.

## FINAL VERDICT — 2026-08-27, RESOLVED: the Windows power plan

**Root cause: the machine's power plan was "Power saver."** On the Threadripper PRO 5975WX
(32 cores, 4 CCDs) that parks cores and clamps clocks; the game's main thread bounced across
half-asleep cores, and because parking decisions differ per boot the severity varied by
session — the "yesterday smooth, today broken" that no game-side change could ever affect.
Switching to High performance (`powercfg /setactive 8c5e7fda-...`) fixed it live, standing in
Kuttenberg. Secondary finding, still open: RAM configured at 2133 MT/s (DOCP/XMP off) — crowd
simulation is memory-latency-bound, so enabling the rated profile should recover more.

The experiment that cornered it: a save from a MOD-FREE playthrough (playline1 — verified
byte-level: zero saver tags, zero merc entities, zero Kleinkrieg state, no Local Hero perk),
loaded on a vanilla install, lagged identically in Kuttenberg — ~27fps at LOWEST settings,
CPU-bound on an RTX 5080. That correctly exonerated the mod; the outer cause then had to be
machine state, and a live audit found it (after ruling out WHEA/PCIe errors, TDRs, a 16.8GB
degenerate NVIDIA DXCache — cleared, no effect — drivers, and resident GPU compute apps).

**Support checklist for any future "the mod lags" report, in order:**
1. `powercfg /getactivescheme` — anything but High performance/Balanced on a desktop is the
   suspect. Free, instant, applies live.
2. RAM at rated speed? (Task Manager → Performance → Memory, or BIOS.)
3. Mod-free save + vanilla install + same spot + fps counter. Only if THAT is smooth does
   mod code enter the conversation.
4. The frame histogram (`merc_dev`, `merc_prof 1`, play, `merc_prof_report`) — judge on
   frame buckets, never on timer lateness.

The "worked before this update" memory dates from an older game build; the game moved to
1.5.6 (build June 2026) and Steam forums record per-patch performance regressions (1.2, 1.3,
and a Kuttenberg-specific stutter tied to the Local Hero perk — which the MAIN playthrough's
save474 carries and playline1 never did; a Lethean Water respec is the community fix).

What this makes of the user reports: "removed the mod and it still lags" was the truth all
along, for the same reason. The mod's real cost rides ON TOP of a Kuttenberg baseline that is
already marginal, so it can tip a borderline machine — which the fixes below shrank measurably
(long-frame events 2.3/sec -> 0.7/sec in the same test spot) — but the baseline is the game's.

Rules this hunt adds to the ones above:
1. The FIRST test for any "mod lag" report is a mod-free save on a vanilla install at the
   same spot. Four days of profiling never beat that one number.
2. A timer-lateness metric is frame-rate quantisation, not a stutter metric. Use the
   profiler's frame histogram (ProfFrameSample) - it measures frames.
3. Save-file name-string counts are NOT entity counts (50 strings = 9 entities); only
   GetEntitiesByClass at runtime is authoritative.

## THE GRID — the suite across three hardware tiers — 2026-08-28 (overnight)

Full 12-scenario suite (tools/autobench.ps1, `-Cores N` restricts affinity), field save,
observer hovering 14m up looking down, devmode god. fps / hidden-flips per cell:

| scenario | full cores | 8 cores | 2 cores |
|---|---|---|---|
| baseline | 139.1 / 0 | 149.6 / 0 | 108.1 / 0 |
| army50 (50 mercs) | 114.1 / 0 | 121.6 / 0 | 62.6 / 0 |
| formations (cycling shapes) | 157.4 / 0 | 158.6 / 0 | 102.7 / 0 |
| camp + raid + breakcamp | ~150 / 0 | ~150 / 0-4 | ~100 / 0 |
| bigbattle (35 hostiles) | 83.8 / 0 | 73.7 / 0 | 41.1 / 0, nothing past 33ms |
| aftermath | 110.0 / 0 | 94.9 / 0 | 55.4 / 0 |
| patrol (16-man gang) | 89.8 / 0 | 75.0 / 0 | 39.8 / 0 |
| raborsch (siege, ~29-man company) | 133.6 / 0 | 100.0 / 0 | 54.4 / 0 |
| boostcycle (forced pin/unpin) | 144.8 / 0 | 137.9 / 0 | 71.3 / 0 |

Read against the pre-fix era: the same class of 2-core siege/battle measured 10-17fps by hand,
and the pre-fix bench measured 64/86/182 hidden-flips. After the cumulative work (cloth trio
defaults, 600ms target polls, behaviour LOD, 4-candidate scans, follower-churn timeboxes,
corpse freeze, population-aware LOD boost + spawn priming): zero flips at every tier, and the
2-core battle holds 41fps with no frame over 33ms.

Caveats, honestly: the field save is not Kuttenberg (city NPC density is the one axis this
save cannot exercise - make a Kuttenberg save the bench target and adjust -DownsToSave to
cover it), and the suite's siege scaled to the post-battle company (~29), smaller than the
50-man manual benches. The 4 breakcamp flips at 8 cores are camp-teardown transients, not
reproduced at other tiers - watch, don't chase.

Rerun everything: `powershell -ExecutionPolicy Bypass -File toolsutobench.ps1 [-Cores N]`.
In game: F9 = bench, F10 = bench + quit (harness mode). This suite is the regression harness
for every future release: any change that reintroduces pop-in or a frame-time tail shows up
as a changed cell.

## POP-IN: root-caused and fixed by the automated bench — 2026-08-28

"They pop in and out of existence" is now a measured, attributed, fixed defect - found by the
closed-loop bench (tools/autobench.ps1 + mercenaries_bench.lua: launches the game, navigates
the menu with verified scancode input, loads the field save, runs a scripted scenario chain,
and polls every tracked NPC 4x/sec for IsHidden / IsSlotCharacter(0) / GetViewDistRatio,
logging every transition with distance and classification).

The measurement (run 2 of the bench, 50 mercs + 35 enemies, full cores):

| scenario | fps | hidden flips | char flips | vdr flips |
|---|---|---|---|---|
| baseline | 104.5 | 0 | 0 | 0 |
| army50 | 84.0 | 0 | 0 | 0 |
| bigbattle | 37.2 | **64** | 0 | 0 |
| aftermath | 25.6 | **86** | 0 | 0 |
| boostcycle (pin/unpin every 10s) | 25.6 | **182** | 0 | 0 |

**Every flip was a HIDDEN flip** - not skin streaming (char), not view distance (vdr). The
engine HIDES whatever exceeds the AI-LOD budgets, and the flips cluster on LOD-boost
transitions. Mechanism: the boost raises WH_AI_LOD_MaxCountDetail/MaxCountLOD (70/400 ->
260/600) for battles, but its OFF decision keyed on CachedEnemies - which drains the moment
fighting stops, while ~100 NPCs and corpses still stand. Budgets collapse under the standing
population -> the engine hides the overflow in front of the player. Every arm/disarm is a
hide/unhide wave; battle START flipped too (the gap before CachedEnemies fills and arms it).

The fix (mercenaries_lodboost.lua, mercenaries_spawning.lua):
- **The budgets may never collapse below the standing population.** LodBoostTick now counts
  the real population (one 120m box query, run only while the boost is up or the cheap crowd
  estimate is near arming) and refuses to drop the boost until population < LodBoostPopRelease
  (50), however long the enemy cache has been empty.
- ~~**Population arms the boost by itself** at LodBoostPopThreshold (65) - no combat
  required.~~ **Reverted — see "The AI-LOD cvar boost must never arm in a town" below.**
- **Spawn bursts arm it BEFORE the men exist**: SpawnEnemyGroup calls LodBoostPrime(n) so the
  budgets are already up when a 35-man encounter appears, closing the battle-start gap.

Verification criterion for the suite: bigbattle/aftermath hidden-flips ~0 against the 64/86
baseline.

### The AI-LOD cvar boost must never arm in a town

`LodBoostPopThreshold` counted **every NPC in a 120 m box**, and armed the boost on that count
alone. A market square in Kuttenberg clears 65 of them with nobody fighting anybody, so simply
walking into town:

* raised `e_ViewDistRatio` to 200 over the 50 the city's own `performanceDemandingArea.cfg`
  had just set, and `e_ViewDistRatioCustom` to 200 over 60;
* pinned `e_CharRenderLodMin` / `e_CharLodMin` to 0 — **every** character held at its highest
  detail mesh regardless of distance — and `e_LodFaceAreaTargetSizeCharacterWH` 5× below stock;
* opened `WH_AI_LOD_MaxCountDetail` to 260 and `MaxDetailDistance` to 250, so up to 260 NPCs
  ran full AI simulation;
* and re-pushed all of it every 300 ms, *deliberately* fighting `CVarOverride` — whose dense
  areas are cities — for as long as the player stayed. `LodBoostPopRelease` (50) then held it
  there, because a town never falls below 50 either.

That is the user report **"very choppy in towns, despite my fps counter stating 120-144
frames, no matter the quality settings"**. Both halves of that sentence are explained: it is
not a framerate a counter shows (it is frame *pacing*, against an engine being argued with
three times a second), and the quality settings genuinely do not matter, because the mod is
overriding them.

**Arming and releasing were never the same question.** Only the release one was ever about how
many people are about — "the budgets must never collapse below the standing population" is a
statement about *dropping* the boost, and that clause already lives in the `elseif` branch.
The arm clause was pure crowd-density, and it is gone:

```lua
if crowd >= self.LodBoostMinCrowd then          -- was: ... or pop >= LodBoostPopThreshold
```

`crowd` is `MercCount + #CachedEnemies` with `LodBoostRequireFoes`, so it is zero without a
fight, whatever the town holds. `LodBoostPopThreshold` is deleted; `LodBoostPopRelease` stays
and does its real job.

**The release hold had the same hole through a different door.** `LodBoostPrime` arms the
boost before a spawn burst of 10+ NPCs, which in a town is a town-watch muster — a real
fight, so arming is right. But the hold clause *restamped* `_lodLastFoeAt` every tick that
population was above the release line, so once armed in a town it could never come down.
The hold no longer restamps and is bounded by `LodBoostPopHoldMax` (240 s with no foes in
the cache) — chosen to clear `PatrolCorpseSecs` (180 s) with margin, since covering a
battle's standing bodies is the whole point of the hold. It is a bound on the pathological
case, not a tuning.

Second win, free: `pop` is now computed only while the boost is already up, since the OFF
decision is its sole consumer. A peaceful town no longer runs a 120 m NPC box query three
times a second either.

**Diagnosing it.** `merc_dev` then `merc_lod_status` in a quiet town: the boost must read
inactive. If it does not, something armed it — check `LodBoostPinned` (the siege pin) and
`CachedEnemies` before assuming density.

## Behaviour LOD for the squad — 2026-08-28

The one lever in the mod that scales DOWN with squad size instead of up, and the answer to
"what is left once the cvar space is exhausted" (73 trials over 23 cvars, controlled, found
nothing - see below).

Every merc ran the full target-acquisition pass on every poll whether or not the world
contained anything to acquire: `ScanForEnemies`, a `For` over up to 8 candidates each doing an
engine `GetTarget`, `PickCombatTarget`, plus an unconditional `GetTarget` on himself. Fifty men
standing in a peaceful market paid all of it, forever.

`MercCheapMode` (mercenaries_ai_modules.lua) publishes `$cheapMode` per merc; the scheduler
counts skipped polls in `$cheapSkip` and lets a FULL pass through every `cheapEvery+1` (4th).
Both the acquisition block and the self-`GetTarget` ride that one counter.

**The gate is squad-wide and pessimistic, not per-merc distance.** Distance is the obvious
proxy and the wrong one - the man forty metres back is exactly who gets jumped first, and a
distance gate blinds him. What makes the pass pointless is that there is nothing to find, and
the mod already computes that authoritatively every 300ms: `ScanForEnemies` READS
`CachedEnemies`/`MaybeEnemies`, so with both empty the whole block is provably a no-op - the
array comes back empty, the `For` never iterates, `PickCombatTarget` has nothing to pick.
Any of alerted / cached enemies / maybe-enemies / focus target / in combat / holding a claim /
forced target takes the whole squad back to full rate.

The one call that genuinely needed care is the self-`GetTarget`: it is how the mod learns a man
is being attacked by something the caches never saw (a town guard turning on him). It is not
gated on the caches alone - it rides the same skip counter, so worst case he notices ~2.4s
late rather than never, and any hit that lands sets `inCombat`, which clears cheapMode outright.

`merc_btlod_off` / `_on` / `_status` for A/B. **Expect this to do nothing in a battle** - in
combat cheapMode is false by construction. It targets the reported scenario (mercs in a town),
not Raborsch.

## Equipment hygiene — what was safe to cut, and what was not — 2026-08-28

Brief was "hygiene, do not reduce visual quality", so the bar was: only remove what provably
cannot render.

**Done.** 24 entries out of `clothing_preset__mercenaries.xml`, zero visual change:
- 2 EXACT duplicate `<Guid>` entries (same item listed twice in one preset - a no-op).
- 22 uses of 7 DEAD GUIDs that no item table defines. Verified against the game's own
  `Data/Tables.pak`, not just the reference dump, so they are not DLC items my extract was
  missing. They resolve to nothing, so they cannot draw. No preset was left empty.
  (590 presets, 6805 -> 6781 items.)

**NOT done, deliberately - the 378 "same-slot collisions" are not safe to cut.** The sweep
reported 60.6% of merc presets carrying two items on one slot vs 9.5% in vanilla, and that
replicates (352/590 here). But the slot map in `mercenaries_gear_data.lua` is COARSE: the
generator folds several ArmorTypes into one slot id (Coat/Waffenrock/Habit all -> 7). The
engine's real rule is `armor_archetype2body_subpart.is_exclusive` per archetype+subpart, so
two items sharing a coarse slot may be legitimately layered. Cutting on the coarse signal
would strip visible pieces - exactly what the brief forbids. Resolving this properly means
modelling archetype -> body_layer/body_subpart exclusivity; worth doing, not worth guessing.

**NOT done - the double-dress, because the risk is documented.** Every merc IS dressed twice:
the Storm rule in `libs/Storm/equipment/mercenariesequipment.xml` (108 rules) applies a vanilla
`<ClothingPresetRef>` + `<WeaponPresetRef>` at spawn, and `SpawnMercenary` immediately applies
the mod's own preset over it. A whole wasted character assembly per spawn - real, and it would
help the "lag when I hire" reports. But `reference_equipping_npcs` records that ORDER IS
EVERYTHING here: a vanilla clothing preset must land before any per-piece
`EquipInventoryItem` or nothing equips at all. The mod's own `EquipMercenary` should satisfy
that, but "should" is not good enough for a change that silently un-dresses the whole company,
and it is spawn-burst cost rather than the sustained per-frame cost. Needs a deliberate test,
not a drive-by edit.

## Round 2: what is left after the cloth win — 2026-08-28

A second 13-agent sweep across the areas the cvar tuner never covers (animation/skinning, job
threading, per-character asset layers, ragdoll physics, AI perception) plus a fresh
bodyguards-vs-mod comparison. Two things shipped straight away; the rest is a ranked queue.

**Shipped: target-poll rate halved.** `mercenary_scheduler.xml` and `archer_scheduler.xml` ran
their acquisition arm - including an unconditional engine `<GetTarget>` - on a 300ms poll. The
bodyguards reference mod runs the same node at 1s +-300ms and carries companions with no
reported cost. At 50 mercs, 300ms is ~167 engine calls/sec scaling with squad size, paid
whether or not anything is happening. Now 600ms +-240ms (2 polls per file).

**The trap in that change**, and why it is not a one-number edit: `idleTicks` is counted in
POLLS, not seconds, and the file's own comment says the thresholds are scaled to the rate
(55 ticks ~ 16s). Halving the rate without halving the counts silently doubles every idle
timeout - the sheathe-weapon, drop-claim and re-fire-follow behaviours. Thresholds moved 66->33
and 55->27 in both files, so they still mean ~20s and ~16s.

**Shipped: corpse ragdolls freeze after 5s.** A wiped gang leaves up to 12 ragdolls - 20-30
part articulated bodies, touching each other, which is CryPhysics' never-settles worst case -
lingering for `PatrolCorpseSecs` (180s) exactly where the player just fought. They now get
`AwakePhysics(0)` + `EnablePhysics(0)` once they have finished falling. Looting reads SOUL
state (`LootCaptureBodies`/`IsCorpse`), not physics, so they stay lootable and the sweep still
clears them on the same schedule. `EnablePhysics(0)` is the call the tower hold-test already
proved works on a live entity here.

### Queue, in order (all verified to exist in the DLL, none benched)

| lever | why | how |
|---|---|---|
| `sys_job_system_max_worker` | help text: *"Defaults to 16 threads on PC... Set to 0 to create as many threads as cores are available"*. Absent from every cfg, so it is at the compiled default. 16 job workers + main + render + physics + 2 anim threads timeslicing 2 cores is exactly the 32-cores-fine / 2-cores-broken shape | set 0, **relaunch** - it is read at System::Init and cannot be tuned live |
| `wh_ca_AnimationComputationJobBatchSize` | *"Sets the size of job batches that are used for animation calculations"* - animation LOD is a DIFFERENT system from the mesh LOD already benched flat | add to TweakDefs, let `merc_opt` bench it |
| `ca_UseJointMasking` | *"Use Joint Masking to speed up motion decoding"* - CPU skeleton work, not render | read current value first; if already 1 there is no win |
| `ca_DrawAttachmentsMergedForShadows` | one shadow submission per character instead of one per worn piece | check for shadow seams at helmet/pauldron |
| clothing piece count | mercs wear 15-43% more pieces than vanilla's own tier-matched presets; weak-tier mercs already exceed vanilla STRONG-tier. Every piece is a skin attachment to skin per frame | trim the presets - fixes per-character cost WITHOUT cutting NPC count |

**Do not automate:** `wh_ai_perception_perceived_states_parallel_update` and
`wh_ai_hearing_parallelUpdate` are forced to 0 by the shipped `system.cfg:210` with Warhorse's
own comment `-- this crashes too much >:[[[`. Possibly a real win, absolutely not something to
put inside an unattended multi-trial descent, and not to ship silently even if it benches well.

## SHIPPED: the simulation defaults, found by auto-tune — 2026-08-28

`merc_opt` runs a coordinate descent over the 18-cvar tweak bench, measuring real frames
(`System.GetFrameID`) in 5s windows with a 1s settle, and only accepting a step that beats a
visual-cost-weighted threshold. Run in the siege of Raborsch on a CPU restricted to two cores:

```
baseline 21.6 fps  ->  29.3 fps   (+35.7%)   46 trials, 3 passes
  wh_ca_ClothBudgetMaxFramesToSkip   4 -> 20     (+7.0%, +2.8%, +13.7% over three steps)
  wh_ca_PendulumMaxLodToSimulate     2 -> 1      (+3.0%)
  ca_ClothBypassSimulation           0 -> 1      (+5.4%)
```

**Every winner is a SIMULATION cut. Not one detail cut survived.** View distance, the
character LOD floor, uberlod swap distance, outfit-unload hysteresis, attachment culling and
item view distance were each tried in both directions across three passes and came back
negative or inside noise. That closes the render-side question the whole 2.1 investigation
had been circling, and it is why `merc_render_lod 200` "worked": it was buying a simulation
cut via the LOD gate (`wh_ca_PendulumMaxLodToSimulate`), and paying for it in ugliness.

Shipped in `mod.cfg` - the documented place for persistent cvars, and the one that survives
CVarOverride re-application. `mod.cfg` does the actual work; the Lua side only backs it up:

| when | what |
|---|---|
| launch | `mod.cfg` sets all three (engine, free) |
| per load | `PerfDefaultsApply` once - a level load re-applies that level's cvar context over the top |
| every 5s | `PerfDefaultsVerify` - three READS, no writes unless something actually moved |

An earlier build re-asserted these every 300ms off the boost tick. That was wrong twice over
and was pulled: writing a character cvar can make the engine re-evaluate every character, and
if a level context re-applies its own value each frame the two fight and re-initialise cloth
on every pass - a "keep it applied" guard that costs more than the setting saves. The verify
is read-only in the normal case, and logs the FIRST time it ever has to repair anything, so
we learn whether `mod.cfg` alone was sufficient rather than assuming either way.

`merc_perf_defaults_off` opts out and persists per save; `merc_perf_defaults_status` shows
live values against wanted.

Honest caveats:
- `ca_ClothBypassSimulation` is GLOBAL and has a visible cost - garments still deform with
  the body (wrap skinning) but stop swinging independently, on vanilla NPCs too. It is the
  one shipped item a purist would object to, which is why the opt-out is one command.
- A live siege is a noisy bench: identical configurations drifted +-3-5% between passes
  (`clothoff` read -0.2% then +5.4%; `facearea` -1.0% then +2.4% then +3.8%). The three
  shipped winners cleared their bar repeatedly and in the same direction; anything that won
  once was not trusted. `facearea` may be a real small win that never cleared its 7% visual
  bar - worth a manual check.

## Bench results on core-restricted hardware — 2026-08-28

Measured by running the release build pinned to 2 logical cores (`$p.ProcessorAffinity`), 50
mercs, Kuttenberg. This is the first data on the axis users actually report.

| knob | effect | reading |
|---|---|---|
| 32 cores, 50 mercs, formation, full view | stable 60fps | **not GPU-bound.** Kills every render-side theory |
| looking away / up | +10fps | cost is occluded when off-screen: per-character CPU |
| `merc_render_lod 200` | +10fps, ugly | works by pushing LOD past a SIMULATION gate, not by drawing less |
| `merc_sim_off` vs `normal` | 30 vs 20-25fps | cloth/socket simulation is worth ~5fps of ~25 |
| `merc_sim_lean` | best feel | the tier to ship |
| **`merc_formation_off`** | **WORSE** | the engine formation is an OPTIMISATION, not a cost - 50 independent CrimeFollowers each pathfind and avoid alone; the formation solves slots once. Candidate A from the comparative sweep is REFUTED |
| Raborsch siege, 2 cores | ~15fps under EVERY knob incl. LOD 200 | nothing mesh- or cloth-side reaches it |

**Why LOD ever helped** - the engine's own help text, out of WHGame.dll:
`wh_ca_PendulumMaxLodToSimulate` = *"Disable simulation of pendulums if animation lod of the
character is higher than this value."* Simulation is gated on LOD INDEX. Raising mesh LOD was
buying a simulation cut and paying for it in ugliness. The direct lever is
`ca_ClothBypassSimulation` = *"if this is 1 actual cloth simulation is disabled (WRAP SKINNING
STILL WORKS)"* - garments still deform with the body, they just stop swinging. Shipped as
`merc_sim_trim | lean | off | normal` (KCD2 has a whole `wh_ca_Cloth*` budget subsystem:
distance cutoffs, screen-size thresholds, adaptive budgets, frame skipping).

**Why the siege is immovable** - it is the one scene where the mod PINS the AI-LOD boost
(`RaborschStandUp` -> `LodBoostPin`), forcing `WH_AI_LOD_MaxCountDetail` 70 -> 260,
`MaxDetailDistance` 120 -> 250, fake-move interval 1s -> 0.05s. That is 260 NPCs in full AI
simulation - pure CPU, and untouchable by mesh LOD or cloth sim, which is exactly why every
knob failed there. Right trade on a strong CPU, backwards on a weak one.

`merc_lowspec_on` goes the other way: boost off, Detail budget cut BELOW stock (40/70m), cloth
lean, torches off. Deliberately manual - core count is a poor proxy for single-thread speed,
and silently degrading a strong machine's siege is worse than a command nobody runs.

## The v2.1 per-merc density cost — user-reported, triaged 2026-08-28

A Nexus report with a real differential: v2.1, 4-5 mercs = -40-50fps in NPC-dense towns on
mid-range hardware; v1.6.1 carried ~20 mercs for free; the 32-core dev box loses ~10fps at 50.
A 13-agent comparative sweep (bodyguards reference mod vs v1.6 vs HEAD, verified adversarially
at an 8-core/16.6ms budget) ranked the causes; the sum only reaches the reported 6-10ms/frame
AT NIGHT or with the (since-fixed) alert latch stuck - or as coincident bursts.

Shipped from that ranking:

| fix | where | mechanism |
|---|---|---|
| follower churn 6.7x down | `follow.xml` foot arms | the 1.5s teardown boxes were re-registering each merc's engine follower (fresh path + avoidance vs every town NPC) ~3.3x/sec squad-wide; leader/chain boxes now 10s (matching the mounted twin - the ContinuousSwitch guard, not the box, handles mode flips), formation-reacquire fallback 4s |
| unarmed pre-filter | `consider()` in target_selection | a town bystander cost ~10 engine calls per 300ms pass through the accept chain (skipWeaponCheck=true bypassed the early weapon gate BY DESIGN, for camps); unarmed + not-a-confirmed-attacker now exits after the 1 IsWeaponDrawn call. Re-entry: next pass once drawn, or instantly via `confirmed` |
| night torches capped | `CampNightTorchTick` | every merc got a moving SHADOW-CASTING light + fire emitter at night, scaling 1:1 with squad size - invisible on a 5080, ms/frame on mid-range GPUs. Cap `CampTorchMax` = 2, camp guards first; `merc_torches N`, 0 = none |

NOT yet touched, pending measurement: the engine formation system itself (MakeFormation /
FormationFollower, absent from both fast trees) - its native cost is invisible to Lua and needs
the core-restricted bench below before any redesign.

**Mid-range bench on the dev box** (honest emulation, no fake sleeps): launch, then
`$p = Get-Process KingdomCome; $p.ProcessorAffinity = 0xFFFF` (16 logical = 8 cores; Task
Manager checkboxes are LOGICAL cpus - 4 boxes is 2 cores). Fixed town loop, frame-bucket
histogram per condition (`merc_prof_reset` / report): 0 mercs, 5 mercs day, 5 mercs NIGHT,
old pak vs new pak. The night leg is the torch hypothesis' direct test; ask reporters "is it
worse at night?" - one word of theirs outranks an hour of profiling.

## The save-residue leak (real, fixed, but NOT the lag)

### The original (now demoted) residue write-up

### saves accumulate the mod's NPCs

Counted straight out of one playline's save files (zlib-inflated, `SpawnedFriend` names):

| save | baked mercs | patrolmen | tower archers | live roster at the time |
|---|---|---|---|---|
| save478 | 10 | 0 | 0 | ~8 |
| save480 | 41 | 27 | 0 | ~8 |
| save483 | 50 | 0 | 6 | 8 |

Every load respawned all of them as full NPC entities. **Nothing ever removed one**: dismiss
set a flag and left the entities alive (and `RebuildMercCache` then *skipped* its scan, so
they were never even looked at again); `DespawnMerc`'s only caller sees current-roster deaths
only; the patrol sweep was a 600m box and the quartermaster sweep 200m. Neither `MercCount`
nor `ActiveMercs` counts any of this, which is why four sessions of profiling and every
squad-size A/B measured "8 mercs" while ~60 unmanaged NPCs stood in the world.

It also resolves the with/without-mod paradox that wrecked every earlier test: the residue
rides in the SAVE, so removing the mod changes nothing (the orphans load anyway, now with
unresolvable souls), while a fresh playthrough or a load-and-resave-without-mods is clean —
exactly the two fixes users kept reporting.

Fixed twice over, in `mercenaries_util.lua` / `mercenaries.lua`:

- **Load sweep**: `RebuildMercCache` (the one full-class scan, on load) now removes every
  mod-prefixed NPC that did not just make it onto the roster — previous-session corpses,
  paid-off men, recordless patrolmen/tower archers/quartermasters/enemies. Owners that want
  them back (camp restore, patrols) respawn fresh ones seconds later. Log line:
  `load sweep: removed N stale mod NPC(s)`.
- **Dismiss despawns**: paid-off men leave the world after 15s; if the player saves inside
  that window the load sweep catches them next time.

## A save carries the mod after the mod is gone

Decompressing a real save (`save483.whs`, 481 zlib streams, 15.7 MB inflated) found 50
`SpawnedFriend_*`, 6 `SpawnedTower_archer_*` and 43 saver-tag entities — the saver tags all
distinct, so that mechanism does **not** leak. The 56 NPCs do persist. Load that save without
the mod and those entities remain while the 222 soul rows, 11 brains and 102 skald characters
that define them are gone.

The practical consequence is a rule about testing, not a bug to fix:

> **"I removed the mod and it still lags" is not evidence until the save has been loaded and
> re-saved without the mod.** Until then the save is still full of the mod.

Two users independently reported that exact sequence — uninstall, load, save, reinstall — as
what fixed them. It is also the reason the corrupted-files verdict above should be read as *a*
cause, not *the* cause: the test that pointed at it was run on a save that still contained the
mod.

## What changed

| change | file | effect |
|---|---|---|
| patrol population caps + nearest-first staggered spawning | `mercenaries_patrols_live.lua` | 234 → 36 NPCs worst case |
| `IsValidEnemy` 65-entry `string.find` → `OwnedSoulSet()` hash | `mercenaries_target_selection.lua` | ~4,300–6,500 pattern matches/sec removed |
| enemy positions cached on `CachedEnemies` | same | duplicate `GetPos` pass per merc per tick removed |
| `table.sort` → bounded top-8 insertion | same | no comparator closure or full sort per merc |
| `FindValidGround` `maxTries` budget | `mercenaries_util.lua` | 1,188 → 360 rays worst case; raid/ambush bursts 16,632 → 2,016 |
| `SaveString` tag map, one scan per session | `mercenaries_saving.lua` | ~7ms → ~1ms per write; `LogiSave` batched |
| `DefForget` wrote an empty string, which `SaveString` rejects | `mercenaries_defences.lua` | defence layout now actually clears |
| `aleksej_scheduler.xml` wrote an undeclared variable | `data/AI/` | 74 engine errors/session gone; Aleksej now defends himself |
| `RayWorldIntersection` skip-entity passed a table | `util.lua`, `tower.lua` | 30 warnings/session gone; the skip now works |
| BT `Wait` variation raised to 40% on 111 pollers | `data/AI/*.xml` | per-NPC trees de-phased |
| LOD boost gated on hostiles, threshold 8 → 70 | `mercenaries_lodboost.lua` | no longer latches on squad size alone |
| LOD band hysteresis + dwell | same | 300m query + per-NPC call no longer re-fires on crowd jitter |
| shared caches and master scheduler | `mercenaries_perf.lua`, `mercenaries_scheduler.lua` | reference sections below |

## Ruled out — do not re-investigate

- **Lua GC** — tested with the collector stopped, no change.
- **Render pinning** — tested with `merc_render_pin 0`, no change. Still a real per-merc cost, just
  not the cause.
- **The mod's Lua generally** — 0.19% of wall time.
- **Invalid script contexts** — all six names validate against the game's 777-entry table.
- **Leftover debug code** — every debug module is console-only, arms no timer at load and leaves
  nothing behind. Every Debug/Test/Verbose flag defaults off.
- **`RebuildMercCache`** — runs once on load, not periodically.
- **Bare BT `Loop`/`Wait` node traversal** — a structural count is not evidence of cost; scriptbind
  crossings and world queries are.
- **`RaidTick` / `LivePatrolTick` / `WBTick` as background cost** — all correctly gated.

## A regression worth remembering

After the caps were confirmed working, an adversarial review flagged that the corpse cap could delete
bodies the player was actively looting. The fix for that reintroduced the lag, because two of its
parts raised the entity count above the version that had been tested:

- `PatrolMaxCorpses` 12 -> 24, and a `PatrolCorpseKeepRange` of 60m **inside which the cap never
  evicted at all**. Standing and fighting in one place then accumulated corpses with nothing to stop
  it - an unbounded case introduced while fixing a bounded one.
- `PatrolLiveGangCount` changed to require a living man, so a wiped gang released its slot instantly
  and a replacement spawned *alongside* the corpse pile. More entities at once, not fewer.

Both reverted. The looting protection is now keyed on **recency, not distance**: the pile just made
is exempt from the cap for `PatrolCorpseGraceSecs` (30s) and then ages out. At most a pile or two is
ever exempt, so it cannot accumulate.

The lesson is narrow and worth keeping: **any change that relaxes a population bound has to be
measured against the bound, not just against the bug it fixes.** A correctness fix that quietly
raises a ceiling is a performance regression wearing a bug-fix hat.

## Known costs not yet addressed

Real, but not the cause, and each needs a design decision rather than a mechanical fix:

- `LogiRebuildCampForUpgrade` tears down and re-raycasts the **entire** camp for every upgrade
  purchase — the heightmap phase alone is up to 7,921 rays, hit 3–7 times a session.
- `TowerMaxCount = 999`; each tower is ~8 always-rendered meshes.
- Every spawned structure gets `SetViewDistUnlimited`; wall segments stack four max-detail render
  calls per piece.
- `merc_deterrenceImmunityPulse` (both level copies) is a 5s repeating quest Timer that logs
  `Empty soul collection` whenever no mercs exist. Harmless at that rate, but it buries real errors.
  Left alone deliberately — quest graphs are fragile.

---

## Shared frame cache

`mercenaries_perf.lua` — one scan per window, everyone reads from it. Load immediately after `mercenaries_util.lua` in the `Script.LoadScript` chain, before anything that reads `PerfPos`/`PerfNpcScan`/`EntityByWuid`.

```lua
mercenaries.PerfPos           = {}   -- [wuidStr] = {x=,y=,z=}; PerfPos.player = player pos
mercenaries.PerfNpcScan       = nil  -- {at=,cx=,cy=,cz=,r=,list={{entity=,wuid=,pos=},...}}
mercenaries.PerfWidestRadius  = mercenaries.EnemyScanRadius or 18
mercenaries.EntityByWuid      = {}   -- [wuidStr] = entity ref
mercenaries.CampActorCache    = {}   -- [wuidStr] = true/false
mercenaries.PatrolMemberIndex = {}   -- [wuidStr] = LivePatrols record

function mercenaries:PerfWantRadius(r)
    if r and r > (self.PerfWidestRadius or 0) then self.PerfWidestRadius = r end
end

-- ONE box query replaces UpdateEnemyCache's own, static archers' own, FindEnemyTarget's own.
function mercenaries:PerfScanNpcs()
    if not player then return end
    local pp = player:GetPos()
    if not pp then return end
    local r = math.max(self.PerfWidestRadius or 18, self.EnemyAlerted and self.EnemyAlertRadius or 0)
    local list = {}
    local ents = System.GetPhysicalEntitiesInBoxByClass(pp, r, "NPC")
    if ents then
        for _, ent in pairs(ents) do
            if ent and type(ent) == "table" then
                local p = ent:GetPos()
                if p then
                    local wuid = ent.this and ent.this.id or ent.id
                    table.insert(list, { entity = ent, wuid = wuid, pos = p })
                    self.PerfPos[tostring(wuid)] = p  -- piggy-back the position cache for free
                end
            end
        end
    end
    local now = 0; pcall(function() now = System.GetCurrTime() or 0 end)
    self.PerfNpcScan = { at = now, cx = pp.x, cy = pp.y, cz = pp.z, r = r, list = list }
end

-- Cheap, O(squad), no world query — driven every master tick (50ms).
function mercenaries:PerfScanMercs()
    for _, ent in pairs(self.ActiveMercs or {}) do
        local wuid = ent and (ent.this and ent.this.id or ent.id)
        if wuid then
            local p = ent:GetPos()
            if p then self.PerfPos[tostring(wuid)] = p end
        end
    end
    if player then
        local pp = player:GetPos()
        if pp then self.PerfPos.player = pp end
    end
end

-- Returns nil (never a false "empty") when out of coverage or too stale — caller MUST
-- fall back to its own query, never assume nothing is there.
function mercenaries:PerfNpcsNear(pos, radius, maxAgeMs)
    local scan = self.PerfNpcScan
    if not (scan and pos and radius) then return nil end
    if maxAgeMs then
        local now = 0; pcall(function() now = System.GetCurrTime() or 0 end)
        if (now - (scan.at or 0)) * 1000 > maxAgeMs then return nil end
    end
    local dx, dy = pos.x - scan.cx, pos.y - scan.cy
    if math.sqrt(dx*dx + dy*dy) + radius > scan.r then return nil end
    local r2, out = radius*radius, {}
    for _, e in ipairs(scan.list) do
        local ex, ey = e.pos.x - pos.x, e.pos.y - pos.y
        if (ex*ex + ey*ey) <= r2 then table.insert(out, e) end
    end
    return out
end

function mercenaries:PerfRegister(ent)
    if not ent then return end
    local wuid = ent.this and ent.this.id or ent.id
    if wuid then self.EntityByWuid[tostring(wuid)] = ent end
end
function mercenaries:PerfUnregister(wuid)
    if wuid then
        local ws = tostring(wuid)
        self.EntityByWuid[ws] = nil
        self.PerfPos[ws]      = nil
    end
end

-- Liveness-checked; falls back to a hash lookup (NOT a name scan) so a stale post-load id
-- can never silently return wrong data — it must pass IsAliveAndWell before being returned.
function mercenaries:PerfEntity(wuid)
    if not wuid then return nil end
    local ws = tostring(wuid)
    local cached = self.EntityByWuid[ws]
    if cached then
        local ok, alive = pcall(function() return cached.id ~= nil and self:IsAliveAndWell(cached, true) end)
        if ok and alive then return cached end
        self.EntityByWuid[ws] = nil
    end
    local ok, ent = pcall(function() return XGenAIModule.GetEntityByWUID(wuid) end)
    if ok and ent then self.EntityByWuid[ws] = ent end
    return ok and ent or nil
end

function mercenaries:OwnedSoulSet()
    if self._ownedSoulSet then return self._ownedSoulSet end
    local set = {}
    for _, tierList in pairs(self.Souls or {}) do
        for _, guid in ipairs(tierList) do set[guid] = true end
    end
    for _, guid in ipairs(self.ArcherSouls or {}) do set[guid] = true end
    for _, guid in ipairs(self.StaticArcherSouls or {}) do set[guid] = true end
    self._ownedSoulSet = set
    return set
end

function mercenaries:CampActorCacheSet(wuid, isActor)
    if wuid then self.CampActorCache[tostring(wuid)] = isActor and true or false end
end
function mercenaries:CampActorCacheInvalidate(wuid)
    if wuid then self.CampActorCache[tostring(wuid)] = nil end
end
function mercenaries:CampActorCacheInvalidateAll()
    self.CampActorCache = {}
end

function mercenaries:PatrolIndexGang(rec)
    for _, e in ipairs(rec.men or {}) do
        local w = e and (e.this and e.this.id or e.id)
        if w then self.PatrolMemberIndex[tostring(w)] = rec end
    end
end
function mercenaries:PatrolIndexClear(rec)
    for _, e in ipairs(rec.men or {}) do
        local w = e and (e.this and e.this.id or e.id)
        if w and self.PatrolMemberIndex[tostring(w)] == rec then
            self.PatrolMemberIndex[tostring(w)] = nil
        end
    end
end

-- Wipe everything on load/level change; the one place EntityByWuid gets re-populated
-- afterward is RebuildMercCacheDelayed (already the mod's one permitted full-world scan).
function mercenaries:PerfReset()
    self.EntityByWuid      = {}
    self.PerfPos           = {}
    self.PerfNpcScan       = nil
    self.CampActorCache    = {}
    self.PatrolMemberIndex = {}
    self._ownedSoulSet     = nil
end
```

**Staleness contract** (write this down — the thing prior ad-hoc caches in this mod never had):

| table | refresh | tolerance |
|---|---|---|
| `PerfPos` | every master tick (50ms), all `ActiveMercs` + player | strictly fresher than any current 150ms+ consumer; never a regression |
| `PerfNpcScan` | on the `combatscan` slot (300ms, 150ms alerted, 600ms+ idle) | consumers at ≤300ms may read directly; anchored-elsewhere consumers (towers, WBTick, QM) MUST call `PerfNpcsNear` and fall back to their own query on nil, never assume empty |
| `EntityByWuid` | liveness-checked every read | never trusted blind; self-heals via hash lookup on miss/fail, so post-load id reuse can't return wrong data |
| `CampActorCache` | event-invalidated (camp spawn/break/recall/dismiss/siege-flip); round-robin sweep is only the safety net | bug in event wiring degrades to "≤2.5s stale," never "wrong forever" |
| `PatrolMemberIndex` | event-invalidated only, never time-based | `PatrolLivingMen` deliberately stays an uncached live rescan — a TTL here would let a corpse anchor the follow chain |

### Adopting call sites

| file:line | current pattern | primitive | replacement |
|---|---|---|---|
| `mercenaries_target_selection.lua:56-83` | 65-entry `string.find` triple loop | `OwnedSoulSet()` | O(1) hash lookup on `ent.soul:GetId()` |
| `mercenaries_target_selection.lua:115-149` | own `GetPhysicalEntitiesInBoxByClass` | `PerfNpcsNear`/`PerfScanNpcs` | driven by `combatscan` slot with backoff |
| `mercenaries_saving.lua:4-61` | full `GetEntitiesByClass('BasicEntity')` scan per save/load | same `PerfRegister`/`PerfEntity` mechanism, applied to a tag→saver-entity table | invalidated via `PerfReset` on load |
| `mercenaries_target_selection.lua:273-314` (`ScanForEnemies`) | fresh table + `table.sort` per merc per tick | entries carry `.pos` from the scan already | no per-call `GetPos`; bounded nearest-N pass instead of sort |
| `mercenaries_logistics.lua:684-703` | `GetEntityByName` for QM every 5s | `PerfEntity(qmWuid)` | QM wuid cached via `PerfRegister` at spawn |
| `mercenaries_static_archer.lua:509-558` | independent 90m box query per archer | `PerfNpcsNear(archerPos, StaticArcherRange, maxAgeMs)` | `PerfWantRadius(90)` announced at spawn; own-query fallback outside coverage; must carry `isModEnemy` flag |
| `mercenaries.lua:857-880` (`CombatScanLoop`) | always-on 300ms | `combatscan` slot | backoff 300ms→600ms only while unalerted and `CachedEnemies` empty, re-checked every tick |
| `mercenaries_target_selection.lua:273-314,414-454` | duplicate `GetPos` across `ScanForEnemies`/`PickCombatTarget` | shared `.pos` from `PerfScanNpcs` | eliminates the duplicate pass entirely |
| `mercenaries_patrols_live.lua:1002-1035,633-639` | O(all route slots) linear scan | `PatrolMemberIndex` | O(1) "which gang"; `PatrolLivingMen` stays uncached |
| `mercenaries_patrol.lua:85-99` | `PatrolCtx` called twice | same index | both calls become O(1); prefer threading params instead |
| `mercenaries_formation.lua:94-138` | tostring/`IsCampActor` pile | `CampActorCache` + `PerfPos` | O(1) cache read; no per-merc `GetPos` |
| `mercenaries_patrols_live.lua:927-963` | redundant living-list rebuild | reuse caller's already-computed living list | not a TTL'd copy — thread it down |
| `data/AI/camp_actor.xml:79-154` | 2-3× redundant role lookups/cycle | `campActorSnapshot` perNpc slot | one `{isGuard,furniture,activity}` computed per NPC per cycle |
| `mercenaries_camp.lua:1808-1934` | unconditional O(n²) pairing scan | distance check inside `campchat` slot body | `if not CampActive` wipe branch stays unconditional |
| `mercenaries_quartermaster.lua:123-177` | always-on 1s box query ×2 | `qmtargetscan` slot with backoff | box query itself unchanged; never shares `CachedEnemies` |
| `data/AI/follow.xml:177-264` | `GetEntityByName` every 500ms | `PerfEntity(data.horse)` | `PerfRegister` right after `System.SpawnEntity` for the horse |
| `mercenaries_spawning.lua:805-930` (`FindEnemyTarget`) | independent per-NPC 50m query | `PerfNpcsNear(myPos, 50, maxAgeMs)` with fallback | per-agent hold/`NavTargetBlocked` state machine untouched |

## Budgeted master scheduler

`mercenaries_scheduler.lua` — one master tick, N registered slots, phase-offset, gated, amortized, adaptive. Load after `mercenaries_perf.lua` and after everything the slot `fn`s call — near the end of the `Script.LoadScript` chain.

```lua
mercenaries.MasterTickMs = 50
mercenaries.SchedTick    = 0
mercenaries.SchedSlots   = {}

local function ticksOf(ms) return math.max(1, math.floor(ms / mercenaries.MasterTickMs + 0.5)) end

function mercenaries:SchedRegister(name, def)
    def = def or {}
    local period = ticksOf(def.periodMs or 1000)
    local phase = def.phaseTicks
    if not phase then
        self._schedPhaseCursor = (self._schedPhaseCursor or 0) + 1
        phase = self._schedPhaseCursor % period
    end
    self.SchedSlots[name] = {
        name = name, fn = def.fn, gate = def.gate,
        periodTicks = period, phaseTicks = phase % period,
        backoff = def.backoff, idle = false, idleSince = nil,
        perNpc = def.perNpc, cursor = 1,
    }
end

-- Only the subsystem itself knows whether this pass found anything; re-checked every
-- master tick, never latched — a squad going alert mid-backoff is caught next tick.
function mercenaries:SchedMarkIdle(name, idle)
    local s = self.SchedSlots[name]
    if not s then return end
    if idle and not s.idle then s.idle = true; s.idleSince = self.SchedTick end
    if not idle then s.idle = false; s.idleSince = nil end
end

local function effectivePeriod(self, s)
    if not (s.backoff and s.idle) then return s.periodTicks end
    if (self.SchedTick - (s.idleSince or 0)) < ticksOf(s.backoff.idleMs or 0) then return s.periodTicks end
    return math.max(s.periodTicks, math.floor(s.periodTicks * (s.backoff.factor or 1)))
end

local function runPerNpc(self, s)
    local pn = s.perNpc
    local t = self[pn.table]
    if not t then return end
    if not s._keys or s._keysDirty then
        s._keys, s._keysDirty = {}, false
        for k in pairs(t) do table.insert(s._keys, k) end
        s.cursor = 1
    end
    local n = #s._keys
    if n == 0 then return end
    for _ = 1, math.min(pn.budget or n, n) do
        local k = s._keys[s.cursor]
        local ent = t[k]
        if ent then pcall(pn.fn, self, ent, k) end
        s.cursor = s.cursor + 1
        if s.cursor > n then s.cursor = 1; s._keysDirty = true end
    end
end

function mercenaries.MasterTick()
    local self = mercenaries
    self.SchedTick = self.SchedTick + 1
    local t = self.SchedTick
    for _, s in pairs(self.SchedSlots) do
        local period = effectivePeriod(self, s)
        if (t + s.phaseTicks) % period == 0 then
            if (not s.gate) or s.gate(self) then
                if s.perNpc then
                    runPerNpc(self, s)
                else
                    local ok, err = pcall(s.fn, self)
                    if not ok then
                        System.LogAlways('[Mercenary Jeff] Scheduler slot "' .. s.name .. '" error: ' .. tostring(err))
                    end
                end
            end
        end
    end
    Script.SetTimerForFunction(mercenaries.MasterTickMs, "mercenaries.MasterTick")
end
```

50ms is the GCD of every existing cadence (150/300/700/1000/3000/5000 all land on an exact boundary — nothing drifts). Phase offsets are auto-assigned from a monotonic cursor, so slots sharing a period spread across it by registration order instead of colliding by coincidence — today, 150/300/700 all divide 2100ms evenly, so `FormationLoop`, `CombatScanLoop`, and `WBTick` periodically all fire on the same frame purely because their independent `SetTimerForFunction` chains happened to drift together.

### Phase-slot table

| slot | periodMs | backoff | perNpc | fn |
|---|---|---|---|---|
| `mercpos` | 50 | — | — | `PerfScanMercs` |
| `formation` | 150 | **none — flat, never backed off** | — | `UpdateFormationLeader` |
| `campactorsweep` | 50 | — | `ActiveMercs`, budget=4 | `CampActorCacheSet` per merc |
| `combatscan` | 300 | idle 5000ms → ×2 (600ms) | — | `DismountWatch`, `UpdatePlayerSpeed`, `PerfScanNpcs`, `UpdateEnemyCache`, `UpdateSquadThreat`, `LodBoostTick` |
| `monitor` | 1000 | — | — | `MonitorInventory`, `MonitorMainQuestLoop`, `MonitorDistanceAndTeleport`, `ProcessReturnPending`, `KeepStaticArchersUp`, `AmbushMonitor`, `CampBedSleepWatch`, `BanditCampMonitor`, `RaborschMonitor`, `AlxTalkTick`, `AlxLodgingTick` |
| `lowpriority` | 5000 | — | — | `PruneMercCache`, `UpdateFormationSlots`, `ResupplyArchersOutOfCombat`, `ResupplyStaticArchers`, `PruneCombatClaims`, `RefreshRenderPins`, `LivePatrolWatchdog`, `MonitorCamp`, `LogiTick` |
| `wbtick` | 700 | — | — | `WBTickBody` (gated, see below) |
| `lodboostreassert` | 300 | — | — | compare-before-write on 18 cvars + `LodRatioAutoApply` |
| `qmtargetscan` | 1000 | idle 8000ms → ×3 | — | `FindQuartermasterTarget` (own query, untouched) |
| `campchat` | 5000 | — | — | `CampChatTick` (distance gate added inside) |
| `lootsweep` | 1000 | — | — | `LootAssign` (busy/free hoisted before scan) |

### Gating preconditions per subsystem

- **`mercpos` / `campactorsweep`**: `next(self.ActiveMercs) ~= nil` — nothing to do with an empty squad.
- **`formation`**: `next(self.ActiveMercs) ~= nil and player ~= nil` — no combat/distance/backoff gate at all, deliberately: this is the one thing that must never lag. Its win comes entirely from the cache primitives, not from running less often.
- **`combatscan`**: no gate function — always fires; the backoff (300ms→600ms) is the throttle, driven by `SchedMarkIdle("combatscan", not (EnemyAlerted or next(CachedEnemies)))`, re-evaluated every 50ms so a squad going alert mid-backoff is corrected on the very next master tick, never stale until some independent timer's own next fire.
- **`wbtick`**: `WBArmed and CampActive and CampCenter and player`, then squared-distance ≤300² from `CampCenter` — mirrors `RaidPlayerInCamp`'s own 45m gate with generous margin; raids only launch within 45m and forces spawn within 120m, so this cannot suppress a legitimate raid.
- **`lodboostreassert`**: `LodBoostActive == true` — cadence stays 300ms on purpose (a slower reassert reintroduces the LOD-popping bug the every-tick reassert was written to fix); the fix is compare-before-write, not a slower timer.
- **`qmtargetscan`**: no gate, backoff only — deliberately never shares `CachedEnemies` (player-centered) because it must keep defending an empty, distant, raided camp.
- **`campchat`**: the `if not CampActive` chat-wipe branch stays unconditional inside the fn; only the O(n²) pairing scan is gated on distance-to-`CampBuildOrigin`.
- **`lootsweep`**: no gate; `busy`/`free` are computed first inside the fn and `LootEligibleMercs()` is skipped when neither can change.

### Timer latches must be cleared on load, not on session start

`Script.SetTimerForFunction` chains **do not survive a save load** — the engine drops them with the
level. The `mercenaries` table does survive, so **any latch guarding a timer outlives the timer it
guards**, and left set it means that tick never comes back for the rest of the session.

That is not a theory. `LootSweepLoop` is armed unconditionally on every load *and* re-arms itself
unconditionally; if timers survived it would double every single load, and it does not.

Getting it wrong killed the whole mod on the second save loaded in one session. `SchedRunning` was
still true from the first, `SchedStart` refused to arm, and the master tick never ran again — taking
`MonitorInventory` with it, so the hire tokens were never consumed and **hiring silently did
nothing**. `_schedWatchdogArmed` was latched the same way, so the one thing that could have noticed
was dead too. The log says it plainly and then stops:

```
[Mercenaries] Game loaded! Starting the inventory monitor loop...
[MercSched] master tick already running - refusing to arm a second chain
```

`SchedOnLoad` runs at the very top of `OnGameplayStarted`, before anything arms a timer, and clears
every latch in `TimerLatches` — `SchedRunning`, `_schedWatchdogArmed`, `LivePatrolRunning`,
`RaidRunning`, `WBRunning`, `FoeLoopArmed`, `GearTickArmed`, `_profHbArmed`. **Add to that list
whenever a new self-arming loop gets a latch.** Only latches whose chain is re-armed somewhere
belong there; a latch nobody re-arms is just a flag.

The latch itself is kept, because the thing it protects against is real — `OnGameplayStarted` arming
twice for *one* load would leave two ghosts independently driving every slot. It is now keyed to a
**load generation** (`SchedLoadGen`) instead of the session: within one load a second `SchedStart`
is still refused, across loads it arms fresh.

## Full findings table

Sorted by severity, then tick rate (fastest first) within severity.

| id | file:line | tick | cost | fix | severity |
|---|---|---|---|---|---|
| follow-horse-getentitybyname-poll | `data/AI/follow.xml:177-264` | 500ms | 2 `GetEntityByName` calls/merc/sec, unconditional of mount state, full-registry linear scan | `PerfEntity(data.horse)` hash lookup | critical |
| formation-eligibility-tostring-pile | `mercenaries_formation.lua:94-138` | 150ms | ~16 tostring/merc/tick incl. one fully redundant `IsCampActor` call; ~500-550 scriptbind + ~1,400-2,100 tostring/sec at 20 mercs | drop redundant call; route through `CampActorCache` | high |
| enemy-cache-soul-guid-stringfind | `mercenaries_target_selection.lua:54-108,115-149` | 300ms | ~1,950 `string.find` + ~450 scriptbind calls/300ms at 30 nearby NPCs | `OwnedSoulSet()` hash lookup | high |
| isvalidenemy-linear-soul-scan | `mercenaries_target_selection.lua:56-83` | 300ms | 65 `string.find`/candidate, ~4,300-6,500/sec at 20-30 NPCs | same `OwnedSoulSet()` fix | high |
| combatscanloop-always-on-unfiltered | `mercenaries.lua:857-880` | 300ms | 3.33 full box-query+validate passes/sec forever once 1 merc hired | rides fix #1's speedup; add idle backoff via scheduler | high |
| patrolctx-linear-rescan-eager-rebuild | `mercenaries_patrols_live.lua:1002-1035,633-639` | 300ms (as fast as 150ms via `PatrolWalkTick`) | O(~26-52 route slots) scan + eager alive-rebuild per hook; ~300-650 scriptbind/sec, 2-gang/15-man | `PatrolMemberIndex[wuidStr]=rec` | high |
| findenemytarget-per-npc-query | `mercenaries_spawning.lua:805-930` | 1000ms | independent 50m box query per enemy NPC; burst of N simultaneous queries at fight start | shared `PerfNpcsNear`, per-agent state machine preserved | medium |
| savestring-full-world-scan | `mercenaries_saving.lua:4-61` | 5000ms | `GetEntitiesByClass('BasicEntity')` + spawn + destroy + log I/O per write; ~94 non-tick call sites too | id-cache per tag, invalidated on load | medium |
| static-archer-per-instance-full-scan | `mercenaries_static_archer.lua:509-558` | 1000ms | N archers × independent 90m query + 65-scan, overlap unshared | shared `PerfNpcsNear` per archer | medium |
| patrolchain-double-ctx-call | `mercenaries_patrol.lua:85-99` | 1000ms | doubles `PatrolCtx` cost + O(gang) identity scan w/ per-comparison `tostring()` | `PatrolMemberIndex`, or thread caller's leader/members as params | medium |
| wbtick-ungated-sphere-scan | `mercenaries_wallbattle.lua:184-214,629-703` | 700ms | ungated 55m sphere query + name/alive walk, forever, once any wall/defence exists | distance gate (300m from `CampCenter`) before the scan | medium |
| scanforenemies-per-merc-sort | `mercenaries_target_selection.lua:273-314` | 300ms | O(m log m) `table.sort` + fresh table per merc per tick on a centrally-refreshed list | bounded nearest-N linear pass, drop `table.sort` | medium |
| scanforenemies-pickcombattarget-duplicate-scan | `mercenaries_target_selection.lua:273-454` | 300ms | one O(E log E) sort + one redundant O(E) `GetPos` pass, duplicated self-lookup | merge into one pass, shared `.pos` | medium |
| ranged-combat-data-ammo-overscan | `mercenaries_ai_modules.lua:236-249` | 300ms | 14 vs at-most-6 `GetCountOfClass` scriptbinds/archer/tick, each pcall-wrapped | `GetArcherWeaponType()` once, scan only that pool | medium |
| archer-ammo-check-no-early-exit | `mercenaries_ai_modules.lua:236-249` | 300ms | same function, no early-exit once ammo found | same fix as above (duplicate finding) | medium |
| scanforenemies-double-getpos-and-closure-alloc | `mercenaries_target_selection.lua:273-314,414-454` | 500ms (true cadence 300ms) | duplicate `GetPos` across 2 passes; ~1,650-1,700 GetPos/sec at 50-merc opening skirmish | cache pos once per `UpdateEnemyCache` pass | medium |
| lodboost-cvar-reassert-always-on | `mercenaries_lodboost.lua:160-246` | 300ms | 18 unconditional `SetCVar` scriptbinds + 18 pcall closures/tick while ≥8 crowd | `GetCVar`-compare-before-`SetCVar` | low |
| foeloop-redundant-query-dormant | `mercenaries_foe.lua:119-161,180-332` | 250ms | zero cost today; would add a second 90m query + 3 nested O(F×C) passes if ever wired live | no action while dormant; share `PerfNpcsNear` before shipping | low |
| monitorinventory-unconditional-token-polling | `mercenaries.lua:596-806` | 1000ms | ~63 `GetCountOfClass` scriptbinds/sec, never early-outs | cheap version/menu-open gate before the ~50-class poll | low |
| patrol-alert-redundant-livingmen-rebuild | `mercenaries_patrols_live.lua:927-963` | 1000ms | 2 more alive-rescans per alert transition, narrow trigger (combat proximity only) | reuse caller's already-computed living list | low |
| camp-actor-bt-redundant-role-lookups | `data/AI/camp_actor.xml:79-154` | 1000ms | same 3 facts recomputed 2-3× via separate `ExecuteLua` crossings, per camp-actor NPC | one snapshot per NPC per cycle | low |
| campchattick-onsquared-no-distance-gate | `mercenaries_camp.lua:1808-1934` (Scripts/mods) | 5000ms | O(n²) pairing + ~3× scriptbind IsAliveAndWell/merc, runs regardless of player distance | distance gate before list-build/pairing | low |
| qm-aleksej-idle-target-scan-always-on | `mercenaries_quartermaster.lua:123-177` | 1000ms | 2 × 30m box query/sec forever, no enemy-presence gate | widen Wait to 2-3s while `~$inCombat` (query itself unchanged) | low |
| lootsweep-full-squad-scan-when-no-work-possible | `mercenaries_lootsweep.lua:290-347` | 1000ms | full ActiveMercs eligibility scan even when cap full/nothing left to give out; ~250 scriptbind/sec worst case at 50 mercs | hoist busy/free check before `LootEligibleMercs()` | low |
| logicampregen-getentitybyname | `mercenaries_logistics.lua:684-703` | 5000ms | linear-scan `GetEntityByName` for QM every regen tick | cache QM entity ref via `PerfEntity` | low |
| banditcamp-sweeptokens-rebuild-and-scan | `mercenaries_banditcamp_quest.lua:2373-2398` | 1000ms | rebuilds static 29-entry list from scratch every tick, 29 `GetCountOfClass` calls even when idle | memoize combined list once, lazily on first call | low |
| ambushmonitor-scene-table-copy | `mercenaries_ambush.lua:274-281,331-366` | 1000ms | 1 table alloc + key copies/sec, currently negligible | return `self.AmbushScenes` directly | low |

---

# Appendix: how this was found

Eight rounds, several of them wrong. The wrong turns are recorded because they are what stops the
next person repeating them.

**Rounds 1–2 optimised Lua.** A 16-agent sweep produced 28 findings, 27 verified. Real bugs, all
shipped — but the symptom did not move, because Lua was never the cost.

**Round 3 reframed the symptom.** "Heartbeat at constant FPS" means a periodic *spike*, not a
sustained load. Correct, and it led to building the profiler.

**Round 4 built the profiler, and it lied.** Its stall discriminator compared each slot's fired-tick
against a tick that had not run yet, so it would have reported *"the stall is outside this mod"* for
every stall regardless of truth. An adversarial audit caught it before it misled anyone, along with
five more defects in the same tool: return values truncated at four (`PatrolCtx` returns five), hitch
periods shared across all sources, nested calls producing phantom heartbeats, a stall threshold below
the timer's own floor, and the GC detector allocating inside the function meant to detect allocation.

**Round 5 measured the wrong build.** `PackageModDev.bat` targets a non-PGO DLL config one game
version behind, laggy with no mods. Every timing taken there overstated cost. The ratio (Lua =
0.19%) survived; the absolute numbers did not.

**Round 6 found GC, and a broken save.** Collections every 186–383ms with 15–29ms pauses landing
inside one-line functions — plausible, and wrong. The same log showed the save had been created with
35 mods and was running with 1, invalidating every with/without comparison made until then.

**Round 7: the scheduler was killing itself.** A duplicate-chain guard added in round 6 exited
without re-arming when two ticks landed within 40ms — which happens after any hitch, when the engine
fires queued timers back to back. Twelve watchdog re-arms in one session, with the core loops
intermittently dead for ~5s at a time. That was the "marginal improvement, kinda unreliable" phase.

**Round 8: patrols.** The answer had been in every log from the start:
`[Patrols] roaming patrols armed (26 route(s))`.

Three engine facts worth carrying forward:

1. `Script.SetTimerForFunction` accepts no third argument — passing one silently stops the timer
   re-firing. It killed the master scheduler for an entire session.
2. `System.GetCurrTime()` is engine-cached per frame and cannot time anything within a frame.
   `os.clock()` is the only usable source, at ~1ms resolution.
3. A syntax check does not catch a mangled identifier: `mathit_sin` passed `luacheck` cleanly and
   would have thrown on first use. Flag a called name that appears exactly once and is never defined.
