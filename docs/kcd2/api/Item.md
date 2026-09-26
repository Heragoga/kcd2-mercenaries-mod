# Item

C++ class(es): `C_ScriptBindPickableItem`, `C_ScriptBind_Item`, `C_ScriptBind_PickableItem`
Reached from Lua as `Item.FunctionName(...)`.
32 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### AttachTo

```lua
Item.AttachTo()
```

C++: `void AttachTo (C_Item * pItem )`

docs: y · retail: unconfirmed

### CanPickUp

```lua
Item.CanPickUp(ScriptHandle userId)
```

Checks if the item can be picked up by the user.

| Param | Description |
|---|---|
| ScriptHandle userId | User identifier. |

docs: y · retail: confirmed (binary, vanilla×1)

### CanUse

```lua
Item.CanUse(ScriptHandle userId)
```

Checks if the item can be used by the user.

| Param | Description |
|---|---|
| ScriptHandle userId | User identifier. |

docs: y · retail: confirmed (binary, vanilla×4)

### GetExtensionParams

```lua
Item.GetExtensionParams(const char *extension, SmartScriptTable params)
```

Gets extension parameters.

| Param | Description |
|---|---|
| const char * extension | Extension name. |
| SmartScriptTable params | Extension parameters. |

docs: y · retail: confirmed (binary)

### GetHealth

```lua
Item.GetHealth()
```

C++: `int GetHealth (IFunctionHandler * pH )`

Gets item health.

docs: y · retail: confirmed (vanilla×4, mod×6)

### GetId

```lua
Item.GetId()
```

C++: `int GetId (IFunctionHandler * pH )`

Gets item id

docs: y · retail: confirmed (binary, vanilla×2, mod×12)

### GetMaxHealth

```lua
Item.GetMaxHealth()
```

C++: `int GetMaxHealth (IFunctionHandler * pH )`

Gets the maximum item health.

docs: y · retail: confirmed (vanilla×1, mod×12)

### GetMountedAngleLimits

```lua
Item.GetMountedAngleLimits()
```

C++: `int GetMountedAngleLimits (IFunctionHandler * pH )`

Gets the mounted angle limits for the item.

docs: y · retail: confirmed (binary)

### GetMountedDir

```lua
Item.GetMountedDir()
```

C++: `int GetMountedDir (IFunctionHandler * pH )`

Gets the mounted direction for the item.

docs: y · retail: confirmed (binary)

### GetOwnerId

```lua
Item.GetOwnerId()
```

C++: `int GetOwnerId (IFunctionHandler * pH )`

Gets the identifier of the item's owner.

docs: y · retail: confirmed (binary)

### GetParams

```lua
Item.GetParams()
```

C++: `int GetParams (IFunctionHandler * pH )`

Gets the item parameters.

docs: y · retail: unconfirmed

### GetStats

```lua
Item.GetStats()
```

C++: `int GetStats (IFunctionHandler * pH )`

Gets the item statistics.

docs: y · retail: confirmed (binary)

### GetUIName

```lua
Item.GetUIName()
```

C++: `int GetUIName (IFunctionHandler * pH )`

Gets the UI name.

docs: y · retail: confirmed (binary, vanilla×3)

### IsDestroyed

```lua
Item.IsDestroyed()
```

C++: `int IsDestroyed (IFunctionHandler * pH )`

Event that occurs when the item is destroyed.

docs: y · retail: confirmed (binary, vanilla×2)

### IsFromShop

```lua
Item.IsFromShop()
```

C++: `int IsFromShop (IFunctionHandler* pH )`

Returns true if the item is owner by some shop and can be bought instead of picked

docs: y · retail: confirmed (binary, vanilla×1)

### IsMounted

```lua
Item.IsMounted()
```

C++: `int IsMounted (IFunctionHandler * pH )`

Checks if the item is mounted.

docs: y · retail: confirmed (binary, vanilla×1, mod×5)

### IsOversized

```lua
Item.IsOversized()
```

C++: `int IsOversized (IFunctionHandler * pH )`

Returns true if the item is too big to be picket up

docs: y · retail: confirmed (binary)

### IsUsed

```lua
Item.IsUsed()
```

C++: `int IsUsed (IFunctionHandler * pH )`

Checks if the item is used.

docs: y · retail: confirmed (binary)

### OnHit

```lua
Item.OnHit(SmartScriptTable hitTable)
```

Events that occurs when the item is hit.

| Param | Description |
|---|---|
| SmartScriptTable hitTable | Table with the hit values. |

docs: y · retail: confirmed (vanilla×16)

### OnUsed

```lua
Item.OnUsed(ScriptHandle userId)
```

Events that occurs when the item is used.

| Param | Description |
|---|---|
| ScriptHandle userId | User identifier. |

docs: y · retail: confirmed (binary, vanilla×38 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Items/Item.lua`), mod×1)

### PlayAction

```lua
Item.PlayAction(const char *actionName)
```

Plays the specified action.

| Param | Description |
|---|---|
| const char * actionName | Action name. |

docs: y · retail: unconfirmed

### PlayAnimation

```lua
Item.PlayAnimation(const char *animationName)
```

Plays the specified animation.

| Param | Description |
|---|---|
| animationName | Animation name. |

docs: y · retail: unconfirmed

### Quiet

```lua
Item.Quiet()
```

C++: `int Quiet (IFunctionHandler * pH )`

Quiets the item.

docs: y · retail: unconfirmed

### Reset

```lua
Item.Reset()
```

C++: `int Reset (IFunctionHandler * pH )`

Resets the item.

docs: y · retail: confirmed (binary, vanilla×81)

### Select

```lua
Item.Select(bool select)
```

Selects/deselects the item.

| Param | Description |
|---|---|
| bool select | True to select, false to deselect. |

docs: y · retail: confirmed (binary)

### SetExtensionActivation

```lua
Item.SetExtensionActivation(const char *extension, bool activation)
```

Activates/deactivates an extension.

| Param | Description |
|---|---|
| const char * extension | Extension name. |
| bool activation | True to activate, false to deactivate. |

docs: y · retail: unconfirmed

### SetExtensionParams

```lua
Item.SetExtensionParams(const char *extension, SmartScriptTable params)
```

Sets extension parameters.

| Param | Description |
|---|---|
| const char * extension | Extension name. |
| SmartScriptTable params | Extension parameters. |

docs: y · retail: confirmed (binary, vanilla×2)

### SetMountedAngleLimits

```lua
Item.SetMountedAngleLimits(float min_pitch, float max_pitch, float yaw_range)
```

Sets the mounted angle limits (yaw-pitch).

| Param | Description |
|---|---|
| float min_pitch | Minimum pitch angle value. |
| float max_pitch | Maximum pitch angle value. |
| float yaw_range | Yaw range value. |

docs: y · retail: confirmed (vanilla×2)

### SetSaveFlag

```lua
Item.SetSaveFlag(bool save)
```

Sets or unsets E_IF_NoSaving flag on item. This item won't be saved or loaded (it will keep it's state through load - use with extreme caution). Intended for use only with transcription books

| Param | Description |
|---|---|
| bool preventSaving | true indicates item should not be saved |

docs: y · retail: unconfirmed

### StartUse

```lua
Item.StartUse(ScriptHandle userId)
```

The specified user now will start to use the item.

| Param | Description |
|---|---|
| ScriptHandle userId | User identifier. |

docs: y · retail: confirmed (binary, vanilla×1)

### StopUse

```lua
Item.StopUse(ScriptHandle userId)
```

The specified user now will stop to use the item.

| Param | Description |
|---|---|
| ScriptHandle userId | User identifier. |

docs: y · retail: confirmed (binary, vanilla×2)

### Use

```lua
Item.Use(ScriptHandle userId)
```

The specified user now will use the item.

| Param | Description |
|---|---|
| ScriptHandle userId | User identifier. |

docs: y · retail: confirmed (vanilla×4)
