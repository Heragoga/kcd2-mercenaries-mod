# Round 4: what to test next

Written 2026-09-04, after the console-quoting fix. Ordered by *what is most likely to be
broken*, not by feature area.

The headline: **the console hands `%line` to Lua already quoted**, so `Func('%line')` received
`"yes"` — five characters, not three. That silently broke **30 of the 38 commands that take an
argument**. They have never worked with arguments in any released build. Everything in part 1
is therefore untested, not retested.

---

## Part 1: the commands that never worked (30 min, highest value)

Ten boolean switches evaluated `tonumber('"0"') ~= 0`, which is `nil ~= 0`, which is **true** —
so every one could be turned on and never off.

```
merc_horses 0            then merc_horses 1
merc_roster_nosave 0     then 1
merc_encounters 0        then 1
merc_travel_stow 0       then 1
merc_status_icons 0      then 1
merc_mqstash 0           then 1
merc_roster 0            then 1
merc_formprobe 0 / merc_travelprobe 0
```

Each must log the *off* state. Before this fix, none of them could.

**The one that matters most:**

```
merc_hire 12
```

`CmdHire` read `tonumber(CmdArgs(line)[1]) or 5`, and the quoted argument made that `nil` —
so **every `merc_hire <n>` has silently hired 5**. Check the count. Then the same for
`merc_hire_weak`, `merc_hire_strong`, `merc_hire_archers`, and `merc_composition`.

Exact-name lookups were broken the same way and are fixed:

```
merc_difficulty hard
merc_upkeep harsh
merc_outfit <name>
```

Confirmation gates now accept the argument (this is what made the purges look dead):

```
merc_purge_items yes
```

---

## Part 2: things fixed but never seen working

| # | What | How to confirm |
|---|---|---|
| 1 | **The groschen short-pay fix.** `CreateItem` mints a coin *stack*, so the fractional last chunk rounded to zero and every hand-in paid one short. | Hand in one Kleinkrieg contract; purse must rise by exactly the stated reward |
| 2 | **The purge set actually removing things.** Never once run to completion — the gate ate every attempt. | `merc_save_audit`, then `merc_purge_props yes`, then audit again |
| 3 | **The phantom-death guard on purge.** Removing the company must NOT log `Morale 0 -> -50 (N merc death(s))`. | Run `merc_purge_npcs yes` with men hired and watch the log |
| 4 | **The scheduler timer-chain fix.** Named timers get restored from saves, so watchdogs multiplied one per load. | Load the same save three times in one session; `master tick armed ... epoch N` once per load |
| 5 | **Camp with a stowed company.** Men return around the player, not where they stood. | Stow with a camp up, unstow, see what happens |

---

## Part 3: whole areas never tested

* **Combat.** Base-game enemies especially: engage, win, loot, re-form — and does combat
  actually *end* (music stops, sheathe, fast travel possible)?
* **Gear.** 17 outfits; Skalitz at all three tiers after a reload and a fight; the custom
  uniform with a mod item in the chest.
* **Camp raids** with a wall up — do they march a gate, do towers and carts man themselves.
* **The Kleinkrieg chain** end to end with a reload mid-contract (carries part 2 item 1).
* **Aleksej's arc and Raborsch** — only ever exercised by the automated runs.
* **Kuttenberg performance** at 0 / 10 / 25 men.
* **Release hygiene** — `merc_help` accuracy, no dev commands without `-devmode`, a
  non-English language pass.

---

## Known and not being fixed

* **Mercenaries are invisible in scripted battles.** Soul membership is the render gate
  (quest-override-battles.md). The battle CVar profile was tested and ruled out
  (`merc_battlecvar all` changed nothing). The automatic stash is
  [shelved](malesov-test.md#shelved-2026-09-04); `merc_mqstash_now` is the manual answer.
* **Uninstalled saves load slowly.** [Closed with a negative result](save-footprint.md#closed-2026-09-04-the-entity-footprint-is-not-the-load-time-cost)
  — not entity residue; the table patches and quest graphs are unreachable from Lua.
* **Skalitz tier 3 has no chest piece** in the authored spec. Needs a decision, not a fix.
* **`merc_clear_enemies` may trigger a respawn.** Unconfirmed; avoid near an active contract.
