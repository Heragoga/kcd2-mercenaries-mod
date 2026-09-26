# VehicleSeat

C++ class(es): `CScriptBindVehicleSeat`, `CScriptBind_VehicleSeat`
Reached from Lua as `VehicleSeat.FunctionName(...)`.
15 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### AttachTo

```lua
VehicleSeat.AttachTo()
```

C++: `void AttachTo (IVehicle * pVehicle , TVehicleSeatId seatId )`

docs: y · retail: unconfirmed

### GetMemoryUsage

```lua
VehicleSeat.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer* pSizer ) const`

This is GetMemoryUsage, a member of class CScriptBind_VehicleSeat.

docs: y · retail: unconfirmed

### GetPassengerId

```lua
VehicleSeat.GetPassengerId()
```

C++: `int GetPassengerId (IFunctionHandler* pH )`

Gets the passenger identifier.

docs: y · retail: unconfirmed

### GetVehicleSeat

```lua
VehicleSeat.GetVehicleSeat()
```

C++: `CVehicleSeat* GetVehicleSeat (IFunctionHandler * pH )`

Gets the vehicle seat identifier.

docs: y · retail: unconfirmed

### GetWeaponCount

```lua
VehicleSeat.GetWeaponCount()
```

C++: `int GetWeaponCount (IFunctionHandler* pH )`

Gets the number of weapons available on this seat.

docs: y · retail: unconfirmed

### GetWeaponId

```lua
VehicleSeat.GetWeaponId(weaponIndex)
```

Gets the weapon identifier.

| Param | Description |
|---|---|
| int weaponIndex | Weapon identifier. |

docs: y · retail: unconfirmed

### IsDriver

```lua
VehicleSeat.IsDriver()
```

C++: `int IsDriver (IFunctionHandler* pH )`

Checks if the seat is the driver seat.

docs: y · retail: unconfirmed

### IsFree

```lua
VehicleSeat.IsFree(actor)
```

Checks if the seat is free.

| Param | Description |
|---|---|
| ScriptHandle actorHandle | Passenger identifier. |

docs: y · retail: unconfirmed

### IsGunner

```lua
VehicleSeat.IsGunner()
```

C++: `int IsGunner (IFunctionHandler* pH )`

Checks if the seat is the gunner seat.

docs: y · retail: unconfirmed

### IsLocked

```lua
VehicleSeat.IsLocked(actor)
```

Checks if the seat is locked for the specified actor.

| Param | Description |
|---|---|
| ScriptHandle actorHandle | Passenger identifier. |

docs: y · retail: confirmed (vanilla×2)

### Release

```lua
VehicleSeat.Release()
```

C++: `void Release ()`

This is Release, a member of class CScriptBind_VehicleSeat.

docs: y · retail: unconfirmed

### RemovePassenger

```lua
VehicleSeat.RemovePassenger()
```

C++: `int RemovePassenger (IFunctionHandler* pH )`

Removes the passenger from the seat.

docs: y · retail: unconfirmed

### Reset

```lua
VehicleSeat.Reset()
```

C++: `int Reset (IFunctionHandler * pH )`

Resets the vehicle seat.

docs: y · retail: confirmed (binary, vanilla×81)

### SetAIWeapon

```lua
VehicleSeat.SetAIWeapon(weaponHandle)
```

Sets the weapon artificial intelligence.

| Param | Description |
|---|---|
| ScriptHandle weaponHandle | Weapon identifier. |

docs: y · retail: unconfirmed

### SetPassenger

```lua
VehicleSeat.SetPassenger(ScriptHandle passengerHandle, bool isThirdPerson)
```

Sets the specified passenger to the seat.

| Param | Description |
|---|---|
| ScriptHandle passengerHandle | Passenger identifier. |
| bool isThirdPerson | True if we are using the third person view, false otherwise. |

docs: y · retail: unconfirmed
