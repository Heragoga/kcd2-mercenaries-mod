# Ranged Mercenaries (Archers)

Archers are a separate combat group from the melee mercs: their own souls, their own brain, their own stance set.

---

## Why a separate brain

Giving the regular melee brain a bow doesn't work: the melee attack tree wraps `CombatAction` in `CombatFollowerDecorator` with `WeaponChange="none"`, so the engine's combat movement walks the NPC into melee range and the weapon automation happily swaps to whatever hits hardest up close. That's exactly the "shoot twice, then charge" behaviour the bodyguards mod suffers from.

The vanilla battle system (`AI/battles/battlegroupcontroller.xml`, trees `standFire`, `crouchFire`, and `AI/test/test_of_everything/test_shooting.xml`) shows the actual recipe for NPC archery:

```xml
<MeleeOffenseAutomationDecorator active="true">
    <WeaponAutomationDecorator WeaponChange="missile" active="true">
        <CombatAction TargetNPC="$enemy" RelationOverride="None" />
    </WeaponAutomationDecorator>
</MeleeOffenseAutomationDecorator>
```

Two things matter:

1. **`WeaponChange="missile"`** locks the weapon automation to the ranged weapon — no swapping to a sword.
2. **`CombatFollowerDecorator` is what closes distance.** Omit it and the NPC stands and fires; include it (with missile locked) and the engine drives positioning.

Every archer combat tree in this mod is built on that pattern.

---

## What was added

All `data/libs` tables are patches onto this mod's own vanilla-pattern files (`__mercenaries` = mod id `mercenaries`), not a separate `__archers` mod — archers are appended into the same `soul__mercenaries.xml`, `brain__mercenaries.xml`, etc. as the melee mercs, just with their own brain id and soul ids inside those files.

| Piece | Files |
|---|---|
| Souls (one pool of 10, no tiers) | appended to `data/libs/tables/rpg/soul__mercenaries.xml` |
| Skald characters (3 voice variants sharing one UI name) | appended to `data/libs/tables/skald/skald_character__mercenaries.xml` + 2role/2profession files |
| Brain (`archer_brain`) | appended to `data/libs/tables/ai/*__mercenaries.xml` (renegade-brain pattern, own brain id) |
| Combat behaviours registry | added to `SmartEntity__so_interrupt__mercenaries.xml` |
| Behaviour trees | `data/AI/archer_scheduler.xml`, `combat_archer_dynamic.xml`, `combat_melee.xml (melee stance)` |
| Weapon sets (ranged weapon + ammo + shortsword sidearm, one set per weapon type) | `weapon_preset__mercenaries.xml` (`merc_weapon_archerset_bow_*` / `_crossbow_*` / `_handcannon_*`, historically `merc_weapon_archerset_*` for bow) |
| Base inventory (light clothes + 40 arrows) | `InventoryPreset__mercenaries.xml` (`inventory_mercenary_archer_*`) |
| Storm rules (appearance/equipment/roles) | appended to the three existing mercenaries storm files |
| Lua | `data/Scripts/mods/mercenaries_archers.lua` + small hooks in `mercenaries.lua`, `mercenaries_equipment.lua`, `mercenaries_util.lua`, `mercenaries_formation_handler.lua`, `mercenaries_target_selection.lua` |
| Recruitment + orders dialog | `hire_dialog.xml` ("Ranged mercenaries" submenu), `dismissal_dialog.xml` (nested under "Change combat orders... → Orders for the archers" and "Change equipment... → Change the archers' weapons"), tokens wired in `mercenaries_background_quest.xml` |
| Tokens | `item__mercenaries.xml`, ids `...be60d` (hire), `...be62d` (stance), `...be63d` (weapon type) |

Archers are spawned as `SpawnedFriend_archer_medium_<rand>_<soulGuid>`. The `SpawnedFriend` prefix means every existing squad system (cache, pruning, formation, teleport catch-up, healing, wait/follow/dismiss, horses via `follow`) picks them up with zero changes; the `_archer_` marker is what archer-specific code branches on. In the marching formation they sort to the back rank.

Archers are a **single pool of 10 with no tiers** — every one of them sits at the melee mercs' medium combat level (0.7). 150 groschen a head.

They still spawn under the melee `medium` tier name (`mercenaries.ArcherTier`) rather than a tier of their own, because the squad systems that are keyed by tier — outfit selection in `EquipMercenary`, camp housing assignment — parse the tier straight out of the entity name via `GetTierFromName`. Reusing `medium` means those systems resolve archers correctly with no archer-specific branch.

---

## Follow / leash parity with the melee mercs

Three places where `archer_scheduler.xml` had drifted from `mercenary_scheduler.xml` and produced the "archers behave weirdly" symptoms:

- **De-target distance** was a flat 40 m. It now comes from `MercLeashes` (`$deTargetDist`) and scales with squad size, so a rear-rank archer is no longer handed a target and told to drop it on the same tick. `UpdateRangedCombatData`'s friend leash follows the same `MeleePlayerLeash()`.
- **The follow re-arm loop was missing.** `FollowStalled` (raised by the teleporter's repeat-straggler counter) sets a flag nothing consumed, so a stalled archer kept `$isFollowingActive` set forever and never re-fired `follow`. The melee scheduler's `PollFollowRefire` / `ConsumeFollowRefire` + `teleport`-evict loop is now here too.
- **The 8 s distance self-heal fired at 15 m, not 35 m.** Archers form up at the *back* of the formation, so 15 m is a normal rear-rank distance — every needless restart dropped them out of `FormationFollower`, their only locomotion, and they coasted further back and re-tripped it.

Archers are also exempt from the emergency teleporter's in-combat exemption — see docs/formations.md.

## Engagement bands

How close an archer fights is per weapon type, from `mercenaries.ArcherBands` (`mercenaries_ai_modules.lua`). Every threshold in `combat_archer_dynamic.xml` is published from there each cycle, so changing the table is the whole knob.

| Weapon | `melee` | `keepMin` | `keepMax` |
|---|---|---|---|
| Bow | 4.5 m | 9 m | 35 m |
| Crossbow | 4.5 m | 9 m | 35 m |
| Hand cannon | 3 m | 5 m | 12 m |

- Below `melee` (or out of ammo) — sidearm burst, until the gap reopens past `melee + 7.5`.
- Between `melee` and `keepMin` — step back to the edge of the band, then fire.
- Between `keepMin` and `keepMax` — stand and fire.
- Beyond `keepMax` — **walk in** to just outside `keepMin`, then fire.

The approach state is why hand cannons work at all. Before it existed the module never advanced, so an archer's engagement range was simply wherever the follow formation had left him standing — fine for a bow, useless for a ten-metre weapon. Approach points are refused when they would put the archer more than 35 m from the player, or across a camp wall.

Enemy and patrol archers always take the bow band: only the player's archers have a chosen weapon type.

## Archer stances (separate from the melee squad stance)

Set via any merc's dialog → "Change combat orders..." → "Orders for the archers", or console:

| Stance | Console | Behaviour |
|---|---|---|
| **Skirmish** (default) | `archer_stance_skirmish` | Shoot at the range the weapon actually wants (`combat_archer_dynamic`): stand-and-fire inside the band, walk in when too far, step back (ground-validated) when the enemy closes. The player leash + scheduler follow logic drags them along when the fight moves. Sidearm only when an enemy is inside `meleeRange` (or the quiver is empty), and back to the ranged weapon once the threat is dead or the gap reopens past `reengageRange`. See **Engagement bands** below. |
| **Melee** | `archer_stance_melee` | Sheathe the bow, draw the sidearm, fight like a regular merc (`WeaponChange="melee"`). |
| **Hold** | `archer_stance_hold` | Don't engage at all; disengage if already fighting. |

There used to be a fourth stance, **Guard** ("stay glued to the player and shoot from there") - it was removed; skirmish/melee/hold covers everything the squad needs, and one fewer stance is one fewer thing to get wrong.

Stance changes apply **mid-fight**: every combat tree watches the stance each ~700ms and bails out when it no longer matches, at which point the scheduler fires the newly selected behaviour within half a second.

---

## Target selection

Archers pick targets exactly the same way regular mercs do: `archer_scheduler.xml` runs the same always-on two-pass acquisition (`EvaluateCombatTarget` then `PickCombatTarget`) from `mercenaries_target_selection.lua`. See [combat-target-selection.md](combat-target-selection.md). The archer stance (skirmish / melee / hold) only chooses which combat behaviour the interrupt fires — it has no say in *who* gets targeted.

---

## Ranged weapon type (bow / crossbow / hand cannon)

Set via any merc's dialog → "Change equipment..." → "Change the archers' weapons", or console:

| Weapon | Console | Notes |
|---|---|---|
| **Bow** (default) | `archer_weapon_bow` | Bow + hunting arrows + shortsword sidearm. |
| **Crossbow** | `archer_weapon_crossbow` | Crossbow + hunting bolts + shortsword sidearm. |
| **Hand cannon** | `archer_weapon_handcannon` | Hand cannon + shortsword sidearm. Vanilla has no separate ammo item for hand cannons, so these archers never report "out of ammo" and never fall back to melee for that reason (they still will if an enemy closes to melee range). |

Changing weapon type re-equips every active archer immediately via `mercenaries:SetArcherWeaponType()`, mirroring how `ChangeMercWeapon` re-equips the melee squad. It's a global setting shared by the whole archer squad (like the archer stance), persisted across saves (`ArcherWeaponTypePersistent`).

Combat-wise nothing else changes: all three weapon types fire through the same `WeaponAutomationDecorator WeaponChange="missile"` automation used for bows (this is generic across ranged weapon classes), so `combat_archer_dynamic.xml` / `combat_melee.xml (melee stance)` needed no changes. Reload/cocking pacing for crossbows and hand cannons is handled by the engine's own combat automation, the same way vanilla mass-battle archers never need a scripted reload step inside `CombatAction`.

The weapon preset GUIDs and vanilla item classes (crossbow bodies, bolts, hand cannons) are documented in `mercenaries_archers.lua` (`ArcherWeaponSets`, `ArcherAmmoClass`/`ArcherBoltClasses`) and `weapon_preset__mercenaries.xml` (`merc_weapon_archerset_crossbow_*` / `_handcannon_*`).

---

## Ammo

Four layers, because it's unclear how strictly KCD2 enforces NPC ammo in `CombatAction`:

1. The storm inventory preset (`inventory_mercenary_archer`) ships regular hired archers with 40 hunting arrows.
2. The archer weapon preset includes an arrow item — but **only one or two**, not a full quiver, so it is never enough on its own.
3. `GiveArcherAmmo` (Lua, on spawn and on every re-equip) tops the quiver back to 40 via **`ent.inventory:CreateItem(class, health, amount)`** — one call that creates and inserts. This is the ONLY ammo source for static/tower archers, which are spawned by `EquipMercenary` + `EquipArcherWeapon` and never receive the `inventory_mercenary_archer` preset (layer 1).
4. `ResupplyArchersOutOfCombat` / `ResupplyStaticArchers` (every 5s from the monitor loops): any archer below 10 rounds and not in combat is topped back to 40, so running dry mid-fight only lasts until the fight ends.

The combat trees check total ammo count each tick; at zero they fight with the sidearm instead of dry-firing.

> **Gotcha (fixed):** `GiveArcherAmmo` originally used `ItemManager.CreateItem(...)` + `inventory:AddItem(itemId)`, which **silently adds nothing** (`Inventory.AddItem` wants an existing item WUID, not a class). Static archers therefore had only the single arrow their weapon preset shipped — fired once, then stood there "out of ammo" through every behaviour-tree rewrite. The tree was never the bug. Give items with `inventory:CreateItem`; see `reference_giving_items_to_npcs` and `references/Scripts/Utils/ItemUtils.lua`.

---

## The archer tower's collision

`watchtower_a.cgf` is not a mesh that needs the invisible-crate treatment for the usual
reason — it has **no `cv_*.cgf` sibling** and carries a complete hull of its own: 53
`$physics_proxy_*` nodes, measured straight out of `IPL_Objects-part1.pak`.

| what | tower-local extent |
| --- | --- |
| four corner posts | 0.31 × 0.31, z −0.14 → 5.74 |
| deck floor plate | x −0.31…2.43, y −1.31…2.97, z 3.01…3.12 |
| parapet ring | z 2.75…4.23, 0.11 thick |
| stair plank walls | x −0.24…−0.12 and −1.70…−1.59, up to z 3.18 |
| staircase | 14 steps + landing, z 0.27 → 3.11, climbing +y on the −x side |
| braces | z 1.81…2.99 and 4.60…5.67 — nothing at walking height |
| roof | **no proxy above z 5.80** — the roof is not collidable |

Two things follow, and they are the whole of why the tower read as "no collision":

1. **The understorey is genuinely open.** Four 31 cm legs on a 4 m square with the first
   brace at 1.8 m is a tower you walk straight under. That is the base game's own hull,
   not a fault — but it is what you hit when you walk at the tower.
2. **Nothing guaranteed the hull was ever physicalised.** `TowerSpawnPart` passed no
   `Physics` table at spawn time and relied on the `mercenaries_Prop` class default.
   Entity properties are read *when the entity physicalises*, and the spawn-time table is
   the only one guaranteed to be in place by then — the same reason `WallSpawnSegment`
   re-passes its own. Both the parts and the collider crates now pass it explicitly.

`TowerColliders` therefore traces the hull rather than inventing one, and every box sits
within 1 mm of measured `$physics_proxy` geometry — so **collision only ever sits where
there is visible timber**. No invisible walls between the legs, which would be worse than
walking through.

`tools/cgf_proxies.py` is what produced those numbers, and `--crate` emits collider rows
ready to paste. Run it before hand-placing a collider on anything — it is the difference
between a box on the timber and a box in mid-air.

| boxes | what |
| --- | --- |
| 4 | the corner posts |
| 2 | the plank walls flanking the stair — the tower's only solid faces at walking height |
| 2 | the platform, which is L-shaped: the main plate plus a second one over the head of the stair |
| 15 | the flight: 14 steps and the top landing |

**The stair is the way up, and the ladder is gone.** The mesh has a real, visible
staircase — 2,586 render verts in the stair volume — so the rustic `Ladder_400` that used
to lean against the −y side stood in front of a perfectly good flight. `TowerLadders` is
now empty, which drops it from the ghost preview as well as the build;
`TowerSpawnLadder` is kept as the mod's only worked example of a climbable Ladder entity,
and the old row is recorded in the comment above it.

The flight is generated from two numbers (0.20 m rise, 0.20 m going) rather than written
out as fifteen near-identical rows. Each box fills its own riser, so the stair is one
continuous solid with no gap to clip through; the bottom tread is bedded into the ground
instead of floating at z 0.11 where the mesh's slope proxy starts, and the landing at 3.11
steps up 0.21 m onto the stair-head plate.

**The parapet ring is deliberately left out.** It is in the mesh hull, but it is a solid
rail at chest height directly in front of the archer, and arrows are physical. Not worth
risking the one thing the tower exists for.

The archer is untouched: the deck slab keeps its old top height (z 3.319), so
`TowerArcherLocal.z = 3.38` still drops him the same 6 cm onto the same surface.

Cost is 23 static crates per tower instead of 1 (less the ladder entity), and it applies to
bandit-camp and siege towers too — they go through the same `TowerColApply`.

---

## Console reference

```
archer_hire_1 / 3        hire 1/3 archers (free, debug)
archer_stance_skirmish / melee / hold
archer_weapon_bow / crossbow / handcannon
merc_status              one-line squad report (also in dialog: "How is everyone holding up?")
merc_heal                heal & wash the squad (flat fee)
merc_help                list every command
```

Everything else (wait/follow/dismiss/heal/outfits/teleport) works on archers through the existing merc commands and dialogs, since they're `SpawnedFriend` entities. The one deliberate exception: the squad **weapon** loadout dialog never touches archers — they keep their bow sets no matter what the melee squad switches to.
