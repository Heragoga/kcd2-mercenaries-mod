# Environment

C++ class(es): `C_ScriptBindEnvironment`, `C_ScriptBind_Environment`
Reached from Lua as `Environment.FunctionName(...)`.
4 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### AddPickable

```lua
Environment.AddPickable()
```

C++: `int AddPickable (IFunctionHandler * pH , ScriptHandle entityId )`

docs: y · retail: unconfirmed

### CoverHole

```lua
Environment.CoverHole()
```

C++: `int CoverHole (IFunctionHandler * pH , bool cover , ScriptHandle entityId )`

docs: y · retail: confirmed (binary)

### HidePicked

```lua
Environment.HidePicked()
```

C++: `int HidePicked (IFunctionHandler * pH , int hide , ScriptHandle entityId )`

docs: y · retail: unconfirmed

### MakeHole

```lua
Environment.MakeHole()
```

C++: `int MakeHole (IFunctionHandler * pH , bool make , ScriptHandle entityId )`

int AddPickable(IFunctionHandler *pH, ScriptHandle entityId); int HidePicked(IFunctionHandler *pH, int hide, ScriptHandle entityId);

docs: y · retail: confirmed (binary)
