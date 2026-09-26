# Shop

C++ class(es): `C_ScriptBindShop`, `C_ScriptBind_Shop`
Reached from Lua as `Shop.FunctionName(...)`.
22 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### AcceptTransaction

```lua
Shop.AcceptTransaction()
```

C++: `int AcceptTransaction (IFunctionHandler * pH , ScriptHandle entityId , float priceMod )`

docs: y · retail: confirmed (binary)

### AcquireShop

```lua
Shop.AcquireShop()
```

C++: `int AcquireShop (IFunctionHandler * pH , int shopDBId , ScriptHandle entityId )`

docs: y · retail: unconfirmed

### AquireShop

```lua
Shop.AquireShop()
```

C++: `int AquireShop (IFunctionHandler * pH , int shopDBId , ScriptHandle entityId )`

docs: y · retail: unconfirmed

### CancelTransaction

```lua
Shop.CancelTransaction()
```

C++: `int CancelTransaction (IFunctionHandler * pH , ScriptHandle entityId )`

docs: y · retail: confirmed (binary)

### CloseShop

```lua
Shop.CloseShop()
```

C++: `int CloseShop (IFunctionHandler * pH , int shopDBId )`

docs: y · retail: unconfirmed

### EnableRestockingOnOpen

```lua
Shop.EnableRestockingOnOpen()
```

C++: `int EnableRestockingOnOpen (IFunctionHandler * pH , int shopDBId , bool enable )`

docs: y · retail: unconfirmed

### FindItemInShop

```lua
Shop.FindItemInShop()
```

C++: `int FindItemInShop (IFunctionHandler * pH , ScriptHandle entityId )`

Looks for item in owned shop and returns inventory slot for this item (or same one)

docs: y · retail: confirmed (binary)

### FindShopInventoryForItem

```lua
Shop.FindShopInventoryForItem()
```

C++: `int FindShopInventoryForItem (IFunctionHandler * pH , ScriptHandle entityId )`

Looks for shop's inventory id where this item belongs to

docs: y · retail: confirmed (binary)

### GetBusinessHoursBegin

```lua
Shop.GetBusinessHoursBegin()
```

C++: `int GetBusinessHoursBegin (IFunctionHandler * pH , int shopDBId )`

returns float

docs: y · retail: unconfirmed

### GetBusinessHoursEnd

```lua
Shop.GetBusinessHoursEnd()
```

C++: `int GetBusinessHoursEnd (IFunctionHandler * pH , int shopDBId )`

returns float

docs: y · retail: unconfirmed

### GetShopDBIdByKeeper

```lua
Shop.GetShopDBIdByKeeper()
```

C++: `int GetShopDBIdByKeeper (IFunctionHandler * pH , ScriptHandle entityId )`

returns shop DB Id. Returns -1 in case entity is not shopkeeper

docs: y · retail: confirmed (binary)

### GetShopDBIdByLinkedEntityId

```lua
Shop.GetShopDBIdByLinkedEntityId()
```

C++: `int GetShopDBIdByLinkedEntityId (IFunctionHandler * pH , ScriptHandle entityId )`

returns shop DB Id. Returns -1 in case entity is linked to no shop

docs: y · retail: confirmed (binary)

### GetShopMoney

```lua
Shop.GetShopMoney()
```

C++: `int GetShopMoney (IFunctionHandler * pH , ScriptHandle entityId )`

docs: y · retail: confirmed (binary)

### IsLinkedWithShop

```lua
Shop.IsLinkedWithShop()
```

C++: `int IsLinkedWithShop (IFunctionHandler * pH , ScriptHandle entityId )`

WH_CTSW(WH_CTSW_EDITOR)

docs: y · retail: confirmed (binary)

### IsShopOpened

```lua
Shop.IsShopOpened()
```

C++: `int IsShopOpened (IFunctionHandler* pH , ScriptHandle linkedEntityId )`

Finds shop by the linkedEntity (stash) and returns true if it is opened. False if it is closed or not a shop's linked entity.

docs: y · retail: confirmed (binary)

### OnPropertyChange

```lua
Shop.OnPropertyChange()
```

C++: `int OnPropertyChange (IFunctionHandler * pH , int shopDBId , ScriptHandle entityId )`

needed by editor

docs: y · retail: confirmed (runtime dump, vanilla×113)

### OpenInventory

```lua
Shop.OpenInventory()
```

C++: `int OpenInventory (IFunctionHandler * pH )`

docs: y · retail: confirmed (vanilla×3)

### OpenInventoryForItem

```lua
Shop.OpenInventoryForItem()
```

C++: `int OpenInventoryForItem (IFunctionHandler * pH , framework::T_WUIDScriptType itemId )`

This is OpenInventoryForItem, a member of class C_ScriptBindShop.

docs: y · retail: confirmed (binary)

### OpenShop

```lua
Shop.OpenShop()
```

C++: `int OpenShop (IFunctionHandler * pH , int shopDBId )`

docs: y · retail: unconfirmed

### ReleaseShop

```lua
Shop.ReleaseShop()
```

C++: `int ReleaseShop (IFunctionHandler * pH , int shopDBId )`

needed by editor

docs: y · retail: unconfirmed

### RestockShop

```lua
Shop.RestockShop()
```

C++: `int RestockShop (IFunctionHandler * pH , int shopDBId , bool clean )`

docs: y · retail: unconfirmed

### SetShopModule

```lua
Shop.SetShopModule()
```

C++: `void SetShopModule (C_ShopModule&)`

This is SetShopModule, a member of class C_ScriptBindShop.

docs: y · retail: unconfirmed
