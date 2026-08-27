# Camp gates

A gate is placed on its own, independently of any wall, and can be opened or shut.
Shutting them seals the camp: a closed gate blocks pathing exactly like a piece of
wall. It does not call a raid off — raiders march on the gate whether it is barred or
not, form up in front of it, and force it open when the fight opens. Barring the gate
buys the company the time to make its line, not immunity.

Meshes are `gate_wooden_d` (open) and `gate_wooden_d_closed` (shut) — the same gate
carved both ways, which is the only true open/closed pair the game ships. There is no
animated field gate anywhere in the data, so swinging a gate is a mesh swap.

## Player flow

Quartermaster → **upgrades** → *Hang a gate in the palisade (400 groschen)*, then aim
and click, same as the tower and the archer cart. Bought per gate, up to `GateMax`
(4). Quartermaster → **the gates** swings every gate in the camp; it toggles, so one
option covers both open and shut.

Gates persist against the camp anchor with the rest of the defences, open state
included, and are left behind when the company pitches somewhere new.

## Console

| command | |
|---|---|
| `merc_gate_build` | aim-place a gate (no charge) |
| `merc_gate_open` / `merc_gate_close` | swing every gate |
| `merc_gate_status` | list the gates and whether raids are suppressed |
| `merc_gate_remove` / `merc_gate_clear` | remove the nearest / all |
| `merc_gate_style <n>` | swap the mesh pair (1 = wooden_d, 2 = road barrier) |
| `merc_gate_yawfix <deg>` | rotate every gate's **mesh** (default 90) — cosmetic only |
| `merc_gate_sink <m>` | raise/sink every gate |
| `merc_gate_walldist <m>` | clearance between a snapped gate and the wall (0 = flush, negative overlaps) |
| `merc_gate_width <m>` | gate length (default 4) — blocking span *and* the slot the wall leaves |
| `merc_gate_colliders <0\|1>` | show the shut gate's invisible collider crates |

`GateWidth` (4 m, per style) is the gate's length along its own panel. It is used for
both the blocking span of a shut gate **and** the slot the wall builder leaves for it,
so the two can never disagree — change it with `merc_gate_width` and both follow.

`GateYawFix` (90°) turns the **mesh only**. It is deliberately not applied to
`GateBlockSegments`: the blocking span comes from the gate's logical yaw, so turning
the mesh to suit its own front axis can never swing the seal off the opening. Anything
that reads gate geometry must use `g.yaw`, never `g.yaw + GateYawFix`.

## Opening a gate by hand

Walk up to a gate and the crosshair offers **Open** / **Close** on `E`, like any door.

That needs a custom entity class — `mercenaries_Gate`
([Scripts/Entities/mercenaries_Gate.lua](../data/Scripts/Entities/mercenaries_Gate.lua),
registered by `data/Entities/mercenaries_Gate.ent`, the same two-file pattern as
`mercenaries_Prop`). It physicalises PE_STATIC like the prop class and adds the usable
machinery a door has: `IsUsable` returns 1, and `GetActions` offers one action whose hint
depends on the state.

No new game data was needed. The prompt reuses the game's own `@ui_door_open` /
`@ui_door_close` strings and the `inr_doorOpen` / `inr_doorClose` interaction filters —
`inr_*` globals come from `Libs/Config/interaction_filter.xml`, where both are declared.

Three things that are easy to get wrong:

* **Do not call `EntityCommon.MakeUsable`.** It *defines* `IsUsable`, gated on the
  `bUsable` property, so calling it after your own definition silently overwrites it and
  the prompt never appears. `AnimDoor`, `Ladder` and `Bed` all skip it and supply their
  own — this class does the same.
* **The state has to ride on the entity.** `GetActions` runs on the entity and cannot see
  the gate record, so `mercGateOpen` is pushed onto it at spawn.
* **`OnUsed` must not swing the gate inline.** Swinging swaps the mesh, which destroys the
  entity whose callback is still running. `GateToggleByEntity` stashes the gate and defers
  the work a tick through `GateToggleDeferred`.

## Colliders

A spawned mesh's own physics proxy does not reliably stop the player, so a shut gate gets
the player-house treatment: a line of PE_STATIC crates tiled across the opening and hidden
with `DrawSlot(0, 0)`, which drops the render slot and keeps the physics.

They are laid along the gate's own panel — the same span `GateBlockSegments` blocks for
pathing — so what stops an NPC and what stops the player are the same line. Three layers
(`GateColliderLayerZ` 0.5 / 1.5 / 2.5) stop it being vaulted.

**Only the closed variant has them.** They are built in `gateSpawnEnt` when the gate is
shut and torn down with the entity on every swing, so an open gate is walkable.
`merc_gate_colliders 1` makes the crates visible to check the span actually covers the
opening; `merc_gate_status` reports the count per gate.

## Staying up

A gate's mesh is a spawned, deliberately non-serialised entity, but the gate **record** is
plain Lua state that outlives it. Anything that removes the entity without going through this
module - a save load, a level change, a sweep of dynamic entities - leaves the camp with a gate
on its books and nothing standing in the gap, and until now nothing ever put it back. That is
the "the gate disappeared after a while" bug. Three things now hold it up:

* **`GateWatchdog`** (low-priority tick, 5 s, at most `GateMax` records) asks
  `System.GetEntity` whether each record's prop still exists and hangs it again if it does not.
  Live gates get their view distance re-pinned in the same pass, since a re-created entity
  comes back at the engine default.
* **The restore is no longer allowed to lose a race.** `DefArmRestore` sets
  `DefRestorePending` alongside the 1500 ms `DefRestoreDelayed` timer, and that flag does two
  jobs: `DefSave` **refuses to write** while it is set - otherwise a gate command in the window
  between the camp going up and its defences coming back saved the *empty* world over
  `QMGates` and the gates were gone for good - and `DefWatchdog` runs the restore by hand if
  the timer never fired (a timer chain dies with the level it was armed in, see `SchedOnLoad`).
* **A restored gate is not ground-snapped again.** `GateBuild` takes a `noSnap` argument and
  `DefRestore` passes it. The saved z was snapped when the gate was first hung; re-snapping
  fires `CampSnapToGround`'s ray from `z + 5` through whatever static geometry now stands at
  that spot - the palisade the gate is butted against, a camp prop - rather than the terrain,
  so the gate climbed a little further out of the ground on every rebuild.

`DefRestore` also clears the gate list before rebuilding it, exactly as it already did for
`WallRuns`: `GateBuild` appends, so a restore that ran with gates still on the books stacked a
second copy of every one of them.

## How sealing works

`GateBlockSegments` returns one segment per **shut** gate, laid across the opening
perpendicular to the way the gate faces, and `NavWallSegments` appends those to the
wall segments. So:

* shut gate → the navmesh sees wall → nobody walks through it while it stays shut;
* open gate → contributes nothing → the opening is walkable again.

Either way the gate is still where the battle happens. `NavFindGaps` checks for gates
*before* it sweeps for holes, so a walled camp that has one gets one gap per gate
(`WBGateGaps`) regardless of open state — which is what stops a sealed camp falling
through to the "wholly enclosed" stand-in and mustering both sides on an arbitrary
bearing. `WBForceGates` then swings the gates under attack as the phase turns to
`battle`; gates on the quiet side of the camp stay barred.

Sentries post on the gates once any exist (`NavGatePosts`); with none they fall back
to the ends of the longest wall run, as before.

## Building a gate while building the wall

While drawing a palisade, bringing the aim within `WallGateSnap` (**3.5 m**, one palisade
piece) of *any* existing wall turns the tiled wall preview into a **gate ghost**, and the
click hangs a gate there instead of dropping a corner. That is how a stretch is finished:
run the wall round, come back to another stretch (or to your own start), and close the
opening with a gate.

* Free — the stretch was already paid for. The quartermaster's 400-groschen gate is for
  adding one to a camp that is already built.
* Hanging the gate **commits the stretch being drawn**: the gate is its end, and marking on
  past it would run wall straight through the opening. You stay in build mode, so the next
  click starts a fresh stretch.
* The gate **snaps onto the wall it has reached**: it takes that palisade's nearest
  endpoint and that palisade's *own* direction, so it is collinear with it and its edge
  sits on the wall's last corner.
* The preview then walls the whole way from the live corner up to the gate's outer edge,
  and everything behind the gate stays ordinary palisade. Clicking does exactly what the
  preview showed.
* `merc_gate_walldist <m>` sets the clearance at the join; `merc_wall_gatesnap <m>` tunes
  how near counts as near, `0` disabling snapping entirely.

### Why it used to leave a gap

The gate was oriented along the **direction of travel** while the palisade it was meeting
ran at some other angle, and an angled join can never close — the two cannot touch on both
sides at once, so there was always a wedge. Snapping the gate to the wall's own direction
removes the angle, and butting it against the wall's endpoint removes the distance.

That fixes the join on the wall side. The join on the *run* side was a second, separate
gap: tiling lays whole segments and cuts the remainder, so the run stopped up to one piece
short of the gate. The last edge of a gate-closed run is therefore built **flush** — one
extra piece, laid so its far edge lands exactly on the gate. It overlaps its neighbour by
whatever the remainder was, and an overlap in a line of stakes is invisible where a gap is
not. The run carries a `flushEnd` flag so a rebuild (after a save, or a retune of the
segment length) does not reopen the seam.

Both seams measure 0.000 m in simulation across straight, angled-target and angled-approach
cases.

A wall piece carries `WallUp` (-3 m, which sinks the palisade mesh into the ground), so
the gate cannot inherit a piece's z — the ground is re-read at the gate's own spot, or the
gate would be buried.

The run being drawn is excluded from the test for its last `WallGateSnapSkip` (2) corners,
otherwise the corner you just dropped would itself read as "a nearby palisade" and every
preview would snap to a gate the moment you started. Extending a run stays wall; coming
back to its start becomes a gate.

Because any aim within 3.5 m of a wall is gate territory, you can no longer join two
stretches with wall — the junction is always a gate. That also means `WallGateMin` is now
0: nothing needs to refuse a corner for leaving a gateway, since closing the last of the
gap gives you a gate by itself.

## Walls: many stretches

`merc_wall_build` (and the quartermaster's palisade purchase) now starts a **new**
stretch each time and leaves every earlier one standing, so a camp can be walled a
side at a time. `mercenaries.WallRuns` holds the finished stretches and `WallMarks` is
the one being drawn; `WallAllRuns()` is what every consumer reads.

* `merc_wall_undo` steps back a corner, and steps into the previous stretch when the
  current one runs out.
* `merc_wall_undo_run` drops the whole of the last stretch.
* `merc_wall_clear` still removes everything.

`merc_wall_close` can still seal a ring deliberately; it is a builder tool, and raid
suppression keys off gates, not off that flag.

The guards' wall-hugging patrol follows the **longest** stretch only: splicing several
disconnected stretches into one loop would march them through the gaps between them.

Saved wall data is one stretch per `|` field, so a single-stretch string from an older
save still loads as stretch one.

## Where the candidates came from

The shipped level layers only reference meshes that level happens to use, so they
under-report badly (`palisade_wall_a_v3`, which we already ship, is not in them). The
complete list comes from the game's own object archives, which are plain zips:

```bash
python -c "import zipfile,glob;print('\n'.join(sorted({n.lower() for p in glob.glob(r'C:/Program Files/Steam/steamapps/common/KingdomComeDeliverance2/Data/IPL_Objects-part*.pak') for n in zipfile.ZipFile(p).namelist() if n.lower().endswith('.cgf')})))"
```

That is 16 541 meshes, and reading the zip directory does not unpack anything. The
plain `Objects-part*.pak` files hold no `.cgf` at all — only the `IPL_` ones do.

`merc_gate_matrix` is the gallery those picks were made from: all 30 gate-ish meshes
in a grid, each flanked by a piece of the camp palisade so scale and material can be
judged against the wall the gate has to join. `merc_gate_matrix_clear` removes it;
`merc_gate_mx_yaw` / `merc_gate_mx_up` / `merc_gate_mx_list` tune and list it.

Other notes from that sweep:

* `palisade_halved_lower_gate_nebakov.cgf` is the only gate shipped inside the
  palisade kit itself, but it is a `halved_` piece sized to the
  `palisade_halved_wall_*` set, not to our full-height `palisade_wall_a_v3`.
* `gate_beams_a` comes with separate `_door_left` / `_door_right` leaves — the only
  candidate set that could ever be animated open, if that is ever worth doing.
* No candidate hides its collision in a sibling `cv_*.cgf`, so none needs the
  invisible-crate-collider treatment (see `camp-forge.md` for when that bites).
