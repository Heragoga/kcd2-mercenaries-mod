# KCD2 Modding 01: Mod Setup and Game File Structure

Written companion to Episode 1 of the *KCD2 Modding* video series. Everything the video skips is here, with exact paths and file contents.

Game version at time of writing: **1.5.6**. Warhorse's official knowledge base is linked where it covers a topic: <https://warhorse.youtrack.cloud/articles/KM-A-1>

---

## 1. Tools

| Tool | Used for |
|---|---|
| 7-Zip | Opening and building `.pak` files |
| VS Code or Notepad++ | Editing XML and Lua |
| Total Commander, or VS Code's "Search in folder" | Searching inside thousands of vanilla files |
| KCD2 Modding Tools (optional, free on Steam with the game) | Lua API docs, Steam Workshop upload, Skald, the dev build |

The Modding Tools install as a separate Steam app, `KCD2Mod`. What's useful early on:

- `KCD2Mod/Tools/modding/docs/`: documentation for every Lua binding the game exposes.
- `KCD2Mod/Tools/SteamWorkshopUploader/`: publishing.
- The development build writes a far more detailed `kcd.log`, but it is a different build from the retail game. Anything you test there has to be tested again in the real game.

Official overview: <https://warhorse.youtrack.cloud/articles/KM-A-55>

---

## 2. The vanilla reference

A `.pak` is a zip archive. Open it with 7-Zip (right-click → 7-Zip → Open archive), or copy it and rename it to `.zip`.

Extract these three into **one** folder outside the game directory:

| Pak (`<game>/Data/`) | Size | Contains |
|---|---|---|
| `Tables.pak` | 7 MB | `Libs/Tables/`: the game database, 1,738 files (items, buffs, perks, souls, factions, shops, AI registration...) |
| `Scripts.pak` | 76 MB | `AI/` (behaviour trees), `Quests/` (Skald quests and dialogue, 21,000+ files), `Scripts/` (Lua), `Entities/` |
| `IPL_GameData.pak` | ~1 GB | `Libs/UI/`, `Libs/Storm/`, `Prefabs/`, `Materials/` |

Keep the target path short, e.g. `C:\kcd2ref\`. The deepest vanilla quest path is 192 characters, and Windows paths stop at 255.

Other game folders:

- `<game>/Localization/`: text (`English_xml.pak`, `German_xml.pak`, ...) and voice (`english-part0.pak`, ...).
- Everything else in `Data/`: `Objects-*`, `Characters`, `Textures-*`, `Animations`, `Heads`, `Videos-*`, `Music`, `Sounds` and their `IPL_*` counterparts. These are art assets, 1–2 GB each. You don't need them for data or script mods.

What's in the extracted reference:

| Folder | What it is | Where it's covered |
|---|---|---|
| `Libs/Tables/` | Database tables (XML). Patchable with `__modid`. | Buff / perk / weapon episodes |
| `Libs/Storm/` | Rules for NPC appearance, equipment, roles, contexts | NPC episodes |
| `Libs/UI/` | Scaleform UI (`.gfx`/`.swf`) and UI definitions | UI episode |
| `AI/` | Behaviour trees (XML). `AI/npc/basic/switch/` handles how NPCs react to the player. | AI episodes |
| `Quests/` | Skald quest graphs, dialogue, random encounters | Quest episode |
| `Scripts/` | Lua. `Scripts/Debug/CombatDebug.lua` is a good example of spawning NPCs. | Throughout |
| `Entities/` | Entity class definitions | Custom interaction episode |

---

## 3. Mod layout

```
<game>/
  Mods/
    mod_order.txt                    optional, see §5
    pack_mule/
      mod.manifest                   required
      mod.cfg                        optional: cvars, see §11
      Data/
        pack_mule.pak                any number of *.pak files
      Localization/
        English_xml.pak              optional: text, see §9
```

- The game opens every `*.pak` in `Mods/<folder>/Data/`. Inside a pak, paths mirror the vanilla `Data/` layout (`Libs/...`, `Scripts/...`, `AI/...`).
- **The retail game only loads files inside paks, plus loose `.cfg` files.** Loose XML or Lua in your mod folder is ignored. Only the Modding Tools' development build reads loose files.
- Steam Workshop mods use the same layout and live in `steamapps/workshop/content/1771300/<workshop id>/`.

Official: <https://warhorse.youtrack.cloud/articles/KM-A-3>

---

## 4. mod.manifest

```xml
<?xml version="1.0" encoding="utf-8"?>
<kcd_mod>
  <info>
    <name>Pack Mule</name>
    <modid>pack_mule</modid>
    <description>Henry carries everything.</description>
    <author>Alex</author>
    <version>1.0</version>
    <created_on>2026-09-23</created_on>
    <modifies_level>false</modifies_level>
  </info>
  <supports>
    <version>1.*</version>
  </supports>
</kcd_mod>
```

| Field | Notes |
|---|---|
| `modid` | **Required.** Only lowercase letters and underscores. It's the id used by `mod_order.txt`, table patches, localization, Storm and the Lua init script. |
| `name`, `version` | Shown to players and saved into savegames, so Warhorse can identify mods in bug reports. |
| `description`, `author` | Display only. |
| `created_on` | `YYYY-MM-DD`. The game doesn't need it, but some tools do. |
| `modifies_level` | Set it to `false` unless you ship level data. |
| `supports/version` | Optional. If the running version doesn't match any entry, the mod is **disabled**. |

**The `supports` gotcha:** versions are compared as strings against `wh_sys_version`, and major releases ship without a patch number (`1.2`, not `1.2.0`). `1.2.*` therefore does not match `1.2`. Use `1.2*`, or `1.*` for any 1.x. Leaving `supports` out entirely means "any version".

**Folder name vs modid:** they can differ (the engine uses the modid), but keep them identical.

**Reserved modids:** a modid that matches one of Warhorse's own table-part names would overwrite their file. For example, the modid `horse` makes your patch `item__horse.xml`, which replaces vanilla's. Taken names include `alchemy`, `dlc`, `horse`, `perk`, `player`, `combat`, `crime`, `clothes` and many quest names. Full list: <https://warhorse.youtrack.cloud/articles/KM-A-35>

**Encoding:** keep `encoding="utf-8"` on the first line. Some mod managers fail on manifests without it.

Official: <https://warhorse.youtrack.cloud/articles/KM-A-57>

---

## 5. Load order

Without `mod_order.txt`:

1. Steam Workshop subscriptions, in the order the Steam API returns them.
2. `Mods/` folder, alphabetically. The log says `[Mod] Loading mods in alphabetical order`.

With `Mods/mod_order.txt`: one **modid** per line, loaded in that order. **Any mod not listed is not loaded at all, Workshop mods included.**

Load order decides:

- **Overrides:** when two mods ship the same file path, the mod loaded **last** wins.
- **Table patches:** applied in load order, so a later mod's patch of the same row lands on top.

Official: <https://warhorse.youtrack.cloud/articles/KM-A-56>

---

## 6. Building the pak

Rules:

- Zip format, **Store** (zero compression).
- The archive root holds the contents of your `Data` mirror (`Libs/`, `Scripts/`, ...), **not** a wrapping folder.
- The extension is `.pak`.

**By hand:** open your source folder, select `Libs`, `Scripts` etc. → 7-Zip → Add to archive → Archive format `zip`, Compression level `Store` → name it `<modid>.pak`.

**Command line** (repeatable, and worth it once you're repacking every few minutes):

```bat
"C:\Program Files\7-Zip\7z.exe" a -tzip -mx0 "C:\...\KingdomComeDeliverance2\Mods\pack_mule\Data\pack_mule.pak" "C:\modding\pack_mule_src\*"
```

`-tzip` forces zip despite the `.pak` extension, `-mx0` means Store, and the trailing `\*` keeps the source folder itself out of the archive. Delete the old pak first. `7z a` adds to an existing archive rather than replacing it.

**The classic silent failure:** zipping the source folder itself gives paths like `pack_mule_src/Libs/Tables/...`. The mod still shows as loaded in the log, but nothing in it matches a game path, so nothing changes. Open your pak in 7-Zip and check that the top level is `Libs`/`Scripts`.

---

## 7. Table patches (`__modid`)

Tables in `Libs/Tables/` can be split into **parts** named `<table>__<part>.xml`. Warhorse ships many (`buff__dlc.xml`, `buff__alchemy.xml`, `item__horse.xml`). A part whose `<part>` is **your modid** is a **table patch**:

| | Regular part (`buff__dlc.xml`) | Patch (`buff__pack_mule.xml`) |
|---|---|---|
| Loaded | With the table, any order | After all parts, in mod load order |
| May reuse existing primary keys | No, new rows only | **Yes**: the vanilla row is replaced or changed |

Place the patch at the same relative path as the vanilla table: `Libs/Tables/rpg/rpg_param__pack_mule.xml` patches `Libs/Tables/rpg/rpg_param.xml`.

What a patched row must contain depends on the table generation:

- **Old tables** (flat KCD1-style rows): the patch row must contain the **entire row**, every attribute, including ones you don't change. Copy the vanilla row and edit it.
- **New tables** (KCD2 structured tables, e.g. `item`): the primary key plus only the properties you change. Everything else comes from vanilla, or from an earlier mod.
- **List properties** (e.g. in `CharacterComponent`): patched per item. The original list is kept and new entries are appended.
- Some tables can't be patched at all. For those, overriding the whole file is the only option, and it will conflict with other mods.

When in doubt, copy the full vanilla row. That works for both generations.

Many tables have a `.tbl` file next to the `.xml`. Patch the `.xml`.

**Episode example** (`Libs/Tables/rpg/rpg_param__pack_mule.xml`):

```xml
<?xml version="1.0" encoding="us-ascii"?>
<database xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="barbora" xsi:noNamespaceSchemaLocation="../database.xsd">
  <rpg_params version="1">
    <rpg_param rpg_param_key="BaseInventoryCapacity" rpg_param_value="9999" />
  </rpg_params>
</database>
```

`rpg_param.xml` has 322 entries. The official list with descriptions is at <https://warhorse.youtrack.cloud/articles/KM-A-20>. RPG params can also be read and set from Lua (`RPG.BaseInventoryCapacity`), and `RPG.Help('Inventory')` lists the matching params.

Official: <https://warhorse.youtrack.cloud/articles/KM-A-12>, <https://warhorse.youtrack.cloud/articles/KM-A-84>

---

## 8. Overrides

Any file in your pak at the exact path of a vanilla file replaces that file entirely. The last-loaded mod wins.

Examples from real mods:

- Fast Launch: `Videos/startup/startup_01/startup_01.bk2`, replaced with a 480-byte empty video, which skips the intro.
- No Helmet Vision: `Libs/UI/Textures/Overlays/Helmets/helmet_1..8.dds`, replaced to remove the visor overlay.

Use an override only when no patch format exists for that file. Every override is a potential conflict with every other mod that touches the same path.

---

## 9. Localization

Every visible string is a **string id** (e.g. an item's `UIName`) looked up in the active language.

```
Mods/pack_mule/Localization/
  English_xml.pak        contains text__pack_mule.xml
  German_xml.pak         same filename, translated
```

- Text paks are named `<Language>_xml.pak`. Voice-over paks are `<language>.pak`.
- Inside, name files `<anything>__<modid>.xml`. The game probes `text__<modid>.xml` by default. Files that don't follow the pattern still load, but at the wrong time, and they fill the log with "hash clash" errors.
- If a player's language is missing from your mod, the game falls back to English.

```xml
<Table>
  <Row><Cell>pack_mule_hello</Cell><Cell>Hello</Cell><Cell>Henry is now a pack mule.</Cell></Row>
</Table>
```

Cell 1 is the string id, cell 2 is ignored, and cell 3 is the text shown in game.

Language pak names: `Chineses_xml`, `Chineset_xml`, `Czech_xml`, `English_xml`, `French_xml`, `German_xml`, `Italian_xml`, `Japanese_xml`, `Korean_xml`, `Polish_xml`, `Portuguese_xml`, `Russian_xml`, `Spanish_xml`, `Turkish_xml`, `Ukrainian_xml`, `Vietnamese_xml`.

Official: <https://warhorse.youtrack.cloud/articles/KM-A-91>

---

## 10. Lua

The game runs **one** Lua file per mod automatically: `Scripts/Mods/<modid>.lua`, executed at startup right after `Scripts/main.lua`. A file with any other name never runs on its own.

```lua
pack_mule = {}

function pack_mule:OnGameplayStarted(actionName, eventName, argTable)
    System.LogAlways("[pack_mule] Henry is now a pack mule.")
end

UIAction.RegisterEventSystemListener(pack_mule, "", "OnGameplayStarted", "OnGameplayStarted")
```

- Code at the top level of the file runs at startup, before the main menu, when no level or player exists yet. Put gameplay setup in `OnGameplayStarted`, which fires every time a save finishes loading.
- More files: load them from the init script, e.g. `Script.LoadScript("Scripts/Mods/pack_mule_util.lua")`. Prefix them with your modid, because all mods share one `Scripts/Mods/` namespace.
- All mods share one Lua state. Keep everything inside one global table named after your mod.
- Wrap risky calls in `pcall`. One uncaught error aborts the rest of the function silently.
- `System.LogAlways(...)` writes to `kcd.log` and the console (`~`).

The log confirms the init script ran:

```
Loading lua init script for mod pack_mule...
Loading and executing script file 'scripts/mods/pack_mule.lua'...
```

Overriding a vanilla script (e.g. `Scripts/Entities/Doors/AnimDoor.lua`) follows the override rules in §8.

Official: <https://warhorse.youtrack.cloud/articles/KM-A-15>

---

## 11. Other special files

| File | Purpose |
|---|---|
| `Libs/Storm/storm__<modid>.xml` | Merged into the Storm root. It registers your own rule files by task (roles, equipment, contexts, appearance). See the example below. |
| `Quests/<modid>.xml` | A concept graph loaded for both maps alongside the main game graph. Covered in the quest episode. |
| `mod.cfg` (mod root, loose) | Console variables, one `name = value` per line, applied at startup. |

Storm root example (from the Mercenaries mod):

```xml
<?xml version="1.0"?>
<storm>
  <tasks>
    <task name="roles" class="roles">
      <source path="roles\mercenariesroles.xml" />
    </task>
    <task name="appearance" class="appearance">
      <source path="appearance\mercenariesappearance.xml" />
    </task>
  </tasks>
</storm>
```

`mod.cfg` example (official):

```
wh_horse_JumpHeight = 30.0
```

Official: <https://warhorse.youtrack.cloud/articles/KM-A-8>, <https://warhorse.youtrack.cloud/articles/KM-A-32>

---

## 12. Debugging

The game does not report most mod errors on screen. Read `<game>/kcd.log`, which is rewritten on every launch.

| Search for | Tells you |
|---|---|
| `[Mod]` | Every mod found, enabled or disabled, and why |
| `doesn't support game version` | Your `supports` list excluded the running version |
| `Opening paks in mods/<folder>/data/*.pak` | Your Data folder was found |
| `Loading localization patch` | Which localization files were picked up |
| `scripts/mods/<modid>.lua` | Your Lua init script ran |
| your modid, `[pack_mule]` | Your own `System.LogAlways` output |
| `error`, `Can't` | Parse errors, missing files |

Silent-failure checklist:

1. **Mod not in the log at all:** wrong folder. It must be `Mods/<folder>/mod.manifest`.
2. **Mod disabled:** check `supports`, or a `mod_order.txt` that doesn't list it.
3. **Mod loads, nothing changes:** check the paths inside the pak (§6) and the patch filename (`<table>__<modid>.xml`, exact modid, correct folder).
4. **Lua never runs:** the file isn't named exactly `Scripts/Mods/<modid>.lua`, or it has a syntax error. Search the log for the filename.
5. **Loose files:** they're ignored. Everything goes in a pak.

---

## 13. Episode files

Source folder:

```
pack_mule_src/
  Libs/Tables/rpg/rpg_param__pack_mule.xml
  Scripts/Mods/pack_mule.lua
```

Installed:

```
<game>/Mods/pack_mule/
  mod.manifest
  Data/pack_mule.pak      (Libs/..., Scripts/... at the archive root)
```

Test:

1. Launch and load a save.
2. Open the inventory. Carry capacity is in the thousands.
3. Press `~`. The console shows `[pack_mule] Henry is now a pack mule.`
