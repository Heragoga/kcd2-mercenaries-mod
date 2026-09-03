# What is left: open bugs and unrun tests

State as of 2026-09-03, after the formation/travel/roster work. Everything not listed here
has either been fixed and confirmed in play, or was never reported.

---

## Fixed in code, never yet seen working

These shipped and nothing has exercised them. Each is a real risk of being wrong.

| # | Thing | How to confirm |
|---|---|---|
| 1 | **The groschen short-pay fix.** `CreateItem` mints a coin *stack*, so the final fractional chunk rounded to zero coins and every hand-in paid one short. The request is now rounded up. | Hand in one Kleinkrieg contract. Purse must rise by exactly the stated reward. |
| 2 | **The Malesov battle stash.** The watchdog teleports the company out of a recognised main-quest battle and brings them back. Never once seen to fire - it needs the engine's own Battle context on the player. | Take the company into the assault. Look for `[MQWatch] MAIN-QUEST BATTLE detected` and `men sent 400m out of the battle`. If nothing, run `merc_mqwatch` during the fight. |
| 3 | **Hiring during a stashed battle.** New hires join the men waiting it out instead of appearing in the battle. Depends entirely on 2. | Hire mid-battle, check they arrive with the others. |
| 4 | **The scheduler timer-chain fix.** Named timers get restored from saves, so watchdogs multiplied one per load. Each chain now carries an identity token and retires when stale. | Load the same save three times in one session. `master tick armed ... epoch N` must appear once per load; `chain retired` lines are expected. |
| 5 | **The roster by hand.** `merc_stow` / `merc_unstow`. This is the mechanism the save fix rests on. | Ten men, stow, unstow, all ten return and follow. `merc_roster_report` before and after. |
| 6 | ~~**The save-footprint switch**~~ **CONFIRMED WORKING for mercenaries.** `[Roster] load: the engine restored 0 merc(s); the roster says 10` - `bSaved_by_game=false` *is* honoured for spawned NPCs. But an uninstalled load was still slow, so the men were never the cost. The purge scanned 4 of the 16 classes the mod spawns into; `mercenaries_Prop` (the white pyramids) was in none of them. Fixed, and split into surgical stages. | Bisect with `merc_purge_props yes` first - see [save-footprint.md](save-footprint.md#the-measurement-to-run-now) |
| 7 | **Camp with a stowed company.** Known limitation, never tested: men come back around the player, not where they stood, so a camp full of men re-forms on the player and walks home. | Do 6 once with a camp up. If that is unacceptable the roster can remember each man's position. |

---

## Known and not fixed

* **Mercs are invisible inside scripted main-quest battles.** Not fixable from Lua - soul
  membership is the render gate (docs/quest-override-battles.md). Items 2 and 3 are the
  workaround, not a cure.
* **Skalitz tier 3 has no chest piece** in the authored spec. Needs a decision, not a fix: a
  veteran in Kobyla livery with no chest armour looks wrong.
* **`merc_clear_enemies` may trigger a respawn** when it removes a quest camp's leader.
  Unconfirmed either way; avoid it near an active contract.
* **The line's `Relaxed` mode is a judgement, not a measurement.** Line shapes no longer hold
  rigid geometry so the ends can lag a turn. `merc_form_keepshape` pins the old behaviour if
  it reads worse by eye.
* **`TravelStaminaMinSpeed` and `CIRCLE_PLAYER_AHEAD` are estimates.** The first is anchored
  to the generic AI movement table rather than a real upgraded horse; the second is
  CrimeFollower's own follow standoff, which the mod does not set. Both are single constants
  and both have a probe (`merc_travelprobe`, and the circle by eye).

---

## Whole areas never tested this round

The hand runs went deep on travel, formations and camp. These were in the round-2 plan and
never reached:

* **Combat.** Mod enemies and, more importantly, *base-game* enemies - engage, win, loot,
  re-form. Plus the one that bites: after every fight, does combat actually end (music stops,
  you can sheathe and fast travel)?
* **Gear.** All 17 outfits; Skalitz at all three tiers after a reload and a fight; the custom
  uniform with a mod-added item in the chest.
* **Camp raids** with a wall up - do they march on a gate, do towers and carts man themselves.
* **The Kleinkrieg chain** end to end, with a reload mid-contract. Item 1 rides on this.
* **Aleksej's arc and Raborsch**, which were only ever exercised by the automated runs.
* **Performance in Kuttenberg** at 0 / 10 / 25 men, and a big battle.
* **Release hygiene** - `merc_help` accuracy, no dev commands without `-devmode`, a
  non-English language pass, a clean uninstall.

---

## Suggested order

1. Item 5, then 6 and 7 - the save footprint is the last of the seven original bugs still
   unproven, and 5 is a two-minute check that gates it.
2. Item 4 - three loads, five minutes.
3. Item 1 alongside the Kleinkrieg run.
4. Items 2 and 3 next time a main-quest battle comes up naturally.
5. The untested areas, in the round-2 plan's own order.
