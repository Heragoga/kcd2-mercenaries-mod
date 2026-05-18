# Custom Weapon Presets

This guide covers how to customize the weapons your mercenaries carry. Like clothing, weapons are dictated by the mercenary's soul/STORM role rather than saved per-NPC — so customizing them means defining a preset and pointing the mercenary at it.

This guide assumes you've already set up the workflow from the [Custom Equipment Presets](#) guide (repo cloned, `PackageMod.bat` working). If not, follow steps 1 and 2 there first.

---

## Step 1 — Create the Weapon Preset File

Create a new file at:

```
data/libs/tables/item/weapon_preset__mercenaries.xml
```

Paste in the following skeleton:

```xml
<?xml version="1.0" encoding="us-ascii"?>
<database xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="barbora" xsi:noNamespaceSchemaLocation="../database.xsd">
    <weapon_presets version="1">
        <weapon_preset
            weapon_preset_id="ae0b60a4-2fea-42e1-8ef5-7b81468cd898"
            weapon_preset_name="hammer_shield_5_01">
            <weapon_preset_item item_class_id="5f7ecb68-3d15-4cbf-988a-9e8de87fa0d9" /> <!-- hammer -->
            <weapon_preset_item item_class_id="e4e1b22a-428a-4e20-aa92-ce216b324c0a" /> <!-- shield -->
        </weapon_preset>
    </weapon_presets>
</database>
```

This is the exact definition of the stock `hammer_shield_5_01` preset. The `<weapon_preset_item>` entries reference weapon/shield GUIDs — the same kind of GUIDs you'd find on [Raider King's console commands list](https://raiderking.com/kingdom-come-deliverance-2-all-console-commands-cheats-list/).

---

## Step 2 — Add Your Own Preset

Add your own `<weapon_preset>` entry inside `<weapon_presets>`. Here's a template:

```xml
<weapon_preset
    weapon_preset_id="YOUR-UNIQUE-UUID-HERE"
    weapon_preset_name="my_weapon_preset1">
    <weapon_preset_item item_class_id="GUID-OF-WEAPON-1" />
    <weapon_preset_item item_class_id="GUID-OF-WEAPON-2" />
</weapon_preset>
```

**Generate a unique UUID** for `weapon_preset_id` at [uuidgenerator.net](https://www.uuidgenerator.net/). Pick a memorable `weapon_preset_name` — you'll need it in the next step.

You can list as many weapons as you like inside the preset. Modded weapons work too, as long as you have their GUIDs.

### Finding weapon GUIDs

Same two options as with clothing items:

**Option A — Cheat mod (easier)**
Install [cheat_add_all_items](https://www.nexusmods.com/kingdomcomedeliverance2/mods/114), grab the weapons in-game, then look them up on [Raider King's list](https://raiderking.com/kingdom-come-deliverance-2-all-console-commands-cheats-list/) to get their GUIDs.

**Option B — Extract game files (more thorough)**
Open:
```
C:\Program Files\Steam\steamapps\common\KingdomComeDeliverance2\Data\IPL_GameData.pak
```
with 7-Zip or WinRAR, then search `tables/item/item.xml` for the weapons you want.

---

## Step 3 — Point the Mercenary's Inventory Preset at Your Preset

Open the mercenary's inventory preset and change the `weapon_preset` reference from `hammer_shield_5_01` (or whatever it currently uses) to the `weapon_preset_name` you defined in Step 2.

---

## Step 4 — Package and Test

Run `PackageMod.bat`, launch the game, and hire some mercenaries. They should now be carrying your custom weapons.