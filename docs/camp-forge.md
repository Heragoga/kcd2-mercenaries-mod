# The camp forge and its smith

This documents the camp forge (the Portable Smithy upgrade) and — more importantly — the long hunt for an NPC smith animation. Roughly ten mechanically distinct approaches were tried before one worked. If you ever want an NPC to "work" at a player-built structure, read this first: it will save you days.

**Files:** `data/Scripts/mods/mercenaries_forge.lua` (build/teardown + smith assignment), `data/AI/camp_actor.xml` (camp activity **mode 10** = the smith), `data/Scripts/mods/mercenaries_camp.lua` (`RotateCampRoles` skips `CampForgeSmithWuid`).

---

## What the camp forge is

When camp is made with the smithy upgrade owned:

1. **Flattest-patch scan** — the smithing minigame needs level ground, so candidate spots on rings (6.5 / 8.5 / 10.5 m, 8 angles each) around the camp are rated by the height spread of a small heightmap sample; the flattest wins.
2. **Borrow the nearest loaded `Smithery`** — the invisible logic entity that drives the *player* blacksmithing minigame — and `SetWorldPos` it to the camp anvil. Its level-baked hidden ItemSlots keep feeding the player's minigame tools even from far away.
3. **Retarget its `alignment` link** (`sm:SetLinkTarget("alignment", campHolder.id)`) to a `SmartObjectHolder` we spawn at the working spot. Without this, pressing E teleported Henry to the origin village mid-minigame.
4. **Dress the scene** with our own props (anvils, furnace, coal, quenching barrel) and borrow a real `Grindstone` (it is fully self-contained and survives being moved).
5. Everything is restored on camp break, and auto-restored if the player comes within 30 m of the borrowed smithy's home village.

The **player** minigame works at the camp forge. The **NPC** story is below.

---

## The NPC smith: what did NOT work (and exactly why)

The goal: a merc visibly smithing at the camp forge, like village blacksmiths do.

### 1. The vanilla smith unstances (`blacksmith_forging` / `blacksmith_heating`)
The real smith behaviour (`references/AI/profession/blacksmith/so_blacksmith.xml`) loops `UnstanceAction blacksmith_heating/forging` anchored to a **`SmartObjectHolder`** (guidSmartObjectType `a7daaa9f…`, soclass `Blacksmith`) — *not* the `Smithery`. That holder owns the `hammerSlot`/`swordSlot`/`forgeBag` links, and the unstances **generate** the hammer/workpiece/tongs into the NPC's hands from those slots at animation start.

* **Anchored at the Smithery** → `No link target for link 'hammerSlot' found from object … Smithery` (wrong entity — the Smithery has no tool links).
* **Anchored at the borrowed holder moved to camp** → the slots are level-baked child entities (`bSpawnOnStart="0"`) that stay behind; the state search fails and the AI **reroutes the merc to the nearest *intact* forge**, hundreds of metres away. This "smith walks off on a merry journey" was the signature failure of almost every attempt.
* **Tools conjured via `CreateItem`+`EquipItem`** → tools appear and equip fine, but the unstance *still* fails instantly: **held items do not substitute for slot-generated content.**
* **`merc_forge_test` control experiment**: the same steps at a real, unmoved village forge (player standing nearby) worked *flawlessly*. The logic was always right; the context is what can't be relocated.

### 2. Moving / spawning the missing context
* The hidden context (ItemSlots, the `SmitheryAlignPoint` TagPoint, GhostDummies like `blacksmith_sword_heating1`, SchedulerHubs, PrefabPorts) is **Lua-invisible**: a scan over all those classes near the village forge found **zero** enumerable instances. They cannot be found, moved, or retargeted.
* **ItemSlot cannot be runtime-spawned**, even in the minimal single-property (`guidItemClassId` only) form used by the armorsmith prefab — `System.SpawnEntity` returns nil. `StanceSmartObject` (seats) and `SmartObjectHolder` spawn fine, but a spawned holder with the right `guidSmartObjectType`/`soclass` still can't feed the animations without real slots.

### 3. Teleport tricks
* Teleport the merc to the real forge, start the anim, teleport back: the animation **does not survive** the trip home.
* Two engine rules learned the hard way:
  * **`entity:SetPos` from inside the entity's own BT `ExecuteLua` does not stick** (the movement controller overrides it). `SetPos` from Lua timers / console context works fine on mercs.
  * **An NPC action already in flight cannot be cancelled from Lua.** A state-search walk started by one attempt kept driving the merc through every subsequent attempt — which masked several tests entirely. To change an NPC's behaviour mid-action, assign a *different* NPC.
* `AddInterrupt_teleport` (the proper AI teleport node) exists but did not fire reliably from inside a running switch case; and the player can't be teleported by it at all (no AI tree to interrupt).

### 4. Direct mannequin fragments
`references/AI/profession/smith/so_smith.xml` plays `Smith*` fragments (SmithGrab, SmithHeating, SmithHarden…) directly via `<AnimationAction fragment="…">` with just an align object — no unstance DB, no slots. At our camp anchor they **no-op silently** (the merc stays put but nothing plays). Presumably the fragments' tag-scoped props still need context we don't have.

### 5. Assorted dead ends
* `repairFenceHammer` (a standing hammer swing) needs a fence location object — it lacks `UseLocationObject="false"`, the attribute that marks genuinely standalone unstances.
* `armorsmith` seated on our spawned bench: sits fine, but the unstance fails instantly for the same slot-generated-content reason (its `hammerSlot`/`helmSlot`).
* A custom `$isForgeSmith` first case in the ContinuousSwitch was never entered reliably even with its flag verifiably true; only the existing **CampActivities pipeline** (`campActMode`) preempts dependably. New behaviours should always ride that pipeline.

**Bottom line: real smith animations are engine-locked to level-baked ItemSlots. They cannot be brought to, or recreated at, a player-built forge.**

---

## What DOES work (shipped)

The smith is a merc **seated at a spawned bench by the anvil, sharpening a sword** — every ingredient individually proven:

1. **Bench**: a stool prop + a `StanceSmartObject` seat with the same properties as the camp's `CampChairSO` — runtime-spawned seats demonstrably work (all camp sitting uses them). Placed 0.69 m from the anvil, facing it.
2. **Pick a patroller** (`ForgeAssignSmith`): guards aren't mid a long in-place animation, so the takeover is clean. The pick is pinned in `CampForgeSmithWuid`, which `RotateCampRoles` skips so the camp role rotation never reassigns him.
3. **Teleport him onto the bench** with Lua `SetPos` — the flat forge patch is often off-navmesh, so a BT `Move` could never reach it.
4. **Camp activity mode 10** (`camp_actor.xml`): conjure a real sword into his hand **once** (`CreateItem` + `EquipItem`, guarded by `$m10Equipped` — unguarded it re-creates an item every loop), sit via `StanceElement`+`WaitAction`, then `UnstanceAction camper_knifeSharpening` with the **seat** as locationObject, held ~15 s, looped.

Why this combination works when everything else failed: `camper_knifeSharpening` is a **camper** animation — built for NPCs *without* smart-object slot rigs, so it uses the **held** item. It was catalogued "BROKEN — needs a knife in hand" only because, at the time, we had no way to put one there. `EquipItem` closed that gap.

### Reusable lessons
* `UseLocationObject="false"` in `NPCStateUnstanceDatabase.xml` is the tell for a genuinely standalone unstance.
* Camper/emote unstances = held items or self-conjured props (the eating anim spawns its own bun). Profession unstances = slot-generated content, village-only.
* `CreateItem` → `EquipItem` (see `references/AI/quests/erik/erik.xml`) is *the* way to arm an NPC from a BT. `HandContentElement` + `<Success/>` only asserts; it never equips. `CreateItem` inside a `HandContentElement` `<Search>` silently kills the whole tree case.
* A ContinuousSwitch flag written from a parallel reader loop must never flicker (`= false` then `= true` in one tick loses the race).
* Drift-pinning an NPC while an unstance align-walks it produces an endless walk/yank loop — never pin during animation-driven movement.

## Surviving a reload (2026-09-03)

The forge and the alchemy bench were the two improvements that did not survive a save: present
for the first seconds after a load, then flickering, then gone. Everything the mod spawns was
fine; the two that *borrow* a village entity were not. The engine restores a moved level entity
**where it was moved to**, so after a load `ForgeFindNearest` finds our own Smithery already
standing at the camp - and `SpawnCampForge` recorded its current position as its home. The 2 s
return watch (`CampForgeMonitor`) then saw the player "within 30 m of the home village" - the
camp itself - and packed the forge; `CampStationRetryTick` put it back every 5 s for its minute
of retries, and gave up.

`StationHome` (mercenaries_forge.lua) now keeps the true home with the camp, under the
`CampForgeHome`, `CampAlchemyHome` and `CampForgeHome_Grindstone` saver tags: a fresh borrow
saves the entity's position; an entity found within `StationHomeNearCamp` (60 m) of its camp
spot is ours, and the saved home is used instead. A camp pitched within packing distance of
the village that owns the entity disables the return watch for that station rather than
packing it on approach. Teardown restores to the true home and forgets the tag; the alchemy
teardown also sends home any `AlchemyItem` still at the bench from an earlier session's drag.
