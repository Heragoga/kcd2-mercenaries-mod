# Custom Equipment Presets

This guide covers how to customize the armor your mercenaries wear. If you're wondering why there's no in-game inventory management feature for your squad, here's why:

**Save persistence.** The equipment an NPC wears is not saved between game reloads — it's dictated by their soul and STORM roles. To support in-game customization, the mod would have to programmatically save every mercenary's inventory and re-dress them on each reload. That's doable in principle, but it's a reliable source of bugs.

**Micromanagement hell.** Individually dressing up six guys — sourcing matching waffenrocks, cloaks, and so on — just isn't fun.

That said, you absolutely can customize their equipment. It just requires a small amount of manual work, which this guide walks you through.

> ⚠️ **Windows only.** The packaging script does not run on macOS or Linux.

---

## Step 1 — Get the Repository

Download the repository at [https://github.com/Heragoga/kcd2-mercenaries-mod](https://github.com/Heragoga/kcd2-mercenaries-mod).

- **If you have Git installed:** `git clone https://github.com/Heragoga/kcd2-mercenaries-mod`
- **Otherwise:** click the green **\<\> Code** button and select **Download ZIP**, then extract it wherever you like.

You'll only be editing files inside the `/data` folder.

### Install & test your build

To install the mod, double-click **`PackageMod.bat`** in the repo root. It converts the mod folders into `.pak` archives and copies them into your game directory:

```
C:\Program Files\Steam\steamapps\common\KingdomComeDeliverance2\Mods
```

> If your game is installed elsewhere, open `PackageMod.bat` in a text editor and update the path at the top.
> **Note:** running the script will delete the existing mod folder in `/Mods` before copying the new one.

Run the script once now, launch KCD2, and confirm the mod works before making any changes.

---

## Step 2 — Set Up Your Workflow

Every time you want to test a change:

1. Edit the files in the repo
2. Run `PackageMod.bat`
3. Launch the game

That's the full loop.

---

## Step 3 — Add a Clothing Preset

Open the following file in your editor (VS Code recommended):

```
data/libs/tables/item/clothing_preset__mercenaries.xml
```

Paste in a new `<clothing_preset>` entry. Here's a template to start from:

```xml
<clothing_preset
    clothing_preset_id="YOUR-UNIQUE-UUID-HERE"
    clothing_preset_name="my_clothing_preset1"
    gender="Male"
    prefers_hood_on="false"
    social_class_id="3">
    <Items>
        <Guid>d87e0065-4eae-429f-917a-df1db1b7285a</Guid> <!-- boots -->
        <Guid>a157447c-3c6f-463a-a02d-d4b696e644e1</Guid> <!-- pants -->
        <Guid>8c21aba6-cc35-4022-807b-22e4bd987e5a</Guid> <!-- cuirass -->
        <Guid>3d5708c2-65a2-433e-9792-03c3cbb5c14d</Guid> <!-- plate legs -->
        <Guid>3f31f6fd-e150-4564-80a5-2a9d1ed7dd6b</Guid> <!-- plate arms -->
        <Guid>17f0d18c-c55c-4570-8710-410fe0238792</Guid> <!-- plate gauntlets -->
        <Guid>02af093e-411c-4369-b428-5502ffe277cc</Guid> <!-- cap -->
        <Guid>ff8f8351-c909-4f46-8d3e-b1b8acc1460f</Guid> <!-- coif -->
        <Guid>0942ca27-0900-4244-a563-08531dc77389</Guid> <!-- gambeson -->
    </Items>
</clothing_preset>
```

**Generate a unique UUID** for `clothing_preset_id` at [uuidgenerator.net](https://www.uuidgenerator.net/). Every preset needs its own — don't reuse the example one.

You can create as many presets as you like. Multiple presets in the same tier give the mercenaries some visual variety.

### Finding item GUIDs

Each `<Guid>` points to an equipment item. Two ways to find GUIDs for the items you want:

**Option A — Cheat mod (easier)**
Install [cheat_add_all_items](https://www.nexusmods.com/kingdomcomedeliverance2/mods/114), which adds every item in the game to Henry's inventory. Dress Henry up however you like, then look up the items you used on a site like [Raider King's console commands list](https://raiderking.com/kingdom-come-deliverance-2-all-console-commands-cheats-list/) to get their GUIDs.

**Option B — Extract game files (more thorough)**
Navigate to:
```
C:\Program Files\Steam\steamapps\common\KingdomComeDeliverance2\Data\IPL_GameData.pak
```
Open it with 7-Zip or WinRAR, extract it somewhere safe, then open `tables/item/item.xml` and search for the items you want.

---

## Step 4 — Register the Preset in the Outfit Pool

Open:

```
data/Scripts/mods/mercenaries.lua
```

Near the top you'll find the `mercenaries.Outfits` table, which looks like this:

```lua
mercenaries.Outfits = {
    -- 1: Generic Mercs
    [1] = {
        weak = {
            "0083b6bd-6ebd-47f3-b324-48d64c7ee625",
            "010dbdae-fce7-4598-9f61-f7c6a9541bee",
            -- ...
        },
        medium = {
            "01234e1e-d58d-4c6b-9f5e-5eafba96e3a5",
            -- ...
        },
        strong = {
            "15dff4c0-790a-47b9-b513-6392eb2b2c10",
            -- ...
        }
    },
    -- ...
}
```

This is the pool of clothing preset UUIDs for each mercenary tier. Pick the tier(s) you want your preset to apply to and paste in the UUID you generated in Step 3.

Every tier (`weak`, `medium`, `strong`) must have **at least one** preset UUID — don't leave any empty.

---

## Step 5 — Package and Test

Run `PackageMod.bat`, launch the game, and hire some mercenaries. You should see your new equipment preset in the wild.