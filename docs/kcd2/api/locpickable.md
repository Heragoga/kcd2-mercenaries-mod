# locpickable

C++ class(es): `C_ScriptBindLockBase`
Reached from Lua as `locpickable.FunctionName(...)`.
4 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### PlayerHoldsKey

```lua
locpickable.PlayerHoldsKey()
```

Returns whether the player has a key that matches this lock

| Param | Description |
|---|---|
| char const* keyClassIdText | key class GUID. |

docs: y · retail: confirmed (vanilla×7)

### ReportLocked

```lua
locpickable.ReportLocked()
```

C++: `virtual int ReportLocked (IFunctionHandler* pH )`

Should be called when the lock is locked.

docs: y · retail: confirmed (vanilla×3)

### ReportLockpickeded

```lua
locpickable.ReportLockpickeded()
```

C++: `virtual int ReportLockpicked (IFunctionHandler* pH )`

Should be called when the lock is lockpicked.

docs: y · retail: unconfirmed

### ReportUnlocked

```lua
locpickable.ReportUnlocked()
```

C++: `virtual int ReportUnlocked (IFunctionHandler* pH )`

Should be called when the lock is unlocked.

docs: y · retail: confirmed (vanilla×3)
