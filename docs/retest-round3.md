# Retest, round 3

> **Test 1 is settled.** The travel detector was rewritten and is confirmed working on both
> an on-foot and a mounted crossing, with the company stowed and all five men put back each
> time. See [travel-detection.md](travel-detection.md) for the measurements. The rest of this
> page stands.

Round 2 confirmed the forge and bench survive a reload, and the patrol day cap holds. Those
are done. This round is the five things it found broken, plus the roster that replaces the
uninstall command.

One command shows every proof line after a session:

```bash
grep -E "Roster|stowed|put back|travel stow|still growing|world IS running|MQWatch|rider limit|big company" "C:/Program Files (x86)/Steam/steamapps/common/KingdomComeDeliverance2/kcd.log"
```

---

## 1. Fast travel takes the company with it (10 min)

Hire five men, then fast travel across the map.

- **Pass:** the men vanish as the crossing starts and are standing around you when it ends,
  all five, following. The log shows `[Roster] 5 man/men stowed` then `5 of 5 man/men put back`.
- **Fail:** any man missing on arrival, or a man standing still afterwards.
- Sleep 8 hours in a bed. Same thing: stowed, then put back.
- **Watch for a false trigger.** Gallop hard on a horse for two minutes. Nothing should be
  stowed: riding moves the player at zero Henry-speed exactly as a crossing does, so the
  world clock has to agree before anything is stowed, and a gallop does not move the clock.

Why the earlier attempts failed, and what the probe measured, is in
[travel-detection.md](travel-detection.md). Short version: an on-foot crossing produces **no
position jump at all**, so no movement-based detector could ever have seen it. The world
clock running several times its normal rate is the signal that catches both cases.

## 2. Fifty men assemble (10 min)

`merc_hire_army_big`, wait for the hiring to finish, then `merc_form_line` and walk 300 m.

- **Pass:** the line assembles and holds. The log shows
  `the squad is still growing ... holding the rebuild until it settles` a few times during the
  hire, and then one rebuild at the end.
- **Fail:** `STALL SpawnedFriend_archer_*` repeating, or men standing about.

Why it failed: hiring fifty men one at a time crosses six formation size boundaries, and each
crossing re-deals every slot. For an archer that is fatal rather than untidy, because the
engine formation is his only locomotion, so a man dropped mid-rebuild simply stops. Your log
had 104 archer stalls against 2 for foot. The rebuild now waits for the count to settle, and
the repair pass no longer stands down when half the company is stranded but the world is
plainly running.

## 3. Mounting works again (5 min)

Hire 40 men, get on a horse.

- **Pass:** they mount up.

The 30-rider cap I added in round 2 is now off by default - it was a worse cure than the
disease. `merc_horses_max 30` brings it back if the riderless-horse behaviour at fifty returns.

## 4. Hiring during Malesov (10 min)

Take the company into the assault, and hire more men mid-battle.

- **Pass:** the new men join the ones waiting out the battle rather than appearing in it. The
  log shows the stash line.
- Also confirm the stash itself fired at all: `[MQWatch] MAIN-QUEST BATTLE detected` and
  `men sent 400m out of the battle`. If those never appear, run `merc_mqwatch` during the
  fight and send me the output.

## 5. The roster, by hand (10 min) - do this before test 6

With ten men standing: `merc_stow`, then `merc_unstow`.

- **Pass:** they vanish, then all ten come back around you and follow. `merc_roster_report`
  prints the count before and after.
- Then save, reload, and check the count is right.

This is the mechanism the save fix depends on, so it has to be watched working first.

## 6. The save fix (15 min) - only after 5 passes

This is your design: the men stop being NPCs in the save and become a list that is rebuilt.

1. `merc_roster_nosave 1`.
2. Hire ten men **after** typing that - it only applies to men hired from then on.
3. Save. Reload.

- **Pass:** the ten are there, `[Roster] load: 0 man/men were in the world, roster says 10 -
  put 10 back`. They will be around you, not where they stood.
- Then remove the mod folder and load that save. **Pass:** it loads at the speed of a save the
  mod never touched, no white pyramids, no generic townsmen.
- **Known limitation to check:** do this once with a camp up. The men will re-form on you and
  have to walk back to camp. If that is unacceptable, say so and I will make the roster
  remember where each man stood.

`merc_roster_nosave 0` turns it off; men hired after that are saved as NPCs again.

---

## Still open

- **One groschen short on every contract hand-in.** Not touched yet.
- **Mercs invisible inside scripted battles.** Not fixable from Lua. Test 4 checks the
  workaround.
- **Timer chains across loads.** Load one save three times in a session and check that
  `master tick armed ... epoch N` appears once per load.
