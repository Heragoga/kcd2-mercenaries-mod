# Detecting that the player is inside a building

**Yes, and we don't have to invent it.** KCD2 has a first-class engine concept for "indoors":
an **area label** called `interior`, attached to `TriggerArea` entities that are authored into
the building prefabs themselves. The game reads it for its own mechanics, and it is reachable
from all three of our scripting surfaces — behaviour trees, Skald, and Lua.

---

## Where the data lives

Areas in a level are `TriggerArea` entities, and they carry a `Label` property holding a
semicolon-separated list of tags:

```xml
<Entity Prefab="1" Name="WH_TriggerArea35[structures/industrial/sheds/shed_kh_c8_6315602b-…]"
        Pos="2851.854,683.8582,35.96436" EntityClass="TriggerArea" …>
  <Properties Label="dogForbidden;interior;private;semipersonal;suppressHorseCall" bSaved_by_game="0" />
</Entity>
```

Counted out of the shipped level object lists (`objects_mission0.xml`):

| | Kuttenberg | Trosky |
| --- | --- | --- |
| `TriggerArea` entities | 6055 | 2983 |
| …carrying a `Label` | 2444 | 1585 |
| distinct labels | 112 | 64 |
| areas labelled **`interior`** | **384** | **179** |

The `interior` areas are not hand-placed one at a time. The `Name` of nearly all of them is
`WH_TriggerAreaNN[structures/living/houses/…]` — they come from the **building prefab**, so
every placed instance of that house, shed, barn, stable or bathhouse brings its interior
volume with it. 241 distinct prefab sources in Kuttenberg alone. Quest interiors (palaces,
towers, hideouts) add hand-placed ones on top: `ttro_trespassPannaPalaceArea_6`,
`kocovnickaCest_marikasHideout_inside_area`.

The rest of the label vocabulary is worth knowing, because it is the same lookup:

| group | labels |
| --- | --- |
| ownership / trespass | `private` `personal` `semipersonal` `semipublic` `public` `household` `prohibited` `antitrespass` `crime_reactionsToTrespass` `fasterTrespassEscalation` |
| space type | `interior` `kitchen` `cellar` `attic` `pantry` `barn` `workshop` `office` `bedside` `settlement` `castle` `closedCastleArea` `empty` `loot` |
| stealth | `stealthArea_crouch` (1015 in Kuttenberg) `stealthArea_stand` |
| suppressors | `suppressHorseCall` `dogForbidden` `horseSpeedLimiter` `suppressTorchWarning` `suppressFrisk` `animals_publicSpace` |
| audio | `music_*` (~40 distinct) |

### Proof the engine trusts it

`interior` is not a leftover. Three shipped buff implementations test exactly this label on the
soul's position (`Cpp:InteriorCrouch`, `Cpp:ExteriorCrouch`, `Cpp:InteriorDrunk` in
`Libs/Tables/rpg/buff_implementation.xml`), and in the disassembly
`wh::rpgmodule::C_InteriorCrouchBuff::vf32` builds the literal string `"interior"` and hands it
to the area-label test. That is the stealth visibility model
(`VisibilityDecrementDaytimeInterior` / `…Nighttime…`, `InteriorCrouchHysteresis`). The same
test drives horse-call suppression and where the dog is allowed to follow.

---

## Three ways to read it

### 1. Behaviour tree — the best fit, and vanilla already does it

Two nodes: `IsInsideAreaWithLabel` (a one-shot condition on a position) and
`IsInsideAreaWithLabelBarrier` (a *gate* that runs its subtree while the condition holds and
tears it down when it stops). 60 vanilla BT files use them, 21 of those on `interior`.

The dog's trespass brain contains a ready-made "player entered / left a building" watcher —
`AI/animal/basic/switch/animal_continuouslyCheckTrespass.xml`:

```xml
<Loop count="-1">
  <IsInsideAreaWithLabelBarrier Who="$__player" Label="&apos;interior&apos;" Negation="true" RunLogic="KeepRunning">
    <Sequence>
      <Expression expressions="$isPlayerInsideInterior = false" />
      <IsInsideAreaWithLabelBarrier Who="$__player" Label="&apos;interior&apos;" Negation="false" RunLogic="Halt">
        <Sequence>
          <Expression expressions="$isPlayerInsideInterior = true" />
          <Wait duration="&apos;-1&apos;" timeType="GameTime" doFail="false" variation="" skipInLOD="false" />
        </Sequence>
      </IsInsideAreaWithLabelBarrier>
    </Sequence>
  </IsInsideAreaWithLabelBarrier>
</Loop>
```

Note the details that make it work: `$__player` is a built-in BT variable (no wuid plumbing),
the `Label` value is a **quoted string inside the attribute** (`&apos;interior&apos;`), and the
inner barrier holds on an infinite `Wait` so it only unwinds on the actual exit. The outer
barrier's `Negation="true"` is the "outdoors" state.

Caveat that applies to us: that infinite `Wait` is `timeType="GameTime"`, which expires
instantly during a sleep or wait time skip and lets the loop free-run (this is what caused the
merc bark storm). Use `RealTime`, or gate the loop, before copying it into a merc tree.

### 2. Skald — `AreaLabelTrigger`, zero Lua

A quest-graph primitive (`Libs/concept/definitions.xml`, `wh::rpgmodule::AreaLabelTrigger`):

| port | dir | |
| --- | --- | --- |
| `IsActive` | in | edge, auto-triggerable |
| `Souls` | in | optional — the player |
| `Label` | in | string, e.g. `interior` |
| `OnEnter` / `OnLeave` | out | trigger |
| `OnAllEnter` / `OnAllLeave` | out | trigger |
| `Soul` | out | who crossed |

It takes a **label**, not an area reference, so there is nothing to bind per building. This is
a definition primitive, not a vanilla sub-module, so it is safe to use in a mod quest — see
the "primitives only" rule in `docs/skald`.

Companions: `wh::rpgmodule::AreaLabelCheck` (a SoulFunction condition, All/Any),
`wh::xgenaimodule::AreaLabel` (an Effect that adds/removes labels on areas at runtime), and
`AreaTrigger` if you ever do want a specific named area instead.

### 3. Lua — `XGenAIModule.IsPointInAreaWithLabelWUID`

```lua
local wuid = player.this and player.this.id or player.id
local indoors = XGenAIModule.IsPointInAreaWithLabelWUID(wuid, "interior")
```

Registered on the `XGenAIModule` table (registrar `sub_A4B8F4`, alongside `GetEntityByWUID`
which the mod already calls 107 times). Despite "Point" in the name it takes a **wuid** and
uses that entity's own position — signature is `(wuid, label) -> bool`. Polling only; there is
no Lua-side enter/leave event, so if we want an event, use route 1 or 2 and publish the result.

---

## Coverage — read this before relying on it

`interior` marks the enterable volume of **buildings authored as prefabs**: houses, sheds,
barns, stables, bathhouses, plus hand-placed quest interiors. It does not mark:

* castle and church interiors, which tend to use `castle` / `closedCastleArea` / `music_*_indoor`
* anything merely under a roof — porches, arcades, gate passages, bridges
* the mod's own spawned structures (our camp tents, the player house, the walls) — nothing we
  spawn carries a label, so the player is "outdoors" inside our own buildings

384 areas across Kuttenberg is plausible for enterable buildings but is nowhere near the
building *count*. Treat `interior` as **"the player is inside a real, enterable building
interior"** — which is usually what we want — and not as "there is something over the player's
head".

### If you need "under a roof" instead

We already have it: `mercenaries:CampDetectRoof(pos)` in
`data/Scripts/mods/mercenaries_camp.lua`, a downward `Physics.RayWorldIntersection` from
`CampProbeStartHeight` above the player against `ent_terrain + ent_static`, reporting a roof
only if the hit is `CampRoofDetectHeight` or more above the feet (so a tree canopy doesn't
count). That is a geometric test with no authoring dependency, and it is what the camp placer
and `FindOutdoorSpawnAnchor` use. The two answer different questions — use the label for
"in a building", the raycast for "sheltered".

### What does *not* work

`System.IsPointIndoors(pos)` is a live scriptbind, but it is CryEngine's VisArea test
(`p3DEngine->GetVisAreaFromPos(pos) != NULL`). Both shipped levels contain **zero** VisArea or
Portal objects — the only occurrence of the word anywhere in Kuttenberg's 63 MB object list is
a `bIgnoresVisAreas` flag on four entities. It will return false everywhere. Don't spend time
on it.

---

## What the mod ships today

`data/Scripts/mods/mercenaries_interior.lua`, on a 300 ms scheduler slot (`interior`).
One area-label lookup per firing, debounced over two agreeing samples so a doorway
threshold doesn't chatter.

### The log

```
[Interior] ENTERED a building at (2851.9, 683.9, 36.0) - labels: private, semipersonal
[Interior] parked 7 man/men who were following
[Interior] LEFT a building at (2854.1, 681.2, 35.9) after 42.3s inside
[Interior] released 7 man/men (player came back out)
```

The label list on the enter line is the context probe, run once per entry, so the log says
*what kind* of building it was. If the bind stops answering, the module says so after five
consecutive misses and stops — it never reports a silent "outdoors", which is the failure
mode that kept the fast-travel detector looking alive for a year
(`docs/travel-detection.md`).

### Parking the followers

Walk into a building and the men who are **actively following** stop where they stand.
Walk out and **exactly those men** resume. Nobody else is touched, and nobody is
"restored" into a follow he was never on.

*Who counts as following* is not a new judgement. `FollowGate` already republishes every
merc's `$isFollowingActive` into `FollowLatchOf` on each scheduler tick, and that latch is
true only while the follow tree is the behaviour actually running on him — so a man who is
fighting, camping, walking a nav order or stood on a hold station reads false and is left
alone. A stale scheduler heartbeat (`FollowSchedAt`) disqualifies him too, so a merc whose
trees are not ticking is never enrolled.

*How they are stopped* is the scheduler's existing idle arm. `mercenaries.InteriorParked`
is consulted by `MercIsIdle` — the single choke point the behaviour trees read — so a
parked man takes the `$isIdle & ~$isCampActor` branch, which evicts his follow tree,
clears his latch and parks him on an endless `Wait`. Clearing the flag drops him back to
the last arm, which re-fires follow by itself.

Four things that are easy to get wrong here, and what the code does instead:

* **No `FollowStalled` on release.** The idle arm has already evicted the tree and cleared
  the latch, so the man re-fires on his own. A second eviction lands *on* that re-fire and
  pins him standing for good — the bug `HoldReleaseAll` documents at length, which once
  cost a third of the squad. Release does only the two things that are safe at fifty men:
  `FollowStaggerSquad` and `BeginFollowVerify`.
* **The park yields to a fight.** The idle arm sits *ahead* of the combat arm in the same
  `ContinuousSwitch`, so a parked man with a target would stand there and be cut down.
  `MercIsIdle` therefore withholds the park while `MercTargetOf` has an entry for him — a
  table lookup, no engine call in a per-merc, per-tick path. He fights, then resumes
  standing.
* **Three other systems had to learn about it.** The laggard teleporter
  (`MonitorDistanceAndTeleport`) would have hauled parked men to the player — i.e. *into*
  the building — and the follow watch (`DismountVerify`) would have read them as stalled
  and re-fired follow at them. Both now exempt `InteriorParked`, next to the exemptions
  they already carry for camp actors and nav orders. `FollowGhostSweep` needed nothing: it
  only judges men whose latch is true, and a parked man's is false.
* **`MercIsIdle` is not called from Lua.** It stamps `BtHeartbeatAt`, which the follow
  watch reads as proof the trees are ticking; calling it to *test* a merc would forge that
  proof. The two states it would have caught are squad-wide and already turned away by
  `InteriorParkBlocked`.

Never parks at all while a hold or escort order stands, during a wall battle, when the
squad is globally idle, or after a dismissal — those states own the men already.
An explicit `SetState`/`SetSortieWait` order outranks the doorway: it hands the parked men
back, and a "follow me" given *inside* a building suppresses further parking until the
player has been outdoors once. Nothing persists across a load (`InteriorOnLoad`), because
the trees come back fresh with nobody parked.

`mercenaries.InteriorState` holds the debounced answer (`nil` until the first sample).

### Dev commands (need `merc_dev`)

| command | |
| --- | --- |
| `merc_interior` | state, whether the bind answers, every label covering the player, and a per-merc following/parked table |
| `merc_interior_label <label>` | test any one label here — `private`, `stealthArea_crouch`, … |
| `merc_interior_park 0\|1` | the parking behaviour on its own; detection keeps logging either way |
| `merc_interior_verbose 0\|1` | a line every sample instead of just the edges |
| `merc_interior_on` / `merc_interior_off` | the whole subsystem (turning it off releases anyone parked) |
