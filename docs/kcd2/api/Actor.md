# Actor

C++ class(es): `CScriptBindGame`, `CScriptBind_Game`, `C_ScriptBindActor`, `C_ScriptBind_Actor`, `C_ScriptBind_Human`
Reached from Lua as `Actor.FunctionName(...)`.
149 documented function(s); 2 additional undocumented function(s) found in retail/runtime.

## Functions

### AcceptChatRequest

```lua
Actor.AcceptChatRequest()
```

C++: `virtual int AcceptChatRequest (IFunctionHandler* pH )`

Accepts chat request from this actor.

docs: y · retail: confirmed (vanilla×1)

### AcceptStealthActionByVictim

```lua
Actor.AcceptStealthActionByVictim()
```

C++: `virtual int AcceptStealthActionByVictim (IFunctionHandler * pH )`

Called by victim to accept stealth action.

docs: y · retail: unconfirmed

### AddAngularImpulse

```lua
Actor.AddAngularImpulse(Ang3 vAngular,float deceleration,float duration)
```

Sets and angular impulse to the actor.

| Param | Description |
|---|---|
| Ang3 vAngular | Rotation angle value. |
| float deceleration | Deceleration of the impulse. |
| float duration | Duration of the impulse. |

docs: y · retail: unconfirmed

### AddBlood

```lua
actor.AddBlood(1, 'head')
```

Adds blood on all equipped items and body in given body part (or all body parts).

| Param | Description |
|---|---|
| float bloodDelta | (negative numbers will clean blood) bodyPartName (optional) - body part name from the database, or nothing to modify blood on all zones |

docs: y · retail: confirmed (binary, vanilla×20)

### AddDirt

```lua
actor.AddDirt(1)
```

Adds dirt on all equipped items.

| Param | Description |
|---|---|
| float dirtDelta |  |

docs: y · retail: confirmed (binary, vanilla×6)

### AddFrost

```lua
actor.AddFrost(float frost)
```

Adds the specified frost amount.

| Param | Description |
|---|---|
| float frost | Frost amount. |

docs: y · retail: unconfirmed

### AttachTo

```lua
Actor.AttachTo()
```

C++: `virtual void AttachTo (C_Actor * pActor )`

docs: y · retail: unconfirmed

### AttachVulnerabilityEffect

```lua
Actor.AttachVulnerabilityEffect(int characterSlot, int partid, Vec3 hitPos, float radius, const char* effect, const char* attachmentIdentifier)
```

Attaches vulnerability effect.

| Param | Description |
|---|---|
| int characterSlot | Character slot. |
| int partid | . |
| Vec3 hitPos | Position of the hit. |
| float radius | Radius of the hit. |
| const char* effect | Effect string name. |
| attachmentIndetifier | Identifier for the attachment. |

docs: y · retail: unconfirmed

### CameraShake

```lua
Actor.CameraShake(float amount,float duration,float frequency,Vec3 pos)
```

Applies a shake movement to the camera.

| Param | Description |
|---|---|
| float amount | Amount of the shake movement. |
| float duration | Duration of the shake movement. |
| float frequency | Frequency of the shake movement. |
| Vec3 pos | Position of the shake movement. |

docs: y · retail: unconfirmed

### CanBeButchered

```lua
Actor.CanBeButchered()
```

C++: `virtual int CanBeButchered (IFunctionHandler* pH )`

Returns true if actor can be butchered (Must be animal and not yet butchered) See also IsPlayerInButcheringDistance

docs: y · retail: confirmed (vanilla×1)

### CanChat

```lua
Actor.CanChat()
```

C++: `virtual int CanChat (IFunctionHandler* pH )`

Checks if chat can be started with this actor.

docs: y · retail: confirmed (vanilla×1)

### CanDoMercyKill

```lua
Actor.CanDoMercyKill(EntityId victimEntityId)
```

Find out if we actor is allowed to kill another from mercy

| Param | Description |
|---|---|
| ScriptHandle victimEntityId | dying entity |

docs: y · retail: confirmed (vanilla×1)

### CanEnemyFight

```lua
Actor.CanEnemyFight(ScriptHandle enemy)
```

Returns true if enemy can fight - is alive and is known for combat system

| Param | Description |
|---|---|
| actor | Enemy actor |

docs: y · retail: unconfirmed

### CanFollow

```lua
Actor.CanFollow(npcEntity)
```

C++: `virtual int CanFollow (IFunctionHandler* pH )`

Checks if this NPC can be followed be player.

docs: y · retail: confirmed (vanilla×1)

### CanGrabCorpse

```lua
Actor.CanGrabCorpse(EntityId victimEntityId)
```

Returns true if actor can grab vitimEntintyId

| Param | Description |
|---|---|
| ScriptHandle victimEntityId | entity to grab |

docs: y · retail: confirmed (vanilla×1)

### CanHorsePullDown

```lua
Actor.CanHorsePullDown(EntityId victimEntityId)
```

Find out if we actor is allowed to pull down another actor from horse

| Param | Description |
|---|---|
| ScriptHandle victimEntityId | entity on horse |

docs: y · retail: confirmed (vanilla×1)

### CanHuntAttack

```lua
Actor.CanHuntAttack(EntityId victimEntityId)
```

Find out if we actor is allowed to hunt attack from run

| Param | Description |
|---|---|
| ScriptHandle victimEntityId | entity on horse |

docs: y · retail: unconfirmed

### CanInteractWith

```lua
Actor.CanInteractWith()
```

C++: `virtual int CanInteractWith (IFunctionHandler * pH , ScriptHandle entityId )`

Checks if entity is close enough to interact with another one. Distance is defined by wh_player_TalkInteractorDistance

docs: y · retail: confirmed (vanilla×4, mod×2)

### CanKnockOut

```lua
Actor.CanKnockOut(EntityId victimEntityId)
```

Find out if actor is allowed to knock out given entity

| Param | Description |
|---|---|
| ScriptHandle victimEntityId | entity to daze |

docs: y · retail: unconfirmed

### CanLoot

```lua
Actor.CanLoot(EntityId victimEntityId)
```

Returns true if actor can loot vitimEntintyId

| Param | Description |
|---|---|
| ScriptHandle victimEntityId | entity to loot |

docs: y · retail: confirmed (vanilla×1)

### CanPutCorpse

```lua
Actor.CanPutCorpse()
```

C++: `virtual int CanPutCorpse (IFunctionHandler * pH )`

Returns true if actor is carrying a corpse and can put it back to the ground

docs: y · retail: unconfirmed

### CanStealthKill

```lua
Actor.CanStealthKill(ScriptHandle victimEntityId)
```

Combat stealth actions ============================================= Syntax: Actor.CanStealthKill(EntityId victimEntityId)

Find out if we actor is allowed to kill given entity by stealth kill

| Param | Description |
|---|---|
| ScriptHandle victimEntityId | entity to kill |

docs: y · retail: confirmed (vanilla×1)

### CanStealthKnockout

```lua
Actor.CanStealthKnockout(EntityId victimEntityId)
```

Find out if we actor is allowed to knockout given entity by stealth

| Param | Description |
|---|---|
| ScriptHandle victimEntityId | entity to knockout |

docs: y · retail: confirmed (vanilla×1)

### CanTalk

```lua
Actor.CanTalk()
```

C++: `virtual int CanTalk (IFunctionHandler* pH )`

Checks if this human have something to say.

docs: y · retail: confirmed (vanilla×3)

### ChangeAnimGraph

```lua
Actor.ChangeAnimGraph(const char *graph, int layer)
```

Changes the animation graph.

| Param | Description |
|---|---|
| const char * graph | Graph name. |
| int layer | . |

docs: y · retail: unconfirmed

### CheckInventoryRestrictions

```lua
Actor.CheckInventoryRestrictions(const char *itemClassName)
```

Checks if there is any restriction in the inventory for the specific item class.

| Param | Description |
|---|---|
| const char * itemClassName | Name of the item class. |

docs: y · retail: unconfirmed

### CheckVirtualInventoryRestrictions

```lua
Actor.CheckVirtualInventoryRestrictions(SmartScriptTable inventory, const char *itemClassName)
```

Checks if there is any restriction in the virtual inventory for the specific item class.

| Param | Description |
|---|---|
| SmartScriptTable inventory | Inventory. |
| const char * itemClassName | Item class name. |

docs: y · retail: unconfirmed

### CleanDirt

```lua
actor.CleanDirt(1)
```

Use only when you want to clean somebody programmatically. If you want to clean player after its in-game action, call WashDirtAndBlood instead. Cleans all actor clothes with 0 - 100% cleaning efficiency

| Param | Description |
|---|---|
| float maxCleaningEffect | , 1 - actor be totally clean, 0 - no cleaning at all |

docs: y · retail: confirmed (binary, mod×1)

### ClearEnemy

```lua
Actor.ClearEnemy()
```

C++: `virtual int ClearEnemy (IFunctionHandler * pH )`

Tells to actor there is no enemy

docs: y · retail: unconfirmed

### ClearForcedLookDir

```lua
Actor.ClearForcedLookDir()
```

C++: `int ClearForcedLookDir (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary)

### ClearForcedLookObjectId

```lua
Actor.ClearForcedLookObjectId()
```

C++: `int ClearForcedLookObjectId (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary)

### CreateCodeEvent

```lua
Actor.CreateCodeEvent(SmartScriptTable params)
```

Creates a code event.

| Param | Description |
|---|---|
| SmartScriptTable params | Parameters for the event. |

docs: y · retail: unconfirmed

### CreateIKLimb

```lua
Actor.CreateIKLimb(int slot, const char *limbName, const char *rootBone, const char *midBone, const char *endBone, int flags)
```

Creates an IK (Inverse Kinematics) limb.

| Param | Description |
|---|---|
| int slot | Slot number. |
| const char * limbName | Limb name string. |
| const char * rootBone | Bone root. |
| const char * midBone | Middle bone. |
| const char * endBone | End bone. |
| int flags | Flags. |

docs: y · retail: unconfirmed

### DamageInfo

```lua
Actor.DamageInfo(ScriptHandle shooter, ScriptHandle target, ScriptHandle weapon, float damage, const char *damageType)
```

Gets damage info.

| Param | Description |
|---|---|
| ScriptHandle shooter | Shooter that caused the damage. |
| ScriptHandle target | Target that suffered the damage. |
| ScriptHandle weapon | Weapon that caused the damage. |
| float damage | Amount of damage caused. |
| const char * damageType | Type of damage caused. |

docs: y · retail: unconfirmed

### DoChat

```lua
Actor.DoChat()
```

C++: `virtual int DoChat (IFunctionHandler* pH )`

Start chat with the player.

docs: y · retail: confirmed (vanilla×2)

### DumpActorInfo

```lua
Actor.DumpActorInfo()
```

C++: `virtual int DumpActorInfo (IFunctionHandler * pH )`

Dumps actor info in the log file.

docs: y · retail: unconfirmed

### EnableAspect

```lua
Actor.EnableAspect(const char *aspect, bool enable)
```

Enables/Disables the specified aspect.

| Param | Description |
|---|---|
| const char * aspect | Aspect name. |
| bool enable | True to enable the aspect, false otherwise. |

docs: y · retail: unconfirmed

### EquipClothingPreset

```lua
Actor.EquipClothingPreset(char const* presetGuid)
```

Clothing ============================================= Syntax: Actor.EquipClothingPreset( "46ea38bb-0be7-ca10-a8ac-d526056c04b3" )

Clothing preset is equipped to actor. Dirt level of actor is used for new items. Health of equipment slots is ignored.

| Param | Description |
|---|---|
| char const* presetGuid | Identifier of the clothing preset |

docs: y · retail: confirmed (vanilla×11, mod×16)

### EquipInventoryItem

```lua
Actor.EquipInventoryItem(ScriptHandle itemId)
```

Equips item from inventory

| Param | Description |
|---|---|
| ScriptHandle itemId | Identifier for the item |

docs: y · retail: confirmed (vanilla×19, mod×3)

### EquipWeaponPreset

```lua
Actor.EquipWeaponPreset(char const* presetGuid)
```

Weapon preset ============================================= Syntax: Actor.EquipWeaponPreset( "46ea38bb-0be7-ca10-a8ac-d526056c04b3" )

Weapon preset is equipped to actor. Health of equipment slots is ignored.

| Param | Description |
|---|---|
| char const* presetGuid | Identifier of the weapon preset |

docs: y · retail: confirmed (vanilla×4, mod×10)

### Fall

```lua
Actor.Fall(Vec3 hitPos)
```

Makes the actor falling down.

| Param | Description |
|---|---|
| Vec3 hitPos | Hit position. |

docs: y · retail: unconfirmed

### GetActor

```lua
Actor.GetActor()
```

C++: `C_Actor * GetActor (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### GetActorId

```lua
Actor.GetActorId()
```

C++: `EntityId GetActorId (IFunctionHandler * pH )`

This is GetActorId, a member of class C_ScriptBindActor.

docs: y · retail: unconfirmed

### GetActorIdFromParameter

```lua
Actor.GetActorIdFromParameter()
```

C++: `EntityId GetActorIdFromParameter (IFunctionHandler* pH , uint index )`

docs: y · retail: unconfirmed

### GetAngles

```lua
Actor.GetAngles()
```

C++: `virtual int GetAngles (IFunctionHandler * pH )`

Gets the rotation angle of the actor.

docs: y · retail: confirmed (binary, vanilla×14, mod×8)

### GetArmor

```lua
Actor.GetArmor()
```

C++: `virtual int GetArmor (IFunctionHandler * pH )`

Gets the amount of armor.

docs: y · retail: confirmed (mod×1)

### GetChannel

```lua
Actor.GetChannel()
```

C++: `virtual int GetChannel (IFunctionHandler * pH )`

Gets network channel.

docs: y · retail: confirmed (vanilla×4)

### GetCloseColliderParts

```lua
Actor.GetCloseColliderParts(int characterSlot, Vec3 hitPos, float radius)
```

Gets the closer collider parts.

| Param | Description |
|---|---|
| Vec3 hitPos | Position of the hit. |
| float radius | Radius of the hit effect. |

docs: y · retail: unconfirmed

### GetClosestAttachment

```lua
Actor.GetClosestAttachment(int characterSlot, Vec3 testPos, float maxDistance, const char* suffix)
```

Gets the closest attachment to the specified position within the specified distance.

| Param | Description |
|---|---|
| int characterSlot | Character slot. |
| Vec3 testPos | Position to be tested. |
| float maxDistance | Maximum distance to be tested. |
| const char* suffix | Suffix string. |

docs: y · retail: unconfirmed

### GetCombatDistance

```lua
Actor.GetCombatDistance()
```

C++: `virtual int GetCombatConfiguration (IFunctionHandler * pH )`

Gets configuration of combatants 0 - undefined 1 - too close 2 - optimal distance 3 - too far

docs: y · retail: unconfirmed

### GetCurrentAnimationState

```lua
Actor.GetCurrentAnimationState()
```

C++: `virtual int GetCurrentAnimationState (IFunctionHandler * pH )`

Gets the state for the current animation.

docs: y · retail: confirmed (mod×5)

### GetExtensionParams

```lua
Actor.GetExtensionParams(const char *extension, SmartScriptTable params)
```

Gets the parameters for the specified extension.

| Param | Description |
|---|---|
| const char * extension | Extension name. |
| SmartScriptTable params | Parameters to be set for the extension. |

docs: y · retail: confirmed (binary)

### GetFrozenAmount

```lua
actor.GetFrozenAmount()
```

C++: `virtual int GetFrozenAmount (IFunctionHandler * pH )`

Gets the frozen amount.

docs: y · retail: unconfirmed

### GetGardDistance

```lua
Actor.GetGardDistance()
```

C++: `virtual int GetGardDistance (IFunctionHandler * pH )`

Combat Actor iface ============================================= Syntax: Actor.GetGardDistance()

Gets the distance from opponent in (gard to gard metric)

docs: y · retail: unconfirmed

### GetHeadDir

```lua
Actor.GetHeadDir()
```

C++: `virtual int GetHeadDir (IFunctionHandler * pH )`

Gets the the actor's head direction.

has to be changed! (maybe bone position)

docs: y · retail: unconfirmed

### GetHeadPos

```lua
Actor.GetHeadPos()
```

C++: `virtual int GetHeadPos (IFunctionHandler * pH )`

Gets the actor's head position.

has to be changed! (maybe bone position)

docs: y · retail: unconfirmed

### GetHealth

```lua
Actor.GetHealth()
```

C++: `virtual int GetHealth (IFunctionHandler * pH )`

Gets the amount of health. NOTE: call soul.GetHealth()

docs: y · retail: confirmed (vanilla×4, mod×6)

### GetInitialClothingPreset

```lua
Actor.GetInitialClothingPreset()
```

C++: `virtual int GetInitialClothingPreset (IFunctionHandler* pH )`

Returns string - GUID of initial clothing preset

docs: y · retail: confirmed (vanilla×3, mod×1)

### GetInitialWeaponPreset

```lua
Actor.GetInitialWeaponPreset()
```

C++: `virtual int GetInitialWeaponPreset (IFunctionHandler* pH )`

Returns string - GUID of initial weapon preset

docs: y · retail: confirmed (mod×1)

### GetLinkedEntity

```lua
Actor.GetLinkedEntity()
```

C++: `virtual int GetLinkedEntity (IFunctionHandler * pH )`

Returns entity which is this actor linked to.

docs: y · retail: confirmed (vanilla×1)

### GetMainChatNPC

```lua
Actor.GetMainChatNPC()
```

C++: `EntityId GetMainChatNPC (EntityId id ) const`

When given entity is in chat, returns Main chat NPC of this chat

docs: y · retail: unconfirmed

### GetMaxArmor

```lua
Actor.GetMaxArmor()
```

C++: `virtual int GetMaxArmor (IFunctionHandler * pH )`

Gets the maximum amount of armor.

docs: y · retail: unconfirmed

### GetMaxHealth

```lua
Actor.GetMaxHealth()
```

C++: `virtual int GetMaxHealth (IFunctionHandler * pH )`

Gets the maximum amount of health.

docs: y · retail: confirmed (vanilla×1, mod×12)

### GetParams

```lua
Actor.GetParams()
```

C++: `virtual int GetParams (IFunctionHandler * pH )`

Gets the Actor parameters.

get some infos from the actor

docs: y · retail: unconfirmed

### GetPhysicalizationProfile

```lua
Actor.GetPhysicalizationProfile()
```

C++: `virtual int GetPhysicalizationProfile (IFunctionHandler * pH )`

Gets the physicalization profile.

docs: y · retail: unconfirmed

### GetSpectatorMode

```lua
Actor.GetSpectatorMode()
```

C++: `virtual int GetSpectatorMode (IFunctionHandler * pH )`

Gets the current spectator mode.

docs: y · retail: confirmed (vanilla×1)

### GetViewAngleOffset

```lua
Actor.GetViewAngleOffset()
```

C++: `virtual int GetViewAngleOffset (IFunctionHandler * pH )`

Gets the offset angle for the view.

docs: y · retail: unconfirmed

### GoLimp

```lua
Actor.GoLimp()
```

C++: `virtual int GoLimp (IFunctionHandler * pH )`

Makes the Actor having a limp. OBSOLETE: in 3.5

docs: y · retail: unconfirmed

### GrabOnLadder

```lua
Actor.GrabOnLadder()
```

C++: `virtual int GrabOnLadder (IFunctionHandler * pH , ScriptHandle ladderId )`

Grabs actor on a ladder

docs: y · retail: confirmed (vanilla×1)

### HasAcceptedChat

```lua
Actor.HasAcceptedChat()
```

C++: `virtual int HasAcceptedChat (IFunctionHandler* pH )`

Checks if this actor has accepted chat.

docs: y · retail: confirmed (vanilla×1)

### HasChatRequest

```lua
Actor.HasChatRequest()
```

C++: `virtual int HasChatRequest (IFunctionHandler* pH )`

Checks if this actor requested a chat with the player.

docs: y · retail: confirmed (vanilla×1)

### IsBodyMoreDirty

```lua
actor.IsBodyMoreDirty(0.2)
```

C++: `int IsBodyMoreDirty (IFunctionHandler* pH , float dirtLevel )`

Returns true if body is more dirty than dirtLevel

docs: y · retail: confirmed (binary, vanilla×1)

### IsCarryingCorpse

```lua
Actor.IsCarryingCorpse()
```

C++: `virtual int IsCarryingCorpse (IFunctionHandler * pH )`

Checks if this human is carrying a corpse.

docs: y · retail: confirmed (vanilla×1)

### IsDead

```lua
Actor.IsDead()
```

C++: `virtual int IsDead (IFunctionHandler* pH )`

docs: y · retail: confirmed (vanilla×5, mod×7)

### IsFlying

```lua
Actor.IsFlying()
```

C++: `virtual int IsFlying (IFunctionHandler * pH )`

Checks if the actor is flying.

docs: y · retail: unconfirmed

### IsFollowing

```lua
Actor.IsFollowing(npcEntity)
```

C++: `virtual int IsFollowing (IFunctionHandler* pH )`

Checks if player is currently following the specified NPC.

docs: y · retail: confirmed (vanilla×1)

### IsGhostPit

```lua
Actor.IsGhostPit()
```

C++: `virtual int IsGhostPit (IFunctionHandler * pH )`

Checks if the actor in the vehicle is hidden.

docs: y · retail: unconfirmed

### IsLocalClient

```lua
Actor.IsLocalClient()
```

C++: `virtual int IsLocalClient (IFunctionHandler * pH )`

Checks if the script is runnin on a local client.

docs: y · retail: unconfirmed

### IsMoreDirty

```lua
actor.IsMoreDirty(0.2)
```

C++: `int IsMoreDirty (IFunctionHandler* pH , float dirtLevel )`

Returns true if any equipped item has more dirt status than the dirtLevel argument.

docs: y · retail: confirmed (binary, vanilla×1)

### IsOnLadder

```lua
Actor.IsOnLadder()
```

C++: `virtual int IsOnLadder (IFunctionHandler * pH )`

Returns 0/1 depending on if actor is already grabbed on a ladder

docs: y · retail: unconfirmed

### IsPlayer

```lua
Actor.IsPlayer()
```

C++: `virtual int IsPlayer (IFunctionHandler * pH )`

Checks if the actor is the player.

docs: y · retail: confirmed (binary, vanilla×15)

### IsPlayerInButcheringDistance

```lua
Actor.IsPlayerInButcheringDistance()
```

C++: `virtual int IsPlayerInButcheringDistance (IFunctionHandler* pH )`

Returns true if actor is withing butchering distance Does not check other butchering conditions - use in conjunction with CanBeButchered

docs: y · retail: confirmed (vanilla×1)

### IsUnconscious

```lua
Actor.IsUnconscious()
```

C++: `virtual int IsUnconscious (IFunctionHandler * pH )`

Returns true if the actor is unconscious.

docs: y · retail: confirmed (vanilla×3, mod×5)

### IsWaitingForDialogueReply

```lua
Actor.IsWaitingForDialogueReply()
```

C++: `virtual int IsWaitingForDialogueReply (IFunctionHandler* pH )`

Checks if actor is waiting for player to reply in a dialogue.

docs: y · retail: confirmed (vanilla×2)

### Kill

```lua
actor.Kill()
```

C++: `virtual int Kill (IFunctionHandler * pH )`

Kills the Actor.

docs: y · retail: unconfirmed

### LinkToEntity

```lua
Actor.LinkToEntity()
```

C++: `virtual int LinkToEntity (IFunctionHandler * pH )`

Links the Actor to an entity.

docs: y · retail: unconfirmed

### MakeLookAsActor

```lua
Actor.MakeLookAsActor(sourceSoulGuid)
```

C++: `virtual int MakeLookAsSoul (IFunctionHandler * pH , char const * sourceSoulGuid )`

Actor will look as another actor according to initial values in soul table. The source actor needs not be in scene.

docs: y · retail: unconfirmed

### OpenChat

```lua
Actor.OpenChat()
```

C++: `virtual int OpenChat (IFunctionHandler* pH )`

Continue chat with the player.

docs: y · retail: confirmed (vanilla×1)

### OpenInventory

```lua
Actor.OpenInventory(entityId, mode, otherInventoryId, filter)
```

Returns more human readable representation of wuid.

| Param | Description |
|---|---|
| ScriptHandle entityId | id of entity that opened this inventory and that entity is notified when item is selected and inventory is closed |
| int mode | inventory mode from enum |
| framework | :T_WUIDScriptType otherInventoryId second inventory for some modes like store |
| char const* pFilter | string filter for filter inventory mode; more milters are delimited with | char (example: *.*.*) |

docs: y · retail: confirmed (vanilla×3)

### OpenItemMultiselectionFilter

```lua
Actor.OpenItemMultiselectionFilter(entityId, filter)
```

Opens UI for selecting multiple items with multiple amounts.

| Param | Description |
|---|---|
| ScriptHandle entityId | id of entity that opened this inventory and that entity is notified when items are selected and inventory is closed |
| char const* pFilter | string filter for filter inventory mode; more milters are delimited with | char (example: *.*.*) |

docs: y · retail: confirmed (vanilla×1)

### OpenItemSelectionFilter

```lua
Actor.OpenItemSelectionFilter(entityId, filter)
```

Opens UI for selecting single item.

| Param | Description |
|---|---|
| ScriptHandle entityId | id of entity that opened this inventory and that entity is notified when item is selected and inventory is closed |
| char const* pFilter | string filter for filter inventory mode; more milters are delimited with | char (example: *.*.*) |

docs: y · retail: confirmed (vanilla×1)

### OpenItemSelectionSharpening

```lua
Actor.OpenItemSelectionSharpening(entityId)
```

Returns more human readable representation of wuid.

| Param | Description |
|---|---|
| ScriptHandle entityId | id of entity that opened this inventory and that entity is notified when item is selected and inventory is closed |

docs: y · retail: confirmed (vanilla×1)

### OpenItemTransferStore

```lua
Actor.OpenItemTransferStore(otherInventoryId)
```

| Param | Description |
|---|---|
| framework | :T_WUIDScriptType otherInventoryId id of inventory between player transfering items |

docs: y · retail: confirmed (vanilla×2, mod×3)

### PlayerSetViewAngles

```lua
Actor.PlayerSetViewAngles()
```

C++: `virtual int PlayerSetViewAngles (IFunctionHandler * pH , Ang3 vAngles )`

docs: y · retail: confirmed (vanilla×2)

### PostPhysicalize

```lua
Actor.PostPhysicalize()
```

C++: `virtual int PostPhysicalize (IFunctionHandler * pH )`

Forces the physical proxy to be rebuilt.

docs: y · retail: unconfirmed

### QueueAnimationState

```lua
Actor.QueueAnimationState(const char *animationState)
```

Pushes an animation state into the queue.

| Param | Description |
|---|---|
| const char * animationState | Animation state. |

docs: y · retail: unconfirmed

### RagDollize

```lua
Actor.RagDollize()
```

C++: `virtual int RagDollize (IFunctionHandler * pH )`

Activates the ragdoll death animations for the Actor.

docs: y · retail: confirmed (binary, vanilla×2)

### RenderScore

```lua
Actor.RenderScore(ScriptHandle player, int kills, int deaths, int ping)
```

Renders the score to the HUD.

| Param | Description |
|---|---|
| ScriptHandle player | Player identifier. |
| int kills | Amount of kills. |
| int deaths | Amount of deaths. |
| int ping | . |

docs: y · retail: unconfirmed

### RequesPutCorpse

```lua
Actor.RequesPutCorpse()
```

C++: `virtual int RequestPutCorpse (IFunctionHandler * pH )`

Start putting corpse to the ground

docs: y · retail: unconfirmed

### RequestDialog

```lua
Actor.RequestDialog(entity, roles, bOnce)
```

Requests dialog with this human. roles - meta roles override for source soul Dialog does not start immediately but it only notifies targeted entity that somebody wants to interact with it. If target entity does not respond in proper time the request is canceled automatically. Returns true in case request was successfully accepted by dialog manager. In some cases it can return false which means that dialog was refused.

| Param | Description |
|---|---|
| entity | entity id to start dialog with |
| roles | string with roles overrides |
| bOnce | true/false if dialog should be played just once and automatically end after that |
| bUseTwins | true/false if twis are requested |
| bRequestChat | true/false if chat is requested |

docs: y · retail: confirmed (vanilla×2)

### RequestGrabCorpse

```lua
Actor.RequestGrabCorpse(EntityId victimEntityId)
```

Start grabbing target entity

| Param | Description |
|---|---|
| ScriptHandle victimEntityId | entity to grab |

docs: y · retail: confirmed (vanilla×1)

### RequestHorsePullDown

```lua
Actor.RequestHorsePullDown(EntityId victimEntityId)
```

Request to pull down from horse

| Param | Description |
|---|---|
| ScriptHandle victimEntityId | entity on horse |

docs: y · retail: confirmed (vanilla×1)

### RequestHuntAttack

```lua
Actor.RequestHuntAttack(EntityId victimEntityId)
```

Request to hunt attack from run

| Param | Description |
|---|---|
| ScriptHandle victimEntityId | entity on horse |

docs: y · retail: unconfirmed

### RequestItemExchange

```lua
Actor.RequestItemExchange(entity)
```

C++: `virtual int RequestItemExchange (IFunctionHandler * pH )`

Requests inventory item exchange from this actor, loot in case actor is dead.

docs: y · retail: confirmed (vanilla×3)

### RequestKnockOut

```lua
Actor.RequestKnockOut(EntityId victimEntityId)
```

Request to knock out given entity

| Param | Description |
|---|---|
| ScriptHandle victimEntityId | entity to kill |

docs: y · retail: confirmed (vanilla×1)

### RequestMercyKill

```lua
Actor.RequestMercyKill(EntityId victimEntityId)
```

Request to mercy kill on dying entity

| Param | Description |
|---|---|
| ScriptHandle victimEntityId | dying entity on horse |

docs: y · retail: confirmed (vanilla×1)

### RequestStealthKill

```lua
Actor.RequestStealthKill(EntityId victimEntityId)
```

Request to kill given entity by stealth kill

| Param | Description |
|---|---|
| ScriptHandle victimEntityId | entity to kill |

docs: y · retail: confirmed (vanilla×1)

### ResetScores

```lua
Actor.ResetScores()
```

C++: `virtual int ResetScores (IFunctionHandler * pH )`

Resets scores.

docs: y · retail: unconfirmed

### ResetVulnerabilityEffects

```lua
Actor.ResetVulnerabilityEffects(int characterSlot)
```

Resets the vulnerability effects.

| Param | Description |
|---|---|
| int characterSlot | Character slot. |

docs: y · retail: unconfirmed

### Revive

```lua
actor.Revive()
```

C++: `virtual int Revive (IFunctionHandler * pH )`

Revives the Actor.

docs: y · retail: confirmed (vanilla×1)

### ReviveToDefaults

```lua
actor.ReviveToDefaults()
```

C++: `virtual int ReviveToDefaults (IFunctionHandler * pH )`

Revives the Actor to default values.

docs: y · retail: unconfirmed

### SetAIBodyId

```lua
Actor.SetAIBodyId(55)
```

| Param | Description |
|---|---|
| char const* bodyId | ID (guid) of body must be from table "ai_body". Otherwise the level can't be saved |

docs: y · retail: unconfirmed

### SetAIBrainId

```lua
Actor.SetAIBrainId(5)
```

| Param | Description |
|---|---|
| char const* brainId | ID (guid) of brain must be from table "brain". Otherwise the level can't be saved |

docs: y · retail: unconfirmed

### SetAngles

```lua
Actor.SetAngles(Ang3 vAngles)
```

Sets the rotation angle for the actor.

TOFIX:rendundant with CScriptBind_Entity::SetAngles

| Param | Description |
|---|---|
| Ang3 vAngles | Rotation angle for the actor. |

docs: y · retail: confirmed (binary, vanilla×10, mod×67)

### SetAnimationInput

```lua
Actor.SetAnimationInput(const char * inputID, const char * value)
```

Sets the animation input.

| Param | Description |
|---|---|
| const char * inputID | Identifier for the input. |
| const char * value | Value for the input. |

docs: y · retail: unconfirmed

### SetClothingDirtLevel

```lua
Actor.SetClothingDirtLevel(0)
```

Sets dirt level on all equipped items

| Param | Description |
|---|---|
| float dirtLevel |  |

docs: y · retail: unconfirmed

### SetDialogAnimationState

```lua
Actor.SetDialogAnimationState(true)
```

C++: `virtual int SetDialogAnimationState (IFunctionHandler * pH , bool state )`

Turns automatic dialog animation on and off

docs: y · retail: unconfirmed

### SetEnemy

```lua
Actor.SetEnemy(ScriptHandle enemy)
```

Tells to actor who is enemy

| Param | Description |
|---|---|
| actor | Enemy actor |

docs: y · retail: unconfirmed

### SetExtensionActivation

```lua
Actor.SetExtensionActivation(const char *extension, bool activation)
```

C++: `virtual int SetExtensionActivation (IFunctionHandler * pH , const char * extension , bool activation )`

docs: y · retail: unconfirmed

### SetExtensionParams

```lua
Actor.SetExtensionParams(const char *extension, SmartScriptTable params)
```

Sets some parameters to the specified extension.

| Param | Description |
|---|---|
| const char * extension | Extension name. |
| SmartScriptTable params | Parameters to be set for the extension. |

docs: y · retail: confirmed (binary, vanilla×2)

### SetForcedLookDir

```lua
Actor.SetForcedLookDir()
```

C++: `int SetForcedLookDir (IFunctionHandler * pH , CScriptVector dir )`

docs: y · retail: unconfirmed

### SetForcedLookObjectId

```lua
Actor.SetForcedLookObjectId()
```

C++: `int SetForcedLookObjectId (IFunctionHandler * pH , ScriptHandle objectId )`

docs: y · retail: confirmed (binary)

### SetHealth

```lua
Actor.SetHealth(float health)
```

OBSOLETE: use soul.SetHealth().

| Param | Description |
|---|---|
| float health | Health amount. |

docs: y · retail: confirmed (mod×12)

### SetLookIK

```lua
Actor.SetLookIK(true)
```

C++: `virtual int SetLookIK (IFunctionHandler * pH , bool )`

Enable/disable look IK for this actor

docs: y · retail: unconfirmed

### SetMaxHealth

```lua
Actor.SetMaxHealth(float health)
```

Sets the maximum of health.

| Param | Description |
|---|---|
| float health | Health amount. |

docs: y · retail: confirmed (mod×8)

### SetMovementControlledByAnimation

```lua
Actor.SetMovementControlledByAnimation(bool enable)
```

Enables or disables animation controlled movement for an actor.

| Param | Description |
|---|---|
| bool enable | enable or disable animation controlled movement |

docs: y · retail: unconfirmed

### SetMovementRestriction

```lua
Actor.SetMovementRestriction(true, true)
```

C++: `virtual int SetMovementRestriction (IFunctionHandler * pH , bool , bool )`

Sets movement restriction. First param is bAllowSprint and second param is bAllowRun.

docs: y · retail: confirmed (vanilla×2)

### SetMovementTarget

```lua
Actor.SetMovementTarget(Vec3 pos, Vec3 target, Vec3 up, float speed)
```

Sets the target movement.

| Param | Description |
|---|---|
| Vec3 pos | Position. |
| Vec3 target | Target position |
| Vec3 up | Up vector. |
| float speed | Speed of the movement. |

docs: y · retail: unconfirmed

### SetParams

```lua
Actor.SetParams()
```

C++: `virtual int SetParams (IFunctionHandler * pH )`

Sets the Actor parameters passing the parameter table to the Actor.

set the actor params, pass the params table to the actor

docs: y · retail: unconfirmed

### SetPhysicalizationProfile

```lua
Actor.SetPhysicalizationProfile(const char *profile)
```

Sets the physicalization profile.

| Param | Description |
|---|---|
| const char * profile | Profile for the physicalization. |

docs: y · retail: unconfirmed

### SetSearchBeam

```lua
Actor.SetSearchBeam(Vec3 dir)
```

Sets the search beam.

| Param | Description |
|---|---|
| Vec3 dir | Beam direction. |

docs: y · retail: unconfirmed

### SetSpectatorMode

```lua
Actor.SetSpectatorMode(int mode, ScriptHandle targetId)
```

Sets the specified spectator mode.

| Param | Description |
|---|---|
| int mode | Spectator mode. |
| ScriptHandle targetId | Identifier of the spectator. |

docs: y · retail: unconfirmed

### SetSpeedMultiplier

```lua
Actor.SetSpeedMultiplier(float)
```

C++: `virtual int SetSpeedMultiplier (IFunctionHandler * pH , float )`

Value multiplies absolute speed in all stances.

docs: y · retail: unconfirmed

### SetStats

```lua
Actor.SetStats()
```

C++: `virtual int SetStats (IFunctionHandler * pH )`

Sets somes tats for the actor.

set some status of the actor

docs: y · retail: unconfirmed

### SetVariationInput

```lua
Actor.SetVariationInput(const char *name, const char* value)
```

Sets variation input value.

| Param | Description |
|---|---|
| const char * name | Variation input name. |
| char const* value | value to set to the selected variation input |

docs: y · retail: unconfirmed

### SetViewAngleOffset

```lua
Actor.SetViewAngleOffset()
```

C++: `virtual int SetViewAngleOffset (IFunctionHandler * pH )`

Sets the offset angle for the view.

docs: y · retail: unconfirmed

### SetViewLimits

```lua
Actor.SetViewLimits(IFunctionHandler *pH,Vec3 dir,float rangeH,float rangeV)
```

Sets the limit of the view.

| Param | Description |
|---|---|
| Vec3 dir | View direction. |
| float rangeH | Height range. |
| float rangeV | Vertical range. |

docs: y · retail: unconfirmed

### SetViewShake

```lua
Actor.SetViewShake(Ang3 shakeAngle, Vec3 shakeShift, float duration, float frequency, float randomness)
```

Sets the shake movement for the view.

| Param | Description |
|---|---|
| Ang3 shakeAngle | Angle of the shake movement. |
| Vec3 shakeShift | Shift of the shake movement. |
| float duration | Duration of the shake movement. |
| float frequency | Frequency of the shake movement. |
| float randomness | Randomness amount. |

docs: y · retail: confirmed (vanilla×1)

### SimulateOnAction

```lua
Actor.SimulateOnAction(IFunctionHandler *pH,const char *action,int mode,float value)
```

| Param | Description |
|---|---|
| const char * action | Action name. |
| int mode | Action activation mode. |
| float value | Value of the action. |

docs: y · retail: unconfirmed

### StandUp

```lua
Actor.StandUp()
```

C++: `virtual int StandUp (IFunctionHandler * pH )`

Makes the Actor standing up.

docs: y · retail: unconfirmed

### StartFollow

```lua
Actor.StartFollow(npcEntity)
```

C++: `virtual int StartFollow (IFunctionHandler* pH )`

Start following the NPC.

docs: y · retail: confirmed (vanilla×1)

### StartInteractiveActionByName

```lua
Actor.StartInteractiveActionByName("ActionName", objectId, true, 1.0)
```

Starts interactive action.

| Param | Description |
|---|---|
| updateVisibility | force animation update |
| animationSpeed | animation speed default is 1 |

docs: y · retail: confirmed (vanilla×1)

### StopTimeWarp

```lua
Actor.StopTimeWarp()
```

C++: `virtual int StopTimeWarp (IFunctionHandler * pH )`

Stops time warp effect

docs: y · retail: unconfirmed

### TrackViewControlled

```lua
Actor.TrackViewControlled(int characterSlot)
```

Checks if the track view is controlled.

| Param | Description |
|---|---|
| int characterSlot | Slot of the character. |

docs: y · retail: unconfirmed

### UnequipInventoryItem

```lua
Actor.UnequipInventoryItem(ScriptHandle itemId)
```

Unequips item from inventory

| Param | Description |
|---|---|
| ScriptHandle itemId | Identifier for the item |

docs: y · retail: confirmed (mod×2)

### VectorToLocal

```lua
Actor.VectorToLocal()
```

C++: `virtual int VectorToLocal (IFunctionHandler * pH )`

Converts a vector to the local coordinates system.

docs: y · retail: confirmed (binary, vanilla×2)

### WarpTime

```lua
Actor.WarpTime(float wantedSpeed, float duration)
```

Time effects ============================================= Syntax: Actor.WarpTime(float wantedSpeed, float duration)

Slowdown/speedup actor animation for given time period

| Param | Description |
|---|---|
| float wantedSpeed | target speed of actor animation |
| float duration | duration of the time effect |

docs: y · retail: unconfirmed

### WashDirtAndBlood

```lua
actor.WashDirtAndBlood(1)
```

Call when somebody washes himself in the game. Cleans all actor clothes with 0 - 100% cleaning efficiency

| Param | Description |
|---|---|
| float maxCleaningEffect | , 1 - actor be totally clean, 0 - no cleaning at all |

docs: y · retail: confirmed (binary)

### WashItems

```lua
actor.WashItems(1)
```

Wash all actor items in inventory or his horse

| Param | Description |
|---|---|
| float maxCleaningEffect | , 1 - totally clean, 0 - no cleaning at all |

docs: y · retail: confirmed (binary)

## Undocumented (present in retail, not in official docs)

### Butcher

`Actor.Butcher(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, vanilla×1)

### CreateActor

`Actor.CreateActor(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/GameRules/SinglePlayer.lua`))
