# MusicLogic

C++ class(es): `CScriptBindMusicLogic`, `CScriptBind_MusicLogic`
Reached from Lua as `MusicLogic.FunctionName(...)`.
5 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### GetMemoryUsage

```lua
MusicLogic.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer* pSizer ) const`

This is GetMemoryUsage, a member of class CScriptBind_MusicLogic.

docs: y · retail: unconfirmed

### SendEvent

```lua
MusicLogic.SendEvent(eventName)
```

C++: `int SendEvent (IFunctionHandler* pH , const char * pEventName )`

Send an event to the music logic.

docs: y · retail: unconfirmed

### SetEvent

```lua
MusicLogic.SetEvent(eMusicEvent)
```

Sets an event in the music logic. Available music event ids are:

| Param | Description |
|---|---|
| int eMusicEvent | identifier of a music event. |

docs: y · retail: unconfirmed

### StartLogic

```lua
MusicLogic.StartLogic()
```

C++: `int StartLogic (IFunctionHandler* pH )`

Starts the music logic.

docs: y · retail: unconfirmed

### StopLogic

```lua
MusicLogic.StopLogic()
```

C++: `int StopLogic (IFunctionHandler* pH )`

Stops the music logic.

docs: y · retail: unconfirmed
