# The camp alchemy bench

The Alchemy Bench upgrade, made real. It mirrors the [camp forge](camp-forge.md) but is simpler, because the `AlchemyTable` entity is far more self-contained than the `Smithery`.

**Files:** `data/Scripts/mods/mercenaries_alchemy.lua` (build/teardown). It reuses the forge's `ForgeFindNearest` / `ForgeFindFlattest` / `ForgeFlatness` helpers.

---

## How it works

Unlike the `Smithery` (which is an invisible logic entity — see the forge doc), the `AlchemyTable` renders its **own** table model and drives the brewing minigame and the E prompt itself. So building the camp bench is mostly a relocation job:

1. **Borrow the nearest loaded `AlchemyTable`** and `SetWorldPos` it to a flat patch near camp (`ForgeFindFlattest`, avoiding the forge's spot if one is up so the two upgrades don't overlap).
2. **Drag its dressing entities along.** The prefab keeps the retort / mortar / bellows / pot / flasks (class `AlchemyItem`), boiling & fire particles (`ParticleEffect`), and fireplace lights (`Light`) within ~2 m of the table. Each entity within `CampAlchemyPropRadius` (3.5 m) is translated by the same delta as the table, so the layout is preserved. Static `Brush` decorations aren't entities and can't be moved, so a few flasks/tripod stay behind — the table plus `AlchemyItem`s carry the look.
3. **Spawn our own table mesh** at the destination. The minigame logic and the `AlchemyItem` props follow `SetWorldPos`, but the table's own **mesh is brush-rendered and stays behind**, leaving the props floating. A `BasicEntity` copy of the model (matched to the table's rotation) gives a solid bench underneath.
4. **Restore on camp break**, and auto-restore if the player wanders back within `CampAlchemyAutoPackDist` (30 m) of the borrowed table's home village, so that settlement isn't left without its bench.

## Gotchas

* Use `alchemy_table_a.cgf` for the spawned mesh. `alchemy_table_b` was see-through from the back, and `alchemy_table_master` rendered invisible as a `BasicEntity`.
* Do the proximity search for props using the table's **real** position, then move the table **last** — otherwise the search origin is already displaced.
* The table's *current* position is not its home after a reload — the engine restores it at the camp, and treating that as home made the auto-restore pack the bench two seconds after every load. `StationHome` keeps the real home with the save; see [camp-forge.md](camp-forge.md), "Surviving a reload".
