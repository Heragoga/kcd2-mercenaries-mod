# XGenAIModule

C++ class(es): `C_ScriptBindXGenAIModule`, `C_ScriptBind_XGenAIModule`
Reached from Lua as `XGenAIModule.FunctionName(...)`.
45 documented function(s); 3 additional undocumented function(s) found in retail/runtime.

## Functions

### _GetDataVariable

```lua
XGenAIModule._GetDataVariable()
```

C++: `int _GetDataVariable (IFunctionHandler* pH , char const * name )`

Undocumented internal functions used in dataMetaTable

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/LuaTreeVarSync.lua`))

### _SetDataVariable

```lua
XGenAIModule._SetDataVariable()
```

C++: `int _SetDataVariable (IFunctionHandler* pH , char const * name )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/LuaTreeVarSync.lua`))

### AddLink

```lua
XGenAIModule.AddLink(framework, framework, const char* linkTag)
```

Adds a link between the linkable objects from and to. The specified tag is used - it must exists! Returns true if the link has been added, false otherwise.

| Param | Description |
|---|---|
| framework | :T_WUIDScriptType fromId id of the object to create link from |
| framework | :T_WUIDScriptType toId id of the object to create link to |
| const char* linkTag | name of the link tag to added |

docs: y · retail: confirmed (runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Doors/AnimDoor.lua`))

### AddRecordedIntellectForFaderProfiling

```lua
XGenAIModule.AddRecordedIntellectForFaderProfiling()
```

C++: `int AddRecordedIntellectForFaderProfiling (IFunctionHandler* pH , framework::T_WUIDScriptType wuid )`

Adds intellect of given object for replay tool recording during next fader profiling

docs: y · retail: confirmed (binary, runtime dump)

### BindToModule

```lua
XGenAIModule.BindToModule()
```

C++: `void BindToModule (C_XGenAIModule* pLink )`

docs: y · retail: unconfirmed

### DespawnPerceptibleVolume

```lua
XGenAIModule.DespawnPerceptibleVolume()
```

C++: `int DespawnPerceptibleVolume (IFunctionHandler * ph , framework::T_WUIDScriptType wuid )`

Despawns perceptible volume with given params.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Doors/AnimDoor.lua`))

### FindLinks

```lua
XGenAIModule.FindLinks(framework, const char* linkTag)
```

Returns all links from given linkableObject with a given tag. Results are stored in array Returns NULL in case of failure

| Param | Description |
|---|---|
| framework | :T_WUIDScriptType fromId id of the object where to start search |
| const char* linkTag | name of the link tag to added |

docs: y · retail: confirmed (binary, runtime dump, vanilla×8 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Doors/AnimDoor.lua`), mod×2)

### ForceSyncFromLua

```lua
XGenAIModule.ForceSyncFromLua()
```

C++: `int ForceSyncFromLua (IFunctionHandler* pH , framework::T_WUIDScriptType wuid )`

Forces sync of brain variables from lua.

docs: y · retail: unconfirmed

### GetBrainVariable

```lua
XGenAIModule.GetBrainVariable()
```

C++: `int GetBrainVariable (IFunctionHandler* pH , framework::T_WUIDScriptType wuid , char const * name )`

Returns brain variable 'name'.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Triggers/KettleActionTrigger.lua`))

### GetCombatSimulatorHumanExperimentParams

```lua
XGenAIModule.GetCombatSimulatorHumanExperimentParams()
```

C++: `int GetCombatSimulatorHumanExperimentParams (IFunctionHandler* ph )`

Returns parameters for the currently running human experiment with combat simulator.

docs: y · retail: unconfirmed

### GetEntityByWUID

```lua
XGenAIModule.GetEntityByWUID()
```

C++: `int GetEntityByWUID (IFunctionHandler * pH , framework::T_WUIDScriptType wuid )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×5 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Systems/StashInventoryCollector.lua`), mod×57)

### GetEntityIdByWUID

```lua
XGenAIModule.GetEntityIdByWUID()
```

C++: `int GetEntityIdByWUID (IFunctionHandler * pH , framework::T_WUIDScriptType wuid )`

docs: y · retail: confirmed (binary, runtime dump)

### GetMyWUID

```lua
XGenAIModule.GetMyWUID(self)
```

C++: `int GetMyWUID (IFunctionHandler * pH , SmartScriptTable table )`

Retrieves the wuid of the entity based on its entity id, use with the self table only

docs: y · retail: confirmed (runtime dump, vanilla×8 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Others/ShootingTarget.lua`), mod×37)

### GetOwner

```lua
XGenAIModule.GetOwner(framework)
```

Finds out ownership of given linkable object. Returns wuid of the owner NPC or invalid wuid if there is no owner.

| Param | Description |
|---|---|
| framework | :T_WUIDScriptType linkableId id of the object whose ownership we try to get |

docs: y · retail: confirmed (binary, runtime dump, vanilla×4 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Triggers/ActionTrigger.lua`))

### GetWuidDebugString

```lua
XGenAIModule.GetWuidDebugString(entity.this.id)
```

C++: `int GetWuidDebugString (IFunctionHandler* ph , framework::T_WUIDScriptType wuid )`

Returns debug description of the wuid.

docs: y · retail: confirmed (binary, runtime dump)

### HasClothingLink

```lua
XGenAIModule.HasClothingLink()
```

C++: `int HasClothingLink (IFunctionHandler* pH , framework::T_WUIDScriptType scriptWuid )`

Returns true if the stash has any scheduler clothing link Retunrs NULL in case of failure

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Systems/StashInventoryCollector.lua`))

### IgnorePerception

```lua
XGenAIModule.IgnorePerception()
```

C++: `int IgnorePerception (IFunctionHandler* ph , framework::T_WUIDScriptType perceptorId , framework::T_WUIDScriptType perceptibleId , const char * timeout , bool isWorldTime , bool uninterruptible )`

Make perceptor ignore a perceptible.

docs: y · retail: confirmed (runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Doors/AnimDoor.lua`))

### IsOneshotAvailable

```lua
XGenAIModule.IsOneshotAvailable()
```

C++: `int IsOneshotAvailable (IFunctionHandler* ph , framework::T_WUIDScriptType wuid )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Triggers/ActionTrigger.lua`))

### IsOneshotBlocked

```lua
XGenAIModule.IsOneshotBlocked()
```

C++: `int IsOneshotBlocked (IFunctionHandler* ph , framework::T_WUIDScriptType wuid )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Triggers/ActionTrigger.lua`))

### IsPointInAreaWithLabel

```lua
XGenAIModule.IsPointInAreaWithLabel()
```

C++: `int IsPointInAreaWithLabel (IFunctionHandler * ph , framework::T_WUIDScriptType wuid )`

Despawns perceptible volume with given params.

docs: y · retail: confirmed (runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Systems/StashInventoryCollector.lua`))

### IsPointInAreaWithLabelWUID

```lua
XGenAIModule.IsPointInAreaWithLabelWUID()
```

C++: `int IsPointInAreaWithLabelWUID (IFunctionHandler * ph , framework::T_WUIDScriptType wuid , const char * label )`

docs: y · retail: confirmed (binary, runtime dump, mod×1)

### IsStanceAvailable

```lua
XGenAIModule.IsStanceAvailable()
```

C++: `int IsStanceAvailable (IFunctionHandler* ph , framework::T_WUIDScriptType wuid )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Triggers/ActionTrigger.lua`))

### IsStanceBlocked

```lua
XGenAIModule.IsStanceBlocked()
```

C++: `int IsStanceBlocked (IFunctionHandler* ph , framework::T_WUIDScriptType wuid )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Triggers/ActionTrigger.lua`))

### IsUnstanceAvailable

```lua
XGenAIModule.IsUnstanceAvailable()
```

C++: `int IsUnstanceAvailable (IFunctionHandler* ph , framework::T_WUIDScriptType wuid , const char * unstance )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Triggers/ActionTrigger.lua`))

### IsUnstanceBlocked

```lua
XGenAIModule.IsUnstanceBlocked()
```

C++: `int IsUnstanceBlocked (IFunctionHandler* ph , framework::T_WUIDScriptType wuid , const char * unstance )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Triggers/ActionTrigger.lua`))

### LootBegin

```lua
XGenAIModule.LootBegin()
```

C++: `int LootBegin (IFunctionHandler * ph , framework::T_WUIDScriptType what )`

Marks player as looting

docs: y · retail: unconfirmed

### LootEnd

```lua
XGenAIModule.LootEnd()
```

C++: `int LootEnd (IFunctionHandler * ph , framework::T_WUIDScriptType what )`

Marks player as not looting

docs: y · retail: confirmed (binary, runtime dump)

### LootInventoryBegin

```lua
XGenAIModule.LootInventoryBegin()
```

C++: `int LootInventoryBegin (IFunctionHandler * ph , framework::T_WUIDScriptType what )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Stash/AnimStash.lua`))

### OnDestroy

```lua
XGenAIModule.OnDestroy()
```

C++: `int OnDestroy (IFunctionHandler * pH , int buildingId )`

needed by editor

docs: y · retail: confirmed (runtime dump, vanilla×11)

### OnPropertyChange

```lua
XGenAIModule.OnPropertyChange()
```

C++: `int OnPropertyChange (IFunctionHandler * pH , ScriptHandle entityId )`

needed by editor

if !WH_CTSW(WH_CTSW_MASTER)

docs: y · retail: confirmed (runtime dump, vanilla×113)

### OnSpawn

```lua
XGenAIModule.OnSpawn()
```

C++: `int OnSpawn (IFunctionHandler * pH , ScriptHandle entityId , char const * assetName )`

docs: y · retail: confirmed (runtime dump, vanilla×75, mod×4)

### OnStart

```lua
XGenAIModule.OnStart()
```

C++: `int OnStart (IFunctionHandler * pH , bool )`

docs: y · retail: confirmed (runtime dump)

### PlaceToSlotFromInventory

```lua
XGenAIModule.PlaceToSlotFromInventory(itemWuid, slotWuid)
```

C++: `int PlaceToSlotFromInventory (IFunctionHandler * ph , framework::T_WUIDScriptType itemId , ScriptHandle wuid_slot )`

Places given item to given slot. Guaranteed to work ONLY if the item is in inventory, and NOT in world

docs: y · retail: confirmed (runtime dump)

### RemoveDaycyclePatch

```lua
XGenAIModule.RemoveDaycyclePatch(Wuid wuid, string patchHandle)
```

C++: `int RemoveDaycyclePatch (IFunctionHandler* ph , framework::T_WUIDScriptType wuid , const char * patchHandle )`

removes the patch with given handle from NPC with given WUID Returns true if the patch has been successfully removed, false otherwise (NPC with given wuid doesn't exist or it doesn't contain patch with specified handle)

docs: y · retail: unconfirmed

### SaveCombatSimulatorHumanExperimentResult

```lua
XGenAIModule.SaveCombatSimulatorHumanExperimentResult(playerHealth,opponentHealth)
```

C++: `int SaveCombatSimulatorHumanExperimentResult (IFunctionHandler* ph , float playerHealth , float opponentHealth )`

Saves the result of a human experiment.

docs: y · retail: unconfirmed

### SendMessageToEntity

```lua
XGenAIModule.SendMessageToEntity()
```

C++: `int SendMessageToEntity (IFunctionHandler * pH , SmartScriptTable sGuid , char const * type , char const * values )`

docs: y · retail: confirmed (runtime dump, vanilla×10 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Doors/AnimDoor.lua`))

### SendMessageToEntityArray

```lua
XGenAIModule.SendMessageToEntityArray()
```

C++: `int SendMessageToEntityArray (IFunctionHandler * pH , framework::T_WUIDScriptType wuid , char const * type , ScriptAnyValue data )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Triggers/TriggerBase.lua`))

### SendMessageToEntityData

```lua
XGenAIModule.SendMessageToEntityData()
```

C++: `int SendMessageToEntityData (IFunctionHandler * pH , SmartScriptTable sGuid , char const * type , SmartScriptTable data )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×24 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Debug/CombatDebug.lua`))

### SetBrainVariable

```lua
XGenAIModule.SetBrainVariable()
```

C++: `int ProduceSound (IFunctionHandler* pH , int soundId , Vec3 pos , float mult )`

Produces 0-1 multiplied sound at given position

docs: y · retail: confirmed (binary, runtime dump)

### SetModuleLink

```lua
XGenAIModule.SetModuleLink()
```

C++: `void SetModuleLink (C_XGenAIModule* pModule )`

docs: y · retail: unconfirmed

### SetPlayerDogMode

```lua
XGenAIModule.SetPlayerDogMode(set)
```

C++: `virtual int SetPlayerDogMode (IFunctionHandler * pH , const char * mode )`

Set given mode to the players companion.

docs: y · retail: confirmed (binary, runtime dump)

### SpawnEntity

```lua
XGenAIModule.SpawnEntity(Name, SharedSoulGuid, SoulArchetypeName, ClassName, LayerName, SpawnPointName, Pos, Rot, NoAI, IdleUntilFirstPatch, PerceptorObjectAI, PerceptibleObjectAI, SchedulerProxyName, SoulPoolName, Difficulty)
```

| Param | Description |
|---|---|
| Name | [string] |
| SharedSoulGuid | [string] |
| SoulArchetypeName | [string] (only needed when SharedSoulGuid is nil) |
| ClassName | [string] (only needed when both SharedSoulGuid and SoulArchetypeName are nil) |
| LayerName | [string] only works for streamed layers |
| SpawnPointName | [string] (position to spawn on) |
| Pos | [Vec3] position if TagPointEntity is nil |
| Rot | [Vec3] rotation (in 3 angles) if TagPointEntity is nil |
| NoAI | [bool] - disabled AI, default false |
| IdleUntilFirstPatch | [bool] default false |
| PerceptorObjectAI | [bool] default true |
| PerceptibleObjectAI | [bool] default true |
| SchedulerProxyName | [string] |
| SoulPoolName | [bool] when spawning from pool, instead of SharedSoulGuid |
| Difficulty | [int] only applied when spawning from pool |

docs: y · retail: confirmed (binary, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Debug/PathfindDebugUtils.lua`))

### SpawnPerceptibleVolume

```lua
XGenAIModule.SpawnPerceptibleVolume()
```

C++: `int SpawnPerceptibleVolume (IFunctionHandler* ph , Vec3 pos , float radius , float height , float visibility , float conspicuousness , const char * label , const char * timer , bool worldTime , bool clipPoints )`

Spawns perceptible volume with given params. If timer is empty string, infinite is used.

docs: y · retail: confirmed (runtime dump, vanilla×2 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/Doors/AnimDoor.lua`))

### SpawnPerceptibleVolumeOnWUID

```lua
XGenAIModule.SpawnPerceptibleVolumeOnWUID()
```

C++: `int SpawnPerceptibleVolumeOnWUID (IFunctionHandler* ph , framework::T_WUIDScriptType wuid , float radius , float height , float visibility , float conspicuousness , const char * label , const char * timer , bool worldTime , bool clipPoints )`

Spawns perceptible volume with given params. If timer is empty string, infinite is used.

docs: y · retail: confirmed (runtime dump)

### TryEndCombat

```lua
XGenAIModule.TryEndCombat(entity.this.id)
```

C++: `int TryEndCombat (IFunctionHandler* ph , framework::T_WUIDScriptType wuid )`

Tries to end combat mode. Returns true if the NPCs are already not in the combat mode.

docs: y · retail: unconfirmed

## Undocumented (present in retail, not in official docs)

### MakeTableFromType

`XGenAIModule.MakeTableFromType(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Utils/TableUtils.lua`))

### ProduceSound

`XGenAIModule.ProduceSound(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump)

### ProduceSoundWUID

`XGenAIModule.ProduceSoundWUID(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Systems/Crime.lua`))
