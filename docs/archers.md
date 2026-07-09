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
| Souls (5 per tier, weak/medium/strong) | appended to `data/libs/tables/rpg/soul__mercenaries.xml` |
| Skald characters (1 per tier) | appended to `data/libs/tables/skald/skald_character__mercenaries.xml` + 2role/2profession files |
| Brain (`archer_brain`) | appended to `data/libs/tables/ai/*__mercenaries.xml` (renegade-brain pattern, own brain id) |
| Combat behaviours registry | added to `SmartEntity__so_interrupt__mercenaries.xml` |
| Behaviour trees | `data/AI/archer_scheduler.xml`, `archer_skirmish.xml`, `archer_melee.xml` |
| Weapon sets (ranged weapon + ammo + shortsword sidearm, one set per weapon type) | `weapon_preset__mercenaries.xml` (`merc_weapon_archerset_bow_*` / `_crossbow_*` / `_handcannon_*`, historically `merc_weapon_archerset_*` for bow) |
| Base inventory (light clothes + 40 arrows) | `InventoryPreset__mercenaries.xml` (`inventory_mercenary_archer_*`) |
| Storm rules (appearance/equipment/roles) | appended to the three existing mercenaries storm files |
| Lua | `data/Scripts/mods/mercenaries_archers.lua` + small hooks in `mercenaries.lua`, `mercenaries_equipment.lua`, `mercenaries_util.lua`, `mercenaries_formation_handler.lua`, `mercenaries_target_selection.lua` |
| Recruitment + orders dialog | `hire_dialog.xml` ("Ranged mercenaries" submenu), `dismissal_dialog.xml` (nested under "Change combat orders... → Orders for the archers" and "Change equipment... → Change the archers' weapons"), tokens wired in `mercenaries_background_quest.xml` |
| Tokens | `item__mercenaries.xml`, ids `...be59d`–`...be63d` |

Archers are spawned as `SpawnedFriend_archer_<tier>_<rand>_<soulGuid>`. The `SpawnedFriend` prefix means every existing squad system (cache, pruning, formation, teleport catch-up, healing, wait/follow/dismiss, horses via `mercenary_follow`) picks them up with zero changes; the `_archer_` marker is what archer-specific code branches on. In the marching formation they sort to the back rank.

Prices: 75 / 150 / 400 groschen for weak / medium / strong.

---

## Archer stances (separate from the melee squad stance)

Set via any merc's dialog → "Change combat orders..." → "Orders for the archers", or console:

| Stance | Console | Behaviour |
|---|---|---|
| **Skirmish** (default) | `archer_stance_skirmish` | Pure stand-and-fire (vanilla `standFire` pattern): plants feet wherever combat starts and shoots, no repositioning at all. The player leash + scheduler follow logic drags them along when the fight moves. Never melee unless an enemy is within ~5m (or the quiver is empty), and they disengage back to the bow once the threat is dead or 12m+ away. |
| **Melee** | `archer_stance_melee` | Sheathe the bow, draw the sidearm, fight like a regular merc (`WeaponChange="melee"`). |
| **Hold** | `archer_stance_hold` | Don't engage at all; disengage if already fighting. |

There used to be a fourth stance, **Guard** ("stay glued to the player and shoot from there") - it was removed; skirmish/melee/hold covers everything the squad needs, and one fewer stance is one fewer thing to get wrong.

Stance changes apply **mid-fight**: every combat tree watches the stance each ~700ms and bails out when it no longer matches, at which point the scheduler fires the newly selected behaviour within half a second.

---

## Target selection

Archers pick targets exactly the same way regular mercs do: `archer_scheduler.xml` reads the same player-set squad stance (`_G.MercStance` / `GetStanceCode` — everyone / player_target / defend / passive) and calls the shared `PickNearestValidTarget` / `PickPlayersTarget` / `EvaluateCombatTarget` functions from `mercenaries_target_selection.lua`, instead of auto-aggroing anything within range. This was previously a separate always-aggressive `PickArcherTarget` function that ignored the squad's targeting stance; it's been removed in favor of the shared logic.

---

## Ranged weapon type (bow / crossbow / hand cannon)

Set via any merc's dialog → "Change equipment..." → "Change the archers' weapons", or console:

| Weapon | Console | Notes |
|---|---|---|
| **Bow** (default) | `archer_weapon_bow` | Bow + tier-appropriate arrows + shortsword sidearm. |
| **Crossbow** | `archer_weapon_crossbow` | Crossbow + tier-appropriate bolts + shortsword sidearm. |
| **Hand cannon** | `archer_weapon_handcannon` | Hand cannon + shortsword sidearm. Vanilla has no separate ammo item for hand cannons, so these archers never report "out of ammo" and never fall back to melee for that reason (they still will if an enemy closes to melee range). |

Changing weapon type re-equips every active archer immediately via `mercenaries:SetArcherWeaponType()`, mirroring how `ChangeMercWeapon` re-equips the melee squad. It's a global setting shared by the whole archer squad (like the archer stance), persisted across saves (`ArcherWeaponTypePersistent`).

Combat-wise nothing else changes: all three weapon types fire through the same `WeaponAutomationDecorator WeaponChange="missile"` automation used for bows (this is generic across ranged weapon classes), so `archer_skirmish.xml` / `archer_melee.xml` needed no changes. Reload/cocking pacing for crossbows and hand cannons is handled by the engine's own combat automation, the same way vanilla mass-battle archers never need a scripted reload step inside `CombatAction`.

The weapon preset GUIDs and vanilla item classes (crossbow bodies, bolts, hand cannons) are documented in `mercenaries_archers.lua` (`ArcherWeaponSets`, `ArcherBoltClassByTier`/`ArcherBoltClasses`) and `weapon_preset__mercenaries.xml` (`merc_weapon_archerset_crossbow_*` / `_handcannon_*`).

---

## Ammo

Four layers, because it's unclear how strictly KCD2 enforces NPC ammo in `CombatAction`:

1. The storm inventory preset ships every archer with 40 tier-appropriate arrows.
2. The archer weapon preset includes an arrow item.
3. `GiveArcherAmmo` (Lua, on spawn and on every re-equip) tops the quiver back to 40 via `ItemManager.CreateItem` — pcall-guarded, logs `[Archer]` lines, harmless if the API differs.
4. `ResupplyArchersOutOfCombat` (every 5s from `LowPriorityMonitorLoop`): any archer below 10 rounds who is not currently in combat gets topped back up to 40, so running dry mid-fight only lasts until the fight ends.

The combat trees check total ammo count each tick; at zero they fight with the sidearm instead of dry-firing.

---

## Console reference

```
archer_hire_w1 / w3      hire 1/3 weak archers (free, debug)
archer_hire_d1 / d3      hire 1/3 medium archers
archer_hire_p1 / p3      hire 1/3 strong archers
archer_stance_skirmish / melee / hold
archer_weapon_bow / crossbow / handcannon
merc_status              one-line squad report (also in dialog: "How is everyone holding up?")
merc_heal                heal & wash the squad (flat fee)
merc_help                list every command
```

Everything else (wait/follow/dismiss/heal/outfits/teleport) works on archers through the existing merc commands and dialogs, since they're `SpawnedFriend` entities. The one deliberate exception: the squad **weapon** loadout dialog never touches archers — they keep their bow sets no matter what the melee squad switches to.
