# Manual test plan

The automated torture campaigns take 25-40 minutes per plan, need a devmode launch, and judge
a scenario from log lines rather than from what is on screen - so they miss anything visual
(an upgrade standing inside a tent, a merc in the wrong livery) and they call a scenario
"passed" when the log said the right words. This list is the hand-run replacement.

**How to use it.** Every test is one thing that can break, the shortest way to reach it, and
what a pass looks like. Run section 0 before every release. Run the section that covers
whatever you just changed. Run the whole list before a version bump.

Timings assume the notebook (~15 fps). Roughly: section 0 is 15 minutes, sections 1-6 about
two hours, section 7 (quests) another two, sections 8-10 half an hour.

## Before you start

1. `PackageMod.bat` - builds and installs `mercenaries.pak`.
2. Keep three saves and never overwrite them:
   - **CLEAN** - made before the mod was ever loaded. The uninstall test needs it.
   - **BENCH** - mod loaded, company of ~10, no camp, out in the open near Rattay.
   - **CAMP** - mod loaded, camp pitched with several upgrades bought.
3. Console is the tilde key. The ~100 player commands work in any launch. Commands marked
   **dev** need `-devmode` on the launch and `merc_dev` typed once per session.
4. When something fails, note the step, keep the save, and copy `kcd.log` out of the game
   folder before relaunching - it is overwritten on every launch.

---

## 0. Smoke test - 15 minutes, before every release

- [ ] Load BENCH. No error spam in the first 10 seconds of `kcd.log`.
- [ ] `merc_status` - the count matches the men standing around you.
- [ ] `merc_hire 5`, then walk 200 m. All five follow, none teleports, none is left behind.
- [ ] `merc_form_line`, `merc_form_wedge`, `merc_form_column` - the shape visibly changes.
- [ ] `merc_spawn_bandit 6` - the company engages, wins, and re-forms without an order.
- [ ] `merc_camp_make` - camp goes up, nothing intersects anything, quartermaster is there.
- [ ] Save, load that save, wait 30 s - camp is still there, same layout, men still yours.
- [ ] `merc_camp_break`, fast travel somewhere, `merc_status` - count unchanged.
- [ ] No F-key does anything (test 1.1).

---

## 1. Regression - the seven reported bugs

### 1.1 No keybinds in a release build

Tap F1 through F12 in a normal (non-devmode) launch with the mod loaded.

**Pass:** nothing mod-related happens on any of them. Photo mode and the vanilla bindings
behave exactly as they do without the mod.

### 1.2 Mercs vanishing during a main quest

Load a save just before a scripted main-quest battle (Malesov, Suchdol, the Kuttenberg
assault - any of the twelve). Take 8-10 men in, fight it through, and watch the company
across the whole cutscene-to-battle transition.

**Pass:** every man is visible for the whole fight, or is deliberately taken away and comes
back after - never invisible-but-fighting, never gone for good. `merc_status` after the quest
reports the same count as before it.

### 1.3 Patrols during fast travel and sleep

With `merc_patrols 1`: fast travel across the map three times, then sleep 8 hours in a bed.

**Pass:** no patrol gang spawns during the travel or the sleep, and none is standing on top of
you when you arrive or wake. A gang appearing a minute later on the road is correct.

### 1.4 Camp layout overlap

`merc_camp_make` on four different grounds: flat field, a slope, near trees, near a road. Buy
three or four upgrades from the quartermaster each time. Walk the whole camp.

**Pass:** no tent inside another tent, no upgrade inside a tent, nothing floating or sunk into
the ground, and you can walk between them. Note the ground type if one fails.

### 1.5 The "too many men" line

Hire to the cap (`merc_hire_army_big`), then try to hire one more from the quartermaster.

**Pass:** the refusal reads "You have too many men already! The company is full." It must not
name a number, and must not say five.

### 1.6 Camp upgrades after a reload

From CAMP: note where every upgrade stands (screenshot it). Save. Reload. Wait a full minute -
the forge and alchemy bench are allowed to arrive late, up to about 60 s.

**Pass:** every upgrade is standing, each in the same spot as the screenshot. Repeat once more
from that reloaded save; twice in a row is where this used to break. Then buy one new upgrade:
pass means the ones already up do not move.

### 1.7 Uninstall and load time

This is a measurement, not a yes/no. See [save-footprint.md](save-footprint.md).

1. Time a load of CLEAN with the mod folder removed. Write the seconds down.
2. Load CAMP, run `merc_save_audit` (read-only), write the numbers down, save as UNINSTALL-A.
3. `merc_purge_world yes`, save as UNINSTALL-B. Then `merc_purge_savers yes`, save as UNINSTALL-C.
4. Remove the mod folder. Time a load of A, then B, then C.

**Pass:** C loads within a couple of seconds of CLEAN. Which of A, B, C drops the time tells
you which residue costs the minute - that is the point of the exercise.

---

## 2. Squad basics

- [ ] **Counts.** Follow with 1, 5, 12 and 24 men over 300 m of mixed terrain, including a gate
      and a bridge. Pass: nobody is stuck on scenery, nobody is more than ~30 m behind.
- [ ] **All seven formations** (`merc_form_*`) at 12 men: column, line, square, wedge, circle,
      escort, vanilla. Pass: each is visibly a different shape and holds while moving.
- [ ] **Formation modes.** `merc_form_keepshape` against `merc_form_relaxed` against
      `merc_form_movehistory` through a wood. Pass: keepshape stays rigid, movehistory walks
      your footsteps, neither drops a man.
- [ ] **Mounted.** Ride at a gallop for 500 m with `merc_horses 1`. Pass: they keep up and the
      formation still reads as a formation. Then `merc_horses 0`: they march on foot.
- [ ] **Orders.** `merc_wait`, walk 100 m, `merc_follow` - they come. `merc_hold` in a fight:
      they hold the ground and do not chase. `merc_escort` on an NPC: they escort it.
- [ ] **Stances.** `merc_stance_defend` next to a hostile: they do not open the fight.
      `merc_stance_attack`: they do. `merc_stance_holdfire` with archers under fire: they hold.
- [ ] **Dismiss.** `merc_dismiss` - everyone leaves, `merc_status` reports none, and no leftover
      NPC is standing about a minute later.

## 3. Combat

- [ ] **Mod enemies.** `merc_spawn_bandit 10` at 12 men. Pass: the company engages without an
      order, wins, loots (mercs wander the bodies for ~30 s), then re-forms on you unasked.
- [ ] **Base-game enemies.** Find a vanilla bandit camp or a road ambush. Pass: the same
      behaviour against enemies the mod did not spawn. This is the case the automated harness
      was weakest at, so watch it closely.
- [ ] **Each enemy group** - bandit, looter, sigismund, knight, prague, cuman, ruthenian. Pass:
      each spawns, is hostile, wears its own gear, and dies properly.
- [ ] **Set-piece.** `merc_battle 20 knight 6 45`. Pass: two lines form, archers behind, the
      fight resolves, survivors follow you home.
- [ ] **Archers.** `merc_hire_archers 6`, then each of `merc_archer_skirmish`, `_melee`,
      `_hold`. Pass: skirmishers fall back while shooting, melee closes, hold stands. No archer
      shoots a friendly in the back at point-blank.
- [ ] **Loot sweep.** After a fight, `merc_loot`. Pass: the men visibly rummage.
      `merc_loot_stop` ends it. Bodies stay lootable by you afterwards, and a body you already
      looted does not become lootable again after a reload.
- [ ] **No stuck-in-combat.** After every fight above, wait 60 s. Pass: the combat music stops,
      you can sheathe, sit, and fast travel. Being stuck in a fight with nothing alive nearby is
      a fail - note which fight caused it.

## 4. Camp

- [ ] **Pitch and strike** three times in different places. Pass: `merc_camp_make` builds,
      `merc_camp_break` removes everything with no leftovers.
- [ ] **Deploy.** `merc_camp_deploy_all`, `merc_camp_deploy_half`, `merc_camp_return_all`,
      `merc_camp_recall`. Pass: the right men come and go; the camp keeps standing on recall.
- [ ] **Party composition.** `merc_camp_party` with no argument lists the options; set two or
      three of them and deploy. Pass: the party you get matches the option you set.
- [ ] **Upgrades.** Buy every one of the eleven over a few sessions. Pass: each stands, works
      (forge and bench are usable, tavern and yard show activity), and survives a reload.
- [ ] **Take one down.** `merc_camp_remove` with no argument lists them; remove one. Pass: only
      that one goes, nothing else moves, and it stays gone after a reload.
- [ ] **Gates and walls.** `merc_gate_open` and `merc_gate_close` with a wall built. Pass: gates
      work, and the wall and gates come back correct after a reload.
- [ ] **Raid on camp.** `merc_raid_bandit 12` with a camp up, then `merc_raid_now`. Pass: they
      march on a gate rather than through the wall; the defence turns out; towers and archer
      carts are manned.

## 5. Patrols and encounters

- [ ] **Never two gangs.** `merc_patrols 1`, ride a road for 15 minutes. Pass: at no moment are
      two patrol gangs alive at once.
- [ ] **Distance.** Pass: a gang is never spawned inside your view. You should always meet one
      by riding up to it, never watch it appear.
- [ ] **Despawn cleanly.** Ride away from a gang until it despawns. Pass: no combat state left
      behind, no bodies frozen in the air, and you are not stuck in a fight.
- [ ] **Frequency by difficulty.** `merc_difficulty easy` against `impossible`, 10 minutes each.
      Pass: noticeably fewer gangs on easy. Neither is overwhelming for a 10-man company.
- [ ] **Off means off.** `merc_patrols 0` and `merc_encounters 0`, ride 15 minutes. Pass:
      nothing mod-spawned appears at all.

## 6. Gear

- [ ] **All 17 outfits.** `merc_outfit 1` through `17` at 6 men, looking at them each time.
      Pass: each is visibly a different livery; nobody is naked, part-dressed, or in the generic
      set when you asked for something else.
- [ ] **Skalitz specifically** (`merc_outfit 6`) - the one that was reverting to generic. Pass:
      the House of Kobyla livery is on every man at all three tiers (hire weak, seasoned and
      veterans and look at all three), and it is still there after a reload and after a fight.
- [ ] **Weapon loadouts.** Each `merc_weapon_*`. Pass: the weapon is drawn and used, and a
      polearm renders on the back rather than vanishing.
- [ ] **Custom uniform with modded items** - `merc_gear_open`, put a full set in the chest
      including at least one item added by this mod, then `merc_gear_apply`. Pass: the whole
      company wears that set, mod items included; `merc_gear_clear` forgets it; the uniform
      survives a reload.
- [ ] **Empty pattern.** Apply with an empty chest. Pass: the documented behaviour (naked with a
      sword), not a crash or a half-dressed squad.

## 7. Quests - the long ones

Run these on their own save, and reload mid-chain at least once in each.

- [ ] **Kleinkrieg, the whole chain.** Take contracts from the quartermaster through all
      thirteen. For each: the marker leads to the camp, the camp is populated, clearing it
      completes the objective, and the hand-in pays.
- [ ] **The letter.** On a contract that puts the letter on the leader: kill the leader, wait,
      and check your pack. Pass: you have the letter within ~20 s even if the body falls
      somewhere unreachable or despawns.
- [ ] **The purse.** Note your money before and after each hand-in. Pass: the purse rises by
      exactly the stated reward. See "Known issues" below - it is currently one groschen short
      every time.
- [ ] **Reload mid-contract.** Save with a camp half-cleared, reload. Pass: the objective and
      the enemies are as you left them, and the contract still completes.
- [ ] **Siege contract.** Pass: the siege stands at full strength after a reload, the fight
      resolves, and leaving the field does not complete it early.
- [ ] **Raborsch.** `merc_raborsch` raises it, `merc_raborsch_clear` strikes it. Play the quest
      end. Pass: the castle is populated when it should be, objectives do not auto-complete on
      load, and "find Aleksej" points at Aleksej.
- [ ] **Aleksej's arc, beats 1-9.** Pass: each beat's camp is populated when you arrive, the
      beat only advances on the dialogue that should advance it, and beat 8's siege turns on you
      when the company comes close.

## 8. Persistence

- [ ] **The three-load test.** In one session, load the same save three times in a row without
      quitting. Watch the company and the camp after each. Pass: behaviour is identical on load
      1, 2 and 3 - no doubling of anything, no growing stutter. This is the test for the
      duplicate-timer bug in "Known issues".
- [ ] **Save matrix.** Save and reload with: men following, men waiting, camp up, camp up with
      upgrades, a contract active, a fight just finished. Pass: each state comes back as it was.
- [ ] **Cold relaunch.** Quit to desktop, relaunch, load. Pass: the same as a warm reload.
- [ ] **Two saves in one session.** Load save A, then save B, without quitting. Pass: hiring,
      camp and orders all still work under B. This used to kill the mod outright.

## 9. Performance

- [ ] **Kuttenberg.** Ride into the city with 0, then 10, then 25 men. Note the fps each time.
      Pass: the drop is gradual. A cliff between 0 and 10 is the texture-pool problem, not
      per-merc cost - see [performance.md](performance.md).
- [ ] **Big battle.** `merc_battle 30 cuman 10 45`. Pass: it is playable, and fps recovers after
      the fight.
- [ ] **Fast travel.** Travel with 25 men several times. Pass: no lag spike on arrival that was
      not there before, and every man is with you.

## 10. Release hygiene

- [ ] `merc_help` lists only player commands, and every one it lists exists.
- [ ] Without `-devmode`, `merc_dev` refuses. No bench or torture command is reachable.
- [ ] `kcd.log` in a normal 10-minute session has no `[Error]`, no `nil value`, and no stack
      traceback from a `mercenaries_*` file.
- [ ] Play 10 minutes in a non-English language. Pass: no raw string keys on screen in anything
      the mod added.
- [ ] Uninstall cleanly (test 1.7) and load CLEAN. Pass: no mod content, no errors.

---

## Fixed after the 2026-09-03 hand run - re-test these first

- [ ] **Forge and alchemy bench after a reload.** Pitch camp well away from any village, buy
      both, save, reload, wait a full minute at the camp. Pass: both stand and stay. The log
      shows `[Camp] CampForgeHome found at the camp ... its home is the saved` on the reload and
      no `torn down` line until you break camp. Then break camp and visit the village: its
      smithy and alchemy table are back where they belong.
- [ ] **Patrols and fast travel.** `merc_patrols 1`, fast travel across the map. Pass: no gang
      on arrival; the log shows `[Patrol] the player jumped ...m / ...h between two ticks`.
      Then ride for a full day. Pass: at most two gangs, and `gang 2 of 2 for today` followed by
      `the road stays quiet until tomorrow` in the log. `merc_patrols_perday` reports the count.
- [ ] **Fifty men in a line.** `merc_hire_army_big`, `merc_form_line`, walk 300 m. Pass: the
      whole line follows; the log shows `[LodBoost] big company - AI Detail 70 -> 260 (AI half
      only ...)` once, and no `30 of 50 merc(s) flagged at once`.
- [ ] **Riders.** With 50 men mounted, `merc_status`. Pass: they march on foot and the log says
      `past the 30-rider limit`. `merc_horses_max 0` lifts it if you want the old behaviour.
- [ ] **Malesov.** Play the assault with the company. Pass: on the first wave the log shows
      `[MQWatch] ... men sent 400m out of the battle` and the men are gone from the field; after
      the battle `brought back to the player and following`. If it does NOT trigger, paste the
      `merc_mqwatch` output - the detector needs the engine's Battle context, and that is the
      unproven part. `merc_mqstash 0` turns it off.

## Known issues to confirm by hand

These came out of the last automated runs and are worth checking first, because a fix is either
pending or unverified.

**Every contract hand-in pays one groschen short.** Four hand-ins across three sessions, each
short by exactly 1 (reward 275, purse 0 to 274). The money is minted in chunks and the purse is
read back as a float, so the last fraction never lands. Cosmetic, but real and reproducible:
note the exact before and after on the next hand-in you do.

**Timer chains multiply across loads in one session.** Sessions that loaded the previous
session's save ran one, then two, then three copies of the scheduler's watchdog - the engine
appears to write pending *named* timers into the save and restore them on load. The scheduler
now stamps each chain with an identity token and retires any chain that is not the current one,
and that fix is **not yet verified in game**. The three-load test in section 8 is the check:
`[MercSched] ... chain retired` in the log is expected, once per stale chain, while
`master tick armed ... epoch N` appearing more than once per load is a fail.

**Skalitz tier 3 has no chest piece** in the authored spec. Confirm that is intended - a veteran
in Kobyla livery with no chest armour would look wrong.

**`merc_clear_enemies` can trigger a respawn** when it removes a quest camp's leader. Use it
away from an active contract until that is confirmed either way.
