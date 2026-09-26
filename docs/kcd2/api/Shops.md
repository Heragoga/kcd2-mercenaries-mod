# Shops

C++ class(es): `C_ScriptBindShop`
Reached from Lua as `Shops.FunctionName(...)`.
4 documented function(s); 11 additional undocumented function(s) found in retail/runtime.

## Functions

### AssignShopKeeper

```lua
Shops.AssignShopKeeper(XX, ent)
```

C++: `int AssignShopKeeper (IFunctionHandler* pH , ScriptHandle shopId , ScriptHandle entityId )`

Assign soul of passed entity as shopkeeper to shop XX (entity id).

docs: y · retail: unconfirmed

### OpenInventory

```lua
Shops.OpenInventory(entityId, bCanHaggle)
```

Opens the shop UI with the specified shopkeeper.

| Param | Description |
|---|---|
| ScriptHandle shopkeeperId | entity id for an NPC. It must be assigned as a shopkeeper for some shop. |
| bool bCanHaggle | if set to false, haggling will be disabled. |

docs: y · retail: confirmed (runtime dump, vanilla×3)

### UnassignAllShopKeepersFromShop

```lua
Shops.UnassignAllShopKeepersFromShop(ShopId)
```

C++: `int UnassignAllShopKeepersFromShop (IFunctionHandler* pH , int shopDBId )`

Unassigns all shopkeepers from selected shop. Strongly discourage you from using that. Use rather Shops.UnassignShopKeeperFromShops script bind if it is possible. Assign soul of passed entity as shopkeeper to shop XX (db id).

docs: y · retail: unconfirmed

### UnassignShopKeeperFromShops

```lua
Shops.UnassignShopKeeperFromShops(ent)
```

C++: `int UnassignShopKeeperFromShops (IFunctionHandler* pH , ScriptHandle entityId )`

Unassign given shop keeper entity from shop.

docs: y · retail: unconfirmed

## Undocumented (present in retail, not in official docs)

### AcceptTransaction

`Shops.AcceptTransaction(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)

### CancelTransaction

`Shops.CancelTransaction(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)

### DoMoneyTransaction

`Shops.DoMoneyTransaction(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/DialogUtils.lua`))

### FindItemInShop

`Shops.FindItemInShop(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)

### FindShopInventoryForItem

`Shops.FindShopInventoryForItem(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)

### GetShopDBIdByKeeper

`Shops.GetShopDBIdByKeeper(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Systems/KCD1/Negotiation.lua`), mod×1)

### GetShopDBIdByLinkedEntityId

`Shops.GetShopDBIdByLinkedEntityId(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, mod×1)

### GetShopMoney

`Shops.GetShopMoney(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Systems/KCD1/Negotiation.lua`), mod×1)

### IsLinkedWithShop

`Shops.IsLinkedWithShop(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Stash/StashCorpse.lua`), mod×2)

### IsShopOpened

`Shops.IsShopOpened(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)

### OpenInventoryForItem

`Shops.OpenInventoryForItem(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Items/PickableItem.lua`))
