# DialogModule

C++ class(es): `C_ScriptBindDialog`, `C_ScriptBind_Dialog`
Reached from Lua as `DialogModule.FunctionName(...)`.
12 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### AnalyzeRequest

```lua
DialogModule.AnalyzeRequest()
```

Analyze dialog request situation. Checks if entities are in correct distance and facing correct directions.

| Param | Description |
|---|---|
| entity | who |
| useLookDir | use look dir instead of entity dir to evaluate angles |
| onlyPos | only evaluate entity positions |

docs: y · retail: confirmed (runtime dump)

### ForceDialog

```lua
DialogModule.ForceDialog()
```

C++: `int ForceDialog (IFunctionHandler * pH , ScriptHandle speakerId , ScriptHandle listenerId )`

Start dialog between selected entities. This should not be used in standard situations. It overrides AI and does not care about entity positioning.

docs: y · retail: confirmed (runtime dump)

### IsDialogInterruptibleByPlayer

```lua
DialogModule.IsDialogInterruptibleByPlayer(wuid)
```

C++: `int IsDialogInterruptibleByPlayer (IFunctionHandler * pH , framework::T_WUIDScriptType id )`

return whether soul can be interrupted by another dialog from player

docs: y · retail: unconfirmed

### IsSequenceAvailable

```lua
DialogModule.IsSequenceAvailable(12345)
```

C++: `int IsSequenceAvailable (IFunctionHandler* pH , wh::dialogmodule::T_SequenceId id )`

return true if sequence is not on cool down

docs: y · retail: unconfirmed

### IsSequenceUsed

```lua
DialogModule.IsSequenceUsed(12345)
```

C++: `int IsSequenceUsed (IFunctionHandler* pH , wh::dialogmodule::T_SequenceId id )`

return true if sequence was selected at last once

docs: y · retail: unconfirmed

### IsSoulInDialog

```lua
DialogModule.IsSoulInDialog(soulWuid)
```

C++: `int IsSoulInDialog (IFunctionHandler * pH , framework::T_WUIDScriptType id )`

return whether soul is currently in some dialog

docs: y · retail: confirmed (runtime dump)

### ResetHaggle

```lua
DialogModule.ResetHaggle()
```

C++: `int ResetHaggle (IFunctionHandler * pH )`

Resets haggle attributes. Please call this at the end of every haggle otherwise ended haggle can interfered into future one

docs: y · retail: confirmed (runtime dump)

### ResetHaveDialogCache

```lua
DialogModule.ResetHaveDialogCache()
```

C++: `int ResetHaveDialogCache (IFunctionHandler * pH )`

reset have dialog cache so NPC will evaluate dialog options next time interactor asks for it

docs: y · retail: unconfirmed

### ResetSequenceTimer

```lua
DialogModule.ResetSequenceTimer(12345)
```

C++: `int ResetSequenceTimer (IFunctionHandler* pH , wh::dialogmodule::T_SequenceId id )`

resets sequence cool down and used flags

docs: y · retail: unconfirmed

### SetAIInteractionState

```lua
DialogModule.SetAIInteractionState(soulid, true)
```

C++: `int SetAIInteractionState (IFunctionHandler * pH , framework::T_WUIDScriptType id , bool state )`

notifies dialog that it should wait for AI until somebody call this function and set false

docs: y · retail: confirmed (runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/DialogUtils.lua`))

### SetPlayerInteractiveState

```lua
DialogModule.SetPlayerInteractiveState(stateName)
```

C++: `int SetPlayerInteractiveState (IFunctionHandler * pH )`

Sets interactive state for players dialog. StateName must correspond to E_D_InteractiveState enum

docs: y · retail: confirmed (runtime dump)

### StartMonolog

```lua
DialogModule.StartMonolog(entity, 2258)
```

C++: `int StartMonolog (IFunctionHandler * pH , ScriptHandle speakerId , T_TopicId topic )`

Start monolog using dialog system. Specific topic can be selected.

docs: y · retail: unconfirmed
