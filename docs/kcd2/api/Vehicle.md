# Vehicle

C++ class(es): `CScriptBindVehicle`, `CScriptBind_Vehicle`
Reached from Lua as `Vehicle.FunctionName(...)`.
60 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### AddSeat

```lua
Vehicle.AddSeat(paramsTable)
```

Adds a seat to the vehicle.

| Param | Description |
|---|---|
| SmartScriptTable paramsTable | Seat parameters. |

docs: y · retail: unconfirmed

### AttachTo

```lua
Vehicle.AttachTo()
```

C++: `void AttachTo (IVehicle* pVehicle )`

docs: y · retail: unconfirmed

### BlockAutomaticDoors

```lua
Vehicle.BlockAutomaticDoors()
```

C++: `int BlockAutomaticDoors (IFunctionHandler * pH , bool isBlocked )`

Broadcast to the vehicle the message to automatically block the doors.

docs: y · retail: unconfirmed

### ChangeSeat

```lua
Vehicle.ChangeSeat(actorHandle, seatId, isAnimationEnabled)
```

Makes the actor changing the seat inside the vehicle.

| Param | Description |
|---|---|
| ScriptHandle actorHandle | Actor identifier. |
| int seatId | Seat identifier. |
| bool isAnimationEnabled | True to enable the animation, false otherwise. |

docs: y · retail: unconfirmed

### CloseAutomaticDoors

```lua
Vehicle.CloseAutomaticDoors()
```

C++: `int CloseAutomaticDoors (IFunctionHandler * pH )`

Broadcast to the vehicle the message to automatically close the doors.

docs: y · retail: unconfirmed

### Destroy

```lua
Vehicle.Destroy()
```

C++: `int Destroy (IFunctionHandler* pH )`

Destroys the vehicle.

docs: y · retail: confirmed (binary, vanilla×1)

### DisableEngine

```lua
Vehicle.DisableEngine(disable)
```

Disables/enables the engine of the vehicle.

| Param | Description |
|---|---|
| bool disable | True to disable the engine, false to enable. |

docs: y · retail: unconfirmed

### EnableMovement

```lua
Vehicle.EnableMovement(enable)
```

Enables/disables the movement of the vehicle.

| Param | Description |
|---|---|
| bool enable | True to enable movement, false to disable. |

docs: y · retail: unconfirmed

### EnterVehicle

```lua
Vehicle.EnterVehicle(actorHandle, seatId, isAnimationEnabled)
```

Makes the actor entering the vehicle.

| Param | Description |
|---|---|
| ScriptHandle actorHandle | Actor identifier. |
| int seatId | Seat identifier. |
| bool isAnimationEnabled | True to enable the animation, false otherwise. |

docs: y · retail: unconfirmed

### ExitVehicle

```lua
Vehicle.ExitVehicle(actorHandle)
```

Makes the actor going out from the vehicle.

| Param | Description |
|---|---|
| ScriptHandle actorHandle | Actor identifier. |

docs: y · retail: unconfirmed

### ExtractGears

```lua
Vehicle.ExtractGears()
```

C++: `int ExtractGears (IFunctionHandler * pH )`

Broadcast to the vehicle the message to extract gears.

docs: y · retail: unconfirmed

### GetCollisionDamageThreshold

```lua
Vehicle.GetCollisionDamageThreshold()
```

Gets the collision damage threshold.

| Param | Description |
|---|---|
| pComponentName | Name of the component. |

docs: y · retail: unconfirmed

### GetComponentDamageRatio

```lua
Vehicle.GetComponentDamageRatio(componentName)
```

C++: `int GetComponentDamageRatio (IFunctionHandler* pH , const char * pComponentName )`

Gets the damage ratio of the specified component.

docs: y · retail: unconfirmed

### GetExtensionParams

```lua
Vehicle.GetExtensionParams(const char *extension, SmartScriptTable params)
```

Gets extension parameters.

| Param | Description |
|---|---|
| const char * extension | Extension name. |
| SmartScriptTable params | Extension parameters |

docs: y · retail: confirmed (binary)

### GetFrozenAmount

```lua
Vehicle.GetFrozenAmount()
```

C++: `int GetFrozenAmount (IFunctionHandler * pH )`

Gets the frozen amount.

docs: y · retail: unconfirmed

### GetHelperDir

```lua
Vehicle.GetHelperDir(name, isInVehicleSpace)
```

Gets the helper direction.

| Param | Description |
|---|---|
| const char* name | Helper name. |
| bool isInVehicleSpace | . |

docs: y · retail: confirmed (binary, vanilla×3)

### GetHelperPos

```lua
Vehicle.GetHelperPos(name, isInVehicleSpace)
```

Gets the helper position.

| Param | Description |
|---|---|
| const char* name | Helper name. |
| bool isInVehicleSpace | . |

docs: y · retail: confirmed (binary)

### GetHelperWorldPos

```lua
Vehicle.GetHelperWorldPos(name)
```

Gets the helper position in the world coordinates.

| Param | Description |
|---|---|
| const char* name | Helper name. |

docs: y · retail: unconfirmed

### GetMemoryUsage

```lua
Vehicle.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer* pSizer ) const`

This is GetMemoryUsage, a member of class CScriptBind_Vehicle.

docs: y · retail: unconfirmed

### GetMovementDamageRatio

```lua
Vehicle.GetMovementDamageRatio()
```

C++: `int GetMovementDamageRatio (IFunctionHandler* pH )`

Gets the movement damage ratio.

docs: y · retail: unconfirmed

### GetMovementType

```lua
Vehicle.GetMovementType()
```

C++: `int GetMovementType (IFunctionHandler* pH )`

Gets the movement type.

docs: y · retail: unconfirmed

### GetOwnerId

```lua
Vehicle.GetOwnerId()
```

C++: `int GetOwnerId (IFunctionHandler * pH )`

Gets the vehicle owner identifier.

docs: y · retail: confirmed (binary)

### GetRepairableDamage

```lua
Vehicle.GetRepairableDamage()
```

C++: `int GetRepairableDamage (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### GetSeatForPassenger

```lua
Vehicle.GetSeatForPassenger(id)
```

Returns the vehicle seat id for the specified passenger

| Param | Description |
|---|---|
| id | passenger id. |

docs: y · retail: unconfirmed

### GetSelfCollisionMult

```lua
Vehicle.GetSelfCollisionMult(Vec3 velocity, Vec3 normal, int partId, ScriptHandle colliderId)
```

Gets self collision mult.

| Param | Description |
|---|---|
| Vec3 velocity | Velocity vector. |
| Vec3 normal | Normal vector. |
| int partId | Part identifier. |
| ScriptHandle colliderId | Collider identifier. |

docs: y · retail: unconfirmed

### GetVehicle

```lua
Vehicle.GetVehicle()
```

C++: `CVehicle* GetVehicle (IFunctionHandler * pH )`

Gets the vehicle identifier.

docs: y · retail: unconfirmed

### GetVehiclePhysicsStatus

```lua
Vehicle.GetVehiclePhysicsStatus(SmartScriptTable statusTable)
```

Gets the vehicle physics status.

| Param | Description |
|---|---|
| SmartScriptTable statusTable | Status table of the vehicle. |

docs: y · retail: unconfirmed

### HasHelper

```lua
Vehicle.HasHelper(name)
```

Checks if the vehicle has the specified helper.

| Param | Description |
|---|---|
| const char* name | Helper name. |

docs: y · retail: unconfirmed

### IsDestroyed

```lua
Vehicle.IsDestroyed()
```

C++: `int IsDestroyed (IFunctionHandler* pH )`

Checks if the vehicle is destroyed.

docs: y · retail: confirmed (binary, vanilla×2)

### IsEmpty

```lua
Vehicle.IsEmpty()
```

C++: `int IsEmpty (IFunctionHandler * pH )`

Checks if the vehicle is empty.

docs: y · retail: unconfirmed

### IsFlipped

```lua
Vehicle.IsFlipped()
```

C++: `int IsFlipped (IFunctionHandler* pH )`

Checks if the vehicle is flipped.

docs: y · retail: unconfirmed

### IsInsideRadius

```lua
Vehicle.IsInsideRadius(pos, radius)
```

C++: `int IsInsideRadius (IFunctionHandler * pH , Vec3 pos , float radius )`

Checks if the vehicle is inside the specified radius.

docs: y · retail: unconfirmed

### IsPartInsideRadius

```lua
Vehicle.IsPartInsideRadius(int slot, Vec3 pos, float radius)
```

Checks if a part is inside the specified radius.

| Param | Description |
|---|---|
| int slot | . |
| Vec3 pos | . |
| float radius | . |

docs: y · retail: unconfirmed

### IsSubmerged

```lua
Vehicle.IsSubmerged()
```

C++: `int IsSubmerged (IFunctionHandler* pH )`

Checks if the vehicle is submerged.

docs: y · retail: unconfirmed

### IsUsable

```lua
Vehicle.IsUsable(userHandle)
```

Checks if the vehicle is usable by the user.

| Param | Description |
|---|---|
| ScriptHandle userHandle | User identifier. |

docs: y · retail: confirmed (vanilla×47, mod×1)

### KillAbandonTimer

```lua
Vehicle.KillAbandonTimer()
```

C++: `int KillAbandonTimer (IFunctionHandler * pH )`

Kills the abandon timer.

docs: y · retail: unconfirmed

### MultiplyWithEntityLocalTM

```lua
Vehicle.MultiplyWithEntityLocalTM(ScriptHandle entityHandle, Vec3 pos)
```

Multiplies with the entity local transformation matrix.

| Param | Description |
|---|---|
| ScriptHandle entityHandle | Entity identifier. |
| Vec3 pos | Position vector. |

docs: y · retail: unconfirmed

### MultiplyWithWorldTM

```lua
Vehicle.MultiplyWithWorldTM(pos)
```

Multiplies with the world transformation matrix.

| Param | Description |
|---|---|
| Vec3 pos | Position vector. |

docs: y · retail: unconfirmed

### OnHit

```lua
Vehicle.OnHit(targetId, shooterId, damage, position, radius, pHitClass, explosion)
```

Event that occurs after the vehicle is hit.

| Param | Description |
|---|---|
| ScriptHandle targetId | Target identifier. |
| ScriptHandle shooterId | Shooter identifier. |
| float damage | Damage amount. |
| float radius | Radius of the hit. |
| int hitTypeId | Hit type. |
| bool explosion | True if the hit cause an explosion, false otherwise. |

docs: y · retail: confirmed (vanilla×16)

### OnPassengerKilled

```lua
Vehicle.OnPassengerKilled(ScriptHandle passengerHandle)
```

Event that occurs if the passenger is killed.

| Param | Description |
|---|---|
| ScriptHandle passengerHandle | Passenger identifier. |

docs: y · retail: unconfirmed

### OnSpawnComplete

```lua
Vehicle.OnSpawnComplete()
```

C++: `int OnSpawnComplete (IFunctionHandler* pH )`

Callback into game code for OnSpawnComplete.

docs: y · retail: unconfirmed

### OnUsed

```lua
Vehicle.OnUsed(userHandle, index)
```

Events that occurs when the user uses the vehicle.

| Param | Description |
|---|---|
| ScriptHandle userHandle | User identifier. |
| int index | Seat identifier. |

docs: y · retail: confirmed (binary, vanilla×36, mod×1)

### OpenAutomaticDoors

```lua
Vehicle.OpenAutomaticDoors()
```

C++: `int OpenAutomaticDoors (IFunctionHandler * pH )`

Broadcast to the vehicle the message to automatically open the doors.

docs: y · retail: unconfirmed

### ProcessPassengerDamage

```lua
Vehicle.ProcessPassengerDamage(passengerId, actorHealth, damage, pDamageClass, explosion)
```

Processes passenger damages.

| Param | Description |
|---|---|
| ScriptHandle passengerId | Passenger identifier. |
| float actorHealth | Actor health amount. |
| float damage | Damage amount. |
| int hitTypeId | Damage type. |
| bool explosion | True if there is an explosion, false otherwise. |

docs: y · retail: unconfirmed

### RefreshPhysicsGeometry

```lua
Vehicle.RefreshPhysicsGeometry(ScriptHandle partHandle, int slot, int physIndex)
```

Refreshes the physics geometry.

| Param | Description |
|---|---|
| ScriptHandle partHandle | . |
| int physIndex | . |

docs: y · retail: unconfirmed

### Release

```lua
Vehicle.Release()
```

C++: `void Release ()`

This is Release, a member of class CScriptBind_Vehicle.

docs: y · retail: unconfirmed

### Reset

```lua
Vehicle.Reset()
```

C++: `int Reset (IFunctionHandler * pH )`

Resets the vehicle.

docs: y · retail: confirmed (binary, vanilla×81)

### ResetSlotGeometry

```lua
Vehicle.ResetSlotGeometry(slot, filename, geometry)
```

C++: `int ResetSlotGeometry (IFunctionHandler* pH , int slot , const char * filename , const char * geometry )`

docs: y · retail: unconfirmed

### RetractGears

```lua
Vehicle.RetractGears()
```

C++: `int RetractGears (IFunctionHandler * pH )`

Broadcast to the vehicle the message to retract gears.

docs: y · retail: unconfirmed

### SetAmmoCount

```lua
Vehicle.SetAmmoCount(const char *name, int amount)
```

Sets the amount of the specified ammunition.

| Param | Description |
|---|---|
| const char * name | Ammunition name. |
| int amount | Amount of the ammunition. |

docs: y · retail: unconfirmed

### SetExtensionActivation

```lua
Vehicle.SetExtensionActivation(const char *extension, bool bActivated)
```

Activates/deactivates the extension.

| Param | Description |
|---|---|
| const char * extension | Extension name. |
| bool bActivated | True to activate the extension, false to deactivate it. |

docs: y · retail: unconfirmed

### SetExtensionParams

```lua
Vehicle.SetExtensionParams(const char *extension, SmartScriptTable params)
```

Sets extension parameters.

| Param | Description |
|---|---|
| const char * extension | Extension name. |
| SmartScriptTable params | Extension parameters |

docs: y · retail: confirmed (binary, vanilla×2)

### SetFrozenAmount

```lua
Vehicle.SetFrozenAmount(float frost)
```

Sets the frozen amount.

| Param | Description |
|---|---|
| float frost | Frost amount. |

docs: y · retail: unconfirmed

### SetMaxSpeed

```lua
Vehicle.SetMaxSpeed(id)
```

C++: `int SetMaxSpeed (IFunctionHandler* pH , float speed )`

Sets the maximum/top speed of a vehicle

docs: y · retail: unconfirmed

### SetMovementMode

```lua
Vehicle.SetMovementMode(int mode)
```

Sets the movement mode.

| Param | Description |
|---|---|
| int mode | Movement mode. |

docs: y · retail: unconfirmed

### SetMovementSoundVolume

```lua
Vehicle.SetMovementSoundVolume(float volume)
```

Sets the sound volume for the movement.

| Param | Description |
|---|---|
| float volume | Sound volume for the movement. |

docs: y · retail: unconfirmed

### SetOwnerId

```lua
Vehicle.SetOwnerId(ScriptHandle ownerId)
```

Sets the owner identifier for the vehicle.

| Param | Description |
|---|---|
| ScriptHandle ownerId | Owner identifier. |

docs: y · retail: unconfirmed

### SetPlayerToSit

```lua
Vehicle.SetPlayerToSit(ScriptHandle playerId, int flags)
```

Sets the player sitting into the vehicle.

| Param | Description |
|---|---|
| ScriptHandle playerId | Player identifier. |
| int flags | Flag to identify where the player is. |

docs: y · retail: unconfirmed

### StartAbandonTimer

```lua
Vehicle.StartAbandonTimer(bool force, float timer)
```

Starts the abandon timer.

| Param | Description |
|---|---|
| force | True to force the abandon, false otherwise. |
| timer | Timer value. |

docs: y · retail: unconfirmed

### UpdateVehicleAnimation

```lua
Vehicle.UpdateVehicleAnimation(ScriptHandle entity, int slot)
```

Updates the vehicle animation.

| Param | Description |
|---|---|
| ScriptHandle entity | Entity identifier. |
| int slot | Slot number. |

docs: y · retail: unconfirmed
