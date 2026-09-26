# Inventory

C++ class(es): `CScriptBindInventory`, `CScriptBind_Inventory`, `C_ScriptBindInventory`, `C_ScriptBind_Inventory`
Reached from Lua as `Inventory.FunctionName(...)`.
49 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### AddItem

```lua
Inventory.AddItem(ScriptHandle id)
```

C++: `int AddItem (IFunctionHandler * pH )`

Adds item with parameters passed from parameter table: item = { sItemClassId = "0", -- GUID of item class in database sOwnerId = "0", -- GUID of the item owner fHealth = 1, -- 1 is 100% health

docs: y · retail: confirmed (binary, vanilla×19, mod×1)

### AddItemWithId

```lua
Inventory.AddItemWithId(ScriptHandle id)
```

Adds new item with classIdText from DB to the inventory (with default settings).

| Param | Description |
|---|---|
| id | Item class GUID |

docs: y · retail: confirmed (vanilla×1)

### AddItemWithIdWithHealth

```lua
Inventory.AddItemWithIdWithHealth(ScriptHandle id)
```

Adds new item with classIdText from DB to the inventory (with default settings).

| Param | Description |
|---|---|
| int health | Health 0-100 |
| id | Item class GUID |

docs: y · retail: unconfirmed

### AddMoney

```lua
Inventory.AddMoney(5.5)
```

C++: `int AddMoney (IFunctionHandler * pH , float count )`

Adds 5.5 of actual currency.

docs: y · retail: unconfirmed

### AttachTo

```lua
Inventory.AttachTo()
```

C++: `void AttachTo (CInventory* pInventory )`

docs: y · retail: unconfirmed

### Clear

```lua
Inventory.Clear()
```

C++: `int Clear (IFunctionHandler * pH )`

Clears the inventory.

docs: y · retail: confirmed (binary)

### CreateItem

```lua
Inventory.CreateItem()
```

C++: `int CreateItem (IFunctionHandler * pH , char const * classId , float health , int amount )`

Creates item defined by guid and immediately insert it into inventory

Returns: True in case item was successfuly created

docs: y · retail: confirmed (vanilla×3, mod×27)

### DeleteItem

```lua
Inventory.DeleteItem(id)
```

Removes an item from the inventory and deletes it.

| Param | Description |
|---|---|
| framework | :T_WUIDScriptType id item id |
| int count | count of item pieces to delete, use -1 to delete all |

Returns: none

docs: y · retail: confirmed (vanilla×1)

### DeleteItemOfClass

```lua
Inventory.DeleteItemOfClass(classIdText, count)
```

Removes an item from the inventory and deletes it.

| Param | Description |
|---|---|
| char const* classIdText | Item class GUID. |
| int count | count of item pieces to remove, use -1 to remove all |

Returns: Amount of items removed

docs: y · retail: confirmed (vanilla×2, mod×56)

### Destroy

```lua
Inventory.Destroy()
```

C++: `int Destroy (IFunctionHandler * pH )`

Destroys the inventory.

docs: y · retail: confirmed (binary, vanilla×1)

### DetachFrom

```lua
Inventory.DetachFrom()
```

C++: `WH_API_ENTITY_MODULE void DetachFrom (IEntity&)`

This is DetachFrom, a member of class C_ScriptBindInventory.

docs: y · retail: unconfirmed

### Dump

```lua
Inventory.Dump()
```

C++: `int Dump (IFunctionHandler * pH )`

Dumps the inventory.

docs: y · retail: confirmed (binary, vanilla×3)

### FindItem

```lua
Inventory.FindItem(classIdText)
```

Finds an item that matches to class id.

| Param | Description |
|---|---|
| char const* classIdText | Item class GUID. |

docs: y · retail: confirmed (binary, vanilla×13, mod×12)

### FindNext

```lua
Inventory.FindNext(const char *className, const char *category, int firstSlot, bool wrap)
```

Search for the specified class and return the previous one in the inventory with the specific info.

| Param | Description |
|---|---|
| const char * className | Class name. |
| const char * category | Category name. |
| int firstSlot | Number of the first slot. |
| bool wrap | True to wrap, false otherwise. |

docs: y · retail: unconfirmed

### GetAmmoCapacity

```lua
Inventory.GetAmmoCapacity(ammoName)
```

Gets the capacity for the specified ammunition.

| Param | Description |
|---|---|
| const char * ammoName | Ammunition name. |

docs: y · retail: confirmed (binary)

### GetAmmoCount

```lua
Inventory.GetAmmoCount(ammoName)
```

Gets the amount of the specified ammunition name.

| Param | Description |
|---|---|
| const char * ammoName | Ammunition name. |

docs: y · retail: confirmed (binary)

### GetCapacity

```lua
Inventory.GetCapacity()
```

C++: `int GetCapacity (IFunctionHandler * pH )`

Gets the inventory capacity.

docs: y · retail: unconfirmed

### GetCount

```lua
Inventory.GetCount()
```

C++: `int GetCount (IFunctionHandler * pH )`

Gets the number of the inventory elements.

docs: y · retail: confirmed (binary, mod×1)

### GetCountOfCategory

```lua
Inventory.GetCountOfCategory(const char* category)
```

Gets the number of element of the specified category inside the inventory.

| Param | Description |
|---|---|
| category | name of item category. |

docs: y · retail: confirmed (binary)

### GetCountOfClass

```lua
Inventory.GetCountOfClass()
```

Gets the number of element of the specified class inside the inventory.

| Param | Description |
|---|---|
| const char * className | Object class name. |

docs: y · retail: confirmed (binary, vanilla×3, mod×72)

### GetCountOfId

```lua
Inventory.GetCountOfId(int itemId)
```

Gets the number of element of the specified DB id inside the inventory.

| Param | Description |
|---|---|
| char const* classIdText | Item class GUID. |

docs: y · retail: unconfirmed

### GetCurrentItem

```lua
Inventory.GetCurrentItem(ScriptHandle itemId)
```

C++: `int SetCurrentItemId (IFunctionHandler * pH , ScriptHandle itemId )`

Sets the specified item as the current one.

docs: y · retail: confirmed (binary)

### GetCurrentItemId

```lua
Inventory.GetCurrentItemId()
```

C++: `int GetCurrentItemId (IFunctionHandler * pH )`

Gets the identifier of the current item.

docs: y · retail: confirmed (binary)

### GetGrenadeWeaponByClass

```lua
Inventory.GetGrenadeWeaponByClass(className)
```

Gets grenade weapon by class name.

| Param | Description |
|---|---|
| const char * className | Class name. |

docs: y · retail: confirmed (binary)

### GetHolsteredItemId

```lua
Inventory.GetHolsteredItemId()
```

C++: `int GetHolsteredItemId (IFunctionHandler * pH )`

Gets the identifier for the holstered item.

docs: y · retail: unconfirmed

### GetId

```lua
Inventory.GetId()
```

C++: `int GetId (IFunctionHandler * pH )`

Returns runtime inventory id.

docs: y · retail: confirmed (binary, vanilla×2, mod×12)

### GetInventoryTable

```lua
Inventory.GetInventoryTable()
```

C++: `int GetInventoryTable (IFunctionHandler * pH )`

Gets the inventory table.

docs: y · retail: confirmed (binary, mod×5)

### GetItem

```lua
Inventory.GetItem(int slotId)
```

C++: `int GetItem (IFunctionHandler * pH , int slotId )`

Gets the table of an item in the specified slot.

docs: y · retail: confirmed (binary)

### GetItemByClass

```lua
Inventory.GetItemByClass(className)
```

Gets item by class name.

| Param | Description |
|---|---|
| const char * className | Class name. |

docs: y · retail: confirmed (binary)

### GetItemId

```lua
Inventory.GetItemId(int slotId)
```

C++: `int GetItemId (IFunctionHandler * pH , int slotId )`

Gets the item id in the specified slot.

docs: y · retail: unconfirmed

### GetLastItem

```lua
Inventory.GetLastItem()
```

C++: `int GetLastItem (IFunctionHandler * pH )`

Gets the last used item.

docs: y · retail: unconfirmed

### GetLastItemId

```lua
Inventory.GetLastItemId()
```

C++: `int GetLastItemId (IFunctionHandler * pH )`

Gets the identifier for the last used item.

docs: y · retail: unconfirmed

### GetMemoryUsage

```lua
Inventory.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer * pSizer ) const`

This is GetMemoryUsage, a member of class C_ScriptBind_Inventory.

docs: y · retail: unconfirmed

### GetMoney

```lua
Inventory.GetMoney()
```

C++: `int GetMoney (IFunctionHandler * pH )`

Returns amount of money in this inventory converted into float

docs: y · retail: confirmed (binary, vanilla×7, mod×21)

### HasAccessory

```lua
Inventory.HasAccessory(accessoryName)
```

Checks if the inventory contains the specified accessory.

| Param | Description |
|---|---|
| const char * accessoryName | Accessory name. |

docs: y · retail: confirmed (binary)

### HasItem

```lua
Inventory.HasItem(ScriptHandle itemId)
```

C++: `int HasItem (IFunctionHandler * pH , ScriptHandle itemId )`

Returns true if item is in this inventory.

docs: y · retail: confirmed (binary)

### MoveItemOfClass

```lua
Inventory.MoveItemOfClass(classIdText, count)
```

Moves an item from the inventory to target inventory.

| Param | Description |
|---|---|
| framework | :T_WUIDScriptType targetInvId inventory where items should be moved to |
| char const* classIdText | Item class GUID. |
| int count | count of item pieces to remove, use 0 to move all |
| bool bChangeOwnerToTarget | makes item not to be stolen |

Returns: Amount of items moved

docs: y · retail: confirmed (vanilla×1, mod×4)

### Release

```lua
Inventory.Release()
```

C++: `void Release ()`

This is Release, a member of class C_ScriptBind_Inventory.

docs: y · retail: unconfirmed

### ReloadWeapons

```lua
Inventory.ReloadWeapons()
```

C++: `int ReloadWeapons (IFunctionHandler* pH )`

Reloads weapons.

docs: y · retail: unconfirmed

### RemoveAllItems

```lua
Inventory.RemoveAllItems()
```

C++: `int RemoveAllItems (IFunctionHandler * pH )`

Removes all items from the inventory.

docs: y · retail: confirmed (binary, vanilla×1, mod×1)

### RemoveItem

```lua
Inventory.RemoveItem(id)
```

Removes an item from the inventory.

| Param | Description |
|---|---|
| ScriptHandle id | item id |
| int count | count of item pieces to remove, use -1 to remove all |

Returns: id of removed item

docs: y · retail: confirmed (binary, mod×2)

### RemoveMoney

```lua
Inventory.RemoveMoney(5.5)
```

C++: `int RemoveMoney (IFunctionHandler * pH , float count )`

Removes 5.5 of actual currency. Money are removed only if inventory have such amount.

docs: y · retail: confirmed (mod×8)

### ResetAmmo

```lua
Inventory.ResetAmmo()
```

C++: `int ResetAmmo (IFunctionHandler * pH )`

Resets ammunition.

docs: y · retail: unconfirmed

### SetAmmoCapacity

```lua
Inventory.SetAmmoCapacity(const char *ammoName, int max)
```

Sets the specific ammunition capacity.

| Param | Description |
|---|---|
| const char * ammoName | Ammunition name. |
| int max | Ammunition capacity. |

docs: y · retail: unconfirmed

### SetAmmoCount

```lua
Inventory.SetAmmoCount(ammoName, count)
```

Sets the amount of the specified ammunition.

| Param | Description |
|---|---|
| const char * ammoName | Ammunition name. |
| int count | Ammunition amount. |

docs: y · retail: unconfirmed

### SetCapacity

```lua
Inventory.SetCapacity(int size)
```

Sets the inventory capacity.

| Param | Description |
|---|---|
| int size | Inventory capacity. |

docs: y · retail: unconfirmed

### SetHolsteredItemId

```lua
Inventory.SetHolsteredItemId(ScriptHandle itemId)
```

C++: `int SetHolsteredItemId (IFunctionHandler * pH , ScriptHandle itemId )`

Sets the specified item as the holstered item.

docs: y · retail: unconfirmed

### SetLastItemId

```lua
Inventory.SetLastItemId(ScriptHandle itemId)
```

C++: `int SetLastItemId (IFunctionHandler * pH , ScriptHandle itemId )`

Sets the specified item as the last used one.

docs: y · retail: unconfirmed

### Validate

```lua
Inventory.Validate()
```

C++: `int Validate (IFunctionHandler * pH )`

Validates the inventory.

docs: y · retail: unconfirmed
