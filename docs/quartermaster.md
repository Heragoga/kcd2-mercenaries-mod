# The Quartermaster

A single, immortal NPC that stands by the player's tent whenever camp is up
and acts as a talking interface. He does nothing else: he stands there all
day, occasionally plays an eating animation, and — when the camp is raided —
fights back with the shared melee tree. He can't die. Right now his dialog is
a placeholder; the intention is that he grows into the camp-management
interface (hence "quartermaster").

He's a full custom NPC built to the two NPC guides
([xml/add-new-npc.md](xml/add-new-npc.md), [xml/make-npc-brain.md](xml/make-npc-brain.md)),
so he survives loads, respects factions, and talks through the quest — but with
a deliberately **lobotomized merc** brain.

---

## The brain (a lobotomized merc)

The merc brain does follow / idle / combat / barks / camp roles. The
quartermaster keeps only "stand still" and "defend yourself", and adds
"occasionally eat". His custom brain (`quartermaster_brain`) is wired exactly
like the renegades' (see [archers.md](archers.md) for the renegade-brain
pattern): a custom switch subbrain plus the shared vanilla scheduler.

| Piece | File |
|---|---|
| Brain + subbrain wiring | `data/libs/tables/ai/*__mercenaries.xml` |
| Switch (stand / eat / defend) | `data/AI/quartermaster_scheduler.xml` |
| Default behaviour (stand + eat) | `data/AI/quartermaster_idle.xml` |
| Interrupt registration (`quartermaster_idle`) | `data/libs/tables/ai/smartEntity/SmartEntity__so_interrupt__mercenaries.xml` |

**How the switch works** (`quartermaster_scheduler.xml`): a `Parallel` of three
loops — one senses whether he's under attack (`crime_interruptAttack`), one
picks a defensive target every second (`FindQuartermasterTarget`), and a
`ContinuousSwitch` fires behaviours:

1. A raider is near and he's not yet fighting → fire **`combat_melee`** (the
   same shared melee combat tree the mercs use) on it.
2. A fight is ongoing → do nothing, let the combat tree run.
3. Otherwise → fire **`quartermaster_idle`** (once, re-fired after any fight).

Both behaviours are fired with `AddInterrupt_attack`, the same generic
interrupt-fire the merc scheduler uses to fire `follow` — so
`quartermaster_idle` declares the `attackData` In-parameter even though it
never touches it. The newest interrupt wins
(`IgnorePriorityOnPreviousInterrupt`), so combat cleanly preempts the idle loop
and the idle loop resumes afterward.

### Why he used to stand where the fight ended

Two separate bugs, both of which stopped the switch ever reaching arm 3 again.

**1. A Lua `nil` does not clear a BT `_wuid`.** `FindQuartermasterTarget` ended with
`data.currentTarget = best`, and `best` is `nil` when nothing hostile is near — which left the
variable holding the last raider for ever. Arms 1 and 2 both tested
`$currentTarget ~= $__null`, so after his first fight the switch sat on arm 2 ("let the combat
tree run") permanently. Everywhere else in the mod a `_wuid` is cleared by a BT `Expression`
(`$playerTarget = $__null` at the top of the merc scheduler's cycle); Lua only ever *writes*
one. The fix keeps that rule: Lua writes `currentTarget` only when there is a real target and
publishes a separate `_bool` **`qmHasTarget`**, which is what both arms now switch on.

**2. The idle latch was only dropped by the arm that starts a fight.** `$isIdleActive = false`
lived solely in arm 1, but a raider who swings first puts him in `crime_interruptAttack`
without arm 1 ever running — the engine's own attack interrupt evicts `quartermaster_idle`, the
latch stays `true`, and arm 3's `~$isIdleActive` guard blocks the re-fire. The combat-detection
loop now clears the latch alongside `$inCombat = true`, so any route into a fight re-arms the
walk home.

**Idle** (`quartermaster_idle.xml`) each cycle: walk back to his post, sheathe,
turn to face the tent, then stand a while and play a `eating_standing`
UnstanceAction (a mode-2 standing activity, confirmed working — see
[camp.md](camp.md#camp-activities-making-the-camp-feel-alive)). The
return-and-sheathe step is what brings him home **after a raid**: the shared
combat tree drags him toward the enemy, so once the fight ends and this
behaviour re-fires he walks back to the post (a vec3 read from
`mercenaries:GetQuartermasterPost`, filled component-wise into the BT the same
way the camp guard patrol reads its waypoint), puts the weapon away
(`DrawWeapon(false)`), and faces the tent. In peacetime he's already home, so
the `Move` returns instantly and it's just stand + eat.

**Immortality** comes from `soul_vip_class_id="12"` (immortality +
unconsciousness protection) on his soul, so a raid can never actually kill or
drop him.

**Defensive targeting** (`FindQuartermasterTarget`, `mercenaries_quartermaster.lua`)
scans NPCs within 30 m of *himself* (not the player — he doesn't move) and picks
the nearest one that passes the shared `IsValidEnemy` filter (genuinely hostile,
weapon drawn, not the player/a merc/an archer). Unlike the renegades'
indiscriminate `FindRenegadeTarget`, he only ever engages real raiders.

---

## Identity, look and dialog

- **Soul / faction**: `soul__mercenaries.xml`, in `mercenariesFaction` — so
  renegades already treat him as an enemy and attack him during a raid (he
  fights back but can't die). Not added to `ActiveMercs`, so no merc system
  counts, heals, teleports or forms him up.
- **Appearance**: a grey-haired older look via a storm rule in
  `mercenariesappearance.xml`. Clothes and weapon are applied from Lua on spawn
  (the renegade pattern): the vanilla **bailiff** clothing preset
  (`kpri_bailiff`) and a sword-and-shield weapon preset — see
  `mercenaries.QuartermasterClothing` / `...Weapon`.
- **Dialog**: his own role, `role_mercenary_quartermaster` (distinct from the
  squad's `role_mercenary_test`), so talking to him opens
  `quartermaster_dialog.xml` and never the squad-orders dialog. Added to **both**
  region quests (kutnohorsko + trosecko). The one test option routes through a
  token (`...be67d`) to `mercenaries:QuartermasterTest` — the same Skald↔Lua
  token bridge everything else uses.

---

## Lifecycle

He is purely a camp fixture:

- **Spawn**: `mercenaries:SpawnQuartermaster(center, facingAngle)`, called from
  `SpawnMercCamp` right after the player tent, placed a few metres out the
  **doorway** and turned to face it. Which doorway depends on what's standing on
  the `(0,0)` tile, and the two are nothing alike:
  - *tent* — its door faces `facingAngle + 130°` (the same `tentAngle` the tent
    is spawned with, **not** raw grid-forward); offset `QuartermasterTentOffset`.
  - *player house* (House upgrade) — the hut opens along **grid-forward** (its
    door gable is the local `-X` end and it spawns at `facingAngle + π`), with its
    body running ~5m the other way, so he uses the forward axis and more
    clearance (`QuartermasterHouseOffset`). The tent's offset would leave him
    standing inside the hut's side wall.
- **Despawn**: `mercenaries:DespawnQuartermaster()`, called from `BreakMercCamp`
  and `ClearAnyLeftoverCamp` (which also sweeps by the `MercQuartermaster_` name
  prefix, since a camp standing at save time loses the tracked handle — he is
  respawned with the camp by `RestoreCampDelayed`, like the rest of the props).

---

## Known limitations / not done yet

- The dialog is a **placeholder** (one test line + a farewell). It exists to
  prove the talk interface works; the real camp-management menu comes later.
- Nothing here is playtested in-game yet; expect to tune his spawn offset,
  facing, and the eating cadence. The front-of-tent placement assumes the
  tent's door faces `tentAngle` (`facingAngle + 130°`); if it turns out to open
  a different way, adjust the `+130°` in `SpawnQuartermaster`.
