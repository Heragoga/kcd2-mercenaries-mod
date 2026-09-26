# CarryItemPile

C++ class(es): `C_ScriptBindCarryItemPile`
Reached from Lua as `CarryItemPile.FunctionName(...)`.
5 documented function(s); 3 additional undocumented function(s) found in retail/runtime.

## Functions

### CanDeposit

```lua
CarryItemPile.CanDeposit()
```

C++: `int CanDeposit (IFunctionHandler* pH , ScriptHandle userId , ScriptHandle pileId )`

docs: y · retail: confirmed (binary)

### CanPackAndPick

```lua
CarryItemPile.CanPackAndPick()
```

C++: `int CanPackAndPick (IFunctionHandler* pH , ScriptHandle userId , ScriptHandle pileId )`

docs: y · retail: confirmed (binary)

### CanPickUp

```lua
CarryItemPile.CanPickUp()
```

C++: `int CanPickUp (IFunctionHandler* pH , ScriptHandle userId , ScriptHandle pileId )`

docs: y · retail: confirmed (binary, vanilla×1)

### Deposit

```lua
CarryItemPile.Deposit()
```

C++: `int Deposit (IFunctionHandler* pH , ScriptHandle userId , ScriptHandle pileId )`

docs: y · retail: confirmed (binary)

### PickUp

```lua
CarryItemPile.PickUp()
```

C++: `int PickUp (IFunctionHandler* pH , ScriptHandle userId , ScriptHandle pileId )`

docs: y · retail: confirmed (binary)

## Undocumented (present in retail, not in official docs)

### GetActions

`CarryItemPile.GetActions(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×35, mod×1)

### OnDeposit

`CarryItemPile.OnDeposit(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### OnPickUp

`CarryItemPile.OnPickUp(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)
