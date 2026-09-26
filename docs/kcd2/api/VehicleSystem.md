# VehicleSystem

C++ class(es): `CScriptBindVehicle`, `CScriptBindVehicleSystem`, `CScriptBind_VehicleSystem`
Reached from Lua as `VehicleSystem.FunctionName(...)`.
9 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### AttachTo

```lua
VehicleSystem.AttachTo()
```

C++: `void AttachTo (IVehicle * pVehicle )`

docs: y · retail: unconfirmed

### GetMemoryUsage

```lua
VehicleSystem.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer* pSizer ) const`

This is GetMemoryUsage, a member of class CScriptBind_VehicleSystem.

docs: y · retail: unconfirmed

### GetOptionalScript

```lua
VehicleSystem.GetOptionalScript(vehicleName)
```

C++: `int GetOptionalScript (IFunctionHandler* pH , char * vehicleName )`

Get an (optional) script for the named vehicle.

docs: y · retail: unconfirmed

### GetVehicleImplementations

```lua
VehicleSystem.GetVehicleImplementations()
```

C++: `int GetVehicleImplementations (IFunctionHandler* pH )`

Get a table of all implemented vehicles.

docs: y · retail: unconfirmed

### LogSlots

```lua
VehicleSystem.LogSlots()
```

C++: `int LogSlots (IFunctionHandler * pH , char * vehicleName )`

docs: y · retail: unconfirmed

### Release

```lua
VehicleSystem.Release()
```

C++: `void Release ()`

This is Release, a member of class CScriptBind_VehicleSystem.

docs: y · retail: unconfirmed

### ReloadSystem

```lua
VehicleSystem.ReloadSystem()
```

C++: `int ReloadSystem (IFunctionHandler * pH )`

Reloads the vehicle system with default values.

docs: y · retail: unconfirmed

### SetTpvDistance

```lua
VehicleSystem.SetTpvDistance(distance)
```

C++: `int SetTpvDistance (IFunctionHandler * pH , float distance )`

Distance of camera in third person view.

docs: y · retail: unconfirmed

### SetTpvHeight

```lua
VehicleSystem.SetTpvHeight(height)
```

C++: `int SetTpvHeight (IFunctionHandler * pH , float height )`

Height of camera in third person view.

docs: y · retail: unconfirmed
