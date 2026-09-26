# Trace

C++ class(es): `C_ScriptBindTrace`, `C_ScriptBind_Trace`
Reached from Lua as `Trace.FunctionName(...)`.
7 documented function(s); 8 additional undocumented function(s) found in retail/runtime.

## Functions

### GetMemoryUsage

```lua
Trace.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer * pSizer ) const`

This is GetMemoryUsage, a member of class C_ScriptBind_Trace.

docs: y · retail: unconfirmed

### Msg

```lua
Trace.Msg()
```

C++: `int Msg (IFunctionHandler * h , int level , const char * msg )`

This is Msg, a member of class C_ScriptBindTrace.

docs: y · retail: confirmed (runtime dump)

### PlotXY

```lua
Trace.PlotXY(level, x, y, tag)
```

C++: `int PlotXY (IFunctionHandler * pH , int level , float x , float y , char const * tag )`

docs: y · retail: confirmed (runtime dump)

### RegisterGlobals

```lua
Trace.RegisterGlobals()
```

C++: `void RegisterGlobals ()`

This is RegisterGlobals, a member of class C_ScriptBindTrace.

docs: y · retail: unconfirmed

### RegisterMethods

```lua
Trace.RegisterMethods()
```

C++: `void RegisterMethods ()`

This is RegisterMethods, a member of class C_ScriptBindTrace.

docs: y · retail: unconfirmed

### TableXY

```lua
Trace.TableXY()
```

C++: `int TableXY (IFunctionHandler * pH , int level , float x , float y , char const * msg )`

This is TableXY, a member of class C_ScriptBind_Trace.

docs: y · retail: confirmed (runtime dump)

### TRACELEVEL_ENUM

```lua
Trace.TRACELEVEL_ENUM()
```

C++: `TRACELEVEL_ENUM (FW_TRACE_DEF_LVL_MSG)`

This is TRACELEVEL_ENUM, a member of class C_ScriptBindTrace.

docs: y · retail: unconfirmed

## Undocumented (present in retail, not in official docs)

### Brutus

`Trace.Brutus(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump)

### Debug

`Trace.Debug(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump)

### Detail

`Trace.Detail(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump)

### Error

`Trace.Error(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×3 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Debug/DebugUtils.lua`))

### Fatal

`Trace.Fatal(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump)

### Info

`Trace.Info(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Debug/DebugUtils.lua`))

### max_trace_level

`Trace.max_trace_level(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump)

### Warning

`Trace.Warning(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Debug/DebugUtils.lua`))
