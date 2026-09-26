# Variables

C++ class(es): `C_ScriptBindVariables`
Reached from Lua as `Variables.FunctionName(...)`.
11 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### CreateContext

```lua
Variables.CreateContext()
```

C++: `int CreateContext (IFunctionHandler * pH , char const * name )`

returns Id of context

docs: y · retail: confirmed (binary, runtime dump)

### DecrementGlobal

```lua
Variables.DecrementGlobal()
```

C++: `int DecrementGlobal (IFunctionHandler * pH , char const * name )`

docs: y · retail: confirmed (binary, runtime dump)

### DecrementLocal

```lua
Variables.DecrementLocal()
```

C++: `int DecrementLocal (IFunctionHandler * pH , char const * name , int contextId )`

docs: y · retail: confirmed (binary, runtime dump)

### DestroyContext

```lua
Variables.DestroyContext()
```

C++: `int DestroyContext (IFunctionHandler * pH , int contextId )`

docs: y · retail: confirmed (binary, runtime dump)

### DiscardContextVariables

```lua
Variables.DiscardContextVariables()
```

C++: `int DiscardContextVariables (IFunctionHandler * pH , int contextId )`

docs: y · retail: confirmed (binary, runtime dump)

### GetGlobal

```lua
Variables.GetGlobal()
```

C++: `int GetGlobal (IFunctionHandler * pH , char const * name )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×30 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Debug/CombatDebug.lua`))

### GetLocal

```lua
Variables.GetLocal()
```

C++: `int GetLocal (IFunctionHandler * pH , char const * name , int contextId )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/GameUtils.lua`))

### IncrementGlobal

```lua
Variables.IncrementGlobal()
```

C++: `int IncrementGlobal (IFunctionHandler * pH , char const * name )`

docs: y · retail: confirmed (binary, runtime dump)

### IncrementLocal

```lua
Variables.IncrementLocal()
```

C++: `int IncrementLocal (IFunctionHandler * pH , char const * name , int contextId )`

docs: y · retail: confirmed (binary, runtime dump)

### SetGlobal

```lua
Variables.SetGlobal()
```

C++: `int SetGlobal (IFunctionHandler * pH , char const * name , T_ExpressionValueType newValue )`

docs: y · retail: confirmed (runtime dump, vanilla×49 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Debug/CombatDebug.lua`))

### SetLocal

```lua
Variables.SetLocal()
```

C++: `int SetLocal (IFunctionHandler * pH , char const * name , int contextId , T_ExpressionValueType newValue )`

docs: y · retail: confirmed (runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/DialogUtils.lua`))
