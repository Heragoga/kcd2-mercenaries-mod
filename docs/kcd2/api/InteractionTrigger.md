# InteractionTrigger

C++ class(es): `C_ScriptBindInteractionTrigger`
Reached from Lua as `InteractionTrigger.FunctionName(...)`.
9 documented function(s); 36 additional undocumented function(s) found in retail/runtime.

## Functions

### AttachTo

```lua
InteractionTrigger.AttachTo()
```

C++: `virtual void AttachTo (I_InteractionTrigger* trigger )`

docs: y · retail: unconfirmed

### GetInteractionTrigger

```lua
InteractionTrigger.GetInteractionTrigger()
```

C++: `I_InteractionTrigger* GetInteractionTrigger (IFunctionHandler* pH )`

docs: y · retail: unconfirmed

### IsEnabled

```lua
interactionTrigger.IsEnabled()
```

C++: `virtual int IsEnabled (IFunctionHandler* pH )`

Checks whether the trigger is enabled for use by player

docs: y · retail: confirmed (binary, runtime dump, vanilla×9)

### IsHoldEnabled

```lua
interactionTrigger.IsHoldEnabled()
```

C++: `virtual int IsHoldEnabled (IFunctionHandler* pH )`

Checks whether the trigger hold button is enabled for use by player.

docs: y · retail: confirmed (vanilla×3)

### IsPressEnabled

```lua
interactionTrigger.IsPressEnabled()
```

C++: `virtual int IsPressEnabled (IFunctionHandler* pH )`

Checks whether the trigger press button is enabled for use by player.

docs: y · retail: confirmed (vanilla×3)

### SetEnabled

```lua
interactionTrigger.SetEnabled(enabled)
```

Enables or disables the trigger based on provided parameter.

| Param | Description |
|---|---|
| const bool enabled | flag that controls trigger enabled state |

docs: y · retail: unconfirmed

### SetHeld

```lua
interactionTrigger.SetHeld()
```

C++: `virtual int SetHeld (IFunctionHandler* pH )`

Should be called when the trigger is held by player.

docs: y · retail: confirmed (vanilla×1)

### SetPressed

```lua
interactionTrigger.SetPressed()
```

C++: `virtual int SetPressed (IFunctionHandler* pH )`

Should be called when the trigger is pressed by player.

docs: y · retail: confirmed (vanilla×1)

### SetPriority

```lua
interactionTrigger.SetPriority()
```

C++: `virtual int SetPriority (IFunctionHandler* pH , int priority )`

Set the priority of this interactor trigger

docs: y · retail: confirmed (vanilla×2)

## Undocumented (present in retail, not in official docs)

### _CheckDialog

`InteractionTrigger._CheckDialog(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### _GetSendTargets

`InteractionTrigger._GetSendTargets(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×4)

### GetActions

`InteractionTrigger.GetActions(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×35, mod×1)

### GetHint

`InteractionTrigger.GetHint(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×3)

### GetHintHold

`InteractionTrigger.GetHintHold(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×3)

### IsActionAvailable

`InteractionTrigger.IsActionAvailable(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×5)

### IsEnabledByProperties

`InteractionTrigger.IsEnabledByProperties(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×3)

### IsEnabledByScriptPerk

`InteractionTrigger.IsEnabledByScriptPerk(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×3)

### IsEnabledBySoulAbility

`InteractionTrigger.IsEnabledBySoulAbility(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×3)

### IsEnabledFromQuestSystem

`InteractionTrigger.IsEnabledFromQuestSystem(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×3)

### IsEnabledHold

`InteractionTrigger.IsEnabledHold(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×7)

### IsUsable

`InteractionTrigger.IsUsable(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×47, mod×1)

### IsUsableHold

`InteractionTrigger.IsUsableHold(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×6)

### NeedSerialize

`InteractionTrigger.NeedSerialize(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×5)

### OnAction

`InteractionTrigger.OnAction(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×5)

### OnEditorSetGameMode

`InteractionTrigger.OnEditorSetGameMode(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×3)

### OnInventoryClosed

`InteractionTrigger.OnInventoryClosed(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×4)

### OnInventoryItemUsed

`InteractionTrigger.OnInventoryItemUsed(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### OnLoad

`InteractionTrigger.OnLoad(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×65, mod×1)

### OnPropertyChange

`InteractionTrigger.OnPropertyChange(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×113)

### OnReset

`InteractionTrigger.OnReset(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×162, mod×2)

### OnSave

`InteractionTrigger.OnSave(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×60, mod×1)

### OnSpawn

`InteractionTrigger.OnSpawn(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×75, mod×4)

### OnUsed

`InteractionTrigger.OnUsed(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×36, mod×1)

### OnUsedHold

`InteractionTrigger.OnUsedHold(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×5)

### OpenInventory

`InteractionTrigger.OpenInventory(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×3)

### PhysicalizeThis

`InteractionTrigger.PhysicalizeThis(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×50, mod×2)

### ReportUse

`InteractionTrigger.ReportUse(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×8)

### ResetHoldMessage

`InteractionTrigger.ResetHoldMessage(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### ResetUseMessage

`InteractionTrigger.ResetUseMessage(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### SetAvailable

`InteractionTrigger.SetAvailable(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### SetAvailableHold

`InteractionTrigger.SetAvailableHold(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### SetHoldMessage

`InteractionTrigger.SetHoldMessage(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### SetUseMessage

`InteractionTrigger.SetUseMessage(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### UpdateMaterial

`InteractionTrigger.UpdateMaterial(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×6)

### UserNoItem

`InteractionTrigger.UserNoItem(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)
