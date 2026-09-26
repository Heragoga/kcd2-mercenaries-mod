# InteractionPoint

C++ class(es): `C_ScriptBind_InteractionPoint`
Reached from Lua as `InteractionPoint.FunctionName(...)`.
6 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### BindToModule

```lua
InteractionPoint.BindToModule()
```

C++: `void BindToModule (C_WorldSimModule* pLink )`

docs: y · retail: unconfirmed

### OnDestroy

```lua
InteractionPoint.OnDestroy()
```

C++: `int OnDestroy (IFunctionHandler * pH , int buildingId )`

needed by editor

docs: y · retail: confirmed (vanilla×11)

### OnPropertyChange

```lua
InteractionPoint.OnPropertyChange()
```

C++: `int OnPropertyChange (IFunctionHandler * pH , ScriptHandle entityId , char const * iotype , char const * goods , int min , int max , float dia , const char * boxType , int maxBoxes )`

needed by editor

if !WH_CTSW(WH_CTSW_MASTER)

docs: y · retail: confirmed (vanilla×113)

### OnSpawn

```lua
InteractionPoint.OnSpawn()
```

C++: `int OnSpawn (IFunctionHandler * pH , ScriptHandle entityId , char const * iotype , char const * goods , int min , int max , float dia , const char * boxType , int maxBoxes )`

docs: y · retail: confirmed (vanilla×75, mod×4)

### OnStart

```lua
InteractionPoint.OnStart()
```

C++: `int OnStart (IFunctionHandler * pH , bool )`

docs: y · retail: unconfirmed

### SignalDeliveryEvent

```lua
InteractionPoint.SignalDeliveryEvent()
```

C++: `int SignalDeliveryEvent (IFunctionHandler * pH , EntityId walkerId , int eventId )`

docs: y · retail: unconfirmed
