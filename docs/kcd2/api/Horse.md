# Horse

C++ class(es): `C_ScriptBindHorse`, `C_ScriptBindHuman`, `C_ScriptBind_Horse`, `C_ScriptBind_Human`
Reached from Lua as `Horse.FunctionName(...)`.
6 documented function(s); 47 additional undocumented function(s) found in retail/runtime.

## Functions

### AttachTo

```lua
Horse.AttachTo()
```

C++: `virtual void AttachTo (C_Horse * pHorse )`

docs: y · retail: unconfirmed

### GetHorse

```lua
Horse.GetHorse()
```

C++: `C_Horse* GetHorse (IFunctionHandler * pH )`

docs: y · retail: confirmed (mod×6)

### GetHorseMountPoint

```lua
Horse.GetHorseMountPoint(EntityId horseId, Vector3 pos, Vector3 dir)
```

C++: `virtual int GetHorseMountPoint (IFunctionHandler * pH , ScriptHandle horseId )`

docs: y · retail: unconfirmed

### HasRider

```lua
Horse.HasRider()
```

C++: `virtual int HasRider (IFunctionHandler * pH )`

docs: y · retail: confirmed (vanilla×2)

### IsMountable

```lua
Horse.IsMountable()
```

C++: `virtual int IsMountable (IFunctionHandler * pH )`

docs: y · retail: confirmed (vanilla×1)

### RearAndThrowDown

```lua
Horse.RearAndThrowDown()
```

C++: `virtual int RearAndThrowDown (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

## Undocumented (present in retail, not in official docs)

### AddAnimalLootAction

`Horse.AddAnimalLootAction(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×4)

### AddLootAction

`Horse.AddLootAction(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×4)

### Event_Spawn

`Horse.Event_Spawn(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×3)

### Event_Spawn_Internal

`Horse.Event_Spawn_Internal(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×3)

### Event_Spawned

`Horse.Event_Spawned(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×3)

### Event_SpawnKeep

`Horse.Event_SpawnKeep(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### Expose

`Horse.Expose(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### ForceUsable

`Horse.ForceUsable(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×4)

### GetActions

`Horse.GetActions(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×35, mod×1)

### GetDogActions

`Horse.GetDogActions(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×3)

### GetFlowgraphForwardingEntity

`Horse.GetFlowgraphForwardingEntity(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### GetInspectableByPlayer

`Horse.GetInspectableByPlayer(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### GetMountableByPlayer

`Horse.GetMountableByPlayer(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### GetReturnToPoolWeight

`Horse.GetReturnToPoolWeight(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### InitialSetup

`Horse.InitialSetup(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### IsAIControlled

`Horse.IsAIControlled(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump)

### IsMountLegal

`Horse.IsMountLegal(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### IsUsable

`Horse.IsUsable(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×47, mod×1)

### NotifyRemoval

`Horse.NotifyRemoval(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### OnBonding

`Horse.OnBonding(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### OnButcher

`Horse.OnButcher(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### OnDestroy

`Horse.OnDestroy(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×11)

### OnDogRequest

`Horse.OnDogRequest(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### OnEditorSetGameMode

`Horse.OnEditorSetGameMode(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×3)

### OnInspect

`Horse.OnInspect(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### OnLoad

`Horse.OnLoad(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×65, mod×1)

### OnLoadAI

`Horse.OnLoadAI(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### OnLoot

`Horse.OnLoot(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### OnMount

`Horse.OnMount(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### OnPropertyChange

`Horse.OnPropertyChange(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×113)

### OnReset

`Horse.OnReset(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×162, mod×2)

### OnSave

`Horse.OnSave(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×60, mod×1)

### OnSaveAI

`Horse.OnSaveAI(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### OnSpawn

`Horse.OnSpawn(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×75, mod×4)

### OnStartle

`Horse.OnStartle(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### OnUsed

`Horse.OnUsed(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×36, mod×1)

### RegisterAI

`Horse.RegisterAI(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×8)

### Reset

`Horse.Reset(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×81)

### ResetAIParameters

`Horse.ResetAIParameters(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×3)

### ResetCommon

`Horse.ResetCommon(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### ReviveInEditor

`Horse.ReviveInEditor(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### SetActorModel

`Horse.SetActorModel(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### SetInspectableByPlayer

`Horse.SetInspectableByPlayer(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### SetMountableByPlayer

`Horse.SetMountableByPlayer(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### SetMountableByPlayerDisabledFromAI

`Horse.SetMountableByPlayerDisabledFromAI(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### SetMountIsLegal

`Horse.SetMountIsLegal(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### SetMountIsLegalFromAI

`Horse.SetMountIsLegalFromAI(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)
