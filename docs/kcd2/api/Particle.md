# Particle

C++ class(es): `CScriptBindParticle`, `CScriptBind_Particle`
Reached from Lua as `Particle.FunctionName(...)`.
11 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### Attach

```lua
Particle.Attach()
```

C++: `int Attach (IFunctionHandler * pH )`

Attaches an effect.

docs: y · retail: unconfirmed

### CreateDecal

```lua
Particle.CreateDecal(pos, normal, size, lifeTime, textureName)
```

| Param | Description |
|---|---|
| Vec3 pos | Decal position. |
| Vec3 normal | Decal normal vector. |
| float size | Decal size. |
| float lifeTime | Decal life time. |
| textureName | Name of the texture.</param Creates a decal with the specified parameters. |

docs: y · retail: confirmed (binary, runtime dump)

### CreateEffect

```lua
Particle.CreateEffect(name, params)
```

Creates a new particle effect.

| Param | Description |
|---|---|
| const char * name | Particle effect name. |
| SmartScriptTable params | Effect parameters. |

docs: y · retail: confirmed (runtime dump)

### CreateMatDecal

```lua
Particle.CreateMatDecal(pos, normal, size, lifeTime, materialName)
```

Creates a material decal.

| Param | Description |
|---|---|
| Vec3 pos | Decal position. |
| Vec3 normal | Decal normal vector. |
| float size | Decal size. |
| float lifeTime | Decal life time. |
| const char * materialName | Name of the Material. |

docs: y · retail: confirmed (binary, runtime dump)

### DeleteEffect

```lua
Particle.DeleteEffect(name)
```

Deletes the specified particle effect.

| Param | Description |
|---|---|
| const char * name | Particle effect name. |

docs: y · retail: confirmed (binary, runtime dump)

### Detach

```lua
Particle.Detach()
```

C++: `int Detach (IFunctionHandler * pH )`

Detaches an effect.

docs: y · retail: unconfirmed

### GetMemoryUsage

```lua
Particle.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer* pSizer ) const`

This is GetMemoryUsage, a member of class CScriptBind_Particle.

docs: y · retail: unconfirmed

### IsEffectAvailable

```lua
Particle.IsEffectAvailable(name)
```

Checks if the specified particle effect is available.

| Param | Description |
|---|---|
| const char * name | Particle effect name. |

docs: y · retail: confirmed (binary, runtime dump)

### SpawnEffect

```lua
Particle.SpawnEffect(effectName, pos, dir)
```

Spawns an effect.

| Param | Description |
|---|---|
| const char * effectName | Effect name. |
| Vec3 pos | Position vector. |
| Vec3 dir | Direction vector. |

docs: y · retail: confirmed (runtime dump, vanilla×6 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Boids/Fish.lua`))

### SpawnEffectLine

```lua
Particle.SpawnEffectLine(effectName, startPos, endPos, dir, scale, slices)
```

Spawns an effect line.

| Param | Description |
|---|---|
| const char * effectName | Effect name. |
| Vec3 startPos | Start position. |
| Vec3 endPos | End position. |
| Vec3 dir | Direction of the effect. |
| float scale | Scale value for the effect. |
| int slices | Number of slices. |

docs: y · retail: confirmed (runtime dump)

### SpawnParticles

```lua
Particle.SpawnParticles(params, pos, dir)
```

Spawns a particle effect.

| Param | Description |
|---|---|
| SmartScriptTable params | Effect parameters. |
| Vec3 pos | Effect position. |
| Vec3 dir | Effect direction. |

docs: y · retail: confirmed (runtime dump)
