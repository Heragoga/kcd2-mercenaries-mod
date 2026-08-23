# Squad orders

Everything the player can tell the company to do, beyond "follow" and "equip".

Four systems, all reached from the silent order wheel (hold the chat key on a merc)
and all available from the console:

| Order | Console | Lives in |
|---|---|---|
| Engagement stance | `merc_engage_default\|aggressive\|defend\|hold` | `mercenaries_orders.lua` |
| Aggression preset | `merc_aggro_tight\|balanced\|loose` | `mercenaries_orders.lua` |
| Call a target | `merc_focus`, `merc_focus_clear` | `mercenaries_orders.lua` |
| Hold this ground | `merc_hold`, `merc_hold_end` | `mercenaries_hold.lua` |
| Escort him | `merc_escort`, `merc_escort_end` | `mercenaries_hold.lua` |

`merc_orders_status` and `merc_hold_status` print the current state of each.

---

## Why none of this touches the schedulers

A merc only ever attacks because `TryClaimTarget` gave him a target: it is the sole
writer of `bt_data.playerTarget`, and the scheduler's fire branch is gated on that
being non-null. **Withholding a claim is therefore enough to stand a man down**, and
no scheduler XML has to learn what a stance is.

That is why the stance system is pure Lua. The one place it is enforced is
`mercenaries_target_selection.lua`, in three spots:

* `UpdateEnemyCache` → `EngageCacheAccepts` decides who is even a candidate.
* `EvaluateCombatTarget` → `EngageAllowsRetaliation` gates hitting back.
* `PickCombatTarget` → `EngageAllowsInitiative` gates starting something.

## The four stances

| Stance | Retaliates | Starts fights | Who counts as an enemy |
|---|---|---|---|
| `default` | yes | yes | declared hostiles (relationship at the −1 floor) |
| `aggressive` | yes | yes | ...plus anyone with a weapon drawn, whatever their faction |
| `defend` | yes | **no** | declared hostiles |
| `hold` | **no** | **no** | — |

`aggressive` is additive, not a replacement: the normal pass still runs first, so
hostiles who have not drawn yet stay targetable exactly as before, and the extra
pass only adds *armed* neutrals. It waives the relationship gate but keeps the
drawn-weapon one, because **exactly one of the two hostility gates may be waived per
path, never both** (see [combat-target-selection.md](combat-target-selection.md)) —
waiving both turns every villager in a 60 m radius into a cached enemy.

`IsOwnSide` is the backstop that keeps the aggressive stance off the quartermaster
and any spawned friend. `IsValidEnemy` filters by soul id, which misses those; that
was harmless while the relationship floor did the work and is load-bearing now.

Changing to `defend` or `hold` calls `EngageDropClaims`, or a man already mid-swing
would keep going until his own watchdog noticed. `hold` drops everyone; `defend`
leaves the men who are actually being attacked alone.

## Aggression presets

Just the three anti-swarm constants under names. `EffectiveSwarmCap` is recomputed
from them every cache pass, so writing them is the whole change.

| Preset | `SwarmCap` | `SwarmCapMax` | `SwarmCapHard` |
|---|---|---|---|
| tight | 1 | 2 | 4 |
| balanced (default) | 2 | 4 | 10 |
| loose | 3 | 7 | 16 |

## Calling a target

`OrderFocusTarget` resolves what the player means, in order: his own lock-on target
if he has one, else the last enemy the crosshair rested on.

The crosshair memory exists because **the wheel opens on a merc** — by the time an
option is picked the player is looking at his own man, not at the enemy he meant.
`OrderLookTick` samples the view ray once a second and remembers the last worthwhile
thing under it for `LookMemorySecs` (12 s). Picking is by angle to the view ray, not
a raycast: a ray against a moving body misses far more often than it hits, and the
angular test still works when the crosshair is on his feet or his horse.

A called target is **force-claimed** — the anti-swarm cap is bypassed on purpose,
since the whole point of the order is that they all go for that one man. It also
lifts a `hold` stance, because ordering a man to kill someone and then refusing him
the claim reads as a broken order.

---

## Hold this ground

`SetState('wait')` is this order now. "Wait here" used to be `_G.MercIdle = true` and
nothing else: the men were evicted from the follow tree and stood wherever they
happened to be, with no anchor, no leash, and nothing pulling them back after combat
dragged them off.

It is **not** an engine formation. `MakeFormation` anchors on whichever entity ran it
and the engine picks which man lands in which spot, so it can do neither of the two
things this order needs — stand still, and put a named merc on a named side. This is
the wall-battle staging pattern instead: one world point per merc computed in Lua,
each man walked to it by `NavGotoRequest` and the stock `nav_goto` tree.

### The shape

A square block of melee centred on the anchor, archers in a file down each flank,
oriented along the direction the player was facing when the order was given:

```
   A     M  M  M  M     A
   A     M  M  M  M     A
   A     M  M [+] M     A        [+] = anchor
   A     M  M  M  M     A
         <- HoldPitch ->  <- HoldArcherFlank -> 
```

`side = ceil(sqrt(melee))`, so the block stays square at any size, and a part-filled
back rank is centred on its own count rather than sitting lopsided. Archers alternate
left/right so the two files stay even, and sit clear of the block's edge so they shoot
*past* it instead of over their own front rank.

Every man gets one exact point. The first version laid melee out in ranks with a
couple of scouts pushed forward and let the widths float, which read as a scatter
rather than a formation.

Stations are assigned from a roster sorted by WUID, so **the same man draws the same
station every time the line is rebuilt**. Rebuilding into a reshuffled lattice is
what makes a squad mill about.

### The leash

`HoldOutOfLeash` refuses any target more than `HoldLeash` (30 m) from the man's own
**station** — not from the player, or the line would drift downfield with him.

**It has to clear an archer's range, not a swordsman's.** At the original 13 m the
squad held perfectly and was shot to pieces by bowmen standing 25 m off, who were
never inside anybody's leash. "Hold this ground" must not mean "stand here and die".

It is checked inside `TryClaimTarget` rather than in the acquisition passes, because
that is the single choke point every claim goes through: no path can smuggle a man
off his station, not even a force-claim.

### What else had to stand down

Three systems would otherwise fight the order, and all three now check `HoldActive`:

* `UpdateFormationRole` — an engine formation running alongside would be a second set
  of destinations pulling the same NPCs somewhere else.
* `MonitorDistanceAndTeleport` — men under a hold order are *supposed* to be away
  from the player; dragging them back defeats the order outright.
### Standing still once he gets there — the part that was wrong first time

`nav_goto` only walks a man to his station; it **ends on arrival**. The first version
had nothing holding him after that, so the scheduler re-fired `follow`, and — with the
formation suppressed — he dropped into the follow chain and walked straight back to
the player. "Wait here" looked like it did nothing, and because the order stayed
active, the formation stayed suppressed too. One bug, both symptoms.

The fix is to reuse the mechanism "wait here" always used. Both schedulers now ask
`mercenaries:MercIsIdle(entity)` instead of reading `_G.MercIdle`:

```lua
_G.MercIdle             -> idle (unchanged, the global order)
holding AND on station  -> idle
holding AND still walking -> NOT idle, so nav_goto owns him
```

The idle arm evicts the follow tree and parks him on an endless `Wait` — which, once
he is standing on his mark, is exactly the behaviour wanted. The two states are
mutually exclusive by construction (walking, or arrived), so the nav arm and the idle
arm can never fight over the same man. `HoldStationSlack` (4 m) is deliberately wider
than `HoldArriveDist` (2.2 m) so a man parked a hair outside cannot oscillate between
them.

Combat is unaffected: acquisition is gated on `~$inCombat`, never on `isIdle`, so a
holding merc still fights — the leash just keeps him near his mark, and he walks back
when it is over.

`_G.MercIdle` itself is deliberately **not** set by a hold order, and its persistent
flag is cleared, so a save taken mid-hold cannot come back permanently idle.

Ending the order calls `HoldReleaseAll`, which raises `FollowStalled` on everyone.
A nav order leaves the scheduler still believing `follow` is running, so without that
the men just stand where they were released; `FollowStalled` is the existing one-shot
signal that evicts the stale tree and re-fires `follow`.

Hold and escort are **not** saved. They are anchored to a spot the player picked, and
a squad that reloads still planted on ground he has since left reads as a bug.

### The hold-to-toggle prompt, and the trap in it

The prompt whose text changes — "Wait here" ⇄ "Follow me" — is **not** the Skald order
wheel. It is the **look-at interactor action** in
`mercenaries_lookatinteraction.lua`: `entity.GetActions` builds an `Action():hint(key)`
each time the engine polls the interactor, so its label is just a Lua string chosen on
the spot. Same mechanism as the camp prompt's make/break/return.

**Anything asking "are the men stopped?" must call `mercenaries:SquadIsWaiting()`,
never `_G.MercPersistentIdleFlag` or `_G.MercIdle` alone.**

A hold order deliberately leaves both globals false (see `MercIsIdle` above). Two
things read them directly and both broke the moment "Wait here" became a hold order:

* the look-at prompt read `_G.MercPersistentIdleFlag` for **both** its label and its
  toggle direction — so the label was pinned to "Wait here" and every press computed
  `not false` and ordered another halt. Pressing it never fell the men back in.
* `ShowSquadStatus` read `_G.MercIdle` and reported a holding squad as "following".

`SetState('wait')` is also a toggle now: a second wait while `HoldActive` falls the men
in instead of re-planting the line on top of itself.

> An earlier attempt drove the *wheel's* label instead, via a marker item in the
> player's inventory plus an `ItemDescriptorTrigger` and `EntryCondition="Port(...)"`.
> It was backed out. The XML shape was fine (546 vanilla chat dialogs use
> `EntryCondition`, 218 repeat a `ChatPosition`), but it was the wrong menu, and a
> marker that has to sit in the inventory for the life of an order is visible to the
> player. If it is ever revisited: `IsQuestItem` on the marker row stops
> `inventory:CreateItem` producing it at all, and acquire-without-lose is a one-way
> latch.

## Escort

Same machinery, but each man trails the escorted entity in column using
`NavGotoRequest`'s `trailEnt`/`trailBack`/`trailLat` (already proven by the
wall-battle staging system).

`trailDir`/`trailAim` are refreshed **in place** on the live record each poll rather
than re-issuing the request, so the column turns with the man being escorted without
tearing down anyone's route and restarting them from a standstill.

---

## Barks

`OrderBarkSome(alias, count, metarole)` makes 3–5 men shout, not one.

* **Who**: farthest-point selection — each speaker is the man furthest from everyone
  already speaking, so the shout comes from across the formation rather than from
  three men standing together.
* **When**: staggered 0.55–1.05 s apart so it reads as a line passing word along
  instead of a chord. The delay is carried in `OrderBarkQueue`, drained by the monitor
  tick, because `Script.SetTimerForFunction` takes a function *name* and cannot carry
  per-call arguments.

### Vanilla voiced lines, for free

`schedulerMonolog` with `alias=""` and a metarole casts from the engine's own pool for
that role, on the cast soul's voice. No mod dialog, no shipped `.ogg`, no
localisation. The alert shout uses `NPC_VIDI_NEPRITELE_A_BUDE_UTOCIT` ("sees an enemy,
will attack"), fired once on the rising edge of `EnemyAlerted`.

**The metarole is a literal in the node, never a variable.** Binding it to
`$barkReqMeta` was tried and backed out: `schedulerMonolog` takes it as a node
attribute, and there is no shipped example anywhere of one being fed from a variable
(the same class of attribute as `FormationMode` and `speed`, which provably cannot be
— see [formations.md](formations.md)). A tree that fails to load costs the formation,
the following and the standing orders all at once, which is not worth saving a node.

So each tree carries **two** nodes: `$hasBarkReq` → our own alias, and `$hasMetaBark`
→ the vanilla shout spelled out exactly as `foe_combat.xml` ships it. `OrderBarkFire`'s
`metarole` argument is therefore a *flag*, not a name; wiring a second vanilla shout
means adding a second node. `BarkPoll` is the one shared consumer, used by
`follow.xml`, `camp_actor.xml` and `mercenary_scheduler.xml`.

---

## Adding another order

The chain is unchanged from every other menu (see
[order-wheel.md](order-wheel.md)):

1. Mint a GUID suffix on the `679a655e-189d-4519-b437-ccc4b92b` prefix — **grep for
   it first, the table is not sorted** — and add one `MiscItem` row to
   `data/libs/tables/item/item__mercenaries.xml`.
2. Add the Lua constant and a reader in the feature's own file, then one call in
   `MonitorInventory`. For a multi-option order use the **count-encoded** pattern:
   one item class, `Amount` = the option index.
3. Add a `<Port>` and a leaf `<Sequence>` to `order_wheel_chat.xml`.
4. Add one `EventFunction` per option to `mercenaries_background_quest.xml`, with an
   `<Edge>` per dialog that should fire it.
5. Do all of 3–4 in **both** `kutnohorsko/` and `trosecko/`. The two dialog files are
   byte-identical mirrors; the quest graphs are not, so those take the same edit
   twice.
6. Add the label rows to `localization/English_xml.xml`.

A dangling `<Edge>` pointing at a port that does not exist is the failure that kills
the whole graph, so check that last.
