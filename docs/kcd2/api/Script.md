# Script

C++ class(es): `CScriptBindScript`, `CScriptBind_Script`
Reached from Lua as `Script.FunctionName(...)`.
12 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### Debug

```lua
Script.Debug()
```

C++: `int Debug (IFunctionHandler * pH )`

DEACTIVATED.

docs: y · retail: unconfirmed

### DebugFull

```lua
Script.DebugFull()
```

C++: `int DebugFull (IFunctionHandler * pH )`

DEACTIVATED.

docs: y · retail: unconfirmed

### DumpLoadedScripts

```lua
Script.DumpLoadedScripts()
```

C++: `int DumpLoadedScripts (IFunctionHandler * pH )`

Dumps all the loaded scripts.

Dump all loaded scripts path calling IScriptSystemSink::OnLoadedScriptDump @see IScriptSystemSink

docs: y · retail: confirmed (runtime dump)

### GetMemoryUsage

```lua
Script.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer* pSizer ) const`

This is GetMemoryUsage, a member of class CScriptBind_Script.

docs: y · retail: unconfirmed

### KillTimer

```lua
Script.KillTimer(nTimerId)
```

Stops a timer set by the Script.SetTimer function.

| Param | Description |
|---|---|
| ScriptHandle nTimerId | ID of the timer returned by the Script.SetTimer function. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×28)

### LoadScript

```lua
Script.LoadScript(scriptName)
```

Loads the script.

load a specified script @param sFileName path of the script that has to be loaded

| Param | Description |
|---|---|
| scriptName | name of the script to load |

docs: y · retail: confirmed (runtime dump, mod×112)

### ReloadEntityScript

```lua
Script.ReloadEntityScript(className)
```

Reloads the specified entity script.

| Param | Description |
|---|---|
| const char * className | Name of the entity script. |

docs: y · retail: confirmed (runtime dump)

### ReloadScript

```lua
Script.ReloadScript()
```

C++: `int ReloadScript (IFunctionHandler * pH )`

Reload the script.

reload a specified script. If the script wasn't loaded at least once before the function will fail @param sFileName path of the script that has to be reloaded

docs: y · retail: confirmed (runtime dump, vanilla×117 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/common.lua`), mod×3)

### ReloadScripts

```lua
Script.ReloadScripts()
```

C++: `int ReloadScripts (IFunctionHandler * pH )`

Reloads all the scripts.

reload all previosly loaded scripts

docs: y · retail: confirmed (runtime dump)

### SetTimer

```lua
Script.SetTimer(nMilliseconds, luaFunction [, userData [, bUpdateDuringPause]])
```

Set a general script timer, when timer expires will call back a specified lua function. ! Lua function will accept 1 or 2 parameters, ! if userData is specified luaFunction must be:

if userData is not specified luaFunction must be:

| Param | Description |
|---|---|
| int nMilliseconds | Delay of trigger in milliseconds. |
| luaFunction | . |
| userData | (optional) Any user defined table. If specified will be passed as a first argument of the callback function. |
| bUpdateDuringPause | (optional) will be updated and trigger even if in pause mode. |

Returns: ID assigned to this timer or nil if not specified.

docs: y · retail: confirmed (binary, runtime dump, vanilla×45 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/EntityCommon.lua`))

### SetTimerForFunction

```lua
Script.SetTimerForFunction(nMilliseconds, luaFunction [, userData [, bUpdateDuringPause]])
```

Set a general script timer, when timer expires will call back a specified lua function. ! Lua function will accept 1 or 2 parameters, ! if userData is specified luaFunction must be:

if userData is not specified luaFunction must be:

.

| Param | Description |
|---|---|
| int nMilliseconds | Delay of trigger in milliseconds. |
| luaFunction | . |
| userData | (optional) Any user defined table. If specified it will be passed as a first argument of the callback function. |
| bUpdateDuringPause | (optional) will be updated and trigger even if in pause mode. |

Returns: ID assigned to this timer or nil if not specified.

docs: y · retail: confirmed (runtime dump, mod×118)

> **Verified note:** Do not pass a third argument. The official script_bind docs describe it as a userData value forwarded to the callback, but in game it never arrives, and passing one can stop the timer chain from re-firing. -- kcd2/lua-scripting.md#timers-and-update-loops (verified in game)
> **Verified note:** Pending SetTimerForFunction timers are serialised into the save and re-armed on load. A chain that is actively running (not merely pending) at save time does not carry into the loaded game and is dropped with the old level. -- kcd2/lua-scripting.md#timers-and-saves (verified in game)

### UnloadScript

```lua
Script.UnloadScript()
```

C++: `int UnloadScript (IFunctionHandler * pH )`

Unloads the script.

unload script from the "loaded scripts map" so if this script is loaded again the Script system will reloadit. this function doesn't involve the LUA VM so the resources allocated by the script will not be released unloading the script @param sFileName path of the script that has to be loaded

docs: y · retail: confirmed (runtime dump)
