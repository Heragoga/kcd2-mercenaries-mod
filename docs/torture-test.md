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
started by **F8** / `merc_torture_auto` (bound in `OnGameplayStarted` like the bench
keys). A step machine on a 1s tick: each step `run`s once (heavy setup calls staggered
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
save by time, i.e. the one just written. The harness then presses **F8 again**;
`TortureStart` sees the stage stamp in the loaded save and runs the phase-B checks
instead of a fresh campaign (arming is exclusively the keybind — see bug 5 below):
camp restored,
squad and out-party counts intact, and **every station tile within 1m of its saved
position** — the "upgrades shuffle around after a reload" regression, tested against real
persistence. It self-validates: the stamp only exists in the right save, so resuming a
wrong one shows as a timeout, never a false pass.

## The scenario probe (F7 / F6)

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

`banditcamp` is armed **aggro** (F6, `merc_torture_probe_aggro`): non-mod NPCs there are
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
   crashing"). It arms only from F8 now; nothing in this framework runs un-asked.

## Reading a run

`[Torture] INFO` lines carry the measurements (funding received, archers deployed vs
wanted, max simultaneous pose-holds, bystanders on record). The bystander check is the
base-game-interaction test: every non-mod NPC within 100m is recorded before the staged
fight and must still be alive after it. `max simultaneous pose-holds` exercises the
sit/sleep→combat handoff when the fight catches the camp mid-rotation (run 1 saw 7, all
cleared; a camp that has just re-formed legitimately shows 0).
