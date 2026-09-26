# EnvironmentModule

C++ class(es): `C_ScriptBindEnvironment`
Reached from Lua as `EnvironmentModule.FunctionName(...)`.
5 documented function(s); 2 additional undocumented function(s) found in retail/runtime.

## Functions

### BlendTimeOfDay

```lua
EnvironmentModule.BlendTimeOfDay(pProfileName, blendDuration, force)
```

Blends Time Of Day profile from current one to specific one. If blending is already in progress it will queue next blend. Only last blend is queued.

| Param | Description |
|---|---|
| const char* pProfileName | name of profile we want to blend into |
| int blendDuration | duration in seconds in game time |
| bool force | if there is blend in progress it will stops current blend and starts new one - this should be used when immediate blend dis requested |

docs: y · retail: confirmed (runtime dump)

### ForceImmediateWeatherUpdate

```lua
EnvironmentModule.ForceImmediateWeatherUpdate()
```

C++: `int ForceImmediateWeatherUpdate (IFunctionHandler* pH )`

Apply all weather params immediately and recreate weather state from those params.

docs: y · retail: confirmed (runtime dump)

### ForceWindDirection

```lua
EnvironmentModule.ForceWindDirection()
```

C++: `int ForceWindDirection (IFunctionHandler* pH , float fAngleDeg )`

Set wind direction override. Negative value turns off override.

docs: y · retail: unconfirmed

### GetRainIntensity

```lua
EnvironmentModule.GetRainIntensity()
```

C++: `int GetRainIntensity (IFunctionHandler* pH )`

Get current intensity of the rain.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Others/BirdsTakeoff.lua`))

### RebuildClouds

```lua
EnvironmentModule.RebuildClouds()
```

C++: `int RebuildClouds (IFunctionHandler* pH )`

Regenerates all clouds with current values of cloudiness and cloud granularity

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Debug/DebugUtils.lua`))

## Undocumented (present in retail, not in official docs)

### CoverHole

`EnvironmentModule.CoverHole(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)

### MakeHole

`EnvironmentModule.MakeHole(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)
