# Stash

C++ class(es): `C_ScriptBindStash`
Reached from Lua as `Stash.FunctionName(...)`.
6 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### AttachTo

```lua
Stash.AttachTo()
```

C++: `virtual void AttachTo (C_Stash* stash )`

docs: y · retail: unconfirmed

### DumpItemsToWorld

```lua
Stash.DumpItemsToWorld()
```

C++: `virtual int DumpItemsToWorld (IFunctionHandler* pH )`

docs: y · retail: confirmed (vanilla×1)

### GetStash

```lua
Stash.GetStash()
```

C++: `C_Stash* GetStash (IFunctionHandler* pH )`

docs: y · retail: unconfirmed

### ReportClosed

```lua
Stash.ReportClosed()
```

C++: `virtual int GetMasterInventory (IFunctionHandler * pH )`

If this stash is shared, returns id of master inventory. Returns invalid wuid otherwise.

docs: y · retail: confirmed (vanilla×2)

### ReportOpened

```lua
stash.ReportOpened()
```

C++: `virtual int ReportOpened (IFunctionHandler* pH )`

Should be called when the stash is opened.

docs: y · retail: confirmed (vanilla×2)

### ReportUnlocked

```lua
stash.ReportUnlocked()
```

C++: `virtual int ReportUnlocked (IFunctionHandler* pH )`

Should be called when the stash is unlocked.

docs: y · retail: confirmed (vanilla×3)
