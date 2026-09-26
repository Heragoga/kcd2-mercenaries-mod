# Framework

C++ class(es): `C_ScriptBindFramework`
Reached from Lua as `Framework.FunctionName(...)`.
6 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### Expr

```lua
Framework.Expr(expression)
```

C++: `int Expr (IFunctionHandler * pH , char const * expression )`

Evaluates expression, output is written to console

docs: y · retail: confirmed (binary, runtime dump)

### IsValidWUID

```lua
Framework.IsValidWUID(wuid)
```

C++: `int IsValidWUID (IFunctionHandler * pH , T_WUIDScriptType wuid )`

Returns true if the argument is not equal to the INVALID_WUID C++ constant.

docs: y · retail: confirmed (binary, runtime dump, vanilla×5 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Stash/AnimStash.lua`), mod×1)

### ScriptHandlerToString

```lua
Framework.ScriptHandlerToString(sriptHandle)
```

Returns string. In case "sriptHandle" is nil the empty string is returned.

| Param | Description |
|---|---|
| sriptHandle | ID of entity, item,... |

docs: y · retail: confirmed (runtime dump)

### WUIDToMsg

```lua
Framework.WUIDToMsg(wuid)
```

C++: `int WUIDToMsg (IFunctionHandler * pH , T_WUIDScriptType wuid )`

Returns string suitable for AI message.

docs: y · retail: confirmed (binary, runtime dump, vanilla×5 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Bed/Bed.lua`))

### WUIDToString

```lua
Framework.WUIDToString(wuid)
```

C++: `int WUIDToString (IFunctionHandler * pH , T_WUIDScriptType wuid )`

Returns more human readable representation of wuid.

docs: y · retail: confirmed (binary, runtime dump)

### WUIDToUI

```lua
Framework.WUIDToUI(wuid)
```

C++: `int WUIDToUI (IFunctionHandler * pH , T_WUIDScriptType wuid )`

Returns wuid representation for UI (string).

docs: y · retail: confirmed (binary, runtime dump)
