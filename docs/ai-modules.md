# AI Modules

The mod's NPC AI is built from five reusable behavior modules plus one thin scheduler per brain. A module is a `SmartBehaviorTemplate` (registered in `SmartEntity__so_interrupt__mercenaries.xml`) fired via `AddInterrupt_attack Behavior='<module>'`; it takes its target from `$attackData.target`, so **who it attacks is always set from outside** by the scheduler that fires it. Side differences (merc vs enemy) are resolved in Lua (`mercenaries_ai_modules.lua`) from the entity's spawn-name prefix, so one tree serves everyone.

This structure exists to make the planned encounters (camp raids, ambushes, patrols, bandit camps, the siege) pure Lua work: spawn NPCs, point the existing modules at the right people, done.

## The modules (`data/AI/`)

| Module | What it does | Used by |
|---|---|---|
| `combat_melee` | The one melee attack: automation decorators + `CombatFollowerDecorator` chasing `$attackData.target`. `WeaponChange=melee` for **everyone** so the weapon is actively drawn (a freshly-spawned enemy would otherwise swing with fists for seconds while the passive draw catches up). | mercs, merc archers (melee stance), quartermaster, all enemy melee |
| `combat_archer_dynamic` | Shoot while keeping distance: stand-and-fire at >9 m; in the 4.5–9 m band, **step ~4 m back then fire a burst** (step-fire kiting — the fire always follows, so a blocked retreat can't leave the archer idle); inside 4.5 m or out of arrows, sidearm burst until the gap reopens (>12 m). | merc archers (skirmish stance), enemy archers |
| `combat_archer_static` | Pure stand-and-fire, no movement. Firing core is the vanilla battle-archer standFire (same as the dynamic module's, and the base-game siege NPCs): a **single** `CombatAction` in a `Parallel` kept alive by a watchdog sibling — one `CombatAction` looses arrows continuously, so it must NOT be wrapped in a per-shot loop (that fires once and stops). **Never ends on its own**: the standFire sits in an outer `Loop` inside the combat context, so when the watchdog ends a burst (target dead) the Loop re-enters standFire rather than ending the behaviour — the context + drawn bow stay on (no flicker). Re-targeting is the scheduler's job (re-fires on target change). | tower archers; wall/siege archers later |
| `follow` | Formation-follow a leader (`CrimeFollower` on `$followTarget`), plus the horse lifecycle for mounted following and the order-bark consumer. The leader comes from Lua each tick. | sortie mercs and archers; enemy patrols later |
| `camp_actor` | Camp life: guard patrol, sit/sleep on furniture, activities (training, smithing, eating…), paired gossip. Entirely driven by the WUID-keyed camp tables in `mercenaries_camp.lua`. | camp mercs; bandit camps later |

## The schedulers

Each brain runs one always-active scheduler subbrain (`subbrain_switching__*.xml` maps subbrain → file):

| Scheduler | Brain | Fires |
|---|---|---|
| `mercenary_scheduler` | mercenary_brain | `combat_melee` (squad stances pick the target), `camp_actor` vs `follow` (split on `IsCampActor`) |
| `archer_scheduler` | archer_brain | `combat_archer_dynamic` (skirmish) / `combat_melee` (melee stance), `camp_actor` vs `follow` |
| `quartermaster_scheduler` | quartermaster_brain | `combat_melee`, `quartermaster_idle` |
| `enemy_melee_scheduler` (was renegade_scheduler) | renegade_brain | `combat_melee`; `camp_actor` while holding a camp role with no target |
| `enemy_archer_scheduler` | enemy_archer_brain | `combat_archer_dynamic` (re-fired whenever the target changes); `camp_actor` like the melee one |
| `static_archer_scheduler` | static_archer_brain | `combat_archer_static` |

The merc/archer schedulers track which follow-family behavior is running (`firedCampActor`) and force a re-fire when the camp role flips, so deploy/return transitions swap `camp_actor` ↔ `follow` cleanly.

## The Lua contract (`mercenaries_ai_modules.lua`)

- `SideOf(name)` — **three** sides: `'enemy'` for `SpawnedEnemy_`/`SpawnedRenegade_`, `'patrol'` for `SpawnedPatrolman_`/`SpawnedPatrol_`, else `'friend'`. Prefix lists (`FriendPrefixes`/`EnemyPrefixes`/`PatrolPrefixes`) are tables — extend them when adding new spawn types. **A new hostile spawn type that falls through to `'friend'` inherits the merc leash to the *player*, which fails its combat on the first tick it fights anywhere else** — that was the patrol start-stop bug.
- `UpdateMeleeCombatData(data, wuid)` — target-alive + per-side disengage (friend: player leash 20 m; friend archer: 25 m / melee-stance check; patrol: own-target leash 60 m, never measured against the player; enemy: never). `isEnemy` (which gates the explicit pre-charge `DrawAction`) means "not the player's own man", so patrols get it too.
- **The target-alive test is conscious-strict.** `IsCombatViable(ent)` = `IsAliveAndWell(ent, false)`; a knocked-out body is not a target. With `allowUnconscious = true` the fighter that downed someone had *no exit at all* (enemies have no leash, so `isTargetAlive` is their only one) and circled the body until something else moved him. Roster/bookkeeping paths deliberately keep `IsAliveAndWell(ent, true)` — `PruneMercCache` schedules a despawn on a false answer, so a KO'd merc must still read as alive there.
- `UpdateRangedCombatData(data, wuid)` — target-alive, distance, out-of-ammo (all ammo classes), stance validity (friend archers only), leash (friend: player 40 m; enemy: own target 60 m), and the retreat point for the dynamic module.
- `ClearCombatClaim(wuid)` — clears every anti-swarm claim table; the modules' `OnFail` calls it so one cleanup works for all sides.

## Control points for encounters

- **Who enemies attack**: `mercenaries.EnemyTargetPrefixes` (what `FindEnemyTarget` may target — extend to make enemies fight someone new) and `mercenaries.ForcedTargetOf[wuidStr] = targetWuid` (pin one NPC onto one target until it dies).
- **NPC-led formations**: `mercenaries:AssignNpcFormation(leaderWuid, memberWuids, width)` builds a chain formation behind any leader in `NpcFormations` (checked before the player-squad `FormationSlots`); fire `follow` on the members and they march behind the leader like mercs behind the player. `ClearNpcFormation(memberWuids)` removes it.
- **Enemy camps**: populate the same WUID-keyed camp tables (`IsCampActor` / `IsCampGuard` / `GetCampFurniture` / `GetCampActivity` / `_G.MercCampChats`) for bandit WUIDs; both enemy schedulers already fire `camp_actor` for role-holders and swap to combat when `FindEnemyTarget` finds someone.

## Rules learned the hard way

- Any tree fired by `AddInterrupt_attack Behavior='X'` must be registered as a `SmartBehaviorTemplate Name="X"` or the NPC just stands there.
- Never force `DrawWeapon()` after spawning a combat NPC — the modules' automation owns weapon draw.
- `WeaponChange="none"` relies on a **passive** weapon draw that a freshly-spawned, instantly-aggressive NPC loses the race to (fists for ~5 s). Force `WeaponChange="melee"`/`"missile"` so the `WeaponAutomationDecorator` owns the draw - this fixes most of it. For the rare residual (weapon equipped but still not drawn as they charge), add an explicit `DrawAction WeaponSet="Primary"` before the combat `Parallel`, gated to enemies only (`$isEnemy & ~$isArcher`) so mercs keep their draw-while-charging and don't lose engagement time. Mercs never showed the bug - they follow (weapon settles) before fighting.
- A one-shot `CombatAction` **returns after its burst**; if it isn't wrapped in an outer `Loop count="-1"` (or a re-firing scheduler), the NPC acts once and stops. Every combat module's action sits inside such a loop.
- **A combat module needs a *timed* exit, not just a conditional one.** `combat_melee` used to test `isTargetAlive` only in the arm around `CombatAction`, which is sampled whenever that node happens to return — so a fighter whose target went down could stay in the behaviour indefinitely. The watchdog arm now tests `$disengage | ~$isTargetAlive` on its 1 s poll, **confirmed by a second read 400 ms later** because `UpdateMeleeCombatData` defaults `isTargetAlive` to false and only sets it after a successful WUID lookup inside a `pcall`, so one hiccup would otherwise read as death.
- **The `OnFail` `Wait` is dead time the whole squad pays.** It sits *inside* the module's `EntityContext crime_interruptAttack`, which is exactly what schedulers read as `inCombat` — so a 1 s wait there is 1 s added to every post-combat recovery before any locomotion behaviour can re-fire. It is now 300 ms, matching the `CombatScanLoop` cadence so a corpse still leaves `CachedEnemies` before re-acquisition can see it. Don't drop the cleanup Lua next to it: without it mercs stand around with their sword out, and `ClearCombatClaim` is what frees the swarm-cap slot.
- Only the combat modules wrap themselves in `EntityContext crime_interruptAttack`; that context is what schedulers read as `inCombat`. `follow`/`camp_actor` deliberately don't, so combat can replace them at equal priority via `IgnorePriorityOnPreviousInterrupt`.
- **Scheduler combat-fire timing** (this stranded ~1 in 10 enemies): the `inCombat` tracker loop must poll at least as fast as the fire loop (both 500 ms). If the tracker is slower, the fire loop re-fires the just-started combat before `inCombat` flips true; with `IgnorePriorityOnPreviousInterrupt` that *replaces* the running behaviour and runs its `OnFail` (sheathes the weapon, drops the target), and unlucky timing leaves the NPC disarmed and idle. Also set `$inCombat = true` optimistically right after `AddInterrupt_attack` so the next iteration can't re-fire before the tracker confirms; the tracker flips it back within one poll if combat genuinely didn't start, so retries still happen. Mercs never showed this — they poll at 500 ms and fall back to `follow`, which hides a hiccup; enemies have no fallback, so it's visible as standing around.
- `CombatAction` fires **one shot and returns**, so it must be re-issued. Doing that from an *outer* loop leaves the weapon-automation decorator between shots, so the NPC lowers and re-raises the weapon each cycle - invisible on a moving NPC, but a **stationary** archer reads it as flicking in/out of combat. Re-issue it from a `Loop count="-1"` placed *inside* the `WeaponAutomationDecorator` (see `combat_archer_static`) so the bow stays drawn; only the parallel watchdog (target dead / out of ammo) ends the burst.
- **A periodic `SetPos` resets an NPC's AI and drops its combat mid-action.** The tower archer is re-`SetPos`'d every 400 ms for up to ~2.4 s after spawn (the drop-to-spot keeper) - during that window any combat it starts is yanked, which reads as "enters and exits combat for a few seconds". No combat-tree change fixes it; the fix is to **hold fire while placement is pending** (`FindStaticArcherTarget` returns no target while `StaticArcherPending[wuid]` is set), so combat only starts once it's landed. Anything that teleports a fighting NPC on a timer needs the same guard.
- The Skald dialogs contain a **port** named `mercenary_follow` (the "follow me" squad order). It is unrelated to the old tree of the same name — don't "fix" it.
