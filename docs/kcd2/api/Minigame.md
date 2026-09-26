# Minigame

C++ class(es): `C_ScriptBindMinigame`
Reached from Lua as `Minigame.FunctionName(...)`.
13 documented function(s); 2 additional undocumented function(s) found in retail/runtime.

## Functions

### BookTranscriptionNextPage

```lua
Minigame.BookTranscriptionNextPage()
```

C++: `int BookTranscriptionNextPage (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### CanUseMinigame

```lua
Minigame.CanUseMinigame(ScriptHandle playerId, int filterMask)
```

Check if the minigame can start. Particular type of minigame can use different mask. By default all filters are enabled. Use disableMask to disable particular filter. Use Lua bit operations (bor) to compose bit values. For example: bor(E_MUF_CombatDanger,E_MUF_Other)

| Param | Description |
|---|---|
| ScriptHandle playerId | ID of entity which want to play a minigame |
| disableMask | Test usage mask for disabling filters composed from E_MinigameUsageFilter enum (optional) |

docs: y · retail: confirmed (runtime dump, vanilla×12 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/AI/Shared/BasicAIActions.lua`))

### CloseInventory

```lua
Minigame.CloseInventory()
```

C++: `virtual int CloseInventory (IFunctionHandler* pH )`

Support functions

docs: y · retail: unconfirmed

### GetBookStudyProgress

```lua
Minigame.GetBookStudyProgress()
```

C++: `int GetBookStudyProgress (IFunctionHandler * pH , const char * documentGuid )`

docs: y · retail: confirmed (binary, runtime dump)

### OnInventoryItemUsed

```lua
Minigame.OnInventoryItemUsed()
```

C++: `void OnInventoryItemUsed (entitymodule::T_ItemId)`

docs: y · retail: confirmed (vanilla×2)

### OnInventoryStateChanged

```lua
Minigame.OnInventoryStateChanged()
```

C++: `void OnInventoryStateChanged ( bool bOpened )`

docs: y · retail: unconfirmed

### OpenInventory

```lua
Minigame.OpenInventory()
```

C++: `virtual int OpenInventory (IFunctionHandler* pH , ScriptHandle entityId , char const * pFilter )`

Support functions

docs: y · retail: confirmed (vanilla×3)

### StartDice

```lua
Minigame.StartDice(ScriptHandle tableId, ScriptHandle playerId, ScriptHandle opponentNpcId, SmartScriptTable options)
```

Start dice minigame.

| Param | Description |
|---|---|
| tableId | Entity ID of the table to play dice at |
| playerId | Entity ID of the player |
| opponentNpcID | Entity ID of the NPC opponent to play dice with |
| options | optional |

docs: y · retail: confirmed (runtime dump)

### StartDiceByName

```lua
Minigame.StartDiceByName(const char* name)
```

Start dice minigame.

| Param | Description |
|---|---|
| tableId | Entity ID of the table to play dice at |
| playerId | Entity ID of the player |
| opponentNpcID | Entity ID of the NPC opponent to play dice with |

docs: y · retail: confirmed (runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Minigames/DiceInteractor.lua`))

### StartHerbGathering

```lua
Minigame.StartHerbGathering()
```

C++: `virtual int StartHerbGathering (IFunctionHandler * pH , ScriptHandle areaId )`

docs: y · retail: confirmed (runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Others/PickableArea.lua`))

### StartHoleDigging

```lua
Minigame.StartHoleDigging()
```

C++: `virtual int StartHoleDigging (IFunctionHandler * pH , ScriptHandle holeId )`

docs: y · retail: confirmed (runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Others/Hole.lua`))

### StartLockPicking

```lua
Minigame.StartLockPicking()
```

C++: `virtual int StartLockPicking (IFunctionHandler * pH , ScriptHandle entityId )`

docs: y · retail: confirmed (runtime dump, vanilla×3 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Doors/AnimDoor.lua`))

### WasBookOpened

```lua
Minigame.WasBookOpened()
```

C++: `int WasBookOpened (IFunctionHandler * pH , const char * documentGuid )`

docs: y · retail: confirmed (binary, runtime dump)

## Undocumented (present in retail, not in official docs)

### CanStartReadingMinigame

`Minigame.CanStartReadingMinigame(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Minigames/Book.lua`))

### StartDiceWithScore

`Minigame.StartDiceWithScore(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump)
