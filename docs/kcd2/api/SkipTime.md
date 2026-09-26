# SkipTime

C++ class(es): `C_ScriptBindSkipTime`
Reached from Lua as `SkipTime.FunctionName(...)`.
2 documented function(s); 1 additional undocumented function(s) found in retail/runtime.

## Functions

### GetSkipTimeMessageString

```lua
SkipTime.GetSkipTimeMessageString(E_SkipTimeMessage message)
```

returns the ui string for the skip time message. Returns nil for Empty message or if the messageType is invalid

| Param | Description |
|---|---|
| message | value from E_SkipTimeMessage enum |

docs: y · retail: unconfirmed

### SetHudMessages

```lua
SkipTime.SetHudMessages()
```

C++: `void SetHudMessages (framework::I_UIHudMessages* hudMessasges )`

docs: y · retail: unconfirmed

## Undocumented (present in retail, not in official docs)

### GetSkipTimeMessageUIString

`SkipTime.GetSkipTimeMessageUIString(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Triggers/BedTrigger.lua`))
