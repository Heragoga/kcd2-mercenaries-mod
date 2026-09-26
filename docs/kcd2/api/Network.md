# Network

C++ class(es): `CScriptBindNetwork`, `CScriptBind_Network`
Reached from Lua as `Network.FunctionName(...)`.
4 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### DelegateAuthority

```lua
Network.DelegateAuthority(ent, channel)
```

Delegate authority for an object to some client.

| Param | Description |
|---|---|
| ScriptHandle ent | Entity identifier. |
| int channel | Network channel. |

docs: y · retail: unconfirmed

### Expose

```lua
Network.Expose()
```

C++: `int Expose (IFunctionHandler * pFH )`

docs: y · retail: confirmed (vanilla×1)

### GetMemoryUsage

```lua
Network.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer* pSizer ) const`

This is GetMemoryUsage, a member of class CScriptBind_Network.

docs: y · retail: unconfirmed

### Release

```lua
Network.Release()
```

C++: `void Release ()`

This is Release, a member of class CScriptBind_Network.

docs: y · retail: unconfirmed
