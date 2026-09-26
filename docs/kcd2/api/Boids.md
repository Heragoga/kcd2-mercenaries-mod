# Boids

C++ class(es): `CScriptBindBoids`, `CScriptBind_Boids`
Reached from Lua as `Boids.FunctionName(...)`.
9 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### CreateBugsFlock

```lua
Boids.CreateBugsFlock(entity,paramsTable)
```

Creates a bugs flock and binds it to the given entity.

| Param | Description |
|---|---|
| SmartScriptTable entity | Valid entity table. |
| SmartScriptTable paramTable | Table with parameters for flock (Look at sample scripts). |

docs: y · retail: unconfirmed

### CreateFishFlock

```lua
Boids.CreateFishFlock(entity,paramsTable)
```

Creates a fishes flock and binds it to the given entity.

| Param | Description |
|---|---|
| SmartScriptTable entity | Valid entity table. |
| SmartScriptTable paramTable | Table with parameters for flock (Look at sample scripts). |

docs: y · retail: unconfirmed

### CreateFlock

```lua
Boids.CreateFlock(entity,paramsTable)
```

Creates a flock of boids and binds it to the given entity.

| Param | Description |
|---|---|
| SmartScriptTable entity | Valid entity table. |
| int nType | Type of the flock, can be Boids.FLOCK_BIRDS,Boids.FLOCK_FISH,Boids.FLOCK_BUGS. |
| SmartScriptTable paramTable | Table with parameters for flock (Look at sample scripts). |

docs: y · retail: confirmed (runtime dump, vanilla×30 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Boids/Birds.lua`))

### EnableFlock

```lua
Boids.EnableFlock(entity,paramsTable)
```

Enables/Disables flock in the entity.

| Param | Description |
|---|---|
| SmartScriptTable entity | Valid entity table containing flock. |
| bool bEnable | true to enable or false to disable flock. |

docs: y · retail: confirmed (runtime dump, vanilla×14 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Boids/Birds.lua`))

### GetMemoryUsage

```lua
Boids.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer * pSizer ) const`

This is GetMemoryUsage, a member of class CScriptBind_Boids.

docs: y · retail: unconfirmed

### OnBoidHit

```lua
Boids.OnBoidHit(flockEntity,boidEntity,hit)
```

Events that occurs on boid hit.

| Param | Description |
|---|---|
| SmartScriptTable flockEntity | Valid entity table containing flock. |
| SmartScriptTable boidEntity | Valid entity table containing boid. |
| SmartScriptTable hit | Valid entity table containing hit information.. |

docs: y · retail: confirmed (runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Boids/Boid.lua`))

### SetAttractionPoint

```lua
Boids.SetAttractionPoint(entity,paramsTable)
```

Sets the one time attraction point for the boids

| Param | Description |
|---|---|
| SmartScriptTable entity | Valid entity table containing flock. |
| Vec3 point | The one time attraction point |

docs: y · retail: confirmed (runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Boids/Birds.lua`))

### SetFlockParams

```lua
Boids.SetFlockParams(entity,paramsTable)
```

Modifies parameters of the existing flock in the specified enity.

| Param | Description |
|---|---|
| SmartScriptTable entity | Valid entity table containing flock. |
| SmartScriptTable paramTable | Table with parameters for flock (Look at sample scripts). |

docs: y · retail: confirmed (runtime dump, vanilla×6 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Boids/Birds.lua`))

### SetFlockPercentEnabled

```lua
Boids.SetFlockPercentEnabled(entity,paramsTable)
```

Used to gradually enable flock. Depending on the percentage more or less boid objects will be rendered in flock.

| Param | Description |
|---|---|
| SmartScriptTable entity | Valid entity table containing flock. |
| int nPercent | In range 0 to 100, 0 mean no boids will be rendered,if 100 then all boids will be rendered. |

docs: y · retail: confirmed (runtime dump, vanilla×6 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Boids/Birds.lua`))
