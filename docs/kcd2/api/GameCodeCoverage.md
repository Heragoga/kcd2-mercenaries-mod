# GameCodeCoverage

C++ class(es): `C_ScriptBindGameCodeCoverage`, `C_ScriptBind_GameCodeCoverage`
Reached from Lua as `GameCodeCoverage.FunctionName(...)`.
8 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### CheckNumCCCPointHits

```lua
GameCodeCoverage.CheckNumCCCPointHits()
```

C++: `int CheckNumCCCPointHits (IFunctionHandler * pH , char const * name )`

docs: y · retail: unconfirmed

### EnableReportUnwatched

```lua
GameCodeCoverage.EnableReportUnwatched()
```

C++: `int EnableReportUnwatched (IFunctionHandler * pH , bool enable )`

docs: y · retail: unconfirmed

### GetMemoryUsage

```lua
GameCodeCoverage.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer * pSizer ) const`

This is GetMemoryUsage, a member of class C_ScriptBind_GameCodeCoverage.

docs: y · retail: unconfirmed

### Reset

```lua
GameCodeCoverage.Reset()
```

C++: `int Reset (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, vanilla×81)

### ResetCCCPointHitCounters

```lua
GameCodeCoverage.ResetCCCPointHitCounters()
```

C++: `int ResetCCCPointHitCounters (IFunctionHandler * pH , char const * name )`

docs: y · retail: unconfirmed

### SCCPOINT

```lua
GameCodeCoverage.SCCPOINT()
```

C++: `int SCCPOINT (IFunctionHandler* pH , char const * name )`

docs: y · retail: unconfirmed

### SCCPOINTID

```lua
GameCodeCoverage.SCCPOINTID()
```

C++: `int SCCPOINTID (IFunctionHandler* pH , char const * name , int userIdx )`

Same as SCCPOINT but will pas one additional user index to callback.

docs: y · retail: unconfirmed

### WatchCCCPoint

```lua
GameCodeCoverage.WatchCCCPoint()
```

C++: `int WatchCCCPoint (IFunctionHandler * pH , char const * name , SmartScriptTable table )`

docs: y · retail: unconfirmed
