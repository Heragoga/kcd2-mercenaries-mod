# The custom uniform

Drop one set of gear in a chest and the whole company wears a copy of it — every
tier, and the archers too. You get the set straight back. It is the seventh entry in
[`mercenaries.Outfits`](outfits.md) and the **second** thing the player sees in the
equipment menu, right after Generic.

Inspired by SirVanir's *NPC Dresser* (`references/NPC_Dresser_SirVanir/`), which
dresses one NPC at a time by opening a transfer store on him; this does the same
thing for a squad, from a pattern rather than the items themselves.

---

## Player flow

1. **"I want you to dress this way..."** — a **top-level option on both** the
   quartermaster's dialogue and any merc's — drops a chest 100 m under the player's
   feet and opens the transfer window on it. No camp needed, anywhere in the world.
   The chest is never meant to be walked up to; the window is the whole interface.
2. Put a set of kit in and close the window. Five seconds after the chest stops
   changing the **transaction is over**: the pattern is saved, every piece is handed
   back, and the company is re-cut onto the Custom uniform.
3. The men wear *copies* (`inventory:CreateItem`), so nothing the player owns is
   spent. The chest keeps listening for three more minutes, so carrying on where you
   left off just works.
4. The uniform can be reselected any time from the merc dialogue or the order wheel
   ("Our own kit").

**The pattern accumulates, newest wins per slot.** Come back with a pair of hose and
they are *added* to the harness; come back with another helmet and it *replaces* the
first. `merc_gear_clear` wipes it back to nothing.

**An empty pattern is legal**: the men go bare with a plain shortsword. That is what
"Custom" means before anything has been handed over, and handing over nothing is how
you get back to it.

**Why a chest and not the delivery panel.** The first build used a Skald
`CreateItemDelivery` panel pointed at the quartermaster, the way the food and drink
panels are. Two things killed it: the panel hangs off a `ForEach` over his soul, so
it did nothing at all without a camp standing, and the gear landed in a live NPC's
inventory where getting it back out again depended on a `MoveItemOfClass` round trip
that did not survive contact — the player lost the set. A `Stash` is spawned by this
mod in seven other places, always works, needs no camp and no NPC, and its worst
failure is *"your gear is in that chest"* rather than *"your gear is gone"*:
`GearEmptyChest` re-reads `GetCountOfClass` after every move and refuses to delete a
chest that still holds anything.

---

## What the mod does with the set

| Given | Result |
|---|---|
| Anything at all | a plain shirt, hose and shoes go on underneath, unless the pattern brings its own |
| A torso plate or mail or arm armour, no gambeson | a plain gambeson is added underneath |
| Leg armour, no padded chausses | padded chausses are added |
| A helmet, no padded coif | a padded coif is added |
| Spurs, no boots | boots are added |
| A helmet *and* a cap | the cap is dropped |
| Two things for one slot | the newest wins, the older is replaced |
| Horse tack | dropped |
| A quest item | refused, with a line saying so |
| A melee weapon | every merc carries it |
| A shield | every merc carries it, and the base loadout switches to a shield one |
| A bow or crossbow | archers use it (and get its ammo); footmen carry it over their sword |
| No weapon at all | a plain shortsword |

The layering rules are not cosmetic. `equipment_slot.xml` declares
`RequiresFilledSlot`, and a slot **silently refuses** everything until the layer
under it is filled — a cuirass handed over on its own would simply never go on and
nothing would say why. `GearPrereqSlot` / `GearPrereqItem` are that table, turned
into a fix.

The shirt, hose and shoes are a different rule and were missed because of it:
**nothing requires them.** A pattern of harness pieces names no hose, the purge then
deletes the base preset's, and the man is left with bare legs under his leg plate —
hidden by padded chausses on nine mercs out of ten, and plainly visible on the one
whose chausses or leg plate did not take. `GearBaseFillItem` puts them back. A pattern
that names *nothing at all* is left alone: empty still means a naked man with a sword.

---

## How it is built

### The baked lookup — `mercenaries_gear_data.lua`

Nothing in the scriptbind reports an item's slot or its category. `ItemManager` has
`GetItem`, `GetItemName` and `GetItemUIName` and that is all; there is no
"what slot does this class go in" call and no "what is in this slot" query either.

So it is generated offline. `tools/gen_gear_table.py` reads **every** `item*.xml` in
`references/base_game/Libs/Tables/item/` and emits **3167 armour GUIDs keyed by
equipment slot and 730 weapon GUIDs keyed by weapon class**, plus the 70 that carry
`IsQuestItem`. The chain it walks:

    item*.xml <Armor|Helmet|Hood>.Clothing  ->  strip the "NN_mNN" tail
      -> armor_type.xml Name                ->  equipment_slot.xml ArmorTypes -> slot Id
    item*.xml <MeleeWeapon|MissileWeapon>.Class -> weapon_class.xml id
    item*.xml <ItemAlias>.SourceItemId      ->  graded as whatever it aliases

> It used to read `item.xml` alone, which left **1120 vanilla gear items** — all of
> `item__dlc`, `item__unique`, `item__rewards`, `item__aux` and `item__horse` — looking
> exactly like modded items to the wardrobe, which silently ignored them. Horse tack is
> matched by keyword rather than prefix for the same reason: the names are
> `BasicBridle03_m04` and `EastSaddle02_m01`, which do not *start* with `Bridle` or
> `Saddle`, so all 415 pieces fell through to slot 0 — a legal, **wearable** answer,
> meaning the wardrobe would have offered your men a saddle to put on.

GUIDs are stored dashless and concatenated 32 characters apiece, grouped by slot.
`GearBuildIndex` unpacks it **lazily**, on first use — a session that never touches the
wardrobe never pays for it.

126 items end up with no slot (spectacles, a hangman's noose, scabbards, a painter's
torso). Slot 0 is a legal answer: those are equipped last and never trigger a
prerequisite. Re-run the generator after a game patch.

### Items from other mods

A modded item is in none of the tables, and so is a loaf of bread — but the wardrobe
must wear the first and ignore the second. That is what the fourth table is for:
`GearNonGearBlobs` lists every **vanilla** item that is *not* equipment (food, potions,
tools, documents, ingredients). The rule, in `GearIsWearableClass`:

| in the slot or weapon table | vanilla gear | worn, fully graded |
| in the non-gear table | a misdrop | ignored, as before |
| in none of them | **not vanilla at all** | taken to be modded equipment, and worn |

Modded pieces then get a slot the only way left: `ItemManager.GetItemName(guid)` returns
the item's database name, and for 98% of vanilla armour its leading letters are the
clothing family that decides the slot. `GearSlotByName` reads that prefix against the
same mapping the generator used (`GearNamePrefixSlots`, longest-prefix-first), so a
modder who copied a vanilla row — which is how nearly all of them are made — gets a real
slot, and with it the layer order and the gambeson-under-plate rule. **That rule is why
this matters rather than being a nicety: plate offered with no gambeson under it is
refused by the engine without a word,** so an unslotted modded cuirass would simply never
appear. Anything the proxy cannot parse stays unknown and is worn last, which still works
for a single piece.

Two honest limits. A modded item is invisible to `GearScanInventory`, the fallback that
probes known classes one at a time — it can only ask after classes it already knows, and
there is no other enumeration; it says so in the log. And a modded item whose name
follows no vanilla convention gets no slot, so it will not pull a gambeson under itself.

### Reading what was handed over, and knowing when to stop

The chest starts empty and is the mod's own, so there is nothing to subtract: what is
in it *is* the pattern. `GearWardrobeTick` polls it every second and rebuilds
`base + contents` from scratch — `base` being the pattern as it stood when the chest
was opened — so taking a piece back out of the chest takes it out of the pattern
again, while a second visit still *adds* to the harness. `GearFold` decides what one
piece replaces: its slot, or its weapon role.

**Nothing in the scriptbind says the transfer window has been closed**, so the end of
the transaction is read off the chest: a content signature that has not changed for
`GearChestSettle` (5) ticks. Until then the gear sits untouched in the chest — the
pattern is not saved, the men are not re-dressed and nothing is handed back. Being
wrong costs nothing worse than a player who was still deciding getting his gear back
mid-thought, and the chest carries on polling afterwards.

The chest is spawned `bSaved_by_game = 1` **because** the gear now waits inside it: a
quicksave mid-transaction must not take somebody's harness with the entity.
`GearSweepChests` empties and removes any it finds on the next load.

Enumeration is `inventory:GetInventoryTable()` + `ItemManager.GetItem(handle).class`
— the only route to a class id, and not used anywhere else in this mod, so it is
guarded and falls back to probing `GetCountOfClass` against every class in the baked
index (~2700 lookups, one-shot) if it ever returns nothing.

### Dressing a merc

Two halves, because the mod's clothing and weapon paths are separate and are always
called clothing-first:

Dressing takes **five stages over about two seconds**, not one:

| when | `GearApplyArmour` / `GearFinishTick` |
|---|---|
| frame 0 | the merc's own generic preset for his tier, then **only the under layers** — shirt, hose, padded chausses, boots, coif, padded coif, gambeson |
| +0.5 s | **delete** every armour piece the pattern does not name, then relay **only the under layers** into the slots that just came free |
| +1.0 s | the whole pattern, in layer order |
| +1.5 s | again |
| +2.0 s | again |

**The delete has to come before the last wear pass, not after it.** It used to be the
very last thing that happened, and that produced a squad that appeared in armour and
then, a second later, lost every piece of plate and stood there in gambesons. The base
preset holds slot 36 from frame 0, the pattern's own gambeson is refused because that
slot is taken, so the pattern's cuirass goes on over the *base* gambeson — and deleting
that gambeson at the end pulls the cuirass off with it, `RequiresFilledSlot` no longer
being satisfied, with no pass left to put it back. `GearPurgePass` is the knob.

### The keep loop

A dressed merc does not stay dressed. Pieces come off over a session and the company
visibly decays, and since nothing can ask an NPC what he is wearing there is no way to
notice, only to prevent. So `GearKeepTick` re-offers the whole pattern to **four mercs
a second, round-robin** — the whole company every five or six seconds — for as long as
the squad is on the custom uniform.

It is deliberately **not** a re-dress: no base preset, no purge, nothing deleted. It
can only add a piece that has gone missing, so unlike a full run it can never be the
thing that loses one. NPC Dresser reached the same answer — its own keeper re-dresses
on a timer rather than trusting one pass.

**A slot does not see its prerequisite as filled in the frame the prerequisite was
equipped in.** `equipment_slot.xml` declares `RequiresFilledSlot`, and a cuirass
equipped in the same breath as the gambeson under it is refused without a word — which
in game looked like a company in gambesons, coifs and hose with no plate anywhere.
Two passes in the same frame did not help, because the frame *is* the problem.

The base preset is the tier's own generic kit: known-good, known to render, and it
means a fresh hire whose first outfit is Custom has had a preset applied at least once
(without that, an NPC accepts `CreateItem` and then quietly declines every
`EquipInventoryItem`). `RemoveAllItems` and a "redraw" preset were both in earlier
builds and both are gone — NPC Dresser, which demonstrably works in the field, calls
`EquipInventoryItem` and nothing else.

### Why the base preset is the tier's own kit

Because it makes the failure **legible**. Three builds of this were debugged from a
log that said "11/11 piece(s) on" every time and a squad that stood there naked, and
`actor:GetArmor()` — the only verification the mod had — turns out to read **0 on a
merc wearing a full strong preset**, so it proved nothing either way.

With an ordinary merc preset as the base, what the player sees names the failing step:

| What they look like | What it means |
|---|---|
| the submitted kit | it works |
| ordinary merc kit | the per-piece equipping did nothing |
| merc kit *and* submitted pieces mixed | equipping worked, the strip did not |
| naked | the strip worked, the equipping did not |

Two lines carry the numbers behind it, one per merc:

```
pattern slots: 35 40 41 30 32 36 37 38 39 42 34
<merc>: pass 1 purged 11, under layers relaid, items 8, base 6d657263-0103-...-000000000007
<merc>: pass 4, 11/11 piece(s), items 15, missed 40:HoseSeparate01_m18_D
```

`pattern slots` is printed once per dressing run and says which slots the pattern
actually owns — **a slot missing from that list is a slot nobody will be wearing
anything in** once the base preset has been stripped, which separates "it did not
equip" from "it was never in the pattern in the first place".

`base` is the generic preset that was rolled for *that* merc. It is the only thing that
differs between two mercs dressed in the same tick, so when one man in a squad comes
out wrong and the other nine do not, that id is the thing to compare.

`missed` names the pieces `wearOne` reported failing, slot first. Treat a clean
`11/11` as weak evidence only: `wearOne` returns the result of `pcall`, which is true
whenever no Lua *error* was raised — including when the engine silently declined the
equip. There is no query that will say whether something is worn.

`merc_gear_redraw` toggles applying `generic_naked` — an empty preset, so it can only
redraw and never add — after the last wear pass. It is **off** by default: it was an
earlier attempt at forcing a rebuild and it did not help. It stays reachable because it
costs nothing to try if a piece is ever equipped-but-invisible.

### Taking things off means deleting them

Nothing short of destroying the item instance reliably takes it off:

- applying a clothing preset over it does not — that is the **mash-up**, a company
  wearing the new livery and the player's harness at the same time;
- `Human.UnequipItemInSlot` does not — and it is only on the legacy
  `C_ScriptBind_Human` bind list anyway;
- `Actor.UnequipInventoryItem` did not move the item count either (`items 23 -> 23`
  across a full strip), and there is no query that will say whether something is worn.

So `GearPurgeArmour` unequips **and then `DeleteItemOfClass`**. Armour only: weapons
are applied after this and a deleted sword is a disarmed merc.

The same guarantee runs the other way. `EquipMercenary` calls `GearRemoveCustom` on
**every** style that is not 7 — before the new preset goes on, so a piece the preset
also happens to use is not deleted out from under it. That is done there rather than
only when leaving style 7, so it holds however the style was reached, reload included.
Everything it deletes is a copy the mod made; nothing of the player's is lost.

`GetArmor()` is logged either side of the dressing, because there is no "what is in
this slot" query and naked-against-plate is the only signal there is.

The base preset is not optional. A runtime-spawned NPC accepts `CreateItem` and then
quietly declines every `EquipInventoryItem` until a clothing preset has been applied
once. It is `beggar_02`, the smallest real vanilla preset — a coat and hand wraps,
both in the strip list — so if a strip ever misses, what shows through is rags
rather than somebody else's livery.

**`GearApplyWeapons`** — apply a weapon preset first so the engine has a populated
weapon set to draw from (an empty set kills `combat_melee` at the draw with
*"Can't execute explicit DrawAction for selected weapon set which contains no
weapons!"*), then wear the player's weapons over the top. The base is chosen to
match: a shield loadout if the pattern has a shield, a shieldless one if it does
not, so what the preset leaves behind never contradicts the pattern.

Archers always keep a working missile set — their combat trees fail outright without
one — using the player's bow if he named one and their own if he did not.

### Named companions are out of it

Martin, Žižka, Capon and the rest wear their own character's gear through every style,
**the custom uniform included**. They carry the `SpawnedFriend_` prefix like everyone
else, so `IsHeroName` has to be an explicit check and it comes first — before the
style-7 branch in `EquipMercenary` and `EquipMercenaryWeapon`, and inside
`GearWantsCustom`, which is what keeps the keep loop off them too.

`GearHeroRestore` exists only to undo a build that briefly did dress them: it puts
their own look back from `actor:GetInitialClothingPreset()` /
`GetInitialWeaponPreset()`, having deleted the pattern pieces first (a preset does not
take off what is already worn). Once a companion is clean it costs one `FindItem` per
pattern piece and returns.

### Who it applies to

`GearWantsCustom` is the gate. An explicit outfit index of 7 is proof enough, but
`EquipMercenaryWeapon` is called for enemies with `outfitPreset = nil` and falls back
to the squad's current outfit — which is exactly how enemy shields once ended up
matching the player's squad. So the nil case additionally requires a
`SpawnedFriend`/`SpawnedTower_archer_` name and rejects `SpawnedEnemy`/`SpawnedFoe`.

---

## Persistence

One tag, `MercCustomGear`, through the mod's own save-string storage
(`mercenaries_saving.lua`): the class GUIDs dashless and concatenated, or `none`.
It is read back in `OnGameplayStarted` **before** the outfit is restored, or a squad
saved wearing the uniform re-dresses out of an empty pattern.

## Files

| Piece | File |
|---|---|
| Everything above | `data/Scripts/mods/mercenaries_custom_gear.lua` |
| The baked GUID table | `data/Scripts/mods/mercenaries_gear_data.lua` (generated) |
| Its generator | `tools/gen_gear_table.py` |
| Style 7 branch | `mercenaries_equipment.lua`, `mercenaries_archers.lua` |
| Delivery panel + outfit 7 reward | `mercenaries_background_quest.xml` (both regions) |
| "I want you to dress this way..." | `quartermaster_dialog.xml` + `dismissal_dialog.xml`, top level in both (both regions) |
| The wardrobe chest | `mercenaries_custom_gear.lua` (`GearOpenWardrobe`, `GearWardrobeTick`) |
| "Our own kit" | `dismissal_dialog.xml`, `order_wheel_chat.xml` (both regions) |

## Console

    merc_gear_dump     log the saved uniform, layer by layer, with added and refused pieces
    merc_gear_clear    forget it (back to naked plus a sword)
    merc_gear_apply    put the company into it
    merc_gear_open     put the wardrobe chest down, without the dialogue
    merc_gear_close    empty the chest back into the player and take it away
    merc_gear_log      per-piece dressing log - what went on, what was refused
    merc_gear_redraw   toggle the empty-preset redraw after the last pass (off by default)

## Known limits

- **The order wheel needed a third page.** It holds four slots and the fourth is
  always "more", so Custom coming second pushes Skalitz onto a page of its own.
- **One item per slot.** A pattern is a uniform, not a wardrobe.
- **Quest items cannot be copied.** `IsQuestItem` blocks `inventory:CreateItem`
  outright, so those are refused at the panel rather than failing silently on
  thirty men.
- **There is no in-dialogue way to clear the pattern**, only to add to it or replace
  a slot. `merc_gear_clear` does it from the console.
- **A chest standing at save time** is swept on the next load (`GearSweepChests`,
  from `GearLoadState`): emptied into the player, then removed.
