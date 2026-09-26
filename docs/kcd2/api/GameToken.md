# GameToken

C++ class(es): `CScriptBind_GameToken`
Reached from Lua as `GameToken.FunctionName(...)`.
5 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### DumpAllTokens

```lua
GameToken.DumpAllTokens()
```

C++: `int DumpAllTokens (IFunctionHandler* pH )`

docs: y · retail: confirmed (runtime dump)

### GetMemoryUsage

```lua
GameToken.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer* pSizer ) const`

This is GetMemoryUsage, a member of class CScriptBind_GameToken.

docs: y · retail: unconfirmed

### GetToken

```lua
GameToken.GetToken(TokenName)
```

C++: `int GetToken (IFunctionHandler* pH , const char * sTokenName )`

Get the value of a game token.

docs: y · retail: confirmed (runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/GameRules/SinglePlayer.lua`))

### Release

```lua
GameToken.Release()
```

C++: `void Release ()`

This is Release, a member of class CScriptBind_GameToken.

docs: y · retail: unconfirmed

### SetToken

```lua
GameToken.SetToken(TokenName, TokenValue)
```

C++: `int SetToken (IFunctionHandler* pH )`

Set the value of a game token.

docs: y · retail: confirmed (runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/GameRules/SinglePlayer.lua`))
