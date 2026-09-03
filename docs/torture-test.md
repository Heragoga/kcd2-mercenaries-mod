# The torture test (functional regression suite)

Where [autobench](performance.md) measures frame time, the torture test checks
**behaviour**: one command drives a real game session through hire, follow, camp, all six
upgrades, both deploy-composition modes, per-merc deploy, a staged camp fight, the
time-skip guards, single-upgrade removal, and — across a real save and a cold relaunch —
camp persistence. 19 checks, every one logged as `[Torture] PASS/FAIL` with a reason.

```
powershell -ExecutionPolicy Bypass -File tools\torturetest.ps1
```

Takes ~20 minutes and the desktop (it launches the game and drives it by keystroke).
The report at the end prints every verdict plus health counters (bark storms, pose spam,
stalls, OOM, script errors) — a run is clean when the verdicts are all PASS and the
counters are 0.

## How it works

Two phases, in two game sessions, because a completed load kills every Lua timer:

**Phase A** — [mercenaries_torture.lua](../data/Scripts/mods/mercenaries_torture.lua),
started by `merc_torture_auto` — dev-gated: `merc_dev` first (requires a `-devmode`
launch). The harness **types** that command into the console; `merc_torture_bindkeys` still
exists for manual use but nothing automated depends on it any more (see "Nothing is fired by
an F-key" below). Nothing is bound or registered in a player's game; the always-on
F-key binds were removed after players kept firing the auto-quit campaigns by
accident. A step machine on a 1s tick: each step `run`s once (heavy setup calls staggered
one per tick through an action queue), then `check`s every tick until pass/fail/timeout.
Henry is held 16m above the field in god mode on every tick — no step may ever need or
endanger him — except during the save step, because **an airborne player cannot save**
(five runs of `Game.QuickSave()` silently wrote nothing before that was found). The final
step stamps the save (`TortureStage=B` + squad/out-party counts + the packed station
tiles) and saves via `Game.SaveGameViaResting()` with `QuickSave` as fallback — the same
primary/fallback pair the camp bed save proved in live play.

**Phase B** — the harness verifies a save file newer than the campaign start actually
exists on disk (a silent save failure must be a loud harness failure, not a starved
phase B), kills the game, relaunches, and presses **Continue** — which resumes the newest
save by time, i.e. the one just written. The harness then types **`merc_torture_auto`
again**; `TortureStart` sees the stage stamp in the loaded save and runs the phase-B checks
instead of a fresh campaign (it never self-arms — see bug 5 below):
camp restored,
squad and out-party counts intact, and **every station tile within 1m of its saved
position** — the "upgrades shuffle around after a reload" regression, tested against real
persistence. It self-validates: the stamp only exists in the right save, so resuming a
wrong one shows as a timeout, never a false pass.

## The scenario probe (`merc_torture_probe` / `_aggro`)

Purpose-built saves get the **adaptive probe** instead of the full campaign:

```
powershell -ExecutionPolicy Bypass -File tools\torturetest.ps1 -Scenario banditcamp
```

Scenarios: `ambush`, `latecamp`, `kuttenberg`, `banditcamp`, `trosky` — each maps to a
save by main-menu list position plus the exact filename the engine must report loading
(a drifted list aborts rather than probing the wrong world; `-ScenarioDowns` overrides).
The probe reads whatever world it lands in and runs only what applies: census (with the
NAMES of nearby base-game NPCs), a squad hired on the spot if the save has none (which in
the city is itself the street-spawning test), defence-restore verification where the
save's stamps say walls/towers belong, a 120s engagement/peace-hold watch, a raid against
a fortified active camp judged off the wall battle's own phase machine, render-flip
sampling, and a health summary. It **never writes a save** and never normalises the world.

`banditcamp` is armed **aggro** (`merc_torture_probe_aggro`): non-mod NPCs there are
the declared enemy, their deaths are combat results, and a `provoke_test` calls five
mercs onto the nearest vanilla NPC via `ForcedTargetOf`. The arming is a separate
keybind, never a heuristic — a heuristic could point it at civilians.

Scenario results on the user's saves (2026-08-29): ambush 6/6 (merc claim on a real road
bandit at +1s), latecamp 6/6 (14 raiders staged, fought and beaten in 60s), kuttenberg
8/8 (12 hired mid-city, perfect peace-hold among 44 civilians), banditcamp 8/8 (bandits
aggroed the fresh squad unprompted; `kgru_pukavec` down 17s after a called attack).
The latecamp save also found and killed a real bug: the follow-stall watch escalating
during wall battles and hauling 18 defenders to the player mid-siege (it now stands down
while `WBPhase` is not idle).

## What the bring-up runs taught (do not relearn these)

- **`Game.QuickSave()` writes an AUTOSAVE slot; `Game.QuickLoad()` silently no-ops**
  (no quicksave file ever exists for it). Continue-after-relaunch is the reliable
  programmatic reload. Full detail in the memory notes and
  [tools/torturetest.ps1](../tools/torturetest.ps1)'s comments.
- **Driving the in-field pause menu by keystroke is treacherous**: the "load" navigation
  landed in the SAVE list often enough to overwrite saves, and the save list prints
  `Loading saved game <file>` merely from *selecting* an entry — only
  `Game loaded! Starting the inventory monitor` proves a load completed. The keystroke
  reload path is kept behind `-MenuReload` (it did verify phase B twice) but the relaunch
  path is the default.
- **The starting save drifts**: the main-menu `-DownsToSave 26` slot points into a moving
  list as autosaves accumulate. Harmless — phase A normalises its world (breaks any
  standing camp) and works from whatever state it gets, which doubles as start-state
  variety.
- The campaign **suspends raids** for its duration (an unscheduled raid mid-step reads as
  an unrelated FAIL) and restores the flag on finish.

## Bugs the campaign found before any player did

1. `GiveMoney` short-paid large sums (one `CreateItem` caps well below the ask) and the
   purse itself stops accepting created coin around 9–10k — now chunked and honest.
2. A coffer withdrawal above that cap **zeroed the coffer while short-paying the purse**
   — vanished money. Withdrawals are partial-and-honest now.
3. The follow-stall escalation originally fired on healthy men (fresh slot claims) and
   once suppressed the elected leader — now gated on a stale claim and never the leader;
   run 7 caught exactly one genuinely dead tree and self-healed it.
4. The stall watch judged wall-battle defenders (schedulers frozen by `wbLocked` stop
   slot stamps) and teleported 18 men off the palisade mid-siege — it stands down for
   the whole battle now.
5. Phase B once armed itself from `OnGameplayStarted` and auto-quit the player's OWN
   session whenever their newest save carried a torture stamp ("the mod keeps
   crashing"). It arms only from an explicit `merc_torture_auto` now; nothing in this
   framework runs un-asked.

## Reading a run

`[Torture] INFO` lines carry the measurements (funding received, archers deployed vs
wanted, max simultaneous pose-holds, bystanders on record). The bystander check is the
base-game-interaction test: every non-mod NPC within 100m is recorded before the staged
fight and must still be alive after it. `max simultaneous pose-holds` exercises the
sit/sleep→combat handoff when the fight catches the camp mid-rotation (run 1 saw 7, all
cleared; a camp that has just re-formed legitimately shows 0).

## The field plan (`-Plan field`)

The campaign tests the **camp**, with Henry pinned 16 m above it. The field plan tests
everything that only exists while he is **walking**, in one session with no save and no
reload:

```
powershell -ExecutionPolicy Bypass -File tools\torturetest.ps1 -Plan field -SaveFile save492.whs
```

Sixteen steps, in order: `field_sanity` (break any camp, force follow, default shape) ·
`follow_5` · `follow_12_shapes` (three shapes, 60 s each) · `follow_24` ·
`fight_mod_enemies_field` (8 bandits in the open) · `post_fight_reform` ·
`fight_base_enemies` (aggro only) · `camp_cycle` · `sortie_fight` · `camp_return_all` ·
`camp_break` · `patrol_pressure` · `raid_camp_make` · `raid_on_camp` · `raid_camp_break` ·
`field_health`.

**Henry walks.** Every field step carries `ground = true`, which makes `TortureKeepSafe`
skip the hoist for that step — god mode stays on, but position and facing belong to the
step. `TortureWalkTo` moves him `TortureWalkStep` (1.5 m, a walking pace) per 1 Hz tick
towards a point, z from `System.GetTerrainElevation` with the camp's own downward ray
(`CampSnapToGround`) and then the previous z as fallbacks; `TortureWalkRoute` follows a
polyline of those. The road is chosen **at runtime**: `PatrolRoutesForLevel` picks the
recorded network for whatever map the save is on, the route whose first point is nearest
Henry wins, and he takes **one** jump to its start and walks from there. The walk cursor is
deliberately not reset between steps, so `follow_5`, `follow_12_shapes` and `follow_24` keep
going down the same road.

**`TortureDrivesPlayer`.** A player moved by `SetWorldPos` has distance with no speed, which
is exactly what `MonitorMainQuestLoop`'s ghost-movement and instant-teleport checks look for
— so left alone, the mod's own fast-travel detector calls the whole walk a fast travel,
idles the squad, and the follow test measures a squad that was ordered to stand still. The
flag makes those two checks read false for the duration of a `ground` step. It is set and
cleared in one place (`TortureNext`, plus `TortureFinish`), and nothing in a player's game
ever sets it.

**Follow verdicts.** A walk passes only if all three hold: every man within 35 m at the end,
the mean distance over the last 30 s under 20 m, and nobody more than 80 m behind for longer
than 15 consecutive seconds. `follow_24` widens the two distance limits ×1.5 — twenty-four
men in a column are legitimately more strung out than five, and the test is "the tail keeps
up", not "the formation is small". Shape keys are read from `FormationShapeOrder`, never
spelled out: a preset name that no longer exists resolves to a null handle and silently drops
the squad onto the follow chain, which looks like a column and would quietly pass.

**Aggro arming.** `fight_base_enemies` is the base-game-NPC fight and uses the probe's
`provoke_test` mechanism (five mercs called onto the nearest non-mod NPC via
`ForcedTargetOf`). It runs **only** under `-Plan field_aggro`
(`merc_torture_field_aggro_auto`). On a save with civilians nearby it would attack a
civilian, which is why the arming is a separate command and never a heuristic — a heuristic
cannot tell a bandit from a miller. Unarmed it logs `[Torture] SKIP fight_base_enemies`,
which is neither a pass nor a fail and is counted separately in the summary. Meant for
`save492.whs`, where the nearest vanilla NPCs are bandits.

**`patrol_pressure`** is the "not overwhelming, not too frequent" test. It clears
`_patrolGraceUntil` and `_patrolQuietUntil` once (the post-load waits would eat the window)
but deliberately leaves the pacing clock running from then on — how long the road stays quiet
between gangs is the thing being measured. Henry stands on the chosen route ~350 m along it
and watches for 300 s: more than one live gang fails immediately, and a patrolman inside
`PatrolMinPlayerDist` **on the tick his gang spawned** fails immediately (a second later they
are walking towards him and any distance is legitimate). Then he jumps to a road point 700 m
away, and after 20 s every gang must be gone and, within a further 30 s, `PlayerBusyForSpawns`
must not answer "in combat" and `EnemyAlerted` must be false — the "the game still thinks I'm
in a fight" regression.

**The position log.** `TorturePosLog` writes, every 5 s during walking and fighting steps
(every 30 s during the patrol watch, where nothing moves):

```
[Torture] POS follow_12_line t=612 player=(1843.2,2210.7,301.4)
[Torture]   Mercenary_44821 (1839.9,2205.1,301.2) d=6.5m alive=true target=-
```

plus, during fights, one `POS <tag> enemies=<n>  <name> d=<m>, ...` line. The harness counts
these rather than reprinting them; the lines stay in kcd.log to be read there.

## Harness knobs added with the field plan

- **`-Plan campaign|field|field_aggro`** — `campaign` is the default and unchanged.
- **`-SaveFile save492.whs`** — name the save and the harness computes its main-menu
  position as its index in `%USERPROFILE%\Saved Games\kingdomcome2\saves\playline0` sorted
  by `LastWriteTime` **descending**. That newest-first order is the menu's own, and it is
  exactly why the documented `-DownsToSave` positions keep drifting: a completed campaign
  writes an autosave to the top of the list and pushes everything down one. After the load,
  kcd.log's `Loading saved game '...saveNNN.whs'` must name that file or the run aborts
  rather than testing the wrong world (generalised from the scenario path).
- **`-FieldTimeout 1500`** — how long to wait for `[Torture] COMPLETE`. The plan's own
  `TortureFieldDeadline` is 1440 s, deliberately just under it, so a plan that is running out
  of time is the one that says so: a truncated report beats no report.
- The report now prints the verdicts, then a **MEASUREMENTS (INFO)** block with every
  `[Torture] INFO` line, then a count of the `[Torture] POS` trace lines.

## The quest plan (`-Plan quest`)

The campaign tests the **camp** and the field plan tests **walking**. This one tests the
**Kleinkrieg contract arc** ([mercenaries_banditcamp_quest.lua](../data/Scripts/mods/mercenaries_banditcamp_quest.lua))
— and the three things about it that only exist **across a real save and a real relaunch**:

```
powershell -ExecutionPolicy Bypass -File tools\torturetest.ps1 -Plan quest -SaveFile save493.whs
```

Three stages in three game sessions, stamped into the save as `TortureStage = "Q1"|"Q2"|"Q3"`.
The harness types `merc_torture_quest_auto`, waits for `[Torture] SAVED - awaiting reload` or
`[Torture] COMPLETE`, and on SAVED verifies a save newer than the run start exists, relaunches,
presses Continue, re-arms `merc_dev` and types the same command again — at most four
relaunches. `TortureStartQuest` picks the stage off the stamp in the loaded save, so **one
command runs all three stages**; `TortureStart` was extended by one clause so a `Q…` stamp
under `merc_torture_auto` hands over here instead of starting a fresh camp campaign on top of a
live contract. Every save is the campaign's save step verbatim (ground Henry, stamp, then
`Game.SaveGameViaResting()` with `Game.QuickSave()` as the fallback), marked `awaitReload` so
`TortureNext` hands control to the harness mid-list instead of only at the end.

**The stages**

| Stage | Steps |
| --- | --- |
| Q1 (fresh) | `q_sanity` · `kk1_accept` · `kk1_approach` · `kk1_fight` · `kk1_letter_deliver` · `kk4_jump_accept` · `kk4_approach` · `kk4_fight` · `kk4_letter` · `kk4_deliver` · `kk10_accept` · `q1_save_Q2` |
| Q2 (after relaunch) | `q2_restore` · `kk10_approach` · `kk10_disperse` · `kk10_deliver` · `kk12_siege_accept` · `kk12_approach` · `kk12_hold` · `kk12_leave_field` · `q2_save_Q3` |
| Q3 (after relaunch) | `q3_siege_restore` · `q3_siege_rebuild` · `kk12_fight` · `kk12_deliver` · `alx_beat8_regression` · `alx_beat8_populated` · `quest_health` |

**What each regression protects**

- **`q2_restore`** — a patrol contract that survived a save must come back as a *contract*, not
  as a standing camp: `BCQ.active` true, `BCQ.site.name == "patrol_looters"`, **`spawned` false**,
  `BanditCampCleared() == 9`, and the `KKPhase` tag at least `cleared + 1` so the quartermaster's
  dialog gates and the counter have not drifted apart. Spawned NPCs never survive a save; what
  is saved is the `BCQuest` blob, and the camp is rebuilt on the first tick the player is back
  inside `BanditCampForgetRange` (300 m).
- **`kk10_disperse`** — the sheathed approach. `BanditCampService` wants a bandit within 8 m of
  the player, weapon sheathed, for four consecutive 1 Hz ticks. This is the **one** step of the
  plan that carries `ground = true`, so `TortureKeepSafe` skips the hoist and Henry walks in on
  `TortureWalkTo`. The squad is put on **hold** first: the disperse branch is gated on
  `not S.alerted`, and one merc claiming a looter turns the whole thing into a fight. **There is
  no sheathe call anywhere in the mod** — `player.human:IsWeaponDrawn()` is read in three places,
  `human:DrawWeapon()` exists, its inverse does not — so the step relies on a fresh load starting
  Henry sheathed (which is why this test lives in Q2, the first step after a relaunch) and reports
  the flag on every INFO line instead of pretending to control it.
- **`q3_siege_restore`** — the one this plan was written for. `RaborschOnLoad` resets
  `RBQ = {active=false}` on **every** load, because the siege's entities do not survive one while
  the contract does. The old code read that zero-man siege as a siege that had been *won* and
  completed contract 12 on the spot — a Raborsch paid out on the loading screen. The step holds
  30 s and fails loudly if `BCQ.cleared` ever latches, then `q3_siege_rebuild` walks back in and
  **records** (never judges) that the rebuilt siege comes back at *full* strength rather than as
  the remnant the player left — shipped behaviour, and the reason `TortureQSiege` is written into
  the save at the end of Q2: Q3 is a different session and plain Lua would not survive the load.
- **`alx_beat8_regression`** — the "castle is empty / objectives auto-complete on load" report.
  A beat-8 camp is raised at the Roman fort while the player stands *there*, 3.6 km from
  Raborsch, and for 90 s `AlxCamp.leaderNoted`, `AlxCamp.cleared` and the beat-8 down token
  (watched by wrapping `AlxSignalToken` for the step, unwrapped on every exit) must all stay
  false. At that range `System.GetEntity` hands back handles whose actor/soul proxies never
  streamed in and `IsAliveAndWell` reads them as dead — one tick and the whole beat closed with
  nobody having been near it. `AlxProgressRange` (250 m) is the fix and this is its test.
  `alx_beat8_populated` then jumps to Raborsch and requires the castle to actually be manned.

**Jumping the counter, and why it is legitimate.** Steps 6, 11 and 15 write `BCampDone`
directly (`3`, `9`, `11`) and call `BanditCampResync()` before accepting. `BCampDone` is the
**only** progress state the arc keeps: `BanditCampCleared()` reads it (through a one-shot cache
that `BanditCampResync` clears), `BanditCampAdvance()` writes it on payment, and
`KleinkriegContract()` picks the contract straight off it. There is no second bookkeeping to get
out of step with, which is exactly why `merc_banditcamp_reset` is nothing but
`SaveString('BCampDone','0')`. Contracts 1, 4, 10 and 12 are the four shapes the arc has —
letterless camp, letter-carrying road patrol, disperse-able looter column, siege — so the run
covers every path without fighting all thirteen.

**The Aleksej journal cannot be advanced from Lua.** The nine beats are opened by Skald from
dialogue; `AlxSpawnBeat(n)` is the only entry point on this side of the bridge and it raises the
*encounter*, not the journal entry. So beat 8 is tested at the encounter level — camp raised,
progress-gating observed, castle populated — and the journal half is out of scope for any
automated run.

**Fights.** Every contract gets the same body: hover onto the camp so the squad walks in, give
the men `TortureQuestFightSecs` (120 s) of a real fight while `TortureEnemyLog` traces every 5 s,
then INFO how many the men actually killed and bound the time with the `merc_clear_enemies`
lever (`CmdEnemyClear`). The verdict is `BCQ.cleared`, which is the contract's own, and it lags
the last death by up to `BanditCampMissingTicks` (5) polls — hence the 60 s grace. `CmdClearPrefixes`
covers `SpawnedEnemy_`/`SpawnedRenegade_`/`SpawnedPatrol_`/`SpawnedPatrolman_` only, so anything a
camp adopted late under another name (tower and cart archers, which
`BanditCampAdoptTowerArchers` adds to the target) survives the lever; 30 s on, a roster backstop
removes whatever is left and says so as a **FINDING** in the INFO line rather than failing.

**Teleports.** All thirteen sites are on Kuttenberg and up to 3.6 km apart, so the plan jumps.
A jump lands **200 m** from `BanditCampSiteAnchor(site)` — inside the 300 m spawn range, well
outside the 50 m `BanditCampDespawnRange` — and the monitor builds the camp; the squad closes on
its own catch-up and the distance goes out as INFO. Landing points are **recorded road points**
(`PatrolRoutesForLevel` / `PatrolRoutesKuttenberg`), for the reason `TortureFarRoutePoint` gives:
recorded routes are ground the author actually rode, while a bearing-and-distance guess lands in
lakes and off cliffs. `TortureQuestJump` moves `S.anchor` with Henry, because `TortureKeepSafe`
re-asserts `S.anchor + TortureHover` every tick and would otherwise haul him back on the next
one. Every step's `qReset` sets `TortureDrivesPlayer` — the plan drives Henry whether or not the
step is `ground`, and without it the mod's own fast-travel detector reads each jump as a fast
travel and idles the squad, which is the same trap the field plan hit.

**Hand-ins** walk off the field first (past `BanditCampDespawnRange`, or the paid contract never
closes out), then check three things: `BanditCampCleared()` advanced by exactly one, `BCQ.active`
false, and the purse up by exactly `BCQ.reward` — `GiveMoney` is chunked and honest, so a short
pay is either the ~10k purse ceiling (bug 1 above) or a real regression, and the FAIL reason says
so with the purse in it. The letter path (`kk4_letter`) reports **how** the letter arrived —
looted, via `BanditCampGrantLetterFallback()`, or via the direct grant behind
`merc_banditcamp_give_letter` when the fallback declines because `letterOnLeader` is set and a
hovering tester will never loot a body. All three are findings in the INFO line; only "no letter
at all", which makes the contract uncompletable, is a failure.

**Harness knobs**: `-QuestTimeout 1500` (per stage; the plan's own `TortureQuestDeadline` is
1440, deliberately just under it) and `-QuestMaxRelaunches 4`. The report is the same one every
plan gets, and it now reads **every** `LogBackups` file written since the run began rather than
just the newest — four relaunches rotate `kcd.log` four times, and only the last two stages
would otherwise survive into the report.

## Nothing is fired by an F-key any more

A run typed `merc_dev` and `merc_torture_bindkeys`, logged `dev binds applied`, tapped F8 —
and **nothing happened**, not one `[Torture]` line. The game's own bindings shadow the
F-keys (autobench's `-ConsoleCmd` was added for the same reason: "videofhotomode et al. own
F-keys"). Worse: the plan is what arms god mode, so a trigger that silently does nothing
leaves Henry standing unprotected in the open, and that run killed him. Two fixes:

- The harness **types** every trigger through `Send-ConsoleCmd` — `merc_torture_auto` for
  phase A *and* for phase B (`TortureStart` dispatches on the save's stage stamp),
  `merc_torture_probe`/`_aggro` for the scenario probe, `merc_torture_field_auto`/
  `merc_torture_field_aggro_auto` for the field plan. `Arm-TortureKeys` is now
  `Arm-DevCommands` and runs only `merc_dev`; `merc_torture_bindkeys` stays registered in
  Lua for manual use but nothing automated depends on it. `Start-Torture` proves each one
  took by waiting for the plan's own banner, retypes once, then fails **loudly** rather than
  sitting out an 800 s timeout on a run that never began.
- `TortureStart` / `TortureStartProbe` / `TortureStartField` arm god mode (and the hoist,
  where the plan hovers) in `TortureArmSafety` **immediately**, before the first tick. The
  worst a dead trigger can cost now is time.

## `steam_appid.txt`

Launched directly rather than through Steam, the game quits during init with
`CSystem::Quit ... reason: Steam Service Quit - not started through Steam` unless
`steam_appid.txt` (content `1771300`) sits beside the exe in
`Bin\Win64MasterMasterSteamPGO\`. It had only ever been created by hand on one machine, so a
fresh checkout on a new PC saw the game exit before the main menu with nothing in the log to
explain it. Both harnesses now write it if it is missing and say so. (`+exec user.cfg` on the
launch line is optional — the engine shrugs at a `user.cfg` that does not exist.)

## Results, 2026-09-02 (the notebook rig, ~15 fps)

Three plans ran unattended on the weak notebook in one afternoon; everything below is read
straight from `[Torture]` lines and the mod's own log, not inferred.

**Field plan** (save492, aggro) - 14 PASS / 2 FAIL on the first pass; both FAILs were the
test's own doing and are fixed (the base-game fight walked away from the only bandits, and
"gang still alive" was a *new* legal spawn at the destination, not the one left behind).
Measured: following at 5 / 12 (three shapes) / 24 men - mean distance 6.9 / 6.8-10.3 / 14.7 m,
worst man ever 26.5 m, never beyond 80 m, zero stalls in 1746 sampled positions; 8 bandits
down in 36 s in the open, squad back inside 35 m one second after; camp of 96 props pitched
and cleared to zero; a 12-man sortie beat 6 bandits and returned; one patrol gang in a 300 s
window, spawned at 389 m for a 25-strong party, never a second one; a 14-raider assault on an
unwalled field camp resolved in 74 s with 24 defenders intact. Zero script errors.

**Quest plan** (save489 -> three sessions, two real saves and relaunches) - **28/28 PASS**:
contract 1 fought and won by seven men in 74 s (no lever needed), contract 4's road patrol
with its letter, the contract-10 disperse (Henry walked in sheathed, they scattered), the
Raborsch siege (9 foot + 4 archers vs a squad of 6, 14 garrison archers), the deliberate
mid-siege save, and the two regressions this plan exists for: **a mid-siege reload no longer
completes the contract on the spot**, and **Aleksej's beat 8 opened from the Roman fort
(3.6 km) stays open** - no "leader down", no cleared camp - with the castle populated on
arrival.

### Bugs the runs found (all fixed in the same session)

- Patrol gangs were sized off the **payroll**, so a player leaving the squad in camp met the
  16-man ceiling alone; now sized off the men actually with him (`BanditCampFollowerCount`).
- Contract letters could be lost for good: the fallback grant defers while the letter is on
  the leader's body and nothing ever noticed the body going away -> hand-in refused for ever.
  The service tick now grants it once the body has been gone for the missing-handle grace.
- `GiveMoney` looped on a float purse (275 minted read back 274.99, one more pass minted a
  0.01 fraction) and the test floored it to "274 of 275". Half-a-coin tolerance on both.
- The scheduler watchdog logged a false "strike 1" every 5 s - a second poller in the same
  window, proven by the instrumented `tick=/lastSeen=` line - and could therefore never reach
  strike 2. It now ignores a poll that arrives within 2.5 s of the previous one.

### What the harness learned about this build

- **No god mode exists for the player.** `god` is unknown, `GameRules.SetInvulnerability`
  errors, and the only `SetInvulnerability` in the Lua state is on breakable props. Henry
  died twice before this was understood - once because a plan never started (F8 shadowed by
  the game's own bindings, so nothing armed) and once hovering "16 m up" above a site whose
  cached z is 15 m below the real road. Now: max health 50 000 refilled every tick, hover
  measured from the real terrain, and every trigger typed into the console.
- `steam_appid.txt` beside the exe is per-PC; the main-menu keystroke recipe can silently do
  nothing right after a session that ended via `quit` (a retry worked; `tools/Screenshot-
  Game.ps1` exists to look at the menu when it does not).
