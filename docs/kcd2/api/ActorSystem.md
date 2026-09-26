# ActorSystem

C++ class(es): `CScriptBindActorSystem`, `CScriptBind_ActorSystem`
Reached from Lua as `ActorSystem.FunctionName(...)`.
3 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### CreateActor

```lua
ActorSystem.CreateActor(channelId, actorParams)
```

Creates an actor.

Example on how to use this function:

local params = { name = "dude", class = "CSpectator", position = {x=0, y=0, z=0}, rotation = {x=0, y=0, z=0}, scale = {x=1, y=1, z=1} }

Actor.CreateActor( channelId, params );

| Param | Description |
|---|---|
| int channelId | Identifier for the network channel. |
| SmartScriptTable actorParams | Parameters for the actor. |

docs: y · retail: unconfirmed

### GetMemoryUsage

```lua
ActorSystem.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer* pSizer ) const`

This is GetMemoryUsage, a member of class CScriptBind_ActorSystem.

docs: y · retail: unconfirmed

### Release

```lua
ActorSystem.Release()
```

C++: `void Release ()`

This is Release, a member of class CScriptBind_ActorSystem.

docs: y · retail: unconfirmed
