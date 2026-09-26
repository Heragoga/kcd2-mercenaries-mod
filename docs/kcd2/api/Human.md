# Human

C++ class(es): `C_ScriptBindHuman`, `C_ScriptBindPlayer`, `C_ScriptBind_Human`
Reached from Lua as `Human.FunctionName(...)`.
87 documented function(s); 0 additional undocumented function(s) found in retail/runtime.

## Functions

### AddSoAction

```lua
Human.AddSoAction(wuid, type, name, interaction, enabled = true, disabled_reason = "")
```

C++: `virtual int AddSoAction (IFunctionHandler * pH , framework::T_WUIDScriptType wuid , const char * type , const char * name , int interaction )`

Adds hint for given SO. Be careful, because of only one of them can be set up in at a same time.

docs: y · retail: unconfirmed

### AttachEntityToHand

```lua
Human.AttachEntityToHand(id, hand)
```

Attaches entity to human's hand

| Param | Description |
|---|---|
| uint hand | 0 = left, 1 = right (use HS_LEFT or HS_RIGHT) |

docs: y · retail: unconfirmed

### AttachTo

```lua
Human.AttachTo()
```

C++: `virtual void AttachTo (C_Human * pHuman )`

docs: y · retail: unconfirmed

### AverageActorSuperFraction

```lua
Human.AverageActorSuperFraction()
```

C++: `virtual int AverageActorSuperFraction (IFunctionHandler* pH )`

Returns average super fraction from all cloths for this human.

docs: y · retail: unconfirmed

### CanBeRobbed

```lua
Human.CanBeRobbed(EntityId victimEntityId)
```

C++: `virtual int CanBeRobbed (IFunctionHandler * pH )`

Find out if actor can be robbed

docs: y · retail: confirmed (vanilla×1)

### CanInteractWith

```lua
Human.CanInteractWith()
```

C++: `virtual int CanInteractWith (IFunctionHandler * pH , ScriptHandle entityId )`

Checks if entity is close enough to interact with another one. @deprecated use Actor.CanInteractWith

docs: y · retail: confirmed (vanilla×4, mod×2)

### CanTalk

```lua
Human.CanTalk()
```

C++: `virtual int CanTalk (IFunctionHandler * pH )`

Checks if this human have something to say. @deprecated use Actor.CanTalk

docs: y · retail: confirmed (vanilla×3)

### CanUseLadder

```lua
Human.CanUseLadder(ladderEntity,useOnlyFromFront)
```

C++: `virtual int CanUseLadder (IFunctionHandler * pH , ScriptHandle ladderId , float ladderHeight , bool useOnlyFromFront )`

Return 0/1 depending if the ladder can be climbed on

docs: y · retail: confirmed (vanilla×2)

### CheckInventoryRestrictions

```lua
Human.CheckInventoryRestrictions(const char *itemClassName)
```

Checks if there is any restriction in the inventory for the specific item class.

| Param | Description |
|---|---|
| const char * itemClassName | Name of the item class. |

docs: y · retail: unconfirmed

### CheckVirtualInventoryRestrictions

```lua
Human.CheckVirtualInventoryRestrictions(SmartScriptTable inventory, const char *itemClassName)
```

Checks if there is any restriction in the virtual inventory for the specific item class.

| Param | Description |
|---|---|
| SmartScriptTable inventory | Inventory. |
| const char * itemClassName | Item class name. |

docs: y · retail: unconfirmed

### CookFood

```lua
Human.CookFood()
```

C++: `virtual int CookFood (IFunctionHandler * pH , framework::T_WUIDScriptType itemId )`

Items

docs: y · retail: unconfirmed

### CycleWeapon

```lua
Human.CycleWeapon()
```

C++: `virtual int CycleWeapon (IFunctionHandler * pH )`

Cycle between primary and secondary weapon set

docs: y · retail: confirmed (vanilla×1)

### DetachFromHand

```lua
Human.DetachFromHand(hand)
```

C++: `virtual int DetachFromHand (IFunctionHandler * pH , uint hand )`

removes item from human's hand - drops if not equip or holster otherwise

docs: y · retail: unconfirmed

### Dismount

```lua
Human.Dismount()
```

C++: `virtual int Dismount (IFunctionHandler * pH )`

Mounts selected horse.

docs: y · retail: unconfirmed

### DoBonding

```lua
Human.DoBonding(EntityId horseId)
```

C++: `virtual int DoBonding (IFunctionHandler* pH , ScriptHandle horseId )`

Bond selected horse.

docs: y · retail: confirmed (vanilla×1)

### DoStepOnGrindstone

```lua
Human.DoStepOnGrindstone()
```

C++: `virtual int DoStepOnGrindstone (IFunctionHandler * pH )`

Perform single step on grindstone, use SetWheelSpeed() for constant speed and automatic pedalling.

docs: y · retail: unconfirmed

### DrawFromInventory

```lua
Human.DrawFromInventory(itemId, hand, animate)
```

Spawn item from inventory to human hands and animate drawing it from somewhere

| Param | Description |
|---|---|
| framework | :T_WUIDScriptType itemId Identifier for the item |
| int hand | to which hand |
| bool bAnimate | draw with animation |

docs: y · retail: unconfirmed

### DrawItemFromInventory

```lua
Human.DrawItemFromInventory(itemId, hand, animate)
```

Spawn item from inventory to human hands and animate drawing it from somewhere

| Param | Description |
|---|---|
| ScriptHandle itemId | Identifier for the item |
| int hand | to which hand |
| bool bAnimate | draw with animation |

docs: y · retail: unconfirmed

### DrawPrimaryWeapon

```lua
Human.DrawPrimaryWeapon()
```

C++: `virtual int DrawPrimaryWeapon (IFunctionHandler * pH )`

Draw primary weapon

docs: y · retail: confirmed (vanilla×1)

### DrawPrimaryWeaponEx

```lua
Human.DrawPrimaryWeaponEx(const char* animInput, bool force)
```

Draw primary weapon with animation input and possibility to force the animation, weapon must be equipped

| Param | Description |
|---|---|
| const char* animInput | animation to be used for drawing, if empty, draw is performed without animation |
| bool force | will force animation even the weapon is already in hand |

docs: y · retail: unconfirmed

### DrawPrimaryWeaponWithAnim

```lua
Human.DrawPrimaryWeaponWithAnim(const char* animInput)
```

Draw primary weapon with animation input

| Param | Description |
|---|---|
| const char* animInput | animation to be used for drawing |

docs: y · retail: unconfirmed

### DrawSecondaryWeapon

```lua
Human.DrawSecondaryWeapon()
```

C++: `virtual int DrawSecondaryWeapon (IFunctionHandler * pH )`

Draw secondary weapon

docs: y · retail: unconfirmed

### DrawSecondaryWeaponEx

```lua
Human.DrawSecondaryWeaponEx(const char* animInput, bool force)
```

Draw secondary weapon with animation input and possibility to force the animation, weapon must be equipped

| Param | Description |
|---|---|
| const char* animInput | animation to be used for drawing, if empty, draw is performed without animation |
| bool force | will force animation even the weapon is already in hand |

docs: y · retail: unconfirmed

### DrawWeapon

```lua
Human.DrawWeapon()
```

C++: `virtual int DrawWeapon (IFunctionHandler * pH )`

Draw active weapon set

docs: y · retail: confirmed (vanilla×7, mod×4)

### DropItem

```lua
Human.DropItem(ScriptHandle itemId)
```

Drops the specified item.

| Param | Description |
|---|---|
| ScriptHandle itemId | Identifier of the item to be dropped. |

docs: y · retail: unconfirmed

### DryHerb

```lua
Human.DryHerb(id, amount)
```

Dry herbs functionality.

| Param | Description |
|---|---|
| int amount | negative value means whole stack |

docs: y · retail: unconfirmed

### EquipClothingPreset

```lua
Human.EquipClothingPreset(clothingPresetId)
```

OBSOLETE - use C_ScriptBind_Actor::EquipClothingPreset Syntax: Human.EquipClothingPreset( "46ea38bb-0be7-ca10-a8ac-d526056c04b3" )

Clothing preset is equipped to actor. Dirt level of actor is used for new items. Health of equipment slots is ignored.

| Param | Description |
|---|---|
| clothingPresetId | Identifier for the clothing preset |

docs: y · retail: confirmed (vanilla×11, mod×16)

### EquipInventoryItem

```lua
Human.EquipInventoryItem(ScriptHandle itemId)
```

Equips item from inventory

| Param | Description |
|---|---|
| int itemId | Identifier for the item |

docs: y · retail: confirmed (vanilla×19, mod×3)

### EquipItemInSlot

```lua
Human.EquipItemInSlot(ScriptHandle itemId)
```

Equips item from selected inventory slot

| Param | Description |
|---|---|
| int slotId | Identifier for the slot |

docs: y · retail: confirmed (vanilla×1)

### GetDialogRequestSourceName

```lua
Human.GetDialogRequestSourceName()
```

C++: `virtual int GetDialogRequestSourceName (IFunctionHandler* pH )`

Returns name of entity which initiated dialog request with this human.

docs: y · retail: unconfirmed

### GetHorse

```lua
Human.GetHorse()
```

C++: `virtual int GetHorse (IFunctionHandler * pH )`

Returns WUID of a horse the human is mounted on, otherwise returns invalid WUID.

docs: y · retail: confirmed (mod×6)

### GetHuman

```lua
Human.GetHuman()
```

C++: `C_Human * GetHuman (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### GetInitialClothingPreset

```lua
Human.GetInitialClothingPreset()
```

C++: `virtual int GetInitialClothingPreset (IFunctionHandler * pH )`

OBSOLETE - use C_ScriptBind_Actor::GetInitialClothingPreset Syntax: Human.GetInitialClothingPreset()

docs: y · retail: confirmed (vanilla×3, mod×1)

### GetItemInHand

```lua
Human.GetItemInHand()
```

C++: `virtual int GetItemInHand (IFunctionHandler * pH , int handId )`

docs: y · retail: confirmed (mod×2)

### GetTorchLightArchetype

```lua
Human.GetTorchLightArchetype()
```

C++: `virtual int GetTorchLightArchetype (IFunctionHandler* pH )`

Gets the light archetype to use for torches for this human (can vary based on script contexts, is/isnt't player)

docs: y · retail: confirmed (vanilla×1)

### GetTotalQuality

```lua
Human.GetTotalQuality()
```

C++: `virtual int GetTotalQuality (IFunctionHandler * pH )`

Get current health of the weapon. Range . 1 is best.

docs: y · retail: unconfirmed

### GetWheelSpeed

```lua
Human.GetWheelSpeed()
```

C++: `virtual int GetWheelSpeed (IFunctionHandler * pH )`

Returns current wheel speed of the grindstone on which is sharpening performed. Range .

docs: y · retail: unconfirmed

### GrabOnLadder

```lua
Human.GrabOnLadder()
```

C++: `virtual int GrabOnLadder (IFunctionHandler * pH , ScriptHandle ladderId )`

Grabs actor on a ladder

docs: y · retail: confirmed (vanilla×1)

### HolsterItem

```lua
Human.HolsterItem(bool holster)
```

Puts back/extracts the current weapon in the holster.

| Param | Description |
|---|---|
| bool holster | true if the weapon has to be put back in the holster, false otherwise. |

docs: y · retail: unconfirmed

### HolsterPrimaryWeapon

```lua
Human.HolsterPrimaryWeapon()
```

C++: `virtual int HolsterPrimaryWeapon (IFunctionHandler * pH )`

Holster primary weapon

docs: y · retail: unconfirmed

### HolsterSecondaryWeapon

```lua
Human.HolsterSecondaryWeapon()
```

C++: `virtual int HolsterSecondaryWeapon (IFunctionHandler * pH )`

Holster secondary weapon

docs: y · retail: unconfirmed

### HolsterToInventory

```lua
Human.HolsterToInventory(hand, animate)
```

Despawn inventory item and animate holstering it to somewhere

| Param | Description |
|---|---|
| int hand | Identifier for the hand |
| bool bAnimate | draw with animation |

docs: y · retail: unconfirmed

### HolsterWeapon

```lua
Human.HolsterWeapon()
```

C++: `virtual int HolsterWeapon (IFunctionHandler * pH )`

Holster active weapon set

docs: y · retail: unconfirmed

### InterruptDialog

```lua
Human.InterruptDialog()
```

C++: `virtual int InterruptDialog (IFunctionHandler* pH )`

Interrupts an ongoing dialog.

docs: y · retail: unconfirmed

### InterruptDialogs

```lua
Human.InterruptDialogs()
```

C++: `virtual int InterruptDialogs (IFunctionHandler* pH )`

Interrupts all ongoing dialogs.

docs: y · retail: unconfirmed

### IsInDialog

```lua
Human.IsInDialog()
```

C++: `virtual int IsInDialog (IFunctionHandler * pH )`

Checks if this human is currently in dialogue/monologue.

docs: y · retail: confirmed (mod×2)

### IsMounted

```lua
Human.IsMounted()
```

C++: `virtual int IsMounted (IFunctionHandler * pH )`

Returns if a human is mounted on a horse

docs: y · retail: confirmed (binary, vanilla×1, mod×5)

### IsOnLadder

```lua
Human.IsOnLadder()
```

C++: `virtual int IsOnLadder (IFunctionHandler * pH )`

Returns 0/1 depending on if actor is already grabbed on a ladder

docs: y · retail: unconfirmed

### IsPickpocketing

```lua
Human.IsPickpocketing()
```

C++: `virtual int IsPickpocketing (IFunctionHandler * pH )`

True if human is pickpocketing

docs: y · retail: confirmed (vanilla×2)

### IsSharpeningActive

```lua
Human.IsSharpeningActive()
```

C++: `virtual int IsSharpeningActive (IFunctionHandler * pH )`

Returns sharpening state. True after StartSharpening and false after StopSharpening.

docs: y · retail: unconfirmed

### IsWeaponDrawn

```lua
Human.IsWeaponDrawn()
```

C++: `virtual int IsWeaponDrawn (IFunctionHandler * pH )`

return true if human have any weapon set active

docs: y · retail: confirmed (mod×21)

### Mount

```lua
Human.Mount(EntityId horseId)
```

C++: `virtual int ForceMount (IFunctionHandler * pH , ScriptHandle horseId )`

Mounts selected horse.

docs: y · retail: confirmed (vanilla×1, mod×1)

### MoveToWorstZone

```lua
Human.MoveToWorstZone()
```

C++: `virtual int MoveToWorstZone (IFunctionHandler * pH )`

Moves to worst sharpened zone or stay on same position, if weapon is sharpened evenly.

docs: y · retail: unconfirmed

### PickUpItem

```lua
Human.PickUpItem(itemId, toHand)
```

Picks up an item

| Param | Description |
|---|---|
| bool toHand | if true item is not placed in inventory but is kept in hands |
| itemId | Identifier for the item to be picked up. |

docs: y · retail: unconfirmed

### Place

```lua
Human.Place(itemId, entityId, fromHand)
```

Places an item

| Param | Description |
|---|---|
| ScriptHandle itemId | Identifier of item to be placed |
| ScriptHandle entityId | entity defines final position and rotation where item will be placed |
| fromhand | if true item currently held in hand will be placed otherwise item will be grabbed from inventory |

docs: y · retail: unconfirmed

### PlayAnim

```lua
Human.PlayAnim()
```

C++: `virtual int PlayAnim (IFunctionHandler * pH , char const * fragmentName , char const * tags )`

docs: y · retail: unconfirmed

### PrepareFood

```lua
Human.PrepareFood(id, type, amount)
```

Cooking functionality.

| Param | Description |
|---|---|
| int amount | negative value means whole stack |
| type | use PFT_COOK, PFT_SMOKE, PFT_DRY |

docs: y · retail: unconfirmed

### PrepareForDialog

```lua
Human.PrepareForDialog()
```

C++: `virtual int PrepareForDialog (IFunctionHandler* pH )`

Notifies dialog manager that this human is preparing for dialog. This is a response to signal dialog request start which handled by AI.

docs: y · retail: unconfirmed

### ReadyForDialog

```lua
Human.ReadyForDialog(false)
```

Notifies dialog manager that this human is ready for dialog. This is a response to signal dialog request start which handled by AI.

| Param | Description |
|---|---|
| bool bForce | Skip request analyze |

docs: y · retail: unconfirmed

### ReadyForDialogWithRole

```lua
Human.ReadyForDialogWithRole(false, "kovar")
```

Notifies dialog manager that this human is ready for dialog. This is a response to signal dialog request start which handled by AI.

| Param | Description |
|---|---|
| bool bForce | Skip request analyze |
| role | list of meta roles used for source soul in this dialog |

docs: y · retail: unconfirmed

### ReadyForDialogWithTwins

```lua
Human.ReadyForDialogWithTwins(false)
```

Notifies dialog manager that this human is not ready for dialog so twins should be used instead. This is a response to signal dialog request start which handled by AI.

| Param | Description |
|---|---|
| bool bForce | Skip request analyze |

docs: y · retail: unconfirmed

### RequestDialog

```lua
Human.RequestDialog(entity, roles, bOnce)
```

Requests dialog with this human. roles - meta roles override for source soul Dialog does not start immediately but it only notifies targeted entity that somebody wants to interact with it. If target entity does not respond in proper time the request is canceled automatically. Returns true in case request was successfully accepted by dialog manager. In some cases it can return false which means that dialog was refused.

| Param | Description |
|---|---|
| entity | entity id to start dialog with |
| roles | string with roles overrides |
| bOnce | true/false if dialog should be played just once and automatically end after that |
| bUseTwins | true/false if twis are requested |

docs: y · retail: confirmed (vanilla×2)

### RequestItemExchange

```lua
Human.RequestItemExchange(entity)
```

C++: `virtual int RequestItemExchange (IFunctionHandler * pH )`

Requests loot from this human.

docs: y · retail: confirmed (vanilla×3)

### RequestPickpocketing

```lua
Human.RequestPickpocketing(EntityId victimEntityId, mode)
```

Start stealing from victim

| Param | Description |
|---|---|
| ScriptHandle victimEntityId | entity to grab |
| int mode | 0 - basic, 1 - contact |

docs: y · retail: confirmed (vanilla×1)

### SelectItem

```lua
Human.SelectItem(ScriptHandle itemId)
```

Selects the specified item.

| Param | Description |
|---|---|
| ScriptHandle itemId | Identifier for the item. |

docs: y · retail: unconfirmed

### SelectItemByName

```lua
Human.SelectItemByName(const char *name)
```

Selects an item using its name.

| Param | Description |
|---|---|
| const char * name | Item name. |

docs: y · retail: unconfirmed

### SetAnimMotionParam

```lua
Human.SetAnimMotionParam()
```

C++: `virtual int SetAnimMotionParam (IFunctionHandler * pH , int paramId , float val )`

docs: y · retail: unconfirmed

### SetGrindstone

```lua
Human.SetGrindstone(EntityId entityId)
```

Sets which grindstone will be used for sharpening.

| Param | Description |
|---|---|
| ScriptHandle entityId | EntityId of selected grindstone |

docs: y · retail: unconfirmed

### SetOptimalRotation

```lua
Human.SetOptimalRotation()
```

C++: `virtual int SetOptimalRotation (IFunctionHandler * pH )`

Sets optimal rotation on which weapon is sharpened correctly.

docs: y · retail: unconfirmed

### SetSharpeningPosition

```lua
Human.SetSharpeningPosition(float value)
```

Weapon will slowly move to desired position.

| Param | Description |
|---|---|
| float value | position, range from left to right |

docs: y · retail: unconfirmed

### SetSharpeningPressure

```lua
Human.SetSharpeningPressure(float value)
```

Set sharpening pressure, more pressure requires more energy but increases sharpening efficiency.

| Param | Description |
|---|---|
| float value | pressure, range |

docs: y · retail: unconfirmed

### SetSharpeningRotation

```lua
Human.SetSharpeningRotation(float value)
```

Weapon will slowly move to desired rotation, use SetOptimalRotation() to sharpen weapon correctly

| Param | Description |
|---|---|
| float value | position, range from left to right |

docs: y · retail: unconfirmed

### SetWheelSpeed

```lua
Human.SetWheelSpeed(float value)
```

Sets speed of grindstone wheel on which is sharpening performed.

| Param | Description |
|---|---|
| float value | speed of the grindstone wheel, range |

docs: y · retail: unconfirmed

### StartBookTranscription

```lua
Human.StartBookTranscription()
```

C++: `virtual int StartBookTranscription (IFunctionHandler * pH , ScriptHandle bookId )`

docs: y · retail: confirmed (vanilla×1)

### StartBuilding

```lua
Human.StartBuilding()
```

C++: `virtual int StartBuilding (IFunctionHandler * pH , ScriptHandle bookId )`

This is StartBuilding, a member of class C_ScriptBindHuman.

docs: y · retail: unconfirmed

### StartReading

```lua
Human.StartReading()
```

C++: `virtual int StartReading (IFunctionHandler * pH , ScriptHandle bookId )`

docs: y · retail: unconfirmed

### StartSharpening

```lua
Human.StartSharpening(EntityId grindstoneId)
```

Starts sharpening weapon in primary slot on selected grindstone.

| Param | Description |
|---|---|
| ScriptHandle grindstoneId | entity id of grindstone on which human will sharpen |

docs: y · retail: unconfirmed

### StartSharpeningWeapon

```lua
Human.StartSharpeningWeapon(EntityId grindstoneId, int itemId)
```

Starts sharpening weapon in selected inventory item on selected grindstone.

| Param | Description |
|---|---|
| ScriptHandle grindstoneId | entity id of grindstone on which human will sharpen |
| framework | :T_WUIDScriptType itemId inventory index of weapon for sharpening |

docs: y · retail: unconfirmed

### StopAnim

```lua
Human.StopAnim()
```

C++: `virtual int StopAnim (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### StopSharpening

```lua
Human.StopSharpening()
```

C++: `virtual int StopSharpening (IFunctionHandler * pH )`

Stops sharpening, reseting state of the grindstone and setting new health to the weapon according to the results of sharpening.

docs: y · retail: unconfirmed

### Talk

```lua
Human.Talk()
```

C++: `virtual int Talk (IFunctionHandler * pH )`

Start dialog with this human.

docs: y · retail: unconfirmed

### TogglePrimaryWeapon

```lua
Human.TogglePrimaryWeapon()
```

C++: `virtual int TogglePrimaryWeapon (IFunctionHandler * pH )`

Toggle primary weapon

docs: y · retail: unconfirmed

### ToggleSecondaryWeapon

```lua
Human.ToggleSecondaryWeapon()
```

C++: `virtual int ToggleSecondaryWeapon (IFunctionHandler * pH )`

Toggle secondary weapon

docs: y · retail: unconfirmed

### ToggleWeapon

```lua
Human.ToggleWeapon()
```

C++: `virtual int ToggleWeapon (IFunctionHandler * pH )`

Toggle active weapon set

docs: y · retail: confirmed (vanilla×1)

### ToggleWeaponSet

```lua
Human.ToggleWeaponSet(set)
```

C++: `virtual int ToggleWeaponSet (IFunctionHandler * pH , int weaponsetId )`

Toggle selected weapon set if available.

docs: y · retail: confirmed (vanilla×4)

### UnequipInventoryItem

```lua
Human.UnequipInventoryItem(ScriptHandle itemId)
```

Unequips item from inventory

| Param | Description |
|---|---|
| int itemId | Identifier for the item |

docs: y · retail: confirmed (mod×2)

### UnequipItemInSlot

```lua
Human.UnequipItemInSlot(ScriptHandle itemId)
```

Unequips item from selected inventory slot

| Param | Description |
|---|---|
| int slotId | Identifier for the slot |

docs: y · retail: confirmed (mod×2)
