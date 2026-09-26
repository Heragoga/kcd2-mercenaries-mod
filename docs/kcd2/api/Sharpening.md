# Sharpening

C++ class(es): `C_ScriptBind_Sharpening`
Reached from Lua as `Sharpening.FunctionName(...)`.
14 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### DoStepOnGrindstone

```lua
Sharpening.DoStepOnGrindstone()
```

C++: `virtual int DoStepOnGrindstone (IFunctionHandler * pH , ScriptHandle userId )`

Perform single step on grindstone, use SetWheelSpeed() for constant speed and automatic pedalling.

docs: y · retail: confirmed (runtime dump)

### GetTotalQuality

```lua
Sharpening.GetTotalQuality()
```

Get current health of the weapon. Range . 1 is best.

| Param | Description |
|---|---|
| user | entity id of sharpening player |

docs: y · retail: confirmed (runtime dump)

### GetWheelSpeed

```lua
Sharpening.GetWheelSpeed()
```

Returns current wheel speed of the grindstone on which is sharpening performed. Range .

| Param | Description |
|---|---|
| user | entity id of sharpening player |

docs: y · retail: confirmed (runtime dump)

### IsActive

```lua
Sharpening.IsActive(user)
```

Returns sharpening state. True after StartSharpening and false after StopSharpening.

| Param | Description |
|---|---|
| user | entity id of sharpening player |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### MoveToWorstZone

```lua
Sharpening.MoveToWorstZone()
```

Moves to worst sharpened zone or stay on same position, if weapon is sharpened evenly.

| Param | Description |
|---|---|
| user | entity id of sharpening player |

docs: y · retail: confirmed (runtime dump)

### OpenInventory

```lua
Sharpening.OpenInventory(EntityId user, EntityId grindstone)
```

Opens inventory for selecting weapon for sharpening.

| Param | Description |
|---|---|
| ScriptHandle grindstoneId | entity id of grindstone on which human will sharpen |
| user | entity id of sharpening player |

docs: y · retail: confirmed (vanilla×3)

### SetGrindstone

```lua
Sharpening.SetGrindstone(EntityId entityId)
```

Sets which grindstone will be used for sharpening.

| Param | Description |
|---|---|
| ScriptHandle entityId | EntityId of selected grindstone |
| user | entity id of sharpening player |

docs: y · retail: confirmed (runtime dump)

### SetOptimalRotation

```lua
Sharpening.SetOptimalRotation()
```

Sets optimal rotation on which weapon is sharpened correctly.

| Param | Description |
|---|---|
| user | entity id of sharpening player |

docs: y · retail: confirmed (runtime dump)

### SetPosition

```lua
Sharpening.SetPosition(float value)
```

Weapon will slowly move to desired position.

| Param | Description |
|---|---|
| float value | position, range from left to right |
| user | entity id of sharpening player |

docs: y · retail: confirmed (runtime dump)

### SetPressure

```lua
Sharpening.SetPressure(float value)
```

Set sharpening pressure, more pressure requires more energy but increases sharpening efficiency.

| Param | Description |
|---|---|
| float value | pressure, range |
| user | entity id of sharpening player |

docs: y · retail: confirmed (runtime dump)

### SetRotation

```lua
Sharpening.SetRotation(float value)
```

Weapon will slowly move to desired rotation, use SetOptimalRotation() to sharpen weapon correctly

| Param | Description |
|---|---|
| float value | position, range from left to right |
| user | entity id of sharpening player |

docs: y · retail: confirmed (binary, runtime dump)

### SetWheelSpeed

```lua
Sharpening.SetWheelSpeed(float value)
```

Sets speed of grindstone wheel on which is sharpening performed.

| Param | Description |
|---|---|
| float value | speed of the grindstone wheel, range |
| user | entity id of sharpening player |

docs: y · retail: confirmed (runtime dump)

### Start

```lua
Sharpening.Start(EntityId grindstoneId, int itemId)
```

Starts sharpening weapon with selected inventory item on selected grindstone.

| Param | Description |
|---|---|
| ScriptHandle grindstoneId | entity id of grindstone on which human will sharpen |
| framework | :T_WUIDScriptType itemId inventory index of weapon for sharpening |
| user | entity id of sharpening player |

docs: y · retail: confirmed (runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Minigames/Grindstone.lua`))

### Stop

```lua
Sharpening.Stop()
```

Stops sharpening, reseting state of the grindstone and setting new health to the weapon according to the results of sharpening.

| Param | Description |
|---|---|
| user | entity id of sharpening player |

docs: y · retail: confirmed (runtime dump, vanilla×22)
