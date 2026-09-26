# SmartObject

C++ class(es): `C_ScriptBindSmartObject`, `C_ScriptBind_SmartObject`
Reached from Lua as `SmartObject.FunctionName(...)`.
7 documented function(s); 5 additional undocumented function(s) found in retail/runtime.

## Functions

### AttachTo

```lua
SmartObject.AttachTo()
```

C++: `void AttachTo (C_SmartObject* pObject )`

docs: y · retail: unconfirmed

### BindToModule

```lua
SmartObject.BindToModule()
```

C++: `void BindToModule (C_XGenAIModule* pLink )`

docs: y · retail: unconfirmed

### GetHelperLinks

```lua
SmartObject.GetHelperLinks()
```

C++: `int GetHelperLinks (IFunctionHandler * pH , char const * helperName )`

docs: y · retail: confirmed (binary)

### GetHelperLinkTarget

```lua
SmartObject.GetHelperLinkTarget()
```

C++: `int GetHelperLinkTarget (IFunctionHandler * pH , char const * helperName , char const * linkName )`

docs: y · retail: confirmed (binary)

### GetHelpers

```lua
SmartObject.GetHelpers()
```

C++: `int GetHelpers (IFunctionHandler * pH )`

Smart object helpers related methods

docs: y · retail: confirmed (binary)

### GetHelpersCategory

```lua
SmartObject.GetHelpersCategory()
```

C++: `int GetHelpersCategory (IFunctionHandler * pH , char const * categoryName )`

docs: y · retail: confirmed (binary)

### GetHelperUserData

```lua
SmartObject.GetHelperUserData()
```

C++: `int GetHelperUserData (IFunctionHandler * pH , char const * helperName , char const * userDataKey )`

docs: y · retail: confirmed (binary)

## Undocumented (present in retail, not in official docs)

### Event_Used

`SmartObject.Event_Used(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### OnInit

`SmartObject.OnInit(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×66)

### OnNavigationStarted

`SmartObject.OnNavigationStarted(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### OnReset

`SmartObject.OnReset(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×162, mod×2)

### OnUsed

`SmartObject.OnUsed(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×36, mod×1)
