# EntityModule

C++ class(es): `C_ScriptBindEntityModule`
Reached from Lua as `EntityModule.FunctionName(...)`.
21 documented function(s); 1 additional undocumented function(s) found in retail/runtime.

## Functions

### AcquireInventory

```lua
EntityModule.AcquireInventory()
```

C++: `int AcquireInventory (IFunctionHandler * pH , char const * DBInventoryId , ScriptHandle ownerEntityId )`

returns Id of inventory

docs: y · retail: unconfirmed

### AnimCharCopyVisual

```lua
EntityModule.AnimCharCopyVisual(entityId)
```

C++: `int AnimCharCopyVisual (IFunctionHandler * pH , ScriptHandle entityId )`

Debug function

docs: y · retail: confirmed (binary, runtime dump)

### AnimCharSetBodyBlood

```lua
EntityModule.AnimCharSetBodyBlood(entityId, "zone", float01)
```

C++: `int AnimCharSetBodyBlood (IFunctionHandler * pH , ScriptHandle entityId , const char * zoneName , float blood01 )`

Debug function

docs: y · retail: confirmed (vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Others/AnimChar.lua`))

### AquireInventory

```lua
EntityModule.AquireInventory()
```

C++: `int AquireInventory (IFunctionHandler * pH , int DBInventoryId , ScriptHandle ownerEntityId )`

returns Id of inventory

docs: y · retail: unconfirmed

### CanUseInventory

```lua
EntityModule.CanUseInventory()
```

C++: `int CanUseInventory (IFunctionHandler * pH , framework::T_WUIDScriptType inventoryId )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Stash/AnimStash.lua`))

### EnableLayerProfile

```lua
EntityModule.EnableLayerProfile(profileName, enable)
```

C++: `int EnableLayerProfile (IFunctionHandler * pH , const char * profileName , bool enable )`

Enable/Disable entity layer profile by name" ! Prerequisites: ! - In your level: Terrain - Environment - Use Layer Activation set to true ! - cvar e_ObjectLayersActivation set to 1

docs: y · retail: unconfirmed

### GetEntityScriptMisc

```lua
EntityModule.GetEntityScriptMisc()
```

C++: `int GetEntityScriptMisc (IFunctionHandler * pH , ScriptHandle entityId )`

general

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/EntityUtils.lua`))

### GetInventoryOwner

```lua
EntityModule.GetInventoryOwner(inventoryid, player.id)
```

C++: `int GetInventoryOwner (IFunctionHandler * pH , framework::T_WUIDScriptType inventoryId )`

Returns owner of this inventory."

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Stash/AnimStash.lua`))

### GetSlotHand

```lua
EntityModule.GetSlotHand()
```

C++: `int GetSlotHand (IFunctionHandler * pH , ScriptHandle slotEntityId )`

ItemSlot

docs: y · retail: unconfirmed

### GetSlotItemClassId

```lua
EntityModule.GetSlotItemClassId()
```

C++: `int GetSlotItemClassId (IFunctionHandler * pH , ScriptHandle slotEntityId )`

ItemSlot

docs: y · retail: confirmed (binary, runtime dump, mod×2)

### GetSlotSpawnOnStart

```lua
EntityModule.GetSlotSpawnOnStart()
```

C++: `int GetSlotSpawnOnStart (IFunctionHandler * pH , ScriptHandle slotEntityId )`

docs: y · retail: unconfirmed

### InitBookEntity

```lua
EntityModule.InitBookEntity()
```

C++: `int InitBookEntity (IFunctionHandler * pH , const char * bookGfx , ScriptHandle bookId )`

docs: y · retail: unconfirmed

### IsInventoryReadOnly

```lua
EntityModule.IsInventoryReadOnly()
```

C++: `int IsInventoryReadOnly (IFunctionHandler * pH , framework::T_WUIDScriptType inventoryId )`

docs: y · retail: confirmed (binary, runtime dump)

### IsLayerProfileEnabled

```lua
EntityModule.IsLayerProfileEnabled()
```

C++: `int IsLayerProfileEnabled (IFunctionHandler * pH , const char * profileName )`

This is IsLayerProfileEnabled, a member of class C_ScriptBindEntityModule.

docs: y · retail: unconfirmed

### LoadInventoryFromDB

```lua
EntityModule.LoadInventoryFromDB()
```

C++: `int LoadInventoryFromDB (IFunctionHandler * pH , char const * DBInventoryId , ScriptHandle ownerEntityId )`

clears inventory and loads inventory items from DB

docs: y · retail: unconfirmed

### MakeParticleEffectActive

```lua
EntityModule.MakeParticleEffectActive()
```

C++: `int MakeParticleEffectActive (IFunctionHandler * pH , ScriptHandle particleEffectEntityId )`

ParticleEffect

docs: y · retail: confirmed (binary, runtime dump)

### MakeParticleEffectIdle

```lua
EntityModule.MakeParticleEffectIdle()
```

C++: `int MakeParticleEffectIdle (IFunctionHandler * pH , ScriptHandle particleEffectEntityId )`

docs: y · retail: confirmed (binary, runtime dump)

### ReleaseInventory

```lua
EntityModule.ReleaseInventory()
```

C++: `int ReleaseInventory (IFunctionHandler * pH , ScriptHandle ownerEntityId )`

docs: y · retail: unconfirmed

### SequenceEntitiesCopyVisual

```lua
EntityModule.SequenceEntitiesCopyVisual(sequenceName)
```

C++: `int SequenceEntitiesCopyVisual (IFunctionHandler * pH , const char * sequenceName )`

For all AnimChar entities in the anim sequence tries to find related soul and copy its look.

docs: y · retail: confirmed (runtime dump)

### SequenceEntitiesCopyVisualImpl

```lua
EntityModule.SequenceEntitiesCopyVisualImpl()
```

C++: `static WH_API_ENTITY_MODULE void SequenceEntitiesCopyVisualImpl (IAnimSequence&)`

docs: y · retail: unconfirmed

### WillSleepingOnThisBedSave

```lua
EntityModule.WillSleepingOnThisBedSave(entityId)
```

C++: `int WillSleepingOnThisBedSave (IFunctionHandler * pH , ScriptHandle entityIdHandle )`

Checks whether this bed will save the game after proper sleep or not.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Bed/Bed.lua`), mod×1)

## Undocumented (present in retail, not in official docs)

### HasPlayerVisibleItems

`EntityModule.HasPlayerVisibleItems(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×3 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Stash/AnimStash.lua`))
