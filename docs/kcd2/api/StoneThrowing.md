# StoneThrowing

C++ class(es): `C_ScriptBind_StoneThrowing`
Reached from Lua as `StoneThrowing.FunctionName(...)`.
2 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### CanUse

```lua
StoneThrowing.CanUse(EntityId user, EntityId pileId)
```

returns true if pile can be used

| Param | Description |
|---|---|
| ScriptHandle pileId | id of pile determined for throwing |
| user | id of user |

docs: y · retail: confirmed (binary, runtime dump, vanilla×5 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Minigames/StoneThrowingPile.lua`))

### StartMinigame

```lua
StoneThrowing.StartMinigame(EntityId user, EntityId pileId)
```

Starts stone throwing minigame.

| Param | Description |
|---|---|
| ScriptHandle pileId | id of pile determined for throwing |
| user | id of user |

docs: y · retail: confirmed (runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Minigames/StoneThrowingPile.lua`))
