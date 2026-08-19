# Combat target selection

How mercs (and archers) decide who to fight. All of this lives in [mercenaries_target_selection.lua](../data/Scripts/mods/mercenaries_target_selection.lua) and is driven from the schedulers (`mercenary_scheduler.xml`, `archer_scheduler.xml`).

## The shared-scan architecture

The soul API (relationship, script-context, alive checks) is expensive, so it runs **once for the whole squad**, not once per merc per candidate:

- **`UpdateEnemyCache`** (called every 300 ms from `CombatScanLoop`) does a single `EnemyScanRadius` (18 m, up from 15) box query around the player, runs every candidate through `IsValidEnemy`, and stores the survivors in `mercenaries.CachedEnemies`. NPCs are queried every tick; animals (`Wolf`/`Dog`) every 3rd (~0.9 s); orphan-horse cleanup (despawn `MercenaryHorse_*` whose owner is dead/missing) every 9th (~2.7 s). It lives on its own timer rather than in `MonitorLoop` because this cadence *is* the squad's reaction time — the behaviour trees only ever see what this pass left behind.
- **`ScanForEnemies`** (per-merc, each BT tick) reads the pre-validated `CachedEnemies` and re-sorts by distance from *this* merc using cheap math only — no soul API calls. It caps the list to the **8 nearest** candidates, because each one the BT then examines costs an engine `GetTarget` call.

Reaction time end to end is one cache tick (≤300 ms) plus one scheduler tick (300 ms ±100 ms), so roughly 0.2–0.7 s from a hostile entering range to the mercs firing their attack interrupt.

## Anti-swarm cap

Every merc's current target is recorded in `MercTargetOf`. Once per second `UpdateEnemyCache` rebuilds `TargetLoad` (a target-WUID → count map) from it, so each merc's per-tick swarm check is a plain O(1) lookup instead of a position scan. `TryClaimTarget` refuses a target already at the cap, spreading the squad across enemies instead of dogpiling one.

**The cap is elastic, and `SwarmCap` (2) is only its floor.** As a hard limit it produced "there's always one just standing there": `PickCombatTarget` has no at-cap fallback (unlike the enemy side's `FindEnemyTarget`, which falls back to `candidates[1]`), so any merc past the *2 × enemies* mark found every candidate full and never engaged for the whole fight. `UpdateEnemyCache` now recomputes `EffectiveSwarmCap = clamp(ceil(MercCount / #CachedEnemies), SwarmCap, SwarmCapMax)` each pass — 5 mercs vs 2 enemies gives 3 and everyone fights; 20 vs 1 gives 4 and sixteen stay in formation.

**Self-defence bypasses the cap entirely.** In `EvaluateCombatTarget`, a candidate whose target is *this merc* is claimed with `force`, because refusing it leaves a merc standing still while someone swings at him. Defending the *player* still respects the cap — spreading out makes sense there.

**Ghost claims are pruned.** The claim tables are released by the combat modules' `OnFail`, which does not run when an NPC simply dies or streams out. Since the load maps are rebuilt from the claim tables every pass, a dead claimer's entry permanently ate a cap slot until the cap quietly stopped binding. `PruneCombatClaims` (from `LowPriorityMonitorLoop`, deliberately *outside* the `ActiveMercs` gate so ambushes and patrols are covered) sweeps `EnemyTargetOf`/`ForcedTargetOf` using `EnemyClaimWuid`, which exists solely to keep the **raw** WUID — the table's string key cannot be handed back to `GetEntityByWUID`. On the merc side `PruneMercCache` releases a knocked-out merc's claim while keeping his roster slot.

## What counts as a valid enemy (`IsValidEnemy`)

A candidate must be: not the player or the companion dog; alive and conscious; weapon drawn; not one of ours (regular-merc soul, archer soul, or custom hero companion); and not fleeing/surrendering/immortal (`combat_flee`, `combat_surrender`, `crime_interruptFlee`, `crime_fleeAfterSurrender`, `combat_immortalityProtection`).

**The relationship rule (the important one):** hostility requires the candidate's relationship to the player to be pinned at exactly **−1**, the faction-hostile floor (see `FactionTree__mercenaries.xml`, where `enemiesFaction`'s player/mercs relations are `reputation="-1"`). Anything above that — 0, 0.5, or unresolved/nil — is **not** treated as fair game. "Merely not a confirmed friend" was the old bug that made mercs attack armed-but-unrelated NPCs like guards and hunters.

Two gates can be waived individually:

- **`skipRelationshipCheck`** — for whoever the player is *already* fighting (`playerCombatTarget`): active aggression against the player is itself proof of hostility, and can come from crime/quest triggers that never resolve to a clean faction −1.
- **`skipWeaponCheck`** — used when building the cache, so hostiles who haven't drawn yet still land in `CachedEnemies` (flagged `armed = false`) and are targeted like any other. An enemy sizing the player up decides who to kill before it unsheathes, and waiting for the sheathe animation was most of the "why are my mercs just standing there" delay. The `armed` flag survives only so the logistics tick can tell a fight in progress from a hostile merely standing nearby.

## Acquisition: always on, two passes

There is no combat stance. Every merc and archer runs the same rule every scheduler tick, whenever it isn't already in combat. Both passes bail only if the merc already has a target, and both go through `TryClaimTarget` — the anti-swarm cap applies to everything *except* the self-defence claim described above. **Health is not a factor** — see "Fighting to the death" below.

1. **`EvaluateCombatTarget`** — the lock-on pass. The BT walks `enemiesArray` (nearest first, breaking as soon as one is claimed), asks the engine `GetTarget` for each candidate, and claims anyone whose target is **the player or this merc**. This is what makes the squad move the instant an enemy picks its victim, rather than when the first blow lands.
2. **`PickCombatTarget`** — the fallback. Takes whoever the player is fighting (`playerCombatTarget`), else the nearest cached hostile.

### Exactly one gate may be waived per path — never both

This is the rule that keeps the squad both responsive and sane, and breaking it produces two very different bugs:

| Path | Waives | Still demands | Why |
|---|---|---|---|
| pass 1, and the nearest-hostile sweep | drawn weapon | relationship = −1 | −1 is already proof of hostility. Waiting for the unsheathe animation on top of it meant the squad never moved until someone had been hit — both `GetTarget` paths only resolve *after* somebody commits to a fight, so this sweep is the only trigger that can fire early. |
| `playerCombatTarget` | relationship | drawn weapon | The player may pick a fight with anyone, so relationship can't apply. But `GetTarget` on the player hands back whoever he happens to be looking at, so without the drawn-weapon proof the squad charges villagers and parks in a permanent combat state (engine NPC state reads "running towards battle", which also blocks dialogue). |

`playerCombatTarget` additionally has to pass `IsWithinAggroRange` — the player's lock-on reaches far past the 20 m follow leash, and a merc sent that far just gets pulled back, re-acquires, and never arrives.

The intended consequence of the first row is that mercs will start a fight with a faction-hostile NPC merely standing within `EnemyScanRadius`. That is the "always aggro" behaviour, not a bug.

## Fighting to the death

Nothing on the player's side breaks off combat over health. `UpdateMeleeCombatData` disengages only on distance/orders, and `UpdateRangedCombatData`'s health flee (≤12 HP) is gated to `side ~= "friend"`, so enemy archers still run but ours don't. There is no `IsHealthCritical` gate on acquisition either.

This was the old behaviour and it read badly: a merc below the threshold dropped its target, sheathed, and trailed the player around unarmed in the middle of a fight — then died anyway, because disengaging in melee doesn't stop anyone hitting you.

`idleTicks` in both schedulers had the same symptom from a different cause. Acquisition is gated on `~inCombat`, so `playerTarget` is null on every tick of a fight — meaning `idleTicks` climbed *during* combat and hit its sheathe-and-relax threshold mid-swing. It is now gated on `~$inCombat` as well, so it only counts genuine idleness. The 20 m follow leash, not `idleTicks`, is what rescues a merc stuck chasing something unreachable.

`playerCombatTarget` is filled by a single `GetTarget` node on the player — once per merc, not once per candidate. The per-candidate `GetTarget` calls in pass 1 are why `ScanForEnemies` caps at 8; they only cost anything when hostiles are actually cached, i.e. in a fight.

The one exception is the archers' **hold** order (`ArcherStance` = hold), which skips acquisition entirely — "hold your fire" would be meaningless otherwise. Skirmish and melee only choose which combat behaviour the interrupt fires.

## Enemy groups (the test enemies)

The six enemy groups (looters, bandits, Sigismund's soldiers, Prague regiment, Cumans, Sigismund's knights) replaced the old single "renegade" enemy. Full guide: [enemies.md](enemies.md). Wiring lives in [mercenaries_spawning.lua](../data/Scripts/mods/mercenaries_spawning.lua) (`SpawnEnemyGroup` / `EquipEnemy`) plus `enemy_melee_scheduler.xml` / `combat_melee.xml` (melee) and `enemy_archer_scheduler.xml` / `combat_archer_dynamic.xml` (archers — a copy of the friendly `combat_archer_dynamic.xml`). They borrow the merc outfit/weapon preset tables, so any merc gear works on them.

`FindEnemyTarget` (once/sec, 50 m) is the mirror of the merc target picker, and — unlike the old renegades, who fought everyone — it is **restricted to the player and the player's side**: only the player and entities named `SpawnedFriend_*` / `MercenaryCustomCompanion*` are candidates. Vanilla NPCs and other spawned enemies are never targeted, so the groups ignore the world and each other. It keeps the same restraints: (1) a separate anti-swarm pool (`EnemyTargetOf` / `EnemyTargetLoad`, cap `EnemySwarmCap`) kept apart from the mercs' pool, falling back to ganging up when everything is at cap, and (2) **holding** a live target for the whole approach.

That second point is not a tuning preference. It used to hold the target only within `EnemyTargetStickRange` (5 m), so for every second of every approach it fell through and re-picked the nearest man instead. In a crowded fight the nearest man keeps changing, which changes `currentTarget`, which trips `enemy_melee_scheduler`'s `$currentTarget ~= $firedTarget` re-fire — and a re-fire **replaces** the running combat and runs its `OnFail`, so the fighter restarts his approach about once a second. That is what made a significant share of the Kleinkrieg convoy close in visible steps. The target is now held out to `EnemyTargetHoldRange` (60 m) and dropped only when he is dead, unreachable or walled off, so `currentTarget` changes for legitimate reasons only — a forced re-point, a death, or a wall — and each of those *should* re-fire. The merc side never had this bug because `mercenary_scheduler` gates acquisition on `~$inCombat`; enemies have no such gate, because encounters need to re-point them mid-fight.

**Never force `DrawWeapon()` after spawning a combat NPC.** `combat_melee.xml` / `combat_archer_dynamic.xml`'s automation decorators own weapon draw once combat starts; forcing it manually races the entity's just-spawned init and can leave it stuck — the likely cause of enemies that spawn and never react. (Archers that spawned and just *stood there* had a different cause: the first attempt drove them with a melee `CombatFollowerDecorator` + missile lock, so they closed distance but never fired — fixed by copying the real stand-and-fire `combat_archer_dynamic` tree.)
