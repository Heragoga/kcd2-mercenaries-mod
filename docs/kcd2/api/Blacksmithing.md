# Blacksmithing

C++ class(es): `C_ScriptBind_Blacksmithing`
Reached from Lua as `Blacksmithing.FunctionName(...)`.
2 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### CanUse

```lua
Blacksmithing.CanUse(EntityId user, EntityId pileId)
```

returns true if smithery can be used

| Param | Description |
|---|---|
| ScriptHandle smitheryId | id of smithery start point |
| user | id of user |

docs: y · retail: confirmed (binary, runtime dump, vanilla×5 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Minigames/Smithery.lua`), mod×3)

### StartMinigame

```lua
Blacksmithing.StartMinigame(EntityId user, EntityId pileId)
```

Starts blacksmithing minigame.

| Param | Description |
|---|---|
| ScriptHandle smitheryId | id of smithery start point |
| user | id of user |

docs: y · retail: confirmed (runtime dump, mod×2)
