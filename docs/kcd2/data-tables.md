---
title: Data tables (the game database)
summary: How KCD2's XML table database is laid out, how a mod patches it with __modid files, what the key tables (items, presets, buffs, RPG params, souls, factions, shops, Skald characters) look like, GUID conventions, and how to find things in vanilla data.
tags: [data, lua, ai]
kind: reference
status: current
scope: kcd2
verified: release_1_5
---

# Data tables (the game database)

## TL;DR

- ~300 tables in `Tables.pak` → `Libs/Tables/<dir>/<table>.xml` (1,738 files in 1.5). Loaded once at startup, **never change during play** (official wiki [KM-A-12](https://warhorse.youtrack.cloud/articles/KM-A-12)).
- Patch with `Libs/Tables/<dir>/<table>__<modid>.xml`, same XML shape as the vanilla table. Patches load after every vanilla part, in mod load order, and may reuse existing primary keys (official wiki KM-A-12).
- What a patch row must contain depends on the table's generation: **old** tables need the whole row; **new** tables need only the key plus changed fields; some tables cannot be patched at all. The per-table list is in [Table generations](#table-generations-and-what-a-patch-must-contain).
- Confirm a patch merged with the retail log line `Table '<t>' is patched by '<t>__<modid>', lines added: N, modified: N, equal: N` (retail binary: sub_2749940).
- GUIDs are bare lowercase `8-4-4-4-12` strings; every new row needs a fresh one. Useful vanilla GUIDs are in [GUID conventions](#guid-conventions).
- Most "my row does nothing" bugs are silent data rules (`IsQuestItem`, `RequiresFilledSlot`, two items in one slot). See [Gotchas](#gotchas).

## Layout and file format

| Where | What |
|---|---|
| `Tables.pak` → `Libs/Tables/` | the database: `ai/`, `rpg/`, `item/`, `combat/`, `character/`, `shop/`, `skald/`, `ui/`, `text/`, `music/`, `RandomEvent/`, ... |
| `<table>.xml` + `<table>.tbl` | source XML and compiled runtime form ship side by side for many tables. **Patch the `.xml`** (tutorial episode 1) |
| `<table>__<part>.xml` | vanilla splits big tables into parts for organisation (`item__unique.xml`, `buff__perk.xml`, `soul__animal.xml`); parts load together in any order and may only add new keys (official wiki KM-A-12) |
| `IPL_GameData.pak` → `Libs/Storm/` | Storm rules (appearance, equipment, roles, abilities), not tables; merged via `storm__<modid>.xml` (official wiki KM-A-32, KM-A-84) |
| `Scripts.pak` → `AI/`, `Quests/` | behaviour trees and Skald graphs, not tables |

Every table file has the same envelope (vanilla `Libs/Tables/rpg/buff.xml`):

```xml
<?xml version="1.0" encoding="us-ascii"?>
<database xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="barbora" xsi:noNamespaceSchemaLocation="../database.xsd">
  <buffs version="1">
    <buff buff_id="..." buff_name="..." ... />
  </buffs>
</database>
```

Copy the wrapper element **and its `version`** from the vanilla file you patch (`<ItemClasses version="8">`, `<InventoryPresets version="2">`, `<Shops version="5">`, `<rpg_params version="1">`). A UTF-8 BOM before the declaration is tolerated (every Mercenaries table patch has one, verified in game).

## Patching

Name: `<table>__<modid>.xml`, placed at the vanilla table's relative path, e.g. `Libs/Tables/rpg/rpg_param__pack_mule.xml` patches `Libs/Tables/rpg/rpg_param.xml` (official wiki KM-A-12, KM-A-84).

- **Patch the base table, not a part.** `InventoryPreset__<modid>.xml`, not a patch of `InventoryPreset__player.xml` (official wiki KM-A-17).
- **Order:** vanilla parts first, then patches in mod load order; a later mod's patch of the same key lands on top (official wiki KM-A-12).
- **Directory case does not matter** inside a pak: vanilla ships `Character/`, the Mercenaries mod patches `libs/tables/character/` (verified in game).
- **Reserved modids:** a modid equal to a vanilla part name (`horse`, `perk`, `player`, `dlc`, ...) turns your patch into an override of that part (official wiki KM-A-35; see [mod-structure.md](mod-structure.md#modmanifest)).
- **Reading the result:** retail logs `Table '%s' is patched by '%s', lines added: %d, modified: %d, equal: %d, time: ...` (retail binary: sub_2749940). `added` = new keys, `modified` = existing keys overridden, `equal` = rows identical to vanilla. The dev build logs `Patched database Item with file 'item__<modid>.xml'` instead (official wiki KM-A-17). Mercenaries has seen `Table 'perk_rpg_param_override' is patched by 'perk_rpg_param_override__mercenaries', lines added: 2` (combat-movement.md, verified in game).
- **SmartEntity is registry-keyed, not row-keyed.** A second `SmartEntityTemplate` file reusing an existing template `Name` (e.g. `so_interrupt`) does not merge into the first; fold new behaviour templates into your one existing file (Mercenaries `TODO.txt`, claimed; the mod ships `ai/smartEntity/SmartEntity__so_interrupt__mercenaries.xml` and it works). Detail: [ai-brains-and-npcs.md](ai-brains-and-npcs.md#smartentity-and-smartbehaviortemplate), [behavior-trees.md](behavior-trees.md#interrupts-and-schedulers).

### Table generations and what a patch must contain

From the official list of 307 tables (KM-A-12): 151 old, 57 new (20 of them "supported since 1.2"), 40 "unsupported, must replace whole", 31 "do not change", 28 unused.

| Generation | Patch row must contain | Examples |
|---|---|---|
| **old** (flat KCD1-style rows, relations via junction tables) | **the entire row**, every attribute, even unchanged ones | `rpg/buff`, `rpg/perk`, `rpg/perk_buff`, `rpg/rpg_param`, `rpg/soul`, `rpg/role`, `rpg/skill`, `ai/brain`, `ai/subbrain`, `ai/brain2mailbox`, `item/armor_type`, `item/weapon_sub_class` |
| **new** (KCD2 structured: lists/maps inline, per-row types) | primary key + changed properties; the rest comes from vanilla or an earlier mod | `item/item`, `item/InventoryPreset`, `item/clothing_preset`, `item/weapon_preset`, `item/weapon_class`, `shop/shop`, `character/CharacterComponent`, `ai/smartentity/smartEntity`, `ai/ScriptContext`, `ui/cutscene`, `RandomEvent/*` |
| **new, since 1.2** | as new | `rpg/FactionTree`, `rpg/buff_ai_tag`, `rpg/crime`, `rpg/SoulPool`, `rpg/skill_teacher`, `character/ClothingConfig`, `character/ClothingMaterial`, `/CVarOverride`, `/Level`, `/player` |
| **unsupported, must replace whole** | override the full file; conflicts with every other mod doing so | `combat/CombatCombos`, `item/equipment_slot`, `item/EquipmentPresetFilter`, `music/*`, `GameAudio/SkaldAtl*`, `ui/menu_*`, `ai/NPCStateActionDatabase`, `rpg/money_change` |
| **do not change** | nothing; values are hard-coded in the engine too | `rpg/buff_implementation`, `rpg/buff_lifetime`, `rpg/buff_exclusivity`, `rpg/gender`, `rpg/race`, `item/ammo_class`, `combat/combat_zone` |

List-valued properties in new tables (notably `CharacterComponent`) are patched **per list item**: the vanilla list is kept and your new entries are appended (official wiki KM-A-12); the wiki's figure suggests entries whose key already exists are modified in place (unverified). `InventoryPreset` sources work the same way since 1.3 (official wiki KM-A-90).

When unsure, copy the full vanilla row: that is valid for both generations (tutorial episode 1).

Not in the official list at all: the `skald/` and `text/` tables. The Mercenaries mod patches `skald/skald_character`, `skald_character2role` and `skald_character2profession` and those merges work (verified in game: its NPCs have names and dialogue).

Overriding an **existing** key in an old table (as opposed to inserting a new one) is less proven: for `rpg_param` only inserts are confirmed by log; check `modified:` in the log line before relying on an override (enemy-morale.md, loot-sweep.md).

## Key tables

| Table (`Libs/Tables/...`) | Primary key | Holds | Mercenaries example |
|---|---|---|---|
| `item/item.xml` (+ 11 vanilla parts) | `Id` GUID (also unique `Name`) | every item class; element name is the type | `item/item__mercenaries.xml` |
| `item/weapon_preset.xml` | `weapon_preset_id` / `weapon_preset_name` | a weapon loadout = list of `item_class_id` | `item/weapon_preset__mercenaries.xml` |
| `item/clothing_preset.xml` | `clothing_preset_id` / `clothing_preset_name` | an outfit = `<Items><Guid>...` list + `gender`, `Quality`, `Condition` | `item/clothing_preset__mercenaries.xml` |
| `item/InventoryPreset.xml` | `Name` | inventories for NPCs, chests and shop stock, built from rules | `item/InventoryPreset__mercenaries.xml` |
| `item/equipment_slot.xml`, `armor_type.xml`, `weapon_class.xml`, `weapon_sub_class.xml` | ids | the slot model, see [Item slot model](#item-slot-model) | read-only |
| `rpg/buff.xml` (+ parts) | `buff_id` | stat modifiers applied to souls | `rpg/buff__mercenaries.xml` |
| `rpg/buff_ai_tag.xml` | id | tags a buff so Skald `BuffTagTrigger` / scheduler links `+tag` can react to it | (official example KM-A-31) |
| `rpg/perk.xml`, `perk_buff.xml`, `soul2perk.xml`, `perk_rpg_param_override.xml` | ids | perks and what they grant | `rpg/perk__mercenaries.xml` |
| `rpg/rpg_param.xml` | `rpg_param_key` | global RPG constants (322 of ~1,025 authored; the rest are code defaults) | `rpg/rpg_param__mercenaries.xml` |
| `rpg/soul.xml` (+ 167 parts, 8,206 souls) | `soul_id` | one row per NPC identity | `rpg/soul__mercenaries.xml` |
| `rpg/FactionTree.xml` | `Faction Name` (hierarchical) | factions, relations, labels | `rpg/FactionTree__mercenaries.xml` |
| `rpg/role.xml` | role id / name | dialogue roles; tied to souls by Storm | `rpg/role__mercenaries.xml` |
| `ai/brain.xml`, `subbrain.xml`, `brain2subbrain.xml`, `brain2mailbox.xml`, `mailbox*`, `brain_variable.xml` | ids | NPC brains; see [ai-brains-and-npcs.md](ai-brains-and-npcs.md#brains-and-subbrains) | `ai/*__mercenaries.xml` |
| `ai/smartEntity/SmartEntity__*.xml` | template `Name` | behaviour templates an interrupt may fire | `ai/smartEntity/SmartEntity__so_interrupt__mercenaries.xml` |
| `shop/shop.xml` | `shop_id` / `shop_name` | shops: restock period, stock preset, price filters | `shop/shop__mercenaries.xml` |
| `skald/skald_character.xml` (+ `2role`, `2profession`) | `skald_character_name` | the character a soul speaks as: `voice_id`, `gender`, `ui_name_string_name` | `skald/skald_character__mercenaries.xml` |
| `skald/voice.xml` | `voice_id` | 93 voices: `abbreviation` (file prefix), fallbacks | read-only; see [audio-voice-lipsync.md](audio-voice-lipsync.md) |
| `character/CharacterComponent.xml` | component `Name` | clothing/armour/body meshes and their features | `character/CharacterComponent__mercenaries.xml` |
| `ui/cutscene.xml` | cutscene name | cutscene registry (patchable, but a mod still cannot play one: [skald-quests-dialog.md](skald-quests-dialog.md#cutscenes-and-random-events)) | - |
| `CVarOverride.xml` | GameContext | binds a game context to a `Config/CVarOverrides/<name>.cfg` with a priority (malesov-test.md) | - |
| `player.xml` | `PlayerId` | the player souls: Henry `4c2dcffb-dea1-6263-72d7-b39f4db2d8b5`, Bohuta `4666cffb-dea1-6263-72d7-b39f4db2d666` | - |

A complete NPC touches soul, FactionTree, role, the three `skald_character*` tables, clothing/weapon/inventory presets, and three Storm files: follow [Adding a new NPC](../xml/add-new-npc.md). Brains: [Making an NPC brain](../xml/make-npc-brain.md).

## Items

`item.xml` rows are typed by element name (`<ItemClasses version="8">`). Counts across vanilla `item*.xml`: `Armor` 2,848, `MeleeWeapon` 664, `MiscItem` 414, `Document` 403, `Food` 328, `NPCTool` 258, `Helmet` 152, `Hood` 150, `MissileWeapon` 57, `CraftingMaterial` 52, `ItemAlias` 51, `Ammo` 41, `Herb` 37, `Ointment` 28, `Poison` 15, `Money` 1, ...

Fields you will use (official wiki KM-A-17, KM-A-89):

- `Id` (GUID, **must be new** for a new item) and `Name` (string key used by presets).
- `UIName` / `UIInfo`: string ids; add rows to your localization file ([mod-structure.md](mod-structure.md#localization-text)).
- `IconId`, `Model` (`.cgf` path), `Weight`, `Price` **in decigroschen** (displayed price = `Price / 10`).
- Weapons: `Class` / `SubClass` → `weapon_class.xml` / `weapon_sub_class.xml` (class 4 = longsword, 5 = mace); `Attack`, `AttackModStab/Slash/Smash`, `Defense`, `StrReq`, `AgiReq`, `MaxQuality`, `IsBreakable`, `Clothing` (scabbard component).
- `IsQuestItem="true"`: see Gotchas; it silently blocks the item from presets.
- `ItemAlias` rows have `SourceItemId`; resolve them to the real item (custom-gear.md).

Quality and health (official wiki [KM-A-89](https://warhorse.youtrack.cloud/articles/KM-A-89)): items have health 0..1; quality 1..4 maps to health bands 0-0.1, 0.075-0.3, 0.225-0.6, 0.45-1 (4 is Henry's crafted tier). Database stats are at max health. `CurrentAttack = Attack*(sqrt(h)*0.6 + 0.4)` (`WeaponStatusToAttackCoef` 0.6); armour defence and charisma use the same shape with `ArmorStatusToDefenseCoef` / `ArmorStatusToCharismaCoef` 0.6; `CurrentPrice = Price*(h*0.99 + 0.01)` (`ItemHealthPriceStatusWeight` 0.99).

Walkthroughs: official [KM-A-17 Adding a new item](https://warhorse.youtrack.cloud/articles/KM-A-17); public guides [adding-new-outfits.md](../general/adding-new-outfits.md), [adding-new-weapons.md](../general/adding-new-weapons.md).

### Item slot model

- An armour item's slot is **not** on the item: `Armor/Helmet/Hood.Clothing` → `CharacterComponent`/`armor_type.xml` → `equipment_slot.xml`'s `ArmorTypes`. Weapons go `Class` → `weapon_class.xml` (which also gives the equip slot, e.g. `PrimaryMainHand`) (custom-gear.md, official wiki KM-A-17).
- `equipment_slot.xml` rows carry `RequiresFilledSlot`: the slot **silently refuses** anything until the prerequisite underlayer is filled (custom-gear.md, vanilla). The complete list - seven slots, five prerequisites (vanilla: `Libs/Tables/item/equipment_slot.xml`):

  | Slot | Requires |
  | --- | --- |
  | `head_helmet` | `head_coif_padded` |
  | `body_plate`, `body_chainmail`, `sleeves` | `body_cloth_padded` |
  | `leg_armor` | `leg_trousers_padded` |
  | `spur` | `boot` |
  | `horse_torso` | `horse_saddle` |

  So equip coif before helmet, gambeson before cuirass *and* arms, padded hose before leg plate, boots before spurs.
- Per-piece equipping (`actor:EquipInventoryItem`) fills only the slots it names; every slot a clothing preset filled earlier **stays dressed**, so a hand-dressed NPC can wear two kits at once. `inventory:RemoveAllItems()` empties the pack, not what is worn. Strip the leftovers with [`human:UnequipItemInSlot`](api/Human.md#unequipiteminslot)`(slotId)`, which takes an `equipment_slot` **Id** (e.g. 7 `body_coat`, 22 `collar`, 23 `head_hood`, 33 `head_cap`), not the item id the docs name (mod: `mercenaries_aleksej.lua` `AlxStripOverLayers`, aleksej.md; effect claimed).
- Two items for the same slot in one `clothing_preset` → **neither** is equipped ([add-new-npc.md](../xml/add-new-npc.md), verified in game).
- A `weapon_preset` is equipped as one atomic set; there is no separate shield slot, so shields go into the weapon preset ([adding-new-weapons.md](../general/adding-new-weapons.md), Mercenaries `TODO.txt`).
- Lua cannot query an item's slot or category (`ItemManager` exposes only `GetItem`/`GetItemName`/`GetItemUIName`); build an offline lookup from the tables. Remember vanilla splits items across `item__*.xml` parts; reading only `item.xml` misses over a thousand (custom-gear.md).
- Runtime rules for dressing NPCs from Lua (apply a preset first, no reliable unequip, `inventory:CreateItem` vs `ItemManager.CreateItem`) belong to [ai-brains-and-npcs.md](ai-brains-and-npcs.md#equipment-and-appearance); see also custom-gear.md and [Inventory.CreateItem](api/Inventory.md#createitem).

### Money

- Money is one item class, `Money` `5ef63059-322e-4e1b-abe8-926e100c770e` (groschen). Item `Price` is in **decigroschen** (above).
- Skald `CreatePlayerReward` with the money class takes `Amount` in **decigroschen** too: vanilla's `createmoney_player` module takes groschen and passes them through `converttodecigroshen` (a plain x10) before calling that node on that class. Pass groschen straight in and the player gets a tenth, and the UI notification confirms the wrong number (vanilla `Quests/`; aleksej.md).
- Skald `move_money` **moves** coins between two inventories; from a source that carries none (e.g. a Lua-spawned NPC) it moves nothing and still reports success. Use `CreatePlayerReward`, which creates (aleksej.md, claimed).
- [`Inventory.AddMoney`](api/Inventory.md#addmoney) is documented but absent from the retail binary and runtime dump; in a `pcall` it silently does nothing. Vanilla Lua pays with `ItemUtils.AddMoneyToInventory(who, amount)`: `ItemManager.CreateItem(<groschen guid>, 1, amount)` + `inventory:AddItem` (vanilla: `Scripts/Utils/ItemUtils.lua`; the unit of `amount` there is unverified). [`Inventory.GetMoney`](api/Inventory.md#getmoney) reads the purse.

### Inventory presets

`InventoryPreset.xml` entries combine sources and a selection mode (official wiki [KM-A-90](https://warhorse.youtrack.cloud/articles/KM-A-90)):

- Sources: `InventoryPresetRef`, `ClothingPresetRef`, `WeaponPresetRef` (by `Name`), `PresetItem` (with `Amount`).
- `Mode`: `All`; `OneChild` (one random source, weighted; picks the closest `CombatLevel` for NPCs); `AmountCount` / `AmountFraction` (`ModeValue` ± `ModeValueVariation` items or percent).
- `Weight`, `CombatLevel` on sources; `Quality` 1-4, `Health`(+`HealthVariation`), `Condition`(+`ConditionVariation`) 0-1 on presets/items. `Quality` overrides health.
- Patching (since 1.3): same `Name` = modify that source, new `Name` = add a source. Sources cannot be removed; set `Weight="0"` where the mode respects weight.
- Shared vanilla pools such as `pockets_soldiers_all` can be referenced by name ([add-new-npc.md](../xml/add-new-npc.md)).

## Buffs

```xml
<buff buff_id="<new guid>" buff_name="mymod_fast" buff_class_id="15" buff_exclusivity_id="1"
      buff_lifetime_id="1" buff_params="rms*1.15,agility+2" duration="-1"
      implementation="Cpp:Constant" is_persistent="false" />
```

| Field | Values | Source |
|---|---|---|
| `buff_params` | comma list of `<code><op><value>`: `*` multiply (625 vanilla uses), `+` add (612), `=` set (310, incl. `=-1`), `-` subtract (207), `%` (19, e.g. `hlh%0.3`, semantics unverified), bare flag (32, e.g. `LimitSprint`, `LimitRun`) | vanilla `rpg/buff*.xml` census |
| codes | technical names of stats/skills/derived stats: `strength`, `agility`, `vitality`, `rms` (real move-speed mod), `hlh` (health loss per hit), `con` (conspicuousness), `imm` (immortality), `plr` (pillory), ... | official wiki [KM-A-21](https://warhorse.youtrack.cloud/articles/KM-A-21) (full list) |
| `buff_class_id` | 1 System, 4 Perk, 5 Injury, 7 Poison, 12 Item, 13 Potion, 15 **Script System** (use for mod buffs), 16 Unconsciousness, 20 Punishment, ... | vanilla `rpg/buff_class.xml` |
| `implementation` | C++ handler: `Cpp:Constant` (358), `Cpp:BasicTimed` (143), `Cpp:Unconscious`, `Cpp:Fading`, ... | vanilla census; do-not-change table |
| `buff_exclusivity_id` | 0 none, 1 IdExclusive (same id not stacked), 2 ModExclusive, 3 ClassExclusive, 4 TargetExclusive | vanilla `rpg/buff_exclusivity.xml` |
| `buff_lifetime_id` | 0 ShortTerm, 1 LongTerm | vanilla `rpg/buff_lifetime.xml` |
| `duration` | seconds; `-1` permanent | vanilla |
| `is_persistent` | `false` buffs are never written into the save | save-footprint.md |
| `icon_id` | shows `Libs/UI/Textures/Icons/Buffs/<icon_id>_icon.dds`; that folder is wildcard-preloaded, so a new `.dds` there needs no registration | ui.md (retail binary + verified in game) |
| `buff_ai_tag_id` | links a `buff_ai_tag` row | official wiki KM-A-31 |

Applying: Lua [soul:AddBuff(guid)](api/Soul.md#addbuff); BT `<AddBuff SoulWUID="$this.id" BuffGUID="'<guid>'"/>` and `<RemoveBuffs .../>`; Skald `Buff` node (official wiki KM-A-31). Re-adding an IdExclusive permanent buff does not stack (old context doc). `AI.SetSpeed`-style speed changes get overwritten each tick; a `rms*` buff persists (old context doc, claimed).

Useful vanilla buffs: `immortality` `85aca9c5-ec41-400d-a563-53df7b2399e8` (`imm=1`); `unconscious_permanent` `c75aa0db-65ca-44d7-9001-e4b6d38c6875` (`Cpp:Unconscious`, knocks a live NPC out, loot-sweep.md); a 60-second unconscious variant `f8d60fe4-e2c1-420a-946a-213e1cd09264` (loot-sweep.md).

## RPG parameters

- `rpg/rpg_param.xml`: `<rpg_param rpg_param_key="HerbGatherXP" rpg_param_value="20"/>`; keys absent from the table keep their compiled default (official wiki KM-A-84). Full list with descriptions: [KM-A-20](https://warhorse.youtrack.cloud/articles/KM-A-20).
- Lua read/write at runtime: `RPG.<Key>`, `RPG.<Key> = v`, `RPG.Help('Herb')` lists matches (official wiki KM-A-84; [RPG.Help](api/RPG.md#help)).
- Some constants are **recomputed every tick** after table load (the `CombatAuto*` attack-cadence block is overwritten by a runtime blend), so a table edit to those does nothing (enemy-morale.md, retail binary).
- Perks override params through `perk_rpg_param_override` (merge confirmed by log, combat-movement.md).
- Initial NPC stats come from Storm `abilities` rules (`setAttribute stat=... value=...`), not the soul row. Add a rule file via `storm__<modid>.xml`; Storm applies rules in load order, so yours runs last and wins (official wiki KM-A-84).

## Souls and factions (data side)

Soul row (vanilla `rpg/soul__player.xml`):

```xml
<soul soul_id="4c2dcffb-..." soul_name="player_henry" brain_id="..." factionName="player"
      soul_archetype_id="13" soul_class_id="5" social_class_id="13" skald_character_name="26"
      soul_vip_class_id="0" xp_multiplier="1" initial_clothing_dirt="0" unique="true" />
```

- `soul_archetype_id` must match the spawned entity class (`NPC` male, `NPC_Female` = archetype 1) or the NPC T-poses (spawning-npcs.md, female-mercenaries.md).
- `soul_vip_class_id` is a declared enum, not a free bitfield: 0 none, 1 pickpocket, 2 attack, 3 attack+steal, 4 immortality, 8 unconsciousness, 12 immortality+unconsciousness, 13, 15, 16 loot protection, 23, 31 untouchable (vanilla `rpg/soul_vip_class.xml`). Use only declared values (companions.md).
- `skald_character_name` → `skald/skald_character.xml` → `voice_id` (see [audio-voice-lipsync.md](audio-voice-lipsync.md)).
- `factionName` must exactly match a `Faction Name` in `FactionTree` ([add-new-npc.md](../xml/add-new-npc.md)).

`FactionTree.xml` is a hierarchy of `<Faction Name=".." Labels="..">` with `<Relations><Relation target=".." reputation="-1|0|1"/>` and `<Children>`. Labels come from `rpg/faction_label.xml`: `city`, `camp`, `settlement`, `solitude`, `jewish`, `german`, `romani`, `publicEnemy`. Two data rules with large consequences: relations are **one-directional** (declaring your faction hostile to vanilla does not make vanilla hostile back), and `Labels="publicEnemy"` is what makes a corpse lootable rather than robbable and a kill not a crime (public-enemy.md, npc-lod.md, verified in game). Re-declaring a vanilla faction node in your patch to add a reverse relation is untested and may drop its children (public-enemy.md). Behaviour consequences: [ai-brains-and-npcs.md](ai-brains-and-npcs.md#factions-and-relations), [combat-and-perception.md](combat-and-perception.md#target-selection).

## Shops

`shop/shop.xml` (`<Shops version="5">`): `<ShopData shop_id=".." shop_name=".." restock_period="7" inventory_preset="inventory_shop_..">` with `<ShopItemFilter filter="food.meat.*" price_buy_multiplier=".." price_sell_multiplier=".."/>` children (vanilla). A shop is bound to its keeper through level-baked XGenAI links, so a runtime-spawned NPC cannot be made a real shopkeeper; the trade UI opens only from a Skald `OpenShop` sequence on the dialogue partner (camp-trader.md, retail binary).

## GUID conventions

- Format: lowercase `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`, bare, no braces (every vanilla table).
- Every new row (item, buff, soul, preset) needs a **fresh unique GUID**; the official walkthrough warns never to reuse a copied vanilla `Id` (official wiki KM-A-17). Nothing validates the GUID version: the Mercenaries mod ships hand-typed sequential soul GUIDs (`c2a51ce4-449f-4a2e-83b9-c098c5b11801` ... `11817`) that work (verified in game).
- In Lua and in Skald `SharedSoulGuids` / BT `BuffGUID` / spawn `properties.guidSharedSoulId`, pass the bare GUID. Exception: vanilla's debug spawner `CombatDebug.SpawnFriend/SpawnEnemy` takes `s<guid>` (soul), `a<guid>` (armour preset), `w<guid>` (weapon preset) as 37-character arguments; a bare 36-character GUID is silently ignored there (vanilla: `Scripts/Debug/CombatDebug.lua`, param parser). See [skald-quests-dialog.md](skald-quests-dialog.md#gotchas) for the conflict with the old context doc.
- Compare GUIDs in Lua with a plain find: `string.find(s, guid, 1, true)`. In a Lua pattern `-` is a quantifier, so the default pattern find mismatches every GUID (old context doc, community).
- The Mercenaries code compares `tostring(soul:GetId())` against GUID strings (old context doc). Entity ids (`ent.id`) are not stable across ticks; compare by entity name (ai-modules.md).

Well-known GUIDs:

| GUID | What | Source |
|---|---|---|
| `4c2dcffb-dea1-6263-72d7-b39f4db2d8b5` | Henry's soul (`player_henry`), constant in every save | vanilla `player.xml`, `rpg/soul__player.xml` |
| `4666cffb-dea1-6263-72d7-b39f4db2d666` | Bohuta (second player soul) | vanilla `player.xml` |
| `5ef63059-322e-4e1b-abe8-926e100c770e` | groschen (`Money` item) | vanilla `item/item.xml` |
| `85aca9c5-ec41-400d-a563-53df7b2399e8` | `immortality` buff | vanilla `rpg/buff.xml` |
| `c75aa0db-65ca-44d7-9001-e4b6d38c6875` | `unconscious_permanent` buff | vanilla `rpg/buff.xml` |

Precedence note: the old context doc lists `96371224-86de-4c6f-b0c8-e9567f5ca3e1` as "the player GUID". It is not in any vanilla table; it is the first Mercenaries merc soul (`data/Quests/.../mercenaries_background_quest.xml` `SoulAsset "mercs"`). Vanilla `player.xml` wins.

## Finding things in vanilla data

- Extract `Tables.pak`, `Scripts.pak` and `IPL_GameData.pak` (all plain zips) to a short path and grep them ([Episode 1](../tutorials/episode-01-mod-setup.md#2-the-vanilla-reference), [how-to-mod.md](../general/how-to-mod.md)). An extracted copy lives in `references/kcd2-mod-docs-main/Libs/Tables/` (local only).
- `python tools/kb.py build --with-vanilla` indexes vanilla Scripts and Tables for `kb.py search`.
- String ids → text: grep `Localization/English_xml.pak` (`text_ui_items.xml`, `text_ui_soul.xml`, ...).
- By item name → GUID: grep `item*.xml` for `Name="..."`; the Cheating mod (Nexus 114) plus a GUID list is the in-game route ([adding-new-outfits.md](../general/adding-new-outfits.md), community).
- Official editing tools: the Excel add-in (`Tools/modding/ExcelDbAddin.DbAndXsdSupport.vsto`) retrieves and posts tables or typed views, and can save straight into your mod as patch files (official wiki [KM-A-86](https://warhorse.youtrack.cloud/articles/KM-A-86)). Community editors: Warbox, ModForge ([sources.md](sources.md)).
- Runtime reads from Lua: [Database.GetTableInfo](api/Database.md#gettableinfo), [Database.GetTableLine](api/Database.md#gettableline), [Database.GetColumnInfo](api/Database.md#getcolumninfo).
- An item GUID that works in game but is missing from your extracted dump means the dump is stale, not the data (weapon-audit.md).
- Before copying an appearance asset name, check it against `CharacterComponent.xml`; grepping your own files proves nothing (bandit-camp-quest.md).

## Gotchas

- **An item is silently missing from an NPC's preset while the rest arrives:** it is `IsQuestItem="true"`; presets never grant quest items and nothing logs it (weapon-audit.md, companions.md, verified in game).
- **The cuirass never equips, no error:** its slot `RequiresFilledSlot` an underlayer that is empty (custom-gear.md).
- **A hand-dressed NPC wears two outfits at once:** per-piece equipping leaves the preset's other slots filled; `UnequipItemInSlot` them (aleksej.md).
- **A reward pays a tenth of what you wrote:** money `Amount` in `CreatePlayerReward` is decigroschen ([Money](#money)).
- **Money transfer "succeeds" and nothing arrives:** `move_money` from an empty purse, or `inventory:AddMoney`, which retail does not bind ([Money](#money)).
- **An NPC is half-dressed:** two items in the clothing preset share a slot, so neither is equipped ([add-new-npc.md](../xml/add-new-npc.md)).
- **Old-table patch wiped fields to defaults:** old tables need the full row in the patch (official wiki KM-A-12).
- **Patch loads but changes nothing:** you patched a table part (`InventoryPreset__player`) instead of the base table, or the file name's modid differs from the manifest (official wiki KM-A-17).
- **Inventory preset patch ignored on an old build:** patching presets needs 1.3+ (official wiki KM-A-90).
- **Your "patch" replaced a vanilla file:** your modid equals a reserved part name (official wiki KM-A-35).
- **Two items fight over one GUID after copy-pasting a vanilla row:** change the `Id`; the official walkthrough warns duplicates break things (official wiki KM-A-17, exact symptom unverified).
- **An RPG constant edit has no effect:** it is recomputed at runtime after load (`CombatAuto*`), or it was an override case that did not apply; read `modified:` in the patch log line (enemy-morale.md).
- **Vanilla NPCs ignore your hostile faction:** relations are one-directional (npc-lod.md).
- **A second SmartEntity file's behaviour "was not available":** templates with the same registry name do not merge across files (Mercenaries `TODO.txt`, claimed).
- **Lua GUID match never succeeds:** you used `string.find` without the plain flag (community).
- **A table edit made in a running dev session does nothing:** tables load once at startup (official wiki KM-A-12).

## See also

- [mod-structure.md](mod-structure.md): packaging, load order, localization files.
- [skald-quests-dialog.md](skald-quests-dialog.md): how quests use buffs, items and souls.
- [audio-voice-lipsync.md](audio-voice-lipsync.md): `skald_character.voice_id` and `voice.xml`.
- Public guides: [add-new-npc.md](../xml/add-new-npc.md), [make-npc-brain.md](../xml/make-npc-brain.md), [adding-new-outfits.md](../general/adding-new-outfits.md), [adding-new-weapons.md](../general/adding-new-weapons.md).
- Official: [KM-A-12 Database tables](https://warhorse.youtrack.cloud/articles/KM-A-12), [KM-A-16 RPG](https://warhorse.youtrack.cloud/articles/KM-A-16), [KM-A-32 STORM](https://warhorse.youtrack.cloud/articles/KM-A-32).
