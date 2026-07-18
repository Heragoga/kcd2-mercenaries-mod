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

- `SideOf(name)` — `'enemy'` for `SpawnedEnemy_`/`SpawnedRenegade_` prefixes, else `'friend'`. Prefix lists (`FriendPrefixes`/`EnemyPrefixes`) are tables — extend them when adding new spawn types.
- `UpdateMeleeCombatData(data, wuid)` — target-alive + per-side disengage (friend: player leash 20 m / passive stance / critical health; friend archer: 25 m / melee-stance check; enemy: never).
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
- Only the combat modules wrap themselves in `EntityContext crime_interruptAttack`; that context is what schedulers read as `inCombat`. `follow`/`camp_actor` deliberately don't, so combat can replace them at equal priority via `IgnorePriorityOnPreviousInterrupt`.
- **Scheduler combat-fire timing** (this stranded ~1 in 10 enemies): the `inCombat` tracker loop must poll at least as fast as the fire loop (both 500 ms). If the tracker is slower, the fire loop re-fires the just-started combat before `inCombat` flips true; with `IgnorePriorityOnPreviousInterrupt` that *replaces* the running behaviour and runs its `OnFail` (sheathes the weapon, drops the target), and unlucky timing leaves the NPC disarmed and idle. Also set `$inCombat = true` optimistically right after `AddInterrupt_attack` so the next iteration can't re-fire before the tracker confirms; the tracker flips it back within one poll if combat genuinely didn't start, so retries still happen. Mercs never showed this — they poll at 500 ms and fall back to `follow`, which hides a hiccup; enemies have no fallback, so it's visible as standing around.
- `CombatAction` fires **one shot and returns**, so it must be re-issued. Doing that from an *outer* loop leaves the weapon-automation decorator between shots, so the NPC lowers and re-raises the weapon each cycle - invisible on a moving NPC, but a **stationary** archer reads it as flicking in/out of combat. Re-issue it from a `Loop count="-1"` placed *inside* the `WeaponAutomationDecorator` (see `combat_archer_static`) so the bow stays drawn; only the parallel watchdog (target dead / out of ammo) ends the burst.
- **A periodic `SetPos` resets an NPC's AI and drops its combat mid-action.** The tower archer is re-`SetPos`'d every 400 ms for up to ~2.4 s after spawn (the drop-to-spot keeper) - during that window any combat it starts is yanked, which reads as "enters and exits combat for a few seconds". No combat-tree change fixes it; the fix is to **hold fire while placement is pending** (`FindStaticArcherTarget` returns no target while `StaticArcherPending[wuid]` is set), so combat only starts once it's landed. Anything that teleports a fighting NPC on a timer needs the same guard.
- The Skald dialogs contain a **port** named `mercenary_follow` (the "follow me" squad order). It is unrelated to the old tree of the same name — don't "fix" it.
