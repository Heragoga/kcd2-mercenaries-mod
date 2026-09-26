# Undocumented ScriptBind functions

Functions seen in the retail binary bind table and/or the runtime Lua state dump
that do **not** appear in the official `script_bind` HTML docs, grouped by the (known)
table they belong to. See [README.md](README.md) for methodology and caveats -- in
particular, binary bind coverage is a static analysis of one build and is not guaranteed
complete. Binds whose owning table could not be determined at all are not here -- see
[unresolved-binds.md](unresolved-binds.md) instead.

## AI

See [AI.md](AI.md) for the documented functions of this table.

- `AllowLowerBodyToTurn` -- binary: y, runtime dump: y, vanilla uses: 0 (AI.md#allowlowerbodytoturn)
- `AssignPFPropertiesToPathType` -- binary: y, runtime dump: y, vanilla uses: 1 (AI.md#assignpfpropertiestopathtype)
- `ClearMovementContext` -- binary: y, runtime dump: y, vanilla uses: 0 (AI.md#clearmovementcontext)
- `DestroyAllTPSQueries` -- binary: y, runtime dump: y, vanilla uses: 0 (AI.md#destroyalltpsqueries)
- `GetDirectAnchorPos` -- binary: y, runtime dump: y, vanilla uses: 0 (AI.md#getdirectanchorpos)
- `GetFormationPointClass` -- binary: y, runtime dump: y, vanilla uses: 0 (AI.md#getformationpointclass)
- `GetPathLoop` -- binary: y, runtime dump: y, vanilla uses: 0 (AI.md#getpathloop)
- `GetPointOnPathBySegNo` -- binary: y, runtime dump: y, vanilla uses: 0 (AI.md#getpointonpathbysegno)
- `IntersectsForbidden` -- binary: y, runtime dump: y, vanilla uses: 0 (AI.md#intersectsforbidden)
- `IsPointInWaterRegion` -- binary: y, runtime dump: y, vanilla uses: 0 (AI.md#ispointinwaterregion)
- `SetPFProperties` -- binary: y, runtime dump: y, vanilla uses: 0 (AI.md#setpfproperties)

## Action

See [Action.md](Action.md) for the documented functions of this table.

- `AddAngleSignal` -- binary: y, runtime dump: y, vanilla uses: 0 (Action.md#addanglesignal)

## Actor

See [Actor.md](Actor.md) for the documented functions of this table.

- `Butcher` -- binary: y, runtime dump: n, vanilla uses: 1 (Actor.md#butcher)
- `CreateActor` -- binary: n, runtime dump: y, vanilla uses: 1 (Actor.md#createactor)

## Alchemy

See [Alchemy.md](Alchemy.md) for the documented functions of this table.

- `ResetTable` -- binary: n, runtime dump: y, vanilla uses: 1 (Alchemy.md#resettable)

## AlchemyTable

See [AlchemyTable.md](AlchemyTable.md) for the documented functions of this table.

- `Event_Use` -- binary: n, runtime dump: y, vanilla uses: 3 (AlchemyTable.md#event_use)
- `Event_User` -- binary: n, runtime dump: y, vanilla uses: 1 (AlchemyTable.md#event_user)
- `GetActions` -- binary: n, runtime dump: y, vanilla uses: 35 (AlchemyTable.md#getactions)
- `GetUsableMessage` -- binary: n, runtime dump: y, vanilla uses: 8 (AlchemyTable.md#getusablemessage)
- `IsUsable` -- binary: n, runtime dump: y, vanilla uses: 47 (AlchemyTable.md#isusable)
- `IsUsableMsgChanged` -- binary: n, runtime dump: y, vanilla uses: 9 (AlchemyTable.md#isusablemsgchanged)
- `LoadModel` -- binary: n, runtime dump: y, vanilla uses: 13 (AlchemyTable.md#loadmodel)
- `OnEnablePhysics` -- binary: n, runtime dump: y, vanilla uses: 7 (AlchemyTable.md#onenablephysics)
- `OnPropertyChange` -- binary: n, runtime dump: y, vanilla uses: 113 (AlchemyTable.md#onpropertychange)
- `OnReset` -- binary: n, runtime dump: y, vanilla uses: 162 (AlchemyTable.md#onreset)
- `OnSpawn` -- binary: n, runtime dump: y, vanilla uses: 75 (AlchemyTable.md#onspawn)
- `OnUsed` -- binary: y, runtime dump: y, vanilla uses: 36 (AlchemyTable.md#onused)
- `PhysicalizeThis` -- binary: n, runtime dump: y, vanilla uses: 50 (AlchemyTable.md#physicalizethis)
- `Reset` -- binary: y, runtime dump: y, vanilla uses: 81 (AlchemyTable.md#reset)
- `ResetChild` -- binary: n, runtime dump: y, vanilla uses: 7 (AlchemyTable.md#resetchild)
- `SetInteractiveCollisionType` -- binary: n, runtime dump: y, vanilla uses: 36 (AlchemyTable.md#setinteractivecollisiontype)
- `SetupTrigger` -- binary: n, runtime dump: y, vanilla uses: 2 (AlchemyTable.md#setuptrigger)

## AnimDoor

See [AnimDoor.md](AnimDoor.md) for the documented functions of this table.

- `BuildNPCAnimationName` -- binary: n, runtime dump: y, vanilla uses: 2 (AnimDoor.md#buildnpcanimationname)
- `BuildObjectAnimationName` -- binary: n, runtime dump: y, vanilla uses: 2 (AnimDoor.md#buildobjectanimationname)
- `Close` -- binary: n, runtime dump: y, vanilla uses: 9 (AnimDoor.md#close)
- `DespawnSuspiciousVolume` -- binary: n, runtime dump: y, vanilla uses: 2 (AnimDoor.md#despawnsuspiciousvolume)
- `DisableLockpick` -- binary: n, runtime dump: y, vanilla uses: 1 (AnimDoor.md#disablelockpick)
- `DoLockOnMissingHomeArea` -- binary: n, runtime dump: y, vanilla uses: 1 (AnimDoor.md#dolockonmissinghomearea)
- `DoPlayAnimation` -- binary: n, runtime dump: y, vanilla uses: 12 (AnimDoor.md#doplayanimation)
- `DoPlaySound` -- binary: n, runtime dump: y, vanilla uses: 6 (AnimDoor.md#doplaysound)
- `DoStopSound` -- binary: n, runtime dump: y, vanilla uses: 14 (AnimDoor.md#dostopsound)
- `DumpState` -- binary: n, runtime dump: y, vanilla uses: 1 (AnimDoor.md#dumpstate)
- `EnableLockpick` -- binary: n, runtime dump: y, vanilla uses: 1 (AnimDoor.md#enablelockpick)
- `Event_Close` -- binary: n, runtime dump: y, vanilla uses: 5 (AnimDoor.md#event_close)
- `Event_Hide` -- binary: n, runtime dump: y, vanilla uses: 25 (AnimDoor.md#event_hide)
- `Event_Lock` -- binary: n, runtime dump: y, vanilla uses: 3 (AnimDoor.md#event_lock)
- `Event_Open` -- binary: n, runtime dump: y, vanilla uses: 6 (AnimDoor.md#event_open)
- `Event_UnHide` -- binary: n, runtime dump: y, vanilla uses: 18 (AnimDoor.md#event_unhide)
- `Event_Unlock` -- binary: n, runtime dump: y, vanilla uses: 3 (AnimDoor.md#event_unlock)
- `GenerateLockData` -- binary: n, runtime dump: y, vanilla uses: 4 (AnimDoor.md#generatelockdata)
- `GetActions` -- binary: n, runtime dump: y, vanilla uses: 35 (AnimDoor.md#getactions)
- `GetLockDifficulty` -- binary: n, runtime dump: y, vanilla uses: 3 (AnimDoor.md#getlockdifficulty)
- `GetObjectAnimName` -- binary: y, runtime dump: n, vanilla uses: 1 (AnimDoor.md#getobjectanimname)
- `GetSuspiciousVolume` -- binary: n, runtime dump: y, vanilla uses: 3 (AnimDoor.md#getsuspiciousvolume)
- `IsAccessedFromFront` -- binary: n, runtime dump: y, vanilla uses: 5 (AnimDoor.md#isaccessedfromfront)
- `IsInteractive` -- binary: y, runtime dump: y, vanilla uses: 5 (AnimDoor.md#isinteractive)
- `IsInUse` -- binary: n, runtime dump: y, vanilla uses: 3 (AnimDoor.md#isinuse)
- `IsLocked` -- binary: n, runtime dump: y, vanilla uses: 2 (AnimDoor.md#islocked)
- `IsOnKeySide` -- binary: n, runtime dump: y, vanilla uses: 6 (AnimDoor.md#isonkeyside)
- `IsOpen` -- binary: n, runtime dump: y, vanilla uses: 4 (AnimDoor.md#isopen)
- `IsRightDoor` -- binary: n, runtime dump: y, vanilla uses: 1 (AnimDoor.md#isrightdoor)
- `IsUsable` -- binary: n, runtime dump: y, vanilla uses: 47 (AnimDoor.md#isusable)
- `IsUsableMsgChanged` -- binary: n, runtime dump: y, vanilla uses: 9 (AnimDoor.md#isusablemsgchanged)
- `Lock` -- binary: n, runtime dump: y, vanilla uses: 14 (AnimDoor.md#lock)
- `Lockpick` -- binary: n, runtime dump: y, vanilla uses: 1 (AnimDoor.md#lockpick)
- `NeedSerialize` -- binary: n, runtime dump: y, vanilla uses: 5 (AnimDoor.md#needserialize)
- `OnEnablePhysics` -- binary: n, runtime dump: y, vanilla uses: 7 (AnimDoor.md#onenablephysics)
- `OnLoad` -- binary: n, runtime dump: y, vanilla uses: 65 (AnimDoor.md#onload)
- `OnPropertyChange` -- binary: n, runtime dump: y, vanilla uses: 113 (AnimDoor.md#onpropertychange)
- `OnReset` -- binary: n, runtime dump: y, vanilla uses: 162 (AnimDoor.md#onreset)
- `OnSave` -- binary: n, runtime dump: y, vanilla uses: 60 (AnimDoor.md#onsave)
- `OnSpawn` -- binary: n, runtime dump: y, vanilla uses: 75 (AnimDoor.md#onspawn)
- `OnUsed` -- binary: y, runtime dump: y, vanilla uses: 36 (AnimDoor.md#onused)
- `Open` -- binary: n, runtime dump: y, vanilla uses: 9 (AnimDoor.md#open)
- `PhysicalizeThis` -- binary: n, runtime dump: y, vanilla uses: 50 (AnimDoor.md#physicalizethis)
- `ProduceAiSound` -- binary: n, runtime dump: y, vanilla uses: 4 (AnimDoor.md#produceaisound)
- `Reset` -- binary: y, runtime dump: y, vanilla uses: 81 (AnimDoor.md#reset)
- `SetInteractiveCollisionType` -- binary: n, runtime dump: y, vanilla uses: 36 (AnimDoor.md#setinteractivecollisiontype)
- `SetLockedDueToPrivate` -- binary: n, runtime dump: y, vanilla uses: 1 (AnimDoor.md#setlockedduetoprivate)
- `SetPhysicalFlags` -- binary: n, runtime dump: y, vanilla uses: 4 (AnimDoor.md#setphysicalflags)
- `SetShouldBeLockedOverride` -- binary: n, runtime dump: y, vanilla uses: 1 (AnimDoor.md#setshouldbelockedoverride)
- `SetUnlockedDueExpected` -- binary: n, runtime dump: y, vanilla uses: 1 (AnimDoor.md#setunlockeddueexpected)
- `ShouldBeLocked` -- binary: n, runtime dump: y, vanilla uses: 2 (AnimDoor.md#shouldbelocked)
- `SpawnSuspiciousVolume` -- binary: n, runtime dump: y, vanilla uses: 2 (AnimDoor.md#spawnsuspiciousvolume)
- `Unlock` -- binary: n, runtime dump: y, vanilla uses: 12 (AnimDoor.md#unlock)

## CarryItemPile

See [CarryItemPile.md](CarryItemPile.md) for the documented functions of this table.

- `GetActions` -- binary: n, runtime dump: y, vanilla uses: 35 (CarryItemPile.md#getactions)
- `OnDeposit` -- binary: n, runtime dump: y, vanilla uses: 1 (CarryItemPile.md#ondeposit)
- `OnPickUp` -- binary: n, runtime dump: y, vanilla uses: 2 (CarryItemPile.md#onpickup)

## CarryableItem

See [CarryableItem.md](CarryableItem.md) for the documented functions of this table.

- `GetActions` -- binary: n, runtime dump: y, vanilla uses: 35 (CarryableItem.md#getactions)
- `GetUsableName` -- binary: n, runtime dump: y, vanilla uses: 6 (CarryableItem.md#getusablename)
- `IsCrossCenteringEnabled` -- binary: y, runtime dump: y, vanilla uses: 6 (CarryableItem.md#iscrosscenteringenabled)
- `OnEnablePhysics` -- binary: n, runtime dump: y, vanilla uses: 7 (CarryableItem.md#onenablephysics)
- `OnLevelLoaded` -- binary: n, runtime dump: y, vanilla uses: 12 (CarryableItem.md#onlevelloaded)
- `OnPickUp` -- binary: n, runtime dump: y, vanilla uses: 2 (CarryableItem.md#onpickup)
- `OnPropertyChange` -- binary: n, runtime dump: y, vanilla uses: 113 (CarryableItem.md#onpropertychange)
- `OnUsed` -- binary: y, runtime dump: y, vanilla uses: 36 (CarryableItem.md#onused)
- `OnUsedHold` -- binary: n, runtime dump: y, vanilla uses: 5 (CarryableItem.md#onusedhold)
- `PhysicalizeThis` -- binary: n, runtime dump: y, vanilla uses: 50 (CarryableItem.md#physicalizethis)
- `SetInteractiveCollisionType` -- binary: n, runtime dump: y, vanilla uses: 36 (CarryableItem.md#setinteractivecollisiontype)
- `Use` -- binary: n, runtime dump: y, vanilla uses: 4 (CarryableItem.md#use)

## Cart

See [Cart.md](Cart.md) for the documented functions of this table.

- `BlockByStash` -- binary: y, runtime dump: y, vanilla uses: 2 (Cart.md#blockbystash)
- `IsEntityOnMovingCart` -- binary: y, runtime dump: y, vanilla uses: 1 (Cart.md#isentityonmovingcart)

## Dog

See [Dog.md](Dog.md) for the documented functions of this table.

- `ActorCanTalk` -- binary: n, runtime dump: y, vanilla uses: 3 (Dog.md#actorcantalk)
- `AddAnimalLootAction` -- binary: n, runtime dump: y, vanilla uses: 4 (Dog.md#addanimallootaction)
- `AddLootAction` -- binary: n, runtime dump: y, vanilla uses: 4 (Dog.md#addlootaction)
- `Event_Spawn` -- binary: n, runtime dump: y, vanilla uses: 3 (Dog.md#event_spawn)
- `Event_Spawn_Internal` -- binary: n, runtime dump: y, vanilla uses: 3 (Dog.md#event_spawn_internal)
- `Event_Spawned` -- binary: n, runtime dump: y, vanilla uses: 3 (Dog.md#event_spawned)
- `Event_SpawnKeep` -- binary: n, runtime dump: y, vanilla uses: 2 (Dog.md#event_spawnkeep)
- `Expose` -- binary: n, runtime dump: y, vanilla uses: 1 (Dog.md#expose)
- `ForceUsable` -- binary: n, runtime dump: y, vanilla uses: 4 (Dog.md#forceusable)
- `GetActions` -- binary: n, runtime dump: y, vanilla uses: 35 (Dog.md#getactions)
- `GetCanTalkHintType` -- binary: n, runtime dump: y, vanilla uses: 5 (Dog.md#getcantalkhinttype)
- `GetChatActions` -- binary: n, runtime dump: y, vanilla uses: 3 (Dog.md#getchatactions)
- `GetDogActions` -- binary: n, runtime dump: y, vanilla uses: 3 (Dog.md#getdogactions)
- `GetFlowgraphForwardingEntity` -- binary: n, runtime dump: y, vanilla uses: 1 (Dog.md#getflowgraphforwardingentity)
- `GetReturnToPoolWeight` -- binary: n, runtime dump: y, vanilla uses: 1 (Dog.md#getreturntopoolweight)
- `InitialSetup` -- binary: n, runtime dump: y, vanilla uses: 2 (Dog.md#initialsetup)
- `IsAIControlled` -- binary: n, runtime dump: y, vanilla uses: 0 (Dog.md#isaicontrolled)
- `IsUsable` -- binary: n, runtime dump: y, vanilla uses: 47 (Dog.md#isusable)
- `NotifyRemoval` -- binary: n, runtime dump: y, vanilla uses: 2 (Dog.md#notifyremoval)
- `OnBonding` -- binary: n, runtime dump: y, vanilla uses: 2 (Dog.md#onbonding)
- `OnButcher` -- binary: n, runtime dump: y, vanilla uses: 1 (Dog.md#onbutcher)
- `OnChat` -- binary: n, runtime dump: y, vanilla uses: 1 (Dog.md#onchat)
- `OnChatOpen` -- binary: n, runtime dump: y, vanilla uses: 1 (Dog.md#onchatopen)
- `OnChatRequestAccepted` -- binary: n, runtime dump: y, vanilla uses: 1 (Dog.md#onchatrequestaccepted)
- `OnChatWithFocus` -- binary: n, runtime dump: y, vanilla uses: 1 (Dog.md#onchatwithfocus)
- `OnDestroy` -- binary: n, runtime dump: y, vanilla uses: 11 (Dog.md#ondestroy)
- `OnDogRequest` -- binary: n, runtime dump: y, vanilla uses: 1 (Dog.md#ondogrequest)
- `OnEditorSetGameMode` -- binary: n, runtime dump: y, vanilla uses: 3 (Dog.md#oneditorsetgamemode)
- `OnFollow` -- binary: n, runtime dump: y, vanilla uses: 1 (Dog.md#onfollow)
- `OnGrabCorpse` -- binary: n, runtime dump: y, vanilla uses: 1 (Dog.md#ongrabcorpse)
- `OnHorsePullDown` -- binary: n, runtime dump: y, vanilla uses: 1 (Dog.md#onhorsepulldown)
- `OnKnockout` -- binary: n, runtime dump: y, vanilla uses: 1 (Dog.md#onknockout)
- `OnLoadAI` -- binary: n, runtime dump: y, vanilla uses: 2 (Dog.md#onloadai)
- `OnLoot` -- binary: n, runtime dump: y, vanilla uses: 2 (Dog.md#onloot)
- `OnMercyKill` -- binary: n, runtime dump: y, vanilla uses: 1 (Dog.md#onmercykill)
- `OnPickpocketing` -- binary: n, runtime dump: y, vanilla uses: 1 (Dog.md#onpickpocketing)
- `OnPropertyChange` -- binary: n, runtime dump: y, vanilla uses: 113 (Dog.md#onpropertychange)
- `OnReset` -- binary: n, runtime dump: y, vanilla uses: 162 (Dog.md#onreset)
- `OnSaveAI` -- binary: n, runtime dump: y, vanilla uses: 2 (Dog.md#onsaveai)
- `OnSpawn` -- binary: n, runtime dump: y, vanilla uses: 75 (Dog.md#onspawn)
- `OnStealthKill` -- binary: n, runtime dump: y, vanilla uses: 1 (Dog.md#onstealthkill)
- `OnTalk` -- binary: n, runtime dump: y, vanilla uses: 2 (Dog.md#ontalk)
- `OnUsed` -- binary: y, runtime dump: y, vanilla uses: 36 (Dog.md#onused)
- `RegisterAI` -- binary: n, runtime dump: y, vanilla uses: 8 (Dog.md#registerai)
- `Reset` -- binary: y, runtime dump: y, vanilla uses: 81 (Dog.md#reset)
- `ResetAIParameters` -- binary: n, runtime dump: y, vanilla uses: 3 (Dog.md#resetaiparameters)
- `ResetCommon` -- binary: n, runtime dump: y, vanilla uses: 1 (Dog.md#resetcommon)
- `ReviveInEditor` -- binary: n, runtime dump: y, vanilla uses: 2 (Dog.md#reviveineditor)
- `SetActorModel` -- binary: n, runtime dump: y, vanilla uses: 1 (Dog.md#setactormodel)
- `TestActorCanTalk` -- binary: n, runtime dump: y, vanilla uses: 1 (Dog.md#testactorcantalk)

## Entity

See [Entity.md](Entity.md) for the documented functions of this table.

- `CheckShaderParamCallbacks` -- binary: y, runtime dump: y, vanilla uses: 2 (Entity.md#checkshaderparamcallbacks)
- `HasFlagsExtended` -- binary: y, runtime dump: y, vanilla uses: 0 (Entity.md#hasflagsextended)
- `LoadObjectWithFlags` -- binary: y, runtime dump: y, vanilla uses: 0 (Entity.md#loadobjectwithflags)
- `SetSelfAsLightCasterException` -- binary: y, runtime dump: y, vanilla uses: 0 (Entity.md#setselfaslightcasterexception)
- `SetSlotAngles` -- binary: n, runtime dump: y, vanilla uses: 1 (Entity.md#setslotangles)
- `SetVelocityEx` -- binary: y, runtime dump: y, vanilla uses: 0 (Entity.md#setvelocityex)

## EntityModule

See [EntityModule.md](EntityModule.md) for the documented functions of this table.

- `HasPlayerVisibleItems` -- binary: y, runtime dump: y, vanilla uses: 3 (EntityModule.md#hasplayervisibleitems)

## EnvironmentModule

See [EnvironmentModule.md](EnvironmentModule.md) for the documented functions of this table.

- `CoverHole` -- binary: y, runtime dump: y, vanilla uses: 0 (EnvironmentModule.md#coverhole)
- `MakeHole` -- binary: y, runtime dump: y, vanilla uses: 0 (EnvironmentModule.md#makehole)

## Game

See [Game.md](Game.md) for the documented functions of this table.

- `HideCurrentTutorial` -- binary: y, runtime dump: y, vanilla uses: 2 (Game.md#hidecurrenttutorial)

## Horse

See [Horse.md](Horse.md) for the documented functions of this table.

- `AddAnimalLootAction` -- binary: n, runtime dump: y, vanilla uses: 4 (Horse.md#addanimallootaction)
- `AddLootAction` -- binary: n, runtime dump: y, vanilla uses: 4 (Horse.md#addlootaction)
- `Event_Spawn` -- binary: n, runtime dump: y, vanilla uses: 3 (Horse.md#event_spawn)
- `Event_Spawn_Internal` -- binary: n, runtime dump: y, vanilla uses: 3 (Horse.md#event_spawn_internal)
- `Event_Spawned` -- binary: n, runtime dump: y, vanilla uses: 3 (Horse.md#event_spawned)
- `Event_SpawnKeep` -- binary: n, runtime dump: y, vanilla uses: 2 (Horse.md#event_spawnkeep)
- `Expose` -- binary: n, runtime dump: y, vanilla uses: 1 (Horse.md#expose)
- `ForceUsable` -- binary: n, runtime dump: y, vanilla uses: 4 (Horse.md#forceusable)
- `GetActions` -- binary: n, runtime dump: y, vanilla uses: 35 (Horse.md#getactions)
- `GetDogActions` -- binary: n, runtime dump: y, vanilla uses: 3 (Horse.md#getdogactions)
- `GetFlowgraphForwardingEntity` -- binary: n, runtime dump: y, vanilla uses: 1 (Horse.md#getflowgraphforwardingentity)
- `GetInspectableByPlayer` -- binary: n, runtime dump: y, vanilla uses: 1 (Horse.md#getinspectablebyplayer)
- `GetMountableByPlayer` -- binary: n, runtime dump: y, vanilla uses: 1 (Horse.md#getmountablebyplayer)
- `GetReturnToPoolWeight` -- binary: n, runtime dump: y, vanilla uses: 1 (Horse.md#getreturntopoolweight)
- `InitialSetup` -- binary: n, runtime dump: y, vanilla uses: 2 (Horse.md#initialsetup)
- `IsAIControlled` -- binary: n, runtime dump: y, vanilla uses: 0 (Horse.md#isaicontrolled)
- `IsMountLegal` -- binary: n, runtime dump: y, vanilla uses: 2 (Horse.md#ismountlegal)
- `IsUsable` -- binary: n, runtime dump: y, vanilla uses: 47 (Horse.md#isusable)
- `NotifyRemoval` -- binary: n, runtime dump: y, vanilla uses: 2 (Horse.md#notifyremoval)
- `OnBonding` -- binary: n, runtime dump: y, vanilla uses: 2 (Horse.md#onbonding)
- `OnButcher` -- binary: n, runtime dump: y, vanilla uses: 1 (Horse.md#onbutcher)
- `OnDestroy` -- binary: n, runtime dump: y, vanilla uses: 11 (Horse.md#ondestroy)
- `OnDogRequest` -- binary: n, runtime dump: y, vanilla uses: 1 (Horse.md#ondogrequest)
- `OnEditorSetGameMode` -- binary: n, runtime dump: y, vanilla uses: 3 (Horse.md#oneditorsetgamemode)
- `OnInspect` -- binary: n, runtime dump: y, vanilla uses: 1 (Horse.md#oninspect)
- `OnLoad` -- binary: n, runtime dump: y, vanilla uses: 65 (Horse.md#onload)
- `OnLoadAI` -- binary: n, runtime dump: y, vanilla uses: 2 (Horse.md#onloadai)
- `OnLoot` -- binary: n, runtime dump: y, vanilla uses: 2 (Horse.md#onloot)
- `OnMount` -- binary: n, runtime dump: y, vanilla uses: 2 (Horse.md#onmount)
- `OnPropertyChange` -- binary: n, runtime dump: y, vanilla uses: 113 (Horse.md#onpropertychange)
- `OnReset` -- binary: n, runtime dump: y, vanilla uses: 162 (Horse.md#onreset)
- `OnSave` -- binary: n, runtime dump: y, vanilla uses: 60 (Horse.md#onsave)
- `OnSaveAI` -- binary: n, runtime dump: y, vanilla uses: 2 (Horse.md#onsaveai)
- `OnSpawn` -- binary: n, runtime dump: y, vanilla uses: 75 (Horse.md#onspawn)
- `OnStartle` -- binary: n, runtime dump: y, vanilla uses: 1 (Horse.md#onstartle)
- `OnUsed` -- binary: y, runtime dump: y, vanilla uses: 36 (Horse.md#onused)
- `RegisterAI` -- binary: n, runtime dump: y, vanilla uses: 8 (Horse.md#registerai)
- `Reset` -- binary: y, runtime dump: y, vanilla uses: 81 (Horse.md#reset)
- `ResetAIParameters` -- binary: n, runtime dump: y, vanilla uses: 3 (Horse.md#resetaiparameters)
- `ResetCommon` -- binary: n, runtime dump: y, vanilla uses: 1 (Horse.md#resetcommon)
- `ReviveInEditor` -- binary: n, runtime dump: y, vanilla uses: 2 (Horse.md#reviveineditor)
- `SetActorModel` -- binary: n, runtime dump: y, vanilla uses: 1 (Horse.md#setactormodel)
- `SetInspectableByPlayer` -- binary: n, runtime dump: y, vanilla uses: 1 (Horse.md#setinspectablebyplayer)
- `SetMountableByPlayer` -- binary: n, runtime dump: y, vanilla uses: 1 (Horse.md#setmountablebyplayer)
- `SetMountableByPlayerDisabledFromAI` -- binary: n, runtime dump: y, vanilla uses: 1 (Horse.md#setmountablebyplayerdisabledfromai)
- `SetMountIsLegal` -- binary: n, runtime dump: y, vanilla uses: 1 (Horse.md#setmountislegal)
- `SetMountIsLegalFromAI` -- binary: n, runtime dump: y, vanilla uses: 1 (Horse.md#setmountislegalfromai)

## InteractionTrigger

See [InteractionTrigger.md](InteractionTrigger.md) for the documented functions of this table.

- `_CheckDialog` -- binary: n, runtime dump: y, vanilla uses: 2 (InteractionTrigger.md#checkdialog)
- `_GetSendTargets` -- binary: n, runtime dump: y, vanilla uses: 4 (InteractionTrigger.md#getsendtargets)
- `GetActions` -- binary: n, runtime dump: y, vanilla uses: 35 (InteractionTrigger.md#getactions)
- `GetHint` -- binary: n, runtime dump: y, vanilla uses: 3 (InteractionTrigger.md#gethint)
- `GetHintHold` -- binary: n, runtime dump: y, vanilla uses: 3 (InteractionTrigger.md#gethinthold)
- `IsActionAvailable` -- binary: n, runtime dump: y, vanilla uses: 5 (InteractionTrigger.md#isactionavailable)
- `IsEnabledByProperties` -- binary: n, runtime dump: y, vanilla uses: 3 (InteractionTrigger.md#isenabledbyproperties)
- `IsEnabledByScriptPerk` -- binary: n, runtime dump: y, vanilla uses: 3 (InteractionTrigger.md#isenabledbyscriptperk)
- `IsEnabledBySoulAbility` -- binary: n, runtime dump: y, vanilla uses: 3 (InteractionTrigger.md#isenabledbysoulability)
- `IsEnabledFromQuestSystem` -- binary: n, runtime dump: y, vanilla uses: 3 (InteractionTrigger.md#isenabledfromquestsystem)
- `IsEnabledHold` -- binary: n, runtime dump: y, vanilla uses: 7 (InteractionTrigger.md#isenabledhold)
- `IsUsable` -- binary: n, runtime dump: y, vanilla uses: 47 (InteractionTrigger.md#isusable)
- `IsUsableHold` -- binary: n, runtime dump: y, vanilla uses: 6 (InteractionTrigger.md#isusablehold)
- `NeedSerialize` -- binary: n, runtime dump: y, vanilla uses: 5 (InteractionTrigger.md#needserialize)
- `OnAction` -- binary: n, runtime dump: y, vanilla uses: 5 (InteractionTrigger.md#onaction)
- `OnEditorSetGameMode` -- binary: n, runtime dump: y, vanilla uses: 3 (InteractionTrigger.md#oneditorsetgamemode)
- `OnInventoryClosed` -- binary: n, runtime dump: y, vanilla uses: 4 (InteractionTrigger.md#oninventoryclosed)
- `OnInventoryItemUsed` -- binary: n, runtime dump: y, vanilla uses: 2 (InteractionTrigger.md#oninventoryitemused)
- `OnLoad` -- binary: n, runtime dump: y, vanilla uses: 65 (InteractionTrigger.md#onload)
- `OnPropertyChange` -- binary: n, runtime dump: y, vanilla uses: 113 (InteractionTrigger.md#onpropertychange)
- `OnReset` -- binary: n, runtime dump: y, vanilla uses: 162 (InteractionTrigger.md#onreset)
- `OnSave` -- binary: n, runtime dump: y, vanilla uses: 60 (InteractionTrigger.md#onsave)
- `OnSpawn` -- binary: n, runtime dump: y, vanilla uses: 75 (InteractionTrigger.md#onspawn)
- `OnUsed` -- binary: y, runtime dump: y, vanilla uses: 36 (InteractionTrigger.md#onused)
- `OnUsedHold` -- binary: n, runtime dump: y, vanilla uses: 5 (InteractionTrigger.md#onusedhold)
- `OpenInventory` -- binary: n, runtime dump: y, vanilla uses: 3 (InteractionTrigger.md#openinventory)
- `PhysicalizeThis` -- binary: n, runtime dump: y, vanilla uses: 50 (InteractionTrigger.md#physicalizethis)
- `ReportUse` -- binary: n, runtime dump: y, vanilla uses: 8 (InteractionTrigger.md#reportuse)
- `ResetHoldMessage` -- binary: n, runtime dump: y, vanilla uses: 1 (InteractionTrigger.md#resetholdmessage)
- `ResetUseMessage` -- binary: n, runtime dump: y, vanilla uses: 1 (InteractionTrigger.md#resetusemessage)
- `SetAvailable` -- binary: n, runtime dump: y, vanilla uses: 1 (InteractionTrigger.md#setavailable)
- `SetAvailableHold` -- binary: n, runtime dump: y, vanilla uses: 1 (InteractionTrigger.md#setavailablehold)
- `SetHoldMessage` -- binary: n, runtime dump: y, vanilla uses: 2 (InteractionTrigger.md#setholdmessage)
- `SetUseMessage` -- binary: n, runtime dump: y, vanilla uses: 1 (InteractionTrigger.md#setusemessage)
- `UpdateMaterial` -- binary: n, runtime dump: y, vanilla uses: 6 (InteractionTrigger.md#updatematerial)
- `UserNoItem` -- binary: n, runtime dump: y, vanilla uses: 2 (InteractionTrigger.md#usernoitem)

## MaterialEffects

See [MaterialEffects.md](MaterialEffects.md) for the documented functions of this table.

- `ExecuteEffect` -- binary: n, runtime dump: y, vanilla uses: 0 (MaterialEffects.md#executeeffect)
- `GetEffectId` -- binary: n, runtime dump: y, vanilla uses: 0 (MaterialEffects.md#geteffectid)
- `GetEffectIdByLibName` -- binary: n, runtime dump: y, vanilla uses: 0 (MaterialEffects.md#geteffectidbylibname)
- `PrintEffectIdByMatIndex` -- binary: n, runtime dump: y, vanilla uses: 0 (MaterialEffects.md#printeffectidbymatindex)

## Minigame

See [Minigame.md](Minigame.md) for the documented functions of this table.

- `CanStartReadingMinigame` -- binary: y, runtime dump: y, vanilla uses: 1 (Minigame.md#canstartreadingminigame)
- `StartDiceWithScore` -- binary: n, runtime dump: y, vanilla uses: 0 (Minigame.md#startdicewithscore)

## Player

See [Player.md](Player.md) for the documented functions of this table.

- `AddLootAction` -- binary: n, runtime dump: y, vanilla uses: 4 (Player.md#addlootaction)
- `CheatEngine` -- binary: n, runtime dump: y, vanilla uses: 17 (Player.md#cheatengine)
- `CheatEngine_animal` -- binary: n, runtime dump: y, vanilla uses: 25 (Player.md#cheatengine_animal)
- `CheatEngine_equipweapon` -- binary: n, runtime dump: y, vanilla uses: 2 (Player.md#cheatengine_equipweapon)
- `CheatEngine_money` -- binary: n, runtime dump: y, vanilla uses: 2 (Player.md#cheatengine_money)
- `CheatEngine_skill` -- binary: n, runtime dump: y, vanilla uses: 9 (Player.md#cheatengine_skill)
- `CheatEngine_stat` -- binary: n, runtime dump: y, vanilla uses: 6 (Player.md#cheatengine_stat)
- `CheatEngine_time` -- binary: n, runtime dump: y, vanilla uses: 2 (Player.md#cheatengine_time)
- `CheatGiveBow` -- binary: n, runtime dump: y, vanilla uses: 2 (Player.md#cheatgivebow)
- `GetDogActions` -- binary: n, runtime dump: y, vanilla uses: 3 (Player.md#getdogactions)
- `InitialSetup` -- binary: n, runtime dump: y, vanilla uses: 2 (Player.md#initialsetup)
- `OnAction` -- binary: n, runtime dump: y, vanilla uses: 5 (Player.md#onaction)
- `OnBed` -- binary: y, runtime dump: n, vanilla uses: 0 (Player.md#onbed)
- `OnBedInteractiveDialog` -- binary: y, runtime dump: n, vanilla uses: 0 (Player.md#onbedinteractivedialog)
- `OnDogRequest` -- binary: n, runtime dump: y, vanilla uses: 1 (Player.md#ondogrequest)
- `OnInit` -- binary: n, runtime dump: y, vanilla uses: 66 (Player.md#oninit)
- `OnLoadAI` -- binary: n, runtime dump: y, vanilla uses: 2 (Player.md#onloadai)
- `OnReset` -- binary: n, runtime dump: y, vanilla uses: 162 (Player.md#onreset)
- `OnSaveAI` -- binary: n, runtime dump: y, vanilla uses: 2 (Player.md#onsaveai)
- `OnSpawn` -- binary: n, runtime dump: y, vanilla uses: 75 (Player.md#onspawn)
- `PRTelep` -- binary: n, runtime dump: y, vanilla uses: 10 (Player.md#prtelep)
- `PRTelep_unlock` -- binary: n, runtime dump: y, vanilla uses: 7 (Player.md#prtelep_unlock)
- `PRTelepShowMessage` -- binary: n, runtime dump: y, vanilla uses: 3 (Player.md#prtelepshowmessage)
- `Reset` -- binary: y, runtime dump: y, vanilla uses: 81 (Player.md#reset)
- `ResetCommon` -- binary: n, runtime dump: y, vanilla uses: 1 (Player.md#resetcommon)
- `ReviveInEditor` -- binary: n, runtime dump: y, vanilla uses: 2 (Player.md#reviveineditor)
- `SetActorModel` -- binary: n, runtime dump: y, vanilla uses: 1 (Player.md#setactormodel)
- `SetModel` -- binary: n, runtime dump: y, vanilla uses: 1 (Player.md#setmodel)

## RPG

See [RPG.md](RPG.md) for the documented functions of this table.

- `ReconcileWithPublicFriends` -- binary: y, runtime dump: y, vanilla uses: 1 (RPG.md#reconcilewithpublicfriends)

## Shops

See [Shops.md](Shops.md) for the documented functions of this table.

- `AcceptTransaction` -- binary: y, runtime dump: y, vanilla uses: 0 (Shops.md#accepttransaction)
- `CancelTransaction` -- binary: y, runtime dump: y, vanilla uses: 0 (Shops.md#canceltransaction)
- `DoMoneyTransaction` -- binary: y, runtime dump: y, vanilla uses: 1 (Shops.md#domoneytransaction)
- `FindItemInShop` -- binary: y, runtime dump: y, vanilla uses: 0 (Shops.md#finditeminshop)
- `FindShopInventoryForItem` -- binary: y, runtime dump: y, vanilla uses: 0 (Shops.md#findshopinventoryforitem)
- `GetShopDBIdByKeeper` -- binary: y, runtime dump: y, vanilla uses: 1 (Shops.md#getshopdbidbykeeper)
- `GetShopDBIdByLinkedEntityId` -- binary: y, runtime dump: y, vanilla uses: 0 (Shops.md#getshopdbidbylinkedentityid)
- `GetShopMoney` -- binary: y, runtime dump: y, vanilla uses: 1 (Shops.md#getshopmoney)
- `IsLinkedWithShop` -- binary: y, runtime dump: y, vanilla uses: 1 (Shops.md#islinkedwithshop)
- `IsShopOpened` -- binary: y, runtime dump: y, vanilla uses: 0 (Shops.md#isshopopened)
- `OpenInventoryForItem` -- binary: y, runtime dump: y, vanilla uses: 1 (Shops.md#openinventoryforitem)

## SkipTime

See [SkipTime.md](SkipTime.md) for the documented functions of this table.

- `GetSkipTimeMessageUIString` -- binary: n, runtime dump: y, vanilla uses: 1 (SkipTime.md#getskiptimemessageuistring)

## SmartObject

See [SmartObject.md](SmartObject.md) for the documented functions of this table.

- `Event_Used` -- binary: n, runtime dump: y, vanilla uses: 2 (SmartObject.md#event_used)
- `OnInit` -- binary: n, runtime dump: y, vanilla uses: 66 (SmartObject.md#oninit)
- `OnNavigationStarted` -- binary: n, runtime dump: y, vanilla uses: 1 (SmartObject.md#onnavigationstarted)
- `OnReset` -- binary: n, runtime dump: y, vanilla uses: 162 (SmartObject.md#onreset)
- `OnUsed` -- binary: y, runtime dump: y, vanilla uses: 36 (SmartObject.md#onused)

## Statistics

See [Statistics.md](Statistics.md) for the documented functions of this table.

- `Insert` -- binary: y, runtime dump: y, vanilla uses: 0 (Statistics.md#insert)
- `Remove` -- binary: y, runtime dump: y, vanilla uses: 0 (Statistics.md#remove)
- `Set` -- binary: n, runtime dump: y, vanilla uses: 0 (Statistics.md#set)

## System

See [System.md](System.md) for the documented functions of this table.

- `GetEntityPositionAndDirection` -- binary: y, runtime dump: y, vanilla uses: 0 (System.md#getentitypositionanddirection)
- `GetSkyHighlight` -- binary: y, runtime dump: y, vanilla uses: 0 (System.md#getskyhighlight)
- `GetWind` -- binary: y, runtime dump: y, vanilla uses: 2 (System.md#getwind)
- `SetOutdoorAmbientColor` -- binary: y, runtime dump: y, vanilla uses: 0 (System.md#setoutdoorambientcolor)
- `ViewDistanceGet` -- binary: y, runtime dump: y, vanilla uses: 2 (System.md#viewdistanceget)

## Trace

See [Trace.md](Trace.md) for the documented functions of this table.

- `Brutus` -- binary: n, runtime dump: y, vanilla uses: 0 (Trace.md#brutus)
- `Debug` -- binary: n, runtime dump: y, vanilla uses: 0 (Trace.md#debug)
- `Detail` -- binary: n, runtime dump: y, vanilla uses: 0 (Trace.md#detail)
- `Error` -- binary: y, runtime dump: y, vanilla uses: 3 (Trace.md#error)
- `Fatal` -- binary: n, runtime dump: y, vanilla uses: 0 (Trace.md#fatal)
- `Info` -- binary: n, runtime dump: y, vanilla uses: 1 (Trace.md#info)
- `max_trace_level` -- binary: n, runtime dump: y, vanilla uses: 0 (Trace.md#max_trace_level)
- `Warning` -- binary: y, runtime dump: y, vanilla uses: 2 (Trace.md#warning)

## UI

See [UI.md](UI.md) for the documented functions of this table.

- `OnForgeBuilderLinkNodeDespawn` -- binary: y, runtime dump: y, vanilla uses: 1 (UI.md#onforgebuilderlinknodedespawn)
- `OnForgeBuilderLinkNodeSpawn` -- binary: y, runtime dump: y, vanilla uses: 1 (UI.md#onforgebuilderlinknodespawn)

## XGenAIModule

See [XGenAIModule.md](XGenAIModule.md) for the documented functions of this table.

- `MakeTableFromType` -- binary: y, runtime dump: y, vanilla uses: 1 (XGenAIModule.md#maketablefromtype)
- `ProduceSound` -- binary: n, runtime dump: y, vanilla uses: 0 (XGenAIModule.md#producesound)
- `ProduceSoundWUID` -- binary: n, runtime dump: y, vanilla uses: 1 (XGenAIModule.md#producesoundwuid)
