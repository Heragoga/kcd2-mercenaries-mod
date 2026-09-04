# What is left

State as of 2026-09-04, after the full Kleinkrieg playthrough. Everything not here is either
confirmed working in play or has never been reported.

## Fixed today, not yet re-tested by hand

| # | Thing | Check |
|---|---|---|
| 1 | **Small-company relief** for Raborsch and the marsh. Solo now faces 7 besiegers instead of 12; the marsh loses its 1.4x health multiplier. A company of 8+ is unchanged. | Run beat 8 and 9 with 0-2 men |
| 2 | **Aleksej kept and adopted across a load** (same cure as the beat leader, which is confirmed). | Reload near his lodging: `ADOPTED the saved Aleksej` |
| 3 | **30 console commands that never accepted an argument** (console quoting). Includes `merc_hire <n>`, which always hired 5, and ten switches that could be turned on but never off. | `merc_hire 12`, `merc_horses 0`, `merc_difficulty hard` |
| 4 | **2,358 modded armour items** now slot-classified for the wardrobe. | `merc_outfit_matrix`, walk the rows |
| 5 | **Groschen short-pay**, phantom deaths on purge, the purge set itself. | Hand in a contract; `merc_purge_npcs yes` must not log a morale drop |

## Known and not being fixed

* **Mercs are invisible in scripted main-quest battles.** Soul membership is the render gate.
  The battle CVar profile was tested and ruled out. Automatic detection is
  [shelved](malesov-test.md#shelved-2026-09-04) - `merc_mqstash_now` is the manual answer.
* **`ShowMapMarker` never renders on a Lua-spawned NPC** (Aleksej's tipster). Clean negative:
  he is present at wake and the gate is always-on. Objective-log markers on the same NPCs work.
* **Uninstalled saves load slowly.** [Closed, negative result](save-footprint.md#closed-2026-09-04-the-entity-footprint-is-not-the-load-time-cost) -
  not entity residue; the table patches and quest graphs are unreachable from Lua.
* **Skalitz tier 3 has no chest piece.** Needs a design decision, not a fix.
* **`merc_clear_enemies` may trigger a respawn.** Unconfirmed; avoid near an active contract.

## Never tested

* **Combat** against base-game enemies - and whether combat actually *ends* afterwards
  (music stops, sheathe, fast travel).
* **Gear**: all 17 outfits, Skalitz at three tiers after a reload, the custom uniform.
* **Camp raids** with a wall up; **Kuttenberg performance** at 0 / 10 / 25 men.
* **Release hygiene**: `merc_help` accuracy, no dev commands without `-devmode`, a
  non-English pass, a clean uninstall.

## Suggested order

1. Items 1-3 above (30 minutes, and item 3 is the interface to everything else).
2. Combat and "does combat end" - the biggest untested surface.
3. Release hygiene, last.
