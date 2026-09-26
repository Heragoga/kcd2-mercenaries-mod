# GameStatistics

C++ class(es): `CScriptBindGameStatistics`, `CScriptBind_GameStatistics`
Reached from Lua as `GameStatistics.FunctionName(...)`.
10 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### AddGameElement

```lua
GameStatistics.AddGameElement(scopeID, elementID, locatorID, locatorValue [, table])
```

C++: `virtual int AddGameElement (IFunctionHandler * pH )`

Adds a game element to specified scope.

Syntax: GameStatistics.AddGameElement( scopeID, elementID, locatorID, locatorValue, table )

docs: y · retail: unconfirmed

### BindTracker

```lua
GameStatistics.BindTracker(name, tracker)
```

C++: `bool BindTracker (IScriptTable* pT , const char * name , IStatsTracker* tracker )`

docs: y · retail: unconfirmed

### CurrentScope

```lua
GameStatistics.CurrentScope()
```

C++: `virtual int CurrentScope (IFunctionHandler * pH )`

Returns the ID of current scope, -1 if stack is empty.

docs: y · retail: unconfirmed

### Event

```lua
GameStatistics.Event()
```

C++: `virtual int Event (IFunctionHandler* pH )`

docs: y · retail: confirmed (binary)

### GetMemoryUsage

```lua
GameStatistics.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer* pSizer ) const`

This is GetMemoryUsage, a member of class CScriptBind_GameStatistics.

docs: y · retail: unconfirmed

### PopGameScope

```lua
GameStatistics.PopGameScope([checkScopeId])
```

Removes the scope from the top of the stack.

| Param | Description |
|---|---|
| checkScopeId | (optional) |

docs: y · retail: unconfirmed

### PushGameScope

```lua
GameStatistics.PushGameScope(scopeID)
```

Pushes a scope on top of the stack.

| Param | Description |
|---|---|
| int scopeID | identifier of the scope to be placed on top of the stack. |

docs: y · retail: unconfirmed

### RemoveGameElement

```lua
GameStatistics.RemoveGameElement(scopeID, elementID, locatorID, locatorValue)
```

C++: `virtual int RemoveGameElement (IFunctionHandler * pH )`

Removes element from the specified scope if data parameters match.

Syntax: GameStatistics.RemoveGameElement( scopeID, elementID, locatorID, locatorValue )

docs: y · retail: unconfirmed

### StateValue

```lua
GameStatistics.StateValue()
```

C++: `virtual int StateValue (IFunctionHandler* pH )`

docs: y · retail: unconfirmed

### UnbindTracker

```lua
GameStatistics.UnbindTracker(name, tracker)
```

C++: `bool UnbindTracker (IScriptTable* pT , const char * name , IStatsTracker* tracker )`

docs: y · retail: unconfirmed
