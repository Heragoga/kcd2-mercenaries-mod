# QuestSystem

C++ class(es): `C_ScriptBindQuest`, `C_ScriptBind_Quest`
Reached from Lua as `QuestSystem.FunctionName(...)`.
37 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### ActivateQuest

```lua
QuestSystem.ActivateQuest(const char *questName, int activate)
```

Activate/deactivate quest

| Param | Description |
|---|---|
| const char * questName | name of the quest |
| int activate | 1 if activating 0 if deactivating |

docs: y · retail: unconfirmed

### AreQuestVIPsAlive

```lua
QuestSystem.AreQuestVIPsAlive(const char *questName)
```

Returns true if all quest vip are still alive

| Param | Description |
|---|---|
| const char * questName | name of the quest |

docs: y · retail: unconfirmed

### CancelObjective

```lua
QuestSystem.CancelObjective(const char *questName)
```

Cancel quest objective (tracked object count)

| Param | Description |
|---|---|
| const char * questName | name of the quest for cancel |
| objectiveId | objective id |

docs: y · retail: unconfirmed

### CancelQuest

```lua
QuestSystem.CancelQuest(const char *questName, bool fail)
```

Cancel quest (repeat count, tracked object count)

| Param | Description |
|---|---|
| const char * questName | name of the quest for cancel |
| bool doCount | true if counter for quest should be decreased |
| bool isFail | true if quest cannot be |

docs: y · retail: unconfirmed

### CanRepeatQuest

```lua
QuestSystem.CanRepeatQuest(const char *questName)
```

Returns if quest can be repeated

| Param | Description |
|---|---|
| const char * questName | name of the quest |

docs: y · retail: unconfirmed

### CompleteObjective

```lua
QuestSystem.CompleteObjective(const char *questName)
```

Complete objective of quest with id, only if it is active

| Param | Description |
|---|---|
| const char * questName | name of the quest |
| objectiveId | id of the objective |
| sendMsg | if true it will send message to the quest smart object (true is default) |

docs: y · retail: unconfirmed

### CompleteQuestObjective

```lua
QuestSystem.CompleteQuestObjective(const char *questName, int objectiveId)
```

Complete objective of quest with id, even if objective was not active before

| Param | Description |
|---|---|
| const char * questName | name of the quest |
| int objectiveId | id of the objective |

docs: y · retail: unconfirmed

### CompleteStep

```lua
QuestSystem.CompleteStep(const char *questName, int objectiveId, int stepId)
```

Complete step from objective of quest with id, only if it is active

| Param | Description |
|---|---|
| const char * questName | name of the quest |
| int objectiveId | id of the objective |
| int stepId | id of the step |

docs: y · retail: unconfirmed

### DeactivateQuest

```lua
QuestSystem.DeactivateQuest(const char *questName)
```

Deactivate quest

| Param | Description |
|---|---|
| const char * questName | name of the quest |
| sendMsg | if true it will send message to the quest smart object (true is default) |

docs: y · retail: unconfirmed

### GetActiveObjectives

```lua
QuestSystem.GetActiveObjectives(const char *questName)
```

Returns table with ids of active objectives

| Param | Description |
|---|---|
| const char * questName | name of the quest to which objective belongs |

docs: y · retail: unconfirmed

### IsObjectiveActive

```lua
QuestSystem.IsObjectiveActive(const char *questName)
```

Returns true if objective is active, false if not, or quest or objective does not exist

| Param | Description |
|---|---|
| const char * questName | name of the quest to which objective belongs |
| objectiveId | id of objective |

docs: y · retail: unconfirmed

### IsObjectiveCanceled

```lua
QuestSystem.IsObjectiveCanceled(const char *questName)
```

Returns true if objective is canceled, false if not, or quest or objective does not exist

| Param | Description |
|---|---|
| const char * questName | name of the quest to which objective belongs |
| objectiveId | id of objective |

docs: y · retail: unconfirmed

### IsObjectiveCompleted

```lua
QuestSystem.IsObjectiveCompleted(const char *questName)
```

Returns true if objective is completed, false if not, or quest or objective does not exist

| Param | Description |
|---|---|
| const char * questName | name of the quest to which objective belongs |
| objectiveId | id of objective |

docs: y · retail: unconfirmed

### IsObjectiveStarted

```lua
QuestSystem.IsObjectiveStarted(const char *questName)
```

Returns true if objective has been started, false if not, or quest or objective does not exist

| Param | Description |
|---|---|
| const char * questName | name of the quest to which objective belongs |
| objectiveId | id of objective |

docs: y · retail: unconfirmed

### IsObjectiveTrackedCompleted

```lua
QuestSystem.IsObjectiveTrackedCompleted(const char *questName)
```

Returns true if objective tracked assets count is enough

| Param | Description |
|---|---|
| const char * questName | name of the quest to which objective belongs |
| objectiveId | id of objective |

docs: y · retail: unconfirmed

### IsObjectiveUnchanged

```lua
QuestSystem.IsObjectiveUnchanged(const char *questName)
```

Returns true if objective is same as after reset, false if not, or quest or objective does not exist

| Param | Description |
|---|---|
| const char * questName | name of the quest to which objective belongs |
| objectiveId | id of objective |

docs: y · retail: unconfirmed

### IsQuestActivated

```lua
QuestSystem.IsQuestActivated(const char *questName)
```

Returns true if quest has been activated, false if not, or quest does not exist

| Param | Description |
|---|---|
| const char * questName | name of the quest |

docs: y · retail: unconfirmed

### IsQuestActive

```lua
QuestSystem.IsQuestActive(const char *questName)
```

Returns true if quest is active, false if not, or quest does not exist

| Param | Description |
|---|---|
| const char * questName | name of the quest |

docs: y · retail: unconfirmed

### IsQuestAvailable

```lua
QuestSystem.IsQuestAvailable(const char *questName)
```

Returns true if quest is available, false if not, or quest does not exist

| Param | Description |
|---|---|
| const char * questName | name of the quest |

docs: y · retail: unconfirmed

### IsQuestCanceled

```lua
QuestSystem.IsQuestCanceled(const char *questName)
```

Returns true if quest is completed, false if not, or quest or objective does not exist

| Param | Description |
|---|---|
| const char * questName | name of the quest |

docs: y · retail: confirmed (mod×1)

### IsQuestCompleted

```lua
QuestSystem.IsQuestCompleted(const char *questName)
```

Returns true if quest is completed, false if not, or quest or objective does not exist

| Param | Description |
|---|---|
| const char * questName | name of the quest |

docs: y · retail: confirmed (mod×2)

### IsQuestStarted

```lua
QuestSystem.IsQuestStarted(const char *questName)
```

Returns true if quest has been started, false if not, or quest does not exist

| Param | Description |
|---|---|
| const char * questName | name of the quest |

docs: y · retail: confirmed (mod×3)

### IsQuestUnchanged

```lua
QuestSystem.IsQuestUnchanged(const char *questName)
```

Returns true if quest has only been loaded from DB

| Param | Description |
|---|---|
| const char * questName | name of the quest |

docs: y · retail: unconfirmed

### IsStepActive

```lua
QuestSystem.IsStepActive(const char *questName, int objectiveId, int stepId)
```

Returns true if step in objective is active, false if not, or quest or objective or step does not exist

| Param | Description |
|---|---|
| const char * questName | name of the quest to which objective belongs |
| int objectiveId | id of objective |
| int stepId | id of step |

docs: y · retail: unconfirmed

### MoveToQuestObjective

```lua
QuestSystem.MoveToQuestObjective(const char *questName)
```

Move to quest objective with id if quest was not completed before, finishes all active objectives, does not check prerequisites

| Param | Description |
|---|---|
| const char * questName | name of the quest |
| objectiveId | id of the objective |

docs: y · retail: unconfirmed

### OpenInventory

```lua
QuestSystem.OpenInventory()
```

Opens inventory with item asset which should be delivered

| Param | Description |
|---|---|
| const char * questName | name of the quest which will be delivered |
| objectiveId | id of objective |
| gVarName | name of the variable with result (0 not set, -1 cancel, -2 wrong item or less items, 1 ok, 2 ok, but broken) |

docs: y · retail: confirmed (vanilla×3)

### PlayerEnteredTrigger

```lua
QuestSystem.PlayerEnteredTrigger(const char *placeAssetName, EntityId userId)
```

Called from script when player enters ProximityTrigger or AreaTrigger

| Param | Description |
|---|---|
| const char * placeAssetName | name of the place asset |
| ScriptHandle userId | entityId of user which entered trigger |

docs: y · retail: unconfirmed

### RegisterQuestEntity

```lua
QuestSystem.RegisterQuestEntity()
```

Registers entity with quest smart object. Not on master.

| Param | Description |
|---|---|
| ScriptHandle entityId | quest object entity id |

docs: y · retail: unconfirmed

### ReloadQuest

```lua
QuestSystem.ReloadQuest()
```

Reload quest DB tables

WH_CTSW(WH_CTSW_MASTER)

| Param | Description |
|---|---|
| const char* questName | name of the quest for reload |

docs: y · retail: unconfirmed

### ReloadQuestAssets

```lua
QuestSystem.ReloadQuestAssets()
```

Prepare assets for quest, used when asset (usually entity) in level was added/removed

WH_CTSW(WH_CTSW_MASTER)

| Param | Description |
|---|---|
| const char * questName | name of the quest for reload assets |

docs: y · retail: unconfirmed

### ReloadQuests

```lua
QuestSystem.ReloadQuests()
```

C++: `int ReloadQuests (IFunctionHandler * pH )`

Reload all quests. Not on master.

docs: y · retail: unconfirmed

### ResetQuest

```lua
QuestSystem.ResetQuest(const char *questName)
```

Reset quest (repeat count, tracked object count)

| Param | Description |
|---|---|
| const char * questName | name of the quest for reset |

docs: y · retail: unconfirmed

### StartObjective

```lua
QuestSystem.StartObjective(const char *questName)
```

Start objective of quest with id

| Param | Description |
|---|---|
| const char * questName | name of the quest |
| objectiveId | id of the objective |
| sendMsg | if true it will send message to the quest smart object (true is default) |

docs: y · retail: unconfirmed

### StartQuest

```lua
QuestSystem.StartQuest(const char *questName)
```

Start quest if loaded from xml

| Param | Description |
|---|---|
| const char * questName | name of the quest |

docs: y · retail: unconfirmed

### StartQuestObjective

```lua
QuestSystem.StartQuestObjective(const char *questName)
```

Start objective of quest with id

| Param | Description |
|---|---|
| const char * questName | name of the quest |
| objectiveId | id of the objective |

docs: y · retail: unconfirmed

### TriggerCondition

```lua
QuestSystem.TriggerCondition()
```

C++: `int TriggerCondition (IFunctionHandler * pH )`

Trigger condition evaluation of all types for current active objectives

docs: y · retail: unconfirmed

### TriggerConditionForAsset

```lua
QuestSystem.TriggerConditionForAsset(const char *assetName)
```

Trigger condition evaluation of type SCRIPT for an asset of current active objectives

| Param | Description |
|---|---|
| int assetId | asset to be evaluated in condition |

docs: y · retail: unconfirmed
