---
title: Skald quests and dialogue
summary: How KCD2's Skald concept graph works for a mod - file layout, quests, objectives and map markers, assets, every dialogue flavour (fader, forced, chat menus, monologs), the Lua-Skald bridge, and the node-level traps that silently kill a mod's whole quest graph.
tags: [skald, lua, ui]
kind: reference
status: current
scope: kcd2
verified: release_1_5
---

# Skald quests and dialogue

## TL;DR

- Skald (a.k.a. the concept graph; the database is `barbora`, mod files say `brambora`) scripts quests, dialogue and reactions. A mod ships its own graph rooted at `Quests/<modid>.xml`, loaded for both maps next to vanilla's (official wiki KM-A-3, KM-A-30). Editing vanilla quest files is a whole-file override with **no merging**.
- Nodes: **Definition** (container), **State** (saved), **Effect** (active only while a bool State drives its `IsActive`). Triggers run synchronously (official wiki [KM-A-30](https://warhorse.youtrack.cloud/articles/KM-A-30)).
- **One bad node kills the whole mod graph** (every dialogue, bark and context), and retail logs nothing. Develop Skald in the dev build, whose `kcd.log` names the failing node. Top killers: a `Namespace=` attribute, `QuestVisual`, an unwired required `IsActive` port ([Graph-killers](#graph-killers)).
- There is **no working Lua → Skald or Skald → Lua call** in retail. Bridge through the player's inventory: Skald grants a token item, Lua polls and deletes it; Lua adds a token, an `ItemDescriptorTrigger` fires ([Lua-Skald bridge](#lua-skald-bridge)).
- A Skald dialogue module **describes** a conversation; it cannot **start** one. Player-initiated dialogues need the NPC's behaviour tree to handle `dialogMailbox`; NPC-initiated ones are started from a BT with `Function_speech_dialogInitiator` ([Forced dialogue](#forced-dialogue-npc-starts-it)).
- Anything that needs a level-placed entity (tag points, trigger areas, cutscene holders, battle groups) is out of reach; `SoulAsset` is the one asset type a mod fully controls.

Public step-by-step guides: [top-level quest](../skald/add-top-level-quest.md), [adding dialogue](../skald/add-dialog.md), [Lua-Skald tokens](../general/lua-skald-communication.md), [BT talking](../behaviour-trees/talking.md). Official: [KM-A-18 Skald](https://warhorse.youtrack.cloud/articles/KM-A-18), [KM-A-31 Tourist mode](https://warhorse.youtrack.cloud/articles/KM-A-31).

## Files and layout

```
Quests/<modid>.xml                       Project: one <Definition> per level file, <Nodes> instancing them
Quests/<modid>/kutnohorsko.xml           <Level Name="kutnohorsko">: OnWake -> your quest's run port
Quests/<modid>/trosecko.xml              <Level Name="trosecko">
Quests/<modid>/kutnohorsko/<quest>.xml   the quest(s) and their dialogue definitions
```

- Root element: `<Database Name="brambora"><Skald><Project Name="<modid>">...`. The Project also carries the `ObjectiveValueTypes` block (`None/Started/Updated/Completed/Canceled`) that any quest with journal objectives needs; copy it verbatim ([add-top-level-quest.md](../skald/add-top-level-quest.md)).
- `Level Name` must be the engine's level name exactly: `kutnohorsko`, `trosecko`, `klaster`. No level file = your quest and its dialogue do not exist on that map ([add-top-level-quest.md](../skald/add-top-level-quest.md)). Levels are separate; mirror every file for each map you support (regions.md).
- `<Edge From="OnWake" To="run"/>` on the level's quest instance starts it at level load.
- Vanilla root: `Quests/Final/Barbora.xml`, content under `Quests/Final/Barbora/...` (21,000+ files in `Scripts.pak`). The Skald editor's "Mod base game" mode writes changed vanilla files to `mods/<modid>/data/Quests/final/Barbora/...`: an override, last mod wins (official wiki KM-A-18, KM-A-30).
- Skald's "New mod project" writes `mods/<modid>/data/Quests/<modid>.xml` (official wiki KM-A-18). It needs the Modding Tools install (Skald opens the game paks and `Developer.pak`) and .NET Framework 4.8 (official wiki KM-A-55).
- **Node catalogue:** `Libs/concept/definitions.xml`, 1,088 node definitions grouped by `Category="wh::<module>"` with every port, type and `IsOptional` flag. This is the reference for what a node accepts; `Libs/Tables/skald/` is only casting and voice data (ui.md; retail data).
- Many authors hand-write the XML from vanilla examples rather than use the editor ([how-to-mod.md](../general/how-to-mod.md), [add-dialog.md](../skald/add-dialog.md)). Hand-authored nodes of some types load cleanly and do nothing while data edits to existing nodes work; the suspected cause is build-time state the editor bakes (merc-battle-rendering.md, symptom verified in game, cause unverified).

## Concepts

| Thing | What it is | Source |
|---|---|---|
| State node | persistent (saved) value: `<State Name=".." TypeT="bool"><Constant Name="DefaultValue" Value="true"/></State>` | official wiki KM-A-30 |
| Effect node | changes the world only while its `IsActive` bool is true; no On/Off triggers. Output data ports are valid **only on the tick the node's output trigger fires** | official wiki KM-A-30 |
| Trigger / data ports | triggers are signals; data ports are typed (`bool`, `int`, `string`, `wh::...*`) | official wiki KM-A-30 |
| Asset | a named placeholder resolved at runtime when the node activates: `<SoulAsset Name="x" SharedSoulGuids="<guid> <guid>"/>`, tag points, areas, smart objects | official wiki KM-A-30 |
| Objective | smallest quest unit, shown in the journal; a State plus a visualising node inside the `Quest` definition | official wiki KM-A-30 |
| `Definition File=..` vs instance | a `<Definition File>` only imports a module **type**; a separate element in `<Nodes>` named after the module's internal `Name` places an instance in the running graph | aleksej.md, verified in game |

Asset resolution rules:

- `<Asset Alias=..>` resolves **lexically up the `Definition` include chain**, and a nearer scope can re-declare the same alias. Tools must key on (file, alias), never alias alone (malesov-structure.md).
- Level entities are bound to quest assets by an entity link `asset['<name>']` on a `SmartObjectHolder` named exactly after the owning `Quest` (the "QSO"); assets have no GUID. QSOs are level-baked and resolve at `OnWake`, before any Lua runs, so a mod cannot create one (cutscenes.md, retail binary). Lua can re-point an existing QSO's link with [Entity.CreateLink](api/Entity.md#createlink).
- A `SoulAsset` resolves to **any** NPC carrying a matching soul, including one Lua spawned with `properties.guidSharedSoulId` (bandit-camp-quest.md, verified in game).
- There is no runtime soul discovery in Skald: `MakeArray<Souls>` / `JoinArrays` take fixed `Asset` children only (malesov-structure.md).
- The player soul GUID for a `SoulAsset` is `4c2dcffb-dea1-6263-72d7-b39f4db2d8b5` ([data-tables.md](data-tables.md#guid-conventions)).

## Quests, objectives and map markers

`<Quest Name=".." Type="Side" Players="0" Repeatable="true">`:

- `Type`: vanilla census `Activity` 67, `Side` 66, `Micro` 56, `Event` 2, `Main` 2, `Racing` 1; **no `Type` attribute** marks a main-story quest (quest-override-battles.md). A silent always-on hook quest is typically `Activity` + `Repeatable="true"` + `Players="0"` ([add-top-level-quest.md](../skald/add-top-level-quest.md)).
- Journal entries come from objective logs: `<EnumLog Type="Started" Marker="<assetName>"/>`. Add `IsTracked="true"` to a marker log: an untracked quest shows no map marker, and a reload can change which quest is tracked (vanilla: 221 `EnumLog`s carry it, 134 of them `Started`; aleksej.md). `Progress` is a built-in objective type with states `None/Active/Done` (2,150 vanilla uses, never declared) (bandit-camp-quest.md).
- `MakeTracker(Current, Total)` is the only numeric widget Skald has: an x/y counter on an objective (ui.md).
- `QuestVisual` is test-only and kills the mod graph (see [Graph-killers](#graph-killers)).

Map markers:

- An objective marker (`EnumLog Marker=`) may point at a `SoulAsset`, `TagPointAsset` or `TriggerAreaAsset`. Only `SoulAsset` is usable by a mod (bandit-camp-quest.md, verified in game).
- The marker binds to whichever NPC carries the soul **at the moment the `Started` log fires**. It does not re-bind when you respawn that soul later, and after a save/load the objective is restored as already active, so `Started` never fires again. Working fix: let the engine save the NPC (default), remember its entity name, and adopt that entity at level wake instead of respawning. Give a marked NPC its own soul; a shared soul makes the marker ambiguous (aleksej.md, bandit-camp-quest.md, verified in game).
- Make sure the marked NPC exists before the player needs the marker (spawn at quest start, not when the player arrives) (bandit-camp-quest.md).
- The compass resolves an objective target live; the world map's marker registry is only repopulated by a fresh `Started` transition (aleksej.md).
- `ShowMapMarker` has a closed `MarkerType` enum (`QuestGiver`, `PoiTipster`, `ActivityGiver`, `FightArena`, `Dog`, `Barber`, ...) with no generic objective icon; its `IsActive` must be a bool (bandit-camp-quest.md). **Conflict:** whether its icon ever renders on a Lua-spawned NPC is unresolved - bandit-camp-quest.md ships a `QuestGiver` marker on one, but a play-test saw no icon on him (aleksej.md, [ui-scaleform.md](ui-scaleform.md#map-poi-markers-apsemap)) `(unverified)`. Custom world-map POIs from Lua: map-marker.md and [ui-scaleform.md](ui-scaleform.md).

## Dialogue

Dialogue module kinds in vanilla quests: `<Dialog>` 6,372, `<FaderDialog>` 2,761, `<ForcedDialog>` 891 (census of `Quests/`; for `ForcedDialog` that is 891 definition files - 810 under `Quests/Final`, 81 under `Quests/Testing` - with 855 distinct module names, 842 of them instanced by 1,445 instance nodes. The "560 uses" in an older note is not reproducible). Each wraps one `<Dialogue>`; `Dialogue Type` values: `ingame monolog` 4,616, `ingame` 1,161, `chat` 480, plus rare `monolog`, `greeting`, `denial`.

Skeleton (full example: [add-dialog.md](../skald/add-dialog.md)):

```xml
<FaderDialog Name="my_dialog">
  <Ports>
    <Port Name="hired" Direction="Out" Type="trigger" />
    <Port Name="gold"  Direction="In"  Type="int" />
  </Ports>
  <Text StringName="ui_my_dialog_title" />
  <Dialogue TechnicalStatus="Enabled" AllowFarewell="false" AllowGreeting="false">
    <Decision Name="dec_root" Priority="General">
      <Sequences>
        <Sequence Name="seq_hire" EndType="Decision" EntryCondition="Port('gold') &gt;= 50">
          <UiPrompt StringName="ui_hire" />
          <Elements>
            <Response Role="HENRY"><Text StringName="my_henry_hire" /></Response>
            <Response Role="role_my_npc" ReferenceLength="3"><Text StringName="my_npc_hire" /></Response>
          </Elements>
          <Triggers><Port Name="hired" /></Triggers>
          <Decision Name="dec_next"> ... </Decision>
        </Sequence>
      </Sequences>
    </Decision>
  </Dialogue>
</FaderDialog>
```

| Element / attribute | Rule | Source |
|---|---|---|
| `Sequence` | one menu option; `UiPrompt` is its label | [add-dialog.md](../skald/add-dialog.md) |
| `EndType` | `EndDialogue` closes (33,146 vanilla uses); **`Decision` is required on every sequence that nests a `<Decision>`**, at every level (28,420); `GoTo` + `GoToDecision` jumps back (23,193); `EndTopic` rare | old context doc (verified in game); vanilla census |
| `Decision Autoselect="true"` | hides the menu and picks the first sequence whose `EntryCondition` passes: hidden conditional branching. Do not fake it with empty responses (localization errors) | old context doc |
| `EntryCondition` | expression over In-ports, e.g. `Port('riddles_solved') == 0`; XML-escape `<`/`>` | [add-dialog.md](../skald/add-dialog.md) |
| `Ports` | `Direction="Out" Type="trigger"` fires when the sequence ends (fed by `<Triggers><Port Name=".."/></Triggers>`); `Direction="In"` feeds conditions | [add-dialog.md](../skald/add-dialog.md) |
| `Response Role` | must match a role the NPC has via Storm `addRole`, a `role.xml` row, and the dialogue itself; a sequence missing a response for a required role never appears | [add-new-npc.md](../xml/add-new-npc.md), [add-dialog.md](../skald/add-dialog.md) |
| `Response ReferenceLength` | seconds, `ceil()` of the audio length; drives subtitle and turn timing | voice-mastering.md |
| `Commands` | `CameraCommand`, `FacialMoodCommand`, `AnimationCommand` (`FragmentId`, `Guid`, `Variant`, `Delay`) | [add-dialog.md](../skald/add-dialog.md) |
| `SelectedSouls` + `VoiceoverFallbackLevel` | needed when a role has no recorded voice-over, or the request stalls until timeout; see [audio-voice-lipsync.md](audio-voice-lipsync.md#voices-which-one-plays-and-fallbacks) | mod: `aleksej_dialog.xml` (verified in game) |

Snapshotting a value when the dialogue opens: fire an Out trigger from the entry sequence into a Function node that reads the value (e.g. an item count), and feed its output back into an In-port the later `EntryCondition`s read (old context doc). The context doc names `wh::inventorymodule::GetItemCount`; **no such node exists** in `definitions.xml` (there is no `wh::inventorymodule` category at all). The closest real node is `wh::entitymodule::ItemsAmount` (`Items` in, `Amount` out). Verify names against `definitions.xml` before wiring (retail data).

### Text, StringName and localization

- `<Text StringName="x"/>` looks `x` up in the localization tables; a `Text="..."` attribute is the WHS source-language text Skald stores when localization mode is "Disabled", and it is what the game shows if present (official wiki KM-A-18). For a localizable mod, keep `StringName` only and put the text in `<Language>_xml.pak` ([mod-structure.md](mod-structure.md#localization-text)); the old context doc strips `Text=` and `<Localization>` children for the same reason.
- String ids must start with a letter (public docs README advice, claimed).
- Pointing a `StringName` at an **existing vanilla id** (e.g. a Henry line such as `bark_henry_dokonano_jest_9xDV`) gets the subtitle in every language for free; the audio still has to be shipped ([audio-voice-lipsync.md](audio-voice-lipsync.md#reusing-vanilla-lines)).

### Chat menus (`Type="chat"`)

A compact option list where the player keeps control; the Mercenaries order wheel and Mutt's commands use it (order-wheel.md):

```xml
<Dialogue Type="chat" TechnicalStatus="Enabled" Initiator="Player" ForceMood="noScope"
          GesturesNotNeeded="true" DefaultChatTimeLimit="0" DefaultMaxDistance="10" ClashPriority="OpenWorld">
```

- `Initiator="Player"` (player opens it) vs `"NonPlayer"` (NPC hails you): different machinery.
- **Four slots per level:** `ChatPosition="First|Second|Third|Fourth"` plus `Refusal` (and `RefusalTimeout`, `RefusalDistance`). More options = `EndType="Decision"` into a submenu; vanilla pages with a "More options..." fourth slot. Vanilla census: 22 uses of `Fourth` vs 678 of `First`.
- The root `Decision` is `Autoselect="true"` with one silent opening sequence listing **both** `HENRY` and the NPC's role; without an NPC-role response the chat has no NPC to attach to.
- A `Response` with no `<Text>` child is silent.
- `Refusal` without a `UiPrompt` closes the whole chat; a real "back" needs `EndType="GoTo"`.
- NPC requirements: `IsChatUsable=1` on the entity class (vanilla `NPC.lua` default); player chat goes through `actor:DoChat` and needs no BT handler.
- Only one chat is open per NPC; a competing vanilla chat of equal `ClashPriority` wins silently (e.g. hardcore-mode directions). Opt out with a `chat_disabled`-style context port and by removing the competing metarole from the soul (`soul:RemoveMetaRoleByName`).
- If `actor:CanFollow(npc)` is true, the follow hint takes the interaction slot and the chat hint never appears.
- One `EventFunction` may take `Exec` edges from several dialogues, so a chat option can reuse an E-dialogue's token with no new Lua.
- Attribute meanings (order-wheel.md): `ForceMood="noScope"` - no dialogue camera, no zoom (2,114 of the 2,125 vanilla `ForceMood` values); `GesturesNotNeeded="true"` - no talking animations; `DefaultChatTimeLimit="0"` / `TimeLimit="0"` - the menu waits instead of timing out (304 vanilla `TimeLimit="0"`).
- Vanilla `switch_handleChat` (`AI/npc/basic/switch/handlechat.xml`) handles only the NPC-initiated `NPC_ZDRAVI_HRACE` greeting and falls into an `ErrorNode` otherwise; it is irrelevant to player-opened chats.

### Monologs and barks

- An NPC-only line is a `<Dialog>` with `<Dialogue Type="ingame monolog" Initiator="NonPlayer" ClashPriority="OpenWorld" GesturesNotNeeded="true">`, an explicit `SelectedSouls` block, and a `Decision Alias="x"`. A behaviour tree plays it with `Function_speech_schedulerMonolog(alias="x", ...)`; several responses in one sequence play back to back ([add-dialog.md](../skald/add-dialog.md), [talking.md](../behaviour-trees/talking.md), verified in game).
- Passing `metarole` instead of `alias` plays vanilla's per-voice line pools (combat barks, gossip, reactions); list in [talking.md](../behaviour-trees/talking.md).
- `RequestBark` only queues an alias for a monolog node inside a behaviour the NPC is already running; it is not a dialogue (aleksej.md).
- Audio side of barks: [audio-voice-lipsync.md](audio-voice-lipsync.md#barks).

### Player-initiated dialogue (E prompt)

The NPC's behaviour tree must poll `ProcessMessage` on the `dialogMailbox` inbox and call `Function_switch_handleDialog(dialogRequest=$dialogRequest)`, at least once a second, or the prompt never opens or lags, however correct the Skald side is ([talking.md](../behaviour-trees/talking.md), verified in game).

### Forced dialogue (NPC starts it)

Vanilla wraps NPC-initiated conversations in `<ForcedDialog>` with `<Dialogue Initiator="NonPlayer">` (855 distinct modules). What actually **starts** one is a behaviour tree calling `Function_speech_dialogInitiator` (vanilla `pacholek_forceDialogue`, 3 nodes). Rules from the census of 199 vanilla call sites (aleksej.md, vanilla + verified in game):

- Pass `alias` only. `metarole` and `recipientMetaroles` stay empty; the player never holds a metarole. Never set both `alias` and `metarole`.
- Use `dialogInitiator` for the player, not `Function_speech_schedulerPolylog_initiator`: `dialogInitiator` builds the participant array itself and forwards to the polylog initiator.
- Success shows in `kcd.log` as `Attempting to start new dialogue with souls 'Ex: <npc>; Ex: Dude'` (`Dude` is the player): the alias resolved and both parties joined.
- `context` / `customParameters` take `$__null`, not `""`. `recipient` defaults to `$__player`.
- `preset` (`dialogPreset`): `ingame`, `chat`, `fader`, `ignored`, `player_ingame`. `fader` is the one that takes control from the player. **Never `player_ingame`**: the shipped preset switch has no branch for it and falls into an `ErrorNode`.
- `fader` and `ingame` walk the participants together; a Lua-spawned NPC placed on terrain but off navmesh fails `Path finding failed ... not close enough to nav mesh` and the request times out. Spawn it near the player. `chat` positions nobody.
- A `Decision` with no `Type` is compatible with every preset; a mismatched explicit `Type` logs `Dialogue chat mode is not consistent with its decisions branch type`.
- Things that deserialize cleanly and never start a conversation: a bool In-port alone, `RequestBark`, `UrgeADialog`, a `CreateDialogParams` → `DialogParams` port, the implicit `enqueuedialogue` port on its own.
- Lua has [DialogModule.ForceDialog](api/DialogModule.md#forcedialog) and [DialogModule.StartMonolog](api/DialogModule.md#startmonolog) in the docs; their retail behaviour is unconfirmed (API page status).

## Lua-Skald bridge

Direct calls do not work in retail:

- **Skald → Lua:** `wh::conceptmodule::ExecuteConsoleString` exists (`Command` string, `Exec` trigger) but is marked `Style="Debug"` in `definitions.xml` and vanilla uses it only in `Quests/Debug/Haste/*` (retail data). It does not work in the retail game ([lua-skald-communication.md](../general/lua-skald-communication.md), [how-to-mod.md](../general/how-to-mod.md): works in the Modding Tools build only, community). Precedence note: the old context doc's section 9.5 recommends it; its own later dossier and every later source say it is locked down. Do not use it.
- **Lua → Skald state:** no quest API is bound into mod Lua. `QuestSystem` is not a global in `Scripts/Mods/*.lua`, and `IsQuestStarted` returned false for 12 real quest names including a running one (malesov-test.md, MODDING_EXPERIENCE.md; [QuestSystem page](api/QuestSystem.md#isqueststarted) shows the documented binds).

The working bridge is the **inventory token** ([lua-skald-communication.md](../general/lua-skald-communication.md), verified in game):

1. Declare a token item in `item__<modid>.xml` (any `MiscItem`, fresh `Id`). If the item row is missing, the grant silently does nothing.
2. **Skald → Lua:** an `EventFunction` `MethodName="wh::entitymodule::CreatePlayerReward"` with constants `ItemClass`, `Amount`, `ShowUINotification="false"`, fired from a dialogue Out-port. Different `Amount`s on identical nodes encode different commands on one item class. (Paying the player real money with it: `Amount` is in **decigroschen**, see [data-tables.md](data-tables.md#money).)
3. Lua polls ~1 Hz with [player.inventory:GetCountOfClass(guid)](api/Inventory.md#getcountofclass) (returns **nil**, not 0, for an unregistered class) and removes it with [DeleteItemOfClass](api/Inventory.md#deleteitemofclass) before acting.
4. **Lua → Skald:** Lua adds a token; Skald watches it with `ItemDescriptorTrigger` (`Inventory` from the player's `ObjectProperties`, `ItemDescriptor` from `wh::entitymodule::CreateItemClassDescriptor` with `ItemClass`/`Amount`, `IsActive` from a bool State). Outputs: `OnAcquire`, `OnTargetAmountAcquire`, `OnLose`, `OnTargetAmountLose`, `OnAfterLose` (retail `definitions.xml`; bandit-camp-quest.md).
5. Sweep Lua→Skald tokens with a one-tick grace, never the same tick you add them, and never leave one lying around for a repeatable quest's next run (bandit-camp-quest.md, claimed).
6. The same pattern drives Skald-only features from Lua, e.g. an input action filter via `FilterInput` (command-ui.md, ui-building.md). Clear such state unconditionally at gameplay start so a crash cannot leave it stuck.

Use `ItemDescriptorTrigger` + `CreateItemClassDescriptor`, not `ItemClassTrigger_SoulInventory`: the latter carries `Namespace="utils.item"` and would kill the graph (bandit-camp-quest.md).

## Engine hooks a mod cannot reach from Lua

| Want | Only via | Source |
|---|---|---|
| Death of a Lua-spawned NPC | Lua polling; `SoulDeathTrigger` never fires for runtime-spawned souls | aleksej.md, crime-watch.md |
| Bed ownership (sleep-save) | Skald `SetOwner`; no Lua setter | camp.md |
| Open the trade screen | a dialogue sequence `Type="OpenShop"` on a level-linked shopkeeper | camp-trader.md |
| Enable a disabled SmartEntity behaviour | Skald `EnableBehavior` (level-baked target) | [formations.md](formations.md#reachability-of-the-controller) |
| NPC morale value | Skald `GetMorale`; Lua sees only `combat_flee`/`combat_surrender` contexts | enemy-morale.md |
| Game contexts (`crime_disabledTrespassReactions`, ...) | Skald `SetGameContext` / `SetGameContextPreset` | official wiki KM-A-31, npc-lod.md |
| Area enter/leave by label | Skald `AreaLabelTrigger` (a primitive, safe) | interior-detection.md |
| React to a buff | `buff_ai_tag` + `BuffTagTrigger` | official wiki KM-A-31 |

## Cutscenes and random events

- **A mod cannot play a cutscene** of any type without shipping level data. The chain is `ui/cutscene.xml` entry (patchable) → `CutsceneHolder` entity → quest `CutsceneHandler` whose holder port is a required entity pointer → an `Asset` resolved through a level-baked QSO at `OnWake`. The only route is a modified `objects_mission0.xml` with `modifies_level=true`, which conflicts with every other level mod. There is no Lua API to play a `.bk2`. Full analysis: cutscenes.md (retail binary, verified in game).
- **Random events** (official wiki [KM-A-68](https://warhorse.youtrack.cloud/articles/KM-A-68)): a *random event* module with *variant* nodes, instanced in an *event place* module, plus event entities linked in the level. `Tags` come from `RandomEvent/RandomEventTag.xml`; static ports wire one definition to every instance (KM-A-76). The web debugger is `http://localhost:1403/player/randomEvents` (dev build). Step 5 needs level entities, so new event places are out of reach for a data-only mod (unverified; reusing vanilla event places is untested).

## Graph-killers

Each of these loads without a retail error and silently disables **every** dialogue, bark and context in the mod's graph. The dev build's `kcd.log` names the node (`Object factory was not able to create new ...`, `Unable to load concept graph xml Quests/<modid>.xml`, `required port X is missing`) (npc-lod.md, verified in game).

- A node with a `Namespace="folder.path"` attribute: it resolves into a vanilla module your compiled graph does not contain. Mod nodes must be primitives. `TypeT="wh::questmodule::QuestProgress"` (a type string) and the built-in `Progress` type are fine (bandit-camp-quest.md).
- `QuestVisual` (test-only node): fails in the object factory and cascades up through Quest → Level → root (npc-lod.md). `SequenceArea` behaves the same (walls-and-sieges.md).
- A required bool port left unwired. `IsAutoTriggerable="true"` does **not** mean optional; if `IsOptional="false"` the whole node is rejected. Wire a constant-true State (`<State TypeT="bool"><Constant Name="DefaultValue" Value="true"/></State>`) into it (npc-lod.md).
- `IsActive` fed by a raw trigger instead of a bool: silently does nothing (not graph-wide, but equally silent). vanilla feeds it from `and`/`not` of States (bandit-camp-quest.md).
- Undefined RTTR types from vanilla helper subgraphs (e.g. `utils.speech:payment`) crash the mod on load (old context doc).
- A dangling `Edge` (one whose `From`/`To` port no longer exists) is reported to brick the whole graph the same way; when deleting a sequence, keep the Out-port and its `EventFunction` declared if anything still edges into them (bounty.md, `(unverified)`).

Debug workflow: build with the dev packager, check the dev build's `kcd.log` **and its timestamp** (a stale log from an old run looks like evidence), then re-test in retail. A lone `Empty soul collection` at load time also appears for vanilla nodes and is a timing transient, not a defect (npc-lod.md). More: [debugging.md](debugging.md).

## Gotchas

- **Every mod dialogue stopped working at once:** one node in the graph failed to load (`Namespace`, `QuestVisual`, unwired required port). Only the dev build log says which (npc-lod.md).
- **Dialogue ends right after a response instead of branching:** the sequence that nests a `Decision` lacks `EndType="Decision"` (old context doc, verified in game).
- **`Decision with alias 'x' was not found!`:** the dialogue is imported with `<Definition>` but has no instance node in `<Nodes>`; the alias is not misspelled (aleksej.md).
- **Forced dialogue request times out:** the NPC is off navmesh (`fader`/`ingame` presets walk participants) (aleksej.md).
- **Token grant does nothing:** the token item row is missing from `item__<modid>.xml` (Mercenaries `TODO.txt`, verified in game).
- **Quest reward pays a tenth of the purse, and the notification agrees:** `CreatePlayerReward` money `Amount` is in decigroschen; multiply groschen by 10 (aleksej.md).
- **Chat menu closes by itself after a few seconds:** `TimeLimit`/`DefaultChatTimeLimit` is not `0` (order-wheel.md).
- **Player receives two tokens:** two `EventFunction` nodes with near-identical names are wired to the same Out-port; both fire, no conflict error (old context doc, verified in game).
- **Repeatable quest completes instantly on the next run:** a stale Lua→Skald token was left in the inventory (bandit-camp-quest.md).
- **Quest marker points at nothing after a reload:** it bound to the pre-reload entity; adopt the saved NPC by name at wake (aleksej.md).
- **Objective never updates when your spawned NPC dies:** `SoulDeathTrigger` ignores Lua-spawned souls; poll in Lua and send a token (aleksej.md).
- **Chat menu never shows on a follower:** the follow hint owns the interaction slot, or another chat won the clash (order-wheel.md).
- **An effect node's output reads garbage:** you read its data port outside the tick its trigger fired; feed live data from `ObjectProperties` (bandit-camp-quest.md).
- **An unrecognised enum constant in a port silently becomes the default** (e.g. a typo'd formation type becomes `Relaxed`) ([formations.md](formations.md#formationmode-and-the-params-struct)).
- **`SpawnFriend`/`SpawnEnemy` ignores your soul GUID:** vanilla `CombatDebug` wants `s<guid>` (37 characters; `a`/`w` prefixes for armour/weapon presets); a bare GUID is not recognised (vanilla: `Scripts/Debug/CombatDebug.lua`). Precedence note: the old context doc (section 9.6) claims the opposite, that the `s` prefix breaks spawning; vanilla source wins. Everywhere else (`SharedSoulGuids`, `guidSharedSoulId`) GUIDs are bare.
- **A dialogue works in the Modding Tools build and not in retail:** console commands from Skald and lenient error handling exist only there ([how-to-mod.md](../general/how-to-mod.md), community).
- **You overrode a vanilla quest file and a later patch "undid" nothing but broke something:** overrides freeze at the build you copied; regenerate after every game patch (quest-override-battles.md).

## See also

- [mod-structure.md](mod-structure.md), [data-tables.md](data-tables.md), [audio-voice-lipsync.md](audio-voice-lipsync.md).
- War stories: aleksej.md (forced dialogue, markers across reloads), bandit-camp-quest.md (tokens, markers, Namespace), order-wheel.md (chat menus), cutscenes.md, npc-lod.md (graph-killers, battle quests), quest-override-battles.md.
- Official: [KM-A-29 Quest system](https://warhorse.youtrack.cloud/articles/KM-A-29), [KM-A-67 Event system](https://warhorse.youtrack.cloud/articles/KM-A-67).
