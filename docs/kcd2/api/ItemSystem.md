# ItemSystem

C++ class(es): `CScriptBindItemSystem`, `CScriptBind_ItemSystem`
Reached from Lua as `ItemSystem.FunctionName(...)`.
11 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### GetMemoryUsage

```lua
ItemSystem.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer* pSizer ) const`

This is GetMemoryUsage, a member of class CScriptBind_ItemSystem.

docs: y · retail: unconfirmed

### GetPackItemByIndex

```lua
ItemSystem.GetPackItemByIndex(packName, index)
```

Gets a pack item from its index.

| Param | Description |
|---|---|
| const char * packName | Pack name. |
| int index | Pack index. |

docs: y · retail: confirmed (runtime dump)

### GetPackNumItems

```lua
ItemSystem.GetPackNumItems()
```

Get the number of items in the specified pack.

| Param | Description |
|---|---|
| const char* packName | Pack name. |

docs: y · retail: confirmed (binary, runtime dump)

### GetPackPrimaryItem

```lua
ItemSystem.GetPackPrimaryItem(packName)
```

Gets the primary item of the specified pack.

| Param | Description |
|---|---|
| const char * packName | Pack name. |

docs: y · retail: confirmed (binary, runtime dump)

### GiveItem

```lua
ItemSystem.GiveItem(itemName)
```

Gives the specified item.

| Param | Description |
|---|---|
| const char * itemName | Item name. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/FlowNodes/InventoryWeapon.lua`))

### GiveItemPack

```lua
ItemSystem.GiveItemPack(actorId, packName)
```

Gives the item pack to the specified actor.

| Param | Description |
|---|---|
| ScriptHandle actorId | Actor identifier. |
| const char * packName | Pack name. |

docs: y · retail: confirmed (runtime dump)

### Release

```lua
ItemSystem.Release()
```

C++: `void Release ()`

This is Release, a member of class CScriptBind_ItemSystem.

docs: y · retail: unconfirmed

### Reset

```lua
ItemSystem.Reset()
```

C++: `int Reset (IFunctionHandler * pH )`

Resets the item system.

docs: y · retail: confirmed (binary, runtime dump, vanilla×81)

### SerializePlayerLTLInfo

```lua
ItemSystem.SerializePlayerLTLInfo(reading)
```

Serializes player LTL info.

| Param | Description |
|---|---|
| bool reading | Boolean value. |

docs: y · retail: confirmed (runtime dump)

### SetActorItem

```lua
ItemSystem.SetActorItem(actorId, itemId, keepHistory)
```

Sets an actor item.

| Param | Description |
|---|---|
| ScriptHandle actorId | Actor identifier. |
| ScriptHandle itemId | Item identifier. |
| bool keepHistory | True to keep history, false otherwise. |

docs: y · retail: confirmed (runtime dump)

### SetActorItemByName

```lua
ItemSystem.SetActorItemByName(actorId, name, keepHistory)
```

Sets an actor item by name.

| Param | Description |
|---|---|
| ScriptHandle actorId | Actor identifier. |
| const char * name | Actor item name. |
| bool keepHistory | True to keep history, false otherwise. |

docs: y · retail: confirmed (runtime dump)
