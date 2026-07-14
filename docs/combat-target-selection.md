# Combat target selection

How mercs (and archers) decide who to fight. All of this lives in [mercenaries_target_selection.lua](../data/Scripts/mods/mercenaries_target_selection.lua) and is driven from the schedulers (`mercenary_scheduler.xml`, `archer_scheduler.xml`).

## The one-scan-per-second architecture

The soul API (relationship, script-context, alive checks) is expensive, so it runs **once per second for the whole squad**, not once per merc per candidate:

- **`UpdateEnemyCache`** (called once/sec from `MonitorLoop`) does a single 15 m sphere query around the player, runs every candidate through `IsValidEnemy`, and stores the survivors in `mercenaries.CachedEnemies`. NPCs are queried every tick; animals (`Wolf`/`Dog`) every 3rd tick — they don't need per-second precision. This pass also does orphan-horse cleanup (despawn `MercenaryHorse_*` whose owner is dead/missing).
- **`ScanForEnemies`** (per-merc, each second, from the BT) reads the pre-validated `CachedEnemies` and re-sorts by distance from *this* merc using cheap math only — no soul API calls. It caps the list to the **8 nearest** candidates, because each one the BT then examines costs an engine `GetTarget` call.

## Anti-swarm cap

Every merc's current target is recorded in `MercTargetOf`. Once per second `UpdateEnemyCache` rebuilds `TargetLoad` (a target-WUID → count map) from it, so each merc's per-tick swarm check is a plain O(1) lookup instead of a position scan. `TryClaimTarget` refuses a target already at `SwarmCap` attackers, spreading the squad across enemies instead of dogpiling one.

## What counts as a valid enemy (`IsValidEnemy`)

A candidate must be: not the player or the companion dog; alive and conscious; **weapon drawn**; not one of ours (regular-merc soul, archer soul, or custom hero companion); and not fleeing/surrendering/immortal (`combat_flee`, `combat_surrender`, `crime_interruptFlee`, `crime_fleeAfterSurrender`, `combat_immortalityProtection`).

**The relationship rule (the important one):** hostility requires the candidate's relationship to the player to be pinned at exactly **−1**, the faction-hostile floor (see `FactionTree__renegades.xml`, where every relation is `reputation="-1"`). Anything above that — 0, 0.5, or unresolved/nil — is **not** treated as fair game. "Merely not a confirmed friend" was the old bug that made mercs attack armed-but-unrelated NPCs like guards and hunters.

**`skipRelationshipCheck`** bypasses only that one gate for whoever the player is *already* fighting (`playerCombatTarget`): active aggression against the player is itself proof of hostility, and can come from crime/quest triggers that never resolve to a clean faction −1. Every other check still applies.

## The stance pickers

The player's squad stance (`_G.MercStance` / `GetStanceCode`) selects which picker the scheduler runs. All three first bail if the merc already has a target or is health-critical (`IsHealthCritical`, ≤25 HP — hurt mercs look after themselves).

| Stance | Function | Behaviour |
|---|---|---|
| everyone | `PickNearestValidTarget` | The player's current combat target first (claimed regardless of relationship), else the nearest strictly-hostile cached enemy. |
| player_target | `PickPlayersTarget` | Only join whatever the player is currently fighting. |
| defend | `EvaluateCombatTarget` | Only fight back at a candidate personally targeting this merc. The only stance that walks `enemiesArray` and asks the engine who each candidate targets (hence the 8-cap). |

`playerCombatTarget` is filled by a single `GetTarget` node on the player — once per merc, not once per candidate.

## Renegades (the test enemy)

Renegades are a separate hostile-to-everyone NPC type used for combat testing (`SpawnRenegade` / `SpawnTestBattle` in [mercenaries_spawning.lua](../data/Scripts/mods/mercenaries_spawning.lua); wiring in `renegade_scheduler.xml` / `renegade_attack.xml`, see [add-new-npc](xml/add-new-npc.md) and [make-npc-brain](xml/make-npc-brain.md)). They borrow the merc outfit/weapon preset tables, so any merc gear works on them; `GetRenegadeOutfitFor` keeps them looking distinct from the current squad.

`FindRenegadeTarget` (once/sec) is **indiscriminate**: any living NPC or the player within 50 m, no faction filtering. Its only restraints are (1) a separate anti-swarm pool (`RenegadeTargetOf` / `RenegadeTargetLoad`, cap `RenegadeSwarmCap`) — kept apart from the mercs' pool since the two claim against different targets — falling back to ganging up when everything is at cap, and (2) sticking with a live target within `RenegadeTargetStickRange` instead of re-rolling each tick. Renegades skip themselves and other renegades.

**Never force `DrawWeapon()` after spawning a combat NPC.** `renegade_attack.xml`'s automation decorators own weapon draw once combat starts; forcing it manually races the entity's just-spawned init and can leave it stuck — the likely cause of renegades that spawn and never react.
