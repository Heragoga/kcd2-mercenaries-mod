# Alchemy

C++ class(es): `C_ScriptBind_Alchemy`
Reached from Lua as `Alchemy.FunctionName(...)`.
10 documented function(s); 1 additional undocumented function(s) found in retail/runtime.

## Functions

### GetDisableReason

```lua
Alchemy.GetDisableReason(EntityId user, item_type)
```

returns string

| Param | Description |
|---|---|
| int item_type | internal alchemy item type |
| user | id of user |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Minigames/AlchemyItem.lua`))

### GetFlagTextFor

```lua
Alchemy.GetFlagTextFor(EntityId user, item_type)
```

returns flag text for alchemy item

| Param | Description |
|---|---|
| int item_type | internal alchemy item type |
| user | id of user |

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Minigames/AlchemyItem.lua`))

### GetUsableFor

```lua
Alchemy.GetUsableFor(EntityId user, item_type)
```

returns usable state

| Param | Description |
|---|---|
| int item_type | internal alchemy item type |
| user | id of user |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Minigames/AlchemyItem.lua`))

### IsCrossCenteringEnabled

```lua
Alchemy.IsCrossCenteringEnabled(EntityId user, item_type)
```

returns if hint is enabled for selected alchemy item

| Param | Description |
|---|---|
| int item_type | internal alchemy item type |
| user | id of user |

docs: y · retail: confirmed (binary, runtime dump, vanilla×7 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Minigames/AlchemyItem.lua`))

### IsUsableByHold

```lua
Alchemy.IsUsableByHold()
```

C++: `int IsUsableByHold (IFunctionHandler * pH , int userId , int item_type )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Minigames/AlchemyItem.lua`))

### IsUsableEnabledFor

```lua
Alchemy.IsUsableEnabledFor(EntityId user, item_type)
```

returns true if item can be currently used

| Param | Description |
|---|---|
| int item_type | internal alchemy item type |
| user | id of user |

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Minigames/AlchemyItem.lua`))

### IsUsableVisibleFor

```lua
Alchemy.IsUsableVisibleFor(EntityId user, item_type)
```

returns true if item can be currently shown

| Param | Description |
|---|---|
| int item_type | internal alchemy item type |
| user | id of user |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Minigames/AlchemyItem.lua`))

### OnUse

```lua
Alchemy.OnUse(EntityId user)
```

returns true

| Param | Description |
|---|---|
| user | id of user |

docs: y · retail: confirmed (runtime dump, vanilla×5 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Minigames/AlchemyItem.lua`))

### ReseTable

```lua
Alchemy.ReseTable(table)
```

Resets alchemy table and all linked alchemy items to theirs default positions.

| Param | Description |
|---|---|
| table | entity id of alchemy table |

docs: y · retail: unconfirmed

### StartAlchemy

```lua
Alchemy.StartAlchemy(EntityId user, EntityId table)
```

Starts alchemy mini game.

| Param | Description |
|---|---|
| table | entity id of alchemy table on which user will do the alchemy mini game |
| user | entity id of user who will do the mini game |

docs: y · retail: confirmed (runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Minigames/AlchemyTable.lua`))

## Undocumented (present in retail, not in official docs)

### ResetTable

`Alchemy.ResetTable(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Minigames/AlchemyTable.lua`))
