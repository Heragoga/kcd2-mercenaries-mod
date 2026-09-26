# UIAction

C++ class(es): `CScriptBindUIAction`, `CScriptBind_UIAction`
Reached from Lua as `UIAction.FunctionName(...)`.
38 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### CallFunction

```lua
UIAction.CallFunction(elementName, instanceID, functionName, [arg1], [arg2], [...])
```

Calls a function of the UI flash asset or the UIEventSystem.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml or UIEventSystem name as defined via cpp. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances. If used on UIEventSystem no instance id is ignored |
| const char* functionName | Function or event name. |
| args | List of arguments (optional) |

docs: y · retail: confirmed (binary, runtime dump, mod×30)

### DisableAction

```lua
UIAction.DisableAction(actionName)
```

Disables the UI Action.

| Param | Description |
|---|---|
| const char * actionName | UI Action name. |

docs: y · retail: confirmed (binary, runtime dump)

### EnableAction

```lua
UIAction.EnableAction(actionName)
```

Enables the UI Action.

| Param | Description |
|---|---|
| const char * actionName | UI Action name. |

docs: y · retail: confirmed (binary, runtime dump)

### EndAction

```lua
UIAction.EndAction(table, disable, arguments)
```

Ends a UI Action. This can be only used withing a UIAction Lua script

| Param | Description |
|---|---|
| bool disable | if true this action gets disabled on end. |
| SmartScriptTable arguments | arguments to return from this action. |
| table | must be "self". |

docs: y · retail: confirmed (runtime dump)

### GetAlpha

```lua
UIAction.GetAlpha(elementName, instanceID, mcName)
```

Get MovieClip alpha value.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances |
| const char * mcName | MovieClip name as defined in the xml. |

docs: y · retail: confirmed (binary, runtime dump, mod×2)

### GetArray

```lua
UIAction.GetArray(elementName, instanceID, arrayName)
```

Returns a table with values of the array.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances |
| const char * arrayName | Array name as defined in the xml. |

docs: y · retail: confirmed (binary, runtime dump)

### GetMemoryUsage

```lua
UIAction.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer* pSizer ) const`

This is GetMemoryUsage, a member of class CScriptBind_UIAction.

docs: y · retail: unconfirmed

### GetPos

```lua
UIAction.GetPos(elementName, instanceID, mcName)
```

Get MovieClip position.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances |
| const char * mcName | MovieClip name as defined in the xml. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×44, mod×71)

### GetRotation

```lua
UIAction.GetRotation(elementName, instanceID, mcName)
```

Get MovieClip rotation.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances |
| const char * mcName | MovieClip name as defined in the xml. |

docs: y · retail: confirmed (binary, runtime dump, mod×1)

### GetScale

```lua
UIAction.GetScale(elementName, instanceID, mcName)
```

Get MovieClip scale.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances |
| const char * mcName | MovieClip name as defined in the xml. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×5, mod×3)

### GetVariable

```lua
UIAction.GetVariable(elementName, instanceID, varName)
```

Gets a variable of the UI flash asset.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances |
| const char * varName | Variable name as defined in the xml. |

docs: y · retail: confirmed (binary, runtime dump)

### GotoAndPlay

```lua
UIAction.GotoAndPlay(elementName, instanceID, mcName, frameNum)
```

Call GotoAndPlay on a MovieClip.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances |
| const char * mcName | MovieClip name as defined in the xml. |
| int frameNum | frame number. |

docs: y · retail: confirmed (binary, runtime dump)

### GotoAndPlayFrameName

```lua
UIAction.GotoAndPlayFrameName(elementName, instanceID, mcName, frameName)
```

Call GotoAndPlay on a MovieClip by frame name.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances |
| const char * mcName | MovieClip name as defined in the xml. |
| const char * frameName | frame name. |

docs: y · retail: confirmed (binary, runtime dump)

### GotoAndStop

```lua
UIAction.GotoAndStop(elementName, instanceID, mcName, frameNum)
```

Call GotoAndStop on a MovieClip.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances |
| const char * mcName | MovieClip name as defined in the xml. |
| int frameNum | frame number. |

docs: y · retail: confirmed (binary, runtime dump)

### GotoAndStopFrameName

```lua
UIAction.GotoAndStopFrameName(elementName, instanceID, mcName, frameName)
```

Call GotoAndStop on a MovieClip by frame name.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances |
| const char * mcName | MovieClip name as defined in the xml. |
| const char * frameName | frame name. |

docs: y · retail: confirmed (binary, runtime dump)

### HideElement

```lua
UIAction.HideElement(elementName, instanceID)
```

Hide the UI flash asset.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances |

docs: y · retail: confirmed (binary, runtime dump, mod×14)

### IsVisible

```lua
UIAction.IsVisible(elementName, instanceID, mcName)
```

Get MovieClip visible state.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances |
| const char * mcName | MovieClip name as defined in the xml. |

docs: y · retail: confirmed (binary, runtime dump, mod×3)

### RegisterActionListener

```lua
UIAction.RegisterActionListener(table, actionName, eventName, callbackFunctionName)
```

Register a callback function for a UIAction event. ! Callback Function must have form: CallbackName(actionName, eventName, argTable)

| Param | Description |
|---|---|
| const char* actionName | UI Action name. |
| const char* eventName | Name of the event that is fired from the UI Action (can be "OnStart" or "OnEnd") - if empty string it will receive all events |
| table | the script that receives the callback (can be "self" to refer the current script). |
| callbackFunctionName | name of the script function that will receive the callback. |

docs: y · retail: confirmed (binary, runtime dump)

### RegisterElementListener

```lua
UIAction.RegisterElementListener(table, elementName, instanceID, eventName, callbackFunctionName)
```

Register a callback function for a UIElement event. ! Callback Function must have form: CallbackName(elementName, instanceId, eventName, argTable)

| Param | Description |
|---|---|
| const char* elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances. |
| const char* eventName | Name of the event that is fired from the UI Element - if empty string it will receive all events |
| table | the script that receives the callback (can be "self" to refer the current script). |
| callbackFunctionName | name of the script function that will receive the callback. |

docs: y · retail: confirmed (runtime dump, mod×5)

### RegisterEventSystemListener

```lua
UIAction.RegisterEventSystemListener(table, eventSystem, eventName, callbackFunctionName)
```

Register a callback function for a UIEventSystem event. ! Callback Function must have form: CallbackName(actionName, eventName, argTable)

| Param | Description |
|---|---|
| const char* eventSystem | UI Event System name |
| const char* eventName | Name of the event that is fired from the UI EventSystem - if empty string it will receive all events |
| table | the script that receives the callback (can be "self" to refer the current script). |
| callbackFunctionName | name of the script function that will receive the callback. |

docs: y · retail: confirmed (binary, runtime dump, mod×1)

### Release

```lua
UIAction.Release()
```

C++: `void Release ()`

This is Release, a member of class CScriptBind_UIAction.

docs: y · retail: unconfirmed

### Reload

```lua
UIAction.Reload()
```

C++: `virtual void Reload ()`

IUIModule

docs: y · retail: confirmed (vanilla×5)

### ReloadElement

```lua
UIAction.ReloadElement(elementName, instanceID)
```

Reloads the UI flash asset.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances |

docs: y · retail: confirmed (binary, runtime dump, mod×3)

### RequestHide

```lua
UIAction.RequestHide(elementName, instanceID)
```

Send the fade out signal to the UI flash asset.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances |

docs: y · retail: confirmed (binary, runtime dump, mod×1)

### Reset

```lua
UIAction.Reset()
```

C++: `virtual void Reset ()`

docs: y · retail: confirmed (binary, vanilla×81)

### SetAlpha

```lua
UIAction.SetAlpha(elementName, instanceID, mcName, fAlpha)
```

Set MovieClip alpha value.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances |
| const char * mcName | MovieClip name as defined in the xml. |
| float fAlpha | alpha value (0-1). |

docs: y · retail: confirmed (runtime dump, mod×7)

### SetArray

```lua
UIAction.SetArray(elementName, instanceID, arrayName, values)
```

Sets an array of the UI flash asset.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances |
| const char * arrayName | Array name as defined in the xml. |
| SmartScriptTable values | Table of values for the array. |

docs: y · retail: confirmed (runtime dump, mod×1)

### SetPos

```lua
UIAction.SetPos(elementName, instanceID, mcName, vPos)
```

Set MovieClip position.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances |
| const char * mcName | MovieClip name as defined in the xml. |
| Vec3 vPos | position. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×6, mod×41)

### SetRotation

```lua
UIAction.SetRotation(elementName, instanceID, mcName, vRotation)
```

Set MovieClip rotation.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances |
| const char * mcName | MovieClip name as defined in the xml. |
| Vec3 vRotation | rotation. |

docs: y · retail: confirmed (binary, runtime dump, mod×5)

### SetScale

```lua
UIAction.SetScale(elementName, instanceID, mcName, vScale)
```

Set MovieClip scale.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances |
| const char * mcName | MovieClip name as defined in the xml. |
| Vec3 vScale | scale. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×2, mod×19)

### SetVariable

```lua
UIAction.SetVariable(elementName, instanceID, varName, value)
```

Sets a variable of the UI flash asset.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances |
| const char * varName | Variable name as defined in the xml. |
| value | Value to set. |

docs: y · retail: confirmed (binary, runtime dump)

### SetVisible

```lua
UIAction.SetVisible(elementName, instanceID, mcName, bVisible)
```

Set MovieClip visible state.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances |
| const char * mcName | MovieClip name as defined in the xml. |
| bool bVisible | visible. |

docs: y · retail: confirmed (runtime dump, mod×14)

### ShowElement

```lua
UIAction.ShowElement(elementName, instanceID)
```

Displays the UI flash asset.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances |

docs: y · retail: confirmed (binary, runtime dump, mod×12)

### StartAction

```lua
UIAction.StartAction(actionName, arguments)
```

Starts a UI Action.

| Param | Description |
|---|---|
| const char* actionName | UI Action name. |
| SmartScriptTable arguments | arguments to pass to this action. |

docs: y · retail: confirmed (runtime dump)

### UnloadElement

```lua
UIAction.UnloadElement(elementName, instanceID)
```

Unloads the UI flash asset.

| Param | Description |
|---|---|
| const char * elementName | UI Element name as defined in the xml. |
| int instanceID | ID of the instance (if instance with id does not exist, it will be created). '-1' for all instances |

docs: y · retail: confirmed (binary, runtime dump, mod×3)

### UnregisterActionListener

```lua
UIAction.UnregisterActionListener(table, callbackFunctionName)
```

Unregister callback functions for a UIAction event.

| Param | Description |
|---|---|
| table | the script that receives the callback (can be "self" to refer the current script). |
| callbackFunctionName | name of the script function that receives the callback. if "" all callbacks for this script will be removed |

docs: y · retail: confirmed (binary, runtime dump)

### UnregisterElementListener

```lua
UIAction.UnregisterElementListener(table, callbackFunctionName)
```

Unregister callback functions for a UIElement event.

| Param | Description |
|---|---|
| table | the script that receives the callback (can be "self" to refer the current script). |
| callbackFunctionName | name of the script function that receives the callback. if "" all callbacks for this script will be removed |

docs: y · retail: confirmed (binary, runtime dump, mod×4)

### UnregisterEventSystemListener

```lua
UIAction.UnregisterEventSystemListener(table, callbackFunctionName)
```

Unregister callback functions for a UIEventSystem event.

| Param | Description |
|---|---|
| table | the script that receives the callback (can be "self" to refer the current script). |
| callbackFunctionName | name of the script function that receives the callback. if "" all callbacks for this script will be removed |

docs: y · retail: confirmed (binary, runtime dump)
