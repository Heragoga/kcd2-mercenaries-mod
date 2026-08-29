# Combat target selection

How mercs (and archers) decide who to fight. All of this lives in [mercenaries_target_selection.lua](../data/Scripts/mods/mercenaries_target_selection.lua) and is driven from the schedulers (`mercenary_scheduler.xml`, `archer_scheduler.xml`).

## The shared-scan architecture

The soul API (relationship, script-context, alive checks) is expensive, so it runs **once for the whole squad**, not once per merc per candidate:

- **`UpdateEnemyCache`** (called every 300 ms from `CombatScanLoop`) does a single `EnemyScanRadius` (18 m, up from 15) box query around the player, runs every candidate through `IsValidEnemy`, and stores the survivors in `mercenaries.CachedEnemies`. NPCs are queried every tick; animals (`Wolf`/`Dog`) every 3rd (~0.9 s); orphan-horse cleanup (despawn `MercenaryHorse_*` whose owner is dead/missing) every 9th (~2.7 s). It lives on its own timer rather than in `MonitorLoop` because this cadence *is* the squad's reaction time — the behaviour trees only ever see what this pass left behind.
- **`ScanForEnemies`** (per-merc, each BT tick) reads the pre-validated `CachedEnemies` and re-sorts by distance from *this* merc using cheap math only — no soul API calls. It caps the list to the **8 nearest** candidates, because each one the BT then examines costs an engine `GetTarget` call.

Reaction time end to end is one cache tick (≤300 ms) plus one scheduler tick (300 ms ±100 ms), so roughly 0.2–0.7 s from a hostile entering range to the mercs firing their attack interrupt.

## Anti-swarm cap

Every merc's current target is recorded in `MercTargetOf`, and `TargetLoad` (a target-WUID → count map) counts the claims on each enemy, so each merc's per-tick swarm check is a plain O(1) lookup instead of a position scan. `TryClaimTarget` refuses a target already at the cap, spreading the squad across enemies instead of dogpiling one.

**Write both tables only through `MercSetClaim` / `MercDropClaim`.** They keep the count in step as claims are made and released, and that is load-bearing rather than tidy. `TargetLoad` used to be rebuilt only in `UpdateEnemyCache`, once per 300 ms pass, and `TryClaimTarget` never touched it — so **every merc evaluating inside one window judged the cap against the same stale snapshot**, which breaks twice over: they all pile onto the same nearest man because to each of them he still reads as empty, and the *next* snapshot then shows him — and, as the pile-on spreads, most of the field — far over cap, so whoever did not get a fight is refused every target there is. Symptoms are a small percentage of the squad never engaging at all, and a much larger group **flapping**: a merc whose target dies is refused a replacement, sheathes, and is handed one again a tick later. `UpdateEnemyCache` still recounts from scratch each pass, but as a resync, not as the source of truth.

**The cap is elastic, and `SwarmCap` (2) is only its floor.** As a hard limit it produced "there's always one just standing there": any merc past the *2 × enemies* mark found every candidate full and never engaged for the whole fight. `UpdateEnemyCache` recomputes `EffectiveSwarmCap = clamp(ceil(MercCount / #CachedEnemies), SwarmCap, SwarmCapMax)` each pass — 5 mercs vs 2 enemies gives 3 and everyone fights; 20 vs 1 gives 4 and sixteen stay in formation.

**`PickCombatTarget` has an at-cap fallback** behind that (the enemy side's `FindEnemyTarget` always had one — it falls back to `candidates[1]`). If nothing is under `EffectiveSwarmCap` it force-claims the nearest candidate anyway, bounded two ways, and both bounds are the design rather than caution:

- **`SwarmCapHard` still stands.** It is the "fifty men must not all mob three bandits" stop, and against a handful of enemies `EffectiveSwarmCap` has already risen to meet it — no headroom, nothing spills over, the surplus keeps formation exactly as before. In a real battle the cap sits at two to four while the hard stop is ten, and that gap is precisely the relief this needs.
- **`SwarmOverflowRange` (18 m).** A benched merc standing inside the melee doing nothing is the bug; a man forty metres back down the column is the design. Distance tells the two apart without needing to know which case it is.

`force` bypasses the soft cap only. The hold leash and the static-archer rule inside `TryClaimTarget` are checked before it, so this can never pull a man off his station.

**Self-defence bypasses the cap entirely.** In `EvaluateCombatTarget`, a candidate whose target is *this merc* is claimed with `force`, because refusing it leaves a merc standing still while someone swings at him. Defending the *player* still respects the cap — spreading out makes sense there.

**Ghost claims are pruned.** The claim tables are released by the combat modules' `OnFail`, which does not run when an NPC simply dies or streams out — so a dead claimer's entry permanently ate a cap slot until the cap quietly stopped binding. `PruneCombatClaims` (from `LowPriorityMonitorLoop`, deliberately *outside* the `ActiveMercs` gate so ambushes and patrols are covered) sweeps both sides:

- enemies, via `EnemyTargetOf`/`ForcedTargetOf` keyed off `EnemyClaimWuid`, which exists solely to keep the **raw** WUID — the tables' string keys cannot be handed back to `GetEntityByWUID`;
- mercs, via `MercTargetOf`, whose keys have the same problem, so the live set is built from `ActiveMercs` instead. A merc **killed** holding a claim never runs his `OnFail`, so his entry sat there for the rest of the session benching a living man. The target side of that table needs no sweep of its own: a claim on a dead enemy is released by the `OnFail` of the merc holding it, and that merc is alive by construction.

`PruneMercCache` releases a knocked-out merc's claim on the spot, while keeping his roster slot.

### Sieges raise the ceiling, they do not pin the cap

The siege of Raborsch used to overwrite `EffectiveSwarmCap` with a flat `RaborschSwarmCap` (6)
every second for the whole battle. That is the elastic cap switched off and replaced by a hard
limit — in the one fight with the most mercs and the fewest reachable enemies, i.e. exactly the
"any merc past the cap found every candidate full and never engaged" failure described above,
reintroduced where it hurts most.

It now raises the formula's **ceiling** instead (`RaborschRaiseSwarmCeiling`: `SwarmCapMax` 4 → 10,
`SwarmCapHard` 10 → 20) and lets `UpdateEnemyCache` keep computing the cap from squad size against
visible enemies. Against a thin line the company commits properly; against one straggler it still
will not send all fifty. Both are saved and restored when the siege is struck, because they are
global tunables the rest of the game keeps using.

Two range bugs went with it:

- **`RaborschAlertRange` was 10 m, measured off the player alone.** A company could be standing
  among the besiegers with the siege still asleep, because the only body the check cared about was
  fifty metres back — the same "wrong body's position" defect as the walled-camp formation gate.
  `RaborschMonitor` now watches the player *and every merc*, off the `PerfPos` cache, and the range
  is 60 — `EnemyAlertRadius`, so the siege goes live at exactly the range an alerted squad can
  already acquire targets.

  Be precise about what `SiegePeace` withholds, because it is **not** every besieger:
  `SiegeSuppressed` only covers entities in `StaticArchers` (the tower and cart archers). Foot
  besiegers live in `BanditCampActors`, and the gate that reads that table only inspects the two
  bandit-camp-quest slots — never `RBQ` — so a foot besieger inside the ordinary `EnemyScanRadius`
  can be engaged before the alert fires. What the alert actually buys is the archers coming off
  hold-fire, the forced targets, and the wide radius and ceiling. Still the difference between a
  battle and a trickle; not a total embargo.

  The trigger has **no line-of-sight test** — wall gating is deliberately off during a siege
  (`NavTargetBlocked`'s `RBQ` early-out,
  [mercenaries_navmesh.lua:891](../data/Scripts/mods/mercenaries_navmesh.lua)) — so it can fire
  through terrain. Acceptable only because `RaborschMonitor` runs at all only while the siege is
  already set up and staged for its quest beat, so there is no "wandered past by accident" case.
- **The leash clamp silently defeated its own floor.** `MeleePlayerLeash` applied the
  `EnemyAlertRadius` floor and *then* clamped to `MeleePlayerLeashMax` (70). Harmless while the
  floor sits under the Max — and wrong the moment a siege pushes `EnemyAlertRadius` to 160: the
  floor computed 160 and the next line cut it to 70, so the squad acquired targets out to 160 m
  while being forbidden to walk past 70. That is the draw/sheathe loop the floor exists to
  prevent. The Max bounds the *squad-size scaling*, never the acquisition floor, so it now clamps
  first and floors second. `MeleeTargetLeash` (flat 70, same defect) is read through
  `MeleeTargetLeashNow()` for the same reason.

## What counts as a valid enemy (`IsValidEnemy`)

A candidate must be: not the player or the companion dog; alive and conscious; weapon drawn; not one of ours (regular-merc soul, archer soul, or custom hero companion); and not fleeing/surrendering/immortal (`combat_flee`, `combat_surrender`, `crime_interruptFlee`, `crime_fleeAfterSurrender`, `combat_immortalityProtection`).

**The relationship rule (the important one):** hostility requires the candidate's relationship to the player to be pinned at exactly **−1**, the faction-hostile floor (see `FactionTree__mercenaries.xml`, where `enemiesFaction`'s player/mercs relations are `reputation="-1"`). Anything above that — 0, 0.5, or unresolved/nil — is **not** treated as fair game. "Merely not a confirmed friend" was the old bug that made mercs attack armed-but-unrelated NPCs like guards and hunters.

Two gates can be waived individually:

- **`skipRelationshipCheck`** — for whoever the player is *already* fighting (`playerCombatTarget`): active aggression against the player is itself proof of hostility, and can come from crime/quest triggers that never resolve to a clean faction −1.
- **`skipWeaponCheck`** — used when building the cache, so hostiles who haven't drawn yet still land in `CachedEnemies` (flagged `armed = false`) and are targeted like any other. An enemy sizing the player up decides who to kill before it unsheathes, and waiting for the sheathe animation was most of the "why are my mercs just standing there" delay. The `armed` flag survives only so the logistics tick can tell a fight in progress from a hostile merely standing nearby.

## Perched archers are archer-merc business only (`MercMayClaim`)

A static archer standing on a **watchtower deck or a cart bed** may only be claimed by an
archer merc. A footman sent at one walks to the foot of the thing and stands there for the
rest of the battle while the distance leash flaps him between drawn and sheathed.

Perch is what makes the difference, not being a static archer:

- `StaticArcherPerched` (mercenaries_static_archer.lua) answers yes for `elevated` (set by
  the tower), `cart` (set by `ArcherCartSpawnArchersDelayed`) or `attached` (set once
  `AttachStaticArcher` has run — the flags cover the delay before it does).
- Everyone else in `StaticArchers` is an ordinary enemy. The besiegers at Raborsch and
  anything the siege builder places are static archers standing on **open ground**, and the
  whole company fights them.

This rule used to refuse *every* entity in `StaticArchers`, which is why the siege of
Raborsch was fought against the attacking foot alone — the melee mercs would not touch the
attackers' archers, so the archery line shot at the squad unopposed.

Unclaimable candidates are skipped inside `PickCombatTarget`'s sweep as well as refused by
`TryClaimTarget`. The sweep keeps only the single nearest enemy, so one perched archer
standing closer than the foot around him used to blank the pass and leave a melee merc with
no target at all.

The mirror rule for the other side is `IsEnemyTargetable` (mercenaries_spawning.lua): enemies
never take one of the player's tower or cart archers as a target, for the same reason.

## Acquisition: always on, two passes

There is no combat stance. Every merc and archer runs the same rule every scheduler tick, whenever it isn't already in combat. Both passes bail only if the merc already has a target, and both go through `TryClaimTarget` — the anti-swarm cap applies to everything *except* the self-defence claim described above. **Health is not a factor** — see "Fighting to the death" below.

1. **`EvaluateCombatTarget`** — the lock-on pass. The BT walks `enemiesArray` (nearest first, breaking as soon as one is claimed), asks the engine `GetTarget` for each candidate, and claims anyone whose target is **the player or this merc**. This is what makes the squad move the instant an enemy picks its victim, rather than when the first blow lands.
2. **`PickCombatTarget`** — the fallback. Takes whoever the player is fighting (`playerCombatTarget`), else the nearest cached hostile.

### Exactly one gate may be waived per path — never both

(One exception, and it is a stronger proof rather than a waiver — see "Base-game enemies: the lock-on gate" below.)

This is the rule that keeps the squad both responsive and sane, and breaking it produces two very different bugs:

| Path | Waives | Still demands | Why |
|---|---|---|---|
| pass 1, and the nearest-hostile sweep | drawn weapon | relationship = −1 | −1 is already proof of hostility. Waiting for the unsheathe animation on top of it meant the squad never moved until someone had been hit — both `GetTarget` paths only resolve *after* somebody commits to a fight, so this sweep is the only trigger that can fire early. |
| `playerCombatTarget` | relationship | drawn weapon | The player may pick a fight with anyone, so relationship can't apply. But `GetTarget` on the player hands back whoever he happens to be looking at, so without the drawn-weapon proof the squad charges villagers and parks in a permanent combat state (engine NPC state reads "running towards battle", which also blocks dialogue). |

`playerCombatTarget` additionally has to pass `IsWithinAggroRange` — the player's lock-on reaches far past the 20 m follow leash, and a merc sent that far just gets pulled back, re-acquires, and never arrives.

The intended consequence of the first row is that mercs will start a fight with a faction-hostile NPC merely standing within `EnemyScanRadius`. That is the "always aggro" behaviour, not a bug.

### `soul:GetTarget()` IS NOT A LUA SCRIPTBIND

It appears **nowhere** in vanilla's own scripts — where `soul:IsInCombatDanger` (22 uses),
`soul:HasScriptContext` (35) and `soul:GetState` (26) all appear freely — and every call the mod
made to it sat inside a `pcall`. So it failed silently and read as *"nobody is targeting anyone"*,
for everybody, always. Anything built on it is dead code that looks alive, and four things were:

- the whole lock-on gate below, and the group escalation that hangs off it;
- the bandit camp's "a bandit took one of ours as his target" wake-up;
- the squad-alert trigger on the player's own target;
- `EngageBeingAttacked`, which the "defend only" stance uses to decide whom *not* to pull out of a
  fight — so that stance had been dropping claims it was meant to keep.

**The engine's `GetTarget` behaviour-tree node does work**, and always has: it is what fills
`$candidateTarget` for the acquisition pass. So the authoritative answer comes from there.
`EvaluateCombatTarget` records every candidate it confirms is locked onto the player or onto a merc
via `NoteAttacker`, and the cache reads that register back. Entries expire after
`AttackerMemorySecs`, so a man who broke off, died or streamed out stops seeding the fight.

That gives a **bootstrap**, which is the part that matters:

1. the cache refuses a base-game bandit (not pinned at −1) but keeps him, armed, in `MaybeEnemies`;
2. `ScanForEnemies` offers `CachedEnemies` **∪ `MaybeEnemies`** to the behaviour tree, so its
   `GetTarget` node runs over him;
3. one merc's tree sees he is locked onto the player → validates → `NoteAttacker` → claims him;
4. the next cache pass (≤300 ms) admits him *and* runs the group pass around him, so the whole camp
   enters the cache;
5. every merc now has something to claim.

`LockedOntoUs` is kept as a no-cost best-effort in case the bind ever exists, and is documented as
such. **Do not build anything new on it.** For "is this soul in a fight", use
`soul:IsInCombatDanger()` — real, vanilla-proven, and now what raises the squad alert off the
player and what gives the bandit camp its earliest wake-up.

### Base-game enemies: the lock-on gate

The relationship floor demands **exactly −1** to the player, and the mod's own spawned enemies are
built to sit there (`enemiesFaction` is hostile to the player and the mercs and nothing else). A
**base-game** hostile is not guaranteed to, at least not before he has committed to the fight — and
a cache miss is total:

- `ScanForEnemies` builds the BT's candidate array from `CachedEnemies`, so the lock-on pass
  (`EvaluateCombatTarget`) could not see him either;
- the nearest-hostile sweep in `PickCombatTarget` reads the same cache;
- so the **only** remaining way in was `playerCombatTarget` — the player's own target.

That is exactly the report: the squad waited for the player to commit (**"not instantly"**) and then
only put the cap's worth of men on that one man (**"not all of them"**), while everyone else stood
with nothing to claim.

`EngageCacheAccepts` now has a **third** gate, sitting between the normal pass and the
aggressive-stance pass:

```lua
if not self:IsOwnSide(ent) and self:LockedOntoUs(ent)
   and self:IsValidEnemy(ent, player, playerWuid, true, true) then return true end
```

Both hostility gates are waived there, which the rule above forbids on the relationship paths — but
this is not a waiver, it is a **stronger proof**: he has his weapon out and our name on it. Every
other filter still applies (combat-viable, siege/bandit-camp suppression, `TargetDetectionRadius`,
`NavTargetBlocked`, own soul, hero name, flee/surrender/immortal).

`LockedOntoUs` checks the **weapon first**, and that ordering is what makes it affordable: it runs
for every candidate the relationship pass rejected, which in a town is every NPC in the scan, and
`GetTarget` is an engine call. Nobody in a market has a weapon out, so the cost collapses to nothing
there and is paid only where there is a fight. An unarmed NPC "targeting" the player is an argument,
not a battle, so the gate costs no coverage either. `OurWuids` (player + `ActiveMercs`) is rebuilt
once per cache pass, alongside the load map that pass already walks the roster for.

**A guard swinging at the player is, by this rule, an enemy.** That is deliberate — the alternative
is a bodyguard company watching its employer be beaten — and it is not new behaviour, only reliable
behaviour: an actively hostile guard generally reached the −1 floor anyway. The engagement stances
still gate the *claim*, so "hold fire" and "defend only" behave as documented.

### A fight is between groups, not individuals

The lock-on gate admits only the individuals who have actually taken one of ours as a target. In a
camp of ten that is the two or three who reacted first — so the squad has two or three claimable
enemies for twenty men, and seventeen of them stand there with nothing to go at. **That is the
"only three of twenty ever engaged" report, and it is not the swarm cap: there was nothing to be
capped.**

`UpdateEnemyCache` therefore runs a **second pass**. The first records where every confirmed
attacker is standing and keeps the armed candidates the normal gates turned away; the second admits
any of those standing within `FightGroupRange` (20 m) of an attacker. Once someone is fighting us,
every armed man standing with him is in that battle.

Narrow on four counts at once, and each one is load-bearing:

- it does nothing unless somebody is **already** fighting us, so peace is untouched — and so is the
  cost, since `maybe` is only walked when `attackers` is non-empty;
- **armed only**, the same drawn-weapon proof the aggressive stance leans on, so a bystander is not
  swept up by a brawl beside him;
- measured from a **confirmed attacker**, not from the player, so the set grows out of the fight
  rather than out of wherever the player happens to be standing;
- `IsOwnSide` plus the whole of `IsValidEnemy` still apply, so it can never turn the squad on
  itself, on a named companion, or on someone fleeing or immortality-protected.

#### ...but a fight has two sides, and only one of them is ours

"Armed, and standing within `FightGroupRange` of a man who is fighting us" describes the
**other** side of that fight exactly as well as it describes his friends. A caravan's guards
drawing steel on the bandits mobbing them are armed, and they are right next to a confirmed
attacker — so the second pass admitted them with the relationship floor waived, and the squad
fell on the caravan. That is the "mercenaries attack random people, like from random
encounters or caravans, without an order" report. No stance was involved: this pass runs on
every stance, including the default one.

`StandsWith(ent, attacker)` is the extra gate, and it asks the candidate what he thinks of
**our enemy** — the one question that separates the two cases:

| `cand.soul:GetRelationship(attacker, "Current")` | Means | Verdict |
| --- | --- | --- |
| `<= -1` | he is fighting the same men we are | **never** a target |
| `> 0` | he is allied with our enemy — he is in the band | take him |
| `0`, or no answer | neither, or the engine declined | fall back to the soul id |

The soul fallback is what keeps the pass doing its original job: a base-game bandit camp is
ten generic bandits off **one roster entry**, so a shared soul id is real proof of a shared
band where the relationship table has nothing to say. `attackers` therefore carries
`{ x, y, z, wuid, soul }` rather than a bare position.

An armed neutral in neither camp is now left alone, where before he was swept in for standing
too close to a brawl. Nothing is lost: if he draws on us he comes back through the lock-on
path in his own right, which is a stronger proof than proximity ever was.

> The aggressive stance (`merc_engage_aggressive`) still takes any armed NPC, relationship
> waived, by design — that is what the stance is. It is opt-in and it is not this bug.

### An unalerted bandit camp cannot hide a fight it has started

`IsValidEnemy` refuses every member of a bandit camp that has not alerted (`BanditCampSuppressed`).
That is right for a camp nobody has touched — it is what stops a merc locking onto a docile bandit
from 18 m and flapping his weapon at a man who will never fight back — and completely wrong once one
of its men is swinging at us: the squad stood watching a fight it was not allowed to see.

Two changes, one on each side:

- `BanditCampAlertTick` gained a **fourth wake-up condition**: any bandit taking one of ours as his
  target, at any range. That one is the authoritative signal and the other three (proximity, health
  loss, a death) are early warnings — a man who has picked the player or a merc to fight has started
  the battle by definition.
- the lock-on gate calls `BanditCampAlertFor`, which wakes the camp **that owns him** on the spot,
  rather than waiting up to a second for the monitor tick. `BanditCampAlert` reads `self.BCQ`, so
  the slot has to be bound around it — the pointer is whatever the last bind left behind, and for a
  call arriving off the target selector that is usually the wrong camp.

Waking the camp rather than exempting the one man is the point: the rest of them are in it too, and
the squad should engage the camp.

### The alert now rises when the player draws and locks on

The unalerted cache only reaches `EnemyScanRadius` (18 m) from the player. Against base-game enemies
— who are not in it until they commit — that meant the squad could not react until the fight was
already on top of him. The alert therefore also rises when the player **has his weapon drawn and a
target**, which is knowable at any distance and widens the sweep to `EnemyAlertRadius` so the whole
engagement becomes visible at once.

The drawn weapon is not decoration. `GetTarget` on the player hands back whoever he happens to be
looking at — the same reason `PickCombatTarget` demands a drawn weapon on the player's target — so
on its own it would keep the squad permanently alerted, and permanently sweeping 60 m, just for
walking through a town. Sword out **and** looking at someone is a fight starting; being attacked
while unarmed is already covered by the `crime_interruptAttack` check beside it.


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

## Sheathing mid-battle

`combat_melee` and `combat_archer_dynamic` both end every time their **target** dies, which in a big
fight is every few seconds per man, and both `OnFail`s used to sheathe unconditionally for anyone
who was not an enemy. With the
battle still going on around him that reads as the whole squad putting weapons away and drawing
them again on a loop.

`CombatMaySheathe` gates it: no sheathe while a live cached enemy is within `SheatheClearRange`
(25 m) of **this merc**. It is the same reasoning the enemy exemption right beside it already
carried — "he is not done, he will be handed another within a second" — applied to a merc in a
battle.

The weapon still goes away, just not there. The scheduler sheathes on `idleTicks > 55` (~16 s with
no target and no fight) and on crossing the player leash, which are the two cases the sheathe
actually exists for: a man standing about in camp with his sword out. Note that a *just-killed*
enemy is not `IsCombatViable`, so the last kill of a fight still sheathes immediately even while the
corpse is in the cache.
