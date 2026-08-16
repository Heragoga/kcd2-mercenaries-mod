# The siege builder

An in-game placement editor for authoring the siege of Raborsch, in
`data/Scripts/mods/mercenaries_siege.lua`. It is a sibling of the bandit-camp builder — same
feel, same underlying placement engine — with a catalogue built for a siege: men on both
sides, field defences to put them behind, and stations you can place more than one of.

`merc_siege_binds` takes the F-keys. They are shared with the camp builder and the route
recorder, so `merc_bcamp_binds` and `merc_binds_routes` take them back.

| Key | Category | Contents |
|---|---|---|
| F5 | defenders | archer **tower**, archer **cart** — the player's own |
| F6 | attackers | static archer, **patrol waypoint** |
| F7 | barricades | taras a/c, pavise a/b, palisade, sharpened stakes, **2 closed gates**, cannon |
| F8 | tents | 5 small tents, the big round tent, **camp circle**, campfire |
| F9 | props | the camp builder's furniture and props, verbatim |
| F10 | stations | supply cart, tavern, hunter's spot |
| F11 | — | dump the layout and the patrol routes |

Press a category key to select it, press it again to **cycle variants**. The ghost follows
your aim; **left click places, right click undoes**. Both clicks arrive through
`Player.OnAction`, which only fires **with a weapon drawn** — that is a property of the input
map the placement engine has always used. `merc_siege_place` / `merc_siege_undo` do the same
jobs from the console.

`merc_siege_new` clears the site, `merc_siege_list` shows the current category,
`merc_siege_off` leaves the editor, `merc_siege_dump` prints the layout.

## The two sides

**Defenders are towers and carts only.** Ground archers and footmen were here and are gone:
Raborsch is defended off the walls, and a defender stood in the open only walked off and got
himself killed. These are the player's own stations, so no group is passed and their archers
come out friendly exactly as a camp tower's do.

**Attackers are static archers plus patrol routes.** `merc_siege_group` picks which enemy group
(`sigi`, `bandit`, `looter`, `knight`, `cuman`, `prague`); with no argument it steps to the
next. The current group shows in the category readout and is written into each dumped row, so
one siege can mix factions.

## Patrol waypoints

The men who move are defined by a **route**, not placed one at a time. Each waypoint on F6
joins the route currently being built; `merc_siege_patrol` starts a new one. The marker is a
visible stake so the line reads while you lay it out — it is **not** part of the layout, and
undo pops the waypoint back off its route as well as removing the stake.

Routes are dumped **absolute**, not relative to the first piece: a patrol walks real ground,
and the whole point of placing the waypoints by hand is that they sit where the ground allows.
They print separately, under `mercenaries.RaborschPatrols`.

## Placing more than one of a station

The camp's upgrades are **singletons**: `SpawnCampFoodCart` opens with
`if self.CampFoodCart then return true end`, so a second call quietly does nothing. A siege
wants a row of supply carts and more than one tavern, so `SiegeBuildStation` clears the field
before each build and again afterwards.

Undo for these uses the **`CampEntities` watermark**, not the upgrade's own teardown — the
teardown only knows about whichever instance the field currently holds, which after several
placements is not the one you just put down.

## The camp circle

`camp circle` on F8 drops a fire plus a ring of six log seats — the merc camp's own
arrangement — as a single undoable piece, so a besiegers' camp goes in with one click per
fire rather than a dozen.

## Tents, and how to find them

Four are in the F8 list, proven by walking `merc_siege_tents_gallery`: `tent_big_round_a` (the
player tent), `tent_big_round_b`, `tent_big_square_a`, `tent_small_forest_c`.

**Two lessons, both learned the hard way here.**

*A failed guess is not evidence.* The first gallery was eighteen paths invented from the
naming convention; fourteen placed nothing, and that was read as "there are no cuman tents, no
yurt, no pavilion". Wrong. Those *names* do not exist — the assets do, filed differently.
Grepping the reference data turned up `fancytentgypsy`, `gypsycamp_tent_b`, `tent_big_fancy_a`
and, best of all, **`tent_big_square_b_hungarien_green`** — as close to a cuman tent as the game
has, and apt for a story about a Hungarian archbishop. It also has **burned and damaged tents**
(`tent_burned_a/b/d`, `tent_small_b_damaged`), which are exactly what a siege wants and would
never have been guessed.

*The grep is a lower bound, not the asset list.* `references/` is a subset of the game.
`tent_small_forest_c` renders in game and appears nowhere in it. So absence from a grep proves
nothing either — **the gallery is the only real arbiter**. Grep for real names, then walk them.

`merc_siege_tents_gallery` lays the candidates out in a numbered row; `merc_siege_tents_clear`
removes it. `merc_siege_try <path>` does one mesh. Confirmed finds go in
`mercenaries.SiegeExtraTents`, which F8 appends automatically.

## The camp circle

`camp circle` on F8 drops a fire plus a ring of six log seats — the merc camp's own
arrangement — as a single undoable piece, so a besiegers' camp goes in with one click per
fire rather than a dozen.

## Tents, and how to find them

Four tents are in the F8 list, proven by walking `merc_siege_tents_gallery`:
`tent_big_round_a` (the player tent), `tent_big_round_b`, `tent_big_square_a` and
`tent_small_forest_c`.

**A warning about how that list was built.** The first gallery was eighteen paths invented from
the naming convention, and fourteen did not exist — from which "there are no cuman tents, no
yurt, no pavilion" was concluded. That was wrong. Those *names* do not exist; the assets do,
filed differently. Grepping the reference data turned up `fancytentgypsy`, `gypsycamp_tent_b`,
`tent_big_fancy_a`, `tent_big_a`, `canopy_tent_big_a` and a dozen more.

**Never conclude an asset is missing from a guessed path failing.** A wrong path places nothing
silently, which is indistinguishable from a missing asset. Grep the reference data for the real
names first, then gallery those to see which are usable.

The gallery is now loaded with real paths (round 2) awaiting a walk.

## The camp circle

`camp circle` on F8 drops a fire plus a ring of six log seats — the merc camp's own
arrangement — as a single undoable piece, so a besiegers' camp goes in with one click per
fire rather than a dozen.

## Tents, and what actually exists

The F8 tent list is short because most of the game's tents do not exist. Eighteen candidates
were laid out with `merc_siege_tents_gallery` and walked; **four** rendered:

| | Mesh | |
|---|---|---|
| 1 | `tent_big_round_a` | the player tent |
| 2 | `tent_big_round_b` | |
| 6 | `tent_big_square_a` | |
| 13 | `tent_small_forest_c` | |

There are **no cuman tents, no yurt, no pavilion and no military tent** in the game data,
however plausible those paths look. A path that does not exist places nothing silently, which
is why they are proven by gallery rather than assumed.

`merc_siege_tents_gallery` lays the candidates out in a numbered row to be walked past;
`merc_siege_tents_clear` removes it. `merc_siege_try <path>` does the same for one mesh.
Anything else found goes in `mercenaries.SiegeExtraTents`, which F8 appends automatically.

## The camp circle

`camp circle` on F8 drops a whole camp in one click, using **the merc camp's own layout maths**
rather than a ring of its own: `CampRingPos` for each slot, `ringAngle + pi + CampTentFacingFix`
for the facing, and the bed placed off the tent through `CampRelativeOffset(CampBedOffset)`.

Rolling that by hand is what had the tents facing *away* from the fire — the mesh's own facing
convention lives in `CampTentFacingFix` and is **not** the same quarter turn the loose-tent
catalogue on F8 uses. Anything that lays tents out in a ring should call the camp's helpers,
not re-derive the angle.

The ring is sized for `CampClusterTentRingSlots` (7) but only six tents are placed, so a slot
is always left open as a way in — exactly as the merc camp does it.

## Barricades

All vetted picks from `task_specific_props/combat`, purpose-built field defences rather than
repurposed fencing. A **taras** is the Hussite war-wagon shield-wall; a **pavise** is the big
standing shield a crossbowman sheltered behind, which is exactly what a placed archer wants in
front of him. The cannon is included and labelled unrealistic — it looks superb and belongs to
no siege of this size.

There are no chevaux-de-frise, caltrop or spike-trap meshes anywhere in the searchable data;
sharpened stakes (`palisade_wall_single_sharp`) are the closest thing to an anti-cavalry
obstacle that exists.

## The dump

`merc_siege_dump` prints a layout table plus its site row, positions **relative to the first
piece** so it can be replayed anywhere. Each row carries `kind` (defender / attacker /
barricade / tent / prop / station / tower / cart), the catalogue `what`, offsets, `yaw`, and
`group` for anything spawned from an enemy group.

The replay side does not exist yet — the dump targets `mercenaries.RaborschLayouts`, which is
where the siege's own module will read it from.
