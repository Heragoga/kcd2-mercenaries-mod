# Calendar

C++ class(es): `C_ScriptBindCalendar`, `C_ScriptBind_Calendar`
Reached from Lua as `Calendar.FunctionName(...)`.
14 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### GetGameTime

```lua
Calendar.GetGameTime()
```

C++: `int GetGameTime (IFunctionHandler * pH )`

Returns game time (whole seconds from start of level)

docs: y · retail: confirmed (binary, runtime dump, vanilla×3 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Doors/AnimDoor.lua`))

### GetWorldDay

```lua
Calendar.GetWorldDay()
```

C++: `int GetWorldDay (IFunctionHandler * pH )`

Returns number of whole days from start of level.

docs: y · retail: confirmed (binary, runtime dump, mod×2)

### GetWorldDayOfWeek

```lua
Calendar.GetWorldDayOfWeek()
```

C++: `int GetWorldDayOfWeek (IFunctionHandler * pH )`

Returns ordinal number of day in current week. Range is monday is 0

docs: y · retail: confirmed (binary, runtime dump)

### GetWorldHourOfDay

```lua
Calendar.GetWorldHourOfDay()
```

C++: `int GetWorldHourOfDay (IFunctionHandler * pH )`

Returns hour of current day. Range is <0,24) The number is float.

docs: y · retail: confirmed (binary, runtime dump, vanilla×5 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Lights/Light.lua`), mod×3)

### GetWorldTime

```lua
Calendar.GetWorldTime()
```

C++: `int GetWorldTime (IFunctionHandler * pH )`

Returns world time (whole seconds from start of level)

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/actor/player.lua`), mod×3)

### GetWorldTimeRatio

```lua
Calendar.GetWorldTimeRatio()
```

C++: `int GetWorldTimeRatio (IFunctionHandler * pH )`

Returns ratio of world time.

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/actor/player.lua`), mod×7)

> **Verified note:** Constant 15.0 on every measured sample (2,343 samples), including fast travel and sleep -- not the old context doc's claim of "spikes to 400+ during time skips, >100 catches all". Use the clock rate (GetWorldTime() delta per real second) to detect skips instead of the ratio value. -- kcd2/world-and-physics.md#time-fast-travel-and-time-skips (verified in game)

### IsFakedTimeOfDay

```lua
Calendar.IsFakedTimeOfDay()
```

C++: `int IsFakedTimeOfDay (IFunctionHandler * pH )`

Returns true in case fake time of day is on.

docs: y · retail: confirmed (binary, runtime dump)

### IsNightTimeOfDay

```lua
Calendar.IsNightTimeOfDay()
```

C++: `int IsNightTimeOfDay (IFunctionHandler * pH )`

Returns true in night, false in day. Uses time from TimeOfDay.

docs: y · retail: confirmed (binary, runtime dump)

### IsWorldTimePaused

```lua
Calendar.IsWorldTimePaused()
```

C++: `int IsWorldTimePaused (IFunctionHandler * pH )`

Returns true if world time is paused.

docs: y · retail: confirmed (binary, runtime dump, mod×2)

### SetFakeTimeOfDay

```lua
Calendar.SetFakeTimeOfDay(10)
```

Forces CryEngine to believe there is time different from our world time. The fake time is static. It is not used for RPG systems, only in TimeOfDay.

| Param | Description |
|---|---|
| float fakeHour | fake hour of current day |

docs: y · retail: confirmed (binary, runtime dump)

### SetWorldTime

```lua
Calendar.SetWorldTime(3000)
```

Sets ratio of world time.

| Param | Description |
|---|---|
| int worldTime | new world time (whole seconds from start of level) to be set. Must not be set backwards. |

docs: y · retail: confirmed (runtime dump, vanilla×3 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/actor/player.lua`))

### SetWorldTimePaused

```lua
Calendar.SetWorldTimePaused(true)
```

Pauses/unpauses world time.

| Param | Description |
|---|---|
| bool worldTimePaused | true means world time is paused |

docs: y · retail: unconfirmed

### SetWorldTimeRatio

```lua
Calendar.SetWorldTimeRatio(30)
```

Sets ratio of world time.

| Param | Description |
|---|---|
| float worldTimeRatio | world time / game time ratio (float) |

docs: y · retail: confirmed (binary, runtime dump, vanilla×3 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/actor/player.lua`), mod×2)

### UnfakeTimeOfDay

```lua
Calendar.UnfakeTimeOfDay()
```

C++: `int UnfakeTimeOfDay (IFunctionHandler * pH )`

Switches CryEngine back to our world time

docs: y · retail: confirmed (binary, runtime dump)
