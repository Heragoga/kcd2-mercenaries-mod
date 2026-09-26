# Cart

C++ class(es): `C_ScriptBind_Cart`
Reached from Lua as `Cart.FunctionName(...)`.
2 documented function(s); 2 additional undocumented function(s) found in retail/runtime.

## Functions

### CanPlayerMount

```lua
Cart.CanPlayerMount(EntityId cartId, bool frontSeat)
```

returns true if player can mount into cart

| Param | Description |
|---|---|
| ScriptHandle cartId | id of cart to be mount |
| bool frontSeat | if true it request front seat to mount. Otherwise back seat. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Vehicles/WHCartMountPoint.lua`))

### MountPlayer

```lua
Cart.MountPlayer(EntityId cartId, bool frontSeat)
```

Mount player into cart

| Param | Description |
|---|---|
| ScriptHandle cartId | id of cart to be mount |
| bool frontSeat | if true it request front seat to mount. Otherwise back seat. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Vehicles/WHCartMountPoint.lua`))

## Undocumented (present in retail, not in official docs)

### BlockByStash

`Cart.BlockByStash(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Stash/CartStash.lua`))

### IsEntityOnMovingCart

`Cart.IsEntityOnMovingCart(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Stash/CartStash.lua`))
