# The camp screen

`U` opens it. The corner hint says so whether or not a camp exists and whether or not you
have any men — pitching one is exactly what you do when you have neither.

Built by `tools/make_camp.py` into `MercCamp.swf` + `mercenaries_campatlas.lua`, driven by
`data/Scripts/mods/mercenaries_campui.lua`. The art contract is the same as the command
interface: see [command-ui.md](command-ui.md) for the Scaleform rules (percent scales, the
baked 1/ss shrink, the deferred first layout).

## Two rules the driver must not get wrong

Both of these looked fine in the offline preview and were only visible in game.

**Where a clip registers.** `Atlas.add(..., center=True)` shifts a sprite's contents by
-w/2,-h/2 so it is positioned by its middle; `center=False` leaves it registered at its
top-left corner. The atlas now emits that flag as `c` beside each clip's size, and `place()`
converts, so every caller says where the MIDDLE of a clip goes and the panels stop landing
half their own size down and to the right.

**One instance per character POSITION, not per character.** A MovieClip instance is what can
be moved, so a figure built from a shared set of ten digit clips asks the single "0"
instance to be in two places at once when it draws 500 - and only the last placement shows.
Every figure that can be on screen beside another one gets its own column of instances
(`n_<field>_<pos>_<glyph>`); `numfields()` in tools/make_camp.py lists them.

## Two modes, one screen

Slot 1 of the bottom row is always the mode toggle and slot 2 is always the camp itself, so
neither of the two things you always need can page away.

| | left panel | right panel | row |
| --- | --- | --- | --- |
| **Build** | every improvement and its status | the focused improvement, its price, and the camp's tile budget | mode, camp, 6 improvements, More |
| **Logistics** | the company's books | what is standing and what it gives, plus the food graph | mode, rations, drink, wages, war chest |

The row reads left to right as the number row; wheel spokes number themselves 1..N. The row
is inert while a wheel is open, so the two can share keys. `U` backs out of a wheel, then
closes the screen.

Keys 1-4 are `qam_1..qam_4`, which unsheathe the weapon in that quick slot. The screen holds
the same weightless marker token the command interface uses, which drives the `FilterInput`
node that blocks them - see [command-ui.md](command-ui.md). It is released on close and
cleared unconditionally at every gameplay start, so a crash with the screen open cannot
leave the filter stuck on.

Both screens keep a corner prompt and together they are one column: the camp's is row 0 and
the command interface's is row 1, 34 units under it. While THIS screen is open its Close prompt
moves beside the compass, clear of its own panels (the command interface leaves its prompts
where they are) - see
[command-ui.md](command-ui.md#the-close-prompt-has-its-own-home). The corner itself is a player setting
(`merc_hints_pos`, or the quartermaster's [Mod settings]) shared by both screens - see
[command-ui.md](command-ui.md#where-it-sits-and-turning-it-off). The command nudge is
suppressed entirely while the camp screen is open, so only one of them ever speaks.

## One screen at a time

The two screens are mutually exclusive, and opening one closes the other. `CUShow` hides the
command interface and `BLShow` hides this one, so U-then-H and H-then-U both swap.

That is an input rule before it is a layout one. The camp screen binds nothing of its own -
it holds the command interface's keys and `BLKey`/`BLSelect` forward into `CUKey` while
`CU.on` - so with both screens up, which of them a number key reaches comes down to which
test runs first. Order matters in `BLShow` for the same reason: it closes the camp screen
BEFORE taking the keys, because `CUReleaseKeys` hands them back to the game on its way out.

A swap does not stack. Closing a screen closes it and nothing reopens behind it - there used
to be a `restoreBL` flag that brought the command interface back when the camp screen shut,
and a screen appearing without a keypress is exactly what players objected to. The corner
prompt is what says the other screen is one key away.

`tools/check_uistate.py` runs both drivers in a real Lua interpreter and presses the keys,
so none of the above can quietly stop being true.

## Three states, and why "owned" exists

An improvement is **for sale**, **stored**, or **built**. Stored is not a bookkeeping
nicety: the camp rebuilds itself out of the logistics flags every time it is pitched, so an
upgrade you bought survives breaking camp and comes back up with the next one. That is why
breaking camp never costs you anything you paid for.

`CUStatus` derives all three from `LogiState`; nothing in the screen keeps its own copy.

## What the buttons actually call

Everything routes into `mercenaries_logistics.lua` and `mercenaries_camp.lua`:

- Buy → `LogiBuyFoodCart` / `LogiBuyInn` / … / `LogiBuyCastleWall`.
- Remove → `LogiRemoveUpgrade`, by its index in `UpgRemovable`.
- Tower, archer cart, gate and wall hand straight over to the game's own aim-and-click
  placement, so the screen hides itself and gets out of the way.
- Rations / Drink / Wages / War Chest → `LogiDeliverFood`, `LogiPanelFood`, `LogiBuyFood`,
  `LogiDeliverDrink`, `LogiPanelDrink`, `LogiToggleWithholdWages`, `LogiDepositCoffer`,
  `LogiWithdrawCoffer`.
- Camp → `SpawnMercCamp`, `BreakMercCamp`, `CampReturnAll`.

## What each action does

Pitching a camp stands up everything you own — there is no auto-build switch and nothing to
opt into.

| | Buy | Construct | Relocate | Remove |
| --- | --- | --- | --- | --- |
| a station (cart, tavern, hunter, smithy, bench, yard) | when you do not own it | when it is in storage | when it stands | stows it |
| tower, archer cart, gate, palisade, stone wall | when you do not own it | when it is in storage | never | stows it |
| tent rings | never — they come with the camp | never | steps through them | never |

**Relocate is never offered for towers or walls.** They are placed by their own
aim-and-click, and running it again ADDS one rather than moving the one that stands, so for
those the pair is deconstruct and reconstruct.

**Remove stows, it does not destroy.** You paid once; `CampStowed` remembers what you had
and how many, so the next camp gets them back for nothing.

Moving one piece rebuilds the camp, and a rebuild re-derives everything that is not pinned —
which is how moving a single tent ring shuffled the rest of the layout. `CUPinLayout` writes
the standing cluster centres and the training ground into the same overrides first, so the
rebuild reproduces them exactly and only the piece you chose moves. Stations need nothing
there; they already keep their own tiles.

The training ground is positioned off `CampTrainCenter`, which `SpawnMercCamp` recomputes
from the camp's forward angle on every build — it overwrote the chosen spot before the yard
spawned, so it could not be moved at all. `CampTrainPlaced` now wins over the computed value,
and is saved alongside the rings.

**Tent rings** all go up with the camp, so there is nothing to construct — only to move.
Relocate walks them in turn: the first press moves ring one, the next ring two, wrapping at
the end. How many there are is read from `CampClusterCenters`, the camp's own list — an
estimate from the head count addressed rings that did not exist, and those presses did
nothing.

The chosen spot goes into `CampCirclePlaced`, and the override is applied to
`clusterCenters` **before anything reads it**. That position is not just where the ring is
remembered: the campfire, the seats, the tents and the beds are each placed off it further
down the build. Applied after that point it moved nothing at all — the ring stayed where the
grid put it and only the saved position changed, which is what "the fire doesn't come along"
looked like.

## Placing an improvement yourself

Construct and Relocate are the same gesture: a projection follows your aim, left click puts
it down, right click backs out. It reuses the mod's existing placement framework
(`StartPlacement` / `GhostBuild` / `ConfirmPlacement` in `mercenaries_tower.lua`), so the
mouse handling, the validity test and the ghost are all the ones the tower and cart already
use.

What made this a small change rather than a large one is that every camp improvement already
asks **one** function where it should stand:

    local spot, ang = self:CampStationSpot("forge")   -- and "cart", "inn", "hunt", "alchemy"

`CampStationSpot` now answers with `CampPlacedSpots[name]` if the player has put that station
somewhere, and only falls back to the automatic grid tile otherwise. So a chosen spot
overrides the layout for that one improvement and leaves every other one alone, and the camp
still rebuilds itself as a whole exactly as before.

Chosen spots are saved as `MercCampPlaced`, in the same format and with the same anchor gate
as the automatic tiles: a spot chosen around one camp means nothing around a camp pitched
somewhere else, so moving camp drops them and the automatic layout takes over again.

The practice yard is the exception — it positions off `CampTrainCenter` rather than a station
tile, so its placement writes that instead.

**Not placeable this way:** the tent rings and your own tent, which *are* the camp's layout
rather than stations within it (move the camp instead), and walls, gates, towers and carts,
which have had their own aim-and-click since long before this screen existed.

Left click places and right click cancels — but those reach the placement code as
`attack_primary_mouse` and `block`, which live in the **combat_base** action map and may only
fire with a weapon drawn. So while aiming, **1 places and 2 cancels** as well: those ride the
same input route as the rest of the screen, which is known to arrive. Input logging is turned
on for the duration of a placement, so a report of "left click does nothing" can be answered
from the log rather than guessed at.

**A wall is not a placement.** Tower, cart and gate go through `StartPlacement`, so
`ActivePlacement` is set for their duration. `StartWallBuild` is a build MODE and leaves
`ActivePlacement` nil the whole time, so anything that tests it to decide "is a placement
still running" must test `WallBuildActive` too — the watchdog did not, decided the placement
had ended, and put the screen back up half a second into the run.

While a spot is being chosen the screen sets `CU.placing`, and that suppresses everything
it would otherwise draw — including the corner hint — and stops it handing the frame back to
the command interface. Hiding once was not enough: the command interface auto-shows itself
off its own hint update, so something kept reappearing mid-aim. A single-instance, capped
watchdog clears the flag if a placement ends through code that never calls back here (tower,
cart, gate and wall all do).

The spot test is deliberately permissive — anywhere you aim. It is **not**
`TowerSpotIsValid`, which refuses any spot within `TowerCampClearRadius` of a camp prop:
that is the right rule for a watchtower and exactly the wrong one here, because a tent ring
or a smithy belongs *inside* the camp. With that test in place every sensible spot was
refused, the click reported "blocked", and nothing happened. Always-valid also means the
ghost never flips to the pink invalid material, so the projection keeps the prop's own
texture.

Ghost meshes are asserted against the game paks by `tools/check_campui.py` — a mistyped
`object_Model` spawns a `BasicEntity` that renders nothing, with no error anywhere, so the
projection would simply never appear.

## Pitching a camp alone

`SpawnMercCamp(atOrigin, silent, allowSolo)` — the third argument is new and only the camp
screen passes it. Every other caller keeps refusing at zero men, because pitching a company
camp with no company is a mistake everywhere else. With it, the player tent goes up on its
own; the cluster maths already floors at one, so the tent rings simply come out empty.

## Tiles

The camp is a fixed number of tiles and every improvement claims one:

    total = CampTileBase (6) + floor(men / CampTilesPerMen (6))

so the ground grows with the company. The build panel draws the budget as the ground itself,
with the tile the focused improvement would claim picked out in gold.

## The food graph

`LogiProcessUpkeep` records the food left after each evening ration into
`LogiState().foodHistory`, capped at `LogiHistoryDays` (14) because it is serialised into the
save as a string. The graph scales each bar against the highest reading in the window; a bar
at or below three days' consumption is drawn in the warning colour.

## Guards

`tools/check_campui.py` walks every state the screen can reach and asserts that each clip
name the driver can form exists in both the atlas and `MercCamp.xml`, that no Lua local is
used above its declaration, that every mod function the driver reaches by name is defined,
and that the key-bound commands are `PlayerCommand`s (a `DevCommand` would need `merc_dev`
typed first, and the whole screen would silently do nothing).

Run it after any change to `tools/make_camp.py` or the driver.
