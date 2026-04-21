# Adding a New NPC to KCD2

If you are reading this and are serious about adding a custom NPC, you are in for a wild ride. This basic workflow took me about 10 hours to figure out and master, so enjoy every word of this guide. You're welcome.

---

## Overview

An NPC is entirely defined across two directories: `data/libs/Storm` and `data/libs/tables`. That covers everything — who they are, what they look like, what they wear, how they behave socially, and what dialog they can speak. If you want a completely custom face or body model, that lives elsewhere and is not my area of expertise. This guide only covers NPCs that use in-game bodies and equipment, which is probably what you want anyway.

Here is a map of everything you will be touching. Keep it open in another tab.

| File | Purpose |
|---|---|
| `tables/rpg/soul__yourmod.xml` | The soul — the NPC's core identity |
| `tables/rpg/FactionTree__yourmod.xml` | Who likes them and who wants to kill them |
| `tables/rpg/role__yourmod.xml` | Role definition — ties to dialog |
| `tables/skald/skald_character__yourmod.xml` | Voice, display name, gender |
| `tables/skald/skald_character2profession__yourmod.xml` | Profession assignment |
| `tables/skald/skald_character2role__yourmod.xml` | Ties Skald character to role |
| `tables/item/clothing_preset__yourmod.xml` | What clothes the NPC wears |
| `tables/item/item__yourmod.xml` | Inventory preset — weapons, carried items |
| `storm/storm__yourmod.xml` | Storm entry point |
| `storm/appearance/yourmod_appearance.xml` | Body, head, hair, beard |
| `storm/equipment/yourmod_equipment.xml` | Ties inventory preset to soul |
| `storm/roles/yourmod_roles.xml` | Ties role to soul |

Work through these in order. Each one depends on the ones before it.

---

## The Soul

`data/libs/tables/rpg/soul.xml`

In `data/libs/tables/rpg` there lives a cute little file called `soul.xml`. It contains all the souls of the little NPCs that walk around the game. We as modders have full control over them — you can change everything about them, destroy souls, add souls. I am a benevolent god, so I'll add one.

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

**`soul_id`** — Must be globally unique. Generate one at [uuidgenerator.net/version4](https://www.uuidgenerator.net/version4). Write it down somewhere — you will reference it in multiple other files and you will regret not writing it down.

**`soul_name`** — Internal soul name, mostly used for Storm rules.

**`brain_id`** — Ties the soul to an AI brain, which governs behavior, combat, schedules, and everything else that makes an NPC actually function rather than stand there like a confused statue. `4b914d1c-724a-a92d-3e6b-d183d35b8b98` is a working in-game brain ID you can borrow for testing. The brain system is complex enough to warrant its own guide, which will come separately.

**`soul_archetype_id`** — The fundamental body type. You cannot mix these with the wrong appearance assets later without the game producing something deeply unsettling.

| ID | Type |
|---|---|
| `0` | Male human |
| `1` | Female human |
| `2` | Child |
| `3` | Horse |
| `8` | Dog |
| `13` | Hero (male) |
| `15` | Hero (female) |

Everything else is various animals. There are a lot of animals in this game apparently.

**`combat_level`** — A float between 0 and 1. Controls which combat techniques the NPC has access to: master strikes, combos, perfect blocks. `0.5` is a competent fighter. `1.0` is your problem now.

**`digestion_multiplier`** — Set to `0` to make the NPC immune to starvation. Set to anything greater than `0` if you want to subject them to the full horror of the hunger system. For any mod NPC, just set this to `0`. Nobody asked for realism here.

**`xp_multiplier`** — How much XP the player gets from killing this NPC. `0` means no reward, which is probably fine unless you specifically want the player farming your lads for levels.

**`factionName`** — Controls who is hostile toward this NPC and who they're friendly with. Covered next.

**`social_class_id`** — How severely crimes against this NPC are punished. Higher is more serious.

**`skald_character_name`** — Links this soul to its Skald character definition. More on this below.

**`initial_clothing_dirt`** — How dirty they spawn. `0` is clean.

**`soul_vip_class_id`** — What protections the NPC has from the player's more criminal instincts:

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

Use `16` if you don't want the player looting their corpse. Use `0` if you don't care. Use `4` or higher if this NPC dying would break your quest. Use `31` if you are truly paranoid.

---

## Factions

`data/libs/tables/rpg/FactionTree__yourmod.xml`

A faction defines who your NPC is friends with and who they will fight. The following entry covers the complete set of relations you need for an NPC allied with the player and hostile to bandits and enemy armies:

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

`reputation` is a float, but `1` and `-1` are all you need. The faction name must exactly match the `factionName` in your soul.

---

## Roles

`data/libs/tables/rpg/role__yourmod.xml`

Roles are how an NPC gets dialog. There are three references of roles across the whole mod:

1. **This file** — the definition itself
2. **Storm roles file** — ties the role to a specific soul
3. **Skald** — dialog lines are tagged with a role name; any soul with that role will speak those lines when the quest is active

All three need to exist. Don't skip any of them.

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

`metarole_name` can be `NPC` for standard NPCs. Pick a `role_name` you'll actually remember.

---

## Skald Character

`data/libs/tables/skald/skald_character__yourmod.xml`

This is the most important Skald file. It defines the voice, display name, and gender of your NPC. Create one character per soul, or share one character across multiple souls if you want them to share voices and names (and don't mind them being philosophically the same person).

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

**`age`** and **`body_type`** — No idea honestly. The values above work, so I left them in.

**`skald_character_name`** — The internal identifier. Must exactly match the `skald_character_name` in your soul. This is the actual link between the two systems.

**`ui_name_string_name`** — References a localization string displayed as the NPC's name when the player looks at them. This is the name your players will actually see. Define it in your localization file or it will show as `@char_mercenary_test_uiName`, which is a great name for a medieval soldier.

**`description_string_name`** and **`skald_character_full_name_string_name`** — Used internally in Skald. Don't stress about these too much.

**`gender`** — Locks which body and hair assets are available for this character in Skald's tooling:

| ID | Meaning |
|---|---|
| `0` | Not defined |
| `1` | Male |
| `2` | Female |
| `3` | Unisex |

Assigning male or female locks you to that gender's assets everywhere.

**`mortality_id`** — `0` is mortal. They can die. Usually fine.

**`voice_id`** — Which voice actor's lines this NPC uses. For a full list, see `libs/tables/skald/voice.xml` in the base game files.

**`voice_categories`** — Fallback categories used when your `voice_id` doesn't have a line for a given situation. `"generic christian"` is a safe default for a standard NPC.

**A note on custom voice lines** — They are defined in your localization file with IDs following the pattern `rlaz_yourstringid`, where `rlaz` is the abbreviated name of the voice actor tied to your `voice_id` 243. If the prefix and the voice ID don't match, the line will play silently. Check `voice.xml` for the correct abbreviation for your chosen ID.

### Two small files you also need

**`skald_character2profession__yourmod.xml`** — Ties the character to a profession:

```xml
<skald_character2profession
    profession_name="pocestny"
    skald_character_name="char_mercenary_test"
/>
```

`pocestny` is a generic non-criminal profession. It just means honest person, basically. Safe default for most NPCs.

**`skald_character2role__yourmod.xml`** — Ties the Skald character to the role you defined earlier, I actually don't know if this has gameplay impacts, but best to leave it in:

```xml
<skald_character2role
    role_id="role_mercenary_test"
    skald_character_id="char_mercenary_test"
/>
```

---

## Clothing and Inventory

### Clothing preset

`data/libs/tables/item/clothing_preset__yourmod.xml`

A clothing preset is the list of specific items an NPC wears. Each `<Guid>` references an item from the base game or your own item definitions.

```xml
<clothing_preset
    clothing_preset_id="YOUR-UUID-HERE"
    clothing_preset_name="clothing_preset_mercenary_test"
    gender="Male"
    prefers_hood_on="false"
    social_class_id="3"
    Quality="2"
    Condition="0.85">
    <Items>
        <Guid>d03ab313-df4c-4073-a58b-7e6ebe615072</Guid>
        <Guid>071caaed-731e-418b-93e8-551abc68409e</Guid>
        <Guid>abb3e8b3-8c25-47f1-8e44-9b4b61380bef</Guid>
        <Guid>ffd9af7c-d24d-4e70-8c25-ad22a37a64e7</Guid>
        <Guid>c69361d6-84d5-4c74-a399-97890561087f</Guid>
    </Items>
</clothing_preset>
```

Comment every GUID. As you can see I neglected to do that in the actual example, and I have suffered for it. If two items occupy the same equipment slot, the game tends to equip neither rather than picking one — so your NPC will be partially naked and you will have no idea why. You can make an NPC wear a chestplate without padding. Nobody asks the NPC how comfortable that is.

`Condition` is a float from 0 to 1. `Quality` affects item stats.

### Inventory preset

```xml
<InventoryPreset Name="inventory_mercenary_test">
    <ClothingPresetRef Name="clothing_preset_mercenary_test"/>
    <WeaponPresetRef Name="longsword_3_01"/>

    <!-- Optional carried items -->
    <PresetItem Name="apple"                 Amount="1" Health="1" HealthVariation="0.3"/>
    <PresetItem Name="repairKit_weaponSmall"  Amount="1"/>

    <!-- Optional shared pocket inventory -->
    <InventoryPresetRef Name="pockets_soldiers_all"/>
</InventoryPreset>
```

You can reference vanilla weapon and inventory presets directly. No need to reinvent the sword.

---

## Storm

Stormy waters are approaching, as this is the most fun part. Storm is a rule engine that connects everything you've defined so far. It looks at an NPC's soul name and applies the correct appearance, equipment and roles based on rules you write. Think of it as a big pattern-matching system: if soul name matches X, do Y. Simple in principle, three separate files in practice.

### Entry point

`data/libs/storm/storm__yourmod.xml`

This tells Storm where your rule files live:

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

Only needs the soul name as a selector. Give it a body, head, hair and beard and you're done.

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

You cannot assign a male body to a female soul or vice versa. For more bodies, heads, hairs and beards, browse the vanilla Storm appearance files or just randomly change the numbers and see what appears in-game — surprisingly effective.

### Equipment

`data/libs/storm/equipment/mercenariesequipment.xml`

Ties the inventory preset to the soul. You can reference vanilla presets here if your needs are simple.

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

Assigns the role to the soul. A soul can have any number of `addRole` operations stacked on it. You can also assign roles to existing vanilla souls from here if you want your dialog attached to NPCs that already walk around the world.

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

---

## Finally

This guide has been a doozy. If you followed all these steps correctly, you should have your own NPC! But you won't see them yet, because you still need to spawn them — that's covered in a separate guide. And you'll need to give them a proper brain, which is also in another guide, because the brain system alone is enough to break a person.

But the foundation is done. Everything you've just defined will survive a game load, play nicely with the quest and crime systems, and respond correctly to factions and relationships. Go touch some grass and come back for the spawning guide.
