# Player

C++ class(es): `C_ScriptBindPlayer`
Reached from Lua as `Player.FunctionName(...)`.
51 documented function(s); 28 additional undocumented function(s) found in retail/runtime.

## Functions

### AddActions

```lua
Player.AddActions()
```

C++: `virtual int AddActions (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### AddLuaActions

```lua
Player.AddLuaActions()
```

C++: `virtual int AddLuaActions (IFunctionHandler * pH )`

docs: y · retail: confirmed (vanilla×5)

### AttachTo

```lua
Player.AttachTo()
```

C++: `virtual void AttachTo (C_Player * pPlayer )`

docs: y · retail: unconfirmed

### CanBondHorse

```lua
Player.CanBondHorse(horseEntityId)
```

C++: `int CanBondHorse (IFunctionHandler* pH , ScriptHandle horseId )`

Returns if the player can bond a target horse

docs: y · retail: confirmed (binary, vanilla×1)

### CancelDogObjective

```lua
Player.CancelDogObjective()
```

C++: `virtual int CancelDogObjective (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### CanChangeStanceObject

```lua
Player.CanChangeStanceObject(Wuid stanceObjectId)
```

C++: `virtual int CanChangeStanceObject (IFunctionHandler* pH , framework::T_WUIDScriptType stanceObjectId )`

Returns true if player either does not use any stance smart object, or if stanceObjectId is the one being used

docs: y · retail: confirmed (vanilla×2)

### CanMountHorse

```lua
Player.CanMountHorse(horseEntityId)
```

C++: `int CanMountHorse (IFunctionHandler * pH , ScriptHandle horseId )`

Returns if the player can mount a target horse

docs: y · retail: confirmed (binary, vanilla×1)

### CanSleep

```lua
Player.CanSleep()
```

C++: `virtual int CanSleep (IFunctionHandler* pH )`

Returns the result of the if the player can sleep and the message (E_SkipTimeMessage) as a pair

docs: y · retail: confirmed (vanilla×4)

### CanSleepAndReportProblem

```lua
Player.CanSleepAndReportProblem()
```

C++: `virtual int CanSleepAndReportProblem (IFunctionHandler * pH )`

Returns bool and report why player cannot sleep right now.

docs: y · retail: unconfirmed

### ChangePlayerHeadLight

```lua
Player.ChangePlayerHeadLight("Archetype")
```

C++: `int ChangePlayerHeadLight (IFunctionHandler * pH , const char * name )`

Recreates player head light with selected archetype.

docs: y · retail: unconfirmed

### ClearPlayerHorse

```lua
Player.ClearPlayerHorse()
```

C++: `virtual int ClearPlayerHorse (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### DebugDisableInteractionFilter

```lua
Player.DebugDisableInteractionFilter()
```

C++: `virtual int DebugDisableInteractionFilter (IFunctionHandler * pH , const char * name )`

docs: y · retail: unconfirmed

### DebugEnableInteractionFilter

```lua
Player.DebugEnableInteractionFilter()
```

C++: `virtual int DebugEnableInteractionFilter (IFunctionHandler * pH , const char * name )`

docs: y · retail: unconfirmed

### DebugStopMinigame

```lua
Player.DebugStopMinigame()
```

C++: `virtual int DebugStopMinigame (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### EnableFastTravel

```lua
Player.EnableFastTravel()
```

C++: `virtual int EnableFastTravel (IFunctionHandler * pH , bool enable )`

docs: y · retail: unconfirmed

### EnablePlayerHorseInventory

```lua
Player.EnablePlayerHorseInventory()
```

C++: `virtual int EnablePlayerHorseInventory (IFunctionHandler * pH , bool enable )`

docs: y · retail: unconfirmed

### FeedDog

```lua
Player.FeedDog()
```

C++: `virtual int FeedDog (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### GetFlyMode

```lua
Player.GetFlyMode()
```

C++: `int GetFlyMode (IFunctionHandler* pH )`

Returns fly mode of the player (FlyMode_Off, FlyMode_On, FlyMode_OnNoCollisions)

docs: y · retail: confirmed (binary, vanilla×1)

### GetHorseId

```lua
Player.GetHorseId()
```

C++: `virtual int GetHorseId (IFunctionHandler * pH )`

docs: y · retail: confirmed (vanilla×1)

### GetPlayer

```lua
Player.GetPlayer()
```

C++: `C_Player * GetPlayer (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### GetPlayerHorse

```lua
Player.GetPlayerHorse()
```

C++: `virtual int GetPlayerHorse (IFunctionHandler * pH )`

docs: y · retail: confirmed (vanilla×1)

### HasRunningDogObjective

```lua
Player.HasRunningDogObjective()
```

C++: `virtual int HasRunningDogObjective (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### HorseInspect

```lua
Player.HorseInspect()
```

C++: `virtual int HorseInspect (IFunctionHandler * pH , ScriptHandle horseId )`

docs: y · retail: confirmed (vanilla×1)

### InterruptSitting

```lua
Player.InterruptSitting()
```

C++: `virtual int InterruptSitting (IFunctionHandler * pH )`

This is InterruptSitting, a member of class C_ScriptBindPlayer.

docs: y · retail: unconfirmed

### IsCombatChatTarget

```lua
Player.IsCombatChatTarget(entityId)
```

C++: `virtual int IsCombatChatTarget (IFunctionHandler* pH , ScriptHandle entityId )`

Returns true when player is in combat danger and target is threat for player

docs: y · retail: confirmed (vanilla×1)

### IsLaying

```lua
Player.IsLaying()
```

C++: `virtual int IsLaying (IFunctionHandler * pH )`

Returns true when player is laying

docs: y · retail: confirmed (vanilla×1, mod×3)

### IsLockedToOpponent

```lua
Player.IsLockedToOpponent(entityId)
```

C++: `virtual int IsLockedToOpponent (IFunctionHandler* pH , ScriptHandle entityId )`

Returns true when player is locked in melee combat to this entity

docs: y · retail: unconfirmed

### IsSitting

```lua
Player.IsSitting()
```

C++: `virtual int IsSitting (IFunctionHandler * pH )`

Returns true when player is sitting

docs: y · retail: confirmed (vanilla×1)

### OnBedInterrupt

```lua
Player.OnBedInterrupt()
```

C++: `virtual int OnBedInterrupt (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### OnBedPrepareForDialog

```lua
Player.OnBedPrepareForDialog(WUID speaker)
```

C++: `virtual int OnBedPrepareForDialog (IFunctionHandler * pH )`

Wake up player and prepare him for dialog with speaker, if speaker is not specified player can end up in bed position

docs: y · retail: unconfirmed

### OnBedStop

```lua
Player.OnBedStop()
```

C++: `virtual int OnBedStop (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### OnEndInteractive

```lua
Player.OnEndInteractive()
```

C++: `virtual int OnEndInteractive (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### OnEndItemInteraction

```lua
Player.OnEndItemInteraction()
```

C++: `virtual int OnEndItemInteraction (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### OnEndSleepState

```lua
Player.OnEndSleepState()
```

C++: `virtual int OnEndSleepState (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### OnEnterInteractive

```lua
Player.OnEnterInteractive()
```

C++: `virtual int OnEnterInteractive (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### OnHold

```lua
Player.OnHold()
```

C++: `virtual int OnHold (IFunctionHandler * pH , bool activate )`

docs: y · retail: unconfirmed

### OnSleepFadeIn

```lua
Player.OnSleepFadeIn()
```

C++: `virtual int OnSleepFadeIn (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### OnSleepFadeOut

```lua
Player.OnSleepFadeOut()
```

C++: `virtual int OnSleepFadeOut (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### OnSleeping

```lua
Player.OnSleeping()
```

C++: `virtual int OnSleeping (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### OnUsableMessage

```lua
Player.OnUsableMessage()
```

C++: `virtual int OnUsableMessage (IFunctionHandler * pH , framework::T_WUIDScriptType wuid , const char * strPress , const char * strHold )`

docs: y · retail: confirmed (vanilla×1)

### OpenInventory

```lua
Player.OpenInventory()
```

C++: `virtual int OpenInventory (IFunctionHandler * pH , int mode , framework::T_WUIDScriptType inventoryId )`

docs: y · retail: confirmed (vanilla×3)

### PlayerForceBedSit

```lua
Player.PlayerForceBedSit()
```

C++: `virtual int PlayerForceSit (IFunctionHandler * pH )`

Player will be immediately transformed into idle sitting state on the bed on which he is currently doing something (sitting or sleeping).

docs: y · retail: unconfirmed

### PushBack

```lua
Player.PushBack()
```

C++: `virtual int PushBack (IFunctionHandler * pH , int distance )`

docs: y · retail: unconfirmed

### RequestDogObjective

```lua
Player.RequestDogObjective()
```

C++: `virtual int RequestDogObjective (IFunctionHandler * pH , ScriptHandle entityId )`

docs: y · retail: confirmed (vanilla×1)

### SetAlcoTeleportTarget

```lua
Player.SetAlcoTeleportTarget(targetWuid)
```

C++: `int SetAlcoTeleportTarget (IFunctionHandler* pH , framework::T_WUIDScriptType targetWuid )`

Sets target place for alcoteleport. Player will be teleported there at the end of unconciousness. Player must be unconscious when this is called, otherwise it is ignored. Set to INVALID_WUID (0) to cancel previous teleport request.

docs: y · retail: confirmed (binary)

### SetFlyMode

```lua
Player.SetFlyMode(flyMode)
```

C++: `int SetFlyMode (IFunctionHandler * pH , int flyMode )`

Sets fly mode of the player (FlyMode_Off, FlyMode_On, FlyMode_OnNoCollisions)

docs: y · retail: confirmed (binary, vanilla×3)

### SetPlayerDog

```lua
Player.SetPlayerDog()
```

C++: `virtual int SetPlayerDog (IFunctionHandler * pH , ScriptHandle entityId )`

This is SetPlayerDog, a member of class C_ScriptBindPlayer.

docs: y · retail: unconfirmed

### SetPlayerHorse

```lua
Player.SetPlayerHorse()
```

C++: `virtual int SetPlayerHorse (IFunctionHandler * pH , ScriptHandle entityId )`

docs: y · retail: unconfirmed

### SetWhistling

```lua
Player.SetWhistling()
```

C++: `virtual int SetWhistling (IFunctionHandler * pH , bool activate )`

docs: y · retail: unconfirmed

### Sleep

```lua
Player.Sleep()
```

C++: `virtual int Sleep (IFunctionHandler * pH , ScriptHandle sleepId )`

docs: y · retail: confirmed (binary)

### TryDrawTorch

```lua
Player.TryDrawTorch()
```

C++: `virtual int TryDrawTorch (IFunctionHandler* pH )`

Attempts to draw torch if equipped and hands are empty

docs: y · retail: unconfirmed

## Undocumented (present in retail, not in official docs)

### AddLootAction

`Player.AddLootAction(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×4)

### CheatEngine

`Player.CheatEngine(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×17)

### CheatEngine_animal

`Player.CheatEngine_animal(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×25)

### CheatEngine_equipweapon

`Player.CheatEngine_equipweapon(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### CheatEngine_money

`Player.CheatEngine_money(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### CheatEngine_skill

`Player.CheatEngine_skill(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×9)

### CheatEngine_stat

`Player.CheatEngine_stat(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×6)

### CheatEngine_time

`Player.CheatEngine_time(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### CheatGiveBow

`Player.CheatGiveBow(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### GetDogActions

`Player.GetDogActions(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×3)

### InitialSetup

`Player.InitialSetup(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### OnAction

`Player.OnAction(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×5, mod×1)

### OnBed

`Player.OnBed(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary)

### OnBedInteractiveDialog

`Player.OnBedInteractiveDialog(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary)

### OnDogRequest

`Player.OnDogRequest(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### OnInit

`Player.OnInit(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×66)

### OnLoadAI

`Player.OnLoadAI(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### OnReset

`Player.OnReset(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×162, mod×2)

### OnSaveAI

`Player.OnSaveAI(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### OnSpawn

`Player.OnSpawn(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×75, mod×4)

### PRTelep

`Player.PRTelep(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×10)

### PRTelep_unlock

`Player.PRTelep_unlock(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×7)

### PRTelepShowMessage

`Player.PRTelepShowMessage(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×3)

### Reset

`Player.Reset(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×81)

### ResetCommon

`Player.ResetCommon(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### ReviveInEditor

`Player.ReviveInEditor(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×2)

### SetActorModel

`Player.SetActorModel(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### SetModel

`Player.SetModel(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)
