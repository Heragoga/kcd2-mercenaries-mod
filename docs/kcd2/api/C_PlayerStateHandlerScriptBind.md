# C_PlayerStateHandlerScriptBind

C++ class(es): `C_PlayerStateHandlerScriptBind`
Reached from Lua as `C_PlayerStateHandlerScriptBind.FunctionName(...)`.
7 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### ChangeStance

```lua
C_PlayerStateHandlerScriptBind.ChangeStance(Wuid stanceObject, string stance)
```

C++: `int ChangeStance (IFunctionHandler* ph , framework::T_WUIDScriptType stanceObject , const char * stance )`

Executes the NPC state change request with the specified stance as the required state

docs: y · retail: confirmed (binary)

### ChangeUnstaceJoined

```lua
C_PlayerStateHandlerScriptBind.ChangeUnstaceJoined(Wuid unstanceObject, string unstance, ScriptTable synchronizationData)
```

C++: `int ChangeUnstanceJoined (IFunctionHandler* ph , framework::T_WUIDScriptType unstanceObject , const char * unstance , SmartScriptTable syncData )`

Executes the NPC state change request with the specified unstance as the requested state. The difference to previous script bind is that this one provides a way to executed joined unstance.

The script bind may contain optional parameter: string slaveLinkName

docs: y · retail: unconfirmed

### ChangeUnstance

```lua
C_PlayerStateHandlerScriptBind.ChangeUnstance(Wuid unstanceObject, string unstance)
```

C++: `int ChangeUnstance (IFunctionHandler* ph , framework::T_WUIDScriptType unstanceObject , const char * unstance )`

Executes the NPC state change request with the specified unstance as the required state. The unstanceObject may be invalid wuid for unstance without location object.

The script bind may contain optional parameters: string slaveLinkName

docs: y · retail: confirmed (binary)

### EndHostResourcesPlayAnimationAction

```lua
C_PlayerStateHandlerScriptBind.EndHostResourcesPlayAnimationAction()
```

C++: `int EndHostResourcesPlayAnimationAction (IFunctionHandler* ph )`

Ends hosting resources previously requested by HostResourcesPlayAnimationAction. It is not necessary to call this function if PlayAnimationAction is called.

docs: y · retail: confirmed (binary)

### HostResourcesPlayAnimationAction

```lua
C_PlayerStateHandlerScriptBind.HostResourcesPlayAnimationAction(Wuid alignObject, string fragment, string tags, EntityId callbackEntityId, bool isHold)
```

C++: `int HostResourcesPlayAnimationAction (IFunctionHandler* ph , framework::T_WUIDScriptType alignObject , const char * fragmentName , const char * tags , ScriptHandle callbackEntityId , bool isHold )`

Starts holding resources necessary for the PlayAnimationAction. Return true if hosting of resources is successfully attempted, returns false otherwise. If the resource hosting is started successfully the callback will be called. Either OnResourcesHosted is called if when the resources are hosted or OnResourcesTakenAway if there is a NPC with priority override. The callback may be called directly from within calling this scripting (if resources are hosted immediately)

The script bind may contain optional parameters: string slaveLinkName, string resourceOveride

docs: y · retail: confirmed (binary)

### PlayAnimationAction

```lua
C_PlayerStateHandlerScriptBind.PlayAnimationAction(Wuid alignObject, string fragment, string tags, ScriptTable synchronizationData, EntityId triggerEntityId, bool isHold)
```

C++: `int PlayAnimationActionJoined (IFunctionHandler* ph , framework::T_WUIDScriptType alignObject , const char * fragmentName , const char * tags , SmartScriptTable syncData , ScriptHandle triggerEntityId , bool isHold )`

Executes the NPC state change request with animation action as a extra action. The animation action is synchronized according to the synchronization data. The alignObject may be invalid wuid if the alignment and resource hosting is not required.

The script bind may contain optional parameters: string slaveLinkName, string resourceOveride, string triggerPointId, bool allowTorchForPlayer

docs: y · retail: confirmed (binary)

### StartMinigame

```lua
C_PlayerStateHandlerScriptBind.StartMinigame(EntityId minigameObjectId, int minigameType, Wuid, resourceObjectId, string resourceName, int interruptUrgency)
```

C++: `int StartMinigame (IFunctionHandler* ph , ScriptHandle minigameObjectId , int minigameType , framework::T_WUIDScriptType resourceObjectId , const char * resourceName , int interruptUrgency )`

Starts minigame after the resource is hosted by the player state handler. If defined by a link from resource object, an interrupt is scheduled to the blocking NPC using the specified urgency

docs: y · retail: unconfirmed
