# Skald: Top-Level Quest Structure

I know my advice in [general/how-to-mod.md](../general/how-to-mod.md) may be something of an unpopular opinion, but it has contributed significantly to the retention of my sanity.

Skald is a good piece of software if you have access to internal Warhorse documentation. We do not. Skald itself only allows editing the base game database `barbora` (or `brambora` — I hereby curse the developer that named the two things so similarly for all eternity), and editing the base game database means overwriting vanilla files, which means incompatibilities between mods. Just don't do it and you'll be fine.

The recommended approach is to define a **global background quest** that runs silently at all times — no map markers, no journal entry. This quest acts as a hook: it loads whatever dialog you need for whatever NPC you need, and that dialog then triggers whatever functionality you're actually building. This is not a guide on making a full side quest (maybe later), but on how to make your mod present in the game alongside any other dialog or functionality you need.

---

## File Layout

Everything lives in `data/quests/`. The structure looks like this:

```
data/quests/
└── mercenaries.xml              ← top-level project file
└── mercenaries/
    ├── kutnohorsko.xml          ← level entry for Kutná Hora
    ├── trosecko.xml             ← level entry for Trosky
    └── kutnohorsko/
        └── mercenaries_background_quest.xml   ← the actual quest
```

---

## The Project File

`data/quests/mercenaries.xml` — the top-level entry point. Defines your mod's Skald project and declares which level files it contains:

```xml
<?xml version="1.0" encoding="utf-8"?>
<Database xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Name="brambora">
    <Skald>
        <Project Name="mercenaries">
            <Definitions>
                <Definition File="mercenaries/kutnohorsko.xml" />
                <Definition File="mercenaries/trosecko.xml" />
            </Definitions>
            <Nodes>
                <kutnohorsko Name="kutnohorsko" PositionY="-370" PositionX="720" />
                <trosecko    Name="trosecko"    PositionY="-390" PositionX="720" />
            </Nodes>
            <Text Text="mercenaries" />
            <ObjectiveValueTypes>
                <ObjectiveValueType Type="None"      IsPast="false" Icon="Exclamation" />
                <ObjectiveValueType Type="Started"   IsPast="false" Icon="Exclamation" Hint="objective_HintStarted" />
                <ObjectiveValueType Type="Updated"   IsPast="false" Icon="Exclamation" Hint="objective_HintUpdated" />
                <ObjectiveValueType Type="Completed" IsPast="true"  Icon="Check"       Hint="objective_HintCompleted" />
                <ObjectiveValueType Type="Canceled"  IsPast="true"  Icon="Check"       Hint="objective_HintCanceled" />
            </ObjectiveValueTypes>
        </Project>
    </Skald>
</Database>
```

- `Name` on `Project` — the project identifier; should match your mod name
- `Definition` entries — one per level your mod needs to be active in
- `Nodes` — positions the level nodes in the Skald editor graph; the values don't affect runtime behaviour
- `ObjectiveValueTypes` — boilerplate; copy it as-is

---

## Level Files

`data/quests/mercenaries/kutnohorsko.xml` — runs when the Kutná Hora level loads. It starts your background quest by wiring the level's `OnWake` signal to the quest's `run` port:

```xml
<?xml version="1.0" encoding="utf-8"?>
<Database xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Name="brambora">
    <Skald>
        <Level Name="kutnohorsko" HibernateMode="Auto" VoiceNamespace="false">
            <Definitions>
                <Definition File="kutnohorsko/mercenaries_background_quest.xml" />
            </Definitions>
            <Nodes>
                <mercenaries_background_quest Name="mercenaries_background_quest" RequiredForOutput="kutnohorsko">
                    <Edge From="OnWake" To="run" />
                </mercenaries_background_quest>
            </Nodes>
            <Text Text="kutnohorsko" />
        </Level>
    </Skald>
</Database>
```

- `Name` on `Level` — must match the game's internal level name exactly (`kutnohorsko`, `trosecko`, `klaster`, etc.)
- `HibernateMode="Auto"` — the game manages when the level sleeps; leave this alone
- `Definition` — imports the quest XML, same pattern as everywhere else in Skald
- `Edge From="OnWake" To="run"` — `OnWake` fires when the level loads; this immediately starts the background quest
- `RequiredForOutput` — ties the node's output to the level name; copy it as-is

Repeat this file for every level you want the mod active in. If you don't define a level file for a given map, your quest and its dialog won't exist there.

---

## The Background Quest

`data/quests/mercenaries/kutnohorsko/mercenaries_background_quest.xml` — the quest itself. It has a `run` input port (triggered by `OnWake` above), loads the dialog definitions it needs, and hooks dialog outputs to whatever functionality you want:

```xml
<?xml version="1.0" encoding="utf-8"?>
<Database xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Name="brambora">
    <Skald>
        <Quest Name="mercenaries_background_quest" Type="Activity" Players="0" Repeatable="true">
            <Ports>
                <Port Name="run" Direction="In" Type="trigger" />
            </Ports>
            <Definitions>
                <Definition File="mercenaries_background_quest/dismissal_dialog.xml" />
            </Definitions>

            <Nodes>
                <dismissal_dialog Name="dismissal_dialog" PositionY="150" PositionX="300" />

                <EventFunction Name="exec_clothes_1" PositionY="1500" PositionX="900"
                               MethodName="wh::entitymodule::CreatePlayerReward"
                               DeclaringType="wh::entitymodule">
                    <Constant Name="ItemClass"          Value="679a655e-189d-4519-b437-ccc4b92be47d" />
                    <Constant Name="Amount"             Value="1" />
                    <Constant Name="ShowUINotification" Value="false" />
                    <Edge From="dismissal_dialog.equip_generic_mercenaries" To="Exec" />
                </EventFunction>
            </Nodes>

            <Assets>
                <SoulAsset Name="player" SharedSoulGuids="4c2dcffb-dea1-6263-72d7-b39f4db2d8b5" />
            </Assets>
        </Quest>
    </Skald>
</Database>
```

Key attributes and patterns:

- `Type="Activity"` — marks this as a background activity rather than a tracked quest; it will not appear in the journal or on the map
- `Repeatable="true"` — the quest can restart if triggered again (e.g. on level reload)
- `Players="0"` — leave at 0; this is a single-player game
- `Port Name="run"` — the entry point wired to `OnWake` in the level file above
- `Definition` — imports a dialog XML; see [skald/add-dialog.md](add-dialog.md) for how to write dialog files
- `<dismissal_dialog Name="..." />` — instantiates the imported dialog as a node; it will be available to any NPC with the appropriate role
- `EventFunction` — how Skald talks to Lua; when a dialog output fires (`dismissal_dialog.equip_generic_mercenaries`), the `EventFunction` node executes a C++ method directly. See [general/lua-skald-communication.md](../general/lua-skald-communication.md) for the full picture
- `SoulAsset` — registers the player's soul GUID so the quest can interact with the player entity. The player GUID `4c2dcffb-dea1-6263-72d7-b39f4db2d8b5` is the same in every save

---

## Summary

The full chain is:

```
Level loads
  → OnWake fires
    → quest run port triggers
      → dialog nodes become active for NPCs with the right role
        → player picks a dialog option
          → dialog output fires a trigger
            → EventFunction / Function node runs
              → Lua code executes / item is given / whatever you need
```

That's the entire skeleton. Everything else — more complex quests, state machines, journal entries, objective tracking — builds on top of this pattern. For now, explore the vanilla quest files; they contain every pattern you will ever need.
