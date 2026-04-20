# Adding a New NPC to KCD2

If you are reading this and are serious about adding a custom NPC, you are in for a wild ride. This workflow took me about 10 hours to figure out and master, so enjoy every word.

---

## Overview

An NPC is entirely defined across two directories: `data/libs/Storm` and `data/libs/tables`. That covers all the core NPC data — who they are, what they look like, what they wear, how they behave socially, and what dialog they can speak. If you want a *completely* custom face or body model, that lives elsewhere and is not covered here. This guide only covers NPCs that use in-game bodies and equipment.

Here is the full list of files you will be touching, and what each one is responsible for:

| File | Purpose |
|---|---|
| `tables/rpg/soul.xml` | The soul — the NPC's core identity |
| `tables/rpg/faction__yourmod.xml` | Faction and relationship definitions |
| `tables/rpg/role__yourmod.xml` | Role definition (ties to dialog) |
| `tables/skald/skald_character__yourmod.xml` | Voice, display name, gender |
| `tables/skald/skald_character2profession__yourmod.xml` | Profession assignment |
| `tables/skald/skald_character2role__yourmod.xml` | Ties Skald character to role |
| `tables/item/clothing_preset__yourmod.xml` | What clothes the NPC wears |
| `tables/item/item__yourmod.xml` | Inventory preset (weapons, items) |
| `storm/storm__yourmod.xml` | Storm entry point |
| `storm/appearance/yourmod_appearance.xml` | Body, head, hair, beard assignment |
| `storm/equipment/yourmod_equipment.xml` | Ties inventory preset to soul |
| `storm/roles/yourmod_roles.xml` | Ties role to soul |

Work through these in order. Each one depends on the ones before it.

---

## The Soul

`data/libs/tables/rpg/soul.xml`

The soul is the heart of any NPC — everything else is built on top of it. The file already exists and contains every NPC soul in the game. Add your entry to it:

```xml
<soul
    brain_id="4b914d1c-724a-a92d-3e6b-d183d35b8b98"
    combat_level="0.5"
    digestion_multiplier="0"
    factionName="mercenariesFaction"
    initial_clothing_dirt="0"
    skald_character_name="char_mercenary_test"
    social_class_id="3"
    soul_archetype_id="0"
    soul_id="YOUR-UUID-HERE"
    soul_name="soul_merc_weak_1"
    soul_vip_class_id="16"
    xp_multiplier="0"
/>
```

### Attribute reference

**`brain_id`** — Ties the soul to an AI brain, which governs behavior, combat routines, schedules and everything else that makes an NPC actually function. `4b914d1c-724a-a92d-3e6b-d183d35b8b98` is a working in-game brain ID you can use for testing. The brain system is complex enough to warrant its own guide and will be covered separately.

**`soul_id`** — Must be globally unique. Generate one at [uuidgenerator.net/version4](https://www.uuidgenerator.net/version4). Write it down somewhere — you will reference this in multiple other files.

**`soul_name`** — References a localization string. If you don't define it in your localization file it will display as `@soul_merc_weak_1` in-game, which is fine for testing.

**`soul_archetype_id`** — Determines the fundamental body type. The relevant values are:

| ID | Type |
|---|---|
| `0` | Male human |
| `1` | Female human |
| `2` | Child |
| `3` | Horse |
| `8` | Dog |
| `13` | Hero (male) |
| `15` | Hero (female) |

Everything else is various animals. Male souls can only be assigned male body assets in Storm, and vice versa — mixing them will either produce nothing or cause a crash.

**`combat_level`** — A float between 0 and 1. This controls which combat techniques the NPC has access to: master strikes, combos, perfect blocks. 0.5 is a competent fighter. 1.0 is a nightmare.

**`digestion_multiplier`** — Set to `0` to make the NPC immune to starvation. Set to anything greater than `0` if you want to subject them to the horrors of hunger. For any mod NPC, just set this to `0`.

**`xp_multiplier`** — How much XP the player gets for interacting with (or killing) this NPC. `0` means no XP reward.

**`factionName`** — Controls who is hostile toward this NPC and who they are friendly with. Covered in the next section.

**`social_class_id`** — Determines how severely crimes against this NPC are punished. Higher values mean more serious crime penalties. `3` is a commoner.

**`skald_character_name`** — Links this soul to a Skald character definition for voice and dialog purposes. More on this below.

**`soul_vip_class_id`** — Governs what protections the NPC has from player interference:

| ID | Protection |
|---|---|
| `0` | None — fully lootable, attackable, pickpocketable |
| `1` | Pickpocket protection |
| `2` | Attack protection |
| `3` | Attack + steal protection |
| `4` | Immortality |
| `8` | Unconsciousness protection |
| `12` | Immortality + unconsciousness protection |
| `13` | Steal + unconsciousness + immortality |
| `15` | Steal + attack + immortality + unconsciousness |
| `16` | Loot protection only |
| `23` | Immortality + attack + pickpocket + loot protection |
| `31` | Untouchable — everything |

Use `16` if you don't want the player to loot the corpse. Use `0` if you don't care. Use `4` or higher if this is a quest-critical NPC.

**`initial_clothing_dirt`** — How dirty the NPC starts. `0` is clean.

---

## Factions

`data/libs/tables/rpg/faction__yourmod.xml`

A faction defines who your NPC is friends with and who they will fight. Create this as a new file:

```xml
<?xml version="1.0" encoding="utf-8"?>
<database xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          name="yourmod"
          xsi:noNamespaceSchemaLocation="FactionTree.xsd">
    <FactionTree version="1">
        <Faction Name="mercenariesFaction">
            <Relations>
                <Relation target="player"                                          reputation="1"  />
                <Relation target="players_friends"                                 reputation="1"  />
                <Relation target="kutnohorsko_allies"                              reputation="1"  />
                <Relation target="trosecko_allies"                                 reputation="1"  />
                <Relation target="players_enemies"                                 reputation="-1" />
                <Relation target="trosecko_enemies"                                reputation="-1" />
                <Relation target="kutnohorsko_enemies"                             reputation="-1" />
                <Relation target="kutnohorsko_enemies_oblehaniSuchdoleEnemyArmy"   reputation="-1" />
            </Relations>
        </Faction>
    </FactionTree>
</database>
```

`reputation` is a float, but `1` (friendly) and `-1` (hostile) cover all practical cases. The relations listed above are the complete set you need for an NPC that is allied with the player and hostile to bandits and enemy armies. Add or remove relations as needed for your use case.

The faction name must exactly match the `factionName` attribute in your soul definition.

---

## Roles

`data/libs/tables/rpg/role__yourmod.xml`

Roles are the mechanism that ties an NPC to dialog. A soul gets one or more roles assigned to it in Storm, and Skald dialog lines are tagged with a role — if an NPC has a matching role and the relevant quest is loaded, that NPC can speak those lines.

```xml
<?xml version="1.0" encoding="utf-8"?>
<database xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          name="yourmod"
          xsi:noNamespaceSchemaLocation="role.xsd">
    <Roles version="1">
        <role
            role_id="YOUR-UUID-HERE"
            metarole_name="NPC"
            role_name="role_mercenary_test"
        />
    </Roles>
</database>
```

There are three places a role is referenced:

1. **This file** — the definition itself
2. **Storm roles file** — ties the role to a specific soul
3. **Skald** — dialog lines are tagged with the role name; any soul with that role assigned can speak those lines when the quest is active

`metarole_name` can be `NPC` for standard NPCs. `role_name` is the identifier you will reference in the other two places — keep it memorable.

---

## Skald Character

`data/libs/tables/skald/skald_character__yourmod.xml`

This is the most important Skald file. It defines the voice, display name, and gender presentation of your NPC as Skald sees it. Create one character per soul, or share one character across multiple souls if you want them to share voice lines and names.

```xml
<?xml version="1.0" encoding="utf-8"?>
<database xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          name="yourmod"
          xsi:noNamespaceSchemaLocation="skald_character.xsd">
    <SkaldCharacters version="1">
        <skald_character
            age="2"
            body_type="4"
            description_string_name="char_mercenary_test_description"
            gender="0"
            image1="false"
            image2="false"
            image3="false"
            image4="false"
            mortality_id="0"
            owner="yourname"
            script_owner="yourname"
            skald_character_full_name_string_name="char_mercenary_test_fullName"
            skald_character_name="char_mercenary_test"
            ui_name_string_name="char_mercenary_test_uiName"
            unique_assets=""
            voice_categories="generic christian"
            voice_id="243"
        />
    </SkaldCharacters>
</database>
```

### Attribute reference

**`skald_character_name`** — The internal identifier. Must exactly match the `skald_character_name` in your soul definition. This is the link between the two.

**`ui_name_string_name`** — References a localization string that is displayed as the NPC's name when the player looks at them or interacts with them. This is the one your players will actually see. Define it in your localization file.

**`skald_character_full_name_string_name`** — Used in Skald dialog trees to refer to the character by full name.

**`description_string_name`** — Internal description used in Skald. Doesn't appear in-game.

**`gender`** — Controls which body and hair assets are available for this character in Skald's tooling:

| ID | Meaning |
|---|---|
| `0` | Not defined |
| `1` | Male |
| `2` | Female |
| `3` | Unisex |

Assigning `1` or `2` locks the character to that gender's assets. `0` is more permissive and fine for generic NPCs.

**`mortality_id`** — Whether the character is mortal. `0` is mortal (can die normally).

**`voice_id`** — Determines which voice actor's recorded lines this NPC uses. For a full list of valid IDs, check `libs/tables/skald/voice.xml` in the base game files.

**`voice_categories`** — Fallback voice categories used when your specific `voice_id` doesn't have a line for a given situation. `"generic christian"` is a safe default for male commoner NPCs.

**Voice lines and localization** — Custom voice lines are defined in your localization file with IDs that follow the pattern `rlaz_yourstringid`, where `rlaz` is the short name of the voice actor tied to your `voice_id`. If the prefix and voice ID don't match, the line will have no audio. Look up the actor abbreviation for your chosen voice ID in `voice.xml`.

### Supplementary Skald files

You also need two small linking files.

**`skald_character2profession__yourmod.xml`** — Ties the character to a profession, which affects which ambient dialog lines they speak:

```xml
<?xml version="1.0" encoding="utf-8"?>
<database xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="yourmod">
    <SkaldCharacter2Professions version="1">
        <skald_character2profession
            profession_name="pocestny"
            skald_character_name="char_mercenary_test"
        />
    </SkaldCharacter2Professions>
</database>
```

`pocestny` is a generic non-criminal profession that works for most honest NPCs. Use it as a default unless you need something more specific.

**`skald_character2role__yourmod.xml`** — Ties the Skald character to the role you defined earlier:

```xml
<?xml version="1.0" encoding="utf-8"?>
<database xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="yourmod">
    <SkaldCharacter2Roles version="1">
        <skald_character2role
            role_id="role_mercenary_test"
            skald_character_id="char_mercenary_test"
        />
    </SkaldCharacter2Roles>
</database>
```

---

## Clothing and Inventory

### Clothing preset

`data/libs/tables/item/clothing_preset__yourmod.xml`

A clothing preset defines the specific items an NPC wears. Each `<Guid>` references an item ID from the base game or your own item definitions.

```xml
<?xml version="1.0" encoding="utf-8"?>
<database xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="yourmod">
    <ItemClasses version="8">
        <clothing_preset
            clothing_preset_id="YOUR-UUID-HERE"
            clothing_preset_name="clothing_preset_mercenary_test"
            gender="Male"
            prefers_hood_on="false"
            social_class_id="3"
            Quality="2"
            Condition="0.85">
            <Items>
                <!-- Gambeson -->
                <Guid>d03ab313-df4c-4073-a58b-7e6ebe615072</Guid>
                <!-- Chainmail hauberk -->
                <Guid>071caaed-731e-418b-93e8-551abc68409e</Guid>
                <!-- Chausses -->
                <Guid>abb3e8b3-8c25-47f1-8e44-9b4b61380bef</Guid>
                <!-- Boots -->
                <Guid>ffd9af7c-d24d-4e70-8c25-ad22a37a64e7</Guid>
                <!-- Belt -->
                <Guid>c69361d6-84d5-4c74-a399-97890561087f</Guid>
            </Items>
        </clothing_preset>
    </ItemClasses>
</database>
```

Comment every GUID — you will absolutely forget what each one is. If two items occupy the same equipment slot, the game tends to equip neither of them rather than picking one. Avoid conflicts between items in the same category.

`Condition` is a float from 0 to 1. `Quality` affects item stats.

### Inventory preset

`data/libs/tables/item/item__yourmod.xml` (or a dedicated inventory file)

The inventory preset ties the clothing preset to a full inventory setup including weapons and carried items:

```xml
<InventoryPreset Name="inventory_mercenary_test">
    <!-- Reference the clothing preset defined above -->
    <ClothingPresetRef Name="clothing_preset_mercenary_test"/>

    <!-- Weapons -->
    <WeaponPresetRef Name="longsword_3_01"/>

    <!-- Optional: carried items -->
    <PresetItem Name="apple"                Amount="1" Health="1" HealthVariation="0.3"/>
    <PresetItem Name="repairKit_weaponSmall" Amount="1"/>

    <!-- Optional: shared pocket inventory reference -->
    <InventoryPresetRef Name="pockets_soldiers_all"/>
</InventoryPreset>
```

You can reference vanilla weapon and inventory presets directly instead of defining your own — check the base game files for available preset names.

---

## Storm

Storm is the rule engine that connects all the pieces above. It looks at an NPC's soul name and applies the correct appearance, equipment and roles based on rules you define. Think of it as a big pattern-matching system: "if soul name matches X, give it Y."

### Entry point

`data/libs/storm/storm__yourmod.xml`

This file tells Storm where to find your rules:

```xml
<?xml version="1.0"?>
<storm>
    <tasks>
        <task name="roles"      class="roles">
            <source path="roles\mercenariesroles.xml" />
        </task>
        <task name="equipment"  class="equipment">
            <source path="equipment\mercenariesequipment.xml" />
        </task>
        <task name="appearance" class="appearance">
            <source path="appearance\mercenariesappearance.xml" />
        </task>
    </tasks>
</storm>
```

### Appearance

`data/libs/storm/appearance/mercenariesappearance.xml`

Assigns body, head, hair, beard and underwear to the soul. Only the soul name is needed as a selector.

```xml
<?xml version="1.0"?>
<!DOCTYPE storm SYSTEM "..\storm.dtd">
<storm>
    <rules>
        <rule name="appearance_mercenary_test">
            <selectors>
                <hasName Name="soul_mercenary_test" />
            </selectors>
            <operations>
                <setBody      name="m_body_tan_04"       />
                <setHead      name="m_head_081"           />
                <setHair      name="m_hair_014_dark_grey" />
                <setBeard     name="m_beard_00"           />
                <setUnderwear name="m_underwear03_m05"    />
            </operations>
        </rule>
    </rules>
</storm>
```

You cannot assign a male body to a female soul or vice versa. For more body, head, hair and beard options, browse the vanilla Storm appearance files or just change the numbers and see what appears in-game — surprisingly effective.

### Equipment

`data/libs/storm/equipment/mercenariesequipment.xml`

Ties the inventory preset to the soul. You can reference vanilla presets here if you don't need a custom one.

```xml
<?xml version="1.0"?>
<!DOCTYPE storm SYSTEM "..\storm.dtd">
<storm>
    <rules>
        <rule name="inventory_mercenary_test" Mode="and">
            <selectors>
                <hasName name="soul_mercenary_test" />
            </selectors>
            <operations>
                <setInventory preset="inventory_mercenary_test" />
            </operations>
        </rule>
    </rules>
</storm>
```

### Roles

`data/libs/storm/roles/mercenariesroles.xml`

Assigns the role to the soul. A soul can have multiple `addRole` operations — just stack them.

```xml
<?xml version="1.0"?>
<!DOCTYPE storm SYSTEM "../../storm.dtd">
<storm>
    <rules>
        <rule name="soul_mercenary_test">
            <selectors>
                <hasName name="soul_mercenary_test" />
            </selectors>
            <operations>
                <addRole name="role_mercenary_test" />
            </operations>
        </rule>
    </rules>
</storm>
```

You can also add roles to existing vanilla souls from here — your Storm rules are merged with the base game's at load time.

---

## You're Done. Sort Of.

If you followed every step correctly, you have a fully defined NPC. They have an identity, a faction, a voice, a face, clothes, weapons and dialog hooks.

What you don't have yet is a way to see them in the world — that requires spawning, which will be covered in a separate guide. You also haven't given them a proper brain, which is the most complex part of the whole process and also gets its own guide.

But the hard part is done. Everything you just defined will survive a game load, will work with the quest system, and will behave correctly with the crime and relationship systems. The rest is just putting them in the world and telling them what to do when they get there.
