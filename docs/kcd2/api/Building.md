# Building

C++ class(es): `C_ScriptBind_Building`
Reached from Lua as `Building.FunctionName(...)`.
5 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### BindToModule

```lua
Building.BindToModule()
```

C++: `void BindToModule (C_WorldSimModule* pLink )`

docs: y · retail: unconfirmed

### OnDestroy

```lua
Building.OnDestroy()
```

C++: `int OnDestroy (IFunctionHandler * pH , int buildingId )`

needed by editor

docs: y · retail: confirmed (vanilla×11)

### OnPropertyChange

```lua
Building.OnPropertyChange()
```

C++: `int OnPropertyChange (IFunctionHandler * pH , ScriptHandle entityId , int productionPeriod , int requestPeriod , bool asap , int requestBoost , char const * category )`

needed by editor

if !WH_CTSW(WH_CTSW_MASTER)

docs: y · retail: confirmed (vanilla×113)

### OnSpawn

```lua
Building.OnSpawn()
```

C++: `int OnSpawn (IFunctionHandler * pH , ScriptHandle entityId , int productionPeriod , int requestPeriod , bool asap , int requestBoost , char const * category )`

docs: y · retail: confirmed (vanilla×75, mod×4)

### OnStart

```lua
Building.OnStart()
```

C++: `int OnStart (IFunctionHandler * pH , bool )`

docs: y · retail: unconfirmed
