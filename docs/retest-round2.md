# Retest, round 2

What the first hand run (2026-09-03) already proved good is not here: camp pitch and break,
sorties, formations at small counts, F-keys, the "too many men" line, camp overlap.

**Part A** is the five fixes made after that run, plus two things still unverified. About 45
minutes. **Part B** is what the run never reached, because it stopped early. Run A first.

Each item names the log line that proves it. After a session, one command shows all of them:

```bash
grep -E "CampForgeHome|CampAlchemyHome|torn down|jumped .*between two ticks|for today|stays quiet until tomorrow|big company - AI Detail|rider limit|MQWatch|chain retired|master tick armed" "C:/Program Files (x86)/Steam/steamapps/common/KingdomComeDeliverance2/kcd.log"
```

`kcd.log` is overwritten on every launch. Copy it out before relaunching.

---

## Part A - the fixes

### A1. Forge and alchemy bench survive a reload (10 min)

Pitch camp **well away from any village**. Buy the smithy and the alchemy bench. Save. Reload.
Stand at the camp for a full minute.

- **Pass:** both stand and stay. On the reload the log says `found at the camp ... its home is
  the saved`, and there is no `torn down` line until you break camp.
- **Fail:** any `[CampForge] torn down` or `[CampAlchemy] torn down` while you are at camp.
- Then break camp and ride to the village that owns them. Its smithy and alchemy table must be
  back in place, bottles included.

Also pitch a camp **next to a village** once. Expect `the village smithy is within reach of the
camp - it will not be packed on approach`, and no flicker.

### A2. Patrols: fast travel and the day cap (15 min)

`merc_patrols 1`, then fast travel across the map.

- **Pass:** nothing spawns on arrival, and the log shows
  `the player jumped ...m / ...h between two ticks`.

Then ride a full in-game day.

- **Pass:** at most two gangs. The log shows `gang 1 of 2 for today`, `gang 2 of 2 for today`,
  then `the road stays quiet until tomorrow`.
- `merc_patrols_perday` with no argument reports the cap and today's count.
- Sleep 8 hours in a bed. Nothing may spawn on waking; the jump line should appear again.

### A3. Fifty men follow (10 min)

`merc_hire_army_big`, `merc_form_line`, walk 300 m over open ground.

- **Pass:** the whole line follows. The log shows `big company - AI Detail 70 -> 260 (AI half
  only, renderer untouched)` once.
- **Fail:** `30 of 50 merc(s) flagged at once` returns, or men stand about.
- Mount up with those 50. **Pass:** they stay on foot and the log says
  `past the 30-rider limit`. No riderless horses. `merc_horses_max 50` lifts it if you want to
  see the old behaviour for comparison.

### A4. Malesov - the battle stash (10 min, the one most likely to fail)

Load before the assault, take the company in.

- **Pass:** at the first wave the log shows `[MQWatch] MAIN-QUEST BATTLE detected` and
  `men sent 400m out of the battle`; the field is clear of your men; after it ends,
  `brought back to the player and following`.
- **If nothing happens:** type `merc_mqwatch` during the fight and send me that output. The
  detector needs the engine's own Battle context on the player, and that is the unproven half.
- `merc_mqstash 0` turns it off.
- Save mid-battle and reload once. **Pass:** the men come back within a minute, or the battle
  is re-detected and they stay out.

### A5. Timer chains across loads (5 min)

Load the same save **three times in one session**, no quitting.

- **Pass:** `master tick armed ... epoch N` appears exactly once per load, and any
  `chain retired` lines are one-offs.
- **Fail:** epochs climbing during a single load, or repeated `master tick stalled twice`.

### A6. Uninstall, done properly (10 min)

The 2:30 load was a camp save with the folder removed but no uninstall run - white pyramids are
missing prop classes, generic townsmen are merc souls falling back. Redo it in order:

1. Load the camp save with the mod installed. `merc_save_audit`, note the numbers.
2. `merc_uninstall yes`. Save as a new slot.
3. Remove the mod folder, load that save, time it.

- **Pass:** loads in about the same time as a save the mod never touched, no white pyramids.
- If it is still slow, use `merc_purge_world yes` and `merc_purge_savers yes` as separate saves
  to see which stage drops the time. Compare against a **late-game** save without the mod, not
  the 1-minute early one.

---

## Part B - never reached in round 1

### B1. Combat (15 min)

`merc_spawn_bandit 10` at 12 men, then a vanilla bandit camp or road ambush.

- **Pass:** they engage unasked, win, loot for ~30 s, re-form on you. After each fight, wait
  60 s: the combat music stops and you can sheathe and fast travel. Being stuck "in a fight"
  with nothing alive is the failure to watch for.

### B2. Gear (10 min)

`merc_outfit 6` at 6 men of mixed tiers - this is the Skalitz livery that was reverting.

- **Pass:** House of Kobyla colours on every man, at all three tiers, still there after a
  reload and after a fight.
- Then `merc_gear_open`, put a set in the chest **including one mod-added item**,
  `merc_gear_apply`. **Pass:** the whole company wears it, mod item included, and it survives a
  reload.

### B3. Camp raid (10 min)

With a camp and a wall up: `merc_raid_bandit 12`.

- **Pass:** they march on a gate rather than through the wall, the defence turns out, towers
  and carts are manned.

### B4. One Kleinkrieg contract (20 min)

Take one contract, clear the camp, hand it in, with a save and reload in the middle.

- **Pass:** the marker leads to a populated camp, clearing it completes the objective, the
  reload does not change the state, and the hand-in pays.
- **Known open bug:** the purse rises by one groschen less than the reward, every time. Not yet
  fixed. Note the exact numbers so we can confirm it is still the float truncation and nothing
  worse.

---

## Still open, not fixed

- **One groschen short on every contract hand-in.** Cosmetic, reproducible, B4 measures it.
- **Mercs invisible inside scripted battles.** Not fixable from Lua - soul membership is the
  render gate. A4 tests the workaround, not a fix.
