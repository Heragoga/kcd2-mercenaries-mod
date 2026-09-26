# PickableItem

C++ class(es): `C_ScriptBindPickableItem`, `C_ScriptBind_PickableItem`
Reached from Lua as `PickableItem.FunctionName(...)`.
39 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### AttachTo

```lua
PickableItem.AttachTo()
```

C++: `void AttachTo (C_PickableItem * pItem )`

docs: y · retail: unconfirmed

### BelongsToDeadBody

```lua
PickableItem.BelongsToDeadBody()
```

C++: `int BelongsToDeadBody (IFunctionHandler* pH )`

DEPRECATED Returns true if the item's owner is dead

docs: y · retail: confirmed (binary, vanilla×1)

### CanPickUp

```lua
PickableItem.CanPickUp(ScriptHandle userId)
```

Checks if the item can be picked up by the user.

| Param | Description |
|---|---|
| ScriptHandle userId | User identifier. |

docs: y · retail: confirmed (binary, vanilla×1)

### CanSteal

```lua
PickableItem.CanSteal(ScriptHandle userId)
```

Checks if the item can be stolen by the user.

| Param | Description |
|---|---|
| ScriptHandle userId | User identifier. |

docs: y · retail: confirmed (binary, vanilla×2)

### CanUse

```lua
PickableItem.CanUse(ScriptHandle userId)
```

Checks if the item can be used by the user.

| Param | Description |
|---|---|
| ScriptHandle userId | User identifier. |

docs: y · retail: confirmed (binary, vanilla×4)

### GetEntityHoldingInHand

```lua
PickableItem.GetEntityHoldingInHand()
```

C++: `int GetEntityHoldingInHand (IFunctionHandler * pH )`

Returns the script table of entity that is hodling this item, if ant

docs: y · retail: confirmed (binary, vanilla×1)

### GetExtensionParams

```lua
PickableItem.GetExtensionParams(const char * extension, SmartScriptTable params)
```

Gets extension parameters.

| Param | Description |
|---|---|
| const char * extension | Extension name. |
| SmartScriptTable params | Extension parameters. |

docs: y · retail: confirmed (binary)

### GetHealth

```lua
PickableItem.GetHealth()
```

C++: `int GetHealth (IFunctionHandler * pH )`

Gets item health.

docs: y · retail: confirmed (vanilla×4, mod×6)

### GetId

```lua
PickableItem.GetId()
```

C++: `int GetId (IFunctionHandler * pH )`

Gets item id

docs: y · retail: confirmed (binary, vanilla×2, mod×12)

### GetLinkedOwner

```lua
PickableItem.GetLinkedOwner()
```

C++: `int GetLinkedOwner (IFunctionHandler* pH )`

Returns linked owner

docs: y · retail: confirmed (binary)

### GetMaxHealth

```lua
PickableItem.GetMaxHealth()
```

C++: `int GetMaxHealth (IFunctionHandler * pH )`

Gets the maximum item health.

docs: y · retail: confirmed (vanilla×1, mod×12)

### GetMountedAngleLimits

```lua
PickableItem.GetMountedAngleLimits()
```

C++: `int GetMountedAngleLimits (IFunctionHandler * pH )`

Gets the mounted angle limits for the item.

docs: y · retail: confirmed (binary)

### GetMountedDir

```lua
PickableItem.GetMountedDir()
```

C++: `int GetMountedDir (IFunctionHandler * pH )`

Gets the mounted direction for the item.

docs: y · retail: confirmed (binary)

### GetOwnerId

```lua
PickableItem.GetOwnerId()
```

C++: `int GetOwnerId (IFunctionHandler * pH )`

Gets the identifier of the item's owner.

docs: y · retail: confirmed (binary)

### GetParams

```lua
PickableItem.GetParams()
```

C++: `int GetParams (IFunctionHandler * pH )`

Gets the item parameters.

docs: y · retail: unconfirmed

### GetPhase

```lua
PickableItem.GetPhase()
```

C++: `int GetPhase (IFunctionHandler* pH )`

Returns phase relative from 0 to 1.

docs: y · retail: confirmed (binary)

### GetPhaseId

```lua
PickableItem.GetPhaseId()
```

C++: `int GetPhaseById (IFunctionHandler* pH )`

Returns absolute phase id from 0 to max phases.

docs: y · retail: unconfirmed

### GetSlot

```lua
PickableItem.GetSlot(bool usePresence)
```

Gets the slot that holds the item. Uses either the presence or the holder to determine the slot. May return invalid wuid if the item's presence/holder is not a slot

| Param | Description |
|---|---|
| bool usePresence | is the presence (current state) or holder (the longer object responsible for the item) used |

docs: y · retail: confirmed (binary, vanilla×1)

### GetStats

```lua
PickableItem.GetStats()
```

C++: `int GetStats (IFunctionHandler * pH )`

Gets the item statistics.

docs: y · retail: confirmed (binary)

### GetUIName

```lua
PickableItem.GetUIName()
```

C++: `int GetUIName (IFunctionHandler * pH )`

Gets the UI name.

docs: y · retail: confirmed (binary, vanilla×3)

### IsDestroyed

```lua
PickableItem.IsDestroyed()
```

C++: `int IsDestroyed (IFunctionHandler * pH )`

Event that occurs when the item is destroyed.

docs: y · retail: confirmed (binary, vanilla×2)

### IsFromShop

```lua
PickableItem.IsFromShop()
```

C++: `int IsFromShop (IFunctionHandler* pH )`

Returns true if the item is owner by some shop and can be bought instead of picked

docs: y · retail: confirmed (binary, vanilla×1)

### IsMounted

```lua
PickableItem.IsMounted()
```

C++: `int IsMounted (IFunctionHandler * pH )`

Checks if the item is mounted.

docs: y · retail: confirmed (binary, vanilla×1, mod×5)

### IsOversized

```lua
PickableItem.IsOversized()
```

C++: `int IsOversized (IFunctionHandler * pH )`

Returns true if the item is too big to be picket up

docs: y · retail: confirmed (binary)

### IsUsed

```lua
PickableItem.IsUsed()
```

C++: `int IsUsed (IFunctionHandler * pH )`

Checks if the item is used.

docs: y · retail: confirmed (binary)

### OnHit

```lua
PickableItem.OnHit(SmartScriptTable hitTable)
```

Events that occurs when the item is hit.

| Param | Description |
|---|---|
| SmartScriptTable hitTable | Table with the hit values. |

docs: y · retail: confirmed (vanilla×16)

### OnSteal

```lua
PickableItem.OnSteal(ScriptHandle userId)
```

If user is player, asks if he wants to steal the item and steals it.

| Param | Description |
|---|---|
| ScriptHandle userId | User identifier. |

docs: y · retail: confirmed (binary, vanilla×1)

### OnUsed

```lua
PickableItem.OnUsed(ScriptHandle userId)
```

Events that occurs when the item is used.

| Param | Description |
|---|---|
| ScriptHandle userId | User identifier. |

docs: y · retail: confirmed (binary, vanilla×37 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Minigames/Book.lua`), mod×1)

### PlayAction

```lua
PickableItem.PlayAction(animationName)
```

Plays the specified animation.

| Param | Description |
|---|---|
| animationName | Animation name. |

docs: y · retail: unconfirmed

### Reset

```lua
PickableItem.Reset()
```

C++: `int Reset (IFunctionHandler * pH )`

Resets the item.

docs: y · retail: confirmed (binary, vanilla×81)

### Select

```lua
PickableItem.Select(bool select)
```

Selects/deselects the item.

| Param | Description |
|---|---|
| bool select | True to select, false to deselect. |

docs: y · retail: confirmed (binary)

### SetExtensionActivation

```lua
PickableItem.SetExtensionActivation(const char * extension, bool activation)
```

Activates/deactivates an extension.

| Param | Description |
|---|---|
| const char * extension | Extension name. |
| bool activation | True to activate, false to deactivate. |

docs: y · retail: unconfirmed

### SetExtensionParams

```lua
PickableItem.SetExtensionParams(const char * extension, SmartScriptTable params)
```

Sets extension parameters.

| Param | Description |
|---|---|
| const char * extension | Extension name. |
| SmartScriptTable params | Extension parameters. |

docs: y · retail: confirmed (binary, vanilla×2)

### SetMountedAngleLimits

```lua
PickableItem.SetMountedAngleLimits(float min_pitch, float max_pitch, float yaw_range)
```

Sets the mounted angle limits (yaw-pitch).

| Param | Description |
|---|---|
| float min_pitch | Minimum pitch angle value. |
| float max_pitch | Maximum pitch angle value. |
| float yaw_range | Yaw range value. |

docs: y · retail: confirmed (vanilla×2)

### SetPhase

```lua
PickableItem.SetPhase()
```

C++: `int SetPhase (IFunctionHandler* pH , float phase )`

Sets phase of this objects and reload its mode. Phase relative from 0 to 1.

docs: y · retail: unconfirmed

### SetPhaseById

```lua
PickableItem.SetPhaseById()
```

C++: `int SetPhaseById (IFunctionHandler* pH , uint id )`

Sets phase of this objects by phase id and reload its model. Id is absolute phase from 0 to max phases. Max phases needs to be known from DB.

docs: y · retail: unconfirmed

### StartUse

```lua
PickableItem.StartUse(ScriptHandle userId)
```

The specified user now will start to use the item.

| Param | Description |
|---|---|
| ScriptHandle userId | User identifier. |

docs: y · retail: confirmed (binary, vanilla×1)

### StopUse

```lua
PickableItem.StopUse(ScriptHandle userId)
```

The specified user now will stop to use the item.

| Param | Description |
|---|---|
| ScriptHandle userId | User identifier. |

docs: y · retail: confirmed (binary, vanilla×2)

### Use

```lua
PickableItem.Use(ScriptHandle userId)
```

The specified user now will use the item.

| Param | Description |
|---|---|
| ScriptHandle userId | User identifier. |

docs: y · retail: confirmed (vanilla×4)
