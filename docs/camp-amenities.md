# Camp amenities: the chest, the drying rack and the smokehouse

Three fixtures that stand for the camp's lifetime, no upgrade needed: the player's
own chest beside the bed, and a drying rack and a smokehouse beside the tent. All
of it lives in `data/Scripts/mods/mercenaries_amenities.lua` and is rebuilt with
the camp like every other prop (nothing is serialised — see [camp.md](camp.md)).

---

## The personal chest

Spawned from `SpawnCampBedTrigger`, so it follows the player's bed rather than the
tent: the tent's bed and the house upgrade's bed both come through that function,
and it is the point at which "this bed is the player's" is decided.

It is a vanilla **`Stash`** with `chest_rustic_a.cdf` — the same class and model
the camping/personal-chest mods use, and the same one the game's own
`playerMasterChest` uses.

**It opens the player's real stash, not a second one.** `Stash:GetInventoryToOpen`
asks the stash component for a *master inventory* and falls back to its own only
when there isn't one, and a master is declared by an entity link named
**`masterStash`**. That is not a guess: `objects_mission0.xml` has exactly one such
link in the whole Trosky level — the Zelejov inn chest (`chest81`) pointing at
`stash[Chest/playerMasterChest_7602b8a8-…]`.

**But the link does not take when it is made from Lua.** The chest still creates
it, because that is how the level declares one, and the code reads the link first
if it ever does resolve — but in practice the stash's own component has already
settled its master by the time `CreateLink` runs, and re-reads nothing.

So the sharing is done a level up, by overriding **`GetInventoryToOpen`** on the
chest's own entity table (which inherits the class table rather than being it, so
no other stash in the game is touched). It answers with the master chest's
inventory, and every vanilla path then follows: `Open`, `GetActions`,
`EntityModule.CanUseInventory`, and — the one that matters here — the look-at
label, which `Stash:GetActions` builds from `HasPlayerVisibleItems` **on the same
inventory**.

That last one is the whole reason this is the right hook. The first version
overrode `Open` instead, delegating the open to the master chest the way the
personal-chest mod does. It worked — the chest opened with the player's gear in
it — but the prompt was still computed by vanilla code against the chest's own,
empty inventory, so it read *empty* while being full. Overriding
`GetInventoryToOpen` fixes the open and the label in one place; a thin `Open`
guard is all that remains, and only to say `merc_info_chest_locked` when the level
has no master chest at all rather than silently opening an empty container.

Finding the master is a whole-level `System.GetEntitiesByClass("Stash")` scan for a
name containing `playermasterchest` (each level has one: `7602b8a8…` at Trosky,
`8d10f6e9…` at Kuttenberg). It runs once per camp build and the handle is cached in
`CampMasterChest`, which `ClearAnyLeftoverCamp` drops on every load — the two
regions are separate levels and the handle must not cross between them.

**Placement.** `CampChestOffset` is `{ right = 1.55, forward = 0.7 }` in the *bed's*
own frame. The sleeper lies along `right` (see `CampBedSOYawFixDeg` in
[camp.md](camp.md#positioning-the-bed-under-a-tent)), so `right` puts the chest past
the head or feet; the narrow `forward` sides are the tent's centre pole one way and
its canvas the other, which is why it isn't there. A chest's open face is a quarter
turn off its yaw (`CampChestYawFixDeg`, 90), so the yaw is computed from "point the
face back at the bed" plus that fix — flip the sign if it ends up back-to-front.
`merc_camp_chest_yaw <deg>` sets it and re-pitches the standing camp, and
`merc_camp_chest <right> <forward>` moves it. Note which axis is which from the
bed's point of view: `CampRelativeOffset`'s `right` is `forward` turned a quarter
turn anticlockwise, so standing at the bed looking down `right` at the chest, it is
`forward` that moves it to the viewer's right.

No ground snap: the house's bed stands on a raised deck and the tent's is already
snapped, so the chest simply takes the bed's own Z.

---

## The drying rack and the smokehouse

Both are the **butcher's own food-processing stations**, rebuilt piece for piece
from `references/Prefabs/profession/butcher/butcher_dryer.xml` and
`butcher_smokeHouse.xml`. They are real, not dressing: E on either opens a filtered
multi-select inventory, and the game dries or smokes what you put in.

Three entities per station:

| Piece | What it does |
|---|---|
| the mesh | `drying_rack_a.cgf` / `smokehouse_a.cgf`, a normal static camp prop |
| `FoodProcessingTrigger` | the "E — use" prompt and the filtered inventory (`InventoryMultiFilter`, `UseMessage`), plus the vanilla tutorial popups |
| `SmartObjectHolder` | carries the `so_smokehouse` smart entity, whose brain actually does the work |

The chain is: the trigger's `TriggerBase:ReportUse` sends
`interactionModule:itemSelection` and `interactionModule:onInteraction` to
**everything it links to**; the holder's `onUpdate` tree catches both and fires
`player_useSmokehouse` on the player, which plays the `SmokehouseSniff`/`Drying`
animation and then runs `PrepareFood` (`Smoke`/`Dry`) or `DryHerb` over the chosen
items. So the single trigger→holder link is the whole connection between prompt and
behaviour, and the link's *name* doesn't matter — `_GetSendTargets` walks every
link regardless.

**None of this is level data**, which is why it can be spawned at all. The holder's
`guidSmartObjectType` `13611b23-…` resolves through `SmartEntity__so_smokehouse.xml`
to the `so_smokehouse` brain, all of it database-driven at runtime. The holder's
`Script.Misc` carries `isSmokehouse:true|false`, which is the branch the tree reads
on init to pick smoking over drying; the trigger's carries
`foodProcessingType:smoking|drying`, which only picks the tutorial.

Two details copied verbatim rather than reasoned about, because the vanilla prefab
is the only reference for them:

* The trigger's local offset and scale (`{−0.003, −0.065, 0.778}` @ 0.2935 for the
  rack; `{−0.003, −0.454, 0.648}` @ 0.45 for the smokehouse) and its
  `fZToleration = 2` / `fAngleTolerance = 90`.
* The holder sits at the station's own origin and yaw, with **`orientation` set at
  spawn as a forward direction vector** — the player is aligned to this entity for
  the animation, and a smart object caches its helper transform at creation, so a
  later `SetAngles` would move the entity and not the pose (the same trap
  `SpawnCampFurnitureSO` documents).

The smokehouse also gets the prefab's `WH_Particels.smokes.smokehouse` particle.

**The rack's material.** The prefab renders it with
`drying_rack_a_interactive` rather than `drying_rack_a` — the interactive
(`%COLORIZING%`) variant that highlights under the use prompt. Overriding a
material on a multi-submaterial mesh is the trap that once lost the wagon its body,
so this was checked: both `.mtl` files carry the same six submaterials
(`branch_ab`, `branch_ab_decal`, `wicker`, `wicker_twigs`, `rope`, `proxy_wood`) in
the same order, so nothing can be dropped.

**The smokehouse mesh is a `.cgf`, not the prefab's `.chr`.** The prefab hangs
`smokehouse_a.chr` on an `AnimObject` because its door animates; `smokehouse_a.cgf`
sits beside it in the same pak and is the same model without needing a character
slot, so it goes down the normal static-prop path.

**Placement.** `CampAmenityOffsets` holds `right`/`forward` per station, in the
frame of whatever stands at the camp centre — the tent's entrance
(`facingAngle + 130°`) or, with the house upgrade bought, grid-forward (the house's
door). Both sit to the left, since the quartermaster stands to the right. Each is
turned so its working face looks back at the tent, and each claims its own
footprint (`CampClaimFoot`) before the fire clusters are laid out, so the camp
routes around them. Those footprints are measured off the `.cgf` and written into
the spec rather than read from `CampPropFoot`, which only covers the models
`tools/measure_camp_props.py` scans.

`merc_camp_amenity <dryer|smokehouse> <right> <forward>` moves one and re-pitches
the standing camp; with no arguments it prints the current pair.

---

## Files touched

| Piece | File |
|---|---|
| The chest, both food stations, and the three tuning commands | `data/Scripts/mods/mercenaries_amenities.lua` |
| The chest spawn hook (in `SpawnCampBedTrigger`), the amenity call in `SpawnMercCamp`, the new classes in `CampPropClasses`, and dropping `CampMasterChest` on load | `data/Scripts/mods/mercenaries_camp.lua` |
| Script registration | `data/Scripts/mods/mercenaries.lua` |
| `merc_info_chest_locked` (16 languages) | `localization/*.xml` |
