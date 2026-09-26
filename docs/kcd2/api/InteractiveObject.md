# InteractiveObject

C++ class(es): `C_ScriptBindInteractiveObject`
Reached from Lua as `InteractiveObject.FunctionName(...)`.
8 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### AbortUse

```lua
InteractiveObject.AbortUse()
```

C++: `int AbortUse (IFunctionHandler * pH )`

This is AbortUse, a member of class C_ScriptBindInteractiveObject.

docs: y · retail: confirmed (vanilla×2)

### AttachTo

```lua
InteractiveObject.AttachTo()
```

C++: `void AttachTo (C_InteractiveObjectEx * pInteractiveObject )`

This is AttachTo, a member of class C_ScriptBindInteractiveObject.

docs: y · retail: unconfirmed

### CanUse

```lua
InteractiveObject.CanUse()
```

C++: `int CanUse (IFunctionHandler * pH , ScriptHandle userId )`

This is CanUse, a member of class C_ScriptBindInteractiveObject.

docs: y · retail: confirmed (binary, vanilla×4)

### Detach

```lua
InteractiveObject.Detach()
```

C++: `void Detach (EntityId entityId )`

This is Detach, a member of class C_ScriptBindInteractiveObject.

docs: y · retail: unconfirmed

### GetMemoryUsage

```lua
InteractiveObject.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer * pSizer ) const`

This is GetMemoryUsage, a member of class C_ScriptBindInteractiveObject.

docs: y · retail: unconfirmed

### GetObjectDataRegistry

```lua
InteractiveObject.GetObjectDataRegistry()
```

C++: `ILINE C_InteractiveObjectRegistry& GetObjectDataRegistry ()`

This is GetObjectDataRegistry, a member of class C_ScriptBindInteractiveObject.

docs: y · retail: unconfirmed

### StopUse

```lua
InteractiveObject.StopUse()
```

C++: `int StopUse (IFunctionHandler * pH , ScriptHandle userId )`

This is StopUse, a member of class C_ScriptBindInteractiveObject.

docs: y · retail: confirmed (binary, vanilla×2)

### Use

```lua
InteractiveObject.Use()
```

C++: `int Use (IFunctionHandler * pH , ScriptHandle userId )`

This is Use, a member of class C_ScriptBindInteractiveObject.

docs: y · retail: confirmed (vanilla×4)
