# ItemManager

C++ class(es): `C_ScriptBindItemManager`, `C_ScriptBind_ItemManager`
Reached from Lua as `ItemManager.FunctionName(...)`.
11 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### AddOnEquipBuff

```lua
ItemManager.AddOnEquipBuff()
```

C++: `int AddOnEquipBuff (IFunctionHandler * pH , framework::T_WUIDScriptType itemId , const char * buff_id , bool add )`

docs: y · retail: confirmed (runtime dump)

### CombineItems

```lua
ItemManager.CombineItems(id, id)
```

Returns item id of combined item

| Param | Description |
|---|---|
| id | id of source and target items |

docs: y · retail: unconfirmed

### CreateItem

```lua
ItemManager.CreateItem()
```

C++: `int CreateItem (IFunctionHandler * pH , char const * classId , float health , int amount )`

creates new item with defined health and amount

docs: y · retail: confirmed (vanilla×22 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Debug/CombatDebug.lua`), mod×28)

### GetItem

```lua
ItemManager.GetItem(id)
```

Returns item script table which can be used to access item specific data

| Param | Description |
|---|---|
| ScriptHandle id | id of item |

docs: y · retail: confirmed (binary, runtime dump, mod×4)

> **Verified note:** The old context doc claims GetItem returns an opaque proxy table that must be iterated with pairs(). Contradicted by shipped mod code, which reads it.class, it.amount, it.health with plain field indexing. -- kcd2/lua-scripting.md#api-recipes (vanilla: data/Scripts/mods/mercenaries_store.lua)

### GetItemName

```lua
ItemManager.GetItemName(classId)
```

Returns database name of the item.

| Param | Description |
|---|---|
| classId | id of item class (GUID in db) |

docs: y · retail: confirmed (binary, runtime dump, mod×3)

### GetItemOwner

```lua
ItemManager.GetItemOwner(id)
```

Returns item owner wuid

| Param | Description |
|---|---|
| framework | :T_WUIDScriptType id id of item |

docs: y · retail: confirmed (binary, runtime dump)

### GetItemUIName

```lua
ItemManager.GetItemUIName(classId)
```

Returns UI name of the item.

| Param | Description |
|---|---|
| classId | id of item class (GUID in db) |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Others/PickableArea.lua`), mod×1)

### IsItemOversized

```lua
ItemManager.IsItemOversized(id)
```

Returns whether item is oversized

| Param | Description |
|---|---|
| framework | :T_WUIDScriptType id id of item |

docs: y · retail: confirmed (binary, runtime dump)

### RemoveItem

```lua
ItemManager.RemoveItem(id)
```

Removes item. Item creation/remove might be disabled on master to avoid cheating.

| Param | Description |
|---|---|
| ScriptHandle id | id of item to be removed |

docs: y · retail: confirmed (binary, runtime dump, mod×2)

### SerItemOwner

```lua
ItemManager.SerItemOwner(itemId, ownerId, markAsStolen)
```

No return value.

| Param | Description |
|---|---|
| framework | :T_WUIDScriptType itemId id of item |
| framework | :T_WUIDScriptType ownerId id of new owner |
| bool markAsStolen | marks item as stolen and start fading |

docs: y · retail: unconfirmed

### ValidateId

```lua
ItemManager.ValidateId(id)
```

After game load this function returns new item id assigned to old item id. All item id's needs to be validated after game load

| Param | Description |
|---|---|
| ScriptHandle id | old save item id |

docs: y · retail: unconfirmed
