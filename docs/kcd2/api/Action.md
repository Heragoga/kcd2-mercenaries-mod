# Action

C++ class(es): `CScriptBindAction`, `CScriptBind_Action`
Reached from Lua as `Action.FunctionName(...)`.
56 documented function(s); 1 additional undocumented function(s) found in retail/runtime.

## Functions

### ActivateEffect

```lua
Action.ActivateEffect(name)
```

Activates the specified effect.

| Param | Description |
|---|---|
| const char * name | Name of the effect. |

docs: y · retail: confirmed (binary)

### ActivateExtensionForGameObject

```lua
Action.ActivateExtensionForGameObject(entityId, extension, activate)
```

Activates a specified extension for a game object.

| Param | Description |
|---|---|
| ScriptHandle entityId | Identifier for the entity. |
| const char * extension | Extension name. |
| bool activate | True to activate the extension, false to deactivate it. |

docs: y · retail: unconfirmed

### AddRangeSignal

```lua
Action.AddRangeSignal(entityId, fAngle, fFlexibleBoundary, sSignal)
```

Adds an angle for the signal.

| Param | Description |
|---|---|
| ScriptHandle entityId | Identifier for the entity. |
| float fAngle | Angle value. |
| float fFlexibleBoundary | Flexible boundary size. |
| const char * sSignal | String for signal. |

docs: y · retail: confirmed (binary)

### AddTargetRangeSignal

```lua
Action.AddTargetRangeSignal(entityId, targetId, fRadius, fFlexibleBoundary, sSignal)
```

| Param | Description |
|---|---|
| ScriptHandle entityId | Identifier for the entity. |
| ScriptHandle targetId | Identifier for the target. |
| float fRadius | Radius of the range area. |
| float fFlexibleBoundary | Flexible boundary size. |
| const char * sSignal | String for signal. |

docs: y · retail: unconfirmed

### BanPlayer

```lua
Action.BanPlayer(entityId, message)
```

Bans a specified player.

| Param | Description |
|---|---|
| ScriptHandle entityId | Identifier for the entity. |
| const char* message | Message for the ban. |

docs: y · retail: confirmed (binary)

### BindGameObjectToNetwork

```lua
Action.BindGameObjectToNetwork(entityId)
```

Binds game object to the network.

| Param | Description |
|---|---|
| ScriptHandle entityId | Identifier for the entity. |

docs: y · retail: confirmed (binary)

### CacheItemGeometry

```lua
Action.CacheItemGeometry(itemName)
```

Caches an item geometry.

| Param | Description |
|---|---|
| const char * itemName | Item name string. |

docs: y · retail: confirmed (binary)

### CacheItemSound

```lua
Action.CacheItemSound(itemName)
```

Caches an item sound.

| Param | Description |
|---|---|
| const char * itemName | Item name string. |

docs: y · retail: confirmed (binary)

### ClearEntityTags

```lua
Action.ClearEntityTags(entityId)
```

Clears the tag for the specified entity.

| Param | Description |
|---|---|
| ScriptHandle entityId | Identifier for the entity. |

docs: y · retail: confirmed (binary)

### ClearStaticTag

```lua
Action.ClearStaticTag(entityId, staticId)
```

Clears the specified static tag for the specified entity.

| Param | Description |
|---|---|
| ScriptHandle entityId | Identifier for the entity. |
| const char * staticId | Identifier for the static tag. |

docs: y · retail: confirmed (binary)

### ConnectToServer

```lua
Action.ConnectToServer(server)
```

Connects to the specified server.

| Param | Description |
|---|---|
| char* server | String that specifies the server to be used for the connection. |

docs: y · retail: unconfirmed

### CreateGameObjectForEntity

```lua
Action.CreateGameObjectForEntity(entityId)
```

Creates a game object for the specified entity.

| Param | Description |
|---|---|
| ScriptHandle entityId | Identifier for the entity. |

docs: y · retail: confirmed (binary)

### DeleteDynamicEntities

```lua
Action.DeleteDynamicEntities()
```

C++: `int DeleteDynamicEntities (IFunctionHandler* pH )`

Deletes dynamic entities (like pieces of broken objects)

docs: y · retail: unconfirmed

### DestroyRangeSignaling

```lua
Action.DestroyRangeSignaling(entityId)
```

| Param | Description |
|---|---|
| ScriptHandle entityId | Identifier for the entity. |

docs: y · retail: confirmed (binary)

### DisableSignalTimer

```lua
Action.DisableSignalTimer(entityId, sText)
```

Disables the signal timer.

| Param | Description |
|---|---|
| ScriptHandle entityId | Identifier for the entity. |
| const char * sText | Text for the signal. |

docs: y · retail: confirmed (binary)

### DontSyncPhysics

```lua
Action.DontSyncPhysics(entityId)
```

Doesn't sync physics for the specified entity.

| Param | Description |
|---|---|
| ScriptHandle entityId | Identifier for the entity. |

docs: y · retail: confirmed (binary)

### EnableRangeSignaling

```lua
Action.EnableRangeSignaling(entityId, bEnable)
```

Enable/Disable range signalling for the specified entity.

| Param | Description |
|---|---|
| ScriptHandle entityId | Identifier for the entity. |
| bool bEnable | Enable/Disable range signalling. |

docs: y · retail: confirmed (binary)

### EnableSignalTimer

```lua
Action.EnableSignalTimer(entityId, sText)
```

Enables the signal timer.

| Param | Description |
|---|---|
| ScriptHandle entityId | Identifier for the entity. |
| const char * sText | Text for the signal. |

docs: y · retail: confirmed (binary)

### ForceGameObjectUpdate

```lua
Action.ForceGameObjectUpdate(entityId, force)
```

Forces the game object to be updated.

| Param | Description |
|---|---|
| ScriptHandle entityId | Identifier for the entity. |
| bool force | True to force the update, false otherwise. |

docs: y · retail: confirmed (binary)

### GetClassName

```lua
Action.GetClassName(classId)
```

C++: `int GetClassName (IFunctionHandler* pH , int classId )`

Returns the matching class name if available for specified classId.

docs: y · retail: confirmed (binary, mod×1)

### GetMemoryUsage

```lua
Action.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer* pSizer ) const`

This is GetMemoryUsage, a member of class CScriptBind_Action.

docs: y · retail: unconfirmed

### GetPlayerList

```lua
Action.GetPlayerList()
```

C++: `int GetPlayerList (IFunctionHandler * pH )`

Checks the current players list.

docs: y · retail: confirmed (binary)

### GetServer

```lua
Action.GetServer(number)
```

C++: `int GetServer (IFunctionHandler * pFH , int number )`

Gets the server.

docs: y · retail: confirmed (binary)

### GetServerTime

```lua
Action.GetServerTime()
```

C++: `int GetServerTime (IFunctionHandler * pFH )`

Gets the current time on the server.

docs: y · retail: confirmed (binary)

### GetWaterInfo

```lua
Action.GetWaterInfo(pos)
```

Gets information about the water at the position pos.

| Param | Description |
|---|---|
| Vec3 pos | Position to be checked. |

docs: y · retail: unconfirmed

### HasAI

```lua
Action.HasAI(entityId)
```

C++: `int HasAI (IFunctionHandler * pH , ScriptHandle entityId )`

Returns if the entity has an AI object associated to it, meaning it has been registered with the AI System

docs: y · retail: confirmed (binary)

### IsChannelOnHold

```lua
Action.IsChannelOnHold(channelId)
```

Checks if the specified channel is on hold.

| Param | Description |
|---|---|
| int channelId | Identifier for the channel. |

docs: y · retail: confirmed (binary)

### IsChannelSpecial

```lua
Action.IsChannelSpecial()
```

C++: `int IsChannelSpecial (IFunctionHandler * pH )`

Gets if the channel is a special one.

docs: y · retail: confirmed (binary)

### IsClient

```lua
Action.IsClient()
```

C++: `int IsClient (IFunctionHandler * pH )`

Checks if the current script runs on a client.

docs: y · retail: confirmed (binary)

### IsGameObjectProbablyVisible

```lua
Action.IsGameObjectProbablyVisible(gameObject)
```

Checks if an object is probably visible.

| Param | Description |
|---|---|
| ScriptHandle gameObject | Object that we want to check. |

docs: y · retail: confirmed (binary)

### IsGameStarted

```lua
Action.IsGameStarted()
```

C++: `int IsGameStarted (IFunctionHandler * pH )`

Checks if the game is started.

docs: y · retail: confirmed (binary)

### IsImmersivenessEnabled

```lua
Action.IsImmersivenessEnabled()
```

C++: `int IsImmersivenessEnabled (IFunctionHandler * pH )`

Gets if the immersive multiplayer is enabled.

docs: y · retail: confirmed (binary)

### IsRMIServer

```lua
Action.IsRMIServer()
```

C++: `int IsRMIServer (IFunctionHandler * pH )`

Checks if the current script is running on an RMI (Remote Method Invocation) server.

docs: y · retail: confirmed (binary)

### IsServer

```lua
Action.IsServer()
```

C++: `int IsServer (IFunctionHandler * pH )`

Checks if the current script runs on a server.

docs: y · retail: confirmed (binary)

### LoadXML

```lua
Action.LoadXML(definitionFile, dataFile)
```

| Param | Description |
|---|---|
| const char * definitionFile | . |
| const char * dataFile | XML-lua data file name. |

docs: y · retail: unconfirmed

### LoadXMLFromFile

```lua
Action.LoadXMLFromFile(const char * xmlFile)
```

| Param | Description |
|---|---|
| const char * xmlFile | . |

docs: y · retail: unconfirmed

### PauseGame

```lua
Action.PauseGame(pause)
```

Puts the game into pause mode.

| Param | Description |
|---|---|
| bool pause | True to set the game into the pause mode, false to resume the game. |

docs: y · retail: unconfirmed

### Persistant2DText

```lua
Action.Persistant2DText(text, size, color, name, timeout)
```

Adds a persistent 2D text.

| Param | Description |
|---|---|
| const char* text | Text that has to be displayed. |
| float size | Size of the 2D text. |
| Vec3 color | Color of the 2D text. |
| const char* name | Name assigned to the 2D text. |
| float timeout | Timeout for the 2D text. |

docs: y · retail: unconfirmed

### PersistantArrow

```lua
Action.PersistantArrow(pos, radius, dir, color, name, timeout)
```

Adds a persistent arrow to the world.

| Param | Description |
|---|---|
| Vec3 pos | Position of the arrow. |
| float radius | Radius of the arrow. |
| Vec3 dir | Direction of the arrow. |
| Vec3 color | Color of the arrow. |
| const char* name | Name assigned to the arrow. |
| float timeout | Timeout for the arrow. |

docs: y · retail: unconfirmed

### PersistantEntityTag

```lua
Action.PersistantEntityTag(entityId, text)
```

Adds a persistent entity tag.

Required Params: entityId, const char *text Optional Params: float size, Vec3 color, float visibleTime, float fadeTime, float viewDistance, const char* staticId, int columnNum, const char* contextTag

| Param | Description |
|---|---|
| ScriptHandle entityId | Identifier for the entity. |
| const char * text | Text for the entity tag. |

docs: y · retail: confirmed (binary)

### PersistantLine

```lua
Action.PersistantLine(start, end, color, name, timeout)
```

Adds a persistent line to the world.

| Param | Description |
|---|---|
| Vec3 start | Starting position of the line. |
| Vec3 end | Ending position of the line. |
| Vec3 color | Color of the line. |
| const char* name | Name assigned to the line. |
| float timeout | Timeout for the line. |

docs: y · retail: unconfirmed

### PersistantSphere

```lua
Action.PersistantSphere(pos, radius, color, name, timeout)
```

Adds a persistent sphere to the world.

| Param | Description |
|---|---|
| Vec3 pos | Position of the sphere. |
| float radius | Radius of the sphere. |
| Vec3 color | Color of the sphere. |
| const char* name | Name assigned to the sphere. |
| float timeout | Timeout for the sphere. |

docs: y · retail: unconfirmed

### PreLoadADB

```lua
Action.PreLoadADB(adbFileName)
```

Use this function to pre-cache ADB files.

Pre-load a mannequin ADB file.

In: The function handler (NULL is invalid!) In: The name of the ADB file.

| Param | Description |
|---|---|
| const char* adbFileName | The path and filename of the animation ADB file which is to be pre-loaded. |

Returns: A default result code (in Lua: void).

docs: y · retail: confirmed (binary)

### RefreshPings

```lua
Action.RefreshPings()
```

C++: `int RefreshPings (IFunctionHandler * pFH )`

Refreshes pings for all the servers listed.

docs: y · retail: confirmed (binary)

### RegisterWithAI

```lua
Action.RegisterWithAI()
```

C++: `int RegisterWithAI (IFunctionHandler* pH )`

Registers the entity to AI System, creating an AI object associated to it.

(MATT) Moved here from ScriptBindAI when that was moved to the AI system {2008/02/15:15:23:16

docs: y · retail: confirmed (binary, vanilla×3)

### Release

```lua
Action.Release()
```

C++: `void Release ()`

This is Release, a member of class CScriptBind_Action.

docs: y · retail: unconfirmed

### ResetRangeSignaling

```lua
Action.ResetRangeSignaling(entityId)
```

| Param | Description |
|---|---|
| ScriptHandle entityId | Identifier for the entity. |

docs: y · retail: confirmed (binary)

### ResetSignalTimer

```lua
Action.ResetSignalTimer(entityId, sText)
```

Resets the rate for the signal timer.

| Param | Description |
|---|---|
| ScriptHandle entityId | Identifier for the entity. |
| const char * sText | Text for the signal. |

docs: y · retail: confirmed (binary)

### ResetToNormalCamera

```lua
Action.ResetToNormalCamera()
```

C++: `int ResetToNormalCamera (IFunctionHandler * pH )`

Resets the camera to the last valid view stored.

docs: y · retail: confirmed (binary)

### SaveXML

```lua
Action.SaveXML(definitionFile, dataFile, dataTable)
```

| Param | Description |
|---|---|
| const char * definitionFile | . |
| const char * dataFile | XML-lua data file name. |
| SmartScriptTable dataTable | . |

docs: y · retail: unconfirmed

### SendGameplayEvent

```lua
Action.SendGameplayEvent(entityId, event)
```

Sends an event for the gameplay.

| Param | Description |
|---|---|
| ScriptHandle entityId | Identifier for the entity. |
| int event | Integer for the event. |

docs: y · retail: confirmed (binary)

### SetAimQueryMode

```lua
Action.SetAimQueryMode(entityId, mode)
```

Set the aim query mode for the ai proxy. Normally the ai proxy ! asks the movement controller if the character is aiming. ! You can override that and set your own 'isAiming' state.

| Param | Description |
|---|---|
| ScriptHandle entityId | Identifier for the entity. |
| int mode | QueryAimFromMovementController or OverriddenAndAiming or OverriddenAndNotAiming |

docs: y · retail: confirmed (binary)

### SetNetworkParent

```lua
Action.SetNetworkParent(entityId, parentId)
```

Sets the network parent.

| Param | Description |
|---|---|
| ScriptHandle entityId | Identifier for the entity. |
| parentID | Identifier for the parent network. |

docs: y · retail: unconfirmed

### SetSignalTimerRate

```lua
Action.SetSignalTimerRate(entityId, sText, fRateMin, fRateMax)
```

Sets the rate for the signal timer.

| Param | Description |
|---|---|
| ScriptHandle entityId | Identifier for the entity. |
| const char * sText | Text for the signal. |
| float fRateMin | Minimum rate for the signal timer. |
| float fRateMax | Maximum rate for the signal timer. |

docs: y · retail: unconfirmed

### SetViewCamera

```lua
Action.SetViewCamera()
```

C++: `int SetViewCamera (IFunctionHandler * pH )`

Saves the previous valid view and override it with the current camera settings.

docs: y · retail: confirmed (binary)

### SetViewCameraByAngles

```lua
Action.SetViewCameraByAngles()
```

C++: `int SetViewCameraByAngles (IFunctionHandler* pH )`

Saves the previous valid view and override it with the current camera settings, given using a similar format as ed_goto.

docs: y · retail: confirmed (binary)

## Undocumented (present in retail, not in official docs)

### AddAngleSignal

`Action.AddAngleSignal(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)
