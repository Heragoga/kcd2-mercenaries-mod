# CarryableItem

C++ class(es): `C_ScriptBindCarryableItem`
Reached from Lua as `CarryableItem.FunctionName(...)`.
4 documented function(s); 12 additional undocumented function(s) found in retail/runtime.

## Functions

### CanPickUp

```lua
CarryableItem.CanPickUp()
```

C++: `int CanPickUp (IFunctionHandler* pH , ScriptHandle userId , ScriptHandle itemEntityId )`

checks if the user is close to the item (wh_ent_CarryItemPileMaxDistance) and is in Idle state

docs: y · retail: confirmed (binary, vanilla×1)

### CanPickUpImpl

```lua
CarryableItem.CanPickUpImpl()
```

C++: `bool CanPickUpImpl (C_Actor& userActor , IEntity& itemEntity )`

docs: y · retail: unconfirmed

### PickUp

```lua
CarryableItem.PickUp()
```

C++: `int PickUp (IFunctionHandler* pH , ScriptHandle userId , ScriptHandle itemEntityId )`

docs: y · retail: confirmed (binary)

### PickUpImpl

```lua
CarryableItem.PickUpImpl()
```

C++: `bool PickUpImpl (C_Actor& userActor , IEntity& itemEntity )`

docs: y · retail: unconfirmed

## Undocumented (present in retail, not in official docs)

### GetActions

`CarryableItem.GetActions(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×35, mod×1)

### GetUsableName

`CarryableItem.GetUsableName(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×6)

### IsCrossCenteringEnabled

`CarryableItem.IsCrossCenteringEnabled(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×6)

### OnEnablePhysics

`CarryableItem.OnEnablePhysics(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×7)

### OnLevelLoaded

`CarryableItem.OnLevelLoaded(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×12)

### OnPickUp

`CarryableItem.OnPickUp(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### OnPropertyChange

`CarryableItem.OnPropertyChange(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×113)

### OnUsed

`CarryableItem.OnUsed(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×36, mod×1)

### OnUsedHold

`CarryableItem.OnUsedHold(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×5)

### PhysicalizeThis

`CarryableItem.PhysicalizeThis(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×50, mod×2)

### SetInteractiveCollisionType

`CarryableItem.SetInteractiveCollisionType(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×36)

### Use

`CarryableItem.Use(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×4)
