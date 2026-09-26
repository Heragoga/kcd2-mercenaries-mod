# Entity

C++ class(es): `CScriptBindEntity`, `CScriptBind_Entity`
Reached from Lua as `Entity.FunctionName(...)`.
307 documented function(s); 6 additional undocumented function(s) found in retail/runtime.

## Functions

### Activate

```lua
Entity.Activate(bActivate)
```

Activates or deactivates entity. ! This calls ignores update policy and forces entity to activate or deactivate ! All active entities will be updated every frame, having too many active entities can affect performance. !

| Param | Description |
|---|---|
| bActivate | if true entity will become active, is false will deactivate and stop being updated every frame.</param |

docs: y · retail: confirmed (binary, runtime dump, vanilla×43, mod×4)

### ActivateOutput

```lua
Entity.ActivateOutput()
```

C++: `int ActivateOutput (IFunctionHandler* pH )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×146)

### ActivatePlayerPhysics

```lua
Entity.ActivatePlayerPhysics(bEnable)
```

C++: `int ActivatePlayerPhysics (IFunctionHandler * pH , bool bEnable )`

docs: y · retail: confirmed (binary, runtime dump)

### AddConstraint

```lua
Entity.AddConstraint()
```

C++: `int AddConstraint (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### AddImpulse

```lua
Entity.AddImpulse(ipart, position, direction, linearImpulse, linearImpulseScale, angularAxis, angularImpulse, massScale)
```

Apply an impulse to the entity. ! At least four parameters need to be provided for a linear impulse. ! For an additional angular impulse, at least seven parameters need to be provided. !

| Param | Description |
|---|---|
| ipart | The index of the part that receives the impulse. |
| position | The point (in world coordinates) where the impulse is applied. Set this to (0, 0, 0) to ignore it. |
| direction | The direction in which the impulse is applied. |
| linearImpulse | The force of the linear impulse. |
| linearImpulseScale | Scaling of the linear impulse. (Default: 1.0) |
| angularAxis | The axis on which the angular impulse is applied. |
| angularImpulse | The force of the the angular impulse. |
| massScale | Mass scaling of the angular impulse. (Default: 1.0) |

docs: y · retail: confirmed (binary, runtime dump, vanilla×12)

### AttachChild

```lua
Entity.AttachChild(childEntityId, flags)
```

C++: `int AttachChild (IFunctionHandler * pH , ScriptHandle childEntityId , int flags )`

docs: y · retail: confirmed (binary, runtime dump, mod×2)

### AttachSurfaceEffect

```lua
Entity.AttachSurfaceEffect(nSlot, effect, countPerUnit, form, typ, countScale, sizeScale)
```

C++: `int AttachSurfaceEffect (IFunctionHandler* pH , int nSlot , const char * effect , bool countPerUnit , const char * form , const char * typ , float countScale , float sizeScale )`

docs: y · retail: confirmed (runtime dump)

### AuxAudioProxiesMoveWithEntity

```lua
Entity.AuxAudioProxiesMoveWithEntity(bCanMoveWithEntity)
```

Set whether AuxAudioProxies should move with the entity or not.

| Param | Description |
|---|---|
| bool const bCanMoveWithEntity | boolean parameter to enable or disable |

Returns: nil

docs: y · retail: confirmed (binary, runtime dump, vanilla×2)

### AwakeCharacterPhysics

```lua
Entity.AwakeCharacterPhysics(nSlot, sRootBoneName, nAwake)
```

C++: `int AwakeCharacterPhysics (IFunctionHandler * pH , int nSlot , const char * sRootBoneName , int nAwake )`

docs: y · retail: confirmed (binary, runtime dump)

### AwakeEnvironment

```lua
Entity.AwakeEnvironment()
```

C++: `int AwakeEnvironment (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### AwakePhysics

```lua
Entity.AwakePhysics(nAwake)
```

C++: `int AwakePhysics (IFunctionHandler * pH , int nAwake )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×27, mod×2)

### BreakToPieces

```lua
Entity.BreakToPieces()
```

C++: `int BreakToPieces (IFunctionHandler* pH , int nSlot , int nPiecesSlot , float fExplodeImp , Vec3 vHitPt , Vec3 vHitImp , float fLifeTime , bool bSurfaceEffects )`

Breaks static geometry in slot 0 into sub objects and spawn them as particles or entities.

docs: y · retail: confirmed (runtime dump, vanilla×1)

### CalcWorldAnglesFromRelativeDir

```lua
Entity.CalcWorldAnglesFromRelativeDir()
```

C++: `int CalcWorldAnglesFromRelativeDir (IFunctionHandler * pH , Vec3 dir )`

docs: y · retail: confirmed (binary, runtime dump)

### CancelSubpipe

```lua
Entity.CancelSubpipe()
```

C++: `int CancelSubpipe (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### ChangeAttachmentMaterial

```lua
Entity.ChangeAttachmentMaterial()
```

C++: `int ChangeAttachmentMaterial (IFunctionHandler * pH , const char * attachmentName , const char * materialName )`

syntax: Entity.ChangeAttachmentMaterial(attachmentName, materialName)

docs: y · retail: confirmed (runtime dump)

### CharacterUpdateAlways

```lua
Entity.CharacterUpdateAlways(characterSlot, updateAlways)
```

C++: `int CharacterUpdateAlways (IFunctionHandler * pH , int characterSlot , bool updateAlways )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### CharacterUpdateOnRender

```lua
Entity.CharacterUpdateOnRender(characterSlot, bUpdateOnRender)
```

C++: `int CharacterUpdateOnRender (IFunctionHandler * pH , int characterSlot , bool bUpdateOnRender )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×3)

### CheckCollisions

```lua
Entity.CheckCollisions()
```

C++: `int CheckCollisions (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### CloneMaterial

```lua
Entity.CloneMaterial(nSlotId, sSubMaterialName)
```

Replace material on the slot with a cloned version of the material. ! Cloned material can be freely changed uniquely for this entity. !

| Param | Description |
|---|---|
| nSlotId | On which slot to clone material. |
| sSubMaterialName | if non empty string only this specific sub-material is cloned. |

docs: y · retail: confirmed (binary, runtime dump)

### CopySlotTM

```lua
Entity.CopySlotTM(destSlot, srcSlot, includeTranslation)
```

Copies the TM (Transformation Matrix) of the slot.

| Param | Description |
|---|---|
| int destSlot | Destination slot identifier. |
| int srcSlot | Source slot identifier. |
| bool includeTranslation | True to include the translation, false otherwise. |

docs: y · retail: confirmed (binary, runtime dump)

### CountLinks

```lua
Entity.CountLinks()
```

C++: `int CountLinks (IFunctionHandler* pH )`

Counts all outgoing links of the entity. !

! ! ! !

Returns: Number of outgoing links.

docs: y · retail: confirmed (binary, runtime dump, vanilla×7, mod×13)

### CreateAuxAudioProxy

```lua
Entity.CreateAuxAudioProxy()
```

C++: `int CreateAuxAudioProxy (IFunctionHandler* pH )`

Creates an additional AudioProxy managed by the EntityAudioProxy. ! The created AuxAudioProxy will move and rotate with the parent EntityAudioProxy. !

Returns: Returns the ID of the additionally created AudioProxy.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### CreateBBoxProxy

```lua
Entity.CreateBBoxProxy()
```

C++: `int CreateBBoxProxy (IFunctionHandler* pH )`

Create a proxy local bounding box object for the entity, this is explicit bbox for this entity.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### CreateBoneAttachment

```lua
Entity.CreateBoneAttachment()
```

C++: `int CreateBoneAttachment (IFunctionHandler * pH , int characterSlot , const char * boneName , const char * attachmentName )`

syntax: Entity.CreateBoneAttachment( characterSlot, boneName, attachmentName )

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### CreateCameraProxy

```lua
Entity.CreateCameraProxy()
```

C++: `int CreateCameraProxy (IFunctionHandler* pH )`

Create a proxy camera object for the entity, allows entity to serve as camera source for material assigned on the entity.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### CreateDRSProxy

```lua
Entity.CreateDRSProxy()
```

C++: `int CreateDRSProxy (IFunctionHandler* pH )`

Creates a Dynamic Response System Proxy !

Returns: Returns the ID of the created proxy.

docs: y · retail: confirmed (binary, runtime dump)

### CreateLink

```lua
Entity.CreateLink(name, targetId)
```

Creates a new outgoing link for this entity. !

! ! ! !

| Param | Description |
|---|---|
| const char* name | Name of the link. Does not have to be unique among all the links of this entity. Multiple links with the same name can perfectly co-exist. |
| (optional) targetId | If specified, the ID of the entity the link shall target. If not specified or 0 then the link will not target anything. Default value: 0 |

Returns: nothing

docs: y · retail: confirmed (binary, runtime dump, mod×10)

### CreateRenderProxy

```lua
Entity.CreateRenderProxy()
```

C++: `int CreateRenderProxy (IFunctionHandler* pH )`

Create a proxy render object for the entity, allows entity to be rendered without loading any assets in immediately.

docs: y · retail: confirmed (binary, runtime dump, vanilla×2)

### CreateSkinAttachment

```lua
Entity.CreateSkinAttachment()
```

C++: `int CreateSkinAttachment (IFunctionHandler * pH , int characterSlot , const char * attachmentName )`

syntax: Entity.CreateSkinAttachment( characterSlot, attachmentName )

docs: y · retail: confirmed (binary, runtime dump)

### Damage

```lua
Entity.Damage()
```

C++: `int Damage (IFunctionHandler * pH )`

syntax: Entity.Damage()

docs: y · retail: confirmed (runtime dump)

### DeactivateParticleEmitter

```lua
Entity.DeactivateParticleEmitter(slot)
```

Deactivates particles emitter from 3dengine - existing particles will be left to finish their lifetime. ! You should call DeleteParticleEmitter after some time.

| Param | Description |
|---|---|
| int slot | slot number |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### DelegateCalls

```lua
Entity.DelegateCalls()
```

C++: `void DelegateCalls (IScriptTable * pInstanceTable )`

docs: y · retail: unconfirmed

### DeleteParticleEmitter

```lua
Entity.DeleteParticleEmitter(slot)
```

Deletes particles emitter from 3dengine.

| Param | Description |
|---|---|
| int slot | . |

docs: y · retail: confirmed (binary, runtime dump, vanilla×4)

### DeleteThis

```lua
Entity.DeleteThis()
```

C++: `int DeleteThis (IFunctionHandler * pH )`

Deletes this entity.

docs: y · retail: confirmed (binary, runtime dump, vanilla×2)

### DestroyAttachment

```lua
Entity.DestroyAttachment()
```

C++: `int DestroyAttachment (IFunctionHandler * pH , int characterSlot , const char * attachmentName )`

syntax: Entity.DestroyAttachment( characterSlot, attachmentName )

docs: y · retail: confirmed (binary, runtime dump, vanilla×5)

### DestroyBBoxProxy

```lua
Entity.DestroyBBoxProxy()
```

C++: `int DestroyBBoxProxy (IFunctionHandler* pH )`

[WH:MR] Destroys the bbox proxy

docs: y · retail: confirmed (binary, runtime dump)

### DestroyPhysics

```lua
Entity.DestroyPhysics()
```

C++: `int DestroyPhysics (IFunctionHandler * pH )`

Destroys the physics of an entity object

docs: y · retail: confirmed (binary, runtime dump, vanilla×8, mod×2)

### DetachAll

```lua
Entity.DetachAll()
```

C++: `int DetachAll (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### DetachThis

```lua
Entity.DetachThis()
```

C++: `int DetachThis (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### DisableAnimationEvent

```lua
Entity.DisableAnimationEvent(nSlot, sAnimation)
```

C++: `int DisableAnimationEvent (IFunctionHandler * pH , int nSlot , const char * sAnimation )`

docs: y · retail: confirmed (runtime dump)

### DrawSlot

```lua
Entity.DrawSlot(nSlot)
```

Enables/Disables drawing of object or character at specified slot of the entity.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |
| int nEnable | 1-Enable drawing, 0-Disable drawing. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×22, mod×12)

### EnableBoneAnimation

```lua
Entity.EnableBoneAnimation(characterSlot, layer, boneName, status)
```

C++: `int EnableBoneAnimation (IFunctionHandler * pH , int characterSlot , int layer , const char * boneName , bool status )`

docs: y · retail: confirmed (runtime dump)

### EnableBoneAnimationAll

```lua
Entity.EnableBoneAnimationAll(characterSlot, layer, status)
```

C++: `int EnableBoneAnimationAll (IFunctionHandler * pH , int characterSlot , int layer , bool status )`

docs: y · retail: confirmed (binary, runtime dump)

### EnableDecals

```lua
Entity.EnableDecals(slot, enable)
```

C++: `int EnableDecals (IFunctionHandler * pH , int slot , bool enable )`

docs: y · retail: unconfirmed

### EnableInheritXForm

```lua
Entity.EnableInheritXForm()
```

C++: `int EnableInheritXForm (IFunctionHandler * pH , bool bEnable )`

Enables/Disable entity from inheriting transformation from the parent.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### EnableMaterialLayer

```lua
Entity.EnableMaterialLayer()
```

C++: `int EnableMaterialLayer (IFunctionHandler * pH , bool enable , int layer )`

int AddMaterialLayer(IFunctionHandler *pH, int slotId, const char *shader); int RemoveMaterialLayer(IFunctionHandler *pH, int slotId, int id); int RemoveAllMaterialLayers(IFunctionHandler *pH, int slotId); int SetMaterialLayerParamF(IFunctionHandler *pH, int slotId, int layerId, const char *name, float value); int SetMaterialLayerParamV(IFunctionHandler *pH, int slotId, int layerId, const char *name, Vec3 vec); int SetMaterialLayerParamC(IFunctionHandler *pH, int slotId, int layerId, const char *name, float r, float g, float b, float a);

syntax: Entity.EnableMaterialLayer( enable, layer )

docs: y · retail: confirmed (runtime dump)

### EnablePhysics

```lua
Entity.EnablePhysics(bEnable)
```

C++: `int EnablePhysics (IFunctionHandler * pH , bool bEnable )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×3, mod×3)

### EnableProceduralFacialAnimation

```lua
Entity.EnableProceduralFacialAnimation(enable)
```

C++: `int EnableProceduralFacialAnimation (IFunctionHandler * pH , bool enable )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×1, mod×1)

### ExecuteAudioTrigger

```lua
Entity.ExecuteAudioTrigger(hTriggerID, hAudioProxyLocalID)
```

Execute the specified audio trigger and attach it to the entity. ! The created audio object will move and rotate with the entity. !

| Param | Description |
|---|---|
| ScriptHandle const hTriggerID | the audio trigger ID handle |
| ScriptHandle const hAudioProxyLocalID | ID of the AuxAudioProxy local to the EntityAudioProxy (to address the default AuxAudioProxy pass 1 to address all AuxAudioProxies pass 0) |

Returns: nil

docs: y · retail: confirmed (binary, runtime dump, vanilla×11)

### FadeGlobalDensity

```lua
Entity.FadeGlobalDensity(nSlot, fadeTime, newGlobalDensity)
```

Sets the fade global density.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |
| float fadeTime | . |
| float newGlobalDensity | . |

docs: y · retail: confirmed (runtime dump, vanilla×3)

### ForceCharacterUpdate

```lua
Entity.ForceCharacterUpdate(characterSlot, updateAlways)
```

C++: `int ForceCharacterUpdate (IFunctionHandler * pH , int characterSlot , bool updateAlways )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×4)

### ForwardTriggerEventsTo

```lua
Entity.ForwardTriggerEventsTo(entityId)
```

C++: `int ForwardTriggerEventsTo (IFunctionHandler * pH , ScriptHandle entityId )`

docs: y · retail: confirmed (binary, runtime dump)

### FreeAllSlots

```lua
Entity.FreeAllSlots()
```

C++: `int FreeAllSlots (IFunctionHandler * pH )`

Delete all objects on every slot part of the entity.

docs: y · retail: confirmed (binary, runtime dump)

### FreeSlot

```lua
Entity.FreeSlot(nSlot)
```

Delete all objects from specified slot.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×25)

### GetAIName

```lua
Entity.GetAIName()
```

C++: `int GetAIName (IFunctionHandler * pH )`

Get the AI name of the entity. Can be different than entity name. @return AI Name of the entity

docs: y · retail: confirmed (binary, runtime dump)

### GetAllAuxAudioProxiesID

```lua
Entity.GetAllAuxAudioProxiesID()
```

C++: `int GetAllAuxAudioProxiesID (IFunctionHandler* pH )`

Returns the ID used to address all AuxAudioProxy of the parent EntityAudioProxy. !

Returns: Returns the ID used to address all AuxAudioProxy of the parent EntityAudioProxy.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### GetAngles

```lua
Entity.GetAngles()
```

C++: `int GetAngles (IFunctionHandler * pH )`

Gets the angle of the entity.

docs: y · retail: confirmed (binary, runtime dump, vanilla×14, mod×8)

### GetAnimationLength

```lua
Entity.GetAnimationLength()
```

C++: `int GetAnimationLength (IFunctionHandler * pH , int characterSlot , const char * animation )`

syntax: Entity.GetAnimationLength( characterSlot, animation )

docs: y · retail: confirmed (binary, runtime dump, vanilla×7)

### GetAnimationSpeed

```lua
Entity.GetAnimationSpeed()
```

C++: `int GetAnimationSpeed (IFunctionHandler * pH , int characterSlot , int layer )`

docs: y · retail: confirmed (binary, runtime dump)

### GetAnimationTime

```lua
Entity.GetAnimationTime()
```

C++: `int GetAnimationTime (IFunctionHandler * pH , int nSlot , int nLayer )`

syntax: Entity.GetAnimationTime( nSlot, nLayer )

docs: y · retail: confirmed (binary, runtime dump, vanilla×10, mod×2)

### GetArchetype

```lua
Entity.GetArchetype()
```

C++: `int GetArchetype (IFunctionHandler * pH )`

Retrieve the archetype of the entity. Return: name of entity archetype, nil if no archetype.

Return name of the archetype.

docs: y · retail: confirmed (binary, runtime dump, vanilla×2)

### GetAttachmentBone

```lua
Entity.GetAttachmentBone()
```

C++: `int GetAttachmentBone (IFunctionHandler * pH , int characterSlot , const char * attachmentName )`

syntax: Entity.GetAttachmentBone( characterSlot, attachmentName )

docs: y · retail: confirmed (binary, runtime dump)

### GetAttachmentCGF

```lua
Entity.GetAttachmentCGF()
```

C++: `int GetAttachmentCGF (IFunctionHandler * pH , int characterSlot , const char * attachmentName )`

syntax: Entity.GetAttachmentCGF( characterSlot, attachmentName )

docs: y · retail: confirmed (binary, runtime dump)

### GetBBoxProxyBBox

```lua
Entity.GetBBoxProxyBBox()
```

C++: `int GetBBoxProxyBBox (IFunctionHandler* pH )`

Returns the aabb of the bbox proxy

docs: y · retail: confirmed (binary, runtime dump)

### GetBoneAngularVelocity

```lua
Entity.GetBoneAngularVelocity(characterSlot, oneName)
```

C++: `int GetBoneAngularVelocity (IFunctionHandler * pH , int characterSlot , const char * boneName )`

docs: y · retail: confirmed (binary, runtime dump)

### GetBoneDir

```lua
Entity.GetBoneDir()
```

C++: `int GetBoneDir (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### GetBoneLocal

```lua
Entity.GetBoneLocal()
```

C++: `int GetBoneLocal (IFunctionHandler * pH , const char * boneName , Vec3 trgDir )`

docs: y · retail: confirmed (runtime dump)

### GetBoneNameFromTable

```lua
Entity.GetBoneNameFromTable()
```

C++: `int GetBoneNameFromTable (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### GetBonePos

```lua
Entity.GetBonePos()
```

C++: `int GetBonePos (IFunctionHandler * pH )`

Retrieves the position of a bone @param bone Name of the helper object in the model @return Three component vector containing the position

docs: y · retail: confirmed (binary, runtime dump)

### GetBoneVelocity

```lua
Entity.GetBoneVelocity(characterSlot, boneName)
```

C++: `int GetBoneVelocity (IFunctionHandler * pH , int characterSlot , const char * boneName )`

docs: y · retail: confirmed (binary, runtime dump)

### GetCenterOfMassPos

```lua
Entity.GetCenterOfMassPos()
```

C++: `int GetCenterOfMassPos (IFunctionHandler * pH )`

Gets the position of the entity center of mass.

Get the position of the entity's physical center of mass @return Three component vector containing the entity's center of mass

docs: y · retail: confirmed (binary, runtime dump)

### GetCharacter

```lua
Entity.GetCharacter(nSlot)
```

C++: `int GetCharacter (IFunctionHandler * pH , int nSlot )`

Gets the character for the specified slot if there is any.

docs: y · retail: confirmed (binary, runtime dump)

### GetChild

```lua
Entity.GetChild(int nIndex)
```

C++: `int GetChild (IFunctionHandler * pH , int nIndex )`

docs: y · retail: confirmed (binary, runtime dump)

### GetChildCount

```lua
Entity.GetChildCount()
```

C++: `int GetChildCount (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### GetCurAnimation

```lua
Entity.GetCurAnimation()
```

C++: `int GetCurAnimation (IFunctionHandler * pH )`

syntax: Entity.GetCurAnimation()

docs: y · retail: confirmed (binary, runtime dump, mod×4)

### GetDefaultAuxAudioProxyID

```lua
Entity.GetDefaultAuxAudioProxyID()
```

C++: `int GetDefaultAuxAudioProxyID (IFunctionHandler* pH )`

Returns the ID of the default AudioProxy of the parent EntityAudioProxy. !

Returns: Returns the ID of the default AudioProxy of the parent EntityAudioProxy.

docs: y · retail: confirmed (binary, runtime dump, vanilla×35)

### GetDirectionVector

```lua
Entity.GetDirectionVector()
```

C++: `int GetDirectionVector (IFunctionHandler * pH )`

Get Forward direction if no parameters if parameter is passed - get Up direction [filippo]: now more complete, if the param is specified we can get the axis we want.

docs: y · retail: confirmed (binary, runtime dump, vanilla×22, mod×25)

### GetDistance

```lua
Entity.GetDistance()
```

C++: `int GetDistance (IFunctionHandler * pH )`

Return the distance from entity specified with entityId

docs: y · retail: confirmed (binary, runtime dump, vanilla×3)

### GetEntitiesInContact

```lua
Entity.GetEntitiesInContact()
```

C++: `int GetEntitiesInContact (IFunctionHandler * pH )`

syntax: Entity.GetEntitiesInContact()

docs: y · retail: unconfirmed

### GetEntityMaterial

```lua
Entity.GetEntityMaterial()
```

C++: `int GetEntityMaterial (IFunctionHandler * pH )`

syntax: Entity.GetEntityMaterial()

docs: y · retail: confirmed (binary, runtime dump)

### GetExplosionImpulse

```lua
Entity.GetExplosionImpulse()
```

C++: `int GetExplosionImpulse (IFunctionHandler * pH )`

syntax: Entity.GetExplosionImpulse()

docs: y · retail: confirmed (binary, runtime dump)

### GetExplosionObstruction

```lua
Entity.GetExplosionObstruction()
```

C++: `int GetExplosionObstruction (IFunctionHandler * pH )`

syntax: Entity.GetExplosionObstruction()

docs: y · retail: confirmed (binary, runtime dump)

### GetFlags

```lua
Entity.GetFlags()
```

C++: `int GetFlags (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### GetFlagsExtended

```lua
Entity.GetFlagsExtended()
```

C++: `int GetFlagsExtended (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### GetGeomCachePrecachedTime

```lua
Entity.GetGeomCachePrecachedTime()
```

C++: `int GetGeomCachePrecachedTime (IFunctionHandler * pH )`

syntax: Entity.GetGeomCachePrecachedTime()

Gets time delta from current playback position to last ready to play frame

Activates/deactivates geom cache drawing

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### GetGravity

```lua
Entity.GetGravity()
```

C++: `int GetGravity (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### GetGUID

```lua
Entity.GetGUID()
```

C++: `int GetGUID (IFunctionHandler* pH )`

docs: y · retail: confirmed (binary, runtime dump)

### GetHelperAngles

```lua
Entity.GetHelperAngles()
```

C++: `int GetHelperAngles (IFunctionHandler * pH )`

Retrieves the rotation angles of a helper (placeholder) object @param helper Name of the helper object in the model @return Three component vector containing the rotation angles

docs: y · retail: confirmed (binary, runtime dump)

### GetHelperDir

```lua
Entity.GetHelperDir()
```

C++: `int GetHelperDir (IFunctionHandler * pH )`

Retrieves the direction of a helper (placeholder) object @param helper Name of the helper object in the model @return Three component vector containing the forward direction

docs: y · retail: confirmed (binary, runtime dump, vanilla×3)

### GetHelperPos

```lua
Entity.GetHelperPos()
```

C++: `int GetHelperPos (IFunctionHandler * pH )`

Retrieves the position of a helper (placeholder) object @param helper Name of the helper object in the model @return Three component vector containing the position

docs: y · retail: confirmed (binary, runtime dump)

### GetLink

```lua
Entity.GetLink()
```

Returns the link at given index. !

! ! ! !

| Param | Description |
|---|---|
| int ith | The index of the link that shall be returned. |

Returns: The script table of the entity that the i'th link is targeting or nil if the specified index is out of bounds.

docs: y · retail: confirmed (binary, runtime dump, vanilla×13, mod×4)

### GetLinkName

```lua
Entity.GetLinkName(targetId, ith)
```

Returns the name of the link that is targeting the entity with given ID. !

! ! ! !

| Param | Description |
|---|---|
| ScriptHandle targetId | ID of the entity for which the link name shall be looked up. |
| (optional) ith | If specified, the i'th link that targets given entity. Default value: 0 (first entity) |

Returns: The name of the i'th link targeting given entity or nil if no such link exists.

docs: y · retail: confirmed (binary, runtime dump)

### GetLinkTarget

```lua
Entity.GetLinkTarget(name, ith)
```

Returns the ID of the entity that given link is targeting. !

! ! ! !

| Param | Description |
|---|---|
| const char* name | Name of the link. |
| (optional) ith | If specified, the i'th link with given name for which to look up the targeted entity. Default value: 0 (first link with given name) |

Returns: The ID of the entity that the link is targeting or nil if no such link exists.

docs: y · retail: confirmed (binary, runtime dump, vanilla×9, mod×1)

### GetLocalAngles

```lua
Entity.GetLocalAngles()
```

C++: `int GetLocalAngles (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### GetLocalBBox

```lua
Entity.GetLocalBBox()
```

C++: `int GetLocalBBox (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×2, mod×1)

### GetLocalPos

```lua
Entity.GetLocalPos()
```

C++: `int GetLocalPos (IFunctionHandler * pH )`

Get the position of the entity @return Three component vector containing the entity position

docs: y · retail: confirmed (binary, runtime dump)

### GetLocalScale

```lua
Entity.GetLocalScale()
```

C++: `int GetLocalScale (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### GetLodRatio

```lua
Entity.GetLodRatio()
```

C++: `int GetLodRatio (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump, mod×1)

### GetMass

```lua
Entity.GetMass()
```

C++: `int GetMass (IFunctionHandler * pH )`

Get the mass of the entity @return mass of the entity;

docs: y · retail: confirmed (binary, runtime dump, mod×4)

### GetMaterial

```lua
Entity.GetMaterial()
```

C++: `int GetMaterial (IFunctionHandler * pH )`

syntax: Entity.GetMaterial()

Get the name of custom entity material.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### GetMaterialFloat

```lua
Entity.GetMaterialFloat(nSlotId, nSubMtlId, sParamName)
```

Change material parameter.

| Param | Description |
|---|---|
| int nSubMtlId | Specify sub-material by Id |
| const char * sParamName | Name of the material parameter. |
| nSlot | On which slot to change material. |

Returns: Material parameter value.

docs: y · retail: confirmed (binary, runtime dump)

### GetMaterialVec3

```lua
Entity.GetMaterialVec3(nSlotId, nSubMtlId, sParamName)
```

C++: `int GetMaterialVec3 (IFunctionHandler * pH , int slot , int nSubMtlId , const char * sParamName )`

docs: y · retail: confirmed (binary, runtime dump)

### GetMemoryUsage

```lua
Entity.GetMemoryUsage()
```

C++: `virtual void GetMemoryUsage (ICrySizer* pSizer ) const`

This is GetMemoryUsage, a member of class CScriptBind_Entity.

docs: y · retail: unconfirmed

### GetName

```lua
Entity.GetName()
```

C++: `int GetName (IFunctionHandler * pH )`

Get the name of the entity @return Name of the entity

docs: y · retail: confirmed (binary, runtime dump, vanilla×60, mod×144)

### GetParent

```lua
Entity.GetParent()
```

C++: `int GetParent (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×4)

### GetParentSlot

```lua
Entity.GetParentSlot(child)
```

C++: `int GetParentSlot (IFunctionHandler* pH , int child )`

docs: y · retail: confirmed (binary, runtime dump)

### GetPhysicalStats

```lua
Entity.GetPhysicalStats()
```

C++: `int GetPhysicalStats (IFunctionHandler * pH )`

Some more physics related.

get some physical infos such mass and gravity

docs: y · retail: confirmed (binary, runtime dump)

### GetPos

```lua
Entity.GetPos()
```

C++: `int GetPos (IFunctionHandler * pH )`

Gets the position of the entity.

docs: y · retail: confirmed (binary, runtime dump, vanilla×44, mod×63)

### GetProjectedWorldBBox

```lua
Entity.GetProjectedWorldBBox()
```

C++: `int GetProjectedWorldBBox (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### GetRawId

```lua
Entity.GetRawId()
```

C++: `int GetRawId (IFunctionHandler * pH )`

Returns entityId in raw numeric format.

Get the id of the entity in number form @return Entity id as number

docs: y · retail: confirmed (binary, runtime dump, vanilla×2)

### GetScale

```lua
Entity.GetScale()
```

C++: `int GetScale (IFunctionHandler * pH )`

Gets the scaling value for the entity.

docs: y · retail: confirmed (binary, runtime dump, vanilla×5)

### GetSlotAngles

```lua
Entity.GetSlotAngles(nSlot, v)
```

Sets the slot angles.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |
| Ang3 v | Angle to be set. |

docs: y · retail: confirmed (binary, runtime dump)

### GetSlotCount

```lua
Entity.GetSlotCount()
```

C++: `int GetSlotCount (IFunctionHandler* pH )`

Gets the count of the slots.

docs: y · retail: confirmed (binary, runtime dump)

### GetSlotHelperPos

```lua
Entity.GetSlotHelperPos(slot, helperName, objectSpace)
```

C++: `int GetSlotHelperPos (IFunctionHandler * pH , int slot , const char * helperName , bool objectSpace )`

Retrieves the position of a helper (placeholder) object @param helper Name of the helper object in the model @return Three component vector cotaining the position

docs: y · retail: confirmed (binary, runtime dump, vanilla×3)

### GetSlotPos

```lua
Entity.GetSlotPos(nSlot)
```

Gets the slot position.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |

docs: y · retail: confirmed (binary, runtime dump)

### GetSlotScale

```lua
Entity.GetSlotScale(nSlot)
```

Gets the slot scale amount.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |

docs: y · retail: confirmed (binary, runtime dump)

### GetSlotWorldDir

```lua
Entity.GetSlotWorldDir(nSlot)
```

Gets the World direction of the slot.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×4)

### GetSlotWorldPos

```lua
Entity.GetSlotWorldPos(nSlot)
```

Gets the World position of the slot.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×3)

### GetSpeed

```lua
Entity.GetSpeed()
```

C++: `int GetSpeed (IFunctionHandler * pH )`

Get the speed of the entity @return Speed in float value

docs: y · retail: confirmed (binary, runtime dump, mod×7)

### GetState

```lua
Entity.GetState()
```

C++: `int GetState (IFunctionHandler * pH )`

syntax: Entity.GetState()

docs: y · retail: confirmed (binary, runtime dump, vanilla×8, mod×36)

### GetSubmergedVolume

```lua
Entity.GetSubmergedVolume(slot, planeNormal, planeOrigin)
```

C++: `int GetSubmergedVolume (IFunctionHandler * pH , int slot , Vec3 planeNormal , Vec3 planeOrigin )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### GetTimeOfDayHour

```lua
Entity.GetTimeOfDayHour()
```

C++: `int GetTimeOfDayHour (IFunctionHandler* pH )`

Returns: current time of day as a float value.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1 (e.g. `references/kcd2-mod-docs-main/Scripts/Scripts/Entities/WH/Others/TODDrivenAnimObject.lua`))

### GetTimeSinceLastSeen

```lua
Entity.GetTimeSinceLastSeen()
```

C++: `int GetTimeSinceLastSeen (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### GetTouchedPoint

```lua
Entity.GetTouchedPoint()
```

C++: `int GetTouchedPoint (IFunctionHandler * pH )`

syntax: Entity.GetTouchedPoint()

Retrieves point of collision for rigid body.

retrieves point of collision for rigid body

docs: y · retail: confirmed (binary, runtime dump)

### GetTouchedSurfaceID

```lua
Entity.GetTouchedSurfaceID()
```

C++: `int GetTouchedSurfaceID (IFunctionHandler * pH )`

syntax: Entity.GetTouchedSurfaceID()

retrieve the material id(surfaceid) of the object in contact with the entity @return the material id of the colliding entity

docs: y · retail: confirmed (binary, runtime dump)

### GetTriggerBBox

```lua
Entity.GetTriggerBBox()
```

C++: `int GetTriggerBBox (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### GetUpdateRadius

```lua
Entity.GetUpdateRadius()
```

C++: `int GetUpdateRadius (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### GetVelocity

```lua
Entity.GetVelocity()
```

C++: `int GetVelocity (IFunctionHandler * pH )`

Get the velocity of the entity @return Three component vector containing the velocity position

docs: y · retail: confirmed (binary, runtime dump, mod×1)

### GetVelocityEx

```lua
Entity.GetVelocityEx()
```

C++: `int GetVelocityEx (IFunctionHandler * pH )`

Get the velocity and angular velocity of the entity @return Three component vector containing the velocity position and three component vector containing angular velocity

docs: y · retail: confirmed (binary, runtime dump)

### GetViewDistRatio

```lua
Entity.GetViewDistRatio()
```

C++: `int GetViewDistRatio (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump, mod×2)

### GetVolume

```lua
Entity.GetVolume(slot)
```

C++: `int GetVolume (IFunctionHandler * pH , int slot )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### GetWorldAngles

```lua
Entity.GetWorldAngles()
```

C++: `int GetWorldAngles (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×2, mod×37)

### GetWorldBBox

```lua
Entity.GetWorldBBox()
```

C++: `int GetWorldBBox (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×5, mod×2)

### GetWorldBoundsCenter

```lua
Entity.GetWorldBoundsCenter()
```

C++: `int GetWorldBoundsCenter (IFunctionHandler * pH )`

Gets the world bbox center for the entity (defaults to entity position if no bbox present).

docs: y · retail: confirmed (binary, runtime dump)

### GetWorldDir

```lua
Entity.GetWorldDir()
```

C++: `int GetWorldDir (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×5)

### GetWorldPos

```lua
Entity.GetWorldPos()
```

C++: `int GetWorldPos (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×54, mod×375)

### GetWorldScale

```lua
Entity.GetWorldScale()
```

C++: `int GetWorldScale (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### GoalParamsHelper

```lua
Entity.GoalParamsHelper()
```

C++: `void GoalParamsHelper (IFunctionHandler* pH , uint32 index , GoalParams& node )`

This is GoalParamsHelper, a member of class CScriptBind_Entity.

docs: y · retail: unconfirmed

### GotoState

```lua
Entity.GotoState()
```

C++: `int GotoState (IFunctionHandler * pH , const char * sState )`

syntax: Entity.GotoState( sState )

docs: y · retail: confirmed (binary, runtime dump, vanilla×40)

### HasFlags

```lua
Entity.HasFlags(flags)
```

C++: `int HasFlags (IFunctionHandler * pH , int flags )`

docs: y · retail: confirmed (binary, runtime dump, mod×2)

### Hide

```lua
Entity.Hide()
```

C++: `int Hide (IFunctionHandler * pH )`

The function has one optional parameter. If value of this parameter is nonzero, entity is hidden. Default value is 1.

docs: y · retail: confirmed (binary, runtime dump, vanilla×43, mod×3)

### HideAllAttachments

```lua
Entity.HideAllAttachments()
```

C++: `int HideAllAttachments (IFunctionHandler * pH , int characterSlot , bool hide , bool hideShadow )`

syntax: Entity.HideAllAttachments( characterSlot, hide, hideShadow )

docs: y · retail: confirmed (runtime dump)

### HideAttachment

```lua
Entity.HideAttachment()
```

C++: `int HideAttachment (IFunctionHandler * pH , int characterSlot , const char * attachmentName , bool hide , bool hideShadow )`

syntax: Entity.HideAttachment( characterSlot, attachmentName, hide, hideShadow )

docs: y · retail: confirmed (runtime dump)

### HideAttachmentMaster

```lua
Entity.HideAttachmentMaster()
```

C++: `int HideAttachmentMaster (IFunctionHandler * pH , int characterSlot , bool hide )`

syntax: Entity.HideAttachmentMaster( characterSlot, hide )

docs: y · retail: confirmed (binary, runtime dump)

### IgnorePhysicsUpdatesOnSlot

```lua
Entity.IgnorePhysicsUpdatesOnSlot(nSlot)
```

Ignore physics when it try to update the position of a slot.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |

docs: y · retail: confirmed (binary, runtime dump)

### InsertSubpipe

```lua
Entity.InsertSubpipe()
```

C++: `int InsertSubpipe (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### IntersectRay

```lua
Entity.IntersectRay(slot, rayOrigin, rayDir, maxDistance)
```

C++: `int IntersectRay (IFunctionHandler * pH , int slot , Vec3 rayOrigin , Vec3 rayDir , float maxDistance )`

docs: y · retail: confirmed (runtime dump)

### InvalidateLocalBBox

```lua
Entity.InvalidateLocalBBox()
```

C++: `int InvalidateLocalBBox (IFunctionHandler * pH , bool forced )`

docs: y · retail: confirmed (binary, runtime dump)

### InvalidateTrigger

```lua
Entity.InvalidateTrigger()
```

C++: `int InvalidateTrigger (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### IsActive

```lua
Entity.IsActive(bActivate)
```

C++: `int IsActive (IFunctionHandler * pH )`

Retrieve active status of entity. Return: true - Entity is active. false - Entity is not active.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### IsAnimationRunning

```lua
Entity.IsAnimationRunning(characterSlot, layer)
```

Retrieves if a characters currently plays an animation @param iAnimationPos Number of the character slot @return nil or not nil @see CScriptBind_Entity::StartAnimation

| Param | Description |
|---|---|
| int characterSlot | Index of the character slot. |
| int layer | Index of the animation layer. |

Returns: nil or not nil

docs: y · retail: confirmed (binary, runtime dump, vanilla×8, mod×5)

### IsColliding

```lua
Entity.IsColliding()
```

C++: `int IsColliding (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### IsEntityInside

```lua
Entity.IsEntityInside()
```

C++: `int IsEntityInside (IFunctionHandler * pH , ScriptHandle entityId )`

docs: y · retail: confirmed (binary, runtime dump)

### IsEntityInsideArea

```lua
Entity.IsEntityInsideArea(areaId, entityId)
```

C++: `int IsEntityInsideArea (IFunctionHandler * pH , int areaId , ScriptHandle entityId )`

docs: y · retail: confirmed (binary, runtime dump)

### IsFromPool

```lua
Entity.IsFromPool()
```

C++: `int IsFromPool (IFunctionHandler * pH )`

Returns if the entity came from an entity pool. Return: true - Entity is from a pool. (Bookmarked) false - Entity is not from a pool. (Not bookmarked)

docs: y · retail: confirmed (binary, runtime dump)

### IsGarbage

```lua
Entity.IsGarbage()
```

C++: `int IsGarbage (IFunctionHandler* pH )`

docs: y · retail: confirmed (binary, runtime dump)

### IsGeomCacheStreaming

```lua
Entity.IsGeomCacheStreaming()
```

C++: `int IsGeomCacheStreaming (IFunctionHandler * pH )`

syntax: Entity.IsGeomCacheStreaming()

Returns true if geom cache is streaming

Returns true if geom cache is streaming

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### IsHidden

```lua
Entity.IsHidden()
```

C++: `int IsHidden (IFunctionHandler * pH )`

syntax: Entity.IsHidden()

docs: y · retail: confirmed (binary, runtime dump, vanilla×3, mod×4)

### IsInState

```lua
Entity.IsInState()
```

C++: `int IsInState (IFunctionHandler * pH , const char * sState )`

syntax: Entity.IsInState( sState )

docs: y · retail: confirmed (binary, runtime dump, vanilla×3)

### IsPerInstanceStreamable

```lua
Entity.IsPerInstanceStreamable()
```

C++: `int IsPerInstanceStreamable (IFunctionHandler* pH )`

docs: y · retail: confirmed (binary, runtime dump)

### IsPointInsideArea

```lua
Entity.IsPointInsideArea(areaId, point)
```

C++: `int IsPointInsideArea (IFunctionHandler * pH , int areaId , Vec3 point )`

docs: y · retail: confirmed (binary, runtime dump)

### IsSlotCharacter

```lua
Entity.IsSlotCharacter(slot)
```

Checks if the slot is a character.

| Param | Description |
|---|---|
| int slot | Slot identifier. |

docs: y · retail: confirmed (binary, runtime dump, mod×2)

### IsSlotGeometry

```lua
Entity.IsSlotGeometry(slot)
```

Checks if the slot is a geometry.

| Param | Description |
|---|---|
| int slot | Slot identifier. |

docs: y · retail: confirmed (binary, runtime dump)

### IsSlotLight

```lua
Entity.IsSlotLight(slot)
```

Checks if the slot is a light.

| Param | Description |
|---|---|
| int slot | Slot identifier. |

docs: y · retail: confirmed (binary, runtime dump)

### IsSlotParticleEmitter

```lua
Entity.IsSlotParticleEmitter(slot)
```

Checks if the slot is a particle emitter.

| Param | Description |
|---|---|
| int slot | Slot identifier. |

docs: y · retail: confirmed (binary, runtime dump)

### IsSlotValid

```lua
Entity.IsSlotValid(nSlot)
```

Checks if the slot is valid.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×11)

### IsUsingPipe

```lua
Entity.IsUsingPipe(pipename)
```

Returns true if entity is running the given goalpipe or has it inserted.

| Param | Description |
|---|---|
| pipename | goalpipe name</param |

Returns: true - if entity is running the given goalpipe or has it inserted ! false - otherwise

docs: y · retail: confirmed (binary, runtime dump)

### KillTimer

```lua
Entity.KillTimer()
```

C++: `int KillTimer (IFunctionHandler * pH )`

syntax: Entity.KillTimer()

docs: y · retail: confirmed (binary, runtime dump, vanilla×28)

### LoadCharacter

```lua
Entity.LoadCharacter(nSlot, sFilename)
```

Load CGF geometry into the entity slot.

Load an animated character @param sFileName File name of the .cid file @param nPos Number of the slot for the character @see CScriptBind_Entity::StartAnimation

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |
| const char* sFilename | CGF geometry file name. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×7)

### LoadCloud

```lua
Entity.LoadCloud(nSlot, sFilename)
```

Loads the cloud XML file into the entity slot.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |
| const char * sFilename | Filename. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### LoadFogVolume

```lua
Entity.LoadFogVolume(nSlot, table)
```

Loads the fog volume XML file into the entity slot.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |
| SmartScriptTable table | Table with fog volume properties. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### LoadGeomCache

```lua
Entity.LoadGeomCache(int nSlot, const char *sFilename)
```

Load geom cache into the entity slot.

Load an geom cache

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |
| const char* sFilename | CAX file name. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### LoadLight

```lua
Entity.LoadLight(nSlot, lightTable)
```

Load CGF geometry into the entity slot.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |
| lightTable | Table with all the light information. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×6)

### LoadLightShape

```lua
Entity.LoadLightShape(nSlot, sLightShapeFile)
```

Loads CGF geometry into the entity slot.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |
| const char * sLightShapeFile | name of the light shape path to load |
| const uint32 nLSFlags | flags of the light shape |

docs: y · retail: confirmed (vanilla×2)

### LoadObject

```lua
Entity.LoadObject(nSlot, sFilename)
```

Load CGF geometry into the entity slot.

Load a static object @param sFileName File name of the .cgf file @param nPos Number of the slot for the character (Zero for first 1st person weapons, one for 3rd person weapons) @see CScriptBind_Entity::StartAnimation

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |
| const char* sFilename | CGF geometry file name. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×30)

### LoadObjectLattice

```lua
Entity.LoadObjectLattice(nSlot)
```

C++: `int LoadObjectLattice (IFunctionHandler * pH , int nSlot )`

Load lattice into the entity slot. nSlot">Slot identifier.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### LoadParticleEffect

```lua
Entity.LoadParticleEffect(nSlot, sEffectName, fPulsePeriod, bPrime, fScale)
```

Loads CGF geometry into the entity slot.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |
| const char * sEffectName | Name of the particle effect (Ex: "explosions/rocket"). Optional table fields: |
| bPrime | Whether effect starts fully primed to equilibrium state. |
| fPulsePeriod | Time period between particle effect restarts. |
| fScale | Size scale to apply to particles |
| fCountScale | Count multiplier to apply to particles |
| bScalePerUnit | Scale size by attachment extent |
| bCountPerUnit | Scale count by attachment extent |
| sAttachType | string for EGeomType |
| sAttachForm | string for EGeomForm |

docs: y · retail: confirmed (runtime dump, vanilla×8)

### LoadPrismObject

```lua
Entity.LoadPrismObject()
```

C++: `int LoadPrismObject (IFunctionHandler* pH , int nSlot )`

This is LoadPrismObject, a member of class CScriptBind_Entity.

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### LoadSubObject

```lua
Entity.LoadSubObject(nSlot, sFilename, sGeomName)
```

Load geometry of one CGF node into the entity slot.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |
| const char * sFilename | CGF geometry file name. |
| const char * sGeomName | Name of the node inside CGF geometry. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×5)

### LoadVolumeObject

```lua
Entity.LoadVolumeObject(nSlot, sFilename)
```

Loads volume object.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |
| const char* sFilename | File name of the volume object. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### MaterialFlashInvoke

```lua
Entity.MaterialFlashInvoke()
```

C++: `int MaterialFlashInvoke (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### MultiplyWithSlotTM

```lua
Entity.MultiplyWithSlotTM(slot, pos)
```

Multiplies with the TM (Transformation Matrix) of the slot.

| Param | Description |
|---|---|
| int slot | Slot identifier. |
| Vec3 pos | Position vector. |

docs: y · retail: confirmed (binary, runtime dump)

### NetPresent

```lua
Entity.NetPresent()
```

C++: `int NetPresent (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×18)

### NoBulletForce

```lua
Entity.NoBulletForce(state)
```

C++: `int NoBulletForce (IFunctionHandler * pH , bool state )`

docs: y · retail: confirmed (binary, runtime dump)

### NoExplosionCollision

```lua
Entity.NoExplosionCollision()
```

C++: `int NoExplosionCollision (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### PassParamsToPipe

```lua
Entity.PassParamsToPipe()
```

C++: `int PassParamsToPipe (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### PauseSound

```lua
Entity.PauseSound(SoundId)
```

Pauses/Unpauses playing sound.

| Param | Description |
|---|---|
| bool bPause | true to pause sound, false to unpause sound. |
| SoundId | Sound Id. |

docs: y · retail: unconfirmed

### Physicalize

```lua
Entity.Physicalize(int nSlot, int nPhysicsType,table physicsParams)
```

Create physical entity from the specified entity slot. ! ! Physics Type Meaning ! ------------- ----------- ! PE_NONE No physics. ! PE_STATIC Static physical entity. ! PE_LIVING Live physical entity (Players,Monsters). ! PE_RIGID Rigid body physical entity. ! PE_WHEELEDVEHICLE Physical vechicle with wheels. ! PE_PARTICLE Particle physical entity, it only have mass and radius. ! PE_ARTICULATED Ragdolls or other articulated physical enttiies. ! PE_ROPE Physical representation of the rope. ! PE_SOFT Soft body physics, cloth simulation. ! PE_AREA Physical Area (Sphere,Box,Geometry or Shape).

! Params table keys Meaning ! ----------------- ----------- ! mass Object mass, only used if density is not specified or -1. ! density Object density, only used if mass is not specified or -1. ! flags Physical entity flags. ! partid Index of the articulated body part, that this new physical entity will be attached to. ! stiffness_scale Scale of character joints stiffness (Multiplied with stiffness values specified from exported model) ! Particle This table must be set when Physics Type is PE_PARTICLE. ! Living This table must be set when Physics Type is PE_LIVING. ! Area This table must be set when Physics Type is PE_AREA.

! Particle table Meaning ! ----------------- ----------- ! mass Particle mass. ! radius Particle pseudo radius. ! thickness Thickness when lying on a surface (if 0, radius will be used). ! velocity Velocity direction and magnitude vector. ! air_resistance Air resistance coefficient, F = kv. ! water_resistance Water resistance coefficient, F = kv. ! gravity Gravity force vector to the air. ! water_gravity Gravity force vector when in the water. ! min_bounce_vel Minimal velocity at which particle bounces of the surface. ! accel_thrust Acceleration along direction of movement. ! accel_lift Acceleration that lifts particle with the current speed. ! constant_orientation (0,1) Keep constance orientation. ! single_contact (0,1) Calculate only one first contact. ! no_roll (0,1) Do not roll particle on terrain. ! no_spin (0,1) Do not spin particle in air. ! no_path_alignment (0,1) Do not align particle orientation to the movement path.

Living table Meaning ! ----------------- ----------- ! height Vertical offset of collision geometry center. ! size Collision cylinder dimensions vector (x,y,z). ! height_eye Vertical offset of the camera. ! height_pivot Offset from central ground position that is considered entity center. ! head_radius Radius of the head. ! height_head Vertical offset of the head. ! inertia Inertia coefficient, the more it is, the less inertia is; 0 means no inertia ! air_resistance Air control coefficient 0..1, 1 - special value (total control of movement) ! gravity Vertical gravity magnitude. ! mass Mass of the player (in kg). ! min_slide_angle If surface slope is more than this angle, player starts sliding (In radians) ! max_climb_angle Player cannot climb surface which slope is steeper than this angle (In radians) ! max_jump_angle Player is not allowed to jump towards ground if this angle is exceeded (In radians) ! min_fall_angle Player starts falling when slope is steeper than this (In radians) ! max_vel_ground Player cannot stand on surfaces that are moving faster than this (In radians)

! Area table keys Meaning ! ----------------- ----------- ! type Type of the area, valid values are: AREA_SPHERE,AREA_BOX,AREA_GEOMETRY,AREA_SHAPE ! radius Radius of the area sphere, must be specified if type is AREA_SPHERE. ! box_min Min vector of bounding box, must be specified if type is AREA_BOX. ! box_max Max vector of bounding box, must be specified if type is AREA_BOX.. ! points Table, indexed collection of vectors in local entity space defining 2D shape of the area, (AREA_SHAPE) ! height Height of the 2D area (AREA_SHAPE), relative to the minimal Z in the points table. ! uniform Same direction in every point or always point to the center. ! falloff ellipsoidal falloff dimensions; 0,0,0 if no falloff. ! gravity Gravity vector inside the physical area.

| Param | Description |
|---|---|
| nSlot | Slot identifier, if -1 use geometries from all slots.</param |
| nPhysicsType | Type of physical entity to create.</param |
| physicsParams | Table with physicalization parameters.</param |

docs: y · retail: confirmed (runtime dump, vanilla×14)

### PhysicalizeAttachment

```lua
Entity.PhysicalizeAttachment()
```

C++: `int PhysicalizeAttachment (IFunctionHandler * pH , int characterSlot , const char * attachmentName , bool physicalize )`

syntax: Entity.PhysicalizeAttachment( characterSlot, attachmentName, physicalize )

docs: y · retail: confirmed (binary, runtime dump)

### PhysicalizeSlot

```lua
Entity.PhysicalizeSlot(slot, physicsParams)
```

C++: `int PhysicalizeSlot (IFunctionHandler * pH , int slot , SmartScriptTable physicsParams )`

docs: y · retail: confirmed (binary, runtime dump)

### PlayFacialAnimation

```lua
Entity.PlayFacialAnimation(name, looping)
```

C++: `int PlayFacialAnimation (IFunctionHandler * pH , char * name , bool looping )`

docs: y · retail: confirmed (runtime dump, vanilla×1, mod×1)

### PlaySound

```lua
Entity.PlaySound(SoundId)
```

Start playing the specified sound and attach it to the entity. Sound will move and rotate with the entity.

| Param | Description |
|---|---|
| SoundId | Sound Id previously loaded with Sound.LoadSound function. |
| Return | Return not a nil value if sound started to play successfully. nil if sound failed to play. |

docs: y · retail: unconfirmed

### PlaySoundEvent

```lua
Entity.PlaySoundEvent(sSoundOrEventName, vOffset, vDirection, nSoundFlags, nSoundFlagsExtended, nSemantic)
```

C++: `int PlaySoundEvent (IFunctionHandler * pH , const char * sSoundOrEventName , Vec3 vOffset , Vec3 vDirection , uint32 nSoundFlags , uint32 nSoundFlagsExtended , uint32 nSemantic )`

First pass impl. and docu.

plays a sound or a subgroup-sound

docs: y · retail: confirmed (vanilla×7)

### PlaySoundEventEx

```lua
Entity.PlaySoundEventEx(sSoundFilename, nSoundFlags, nSoundFlagsExtended, fVolume, vOffset, minRadius, maxRadius, nSemantic)
```

Play sound file attached to the entity.

| Param | Description |
|---|---|
| uint32 nSoundFlags | Sound flags, specify how to play sound. |
| uint32 nSoundFlagsExtended | Extended sound flags. |
| float fVolume | The sound's volume between 0-1 |
| Vec3 vOffset | Position offset in regards to the entity. |
| float minRadius | min radius |
| float maxRadius | max radius |
| uint32 nSemantic | Semantical information what this sound is. |
| sSoundFilename | Name of the sound file to play. |
| Return | Sound ID, or nil if failed to play sound. |

docs: y · retail: unconfirmed

### PreLoadParticleEffect

```lua
Entity.PreLoadParticleEffect(sEffectName)
```

Pre-loads a particle effect.

| Param | Description |
|---|---|
| const char * sEffectName | Name of the particle effect (Ex: "explosions/rocket"). |

docs: y · retail: confirmed (binary, runtime dump, vanilla×12)

### ProcessBroadcastEvent

```lua
Entity.ProcessBroadcastEvent()
```

C++: `int ProcessBroadcastEvent (IFunctionHandler* pH )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### RagDollize

```lua
Entity.RagDollize(slot)
```

C++: `int RagDollize (IFunctionHandler* pH , int slot )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×2)

### ReattachSoftEntityVtx

```lua
Entity.ReattachSoftEntityVtx(partId)
```

C++: `int ReattachSoftEntityVtx (IFunctionHandler * pH , ScriptHandle entityId , int partId )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### RedirectAnimationToLayer0

```lua
Entity.RedirectAnimationToLayer0(characterSlot, redirect)
```

C++: `int RedirectAnimationToLayer0 (IFunctionHandler * pH , int characterSlot , bool redirect )`

docs: y · retail: confirmed (binary, runtime dump)

### RegisterForAreaEvents

```lua
Entity.RegisterForAreaEvents(enable)
```

Registers the script proxy so that it receives area events. for this entity.

| Param | Description |
|---|---|
| int enable | 0, for disable, any other value for enable.. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×39)

### RelinkBoneAttachments

```lua
Entity.RelinkBoneAttachments()
```

C++: `int RelinkBoneAttachments (IFunctionHandler * pH )`

docs: y · retail: unconfirmed

### RemoveAllLinks

```lua
Entity.RemoveAllLinks()
```

C++: `int RemoveAllLinks (IFunctionHandler* pH )`

Removes all links of an entity. !

! ! ! !

Returns: nothing

docs: y · retail: confirmed (binary, runtime dump)

### RemoveAuxAudioProxy

```lua
Entity.RemoveAuxAudioProxy(hAudioProxyLocalID)
```

Removes the AuxAudioProxy corresponding to the passed ID from the parent EntityAudioProxy. !

| Param | Description |
|---|---|
| ScriptHandle const hAudioProxyLocalID | hAudioProxyLocalID - ID of the AuxAudioProxy to be removed from the parent EntityAudioProxy. |

Returns: nil

docs: y · retail: confirmed (binary, runtime dump)

### RemoveDecals

```lua
Entity.RemoveDecals()
```

C++: `int RemoveDecals (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×3)

### RemoveLink

```lua
Entity.RemoveLink(name, ith)
```

! ! ! !

| Param | Description |
|---|---|
| const char* name | Name of the link to remove. |
| (optional) ith | If specified, the i'th link with given name that shall be removed. Default value: 0 (first link with given name) |

Returns: nothing

docs: y · retail: confirmed (binary, runtime dump)

### RenderAlways

```lua
Entity.RenderAlways(enable)
```

Enables 'always render' on the render node, skipping any kind of culling.

| Param | Description |
|---|---|
| int enable | 0, for disable, any other value for enable. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×3)

### RenderShadow

```lua
Entity.RenderShadow()
```

C++: `int RenderShadow (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×1, mod×18)

### ReplaceMaterial

```lua
Entity.ReplaceMaterial()
```

C++: `int ReplaceMaterial (IFunctionHandler * pH , int slot , const char * name , const char * replacement )`

syntax: Entity.ReplaceMaterial( slot, name, replacement )

docs: y · retail: confirmed (binary, runtime dump)

### ResetAnimation

```lua
Entity.ResetAnimation(characterSlot, layer)
```

C++: `int ResetAnimation (IFunctionHandler* pH , int characterSlot , int layer )`

Resets the animation of a character @param pos Number of the character slot @see CScriptBind_Entity::LoadCharacter @see CEntity::StartAnimation

docs: y · retail: confirmed (runtime dump, vanilla×6)

### ResetAttachment

```lua
Entity.ResetAttachment()
```

C++: `int ResetAttachment (IFunctionHandler * pH , int characterSlot , const char * attachmentName )`

syntax: Entity.ResetAttachment( characterSlot, attachmentName )

docs: y · retail: confirmed (binary, runtime dump)

### ResetMaterial

```lua
Entity.ResetMaterial()
```

C++: `int ResetMaterial (IFunctionHandler * pH , int slot )`

syntax: Entity.ResetMaterial( slot )

docs: y · retail: confirmed (binary, runtime dump, mod×1)

### ResetPhysics

```lua
Entity.ResetPhysics()
```

C++: `int ResetPhysics (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### SelectPipe

```lua
Entity.SelectPipe()
```

C++: `int SelectPipe (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### SetAIName

```lua
Entity.SetAIName()
```

C++: `int SetAIName (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### SetAngles

```lua
Entity.SetAngles(vAngles)
```

Sets the angle of the entity.

| Param | Description |
|---|---|
| Ang3 vAngles | Angle vector. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×10, mod×67)

### SetAnimateOffScreenShadow

```lua
Entity.SetAnimateOffScreenShadow(bAnimateOffScreenShadow)
```

C++: `int SetAnimateOffScreenShadow (IFunctionHandler * pH , bool bAnimateOffScreenShadow )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### SetAnimationBlendOut

```lua
Entity.SetAnimationBlendOut(characterSlot, layer, blendOut)
```

C++: `int SetAnimationBlendOut (IFunctionHandler * pH , int characterSlot , int layer , float blendOut )`

docs: y · retail: confirmed (binary, runtime dump)

### SetAnimationDrivenMotion

```lua
Entity.SetAnimationDrivenMotion()
```

C++: `int SetAnimationDrivenMotion (IFunctionHandler* pH , int characterSlot , int enable )`

MH: ADD

MH: ADD

docs: y · retail: confirmed (binary, runtime dump)

### SetAnimationEvent

```lua
Entity.SetAnimationEvent(nSlot, sAnimation)
```

C++: `int SetAnimationEvent (IFunctionHandler * pH , int nSlot , const char * sAnimation )`

docs: y · retail: confirmed (runtime dump)

### SetAnimationFlip

```lua
Entity.SetAnimationFlip()
```

C++: `int SetAnimationFlip (IFunctionHandler * pH , int characterSlot , Vec3 flip )`

syntax: Entity.SetAnimationFlip( characterSlot, flip )

docs: y · retail: confirmed (binary, runtime dump)

### SetAnimationKeyEvent

```lua
Entity.SetAnimationKeyEvent(nSlot, sAnimation, nFrameID, sEvent)
```

C++: `int SetAnimationKeyEvent (IFunctionHandler* pH )`

Now is using dynamic parameters because the argument can be both a string or a number int CScriptBind_Entity::SetAnimationKeyEvent(IFunctionHandler *pH,int nSlot,const char *sAnimation,int nFrameID,const char *sEvent)

docs: y · retail: confirmed (runtime dump)

### SetAnimationSpeed

```lua
Entity.SetAnimationSpeed()
```

C++: `int SetAnimationSpeed (IFunctionHandler * pH , int characterSlot , int layer , float speed )`

syntax: Entity.SetAnimationSpeed( characterSlot, layer, speed )

docs: y · retail: confirmed (binary, runtime dump, vanilla×11)

### SetAnimationTime

```lua
Entity.SetAnimationTime()
```

C++: `int SetAnimationTime (IFunctionHandler * pH , int nSlot , int nLayer , float fTime )`

syntax: Entity.SetAnimationTime( nSlot, nLayer, fTime )

docs: y · retail: confirmed (binary, runtime dump, vanilla×11)

### SetAttachmentAngles

```lua
Entity.SetAttachmentAngles()
```

C++: `int SetAttachmentAngles (IFunctionHandler * pH , int characterSlot , const char * attachmentName , Vec3 angles )`

syntax: Entity.SetAttachmentAngles( characterSlot, attachmentName, angles )

docs: y · retail: confirmed (binary, runtime dump)

### SetAttachmentCGF

```lua
Entity.SetAttachmentCGF()
```

C++: `int SetAttachmentCGF (IFunctionHandler * pH , int characterSlot , const char * attachmentName , const char * filePath )`

syntax: Entity.SetAttachmentCGF( characterSlot, attachmentName, filePath )

docs: y · retail: confirmed (binary, runtime dump)

### SetAttachmentDir

```lua
Entity.SetAttachmentDir()
```

C++: `int SetAttachmentDir (IFunctionHandler * pH , int characterSlot , const char * attachmentName , Vec3 dir , bool worldSpace )`

syntax: Entity.SetAttachmentDir()

docs: y · retail: confirmed (runtime dump)

### SetAttachmentEffect

```lua
Entity.SetAttachmentEffect()
```

C++: `int SetAttachmentEffect (IFunctionHandler * pH , int characterSlot , const char * attachmentName , const char * effectName , Vec3 offset , Vec3 dir , float scale , int flags )`

syntax: Entity.SetAttachmentEffect( characterSlot, attachmentName, effectName, offset, dir, scale, flags )

docs: y · retail: confirmed (runtime dump)

### SetAttachmentLight

```lua
Entity.SetAttachmentLight()
```

C++: `int SetAttachmentLight (IFunctionHandler * pH , int characterSlot , const char * attachmentName , SmartScriptTable lightTable , int flags )`

syntax: Entity.SetAttachmentLight( characterSlot, attachmentName, lightTable, flags )

docs: y · retail: confirmed (runtime dump)

### SetAttachmentObject

```lua
Entity.SetAttachmentObject()
```

C++: `int SetAttachmentObject (IFunctionHandler * pH , int characterSlot , const char * attachmentName , ScriptHandle entityId , int slot , int flags )`

syntax: Entity.SetAttachmentObject( characterSlot, attachmentName, entityId, slot, flags )

docs: y · retail: confirmed (runtime dump, vanilla×1)

### SetAttachmentPos

```lua
Entity.SetAttachmentPos()
```

C++: `int SetAttachmentPos (IFunctionHandler * pH , int characterSlot , const char * attachmentName , Vec3 pos )`

syntax: Entity.SetAttachmentPos( characterSlot, attachmentName, pos )

docs: y · retail: confirmed (binary, runtime dump)

### SetAudioEnvironmentID

```lua
Entity.SetAudioEnvironmentID(nAudioEnvironmentID)
```

Sets the ID of the audio environment this entity will set for entities inside it.

| Param | Description |
|---|---|
| nAudioEnvironmentID | audio environment ID |

Returns: nil

docs: y · retail: confirmed (binary, runtime dump, vanilla×4)

### SetAudioObstructionCalcType

```lua
Entity.SetAudioObstructionCalcType(nObstructionCalcType, hAudioProxyLocalID)
```

Set the Audio Obstruction/Occlusion calculation type on the underlying GameAudioObject.

| Param | Description |
|---|---|
| int const nObstructionCalcType | Obstruction/Occlusion calculation type; ! Possible values: ! 0 - ignore Obstruction/Occlusion ! 1 - use single physics ray ! 2 - use multiple physics rays (currently 5 per object) |
| ScriptHandle const hAudioProxyLocalID | ID of the AuxAudioProxy local to the EntityAudioProxy (to address the default AuxAudioProxy pass 1 to address all AuxAudioProxies pass 0) |

Returns: nil

docs: y · retail: confirmed (binary, runtime dump)

### SetAudioProxyOffset

```lua
Entity.SetAudioProxyOffset(vOffset, hAudioProxyLocalID)
```

Set offset on the AudioProxy attached to the Entity.

| Param | Description |
|---|---|
| Vec3 const vOffset | offset vector |
| ScriptHandle const hAudioProxyLocalID | ID of the AuxAudioProxy local to the EntityAudioProxy (to address the default AuxAudioProxy pass 1 to address all AuxAudioProxies pass 0) |

Returns: nil

docs: y · retail: confirmed (runtime dump, vanilla×9)

### SetAudioRtpcValue

```lua
Entity.SetAudioRtpcValue(hRtpcID, fValue, hAudioProxyLocalID)
```

Set the specified audio RTPC to the specified value on the current Entity.

| Param | Description |
|---|---|
| ScriptHandle const hRtpcID | the audio RTPC ID handle |
| float const fValue | the RTPC value |
| ScriptHandle const hAudioProxyLocalID | ID of the AuxAudioProxy local to the EntityAudioProxy (to address the default AuxAudioProxy pass 1 to address all AuxAudioProxies pass 0) |

Returns: nil

docs: y · retail: confirmed (runtime dump, vanilla×5)

### SetAudioSwitchState

```lua
Entity.SetAudioSwitchState(hSwitchID, hSwitchStateID, hAudioProxyLocalID)
```

Set the specified audio switch to the specified state on the current Entity.

| Param | Description |
|---|---|
| ScriptHandle const hSwitchID | the audio switch ID handle |
| ScriptHandle const hAudioProxyLocalID | ID of the AuxAudioProxy local to the EntityAudioProxy (to address the default AuxAudioProxy pass 1 to address all AuxAudioProxies pass 0) |
| nSwitchStateID | the switch state ID handle |

Returns: nil

docs: y · retail: confirmed (runtime dump, vanilla×6)

### SetBBoxProxyBBox

```lua
Entity.SetBBoxProxyBBox()
```

C++: `int SetBBoxProxyBBox (IFunctionHandler* pH , Vec3 min , Vec3 max )`

Modifies the aabb of the bbox proxy

docs: y · retail: confirmed (binary, runtime dump)

### SetCharacterPhysicParams

```lua
Entity.SetCharacterPhysicParams()
```

C++: `int SetCharacterPhysicParams (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### SetCloudMovementProperties

```lua
Entity.SetCloudMovementProperties(nSlot, table)
```

Sets the cloud movement properties.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |
| SmartScriptTable table | Table property for the cloud movement. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### SetColliderMode

```lua
Entity.SetColliderMode(mode)
```

C++: `int SetColliderMode (IFunctionHandler * pH , int mode )`

Set the position of the entity @param vec Three component vector containing the entity position

docs: y · retail: confirmed (binary, runtime dump, vanilla×2, mod×7)

### SetCurrentAudioEnvironments

```lua
Entity.SetCurrentAudioEnvironments()
```

C++: `int SetCurrentAudioEnvironments (IFunctionHandler* pH )`

Sets the correct audio environment amounts based on the entity's position in the world.

Returns: nil

docs: y · retail: confirmed (binary, runtime dump, vanilla×14)

### SetDefaultIdleAnimations

```lua
Entity.SetDefaultIdleAnimations()
```

C++: `int SetDefaultIdleAnimations (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### SetDirectionVector

```lua
Entity.SetDirectionVector(direction)
```

C++: `int SetDirectionVector (IFunctionHandler * pH , Vec3 dir )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×2)

### SetEnvironmentFadeDistance

```lua
Entity.SetEnvironmentFadeDistance(fEnvironmentFadeDistance)
```

Sets the distance over which this entity will fade the audio environment amount for all approaching entities.

| Param | Description |
|---|---|
| float const fEnvironmentFadeDistance | fade distance in meters |

Returns: nil

docs: y · retail: confirmed (binary, runtime dump, vanilla×2)

### SetFadeDistance

```lua
Entity.SetFadeDistance(fFadeDistance)
```

Sets the distance in which this entity will execute fade calculations.

| Param | Description |
|---|---|
| float const fFadeDistance | fade distance in meters |

Returns: nil

docs: y · retail: confirmed (binary, runtime dump, vanilla×3)

### SetFlags

```lua
Entity.SetFlags(flags, mode)
```

C++: `int SetFlags (IFunctionHandler * pH , int flags , int mode )`

Mode: 0->or 1->and 2->xor

docs: y · retail: confirmed (binary, runtime dump, vanilla×70, mod×1)

### SetFlagsExtended

```lua
Entity.SetFlagsExtended(flags, mode)
```

C++: `int SetFlagsExtended (IFunctionHandler * pH , int flags , int mode )`

Mode: 0->or 1->and 2->xor

docs: y · retail: confirmed (binary, runtime dump, vanilla×22)

### SetGeomCacheDrawing

```lua
Entity.SetGeomCacheDrawing()
```

C++: `int SetGeomCacheDrawing (IFunctionHandler * pH , bool active )`

syntax: Entity.SetGeomCacheDrawing()

Activates/deactivates geom cache drawing

Activates/deactivates geom cache drawing

docs: y · retail: confirmed (binary, runtime dump, vanilla×2)

### SetGeomCacheParams

```lua
Entity.SetGeomCacheParams()
```

C++: `int SetGeomCacheParams (IFunctionHandler * pH , bool looping , const char * standIn , const char * standInMaterial , const char * firstFrameStandIn , const char * firstFrameStandInMaterial , const char * lastFrameStandIn , const char * lastFrameStandInMaterial , float standInDistance , float streamInDistance )`

syntax: Entity.SetGeomCacheParams()

Sets geometry cache parameters

Sets the parameters of a geometry cache

docs: y · retail: confirmed (runtime dump, vanilla×1)

### SetGeomCachePlaybackTime

```lua
Entity.SetGeomCachePlaybackTime()
```

C++: `int SetGeomCachePlaybackTime (IFunctionHandler * pH , float time )`

syntax: Entity.SetGeomCachePlaybackTime()

Sets the playback time

Sets the playback time of a geometry cache

docs: y · retail: confirmed (binary, runtime dump, vanilla×2)

### SetGeomCacheStreaming

```lua
Entity.SetGeomCacheStreaming()
```

C++: `int SetGeomCacheStreaming (IFunctionHandler * pH , bool active , float time )`

syntax: Entity.SetGeomCacheStreaming()

Activates/deactivates geom cache streaming

Activates/deactivates geom cache streaming

docs: y · retail: confirmed (runtime dump, vanilla×3)

### SetLightBlendParams

```lua
Entity.SetLightBlendParams(int nSlot, char const* tex1, char const* tex2, float blend_weight)
```

C++: `int SetLightBlendParams (IFunctionHandler * pH , int nSlot , char const * tex1 , char const * tex2 , float blend_weight )`

changes the blend textures and weight for probe blending

docs: y · retail: unconfirmed

### SetLightCasterException

```lua
Entity.SetLightCasterException(nLightSlot, nGeometrySlot)
```

Entity render node will be a caster exception for light loaded in nLightSlot.

| Param | Description |
|---|---|
| int nLightSlot | Slot where our light is loaded. |

docs: y · retail: unconfirmed

### SetLightColorParams

```lua
Entity.SetLightColorParams(nSlot, color, specular_multiplier)
```

C++: `int SetLightColorParams (IFunctionHandler* pH , int nSlot , Vec3 color , float specular_multiplier )`

changes the color related params of an existing light.

docs: y · retail: confirmed (runtime dump, vanilla×3)

### SetLinkTarget

```lua
Entity.SetLinkTarget(name, targetId, ith)
```

Specifies the entity that an existing link shall target. Use this function to change the target of an existing link. !

! ! ! !

| Param | Description |
|---|---|
| const char* name | Name of the link that shall target given entity. |
| ScriptHandle targetId | The ID of the entity the link shall target. Pass in NULL_ENTITY to make the link no longer target an entity. |
| (optional) ith | If specified, the i'th link with given name that shall target given entity. Default value: 0 (first link with given name) |

Returns: nothing

docs: y · retail: confirmed (runtime dump, mod×4)

### SetLocalAngles

```lua
Entity.SetLocalAngles(vAngles)
```

C++: `int SetLocalAngles (IFunctionHandler * pH , Ang3 vAngles )`

docs: y · retail: confirmed (binary, runtime dump)

### SetLocalBBox

```lua
Entity.SetLocalBBox(vMin, vMax)
```

C++: `int SetLocalBBox (IFunctionHandler * pH , Vec3 vMin , Vec3 vMax )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×3)

### SetLocalPos

```lua
Entity.SetLocalPos(vPos)
```

C++: `int SetLocalPos (IFunctionHandler * pH , Vec3 vPos )`

Set the position of the entity @param vec Three component vector containing the entity position

docs: y · retail: confirmed (binary, runtime dump)

### SetLocalScale

```lua
Entity.SetLocalScale(fScale)
```

C++: `int SetLocalScale (IFunctionHandler * pH , float fScale )`

docs: y · retail: confirmed (binary, runtime dump)

### SetLodRatio

```lua
Entity.SetLodRatio()
```

C++: `int SetLodRatio (IFunctionHandler * pH )`

0..254 (value is autmatically clamed to to this range)

docs: y · retail: confirmed (binary, runtime dump, mod×14)

### SetMaterial

```lua
Entity.SetMaterial()
```

C++: `int SetMaterial (IFunctionHandler * pH )`

syntax: Entity.SetMaterial()

Set the material of the entity @param materialName Name of material.

docs: y · retail: confirmed (binary, runtime dump, vanilla×7, mod×9)

### SetMaterialFloat

```lua
Entity.SetMaterialFloat(nSlotId, nSubMtlId, sParamName, fValue)
```

Change material parameter.

| Param | Description |
|---|---|
| int nSubMtlId | Specify sub-material by Id |
| const char * sParamName | Name of the material parameter. |
| float fValue | New material parameter value. |
| nSlot | On which slot to change material. |

docs: y · retail: confirmed (runtime dump)

### SetMaterialVec3

```lua
Entity.SetMaterialVec3(nSlotId, nSubMtlId, sParamName, vVec3)
```

C++: `int SetMaterialVec3 (IFunctionHandler * pH , int slot , int nSubMtlId , const char * sParamName , Vec3 fValue )`

docs: y · retail: confirmed (runtime dump)

### SetName

```lua
Entity.SetName()
```

C++: `int SetName (IFunctionHandler * pH )`

Set the name of the entity @param sName String containing the new entity name

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### SetParentSlot

```lua
Entity.SetParentSlot(child, parent)
```

C++: `int SetParentSlot (IFunctionHandler * pH , int child , int parent )`

docs: y · retail: confirmed (binary, runtime dump)

### SetPhysicParams

```lua
Entity.SetPhysicParams()
```

C++: `int SetPhysicParams (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×60, mod×4)

### SetPos

```lua
Entity.SetPos(vPos)
```

Sets the position of the entity.

| Param | Description |
|---|---|
| Vec3 vPos | Position vector. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×6, mod×30)

### SetPublicParam

```lua
Entity.SetPublicParam()
```

Set a shader parameter

| Param | Description |
|---|---|
| paramName | The name of the shader parameter. |
| value | The new value of the parameter. |

docs: y · retail: confirmed (binary, runtime dump)

### SetRegisterInSectors

```lua
Entity.SetRegisterInSectors()
```

C++: `int SetRegisterInSectors (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### SetScale

```lua
Entity.SetScale(fScale)
```

Sets the scaling value for the entity.

| Param | Description |
|---|---|
| float fScale | Scale amount. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×2, mod×12)

### SetScriptUpdateRate

```lua
Entity.SetScriptUpdateRate()
```

C++: `int SetScriptUpdateRate (IFunctionHandler * pH , int nMillis )`

syntax: Entity.SetScriptUpdateRate( nMillis )

docs: y · retail: confirmed (binary, runtime dump, vanilla×3)

### SetSlotFlags

```lua
Entity.SetSlotFlags(int nSlot, const int nFlags, int mode)
```

Set flags for entity slot.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |
| const int nFlags | entity slot flag. |
| Mode | 0=or, 1=and, 2=xor |

docs: y · retail: unconfirmed

### SetSlotHud3D

```lua
Entity.SetSlotHud3D(nSlot)
```

Setup flags for use as 3D HUD entity.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |

docs: y · retail: confirmed (binary, runtime dump)

### SetSlotPos

```lua
Entity.SetSlotPos(nSlot, v)
```

Sets the slot position.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |
| Vec3 v | Position to be set. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×3)

### SetSlotPosAndDir

```lua
Entity.SetSlotPosAndDir(nSlot, pos, dir)
```

Sets the slot position and direction.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |
| Vec3 pos | Position to be set. |
| Vec3 dir | Direction to be set. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×6)

### SetSlotScale

```lua
Entity.SetSlotScale(nSlot, fScale)
```

Sets the slot scale amount.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |
| float fScale | Scale amount for the slot. |

docs: y · retail: confirmed (runtime dump)

### SetSlotScaleAsymmetric

```lua
Entity.SetSlotScaleAsymmetric(nSlot, fScaleX, fScaleY, fScaleZ)
```

Sets the slot scale amount.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |
| float fScaleX | Scale amount for the slot for axis X. |
| float fScaleY | Scale amount for the slot for axis Y. |
| float fScaleZ | Scale amount for the slot for axis Z. |

docs: y · retail: confirmed (runtime dump, vanilla×1)

### SetSlotWorldTM

```lua
Entity.SetSlotWorldTM(nSlot, pos, dir)
```

Sets the World TM (Transformation Matrix) of the slot.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |
| Vec3 pos | Position vector. |
| Vec3 dir | Direction vector. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×2)

### SetSoundEffectRadius

```lua
Entity.SetSoundEffectRadius(float fEffectRadius)
```

syntax: Entity.SetSoundEffectRadius( float fEffectRadius)

Sets the effect radius for a sound entity (e.g. volume ambient sound, reverb preset)

| Param | Description |
|---|---|
| float fEffectRadius | radius of when the effect will be faded in |

docs: y · retail: unconfirmed

### SetSoundSphereSpec

```lua
Entity.SetSoundSphereSpec(soundId, radius)
```

C++: `int SetSoundSphereSpec (IFunctionHandler * pH , ScriptHandle soundId , float radius )`

docs: y · retail: unconfirmed

### SetStateClientside

```lua
Entity.SetStateClientside()
```

C++: `int SetStateClientside (IFunctionHandler * pH )`

true=prevents error when state changes on the client and does not sync state changes to the client

docs: y · retail: confirmed (binary, runtime dump)

### SetStaticSound

```lua
Entity.SetStaticSound(SoundId, bStatic)
```

Marks a sound as static to a certain entity. This sound will not be deleted on done, but can be started a new.

| Param | Description |
|---|---|
| bool bStatic | boolean |
| SoundId | Sound Id. |

docs: y · retail: unconfirmed

### SetTimer

```lua
Entity.SetTimer()
```

C++: `int SetTimer (IFunctionHandler * pH )`

syntax: Entity.SetTimer()

docs: y · retail: confirmed (binary, runtime dump, vanilla×43)

### SetTriggerBBox

```lua
Entity.SetTriggerBBox(vMin, vMax)
```

C++: `int SetTriggerBBox (IFunctionHandler * pH , Vec3 vMin , Vec3 vMax )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### SetUpdatePolicy

```lua
Entity.SetUpdatePolicy(nUpdatePolicy)
```

Changes update policy for the entity. ! Update policy controls when entity becomes active or inactive (ex. when visible, when in close proximity, etc...). ! All active entities will be updated every frame, having too many active entities can affect performance. ! ! Update Policy Meaning ! ------------- ----------- ! ENTITY_UPDATE_NEVER Never update this entity. ! ENTITY_UPDATE_IN_RANGE Activate entity when in specified radius. ! ENTITY_UPDATE_POT_VISIBLE Activate entity when potentially visible. ! ENTITY_UPDATE_VISIBLE Activate entity when visible in frustum. ! ENTITY_UPDATE_PHYSICS Activate entity when physics awakes, deactivate when physics go to sleep. ! ENTITY_UPDATE_PHYSICS_VISIBLE Same as ENTITY_UPDATE_PHYSICS, but also activates when visible. ! ENTITY_UPDATE_ALWAYS Entity is always active and updated every frame.

| Param | Description |
|---|---|
| int nUpdatePolicy | Update policy type. |

Remarks: Use SetUpdateRadius for update policy that require a radius.

docs: y · retail: confirmed (binary, runtime dump, vanilla×12)

### SetUpdateRadius

```lua
Entity.SetUpdateRadius()
```

C++: `int SetUpdateRadius (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### SetVelocity

```lua
Entity.SetVelocity(velocity)
```

C++: `int SetVelocity (IFunctionHandler * pH , Vec3 velocity )`

Set the velocity of the entity

docs: y · retail: confirmed (binary, runtime dump)

### SetViewDistRatio

```lua
Entity.SetViewDistRatio()
```

C++: `int SetViewDistRatio (IFunctionHandler * pH )`

0..254 (value is autmatically clamed to to this range)

docs: y · retail: confirmed (binary, runtime dump, mod×22)

### SetViewDistUnlimited

```lua
Entity.SetViewDistUnlimited()
```

C++: `int SetViewDistUnlimited (IFunctionHandler * pH )`

do not fade out object - no matter how far away it is

docs: y · retail: confirmed (binary, runtime dump, mod×29)

### SetVolumeObjectMovementProperties

```lua
Entity.SetVolumeObjectMovementProperties(nSlot, table)
```

Sets the properties of the volume object movement.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |
| SmartScriptTable table | Table with volume object properties. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### SetWorldAngles

```lua
Entity.SetWorldAngles(vAngles)
```

C++: `int SetWorldAngles (IFunctionHandler * pH , Ang3 vAngles )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×2, mod×2)

### SetWorldPos

```lua
Entity.SetWorldPos(vPos)
```

C++: `int SetWorldPos (IFunctionHandler * pH , Vec3 vPos )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×4, mod×36)

### SetWorldScale

```lua
Entity.SetWorldScale(fScale)
```

C++: `int SetWorldScale (IFunctionHandler * pH , float fScale )`

docs: y · retail: confirmed (binary, runtime dump)

### StartAnimation

```lua
Entity.StartAnimation()
```

C++: `int StartAnimation (IFunctionHandler* pH )`

Starts an animation of a character @param pos Number of the character slot @param animname Name of the animation from the .chrparams file @see CScriptBind_Entity::LoadCharacter @see CEntity::StartAnimation

docs: y · retail: confirmed (binary, runtime dump, vanilla×10)

### StopAllSounds

```lua
Entity.StopAllSounds()
```

C++: `int StopAllSounds (IFunctionHandler * pH )`

Stop all sounds played on the entity.

docs: y · retail: confirmed (vanilla×2)

### StopAnimation

```lua
Entity.StopAnimation(characterSlot, layer)
```

C++: `int StopAnimation (IFunctionHandler * pH , int characterSlot , int layer )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×8)

### StopAudioTrigger

```lua
Entity.StopAudioTrigger(hTriggerID, hAudioProxyLocalID)
```

Stop the audio event generated by the trigger with the specified ID on this entity.

| Param | Description |
|---|---|
| ScriptHandle const hTriggerID | the audio trigger ID handle |
| ScriptHandle const hAudioProxyLocalID | ID of the AuxAudioProxy local to the EntityAudioProxy (to address the default AuxAudioProxy pass 1 to address all AuxAudioProxies pass 0) |

Returns: nil

docs: y · retail: confirmed (binary, runtime dump, vanilla×8)

### StopSound

```lua
Entity.StopSound(SoundId)
```

Stop sound played on the entity. Only sound started for this entity will be stopped.

| Param | Description |
|---|---|
| SoundId | Sound Id. |

docs: y · retail: confirmed (vanilla×2)

### ToGlobal

```lua
Entity.ToGlobal(slotId, point)
```

C++: `int ToGlobal (IFunctionHandler * pH , int slotId , Vec3 point )`

transform pos from local to world coordinates. uses object when slot<0

docs: y · retail: confirmed (binary, runtime dump, vanilla×3)

### ToLocal

```lua
Entity.ToLocal(slotId, point)
```

C++: `int ToLocal (IFunctionHandler * pH , int slotId , Vec3 point )`

transform pos from world to local coordinates. uses object when slot<0

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### TriggerEvent

```lua
Entity.TriggerEvent()
```

C++: `int TriggerEvent (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×5)

### UnSeenFrames

```lua
Entity.UnSeenFrames()
```

C++: `int UnSeenFrames (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### UpdateAreas

```lua
Entity.UpdateAreas()
```

C++: `int UpdateAreas (IFunctionHandler * pH )`

docs: y · retail: confirmed (binary, runtime dump)

### UpdateLightClipBounds

```lua
Entity.UpdateLightClipBounds(nSlot)
```

Update the clip bounds of the light from the linked entities.

| Param | Description |
|---|---|
| int nSlot | Slot identifier. |

docs: y · retail: confirmed (binary, runtime dump, vanilla×8)

### UpdateShaderParamCallback

```lua
Entity.UpdateShaderParamCallback()
```

C++: `int CheckShaderParamCallbacks (IFunctionHandler* pH )`

Check all the currently set shader param callbacks on the renderproxy with the current state of the entity.

docs: y · retail: unconfirmed

### UpdateSlotPhysics

```lua
Entity.UpdateSlotPhysics(slot)
```

C++: `int UpdateSlotPhysics (IFunctionHandler * pH , int slot )`

docs: y · retail: confirmed (binary, runtime dump)

### VectorToGlobal

```lua
Entity.VectorToGlobal(slotId, dir)
```

C++: `int VectorToGlobal (IFunctionHandler * pH , int slotId , Vec3 dir )`

transform vector from local to world coordinates. uses object when slot<0

docs: y · retail: confirmed (binary, runtime dump, vanilla×1)

### VectorToLocal

```lua
Entity.VectorToLocal(slotId, dir)
```

C++: `int VectorToLocal (IFunctionHandler * pH , int slotId , Vec3 dir )`

transform vector from world to local coordinates. uses object when slot<0

docs: y · retail: confirmed (binary, runtime dump, vanilla×2)

## Undocumented (present in retail, not in official docs)

### CheckShaderParamCallbacks

`Entity.CheckShaderParamCallbacks(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump, vanilla×2)

### HasFlagsExtended

`Entity.HasFlagsExtended(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)

### LoadObjectWithFlags

`Entity.LoadObjectWithFlags(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)

### SetSelfAsLightCasterException

`Entity.SetSelfAsLightCasterException(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)

### SetSlotAngles

`Entity.SetSlotAngles(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (runtime dump, vanilla×1)

### SetVelocityEx

`Entity.SetVelocityEx(...)` -- not in the official script_bind docs.

docs: n · retail: confirmed (binary, runtime dump)
