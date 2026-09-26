# ActionMapManager

C++ class(es): `CScriptBindActionMapManager`, `CScriptBind_ActionMapManager`
Reached from Lua as `ActionMapManager.FunctionName(...)`.
13 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### EnableActionFilter

```lua
ActionMapManager.EnableActionFilter(name, enable)
```

Enables a filter for the actions.

| Param | Description |
|---|---|
| const char * name | Filter name. |
| bool enable | True to enable the filter, false otherwise. |

docs: y · retail: unconfirmed

### EnableActionMap

```lua
ActionMapManager.EnableActionMap(name, enable)
```

Enables an action map.

| Param | Description |
|---|---|
| const char * name | Action map name. |
| bool enable | True to enable the filter, false otherwise. |

docs: y · retail: confirmed (runtime dump, vanilla×25 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/actor/player.lua`), mod×7)

### EnableActionMapManager

```lua
ActionMapManager.EnableActionMapManager(enable, resetStateOnDisable)
```

Enables/Disables ActionMapManager.

| Param | Description |
|---|---|
| bool enable | Enables/Disables ActionMapManager. |
| bool resetStateOnDisable | Resets the different Action states when ActionMapManager gets disabled. |

docs: y · retail: confirmed (runtime dump)

### GetDefaultActionEntity

```lua
ActionMapManager.GetDefaultActionEntity()
```

C++: `int GetDefaultActionEntity (IFunctionHandler* pH )`

Gets the currently set default action entity.

docs: y · retail: confirmed (runtime dump)

### GetMemoryUsage

```lua
ActionMapManager.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer* pSizer ) const`

This is GetMemoryUsage, a member of class CScriptBind_ActionMapManager.

docs: y · retail: unconfirmed

### InitActionMaps

```lua
ActionMapManager.InitActionMaps(path)
```

Initializes the action maps and filters found in given file

| Param | Description |
|---|---|
| const char* path | XML file path. |

docs: y · retail: confirmed (binary, runtime dump)

### IsFilterEnabled

```lua
ActionMapManager.IsFilterEnabled(filterName)
```

Checks if a filter is currently enabled.

| Param | Description |
|---|---|
| const char* filterName | filter name. |

docs: y · retail: confirmed (binary, runtime dump, mod×1)

### LoadControllerLayoutFile

```lua
ActionMapManager.LoadControllerLayoutFile(layoutName)
```

Loads the given controller layout into the action manager.

| Param | Description |
|---|---|
| const char* layoutName | layout name. |

docs: y · retail: confirmed (binary, runtime dump)

### LoadFromXML

```lua
ActionMapManager.LoadFromXML(name)
```

Loads information from an XML file.

| Param | Description |
|---|---|
| const char * name | XML file name. |

docs: y · retail: confirmed (binary, runtime dump, mod×1)

### OnLoadGame

```lua
ActionMapManager.OnLoadGame()
```

C++: `void OnLoadGame ()`

WH:JK

WH:JK

docs: y · retail: unconfirmed

### Release

```lua
ActionMapManager.Release()
```

C++: `void Release ()`

This is Release, a member of class CScriptBind_ActionMapManager.

docs: y · retail: unconfirmed

### SetActionListener

```lua
ActionMapManager.SetActionListener()
```

C++: `int SetActionListener (IFunctionHandler* pH , const char * name , ScriptHandle entityId )`

WH::PH

WH::PH

docs: y · retail: confirmed (runtime dump, vanilla×12 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/actor/player.lua`))

### SetDefaultActionEntity

```lua
ActionMapManager.SetDefaultActionEntity(id, updateAll)
```

Sets the new default entity.

| Param | Description |
|---|---|
| EntityId id | EntityId of the new default action entity. |
| bool updateAll | Updates all existing action map assignments. |

docs: y · retail: confirmed (runtime dump)
