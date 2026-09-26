# Physics

C++ class(es): `CScriptBindPhysics`, `CScriptBind_Physics`
Reached from Lua as `Physics.FunctionName(...)`.
7 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### GetMemoryUsage

```lua
Physics.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer * pSizer ) const`

This is GetMemoryUsage, a member of class CScriptBind_Physics.

docs: y · retail: unconfirmed

### RayTraceCheck

```lua
Physics.RayTraceCheck(src, dst, skipEntityId1, skipEntityId2)
```

Check if ray segment from src to dst intersect anything.

| Param | Description |
|---|---|
| Vec3 src | Ray segment origin point. |
| Vec3 dst | Ray segment end point. |
| ScriptHandle skipEntityId1 | Entity id to skip when checking for intersection. |
| ScriptHandle skipEntityId2 | Entity id to skip when checking for intersection. |

docs: y · retail: confirmed (binary, runtime dump)

### RayWorldIntersection

```lua
Physics.RayWorldIntersection(vPos, vDir, nMaxHits, iEntTypes [, skipEntityId1 [, skipEntityId2]])
```

Check if ray segment from src to dst intersect anything.

| Param | Description |
|---|---|
| vPos | Ray origin point. |
| vDir | Ray direction. |
| nMaxHits | Max number of hits to return, sorted in nearest to farest order. |
| iEntTypes | Physical Entity types bitmask, ray will only intersect with entities specified by this mask (ent_all,...). |
| skipEntityId1 | (optional) Entity id to skip when checking for intersection. |
| skipEntityId2 | (optional) Entity id to skip when checking for intersection. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Physics/PressurizedObject.lua`), mod×13)

### RegisterExplosionCrack

```lua
Physics.RegisterExplosionCrack(sGeometryFile, int nMaterialId)
```

Register a new crack for breakable object.

| Param | Description |
|---|---|
| const char* sGeometryFile | Static geometry file name fro the crack (CGF). |
| nMaterialId | ID of the breakable material to apply this crack on. |

docs: y · retail: confirmed (runtime dump)

### RegisterExplosionShape

```lua
Physics.RegisterExplosionShape(sGeometryFile, fSize, nMaterialId, fProbability, sSplintersFile, fSplintersOffset, sSplintersCloudEffect)
```

Register a new explosion shape from the static geometry. ! Does not apply any game related explosion damages, this function only apply physical forces. !

| Param | Description |
|---|---|
| const char* sGeometryFile | Static geometry file name (CGF). |
| float fSize | Scale for the static geometry. |
| float fProbability | Preference ratio of using this shape then other registered shape. |
| const char* sSplintersFile | additional non-physicalized splinters cgf to place on cut surfaces. |
| float fSplintersOffset | the lower splinters piece wrt to the upper one. |
| const char* sSplintersCloudEffect | particle effect when the splinters constraint breaks. |
| nMaterialId | ID of the breakable material to apply this shape on. |

docs: y · retail: confirmed (runtime dump, vanilla×3 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/physics.lua`))

### SamplePhysEnvironment

```lua
Physics.SamplePhysEnvironment(pt, r [, objtypes])
```

Find physical entities touched by a sphere.

| Param | Description |
|---|---|
| pt | center of sphere. |
| r | radius of sphere. |
| objtypes | (optional) physics entity types. |

docs: y · retail: confirmed (runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Physics/Cloth.lua`))

### SimulateExplosion

```lua
Physics.SimulateExplosion(explosionParams)
```

Simulate physical explosion. ! Does not apply any game related explosion damages, this function only apply physical forces. ! The parameters are passed as a table containing the elements described below. !

| Param | Description |
|---|---|
| pos | Explosion epicenter position. |
| radius | Explosion radius. |
| direction | Explosion impulse direction. |
| impulse_pos | Explosion impulse position (Can be different from explosion epicenter). |
| impulse_presure | Explosion impulse presur at radius distance from epicenter. |
| rmin | Explosion minimal radius, at this radius full pressure is applied. |
| rmax | Explosion maximal radius, at this radius impulse pressure will be reaching zero. |
| hole_size | Size of the explosion hole to create in breakable objects. |

docs: y · retail: confirmed (runtime dump)
